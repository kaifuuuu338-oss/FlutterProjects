import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  String _languageCode = 'en-IN';
  bool _isSpeaking = false;

  String get languageCode => _languageCode;
  bool get isSpeaking => _isSpeaking;

  TtsService() {
    _tts.awaitSpeakCompletion(true);
    _tts.setStartHandler(() {
      _isSpeaking = true;
      notifyListeners();
    });
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      notifyListeners();
    });
    _tts.setCancelHandler(() {
      _isSpeaking = false;
      notifyListeners();
    });
    _tts.setErrorHandler((_) {
      _isSpeaking = false;
      notifyListeners();
    });
  }

  Future<void> syncLocale(Locale locale) async {
    final mapped = _mapLocale(locale);
    if (mapped == _languageCode) return;
    _languageCode = mapped;
    await _tts.setLanguage(_languageCode);
    await _selectIndianVoice();
    notifyListeners();
  }

  Future<void> setLanguageCode(String code) async {
    _languageCode = code;
    await _tts.setLanguage(_languageCode);
    await _selectIndianVoice();
    notifyListeners();
  }

  Future<void> speak(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    await _tts.setLanguage(_languageCode);
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.speak(clean);
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  Future<void> pause() async {
    try {
      await _tts.pause();
    } catch (_) {
      await _tts.stop();
    }
  }

  Future<void> _selectIndianVoice() async {
    try {
      final voices = await _tts.getVoices;
      if (voices is! List) return;
      dynamic target;
      for (final v in voices) {
        final locale = (v is Map && v['locale'] != null) ? v['locale'].toString() : '';
        if (locale != _languageCode) continue;
        final name = (v is Map && v['name'] != null) ? v['name'].toString().toLowerCase() : '';
        if (name.contains('india') || name.contains('hindi') || name.contains('telugu') || name.contains('google')) {
          target = v;
          break;
        }
      }
      if (target is Map && target['name'] != null && target['locale'] != null) {
        await _tts.setVoice({'name': target['name'], 'locale': target['locale']});
      }
    } catch (_) {
      // Ignore voice selection errors
    }
  }

  String _mapLocale(Locale locale) {
    switch (locale.languageCode) {
      case 'te':
        return 'te-IN';
      case 'hi':
        return 'hi-IN';
      default:
        return 'en-IN';
    }
  }
}
