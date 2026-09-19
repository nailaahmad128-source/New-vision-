# Scanner Live Detection Pass

Implemented a real throttled camera-frame document detection path on Android.

- Camera preview starts an image stream after initialization.
- JPEG camera frames are throttled to roughly one detection every 280 ms.
- Frames are sent to the existing Android/OpenCV scanner channel.
- Native OpenCV returns a normalized four-corner document quadrilateral when confidence is sufficient.
- The camera UI displays the actual detected quadrilateral and a real "Document detected" state.
- Capture stops the image stream before taking the photo.
- Existing post-capture perspective correction remains the authoritative high-quality crop path.
- Devices that cannot provide a compatible stream still retain the normal capture workflow.

This is intentionally not a fake animation/status indicator: the detection state is driven by actual OpenCV results.
