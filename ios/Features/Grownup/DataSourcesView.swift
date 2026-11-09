import ComposableArchitecture
import CrayonKit
import DesignSystem
import Strings
import SwiftUI

/// Data sources: each data set's name, its licence notice and the licence link.
public struct DataSourcesView: View {
    let store: StoreOf<DataSourcesFeature>

    public init(store: StoreOf<DataSourcesFeature>) {
        self.store = store
    }

    public var body: some View {
        GrownupScreen {
            GrownupHeader(title: L10n.tr("sources.title"), onBack: { store.send(.backTapped) })
        } content: { layout in
            PaperCard(seed: 41) {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    Text(L10n.tr("sources.intro")).crayonType(.body).foregroundStyle(CrayonColor.ink)
                    ForEach(store.sources) { source in
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(source.name).crayonType(.body, bold: true).foregroundStyle(CrayonColor.ink)
                            Text(source.attribution).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                                .fixedSize(horizontal: false, vertical: true)
                            if let url = URL(string: source.licenceURL) {
                                Link(L10n.tr("sources.licence"), destination: url)
                                    .crayonType(.caption).foregroundStyle(CrayonColor.link)
                            }
                        }
                    }
                    Text(L10n.tr("sources.no_endorsement")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: layout.form.width - 2 * layout.formInset, alignment: .leading)
            }
            .frame(width: layout.form.width)
        } primaryAction: { _ in
            EmptyView()
        }
        .task { await store.send(.task).finish() }
    }
}
