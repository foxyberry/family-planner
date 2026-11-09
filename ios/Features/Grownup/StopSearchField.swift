import ComposableArchitecture
import CrayonKit
import DesignSystem
import Strings
import SwiftUI

/// The stop field of C2 and S3 (boards C2, S3, v9): the field 400 × 80 on 232, its caption 8 below
/// (the check picture 32 once a stop is picked), and the matches as a card 40 below the field, over
/// the rows under it. Give the row holding it a higher `zIndex` so the card covers the next rows.
public struct StopSearchField: View {
    let store: StoreOf<StopSearchFeature>
    /// Rows that fit above the form card's bottom (layout v14: S3 6, C2 8); more scroll.
    let visibleRows: Int

    public init(store: StoreOf<StopSearchFeature>, visibleRows: Int) {
        self.store = store
        self.visibleRows = visibleRows
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            CrayonField(L10n.tr("c2.stop.placeholder"),
                        text: Binding(get: { store.text }, set: { store.send(.textChanged($0)) }))
                .frame(width: 400)
                .overlay(alignment: .topLeading) {
                    if store.isListOpen { matches.resultVeilHole().offset(y: 80 + Spacing.l) }
                }
            HStack(spacing: Spacing.xs) {
                if store.pickedStop != nil { CheckMark(isDone: true, size: 32) }
                Text(store.caption).crayonType(.caption).foregroundStyle(CrayonColor.softText)
            }
        }
        .resultVeilHole()
    }

    /// Stops matching the typed name: the shared result card, the name over road and code.
    private var matches: some View {
        ResultListCard(rows: store.matches.map { stop in
            .init(id: stop.code, title: stop.name, caption: L10n.tr("c2.stop.match", stop.road, stop.code)) {
                store.send(.stopPicked(stop))
            }
        }, visibleRows: visibleRows, seed: 55)
    }
}
