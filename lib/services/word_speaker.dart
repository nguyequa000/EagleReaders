import 'package:flutter_tts/flutter_tts.dart';

/// Speaks a word the child highlighted in the book reader ("Say it"), slowly
/// enough to hear each sound.
class WordSpeaker {
  /// [speak] replaces the speech engine in tests.
  WordSpeaker({Future<void> Function(String text)? speak}) : _speak = speak;

  static WordSpeaker instance = WordSpeaker();

  final Future<void> Function(String text)? _speak;
  FlutterTts? _tts;

  /// The most a single "Say it" reads, so a dragged-out paragraph stops.
  static const maxLength = 200;

  /// Slower than story read-aloud (0.45): this is for hearing one word.
  static const speechRate = 0.4;

  static final _edges = RegExp(
    r"^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$",
    unicode: true,
  );
  static final _letter = RegExp(r'\p{L}', unicode: true);

  /// What "Say it" reads for a selection: spaces collapsed, punctuation and
  /// quotes trimmed from the ends (inner apostrophes and hyphens stay, as in
  /// "don't" and "well-known"). Null when there's no word in it.
  static String? sayable(String text) {
    var words = text.replaceAll(RegExp(r'\s+'), ' ').replaceAll(_edges, '');
    if (!_letter.hasMatch(words)) return null;
    if (words.length > maxLength) {
      final cut = words.lastIndexOf(' ', maxLength);
      words = words.substring(0, cut > 0 ? cut : maxLength);
    }
    return words;
  }

  /// Speaks [text], cutting off whatever was still being said. Speech that
  /// fails (no engine, tests) is ignored: it must never get in the way of
  /// reading.
  Future<void> say(String text) async {
    final words = sayable(text);
    if (words == null) return;
    try {
      final speak = _speak;
      if (speak != null) return await speak(words);
      final tts = await _engine();
      await tts.stop();
      await tts.speak(words);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }

  Future<FlutterTts> _engine() async {
    final existing = _tts;
    if (existing != null) return existing;
    final tts = _tts = FlutterTts();
    try {
      await tts.setLanguage('en-US');
      await tts.setSpeechRate(speechRate);
      await tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
      ]);
    } catch (_) {}
    return tts;
  }
}
