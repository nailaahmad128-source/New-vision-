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

              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    Colors.black,
                    Color(0xFF263238),
                    Color(0xFF1565C0),
                    Color(0xFF00897B),
                    Color(0xFF2E7D32),
                    Color(0xFF6A1B9A),
                    Color(0xFFC62828),
                    Color(0xFFEF6C00),
                    Color(0xFFAD1457),
                    Color(0xFF5D4037),
                    Color(0xFF546E7A),
                    Colors.grey,
                    Colors.white,
                  ].map((color) => _QuickColorCircle(color: color)).toList(),
                ),
              ),

              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: const [
                    Color(0xFF000000),
                    Color(0xFFFFFFFF),
                    Color(0xFFF44336),
                    Color(0xFFE91E63),
                    Color(0xFF9C27B0),
                    Color(0xFF673AB7),
                    Color(0xFF3F51B5),
                    Color(0xFF2196F3),
                    Color(0xFF03A9F4),
                    Color(0xFF00BCD4),
                    Color(0xFF009688),
                    Color(0xFF4CAF50),
                    Color(0xFF8BC34A),
                    Color(0xFFFFEB3B),
                    Color(0xFFFFC107),
                    Color(0xFFFF9800),
                    Color(0xFFFF5722),
                    Color(0xFF795548),
                    Color(0xFF607D8B),
                  ].map((color) => GestureDetector(
                    onTap: () => _changeColor(color),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.value == 0xFFFFFFFF ? Colors.black38 : Colors.black26,
                          width: 1.5,
                        ),
                      ),
                    ),
                  )).toList(),
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

class _QuickColorCircle extends StatelessWidget {
  final Color color;

  const _QuickColorCircle({required this.color});

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_SignaturePadScreenState>();
    final selected = state?._selectedColor.value == color.value;

    return GestureDetector(
      onTap: () => state?._changeColor(color),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: color.computeLuminance() > 0.75
                ? Colors.black45
                : Colors.white,
            width: selected ? 3 : 1.5,
          ),
        ),
        child: selected
            ? Icon(
                Icons.check_rounded,
                size: 16,
                color: color.computeLuminance() > 0.55
                    ? Colors.black87
                    : Colors.white,
              )
            : null,
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


class _DocumentColorPickerScreenState extends State<_DocumentColorPickerScreen> {
  ui.Image? _image;
  ByteData? _pixels;
  Offset? _pickPosition;
  Color? _previewColor;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (!mounted) return;
    setState(() {
      _image = image;
      _pixels = pixels;
    });
  }

  Color? _sampleColor(Offset p, Size size) {
    final image = _image, pixels = _pixels;
    if (image == null || pixels == null) return null;
    final ia = image.width / image.height, ba = size.width / size.height;
    double left, top, width, height;
    if (ia > ba) {
      width = size.width;
      height = width / ia;
      left = 0;
      top = (size.height - height) / 2;
    } else {
      height = size.height;
      width = height * ia;
      top = 0;
      left = (size.width - width) / 2;
    }
    if (p.dx < left || p.dx > left + width || p.dy < top || p.dy > top + height) return null;
    final x = ((p.dx - left) / width * image.width).floor().clamp(0, image.width - 1);
    final y = ((p.dy - top) / height * image.height).floor().clamp(0, image.height - 1);
    final i = (y * image.width + x) * 4;
    return Color.fromARGB(255, pixels.getUint8(i), pixels.getUint8(i + 1), pixels.getUint8(i + 2));
  }

  void _updatePick(Offset p, Size size) {
    final color = _sampleColor(p, size);
    if (color == null) return;
    setState(() {
      _pickPosition = p;
      _previewColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick color from document'),
        actions: [
          if (_previewColor != null)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _previewColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: image == null || _pixels == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (d) => _updatePick(d.localPosition, size),
                        onPanUpdate: (d) => _updatePick(d.localPosition, size),
                        onPanEnd: (_) {
                          final color = _previewColor;
                          if (color != null) Navigator.pop(context, color);
                        },
                        onTapDown: (d) => _updatePick(d.localPosition, size),
                        onTapUp: (d) {
                          final color = _sampleColor(d.localPosition, size);
                          if (color != null) Navigator.pop(context, color);
                        },
                        child: Image.memory(widget.imageBytes, fit: BoxFit.contain),
                      ),
                    ),
                    if (_pickPosition != null && _previewColor != null)
                      Positioned(
                        left: (_pickPosition!.dx - 24).clamp(0.0, size.width - 48).toDouble(),
                        top: (_pickPosition!.dy - 24).clamp(0.0, size.height - 48).toDouble(),
                        child: IgnorePointer(
                          child: Column(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.black87, width: 2),
                                  boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black45)],
                                ),
                                child: Center(
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: _previewColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.black54),
                                    ),
                                  ),
                                ),
                              ),
                              Container(width: 2, height: 22, color: Colors.black87),
                              Container(width: 18, height: 2, color: Colors.black87),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 20,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'انگلی سے رنگ پر جائیں، نشان کو دیکھیں، پھر انگلی اٹھائیں۔',
                            style: TextStyle(color: Colors.white),
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
