import ComposableArchitecture
import Localization
import SchoolDirectory
import Strings

/// Data sources (spec S2): the notices the Singapore Open Data Licence asks for, for the school
/// list (data.gov.sg) and its map positions (OneMap). Opened from Settings.
@Reducer
public struct DataSourcesFeature {
    @ObservableState
    public struct State: Equatable {
        public var strings = Localizer.injected
        public var sources: [DataSource] = []

        /// The screen's words: title, the intro, each source's licence link, and the closing note.
        public var title: String { strings.tr("sources.title") }
        public var intro: String { strings.tr("sources.intro") }
        public var licenceTitle: String { strings.tr("sources.licence") }
        public var noEndorsement: String { strings.tr("sources.no_endorsement") }

        public init() {}
    }

    public enum Action: Equatable {
        case task
        case loaded([DataSource])
        case backTapped
    }

    @Dependency(\.schoolDirectory) var schoolDirectory

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .run { [schoolDirectory] send in await send(.loaded(await schoolDirectory.sources())) }
            case let .loaded(sources):
                state.sources = sources
                return .none
            case .backTapped:
                return .none
            }
        }
    }
}
