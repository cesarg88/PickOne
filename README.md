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
│       └── AppConfiguration.swift       # API keys, build config
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

1. Copy the template config:
   - `Config/Debug.xcconfig.example` → `Config/Debug.xcconfig`
2. Add your TMDB key to `Config/Debug.xcconfig`:
   - `TMDB_API_KEY = YOUR_TMDB_API_KEY_HERE`

**Release / CI**
- Use `Config/Release.xcconfig` with secrets injected by CI.
- Never commit real keys to the repo.

---

## 🧠 Cache Policy (MVP)

- Cache is **in-memory only** and **session-only**.
- No disk cache or persistence between launches in the MVP.

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
