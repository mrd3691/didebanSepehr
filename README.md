# Dideban Sepehr mobile

Native Flutter app for the existing loc8ion Traccar backend. Android and iOS projects are included. The app contains login, Live, and Tracking only.

## Run

From this folder, with Flutter 3.38 / Dart 3.10 or newer:

```sh
flutter pub get
flutter run --dart-define=TRACCAR_URL=https://gps.example.com
```

First-time setup is prefilled with `http://37.202.178.136:8082/`. Confirm or edit it once; the app stores it independently of the account session. Logout keeps the server address. A Change action on login allows reconfiguration. TRACCAR_URL optionally preconfigures it at build time. Use the Traccar server origin, not the Next.js website or an `/api` URL. The UI, validation messages, and connection errors are in English, with Roboto for Latin text and numbers.

For the existing web deployment, enter **`http://37.202.178.136:8082`**. This corresponds to `NEXT_PUBLIC_TRACCAR_URL_IP`. `http://localhost:8082` is the web server's local backend address; on a phone, localhost refers to the phone itself. Do not enter `ws://37.202.178.136:8082/api/socket` in setup: the app builds that WebSocket address automatically from the HTTP origin. HTTPS origins similarly use WSS.

Android and iOS have a scoped HTTP exception for `37.202.178.136`; HTTPS remains available for other servers. Adding another HTTP host requires updating Android's `res/xml/network_security_config.xml` and iOS's `NSExceptionDomains` configuration. The iOS IP exception requires iOS 17 or later; iOS builds still require validation on macOS. The server must accept WebSocket upgrades on `/api/socket`.

Sign in with the same Traccar account as the web project. Remembered session cookies are kept in Keychain / Android encrypted storage. Passwords are not persisted. Session expiry returns to login. The server is entered by the user; the HTTP exception and example above refer to the existing deployment. Credentials are not embedded in source control.

## Features

- Hierarchical device selection for Live and Tracking, matching the web group/subgroup structure. Live group checkboxes cascade to all descendants and show partial selections; Tracking selects one device from the same tree. Search matches group names, device names and identifiers, preserving ancestors and expanding matching branches.
- Initial positions from REST, then WebSocket updates throttled to 300 ms; older fixes cannot overwrite newer ones.
- Reconnect with exponential backoff up to 32 seconds; refresh positions after reconnect and app resume.
- Map labels, speed in km/h, GPS fix status, timestamp, address, follow and fit controls. Latitude/longitude and device online/offline/unknown labels are not displayed. Missing addresses do not fall back to coordinates.
- Tracking for one device and a Shamsi date/time range; dates use the phone's local timezone and requests use UTC.
- Route line, start/end markers, slider, previous/next, pause/play and 1x/2x/4x/8x/16x playback. Each point advances at 900 ms / multiplier, matching the web project rather than real elapsed journey time.
- Red markers and a selected-device speed warning above the configured threshold (default 100 km/h; zero disables warnings).
- Map rotation is disabled; pinch zoom and panning remain available. Live marker name labels are hidden. Clicking a device name in the tree closes the picker and zooms directly to that device, including repeated clicks on the same device.
- Device sheets, route controls and navigation respect the phone's system navigation area and keyboard. Sign-in uses a compact form without promotional headings or slogans.

## Configuration

```sh
flutter run --dart-define=TRACCAR_URL=https://gps.example.com --dart-define=SPEED_ALERT_THRESHOLD_KMH=100
flutter run --dart-define=MAP_TILE_URL=https://maps.example.com/tiles/{z}/{x}/{y}.png
```

The default basemap is OpenStreetMap raster tiles, with attribution. The web project's MapLibre vector `style.json` is not a raster tile URL; use a raster endpoint for a self-hosted map. This version requires network access for tiles and does not bundle offline maps. The device tree uses each group's `groupId` as its parent. Devices with no accessible group are shown under the root; malformed cycles are broken so permitted devices remain reachable.

## API contract

- `POST /api/session` with URL-encoded `email` / `password`; retain `JSESSIONID`.
- `GET /api/session` validates a remembered session.
- `GET /api/devices`, `/api/groups`, `/api/positions` with the session cookie.
- `GET /api/positions?deviceId=...&from=...&to=...` fetches historical points.
- `WSS /api/socket` uses the session cookie for device/position updates.
- `DELETE /api/session` on logout (local credentials are cleared even if the server is unavailable).

No backend changes are required. Reports, administration, commands, phone GPS collection and background tracking services are outside this app's scope.

## Verify and build

```sh
flutter analyze
flutter test
flutter test tool/preview_test.dart --update-goldens
flutter build apk --debug
flutter build appbundle --release
```

Preview images are generated in `build/previews/`. On macOS, configure the iOS signing team in Xcode before building for an iPhone. Configure your release signing key before distributing Android releases; the generated project currently uses Flutter's debug signing configuration.

Dependencies are locked in `pubspec.lock`. If pub.dev is unavailable and the packages already exist locally, use `flutter pub get --offline`.

### Google Maven returns 404 / Android Gradle Plugin not found

If Android dependencies are already cached on this Windows machine, prepare a local Maven repository:

```powershell
.\tool\prepare_maven_cache.ps1
flutter build apk --release --no-pub
```

The script reuses Gradle's artifact cache with hard links in the temporary folder (copies only when hard links are unavailable). It sets `dideban.mavenRepository` in the ignored `android/local.properties`, so both Flutter CLI and Android Studio can use it. It does not modify global Gradle settings or change dependency versions. Remove that one property to return to the default repositories. Keep the generated repository while using this configuration, or rerun the script after the temporary folder is cleared.

With the local repository enabled, Flutter plugin buildscript dependencies reuse the app's AGP version. This avoids fetching a separate AGP version for each plugin.

For this machine's installed SDK/cache, the following additional overrides are configured in the ignored `android/local.properties`:

```properties
dideban.ndkVersion=27.0.12077973
dideban.annotationVersion=1.8.2
```

The NDK override selects the installed stable r27 instead of Flutter's unavailable r28. The annotation override aligns `annotation` and `annotation-jvm` to the cached version for this local build. Both are optional; omit them on machines with the default dependencies available. No files inside Flutter, the Android SDK, or the global Gradle cache are edited.

This is a cache fallback, not a complete dependency download: uncached artifacts still require access to the normal repositories. A machine with an empty Gradle cache needs working Google Maven access.

Validated on this machine: `flutter build apk --release --no-pub` succeeds with the local cache/SDK overrides above. Output: `build/app/outputs/flutter-apk/app-release.apk`. The release dependencies explicitly include Error Prone and JSR-305 annotations referenced by the storage library, so R8 can validate the complete classpath without suppressing missing-class checks.

The real backend integration still needs validation with your HTTPS server and account. Automated tests use a local Traccar-shaped HTTP/WebSocket server; they do not access production vehicles.

