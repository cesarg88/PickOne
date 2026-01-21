import SwiftUI

struct APIKeySetupView: View {
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.system(size: 42))
                .foregroundStyle(.orange)
            
            Text("TMDB API Key missing")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Add TMDB_API_KEY via your Run Scheme or Debug xcconfig.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                onRetry()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .accessibilityElement(children: .combine)
    }
}
