# M1 크레용 디자인 시스템 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 시안의 디자인 기본 보드(0a–0f)를 SwiftUI 모듈로 옮긴다. 이후 모든 화면(M2~)은 이 모듈의 토큰, 크레용 도형, 부품, 화면 틀만 써서 만든다. 부모 화면의 디버그 메뉴에서 부품 갤러리를 열 수 있고, 스냅샷 테스트가 CI에서 돈다.

**Architecture:** 모듈 세 개를 더한다. 셋 다 TCA에 의존하지 않는 순수 SwiftUI 모듈이다.
- `CrayonKit`: 크레용 도형을 그때그때 계산해서 그리는 렌더러. 시드를 고정한 손떨림 테두리(마커)와 빗금 채우기(크레용)를 만든다. 시안에서 쓴 Rough.js의 핵심 동작만 Swift로 옮긴다. SVG 배경을 늘려 쓰면 비율 때문에 찌그러지거나 작아지는 문제(시안에서 실제로 겪음)를 없애고, 어떤 크기에서도 선 굵기를 같게 유지한다.
- `DesignSystem`: 색·글꼴·그리드·간격 토큰, 0b·0c의 부품, 0f의 화면 틀(아이 화면 / 부모 화면), 부품 갤러리.
- `KitArt`: 크레용 킷 그림(정사각형 SVG 에셋)과 그림 칸(`KitSlot`). 지금은 v0(킷)만 돌려준다. M6에서 아이가 그린 그림 버전(Kid A의 그림)으로 바꿔 끼울 수 있게 SwiftUI Environment 값으로 해석기를 둔다.

`AppCore`는 부모 화면에 갤러리로 가는 디버그 경로 하나만 더한다. 그 밖의 기능 화면은 만들지 않는다.

**Tech Stack:** Bazel 8.8.2, rules_apple(`apple_resource_bundle`), rules_swift, SwiftUI `Canvas`·`Shape`, Core Text(글꼴 등록), swift-snapshot-testing, XCTest, Node + roughjs 4.6.6(그림 생성 스크립트, 개발용)

**Spec:** `docs/private/2026-11-07-family-planner-design.md`. 이 계획의 기준은 로드맵(`docs/private/2026-11-07-roadmap-after-hifi.md`, 개인 정보가 있어 git 제외)의 M1과 시안 보드 0a–0f다(비공개 Design canvas, v3 페이지).

## Global Constraints

- M0의 Global Constraints를 모두 따른다(Bazel 8.8.2, Swift 6, `fp_swift_library`, iPad 가로 전용, 개인정보 규칙, 8GB 맥 메모리 제한).
- 모듈 위치는 M0 구조를 따른다: `ios/CrayonKit`, `ios/DesignSystem`, `ios/KitArt`. 테스트는 각 모듈의 `Tests/`.
- 세 모듈 모두 `ComposableArchitecture`에 의존하지 않는다. `visibility = ["//ios:__subpackages__"]`.
- 의존 방향: `DesignSystem` → `CrayonKit`, `KitArt`. `KitArt` → 없음(SwiftUI만). `CrayonKit` → 없음.
- 글꼴은 **Playpen Sans 하나**다. Google Fonts 저장소의 가변 글꼴(`PlaypenSans[wght].ttf`)과 `OFL.txt`를 그대로 넣는다. 파일을 내려받기 전에 출처 URL과 크기를 사용자에게 알리고 승인을 받는다.
- 화면 좌표의 기준은 시안 크기 1376×1032pt다. 실제 기기(M1 iPad Pro 12.9인치)는 1366×1024pt라서 **그리드는 화면 폭에서 계산**하고 고정 픽셀 위치를 쓰지 않는다.
- **공개 저장소에 넣지 않는 그림**: 학교 마스코트 그림(학교를 알아볼 수 있음)과 집 그림(실제 건물).
- **이름 규칙**: 계획서, 코드, 테스트, 에셋 이름 어디에도 실제 아이 이름을 쓰지 않는다. 예시와 샘플 데이터는 `Kid A`, `Kid B`를 쓴다. `KitArt`의 학교·집 칸 v0은 일반 그림(학교 건물, 집)을 쓴다. 진짜 그림은 M6의 그림 칸으로 들어가고, 개발 중에는 git에서 제외된 `ios/KitArt/Private/`에 둔다.
- 글자 크기는 6단계(144/96/48/36/30/24)만 쓰고, 화면 글자는 24pt보다 작게 쓰지 않는다.

## Review Focus

1. **크레용 도형이 크기마다 달라 보이는 문제**: 같은 부품을 다른 폭으로 그려도 선 굵기·빗금 간격·흔들림 크기가 같아야 한다. → Task 3 `testStrokeJitterDoesNotScaleWithSize`, Task 9 스냅샷의 폭 3종.
2. **매 프레임 다시 계산되는 비용**: `Canvas`가 다시 그릴 때마다 경로를 새로 만들면 아침 화면(1초마다 갱신)에서 버벅인다. 경로는 (크기, 시드, 스타일)이 같으면 한 번만 만든다. → Task 4 `testGeometryIsCachedPerSize`, Task 9 성능 측정.
3. **테스트 번들에서 글꼴이 안 잡히는 문제**: 앱을 호스트로 쓰지 않는 단위 테스트에서는 `Bundle.main`이 테스트 러너다. 글꼴 등록이 조용히 실패하면 스냅샷이 시스템 글꼴로 찍혀 모두 깨진다. → Task 2 `testPlaypenSansIsRegistered`.
4. **CI와 로컬의 스냅샷 차이**: CI 러너의 iOS 런타임이 로컬(26.5)과 다르면 글자 렌더링이 조금씩 달라진다. 정밀도 기준과 기록 위치를 정해 둔다. → Task 9 Step 5.
5. **아이 화면에 스크롤이 생기는 실수**: 0f 규칙("아이 화면은 스크롤 없음, 개수를 자른다")이 코드로 강제되어야 한다. → Task 8 `KidScreen`에는 `ScrollView`를 넣을 방법이 없게 만든다.
6. **SVG 에셋이 벡터로 유지되지 않는 문제**: 에셋 카탈로그 설정이 빠지면 SVG가 한 크기로만 래스터화되어 큰 그림이 흐려진다. → Task 5 Step 4.

---

### Task 1: 디자인 토큰 (색, 글자 크기, 그리드, 간격)

**Files:**
- Create: `ios/DesignSystem/BUILD.bazel`, `ios/DesignSystem/Tokens/CrayonColor.swift`, `ios/DesignSystem/Tokens/CrayonType.swift`, `ios/DesignSystem/Tokens/GridMetrics.swift`, `ios/DesignSystem/Tokens/Spacing.swift`, `ios/DesignSystem/Tokens/Contrast.swift`
- Test: `ios/DesignSystem/Tests/BUILD.bazel`, `ios/DesignSystem/Tests/TokenTests.swift`

**Interfaces:**
- Produces: 모듈 `DesignSystem`, 타깃 `//ios/DesignSystem`

```swift
public enum CrayonColor {
  // 0a 팔레트 (채우기용)
  public static let kidABlue, kidBOrange, onTimeGreen, handRed: Color   // #2E8FE0 #F28C28 #3FAE5A #E5484D
  public static let paper, marker, softText, hurry: Color                   // #F6F2EA #1E1B22 #625D6E #FFB341
  public static let nowSky, goYellow, kidApricot, card: Color               // #8FD3F4 #FFD23F #FBC97A #FFFFFF
  public static let doneGreen: Color                                        // #9ED39A (슬라이더 완료)
  // 글자용 (대비 기준을 통과한 진한 색)
  public static let ink, onTimeText, lateText, link: Color                  // #2B2833 #17744D #C62F35 #2F6FD0
  // 밤 화면
  public static let night, nightText: Color                                 // #22213A #F4EFFF
  public static let kidPalette: [Color]                                     // S1 색 고르기: 파랑, 주황, 초록, 보라
}

public enum CrayonType: CaseIterable {
  case hero, display, title, head, body, caption                            // 144 96 48 36 30 24
  public var size: CGFloat { get }
  public var weight: Font.Weight { get }                                    // 700 700 700 700 500 500
  public var lineHeight: CGFloat { get }                                    // 1.0 1.0 1.15 1.2 1.25 1.3 배
}
extension View { public func crayonType(_ t: CrayonType) -> some View }    // Playpen Sans + 크기 + 굵기 + 줄 간격

public struct GridMetrics: Equatable, Sendable {
  public static let margin: CGFloat = 64, gutter: CGFloat = 24, columns = 12
  public static let headerTop: CGFloat = 48, headerBottom: CGFloat = 128, contentTop: CGFloat = 176, contentBottomInset: CGFloat = 64
  public init(width: CGFloat)
  public var columnWidth: CGFloat { get }                                   // (width - 2*64 - 11*24) / 12
  public func span(_ n: Int) -> CGFloat                                     // n칸 + (n-1) 간격
  public func x(column: Int) -> CGFloat                                     // 0부터
}
public enum Spacing { public static let xs: CGFloat = 8, s = 16, m = 24, l = 40, xl = 64 }

public enum Contrast { public static func ratio(_ a: RGB, _ b: RGB) -> Double }  // WCAG 2.x 상대 휘도
```

- [ ] **Step 1: 실패하는 테스트 작성** — `TokenTests`
  - `testGridAtDesignWidth`: `GridMetrics(width: 1376).columnWidth == 82`, `span(8) == 824`, `span(4) == 400`, `x(column: 8) == 64 + 8*(82+24)`
  - `testGridAtDeviceWidth`: `GridMetrics(width: 1366)`에서 `span(12) == 1366 - 128`(양쪽 여백을 뺀 폭과 같다)
  - `testTypeScaleHasSixSteps`: `CrayonType.allCases.map(\.size) == [144, 96, 48, 36, 30, 24]`
  - `testNoTextStyleBelow24`: 모든 `size >= 24`
  - `testTextColorsPassContrastOnPaper`: `ink`, `softText`, `onTimeText`, `lateText`, `link`를 `paper` 위에 놓았을 때 대비가 4.5 이상. `nightText`는 `night` 위에서 7 이상.
  - `testContrastKnownValues`: 검정/흰색 = 21, 같은 색 = 1
- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `bazel test //ios/DesignSystem/Tests:DesignSystemTests --test_arg=--device_type --test_arg="iPad Pro 13-inch (M5)" --test_arg=--os_version --test_arg=26.5`
Expected: 타입이 없어서 컴파일 FAIL

- [ ] **Step 3: 구현.** 색은 `Color(red:green:blue:)`로 정의하고, 대비 계산용 `RGB` 값도 같은 상수에서 만든다(색을 두 군데에 적지 않는다). `crayonType`은 Task 2의 글꼴 이름을 쓰지만, 이 단계에서는 `Font.system`으로 대신해도 된다.
- [ ] **Step 4: 테스트 실행 → 통과 확인** (Step 2와 같은 명령). 대비 테스트가 실패하면 색을 바꾸지 말고 실패한 값을 기록해서 사용자에게 보고한다(시안과 달라지기 때문).
- [ ] **Step 5: Commit**

```bash
git add ios/DesignSystem
git commit -m "feat(design): add crayon color, type, grid and spacing tokens"
```

### Task 2: Playpen Sans 글꼴 묶기와 등록

**Files:**
- Create: `ios/DesignSystem/Resources/Fonts/PlaypenSans[wght].ttf`, `ios/DesignSystem/Resources/Fonts/OFL.txt`, `ios/DesignSystem/Fonts/FontRegistrar.swift`, `ios/DesignSystem/Fonts/ResourceLocator.swift`
- Modify: `ios/DesignSystem/BUILD.bazel`, `ios/DesignSystem/Tokens/CrayonType.swift`, `ios/AppCore/AppDelegateBase.swift`
- Test: `ios/DesignSystem/Tests/FontTests.swift`

**Interfaces:**
- Produces: `apple_resource_bundle(name = "DesignSystemResources")`를 `//ios/DesignSystem`의 `data`로 붙인다. 앱과 테스트 번들 안에 `DesignSystemResources.bundle`로 들어간다.

```swift
public enum FontRegistrar {
  public static let familyName = "Playpen Sans"
  @discardableResult public static func registerAll() -> Bool   // 이미 등록됐으면 true만 반환 (두 번 불러도 안전)
}
enum ResourceLocator {
  static func bundle(named: String) -> Bundle?                  // Bundle.main → Bundle.allBundles 순서로 *.bundle을 찾는다
}
```

- [ ] **Step 1: 글꼴 파일 준비.** Google Fonts 저장소(`google/fonts`의 `ofl/playpensans/`)에서 `PlaypenSans[wght].ttf`와 `OFL.txt`를 받는다. **받기 전에 URL과 파일 크기를 사용자에게 알리고 승인을 받는다.** 받은 뒤 `shasum -a 256` 값을 `ios/DesignSystem/Resources/Fonts/SOURCE.md`에 출처와 함께 적는다.
- [ ] **Step 2: 실패하는 테스트 작성** — `FontTests`
  - `testPlaypenSansIsRegistered`: `FontRegistrar.registerAll()`이 `true`이고, `UIFont(name:size:)`로 찾은 글꼴의 `familyName`이 `"Playpen Sans"`
  - `testRegisterTwiceIsHarmless`: 두 번 불러도 `true`, 오류 로그 없음
  - `testWeightsResolve`: 굵기 500, 600, 700이 서로 다른 글리프 폭을 낸다(같은 문자열을 세 굵기로 재서 폭이 커지는 순서)
- [ ] **Step 3: 테스트 실행 → 실패 확인** (Task 1 Step 2와 같은 형식, 타깃만 다름)
- [ ] **Step 4: 구현.** `CTFontManagerRegisterFontsForURL(url, .process, nil)`를 쓴다. 이미 등록돼 있다는 오류(`kCTFontManagerErrorAlreadyRegistered`)는 성공으로 본다. `crayonType`을 `Font.custom(familyName, size:).weight(...)`로 바꾼다. `AppDelegateBase.application(_:didFinishLaunchingWithOptions:)`에서 `FontRegistrar.registerAll()`을 한 번 부른다.
- [ ] **Step 5: 테스트 실행 → 통과 확인.** 테스트 번들에서 `ResourceLocator`가 번들을 못 찾으면 rules_apple이 리소스를 테스트 번들에 넣었는지 `bazel-bin` 안의 `.xctest`를 열어 확인한다.
- [ ] **Step 6: Commit**

```bash
git add ios/DesignSystem ios/AppCore/AppDelegateBase.swift
git commit -m "feat(design): bundle and register Playpen Sans"
```

### Task 3: CrayonKit 손떨림 선과 빗금 (순수 계산)

**Files:**
- Create: `ios/CrayonKit/BUILD.bazel`, `ios/CrayonKit/SeededRandom.swift`, `ios/CrayonKit/CrayonOutline.swift`, `ios/CrayonKit/Hachure.swift`, `ios/CrayonKit/CrayonShapeKind.swift`, `ios/CrayonKit/CrayonGeometry.swift`
- Test: `ios/CrayonKit/Tests/BUILD.bazel`, `ios/CrayonKit/Tests/CrayonGeometryTests.swift`

**Interfaces:**
- Produces: 모듈 `CrayonKit`, 타깃 `//ios/CrayonKit`

```swift
public struct SeededRandom: Sendable {                 // Rough.js와 같은 Park–Miller LCG (48271, 2^31-1)
  public init(seed: UInt32)
  public mutating func next() -> Double                // [0, 1)
}

public enum CrayonShapeKind: Hashable, Sendable {
  case roundedRect(cornerRadius: CGFloat)
  case capsule
  case circle
  case speechBubble(tailX: CGFloat, tailHeight: CGFloat)   // BusBubble, PickerPopover (꼬리 위치는 비율 0...1)
}

public struct MarkerStyle: Hashable, Sendable {        // 시안 기본값: roughness 1.2, bowing 1.4, width 4
  public var width: CGFloat, roughness: CGFloat, bowing: CGFloat
  public static let standard, thin: MarkerStyle        // 4 / 3.5
}
public struct HachureStyle: Hashable, Sendable {       // 시안 기본값: gap 5.5, weight 2.6, wash 0.32
  public var angle: Angle, gap: CGFloat, weight: CGFloat, washOpacity: Double
}

public struct CrayonGeometry: Sendable {
  public let outline: [CGPoint]                        // 마커 선 (한 번 긋기, 닫힌 경로)
  public let washOutline: [CGPoint]                    // 옅은 바탕 칠의 흔들린 테두리
  public let hachureLines: [(CGPoint, CGPoint)]        // 빗금 선분들
  public init(kind: CrayonShapeKind, in rect: CGRect, seed: UInt32,
              marker: MarkerStyle, hachure: HachureStyle?)
}
```

- 알고리즘(시안의 Rough.js 설정과 같은 느낌을 내되 단순하게):
  - 도형의 이상적인 테두리를 일정한 **길이 간격**(약 12pt)으로 점을 찍는다. 크기에 비례하는 간격이 아니라 고정 길이라서, 큰 카드와 작은 칩의 손떨림 정도가 같다.
  - 각 점을 법선 방향으로 `±roughness`pt 안에서, 저주파(이웃 점과 보간한) 노이즈로 민다. 변 전체가 살짝 휘는 `bowing`은 변마다 한 번 정한다.
  - 마지막 점은 첫 점을 1–2pt 지나치게 해서 한 번에 그은 마커처럼 닫는다.
  - 빗금: 도형을 `-angle`만큼 돌려 `gap` 간격 수평선과 교차시킨 뒤 다시 돌린다. 선분 양 끝을 ±1pt 흔들고, 테두리 밖으로 최대 2pt까지 삐져나가게 둔다(시안의 "칠이 선 밖으로 살짝").
  - 모든 무작위 값은 `SeededRandom(seed)` 하나에서만 뽑는다.

- [ ] **Step 1: 실패하는 테스트 작성** — `CrayonGeometryTests`
  - `testSameSeedSameGeometry`: 같은 입력 두 번 → `outline`, `hachureLines`가 완전히 같다
  - `testDifferentSeedDifferentGeometry`: 시드만 다르면 `outline`이 다르다
  - `testOutlineStaysNearIdealShape`: 모든 점이 이상적인 테두리에서 `roughness + bowing + 1`pt 안에 있다(capsule, roundedRect, circle, speechBubble 각각)
  - `testStrokeJitterDoesNotScaleWithSize`: 같은 시드로 200×80과 1200×80을 만들었을 때 최대 흔들림 폭이 둘 다 같은 범위 안
  - `testHachureSpacingMatchesGap`: 이웃 빗금 사이 거리의 중앙값이 `gap ± 1`
  - `testHachureStaysMostlyInside`: 빗금 끝점이 테두리 밖으로 2pt 넘게 나가지 않는다
  - `testRandomMatchesReferenceSequence`: `SeededRandom(seed: 101)`의 첫 5개 값이 미리 계산한 값과 같다(Rough.js `random.ts`와 같은 식으로 계산한 값을 테스트에 적는다)
- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `bazel test //ios/CrayonKit/Tests:CrayonKitTests --test_arg=--device_type --test_arg="iPad Pro 13-inch (M5)" --test_arg=--os_version --test_arg=26.5`
Expected: 컴파일 FAIL

- [ ] **Step 3: 구현.** UI와 무관한 계산만 둔다(`CoreGraphics` 타입만 import). 
- [ ] **Step 4: 테스트 실행 → 통과 확인**
- [ ] **Step 5: Commit**

```bash
git add ios/CrayonKit
git commit -m "feat(crayon): seeded marker outline and hachure geometry"
```

### Task 4: CrayonKit SwiftUI 표면 (`CrayonSurface`)

**Files:**
- Create: `ios/CrayonKit/CrayonSurface.swift`, `ios/CrayonKit/GeometryCache.swift`
- Test: `ios/CrayonKit/Tests/CrayonSurfaceTests.swift`

**Interfaces:**

```swift
public struct CrayonFill: Hashable, Sendable {
  public var color: Color; public var hachure: HachureStyle
  public static func paper(_ color: Color = .white) -> CrayonFill?   // 빗금 없는 흰 종이 → hachure 없이 단색
}

public struct CrayonSurface: View {
  public init(_ kind: CrayonShapeKind, fill: CrayonFill?, marker: MarkerStyle = .standard,
              markerColor: Color = .init(white: 0.12), seed: UInt32)
}
extension View {
  public func crayonBackground(_ kind: CrayonShapeKind, fill: CrayonFill?, seed: UInt32,
                               marker: MarkerStyle = .standard) -> some View
}

final class GeometryCache: @unchecked Sendable {          // NSCache 래퍼, 키 = (kind, size 반올림, seed, marker, hachure)
  static let shared: GeometryCache
  func geometry(for key: Key, make: () -> CrayonGeometry) -> CrayonGeometry
  var makeCount: Int { get }                              // 테스트용
}
```

- `CrayonSurface`는 `Canvas` 하나로 그린다: 바탕 칠(`washOpacity`) → 빗금 → 마커 선 순서. 테두리 선의 굵기는 화면 크기와 무관한 pt 값이다.
- 크기는 소수점 아래를 반올림해 캐시 키로 쓴다. 회전·애니메이션 중 크기가 조금씩 바뀌어도 캐시가 폭발하지 않게 한다.
- 시드는 부품이 정한다. 같은 화면의 같은 부품은 언제나 같은 모양이어야 하므로 **시드를 무작위로 만들지 않는다**. 부품 종류마다 기본 시드를 두고, 목록처럼 같은 부품이 여러 개면 순번을 더한다.

- [ ] **Step 1: 실패하는 테스트 작성** — `CrayonSurfaceTests`
  - `testGeometryIsCachedPerSize`: 같은 키로 두 번 요청 → `makeCount == 1`. 폭이 1pt 달라지면 2.
  - `testSubpixelSizesShareCache`: 200.2와 200.4 폭은 같은 키
  - `testPaperFillHasNoHachure`: `.paper()`로 만든 표면의 기하에 빗금이 없다
- [ ] **Step 2–4: 실패 확인 → 구현 → 통과 확인** (Task 3과 같은 명령)
- [ ] **Step 5: 미리보기 확인.** `#Preview`에 카드(흰 종이), 하늘색 알약(빗금 −30°), 노란 슬라이더(−50°), 말풍선을 시안 크기로 나란히 둔다. `make xcodeproj` 없이 확인하려면 Task 9의 갤러리에서 본다.
- [ ] **Step 6: Commit**

```bash
git add ios/CrayonKit
git commit -m "feat(crayon): CrayonSurface view with cached geometry"
```

### Task 5: KitArt 그림 칸과 크레용 킷 에셋

**Files:**
- Create: `tools/crayon-art/package.json`, `tools/crayon-art/package-lock.json`, `tools/crayon-art/kit.js`, `tools/crayon-art/README.md`
- Create: `ios/KitArt/BUILD.bazel`, `ios/KitArt/KitSlot.swift`, `ios/KitArt/KitArtResolver.swift`, `ios/KitArt/KitIcon.swift`, `ios/KitArt/Resources/KitArt.xcassets/**`
- Create (git 제외): `ios/KitArt/Private/` (학교 마스코트, 집 그림. `.gitignore`에 추가)
- Modify: `Makefile` (`art` 타깃), `.gitignore`
- Test: `ios/KitArt/Tests/BUILD.bazel`, `ios/KitArt/Tests/KitArtTests.swift`

**Interfaces:**

```swift
public enum KitSlot: String, CaseIterable, Sendable {
  case busMini, busSingle, busDouble
  case medalGold, medalSilver, medalBronze
  case toothbrush, backpack, shirt, shoe, tv, star, sun
  case actBreakfast, actSchool, actCCA, actPlay, actDinner, actShower, actSleep
  case actDance, actStory, actSwim                             // 방과후 활동. 그림이 없는 활동은 actCCA
  case feelVeryHappy, feelHappy, feelOK, feelSad, feelVerySad
  case energyLots, energyGood, energyTired, energyNone
  case home, kidFace                                           // 공개 v0은 일반 그림. 실제 학교(actSchool)·집(home) 그림은 비공개 덮어쓰기
}

public protocol KitArtResolving: Sendable {
  func image(for slot: KitSlot) -> Image
}
public struct BundledKitArt: KitArtResolving { public init() }  // v0: 에셋 카탈로그
extension EnvironmentValues { public var kitArt: any KitArtResolving { get set } }  // 기본값 BundledKitArt()

public struct KitIcon: View {
  public init(_ slot: KitSlot, size: CGFloat)                   // 시안 크기: 56 / 64 / 88 / 104
}
```

- [ ] **Step 1: 그림 생성 스크립트를 저장소로 옮긴다.** 시안 세션이 넘겨준 `handover/crayon-art/`(`kit.js`, `package.json`, `package-lock.json`, `README.md`)를 `tools/crayon-art/`로 복사한다. `roughjs`는 4.6.6으로 고정돼 있다. 그림 이름이 곧 `KitSlot` 값이고, 출력은 `ios/KitArt/Resources/KitArt.xcassets/<slot>.imageset/`(SVG + `Contents.json`, 벡터 유지 설정 포함)이다. 그림마다 이름에서 시드를 만들어서, 그림을 추가·삭제·재정렬해도 다른 그림이 바뀌지 않는다.
  - 학교 마스코트와 실제 집 그림은 생성기에 없다. 완성된 SVG(`handover/private-art/actSchool.svg`, `home.svg`)를 git에서 제외된 `ios/KitArt/Private/<slot>.svg`에 둔다. 개발 빌드는 이 파일이 있으면 같은 이름의 공개 그림 대신 쓴다(Task 5 해석기).
  - `make art`: `cd tools/crayon-art && npm ci && node kit.js . ../../ios/KitArt/Resources/KitArt.xcassets`
- [ ] **Step 2: `make art` 실행 후 재현성 확인.** 두 번 실행해서 `git status`가 깨끗해야 한다(같은 시드 → 같은 파일).
- [ ] **Step 3: 실패하는 테스트 작성** — `KitArtTests`
  - `testEverySlotHasAnAsset`: 모든 `KitSlot`에 대해 `UIImage(named: slot.rawValue, in: kitArtBundle, with: nil)`이 nil이 아니다
  - `testAssetsArePreservedVectors`: 64pt와 256pt로 그린 이미지가 둘 다 선명하다(256pt 렌더의 가장자리 픽셀 대비가 64pt 렌더를 4배 늘린 것보다 크다)
  - `testResolverCanBeReplaced`: 환경에 가짜 해석기를 넣으면 `KitIcon`이 그 이미지를 쓴다(뷰를 `ImageRenderer`로 그려 픽셀로 비교)
  - `testCatalogMatchesSlotAllowlist`: 공개 카탈로그의 에셋 이름 목록이 `KitSlot.allCases`의 `rawValue` 목록과 정확히 같다(허용 목록 방식이라, 비공개 그림의 이름을 테스트에 적지 않아도 섞여 들어오면 실패한다)
- [ ] **Step 4: 구현.** 각 `imageset`의 `Contents.json`에 `"preserves-vector-representation": true`를 넣는다. 에셋 카탈로그는 `apple_resource_bundle(name = "KitArtResources", resources = glob(["Resources/KitArt.xcassets/**"]))`로 묶는다.
- [ ] **Step 5: 테스트 실행 → 통과 확인**
- [ ] **Step 6: 개인정보 검사**

Run: `scripts/check-private-terms.sh $(git ls-files tools ios/KitArt)`
Expected: 종료 코드 0

- [ ] **Step 7: Commit**

```bash
git add tools/crayon-art ios/KitArt Makefile .gitignore
git commit -m "feat(kitart): crayon kit assets, slots and swappable resolver"
```

### Task 6: 조작 부품 (0b · Components — controls)

**Files:**
- Create: `ios/DesignSystem/Controls/InkButton.swift`, `KidPillButton.swift`, `RoundButton.swift`, `CheckMark.swift`, `CrayonTabs.swift`, `DayChip.swift`, `DateChip.swift`, `CrayonField.swift`, `TimeField.swift`, `IconPicker.swift`, `TimeLeft.swift`, `SlideToGo.swift`, `SlideToGoModel.swift`
- Test: `ios/DesignSystem/Tests/SlideToGoModelTests.swift`, `ios/DesignSystem/Tests/TimeLeftTests.swift`

**Interfaces:** (모두 `public`, 크기·색은 0b 보드 그대로)

| 부품 | 핵심 API | 시안 규칙 |
|---|---|---|
| `InkButton` | `init(_ title: String, action:)` | 높이 96, 검정 마커 칠, 흰 글자, 한 화면에 하나 |
| `KidPillButton` | `init(_ title: String, icon: KitSlot?, action:)` | 높이 96, 살구색 크레용 |
| `RoundButton` | `init(systemSymbol or text: String, accessibilityLabel:, action:)` | 지름 80, 흰 종이 원 |
| `CheckMark` | `init(isDone: Bool, size: CGFloat = 56)` | 끝남 = 파란 크레용 + 흰 체크 |
| `CrayonTabs<ID>` | `init(selection: Binding<ID>, items: [(ID, String, Color?)])` | 높이 72, 고른 칸만 하늘색 |
| `DayChip` | `init(_ letter: String, isOn: Binding<Bool>)` | 지름 72 |
| `DateChip` | `init(weekday: String, day: Int, isOn: Bool, action:)` | 96×104 |
| `CrayonField` | `init(_ placeholder: String, text: Binding<String>)` | 높이 80, 포커스 시 파란 테두리(0b, C3k) |
| `TimeField` | `init(time: Binding<Date>)` | 높이 80, 누르면 시간 휠 |
| `IconPicker` | `init(selection: Binding<KitSlot?>, slots: [KitSlot], onRequestDrawing: () -> Void)` | 88pt 칸, 고르면 파란 링, 끝의 "+"는 그림 요청 |
| `TimeLeft` | `init(minutes: Int)` | 남으면 검정, 0 이하면 빨강 `−2 min` |
| `SlideToGo` | `init(state: SlideToGoModel.Phase, lockedTitle:, idleTitle:, doneTitle:, onGo: () -> Void)` | 잠김(흐림) → 끌기 → 끝에 닿으면 초록 + 체크. 손잡이는 `KitIcon(.busDouble)` |

```swift
public struct SlideToGoModel: Equatable, Sendable {
  public enum Phase: Equatable, Sendable { case locked(remaining: Int), idle, dragging(progress: Double), done }
  public static let completeThreshold = 0.9
  public var phase: Phase
  public mutating func dragChanged(progress: Double)      // locked면 무시, 0...1로 자름
  public mutating func dragEnded() -> Bool                // threshold 이상이면 .done으로 바꾸고 true
}
```

- `SlideToGo`의 손 동작 판단은 `SlideToGoModel`에만 둔다(뷰는 그리기와 제스처 연결만). 끝에 닿는 순간 가벼운 햅틱. VoiceOver에서는 `accessibilityAction(named: "Go")`로 끌지 않고도 실행할 수 있게 한다.
- 문구는 부품이 정하지 않고 호출하는 쪽에서 넘긴다(아침 화면의 "Finish 3 more, then slide" 등).

- [ ] **Step 1: 실패하는 테스트 작성**
  - `SlideToGoModelTests`: `testLockedIgnoresDrag`, `testDragClampsToUnitRange`, `testReleaseBelowThresholdSnapsBack`(→ `.idle`, `false`), `testReleaseAtThresholdCompletes`(→ `.done`, `true`), `testDoneIgnoresFurtherDrags`
  - `TimeLeftTests`: `testPositiveMinutesUseInk`, `testZeroOrNegativeUsesLateRed`, `testNegativeLabelHasMinusSign`(`"−2 min"`, 하이픈이 아닌 마이너스 기호) — 표시 문자열과 색을 정하는 순수 함수 `TimeLeft.presentation(minutes:)`를 테스트한다
- [ ] **Step 2–4: 실패 확인 → 구현 → 통과 확인.** 모든 부품은 Task 4의 `crayonBackground`와 Task 1의 토큰만 쓴다. 색 hex나 글자 크기 숫자를 부품 파일에 직접 쓰지 않는다.
- [ ] **Step 5: Commit**

```bash
git add ios/DesignSystem
git commit -m "feat(design): crayon controls from board 0b"
```

### Task 7: 내용 부품 (0c · Components — content)

**Files:**
- Create: `ios/DesignSystem/Content/NowRow.swift`, `ListRow.swift`, `TodayRow.swift`, `PaperCard.swift`, `PickerPopover.swift`, `BusBubble.swift`, `LeagueProgress.swift`, `VoiceNote.swift`, `KidDot.swift`, `Medal.swift`
- Test: `ios/DesignSystem/Tests/ContentLogicTests.swift`

**Interfaces:**

| 부품 | 핵심 API | 시안 규칙 |
|---|---|---|
| `NowRow` | `init(title:, icon: KitSlot, isDone: Bool, action:)` | 높이 104, 하늘색은 "지금 할 일"에만 |
| `ListRow` / `TodayRow` | `init(leading: String, content: () -> Content)` | 높이 80, 오늘은 흰 종이 카드 + 굵은 글자 |
| `PaperCard` | `init(content:)` | 흰 종이, 마커 테두리, 모서리 24 |
| `PickerPopover<Item>` | `init(title:, items:, selection: Binding<Item>, anchor:)` | 연 칸을 가리키는 꼬리, 기본값이 있음 |
| `BusBubble` | `init(route: String, minutes: Int, crowd: Crowd?, isMine: Bool, transferTo: String?)` | 번호판(내 버스 흰색 28pt, 환승 버스 노란색 24pt), 분, 혼잡도 얼굴 0–2개 |
| `LeagueProgress` | `init(level: KitSlot, levelName:, done: Int, goal: Int, nextName:)` | 줄지 않는 막대, "12 more Go! days to …" |
| `VoiceNote` | `init(duration: Duration, isPlaying: Bool, onPlay:)` | 재생 56 + 파형 + 길이 (녹음 버튼은 M5) |
| `KidDot` | `init(color: Color)` | 이름 옆 24–28pt 점 |
| `Medal` | `init(_ kind: MedalKind, size:)` | 금·은·동 킷 그림 |

```swift
public enum Crowd: Sendable { case seats, standing, full }           // LTA Load: SEA / SDA / LSD
extension Crowd { public var happyFaces: Int }                       // seats 2, standing 1, full 0
public enum MedalKind: Sendable { case gold, silver, bronze }
```

- [ ] **Step 1: 실패하는 테스트 작성** — `ContentLogicTests`
  - `testCrowdFaces`: seats 2, standing 1, full 0
  - `testLeagueProgressNeverExceedsGoal`: done > goal이면 막대 비율 1.0
  - `testLeagueRemainingText`: done 18, goal 30 → `"12 more Go! days to the Double-Decker"`
  - `testBusPlateSizes`: 내 버스 28pt, 환승 버스 24pt(24 미만 금지 규칙)
- [ ] **Step 2–4: 실패 확인 → 구현 → 통과 확인**
- [ ] **Step 5: Commit**

```bash
git add ios/DesignSystem
git commit -m "feat(design): content components from board 0c"
```

### Task 8: 화면 틀 (0f · Scroll and overflow)

**Files:**
- Create: `ios/DesignSystem/Screens/KidScreen.swift`, `ios/DesignSystem/Screens/GrownupScreen.swift`, `ios/DesignSystem/Screens/Capped.swift`
- Test: `ios/DesignSystem/Tests/CappedTests.swift`

**Interfaces:**

```swift
public struct Capped<Element> {                         // 아이 화면: 넘치면 잘라서 "+N"
  public let visible: [Element]; public let overflow: Int
  public init(_ items: [Element], max: Int)
}

public struct KidScreen<Header: View, Body: View>: View {      // 스크롤 없음, 그리드 여백, 크림 바탕
  public init(@ViewBuilder header: () -> Header, @ViewBuilder body: (GridMetrics) -> Body)
}

public struct GrownupScreen<Header: View, Content: View, Action: View>: View {
  // 머리글(48–128)과 아래 주 버튼은 고정, 가운데 content만 세로 스크롤
  // 키보드가 올라오면 content 영역이 키보드 위까지로 줄고, 포커스된 칸이 보이도록 스크롤 (C3k)
  public init(@ViewBuilder header: () -> Header, @ViewBuilder content: () -> Content,
              @ViewBuilder primaryAction: () -> Action)
}
```

- `KidScreen`은 내부에서 `ScrollView`를 쓰지 않고, `body`에 넣은 내용이 넘치면 잘린다. 넘치는 개수는 `Capped`로 미리 정하는 것이 규칙이다(아침 화면 "지금 할 일 + 다음 2개", 지도 버스 3대, 영상 알약 아이당 3개).
- `GrownupScreen`의 주 버튼은 키보드가 올라오면 키보드 바로 위로 따라 올라간다(`safeAreaInset(edge: .bottom)`).

- [ ] **Step 1: 실패하는 테스트 작성** — `CappedTests`: `testUnderCapShowsAll`, `testOverCapCountsOverflow`(5개, max 3 → visible 3, overflow 2), `testZeroCap`
- [ ] **Step 2–4: 실패 확인 → 구현 → 통과 확인**
- [ ] **Step 5: 키보드 수동 확인.** Task 9의 갤러리에 `GrownupScreen` 예시(입력칸 6개)를 넣고, 시뮬레이터에서 하드웨어 키보드를 끈 상태(I/O → Keyboard → Connect Hardware Keyboard 해제)로 맨 아래 칸을 누른다. 그 칸과 주 버튼이 키보드 위에 보여야 한다.
- [ ] **Step 6: Commit**

```bash
git add ios/DesignSystem
git commit -m "feat(design): kid and grown-up screen frames with overflow rules"
```

### Task 9: 부품 갤러리, 앱 연결, 스냅샷 테스트

**Files:**
- Create: `ios/DesignSystem/Gallery/ComponentGallery.swift` (0b, 0c, 0f 예시를 보드와 같은 배치로)
- Modify: `ios/AppCore/AppFeature.swift`, `ios/AppCore/ParentHomeFeature.swift`, `ios/AppCore/ParentHomeView.swift`, `ios/AppCore/BUILD.bazel`, `Package.swift`, `MODULE.bazel`
- Test: `ios/AppCore/Tests/AppFeatureTests.swift`(추가), `ios/DesignSystem/SnapshotTests/BUILD.bazel`, `ios/DesignSystem/SnapshotTests/ComponentSnapshotTests.swift`, `ios/DesignSystem/SnapshotTests/__Snapshots__/`

**Interfaces:**
- `AppFeature.Path`에 `case gallery(GalleryFeature)`를 더한다. `GalleryFeature`는 상태가 빈 리듀서다(M0의 `StackState` 견본에 두 번째 목적지를 더하는 연습).
- `ParentHomeFeature.Action`에 `.galleryButtonTapped`를 더한다. 버튼은 `#if DEBUG`에서만 보인다.
- 스냅샷: `pointfreeco/swift-snapshot-testing`(`.upToNextMajor(from: "1.18.0")`, 실행 시점의 최신 1.x를 확인)을 `Package.swift`에 더하고 `use_repo`에 `swiftpkg_swift_snapshot_testing`을 추가한다. 스냅샷 테스트는 `testonly` 타깃으로만 의존한다.

- [ ] **Step 1: 실패하는 테스트 작성**
  - `AppFeatureTests.testGalleryButtonPushesGallery`: 부모 화면에서 `.galleryButtonTapped` → `path`에 `.gallery`가 쌓인다
  - `ComponentSnapshotTests`: 부품마다 시안 크기로 한 장씩, 그리고 `PaperCard`·`NowRow`·`SlideToGo`는 **폭 3종**(시안 폭, 0.5배, 1.5배)으로 찍는다(Review Focus 1). `SlideToGo`는 `locked`, `idle`, `dragging(0.5)`, `done` 네 상태. `TimeLeft`는 19와 −2. 테스트 시작 전에 `FontRegistrar.registerAll()`을 부르고 실패하면 `XCTFail`.
- [ ] **Step 2: 기록 모드로 한 번 실행해서 기준 이미지를 만든다** (`withSnapshotTesting(record: .all)`). 만든 이미지를 시안 보드(0b, 0c)와 나란히 열어 눈으로 비교하고, 다른 점을 고친 뒤 다시 기록한다. 기준 이미지는 커밋한다.
- [ ] **Step 3: 비교 모드로 실행 → 통과 확인**

Run: `bazel test //ios/DesignSystem/SnapshotTests:ComponentSnapshotTests //ios/AppCore/Tests:AppCoreTests --test_arg=--device_type --test_arg="iPad Pro 13-inch (M5)" --test_arg=--os_version --test_arg=26.5`
Expected: 모두 PASS

- [ ] **Step 4: 성능 확인.** 갤러리에 `TimeLeft`를 1초마다 바꾸는 예시를 두고 Instruments 없이 `os_signpost` 구간 로그로 `CrayonSurface` 재계산 횟수를 센다. 1분 동안 같은 크기의 표면이 다시 계산되지 않아야 한다(`GeometryCache.makeCount`가 늘지 않음).
- [ ] **Step 5: CI 스냅샷 기준 정하기.** CI의 첫 실행에서 런타임이 로컬과 다르면(Task 6 of M0에서 기록한 러너 런타임) 실패한 스냅샷의 이름과 차이 비율을 로그에서 확인하고, 같은 런타임의 로컬 시뮬레이터에서 `make test`로 차이 이미지를 만들어 본다. 차이가 글자 안티앨리어싱 정도면 `perceptualPrecision: 0.98`로 둔다. 그보다 크면 **CI 러너와 같은 런타임으로 기준을 다시 기록**하고, 로컬 `SIM_OS`도 그 런타임으로 맞춘다. 결정한 내용을 CLAUDE.md에 적는다.
- [ ] **Step 6: 시뮬레이터 확인**

Run: `make run`
Expected: 부모 화면 → Design gallery → 0b, 0c, 0f 예시가 시안과 같은 배치로 보이고, `SlideToGo`를 끝까지 밀면 초록으로 바뀐다. 손잡이를 중간에서 놓으면 돌아간다.

- [ ] **Step 7: Commit**

```bash
git add ios Package.swift Package.resolved MODULE.bazel MODULE.bazel.lock
git commit -m "feat(design): component gallery in debug parent mode and snapshot tests"
```

### Task 10: CI와 문서

**Files:**
- Modify: `.github/workflows/ios-ci.yml`, `.gitignore`, `CLAUDE.md`, `docs/superpowers/plans/2026-11-07-m1-crayon-design-system.md`(이 계획서, 저장소에 추가)

- [ ] **Step 1: 스냅샷 실패를 로그로만 남긴다.** CI는 아티팩트를 보관하지 않고 로그도 최소로 둔다(사용자 결정). 스냅샷 테스트가 실패하면 실패한 스냅샷 이름과 차이 비율(%)만 한 줄씩 출력하게 한다. 차이 이미지는 로컬에서 `make test`를 돌릴 때만 git에서 제외된 폴더(`ios/DesignSystem/SnapshotTests/__Diffs__/`, `.gitignore`에 추가)에 만든다. 워크플로에 이 이유를 주석으로 단다.
- [ ] **Step 2: `paths` 필터에 `tools/crayon-art/**`를 더한다.**
- [ ] **Step 3: CLAUDE.md에 디자인 시스템 규칙을 적는다.**
  - 화면은 `DesignSystem`의 토큰·부품·화면 틀만 쓴다. 부품 파일 밖에서 색 hex, 글자 크기 숫자, `ScrollView`(아이 화면)를 쓰지 않는다.
  - 새 부품이 필요하면 먼저 갤러리와 스냅샷에 추가한다(시안의 "새 부품은 여기에 먼저 그린다" 규칙).
  - 크레용 도형의 시드는 부품마다 고정한다.
  - 그림은 `KitIcon(slot)`으로만 쓴다(M6에서 아이가 그린 그림으로 바뀔 수 있게).
  - 공개 그림은 `make art`로만 만든다. 생성된 SVG를 손으로 고치지 않는다.
  - 학교 마스코트와 집 그림은 `ios/KitArt/Private/`(git 제외). 예시 이름은 `Kid A`, `Kid B`.
- [ ] **Step 4: 개인정보 검사**

Run: `scripts/check-private-terms.sh $(git ls-files) docs/superpowers/plans/2026-11-07-m1-crayon-design-system.md CLAUDE.md`
Expected: 종료 코드 0

- [ ] **Step 5: Commit과 push, CI 확인**

```bash
git add .github .gitignore CLAUDE.md docs/superpowers/plans
git commit -m "ci: log snapshot failures only; document design-system rules"
git push
```

Run: `gh run watch`
Expected: `iOS CI`, `Secret scan` 모두 성공

---

## 끝났다고 보는 기준 (M1)

- `make test` 초록, CI 초록, 스냅샷이 CI에서 비교된다.
- 부모 화면의 Design gallery에서 0b(조작 12종), 0c(내용 10종), 0f(화면 틀 2종)가 시안과 같은 크기와 상태로 보인다.
- 같은 부품을 폭 3종으로 그려도 선 굵기와 빗금 간격이 같다.
- 공개 저장소에 학교 마스코트 그림, 집 그림, 아이 이름, 학교 이름이 없다.

## 다음 (M2로 넘길 것)

- 파이 시계(`CrayonKit`으로 그날의 칸을 그리는 `PieClock`)는 일정 모델이 필요하므로 M2 첫 작업으로 한다. M1에서는 갤러리에 고정 데이터 예시만 둘 수 있다.
- 크레용 지도 띠(`BusMapStrip`)는 M3 첫 작업.
