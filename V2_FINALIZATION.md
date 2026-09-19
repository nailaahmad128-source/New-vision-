# V2 Finalization

## Release identity
- Version name: 2.0.0
- Version code: 12
- Current published Play Store release before V2: 1.0.7 (11)

## Batch 14 changes
- Auto OCR now uses multilingual Tesseract (English + Urdu + Arabic) instead of silently treating Auto as English.
- Explicit English remains on-device ML Kit for speed.
- Urdu/Arabic and mixed-script OCR continue through Tesseract trained data.
- OCR UI label now clearly describes Auto support.

## Important verification
- Run `flutter pub get` and `flutter analyze`.
- Run a debug build on a real Android phone.
- Test camera, OpenCV auto-crop, multi-page scan, PDF page editor, OCR, translation, TTS, QR, sharing, AdMob and file opening.
- Only after those pass, build the signed release AAB for Play Console.
