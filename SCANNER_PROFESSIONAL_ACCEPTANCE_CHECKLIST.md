# Smart Scanner — Professional Acceptance Checklist

The scanner is the primary product workflow. Validate these behaviors on real Android devices:

1. Capture an A4/document at a normal angle.
2. Capture a rotated/skewed document; detected corners must follow the physical page.
3. Capture a receipt or small card; small contours must not be discarded too aggressively.
4. Capture under uneven lighting; adaptive threshold/Canny fallback should still find the page where possible.
5. Capture with the page near the frame edge; center-position scoring must not reject valid pages.
6. Capture multiple pages in Batch mode; thumbnails, selection, reorder, duplicate, delete and per-page corner adjustment must remain stable.
7. Manually adjust all four corners; the resulting perspective-corrected image must preserve the selected quadrilateral.
8. Verify EXIF-rotated photos from gallery import.
9. Verify high-resolution photos do not cause UI freezes or excessive memory use.
10. Verify failed detection falls back to manual corner adjustment instead of a dead end.
11. Verify saving to PDF preserves page order and readable resolution.
12. Verify the original source image is never destructively overwritten by crop/enhancement operations.

Important honesty rule:
The current native detector is capture/post-processing based. Do not display fake live "document detected" status unless detection is actually running continuously on camera frames.

Build verification still required in a Flutter environment:
- flutter pub get
- flutter analyze
- flutter build apk --release
