# Windows Edition Audit — Pass 2

This pass rechecked the previously audited source and fixed additional desktop issues.

## Fixed in pass 2
- Raised the Flutter SDK floor to 3.38.0 to match the current file_picker 12.x desktop toolchain.
- Updated file_picker from the old 12.0.0-beta.7 dependency to stable 12.2.0.
- Removed the unnecessary image_picker import from the Windows scanner screen.
- Fixed Image to PDF's Camera action on Windows: it now opens the Windows image file picker instead of calling ImageSource.camera, which desktop image_picker does not provide by default.
- Kept Android/iOS camera capture intact through a mobile-only helper.
- Rechecked conditional exports for OCR, translation, scanner, QR scanner, and AdMob.
- Rechecked relative imports and Windows runner/CMake files.

## Remaining intentional limitations
- Windows OCR and on-device ML Kit translation are explicitly disabled with a clear UnsupportedError message.
- Windows live camera scanning and live QR camera scanning are not enabled; desktop uses file/image import.
- A real Windows build still requires Flutter + Visual Studio Desktop C++ tooling on the Windows laptop.

Flutter officially supports Windows desktop deployment, and platform-specific plugins must provide Windows implementations where required. The source has been structured accordingly.
