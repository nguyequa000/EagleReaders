import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('storysprout/memory');

const _mb = 1024 * 1024;

/// The limit where nothing is known about the phone (iOS, a failed lookup):
/// what a phone with the usual 192 MB Java heap can take.
const defaultPagedBookLimit = 15 * _mb;

/// The biggest book the paged reader should be given on this phone.
///
/// `flutter_epub_viewer` hands the whole book to its web view as one huge
/// string, copied several times over: on the Java heap, in Dart, and in the
/// web view. So two things run out, and the limit follows whichever is
/// tighter (measured on a 2 GB phone emulator):
/// - the Java heap the app is granted: with the usual 192 MB, an 11.6 MB book
///   peaked around 85 MB and a 22 MB one got the app killed.
///   android:largeHeap raises it (512 MB there), which alone wasn't enough:
/// - the phone's RAM: with the 512 MB heap, a 20 MB book opened once and the
///   phone's low-memory killer closed the app on the second open, while
///   12.6 MB opened again and again.
/// Capped, because past that the string itself gets unreasonable.
Future<int> pagedBookLimit() => _limit ??= _lookUp();

Future<int>? _limit;

Future<int> _lookUp() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return defaultPagedBookLimit;
  }
  try {
    final memory = await _channel.invokeMapMethod<String, int>('memory');
    final heap = memory?['maxHeap'];
    final ram = memory?['totalRam'];
    if (heap == null || ram == null) return defaultPagedBookLimit;
    final limit = pagedBookLimitFor(maxHeapBytes: heap, totalRamBytes: ram);
    debugPrint(
      'Paged reader: ${heap ~/ _mb} MB heap, ${ram ~/ _mb} MB RAM, '
      'books up to ${limit ~/ _mb} MB',
    );
    return limit;
  } catch (_) {
    return defaultPagedBookLimit;
  }
}

/// [pagedBookLimit] for a phone with this Java heap and RAM: about a tenth
/// of the heap after headroom for the rest of the app, and 1/140 of the RAM
/// (14 MB on a 2 GB phone, 29 MB on 4 GB), whichever is smaller.
@visibleForTesting
int pagedBookLimitFor({required int maxHeapBytes, required int totalRamBytes}) {
  final byHeap = (maxHeapBytes - 40 * _mb) ~/ 10;
  final byRam = totalRamBytes ~/ 140;
  return (byHeap < byRam ? byHeap : byRam).clamp(8 * _mb, 40 * _mb);
}

/// Forgets the looked-up limit, so tests can try another phone.
@visibleForTesting
void resetPagedBookLimit() => _limit = null;
