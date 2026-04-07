# Bus Tracker Driver App

Flutter driver app for sharing live bus location to Firebase Realtime Database.

## Overview

This app lets a driver:

- select a route and assigned bus/driver profile
- start a time-limited location sharing session
- push GPS updates to backend APIs and Firebase RTDB
- view current position in an embedded Google Map preview
- stop sharing manually or auto-stop when session expires

The app uses Firebase Cloud Functions endpoints to enforce one active session per bus.

## Tech Stack

- Flutter (Dart)
- Firebase Core + Firebase Realtime Database
- Google Maps Flutter (Android/iOS)
- Location + permission_handler
- Awesome Notifications (foreground service notification)
- Firebase Cloud Functions (Node.js, in `functions/`)

## Project Structure

- `lib/main.dart`: app bootstrap, Firebase init, notifications init
- `lib/screens/loading.dart`: splash/loading transition
- `lib/screens/home.dart`: main driver UI and sharing logic
- `lib/services/share_backend_service.dart`: HTTP client for backend endpoints
- `lib/data/bus_catalog.dart`: route and bus catalog
- `functions/index.js`: backend APIs (`startSharing`, `updateLocation`, `stopSharing`)

## Prerequisites

- Flutter SDK installed and on PATH
- Android Studio SDK + platform tools
- Java 17+ recommended for Android build tooling
- Firebase project configured with Realtime Database and Cloud Functions
- Google Cloud billing enabled (required for Google Maps SDK)

## Android Setup

### 1. Add Maps API key to local properties

Edit `android/local.properties` and set:

```properties
MAPS_API_KEY=YOUR_ANDROID_MAPS_KEY
```

This project already injects this key into manifest using:

- `android/app/build.gradle` -> `manifestPlaceholders += [MAPS_API_KEY: mapsApiKey]`
- `android/app/src/main/AndroidManifest.xml` -> `${MAPS_API_KEY}`

### 2. Configure key restrictions in Google Cloud

In Google Cloud Console -> Credentials -> your API key:

1. Enable API: `Maps SDK for Android`
2. Set `Application restrictions` to `Android apps`
3. Add entries with package name:
	- `com.bus_tracker_driver_app.app`
4. Add SHA-1 fingerprints for your signing certs.

Current values used in this project:

- Debug SHA-1: `49:2C:AC:01:14:6D:2C:12:E5:F5:67:5B:62:F5:77:33:AA:33:C4:F8`
- Release SHA-1: `0C:68:90:19:44:55:4E:54:3A:7B:84:0E:B3:6D:AE:31:E9:1B:C0:98`

To regenerate on your machine:

```bash
cd android
./gradlew signingReport
```

On Windows PowerShell:

```powershell
Set-Location android
.\gradlew signingReport
```

## Firebase Setup

### 1. Android Firebase config

Ensure `android/app/google-services.json` matches package name:

- `com.bus_tracker_driver_app.app`

This file is intentionally ignored from Git for security. Keep your own local copy in:

- `android/app/google-services.json`

### 1.1 Generate FlutterFire options locally

`lib/firebase_options.dart` is also ignored from Git. Generate it on each machine using FlutterFire CLI:

```bash
flutterfire configure
```

### 2. Deploy backend functions

```bash
cd functions
npm install
firebase deploy --only functions
```

### 3. Realtime Database paths used

- `Buses/<busId>/status`
- `Buses/<busId>/location`
- `ActiveShareSessions/<busId>`
- `ServerMetrics/sharing/*`

## Backend URL Configuration

Client uses `SHARING_API_BASE_URL` via dart define:

```bash
flutter run --dart-define=SHARING_API_BASE_URL=https://asia-southeast1-<project-id>.cloudfunctions.net
```

If not provided, app falls back to:

`https://asia-southeast1-bus-tracker-bbaa6.cloudfunctions.net`

## Admin Reset Endpoint (Protected)

The backend includes `forceStopAllSharing` for emergency reset of all active sharing sessions.

Security requirements:

- Endpoint requires `x-admin-key` header.
- Key is loaded from `functions/.env` as `FORCE_STOP_ADMIN_KEY`.
- `functions/.env` is ignored from Git.
- Use `functions/.env.example` as template.

Example (PowerShell):

```powershell
Set-Location functions
$line = (Get-Content .env | Where-Object { $_ -match '^FORCE_STOP_ADMIN_KEY=' } | Select-Object -First 1)
$adminKey = $line.Substring('FORCE_STOP_ADMIN_KEY='.Length).Trim()
$headers = @{ 'x-admin-key' = $adminKey }
$body = @{ reason = 'manual_admin_reset' } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri 'https://forcestopallsharing-rr2r4culhq-as.a.run.app' -Headers $headers -ContentType 'application/json' -Body $body
```

## Run Locally

```bash
flutter pub get
flutter run
```

Build debug APK:

```bash
flutter build apk --debug
```

## Troubleshooting

### Google map shows gray tiles / blank map

Check logcat for `Authorization failure` from `Google Android Maps SDK`.

Fix checklist:

1. Correct key in `android/local.properties` (`MAPS_API_KEY`)
2. `Maps SDK for Android` enabled
3. Billing enabled in Google Cloud project
4. Correct package name + SHA-1 restriction
5. Wait 5-10 minutes after key/restriction changes
6. Reinstall app and run again

### Build errors related to stale Gradle/Kotlin cache

Try:

```bash
flutter clean
flutter pub get
flutter build apk --debug
```

## Notes

- Do not commit private keys or secrets.
- `android/local.properties` is machine-local and suitable for local key storage.
- `android/app/google-services.json`, `lib/firebase_options.dart`, and `functions/.env` are intentionally kept out of Git.
