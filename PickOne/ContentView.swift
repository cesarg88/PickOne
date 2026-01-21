import SwiftUI

struct ContentView: View {
    let container: AppContainer
        
    var body: some View {
        DiscoveryView(
            model: container.discoveryViewModel,
            getMovieDetail: container.getMovieDetail,
            imagePipeline: container.imagePipeline
        )
    }
}
