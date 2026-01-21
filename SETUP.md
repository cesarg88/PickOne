# PickOne — Setup Instructions

## ✅ Phase 0: Setup COMPLETE

### What's Been Created

#### 1. **Configuration Layer**
- `Core/Configuration/AppConfiguration.swift`
  - Centralized config for API keys
  - Cache TTL settings
  - UI constants

#### 2. **Data Layer — Foundation**

**DTOs (Data Transfer Objects):**
- `Data/DTOs/MovieDTO.swift`
  - Complete TMDB response models
  - Proper snake_case → camelCase mapping

**Network Infrastructure:**
- `Data/Network/HTTPClient.swift` — Generic async HTTP client
- `Data/Network/NetworkError.swift` — Error types with handling

**Clients:**
- `Data/Clients/MovieCatalogClient.swift`
  - `getTopRated(page:)`
  - `getMovieDetail(id:)`
  - `getSimilarMovies(id:page:)`
  - `searchMovies(query:page:)`
  - `getMovieCredits(id:)`

**Persistence:**
- `Data/Persistence/LocalStore.swift`
  - UserDefaults wrapper
  - Watchlist IDs management
  - Watched status tracking
  - Search history

#### 3. **Domain Layer — Models**

**Core Models:**
- `Domain/Models/Movie.swift`
  - `Movie` (full detail)
  - `MovieSummary` (for lists)
  - `Genre`, `Person`, `PersonRole`

- `Domain/Models/Watchlist.swift`
  - `WatchlistItem`
  - `WatchlistStatus`

- `Domain/Models/Snapshots.swift`
  - `DiscoverySnapshot`
  - `MovieDetailSnapshot`
  - `WatchlistSnapshot`
  - `ChatRecommendationSnapshot`
  - `SearchSnapshot`

#### 4. **Presentation Layer — Template**
- `ContentView.swift` — Temporary placeholder
- `PickOneApp.swift` — Clean app entry point

---

## 🔧 Next Steps: Configure TMDB API Key

### Step 1: Get Your API Key
1. Go to: https://developer.themoviedb.org/reference/getting-started
2. Sign up / Log in
3. Generate an **API Read Access Token** (Bearer token)

### Step 2: Add API Key (Debug)
In Xcode: **Product → Scheme → Edit Scheme** (⌘<) → **Run → Arguments**
Add an environment variable:
- **Name:** `TMDB_API_KEY`
- **Value:** your Bearer token

> Do not hardcode secrets in the repo.

### Step 3: Release Builds
Configure `TMDB_API_KEY` in the Release `.xcconfig` used by the app target.

### Step 4: Verify Setup
Build the project in Xcode:
```bash
⌘ + B (Build)
```

If the key is missing in Debug, the app shows a setup screen with a Retry button.

---

## 📁 Folder Structure Created

```
PickOne/
├── Core/
│   └── Configuration/
│       └── AppConfiguration.swift ✅
│
├── Data/
│   ├── DTOs/
│   │   └── MovieDTO.swift ✅
│   ├── Network/
│   │   ├── HTTPClient.swift ✅
│   │   └── NetworkError.swift ✅
│   ├── Clients/
│   │   └── MovieCatalogClient.swift ✅
│   └── Persistence/
│       └── LocalStore.swift ✅
│
├── Domain/
│   └── Models/
│       ├── Movie.swift ✅
│       ├── Watchlist.swift ✅
│       └── Snapshots.swift ✅
│
└── Presentation/
    ├── ContentView.swift ✅
    └── PickOneApp.swift ✅
```

---

## 🚀 Ready for Phase 1

Once your API key is configured, we're ready to proceed with:

**Phase 1: Data Layer Foundation**
- Implement repositories
- Add caching logic
- Test TMDB integration
- Validate DTO parsing

---

## 📝 Notes

- SwiftData removed (not needed for MVP)
- UserDefaults used for local persistence
- Architecture follows strict layering (Data → Domain → Presentation)
- No third-party dependencies yet (pure Swift/SwiftUI)

---

**Status:** 🟢 Phase 0 Complete — Waiting for API Key
