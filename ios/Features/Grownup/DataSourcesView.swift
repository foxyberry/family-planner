import ComposableArchitecture
import CrayonKit
import DesignSystem
import Strings
import SwiftUI

/// Data sources: each data set's name, its licence notice and the licence link.
public struct DataSourcesView: View {
    @Environment(\.sizing) private var sizing
    let store: StoreOf<DataSourcesFeature>

    public init(store: StoreOf<DataSourcesFeature>) {
        self.store = store
    }

    public var body: some View {
        // Spec "Scrolling": the card stays put and its rows scroll inside it.
        GrownupScreen(scrolls: false) {
            GrownupHeader(title: store.title, caption: store.headerCaption,
                          onBack: { store.send(.backTapped) })
        } content: { layout in
            PaperCard(seed: 41) {
                ScrollColumn {
                VStack(alignment: .leading, spacing: sizing(Spacing.m)) {
                    Text(store.intro).crayonType(.body).foregroundStyle(CrayonColor.ink)
                    ForEach(store.sources) { source in
                        VStack(alignment: .leading, spacing: sizing(Spacing.xs)) {
                            Text(source.name).crayonType(.body, bold: true).foregroundStyle(CrayonColor.ink)
                            Text(source.attribution).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                                .fixedSize(horizontal: false, vertical: true)
                            if let url = URL(string: source.licenceURL) {
                                Link(store.licenceTitle, destination: url)
                                    .crayonType(.caption).foregroundStyle(CrayonColor.link)
                            }
                        }
                    }
                    Text(store.noEndorsement).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: layout.editorRowsWidth, alignment: .leading)
                }
            }
            .frame(width: layout.form.width, height: layout.form.height)
        } primaryAction: { _ in
            EmptyView()
        }
        .task { await store.send(.task).finish() }
    }
}
