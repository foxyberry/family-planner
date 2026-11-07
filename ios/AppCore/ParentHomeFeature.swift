import ComposableArchitecture

/// Placeholder for parent mode (settings, limits, imports arrive in M1+).
@Reducer
public struct ParentHomeFeature {
    @ObservableState
    public struct State: Equatable {
        public init() {}
    }

    public enum Action {
        case doneButtonTapped
    }

    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .doneButtonTapped:
                return .run { [dismiss] _ in await dismiss() }
            }
        }
    }
}
