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

import '../../../core/services/file_storage_service.dart';
import '../../../models/document_item.dart';
import '../../../core/storage/app_data_controller.dart';

import '../../../core/theme/app_colors.dart';
import '../../ocr/screens/text_extraction_screen.dart';
import '../widgets/page_thumbnail_strip.dart';
import 'corner_adjust_screen.dart';
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

  Future<Uint8List> _processScanFile(XFile file) async {
    final original = await File(file.path).readAsBytes();

    if (!context.read<AppDataController>().autoDocumentDetection) {
      final decoded = img.decodeImage(original);
      if (decoded == null) return original;
      return Uint8List.fromList(
        img.encodeJpg(
          decoded,
          quality: _imageQuality(context),
        ),
      );
    }

    try {
      final detected =
          await _scannerChannel.invokeMethod<List<dynamic>>(
        'detectDocument',
        {'path': file.path},
      );

      if (detected == null || detected.length != 4) {
        return original;
      }

      final points = detected.map((p) {
        return {
          'x': (p['x'] as num).toDouble(),
          'y': (p['y'] as num).toDouble(),
        };
      }).toList();

      final output =
          await _scannerChannel.invokeMethod<String>(
        'perspectiveCrop',
        {
          'path': file.path,
          'points': points,
        },
      );

      if (output != null) {
        final cropped = await File(output).readAsBytes();
        if (cropped.isNotEmpty) return cropped;
      }
    } catch (_) {
      // Detection failure falls back to the original image.
    }

    return original;
  }

  Future<void> _setImage(XFile file) async {
    setState(() {
      _image = file;
      _processing = true;
      _filter = 0;
      _brightness = 1.0;
      _contrast = 1.0;
      _corners = null;
      _savedDocumentId = null;
      _selectedPage = 0;
    });

    try {
      final processed = await _processScanFile(file);

      if (!mounted) return;

      setState(() {
        _processed = processed;

        if (_pages.isEmpty) {
          _pages.add(processed);
        } else {
          _pages[_selectedPage.clamp(0, _pages.length - 1)] = processed;
        }

        _corners = null;
        _processing = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not process this document image.'),
          ),
        );
      }
    }
  }

  /// Opens the full-screen manual corner-adjustment step for [index], then
  /// perspective-crops that page to whatever corners the user confirms.
  /// Works for any page in the batch, not just the one just captured —
  /// each page's bytes are materialized to a temp file first since the
  /// native crop channel operates on a file path.
  Future<void> _adjustCornersForPage(int index) async {
    if (index < 0 || index >= _pages.length) return;
    final bytes = _pages[index];
    final storage = context.read<FileStorageService>();
    final tmp = await storage.newTmpFile('adjust_$index.jpg');
    await tmp.writeAsBytes(bytes, flush: true);
    if (!mounted) return;
    final result = await Navigator.of(context).push<List<Offset>>(
      MaterialPageRoute(
        builder: (_) => CornerAdjustScreen(
          imagePath: tmp.path,
          imageBytes: bytes,
          initialCorners: index == _selectedPage ? _corners : null,
        ),
      ),
    );
    if (result == null || result.length != 4 || !mounted) return;
    setState(() => _processing = true);
    try {
      final points = result.map((p) => {'x': p.dx, 'y': p.dy}).toList();
      final output = await _scannerChannel.invokeMethod<String>('perspectiveCrop', {
        'path': tmp.path,
        'points': points,
      });
      if (output != null) {
        final croppedBytes = await File(output).readAsBytes();
        if (!mounted) return;
        setState(() {
          _pages[index] = croppedBytes;
          if (index == _selectedPage) {
            _processed = croppedBytes;
            _image = XFile(output);
            _corners = null;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not crop the document to those corners.')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _showAddPageSheet() async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _addPage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _addGalleryPages();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _extractSavedDocument() async {
    final id = _savedDocumentId;
    if (id == null || !mounted) return;
    final doc = context.read<AppDataController>().documentById(id);
    if (doc == null) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TextExtractionScreen(imagePath: doc.filePath, documentId: doc.id)));
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
        final image = pw.MemoryImage(bytes);
        doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(18), build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain))));
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
    final files = await _picker.pickMultiImage(
      imageQuality: _imageQuality(context),
      maxWidth: _maxWidth(context),
    );

    if (files.isEmpty) return;

    setState(() => _processing = true);

    try {
      for (final file in files) {
        final processed = await _processScanFile(file);

        if (processed.isNotEmpty) {
          _pages.add(processed);
        }
      }

      if (_pages.isNotEmpty) {
        _selectedPage = _pages.length - 1;
        _processed = _pages[_selectedPage];
        _image = null;
        _corners = null;
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Some gallery pages could not be processed.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _addPage() async {
    final file = await Navigator.of(context).push<XFile>(
      MaterialPageRoute(
        builder: (_) => const LiveDocumentCameraScreen(),
      ),
    );

    if (file == null) return;

    try {
      final bytes = await File(file.path).readAsBytes();
      final decoded = img.decodeImage(bytes);

      if (decoded == null) return;

      final jpg = Uint8List.fromList(
        img.encodeJpg(
          decoded,
          quality: _imageQuality(context),
        ),
      );

      if (!mounted) return;

      setState(() {
        _pages.add(jpg);
        _selectedPage = _pages.length - 1;
        _image = file;
        _processed = jpg;
        _corners = null;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not add the scanned page.'),
          ),
        );
      }
    }
  }

  void _deletePage(int index) {
    if (_pages.length <= 1) return;
    setState(() {
      _pages.removeAt(index);
      if (_selectedPage >= _pages.length) _selectedPage = _pages.length - 1;
      _processed = _pages[_selectedPage];
    });
  }

  void _duplicatePage(int index) {
    if (index < 0 || index >= _pages.length) return;
    setState(() {
      _pages.insert(index + 1, Uint8List.fromList(_pages[index]));
      _selectedPage = index + 1;
      _processed = _pages[_selectedPage];
    });
  }

  void _movePage(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, item);
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
      _processed = _pages[index];
      _image = null;
      _corners = null;
    });
  }

  Future<void> _applyAdjustments() async {
    if (_processed == null) return;
    setState(() => _processing = true);
    try {
      final decoded = img.decodeImage(_processed!);
      if (decoded == null) return;
      img.adjustColor(decoded, brightness: _brightness, contrast: _contrast);
      final jpg = Uint8List.fromList(img.encodeJpg(decoded, quality: 95));
      if (!mounted) return;
      setState(() {
        _processed = jpg;
        if (_pages.isEmpty) {
          _pages.add(jpg);
        } else {
          _pages[_selectedPage] = jpg;
        }
      });
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _rotatePage() => _rotateSpecificPage(_selectedPage);

  /// Rotates a specific page in the batch by 90°, regardless of which page
  /// is currently selected in the editor.
  Future<void> _rotateSpecificPage(int index) async {
    final bytes = index >= 0 && index < _pages.length ? _pages[index] : _processed;
    if (bytes == null) return;
    setState(() => _processing = true);
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return;
      final rotated = img.copyRotate(decoded, angle: 90);
      final jpg = Uint8List.fromList(img.encodeJpg(rotated, quality: 95));
      if (!mounted) return;
      setState(() {
        if (_pages.isEmpty) {
          _pages.add(jpg);
          _selectedPage = 0;
          _processed = jpg;
        } else {
          _pages[index] = jpg;
          if (index == _selectedPage) _processed = jpg;
        }
      });
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _applyFilter(int filter) async {
    if (_processed == null) return;
    setState(() {
      _processing = true;
      _filter = filter;
    });
    final decoded = img.decodeImage(_processed!);
    if (decoded == null) {
      if (mounted) setState(() => _processing = false);
      return;
    }
    if (filter == 1) {
      img.grayscale(decoded);
    } else if (filter == 2) {
      img.grayscale(decoded);
      img.adjustColor(decoded, contrast: 1.35, brightness: 1.05);
    } else if (filter == 3) {
      img.grayscale(decoded);
      img.adjustColor(decoded, contrast: 1.75, brightness: 1.08);
      img.convolution(decoded, filter: const [
        0, -1, 0,
        -1, 5, -1,
        0, -1, 0,
      ]);
    } else if (filter == 4) {
      img.adjustColor(decoded, contrast: 1.22, brightness: 1.04, saturation: 0.92);
    }
    final jpg = img.encodeJpg(decoded, quality: 94);

    if (!mounted) return;

    setState(() {
      _processed = Uint8List.fromList(jpg);

      if (_pages.isEmpty) {
        _pages.add(_processed!);
        _selectedPage = 0;
      } else {
        _pages[_selectedPage] = _processed!;
      }

      _corners = null;
      _processing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _processed != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Scanner'),
        actions: [
          if (hasImage)
            IconButton(
              tooltip: 'Retake',
              onPressed: _capture,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: Column(
            children: [
              Expanded(
                flex: hasImage ? 4 : 1,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkSurface
                        : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _processing
                      ? const Center(child: CircularProgressIndicator())
                      : hasImage
                          ? InteractiveViewer(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.memory(_processed!, fit: BoxFit.contain),
                                      if (_corners != null)
                                        CustomPaint(painter: _DocumentCornersPainter(_corners!)),
                                    ],
                                  );
                                },
                              ),
                            )
                          : _EmptyScannerState(onCapture: _capture),
                ),
              ),
              const SizedBox(height: 14),
              // The rest of the editor (page strip, crop/save actions, enhance
              // controls, filters) scrolls independently of the preview and the
              // pinned capture bar below, so it never overflows on smaller
              // phones no matter how many pages or controls are visible.
              if (hasImage)
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text('Pages', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(width: 8),
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text('${_pages.length}'),
                            ),
                            const Spacer(),
                            if (_corners != null)
                              Text('Edges detected', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                        const SizedBox(height: 6),
                        PageThumbnailStrip(
                          pages: _pages,
                          selectedIndex: _selectedPage,
                          onSelect: _selectPage,
                          onReorder: _movePage,
                          onDelete: _deletePage,
                          onDuplicate: _duplicatePage,
                          onAdjustCrop: _adjustCornersForPage,
                          onRotate: _rotateSpecificPage,
                          onAddPressed: _showAddPageSheet,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => _adjustCornersForPage(_selectedPage),
                                icon: const Icon(Icons.crop_rounded),
                                label: const Text('Adjust Corners'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _saveAsPdf,
                                icon: const Icon(Icons.picture_as_pdf_rounded),
                                label: const Text('Save PDF'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _savedDocumentId != null ? _extractSavedDocument : (_image == null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TextExtractionScreen(imagePath: _image!.path, documentId: _savedDocumentId)))),
                                icon: const Icon(Icons.text_fields_rounded),
                                label: const Text('Extract Text'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _rotatePage,
                                icon: const Icon(Icons.rotate_right_rounded),
                                label: const Text('Rotate 90°'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  setState(() { _brightness = 1.0; _contrast = 1.0; });
                                  _applyAdjustments();
                                },
                                icon: const Icon(Icons.restart_alt_rounded),
                                label: const Text('Reset'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text('Enhance', style: Theme.of(context).textTheme.titleMedium),
                            const Spacer(),
                            Chip(avatar: const Icon(Icons.high_quality_rounded, size: 17), label: Text('${context.watch<AppDataController>().scanQuality[0].toUpperCase()}${context.watch<AppDataController>().scanQuality.substring(1)} quality')),
                          ],
                        ),
                        Row(
                          children: [
                            const SizedBox(width: 72, child: Text('Brightness')),
                            Expanded(
                              child: Slider(
                                min: 0.75, max: 1.35, value: _brightness,
                                onChanged: (v) => setState(() => _brightness = v),
                                onChangeEnd: (_) => _applyAdjustments(),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const SizedBox(width: 72, child: Text('Contrast')),
                            Expanded(
                              child: Slider(
                                min: 0.75, max: 1.5, value: _contrast,
                                onChanged: (v) => setState(() => _contrast = v),
                                onChangeEnd: (_) => _applyAdjustments(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 54,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _FilterChip(label: 'Original', selected: _filter == 0, onTap: () => _applyFilter(0)),
                              _FilterChip(label: 'Grayscale', selected: _filter == 1, onTap: () => _applyFilter(1)),
                              _FilterChip(label: 'Document', selected: _filter == 2, onTap: () => _applyFilter(2)),
                              _FilterChip(label: 'B&W', selected: _filter == 3, onTap: () => _applyFilter(3)),
                              _FilterChip(label: 'Magic', selected: _filter == 4, onTap: () => _applyFilter(4)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _capture,
                      icon: const Icon(Icons.document_scanner_rounded),
                      label: Text(hasImage ? 'Scan Again' : 'Scan Document'),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
