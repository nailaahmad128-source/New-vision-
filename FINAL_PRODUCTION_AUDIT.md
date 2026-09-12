# PDF Master Tools — Final Production Audit Pass

## Completed in this pass
- CI static analysis is now a required gate; analyzer failures no longer get silently ignored.
- CI verifies that `pubspec.lock` exists before analysis/build steps.
- Release builds remain signed only when the CI key.properties is generated from GitHub Secrets.
- Release version remains `2.0.0+12`.
- Android package remains `com.hameed.pdfmastertools`.
- Existing scanner/live detection/editor, OCR, PDF tools, Library, Windows fallbacks and AdMob cadence work are preserved.

## Verification limitation
A real Android camera/device test and Play Console upload cannot be performed inside this environment. The final release must still be exercised on at least one physical Android device before production rollout.

## Recommended release smoke test
1. Fresh install and permission flow.
2. Single-page document scan with live edge detection.
3. Batch scan: reorder, rotate, crop, filter and save.
4. OCR English and Urdu where supported.
5. PDF open/share/rename/delete/restore.
6. Merge, split, extract, compress, watermark and security tools.
7. ID scan front/back.
8. QR scan/generate.
9. Cold start with network unavailable.
10. Release AAB install/update over the existing Play version.
