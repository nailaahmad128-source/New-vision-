/// Platform-neutral translation language model used by the UI.
enum TranslateLanguage {
  english, urdu, arabic, persian, hindi, bengali,
  french, german, spanish, turkish, russian, chinese, japanese,
}

extension TranslateLanguageCode on TranslateLanguage {
  String get bcpCode => switch (this) {
    TranslateLanguage.english => 'en', TranslateLanguage.urdu => 'ur', TranslateLanguage.arabic => 'ar',
    TranslateLanguage.persian => 'fa', TranslateLanguage.hindi => 'hi', TranslateLanguage.bengali => 'bn',
    TranslateLanguage.french => 'fr', TranslateLanguage.german => 'de', TranslateLanguage.spanish => 'es',
    TranslateLanguage.turkish => 'tr', TranslateLanguage.russian => 'ru', TranslateLanguage.chinese => 'zh',
    TranslateLanguage.japanese => 'ja',
  };
}
