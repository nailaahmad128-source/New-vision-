# Scanner Deep Technical Pass

- Strengthened Android OpenCV document candidate detection with Canny + adaptive threshold,
  morphological closing, external contours, larger candidate search range, and weighted
  rectangularity/angle/aspect/center scoring.
- Preserved EXIF-aware decoding.
- Perspective crop now uses high-quality Lanczos interpolation and caps the output dimensions
  to reduce memory pressure on very large captures.
- Scanner Dart filter re-detection now uses the selected batch page's real source path rather
  than relying only on the currently visible `_image` value.
- No fake live detection overlay was introduced; the camera still honestly reports that
  auto-crop occurs after capture.
- Flutter SDK was not available in this environment, so Flutter analyze/build could not be run.
