//
//  ContentView.swift
//  PickOne
//
//  Created by César González on 19/1/26.
//
//  TEMPORARY: Test UI for validating refactored HTTPClient
//

import SwiftUI

struct ContentView: View {
    
    @State private var testResult: TestResult?
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
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
                    
                    Spacer().frame(height: 20)
                    
                    // Status Card
                    VStack(spacing: 12) {
                        Text("🚧 Testing Refactored HTTPClient")
                            .font(.headline)
                        
                        Text("✨ No CodingKeys - Auto snake_case conversion")
                            .font(.caption)
                            .foregroundStyle(.green)
                        
                        Text("Check console for DEBUG logs 🌐✅❌")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Test Button
                    Button(action: testRefactoredHTTPClient) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "network")
                                Text("Test Refactored HTTPClient")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isLoading ? Color.gray : Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal)
                    
                    // Test Results
                    if let result = testResult {
                        TestResultView(result: result)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("PickOne - Test")
        }
    }
    
    // MARK: - Test Function
    
    private func testRefactoredHTTPClient() {
        isLoading = true
        testResult = nil
        
        print("🧪 Starting HTTPClient refactor test...")
        
        Task {
            do {
                // Create HTTP Client with refactored code
                let httpClient = URLSessionHTTPClient(
                    baseURL: AppConfiguration.tmdbBaseURL
                )
                
                // Create TMDB Client
                let tmdbClient = MovieCatalogClient(
                    httpClient: httpClient,
                    apiKey: AppConfiguration.tmdbAPIKey
                )
                
                // Test API call (check console for DEBUG logs!)
                let response = try await tmdbClient.getTopRated(page: 1)
                
                print("✅ Test successful! Received \(response.results.count) movies")
                
                // Success
                await MainActor.run {
                    testResult = .success(
                        movieCount: response.results.count,
                        movies: response.results.prefix(5).map { movie in
                            MovieInfo(
                                title: movie.title,
                                year: String(movie.releaseDate.prefix(4)),
                                rating: movie.voteAverage
                            )
                        }
                    )
                    isLoading = false
                }
                
            } catch {
                print("❌ Test failed: \(error)")
                
                // Failure
                await MainActor.run {
                    testResult = .failure(error: error.localizedDescription)
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Test Result Models

enum TestResult {
    case success(movieCount: Int, movies: [MovieInfo])
    case failure(error: String)
}

struct MovieInfo {
    let title: String
    let year: String
    let rating: Double
}

// MARK: - Test Result View

struct TestResultView: View {
    let result: TestResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch result {
            case .success(let count, let movies):
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Refactor Successful!")
                        .font(.headline)
                }
                
                Text("Received \(count) movies from TMDB")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text("✅ Auto snake_case → camelCase working!")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.top, 4)
                
                Divider()
                
                Text("Top 5 Movies:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ForEach(movies.indices, id: \.self) { index in
                    HStack {
                        Text("\(index + 1).")
                            .foregroundStyle(.secondary)
                            .frame(width: 20, alignment: .leading)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(movies[index].title)
                                .font(.subheadline)
                            Text(movies[index].year)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", movies[index].rating))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Text("📋 Check Xcode console for DEBUG logs")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .padding(.top, 8)
                
            case .failure(let error):
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text("Refactor Failed")
                        .font(.headline)
                }
                
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    ContentView()
}
