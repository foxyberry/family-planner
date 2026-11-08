import ComposableArchitecture

/// Destination that shows the design-system gallery, reached from parent mode. No state of its own;
/// its crayon Back button pops it (the navigation bar is hidden like on every grown-up screen).
@Reducer
public struct GalleryFeature {
    @ObservableState
    public struct State: Equatable {
        public init() {}
    }

    public enum Action: Equatable {
        case backTapped
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        EmptyReducer()
    }
}
