import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Professional capture surface for the V2 scanner.
///
/// Document analysis/corner detection is deliberately kept separate from the
/// camera preview so the native/OpenCV detector can be attached without
/// changing the capture UX later.
class LiveDocumentCameraScreen extends StatefulWidget {
  const LiveDocumentCameraScreen({super.key});

  @override
  State<LiveDocumentCameraScreen> createState() => _LiveDocumentCameraScreenState();
}

class _LiveDocumentCameraScreenState extends State<LiveDocumentCameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _busy = true;
  bool _flash = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera({int? preferredIndex}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('NoCamera', 'No camera is available.');
      _cameras = cameras;
      _cameraIndex = preferredIndex ?? _cameraIndex.clamp(0, cameras.length - 1);
      final old = _controller;
      _controller = CameraController(
        cameras[_cameraIndex],
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await old?.dispose();
      await _controller!.initialize();
      await _controller!.setFlashMode(FlashMode.off);
    } on CameraException catch (e) {
      _error = e.description ?? e.code;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || controller.value.isTakingPicture) return;
    setState(() => _busy = true);
    try {
      final file = await controller.takePicture();
      if (mounted) Navigator.of(context).pop(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not capture document: $e')),
        );
      }
    } finally {
      if (mounted && Navigator.of(context).canPop()) setState(() => _busy = false);
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null) return;
    final next = !_flash;
    try {
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _flash = next);
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    final next = (_cameraIndex + 1) % _cameras.length;
    await _initCamera(preferredIndex: next);
  }

  @override
  void dispose() {
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
            if (ready) _CameraPreviewWithGuide(controller: controller!)
            else Center(
              child: _error == null
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.no_photography_rounded, color: Colors.white, size: 52),
                          const SizedBox(height: 14),
                          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                          const SizedBox(height: 18),
                          FilledButton(onPressed: _initCamera, child: const Text('Try Again')),
                        ],
                      ),
                    ),
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RoundButton(icon: Icons.close_rounded, onTap: () => Navigator.of(context).pop()),
                  const Text('Scan Document', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  Row(children: [
                    _RoundButton(icon: _flash ? Icons.flash_on_rounded : Icons.flash_off_rounded, onTap: _toggleFlash),
                    const SizedBox(width: 8),
                    _RoundButton(icon: Icons.flip_camera_android_rounded, onTap: _switchCamera),
                  ]),
                ],
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 112,
              child: Column(
                children: const [
                  Text('Place the whole document inside the frame', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  SizedBox(height: 6),
                  Text('Keep the page flat and steady for the clearest scan', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            Positioned(
              bottom: 22,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: ready ? _capture : null,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 5)),
                    padding: const EdgeInsets.all(7),
                    child: Container(decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraPreviewWithGuide extends StatelessWidget {
  final CameraController controller;
  const _CameraPreviewWithGuide({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(controller),
            CustomPaint(painter: _ScannerGuidePainter()),
          ],
        ),
      ),
    );
  }
}

class _ScannerGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * .84;
    final h = size.height * .68;
    final left = (size.width - w) / 2;
    final top = (size.height - h) / 2;
    final rect = Rect.fromLTWH(left, top, w, h);
    final shade = Paint()..color = Colors.black.withValues(alpha: .28);
    final path = Path()..addRect(Offset.zero & size)..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(18)))..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, shade);
    final line = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.2;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(18)), line);
    final corner = Paint()..color = Colors.white..strokeWidth = 5..strokeCap = StrokeCap.round;
    const c = 28.0;
    for (final data in <({Offset a, Offset b})>[
      (a: Offset(0, 0), b: Offset(c, 0)), (a: Offset(0, 0), b: Offset(0, c)),
      (a: Offset(1, 1), b: Offset(1-c, 1)), (a: Offset(1, 1), b: Offset(1, 1-c)),
      (a: Offset(0, 1), b: Offset(c, 1)), (a: Offset(0, 1), b: Offset(0, 1-c)),
      (a: Offset(1, 0), b: Offset(1-c, 0)), (a: Offset(1, 0), b: Offset(1, c)),
    ]) {
      canvas.drawLine(Offset(left + data.a.dx * w, top + data.a.dy * h), Offset(left + data.b.dx * w, top + data.b.dy * h), corner);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.black.withValues(alpha: .48),
        shape: const CircleBorder(),
        child: InkWell(onTap: onTap, customBorder: const CircleBorder(), child: Padding(padding: const EdgeInsets.all(11), child: Icon(icon, color: Colors.white, size: 21))),
      );
}
