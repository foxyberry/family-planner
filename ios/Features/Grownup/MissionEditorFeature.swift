import ComposableArchitecture
import Domain
import Foundation
import Localization
import ScheduleStore
import Strings

/// C5 · Routines (grown-up editor, board C5, issue 024): a kid's bundles, which events pick for their
/// lists. The side column lists the bundles and "New bundle"; the card edits the picked one: its name,
/// then its missions in circle order (add up to `Mission.most`, rename, change the picture, remove,
/// drag to reorder). "Remove {bundle}" asks first when an event uses it. Every change saves at once;
/// done marks of kept missions stay, since they are keyed by id.
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
        public var strings = Localizer.injected
        public var kids: [Kid] = []
        public var selectedKid: Kid.ID
        public var bundles: [MissionBundle] = []
        /// The bundle the card edits; nil picks the kid's first.
        public var picked: MissionBundle.ID?
        /// The events that may pick a bundle (for "Used by").
        public var items: [ScheduleItem] = []
        public var routines: [Routine] = []
        public var draft: Draft?
        /// "Remove {bundle}?" is showing.
        public var confirmsBundleRemove = false
        public var saveError: String?

        public init(kid: Kid.ID) {
            selectedKid = kid
        }

        public var kid: Kid? { kids.first { $0.id == selectedKid } }

        /// The chosen kid's bundles, in the stored order.
        public var kidBundles: [MissionBundle] { bundles.filter { $0.kid == selectedKid } }
        public var bundle: MissionBundle? { kidBundles.first { $0.id == picked } ?? kidBundles.first }

        /// The picked bundle's missions, in circle order.
        public var rows: [Mission] { (bundle?.missions ?? []).sorted { $0.order < $1.order } }

        /// The events whose before or after list picks the bundle: the kid's School, then templates'
        /// blocks and items by name, each name once.
        public func usedBy(_ id: MissionBundle.ID) -> [String] {
            var names: [String] = []
            func add(_ name: String) { if !names.contains(name) { names.append(name) } }
            func uses(_ lists: EventLists?) -> Bool { lists.map { $0.before.contains(id) || $0.afterBundles.contains(id) } ?? false }
            // The school record, and a school change still waiting for its day (#316 review).
            if uses(kid?.school?.lists) || uses(kid?.pendingSchool?.school?.lists) { add(strings.tr("from.school")) }
            for routine in routines where routine.kid == selectedKid {
                for block in routine.blocks where uses(block.lists) { add(block.title) }
            }
            for item in items where uses(item.lists) { add(item.title) }
            return names
        }

        // MARK: The bundles (side column and Name row)

        public var bundleRows: [(id: MissionBundle.ID, name: String, isPicked: Bool)] {
            kidBundles.map { ($0.id, $0.name, $0.id == bundle?.id) }
        }
        public var newBundleTitle: String { strings.tr("c5.new_bundle") }
        public var bundleName: String { bundle?.name ?? "" }
        /// "Used by School, Swimming", or "Not used yet".
        public var usedByCaption: String? {
            guard let bundle else { return nil }
            let names = usedBy(bundle.id)
            return names.isEmpty ? strings.tr("c5.not_used") : strings.tr("c5.used_by", names.joined(separator: ", "))
        }
        public var removeBundleTitle: String? { bundle.map { strings.tr("c5.bundle.remove", $0.name) } }
        /// The confirm card's title and message ("Remove Morning routine?" / "School will lose it.").
        public var removeBundleConfirm: (title: String, message: String)? {
            guard confirmsBundleRemove, let bundle else { return nil }
            return (strings.tr("c5.remove.title", bundle.name),
                    strings.tr("c5.bundle.lose", usedBy(bundle.id).joined(separator: ", ")))
        }

        public var canAdd: Bool { bundle != nil && rows.count < Mission.most }

        /// "+ Add a mission (6 of 8)".
        public var addTitle: String { strings.tr("c5.add", rows.count, Mission.most) }

        // MARK: What the view shows (it holds no values of its own)

        /// The header's title and the Done button.
        public var title: String { strings.tr("c5.title") }
        /// Board C5: the Name row's field holds up to 14 characters, as a mission name.
        public static let longestBundleName = 14
        public var doneTitle: String { strings.tr("c5.done") }
        /// In place of the add row once the kid has `Mission.most` missions.
        public var mostCaption: String { strings.tr("c5.most") }
        /// The mission card's words: the name field, Remove (also the confirm card's button) and Save.
        public var nameLabel: String { strings.tr("c5.name") }
        public var removeLabel: String { strings.tr("c5.remove") }
        public var saveTitle: String { strings.tr("c5.save") }
        /// The remove confirm card's cancel button.
        public var keepLabel: String { strings.tr("c5.remove.keep") }

        /// The caption under a mission's name in the list: its days when it is not on every day
        /// ("Thu", "Mon · Wed").
        public func daysCaption(_ mission: Mission) -> String? {
            mission.days.count == Weekday.allCases.count ? nil
                : mission.days.sorted().map(DayText.shortName).joined(separator: " · ")
        }

        public var removeTitle: String? {
            guard let draft, draft.confirmsRemove else { return nil }
            return strings.tr("c5.remove.title", draft.name)
        }
    }

    public enum Action: Equatable {
        case task
        case loaded(ScheduleSnapshot?)
        case kidTabTapped(Kid.ID)
        case bundleTapped(MissionBundle.ID)
        case newBundleTapped
        case bundleNameChanged(String)
        case removeBundleTapped
        case removeBundleConfirmed
        case removeBundleCancelled
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
        /// A dragged row dropped on the place of another (drag ≡).
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
                state.bundles = snapshot.bundles
                state.items = snapshot.items
                state.routines = snapshot.routines
                return .none

            case let .kidTabTapped(kid):
                state.selectedKid = kid
                state.picked = nil
                state.draft = nil
                state.confirmsBundleRemove = false
                return .none

            case let .bundleTapped(id):
                state.picked = id
                state.draft = nil
                return .none

            case .newBundleTapped:
                // Spec C5: a new bundle starts as "New bundle" with no missions, picked.
                let bundle = MissionBundle(id: uuid(), kid: state.selectedKid, name: state.newBundleTitle, missions: [])
                state.bundles.append(bundle)
                state.picked = bundle.id
                return saveBundle(bundle)

            case let .bundleNameChanged(name):
                guard var bundle = state.bundle,
                      let index = state.bundles.firstIndex(where: { $0.id == bundle.id }) else { return .none }
                bundle.name = String(name.prefix(State.longestBundleName))
                state.bundles[index] = bundle
                // As a mission's: an empty name is not saved (the field keeps it while typing).
                guard !bundle.name.trimmingCharacters(in: .whitespaces).isEmpty else { return .none }
                return saveBundle(bundle)

            case .removeBundleTapped:
                guard let bundle = state.bundle else { return .none }
                // Asks first only when an event uses it (spec C5).
                if state.usedBy(bundle.id).isEmpty { return removeBundle(&state) }
                state.confirmsBundleRemove = true
                return .none

            case .removeBundleCancelled:
                state.confirmsBundleRemove = false
                return .none

            case .removeBundleConfirmed:
                return removeBundle(&state)

            case let .rowTapped(id):
                guard let mission = state.rows.first(where: { $0.id == id }) else { return .none }
                state.draft = Draft(id: id, name: mission.name, picture: mission.picture, isNew: false,
                                    days: mission.days)
                return .none

            case .addTapped:
                guard state.canAdd, state.bundle != nil else { return .none }
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

    /// Renumbers `rows` 0… (the circle order), puts them in the picked bundle and saves it.
    private func save(_ rows: [Mission], in state: inout State) -> Effect<Action> {
        guard var bundle = state.bundle, let index = state.bundles.firstIndex(where: { $0.id == bundle.id }) else {
            return .none
        }
        bundle.missions = rows.enumerated().map { index, mission in
            var mission = mission
            mission.order = index
            return mission
        }
        state.bundles[index] = bundle
        state.saveError = nil
        return saveBundle(bundle)
    }

    /// One save at a time per bundle: a newer one cancels the one in flight, so typing "Swim" never
    /// ends on "Swi" (#316 review).
    private func saveBundle(_ bundle: MissionBundle) -> Effect<Action> {
        .run { [scheduleStore] send in
            do { try await scheduleStore.saveBundle(bundle) } catch { await send(.saveFailed) }
        }
        .cancellable(id: SaveID(bundle: bundle.id), cancelInFlight: true)
    }

    private struct SaveID: Hashable { let bundle: MissionBundle.ID }

    /// Removes the picked bundle; the card goes to the kid's first bundle left.
    private func removeBundle(_ state: inout State) -> Effect<Action> {
        guard let bundle = state.bundle else { return .none }
        state.bundles.removeAll { $0.id == bundle.id }
        state.picked = nil
        state.confirmsBundleRemove = false
        return .run { [scheduleStore] send in
            do { try await scheduleStore.deleteBundle(bundle.id) } catch { await send(.saveFailed) }
        }
    }
}
