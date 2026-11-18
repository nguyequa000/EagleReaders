# EagleReaders

## Project Description

EagleReaders is a cross-platform Flutter mobile app that helps kids build reading skills through interactive, AI-assisted storytelling. Parents create an account, set up child profiles behind a PIN, and children can read books (EPUB support), generate custom AI stories by picking a character, mood, and setting, and complete reading comprehension activities afterward. Parents get a dashboard and settings to manage their children's accounts.

Core features:
- Parent and child account flows with PIN-protected child profiles
- EPUB reading module (`flutter_epub_viewer`, `epub_view`)
- AI-generated custom stories (character / mood / setting selection → generated story → summary)
- Reading comprehension screens
- Firebase-backed auth, data storage, and analytics

## Technologies Used

- **Framework:** Flutter (Dart), targeting Android, iOS, Windows, macOS, Linux, Web
- **Backend / Auth:** Firebase (`firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_analytics`)
- **Reading:** `flutter_epub_viewer`, `epub_view`, `flutter_read`
- **Other:** `file_picker`
- Package/app ID: `com.UNT.storysprout`

## Installation Instructions

1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart SDK `^3.11.4` or newer).
2. Clone this repository and install dependencies:
   ```
   git clone https://github.com/nguyequa000/EagleReaders.git
   cd EagleReaders
   flutter pub get
   ```
3. Firebase is already configured for this project (`android/app/google-services.json`, `lib/firebase_options.dart`, `firebase.json` are checked in). If you're setting up your own Firebase project instead, install the [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup) and run `flutterfire configure`.

## How to Run the Application

Connect a device/emulator or select a desktop/web target, then run:
```
flutter run
```
To target a specific platform: `flutter run -d chrome`, `flutter run -d windows`, etc.

Story generation goes through Firebase AI Logic, which requires App Check. Outside a Play Store install, use a debug token registered in the Firebase console (App Check > Apps > Manage debug tokens). Put it in `app_check.json` at the project root (gitignored):
```
{ "APP_CHECK_DEBUG_TOKEN": "<token>" }
```
then run with `flutter run --dart-define-from-file=app_check.json`, or build a test APK with `flutter build apk --release --dart-define-from-file=app_check.json`. In VS Code, pick the "Story Sprout (App Check token)" launch config. A build without the token can't reach Gemini, and installing it replaces any working build on the device.

## Testing

Widget tests live in `test/`. Run the test suite with:
```
flutter test
```

## Contributions

See [CONTRIBUTIONS.md](./CONTRIBUTIONS.md) for a breakdown of what each team member worked on.

## Asset Attribution

Bundled illustrations and fonts are third-party open-source assets. See
[ATTRIBUTION.md](./ATTRIBUTION.md) for sources and licenses.
