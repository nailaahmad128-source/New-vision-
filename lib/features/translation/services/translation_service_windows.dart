import 'translation_types.dart';

class TranslationService {
  TranslateLanguage? languageFromCode(String code) {
    switch (code.toLowerCase().split('-').first) {
      case 'ar': return TranslateLanguage.arabic; case 'bn': return TranslateLanguage.bengali;
      case 'de': return TranslateLanguage.german; case 'en': return TranslateLanguage.english;
      case 'es': return TranslateLanguage.spanish; case 'fa': return TranslateLanguage.persian;
      case 'fr': return TranslateLanguage.french; case 'hi': return TranslateLanguage.hindi;
      case 'ja': return TranslateLanguage.japanese; case 'ru': return TranslateLanguage.russian;
      case 'tr': return TranslateLanguage.turkish; case 'ur': return TranslateLanguage.urdu;
      case 'zh': return TranslateLanguage.chinese; default: return null;
    }
  }

  Future<String?> detectLanguageCode(String text) async => null;

  Future<String> translate({required String text, required TranslateLanguage source, required TranslateLanguage target}) async {
    if (source == target) return text;
    throw UnsupportedError('On-device translation is currently available on Android/iOS.');
  }

  void dispose() {}
}
