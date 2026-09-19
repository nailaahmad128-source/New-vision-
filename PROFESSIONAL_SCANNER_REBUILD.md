# PDF Master Tools — Professional Scanner Rebuild

This revision hardens the existing Android scanner around a real document-scanning lifecycle:

**Capture → orientation normalization → document detection → perspective crop → manual corner correction → enhance → single/batch page management → PDF/image export → OCR**

## Included

- Five-tab app shell: Home / Library / Scan / Tools / Me.
- Raised visual center Scan action.
- Single/Batch mode in the scanner.
- Batch page thumbnails with drag reorder.
- Per-page adjust-corners, rotate, duplicate and delete actions.
- Automatic perspective crop after a successful capture/import.
- Full-screen manual four-corner correction fallback.
- EXIF orientation normalization before native detection.
- Stronger OpenCV contour scoring with Canny + adaptive-threshold passes.
- Lower document-area threshold so smaller pages can still be detected.
- Improved camera capture surface and honest post-capture auto-crop feedback.
- Real Save Images to Library workflow.
- Library Searchable/OCR filter and Recently Deleted access.

## Verification note

The supplied environment does not contain the Flutter SDK, so this source package was statically reviewed and structurally checked but **not claimed as a green Flutter build**. Before merging/releasing, run:

```text
flutter pub get
flutter analyze
flutter build apk --release
```

Then test on a physical Android phone with:

1. A4 document on a plain background.
2. A4 document at an angle.
3. Small receipt.
4. Dark/low-contrast page.
5. EXIF-rotated photo from gallery.
6. Batch capture of 2–5 pages.
7. Manual corner correction when automatic detection fails.
8. Reorder/delete/duplicate/rotate individual batch pages.
9. Save as PDF and Save Images.
10. OCR after saving.

This rebuild deliberately does not claim real-time live edge detection: the current native detector runs after capture/import. The camera UI therefore says **Auto crop after capture** rather than pretending to detect edges live.
