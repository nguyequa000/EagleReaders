import 'dart:async';

import 'package:flutter/widgets.dart';

import '../services/pin_attempts.dart';

/// The lock-out half of a PIN screen, on top of [PinAttempts]: whether the
/// PIN can be tried right now, the message to show while it can't, and a
/// timer that unlocks the screen when the lock runs out.
///
/// A screen calls [checkLock] before verifying a PIN, then [pinFailed] or
/// [pinSucceeded], and shows [lockMessage] (when set) in place of its own
/// error.
mixin PinLockout<T extends StatefulWidget> on State<T> {
  /// Which count this screen uses: [PinAttempts.parent] or
  /// [PinAttempts.child].
  String get pinAttemptsKey;

  /// "Too many tries…" while locked, else null.
  String? lockMessage;

  bool get isLocked => lockMessage != null;

  Timer? _unlockTimer;

  @override
  void initState() {
    super.initState();
    // A lock from an earlier visit still applies.
    checkLock();
  }

  /// Re-reads the lock (another screen may have set it) and returns whether
  /// the PIN is locked right now.
  Future<bool> checkLock() async {
    final left = await PinAttempts.instance.lockedFor(pinAttemptsKey);
    if (mounted) _show(left);
    return left != null;
  }

  /// Notes a wrong PIN. Returns true when that locked the PIN.
  Future<bool> pinFailed() async {
    final lock = await PinAttempts.instance.recordFailure(pinAttemptsKey);
    if (lock != null && mounted) _show(lock);
    return lock != null;
  }

  Future<void> pinSucceeded() =>
      PinAttempts.instance.recordSuccess(pinAttemptsKey);

  void _show(Duration? left) {
    _unlockTimer?.cancel();
    setState(
      () => lockMessage = left == null ? null : PinAttempts.lockMessage(left),
    );
    if (left != null) {
      _unlockTimer = Timer(left, () {
        if (mounted) setState(() => lockMessage = null);
      });
    }
  }

  @override
  void dispose() {
    _unlockTimer?.cancel();
    super.dispose();
  }
}
