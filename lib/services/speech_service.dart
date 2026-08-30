import 'package:flutter/services.dart';

/// Launches Android's system speech recognition dialog (Google's own voice UI)
/// and returns the recognized text. The dialog handles microphone capture,
/// pause detection and retry itself, so nothing on this side can "snap shut".
class SpeechService {
  static const MethodChannel _channel =
      MethodChannel('com.example.lingua/speech');

  /// Fired when the user finishes speaking a single word.
  void Function(String word)? onWordSpoken;

  /// Fired just before Google's recognition dialog opens.
  void Function()? onStarted;

  /// Fired when the dialog closes without capturing a usable word.
  void Function()? onCanceled;

  /// Fired on any error (no recognizer, permission issue, unsupported platform).
  void Function(String message)? onError;

  Future<void> listen() async {
    onStarted?.call();
    String? result;
    try {
      result = await _channel.invokeMethod<String>('recognize');
    } on PlatformException {
      onError?.call('Speech recognition is not available on this device.');
      return;
    } on MissingPluginException {
      onError?.call('Google voice is only available on Android.');
      return;
    }

    final word = _extractWord(result ?? '');
    if (word.isEmpty) {
      onCanceled?.call();
    } else {
      onWordSpoken?.call(word);
    }
  }

  Future<void> stop() async {}

  void dispose() {}

  static const Set<String> _filler = {
    'uh', 'um', 'er', 'ah', 'like', 'the', 'a', 'an', 'please', 'word',
    'this', 'that', 'it', 'and', 'of', 'to', 'for',
  };

  String _extractWord(String text) {
    final words = text
        .toLowerCase()
        .split(RegExp(r"[^a-z']+"))
        .where((w) => w.isNotEmpty)
        .toList();

    for (final w in words) {
      if (!_filler.contains(w)) {
        return w;
      }
    }
    return words.isNotEmpty ? words.first : '';
  }
}