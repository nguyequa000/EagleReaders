import 'dart:async';

import 'package:flutter/widgets.dart';

/// Keeps a screen current while the same account is open on another device.
///
/// Each screen already knows how to load itself; this just re-runs that load
/// whenever one of the services' `changes()` streams fires, so a coin earned
/// on the child's tablet shows up on the parent's phone without anyone
/// leaving the screen.
mixin LiveRefresh<T extends StatefulWidget> on State<T> {
  final List<StreamSubscription<void>> _liveSubscriptions = [];
  Timer? _liveDebounce;

  /// One write often touches several sources at once — a redemption updates
  /// the balance and adds a ledger row — so a burst becomes one reload.
  static const Duration debounce = Duration(milliseconds: 300);

  /// Reloads with [reload] whenever any stream from [sources] fires. Calling
  /// it again replaces the previous sources, for screens whose list of
  /// children can change underneath them.
  ///
  /// [sources] is a callback so a service that cannot reach Firebase (signed
  /// out, or a test that never initialized it) costs the screen its live
  /// updates rather than throwing out of `initState`.
  void refreshOn(
    Iterable<Stream<void>> Function() sources,
    Future<void> Function() reload,
  ) {
    _cancelLive();
    final List<Stream<void>> streams;
    try {
      streams = sources().toList();
    } catch (_) {
      return;
    }
    for (final source in streams) {
      _liveSubscriptions.add(
        source.listen(
          (_) {
            _liveDebounce?.cancel();
            _liveDebounce = Timer(debounce, () {
              if (mounted) reload();
            });
          },
          // A dropped listener just means this screen stops updating live; it
          // still reloads the usual way, so there is nothing to show the child.
          onError: (_) {},
        ),
      );
    }
  }

  void _cancelLive() {
    _liveDebounce?.cancel();
    for (final subscription in _liveSubscriptions) {
      subscription.cancel();
    }
    _liveSubscriptions.clear();
  }

  @override
  void dispose() {
    _cancelLive();
    super.dispose();
  }
}
