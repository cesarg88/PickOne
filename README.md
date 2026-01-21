# PickOne — Architecture Documentation

## 📐 Layered Architecture

PickOne follows a strict **3-layer architecture** with clear boundaries:

```
┌─────────────────────────────────────┐
│      Presentation Layer             │
│   (SwiftUI Views + ViewModels)      │
└─────────────────────────────────────┘
              ↓ Snapshots
┌─────────────────────────────────────┐
│        Domain Layer                 │
│  (Use Cases + Decision Engine)      │
└─────────────────────────────────────┘
              ↓ Interfaces
┌─────────────────────────────────────┐
│         Data Layer                  │
│  (Repositories + Clients + DTOs)    │
└─────────────────────────────────────┘
```

---

## 📁 Folder Structure

```
PickOne/
├── Core/
│   └── Configuration/
│       └── AppConfiguration.swift       # API keys, environment config
│
├── Data/                                # DATA LAYER
│   ├── DTOs/
│   │   └── MovieDTO.swift               # TMDB response models
│   ├── Network/
│   │   ├── HTTPClient.swift             # Generic HTTP client
│   │   └── NetworkError.swift           # Network error types
│   ├── Clients/
│   │   ├── MovieCatalogClient.swift     # TMDB API calls
│   │   └── AIRecommendationClient.swift # AI LLM calls (future)
│   ├── Persistence/
│   │   └── LocalStore.swift             # UserDefaults wrapper
│   └── Repositories/
│       ├── MovieRepository.swift        # DTO → Domain mapping + cache
│       ├── WatchlistRepository.swift
│       └── SearchRepository.swift
│
├── Domain/                              # DOMAIN LAYER
│   ├── Models/
│   │   ├── Movie.swift                  # Core domain models
│   │   ├── Watchlist.swift
│   │   └── Snapshots.swift              # Immutable UI snapshots
│   ├── UseCases/
│   │   ├── GetDiscoveryFeed.swift
│   │   ├── GetMovieDetail.swift
│   │   ├── GetWatchlist.swift
│   │   ├── SearchMovies.swift
│   │   ├── AddToWatchlist.swift
│   │   ├── MarkAsWatched.swift
│   │   └── GetAIRecommendations.swift
│   ├── Services/
│   │   ├── DecisionEngine.swift         # Ranking, filtering, constraints
│   │   └── SnapshotBuilder.swift        # Domain → Snapshot transformation
│   └── Interfaces/
│       └── (Protocols for dependency injection)
│
└── Presentation/                        # PRESENTATION LAYER
    ├── Screens/
    │   ├── Discovery/
    │   │   ├── DiscoveryView.swift
    │   │   └── DiscoveryViewModel.swift
    │   ├── MovieDetail/
    │   │   ├── MovieDetailView.swift
    │   │   └── MovieDetailViewModel.swift
    │   ├── Watchlist/
    │   │   ├── WatchlistView.swift
    │   │   └── WatchlistViewModel.swift
    │   ├── Search/
    │   │   ├── SearchView.swift
    │   │   └── SearchViewModel.swift
    │   └── AIChat/
    │       ├── AIChatView.swift
    │       └── AIChatViewModel.swift
    ├── Components/
    │   ├── MoviePosterCard.swift
    │   └── (Reusable UI components)
    └── Utilities/
        └── (Formatters, extensions)
```

---

## 🎯 Dependency Rules (Non-Negotiable)

1. **Presentation → Domain** (Use Cases only)
2. **Domain → Data** (Interfaces only, never implementations)
3. **Data → External APIs**
4. **DTOs never enter Domain**
5. **AI output never bypasses Domain logic**
6. **UI never manages decision rules**

---

## 🔄 Core Flows

### Flow 1: Discovery Feed
```
UI → GetDiscoveryFeed
  → MovieRepository (cache/fetch)
  → SnapshotBuilder
  ← DiscoverySnapshot
UI renders grid
```

### Flow 2: Movie Detail
```
UI → GetMovieDetail(id)
  → MovieRepository (detail + similar)
  → WatchlistRepository (status check)
  → SnapshotBuilder
  ← MovieDetailSnapshot
UI renders detail
```

### Flow 3: Add to Watchlist
```
UI → AddToWatchlist(id)
  → WatchlistRepository
  → LocalStore (persist)
  → GetWatchlist
  ← WatchlistSnapshot
UI updates
```

---

## ⚙️ Configuration

### TMDB API Key Setup

This project uses xcconfig files for secure API key management. The API key is **never** committed to the repository.

#### Local Development

1. Get your **API Read Access Token** (Bearer token) from: https://developer.themoviedb.org/reference/getting-started

2. Copy the example config files:
   ```bash
   cp Config/Debug.xcconfig.example Config/Debug.xcconfig
   cp Config/Release.xcconfig.example Config/Release.xcconfig
   ```

3. Edit `Config/Debug.xcconfig` and replace the placeholder:
   ```
   TMDB_API_KEY = your_actual_api_key_here
   ```

4. Build and run the project in Xcode

#### CI/CD Setup

For automated builds (GitHub Actions, Xcode Cloud, etc.):
- Store `TMDB_API_KEY` as a secret in your CI environment
- Generate the xcconfig file during the build:
  ```bash
  echo "TMDB_API_KEY = $TMDB_API_KEY" > Config/Release.xcconfig
  ```

> **Note:** The app will crash on launch with clear instructions if the API key is missing or not configured.

---

## 🧪 Testing Strategy

- **Data Layer:** Mock HTTPClient, test DTO parsing
- **Domain Layer:** Mock repositories, test use case orchestration
- **Decision Engine:** Unit tests for ranking/filtering logic
- **Presentation Layer:** SwiftUI previews with mock snapshots

---

## 📝 MVP Scope (Locked)

**IN SCOPE:**
1. Discovery Feed (Top Rated)
2. Movie Detail (with Similar)
3. Watchlist (To Watch / Watched)
4. Search (Movies, Actors, Directors)
5. AI Chat v0 (Stateless)
6. Local Persistence (No accounts)

**OUT OF SCOPE:**
- TV Shows
- Social features
- Streaming availability
- User accounts
- Multi-platform (iPad, Android)
- Monetization

---

## 🚀 Implementation Status

- [x] Phase 0: Setup & Folder Structure
- [ ] Phase 1: Data Layer (TMDB Integration)
- [ ] Phase 2: Domain Layer (Repositories)
- [ ] Phase 3: Domain Layer (Use Cases)
- [ ] Phase 4: Presentation (Discovery + Detail)
- [ ] Phase 5: Watchlist + Search
- [ ] Phase 6: AI Chat v0

---

## 📚 Key Documents

- Product Brief v1 (Context & Opportunity)
- MVP Scope Definition v1 (IN/OUT)
- Architecture Core — Skeleton v1
- Architecture Core — Policies v1

---

**Built with:** SwiftUI, Swift Concurrency, TMDB API
**Platform:** iOS 17+
**Language:** Swift 5.9+
