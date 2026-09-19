import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../translation/services/speech_service.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../models/document_item.dart';
import '../../fill_sign/screens/fill_sign_screen.dart';
import '../../ocr/screens/text_extraction_screen.dart';
import '../../reader/screens/pdf_reader_screen.dart';
import '../../tools/screens/compress_screen.dart';
import '../../tools/screens/merge_screen.dart';
import '../../tools/screens/rotate_screen.dart';
import '../../tools/screens/security_screen.dart';
import '../../tools/screens/split_screen.dart';
import '../../tools/screens/watermark_screen.dart';
import '../../translation/screens/translation_screen.dart';
import '../../tools/screens/pdf_page_editor_screen.dart';

class DocumentDetailScreen extends StatelessWidget {
  final DocumentItem doc;
  const DocumentDetailScreen({super.key, required this.doc});

  Future<void> _rename(BuildContext context) async {
    final c = TextEditingController(text: doc.name.replaceFirst(RegExp(r'\.pdf$'), ''));
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename document'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(labelText: 'Name')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Save'))],
      ),
    );
    c.dispose();
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    await context.read<AppDataController>().renameDocument(doc.id, name.trim());
  }

  Future<void> _listen(BuildContext context, DocumentItem d) async {
    var text = d.extractedText?.trim() ?? '';
    if (text.isEmpty) {
      if (d.type == 'pdf' || d.type == 'image') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => TextExtractionScreen(imagePath: d.filePath, documentId: d.id)));
      }
      return;
    }
    final tts = SpeechService();
    await tts.speak(text);
    await tts.dispose();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reading document text…')));
    }
  }

  Future<void> _print(BuildContext context, DocumentItem d) async {
    try {
      await Printing.layoutPdf(onLayout: (_) => File(d.filePath).readAsBytes());
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the print dialog: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = context.watch<AppDataController>().documentById(doc.id) ?? doc;
    final data = context.read<AppDataController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document'),
        actions: [
          IconButton(icon: Icon(live.isFavorite ? Icons.star_rounded : Icons.star_border_rounded), onPressed: () => data.toggleFavorite(live.id)),
          IconButton(icon: const Icon(Icons.more_vert_rounded), onPressed: () => _showMore(context, live)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          _PreviewCard(doc: live),
          const SizedBox(height: 18),
          Text(live.name, style: Theme.of(context).textTheme.headlineSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Text('${live.pageCount ?? 1} page${(live.pageCount ?? 1) == 1 ? '' : 's'}  •  ${_size(live.sizeBytes)}  •  ${live.type.toUpperCase()}'),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: () => _open(context, live), icon: const Icon(Icons.open_in_new_rounded), label: const Text('Open'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: () => Share.shareXFiles([XFile(live.filePath)]), icon: const Icon(Icons.share_rounded), label: const Text('Share'))),
          ]),
          const SizedBox(height: 14),
          _ActionGrid(
            doc: live,
            onListen: () => _listen(context, live),
            onEditPages: live.type == 'pdf' ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => PdfPageEditorScreen(doc: live))) : null,
            onPrint: live.type == 'pdf' ? () => _print(context, live) : null,
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, DocumentItem d) {
    if (d.type == 'pdf') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PdfReaderScreen(doc: d)));
    } else {
      OpenFilex.open(d.filePath);
    }
  }

  Future<void> _showMore(BuildContext context, DocumentItem d) async {
    final action = await showModalBottomSheet<String>(context: context, showDragHandle: true, builder: (ctx) => SafeArea(child: Wrap(children: [
      ListTile(leading: const Icon(Icons.drive_file_rename_outline_rounded), title: const Text('Rename'), onTap: () => Navigator.pop(ctx, 'rename')),
      ListTile(leading: Icon(d.isFavorite ? Icons.star_rounded : Icons.star_border_rounded), title: Text(d.isFavorite ? 'Remove favorite' : 'Add to favorites'), onTap: () => Navigator.pop(ctx, 'favorite')),
      ListTile(leading: const Icon(Icons.delete_outline_rounded), title: const Text('Move to Recently Deleted'), onTap: () => Navigator.pop(ctx, 'delete')),
    ])));
    if (!context.mounted || action == null) return;
    final data = context.read<AppDataController>();
    if (action == 'rename') await _rename(context);
    if (action == 'favorite') await data.toggleFavorite(d.id);
    if (action == 'delete') { await data.deleteDocument(d.id); if (context.mounted) Navigator.pop(context); }
  }

  static String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _PreviewCard extends StatelessWidget {
  final DocumentItem doc;
  const _PreviewCard({required this.doc});
  @override Widget build(BuildContext context) {
    return Container(
      height: 260,
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: doc.thumbnailPath != null && File(doc.thumbnailPath!).existsSync()
          ? Image.file(File(doc.thumbnailPath!), fit: BoxFit.contain)
          : Center(child: Icon(doc.type == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.image_rounded, size: 86, color: Theme.of(context).colorScheme.primary)),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  final DocumentItem doc;
  final VoidCallback onListen;
  final VoidCallback? onEditPages;
  final VoidCallback? onPrint;
  const _ActionGrid({required this.doc, required this.onListen, this.onEditPages, this.onPrint});
  @override Widget build(BuildContext context) {
    final isPdf = doc.type == 'pdf';
    final actions = [
      ('Extract Text', Icons.text_fields_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => TextExtractionScreen(imagePath: doc.filePath, documentId: doc.id)))),
      ('Translate', Icons.translate_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => TranslationScreen(initialText: doc.extractedText ?? '')))),
      ('Listen', Icons.volume_up_rounded, onListen),
      ('Favorite', doc.isFavorite ? Icons.star_rounded : Icons.star_border_rounded, () => context.read<AppDataController>().toggleFavorite(doc.id)),
      if (onEditPages != null) ('Edit Pages', Icons.layers_rounded, onEditPages!),
      if (isPdf && onPrint != null) ('Print', Icons.print_rounded, onPrint!),
      if (isPdf) ('Compress', Icons.compress_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => CompressScreen(initialSourcePath: doc.filePath)))),
      if (isPdf) ('Merge', Icons.merge_type_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => MergeScreen(initialSourcePath: doc.filePath)))),
      if (isPdf) ('Split', Icons.call_split_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => SplitScreen(initialSourcePath: doc.filePath)))),
      if (isPdf) ('Rotate', Icons.rotate_right_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => RotateScreen(initialSourcePath: doc.filePath)))),
      if (isPdf) ('Watermark', Icons.branding_watermark_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => WatermarkScreen(initialSourcePath: doc.filePath)))),
      if (isPdf) ('Password', Icons.lock_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => SecurityScreen(initialSourcePath: doc.filePath)))),
      if (isPdf) ('Signature', Icons.draw_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => FillSignScreen(initialPath: doc.filePath)))),
    ];
    return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: actions.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.4), itemBuilder: (_, i) {
      final a = actions[i];
      return OutlinedButton.icon(onPressed: a.$3, icon: Icon(a.$2), label: Text(a.$1));
    });
  }
}
