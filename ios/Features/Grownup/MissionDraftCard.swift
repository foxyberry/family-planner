import DesignSystem
import Domain
import KitArt
import Strings
import SwiftUI

/// The C5 card that edits one mission (board C5): the name, the picture, Remove (not for a new one)
/// and Save. The morning missions (C5) and an item's missions before / after (spec "Event form rows
/// for 6b") use the same card.
struct MissionDraftCard: View {
    /// Morning pictures offered for a mission.
    static let pictures: [KitSlot] = [.star, .sun, .toilet, .toothbrush, .washFace, .hairBrush, .shirt, .actBreakfast,
                                      .milk, .babyBottle, .backpack, .lunchBox, .waterBottle, .shoe]

    let draft: MissionEditorFeature.Draft
    /// The card's words, from the caller's State.
    let nameLabel: String
    let removeLabel: String
    let saveTitle: String
    let onName: (String) -> Void
    let onPicture: (String) -> Void
    /// The Days row (C5 morning missions only; an item's missions have no days).
    var onDay: ((Weekday) -> Void)?
    let onRemove: () -> Void
    let onSave: () -> Void
    @Environment(\.sizing) private var sizing

    var body: some View {
        PaperCard(seed: 43) {
            VStack(alignment: .leading, spacing: sizing(Spacing.m)) {
                CrayonField(nameLabel, text: Binding(get: { draft.name }, set: onName))
                IconPicker(selection: Binding(get: { KitSlot(rawValue: draft.picture) },
                                              set: { if let slot = $0 { onPicture(slot.rawValue) } }),
                           slots: Self.pictures)
                if let days = draft.days, let onDay {
                    // Spec C5 "days per mission": seven DayChip 56, all on by default.
                    HStack(spacing: sizing(Spacing.sm)) {
                        ForEach(Weekday.allCases.sorted(), id: \.self) { day in
                            DayChip(DayText.initial(day), isOn: Binding(get: { days.contains(day) }, set: { _ in onDay(day) }),
                                    size: 56)
                        }
                    }
                }
                HStack(spacing: sizing(Spacing.m)) {
                    if !draft.isNew {
                        Button(action: onRemove) {
                            Text(removeLabel).crayonType(.body).foregroundStyle(CrayonColor.lateText)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    InkButton(saveTitle, isEnabled: draft.canSave, action: onSave)
                        .frame(width: sizing(240))
                }
            }
        }
        .frame(width: sizing(720))
    }
}
