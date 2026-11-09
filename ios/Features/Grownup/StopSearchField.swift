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

    public init(store: StoreOf<StopSearchFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            CrayonField(L10n.tr("c2.stop.placeholder"),
                        text: Binding(get: { store.text }, set: { store.send(.textChanged($0)) }))
                .frame(width: 400)
                .overlay(alignment: .topLeading) {
                    if !store.matches.isEmpty { matches.offset(y: 80 + Spacing.l) }
                }
            HStack(spacing: Spacing.xs) {
                if store.pickedStop != nil { CheckMark(isDone: true, size: 32) }
                Text(store.caption).crayonType(.caption).foregroundStyle(CrayonColor.softText)
            }
        }
    }

    /// Stops matching the typed name: a white card of 64-tall rows, the name over road and code.
    private var matches: some View {
        PaperCard(seed: 55) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(store.matches.enumerated()), id: \.element.id) { index, stop in
                    if index > 0 { Rectangle().fill(CrayonColor.paper).frame(height: 2) }
                    Button { store.send(.stopPicked(stop)) } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(stop.name).crayonType(.body, bold: true).foregroundStyle(CrayonColor.link).lineLimit(1)
                            Text(L10n.tr("c2.stop.match", stop.road, stop.code)).crayonType(.caption)
                                .foregroundStyle(CrayonColor.softText).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .environment(\.cardInset, Spacing.m)
        .frame(width: 400)
    }
}
