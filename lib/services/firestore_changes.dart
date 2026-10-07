import 'dart:async';

/// Turns a Firestore `snapshots()` stream into a plain "something changed"
/// signal for screens that already know how to load their own data.
///
/// The first snapshot is dropped: it is the state the screen has just loaded,
/// so only later ones — writes from this device or another one signed into the
/// same account — are changes.
Stream<void> changesOf(Stream<Object?> snapshots) =>
    snapshots.skip(1).map((_) {});

/// Merges several change signals into one. Closes once every source has.
Stream<void> mergeChanges(List<Stream<void>> sources) {
  if (sources.isEmpty) return const Stream.empty();
  if (sources.length == 1) return sources.single;

  final subscriptions = <StreamSubscription<void>>[];
  late final StreamController<void> controller;
  var open = sources.length;
  controller = StreamController<void>(
    onListen: () {
      for (final source in sources) {
        subscriptions.add(
          source.listen(
            controller.add,
            onError: controller.addError,
            onDone: () {
              if (--open == 0) controller.close();
            },
          ),
        );
      }
    },
    onCancel: () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    },
  );
  return controller.stream;
}
