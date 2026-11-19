import 'package:shared_preferences/shared_preferences.dart';

/// Counts wrong PIN guesses on this device and locks the PIN out for a while
/// after too many, so a child can't work through all 10,000 parent PINs.
///
/// Five free tries; the fifth wrong one locks for 1 minute, the next for 5,
/// then 15 minutes for every one after that. A right PIN starts the count
/// again.
///
/// It lives in SharedPreferences, so it is per device and clearing the app's
/// data resets it. That's fine for a prototype: `firestore.rules` is the real
/// boundary, and the account password can always reset the parent PIN.
class PinAttempts {
  PinAttempts({
    Future<SharedPreferences> Function()? prefs,
    DateTime Function()? now,
  }) : _prefs = prefs ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now;

  /// Shared instance the screens use. Assignable so tests can give it a fake
  /// clock.
  static PinAttempts instance = PinAttempts();

  final Future<SharedPreferences> Function() _prefs;
  final DateTime Function() _now;

  /// The parent PIN is asked for in two places (the persona picker and the
  /// child's grown-up unlock); they share one count so neither is a way
  /// around the other.
  static const String parent = 'parent';

  static String child(String childId) => 'child.$childId';

  static const int freeTries = 5;

  /// Lock lengths for the 5th, 6th and every later wrong try.
  static const List<Duration> lockSteps = [
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
  ];

  static String _failsKey(String key) => 'pin_attempts.$key.fails';
  static String _untilKey(String key) => 'pin_attempts.$key.lockedUntil';

  /// How long [key] is still locked for, or null when it can be tried.
  Future<Duration?> lockedFor(String key) async {
    try {
      final until = (await _prefs()).getInt(_untilKey(key));
      return _remaining(until);
    } catch (_) {
      return null;
    }
  }

  /// Notes a wrong PIN and returns the lock it caused, if any.
  Future<Duration?> recordFailure(String key) async {
    try {
      final prefs = await _prefs();
      final fails = (prefs.getInt(_failsKey(key)) ?? 0) + 1;
      await prefs.setInt(_failsKey(key), fails);
      if (fails < freeTries) return null;
      final step = (fails - freeTries).clamp(0, lockSteps.length - 1);
      final lock = lockSteps[step];
      await prefs.setInt(
        _untilKey(key),
        _now().add(lock).millisecondsSinceEpoch,
      );
      return lock;
    } catch (_) {
      return null;
    }
  }

  /// Notes a right PIN: the count starts again.
  Future<void> recordSuccess(String key) async {
    try {
      final prefs = await _prefs();
      await prefs.remove(_failsKey(key));
      await prefs.remove(_untilKey(key));
    } catch (_) {}
  }

  Duration? _remaining(int? untilMillis) {
    if (untilMillis == null) return null;
    final left = DateTime.fromMillisecondsSinceEpoch(
      untilMillis,
    ).difference(_now());
    return left > Duration.zero ? left : null;
  }

  /// "Too many tries. Try again in 5 minutes." for a lock of [left], rounded
  /// up to whole minutes so it never says 0 while still locked.
  static String lockMessage(Duration left) {
    final minutes = (left.inSeconds / 60).ceil().clamp(1, 1 << 30);
    final unit = minutes == 1 ? 'minute' : 'minutes';
    return 'Too many tries. Try again in $minutes $unit.';
  }
}
