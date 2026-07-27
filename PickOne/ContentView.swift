import SwiftUI

@MainActor
struct ContentView: View {
    let container: AppContainer
        
    var body: some View {
        DiscoveryView(
            model: container.discoveryViewModel,
            getMovieDetail: container.getMovieDetail,
            setMembership: container.setWatchlistMembership,
            setWatched: container.setWatched,
            imagePipeline: container.imagePipeline
        )
    }
}
