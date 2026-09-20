import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class SignaturePadScreen extends StatefulWidget {
  final Uint8List? documentImageBytes;

  const SignaturePadScreen({
    super.key,
    this.documentImageBytes,
  });

  @override
  State<SignaturePadScreen> createState() => _SignaturePadScreenState();
}

class _SignaturePadScreenState extends State<SignaturePadScreen> {
  late SignatureController _controller;

  Color _selectedColor = Colors.black;

  @override
  void initState() {
    super.initState();
    _controller = _createController(_selectedColor);
  }

  SignatureController _createController(Color color) {
    return SignatureController(
      penStrokeWidth: 3.5,
      penColor: color,
      exportBackgroundColor: Colors.transparent,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _changeColor(Color color) async {
    final oldPoints = List.of(_controller.points);

    final oldController = _controller;

    setState(() {
      _selectedColor = color;
      _controller = SignatureController(
        points: oldPoints,
        penStrokeWidth: 3.5,
        penColor: color,
        exportBackgroundColor: Colors.transparent,
      );
    });

    oldController.dispose();
  }

  Future<void> _openColorPicker() async {
    int red = _selectedColor.r.round();
    int green = _selectedColor.g.round();
    int blue = _selectedColor.b.round();

    final result = await showDialog<Color>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final color = Color.fromARGB(255, red, green, blue);

            return AlertDialog(
              title: const Text('Signature Color'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 55,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black26),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _rgbSlider(
                      label: 'Red',
                      value: red,
                      onChanged: (v) {
                        setDialogState(() => red = v);
                      },
                    ),

                    _rgbSlider(
                      label: 'Green',
                      value: green,
                      onChanged: (v) {
                        setDialogState(() => green = v);
                      },
                    ),

                    _rgbSlider(
                      label: 'Blue',
                      value: blue,
                      onChanged: (v) {
                        setDialogState(() => blue = v);
                      },
                    ),

                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        Colors.black,
                        Colors.red,
                        Colors.blue,
                        Colors.green,
                        Colors.orange,
                        Colors.purple,
                        Colors.brown,
                        Colors.teal,
                        Colors.indigo,
                        Colors.pink,
                        Colors.grey,
                      ].map((c) {
                        return _ColorCircle(color: c);
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    ctx,
                    Color.fromARGB(255, red, green, blue),
                  ),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      await _changeColor(result);
    }
  }

  Widget _rgbSlider({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 55,
          child: Text(label),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 255,
            divisions: 255,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(
          width: 35,
          child: Text(
            '$value',
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Future<void> _pickFromDocument() async {
    final bytes = widget.documentImageBytes;

    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document color picker is unavailable.'),
        ),
      );
      return;
    }

    final color = await Navigator.push<Color?>(
      context,
      MaterialPageRoute(
        builder: (_) => _DocumentColorPickerScreen(
          imageBytes: bytes,
        ),
      ),
    );

    if (color != null && mounted) {
      await _changeColor(color);
    }
  }

  Future<void> _done() async {
    if (_controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draw your signature first.'),
        ),
      );
      return;
    }

    final Uint8List? bytes = await _controller.toPngBytes();

    if (!mounted) return;

    Navigator.pop(context, bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Draw your signature'),
        actions: [
          IconButton(
            tooltip: 'Signature color',
            onPressed: _openColorPicker,
            icon: Container(
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                color: _selectedColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.black38,
                  width: 2,
                ),
              ),
            ),
          ),
          if (widget.documentImageBytes != null)
            IconButton(
              tooltip: 'Pick color from document',
              onPressed: _pickFromDocument,
              icon: const Icon(Icons.colorize_rounded),
            ),
          TextButton(
            onPressed: () => _controller.clear(),
            child: const Text('Clear'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.palette_outlined),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Choose any color for your signature.',
                      ),
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: _selectedColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.black38,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Signature(
                    controller: _controller,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _done,
                  child: const Text('Use this signature'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorCircle extends StatelessWidget {
  final Color color;

  const _ColorCircle({
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context, color);
      },
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.black26,
          ),
        ),
      ),
    );
  }
}

class _DocumentColorPickerScreen extends StatefulWidget {
  final Uint8List imageBytes;

  const _DocumentColorPickerScreen({
    required this.imageBytes,
  });

  @override
  State<_DocumentColorPickerScreen> createState() =>
      _DocumentColorPickerScreenState();
}

class _DocumentColorPickerScreenState
    extends State<_DocumentColorPickerScreen> {
  ui.Image? _image;
  ByteData? _pixels;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final codec = await ui.instantiateImageCodec(
      widget.imageBytes,
    );

    final frame = await codec.getNextFrame();
    final image = frame.image;

    final pixels = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );

    if (!mounted) return;

    setState(() {
      _image = image;
      _pixels = pixels;
    });
  }

  Color? _sampleColor(
    Offset localPosition,
    Size boxSize,
  ) {
    final image = _image;
    final pixels = _pixels;

    if (image == null || pixels == null) return null;

    final imageAspect = image.width / image.height;
    final boxAspect = boxSize.width / boxSize.height;

    double left;
    double top;
    double width;
    double height;

    if (imageAspect > boxAspect) {
      width = boxSize.width;
      height = width / imageAspect;
      left = 0;
      top = (boxSize.height - height) / 2;
    } else {
      height = boxSize.height;
      width = height * imageAspect;
      top = 0;
      left = (boxSize.width - width) / 2;
    }

    if (localPosition.dx < left ||
        localPosition.dx > left + width ||
        localPosition.dy < top ||
        localPosition.dy > top + height) {
      return null;
    }

    final x = ((localPosition.dx - left) / width * image.width)
        .floor()
        .clamp(0, image.width - 1);

    final y = ((localPosition.dy - top) / height * image.height)
        .floor()
        .clamp(0, image.height - 1);

    final index = (y * image.width + x) * 4;

    return Color.fromARGB(
      255,
      pixels.getUint8(index),
      pixels.getUint8(index + 1),
      pixels.getUint8(index + 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick color from document'),
      ),
      body: image == null || _pixels == null
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;

                return Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) {
                          final color = _sampleColor(
                            details.localPosition,
                            size,
                          );

                          if (color != null) {
                            Navigator.pop(context, color);
                          }
                        },
                        child: Image.memory(
                          widget.imageBytes,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 20,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Tap anywhere on the document to pick its color.',
                            style: TextStyle(
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
