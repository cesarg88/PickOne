import SwiftUI

struct ContentView: View {
    let container: AppContainer
    @State private var isAPIKeyConfigured = AppConfiguration.isTMDBAPIKeyConfigured
        
    var body: some View {
        #if DEBUG
        if !isAPIKeyConfigured {
            APIKeySetupView {
                isAPIKeyConfigured = AppConfiguration.isTMDBAPIKeyConfigured
            }
        } else {
            DiscoveryView(
                model: container.discoveryViewModel,
                getMovieDetail: container.getMovieDetail,
                imagePipeline: container.imagePipeline
            )
        }
        #else
        DiscoveryView(
            model: container.discoveryViewModel,
            getMovieDetail: container.getMovieDetail,
            imagePipeline: container.imagePipeline
        )
        #endif
    }
}
