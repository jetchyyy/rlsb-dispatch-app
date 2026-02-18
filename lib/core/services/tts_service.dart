import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSupported = false;

  Future<void> init() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.awaitSpeakCompletion(true); // Wait for speech to finish
      _isSupported = true;
    } catch (e) {
      debugPrint('❌ TTS Init Error: $e');
      _isSupported = false;
    }
  }

  Future<void> speak(String text) async {
    if (!_isSupported) await init();
    try {
      await _flutterTts.stop(); // Stop any previous speech
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('❌ TTS Speak Error: $e');
    }
  }

  Future<void> stop() async {
    if (!_isSupported) return;
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('❌ TTS Stop Error: $e');
    }
  }

  void setCompletionHandler(VoidCallback callback) {
    _flutterTts.setCompletionHandler(callback);
  }
}
