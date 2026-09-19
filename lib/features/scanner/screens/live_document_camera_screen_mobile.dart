import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'corner_adjust_screen.dart';

enum ScannerMode {
  document,
  idCard,
  book,
  qr,
}

class LiveDocumentCameraScreen extends StatefulWidget {
  const LiveDocumentCameraScreen({super.key, this.initialMode});

  /// Preselects a scan mode (e.g. [ScannerMode.idCard] when launched from
  /// the dedicated ID scan flow) so live detection uses the right tuning
  /// from the first frame instead of defaulting to Document.
  final ScannerMode? initialMode;

  @override
  State<LiveDocumentCameraScreen> createState() =>
      _LiveDocumentCameraScreenState();
}

typedef _ScanMode = ScannerMode;

class _LiveDocumentCameraScreenState
    extends State<LiveDocumentCameraScreen> {
  static const Color _teal = Color(0xFF01D7A5);
  static const Color _navy = Color(0xFF0D1722);

  static const MethodChannel _scannerChannel =
      MethodChannel('com.hameed.pdfmastertools/scanner');

  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  final ImagePicker _galleryPicker = ImagePicker();

  bool _ready = false;
  bool _busy = false;
  bool _flashOn = false;

  // BUG FIX (race condition, requirement #14): `_busy` only means "a
  // full-resolution capture is in progress". Nothing previously stopped a
  // second `detectDocumentFrame` round-trip from starting before the first
  // one returned. On a slower device, a single native OpenCV call can take
  // longer than the 90ms poll interval, so calls could overlap — and
  // because Flutter's MethodChannel gives no ordering guarantee on when
  // each async call resolves, a slower *older* frame's result could land
  // after a newer one and stomp fresh corner data with stale data,
  // corrupting the stability/smoothing logic. This flag makes frame
  // detection single-flight: at most one in-flight detection call at a
  // time, using the newest frame only.
  bool _detecting = false;

  late _ScanMode _mode;

  List<Offset>? _documentCorners;
  List<Offset>? _smoothedCorners;

  DateTime _lastDetection =
      DateTime.fromMillisecondsSinceEpoch(0);

  DateTime? _stableSince;

  int _stableFrames = 0;
  bool _captureRequested = false;

  // Laplacian-variance sharpness of the most recent analyzed frame, reported
  // by the native detector. Auto-capture waits for this to clear a floor so
  // a genuinely blurry frame (motion, hunting autofocus) is never captured
  // just because the corners happened to sit still for a moment.
  double _lastSharpness = 0.0;

  // The native Laplacian-variance metric is computed on a fixed 960px-wide
  // downscale of the live frame (see MainActivity.findBestDocument), so its
  // scale is at least consistent frame-to-frame and mode-to-mode. It is
  // still just a heuristic threshold, not a calibrated value — 18.0 was a
  // single flat number with no stated rationale. Made mode-aware instead of
  // one-size-fits-all: document mode is what gets fed to OCR, so it asks
  // for a slightly sharper frame; ID cards and books are typically photographed
  // at steadier, closer range with more contrast-y edges, so a lower floor
  // avoids making users wait for focus hunting to fully settle.
  // NOTE: these values are still a starting point, not something verified
  // against real camera sensors/lenses — they need tuning on physical
  // Android devices across a range of cameras.
  double get _minSharpness {
    switch (_mode) {
      case _ScanMode.document:
        return 20.0;
      case _ScanMode.idCard:
        return 14.0;
      case _ScanMode.book:
        return 12.0;
      case _ScanMode.qr:
        return 0.0;
    }
  }

  String _status = 'Place the document inside the camera';
  String? _qrText;

  static const Duration _detectionInterval =
      Duration(milliseconds: 90);

  static const Duration _requiredStableDuration =
      Duration(milliseconds: 850);

  static const int _requiredStableFrames = 7;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode ?? _ScanMode.document;
    if (_mode == _ScanMode.qr) {
      _status = 'Point the camera at a QR code';
    }

    // BUG FIX (coordinate/rotation mapping): the app allows both
    // portraitUp and portraitDown (see main.dart). The native detector
    // rotates each YUV frame using only `sensorOrientation`, a single
    // fixed constant that is only correct when the device is held
    // right-side-up. If the phone is physically upside down
    // (portraitDown), that fixed rotation is wrong by 180°, so OpenCV's
    // corners would be computed for a frame that doesn't match what's on
    // screen and the overlay would appear rotated/mirrored. Rather than
    // plumb a live accelerometer-based orientation signal through the
    // MethodChannel (a much bigger change), the scanner screen locks to
    // portraitUp for the duration of the session, which removes the
    // ambiguity entirely. The app-wide preference is restored on dispose.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        throw Exception('No camera found.');
      }

      final backCamera = _cameras.firstWhere(
        (camera) =>
            camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      await _createController(backCamera);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Camera error: $e'),
        ),
      );
    }
  }

  Future<void> _createController(
    CameraDescription camera,
  ) async {
    final oldController = _controller;

    if (oldController != null) {
      try {
        if (oldController.value.isStreamingImages) {
          await oldController.stopImageStream();
        }
      } catch (_) {}

      await oldController.dispose();
    }

    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );

    _controller = controller;

    await controller.initialize();

    if (!mounted) return;

    setState(() {
      _ready = true;
      _documentCorners = null;
      _smoothedCorners = null;
      _stableFrames = 0;
      _stableSince = null;
      _lastSharpness = 0.0;
      _status = 'Place the document inside the camera';
    });

    await controller.startImageStream(
      _processCameraFrame,
    );
  }

  void _processCameraFrame(CameraImage image) {
    if (_busy ||
        _detecting ||
        !_ready ||
        _captureRequested ||
        _mode == _ScanMode.qr) {
      return;
    }

    final now = DateTime.now();

    if (now.difference(_lastDetection) <
        _detectionInterval) {
      return;
    }

    _lastDetection = now;

    // Capture the controller/camera actually producing this frame right
    // now, synchronously, before any await — if the user switches camera
    // mid-flight, `_controller` may be reassigned before this detection
    // call resolves, which would otherwise apply the *new* camera's
    // sensorOrientation to a frame that came from the *old* one.
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    _detecting = true;
    _detectFrame(image, controller.description.sensorOrientation)
        .whenComplete(() => _detecting = false);
  }

  Future<void> _detectFrame(CameraImage image, int sensorOrientation) async {
    try {
      if (!Platform.isAndroid) {
        return;
      }

      if (image.planes.isEmpty) {
        return;
      }

      final y = image.planes[0];

      final response =
          await _scannerChannel.invokeMethod<Map<dynamic, dynamic>>(
        'detectDocumentFrame',
        <String, dynamic>{
          'bytes': y.bytes,
          'width': image.width,
          'height': image.height,
          'rotation': sensorOrientation,
          'rowStride': y.bytesPerRow,
          'pixelStride': y.bytesPerPixel ?? 1,
          'mode': _nativeMode,
        },
      );

      if (!mounted || _busy) return;

      _lastSharpness =
          (response?['sharpness'] as num?)?.toDouble() ?? _lastSharpness;

      final result = response?['corners'];

      if (result is! List || result.length != 4) {
        _handleNoDocument();
        return;
      }

      final corners = <Offset>[];

      for (final item in result) {
        if (item is! Map) {
          _handleNoDocument();
          return;
        }

        final x =
            (item['x'] as num?)?.toDouble();

        final yValue =
            (item['y'] as num?)?.toDouble();

        if (x == null || yValue == null) {
          _handleNoDocument();
          return;
        }

        corners.add(
          Offset(
            x.clamp(0.0, 1.0),
            yValue.clamp(0.0, 1.0),
          ),
        );
      }

      if (corners.length != 4) {
        _handleNoDocument();
        return;
      }

      _updateDetection(corners);
    } catch (_) {
      // Never stop the camera because live detection failed.
    }
  }

  void _handleNoDocument() {
    if (!mounted) return;

    _stableFrames = 0;
    _stableSince = null;

    if (_documentCorners != null ||
        _status != 'Place the document inside the camera') {
      setState(() {
        _documentCorners = null;
        _smoothedCorners = null;
        _status = 'Place the document inside the camera';
      });
    }
  }

  void _updateDetection(List<Offset> corners) {
    final smoothed = _smoothCorners(corners);

    final movement = _cornerMovement(
      _smoothedCorners,
      smoothed,
    );

    if (movement > 0.020) {
      _stableFrames = 0;
      _stableSince = DateTime.now();

      if (mounted) {
        setState(() {
          _documentCorners = smoothed;
          _smoothedCorners = smoothed;
          _status = 'Hold steady...';
        });
      }

      return;
    }

    if (_smoothedCorners == null) {
      _stableFrames = 0;
      _stableSince = DateTime.now();
    }

    _stableFrames++;

    _documentCorners = smoothed;
    _smoothedCorners = smoothed;

    final stableTime = _stableSince == null
        ? Duration.zero
        : DateTime.now().difference(_stableSince!);

    final areaRatio = _quadAreaRatio(smoothed);
    final tooSmall = areaRatio < _comfortableMinArea;
    final tooLarge = areaRatio > 0.94;
    final sharpEnough = _lastSharpness >= _minSharpness;

    final stableEnough =
        _stableFrames >= _requiredStableFrames &&
        stableTime >= _requiredStableDuration;

    final readyForCapture =
        stableEnough && sharpEnough && !tooSmall && !tooLarge;

    final status = tooSmall
        ? 'Move closer'
        : tooLarge
            ? 'Move back a little'
            : readyForCapture
                ? 'Perfect — capturing...'
                : stableEnough && !sharpEnough
                    ? 'Hold steady — focusing...'
                    : 'Document detected • Hold steady';

    if (mounted) {
      setState(() {
        _documentCorners = smoothed;
        _smoothedCorners = smoothed;
        _status = status;
      });
    }

    if (readyForCapture &&
        !_captureRequested &&
        !_busy) {
      _captureRequested = true;
      _capture();
    }
  }

  List<Offset> _smoothCorners(
    List<Offset> current,
  ) {
    final previous = _smoothedCorners;

    if (previous == null ||
        previous.length != 4) {
      return List<Offset>.from(current);
    }

    const alpha = 0.68;

    return List<Offset>.generate(
      4,
      (index) {
        final old = previous[index];
        final now = current[index];

        return Offset(
          old.dx * alpha + now.dx * (1 - alpha),
          old.dy * alpha + now.dy * (1 - alpha),
        );
      },
    );
  }

  /// Shoelace-formula area of the (normalized 0..1) quad, used only for
  /// "move closer / move back" guidance — not for detection itself.
  double _quadAreaRatio(List<Offset> c) {
    if (c.length != 4) return 0.0;
    double sum = 0;
    for (var i = 0; i < 4; i++) {
      final a = c[i];
      final b = c[(i + 1) % 4];
      sum += a.dx * b.dy - b.dx * a.dy;
    }
    return sum.abs() / 2.0;
  }

  /// Comfortable minimum frame-fill fraction below which we ask the user to
  /// move closer. ID cards are legitimately scanned much smaller in-frame
  /// than a document or open book, so this is mode-aware.
  double get _comfortableMinArea {
    switch (_mode) {
      case _ScanMode.idCard:
        return 0.04;
      case _ScanMode.book:
        return 0.16;
      case _ScanMode.document:
      case _ScanMode.qr:
        return 0.09;
    }
  }

  double _cornerMovement(
    List<Offset>? previous,
    List<Offset> current,
  ) {
    if (previous == null ||
        previous.length != 4 ||
        current.length != 4) {
      return 1.0;
    }

    double total = 0;

    for (var i = 0; i < 4; i++) {
      final dx =
          previous[i].dx - current[i].dx;
      final dy =
          previous[i].dy - current[i].dy;

      total +=
          (dx * dx + dy * dy);
    }

    return total / 4;
  }

  /// Runs the native OpenCV detector on the just-captured, full-resolution
  /// photo and, if it finds a usable quad, perspective-crops using those
  /// corners — i.e. corners re-detected on the original, never the
  /// low-resolution live-preview frame. Returns the cropped file path, or
  /// null if either step failed or found nothing.
  Future<String?> _detectAndCropHighRes(String path) async {
    try {
      final detected = await _scannerChannel.invokeMethod<List<dynamic>>(
        'detectDocument',
        <String, dynamic>{'path': path, 'mode': _nativeMode},
      );

      if (detected == null || detected.length != 4) return null;

      final points = <Map<String, dynamic>>[];
      for (final item in detected) {
        if (item is Map) {
          points.add({'x': item['x'], 'y': item['y']});
        }
      }
      if (points.length != 4) return null;

      return await _scannerChannel.invokeMethod<String>(
        'perspectiveCrop',
        <String, dynamic>{'path': path, 'points': points},
      );
    } catch (_) {
      return null;
    }
  }

  /// Perspective-crops [path] using an explicit set of normalized (0..1)
  /// corners rather than asking the native side to detect them.
  Future<String?> _cropWithCorners(String path, List<Offset> corners) async {
    try {
      final points = corners
          .map((o) => {'x': o.dx, 'y': o.dy})
          .toList(growable: false);

      return await _scannerChannel.invokeMethod<String>(
        'perspectiveCrop',
        <String, dynamic>{'path': path, 'points': points},
      );
    } catch (_) {
      return null;
    }
  }

  /// Cheap, dependency-free sanity check on a normalized quad before we
  /// trust it enough to crop with it: correct point count, every coordinate
  /// actually inside the frame, and a non-degenerate (not sliver-thin)
  /// enclosed area. This is what requirement #7 calls "mathematically
  /// valid" — it does not re-run OpenCV, it just guards against handing a
  /// corrupted/degenerate quad to the native perspective-warp.
  bool _isMathematicallyValidQuad(List<Offset>? corners) {
    if (corners == null || corners.length != 4) return false;

    for (final c in corners) {
      if (c.dx.isNaN ||
          c.dy.isNaN ||
          c.dx < 0.0 ||
          c.dx > 1.0 ||
          c.dy < 0.0 ||
          c.dy > 1.0) {
        return false;
      }
    }

    return _quadAreaRatio(corners) > 0.015;
  }

  /// Last-resort tier: both the live preview's stable quad AND a fresh
  /// high-resolution detection failed to produce something usable. Rather
  /// than silently returning the raw, uncropped photo (the previous
  /// behavior), hand the user straight to manual corner adjustment so the
  /// scan is never lost and never silently wrong. If the user cancels that
  /// screen, the raw photo is still returned — manual capture must always
  /// produce a result and must never leave the user stuck.
  Future<XFile> _resolveWithManualCorners(XFile original) async {
    try {
      final bytes = await File(original.path).readAsBytes();

      if (!mounted) return original;

      final corners = await Navigator.of(context).push<List<Offset>>(
        MaterialPageRoute(
          builder: (_) => CornerAdjustScreen(
            imagePath: original.path,
            imageBytes: bytes,
          ),
        ),
      );

      if (corners == null || corners.length != 4) return original;

      final cropped = await _cropWithCorners(original.path, corners);

      if (cropped != null &&
          cropped.isNotEmpty &&
          await File(cropped).exists()) {
        return XFile(cropped);
      }

      return original;
    } catch (_) {
      return original;
    }
  }

  Future<void> _capture() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        _busy) {
      _captureRequested = false;
      return;
    }

    // Snapshot the live, stability-gated corners before capture clears
    // them. If detection on the full-resolution photo comes back empty,
    // this is the tier-2 fallback described in requirement #7: the live
    // preview and the captured photo share the same sensor aspect ratio,
    // so these already-validated normalized corners still line up.
    final liveCornersAtCapture = _documentCorners == null
        ? null
        : List<Offset>.from(_documentCorners!);

    if (mounted) {
      setState(() {
        _busy = true;
        _status = 'Capturing document...';
      });
    }

    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }

      final original =
          await controller.takePicture();

      // Tier 1: detect fresh on the high-resolution original — never the
      // low-res live preview frame.
      String? croppedPath = await _detectAndCropHighRes(original.path);

      // Tier 2: high-res detection failed but the live preview had a
      // stable, sane quad right before the shutter fired.
      if ((croppedPath == null || croppedPath.isEmpty) &&
          _isMathematicallyValidQuad(liveCornersAtCapture)) {
        croppedPath =
            await _cropWithCorners(original.path, liveCornersAtCapture!);
      }

      if (!mounted) return;

      if (croppedPath != null &&
          croppedPath.isNotEmpty &&
          await File(croppedPath).exists()) {
        Navigator.of(context).pop(
          XFile(croppedPath),
        );
        return;
      }

      // Tier 3: both automatic passes failed. Never return a silently
      // uncropped photo and call it done.
      final resolved = await _resolveWithManualCorners(original);
      if (!mounted) return;
      Navigator.of(context).pop(resolved);
    } catch (e) {
      _captureRequested = false;

      if (!mounted) return;

      setState(() {
        _busy = false;
        _status = 'Could not capture. Try again.';
        _stableFrames = 0;
        _stableSince = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not capture document: $e',
          ),
        ),
      );

      try {
        await controller.startImageStream(
          _processCameraFrame,
        );
      } catch (_) {}
    }
  }

  Future<void> _manualCapture() async {
    if (_busy) return;

    _captureRequested = true;
    await _capture();
  }

  Future<void> _pickFromGallery() async {
    if (_busy) return;

    final XFile? picked;

    try {
      picked = await _galleryPicker.pickImage(
        source: ImageSource.gallery,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open gallery: $e')),
      );
      return;
    }

    if (picked == null || !mounted) return;

    final controller = _controller;

    setState(() {
      _busy = true;
      _status = 'Processing selected image...';
    });

    try {
      if (controller != null &&
          controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {}

    try {
      String? croppedPath;

      try {
        final detected = await _scannerChannel
            .invokeMethod<List<dynamic>>(
          'detectDocument',
          <String, dynamic>{
            'path': picked.path,
            'mode': _nativeMode,
          },
        );

        if (detected != null && detected.length == 4) {
          final points = <Map<String, dynamic>>[];

          for (final item in detected) {
            if (item is Map) {
              points.add({'x': item['x'], 'y': item['y']});
            }
          }

          if (points.length == 4) {
            croppedPath = await _scannerChannel
                .invokeMethod<String>(
              'perspectiveCrop',
              <String, dynamic>{
                'path': picked.path,
                'points': points,
              },
            );
          }
        }
      } catch (_) {
        croppedPath = null;
      }

      if (!mounted) return;

      if (croppedPath != null &&
          croppedPath.isNotEmpty &&
          await File(croppedPath).exists()) {
        Navigator.of(context).pop(XFile(croppedPath));
      } else {
        // Detection failed on the picked image — return it unmodified
        // rather than pretending a crop happened.
        Navigator.of(context).pop(picked);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _busy = false;
        _status = 'Place the document inside the camera';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not process the selected image: $e')),
      );

      try {
        await controller?.startImageStream(_processCameraFrame);
      } catch (_) {}
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;

    if (controller == null) return;

    try {
      _flashOn = !_flashOn;

      await controller.setFlashMode(
        _flashOn
            ? FlashMode.torch
            : FlashMode.off,
      );

      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Flash is not available on this camera.',
          ),
        ),
      );
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 ||
        _busy) {
      return;
    }

    final current =
        _controller?.description;

    if (current == null) return;

    final index =
        _cameras.indexOf(current);

    final next =
        _cameras[(index + 1) % _cameras.length];

    setState(() {
      _ready = false;
      _documentCorners = null;
      _smoothedCorners = null;
    });

    _captureRequested = false;
    _stableFrames = 0;
    _stableSince = null;

    await _createController(next);
  }

  void _selectMode(_ScanMode mode) {
    if (_busy) return;

    setState(() {
      _mode = mode;
      _documentCorners = null;
      _smoothedCorners = null;
      _stableFrames = 0;
      _stableSince = null;
      _lastSharpness = 0.0;
      _qrText = null;

      _status = mode == _ScanMode.qr
          ? 'Point the camera at a QR code'
          : 'Place the document inside the camera';
    });
  }

  String get _modeLabel {
    switch (_mode) {
      case _ScanMode.document:
        return 'Document';
      case _ScanMode.idCard:
        return 'ID Card';
      case _ScanMode.book:
        return 'Book';
      case _ScanMode.qr:
        return 'QR Code';
    }
  }

  /// The string the native OpenCV detector uses to pick mode-tuned
  /// thresholds (smaller minimum area + aspect bonus for ID cards, relaxed
  /// rectangularity for books). Must match MainActivity.kt's `tuningFor`.
  String get _nativeMode {
    switch (_mode) {
      case _ScanMode.idCard:
        return 'idCard';
      case _ScanMode.book:
        return 'book';
      case _ScanMode.document:
      case _ScanMode.qr:
        return 'document';
    }
  }

  @override
  void dispose() {
    final controller = _controller;

    if (controller != null) {
      try {
        controller.stopImageStream();
      } catch (_) {}
    }

    controller?.dispose();

    // Restore the app-wide orientation preference set in main.dart now
    // that the rotation-sensitive live detection session is over.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: !_ready ||
              controller == null ||
              !controller.value.isInitialized
          ? const Center(
              child: CircularProgressIndicator(
                color: _teal,
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                if (_mode == _ScanMode.qr)
                  MobileScanner(
                    onDetect: (capture) {
                      if (!mounted ||
                          capture.barcodes.isEmpty) {
                        return;
                      }

                      final value =
                          capture.barcodes.first.rawValue;

                      if (value != null &&
                          value.isNotEmpty) {
                        setState(() {
                          _qrText = value;
                          _status = 'QR detected';
                        });
                      }
                    },
                  )
                else
                  CameraPreview(controller),

                if (_mode != _ScanMode.qr)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _DocumentOverlayPainter(
                        corners: _documentCorners,
                        color: _teal,
                      ),
                    ),
                  ),

                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(
                          18,
                          12,
                          18,
                          0,
                        ),
                        child: Row(
                          children: [
                            _glassButton(
                              icon:
                                  Icons.close_rounded,
                              onTap: () {
                                Navigator.of(context)
                                    .pop();
                              },
                            ),
                            const Spacer(),
                            const Text(
                              'ScanFlow',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            _glassButton(
                              icon: _flashOn
                                  ? Icons
                                      .flash_on_rounded
                                  : Icons
                                      .flash_off_rounded,
                              onTap: _toggleFlash,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      AnimatedSwitcher(
                        duration:
                            const Duration(
                          milliseconds: 180,
                        ),
                        child: Container(
                          key: ValueKey(
                            '$_status$_modeLabel',
                          ),
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration:
                              BoxDecoration(
                            color: Colors.black
                                .withValues(
                              alpha: 0.55,
                            ),
                            borderRadius:
                                BorderRadius.circular(
                              24,
                            ),
                            border: Border.all(
                              color: _documentCorners !=
                                      null
                                  ? _teal
                                  : Colors.white24,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize:
                                MainAxisSize.min,
                            children: [
                              Icon(
                                _documentCorners !=
                                        null
                                    ? Icons
                                        .check_circle_rounded
                                    : Icons
                                        .document_scanner_outlined,
                                color: _teal,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _status,
                                  style:
                                      const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_qrText != null)
                        Padding(
                          padding:
                              const EdgeInsets.only(
                            top: 12,
                            left: 24,
                            right: 24,
                          ),
                          child: Container(
                            padding:
                                const EdgeInsets.all(12),
                            decoration:
                                BoxDecoration(
                              color: Colors.black
                                  .withValues(
                                alpha: 0.70,
                              ),
                              borderRadius:
                                  BorderRadius.circular(
                                14,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _qrText!,
                                  textAlign:
                                      TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: _qrText!),
                                    );
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text('Copied'),
                                        duration:
                                            Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.copy_rounded,
                                    size: 16,
                                    color: _teal,
                                  ),
                                  label: const Text(
                                    'Copy',
                                    style: TextStyle(
                                      color: _teal,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(
                                      0,
                                      28,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize
                                            .shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      const Spacer(),

                      Container(
                        margin:
                            const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        decoration:
                            BoxDecoration(
                          color: Colors.black
                              .withValues(
                            alpha: 0.58,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            22,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .spaceAround,
                          children: [
                            _ModeItem(
                              label: 'Document',
                              selected:
                                  _mode ==
                                      _ScanMode.document,
                              onTap: () =>
                                  _selectMode(
                                _ScanMode.document,
                              ),
                            ),
                            _ModeItem(
                              label: 'ID Card',
                              selected:
                                  _mode ==
                                      _ScanMode.idCard,
                              onTap: () =>
                                  _selectMode(
                                _ScanMode.idCard,
                              ),
                            ),
                            _ModeItem(
                              label: 'Book',
                              selected:
                                  _mode ==
                                      _ScanMode.book,
                              onTap: () =>
                                  _selectMode(
                                _ScanMode.book,
                              ),
                            ),
                            _ModeItem(
                              label: 'QR Code',
                              selected:
                                  _mode ==
                                      _ScanMode.qr,
                              onTap: () =>
                                  _selectMode(
                                _ScanMode.qr,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(
                          38,
                          0,
                          38,
                          22,
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .spaceBetween,
                          children: [
                            _bottomAction(
                              Icons
                                  .photo_library_outlined,
                              'Gallery',
                              _pickFromGallery,
                            ),

                            GestureDetector(
                              onTap: _manualCapture,
                              child: Container(
                                width: 82,
                                height: 82,
                                decoration:
                                    BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 5,
                                  ),
                                ),
                                child: _busy
                                    ? const Padding(
                                        padding:
                                            EdgeInsets.all(
                                          25,
                                        ),
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth: 3,
                                          color: _teal,
                                        ),
                                      )
                                    : const SizedBox(),
                              ),
                            ),

                            _bottomAction(
                              Icons
                                  .flip_camera_ios_rounded,
                              'Switch',
                              _switchCamera,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _glassButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.black.withValues(
        alpha: 0.45,
      ),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.all(11),
          child: Icon(
            icon,
            color: Colors.white,
            size: 25,
          ),
        ),
      ),
    );
  }

  Widget _bottomAction(
    IconData icon,
    String label,
    VoidCallback? onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.black.withValues(
                alpha: 0.52,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white24,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF01D7A5)
              : Colors.transparent,
          borderRadius:
              BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? const Color(0xFF0D1722)
                : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DocumentOverlayPainter
    extends CustomPainter {
  final List<Offset>? corners;
  final Color color;

  const _DocumentOverlayPainter({
    required this.corners,
    required this.color,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final points = corners;

    if (points == null ||
        points.length != 4) {
      return;
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(
        points[0].dx * size.width,
        points[0].dy * size.height,
      )
      ..lineTo(
        points[1].dx * size.width,
        points[1].dy * size.height,
      )
      ..lineTo(
        points[2].dx * size.width,
        points[2].dy * size.height,
      )
      ..lineTo(
        points[3].dx * size.width,
        points[3].dy * size.height,
      )
      ..close();

    canvas.drawPath(
      path,
      paint,
    );

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(
        Offset(
          point.dx * size.width,
          point.dy * size.height,
        ),
        7,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _DocumentOverlayPainter
        oldDelegate,
  ) {
    return oldDelegate.corners != corners ||
        oldDelegate.color != color;
  }
}
