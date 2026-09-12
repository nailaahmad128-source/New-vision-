import 'package:google_mlkit_language_id/google_mlkit_language_id.dart' as lid;
import 'package:google_mlkit_translation/google_mlkit_translation.dart' as ml;
import 'translation_types.dart';

class TranslationService {
  final lid.LanguageIdentifier _languageIdentifier = lid.LanguageIdentifier(confidenceThreshold: 0.45);

  ml.TranslateLanguage _ml(TranslateLanguage l) => switch (l) {
    TranslateLanguage.english => ml.TranslateLanguage.english, TranslateLanguage.urdu => ml.TranslateLanguage.urdu,
    TranslateLanguage.arabic => ml.TranslateLanguage.arabic, TranslateLanguage.persian => ml.TranslateLanguage.persian,
    TranslateLanguage.hindi => ml.TranslateLanguage.hindi, TranslateLanguage.bengali => ml.TranslateLanguage.bengali,
    TranslateLanguage.french => ml.TranslateLanguage.french, TranslateLanguage.german => ml.TranslateLanguage.german,
    TranslateLanguage.spanish => ml.TranslateLanguage.spanish, TranslateLanguage.turkish => ml.TranslateLanguage.turkish,
    TranslateLanguage.russian => ml.TranslateLanguage.russian, TranslateLanguage.chinese => ml.TranslateLanguage.chinese,
    TranslateLanguage.japanese => ml.TranslateLanguage.japanese,
  };

  TranslateLanguage? languageFromCode(String code) {
    switch (code.toLowerCase().split('-').first) {
      case 'ar': return TranslateLanguage.arabic; case 'bn': return TranslateLanguage.bengali; case 'de': return TranslateLanguage.german;
      case 'en': return TranslateLanguage.english; case 'es': return TranslateLanguage.spanish; case 'fa': return TranslateLanguage.persian;
      case 'fr': return TranslateLanguage.french; case 'hi': return TranslateLanguage.hindi; case 'ja': return TranslateLanguage.japanese;
      case 'ru': return TranslateLanguage.russian; case 'tr': return TranslateLanguage.turkish; case 'ur': return TranslateLanguage.urdu;
      case 'zh': return TranslateLanguage.chinese; default: return null;
    }
  }

  Future<String?> detectLanguageCode(String text) async {
    if (text.trim().length < 4) return null;
    final code = await _languageIdentifier.identifyLanguage(text);
    return code == 'und' ? null : code;
  }

  Future<String> translate({required String text, required TranslateLanguage source, required TranslateLanguage target}) async {
    if (source == target) return text;
    final s = _ml(source), t = _ml(target);
    final manager = ml.OnDeviceTranslatorModelManager();
    await manager.downloadModel(s.bcpCode); await manager.downloadModel(t.bcpCode);
    final translator = ml.OnDeviceTranslator(sourceLanguage: s, targetLanguage: t);
    try { return await translator.translateText(text); } finally { translator.close(); }
  }

  void dispose() => _languageIdentifier.close();
}
