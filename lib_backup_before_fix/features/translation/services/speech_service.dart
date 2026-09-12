import 'package:flutter_tts/flutter_tts.dart';
class SpeechService {
  final FlutterTts _tts = FlutterTts();
  Future<void> speak(String text, {String language = 'en-US'}) async { if (text.trim().isEmpty) return; await _tts.stop(); await _tts.setLanguage(language); await _tts.setSpeechRate(0.46); await _tts.setPitch(1.0); await _tts.awaitSpeakCompletion(true); await _tts.speak(text); }
  Future<void> stop() => _tts.stop(); Future<void> dispose() => _tts.stop();
}
