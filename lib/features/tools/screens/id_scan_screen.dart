import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../core/services/file_storage_service.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../models/document_item.dart';
import '../../scanner/screens/live_document_camera_screen.dart';

/// Real two-sided ID workflow. It deliberately stays generic: the app does
/// not pretend to recognize passport/license/card sub-types without a model.
class IdScanScreen extends StatefulWidget {
  const IdScanScreen({super.key});
  @override State<IdScanScreen> createState() => _IdScanScreenState();
}

class _IdScanScreenState extends State<IdScanScreen> {
  final List<Uint8List> _sides = [];
  bool _working = false;
  static const _channel = MethodChannel('pdf_master_tools/scanner');

  Future<void> _captureSide() async {
    if (_working || _sides.length >= 2) return;
    final file = await Navigator.push<XFile>(
      context,
      MaterialPageRoute(builder: (_) => const LiveDocumentCameraScreen()),
    );
    if (file == null || !mounted) return;
    setState(() => _working = true);
    try {
      final original = await File(file.path).readAsBytes();
      final processed = await _tryAutoCrop(file.path) ?? original;
      if (!mounted) return;
      setState(() => _sides.add(processed));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<Uint8List?> _tryAutoCrop(String path) async {
    try {
      final points = await _channel.invokeMethod<List<dynamic>>('detectDocument', {'path': path});
      if (points == null || points.length != 4) return null;
      final cropped = await _channel.invokeMethod<String>('perspectiveCrop', {
        'path': path,
        'points': points.map((p) => {'x': (p['x'] as num).toDouble(), 'y': (p['y'] as num).toDouble()}).toList(),
      });
      if (cropped == null) return null;
      final file = File(cropped);
      return await file.exists() ? file.readAsBytes() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    if (_sides.isEmpty || _working) return;
    setState(() => _working = true);
    try {
      final storage = context.read<FileStorageService>();
      final data = context.read<AppDataController>();
      final pdf = pw.Document();
      for (final bytes in _sides) {
        final image = pw.MemoryImage(bytes);
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(18),
            build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
          ),
        );
      }
      final tmp = await storage.newTmpFile('id_scan.pdf');
      await tmp.writeAsBytes(await pdf.save(), flush: true);
      final name = 'ID_Scan_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final path = await storage.importIntoLibrary(tmp, preferredName: name);
      final thumb = await storage.saveThumbnail(_sides.first, name: 'id_thumb_${storage.newId()}.jpg');
      await data.addDocument(DocumentItem(
        id: storage.newId(), name: p.basename(path), filePath: path,
        thumbnailPath: thumb, sizeBytes: await storage.fileSize(path),
        createdAt: DateTime.now(), modifiedAt: DateTime.now(), type: 'pdf', pageCount: _sides.length,
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID document saved to Library.')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create the ID PDF: $e')));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ID Scan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.badge_rounded, size: 36),
                const SizedBox(height: 10),
                Text('Scan both sides', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Capture the front and back. The two sides will be combined into one PDF.'),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          _SideCard(label: 'Front side', image: _sides.isNotEmpty ? _sides[0] : null, onTap: _sides.isEmpty ? () => _captureSide() : null),
          const SizedBox(height: 12),
          _SideCard(label: 'Back side', image: _sides.length > 1 ? _sides[1] : null, onTap: _sides.length == 1 ? () => _captureSide() : null),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _sides.isEmpty || _working ? null : _save,
            icon: _working ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.picture_as_pdf_rounded),
            label: Text(_sides.length == 2 ? 'Save 2-page ID PDF' : 'Save ID PDF'),
          ),
          if (_sides.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton.icon(onPressed: _working ? null : () => setState(_sides.clear), icon: const Icon(Icons.restart_alt_rounded), label: const Text('Start over')),
          ],
        ],
      ),
    );
  }
}

class _SideCard extends StatelessWidget {
  final String label;
  final Uint8List? image;
  final VoidCallback? onTap;
  const _SideCard({required this.label, required this.image, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 190,
          child: image == null
              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo_rounded, size: 34, color: theme.colorScheme.primary), const SizedBox(height: 8), Text('Capture $label')])
              : Stack(fit: StackFit.expand, children: [Image.memory(image!, fit: BoxFit.contain), Positioned(left: 12, bottom: 12, child: Chip(label: Text(label))) ]),
        ),
      ),
    );
  }
}
