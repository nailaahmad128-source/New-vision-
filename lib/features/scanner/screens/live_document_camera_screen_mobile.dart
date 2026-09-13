import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Full-screen document capture surface inspired by modern document scanners.
/// The design is intentionally original while following the familiar scanner
/// workflow: immersive preview, document frame, capture, flash, camera flip,
/// gallery import and scan modes.
class LiveDocumentCameraScreen extends StatefulWidget {
  const LiveDocumentCameraScreen({super.key});

  @override
  State<LiveDocumentCameraScreen> createState() => _LiveDocumentCameraScreenState();
}

class _LiveDocumentCameraScreenState extends State<LiveDocumentCameraScreen> {
  final ImagePicker _picker = ImagePicker();
  static const _scannerChannel =
      MethodChannel('com.hameed.pdfmastertools/scanner');
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _initializing = true;
  bool _capturing = false;
  bool _flash = false;
  bool _autoScan = true;
  bool _idMode = false;
  Timer? _autoTimer;
  bool _autoBusy = false;
  bool _streamStarted = false;
  bool _frameBusy = false;
  DateTime? _lastFrameAt;
  List<dynamic>? _liveCorners;
  List<dynamic>? _previousCorners;
  int _stableFrames = 0;
  String _liveStatus = 'Align the document inside the frame';
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera({int? preferredIndex}) async {
    if (mounted) {
      setState(() {
        _initializing = true;
        _error = null;
      });
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('NoCamera', 'No camera is available.');
      }
      _cameras = cameras;
      _cameraIndex = preferredIndex ?? _cameraIndex.clamp(0, cameras.length - 1);
      final old = _controller;
      final next = CameraController(
        cameras[_cameraIndex],
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      _controller = next;
      await old?.dispose();
      await next.initialize();
      await next.setFlashMode(FlashMode.off);
      if (mounted) {
        setState(() {
          _initializing = false;
          _liveStatus = 'Align the document inside the frame';
          _liveCorners = null;
          _previousCorners = null;
          _stableFrames = 0;
        });
      }
      await _startLiveDetection();
    } on CameraException catch (e) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = e.description ?? e.code;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (_capturing ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }

    setState(() => _capturing = true);
    HapticFeedback.mediumImpact();

    try {
      await _stopLiveDetection();

      final file = await controller.takePicture();
      final processed = await _detectAndCrop(file);

      if (mounted) {
        Navigator.of(context).pop(processed);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not capture document: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<XFile> _detectAndCrop(XFile file) async {
    try {
      final detected =
          await _scannerChannel.invokeMethod<List<dynamic>>(
        'detectDocument',
        {'path': file.path},
      );

      if (detected == null || detected.length != 4) {
        return file;
      }

      final points = detected.map((p) {
        return {
          'x': (p['x'] as num).toDouble(),
          'y': (p['y'] as num).toDouble(),
        };
      }).toList();

      final output =
          await _scannerChannel.invokeMethod<String>(
        'perspectiveCrop',
        {
          'path': file.path,
          'points': points,
        },
      );

      return output == null ? file : XFile(output);
    } catch (_) {
      return file;
    }
  }

  double _documentArea(List<dynamic> points) {
    if (points.length != 4) return 0;

    double area = 0;
    for (var i = 0; i < 4; i++) {
      final a = points[i];
      final b = points[(i + 1) % 4];
      final ax = (a['x'] as num).toDouble();
      final ay = (a['y'] as num).toDouble();
      final bx = (b['x'] as num).toDouble();
      final by = (b['y'] as num).toDouble();
      area += ax * by - bx * ay;
    }

    return area.abs() / 2;
  }

  Future<void> _startLiveDetection() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _streamStarted ||
        !_autoScan) {
      return;
    }

    try {
      await controller.startImageStream(_processLiveFrame);
      _streamStarted = true;
    } catch (_) {
      _streamStarted = false;
      if (mounted) {
        setState(() {
          _liveStatus = 'Live detection unavailable — use the shutter';
        });
      }
    }
  }

  Future<void> _stopLiveDetection() async {
    final controller = _controller;
    if (controller == null) return;

    if (controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } catch (_) {}
    }

    _streamStarted = false;
    _frameBusy = false;
  }

  Future<void> _processLiveFrame(CameraImage image) async {
    if (!_autoScan ||
        _autoBusy ||
        _capturing ||
        !_streamStarted ||
        _frameBusy ||
        _initializing) {
      return;
    }

    final now = DateTime.now();
    final last = _lastFrameAt;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 220)) {
      return;
    }

    if (image.planes.isEmpty) return;

    _lastFrameAt = now;
    _frameBusy = true;

    try {
      final bytes = image.planes.first.bytes;

      final detected =
          await _scannerChannel.invokeMethod<List<dynamic>>(
        'detectDocumentFrame',
        {
          'bytes': bytes,
          'width': image.width,
          'height': image.height,
          'rotation': _controller?.description.sensorOrientation ?? 0,
        },
      );

      if (detected != null && detected.length == 4) {
        final area = _documentArea(detected);
        final stable = _isStableCorners(detected);

        if (mounted) {
          setState(() {
            _liveCorners = detected;
            _liveStatus = area >= 0.18
                ? (!_isInsideScanFrame(detected)
                    ? 'Keep the whole document inside the frame'
                    : (stable
                        ? 'Hold steady… scanning'
                        : 'Document detected — hold steady'))
                : 'Move closer to the document';
          });
        }

        final insideFrame = _isInsideScanFrame(detected);

        if (stable && insideFrame && area >= 0.14) {
          _stableFrames++;
        } else {
          _stableFrames = 0;
        }

        // Require several consecutive stable frames before auto capture.
        // This prevents accidental captures while the phone is moving.
        if (_stableFrames >= 7) {
          await _performLiveCapture();
        }
      } else {
        _stableFrames = 0;
        if (mounted) {
          setState(() {
            _liveCorners = null;
            _liveStatus = 'Align the document inside the frame';
          });
        }
      }
    } catch (_) {
      // Live detection is intentionally silent.
    } finally {
      _frameBusy = false;
    }
  }

  bool _isInsideScanFrame(List<dynamic> points) {
    if (points.length != 4) return false;

    // Keep the detected document safely inside the visible scanning area.
    // A small margin avoids capturing table edges or objects touching the
    // extreme borders of the camera preview.
    for (final point in points) {
      final x = (point['x'] as num).toDouble();
      final y = (point['y'] as num).toDouble();

      if (x < 0.035 || x > 0.965 || y < 0.035 || y > 0.965) {
        return false;
      }
    }

    return true;
  }

  bool _isStableCorners(List<dynamic> points) {
    final previous = _previousCorners;
    _previousCorners = points;

    if (previous == null || previous.length != 4) return false;

    double total = 0;

    for (var i = 0; i < 4; i++) {
      final a = previous[i];
      final b = points[i];

      final dx =
          (a['x'] as num).toDouble() - (b['x'] as num).toDouble();
      final dy =
          (a['y'] as num).toDouble() - (b['y'] as num).toDouble();

      total += (dx * dx + dy * dy);
    }

    return (total / 4) < 0.0012;
  }

  Future<void> _performLiveCapture() async {
    if (_autoBusy || _capturing) return;

    _autoBusy = true;
    _capturing = true;

    try {
      await _stopLiveDetection();

      final controller = _controller;
      if (controller == null ||
          !controller.value.isInitialized ||
          controller.value.isTakingPicture) {
        return;
      }

      HapticFeedback.mediumImpact();

      final file = await controller.takePicture();
      final processed = await _detectAndCrop(file);

      if (mounted) {
        Navigator.of(context).pop(processed);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _liveStatus = 'Could not scan — try again';
          _stableFrames = 0;
        });
      }
    } finally {
      _autoBusy = false;
      _capturing = false;
    }
  }

  Future<void> _setAutoScan(bool value) async {
    setState(() {
      _autoScan = value;
      _stableFrames = 0;
      _liveCorners = null;
      _previousCorners = null;
      _liveStatus = value
          ? 'Align the document inside the frame'
          : 'Manual capture mode';
    });

    if (value) {
      await _startLiveDetection();
    } else {
      await _stopLiveDetection();
    }
  }

  Future<void> _pickFromGallery() async {
    await _stopLiveDetection();
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (file != null && mounted) Navigator.of(context).pop(file);
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null) return;
    final next = !_flash;
    try {
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _flash = next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Flash is not available on this camera.')),
        );
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _initializing) return;
    final next = (_cameraIndex + 1) % _cameras.length;
    await _initCamera(preferredIndex: next);
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    if (_controller?.value.isStreamingImages == true) {
      unawaited(_controller!.stopImageStream());
    }
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller?.value.isInitialized == true && !_initializing && _error == null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (ready)
            _ImmersiveCameraPreview(controller: controller!)
          else
            _CameraLoading(error: _error, onRetry: _initCamera),

          if (ready) ...[
            const _ScannerTopGradient(),
            const _ScannerBottomGradient(),
            if (_liveCorners != null)
              IgnorePointer(
                child: CustomPaint(
                  painter: _LiveDocumentPainter(
                    corners: _liveCorners!,
                    stable: _stableFrames >= 4,
                    cameraAspectRatio: controller.value.aspectRatio,
                  ),
                ),
              ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Row(
                      children: [
                        _GlassButton(icon: Icons.close_rounded, onTap: () => Navigator.of(context).pop()),
                        const Spacer(),
                        const Text(
                          'Scan Document',
                          style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        _GlassButton(
                          icon: _flash ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                          onTap: _toggleFlash,
                        ),
                        const SizedBox(width: 8),
                        _GlassButton(icon: Icons.flip_camera_android_rounded, onTap: _switchCamera),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final frameWidth =
                                constraints.maxWidth.clamp(250.0, 430.0);
                            final maxFrameHeight =
                                (constraints.maxHeight * .72).clamp(220.0, 560.0);

                            return ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: frameWidth,
                                maxHeight: maxFrameHeight,
                              ),
                              child: AspectRatio(
                                aspectRatio: _idMode ? 1.586 : .707,
                                child: _ScanFrame(idMode: _idMode),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: _idMode
                                ? const _DetectionHint(
                                    key: ValueKey('id'),
                                    text: 'Align the ID card inside the frame',
                                  )
                                : _autoScan
                                    ? _DetectionHint(
                                        key: const ValueKey('auto'),
                                        text: _liveStatus,
                                      )
                                    : const _DetectionHint(
                                        key: ValueKey('manual'),
                                        text: 'Place the whole document inside the frame',
                                      ),
                          ),
                          const SizedBox(height: 10),
                          _ModeSelector(
                            idMode: _idMode,
                            autoScan: _autoScan,
                            onDocument: () =>
                                setState(() => _idMode = false),
                            onId: () => setState(() => _idMode = true),
                            onAutoChanged: _setAutoScan,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 92,
                            child: Row(
                              children: [
                                Expanded(
                                  child: _BottomTool(
                                    icon: Icons.photo_library_outlined,
                                    label: 'Gallery',
                                    onTap: _pickFromGallery,
                                  ),
                                ),
                                Expanded(
                                  child: Center(
                                    child: GestureDetector(
                                      onTap: _capture,
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 120),
                                        width: _capturing ? 72 : 78,
                                        height: _capturing ? 72 : 78,
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: .98),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: .75),
                                            width: 3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: .35),
                                              blurRadius: 18,
                                            ),
                                          ],
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.black
                                                  .withValues(alpha: .16),
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: _BottomTool(
                                    icon: Icons.document_scanner_outlined,
                                    label: 'Auto',
                                    active: _autoScan,
                                    onTap: () =>
                                        _setAutoScan(!_autoScan),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ImmersiveCameraPreview extends StatelessWidget {
  final CameraController controller;

  const _ImmersiveCameraPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

class _LiveDocumentPainter extends CustomPainter {
  final List<dynamic> corners;
  final bool stable;
  final double cameraAspectRatio;

  const _LiveDocumentPainter({
    required this.corners,
    required this.stable,
    required this.cameraAspectRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length != 4) return;

    final screenRatio = size.width / size.height;

    double previewWidth;
    double previewHeight;
    double offsetX;
    double offsetY;

    if (screenRatio > cameraAspectRatio) {
      previewHeight = size.height;
      previewWidth = previewHeight * cameraAspectRatio;
      offsetX = (size.width - previewWidth) / 2;
      offsetY = 0;
    } else {
      previewWidth = size.width;
      previewHeight = previewWidth / cameraAspectRatio;
      offsetX = 0;
      offsetY = (size.height - previewHeight) / 2;
    }

    final points = corners.map((p) {
      final x = (p['x'] as num).toDouble().clamp(0.0, 1.0);
      final y = (p['y'] as num).toDouble().clamp(0.0, 1.0);

      return Offset(
        offsetX + x * previewWidth,
        offsetY + y * previewHeight,
      );
    }).toList();

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(
        alpha: stable ? .10 : .05,
      );

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stable ? 4 : 3
      ..strokeCap = StrokeCap.round
      ..color = stable ? Colors.greenAccent : Colors.white;

    final path = Path()
      ..moveTo(points[0].dx, points[0].dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..lineTo(points[2].dx, points[2].dy)
      ..lineTo(points[3].dx, points[3].dy)
      ..close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, line);

    final cornerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = stable ? Colors.greenAccent : Colors.white;

    const len = 22.0;

    for (var i = 0; i < 4; i++) {
      final point = points[i];
      final next = points[(i + 1) % 4];
      final prev = points[(i + 3) % 4];

      final v1 = next - point;
      final v2 = prev - point;

      final l1 = v1.distance;
      final l2 = v2.distance;

      if (l1 > 0 && l2 > 0) {
        canvas.drawLine(
          point,
          point + v1 / l1 * len,
          cornerPaint,
        );

        canvas.drawLine(
          point,
          point + v2 / l2 * len,
          cornerPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LiveDocumentPainter oldDelegate) {
    return oldDelegate.corners != corners ||
        oldDelegate.stable != stable ||
        oldDelegate.cameraAspectRatio != cameraAspectRatio;
  }
}

class _CameraLoading extends StatelessWidget {
  final String? error;
  final VoidCallback onRetry;
  const _CameraLoading({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (error == null) return const Center(child: CircularProgressIndicator(color: Colors.white));
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_rounded, color: Colors.white, size: 52),
            const SizedBox(height: 14),
            Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 18),
            FilledButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}
