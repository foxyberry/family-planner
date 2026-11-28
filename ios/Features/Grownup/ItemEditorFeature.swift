import ComposableArchitecture
import DesignSystem
import Domain
import Foundation
import HolidayProvider
import KitArt
import Localization
import ScheduleStore
import SchoolDirectory
import Strings

/// Add to the day (boards C3, C4, C3k) and edit an item (C4 edit mode, G2).
@Reducer
public struct ItemEditorFeature {
    public enum Mode: Equatable, Sendable {
        case add(Audience)
        case editOnce(ScheduleItem)
        case editWeekly(ScheduleItem)
    }

    public enum Confirm: Equatable, Sendable {
        case leave, removeOnce, removeSeries
    }

    /// The every-week item's edit tabs (boards G2, G3): this day only, or the series.
    public enum Scope: Hashable, Sendable { case thisDay, allDays }

    /// Board G5 "Change from when?": the day the changed series starts.
    public enum FromWhen: Hashable, Sendable { case today, next, date }

    /// A form row's card (boards F1–F4), with the form as it was when it opened: Done keeps the
    /// changes, Cancel or a tap outside puts the form back.
    public struct Card: Equatable, Sendable {
        public enum Kind: Equatable, Sendable { case from, before, back, runsEnd, noSchool }
        public var kind: Kind
        public var was: ItemForm
    }

    /// One tab under "For": a kid, or both kids.
    public struct AudienceTab: Equatable, Sendable {
        public var audience: Audience
        public var title: String
        /// The kid's face in their colour ring; nil for "Both".
        public var badge: KidFace.Badge?

        public init(audience: Audience, title: String, badge: KidFace.Badge?) {
            self.audience = audience
            self.title = title
            self.badge = badge
        }
    }

    /// One date chip in the just-once row.
    public struct DateOption: Equatable, Sendable {
        public var day: Day
        /// "Mon"
        public var weekday: String
        public var isOn: Bool

        public init(day: Day, weekday: String, isOn: Bool) {
            self.day = day
            self.weekday = weekday
            self.isOn = isOn
        }
    }

    @ObservableState
    public struct State: Equatable {
        public var strings = Localizer.injected
        public var mode: Mode
        public var form: ItemForm
        public var original: ItemForm
        public var calendar: Calendar
        public var today: Day
        public var nowMinute: Int
        public var snapshot: ScheduleSnapshot?

        /// Board C3g "Going": None, Walk, Bus, Car, Taxi; the item's way is picked.
        public var goingChoices: [ChoiceCircles.Choice] {
            let way = form.trip?.way
            return [
                ChoiceCircles.Choice(id: "none", picture: nil, caption: L10n.tr("going.none"), isPicked: way == nil),
                ChoiceCircles.Choice(id: Domain.Way.walk.rawValue, picture: .shoe, caption: L10n.tr("going.walk"),
                                     isPicked: way == .walk),
                ChoiceCircles.Choice(id: Domain.Way.bus.rawValue, picture: .busDouble, caption: L10n.tr("going.bus"),
                                     isPicked: way == .bus),
                ChoiceCircles.Choice(id: Domain.Way.car.rawValue, picture: .car, caption: L10n.tr("going.car"),
                                     isPicked: way == .car),
                ChoiceCircles.Choice(id: Domain.Way.taxi.rawValue, picture: .taxi, caption: L10n.tr("going.taxi"),
                                     isPicked: way == .taxi),
            ]
        }
        /// The family's year: each kid's school calendar and the public holidays.
        public var family = FamilyCalendar()
        /// The days off of the form's kid (for both kids: the days off for both).
        public var holidays: Set<Day> { family.daysOff(for: form.audience) }
        /// Board C3 "What": the "More" popover with every picture is open.
        public var isPickingMorePictures = false

        /// The pictures offered under "What" (the kit's activity pictures), in the popover's order.
        public static let pictures: [KitSlot] = [.actSwim, .actArt, .actMusic, .actPiano, .actDance, .actFootball,
                                                 .actStory, .actCCA, .actPlay, .homework, .doctor, .cake]
        /// Spec C3 "What" (N15): the country flags after the pictures in "More", in kit order (0d3),
        /// so a weekend school can wear its country's flag.
        public static let flags: [KitSlot] = [.flagKR, .flagJP, .flagCN, .flagUK, .flagFR, .flagIN, .flagTH, .flagVN]

        /// Board C3 "What" row: the picked picture first, then the pictures this kid's items use most,
        /// then the kit's list; five slots (the sixth is "More").
        public var whatRow: [String] {
            let items = (snapshot?.items ?? []).filter { item in
                switch form.audience {
                case let .kid(id): item.audience.includes(id)
                case .both: true
                }
            }
            return ItemForm.rowPictures(picked: form.iconName, used: items.map(\.iconName),
                                        all: Self.pictures.map(\.rawValue))
        }
        /// Weeks forward in the just-once date chips; never before this week.
        public var datePage = 0
        public var confirm: Confirm?
        public var saveError: String?
        /// A save, skip or remove is on its way to the store; further taps wait for it.
        public var isSaving = false
        /// The every-week item as saved right now (skips are saved at once, board G2).
        public var weeklyItem: ScheduleItem?
        /// The date "Skip this day" skipped, while it can still be brought back.
        public var skippedDay: Day?
        /// Board G3 / G2 tabs; an every-week item opens on All days wherever it is opened from (G1's
        /// Details on either tab, the List, Settings), as School does (specs #293, #298); This day
        /// stays one tap away.
        public var editScope: Scope = .allDays
        /// Board G5: the "Change from when?" card is open, with its choice and date.
        public var fromWhen: FromWhen?
        public var fromWhenDate: Day
        /// The day G1 showed when "Details ›" opened this form; nil from the List or an add. This day
        /// means it (moved on when the series is not on it), and G5 opens on that day when it is after
        /// today (spec G5).
        public let shownDay: Day?
        /// The id a new item has in the preview, kept from `.task` on (save still asks for a fresh id).
        public var draftID: ScheduleItem.ID?
        /// The From, Bring, Ends or No school days card is open.
        public var card: Card?

        /// The Bring card shows the whole kit ("More").
        public var isPickingMoreBring = false
        /// Board F2k: the kid whose bundles the Before card shows (an event for more than one kid).
        public var beforeKid: Kid.ID?

        /// The From card's choices (Home, then events this item can follow).
        public var fromChoices: [ItemForm.FromChoice] {
            form.fromChoices(kids: snapshot?.kids ?? [], routines: snapshot?.routines ?? [],
                             items: snapshot?.items ?? [], editing: editingItem?.id, today: today, calendar: calendar)
        }

        /// The From card's circles; the item's From is picked.
        public var fromCircles: [ChoiceCircles.Choice] {
            fromChoices.map { choice in
                ChoiceCircles.Choice(id: Self.choiceID(choice.event), picture: KitSlot(rawValue: choice.picture),
                                     caption: choice.title, isPicked: choice.event == form.after)
            }
        }

        static func choiceID(_ event: EventRef?) -> String {
            switch event {
            case nil: "home"
            case .school?: "school"
            case let .item(id)?: id.uuidString
            }
        }

        /// The linked event's name, for "After {event}".
        private var afterTitle: String? {
            guard let after = form.after else { return nil }
            if let choice = fromChoices.first(where: { $0.event == after }) { return choice.title }
            if case let .item(id) = after { return snapshot?.items.first { $0.id == id }?.title }
            return L10n.tr("from.school")
        }

        /// The From row: "Home", "After School" or "After School · 15 min after" (board G2b).
        public var fromText: String {
            guard let afterTitle else { return L10n.tr("from.home") }
            return form.afterGap == 0 ? L10n.tr("from.after", afterTitle) : L10n.tr("from.after.gap", afterTitle, form.afterGap)
        }

        /// "15 min after" between − and + in the From card.
        public var gapText: String { L10n.tr("from.gap", form.afterGap) }

        /// Board G2b: an item after School gets "No school"; it follows School's days, so it has no
        /// "Skip school holidays".
        public var showsNoSchool: Bool { form.after == .school }
        public var showsSkipHolidays: Bool { form.after != .school }

        /// "Skip", or "At 10:00 am".
        public var noSchoolText: String {
            form.noSchoolStart.map { L10n.tr("no_school.at", TimeText.withPeriod($0)) } ?? L10n.tr("no_school.skip")
        }
        public var noSchoolTime: Date { today.date(minute: form.noSchoolStart ?? form.start, calendar: calendar) }
        public var noSchoolTimeLabel: String { TimeText.withPeriod(form.noSchoolStart ?? form.start) }

        /// How the kid goes on a day without School: None, Walk, Bus, Car or Taxi.
        public var noSchoolGoing: [ChoiceCircles.Choice] {
            // Board F4: Walk, Bus or Car (a day without School starts from Home, so never None).
            goingChoices.filter { choice in [Domain.Way.walk, .bus, .car].contains { $0.rawValue == choice.id } }.map { choice in
                var copy = choice
                copy.isPicked = choice.id == form.noSchoolWay?.rawValue
                return copy
            }
        }
        /// The set time's end: its own, or the item's length after the start (board F4).
        public var noSchoolEndMinute: Int {
            form.noSchoolEnd ?? (form.noSchoolStart ?? form.start) + max(form.end - form.start, 0)
        }
        public var noSchoolEndTime: Date { today.date(minute: min(noSchoolEndMinute, 1439), calendar: calendar) }
        public var noSchoolEndLabel: String { TimeText.withPeriod(noSchoolEndMinute) }
        /// A linked item's start is not typed: "after School".
        public var linkedStartText: String? { afterTitle.map { L10n.tr("from.start", $0) } }

        /// The Bring card's pictures: the kit's bring group, or every picture after "More".
        public var bringSlots: [KitSlot] { isPickingMoreBring ? Self.bringAll : Self.bringGroup }
        public static let bringGroup: [KitSlot] = [.backpack, .lunchBox, .waterBottle, .shoe]

        /// Board F2: one row of up to four things (the kit's bring group, with things picked under
        /// "More" taking the place of unpicked ones), then "More".
        public var bringRow: [ChoiceCircles.Choice] {
            let picked = form.bring.compactMap { KitSlot(rawValue: $0.picture) }
            var row = Self.bringGroup + picked.filter { !Self.bringGroup.contains($0) }
            while row.count > ItemMission.most, let index = row.lastIndex(where: { !picked.contains($0) }) {
                row.remove(at: index)
            }
            return row.map { slot in
                ChoiceCircles.Choice(id: slot.rawValue, picture: slot, caption: ItemForm.bringLabel(for: slot.rawValue),
                                     isPicked: picked.contains(slot))
            } + [ChoiceCircles.Choice(id: Self.bringMoreID, picture: nil, caption: "", isPicked: isPickingMoreBring,
                                      word: L10n.tr("picker.more"))]
        }
        static let bringMoreID = "more" // copy-ok: choice id

        /// "More" (spec "Event form rows"): object pictures only (`KitSlot.isThing`).
        /// The bring kit (board 0d4) first, then every other thing.
        public static let bringKit: [KitSlot] = [.backpack, .lunchBox, .waterBottle, .swimsuit, .goggles, .towel,
                                                 .rollerblades, .helmet, .libraryBag]
        public static let bringAll: [KitSlot] = bringKit + KitSlot.allCases.filter { $0.isThing && !bringKit.contains($0) }
        public var bringPicked: Set<KitSlot> { Set(form.bring.compactMap { KitSlot(rawValue: $0.picture) }) }

        /// Going / Leave show when the item starts from Home (C3g); a linked item has no trip.
        public var showsGoing: Bool { form.after == nil }

        /// Board C3m: the rule tabs under the date strip.
        public var monthlyChoices: [(byDate: Bool, title: String)] { form.monthlyChoices(calendar: calendar) }

        /// The last day of the term the run starts in, for the form's kid; nil without a school calendar.
        public var termEnd: Day? { family.termEnd(for: form.audience, from: form.date) }

        /// Board G2 Runs: "9 Nov" → "End of term".
        public var runsStartText: String { form.runsStartText(calendar: calendar) }
        public var runsEndText: String { form.runsEndText(calendar: calendar) }
        public var runsStart: Date { form.date.date(calendar: calendar) }
        public var runsUntil: Date { max(form.untilDate, form.date).date(calendar: calendar) }

        /// Board F3's rows as shown: the label, the term's date under "End of this term", and the pick.
        public struct RunsEndRow: Equatable, Sendable {
            public var kind: ItemForm.RunsEndKind
            public var title: String
            public var caption: String?
            public var isPicked: Bool
        }
        public var runsEndRows: [RunsEndRow] {
            runsEndTabs.map { kind, title in
                RunsEndRow(kind: kind, title: title, caption: kind == .term ? termCaption : nil,
                           isPicked: form.runsEnd == kind)
            }
        }

        /// The Ends card's rows (board F3): "End of this term" only when the kid's school has terms.
        public var runsEndTabs: [(ItemForm.RunsEndKind, String)] {
            (termEnd == nil ? [] : [(ItemForm.RunsEndKind.term, L10n.tr("runs.pick.term"))])
                + [(.date, L10n.tr("runs.pick.date")), (.count, L10n.tr("runs.pick.count")), (.none, L10n.tr("runs.pick.none"))]
        }

        /// "Term 4 ends 20 Nov" under the End of term tab.
        public var termCaption: String? {
            guard let termEnd else { return nil }
            return DayText.short(termEnd, calendar: calendar)
        }

        public init(mode: Mode, repeats: ItemForm.Repeat = .weekly, now: Date, calendar: Calendar,
                    shownDay: Day? = nil) {
            self.mode = mode
            self.shownDay = shownDay
            self.calendar = calendar
            today = Day(now, calendar: calendar)
            nowMinute = Day.minute(of: now, calendar: calendar)
            let initial: ItemForm
            switch mode {
            case let .add(audience):
                var form = ItemForm.defaults(audience: audience, now: now, calendar: calendar)
                form.repeats = repeats
                form.refreshMonthly(calendar: calendar)
                initial = form
            case let .editOnce(item), let .editWeekly(item):
                initial = ItemForm(item: item)
            }
            form = initial
            original = initial
            fromWhenDate = Day(now, calendar: calendar)
            if case let .editWeekly(item) = mode { weeklyItem = item }
        }

        public var isAdding: Bool { if case .add = mode { true } else { false } }
        public var isEditingWeekly: Bool { if case .editWeekly = mode { true } else { false } }

        public var editingItem: ScheduleItem? {
            switch mode {
            case .add: nil
            case let .editOnce(item), let .editWeekly(item): item
            }
        }

        public var title: String { isAdding ? L10n.tr("editor.title.add") : L10n.tr("editor.title.edit", original.name) }
        public var primaryTitle: String { isAdding ? L10n.tr("editor.primary.add") : L10n.tr("editor.primary.save") }
        /// The remove button of a just-once item.
        public var removeTitle: String { L10n.tr("editor.remove", original.name) }

        // MARK: What the view shows (it holds no values of its own)

        /// The form rows' labels (boards C3, C4, G2): For, What, Name (also the field's), When, Repeat,
        /// Days, Runs, From, Off days, Going, Leave, Bring and Medal.
        public var forLabel: String { strings.tr("editor.row.for") }
        public var whatLabel: String { strings.tr("editor.row.what") }
        public var nameLabel: String { strings.tr("editor.row.name") }
        public var whenLabel: String { strings.tr("editor.row.when") }
        public var repeatLabel: String { strings.tr("editor.row.repeat") }
        public var daysLabel: String { strings.tr("editor.row.days") }
        public var runsLabel: String { strings.tr("editor.row.runs") }
        /// The From row's label, also board F1's title.
        public var fromLabel: String { strings.tr("editor.row.from") }
        public var noSchoolLabel: String { strings.tr("editor.row.no_school") }
        public var goingLabel: String { strings.tr("going.label") }
        public var leaveLabel: String { strings.tr("going.leave") }
        /// The Bring row's label, also board F2's title.
        public var medalLabel: String { strings.tr("editor.row.medal") }
        /// Layout v45: "Once · Weekly · Monthly".
        public var repeatTabs: [(ItemForm.Repeat, String)] {
            [(.once, strings.tr("editor.repeat.once")), (.weekly, strings.tr("editor.repeat.weekly")),
             (.monthly, strings.tr("editor.repeat.monthly"))]
        }
        /// "More" after the What row's pictures.
        public var moreTitle: String { strings.tr("picker.more") }
        /// The checks: Skip school holidays, and C4's star on the clock.
        public var skipHolidaysTitle: String { strings.tr("editor.skip_holidays") }
        public var starTitle: String { strings.tr("editor.star") }
        /// The Bring row with nothing to bring.
        public var nothingText: String { strings.tr("editor.row.nothing") }
        /// Boards F1–F4: every form card's Done and Cancel.
        public var cardDoneTitle: String { strings.tr("c5.done") }
        public var cardCancelTitle: String { strings.tr("card.cancel") }
        /// Board F3 Ends: its title and the picked count ("6 times").
        public var runsCardTitle: String { strings.tr("runs.card.title") }
        public var runsCountText: String { strings.tr("runs.count.value", form.times) }
        /// Board F1: "Starts" before the gap after an event.
        public var startsLabel: String { strings.tr("from.starts") }
        /// Board F4 Off days: its title and two choices.
        public var noSchoolCardTitle: String { strings.tr("no_school.card.title") }
        public var noSchoolSkipTitle: String { strings.tr("no_school.pick.skip") }
        public var noSchoolAtTitle: String { strings.tr("no_school.pick.at") }
        /// Board C3g: the Leave row of a kid who goes by bus links to Our buses ("Uses Our buses ›").
        /// The "›" is drawn by GlyphText at the key's "%@" (Playpen Sans has none).
        public var usesBusesTitle: String { strings.tr("going.uses_buses", "%@") }
        /// Boards G2 / G3: the side column's This day / All days tabs.
        public var scopeTabs: [(Scope, String)] {
            [(.thisDay, strings.tr("editor.scope.this_day")), (.allDays, strings.tr("editor.scope.all_days"))]
        }
        /// Board G5: the "Change from when?" card's words, and the tab it shows (Today until picked).
        public var fromWhenTitle: String { strings.tr("from_when.title") }
        public var fromWhenSave: String { strings.tr("from_when.save") }
        public var fromWhenCancel: String { strings.tr("from_when.cancel") }
        public var fromWhenChoice: FromWhen { fromWhen ?? .today }
        /// While editing, an event that already started keeps its start time without "That time has passed".
        public var problem: FormProblem? {
            let keptStart = !isAdding && form.date == original.date ? original.start : nil
            return form.problem(today: today, nowMinute: nowMinute, keptStart: keptStart)
        }
        /// Spec "Add-screen feedback": Save stays on; a tap with a problem shows the problem under
        /// its field and scrolls there. Until then the form shows no warning (board C3 opens with an
        /// empty name).
        public var showsProblems = false
        public var scrollTarget: GrownupScrollTarget?

        /// The problem shown under `row`, once Save has been tapped with a problem.
        public func problem(for row: FormRow) -> FormProblem? {
            guard showsProblems else { return nil }
            return problem.flatMap { $0.row == row ? $0 : nil }
        }
        /// Save can always be tapped (it explains a problem instead), except while it saves.
        public var canSave: Bool { !isSaving }
        public var hasChanges: Bool { form != original }

        /// A tab per kid, and "Both" once there are two or more kids.
        public var audienceTabs: [AudienceTab] {
            let kids = snapshot?.kids ?? []
            return kids.map { AudienceTab(audience: .kid($0.id), title: $0.name,
                                     badge: KidFace.Badge(face: $0.face, colorIndex: $0.colorIndex)) }
                + (kids.count > 1 ? [AudienceTab(audience: .both, title: L10n.tr("editor.audience.both"), badge: nil)] : [])
        }

        /// The form's times as times on today, for the time fields.
        public var startTime: Date { today.date(minute: form.start, calendar: calendar) }
        public var endTime: Date { today.date(minute: form.end, calendar: calendar) }
        /// "3:30 pm" on the time fields.
        public var startLabel: String { TimeText.withPeriod(form.start) }
        public var endLabel: String { TimeText.withPeriod(form.end) }

        /// Five dates from today, a week per page (board C4).
        public var visibleDates: [Day] {
            (0..<5).map { today.adding(days: datePage * 7 + $0, calendar: calendar) }
        }

        public var dateChips: [DateOption] {
            visibleDates.map {
                DateOption(day: $0, weekday: DayText.shortName($0.weekday(calendar)), isOn: form.date == $0)
            }
        }

        /// Paging never goes before this week; board C4's ‹ is off on the first page.
        public var canPageEarlier: Bool { datePage > 0 }

        /// The every-week side column's title (board G2): "Every Mon and Wed".
        /// "Every Mon and Wed", or for every month "Every 2nd Sat" / "Every 14th" (board G2m).
        public var everyTitle: String {
            form.repeats == .monthly ? DayText.monthlyEvery(form.monthlyRule) : DayText.every(form.days)
        }

        /// Board G2m: "Remove every month" for an every-month series.
        public var removeSeriesTitle: String {
            form.repeats == .monthly ? L10n.tr("editor.remove_series.monthly") : L10n.tr("editor.remove_series")
        }

        /// The add and just-once side column; the every-week side column has none.
        public var preview: FormPreview? {
            guard !isEditingWeekly else { return nil }
            return form.preview(kids: snapshot?.kids ?? [], routines: snapshot?.routines ?? [],
                                items: family.resolving(snapshot?.items ?? [], calendar: calendar), family: family,
                                draftID: editingItem?.id ?? draftID, showsDraft: form.end > form.start, today: today,
                                calendar: calendar)
        }

        public var overlapCaption: String? {
            guard let snapshot else { return nil }
            return form.overlapCaption(items: family.resolving(snapshot.items, calendar: calendar), kids: snapshot.kids, family: family,
                                       editing: editingItem?.id, today: today, calendar: calendar)
        }

        public var confirmTitle: String? {
            switch confirm {
            case .leave: isAdding ? L10n.tr("editor.confirm.leave_new.title") : L10n.tr("editor.confirm.leave.title")
            case .removeOnce: L10n.tr("editor.confirm.remove_once.title", original.name)
            case .removeSeries: L10n.tr("editor.confirm.remove_series.title", original.name)
            case nil: nil
            }
        }

        public var confirmCancelTitle: String {
            confirm == .leave ? L10n.tr("editor.confirm.leave.cancel") : L10n.tr("editor.confirm.remove.cancel")
        }
        public var confirmAcceptTitle: String {
            confirm == .leave ? L10n.tr("editor.confirm.leave.accept") : L10n.tr("editor.confirm.remove.accept")
        }
        /// Board C3x: "Leave" is lateText too, since it drops the changes.
        public var confirmIsDestructive: Bool { true }
        /// Board C3x: the leave card points at "←" (40, 140), 560 wide; the others sit centred.
        public var confirmPointsAtBack: Bool { confirm == .leave }

        public var confirmMessage: String? {
            switch confirm {
            case .removeOnce:
                return L10n.tr("editor.confirm.remove_once.message", DayText.long(original.date, calendar: calendar))
            case .removeSeries:
                let from = DayText.short(thisDay ?? today, calendar: calendar)
                return L10n.tr("editor.confirm.remove_series.message", clockOwner, from)
            default:
                return nil
            }
        }

        /// "Kid A's clock", or "both kids' clocks".
        private var clockOwner: String {
            switch form.audience {
            case let .kid(id):
                L10n.tr("editor.clock_owner.kid",
                        snapshot?.kids.first { $0.id == id }?.name ?? L10n.tr("editor.clock_owner.unknown"))
            case .both: L10n.tr("editor.clock_owner.both")
            }
        }

        /// The next date of the series that has not ended yet.
        public var skipCandidate: Day? {
            weeklyItem.flatMap {
                SeriesEdits.nextOccurrence(of: $0, from: today, nowMinute: nowMinute, holidays: holidays,
                                           calendar: calendar)
            }
        }

        /// Board G3: the day "This day" changes: the one just skipped, else the day G1 showed (spec G5
        /// "Which screens and days"), else the next one.
        public var thisDay: Day? { skippedDay ?? carriedDay ?? skipCandidate }

        /// From G1 (spec G5 "More G5 edges"): the day shown there when the series happens on it and it
        /// is not over; a day that has passed, or one without the series, moves on to the next day it
        /// happens after it (never before today).
        var carriedDay: Day? {
            guard let shownDay, let weekly = weeklyItem else { return nil }
            let from = max(shownDay, today)
            return SeriesEdits.nextOccurrence(of: weekly, from: from, nowMinute: from == today ? nowMinute : 0,
                                              holidays: holidays, calendar: calendar)
        }

        /// The side column's tabs show for an every-week item that still has a day ahead.
        public var showsScopeTabs: Bool { isEditingWeekly && thisDay != nil }
        public var isThisDay: Bool { showsScopeTabs && editScope == .thisDay }

        /// "Mon 9 Nov only" (board G3).
        public var thisDayTitle: String? {
            thisDay.map { L10n.tr("editor.this_day.only", DayText.short($0, calendar: calendar)) }
        }

        /// "Skip this day", or "Bring back this day" once skipped.
        public var skipTitle: String {
            skippedDay == nil ? L10n.tr("editor.this_day.skip") : L10n.tr("editor.this_day.bring_back")
        }

        /// Board G5's tabs: "Today", the next day of the changed series ("Tomorrow" or "Wed 18 Nov";
        /// none when it has no day in the next 14 days), "Date".
        public var fromWhenTabs: [(FromWhen, String)] {
            FromWhenTabs.tabs(next: nextDay, today: today, calendar: calendar)
        }

        /// The first day after today, within 14 days, that the changed series really happens: on its
        /// repeat (every week or every month), within its Runs (its end worked out: "End of term",
        /// "After n times"), not skipped, and not a school holiday when it skips them.
        var nextDay: Day? {
            let series = family.resolving([seriesEdit], calendar: calendar).first ?? seriesEdit
            return FromWhenTabs.nextDay(of: series, after: today, holidays: holidays, calendar: calendar)
        }

        /// Where the series splits for the card's choice.
        public var splitDay: Day {
            switch fromWhen {
            case .next?: nextDay ?? today
            case .date?: max(fromWhenDate, today)
            case .today?, nil: today
            }
        }

        public var fromWhenDateLabel: String { DayText.dayMonth(max(fromWhenDate, today), calendar: calendar) }
        public var fromWhenDateValue: Date { max(fromWhenDate, today).date(calendar: calendar) }

        /// The changed series as it would be saved (the card lists the days it drops).
        func split(newID: UUID) -> SeriesEdits.Split? {
            guard let weekly = weeklyItem else { return nil }
            return SeriesEdits.splitting(weekly, with: seriesEdit, from: splitDay, newID: newID, calendar: calendar)
        }

        /// Board G5's caption: "17 Nov and 24 Nov were changed and no longer fit. They'll be removed."
        public var fromWhenCaption: String? {
            guard let removed = split(newID: UUID())?.removed, !removed.isEmpty else { return nil }
            let list = DayText.list(removed.map { DayText.dayMonth($0, calendar: calendar) })
            return removed.count == 1 ? L10n.tr("from_when.removed.one", list) : L10n.tr("from_when.removed.many", list)
        }

        /// The form as the series' new version: its start and end from Runs when they changed.
        var seriesEdit: ScheduleItem {
            var item = form.item(id: weeklyItem?.id ?? UUID(), today: today)
            if let weekly = weeklyItem, let (from, until) = weekly.recurrence.range, item.recurrence.range != nil {
                let start = form.date == original.date ? from : form.date
                let end = form.runsEnd == original.runsEnd && form.untilDate == original.untilDate
                    && form.times == original.times ? until : form.until
                item.recurrence = item.recurrence.with(from: start, until: end)
                item.skippedDays = weekly.skippedDays
                item.dayChanges = weekly.dayChanges
            }
            return item
        }
    }

    public enum Action: BindableAction, Equatable {
        case task
        case loaded(ScheduleSnapshot?, family: FamilyCalendar)
        case binding(BindingAction<State>)
        case audienceTapped(Audience)
        case picturePicked(String)
        /// The "More" slot after the five pictures (board C3): opens or closes the popover.
        case morePicturesTapped
        case startPicked(Date)
        case endPicked(Date)
        case dayToggled(Weekday)
        case repeatChanged(ItemForm.Repeat)
        case dateTapped(Day)
        /// Board C3m: "{nth} {weekday}" (false) or "Day {d}" (true).
        case monthlyRuleTapped(byDate: Bool)
        case datePageTapped(Int)
        case saveTapped
        case saved(Bool)
        case backTapped
        case removeTapped
        case confirmAccepted
        case confirmCancelled
        case removed
        /// "Skip just …", or "Skipped … · Undo" once skipped.
        case skipRowTapped
        /// Going row (board C3g): None, Walk, Bus, Car or Taxi.
        case goingTapped(Domain.Way?)
        case leaveStepped(Int)
        /// "Uses Our buses ›": the app opens C2 for the item's kid.
        case busesRowTapped
        case skipSaved(ScheduleItem, skipped: Day?)
        case removeSeriesTapped
        /// Event rows (spec "Event form rows for 6b"): From, Bring, Medal.
        case fromRowTapped
        case fromPicked(String)
        /// Board F2: the Before row opens its card (bundles and Bring).
        case beforeRowTapped
        case beforeKidPicked(Kid.ID)
        case bundleToggled(MissionBundle.ID)
        /// Board F7: the Back row opens its card (the way home and its minutes).
        case backRowTapped
        case wayHomePicked(String)
        case homeAfterStepped(Int)
        case bringToggled(KitSlot)
        /// A circle on the Bring row: a thing toggles, "More" opens every picture.
        case bringCircleTapped(String)
        /// Done on a form card keeps its changes; Cancel or a tap outside puts the form back.
        case cardDoneTapped
        case cardClosed
        case medalToggled
        /// Runs (board G2): the start date, and the end card (kind, date, times, Done).
        case runsStartPicked(Date)
        case runsEndTapped
        case runsEndKindPicked(ItemForm.RunsEndKind)
        case runsUntilPicked(Date)
        case runsTimesStepped(Int)
        /// From card: the minutes after the event.
        case fromGapStepped(Int)
        /// No school days card: Skip or a set time, its start and end, how the kid goes.
        case noSchoolRowTapped
        case noSchoolSetTime(Bool)
        case noSchoolStartPicked(Date)
        case noSchoolEndPicked(Date)
        case noSchoolGoingTapped(Domain.Way?)
        /// Boards G2 / G3: the This day / All days tabs.
        case scopeTapped(Scope)
        /// Board G5: the choice, the date, Save and Cancel.
        case fromWhenPicked(FromWhen)
        case fromWhenDatePicked(Date)
        case fromWhenSaveTapped
        case fromWhenCancelTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// Saved, removed or left: the app pops this screen.
            case finished
            /// "Uses Our buses ›": open C2 for this kid.
            case openBuses(Kid.ID)
        }
    }

    @Dependency(\.scheduleStore) var scheduleStore
    @Dependency(\.holidays) var holidays
    @Dependency(\.schoolDirectory) var schoolDirectory
    @Dependency(\.uuid) var uuid

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .task:
                if state.isAdding, state.draftID == nil { state.draftID = uuid() }
                // Spec G5: every year the 14-day window touches (late December reads January too).
                let years = FromWhenTabs.years(from: state.today, calendar: state.calendar)
                return .run { [scheduleStore, holidays, schoolDirectory] send in
                    let snapshot = try? await scheduleStore.load()
                    var publicHolidays: [Day] = []
                    for year in years { publicHolidays += await holidays.holidays(year).map(\.day) }
                    let family = await schoolDirectory.family(kids: snapshot?.kids ?? [], publicHolidays: publicHolidays)
                    await send(.loaded(snapshot, family: family))
                }

            case let .loaded(snapshot, family):
                state.snapshot = snapshot
                // A new every-week item runs to the end of term when the kid's school has terms.
                if state.isAdding, state.form == state.original, family.termEnd(for: state.form.audience,
                                                                              from: state.form.date) != nil {
                    state.form.runsEnd = .term
                    state.original.runsEnd = .term
                }
                state.family = family
                return .none

            case .binding:
                state.saveError = nil
                return .none

            case let .audienceTapped(audience):
                state.saveError = nil
                state.form.audience = audience
                return .none

            case let .picturePicked(name):
                state.form.pickPicture(name)
                state.isPickingMorePictures = false
                return .none

            case .morePicturesTapped:
                state.isPickingMorePictures.toggle()
                return .none

            case let .startPicked(time):
                state.saveError = nil
                state.form.start = Day.minute(of: time, calendar: state.calendar)
                return .none

            case let .endPicked(time):
                state.saveError = nil
                state.form.end = Day.minute(of: time, calendar: state.calendar)
                return .none

            case let .dayToggled(day):
                state.saveError = nil
                if state.form.days.contains(day) { state.form.days.remove(day) } else { state.form.days.insert(day) }
                return .none

            case let .repeatChanged(repeats):
                // An every-week item cannot turn into a one-off here (board G2).
                if state.isEditingWeekly { return .none }
                state.form.repeats = repeats
                state.form.refreshMonthly(calendar: state.calendar)
                return .none

            case let .dateTapped(day):
                state.form.date = day
                state.form.refreshMonthly(calendar: state.calendar)
                return .none

            case let .monthlyRuleTapped(byDate):
                state.form.monthlyByDate = byDate
                state.form.refreshMonthly(calendar: state.calendar)
                return .none

            case let .datePageTapped(step):
                state.datePage = max(0, state.datePage + step)
                return .none

            case .saveTapped:
                guard state.canSave else { return .none }
                if let problem = state.problem {
                    state.showsProblems = true
                    state.scrollTarget = GrownupScrollTarget(id: problem.row.rawValue,
                                                             request: (state.scrollTarget?.request ?? 0) + 1)
                    return .none
                }
                if state.showsScopeTabs, let weekly = state.weeklyItem {
                    guard state.editScope == .thisDay, let day = state.thisDay else {
                        // All days asks from when first (board G5), on the day carried from G1 as This day
                        // moved it (spec G5, #250); from the List none, so Today.
                        let opening = FromWhenTabs.opening(shown: state.carriedDay, next: state.nextDay, today: state.today)
                        state.fromWhen = opening.choice
                        state.fromWhenDate = opening.date
                        return .none
                    }
                    state.isSaving = true
                    state.saveError = nil
                    let edit = state.form.item(id: weekly.id, today: state.today)
                    return saveAll([SeriesEdits.changing(weekly, on: day, to: edit)])
                }
                state.isSaving = true
                state.saveError = nil
                let id = state.editingItem?.id ?? uuid()
                return saveAll(state.isEditingWeekly ? [state.seriesEdit] : [state.form.item(id: id, today: state.today)])

            case let .fromWhenPicked(choice):
                state.fromWhen = choice
                return .none

            case let .fromWhenDatePicked(date):
                state.fromWhen = .date
                state.fromWhenDate = max(Day(date, calendar: state.calendar), state.today)
                return .none

            case .fromWhenCancelTapped:
                state.fromWhen = nil
                return .none

            case .fromWhenSaveTapped:
                guard let split = state.split(newID: uuid()), !state.isSaving else { return .none }
                state.fromWhen = nil
                state.isSaving = true
                state.saveError = nil
                return saveAll(split.items)

            case let .scopeTapped(scope):
                state.editScope = scope
                // Lists and Bring are the series' (This day has no Before or Back rows): they go back to
                // the item's, so nothing set on All days is dropped by a This-day save (#289 review).
                if scope == .thisDay {
                    state.form.lists = state.original.lists
                    state.form.bring = state.original.bring
                }
                return .none

            case let .goingTapped(way):
                state.form.setGoing(way)
                return .none

            case let .leaveStepped(step):
                state.form.stepLeave(step)
                return .none

            case .busesRowTapped:
                let kid: Kid.ID? = switch state.form.audience {
                case let .kid(id): id
                case .both: state.snapshot?.kids.first?.id
                }
                return kid.map { .send(.delegate(.openBuses($0))) } ?? .none

            case .skipRowTapped:
                guard !state.isSaving, let weekly = state.weeklyItem else { return .none }
                if let day = state.skippedDay {
                    state.isSaving = true
                    return save(SeriesEdits.unskipping(weekly, day: day), skipped: nil)
                }
                guard let day = state.thisDay else { return .none }
                state.isSaving = true
                return save(SeriesEdits.skipping(weekly, day: day), skipped: day)

            case let .skipSaved(item, skipped):
                state.isSaving = false
                state.weeklyItem = item
                state.skippedDay = skipped
                return .none

            case .removeSeriesTapped:
                state.confirm = .removeSeries
                return .none

            case .saved(true):
                // Stays "saving": the screen is leaving, and a late second tap must not save again.
                return .send(.delegate(.finished))

            case .saved(false):
                state.isSaving = false
                state.saveError = L10n.tr("editor.save_error")
                return .none

            case .backTapped:
                guard state.hasChanges else { return .send(.delegate(.finished)) }
                state.confirm = .leave
                return .none

            case .removeTapped:
                state.confirm = .removeOnce
                return .none

            case .confirmCancelled:
                state.confirm = nil
                return .none

            case .confirmAccepted:
                let confirm = state.confirm
                state.confirm = nil
                if confirm != .leave {
                    guard !state.isSaving else { return .none }
                    state.isSaving = true
                }
                switch confirm {
                case .leave:
                    return .send(.delegate(.finished))
                case .removeOnce:
                    guard let id = state.editingItem?.id else { return .none }
                    return .run { [scheduleStore] send in
                        do {
                            try await scheduleStore.delete(id)
                            await send(.removed)
                        } catch {
                            await send(.saved(false))
                        }
                    }
                case .removeSeries:
                    guard let weekly = state.weeklyItem else { return .none }
                    let ended = SeriesEdits.ending(weekly, before: state.thisDay ?? state.today,
                                                   calendar: state.calendar)
                    return .run { [scheduleStore] send in
                        do {
                            try await scheduleStore.save(ended)
                            await send(.saved(true))
                        } catch {
                            await send(.saved(false))
                        }
                    }
                case nil:
                    return .none
                }

            case .removed:
                return .send(.delegate(.finished))

            case .fromRowTapped:
                state.card = Card(kind: .from, was: state.form)
                return .none

            case let .fromPicked(id):
                if let choice = state.fromChoices.first(where: { State.choiceID($0.event) == id }) {
                    state.form.setFrom(choice)
                }
                return .none

            case .beforeRowTapped:
                state.card = Card(kind: .before, was: state.form)
                state.isPickingMoreBring = false
                state.beforeKid = state.listKids.first?.id
                return .none

            case let .beforeKidPicked(kid):
                state.beforeKid = kid
                return .none

            case let .bundleToggled(id):
                state.form.toggleBundle(id)
                return .none

            case .backRowTapped:
                state.card = Card(kind: .back, was: state.form)
                return .none

            case let .wayHomePicked(id):
                if let way = WayHome(rawValue: id) { state.form.setWayHome(way) }
                return .none

            case let .homeAfterStepped(step):
                state.form.stepHomeAfter(step)
                return .none

            case let .bringToggled(slot):
                state.form.toggleBring(slot.rawValue, id: uuid())
                return .none

            case let .bringCircleTapped(id):
                if id == State.bringMoreID {
                    state.isPickingMoreBring.toggle()
                } else if let slot = KitSlot(rawValue: id) {
                    state.form.toggleBring(slot.rawValue, id: uuid())
                }
                return .none

            case .cardDoneTapped:
                state.card = nil
                return .none

            case .cardClosed:
                if let was = state.card?.was { state.form = was }
                state.card = nil
                return .none

            case .medalToggled:
                state.form.toggleMedal()
                return .none

            case let .runsStartPicked(date):
                state.form.date = Day(date, calendar: state.calendar)
                // Board G2m: an every-month rule is made from the series' start.
                if state.form.repeats == .monthly { state.form.refreshMonthly(calendar: state.calendar) }
                return .none

            case .runsEndTapped:
                state.card = Card(kind: .runsEnd, was: state.form)
                return .none

            case let .runsEndKindPicked(kind):
                state.form.runsEnd = kind
                if kind == .date, state.form.untilDate <= state.form.date {
                    state.form.untilDate = state.termEnd ?? state.form.date.adding(days: 28, calendar: state.calendar)
                }
                return .none

            case let .runsUntilPicked(date):
                state.form.untilDate = max(Day(date, calendar: state.calendar), state.form.date)
                return .none

            case let .runsTimesStepped(step):
                state.form.stepTimes(step)
                return .none

            case let .fromGapStepped(step):
                state.form.stepGap(step)
                return .none

            case .noSchoolRowTapped:
                state.card = Card(kind: .noSchool, was: state.form)
                return .none

            case let .noSchoolSetTime(atSetTime):
                state.form.setNoSchool(atSetTime: atSetTime)
                return .none

            case let .noSchoolStartPicked(time):
                let start = Day.minute(of: time, calendar: state.calendar)
                // The end moves with the start, keeping the length.
                if let end = state.form.noSchoolEnd, let old = state.form.noSchoolStart {
                    state.form.noSchoolEnd = min(end + start - old, 1440)
                }
                state.form.noSchoolStart = start
                return .none

            case let .noSchoolEndPicked(time):
                let end = Day.minute(of: time, calendar: state.calendar)
                state.form.noSchoolEnd = end > (state.form.noSchoolStart ?? state.form.start) ? end : nil
                return .none

            case let .noSchoolGoingTapped(way):
                state.form.noSchoolWay = way
                return .none

            case .delegate:
                return .none
            }
        }
    }

    /// Saves the items (one, or a split series) and leaves on success.
    private func saveAll(_ items: [ScheduleItem]) -> Effect<Action> {
        .run { [scheduleStore] send in
            do {
                if items.count == 1 { try await scheduleStore.save(items[0]) } else { try await scheduleStore.saveAll(items) }
                await send(.saved(true))
            } catch {
                await send(.saved(false))
            }
        }
    }

    /// Skips are saved at once, without "Save changes" (board G2).
    private func save(_ item: ScheduleItem, skipped: Day?) -> Effect<Action> {
        .run { [scheduleStore] send in
            do {
                try await scheduleStore.save(item)
                await send(.skipSaved(item, skipped: skipped))
            } catch {
                await send(.saved(false))
            }
        }
    }
}
