# M0 Bazel 뼈대 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 시뮬레이터에서 실행되는 빈 TCA iPad 앱을 만든다. Bazel 빌드, 모듈 경계, 개인정보 보호 장치, GitHub Actions CI까지 갖춘 공개 저장소 상태로 만든다.

**Architecture:** KrossBuy(`~/Workspace/agent-commerce-mvp`)의 Bazel + Makefile 구조를 iPad 전용으로 옮긴다. 기능 모듈(`Features/*`)은 서비스 **인터페이스** 모듈(`Clients/*`)에만 의존한다. **구현** 모듈(`Clients/*Live`)은 Bazel `visibility`로 앱 타깃에서만 보이게 막는다. **앱 타깃은 얇게 유지한다**: `@main` 진입점과 실제 구현 주입(bootstrap)만 둔다. 화면, 상태, 수명 주기 처리는 `AppCore` 모듈에 있고, 수명 주기 이벤트도 TCA 액션으로 바꿔 테스트한다. M0의 실제 기능은 시계 표시, 부모 모드 진입(Face ID), 부모 모드에서 돌아오기뿐이다. 이 기능은 TCA 리듀서, 이펙트, 시계 의존성, `StackState` 화면 이동, `TestStore` 테스트 패턴의 견본 역할을 한다.

**Tech Stack:** Bazel 8.8.2 (bzlmod), rules_apple, rules_swift, rules_swift_package_manager, rules_xcodeproj, Swift 6, SwiftUI, TCA 1.x, LocalAuthentication, XCTest, GitHub Actions, gitleaks

**Spec:** `docs/private/2026-11-07-family-planner-design.md` (개인정보가 있어 git에서 제외. 이 세션 폴더의 `docs/superpowers/specs/`에서 복사)

## Global Constraints

- 저장소 위치: `~/Workspace/family-planner`, 공개 GitHub 저장소 (개인 스터디 용도)
- `.bazelversion` = `8.8.2`
- Rules 시작 버전 (KrossBuy와 동일, 8.8.2에서 실패할 때만 올림): apple_support 1.24.5, rules_swift 3.4.2, rules_apple 4.3.3, bazel_skylib 1.9.0, rules_swift_package_manager 1.12.0, rules_xcodeproj 3.5.1 (dev_dependency)
- `repo_name` 필수: `build_bazel_apple_support`, `build_bazel_rules_swift`, `build_bazel_rules_apple` (KrossBuy Known Gotchas 1, 2)
- `MINIMUM_OS_VERSION = "26.0"`, `families = ["ipad"]`, 가로 방향만 지원
- 앱 이름 `FamilyPlanner`, 번들 ID는 임시 값 `com.example.familyplanner` (`project.bzl`에서만 정의)
- `TEAM_ID = ""`. M0–M3는 시뮬레이터 전용이고, 기기 프로비저닝 타깃은 M4에서 추가한다.
- 모든 자체 Swift 모듈은 Swift 6 언어 모드(`-swift-version 6`)로 빌드한다.
- TCA: `pointfreeco/swift-composable-architecture` `.upToNextMajor(from: "1.23.1")`
- 화면 문구 기본 언어는 영어
- 코드, 기본값, 테스트, 문서, 커밋에 넣지 않는 것: 집 위치, 정류장 ID, 경로, 아이 이름·나이·학교 이름, API 키. 예시가 필요하면 가짜 값을 쓴다.
- 로컬 시뮬레이터 기본값: `iPad Pro 13-inch (M5)`, iOS `26.5` (이 맥에 설치된 런타임. 실제 기기 M1 iPad Pro 12.9인치와 같은 4:3 비율)
- **개발 맥은 RAM 8GB**: Bazel 서버(JVM), Swift 컴파일, 시뮬레이터가 동시에 메모리를 쓴다. 로컬 전용 메모리 제한은 git에서 제외되는 `user.bazelrc`에 두고(CI에는 적용하지 않음), 시뮬레이터는 하나만 띄우고 쓰지 않을 때 끈다.

## Review Focus

1. **8GB 맥에서 첫 빌드 중 메모리 부족**: TCA와 swift-syntax를 처음 빌드할 때 병렬 컴파일 때문에 스왑이 심해져 맥이 멈춘 것처럼 될 수 있다. 느려도 끝까지 빌드되어야 한다. → Task 2 Step 1의 `user.bazelrc` 제한과 Step 6 검증.
2. **CI 첫 실행 시간 초과**: 캐시가 비어 있으면 swift-syntax를 포함한 TCA 의존성을 처음부터 컴파일한다. 첫 실행이 오래 걸려도 성공해야 하고, 캐시가 생긴 뒤에는 훨씬 빨라야 한다. → Task 6 검증 단계에서 두 번째 실행 시간을 기록한다.
3. **개인정보가 커밋에 섞이는 경우**: 계획서나 메모를 붙여 넣다가 정류장 ID나 아이 이름이 스테이징될 수 있다. 커밋이 막혀야 하고, 막힌 이유가 보여야 한다. → Task 1 테스트.
4. **Face ID가 등록되지 않은 시뮬레이터나 기기**: 인증이 실패해도 앱이 멈추거나 죽지 않고 홈 화면에 남아야 한다. → Task 4 `testParentButtonDeniedStaysHome`, Task 5 수동 확인.
5. **화면을 벗어날 때 시계 이펙트가 남는 경우**: 1초 타이머가 취소되지 않으면 테스트가 끝나지 않고 앱에서는 누수가 생긴다. → Task 4 `testClockTicksEverySecondUntilCancelled`.
6. **Bazel 8.8.2와 rules 버전 비호환**: 의존성을 가져오는 단계에서 실패할 수 있다. 실패하면 rules만 올리고, 올린 버전을 CLAUDE.md에 기록한다. → Task 2 검증.

---

### Task 1: 저장소 시작과 개인정보 보호 장치

이 작업을 실행하기 전에 사용자 승인을 받아 세션 작업 폴더를 `~/Workspace/family-planner`로 옮긴다(`change_directory`).

**Files:**
- Create: `.gitignore`, `.private-terms.example`, `scripts/check-private-terms.sh`, `scripts/tests/check-private-terms-test.sh`, `.githooks/pre-commit`
- Create (git 제외): `docs/private/2026-11-07-family-planner-design.md` (세션 폴더의 설계 문서 복사본), `.private-terms`

**Interfaces:**
- Produces: `scripts/check-private-terms.sh [--staged | <file>...]`. 종료 코드는 0(통과) 또는 1(발견)이다. 발견하면 stderr에 `private term found: <term> in <file>`을 출력한다. 단어 목록은 저장소 루트의 `.private-terms`에서 읽는다(한 줄에 하나, `#` 주석과 빈 줄 무시, 대소문자 무시, 고정 문자열 비교). 파일이 없으면 경고만 하고 0으로 끝낸다.
- Produces: `.githooks/pre-commit`. `gitleaks`로 스테이징된 변경을 검사한 뒤 `scripts/check-private-terms.sh --staged`를 실행한다.

- [ ] **Step 1: `git init`, `.gitignore` 작성.** KrossBuy `.gitignore`의 Bazel/Xcode/SPM/macOS/`.claude` 규칙에 다음을 더한다: `docs/private/`, `.private-terms`, `user.bazelrc`, `LocalConfig.*`, `*.local.json`. KrossBuy와 달리 `MODULE.bazel.lock`은 **무시하지 않는다**(커밋해서 CI 캐시 키와 재현성에 쓴다).

- [ ] **Step 2: 설계 문서를 `docs/private/`에 복사하고, `.private-terms`에 실제 민감 단어를 넣는다.** 넣을 단어: 설계 문서 3장 F3 표에 있는 정류장 ID와 정류장 이름, 학교와 어린이집 이름, 아이 실명(사용자에게 물어서 받는다). `.private-terms.example`에는 형식만 보여주는 가짜 값을 넣는다(`# one term per line`, `12345`, `Example Primary School`).

- [ ] **Step 3: 실패하는 테스트 작성** — `scripts/tests/check-private-terms-test.sh`. 임시 git 저장소를 만들고 `.private-terms`에 `Zebra Stop 99999`를 넣은 뒤 다음을 확인한다.
  - `test_blocks_staged_term`: `notes.md`에 `meet at zebra stop 99999`를 쓰고 스테이징한 뒤 `--staged` 실행 → 종료 코드 1, stderr에 `private term found: Zebra Stop 99999` 포함
  - `test_passes_clean_change`: `notes.md`에 `hello`만 스테이징 → 종료 코드 0
  - `test_ignores_comments_and_blank_lines`: `.private-terms`에 `# comment`와 빈 줄만 있음 → 아무 변경이나 스테이징해도 종료 코드 0
  - `test_missing_terms_file_warns`: `.private-terms` 없음 → 종료 코드 0, stderr에 `.private-terms not found` 포함
  - `test_checks_named_files`: `--staged` 없이 파일 경로를 인자로 주면 그 파일 내용을 검사

- [ ] **Step 4: 테스트 실행 → 실패 확인**

Run: `bash scripts/tests/check-private-terms-test.sh`
Expected: 스크립트가 없어서 FAIL

- [ ] **Step 5: `scripts/check-private-terms.sh` 구현.** `--staged`이면 `git diff --cached -U0 --diff-filter=ACM`의 추가된 줄(`+`로 시작하고 `+++`가 아닌 줄)만 검사한다. 일치한 줄 내용은 출력하지 않고 단어와 파일만 출력한다. `grep -iF`를 쓴다.

- [ ] **Step 6: 테스트 실행 → 통과 확인**

Run: `bash scripts/tests/check-private-terms-test.sh`
Expected: 5개 모두 PASS, 종료 코드 0

- [ ] **Step 7: `.githooks/pre-commit` 작성과 연결.** gitleaks가 없으면 `brew install gitleaks`를 안내하고 실패한다. 스테이징 검사 명령은 설치된 버전에 맞춘다(`gitleaks git --pre-commit --staged --redact`, 없으면 `gitleaks protect --staged --redact`). `git config core.hooksPath .githooks`를 실행한다.

- [ ] **Step 8: 훅 동작 확인.** `.private-terms`의 단어 하나를 넣은 임시 파일을 스테이징하고 `git commit` → 커밋이 막혀야 한다. 파일을 지우고 다시 시도 → 통과해야 한다.

- [ ] **Step 9: Commit**

```bash
git add .gitignore .private-terms.example scripts .githooks
git commit -m "chore: add private-term and secret guards for a public repo"
```

### Task 2: Bazel로 빌드되는 빈 iPad 앱

**Files:**
- Create: `.bazelversion`, `.bazelrc`, `user.bazelrc.example`, `MODULE.bazel`, `BUILD.bazel`, `project.bzl`, `.buildifier.json`, `Package.swift`, `Makefile`, `scripts/check-prereqs.sh`, `scripts/setup-ios.sh`
- Create: `ios/.bazelrc`, `ios/build_defs.bzl`, `ios/BUILD.bazel`, `ios/Info.plist`, `ios/App/FamilyPlannerApp.swift`

**Interfaces:**
- Produces: `project.bzl` 상수 `APP_NAME = "FamilyPlanner"`, `BUNDLE_ID = "com.example.familyplanner"`, `TEAM_ID = ""`, `MINIMUM_OS_VERSION = "26.0"`
- Produces: `ios/build_defs.bzl`의 `fp_swift_library(name, srcs, deps = [], visibility = None, testonly = False)`. `swift_library`를 `module_name = name`, `copts = ["-swift-version", "6"]`, `tags = ["manual"]`로 감싼다. 이후 모든 Swift 모듈은 이 매크로를 쓴다.
- Produces: 타깃 `//ios:FamilyPlannerApp`(앱 라이브러리, module `FamilyPlannerApp`), `//ios:FamilyPlanner`(ios_application), `//ios:xcodeproj`
- Produces: Makefile 타깃 `setup`, `build`, `run`, `test`, `xcodeproj`, `fmt`, `lint`, `clean`, `clean-expunge`. 변수 `SIM_DEVICE ?= iPad Pro 13-inch (M5)`, `SIM_OS ?= 26.5`.

- [ ] **Step 1: 루트 Bazel 설정 작성.** `.bazelversion`은 `8.8.2`. `.bazelrc` 맨 끝에 `try-import %workspace%/user.bazelrc`를 둔다. `user.bazelrc`는 `.gitignore`에 넣고, 8GB 맥용 예시를 `user.bazelrc.example`로 커밋한다. 예시 내용은 다음과 같다(`make setup`이 없으면 복사).
  - `startup --host_jvm_args=-Xmx2g`
  - `startup --max_idle_secs=600` (10분 쉬면 Bazel 서버가 내려가 메모리를 돌려준다)
  - `common --local_resources=memory=HOST_RAM*.5`
  - `common --local_resources=cpu=4`
  - `common --worker_max_instances=1`
  
  나머지는 `.bazelrc`, `ios/.bazelrc`, `.buildifier.json`, `BUILD.bazel`은 KrossBuy 내용을 그대로 쓴다. `MODULE.bazel`은 KrossBuy 구성에서 `rules_python`을 빼고 Global Constraints의 버전을 쓴다. `module(name = "family_planner")`. `swift_deps.from_package`의 `use_repo`에는 `swift_package`와 `swiftpkg_swift_composable_architecture`를 둔다.

- [ ] **Step 2: `Package.swift`에 TCA 의존성 선언**(`swift-tools-version: 6.0`, `platforms: [.iOS(.v26)]`). `swift package resolve`로 `Package.resolved`를 만든다.

- [ ] **Step 3: `ios/App/FamilyPlannerApp.swift`에 `@main struct FamilyPlannerApp: App`를 만든다.** `Text("Family Planner")`만 보여준다. `ios/BUILD.bazel`에 `fp_swift_library(name = "FamilyPlannerApp")`, `ios_application(name = "FamilyPlanner", families = ["ipad"], ...)`, `xcodeproj` 타깃을 만든다. KrossBuy 구조에서 provisioning 관련 부분만 뺀다.

- [ ] **Step 4: `ios/Info.plist` 작성.** `UISupportedInterfaceOrientations~ipad`는 `UIInterfaceOrientationLandscapeLeft`, `UIInterfaceOrientationLandscapeRight` 두 개만 둔다. `UILaunchScreen`은 빈 dict다.

- [ ] **Step 5: Makefile과 setup 스크립트 작성.** KrossBuy의 iOS·공통·Setup 부분만 가져온다(backend, backoffice, parsers 제외). 차이점은 다음과 같다.
  - `test`: `$(IOS_BAZEL) test //ios/... --test_arg=--device_type --test_arg="$(SIM_DEVICE)" --test_arg=--os_version --test_arg="$(SIM_OS)"`
  - `setup`: `check-prereqs`, `setup-ios`를 실행하고 `git config core.hooksPath .githooks`
  - `check-prereqs.sh`: brew, Xcode, bazelisk, buildifier, gitleaks만 확인
  - `setup`은 `user.bazelrc`가 없으면 `user.bazelrc.example`을 복사한다.
  - `sim-stop`: `xcrun simctl shutdown all` (시뮬레이터 메모리 돌려받기)
  - `run`은 빌드가 끝난 뒤에 시뮬레이터를 부팅한다(KrossBuy와 같은 순서). 빌드와 시뮬레이터가 동시에 메모리를 쓰지 않게 하기 위해서다.
  - 테스트 러너: `ios_xctestrun_runner`의 시뮬레이터 재사용 옵션(rules_apple 버전에 있는 이름을 확인한다, 예: `reuse_simulator = True`)을 켠 러너 타깃을 `//ios:test_runner`로 만들고 모든 `ios_unit_test`가 쓴다. 테스트할 때마다 새 시뮬레이터를 만들지 않게 하기 위해서다.

- [ ] **Step 6: 빌드 확인**

Run: `make build`
Expected: `//ios:FamilyPlanner` 빌드 성공. 빌드 중 Activity Monitor의 메모리 압력이 빨간색으로 오래 머물지 않는다. 머물면 `user.bazelrc`의 `cpu`를 2로 낮춘다. 의존성 단계에서 실패하면 rules 버전을 올리고 다시 시도한다. 올린 버전은 Task 6의 CLAUDE.md에 기록한다.

- [ ] **Step 7: 실행 확인**

Run: `make run`
Expected: iPad Pro 13-inch (M5) 시뮬레이터에서 앱이 가로로 뜨고 "Family Planner"가 보인다. 시뮬레이터를 세로로 돌려도 화면이 세로로 바뀌지 않는다.

- [ ] **Step 8: BUILD 파일 정리 확인**

Run: `make lint`
Expected: buildifier 경고 없음

- [ ] **Step 9: Commit**

```bash
git add .bazelversion .bazelrc user.bazelrc.example MODULE.bazel MODULE.bazel.lock BUILD.bazel project.bzl .buildifier.json Package.swift Package.resolved Makefile scripts/check-prereqs.sh scripts/setup-ios.sh ios
git commit -m "build: scaffold iPad-only app with Bazel 8.8.2"
```

### Task 3: 부모 인증 서비스 인터페이스

**Files:**
- Create: `ios/Clients/ParentAuthClient/BUILD.bazel`, `ios/Clients/ParentAuthClient/ParentAuthClient.swift`

**Interfaces:**
- Consumes: `fp_swift_library` (Task 2), `@swiftpkg_swift_composable_architecture//:ComposableArchitecture`
- Produces: 모듈 `ParentAuthClient`, 타깃 `//ios/Clients/ParentAuthClient`

```swift
@DependencyClient
public struct ParentAuthClient: Sendable {
  public var authenticate: @Sendable (_ reason: String) async -> Bool = { _ in false }
}
extension ParentAuthClient: TestDependencyKey { public static let testValue = Self() }
extension DependencyValues { public var parentAuth: ParentAuthClient { get set } }
```

- 이 모듈에는 `liveValue`를 두지 않는다. 실제 구현은 Task 5에서 앱이 주입한다. 다른 모듈의 타입에 `DependencyKey`를 사후 적합(retroactive conformance)시키는 경고를 피하기 위해서다.

- [ ] **Step 1: 위 인터페이스 구현.** BUILD의 `visibility`는 `["//ios:__subpackages__"]`이다.

- [ ] **Step 2: 빌드 확인**

Run: `bazel build //ios/Clients/ParentAuthClient`
Expected: 성공, Swift 6 동시성 경고 없음

- [ ] **Step 3: Commit**

```bash
git add ios/Clients/ParentAuthClient
git commit -m "feat: add ParentAuthClient dependency interface"
```

### Task 4: AppCore 모듈 (수명 주기, 시계, 부모 모드 이동)

앱 타깃에서 실제 동작을 모두 빼서 이 모듈로 옮긴다. 수명 주기 이벤트(앱 시작, scenePhase 변화)는 TCA 액션으로 바꿔서 리듀서에서 처리하고 테스트한다. 앱 타깃에는 진입점과 실제 구현 주입만 남긴다(Task 5).

**Files:**
- Create: `ios/AppCore/BUILD.bazel`, `ios/AppCore/AppFeature.swift`, `ios/AppCore/AppView.swift`, `ios/AppCore/AppScene.swift`, `ios/AppCore/AppDelegateBase.swift`, `ios/AppCore/ParentHomeFeature.swift`, `ios/AppCore/ParentHomeView.swift`
- Test: `ios/AppCore/Tests/BUILD.bazel`, `ios/AppCore/Tests/AppFeatureTests.swift`

**Interfaces:**
- Consumes: `ParentAuthClient`, `DependencyValues.parentAuth` (Task 3)
- Produces: 모듈 `AppCore`, 타깃 `//ios/AppCore`. deps는 ComposableArchitecture와 `//ios/Clients/*` 인터페이스 모듈**만** 쓴다(`*Live`는 쓰지 않는다).

```swift
@Reducer public struct AppFeature {
  @Reducer public enum Path { case parentHome(ParentHomeFeature) }
  @ObservableState public struct State: Equatable {
    public var now: Date?
    public var scenePhase: ScenePhase = .inactive
    public var path = StackState<Path.State>()
    public init()
  }
  public enum AppDelegateAction: Equatable { case didFinishLaunching }
  public enum Action {
    case appDelegate(AppDelegateAction), scenePhaseChanged(ScenePhase)
    case task, tick(Date), parentButtonTapped, parentAuthResponse(Bool), path(StackActionOf<Path>)
  }
}
extension AppFeature.Path.State: Equatable {}

@Reducer public struct ParentHomeFeature {
  @ObservableState public struct State: Equatable { public init() }
  public enum Action { case doneButtonTapped }
}

public struct AppView: View { public init(store: StoreOf<AppFeature>) }

// 앱 전체 Scene. WindowGroup + scenePhase 전달을 담당한다.
public struct AppScene: Scene { public init(store: StoreOf<AppFeature>) }

// 수명 주기 처리의 본체. 앱 타깃은 이 클래스를 상속해서 bootstrap만 override한다.
@MainActor open class AppDelegateBase: NSObject, UIApplicationDelegate {
  public private(set) lazy var store: StoreOf<AppFeature>   // withDependencies: { self.bootstrap(&$0) }
  open func bootstrap(_ dependencies: inout DependencyValues)  // 기본 구현은 비어 있다
  public func application(_:didFinishLaunchingWithOptions:) -> Bool  // store.send(.appDelegate(.didFinishLaunching))
}
```

- 동작:
  - `.appDelegate(.didFinishLaunching)`: M0에서는 상태 변화도 이펙트도 없다. 알림 권한, 백그라운드 작업 등록 같은 시작 작업이 앞으로 여기에 붙는다.
  - `.scenePhaseChanged(phase)`: `state.scenePhase = phase`로 기록한다. `AppScene`이 `@Environment(\.scenePhase)`의 변화를 이 액션으로 보낸다.
  - `.task`: `continuousClock.timer(interval: .seconds(1))`로 매 초 `.tick(date.now)`을 보낸다.
  - `.parentButtonTapped`: `parentAuth.authenticate("Open parent mode")`를 호출하고 결과를 `.parentAuthResponse(Bool)`로 받는다. `true`이면 `path.append(.parentHome(.init()))`, `false`이면 상태를 바꾸지 않는다.
  - `ParentHomeFeature.doneButtonTapped`: `@Dependency(\.dismiss)`로 화면을 닫는다.
  - `AppView`: `NavigationStack(path: $store.scope(state: \.path, action: \.path))`의 루트에 시각(`now`, `HH:mm:ss`)과 `Parent` 버튼을 보여준다. 시각은 `.task { await store.send(.task).finish() }`로 시작한다.

- [ ] **Step 1: 실패하는 테스트 작성** — `AppFeatureTests` (XCTest, `@MainActor`, `TestStore`). 고정 날짜는 `Date(timeIntervalSince1970: 1_800_000_000)`를 쓴다.
  - `testClockTicksEverySecondUntilCancelled`: `TestClock`을 주입하고 `.task`를 보낸다. `clock.advance(by: .seconds(1))` 후 `.tick(fixedDate)`를 받고 `state.now == fixedDate`인지 확인한다. 한 번 더 advance해서 두 번째 tick을 받는다. `await task.cancel()` 후 테스트가 남은 이펙트 없이 끝나는지 확인한다.
  - `testParentButtonAuthorizedPushesParentHome`: `parentAuth.authenticate = { _ in true }`. 버튼을 누르면 `.parentAuthResponse(true)`를 받고 `state.path`에 `.parentHome(ParentHomeFeature.State())` 하나가 생긴다.
  - `testParentButtonDeniedStaysHome`: `authenticate`가 `false`를 반환한다. `.parentAuthResponse(false)`를 받고 `state.path`는 비어 있다.
  - `testParentHomeDoneDismisses`: `path`에 parentHome이 있는 상태에서 `.path(.element(id: 0, action: .parentHome(.doneButtonTapped)))`를 보내면 `.path(.popFrom(id: 0))`를 받고 `path`가 빈다.
  - `testAuthenticateReceivesReason`: `authenticate`에 넘어온 `reason`이 `"Open parent mode"`인지 확인한다.
  - `testDidFinishLaunchingHasNoSideEffects`: `.appDelegate(.didFinishLaunching)`를 보내면 상태 변화와 이펙트가 없다.
  - `testScenePhaseIsTracked`: `.scenePhaseChanged(.active)` 후 `state.scenePhase == .active`, `.scenePhaseChanged(.background)` 후 `.background`.

  `Tests/BUILD.bazel`은 `fp_swift_library(name = "AppCoreTestsLib", testonly = True)`와 `ios_unit_test(name = "AppCoreTests", minimum_os_version = MINIMUM_OS_VERSION, bundle_id = BUNDLE_ID + ".appcore.tests", runner = "//ios:test_runner")`로 구성한다. 앱을 호스트로 쓰지 않는다.

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `bazel test //ios/AppCore/Tests:AppCoreTests --test_arg=--device_type --test_arg="iPad Pro 13-inch (M5)" --test_arg=--os_version --test_arg=26.5`
Expected: `AppFeature` 타입이 없어서 컴파일 FAIL

- [ ] **Step 3: 위 Interfaces대로 `AppFeature`, `ParentHomeFeature`, `AppView`, `ParentHomeView`, `AppScene`, `AppDelegateBase` 구현**

- [ ] **Step 4: 테스트 실행 → 통과 확인**

Run: Step 2와 같은 명령
Expected: 7개 PASS

- [ ] **Step 5: Commit**

```bash
git add ios/AppCore
git commit -m "feat: add AppCore with lifecycle actions, clock and parent-mode navigation"
```

### Task 5: 실제 Face ID 구현과 얇은 앱 타깃 (모듈 경계)

**Files:**
- Create: `ios/Clients/ParentAuthClientLive/BUILD.bazel`, `ios/Clients/ParentAuthClientLive/ParentAuthClientLive.swift`
- Modify: `ios/App/FamilyPlannerApp.swift`, `ios/BUILD.bazel` (`FamilyPlannerApp` deps), `ios/Info.plist`

**Interfaces:**
- Consumes: `ParentAuthClient` (Task 3), `AppDelegateBase`, `AppScene` (Task 4)
- Produces: 모듈 `ParentAuthClientLive`, `extension ParentAuthClient { public static let live: ParentAuthClient }`. 타깃의 `visibility = ["//ios:__pkg__"]`이므로 앱 라이브러리만 의존할 수 있다.

- [ ] **Step 1: `ParentAuthClient.live` 구현.** `LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)`을 쓴다(Face ID, 실패 시 기기 암호). 오류가 나면 `false`를 반환한다. `canEvaluatePolicy`가 실패하는 경우(Face ID 미등록, 암호 없음)도 `false`다. 예외를 밖으로 던지지 않는다. Info.plist에 `NSFaceIDUsageDescription` = `"Unlock parent mode."`를 추가한다.

- [ ] **Step 2: 앱 타깃을 얇게 다시 쓴다.** `ios/App/FamilyPlannerApp.swift` 한 파일에 다음 두 가지만 둔다.
  - `final class AppDelegate: AppDelegateBase`: `bootstrap`을 override해서 실제 구현을 주입한다(`$0.parentAuth = .live`). 앞으로 실제 구현 모듈이 생기면 여기에 한 줄씩 추가한다.
  - `@main struct FamilyPlannerApp: App`: `@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate`를 두고, `body`는 `AppScene(store: appDelegate.store)`만 반환한다.

  화면, 상태, 수명 주기 처리 코드는 앱 타깃에 두지 않는다. `//ios:FamilyPlannerApp`의 deps는 `//ios/AppCore`와 `*Live` 모듈들뿐이다.

- [ ] **Step 3: 경계 확인 두 가지.**
  - `ios/AppCore/BUILD.bazel` deps에 `//ios/Clients/ParentAuthClientLive`를 임시로 넣는다.

    Run: `bazel build //ios/AppCore`
    Expected: visibility 오류로 FAIL (`is not visible from target`). 확인 후 되돌린다.
  - Run: `grep -cv '^\s*\(//.*\)\?$' ios/App/FamilyPlannerApp.swift`
    Expected: 빈 줄과 주석을 뺀 코드가 20줄 이하

- [ ] **Step 4: 시뮬레이터 확인**

Run: `make run`
Expected:
  - 시각이 매 초 바뀐다.
  - 시뮬레이터 Features → Face ID → Enrolled를 켠 상태에서 `Parent`를 누르고 Matching Face를 고르면 부모 화면으로 이동한다. `Done`을 누르면 돌아온다.
  - Non-matching Face를 고르거나 Enrolled를 끈 상태에서는 홈 화면에 남고, 앱이 멈추지 않는다.

- [ ] **Step 5: 전체 테스트 확인**

Run: `make test`
Expected: 전체 PASS

- [ ] **Step 6: Commit**

```bash
git add ios
git commit -m "feat: thin app target that only bootstraps live dependencies"
```

### Task 6: CI, 문서, 공개 저장소

**Files:**
- Create: `.github/workflows/ios-ci.yml`, `.github/workflows/secret-scan.yml`, `CLAUDE.md`, `AGENTS.md` (→ `CLAUDE.md` 심볼릭 링크), `README.md`, `docs/superpowers/plans/2026-11-07-m0-bazel-scaffold.md` (이 계획서)

**Interfaces:**
- Consumes: Makefile 타깃 `build`, `test` (Task 2)

- [ ] **Step 1: `ios-ci.yml` 작성.** KrossBuy `ios-ci.yml`을 바탕으로 하되 다음을 바꾼다.
  - `runs-on: macos-26`, `timeout-minutes: 60` (첫 실행의 swift-syntax 컴파일 대비)
  - SwiftLint와 PR 댓글 단계는 뺀다.
  - 캐시 키는 `bazel-ios-${{ hashFiles('MODULE.bazel.lock', '.bazelversion', 'Package.resolved') }}`
  - 첫 단계에서 `xcodebuild -version`과 `xcrun simctl list devices available | grep iPad`를 출력한다. `make test`의 `SIM_DEVICE`, `SIM_OS`는 러너에 실제로 있는 iPad와 런타임으로 정한다.
  - `paths` 필터는 `ios/**`, `MODULE.bazel*`, `.bazelrc`, `.bazelversion`, `Package.*`, `Makefile`, 이 워크플로 파일
  - `workflow_dispatch` 트리거도 둔다(손으로 다시 돌려 캐시 효과를 확인할 때 쓴다).
  - 사용자가 CI를 배우는 중이므로 **각 단계 위에 왜 필요한지 한두 줄 주석**을 단다(캐시가 무엇을 아끼는지, `paths` 필터가 왜 있는지 등).
  - **CI 결과물(artifact)은 남기지 않는다** **[사용자 결정]**: `actions/upload-artifact`를 쓰지 않는다. 테스트 러너는 `create_xcresult_bundle = False`, Bazel은 `--test_output=errors`만 쓴다. 공개 저장소에서는 CI 로그도 누구나 볼 수 있으므로 `env`, `printenv`, `set -x`처럼 환경 변수를 출력하는 단계를 두지 않고, CI에서는 `--announce_rc`를 끈다(`--noannounce_rc`). 예전에 xcodebuild 로그에 의도하지 않은 환경 변수가 찍힌 경험 때문이다.

- [ ] **Step 2: `secret-scan.yml` 작성.** `ubuntu-latest`에서 `actions/checkout@v4`(`fetch-depth: 0`)와 `gitleaks/gitleaks-action@v2`를 모든 push와 PR에 실행한다. 공개 저장소에 비밀값이 올라가면 이미 늦다는 점과, 로컬 훅이 1차 방어이고 CI가 2차 방어라는 점을 주석으로 단다. 개인 단어 검사(`.private-terms`)는 목록 자체가 비공개라서 로컬에서만 돈다는 점도 주석으로 단다.

- [ ] **Step 3: `CLAUDE.md` 작성.** KrossBuy CLAUDE.md 구조를 따른다. 넣을 내용은 다음과 같다.
  - 프로젝트 한 줄 설명
  - 모노레포 레이아웃 (`ios/`만, `backend/`는 나중)
  - Bazel 버전, 실제로 쓴 rules 버전
  - 모듈 규칙: 앱 타깃(`ios/App`)은 `@main`과 `AppDelegate.bootstrap`(실제 구현 주입)만 둔다. 화면과 수명 주기는 `AppCore`와 기능 모듈에 둔다. 기능 모듈은 Clients 인터페이스에만 의존하고, `*Live`는 `//ios:__pkg__`에만 보이며, 새 모듈은 `fp_swift_library`를 쓴다. 나중에 추가할 App Extension도 같은 방식으로 얇은 진입점만 둔다.
  - 명령 목록
  - Known Gotchas: KrossBuy 1–3번, 이번에 만난 것
  - **공개 저장소 규칙**: Global Constraints의 개인정보 줄, `docs/private/`, `.private-terms`
  - 설계 문서 위치: `docs/private/` (git 제외)

  `README.md`는 개인정보 없이 목적, 요구 사항(Xcode 26, bazelisk), `make setup && make run`만 적는다.

- [ ] **Step 4: 개인정보 검사**

Run: `scripts/check-private-terms.sh $(git ls-files) docs/superpowers/plans/2026-11-07-m0-bazel-scaffold.md CLAUDE.md README.md`
Expected: 종료 코드 0

- [ ] **Step 5: Commit**

```bash
git add .github CLAUDE.md AGENTS.md README.md docs/superpowers/plans
git commit -m "ci: add iOS build/test and secret scan workflows; add project docs"
```

- [ ] **Step 6: 공개 GitHub 저장소 만들기와 push.** 공개 저장소를 만드는 일은 되돌리기 어렵고 외부에 공개되므로 **실행 직전에 사용자에게 저장소 이름과 공개 여부를 확인받는다.** 확인 후 실행한다.

```bash
gh repo create family-planner --public --source . --push
```

- [ ] **Step 7: CI 확인**

Run: `gh run watch` (두 워크플로)
Expected: `iOS CI`와 `Secret scan` 모두 성공. 첫 `iOS CI` 실행 시간을 기록한다. `gh workflow run ios-ci.yml`로 한 번 더 실행해서(빈 커밋은 `paths` 필터에 걸려 실행되지 않는다) 캐시가 맞았는지(`Cache restored`)와 두 번째 실행 시간을 기록하고, 두 숫자를 CLAUDE.md에 남긴다.
