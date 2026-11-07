import ComposableArchitecture

/// Debug destination that shows the design-system gallery. No state of its own; it exists as a
/// second StackState destination next to parent mode.
@Reducer
public struct GalleryFeature {
    @ObservableState
    public struct State: Equatable {
        public init() {}
    }

    public enum Action {}

    public init() {}

    public var body: some ReducerOf<Self> {
        EmptyReducer()
    }
}
