import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/services/pdf_tools_service.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../models/document_item.dart';

class PdfPageEditorScreen extends StatefulWidget {
  final DocumentItem doc;
  const PdfPageEditorScreen({super.key, required this.doc});

  @override
  State<PdfPageEditorScreen> createState() => _PdfPageEditorScreenState();
}

class _PdfPageEditorScreenState extends State<PdfPageEditorScreen> {
  final List<Uint8List?> _thumbs = [];
  late List<int> _order;
  late List<int> _rotations;
  bool _loading = true;
  bool _saving = false;
  final List<Uint8List> _insertedImages = [];
  final ImagePicker _picker = ImagePicker();
  String? _error;

  @override
  void initState() {
    super.initState();
    _order = const [];
    _rotations = [];
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.doc.filePath).readAsBytes();
      final thumbs = <Uint8List?>[];
      var count = 0;
      await for (final page in Printing.raster(bytes, dpi: 72)) {
        thumbs.add(await page.toPng());
        count++;
      }
      if (!mounted) return;
      setState(() {
        _thumbs
          ..clear()
          ..addAll(thumbs);
        _order = List.generate(count, (i) => i);
        _rotations = List.filled(count, 0);
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Could not load PDF pages.'; });
    }
  }

  void _rotate(int outputIndex) {
    setState(() {
      _rotations[outputIndex] = (_rotations[outputIndex] + 90) % 360;
    });
  }

  Future<void> _delete(int index) async {
    if (_order.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A PDF must contain at least one page.')));
      return;
    }
    setState(() {
      _order.removeAt(index);
      _rotations.removeAt(index);
    });
  }

  Future<void> _addImages() async {
    final files = await _picker.pickMultiImage(imageQuality: 92);
    if (files.isEmpty || !mounted) return;
    final bytes = <Uint8List>[];
    for (final file in files) {
      bytes.add(await file.readAsBytes());
    }
    setState(() {
      final start = _insertedImages.length;
      _insertedImages.addAll(bytes);
      for (var i = 0; i < bytes.length; i++) {
        _order.add(-(start + i + 1));
        _rotations.add(0);
      }
    });
  }

  Future<void> _save() async {
    if (_saving || _order.isEmpty) return;
    setState(() => _saving = true);
    try {
      final tools = context.read<PdfToolsService>();
      final tmp = await tools.editPagesWithImages(
        widget.doc.filePath,
        order: List<int>.from(_order),
        rotations: {for (var i = 0; i < _rotations.length; i++) i: _rotations[i]},
        insertedImages: List<Uint8List>.from(_insertedImages),
        outputName: '${DateTime.now().millisecondsSinceEpoch}_edited.pdf',
      );
      final data = context.read<AppDataController>();
      final result = await data.saveToolResultToLibrary(widget.doc.copyWith(
        name: widget.doc.name.replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '') + '_edited.pdf',
        filePath: tmp.path,
        pageCount: _order.length,
      ));
      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edited PDF saved to Library.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save the edited PDF.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Pages'),
        actions: [
          if (!_loading && _order.isNotEmpty) IconButton(tooltip: 'Add images', onPressed: _saving ? null : _addImages, icon: const Icon(Icons.add_photo_alternate_rounded)),
          if (!_loading && _order.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded),
                label: const Text('Save'),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _order.isEmpty
                  ? const Center(child: Text('No pages found.'))
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                          child: Row(children: [
                            const Icon(Icons.swipe_rounded),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Drag pages to reorder • rotate or delete any page', style: Theme.of(context).textTheme.bodyMedium)),
                          ]),
                        ),
                        Expanded(
                          child: ReorderableListView.builder(
                            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                            itemCount: _order.length,
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                if (newIndex > oldIndex) newIndex--;
                                final item = _order.removeAt(oldIndex);
                                final rot = _rotations.removeAt(oldIndex);
                                _order.insert(newIndex, item);
                                _rotations.insert(newIndex, rot);
                              });
                            },
                            itemBuilder: (context, index) {
                              final source = _order[index];
                              final thumb = source < 0 ? _insertedImages[-source - 1] : _thumbs[source];
                              final rotation = _rotations[index];
                              return Card(
                                key: ValueKey('page_${_order[index]}_$index'),
                                margin: const EdgeInsets.only(bottom: 12),
                                clipBehavior: Clip.antiAlias,
                                child: Row(children: [
                                  SizedBox(
                                    width: 100,
                                    height: 132,
                                    child: thumb == null ? const Icon(Icons.picture_as_pdf_rounded, size: 44) : RotatedBox(quarterTurns: rotation ~/ 90, child: Image.memory(thumb, fit: BoxFit.contain)),
                                  ),
                                  Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('Page ${index + 1}', style: Theme.of(context).textTheme.titleMedium),
                                    const SizedBox(height: 5),
                                    Text(_order[index] < 0 ? 'Added image' : 'Original page ${_order[index] + 1}'),
                                  ]))),
                                  IconButton(tooltip: 'Rotate', onPressed: () => _rotate(index), icon: const Icon(Icons.rotate_right_rounded)),
                                  IconButton(tooltip: 'Delete', onPressed: () => _delete(index), icon: const Icon(Icons.delete_outline_rounded)),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.drag_handle_rounded),
                                  const SizedBox(width: 8),
                                ]),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
}
