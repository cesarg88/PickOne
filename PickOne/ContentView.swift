//
//  ContentView.swift
//  PickOne
//
//  Created by César González on 19/1/26.
//

import SwiftUI

struct ContentView: View {
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "film.stack")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                
                Text("PickOne")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Decide what to watch, quickly and confidently")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Text("🚧 MVP in Development")
                        .font(.headline)
                    
                    Text("Phase 0: Setup Complete ✅")
                        .font(.caption)
                        .foregroundStyle(.green)
                    
                    Text("Next: Data Layer Integration with TMDB")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("PickOne")
        }
    }
}

#Preview {
    ContentView()
}
