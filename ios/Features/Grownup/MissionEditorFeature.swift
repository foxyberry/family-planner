import ComposableArchitecture
import Domain
import Foundation
import ScheduleStore
import Strings

/// C5 · Morning missions (grown-up editor): one kid's missions in the order of their morning
/// screen. Add (up to `Mission.most`), rename, change the picture, remove (asks first), drag to
/// reorder. Every change saves at once; done marks of kept missions stay, since they are keyed by id.
@Reducer
public struct MissionEditorFeature {
    /// The card that edits one mission, or a new one (`isNew`).
    public struct Draft: Equatable, Sendable {
        public var id: Mission.ID
        public var name: String
        public var picture: String
        public var isNew: Bool
        /// The days a morning mission is on (spec C5 "days per mission"); nil for an item's mission,
        /// whose card has no Days row.
        public var days: Set<Weekday>?
        /// "Remove {name}?" is showing.
        public var confirmsRemove = false

        public init(id: UUID, name: String, picture: String, isNew: Bool, days: Set<Weekday>? = nil) {
            self.id = id
            self.name = name
            self.picture = picture
            self.isNew = isNew
            self.days = days
        }

        /// A name, and at least one day for a morning mission.
        public var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && days?.isEmpty != true }
    }

    @ObservableState
    public struct State: Equatable {
        public var kids: [Kid] = []
        public var selectedKid: Kid.ID
        public var missions: [Mission] = []
        public var draft: Draft?
        public var saveError: String?

        public init(kid: Kid.ID) {
            selectedKid = kid
        }

        public var kid: Kid? { kids.first { $0.id == selectedKid } }

        /// The chosen kid's missions, in circle order.
        public var rows: [Mission] {
            missions.filter { $0.kid == selectedKid }.sorted { $0.order < $1.order }
        }

        public var canAdd: Bool { rows.count < Mission.most }

        /// "+ Add a mission (6 of 8)".
        public var addTitle: String { L10n.tr("c5.add", rows.count, Mission.most) }

        /// "Same order as Kid A's morning screen".
        public var caption: String { L10n.tr("c5.caption", kid?.name ?? "") }

        /// Picture cards for a kid at home (board C5, Kid B tab).
        public var showsCardsNote: Bool { kid?.school == nil }

        /// The caption under a mission's name in the list: its days when it is not on every day
        /// ("Thu", "Mon · Wed").
        public func daysCaption(_ mission: Mission) -> String? {
            mission.days.count == Weekday.allCases.count ? nil
                : mission.days.sorted().map(DayText.shortName).joined(separator: " · ")
        }

        public var removeTitle: String? {
            guard let draft, draft.confirmsRemove else { return nil }
            return L10n.tr("c5.remove.title", draft.name)
        }
    }

    public enum Action: Equatable {
        case task
        case loaded(ScheduleSnapshot?)
        case kidTabTapped(Kid.ID)
        case rowTapped(Mission.ID)
        case addTapped
        case draftNameChanged(String)
        case draftPicturePicked(String)
        case draftDayToggled(Weekday)
        case draftClosed
        case saveTapped
        case removeTapped
        case removeConfirmed
        case removeCancelled
        /// A dragged row dropped on the place of another (drag ≡), or moved by VoiceOver.
        case moved(Mission.ID, to: Int)
        case saveFailed
        case doneTapped
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
        Reduce { state, action in
            switch action {
            case .task:
                return .run { [scheduleStore] send in
                    await send(.loaded(try? await scheduleStore.load()))
                }

            case let .loaded(snapshot):
                guard let snapshot else { return .none }
                state.kids = snapshot.kids
                state.missions = snapshot.missions
                return .none

            case let .kidTabTapped(kid):
                state.selectedKid = kid
                state.draft = nil
                return .none

            case let .rowTapped(id):
                guard let mission = state.missions.first(where: { $0.id == id }) else { return .none }
                state.draft = Draft(id: id, name: mission.name, picture: mission.picture, isNew: false,
                                    days: mission.days)
                return .none

            case .addTapped:
                guard state.canAdd else { return .none }
                state.draft = Draft(id: uuid(), name: "", picture: "star", isNew: true, days: Set(Weekday.allCases))
                return .none

            case let .draftNameChanged(name):
                state.draft?.name = String(name.prefix(Mission.longestName))
                return .none

            case let .draftPicturePicked(picture):
                state.draft?.picture = picture
                return .none

            case let .draftDayToggled(day):
                guard var days = state.draft?.days else { return .none }
                if days.contains(day) { days.remove(day) } else { days.insert(day) }
                state.draft?.days = days
                return .none

            case .draftClosed:
                state.draft = nil
                return .none

            case .saveTapped:
                guard let draft = state.draft, draft.canSave else { return .none }
                let name = draft.name.trimmingCharacters(in: .whitespaces)
                var rows = state.rows
                if let index = rows.firstIndex(where: { $0.id == draft.id }) {
                    rows[index].name = name
                    rows[index].picture = draft.picture
                    rows[index].days = draft.days ?? rows[index].days
                } else if rows.count < Mission.most {
                    rows.append(Mission(id: draft.id, kid: state.selectedKid, name: name, picture: draft.picture,
                                        order: rows.count, days: draft.days ?? Set(Weekday.allCases)))
                }
                state.draft = nil
                return save(rows, in: &state)

            case .removeTapped:
                state.draft?.confirmsRemove = true
                return .none

            case .removeCancelled:
                state.draft?.confirmsRemove = false
                return .none

            case .removeConfirmed:
                guard let draft = state.draft else { return .none }
                state.draft = nil
                return save(state.rows.filter { $0.id != draft.id }, in: &state)

            case let .moved(id, to):
                var rows = state.rows
                guard let from = rows.firstIndex(where: { $0.id == id }) else { return .none }
                let target = min(max(to, 0), rows.count - 1)
                guard target != from else { return .none }
                rows.insert(rows.remove(at: from), at: target)
                return save(rows, in: &state)

            case .saveFailed:
                state.saveError = L10n.tr("editor.save_error")
                return .none

            case .doneTapped:
                return .send(.delegate(.finished))

            case .delegate:
                return .none
            }
        }
    }

    /// Renumbers `rows` 0… (the circle order), puts them in state and saves the kid's whole list.
    private func save(_ rows: [Mission], in state: inout State) -> Effect<Action> {
        let kid = state.selectedKid
        let ordered = rows.enumerated().map { index, mission in
            var mission = mission
            mission.order = index
            return mission
        }
        state.missions = state.missions.filter { $0.kid != kid } + ordered
        state.saveError = nil
        return .run { [scheduleStore] send in
            do { try await scheduleStore.saveMissions(kid, ordered) } catch { await send(.saveFailed) }
        }
    }
}
