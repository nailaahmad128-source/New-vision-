import 'dart:async';

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
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _initializing = true;
  bool _capturing = false;
  bool _flash = false;
  bool _autoScan = true;
  bool _idMode = false;
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
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _controller = next;
      await old?.dispose();
      await next.initialize();
      await next.setFlashMode(FlashMode.off);
      if (mounted) setState(() => _initializing = false);
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
    if (_capturing || controller == null || !controller.value.isInitialized || controller.value.isTakingPicture) return;
    setState(() => _capturing = true);
    HapticFeedback.mediumImpact();
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
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _pickFromGallery() async {
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
                  const Spacer(),
                  _ScanFrame(idMode: _idMode),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: Column(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: _idMode
                              ? const _DetectionHint(key: ValueKey('id'), text: 'Align the ID card inside the frame')
                              : _autoScan
                                  ? const _DetectionHint(key: ValueKey('auto'), text: 'Move closer • Auto scan when the page is ready')
                                  : const _DetectionHint(key: ValueKey('manual'), text: 'Place the whole document inside the frame'),
                        ),
                        const SizedBox(height: 16),
                        _ModeSelector(
                          idMode: _idMode,
                          autoScan: _autoScan,
                          onDocument: () => setState(() => _idMode = false),
                          onId: () => setState(() => _idMode = true),
                          onAutoChanged: (value) => setState(() => _autoScan = value),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(child: _BottomTool(icon: Icons.photo_library_outlined, label: 'Gallery', onTap: _pickFromGallery)),
                            Expanded(
                              child: Center(
                                child: GestureDetector(
                                  onTap: _capture,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 120),
                                    width: _capturing ? 72 : 78,
                                    height: _capturing ? 72 : 78,
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: .98),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white.withValues(alpha: .75), width: 3),
                                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .35), blurRadius: 18)],
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.black.withValues(alpha: .16), width: 1.5),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(child: _BottomTool(icon: Icons.document_scanner_outlined, label: 'Auto', active: _autoScan, onTap: () => setState(() => _autoScan = !_autoScan))),
                          ],
                        ),
                      ],
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final cameraRatio = controller.value.aspectRatio;
        final screenRatio = size.width / size.height;
        final scale = cameraRatio < screenRatio ? screenRatio / cameraRatio : cameraRatio / screenRatio;
        return ClipRect(
          child: Transform.scale(
            scale: scale,
            child: Center(child: CameraPreview(controller)),
          ),
        );
      },
    );
  }
}

class _ScanFrame extends StatelessWidget {
  final bool idMode;
  const _ScanFrame({required this.idMode});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width * .84,
      height: idMode ? MediaQuery.sizeOf(context).width * .53 : MediaQuery.sizeOf(context).height * .53,
      child: CustomPaint(painter: _ScanFramePainter(idMode: idMode)),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  final bool idMode;
  const _ScanFramePainter({required this.idMode});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(idMode ? 20 : 18));
    final shade = Paint()..color = Colors.black.withValues(alpha: .20);
    final outside = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(rect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(outside, shade);

    final border = Paint()
      ..color = Colors.white.withValues(alpha: .62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawRRect(rect, border);

    final corner = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    const len = 30.0;
    const r = 18.0;
    final w = size.width;
    final h = size.height;
    final segments = <List<Offset>>[
      [Offset(r, 0), Offset(len, 0)], [Offset(0, r), Offset(0, len)],
      [Offset(w - r, 0), Offset(w - len, 0)], [Offset(w, r), Offset(w, len)],
      [Offset(0, h - r), Offset(0, h - len)], [Offset(r, h), Offset(len, h)],
      [Offset(w, h - r), Offset(w, h - len)], [Offset(w - r, h), Offset(w - len, h)],
    ];
    for (final pair in segments) {
      canvas.drawLine(pair[0], pair[1], corner);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter oldDelegate) => oldDelegate.idMode != idMode;
}

class _ModeSelector extends StatelessWidget {
  final bool idMode;
  final bool autoScan;
  final VoidCallback onDocument;
  final VoidCallback onId;
  final ValueChanged<bool> onAutoChanged;

  const _ModeSelector({
    required this.idMode,
    required this.autoScan,
    required this.onDocument,
    required this.onId,
    required this.onAutoChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ModeChip(label: 'Document', icon: Icons.description_outlined, selected: !idMode, onTap: onDocument),
        const SizedBox(width: 8),
        _ModeChip(label: 'ID Card', icon: Icons.badge_outlined, selected: idMode, onTap: onId),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => onAutoChanged(!autoScan),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .48),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: .20)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 17, color: autoScan ? Colors.white : Colors.white60),
                const SizedBox(width: 6),
                Text('Auto', style: TextStyle(color: autoScan ? Colors.white : Colors.white60, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ModeChip({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.black.withValues(alpha: .48),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: selected ? Colors.black87 : Colors.white),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: selected ? Colors.black87 : Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _DetectionHint extends StatelessWidget {
  final String text;
  const _DetectionHint({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: .52), borderRadius: BorderRadius.circular(20)),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

class _BottomTool extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _BottomTool({required this.icon, required this.label, this.active = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? Colors.white : Colors.white.withValues(alpha: .88), size: 27),
          const SizedBox(height: 5),
          Text(label, style: TextStyle(color: active ? Colors.white : Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: .48),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(icon, color: Colors.white, size: 21),
        ),
      ),
    );
  }
}

class _ScannerTopGradient extends StatelessWidget {
  const _ScannerTopGradient();
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [Colors.black.withValues(alpha: .62), Colors.transparent],
            ),
          ),
        ),
      );
}

class _ScannerBottomGradient extends StatelessWidget {
  const _ScannerBottomGradient();
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: .48,
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: .88)],
                ),
              ),
            ),
          ),
        ),
      );
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
