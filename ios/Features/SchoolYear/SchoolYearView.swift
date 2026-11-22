import ComposableArchitecture
import DesignSystem
import SwiftUI

/// K1 · School calendar (boards K1, K1o, K1n): "‹", the year tabs and the key in the header, the
/// twelve month cards, and a tapped month open over the year. Every part is placed from
/// `SchoolYearLayout`; nothing scrolls.
public struct SchoolYearView: View {
    let store: StoreOf<SchoolYearFeature>
    @Environment(\.sizing) private var sizing

    public init(store: StoreOf<SchoolYearFeature>) {
        self.store = store
    }

    public var body: some View {
        let layout = SchoolYearLayout(sizing: sizing)
        // Board K1n: at night the tokens take their night values (the night mapping).
        KidFullScreen(look: store.look, nightTokens: true) {
            ZStack(alignment: .topLeading) {
                RoundButton(glyph: .chevronLeft) { store.send(.backTapped) }
                    .look(store.look)
                    .place(layout.back)
                if let screen = store.screen {
                    year(screen, layout: layout)
                    if let open = screen.open {
                        openMonth(open, weekdays: screen.openWeekdays, layout: layout)
                    }
                }
            }
            .frame(width: sizing.width, height: sizing.height, alignment: .topLeading)
        }
        .task { await store.send(.task).finish() }
    }

    @ViewBuilder private func year(_ screen: SchoolYearFeature.State.Screen, layout: SchoolYearLayout) -> some View {
        CrayonTabs(selection: Binding(get: { screen.pickedYear }, set: { store.send(.yearTapped($0)) }),
                   items: screen.tabs, itemSize: SchoolYearLayout.tabSize, spacing: SchoolYearLayout.tabGap,
                   neutral: true)
            .place(topLeft: layout.tabs)
        CalendarLegend(items: screen.legend)
            .frame(width: layout.legend.width, alignment: .topLeading)
            .place(topLeft: layout.legend.origin)
        ForEach(Array(screen.months.enumerated()), id: \.element.id) { index, month in
            Button { store.send(.monthTapped(month.month)) } label: {
                MonthCard(title: month.title, weekdays: screen.weekdays, weeks: month.weeks, size: .card,
                          seed: UInt32(index))
            }
            .buttonStyle(.plain)
            .place(topLeft: layout.card(index).origin)
        }
    }

    /// Board K1o: the dim layer (a tap on it closes), the month 860 × 800 and its "×".
    @ViewBuilder private func openMonth(_ month: SchoolYearFeature.State.Month, weekdays: [String],
                                        layout: SchoolYearLayout) -> some View {
        CrayonColor.dim
            .fullBleed()
            .contentShape(Rectangle())
            .onTapGesture { store.send(.dimTapped) }
        MonthCard(title: month.title, weekdays: weekdays, weeks: month.weeks, size: .open, seed: 12)
            // The card takes its own taps, so only a tap outside it closes the month.
            .onTapGesture {}
            .place(topLeft: layout.openCard.origin)
        RoundButton(glyph: .close) { store.send(.closeTapped) }
            .size(72)
            .look(store.look)
            .place(layout.openClose)
    }
}
