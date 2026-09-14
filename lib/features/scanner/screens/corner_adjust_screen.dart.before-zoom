import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/image_codec_isolate.dart';
import '../../../core/theme/app_colors.dart';

/// Full-screen manual corner-adjustment step of the scan pipeline.
///
/// This is always reachable — even when automatic detection fails, is
/// disabled, or the device has no OpenCV support — so a scan is never
/// stuck without a way to crop it. On open it makes one attempt at the
/// native OpenCV edge detector to seed a starting guess; if that fails,
/// the four handles start on an inset rectangle instead of pretending
/// detection succeeded. The user can always drag any handle by hand.
class CornerAdjustScreen extends StatefulWidget {
  /// Path to a JPEG file on disk containing exactly [imageBytes] — required
  /// because the native detector/crop channel operates on a file path.
  final String imagePath;
  final Uint8List imageBytes;

  /// Normalized (0..1) starting corners, in image space. Pass null to make
  /// this screen attempt auto-detection itself before falling back to a
  /// default inset rectangle.
  final List<Offset>? initialCorners;

  const CornerAdjustScreen({
    super.key,
    required this.imagePath,
    required this.imageBytes,
    this.initialCorners,
  });

  @override
  State<CornerAdjustScreen> createState() => _CornerAdjustScreenState();
}

class _CornerAdjustScreenState extends State<CornerAdjustScreen> {
  static const _scannerChannel = MethodChannel('com.hameed.pdfmastertools/scanner');

  List<Offset> _corners = _defaultRect();
  int? _imgW;
  int? _imgH;
  bool _ready = false;
  bool _detecting = false;
  int? _activeHandle;

  static List<Offset> _defaultRect() => const [
        Offset(0.08, 0.08),
        Offset(0.92, 0.08),
        Offset(0.92, 0.92),
        Offset(0.08, 0.92),
      ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final dims = await decodeImageDimensionsInBackground(widget.imageBytes);
    if (!mounted) return;
    setState(() {
      _imgW = dims?.width;
      _imgH = dims?.height;
      _corners = (widget.initialCorners != null && widget.initialCorners!.length == 4)
          ? List.of(widget.initialCorners!)
          : _defaultRect();
      _ready = true;
    });
    if (widget.initialCorners == null) {
      await _autoDetect(silent: true);
    }
  }

  Future<void> _autoDetect({bool silent = false}) async {
    if (!silent) setState(() => _detecting = true);
    try {
      final detected = await _scannerChannel.invokeMethod<List<dynamic>>(
        'detectDocument',
        {'path': widget.imagePath},
      );
      final points = detected
          ?.map((p) => Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()))
          .toList();
      if (!mounted) return;
      if (points != null && points.length == 4) {
        setState(() => _corners = points);
      } else if (!silent) {
        _notify('No document edges found — drag the corners into place.');
      }
    } catch (_) {
      if (!silent && mounted) {
        _notify('Automatic detection is unavailable on this device — drag the corners into place.');
      }
    } finally {
      if (!silent && mounted) setState(() => _detecting = false);
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _reset() => setState(() => _corners = _defaultRect());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Adjust Corners'),
        actions: [
          IconButton(
            tooltip: 'Auto detect',
            onPressed: _detecting ? null : () => _autoDetect(),
            icon: _detecting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.auto_fix_high_rounded),
          ),
          IconButton(tooltip: 'Reset', onPressed: _reset, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: SafeArea(
        child: !_ready
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Text(
                      'Drag each corner so it sits on the edge of the document.',
                      style: TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final imageRect = _fitRect(
                            constraints.biggest,
                            (_imgW ?? 3).toDouble(),
                            (_imgH ?? 4).toDouble(),
                          );
                          return Stack(
                            children: [
                              Positioned.fromRect(
                                rect: imageRect,
                                child: Image.memory(widget.imageBytes, fit: BoxFit.fill),
                              ),
                              CustomPaint(
                                size: constraints.biggest,
                                painter: _CornerLinesPainter(_toPixels(imageRect)),
                              ),
                              for (var i = 0; i < 4; i++) _handle(i, imageRect),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.of(context).pop(_corners),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Confirm & Crop'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Rect _fitRect(Size bounds, double w, double h) {
    final scale = (bounds.width / w < bounds.height / h) ? bounds.width / w : bounds.height / h;
    final rw = w * scale;
    final rh = h * scale;
    final left = (bounds.width - rw) / 2;
    final top = (bounds.height - rh) / 2;
    return Rect.fromLTWH(left, top, rw, rh);
  }

  List<Offset> _toPixels(Rect imageRect) => _corners
      .map((c) => Offset(imageRect.left + c.dx * imageRect.width, imageRect.top + c.dy * imageRect.height))
      .toList();

  Widget _handle(int index, Rect imageRect) {
    final px = imageRect.left + _corners[index].dx * imageRect.width;
    final py = imageRect.top + _corners[index].dy * imageRect.height;
    const handleSize = 36.0;
    return Positioned(
      left: px - handleSize / 2,
      top: py - handleSize / 2,
      child: GestureDetector(
        onPanStart: (_) => setState(() => _activeHandle = index),
        onPanUpdate: (details) {
          setState(() {
            final currentPx = imageRect.left + _corners[index].dx * imageRect.width + details.delta.dx;
            final currentPy = imageRect.top + _corners[index].dy * imageRect.height + details.delta.dy;
            final dx = ((currentPx - imageRect.left) / imageRect.width).clamp(0.0, 1.0);
            final dy = ((currentPy - imageRect.top) / imageRect.height).clamp(0.0, 1.0);
            _corners[index] = Offset(dx, dy);
          });
        },
        onPanEnd: (_) => setState(() => _activeHandle = null),
        child: Container(
          width: handleSize,
          height: handleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (_activeHandle == index ? AppColors.brandPrimary : Colors.white).withValues(alpha: .92),
            border: Border.all(color: Colors.black26, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 1))],
          ),
        ),
      ),
    );
  }
}

class _CornerLinesPainter extends CustomPainter {
  final List<Offset> pixelCorners;
  _CornerLinesPainter(this.pixelCorners);

  @override
  void paint(Canvas canvas, Size size) {
    if (pixelCorners.length != 4) return;
    final fill = Paint()
      ..color = AppColors.brandPrimary.withValues(alpha: .18)
      ..style = PaintingStyle.fill;
    final line = Paint()
      ..color = AppColors.brandPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final path = Path()..moveTo(pixelCorners[0].dx, pixelCorners[0].dy);
    for (var i = 1; i < pixelCorners.length; i++) {
      path.lineTo(pixelCorners[i].dx, pixelCorners[i].dy);
    }
    path.close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _CornerLinesPainter oldDelegate) => oldDelegate.pixelCorners != pixelCorners;
}
