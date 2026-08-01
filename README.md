# Ferrematica Express

Flutter scaffold for Ferrematica's delivery app (see `SDD.md`).

## Setup

1. `flutter pub get`
2. Copy `dart_define.example.json` to `dart_define.json` (gitignored) and fill
   in real `SUPABASE_URL` / `SUPABASE_ANON_KEY` / `GOOGLE_MAPS_API_KEY` values.
3. Run with secrets injected:
   `flutter run --dart-define-from-file=dart_define.json`

### Google Maps native configuration

Native Maps config (Android/iOS) reads the API key from **gitignored,
machine-local files**, not from `dart_define.json` (the native SDKs can't
read Dart's `--dart-define` values):

- Android: `android/local.properties` → `MAPS_API_KEY=...`
- iOS: copy `ios/Runner/Config/Secrets.example.xcconfig` to
  `ios/Runner/Config/Secrets.xcconfig` and fill in `GOOGLE_MAPS_API_KEY`.

Both files ship with a placeholder value so the app builds without a real
key (Maps requests will simply fail at runtime until a real key is set).

**MANUAL STEP — cannot be automated by sdd-apply:** before shipping, the
real Google Maps API key MUST be restricted in the
[Google Cloud Console](https://console.cloud.google.com/):

- Android: restrict by the app's SHA-1 signing certificate fingerprint +
  package name `com.ferrematica.express`.
- iOS: restrict by Bundle ID `com.ferrematica.express`.

An unrestricted key embedded in a shipped binary is not secret — it can be
extracted from the APK/IPA. The restriction is what actually protects it.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
