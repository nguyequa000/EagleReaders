// The paged reader's biggest book follows the phone's memory (its Java heap,
// raised by android:largeHeap, and its RAM) instead of a fixed 15 MB.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/services/device_memory.dart';

const _mb = 1024 * 1024;
const _gb = 1024 * _mb;
const _channel = MethodChannel('storysprout/memory');

int _limit(int heap, int ram) =>
    pagedBookLimitFor(maxHeapBytes: heap, totalRamBytes: ram);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void phone(Object? Function() answer) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async => answer());
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null),
    );
  }

  setUp(() {
    resetPagedBookLimit();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('a 2 GB phone stays at the size measured safe there', () {
    // 12.6 MB reopened fine on the emulator; 20 MB got the app killed.
    expect(_limit(512 * _mb, 2 * _gb) ~/ _mb, 14);
  });

  test('without largeHeap the usual 192 MB heap is the tighter limit', () {
    expect(_limit(192 * _mb, 8 * _gb) ~/ _mb, 15);
  });

  test('more RAM allows bigger books, up to a cap', () {
    expect(_limit(512 * _mb, 4 * _gb) ~/ _mb, 29);
    expect(_limit(512 * _mb, 12 * _gb), 40 * _mb);
  });

  test('a tiny phone still gets a usable floor', () {
    expect(_limit(64 * _mb, 512 * _mb), 8 * _mb);
  });

  test('asks Android once and reuses the answer', () async {
    var calls = 0;
    phone(() {
      calls++;
      return {'maxHeap': 512 * _mb, 'totalRam': 4 * _gb};
    });
    expect(await pagedBookLimit() ~/ _mb, 29);
    expect(await pagedBookLimit() ~/ _mb, 29);
    expect(calls, 1);
  });

  test('falls back to 15 MB when the lookup fails', () async {
    phone(() => throw PlatformException(code: 'nope'));
    expect(await pagedBookLimit(), defaultPagedBookLimit);
  });

  test('other platforms keep 15 MB without asking', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var asked = false;
    phone(() {
      asked = true;
      return {'maxHeap': 512 * _mb, 'totalRam': 4 * _gb};
    });
    expect(await pagedBookLimit(), defaultPagedBookLimit);
    expect(asked, isFalse);
  });
}
