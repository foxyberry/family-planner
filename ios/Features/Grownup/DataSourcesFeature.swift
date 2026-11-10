import ComposableArchitecture
import SchoolDirectory

/// Data sources (spec S2): the notices the Singapore Open Data Licence asks for, for the school
/// list (data.gov.sg) and its map positions (OneMap). Opened from Settings.
@Reducer
public struct DataSourcesFeature {
    @ObservableState
    public struct State: Equatable {
        public var sources: [DataSource] = []

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
