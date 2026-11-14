import ComposableArchitecture
import Domain
import Foundation
import ScheduleStore
import Strings

/// G6f "+ Add a child" (spec "G6 · Settings", layout v44): the S1 kid card for one new kid (name,
/// age, colour, face), up to four kids. The new kid starts at home with the starter day templates
/// and missions; a school is added later from Settings (G7).
@Reducer
public struct AddChildFeature {
    public static let most = 4
    public static let colours = 4

    @ObservableState
    public struct State: Equatable {
        public var name = ""
        public var ageText = ""
        public var colorIndex = 0
        public var face = "kidGirl" // copy-ok: a KitSlot name
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
        public var canSave: Bool { !trimmedName.isEmpty && age != nil && !isSaving }

        /// The swatch's VoiceOver name (the S1 words).
        public static func colourName(_ index: Int) -> String {
            switch index {
            case 0: L10n.tr("s1.colour.blue")
            case 1: L10n.tr("s1.colour.orange")
            case 2: L10n.tr("s1.colour.green")
            default: L10n.tr("s1.colour.purple")
            }
        }
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
