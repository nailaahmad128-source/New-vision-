import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import '../../../core/services/file_storage_service.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../models/document_item.dart';

/// Windows edition of Smart Scanner.
///
/// Desktop cannot use the mobile camera pipeline, so this screen turns the
/// laptop into a document workstation: import one or many images, create a
/// PDF, and send the result directly into Library.
class SmartScannerScreen extends StatefulWidget {
  const SmartScannerScreen({super.key});
  @override State<SmartScannerScreen> createState() => _SmartScannerScreenState();
}

class _SmartScannerScreenState extends State<SmartScannerScreen> {
  final List<String> _files = [];
  bool _busy = false;

  Future<void> _pickImages() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true, withData: false);
    if (r == null) return;
    setState(() {
      _files
        ..clear()
        ..addAll(r.files.where((f) => f.path != null).map((f) => f.path!));
    });
  }

  Future<void> _saveAsPdf() async {
    if (_files.isEmpty) return;
    setState(() => _busy = true);
    try {
      final docPdf = pw.Document();
      for (final path in _files) {
        final bytes = await File(path).readAsBytes();
        final image = pw.MemoryImage(bytes);
        docPdf.addPage(pw.Page(margin: const pw.EdgeInsets.all(18), build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain))));
      }
      final storage = context.read<FileStorageService>();
      final tmp = await storage.newTmpFile('scan.pdf');
      await tmp.writeAsBytes(await docPdf.save(), flush: true);
      final saved = await storage.importIntoLibrary(tmp, preferredName: 'Scanned_Document.pdf');
      final now = DateTime.now();
      final item = DocumentItem(id: storage.newId(), name: p.basename(saved), filePath: saved, sizeBytes: await storage.fileSize(saved), createdAt: now, modifiedAt: now, type: 'pdf', pageCount: _files.length);
      await context.read<AppDataController>().addDocument(item);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF saved • ${_files.length} page(s)')));
        setState(() => _files.clear());
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create PDF: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importImages() async {
    if (_files.isEmpty) return;
    setState(() => _busy = true);
    try {
      final storage = context.read<FileStorageService>();
      final data = context.read<AppDataController>();
      for (final sourcePath in _files) {
        final source = File(sourcePath);
        final saved = await storage.importIntoLibrary(source, preferredName: p.basename(sourcePath));
        final now = DateTime.now();
        await data.addDocument(DocumentItem(id: storage.newId(), name: p.basename(saved), filePath: saved, sizeBytes: await storage.fileSize(saved), createdAt: now, modifiedAt: now, type: 'image', pageCount: 1));
      }
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_files.length} image(s) imported to Library'))); setState(() => _files.clear()); }
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Smart Scanner • Windows')),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      Container(padding: const EdgeInsets.all(26), decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), color: Theme.of(context).colorScheme.primaryContainer), child: Column(children: [
        Icon(Icons.document_scanner_rounded, size: 68, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 14), const Text('Desktop Document Scanner', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8), const Text('Select document images from your laptop, arrange them, and create a professional PDF.', textAlign: TextAlign.center),
        const SizedBox(height: 20), FilledButton.icon(onPressed: _busy ? null : _pickImages, icon: const Icon(Icons.add_photo_alternate_rounded), label: const Text('Choose document images')),
      ])),
      const SizedBox(height: 18),
      if (_files.isNotEmpty) Card(child: Column(children: [
        ListTile(title: Text('${_files.length} image(s) selected'), subtitle: const Text('Ready to import or combine into one PDF'), leading: const Icon(Icons.collections_rounded)),
        ..._files.take(8).map((f) => ListTile(dense: true, leading: const Icon(Icons.image_outlined), title: Text(p.basename(f), maxLines: 1, overflow: TextOverflow.ellipsis))),
        if (_files.length > 8) ListTile(title: Text('+ ${_files.length - 8} more')),
      ])),
      if (_files.isNotEmpty) ...[
        const SizedBox(height: 12),
        Row(children: [Expanded(child: FilledButton.icon(onPressed: _busy ? null : _saveAsPdf, icon: const Icon(Icons.picture_as_pdf_rounded), label: const Text('Create PDF'))), const SizedBox(width: 10), Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : _importImages, icon: const Icon(Icons.file_download_done_rounded), label: const Text('Import images')))]),
      ],
    ]),
  );
}
