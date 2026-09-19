import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../../core/constants/tools_catalog.dart';
import '../../../core/services/pdf_tools_service.dart';
import '../../../core/services/file_storage_service.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../core/widgets/empty_state.dart';
import '../../tools/widgets/source_picker.dart';
import '../../tools/widgets/tool_result_screen.dart';
import '../../tools/widgets/tool_history_list.dart';
import '../widgets/canvas_element.dart';
import 'signature_pad_screen.dart';

class _PlacedElement {
  final String id;
  int pageIndex;
  Offset position; // in page-image pixel space at render DPI
  Size size;
  final bool isImage;
  String? imagePath;
  String? text;
  _PlacedElement({
    required this.id,
    required this.pageIndex,
    required this.position,
    required this.size,
    required this.isImage,
    this.imagePath,
    this.text,
  });
}

class FillSignScreen extends StatefulWidget {
  final String? initialPath;
  const FillSignScreen({super.key, this.initialPath});

  @override
  State<FillSignScreen> createState() => _FillSignScreenState();
}

class _FillSignScreenState extends State<FillSignScreen> {
  String? _path;
  List<Uint8List> _pageImages = [];
  List<Size> _pageSizes = []; // rendered raster pixel size per page
  int _currentPage = 0;
  bool _loading = false;
  bool _working = false;
  bool _canvasInteractive = true;
  final List<_PlacedElement> _elements = [];
  String? _selectedElementId;
  int _idCounter = 0;
  static const double _renderDpi = 130;

  @override
  void initState() {
    super.initState();
    if (widget.initialPath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load(widget.initialPath!));
    }
  }

  Future<void> _pickFile() async {
    final picked = await pickSourceFiles(context, allowMultiple: false, extensions: const ['pdf']);
    if (picked.isEmpty) return;
    await _load(picked.first);
  }

  Future<void> _load(String path) async {
    setState(() { _path = path; _loading = true; });
    try {
      final tools = context.read<PdfToolsService>();
      final thumbs = await tools.renderPageThumbnails(path, dpi: _renderDpi);
      if (!mounted) return;
      if (thumbs.isEmpty) throw Exception('No readable pages found');
      setState(() {
        _pageImages = thumbs;
        _pageSizes = [];
        _loading = false;
        _currentPage = 0;
        _elements.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _path = null; _loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Couldn't open this PDF. It may be corrupted or password protected."),
      ));
    }
  }

  Future<void> _addSignature() async {
    final bytes = await Navigator.push<Uint8List?>(
      context, MaterialPageRoute(builder: (_) => const SignaturePadScreen()));
    if (bytes == null || !mounted) return;
    final storage = context.read<FileStorageService>();
    final file = await storage.newTmpFile('sig_${_idCounter}.png');
    await file.writeAsBytes(bytes, flush: true);
    setState(() {
      final id = 'el_${_idCounter++}';
      _elements.add(_PlacedElement(
        id: id,
        pageIndex: _currentPage,
        position: const Offset(60, 60),
        size: const Size(160, 80),
        isImage: true,
        imagePath: file.path,
      ));
      _selectedElementId = id;
    });
  }

  Future<void> _addText() async {
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Add text'),
          content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Type here')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Add')),
          ],
        );
      },
    );
    if (text == null || text.trim().isEmpty) return;
    setState(() {
      final id = 'el_${_idCounter++}';
      _elements.add(_PlacedElement(
        id: id,
        pageIndex: _currentPage,
        position: const Offset(60, 60),
        size: const Size(160, 40),
        isImage: false,
        text: text,
      ));
      _selectedElementId = id;
    });
  }

  Future<void> _save() async {
    if (_path == null) return;
    if (_elements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add a signature or text before saving.')));
      return;
    }
    setState(() => _working = true);
    try {
      final tools = context.read<PdfToolsService>();
      final data = context.read<AppDataController>();
      final baseName = p.basenameWithoutExtension(_path!);
      final outName = '${baseName}_signed.pdf';

      final overlays = _elements.map((e) {
        final pageSize = _pageSizes.isNotEmpty ? _pageSizes[e.pageIndex] : const Size(612, 792);
        final normX = e.position.dx / pageSize.width;
        final normY = e.position.dy / pageSize.height;
        final normW = e.size.width / pageSize.width;
        final normH = e.size.height / pageSize.height;
        if (e.isImage) {
          return PdfOverlayImage(
            pageIndex: e.pageIndex,
            normX: normX, normY: normY, normW: normW, normH: normH,
            imagePath: e.imagePath!,
          );
        }
        return PdfOverlayText(
          pageIndex: e.pageIndex,
          normX: normX, normY: normY, normW: normW, normH: normH,
          text: e.text!,
          fontSize: 14,
        );
      }).toList();

      final file = await tools.applyOverlays(_path!, elements: overlays, outputName: outName);
      final pages = await tools.pageCount(file.path);
      final thumb = await tools.generateThumbnail(file.path, type: 'pdf');
      final doc = await data.registerToolResult(
        tmpFile: file,
        fileName: outName,
        toolId: ToolId.fillSign.name,
        toolTitle: 'Signed $baseName',
        type: 'pdf',
        pageCount: pages,
      );
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ToolResultScreen(results: [doc], successTitle: 'Document signed!'),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fill & Sign'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'History',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const ToolHistoryScreen(toolId: ToolId.fillSign, title: 'Fill & Sign History'),
            )),
          ),
          if (_pageImages.isNotEmpty)
            TextButton(
              onPressed: _working ? null : _save,
              child: _working
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
        ],
      ),
      floatingActionButton: _pageImages.isEmpty
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'sig',
                  onPressed: _addSignature,
                  child: const Icon(Icons.draw_rounded),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'txt',
                  onPressed: _addText,
                  child: const Icon(Icons.text_fields_rounded),
                ),
              ],
            ),
      body: SafeArea(
        child: _path == null
            ? Column(
                children: [
                  const Expanded(
                    child: EmptyState(
                      icon: Icons.draw_rounded,
                      title: 'Choose a PDF',
                      message: 'Add your signature and text anywhere, then save.',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.upload_file_rounded),
                        label: const Text('Choose PDF'),
                      ),
                    ),
                  ),
                ],
              )
            : _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      if (_pageImages.length > 1)
                        SizedBox(
                          height: 44,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _pageImages.length,
                            itemBuilder: (ctx, i) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: ChoiceChip(
                                label: Text('${i + 1}'),
                                selected: _currentPage == i,
                                onSelected: (_) => setState(() => _currentPage = i),
                              ),
                            ),
                          ),
                        ),
                      Expanded(child: _buildPageCanvas()),
                    ],
                  ),
      ),
    );
  }

  Widget _buildPageCanvas() {
    if (_pageImages.isEmpty) {
      // Defensive guard: _load() never leaves _pageImages empty on
      // success, but this keeps the screen crash-safe rather than
      // throwing a RangeError if state ever gets out of sync.
      return const EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'No pages to display',
        message: 'Try choosing the PDF again.',
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      final imgBytes = _pageImages[_currentPage];
      return FutureBuilder<ui.Image>(
        future: _decodeImage(imgBytes),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final img = snap.data!;
          while (_pageSizes.length <= _currentPage) {
            _pageSizes.add(const Size(612, 792));
          }
          _pageSizes[_currentPage] = Size(img.width.toDouble(), img.height.toDouble());

          return InteractiveViewer(
            panEnabled: _canvasInteractive,
            scaleEnabled: _canvasInteractive,
            minScale: 0.5,
            maxScale: 4,
            boundaryMargin: const EdgeInsets.all(80),
            child: Center(
              child: SizedBox(
                width: img.width.toDouble(),
                height: img.height.toDouble(),
                child: Stack(
                  children: [
                    Positioned.fill(child: Image.memory(imgBytes, fit: BoxFit.fill)),
                    ..._elements.where((e) => e.pageIndex == _currentPage).map((e) {
                      return CanvasElement(
                        key: ValueKey(e.id),
                        position: e.position,
                        size: e.size,
                        selected: _selectedElementId == e.id,
                        onTap: () => setState(() => _selectedElementId = e.id),
                        onMove: (pos) => setState(() => e.position = pos),
                        onResize: (size) => setState(() => e.size = size),
                        onDelete: () => setState(() {
                          _elements.remove(e);
                          if (_selectedElementId == e.id) _selectedElementId = null;
                        }),
                        onInteractionLock: (locked) => setState(() => _canvasInteractive = !locked),
                        child: e.isImage
                            ? Image.file(File(e.imagePath!), fit: BoxFit.contain)
                            : Container(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  e.text!,
                                  style: const TextStyle(fontSize: 22, color: Colors.black, fontWeight: FontWeight.w600),
                                ),
                              ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          );
        },
      );
    });
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}
