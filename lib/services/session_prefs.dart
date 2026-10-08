import 'package:shared_preferences/shared_preferences.dart';

/// What this device remembers about signing in: whether to skip the login
/// screen next time, and the email to fill in when it does not.
///
/// Deliberately nothing else. The password lives only in Firebase Auth's own
/// session, and parent and child PINs are never stored on the device — they
/// are asked for every time someone picks who is reading.
class SessionPrefs {
  SessionPrefs({Future<SharedPreferences> Function()? prefs})
    : _prefs = prefs ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _prefs;

  static const String keepSignedInKey = 'session.keepSignedIn';
  static const String emailKey = 'session.email';

  /// Whether to open straight past the login screen. Defaults to true, so a
  /// parent who never saw the checkbox (signed in before it existed, or
  /// registered) stays signed in as Firebase already kept them.
  Future<bool> keepSignedIn() async {
    try {
      return (await _prefs()).getBool(keepSignedInKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// The email last used to sign in on this device, if any.
  Future<String?> rememberedEmail() async {
    try {
      return (await _prefs()).getString(emailKey);
    } catch (_) {
      return null;
    }
  }

  /// Records a successful sign-in. A failure only means the choice does not
  /// survive a restart, which is not worth failing the sign-in over.
  Future<void> save({required bool keepSignedIn, required String email}) async {
    try {
      final prefs = await _prefs();
      await prefs.setBool(keepSignedInKey, keepSignedIn);
      await prefs.setString(emailKey, email);
    } catch (_) {}
  }
}
