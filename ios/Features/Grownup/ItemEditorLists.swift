import DesignSystem
import Domain
import Foundation
import KitArt
import Localization
import Strings

// Spec "Event form rows" (issue 024, boards G2b, F2, F2k, F7, layout v77): the Before row (bundles and
// Bring) and the Back row (the way home), with their cards. Every word and choice comes from here.
extension ItemEditorFeature.State {
    public var beforeLabel: String { strings.tr("editor.row.before") }
    public var backLabel: String { strings.tr("editor.row.back") }
    public var bundlesCaption: String { strings.tr("before.bundles") }
    public var bringCaption: String { strings.tr("before.bring") }
    public var takesLabel: String { strings.tr("back.takes") }

    /// The kids the event is for, in family order.
    var listKids: [Kid] {
        (snapshot?.kids ?? []).filter { form.audience.includes($0.id) }
    }

    /// Board F2k: kid tabs beside the title, only for an event of more than one kid.
    public var beforeKidTabs: [(Kid.ID, String, KidFace.Badge?)] {
        guard listKids.count > 1 else { return [] }
        return listKids.map { ($0.id, $0.name, KidFace.Badge(face: $0.face, colorIndex: $0.colorIndex)) }
    }

    /// The Before card's kid: the picked tab, else the event's first kid.
    public var beforeKidShown: Kid.ID? { beforeKid ?? listKids.first?.id }

    /// Board F2 "Bundles": the shown kid's bundles, the picked ones on.
    public var bundleChips: [BundleChip] {
        (snapshot?.bundles ?? []).filter { $0.kid == beforeKidShown }.map { bundle in
            BundleChip(id: bundle.id, name: bundle.name, isOn: form.lists.before.contains(bundle.id))
        }
    }

    /// Before is shown on outings only: an item with a trip, or one linked after another event.
    public var showsBefore: Bool { form.trip != nil || form.after != nil }

    /// Back is only on an outing that ends its chain: no other item follows it on every day it runs
    /// (a follower on some days leaves the rest to this one).
    public var showsBack: Bool {
        guard showsBefore else { return false }
        guard let id = editingItem?.id else { return true }
        return !(snapshot?.items ?? []).contains { $0.after == .item(id) && form.days.isSubset(of: $0.weeklyDays) }
    }
    /// The Back row with no way home (spec: "None").
    public var backNoneText: String { strings.tr("going.none") }

    /// The Before row's value (spec): the picked bundles' names, then the Bring names; nil is "Nothing".
    public var beforeText: String? {
        let names = (snapshot?.bundles ?? []).filter { form.lists.before.contains($0.id) }.map(\.name) + form.bring.map(\.name)
        return names.isEmpty ? nil : names.joined(separator: " · ")
    }
    /// The first Bring picture beside the Before row's words.
    public var beforePicture: KitSlot? { form.bring.first.flatMap { KitSlot(rawValue: $0.picture) } }

    /// Board F7: Pickup, Bus, Walk, None.
    public var backChoices: [ChoiceCircles.Choice] { BackCopy.choices(form.lists.wayHome, strings: strings) }
    /// "Takes" is hidden for None.
    public var showsTakes: Bool { form.lists.wayHome != .none }
    /// Board F7's "Takes" stepper; nil for None.
    public var backTakes: BackCard.Stepper? {
        guard showsTakes else { return nil }
        return BackCard.Stepper(label: takesLabel, value: homeAfterText, canMinus: form.homeAfterEnds.canLower,
                                canPlus: form.homeAfterEnds.canRaise)
    }
    public var homeAfterText: String { strings.tr("c2.minutes", form.lists.homeAfter) }
    /// The Back row's value: "{Way} · {n} min" with the way's picture; nil is "None".
    public var backText: String? { BackCopy.text(form.lists, strings: strings) }
    public var backPicture: KitSlot? { BackCopy.picture(form.lists) }
}

/// The Back row and card's words and choices (board F7), shared by the item editor and G4.
enum BackCopy {
    static func choices(_ way: WayHome, strings: Localizer) -> [ChoiceCircles.Choice] {
        [
            ChoiceCircles.Choice(id: WayHome.pickup.rawValue, picture: .car, caption: strings.tr("back.pickup"),
                                 isPicked: way == .pickup),
            ChoiceCircles.Choice(id: WayHome.bus.rawValue, picture: .busDouble, caption: strings.tr("going.bus"),
                                 isPicked: way == .bus),
            ChoiceCircles.Choice(id: WayHome.walk.rawValue, picture: .shoe, caption: strings.tr("going.walk"),
                                 isPicked: way == .walk),
            ChoiceCircles.Choice(id: WayHome.none.rawValue, picture: nil, caption: strings.tr("going.none"),
                                 isPicked: way == .none),
        ]
    }

    /// "{Way} · {n} min"; nil for None.
    static func text(_ lists: EventLists, strings: Localizer) -> String? {
        guard lists.wayHome != .none, let choice = choices(lists.wayHome, strings: strings).first(where: \.isPicked) else {
            return nil
        }
        return strings.tr("back.value", choice.caption, strings.tr("c2.minutes", lists.homeAfter))
    }

    static func picture(_ lists: EventLists) -> KitSlot? {
        choices(lists.wayHome, strings: .keys).first(where: \.isPicked)?.picture
    }
}

