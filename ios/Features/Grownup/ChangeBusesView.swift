import ComposableArchitecture
import CrayonKit
import DesignSystem
import Strings
import SwiftUI

/// C2c · A bus that changes (board C2c, v57): From, First bus, Then, Ride 1, Change, Ride 2.
public struct ChangeBusesView: View {
    @Bindable var store: StoreOf<ChangeBusesFeature>
    @Environment(\.sizing) private var sizing

    public init(store: StoreOf<ChangeBusesFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            screen
            if store.isConfirmingLeave {
                // Board C3x: the dim starts under the header, and the card points at "←".
                CrayonColor.dim.ignoresSafeArea(edges: .bottom)
                    .padding(.top, sizing.y(124))
                    .onTapGesture { store.send(.leaveCancelled) }
                ConfirmCard(title: L10n.tr("editor.confirm.leave.title"), message: nil,
                            cancel: L10n.tr("editor.confirm.leave.cancel"), confirm: L10n.tr("editor.confirm.leave.accept"),
                            isDestructive: true,
                            onCancel: { store.send(.leaveCancelled) }, onConfirm: { store.send(.leaveConfirmed) })
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, sizing.left(40))
                    .padding(.top, sizing.y(140))
                    .ignoresSafeArea(.container, edges: .top)
            }
        }
        .task { await store.send(.task).finish() }
    }

    private var screen: some View {
        GrownupScreen(scrolls: false) {
            GrownupHeader(title: store.title, onBack: { store.send(.backTapped) })
        } content: { layout in
            HStack(alignment: .top, spacing: layout.gap) {
                PaperCard(seed: 52) {
                    ScrollColumn {
                        rows(layout).frame(width: layout.editorRowsWidth, alignment: .leading)
                    }
                }
                .frame(width: layout.form.width, height: layout.form.height, alignment: .top)
                Color.clear.frame(width: layout.side.width, height: 1)
            }
        } primaryAction: { layout in
            InkButton(L10n.tr("c2c.save")) { store.send(.saveTapped) }
                .disabled(!store.canSave)
                .frame(width: layout.side.width)
        }
    }

    /// Board C2c (layout v58): rows 24 apart between drawn edges; From is a text row drawn to its
    /// edge, the pills, field and steppers lay out their drawn box.
    private func rows(_ layout: GrownupLayout) -> some View {
        VStack(alignment: .leading, spacing: layout.sizing.formRowGap) {
            ListRow(leading: L10n.tr("c2c.from"), minHeight: 0) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                    Text(store.fromName).crayonType(.body, bold: true).foregroundStyle(CrayonColor.ink)
                    Text(L10n.tr("c2c.our_stop")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                }
            }
            pills(L10n.tr("c2c.first_bus"), controlWidth: layout.controlWidth, services: store.firstBuses, picked: store.firstBus) {
                store.send(.firstBusTapped($0))
            }
            // Board C2c: the second bus is typed (160 × 80), checked against LTA's service list.
            ListRow(leading: L10n.tr("c2c.then"), labelHeight: 80) {
                VStack(alignment: .leading, spacing: FormLines.captionGap) {
                    CrayonField(L10n.tr("c2c.then.placeholder"),
                                text: Binding(get: { store.thenText }, set: { store.send(.thenChanged($0)) }))
                        .keyboardType(.asciiCapable)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .fieldProblem(store.thenHasProblem)
                        .frame(width: FormLines.busNumberField)
                    if let caption = store.thenCaption {
                        Text(caption).crayonType(.caption).foregroundStyle(CrayonColor.hurry)
                    }
                }
            }
            // Drawn on both edges without a caption; with one, the caption draws to its own edge.
            .padding(.top, -CrayonPart.inset)
            .padding(.bottom, store.thenCaption == nil ? -CrayonPart.inset : 0)
            stepper(L10n.tr("c2c.ride1"), text: store.ride1Text, caption: store.ride1Caption, value: store.ride1) {
                store.send(.ride1Changed($0))
            }
            stepper(L10n.tr("c2c.change"), text: store.changeText, caption: L10n.tr("c2c.change.caption"),
                    value: store.change) {
                store.send(.changeChanged($0))
            }
            stepper(L10n.tr("c2c.ride2"), text: store.ride2Text, caption: store.ride2Caption, value: store.ride2) {
                store.send(.ride2Changed($0))
            }
        }
    }

    /// Bus pills (180 × 72), one picked; "No buses found" while the stop has none.
    private func pills(_ label: String, controlWidth: CGFloat, services: [String], picked: String?,
                       tap: @escaping (String) -> Void) -> some View {
        ListRow(leading: label, minHeight: sizing.tabHeight(), labelHeight: sizing.tabHeight()) {
            if services.isEmpty {
                Text(L10n.tr("c2.buses.none")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                    .frame(height: PillToggle.size.height)
            } else {
                PillToggleGrid(controlWidth: controlWidth) {
                    ForEach(services, id: \.self) { service in
                        PillToggle(service, isOn: picked == service) { tap(service) }
                    }
                }
            }
        }
        .drawnRow()
    }

    private func stepper(_ label: String, text: String, caption: String, value: Int,
                         change: @escaping (Int) -> Void) -> some View {
        ListRow(leading: label, minHeight: MinutesStepper.rowHeight(sizing)) {
            MinutesStepper(value: text, caption: caption, spoken: label,
                           minus: { change(value - 1) }, plus: { change(value + 1) })
        }
        .drawnRow()
    }
}
