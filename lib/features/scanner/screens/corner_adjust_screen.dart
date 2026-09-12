import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

class CornerAdjustScreen extends StatefulWidget {
  final String imagePath;
  final List<Offset>? initialCorners;

  const CornerAdjustScreen({
    super.key,
    required this.imagePath,
    this.initialCorners,
  });

  @override
  State<CornerAdjustScreen> createState() => _CornerAdjustScreenState();
}

class _CornerAdjustScreenState extends State<CornerAdjustScreen> {
  static const _channel =
      MethodChannel('com.hameed.pdfmastertools/scanner');

  List<Offset> _points = const [
    Offset(.08, .08),
    Offset(.92, .08),
    Offset(.92, .92),
    Offset(.08, .92),
  ];

  Size _imageSize = Size.zero;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final points = widget.initialCorners;
    if (points != null && points.length == 4) {
      _points = List<Offset>.from(points);
    }

    _readImageSize();
  }

  Future<void> _readImageSize() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final size = await _decodeSize(bytes);

      if (mounted) {
        setState(() => _imageSize = size);
      }
    } catch (_) {}
  }

  Future<Size> _decodeSize(List<int> bytes) async {
    final decoded = img.decodeImage(bytes);

    if (decoded == null) {
      return const Size(1, 1);
    }

    return Size(
      decoded.width.toDouble(),
      decoded.height.toDouble(),
    );
  }

  Future<void> _apply() async {
    setState(() => _saving = true);

    try {
      final output =
          await _channel.invokeMethod<String>('perspectiveCrop', {
        'path': widget.imagePath,
        'points': _points
            .map((p) => {
                  'x': p.dx,
                  'y': p.dy,
                })
            .toList(),
      });

      if (output == null || output.isEmpty) {
        throw StateError('No cropped image returned');
      }

      if (mounted) {
        Navigator.of(context).pop(output);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not crop this page: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _movePoint(int index, Offset point) {
    final next = List<Offset>.from(_points);

    next[index] = Offset(
      point.dx.clamp(0.0, 1.0),
      point.dy.clamp(0.0, 1.0),
    );

    setState(() => _points = next);
  }

  Rect _containRect(Size viewport, Size image) {
    if (image.width <= 1 || image.height <= 1) {
      final side = math.min(viewport.width, viewport.height);

      return Rect.fromCenter(
        center: viewport.center,
        width: side,
        height: side,
      );
    }

    final fitted = applyBoxFit(
      BoxFit.contain,
      image,
      viewport,
    );

    return Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & viewport,
    );
  }

  Offset _toCanvas(Offset normalized, Rect rect) {
    return Offset(
      rect.left + normalized.dx * rect.width,
      rect.top + normalized.dy * rect.height,
    );
  }

  Offset _fromCanvas(Offset canvas, Rect rect) {
    return Offset(
      (canvas.dx - rect.left) / rect.width,
      (canvas.dy - rect.top) / rect.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Adjust Corners'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _apply,
            child: const Text(
              'Done',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final rect =
                    _containRect(constraints.biggest, _imageSize);

                return Stack(
                  children: [
                    Positioned.fill(
                      child: Container(color: Colors.black),
                    ),
                    Positioned.fromRect(
                      rect: rect,
                      child: Image.file(
                        File(widget.imagePath),
                        fit: BoxFit.fill,
                      ),
                    ),
                    Positioned.fromRect(
                      rect: rect,
                      child: CustomPaint(
                        painter: _CornerPainter(_points),
                      ),
                    ),
                    for (var i = 0; i < 4; i++)
                      _Handle(
                        point: _toCanvas(_points[i], rect),
                        onDrag: (delta) {
                          final canvasPoint =
                              _toCanvas(_points[i], rect) + delta;

                          _movePoint(
                            i,
                            _fromCanvas(canvasPoint, rect),
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                18,
                12,
                18,
                14,
              ),
              color: Colors.black,
              child: const Text(
                'Drag each corner onto the exact document edge. '
                'The preview uses the original image, not the '
                'already-cropped result.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  final Offset point;
  final ValueChanged<Offset> onDrag;

  const _Handle({
    required this.point,
    required this.onDrag,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: point.dx - 18,
      top: point.dy - 18,
      child: GestureDetector(
        onPanUpdate: (details) {
          onDrag(details.delta);
        },
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF5B4FE9),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 3,
            ),
          ),
          child: const Icon(
            Icons.drag_indicator_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final List<Offset> points;

  const _CornerPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length != 4) {
      return;
    }

    final mapped = points
        .map(
          (p) => Offset(
            p.dx * size.width,
            p.dy * size.height,
          ),
        )
        .toList();

    final shade = Paint()
      ..color = Colors.black.withValues(alpha: .30);

    final path = Path()
      ..addRect(Offset.zero & size)
      ..addPolygon(mapped, true)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, shade);

    final line = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final outline = Path()
      ..moveTo(mapped[0].dx, mapped[0].dy);

    for (var i = 1; i < mapped.length; i++) {
      outline.lineTo(mapped[i].dx, mapped[i].dy);
    }

    outline.close();

    canvas.drawPath(outline, line);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
