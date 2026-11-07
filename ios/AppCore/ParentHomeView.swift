import ComposableArchitecture
import SwiftUI

struct ParentHomeView: View {
    let store: StoreOf<ParentHomeFeature>

    var body: some View {
        VStack(spacing: 24) {
            Text("Parent mode").font(.largeTitle)
            Button("Done") { store.send(.doneButtonTapped) }
                .buttonStyle(.borderedProminent)
        }
        .navigationBarBackButtonHidden()
    }
}
