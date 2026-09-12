import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/file_storage_service.dart';
import '../../../models/document_item.dart';
import '../../../core/storage/app_data_controller.dart';

import '../../../core/theme/app_colors.dart';
import '../../ocr/screens/text_extraction_screen.dart';
import 'corner_adjust_screen.dart';
import '../widgets/page_thumbnail_strip.dart';
import 'live_document_camera_screen.dart';

/// Professional multi-page scanner: capture, detect, crop, enhance and save.
class SmartScannerScreen extends StatefulWidget {
  const SmartScannerScreen({super.key});

  @override
  State<SmartScannerScreen> createState() => _SmartScannerScreenState();
}

class _SmartScannerScreenState extends State<SmartScannerScreen> {
  final _picker = ImagePicker();
  XFile? _image;
  Uint8List? _processed;
  final List<Uint8List> _pages = [];
  final List<Uint8List> _basePages = [];
  final List<String?> _sourcePaths = [];
  final List<int> _pageFilters = [];
  final List<double> _pageBrightness = [];
  final List<double> _pageContrast = [];
  bool _batchMode = true;
  bool _processing = false;
  int _filter = 0;
  int _selectedPage = 0;
  double _brightness = 1.0;
  double _contrast = 1.0;
  List<Offset>? _corners;
  String? _savedDocumentId;
  static const _scannerChannel = MethodChannel('com.hameed.pdfmastertools/scanner');

  Future<void> _capture() async {
    final file = await Navigator.of(context).push<XFile>(
      MaterialPageRoute(builder: (_) => const LiveDocumentCameraScreen()),
    );
    if (file == null) return;
    await _setImage(file);
  }

  int _imageQuality(BuildContext context) {
    final quality = context.read<AppDataController>().scanQuality;
    return switch (quality) {
      'standard' => 82,
      'ultra' => 98,
      _ => 94,
    };
  }

  double _maxWidth(BuildContext context) {
    final quality = context.read<AppDataController>().scanQuality;
    return switch (quality) {
      'standard' => 2200,
      'ultra' => 4200,
      _ => 3200,
    };
  }

  Future<void> _pickFromGallery() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: _imageQuality(context),
      maxWidth: _maxWidth(context),
    );
    if (file == null) return;
    await _setImage(file);
  }

  void _ensurePageState(int count) {
    while (_basePages.length < count) _basePages.add(Uint8List(0));
    while (_pageFilters.length < count) _pageFilters.add(0);
    while (_pageBrightness.length < count) _pageBrightness.add(1.0);
    while (_pageContrast.length < count) _pageContrast.add(1.0);
    if (_basePages.length > count) _basePages.removeRange(count, _basePages.length);
    if (_pageFilters.length > count) _pageFilters.removeRange(count, _pageFilters.length);
    if (_pageBrightness.length > count) _pageBrightness.removeRange(count, _pageBrightness.length);
    if (_pageContrast.length > count) _pageContrast.removeRange(count, _pageContrast.length);
  }

  Uint8List _renderPage(Uint8List base, int filter, double brightness, double contrast) {
    final decoded = img.decodeImage(base);
    if (decoded == null) return base;
    if (filter == 1) {
      img.grayscale(decoded);
    } else if (filter == 2) {
      img.grayscale(decoded);
      img.adjustColor(decoded, contrast: 1.35, brightness: 1.05);
    } else if (filter == 3) {
      img.grayscale(decoded);
      img.adjustColor(decoded, contrast: 1.75, brightness: 1.08);
      img.convolution(decoded, filter: const [0, -1, 0, -1, 5, -1, 0, -1, 0]);
    } else if (filter == 4) {
      img.adjustColor(decoded, contrast: 1.22, brightness: 1.04, saturation: 0.92);
    }
    if (brightness != 1.0 || contrast != 1.0) {
      img.adjustColor(decoded, brightness: brightness, contrast: contrast);
    }
    return Uint8List.fromList(img.encodeJpg(decoded, quality: 95));
  }

  void _syncSelectedState() {
    _ensurePageState(_pages.length);
    if (_pages.isEmpty) return;
    _filter = _pageFilters[_selectedPage];
    _brightness = _pageBrightness[_selectedPage];
    _contrast = _pageContrast[_selectedPage];
    _processed = _pages[_selectedPage];
  }

  Future<void> _setImage(XFile file, {bool append = false}) async {
    setState(() {
      _processing = true;
      if (!append) {
        _image = file;
        _filter = 0;
        _brightness = 1.0;
        _contrast = 1.0;
        _corners = null;
        _savedDocumentId = null;
      }
    });

    try {
      final normalized = await _normalizeOrientation(file);
      final bytes = await normalized.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw StateError('Unable to decode image');
      final original = Uint8List.fromList(img.encodeJpg(decoded, quality: _imageQuality(context)));

      Uint8List processed = original;
      List<Offset>? detected;
      try {
        final result = await _scannerChannel.invokeMethod<List<dynamic>>('detectDocument', {'path': normalized.path});
        detected = result?.map((p) => Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble())).toList();
      } catch (_) {}

      if (detected?.length == 4) {
        try {
          final croppedPath = await _scannerChannel.invokeMethod<String>('perspectiveCrop', {
            'path': normalized.path,
            'points': detected!.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
          });
          if (croppedPath != null) {
            processed = await File(croppedPath).readAsBytes();
          }
        } catch (_) {
          // Keep the original page; manual corner adjustment remains available.
        }
      }

      if (!mounted) return;
      setState(() {
        if (!append) {
          _pages
            ..clear()
            ..add(processed);
          _basePages
            ..clear()
            ..add(processed);
          _sourcePaths
            ..clear()
            ..add(normalized.path);
          _pageFilters..clear()..add(0);
          _pageBrightness..clear()..add(1.0);
          _pageContrast..clear()..add(1.0);
          _selectedPage = 0;
        } else {
          _pages.add(processed);
          _basePages.add(processed);
          _sourcePaths.add(normalized.path);
          _pageFilters.add(0);
          _pageBrightness.add(1.0);
          _pageContrast.add(1.0);
          _selectedPage = _pages.length - 1;
        }
        _image = XFile(normalized.path);
        _processed = processed;
        _corners = detected?.length == 4 ? detected : null;
        _processing = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not prepare this scan: $e')));
      }
    }
  }

  Future<File> _normalizeOrientation(XFile file) async {
    final source = File(file.path);
    final bytes = await source.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return source;

    // Never write normalized copies beside the user's original photo.
    // Scanner intermediates belong in the app temp area and can be cleaned
    // without polluting the user's gallery.
    final normalized = img.bakeOrientation(decoded);
    final storage = context.read<FileStorageService>();
    final out = await storage.newTmpFile('scanner_normalized.jpg');
    await out.writeAsBytes(
      img.encodeJpg(normalized, quality: _imageQuality(context)),
      flush: true,
    );
    return out;
  }

  Future<void> _adjustCornersForPage(int index) async {
    if (index < 0 || index >= _pages.length) return;
    final sourcePath = await _ensureSourcePath(index);
    final initial = index == _selectedPage ? _corners : null;
    final output = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => CornerAdjustScreen(imagePath: sourcePath, initialCorners: initial),
    ));
    if (output == null || !mounted) return;
    final bytes = await File(output).readAsBytes();
    setState(() {
      _ensurePageState(_pages.length);
      _pages[index] = bytes;
      _basePages[index] = bytes;
      _pageFilters[index] = 0;
      _pageBrightness[index] = 1.0;
      _pageContrast[index] = 1.0;
      if (_selectedPage == index) {
        _processed = bytes;
        _image = XFile(sourcePath);
        _corners = null;
      }
    });
  }

  Future<String> _ensureSourcePath(int index) async {
    final existing = index < _sourcePaths.length ? _sourcePaths[index] : null;
    if (existing != null && await File(existing).exists()) return existing;
    final storage = context.read<FileStorageService>();
    final file = await storage.newTmpFile('scanner_source_$index.jpg');
    await file.writeAsBytes(_pages[index], flush: true);
    while (_sourcePaths.length <= index) _sourcePaths.add(null);
    _sourcePaths[index] = file.path;
    return file.path;
  }

  Future<void> _autoCrop() async {
    if (_selectedPage < 0 || _selectedPage >= _pages.length) return;
    await _adjustCornersForPage(_selectedPage);
  }

  Future<void> _extractSavedDocument() async {
    if (_pages.isEmpty) return;
    final storage = context.read<FileStorageService>();
    final file = await storage.newTmpFile('ocr_scan_${_selectedPage + 1}.jpg');
    await file.writeAsBytes(_pages[_selectedPage], flush: true);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TextExtractionScreen(imagePath: file.path, documentId: _savedDocumentId),
    ));
  }

  Future<void> _shareCurrentPage() async {
    if (_pages.isEmpty) return;
    final storage = context.read<FileStorageService>();
    final file = await storage.newTmpFile('share_scan_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(_pages[_selectedPage], flush: true);
    if (!mounted) return;
    await Share.shareXFiles([XFile(file.path)], text: 'Scanned with PDF Master Tools');
  }

  Future<void> _saveAsPdf() async {
    if (_processed == null) return;
    setState(() => _processing = true);
    try {
      final storage = context.read<FileStorageService>();
      final controller = context.read<AppDataController>();
      final doc = pw.Document();
      final pages = _pages.isEmpty ? <Uint8List>[_processed!] : List<Uint8List>.from(_pages);
      for (final bytes in pages) {
        final decoded = img.decodeImage(bytes);
        final width = (decoded?.width ?? 1240).toDouble();
        final height = (decoded?.height ?? 1754).toDouble();
        final image = pw.MemoryImage(bytes);
        final ratio = width / height;
        final pageFormat = ratio >= 1
            ? PdfPageFormat(height, width)
            : PdfPageFormat(width, height);
        doc.addPage(pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(8),
          build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
        ));
      }
      final tmp = await storage.newTmpFile('scan.pdf');
      await tmp.writeAsBytes(await doc.save(), flush: true);
      final now = DateTime.now();
      final name = 'Scan_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.pdf';
      final libraryPath = await storage.importIntoLibrary(tmp, preferredName: name);
      final size = await storage.fileSize(libraryPath);
      final thumbnailPath = await storage.saveThumbnail(
        pages.first,
        name: 'thumb_${storage.newId()}.jpg',
      );
      final libraryDoc = DocumentItem(
        id: storage.newId(),
        name: p.basename(libraryPath),
        filePath: libraryPath,
        thumbnailPath: thumbnailPath,
        sizeBytes: size,
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        type: 'pdf',
        pageCount: pages.length,
      );
      await controller.addDocument(libraryDoc);
      if (mounted) {
        setState(() => _savedDocumentId = libraryDoc.id);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to Library • You can now extract text from all pages')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save the scan.')));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _addGalleryPages() async {
    if (!_batchMode) return;
    final files = await _picker.pickMultiImage(imageQuality: _imageQuality(context), maxWidth: _maxWidth(context));
    if (files.isEmpty) return;
    setState(() => _processing = true);
    try {
      for (final file in files) {
        await _setImage(file, append: true);
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _addPage() async {
    if (!_batchMode) return;
    final file = await Navigator.of(context).push<XFile>(MaterialPageRoute(builder: (_) => const LiveDocumentCameraScreen()));
    if (file == null) return;
    await _setImage(file, append: true);
  }

  Future<void> _saveImagesToLibrary() async {
    if (_pages.isEmpty) return;
    setState(() => _processing = true);
    try {
      final storage = context.read<FileStorageService>();
      final data = context.read<AppDataController>();
      for (var i = 0; i < _pages.length; i++) {
        final tmp = await storage.newTmpFile('scan_page_${i + 1}.jpg');
        await tmp.writeAsBytes(_pages[i], flush: true);
        final name = 'Scan_Page_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final path = await storage.importIntoLibrary(tmp, preferredName: name);
        final size = await storage.fileSize(path);
        final thumb = await storage.saveThumbnail(_pages[i], name: 'thumb_${storage.newId()}.jpg');
        await data.addDocument(DocumentItem(
          id: storage.newId(), name: p.basename(path), filePath: path, thumbnailPath: thumb,
          sizeBytes: size, createdAt: DateTime.now(), modifiedAt: DateTime.now(), type: 'image', pageCount: 1,
        ));
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_pages.length} image${_pages.length == 1 ? '' : 's'} saved to Library.')));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _deletePage(int index) {
    if (_pages.length <= 1) return;
    setState(() {
      _pages.removeAt(index);
      if (index < _basePages.length) _basePages.removeAt(index);
      if (index < _sourcePaths.length) _sourcePaths.removeAt(index);
      if (index < _pageFilters.length) _pageFilters.removeAt(index);
      if (index < _pageBrightness.length) _pageBrightness.removeAt(index);
      if (index < _pageContrast.length) _pageContrast.removeAt(index);
      if (_selectedPage >= _pages.length) _selectedPage = _pages.length - 1;
      _processed = _pages[_selectedPage];
    });
  }

  void _duplicatePage(int index) {
    if (index < 0 || index >= _pages.length) return;
    setState(() {
      _pages.insert(index + 1, Uint8List.fromList(_pages[index]));
      _basePages.insert(index + 1, Uint8List.fromList(_basePages[index]));
      _sourcePaths.insert(index + 1, index < _sourcePaths.length ? _sourcePaths[index] : null);
      _pageFilters.insert(index + 1, _pageFilters[index]);
      _pageBrightness.insert(index + 1, _pageBrightness[index]);
      _pageContrast.insert(index + 1, _pageContrast[index]);
      _selectedPage = index + 1;
      _processed = _pages[_selectedPage];
    });
  }

  void _movePage(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _pages.removeAt(oldIndex);
      final base = _basePages.removeAt(oldIndex);
      final source = oldIndex < _sourcePaths.length ? _sourcePaths.removeAt(oldIndex) : null;
      final filter = _pageFilters.removeAt(oldIndex);
      final brightness = _pageBrightness.removeAt(oldIndex);
      final contrast = _pageContrast.removeAt(oldIndex);
      _pages.insert(newIndex, item);
      _basePages.insert(newIndex, base);
      while (_sourcePaths.length < newIndex) _sourcePaths.add(null);
      _sourcePaths.insert(newIndex, source);
      _pageFilters.insert(newIndex, filter);
      _pageBrightness.insert(newIndex, brightness);
      _pageContrast.insert(newIndex, contrast);
      if (_selectedPage == oldIndex) {
        _selectedPage = newIndex;
      } else if (oldIndex < _selectedPage && newIndex >= _selectedPage) {
        _selectedPage--;
      } else if (oldIndex > _selectedPage && newIndex <= _selectedPage) {
        _selectedPage++;
      }
      _processed = _pages[_selectedPage];
    });
  }

  void _selectPage(int index) {
    if (index < 0 || index >= _pages.length) return;
    setState(() {
      _selectedPage = index;
      _syncSelectedState();
      final source = index < _sourcePaths.length ? _sourcePaths[index] : null;
      _image = source == null ? null : XFile(source);
      _corners = null;
    });
  }

  Future<void> _applyAdjustments() async {
    if (_pages.isEmpty) return;
    setState(() => _processing = true);
    try {
      _ensurePageState(_pages.length);
      _pageBrightness[_selectedPage] = _brightness;
      _pageContrast[_selectedPage] = _contrast;
      final rendered = _renderPage(_basePages[_selectedPage], _filter, _brightness, _contrast);
      if (!mounted) return;
      setState(() {
        _pages[_selectedPage] = rendered;
        _processed = rendered;
      });
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _rotateSpecificPage(int index) async {
    if (index < 0 || index >= _pages.length) return;
    setState(() => _processing = true);
    try {
      final decoded = img.decodeImage(_pages[index]);
      if (decoded == null) return;
      final rotated = img.copyRotate(decoded, angle: 90);
      final jpg = Uint8List.fromList(img.encodeJpg(rotated, quality: 95));
      if (!mounted) return;
      setState(() {
        _pages[index] = jpg;
        _basePages[index] = jpg;
        _pageFilters[index] = 0;
        _pageBrightness[index] = 1.0;
        _pageContrast[index] = 1.0;
        if (_selectedPage == index) {
          _filter = 0; _brightness = 1.0; _contrast = 1.0; _processed = jpg;
        }
      });
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _rotatePage() => _rotateSpecificPage(_selectedPage);

  Future<void> _applyFilter(int filter) async {
    if (_pages.isEmpty) return;
    setState(() { _processing = true; _filter = filter; });
    try {
      _ensurePageState(_pages.length);
      _pageFilters[_selectedPage] = filter;
      _pageBrightness[_selectedPage] = _brightness;
      _pageContrast[_selectedPage] = _contrast;
      final rendered = _renderPage(_basePages[_selectedPage], filter, _brightness, _contrast);
      if (!mounted) return;
      setState(() {
        _pages[_selectedPage] = rendered;
        _processed = rendered;
        _corners = null;
      });
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _processed != null && _pages.isNotEmpty;
    final quality = context.watch<AppDataController>().scanQuality;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Scanner'),
        actions: [
          if (hasImage)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SegmentedButton<bool>(
                segments: const [ButtonSegment(value: false, label: Text('Single')), ButtonSegment(value: true, label: Text('Batch'))],
                selected: {_batchMode},
                onSelectionChanged: (v) {
                  final next = v.first;
                  if (!next && _pages.length > 1) {
                    final selected = _pages[_selectedPage];
                    final selectedBase = _selectedPage < _basePages.length ? _basePages[_selectedPage] : selected;
                    final source = _selectedPage < _sourcePaths.length ? _sourcePaths[_selectedPage] : null;
                    setState(() {
                      _batchMode = false;
                      _pages..clear()..add(selected);
                      _basePages..clear()..add(selectedBase);
                      _sourcePaths..clear()..add(source);
                      _pageFilters..clear()..add(_filter);
                      _pageBrightness..clear()..add(_brightness);
                      _pageContrast..clear()..add(_contrast);
                      _selectedPage = 0;
                      _processed = selected;
                    });
                  } else {
                    setState(() => _batchMode = next);
                  }
                },
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ),
          if (hasImage) IconButton(tooltip: 'Retake', onPressed: _capture, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(26), border: Border.all(color: Theme.of(context).dividerColor)),
                  clipBehavior: Clip.antiAlias,
                  child: _processing
                      ? const Center(child: CircularProgressIndicator())
                      : hasImage
                          ? InteractiveViewer(minScale: .8, maxScale: 4, child: Image.memory(_processed!, fit: BoxFit.contain))
                          : _EmptyScannerState(onCapture: _capture),
                ),
              ),
            ),
            if (hasImage && _batchMode) ...[
              const SizedBox(height: 8),
              PageThumbnailStrip(
                pages: _pages,
                selectedIndex: _selectedPage,
                onSelect: _selectPage,
                onMove: _movePage,
                onDelete: _deletePage,
                onDuplicate: _duplicatePage,
                onAdjustCorners: _adjustCornersForPage,
                onRotate: _rotateSpecificPage,
              ),
            ],
            if (hasImage)
              SizedBox(
                height: 54,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                  child: Row(children: [
                    _ActionChip(icon: Icons.crop_rounded, label: 'Adjust corners', onTap: () => _adjustCornersForPage(_selectedPage)),
                    _ActionChip(icon: Icons.rotate_right_rounded, label: 'Rotate', onTap: _rotatePage),
                    _ActionChip(icon: Icons.camera_alt_outlined, label: 'Add camera', onTap: _batchMode ? _addPage : null),
                    _ActionChip(icon: Icons.photo_library_outlined, label: 'Add gallery', onTap: _batchMode ? _addGalleryPages : null),
                    _ActionChip(icon: Icons.image_outlined, label: 'Save images', onTap: _saveImagesToLibrary),
                    _ActionChip(icon: Icons.share_outlined, label: 'Share page', onTap: _shareCurrentPage),
                  ]),
                ),
              ),
            if (hasImage)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
                child: Column(children: [
                  Row(children: [
                    Expanded(child: Text('Enhance', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                    if (_batchMode) Text('${_selectedPage + 1}/${_pages.length}', style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(width: 8),
                    Chip(label: Text('${quality[0].toUpperCase()}${quality.substring(1)}')),
                  ]),
                  SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                    _FilterChip(label: 'Original', selected: _filter == 0, onTap: () => _applyFilter(0)),
                    _FilterChip(label: 'B&W', selected: _filter == 1, onTap: () => _applyFilter(1)),
                    _FilterChip(label: 'Document', selected: _filter == 2, onTap: () => _applyFilter(2)),
                    _FilterChip(label: 'Sharp', selected: _filter == 3, onTap: () => _applyFilter(3)),
                    _FilterChip(label: 'Color', selected: _filter == 4, onTap: () => _applyFilter(4)),
                  ])),
                  Row(children: [Expanded(child: Slider(min: .75, max: 1.35, value: _brightness, onChanged: (v) => setState(() => _brightness = v), onChangeEnd: (_) => _applyAdjustments())), Expanded(child: Slider(min: .75, max: 1.5, value: _contrast, onChanged: (v) => setState(() => _contrast = v), onChangeEnd: (_) => _applyAdjustments()))]),
                  Row(children: [Expanded(child: FilledButton.icon(onPressed: _saveAsPdf, icon: const Icon(Icons.picture_as_pdf_rounded), label: Text(_batchMode && _pages.length > 1 ? 'Save ${_pages.length} Pages as PDF' : 'Save PDF'))), const SizedBox(width: 10), Expanded(child: OutlinedButton.icon(onPressed: _pages.isEmpty ? null : _extractSavedDocument, icon: const Icon(Icons.text_fields_rounded), label: const Text('OCR')))]),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyScannerState extends StatelessWidget {
  final VoidCallback onCapture;
  const _EmptyScannerState({required this.onCapture});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withValues(alpha: .1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.document_scanner_rounded, size: 42, color: AppColors.brandPrimary),
            ),
            const SizedBox(height: 20),
            Text('Scan a document', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Capture a page clearly. Smart framing and document processing keep every scan clean.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCapture,
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Open Camera'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ActionChip({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(avatar: Icon(icon, size: 18), label: Text(label), onPressed: onTap));
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}


class _DocumentCornersPainter extends CustomPainter {
  final List<Offset> points;
  _DocumentCornersPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length != 4) return;
    // The current preview is a contain-fit overlay. Normalized coordinates
    // are mapped into the preview bounds; the next camera-preview phase will
    // use the camera aspect ratio to account for letterboxing precisely.
    final mapped = points.map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList();
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    final path = Path()..moveTo(mapped[0].dx, mapped[0].dy);
    for (var i = 1; i < mapped.length; i++) path.lineTo(mapped[i].dx, mapped[i].dy);
    path.close();
    canvas.drawPath(path, paint);
    final dot = Paint()..color = AppColors.brandPrimary;
    for (final p in mapped) canvas.drawCircle(p, 7, dot);
  }

  @override
  bool shouldRepaint(covariant _DocumentCornersPainter oldDelegate) => oldDelegate.points != points;
}
