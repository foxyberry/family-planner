# M2 하루 일정과 홈 시계 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 부모가 시계를 2초 누르고 Face ID로 잠금을 풀어 "매주 월·수 15:30 수영"을 넣으면, 홈의 크레용 파이 시계에 그 칸이 생기고 바늘이 실시간으로 움직인다. 일정마다 학교 휴일 건너뛰기를 켜고 끌 수 있고, 한 번만 건너뛰기·삭제·수정이 된다.

**Architecture:**
- `Domain`(Foundation만): 아이·루틴·일정 모델, "그날의 칸 목록"을 만드는 `DayPlanner`, 반복 일정 편집 규칙, 화면 문구 형식(`TimeText`, `DayText`). 날짜는 시간대 문제를 피하려고 `Day`(연·월·일)와 자정부터의 분으로 다룬다.
- `Clients/ScheduleStore`·`HolidayProvider` 인터페이스와 `*Live` 구현. `ParentAuthClient`는 성공/실패 대신 상태(결과 enum)를 돌려주도록 바꾼다.
- `DesignSystem`에 M2 부품 다섯 개(`ClockSlot` 색, `PieClock`, `KidNowNext`, `ConfirmCard`, `LockOverlay`)를 더한다.
- `Features/Home`(A1, E1, E3, C0 진입), `Features/Grownup`(C1/E6 허브, C3/C4/C3k/E5 편집기): TCA 리듀서. `AppCore`는 홈을 첫 화면으로 두고, 잠금·2분 뒤 다시 잠김·화면 이동을 맡는다.
- 아이는 M4까지 **가짜 시드 두 명**(Kid A 학교 다님, Kid B 집에 있음)이다. 아이 추가는 M4(S1).

**Tech Stack:** Swift 6, TCA 1.26(`@Presents`, `StackState`, `\.date`, `\.calendar`, `\.continuousClock`, `\.openURL`), SwiftUI `Canvas`·`ViewThatFits`·`LongPressGesture`, SwiftData(안 되면 JSON 파일, Task 2), LocalAuthentication, XCTest, swift-snapshot-testing(로컬 전용).

**Spec:** 화면 명세 `docs/superpowers/specs/2026-11-07-m2-screens-spec.md`(디자인 세션이 시안 보드에서 정리, 공개 가능). 범위와 데이터 모델은 로드맵 `docs/private/2026-11-07-roadmap-after-hifi.md` M2와 설계 문서 F1·F4·F5·F6(둘 다 git 제외라 개인 정보는 옮기지 않는다). 명세의 [later Mx] 항목은 M2에서 **숨긴다**(비활성으로 보이지 않는다).

## Global Constraints

- M0·M1의 Global Constraints와 CLAUDE.md 규칙을 따른다: Swift 6, `fp_swift_library`, 개인정보, 8GB 맥(테스트는 한 번에 하나), 아이 화면 스크롤 금지(`check-kid-screens.sh`), 화면은 `DesignSystem` 토큰과 부품만, 화살표·체크 문자를 글자로 쓰지 않기(`→`, `‹ ›` 같은 화살표는 `RoundButton(systemImage:)`나 KitArt로).
- 글자 크기는 6단계(144/96/48/36/30/24)만 쓴다. 허브: NOW caption 24, 제목 title 48(260pt보다 넓으면 head 36, 그래도 넓으면 "…"), until body 30(명세 반영, 디자인 확정).
- 새 모듈: `ios/Domain`, `ios/Clients/ScheduleStore(Live)`, `ios/Clients/HolidayProvider(Live)`, `ios/Features/Home`, `ios/Features/Grownup`. 테스트는 각 모듈 `Tests/`(`ios_unit_test`, `runner = "//ios:test_runner"`).
- 의존 방향: `Domain` → Foundation만(SwiftUI·TCA·KitArt 금지, 그림은 `KitSlot` 원시값 문자열 `iconName`). `Features/*` → `Domain`, `DesignSystem`, `KitArt`, `CrayonKit`, `Clients/*` 인터페이스. `*Live`는 `//ios:__pkg__`에만 보인다.
- 시간은 `@Dependency(\.date)`, `\.calendar`, `\.continuousClock`으로만 얻는다. 테스트 기준: `Calendar(identifier: .gregorian)`, `TimeZone(identifier: "Asia/Singapore")`, 2026-11-09(월) 기준.
- 하루는 0–1440분. 자정을 넘는 칸은 데이터에서 두 칸(0:00–7:00, 20:30–24:00)이고, 시계가 같은 종류의 맞닿은 칸을 경계선 없이 한 부채꼴로 그린다. "지금 칸" 표시(6pt 테두리)와 허브의 "until"도 합친 칸을 쓴다(23:00에 "until 7:00").
- 시계의 하루는 **자정에 바뀐다**. 한 번 일정은 그날 시계에만 보이고 자정에 사라진다. C1/E6 "Just once" 목록에서는 아이의 다음 기상 시각까지 남는다.
- 부모 잠금은 **Face ID만**(`.deviceOwnerAuthenticationWithBiometrics`, `localizedFallbackTitle = ""`). 기기 암호로 여는 길은 없다.
- 시드·테스트 이름은 `Kid A`, `Kid B`, 학교는 `Example Primary School`. 실제 학교, 정류장, 집, 시간표를 넣지 않는다.
- 문구는 명세의 영어 원문 그대로 쓴다. `String(localized:)`로 감싸 String Catalog에 모은다(한국어는 나중).
- 공휴일 데이터는 공개 자료(싱가포르 MOM 공휴일 목록)만. M2의 "Skip school holidays"는 이 공휴일 목록에 적용한다(학교 휴일 가져오기는 나중).

## Review Focus

1. **앱을 켜 둔 채 자정이 지나는 경우**: 0:00에 시계가 새 날의 칸, 요일, 주말/공휴일 여부로 바뀌어야 한다. → Task 6 `testMidnightTickReloadsTheNewDay`.
2. **편집 중에 2분이 지나거나 앱이 백그라운드로 가는 경우**: 저장하지 않은 입력을 버리고 홈으로 가며, 다음 진입은 Face ID가 필요하다. 30초 전부터 "Locks in 0:30" 카운트다운. → Task 7 `testIdleTwoMinutesRelocksAndDropsUnsavedForm`, `testBackgroundRelocks`, `testCountdownCaptionInLast30Seconds`.
3. **짧고 겹치는 칸**: 10분 미만 칸, 맞닿은 짧은 칸, 우선순위가 다른 겹침에서도 부채꼴이 겹치거나 사라지지 않는다. → Task 1 우선순위 테스트, Task 5 `testShortSlotsGetMinimumWidthAndPushApart`.
4. **저장 실패**: 저장소 오류가 나도 입력이 남고 "Couldn't save. Try again."이 보이며, 다시 누르면 저장된다. → Task 9 `testSaveFailureKeepsFormAndShowsCaption`.
5. **긴 이름과 Face ID가 없는 기기(시뮬레이터 기본)**: 긴 일정 이름은 허브에서 줄어들고 말줄임되며 줄바꿈하지 않는다. Face ID가 꺼져 있으면 안내 문구와 "Open Settings"가 나온다. → Task 5 스냅샷 `testHubLongTitle`, Task 7 `testFaceIDOffShowsSettingsMessage`.

---

### Task 1: Domain 모델, 그날의 칸, 반복 일정 편집, 문구 형식

**Files:**
- Create: `ios/Domain/{BUILD.bazel,Day.swift,Models.swift,DayPlanner.swift,SeriesEdits.swift,Formatting.swift,SeedData.swift}`
- Test: `ios/Domain/Tests/{BUILD.bazel,DayTests.swift,DayPlannerTests.swift,SeriesEditsTests.swift,FormattingTests.swift}`

**Interfaces:**
- Produces:
  - `struct Day: Hashable, Comparable, Codable, Sendable { year, month, day: Int; init(_ date: Date, calendar: Calendar); func weekday(_ calendar: Calendar) -> Weekday; func adding(days: Int, calendar: Calendar) -> Day; func date(minute: Int, calendar: Calendar) -> Date }`
  - `enum Weekday: Int, CaseIterable, Codable, Sendable { case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday }`(Calendar 번호와 같음), `static let schoolDays: Set<Weekday>`(월–금)
  - `struct School: Hashable, Codable, Sendable { name: String; days: Set<Weekday>; start: Int; end: Int }`
  - `struct Kid: Identifiable, Hashable, Codable, Sendable { id: UUID; name: String; colorIndex: Int; age: Int; schoolYear: String?; school: School? }`
  - `enum Audience: Hashable, Codable, Sendable { case kid(Kid.ID), both }`
  - `enum Recurrence: Hashable, Codable, Sendable { case once(Day); case weekly(Set<Weekday>, from: Day, until: Day?) }`
  - `enum SlotKind: String, Codable, Sendable { case sleep, morning, school, afterSchool, play, dinner, evening, event }`
  - `struct ScheduleItem: Identifiable, Hashable, Codable, Sendable { id: UUID; title: String; iconName: String; audience: Audience; start: Int; end: Int; recurrence: Recurrence; skippedDays: Set<Day>; skipsHolidays: Bool; showsStar: Bool; var kind: SlotKind }`(`kind`: weekly → `.afterSchool`, once → `.event`)
  - `enum DayKind: Hashable, Codable, Sendable { case schoolDay, dayOff }`
  - `struct RoutineBlock: Hashable, Codable, Sendable { title: String; iconName: String; kind: SlotKind; start: Int; end: Int }`, `struct Routine: Hashable, Codable, Sendable { kid: Kid.ID; dayKind: DayKind; blocks: [RoutineBlock] }`
  - `struct Slot: Hashable, Sendable { title: String; iconName: String; kind: SlotKind; start: Int; end: Int; source: Source; showsStar: Bool; enum Source: Hashable, Sendable { case routine, weekly(ScheduleItem.ID), once(ScheduleItem.ID) } }`
  - `enum DayPlanner`:
    - `static func dayKind(on: Day, kid: Kid, holidays: Set<Day>, calendar: Calendar) -> DayKind`(학교 요일이고 공휴일이 아니면 `.schoolDay`. 학교가 없는 아이는 주중 `.schoolDay` 루틴을, 주말·공휴일 `.dayOff` 루틴을 쓴다)
    - `static func slots(on: Day, kid: Kid, routines: [Routine], items: [ScheduleItem], holidays: Set<Day>, calendar: Calendar) -> [Slot]`
    - `static func now(at minute: Int, in slots: [Slot]) -> (current: Slot?, next: Slot?)`
    - `static func occurs(_ item: ScheduleItem, on: Day, kid: Kid.ID, holidays: Set<Day>, calendar: Calendar) -> Bool`
  - `enum SeriesEdits`(반복 일정 편집, 모두 순수 함수):
    - `static func nextOccurrence(of: ScheduleItem, from: Day, nowMinute: Int, holidays: Set<Day>, calendar: Calendar) -> Day?`(오늘 일정이 아직 안 끝났으면 오늘, 건너뛴 날은 넘김, 최대 1년 앞까지)
    - `static func skipping(_: ScheduleItem, day: Day) -> ScheduleItem`, `unskipping(_:day:)`
    - `static func ending(_: ScheduleItem, before day: Day, calendar: Calendar) -> ScheduleItem`(`until = day − 1`)
    - `static func applying(edit: ScheduleItem, to original: ScheduleItem, today: Day, nowMinute: Int, holidays: Set<Day>, calendar: Calendar) -> [ScheduleItem]`(원본이 오늘 있고 이미 시작했거나 끝났으면(`nowMinute >= start`) `[원본(until 오늘), 새 id의 edit(from 내일, 오늘 이후의 건너뛴 날을 넘겨받음)]`, 아니면 `[edit]`)
  - `enum TimeText { static func clock(_ minute: Int) -> String /* "3:30" */; static func withPeriod(_: Int) -> String /* "3:30 pm" */; static func duration(_ minutes: Int) -> String /* "1 hour", "1 hr 30 min", "45 min" */ }`
  - `enum DayText { static func short(_: Day, calendar:) -> String /* "Sat 14 Nov" */; static func long(_:calendar:) -> String /* "Saturday 14 Nov" */; static func chips(_: Set<Weekday>) -> String /* "Mon · Wed", "Every school day" */; static func sentence(_: Set<Weekday>) -> String /* "Monday", "Monday and Wednesday", "Monday, Wednesday and Friday", "school day" */ }`(영어 고정, `en_US_POSIX`)
  - `enum SeedData { static let kidA: Kid; static let kidB: Kid; static var kids: [Kid]; static var routines: [Routine]; static func items(today: Day, calendar: Calendar) -> [ScheduleItem] }`(명세 "Seed data", 나이는 가짜 값 Kid A 8세·Year 3, Kid B 4세: Kid A 학교 월–금 + 매주 두 개 + 한 번 하나, Kid B 낮잠·잠 + 같은 한 번 일정 `.both`. UUID는 고정 문자열)

- [ ] **Step 1: 실패하는 테스트** (`DayPlannerTests`)
  - `testWeekdayIsSchoolDayAndWeekendIsDayOff`(월 → `.schoolDay`, 2026-11-14 토 → `.dayOff`)
  - `testPublicHolidayIsDayOff`
  - `testWeeklyItemOnItsWeekdaysOnly`(월·수 15:30–16:30 "Swimming": 월요일 있음, 화요일 없음)
  - `testWeeklyItemRespectsFromAndUntil`(until 당일 포함)
  - `testOnceItemOnItsDayOnly`
  - `testSkippedDayHidesItem`
  - `testHolidaySkipCanBeTurnedOff`(공휴일에 `skipsHolidays` true → 없음, false → 있음)
  - `testAudienceFilters`(`.kid(B)` 일정은 A에 없음, `.both`는 둘 다)
  - `testPriorityOnceOverWeeklyOverRoutine`(루틴 15:00–17:00 "Play", 매주 15:30–16:30, 한 번 16:00–18:00 → Play 15:00–15:30, 매주 15:30–16:00, 한 번 16:00–18:00, 루틴 나머지 없음)
  - `testSamePriorityLaterStartCutsEarlier`(매주 15:00–16:00과 15:30–17:00 → 앞의 것 15:30에 끝)
  - `testSlotsSortedNeverOverlapNoZeroLength`(여러 조합)
  - `testNowAndNext`(15:45 → current/next, 빈 시간 → current nil, 마지막 뒤 → 둘 다 nil)
  - `DayTests.testDayFromDateUsesCalendarTimeZone`(싱가포르 2026-11-09 00:30 → `Day(2026,11,9)`)
  - `SeriesEditsTests`: `testNextOccurrenceTodayIfNotEnded`, `testNextOccurrenceSkipsSkippedDays`, `testEndingKeepsPastDays`(오늘 이전 날 `occurs` 그대로), `testApplyingEditSplitsWhenRunningToday`, `testApplyingEditSplitsWhenAlreadyFinishedToday`, `testApplyingEditMovesFutureSkipsToNewSeries`, `testApplyingEditInPlaceWhenNotStarted`
  - `FormattingTests`: 위 Interfaces 주석의 예시 값 그대로, 그리고 `duration(60) == "1 hour"`, `duration(90) == "1 hr 30 min"`, `withPeriod(0) == "12:00 am"`, `withPeriod(720) == "12:00 pm"`, `sentence(schoolDays) == "school day"`, `chips(schoolDays) == "Every school day"`
- [ ] **Step 2:** `make test-one TARGET=//ios/Domain/Tests:DomainTests` → 빌드 실패
- [ ] **Step 3: 구현.** 칸 만들기: 그날 `DayKind` 루틴 블록 → 해당 일정 → 우선순위 높은 순서로 칸을 놓고, 낮은 칸은 높은 칸 둘레로 잘라 낸다(같은 순위는 늦게 시작한 쪽이 앞을 자른다) → 길이 0 칸 버림 → 시작순 정렬.
- [ ] **Step 4:** 같은 명령 → PASS
- [ ] **Step 5: Commit** `feat(domain): day schedule model, planner, series edits and copy formats`

### Task 2: 일정 저장소 (ScheduleStore)

**Files:**
- Create: `ios/Clients/ScheduleStore/{BUILD.bazel,ScheduleStore.swift}`, `ios/Clients/ScheduleStoreLive/{BUILD.bazel,ScheduleStoreLive.swift}`, `ios/Clients/ScheduleStoreLive/Tests/{BUILD.bazel,ScheduleStoreLiveTests.swift}`
- Modify: `ios/App/FamilyPlannerApp.swift`(bootstrap에서 Live 주입), `ios/BUILD.bazel`

**Interfaces:**
- Consumes: Task 1 모델, `SeedData`
- Produces: `@DependencyClient struct ScheduleStore: Sendable { var load: @Sendable () async throws -> ScheduleSnapshot; var save: @Sendable (ScheduleItem) async throws -> Void; var saveAll: @Sendable ([ScheduleItem]) async throws -> Void; var delete: @Sendable (ScheduleItem.ID) async throws -> Void }`, `struct ScheduleSnapshot: Equatable, Sendable { kids: [Kid]; routines: [Routine]; items: [ScheduleItem] }`, `DependencyValues.scheduleStore`. `testValue`는 미구현(호출 시 실패), `previewValue`는 시드 메모리 저장소. `ScheduleStore.live(directory: URL)`.

- [ ] **Step 1: 실패하는 테스트**(임시 폴더): `testFirstLoadSeeds`, `testSaveThenLoadInNewStoreKeepsItem`(앱 재시작), `testSaveSameIDReplaces`, `testSaveAllIsOneWrite`(분할 편집 두 개가 함께 저장), `testDeleteRemoves`, `testCorruptFileThrowsAndKeepsFile`
- [ ] **Step 2:** `make test-one TARGET=//ios/Clients/ScheduleStoreLive/Tests:ScheduleStoreLiveTests` → 실패
- [ ] **Step 3: 구현.** 먼저 SwiftData `@Model` 하나가 Bazel에서 컴파일되고 메모리 컨테이너로 도는지 30분 안에 확인한다. 되면 SwiftData, 안 되면 Application Support의 `schedule.json` 하나(원자적 쓰기, `version: 1`). 결정은 ledger Ruling으로 남긴다.
- [ ] **Step 4:** 같은 명령 PASS, `make build` 성공
- [ ] **Step 5: Commit** `feat(clients): on-device schedule store with seed data`

### Task 3: 싱가포르 공휴일 (HolidayProvider)

**Files:**
- Create: `ios/Clients/HolidayProvider/{BUILD.bazel,HolidayProvider.swift}`, `ios/Clients/HolidayProviderLive/{BUILD.bazel,HolidayProviderLive.swift,ResourceBundle-Info.plist,Resources/sg-public-holidays.json,Resources/SOURCE.md}`, `ios/Clients/HolidayProviderLive/Tests/…`

**Interfaces:**
- Produces: `@DependencyClient struct HolidayProvider: Sendable { var holidays: @Sendable (_ year: Int) async -> [Holiday] }`, `struct Holiday: Hashable, Codable, Sendable { day: Day; name: String }`, `DependencyValues.holidays`. Live는 리소스 번들 JSON(Info.plist에 `CFBundleIdentifier`, bazel-ios 스킬).

- [ ] **Step 1: 실패하는 테스트**: `testBundledYearsHaveHolidays`(2026, 2027 각 10개 이상), `testNationalDay2026AndObservedMonday`(2026-08-09, 2026-08-10), `testChristmas2026`, `testUnknownYearIsEmpty`(2030)
- [ ] **Step 2:** `make test-one TARGET=//ios/Clients/HolidayProviderLive/Tests:HolidayProviderLiveTests` → 실패
- [ ] **Step 3:** MOM 목록의 2026·2027년 날짜를 `[{"date":"2026-01-01","name":"New Year's Day"}, …]`로 옮긴다(일요일 공휴일의 대체 휴일 포함). 출처 URL과 확인 날짜는 `SOURCE.md`.
- [ ] **Step 4:** PASS
- [ ] **Step 5: Commit** `feat(clients): bundled Singapore public holidays`

### Task 4: Face ID 결과 상태 (ParentAuthClient)

**Files:**
- Modify: `ios/Clients/ParentAuthClient/ParentAuthClient.swift`, `ios/Clients/ParentAuthClientLive/ParentAuthClientLive.swift`, `ios/AppCore/AppFeature.swift`(호출부 컴파일만 맞춤)
- Test: `ios/Clients/ParentAuthClientLive/Tests/ParentAuthOutcomeTests.swift`, `ios/AppCore/Tests/AppFeatureTests.swift`(기존 테스트 갱신)

**Interfaces:**
- Produces: `enum ParentAuthOutcome: Equatable, Sendable { case success, notRecognised, cancelled, notAvailable, lockedOut }`, `enum Biometry: Equatable, Sendable { case faceID, touchID, none }`, `ParentAuthClient { var authenticate: @Sendable (_ reason: String) async -> ParentAuthOutcome; var biometry: @Sendable () -> Biometry }`. Live: `static func outcome(for error: LAError.Code?) -> ParentAuthOutcome`(순수, 테스트 대상).

- [ ] **Step 1: 실패하는 테스트** `testOutcomeMapping`: `nil` → success, `.authenticationFailed` → notRecognised, `.userCancel`/`.systemCancel`/`.appCancel` → cancelled, `.biometryNotEnrolled`/`.biometryNotAvailable` → notAvailable, `.biometryLockout` → lockedOut
- [ ] **Step 2:** `make test-one TARGET=//ios/Clients/ParentAuthClientLive/Tests:ParentAuthClientLiveTests` → 실패
- [ ] **Step 3:** Live에 `context.localizedFallbackTitle = ""`, 정책은 그대로 `.deviceOwnerAuthenticationWithBiometrics`. `AppFeature`는 `.success`일 때만 기존처럼 부모 화면을 연다(나머지 상태 화면은 Task 7).
- [ ] **Step 4:** 위 명령과 `make test-one TARGET=//ios/AppCore/Tests:AppCoreTests` PASS
- [ ] **Step 5: Commit** `feat(auth): Face ID outcomes instead of a yes/no answer`

### Task 5: M2 디자인 부품 (ClockSlot, PieClock, KidNowNext, ConfirmCard, LockOverlay)

**Files:**
- Create: `ios/DesignSystem/Tokens/ClockSlot.swift`, `ios/DesignSystem/Clock/{PieClock.swift,PieClockLayout.swift}`, `ios/DesignSystem/Content/{KidNowNext.swift,ConfirmCard.swift}`, `ios/DesignSystem/Screens/LockOverlay.swift`
- Modify: `ios/DesignSystem/Tokens/CrayonPalette.swift`(mint #7FD6B5, orange #F7A84B, green #A8DB7A, coral #F9A88A, lilac #B9A3F0, pink #F7A8CF, handRed #E5484D, 그리고 명세에 이름만 나오는 `hurry`, `onTimeText`, `nightText`가 없으면 시안 값으로 추가), `ios/DesignSystem/Gallery/ComponentGallery.swift`(새 부품 예시)
- Test: `ios/DesignSystem/Tests/PieClockLayoutTests.swift`, `ios/DesignSystem/SnapshotTests/ComponentSnapshotTests.swift`(새 부품)

**Interfaces:**
- Consumes: CrayonKit `CrayonFill`, `CrayonSurface`, KitArt `KitIcon`. `DesignSystem`은 `Domain`에 의존하지 않는다: 칸은 자체 입력 타입으로 받는다.
- Produces:
  - `enum ClockSlotStyle: CaseIterable, Sendable { case sleep, morning, school, afterSchool, play, dinner, evening, event; var fill: CrayonFill }`(명세 A1 표의 색과 빗금 각도)
  - `struct ClockSector: Hashable, Sendable { start: Int; end: Int; style: ClockSlotStyle; iconName: String?; isCurrent: Bool; showsStar: Bool }`
  - `enum PieClockLayout { static func angle(minute: Int) -> Angle /* 0시 위, 시계 방향, 시간당 15° */; static func drawable(_ sectors: [ClockSector]) -> [ClockSector] /* 자정 넘는 같은 style 병합, 10분 최소 폭, 짧은 칸 밀어내기 최대 5분, 그래도 겹치면 낮은 우선순위 버림 */; static func pictureSize(minutes: Int) -> CGFloat? /* ≥180 → 104, 60–179 → 84, 30–59 → 68, <30 → nil */ }`
  - `struct PieClock: View { init(sectors: [ClockSector], now: Int, hub: Hub, holdProgress: Double); struct Hub: Equatable { var title: String?; var subtitle: String? } }`(R 372, 허브 r 152, 바늘·눈금·라벨·해·달은 명세 A1, 접근성 라벨은 호출자가 붙인다)
  - `struct KidNowNext: View { init(now: String /*iconName*/, next: String?) }`
  - `struct ConfirmCard: View { init(title: String, body: String?, cancel: String, confirm: String, isDestructive: Bool, onCancel:, onConfirm:) }`
  - `struct LockOverlay: View { init(state: State, onPrimary:, onCancel:); enum State: Equatable { case scanning, notRecognised, notAvailable(touchID: Bool), lockedOut } }`(문구와 버튼은 명세 C0 표 그대로)

- [ ] **Step 1: 실패하는 테스트** `PieClockLayoutTests`:
  - `testAngles`(0 → 0°, 360 → 90°, 720 → 180°, 1080 → 270°)
  - `testMidnightSleepMerges`(sleep 0–420 + sleep 1230–1440 → 하나, start 1230, end 420 다음날)
  - `testShortSlotsGetMinimumWidthAndPushApart`(5분 칸 두 개가 맞닿으면 각 10분 폭, 순서 유지, 겹침 없음)
  - `testPictureSizeByLength`
- [ ] **Step 2:** `make test-one TARGET=//ios/DesignSystem/Tests:DesignSystemTests` → 실패
- [ ] **Step 3: 구현.** 부채꼴은 `CrayonSurface`와 같은 채우기(wash + flicks)를 부채꼴 경로에 적용한다. 필요하면 `CrayonShapeKind`에 `.sector(start: Angle, end: Angle, inner: CGFloat)`를 더한다. 허브 제목은 `ViewThatFits`로 title 48 → head 36 → 말줄임(줄바꿈 금지). 바늘 반경: 선 154–312, 원 r 24 at 336.
- [ ] **Step 4:** 테스트 PASS. 스냅샷 추가 후 `make snapshots-record`, PNG를 열어 시안 A1·C0과 비교: `testPieClockSeedDay`, `testPieClockEmpty`, `testHubLongTitle`, `testKidNowNext`, `testConfirmCard`, `testLockOverlayStates`(4상태). `make test-one TARGET=//ios/DesignSystem/SnapshotTests:ComponentSnapshotTests` PASS
- [ ] **Step 5: Commit** `feat(design): pie clock and M2 parts`

### Task 6: 홈 화면 (A1, E1, E3)

**Files:**
- Create: `ios/Features/Home/{BUILD.bazel,HomeFeature.swift,HomeView.swift,HomeModel.swift}`, `ios/Features/Home/Tests/…`
- Modify: `ios/AppCore/AppFeature.swift`, `ios/AppCore/AppView.swift`(첫 화면 = 홈, 시계 문구와 "Parent" 버튼 삭제), `ios/AppCore/BUILD.bazel`

**Interfaces:**
- Consumes: Task 1–3, Task 5 `PieClock`·`KidNowNext`
- Produces: `@Reducer struct HomeFeature { State { snapshot: ScheduleSnapshot?; holidays: Set<Day>; today: Day?; minute: Int; var layout: HomeLayout /* .twoKids, .oneKid, .dayOff */ }; Action { case task; case loaded(Result<ScheduleSnapshot, Error>, holidays: [Holiday]); case tick(Date); case reload; case clockHoldCompleted /* Task 7이 받음 */ } }`. `HomeModel`(순수): `static func sectors(for: [Slot], minute: Int) -> [ClockSector]`, `static func hub(_ now: (Slot?, Slot?), minute:) -> PieClock.Hub`(명세 NOW 규칙, 자정을 넘는 잠은 합친 칸의 끝으로 "until"), `static func nextRows(_ slots: [Slot], minute:, max: 2)`, `static func accessibilityLabel(kidName:, minute:, current:) -> String`.

- [ ] **Step 1: 실패하는 테스트**
  - `HomeModelTests`: `testHubShowsCurrentSlot`("NOW"/"Swimming"/"until 4:30"), `testHubSleepBeforeMidnightSaysUntilWakeUp`(23:00 → "until 7:00"), `testHubGapSaysFreeTimeUntilNext`, `testHubFreeTimeWithoutSecondLineWhenNothingLater`, `testHubNothingPlanned`, `testAccessibilityLabel`("Kid A's day as a 24-hour clock. Midnight at the top, noon at the bottom. Now 3:45, Swimming.")
  - `HomeFeatureTests`(TestStore, 고정 날짜): `testLoadsTwoKidsLayout`, `testOneKidLayout`, `testWeekendIsDayOffLayout`, `testHolidayIsDayOffLayout`, `testMidnightTickReloadsTheNewDay`(23:59 → 0:00 tick에서 `today`가 바뀌고 칸이 새 날 것), `testMinuteTickMovesNowWithoutReload`
- [ ] **Step 2:** `make test-one TARGET=//ios/Features/Home/Tests:HomeTests` → 실패
- [ ] **Step 3: 구현.** 레이아웃은 명세 A1/E1/E3. M3 "Leave in" 자리에는 E1의 Next 목록, "Missions →"·"Diary →"는 숨김. 시계 영역은 그리드 밖(원 중심 448, 528). 화면은 `KidScreen`(빈 헤더). 저장 실패 시 "Nothing planned" 시계(아이 화면에 오류 문구 없음).
- [ ] **Step 4:** 테스트 PASS, `make build`, `bash scripts/check-kid-screens.sh`
- [ ] **Step 5: Commit** `feat(home): pie clock home for one or two kids and days off`

### Task 7: 부모 잠금 (C0)과 2분 뒤 다시 잠김

**Files:**
- Modify: `ios/AppCore/AppFeature.swift`, `ios/AppCore/AppView.swift`, `ios/Features/Home/HomeView.swift`(2초 누르기), `ios/DesignSystem/Screens/GrownupScreen.swift`(헤더 캡션을 바꿀 수 있게 `caption: String` 인자가 없으면 추가)
- Test: `ios/AppCore/Tests/ParentLockTests.swift`

**Interfaces:**
- Consumes: Task 4 `ParentAuthOutcome`, Task 5 `LockOverlay`, Task 6 `.clockHoldCompleted`
- Produces: `AppFeature.State { @Presents var lock: LockOverlay.State?; var lastGrownupTouch: Date?; var relockCaption: String? }`, `Action { case grownupTouched; case lockPrimaryTapped; case lockCancelTapped; case authResult(ParentAuthOutcome) }`. 부모 화면 경로가 비어 있지 않을 때만 2분 타이머가 의미가 있다.

- [ ] **Step 1: 실패하는 테스트**(TestStore, `\.date`·`\.continuousClock` 고정)
  - `testHoldOpensScanningAndSuccessPushesHub`
  - `testNotRecognisedShowsTryAgain`(Try again → 다시 scanning)
  - `testCancelClosesOverlay`
  - `testFaceIDOffShowsSettingsMessage`(Open Settings → `\.openURL`에 `UIApplication.openSettingsURLString`)
  - `testLockedOutShowsOK`
  - `testCountdownCaptionInLast30Seconds`(90초 무입력 → "Locks in 0:30", 100초 → "Locks in 0:20", 터치하면 nil)
  - `testIdleTwoMinutesRelocksAndDropsUnsavedForm`(편집기 경로가 있어도 120초에 경로 전체 제거, 저장 호출 없음)
  - `testBackgroundRelocks`(`scenePhaseChanged(.background)` → 경로 제거)
- [ ] **Step 2:** `make test-one TARGET=//ios/AppCore/Tests:AppCoreTests` → 실패
- [ ] **Step 3: 구현.** 누르기: 시계 원판에만 `LongPressGesture(minimumDuration: 2)`, 진행 링(r 160, 8 pt)은 `PieClock(holdProgress:)`, 시작에 가벼운 햅틱, 2초에 성공 햅틱, 놓으면 0.2초에 링이 사라짐. 부모 화면 전체에 `simultaneousGesture`로 `.grownupTouched`. 카운트다운 문구는 `hurry` 색으로 헤더 캡션 자리에.
- [ ] **Step 4:** 테스트 PASS
- [ ] **Step 5: Commit** `feat(lock): hold-to-unlock with Face ID states and idle relock`

### Task 8: 부모 허브 (C1 Kid A, E6 Kid B)

**Files:**
- Create: `ios/Features/Grownup/{BUILD.bazel,GrownupHubFeature.swift,GrownupHubView.swift,HubModel.swift}`, `ios/Features/Grownup/Tests/…`
- Modify: `ios/AppCore/AppFeature.swift`(`Path.parentHome` → `Path.hub(GrownupHubFeature)`, 디버그 갤러리 버튼은 허브로 옮김), `ParentHomeFeature/View` 삭제

**Interfaces:**
- Consumes: Task 1·2, M1 부품
- Produces: `@Reducer struct GrownupHubFeature { State { selectedKid: Kid.ID; snapshot: ScheduleSnapshot? }; Action { case task; case kidTabTapped(Kid.ID); case weeklyItemTapped(ScheduleItem.ID); case onceItemTapped(ScheduleItem.ID); case addWeeklyTapped; case addOnceTapped; case backTapped; case galleryButtonTapped } }`(앞의 다섯 이동은 `AppFeature`가 받아 경로에 편집기를 넣는다). `HubModel.aboutRows(kid:routines:) -> [(key: String, value: String)]`, `weeklyRows(...)`(요일 문구 `DayText.chips`, `until == nil`인 시리즈만: 그만한 시리즈와 수정으로 끝난 옛 시리즈는 목록에서 빠지고 지난 날에만 남는다), `onceRows(today:nowMinute:...)`(가까운 순, 최대 5, 다음 기상까지 남김).

- [ ] **Step 1: 실패하는 테스트**: `testAboutRowsForSchoolKid`("Age" → "8 · Year 3", "Day" → "Up 7:00 · Bed 8:30"), `testAboutRowsForHomeKid`("4 · at home", "Nap 1:00–2:30 · Bed 7:30"), `testWeeklyRowsText`("Mon · Wed 3:30–4:30", 월–금은 "Every school day"), `testEndedSeriesNotListed`, `testOnceRowsNearestFirstMaxFiveUntilNextWakeUp`, `testEmptyListsSayNothingYet`, `testTabSwitchKeepsData`
- [ ] **Step 2:** `make test-one TARGET=//ios/Features/Grownup/Tests:GrownupTests` → 실패
- [ ] **Step 3: 구현.** 명세 C1/E6 레이아웃. "Getting there", "Cards", "Add when they start", "Holidays ›", "Day ›"는 숨김/화살표 없음. 왼쪽 카드만 스크롤(헤더·탭 고정).
- [ ] **Step 4:** PASS
- [ ] **Step 5: Commit** `feat(grownup): our kids hub with weekly and just-once lists`

### Task 9: 일정 추가와 한 번 일정 수정 (C3, C4, C3k)

**Files:**
- Create: `ios/Features/Grownup/{ItemEditorFeature.swift,ItemEditorView.swift,ItemForm.swift}`
- Modify: `ios/AppCore/AppFeature.swift`(`Path.editor(ItemEditorFeature)`)
- Test: `ios/Features/Grownup/Tests/ItemEditorTests.swift`, `ItemFormTests.swift`

**Interfaces:**
- Consumes: Task 1 `SeriesEdits`·`DayPlanner`·`TimeText`·`DayText`, Task 2 `ScheduleStore`, Task 8 이동 액션
- Produces: `@Reducer struct ItemEditorFeature { enum Mode: Equatable { case add(for: Audience), editOnce(ScheduleItem), editWeekly(ScheduleItem) }; State { mode; form: ItemForm; @Presents var confirm: ConfirmKind?; saveFailed: Bool }; Action { … case saveTapped; case saved(Result<Void, Error>); case backTapped; case delegate(Delegate) ; enum Delegate { case finished } } }`. `ItemForm`(순수 값): `audience`, `iconName?`, `name`, `start`, `end`, `repeats: Repeat(.once/.weekly)`, `days: Set<Weekday>`, `date: Day?`, `skipsHolidays`, `showsStar`; `func validation(today:nowMinute:) -> FormProblem?`(`.noName` "Give it a name", `.endsBeforeStart` "Ends before it starts", `.noDay` "Pick at least one day", `.timePassed` "That time has passed"); `func overlapCaption(snapshot:holidays:calendar:) -> String?`; `func previewRows(...)`; `static func defaults(audience:now:calendar:) -> ItemForm`(다음 정시부터 1시간, 오늘 요일, 휴일 건너뛰기 on, 한 번 일정 별 on).

- [ ] **Step 1: 실패하는 테스트**
  - `ItemFormTests`: `testDefaults`, `testPictureFillsEmptyNameOnly`, `testValidationOrder`(문구 그대로), `testDurationCaption`, `testOverlapCaptionWhenNewWins`("Overlaps Swimming 3:30–4:30. This one shows on the clock then."), `testOverlapCaptionWhenOtherWins`("Swimming shows on the clock then."), `testSummaryCaption`("On the clock every Monday and Wednesday from 9 Nov.")
  - `ItemEditorTests`(TestStore): `testAddWeeklySavesAndFinishes`, `testSwitchToJustOnceKeepsForWhatNameWhen`, `testBackWithChangesAsksLeaveWithoutAdding`("Leave without adding?", "Keep editing" / "Leave"), `testBackWithoutChangesLeavesAtOnce`, `testSaveFailureKeepsFormAndShowsCaption`("Couldn't save. Try again."), `testDateChipsShowFiveFromTodayAndPageByWeek`, `testEditOnceRemoveAsksAndDeletes`("Remove {Name}?", "It leaves the clock on Saturday 14 Nov.")
- [ ] **Step 2:** `make test-one TARGET=//ios/Features/Grownup/Tests:GrownupTests` → 실패
- [ ] **Step 3: 구현.** 명세 C3/C4 표의 행과 크기. 키보드(C3k): 이름 칸에 포커스가 가면 폼 카드가 818×352 스크롤 영역이 되고 포커스 칸이 보이게 유지, 미리보기 행 숨김, 메인 버튼만 키보드 28 위로. 리턴 키는 키보드 닫기. `IconPicker`의 "+"는 숨김.
- [ ] **Step 4:** PASS
- [ ] **Step 5: Commit** `feat(grownup): add every-week and just-once items`

### Task 10: 매주 일정 수정 (E5): 한 번 건너뛰기, 그만하기, 저장

**Files:**
- Modify: `ios/Features/Grownup/ItemEditorFeature.swift`, `ItemEditorView.swift`
- Test: `ios/Features/Grownup/Tests/WeeklyEditTests.swift`

**Interfaces:**
- Consumes: Task 1 `SeriesEdits`, Task 9 `ItemEditorFeature.Mode.editWeekly`
- Produces: `Action { case skipNextTapped; case undoSkipTapped; case removeSeriesTapped; case removeConfirmed }`, `State.skippedDay: Day?`

- [ ] **Step 1: 실패하는 테스트**: `testSkipSavesAtOnceAndOffersUndo`(행 문구 "Skipped Mon 16 Nov · Undo", 저장소 `save` 한 번), `testUndoRemovesException`, `testSkipOffersDateAfterAlreadySkipped`, `testRemoveAsksThenEndsSeriesAndFinishes`("Remove Swimming every week?", "It leaves Kid A's clock from Mon 16 Nov. Days before stay in the diary.", 저장된 항목의 until이 전날), `testSaveChangesSplitsWhenRunningToday`(`saveAll` 두 항목), `testSaveChangesInPlaceOtherwise`, `testRepeatCannotSwitchToJustOnce`
- [ ] **Step 2:** 같은 명령 → 실패
- [ ] **Step 3: 구현.** 명세 E5 표. 건너뛰기는 "Save changes" 없이 바로 저장, 그만하기는 확인 카드 후 C1로 돌아감, 과거 날은 그대로.
- [ ] **Step 4:** PASS
- [ ] **Step 5: Commit** `feat(grownup): skip once, stop, or change an every-week item`

### Task 11: 마무리: 갤러리, 시뮬레이터 확인, 문서

**Files:**
- Modify: `CLAUDE.md`(모듈 목록과 시간 규칙 한 줄씩), `ios/DesignSystem/Gallery/ComponentGallery.swift`
- [ ] **Step 1:** `make test`(로컬, 스냅샷 포함) 초록, `bash scripts/check-kid-screens.sh`, `make lint`, 검사용 테스트 전부
- [ ] **Step 2: 시뮬레이터 확인**(`make run`, bazel-ios 스킬의 Face ID 방법):
  - 홈에 시드 하루가 보이고 바늘이 지금 시각을 가리킨다.
  - 시계를 2초 누르면 링이 차고 Face ID 상태 화면이 뜬다. 매칭 → Our kids.
  - Kid A → "Add every week" → 월·수 15:30–16:30 "Swimming" 추가 → 홈 시계(월·수)에 칸이 생긴다.
  - E5에서 "Skip just …", Undo, "Remove every week" 확인.
  - 2분 둔 뒤 홈으로 돌아가고 30초 전 카운트다운이 보인다.
  - 각 화면 스크린샷을 시안 보드와 나란히 비교한다(로드맵 공통 완료 조건).
- [ ] **Step 3:** 개인정보 검사(`git ls-files -z | xargs -0 scripts/check-private-terms.sh`)
- [ ] **Step 4: Commit** `docs: M2 modules and time rules`, 사용자에게 푸시 여부 확인 후 PR(develop)

## M2 완료 기준

- 위 시뮬레이터 확인 다섯 가지가 된다. `make test` 로컬 초록(스냅샷 포함), CI 초록.
- 아이 화면에 스크롤이 없고, 24pt 미만 글자가 없다.
- 공개 저장소에 실제 이름, 학교, 정류장, 시간표가 없다.

## 다음 (M3로 넘길 것)

- 홈 오른쪽 "Leave in"·버스·상태, "Missions →" 버튼, C1 "Getting there", E6 "Cards".
