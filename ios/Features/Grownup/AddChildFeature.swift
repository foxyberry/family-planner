import ComposableArchitecture
import DesignSystem
import Domain
import Foundation
import Localization
import ScheduleStore
import Strings

/// G6f "+ Add a child" (spec "G6 · Settings"): the S1 kid card for one new kid (name,
/// age, colour, face), up to four kids. The new kid starts at home with the starter day templates
/// and missions; a school is added later from Settings (G7).
@Reducer
public struct AddChildFeature {
    public static let most = 4
    public static let colours = 4

    @ObservableState
    public struct State: Equatable {
        public var strings = Localizer.injected
        public var name = ""
        public var ageText = ""
        public var colorIndex = 0
        /// Board G6a: no face is picked at first (the colour dot shows in the Name field, as on S1).
        public var face = ""
        public var today: Day
        public var isSaving = false
        public var saveError: String?

        public init(today: Day, takenColours: [Int]) {
            self.today = today
            colorIndex = (0..<AddChildFeature.colours).first { !takenColours.contains($0) } ?? 0
        }

        public var title: String { L10n.tr("add_child.title") }
        public var age: Int? { Int(ageText.trimmingCharacters(in: .whitespaces)).flatMap { (1...18).contains($0) ? $0 : nil } }
        public var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
        /// As on S1, every kid needs a name, an age and a face (user, 2026-11-09).
        /// The side column's button.
        public var addTitle: String { strings.tr("add_child.add") }
        public var canSave: Bool { !trimmedName.isEmpty && age != nil && !face.isEmpty && !isSaving }
        /// The shared kid card's words (S1's).
        public var cardWords: KidCard.Words { .kid(strings) }
        /// The face inside the Name field, in the picked colour.
        public var badge: KidFace.Badge { KidFace.Badge(face: face, colorIndex: colorIndex) }
    }

    public enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case colourTapped(Int)
        case faceTapped(String)
        case saveTapped
        case saved(Bool)
        case backTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case finished
        }
    }

    @Dependency(\.scheduleStore) var scheduleStore
    @Dependency(\.uuid) var uuid

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                state.name = String(state.name.prefix(Mission.longestName))
                return .none

            case let .colourTapped(colour):
                state.colorIndex = colour
                return .none

            case let .faceTapped(face):
                state.face = face
                return .none

            case .saveTapped:
                guard state.canSave, let age = state.age else { return .none }
                state.isSaving = true
                let kid = Kid(id: uuid(), name: state.trimmedName, colorIndex: state.colorIndex, age: age, schoolYear: nil,
                              school: nil, face: state.face)
                let routines = StarterDays.routines(for: kid, trip: nil, from: state.today)
                let missions = StarterDays.missions(for: kid, id: { uuid() })
                return .run { [scheduleStore] send in
                    do {
                        try await scheduleStore.saveKid(kid)
                        for routine in routines { try await scheduleStore.saveRoutine(routine) }
                        try await scheduleStore.saveMissions(kid.id, missions)
                        await send(.saved(true))
                    } catch {
                        await send(.saved(false))
                    }
                }

            case let .saved(ok):
                state.isSaving = false
                guard ok else {
                    state.saveError = L10n.tr("day.save_failed")
                    return .none
                }
                return .send(.delegate(.finished))

            case .backTapped:
                return .send(.delegate(.finished))

            case .delegate:
                return .none
            }
        }
    }
}
