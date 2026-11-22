import ComposableArchitecture
import CrayonKit
import DesignSystem
import SwiftUI

/// C2c · A bus that changes (board C2c, v61): From, First bus, Then, Ride 1 (one per first bus),
/// Change, Ride 2; the side column names the bus and, for one that exists, "Remove this bus".
public struct ChangeBusesView: View {
    @Bindable var store: StoreOf<ChangeBusesFeature>
    @Environment(\.sizing) private var sizing

    public init(store: StoreOf<ChangeBusesFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            screen
            if let words = store.confirmWords {
                let card = ConfirmCard(title: words.title, titleGlyph: words.titleGlyph,
                                       message: nil, cancel: words.cancel, confirm: words.accept, isDestructive: true,
                                       onCancel: { store.send(.confirmCancelled) },
                                       onConfirm: { store.send(.confirmAccepted) })
                if store.confirmPointsAtBack {
                    // Board C3x: the dim starts under the header, and the card points at "←".
                    CrayonColor.dim.padding(.horizontal, -sizing.bleed).ignoresSafeArea(edges: .bottom)
                        .padding(.top, sizing.y(124))
                        .onTapGesture { store.send(.confirmCancelled) }
                    card.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.leading, sizing.x(40))
                        .padding(.top, sizing.y(140))
                        .ignoresSafeArea(.container, edges: .top)
                } else {
                    // As G2's "Remove every week": the card over the dimmed screen.
                    CrayonColor.dim.fullBleed()
                        .onTapGesture { store.send(.confirmCancelled) }
                    card
                }
            }
        }
        .task { await store.send(.task).finish() }
    }

    private var screen: some View {
        GrownupScreen(scrolls: false) {
            GrownupHeader(title: store.title, caption: store.headerCaption,
                          onBack: { store.send(.backTapped) })
        } content: { layout in
            HStack(alignment: .top, spacing: layout.gap) {
                PaperCard(seed: 52) {
                    ScrollColumn(bleed: sizing.drawnBleed) {
                        rows(layout).frame(width: layout.editorRowsWidth, alignment: .leading)
                    }
                }
                .frame(width: layout.form.width, height: layout.form.height, alignment: .top)
                ScrollColumn { side }
                    .frame(width: layout.side.width, height: layout.action.minY - layout.side.minY - sizing(Spacing.s),
                           alignment: .topLeading)
            }
        } primaryAction: { layout in
            InkButton(store.saveTitle, isEnabled: store.canSave) { store.send(.saveTapped) }
                .frame(width: layout.side.width)
        }
    }

    /// Board C2c (layout v61): rows 24 apart between drawn edges; From is a text row drawn to its
    /// edge, the pills, field and steppers lay out their drawn box.
    private func rows(_ layout: GrownupLayout) -> some View {
        VStack(alignment: .leading, spacing: layout.sizing.formRowGap) {
            ListRow(leading: store.fromLabel, minHeight: 0) {
                HStack(alignment: .firstTextBaseline, spacing: sizing(Spacing.s)) {
                    Text(store.fromName).crayonType(.body, bold: true).foregroundStyle(CrayonColor.ink)
                    Text(store.ourStopCaption).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                }
            }
            firstBuses(layout)
            // Board C2c: the second bus is typed (160 × 80), checked against LTA's service list.
            ListRow(leading: store.thenLabel, labelHeight: sizing.fieldHeight) {
                VStack(alignment: .leading, spacing: sizing.captionGap) {
                    CrayonField(store.thenPlaceholder,
                                text: Binding(get: { store.thenText }, set: { store.send(.thenChanged($0)) }))
                        .keyboardType(.asciiCapable)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .fieldProblem(store.thenHasProblem)
                        .frame(width: sizing(FormLines.busNumberField))
                    if let caption = store.thenCaption {
                        Text(caption).crayonType(.caption).foregroundStyle(CrayonColor.hurry)
                    }
                }
            }
            .captionedRow(hasCaption: store.thenHasProblem)
            ForEach(store.ride1Rows) { row in
                stepper(row.label, text: row.text, caption: row.caption, value: row.minutes) {
                    store.send(.ride1Changed(service: row.service, minutes: $0))
                }
            }
            stepper(store.changeLabel, text: store.changeText, caption: store.changeCaption, value: store.change) {
                store.send(.changeChanged($0))
            }
            stepper(store.ride2Label, text: store.ride2Text, caption: store.ride2Caption, value: store.ride2) {
                store.send(.ride2Changed($0))
            }
        }
    }

    /// First bus: a pill (180 × 72) per bus at our stop, any number picked, as on C2; "No buses
    /// found" while the stop has none.
    private func firstBuses(_ layout: GrownupLayout) -> some View {
        ListRow(leading: store.firstBusLabel, minHeight: sizing.tabHeight(), labelHeight: sizing.tabHeight()) {
            if store.pills.isEmpty {
                Text(store.noBusesText).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                    .frame(height: sizing.tabHeight())
            } else {
                PillToggleGrid(controlWidth: layout.controlWidth) {
                    ForEach(store.pills) { pill in
                        PillToggle(pill.service, isOn: pill.isOn) { store.send(.firstBusTapped(pill.service)) }
                    }
                }
            }
        }
        .drawnRow()
    }

    /// Board C2c's side column (v61): the bus as a head ("12 · 34 → 33", the arrow drawn) and, when
    /// it exists, "Remove this bus" (472 × 88).
    private var side: some View {
        VStack(alignment: .leading, spacing: sizing(Spacing.s)) {
            switch store.head {
            case let .buses(name)?:
                Text(name).crayonType(.head).foregroundStyle(CrayonColor.ink)
            case let .change(format)?:
                GlyphText(format, glyph: .arrowRight, type: .head, color: CrayonColor.ink)
            case nil:
                EmptyView()
            }
            if let remove = store.removeTitle {
                RemoveButton(remove) { store.send(.removeTapped) }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func stepper(_ label: String, text: String, caption: String, value: Int,
                         change: @escaping (Int) -> Void) -> some View {
        ListRow(leading: label, minHeight: MinutesStepper.rowHeight(sizing)) {
            MinutesStepper(value: text, caption: caption,
                           minus: { change(value - 1) }, plus: { change(value + 1) })
        }
        .drawnRow()
    }
}
