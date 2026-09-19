# PDF Master Tools — Professional Library & Tools Batch

This batch extends the scanner rebuild with a deeper document lifecycle and a more complete Tools catalog.

## Implemented
- Professional document detail screen with preview, metadata pills, OCR status, quick actions, print, duplicate, favorite, rename and safe delete.
- Library rename now preserves the original file extension for images as well as PDFs.
- Real document duplication with a new library file and copied thumbnail.
- Categorized Tools screen with Scan / Create / PDF Manage / Convert / Edit & Secure / OCR & Language sections.
- Real ID Scanner workflow: front + back capture, native auto-crop when available, combined multi-page PDF, Library registration.
- Standalone OCR entry point using the existing OCR service.
- Standalone Smart Translation entry point using the existing translation service.
- Standalone Text-to-Speech tool using the existing TTS service.

## Deliberate product rule
Office conversions (PDF <-> Word/Excel/PPT) are not faked or implemented as misleading text-only conversions. They should use a real conversion provider when that provider is selected and configured.

## Verification
Source-level checks were performed in this environment. Flutter SDK/build verification must still be run in the target Android/Windows build environment:

    flutter pub get
    flutter analyze
    flutter build apk --release
