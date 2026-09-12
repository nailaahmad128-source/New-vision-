# PDF Master Tools — Windows Edition

This edition adds a Windows desktop target while keeping the Android build intact.

## Windows-ready areas
- Home / Library / Recently Deleted
- PDF merge, split, compress, convert, reorder, rotate, watermark, security, fill/sign
- File import and desktop document workflow
- Desktop Smart Scanner: choose one or multiple images and create a PDF
- PDF reader and local file management
- Windows text-to-speech via `flutter_tts`
- AdMob is intentionally disabled on Windows

## Mobile-only areas
The Android/iOS implementations remain unchanged for:
- live camera scanner
- ML Kit OCR
- Tesseract Urdu/Arabic OCR
- ML Kit on-device translation
- live QR camera scanning

On Windows these screens fail gracefully or provide a desktop alternative instead of crashing.

## Build
Double-click `BUILD_WINDOWS.bat`.
The release EXE bundle will be under:
`build\\windows\\x64\\runner\\Release`

A Windows Flutter build requires the Windows desktop toolchain (Visual Studio with the Desktop development with C++ workload) in addition to Flutter.
