# PDF Master Tools — Batch 16

## PDF utility expansion

Implemented real page-selection workflows for:
- Extract Pages: select arbitrary pages and save them as a new PDF.
- Delete Pages: select pages to remove and save a new PDF, with protection against deleting every page.

Also expanded the Tools catalog and router so both utilities are first-class tools, with history/result registration.

## Design rules
- Original PDF is not overwritten.
- Page order is preserved for extracted pages.
- Delete operation always requires at least one page to remain.
- No placeholder buttons.
- Uses the existing Syncfusion PDF service and storage architecture.

## Verification
Source-level checks performed: references resolved, no merge-conflict markers, balanced Dart delimiters in edited files.
Flutter SDK/build is not available in this environment; run `flutter pub get`, `flutter analyze`, and `flutter build apk --release` in the project's normal build environment.
