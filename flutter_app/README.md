# KhetLink

A Flutter application for farming-related features (maps, reports, weather, and farm management).

This README explains how to set up the development environment, run the app (Windows/Android/iOS/web), run tests, and where important code lives.

## Table of contents

- About
- Prerequisites
- Quick start (Windows / PowerShell)
- Running on Android, iOS, Web, and Desktop
- Tests and static analysis
- Project structure
- Configuration
- Troubleshooting
- Contributing
- License

## About

KhetLink is a Flutter-based mobile (and desktop/web) app. It includes features such as mapping (`map_my_farm.dart`), farm screens, report generation, and integrations with weather APIs. The UI and app logic live under `lib/`.

## Prerequisites

- Flutter SDK (stable) — follow the official install guide: https://flutter.dev/docs/get-started/install
- Android SDK (for Android builds) and Android Studio (recommended)
- Xcode (for iOS builds) — macOS only
- For Windows desktop builds, enable Windows desktop support in Flutter
- A valid API key for weather services (see `lib/weather_api_key.dart`)

Run `flutter doctor` to validate your environment before proceeding.

## Quick start (Windows / PowerShell)

Open PowerShell in the project root (this repo root contains `pubspec.yaml`). Then run:

```powershell
# Install dependencies
flutter pub get

# Run the app on the default connected device (or the Windows desktop if enabled)
flutter run

# Run on a specific device (example: Windows desktop)
flutter run -d windows

# Run tests
flutter test

# Static analysis
flutter analyze
```

If you prefer to run on an Android emulator, start the emulator first from Android Studio or via command line and then use `flutter run -d <device-id>` (use `flutter devices` to list IDs).

## Running on Android, iOS, web, and desktop

- Android: `flutter run -d emulator-5554` or use your phone (USB debugging enabled)
- iOS (macOS only): `flutter run -d <your-ios-device-id>` and ensure a valid signing setup
- Web: `flutter run -d chrome`
- Windows: `flutter run -d windows` (requires Windows desktop support enabled)
- Build release APK for Android: `flutter build apk --release`
- Build iOS (macOS only): `flutter build ios --release`

## Tests and static analysis

- Run unit/widget tests: `flutter test`
- Run analyzer: `flutter analyze`

Add tests under the `test/` directory. This repo contains example tests such as `test/widget_test.dart` and `test/auth_service_test.dart`.

## Project structure (important files)

- `lib/main.dart` — app entry point
- `lib/api_service.dart` — API client utilities
- `lib/config.dart` — app configuration and endpoints
- `lib/weather_api_key.dart` — place your weather API key here (this file exists in the repo)
- `lib/map_my_farm.dart`, `lib/my_farm_screen.dart`, `lib/report_generation_screen.dart` — feature screens
- `lib/models/` — data models
- `lib/services/` — business logic and service classes
- `lib/widgets/` — shared UI widgets
- `assets/` — bundled images used by the app
- `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/` — platform-specific folders

## Configuration

- Weather and other API keys: the repo contains `lib/weather_api_key.dart`. Replace placeholder values with your key(s). Never commit secret keys to public repositories.
- `lib/config.dart` contains runtime config values and endpoints. Update as needed for dev/staging/production.

Tip: Use environment-specific build-time configuration or a secrets manager for production keys.

## Troubleshooting

- If Flutter cannot find Android SDK: ensure `ANDROID_HOME` or `ANDROID_SDK_ROOT` is set and `sdkmanager` tools are installed.
- If devices don’t appear: run `flutter devices` and confirm your emulator or device is connected.
- Common fix for build issues: run `flutter clean` then `flutter pub get` and try again.

If you hit a platform-specific issue, running `flutter doctor -v` and sharing the output helps debug quickly.

## Contributing

Contributions are welcome. Suggested workflow:

1. Fork the repository
2. Create a feature branch
3. Run tests and linters locally
4. Open a pull request with a clear description of changes

Before opening major PRs, please open an issue to discuss large changes.


# KhetLink

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
