import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../tools/screens/id_scan_screen.dart';

/// Full-screen document capture experience inspired by the workflow quality of
/// leading scanner apps, while keeping PDF Master Tools' own identity.
class LiveDocumentCameraScreen extends StatefulWidget {
  const LiveDocumentCameraScreen({super.key});

  @override
  State<LiveDocumentCameraScreen> createState() => _LiveDocumentCameraScreenState();
}

class _LiveDocumentCameraScreenState extends State<LiveDocumentCameraScreen>
    with WidgetsBindingObserver {
  final _picker = ImagePicker();
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _busy = true;
  bool _flash = false;
  bool _detecting = false;
  bool _documentDetected = false;
  List<Offset>? _liveCorners;
  List<Offset>? _stableCorners;
  DateTime _lastDetection = DateTime.fromMillisecondsSinceEpoch(0);

  String? _error;
  String _mode = 'Document';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      unawaited(controller.dispose());
    } else if (state == AppLifecycleState.resumed) {
      _initCamera(preferredIndex: _cameraIndex);
    }
  }

  Future<void> _initCamera({int? preferredIndex}) async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('NoCamera', 'No camera is available on this device.');
      }
      _cameras = cameras;
      _cameraIndex = preferredIndex ?? _cameraIndex.clamp(0, cameras.length - 1);
      final old = _controller;
      final next = CameraController(
        cameras[_cameraIndex],
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _controller = next;
      await old?.dispose();
      await next.initialize();
      await next.setFlashMode(FlashMode.off);
      if (mounted) {
        setState(() { _busy = false; _documentDetected = false; _liveCorners = null; _stableCorners = null; });
        unawaited(_startLiveDetection(next));
      }
    } on CameraException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.description ?? e.code;
          _busy = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _busy = false; });
    }
  }

  Future<void> _startLiveDetection(CameraController controller) async {
    if (!mounted || !controller.value.isInitialized) return;
    try {
      await controller.startImageStream((CameraImage image) {
        final now = DateTime.now();
        if (_detecting || now.difference(_lastDetection).inMilliseconds < 280) return;
        if (image.planes.isEmpty) return;
        final bytes = image.planes.first.bytes;
        if (bytes.length < 1000) return;
        _lastDetection = now;
        _detecting = true;
        _detectFrame(bytes);
      });
    } catch (_) {
      // Some devices do not support a simultaneous preview stream.
      // Capture remains fully functional and native detection still runs after capture.
    }
  }

  Future<void> _detectFrame(Uint8List bytes) async {
    try {
      final result = await const MethodChannel('com.hameed.pdfmastertools/scanner')
          .invokeMethod<List<dynamic>>('detectDocumentBytes', {'bytes': bytes});
      final corners = result?.map((p) => Offset(
        (p['x'] as num).toDouble(),
        (p['y'] as num).toDouble(),
      )).toList();
      if (!mounted) return;
      final detected = corners?.length == 4 ? corners : null;
      if (!mounted) return;
      setState(() {
        _documentDetected = detected != null;
        if (detected == null) {
          _liveCorners = null;
          _stableCorners = null;
        } else {
          _stableCorners = _smoothCorners(_stableCorners, detected, .38);
          _liveCorners = _stableCorners;
        }
      });
    } catch (_) {
      if (mounted) setState(() { _documentDetected = false; _liveCorners = null; _stableCorners = null; });
    } finally {
      _detecting = false;
    }
  }

  List<Offset> _smoothCorners(List<Offset>? previous, List<Offset> next, double alpha) {
    if (previous == null || previous.length != 4) return List<Offset>.from(next);
    return List<Offset>.generate(4, (i) => Offset(
      previous[i].dx + (next[i].dx - previous[i].dx) * alpha,
      previous[i].dy + (next[i].dy - previous[i].dy) * alpha,
    ));
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _busy) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      final file = await controller.takePicture();
      if (mounted) Navigator.of(context).pop(file);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not capture the page: $e')),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_busy) return;
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    Navigator.of(context).pop(file);
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
    if (_cameras.length < 2 || _busy) return;
    await _initCamera(preferredIndex: (_cameraIndex + 1) % _cameras.length);
  }

  void _selectMode(String mode) {
    if (mode == 'ID Card') {
      // Use the project's real front/back ID workflow rather than a fake camera mode.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const IdScanScreen()),
      );
      return;
    }
    setState(() => _mode = mode);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller?.value.isInitialized == true && !_busy && _error == null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (ready)
              Stack(
                fit: StackFit.expand,
                children: [
                  _CameraPreviewWithGuide(controller: controller!),
                  if (_liveCorners?.length == 4)
                    IgnorePointer(child: CustomPaint(painter: _LiveDocumentPainter(
                      _liveCorners!,
                      sourceAspect: (controller.value.previewSize == null) ? .5625 :
                          controller.value.previewSize!.height / controller.value.previewSize!.width,
                    ))),
                ],
              )
            else
              _CameraError(error: _error, onRetry: _initCamera),

            // Top controls: intentionally minimal so the document remains the focus.
            Positioned(
              top: 10,
              left: 14,
              right: 14,
              child: Row(
                children: [
                  _GlassButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  _GlassButton(
                    icon: _flash ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    onTap: ready ? _toggleFlash : null,
                  ),
                  if (_cameras.length > 1) ...[
                    const SizedBox(width: 8),
                    _GlassButton(
                      icon: Icons.flip_camera_android_rounded,
                      onTap: ready ? _switchCamera : null,
                    ),
                  ],
                ],
              ),
            ),

            if (ready)
              Positioned(
                top: 70,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .48),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withValues(alpha: .12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _documentDetected ? Icons.check_circle_rounded : Icons.crop_free_rounded,
                          color: _documentDetected ? Colors.greenAccent : Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          _documentDetected ? 'Document detected' : 'Place the document inside the frame',
                          style: TextStyle(color: _documentDetected ? Colors.greenAccent : Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (ready)
              Positioned(
                left: 0,
                right: 0,
                bottom: 122,
                child: _ModeSelector(
                  selected: _mode,
                  onSelected: _selectMode,
                ),
              ),

            if (ready)
              Positioned(
                left: 22,
                right: 22,
                bottom: 22,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _BottomCameraButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Gallery',
                      onTap: _pickFromGallery,
                    ),
                    GestureDetector(
                      onTap: _capture,
                      child: Container(
                        width: 82,
                        height: 82,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.white.withValues(alpha: .5), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .35),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          child: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 29),
                        ),
                      ),
                    ),
                    _BottomCameraButton(
                      icon: Icons.info_outline_rounded,
                      label: 'Guide',
                      onTap: () => _showGuide(context),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showGuide(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (context) => const Padding(
        padding: EdgeInsets.fromLTRB(22, 4, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Better scans', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            SizedBox(height: 12),
            _GuideRow(icon: Icons.crop_free_rounded, text: 'Keep all four document edges visible.'),
            _GuideRow(icon: Icons.wb_sunny_outlined, text: 'Use even lighting and avoid strong reflections.'),
            _GuideRow(icon: Icons.stay_current_portrait_rounded, text: 'Hold the phone parallel to the page.'),
            _GuideRow(icon: Icons.auto_awesome_rounded, text: 'After capture, the scanner automatically crops and corrects perspective when detection succeeds.'),
          ],
        ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  const _ModeSelector({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final modes = const ['Document', 'ID Card'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: modes.map((mode) {
          final active = mode == selected;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: GestureDetector(
              onTap: () => onSelected(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.black.withValues(alpha: .42),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: active ? .9 : .18)),
                ),
                child: Text(
                  mode,
                  style: TextStyle(
                    color: active ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BottomCameraButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _BottomCameraButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 72,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
}

class _GuideRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _GuideRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.35))),
          ],
        ),
      );
}

class _CameraError extends StatelessWidget {
  final String? error;
  final VoidCallback onRetry;
  const _CameraError({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_rounded, color: Colors.white, size: 56),
              const SizedBox(height: 16),
              Text(error ?? 'Opening camera…', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 18),
              if (error != null) FilledButton(onPressed: onRetry, child: const Text('Try Again')),
            ],
          ),
        ),
      );
}

class _CameraPreviewWithGuide extends StatelessWidget {
  final CameraController controller;
  const _CameraPreviewWithGuide({required this.controller});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final preview = controller.value.previewSize;
        final aspect = preview == null ? 1.0 : preview.height / preview.width;
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxWidth / aspect,
                  child: CameraPreview(controller),
                ),
              ),
            ),
            const IgnorePointer(child: CustomPaint(painter: _ScannerGuidePainter())),
          ],
        );
      },
    );
  }
}

class _LiveDocumentPainter extends CustomPainter {
  final List<Offset> normalizedCorners;
  final double sourceAspect;
  const _LiveDocumentPainter(this.normalizedCorners, {this.sourceAspect = .5625});

  @override
  void paint(Canvas canvas, Size size) {
    if (normalizedCorners.length != 4) return;
    final sourceW = size.width;
    final sourceH = sourceW / sourceAspect;
    final yOffset = (size.height - sourceH) / 2;
    final points = normalizedCorners.map((p) => Offset(p.dx * sourceW, p.dy * sourceH + yOffset)).toList();
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (final point in points.skip(1)) { path.lineTo(point.dx, point.dy); }
    path.close();
    final fill = Paint()..color = Colors.greenAccent.withValues(alpha: .08);
    final line = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, fill);
    canvas.drawPath(path, line);
    final dot = Paint()..color = Colors.white;
    for (final point in points) { canvas.drawCircle(point, 4.5, dot); }
  }

  @override
  bool shouldRepaint(covariant _LiveDocumentPainter oldDelegate) =>
      oldDelegate.normalizedCorners != normalizedCorners || oldDelegate.sourceAspect != sourceAspect;
}

class _ScannerGuidePainter extends CustomPainter {
  const _ScannerGuidePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * .86;
    final h = mathMin(size.height * .62, size.width * .86 * 1.42);
    final left = (size.width - w) / 2;
    final top = (size.height - h) / 2 - 8;
    final rect = Rect.fromLTWH(left, top, w, h);
    final shade = Paint()..color = Colors.black.withValues(alpha: .38);
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(18)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, shade);

    final line = Paint()
      ..color = Colors.white.withValues(alpha: .9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(18)), line);

    final corner = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    const c = 28.0;
    final corners = [
      (Offset(left, top), Offset(left + c, top), Offset(left, top + c)),
      (Offset(left + w, top), Offset(left + w - c, top), Offset(left + w, top + c)),
      (Offset(left, top + h), Offset(left + c, top + h), Offset(left, top + h - c)),
      (Offset(left + w, top + h), Offset(left + w - c, top + h), Offset(left + w, top + h - c)),
    ];
    for (final item in corners) {
      canvas.drawLine(item.$1, item.$2, corner);
      canvas.drawLine(item.$1, item.$3, corner);
    }
  }
  @override
  bool shouldRepaint(covariant _ScannerGuidePainter oldDelegate) => false;
}

double mathMin(double a, double b) => a < b ? a : b;

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _GlassButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.black.withValues(alpha: .48),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Icon(icon, color: onTap == null ? Colors.white38 : Colors.white, size: 21),
          ),
        ),
      );
}
