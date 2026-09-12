import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../core/services/pdf_tools_service.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../models/document_item.dart';

/// Professional multi-page PDF editor.
///
/// The editor keeps page order/rotation in memory and only writes a new PDF
/// when the user taps Save. The source document is never modified in place.
class PdfPageEditorScreen extends StatefulWidget {
  final DocumentItem doc;

  const PdfPageEditorScreen({super.key, required this.doc});

  @override
  State<PdfPageEditorScreen> createState() => _PdfPageEditorScreenState();
}

class _PdfPageEditorScreenState extends State<PdfPageEditorScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<Uint8List?> _thumbs = <Uint8List?>[];
  final List<Uint8List> _insertedImages = <Uint8List>[];

  late List<int> _order;
  late List<int> _rotations;

  bool _loading = true;
  bool _saving = false;
  String? _error;
  int _selectedIndex = 0;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _order = <int>[];
    _rotations = <int>[];
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.doc.filePath).readAsBytes();
      final thumbs = <Uint8List?>[];
      await for (final page in Printing.raster(bytes, dpi: 78)) {
        thumbs.add(await page.toPng());
      }
      if (!mounted) return;
      if (thumbs.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'This PDF has no readable pages.';
        });
        return;
      }
      setState(() {
        _thumbs
          ..clear()
          ..addAll(thumbs);
        _order = List<int>.generate(thumbs.length, (i) => i);
        _rotations = List<int>.filled(thumbs.length, 0);
        _selectedIndex = 0;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load the PDF pages.';
        });
      }
    }
  }

  Uint8List? _thumbnailFor(int index) {
    if (index < 0 || index >= _order.length) return null;
    final source = _order[index];
    if (source < 0) {
      final imageIndex = -source - 1;
      if (imageIndex >= 0 && imageIndex < _insertedImages.length) {
        return _insertedImages[imageIndex];
      }
      return null;
    }
    if (source >= 0 && source < _thumbs.length) return _thumbs[source];
    return null;
  }

  void _select(int index) {
    if (index < 0 || index >= _order.length) return;
    setState(() => _selectedIndex = index);
  }

  void _rotateSelected() {
    _rotateAt(_selectedIndex);
  }

  void _rotateAt(int index) {
    if (index < 0 || index >= _rotations.length) return;
    setState(() {
      _rotations[index] = (_rotations[index] + 90) % 360;
      _dirty = true;
    });
  }

  Future<void> _deleteAt(int index) async {
    if (_order.length <= 1) {
      _message('A PDF must contain at least one page.');
      return;
    }

    final confirmed = await _confirm(
      title: 'Delete page?',
      message: 'Page ${index + 1} will be removed from the edited copy.',
      action: 'Delete',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _order.removeAt(index);
      _rotations.removeAt(index);
      _selectedIndex = _selectedIndex.clamp(0, _order.length - 1);
      _dirty = true;
    });
  }

  void _duplicateSelected() {
    final index = _selectedIndex;
    if (index < 0 || index >= _order.length) return;
    setState(() {
      _order.insert(index + 1, _order[index]);
      _rotations.insert(index + 1, _rotations[index]);
      _selectedIndex = index + 1;
      _dirty = true;
    });
  }

  Future<void> _addImages() async {
    try {
      final files = await _picker.pickMultiImage(imageQuality: 92);
      if (files.isEmpty || !mounted) return;

      final bytes = <Uint8List>[];
      for (final file in files) {
        bytes.add(await file.readAsBytes());
      }

      setState(() {
        final start = _insertedImages.length;
        _insertedImages.addAll(bytes);
        final insertAt = _selectedIndex + 1;
        for (var i = 0; i < bytes.length; i++) {
          _order.insert(insertAt + i, -(start + i + 1));
          _rotations.insert(insertAt + i, 0);
        }
        _selectedIndex = insertAt + bytes.length - 1;
        _dirty = true;
      });
    } catch (_) {
      _message('Could not add the selected images.');
    }
  }

  Future<void> _move(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex || oldIndex < 0 || newIndex < 0) return;
    if (newIndex >= _order.length) newIndex = _order.length - 1;
    setState(() {
      final page = _order.removeAt(oldIndex);
      final rotation = _rotations.removeAt(oldIndex);
      _order.insert(newIndex, page);
      _rotations.insert(newIndex, rotation);
      _selectedIndex = newIndex;
      _dirty = true;
    });
  }

  Future<void> _showPageActions(int index) async {
    if (index < 0 || index >= _order.length) return;
    _select(index);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.rotate_right_rounded),
              title: const Text('Rotate 90°'),
              onTap: () => Navigator.pop(context, 'rotate'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_rounded),
              title: const Text('Duplicate page'),
              onTap: () => Navigator.pop(context, 'duplicate'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Delete page'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;
    switch (action) {
      case 'rotate':
        _rotateAt(index);
        break;
      case 'duplicate':
        _duplicateAt(index);
        break;
      case 'delete':
        await _deleteAt(index);
        break;
    }
  }

  void _duplicateAt(int index) {
    if (index < 0 || index >= _order.length) return;
    setState(() {
      _order.insert(index + 1, _order[index]);
      _rotations.insert(index + 1, _rotations[index]);
      _selectedIndex = index + 1;
      _dirty = true;
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
        rotations: <int, int>{
          for (var i = 0; i < _rotations.length; i++) i: _rotations[i],
        },
        insertedImages: List<Uint8List>.from(_insertedImages),
        outputName: '${DateTime.now().millisecondsSinceEpoch}_edited.pdf',
      );

      final data = context.read<AppDataController>();
      final baseName = widget.doc.name.replaceFirst(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      );
      final result = await data.saveToolResultToLibrary(
        widget.doc.copyWith(
          name: '${baseName}_edited.pdf',
          filePath: tmp.path,
          pageCount: _order.length,
        ),
      );

      if (result != null && mounted) {
        setState(() => _dirty = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Edited PDF saved to Library.')),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) _message('Could not save the edited PDF.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<bool> _handleBack() async {
    if (!_dirty || _saving) return true;
    return _confirm(
      title: 'Discard changes?',
      message: 'Your page edits have not been saved.',
      action: 'Discard',
    );
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _handleBack() && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit PDF'),
          actions: [
            if (!_loading && _order.isNotEmpty)
              IconButton(
                tooltip: 'Add pages',
                onPressed: _saving ? null : _addImages,
                icon: const Icon(Icons.add_photo_alternate_rounded),
              ),
            if (!_loading && _order.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text('Save'),
                ),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : _order.isEmpty
                    ? const Center(child: Text('No pages found.'))
                    : Column(
                        children: [
                          Expanded(child: _preview(theme)),
                          _actionBar(theme),
                          _thumbnailStrip(theme),
                        ],
                      ),
      ),
    );
  }

  Widget _preview(ThemeData theme) {
    final thumb = _thumbnailFor(_selectedIndex);
    final rotation = _selectedIndex < _rotations.length
        ? _rotations[_selectedIndex]
        : 0;

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerLowest,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Column(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Container(
                key: ValueKey('preview_${_selectedIndex}_$rotation'),
                constraints: const BoxConstraints(maxWidth: 620),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 24,
                      spreadRadius: 1,
                      color: Colors.black.withValues(alpha: .08),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: thumb == null
                    ? const Center(child: Icon(Icons.picture_as_pdf_rounded, size: 64))
                    : Center(
                        child: RotatedBox(
                          quarterTurns: rotation ~/ 90,
                          child: Image.memory(
                            thumb,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Page ${_selectedIndex + 1} of ${_order.length}',
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _actionBar(ThemeData theme) {
    final actions = [
      _EditorAction(icon: Icons.rotate_right_rounded, label: 'Rotate', onPressed: _rotateSelected),
      _EditorAction(icon: Icons.copy_all_rounded, label: 'Duplicate', onPressed: _duplicateSelected),
      _EditorAction(icon: Icons.add_photo_alternate_rounded, label: 'Add page', onPressed: _addImages),
      _EditorAction(icon: Icons.delete_outline_rounded, label: 'Delete', onPressed: () => _deleteAt(_selectedIndex)),
    ];
    return Material(
      color: theme.colorScheme.surface,
      child: SizedBox(
        height: 76,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          itemCount: actions.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, index) => SizedBox(width: 82, child: actions[index]),
        ),
      ),
    );
  }

  Widget _thumbnailStrip(ThemeData theme) {
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .55),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 118,
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            itemCount: _order.length,
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex--;
              _move(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final selected = index == _selectedIndex;
              final thumb = _thumbnailFor(index);
              final rotation = _rotations[index];
              return ReorderableDragStartListener(
                key: ValueKey('editor_page_${_order[index]}_$index'),
                index: index,
                child: GestureDetector(
                  onTap: () => _select(index),
                  onLongPress: () => _showPageActions(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 78,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.dividerColor.withValues(alpha: .45),
                        width: selected ? 2 : 1,
                      ),
                      color: theme.colorScheme.surface,
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: thumb == null
                                ? const Center(child: Icon(Icons.picture_as_pdf_rounded))
                                : RotatedBox(
                                    quarterTurns: rotation ~/ 90,
                                    child: Image.memory(thumb, fit: BoxFit.contain),
                                  ),
                          ),
                        ),
                        Positioned(
                          left: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .65),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 1,
                          top: 1,
                          child: Material(
                            color: Colors.black.withValues(alpha: .58),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => _showPageActions(index),
                              child: const Padding(
                                padding: EdgeInsets.all(3),
                                child: Icon(Icons.more_horiz_rounded, color: Colors.white, size: 17),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EditorAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _EditorAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 4),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf_outlined, size: 52),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
