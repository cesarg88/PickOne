# PickOne — Setup

This document explains how to configure and run the PickOne project locally using Xcode.

---

## Requirements

- macOS with Xcode 15+
- iOS 17+ Simulator or physical device
- A TMDB (The Movie Database) account

---

## Step 1: Get a TMDB API Key

1. Go to: https://developer.themoviedb.org/reference/getting-started
2. Sign up or log in.
3. Generate an **API Read Access Token (Bearer token)**.

You will use this token in the next step.

---

## Step 2: Configure the API Key (Local Development)

This project uses **xcconfig files** to inject the TMDB API key at build time.  
The API key is **not committed** to the repository.

1. Copy the example configuration file:

   ```bash
   cp Config/Debug.xcconfig.example Config/Debug.xcconfig

	2.	Open Config/Debug.xcconfig and replace the placeholder:

TMDB_API_KEY = YOUR_TMDB_API_KEY_HERE


	3.	Save the file.

⚠️ Do not commit Debug.xcconfig or Release.xcconfig.
These files are intentionally ignored by git.

⸻

Step 3: Open the Project in Xcode
	1.	Open PickOne.xcodeproj in Xcode.
	2.	Select the PickOne scheme.
	3.	Choose an iOS Simulator or a physical device.

⸻

Step 4: Build and Run
	1.	Press ⌘ + B to build the project.
	2.	Press ⌘ + R to run the app.

If the TMDB API key is correctly configured, the app will launch normally.

If the key is missing or invalid, the app will fail fast at launch with a clear configuration error.

⸻

CI / Release Builds (Optional)

For automated builds (e.g. GitHub Actions, Xcode Cloud):
	1.	Store TMDB_API_KEY as a secret in your CI environment.
	2.	Generate the Release config during the build:

echo "TMDB_API_KEY = $TMDB_API_KEY" > Config/Release.xcconfig



No API keys should ever be committed to the repository.

⸻

Troubleshooting
	•	App fails at launch
Ensure TMDB_API_KEY is set correctly in Debug.xcconfig.
	•	401 Unauthorized responses
Verify that you are using the API Read Access Token (Bearer token), not the legacy v3 API key.

⸻

Notes
	•	API keys are injected at build time via xcconfig.
	•	For production-scale usage, the TMDB API should be accessed through a backend proxy.

---
