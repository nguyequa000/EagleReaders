import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

// Firebase AI Logic rejects calls that carry no App Check token, and
// FirebaseAI.googleAI() attaches one automatically once App Check is active.
//
// Test builds pass a debug token registered in the console (App Check > Apps >
// Manage debug tokens), kept in the gitignored app_check.json as
// {"APP_CHECK_DEBUG_TOKEN": "<uuid>"}:
//   flutter build apk --release --dart-define-from-file=app_check.json
// Without it, Android uses Play Integrity, which only attests apps installed
// from Google Play — a sideloaded APK built that way can't reach Gemini.
const _debugToken = String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');

/// What a run without the token prints at startup, so a missing
/// `--dart-define-from-file=app_check.json` is obvious long before a quiz or
/// story fails with "App attestation failed". Release builds stay quiet:
/// installed from Google Play they don't need the token.
@visibleForTesting
String? missingTokenWarning({required bool hasToken, required bool release}) =>
    hasToken || release
    ? null
    : '''
⚠️ ═══════════════════ APP CHECK TOKEN MISSING ═══════════════════
⚠️ This run has no APP_CHECK_DEBUG_TOKEN, so Firebase rejects every
⚠️ Gemini call: quizzes and AI stories will fail (403 "App attestation
⚠️ failed"). Stop the app and restart it with the token:
⚠️   flutter run --dart-define-from-file=app_check.json
⚠️ In VS Code, use the "Story Sprout" launch config.
⚠️ ════════════════════════════════════════════════════════════════''';

// Call once, right after Firebase.initializeApp().
Future<void> activateAppCheck() async {
  final debug = _debugToken.isNotEmpty;
  final warning = missingTokenWarning(hasToken: debug, release: kReleaseMode);
  if (warning != null) debugPrint(warning);
  // Web has no reCAPTCHA site key set up, so it only works with a debug token.
  if (kIsWeb && !debug) return;
  await FirebaseAppCheck.instance.activate(
    providerAndroid: debug
        ? const AndroidDebugProvider(debugToken: _debugToken)
        : const AndroidPlayIntegrityProvider(),
    providerWeb: debug ? WebDebugProvider(debugToken: _debugToken) : null,
    providerWindows: WindowsDebugProvider(
      debugToken: debug ? _debugToken : null,
    ),
  );
}
