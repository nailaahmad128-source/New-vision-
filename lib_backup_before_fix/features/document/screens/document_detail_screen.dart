import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/storage/app_data_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/document_item.dart';
import '../../ocr/screens/text_extraction_screen.dart';
import '../../reader/screens/pdf_reader_screen.dart';
import '../../translation/screens/translation_screen.dart';
import '../../translation/services/speech_service.dart';
import '../../tools/screens/pdf_page_editor_screen.dart';

class DocumentDetailScreen extends StatelessWidget {
  final DocumentItem doc;
  const DocumentDetailScreen({super.key, required this.doc});

  Future<void> _rename(BuildContext context, DocumentItem live) async {
    final controller = TextEditingController(
      text: p.basenameWithoutExtension(live.name),
    );
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename document'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Document name',
            hintText: 'Enter a clear name',
          ),
          onSubmitted: (value) => Navigator.pop(ctx, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (!context.mounted || name == null || name.trim().isEmpty) return;
    final updated = await context.read<AppDataController>().renameDocument(
      live.id,
      name.trim(),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(updated == null
            ? 'Could not rename. A file with that name may already exist.'
            : 'Document renamed.'),
      ),
    );
  }

  Future<void> _print(BuildContext context, DocumentItem d) async {
    try {
      final bytes = await File(d.filePath).readAsBytes();
      if (d.type == 'pdf') {
        await Printing.layoutPdf(onLayout: (_) async => bytes);
      } else {
        await Printing.layoutPdf(
          onLayout: (_) async {
            final image = pw.MemoryImage(bytes);
            final document = pw.Document();
            document.addPage(
              pw.Page(
                pageFormat: pw.PdfPageFormat.a4,
                margin: const pw.EdgeInsets.all(24),
                build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
              ),
            );
            return document.save();
          },
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Printing is not available for this document.')),
        );
      }
    }
  }

  Future<void> _listen(BuildContext context, DocumentItem d) async {
    final existing = d.extractedText?.trim() ?? '';
    if (existing.isEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TextExtractionScreen(imagePath: d.filePath, documentId: d.id),
        ),
      );
      return;
    }
    final tts = SpeechService();
    try {
      await tts.speak(existing);
    } finally {
      await tts.dispose();
    }
  }

  Future<void> _duplicate(BuildContext context, DocumentItem d) async {
    final copy = await context.read<AppDataController>().duplicateDocument(d.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(copy == null ? 'Could not duplicate document.' : 'Duplicate saved to Library.')),
    );
  }

  Future<void> _delete(BuildContext context, DocumentItem d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to Recently Deleted?'),
        content: Text('“${d.name}” will remain recoverable in Recently Deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Move to Deleted'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<AppDataController>().deleteDocument(d.id);
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _showMore(BuildContext context, DocumentItem d) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline_rounded),
              title: const Text('Rename'),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_rounded),
              title: const Text('Make a copy'),
              onTap: () => Navigator.pop(ctx, 'duplicate'),
            ),
            ListTile(
              leading: Icon(d.isFavorite ? Icons.star_rounded : Icons.star_border_rounded),
              title: Text(d.isFavorite ? 'Remove favorite' : 'Add to favorites'),
              onTap: () => Navigator.pop(ctx, 'favorite'),
            ),
            ListTile(
              leading: const Icon(Icons.print_rounded),
              title: const Text('Print'),
              onTap: () => Navigator.pop(ctx, 'print'),
            ),
            const Divider(height: 8),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('Move to Recently Deleted'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    final data = context.read<AppDataController>();
    switch (action) {
      case 'rename':
        await _rename(context, d);
        break;
      case 'duplicate':
        await _duplicate(context, d);
        break;
      case 'favorite':
        await data.toggleFavorite(d.id);
        break;
      case 'print':
        await _print(context, d);
        break;
      case 'delete':
        await _delete(context, d);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = context.watch<AppDataController>().documentById(doc.id) ?? doc;
    final data = context.read<AppDataController>();
    final searchable = (live.extractedText ?? '').trim().isNotEmpty;
    final pages = live.pageCount ?? 1;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document details'),
        actions: [
          IconButton(
            tooltip: live.isFavorite ? 'Remove favorite' : 'Add favorite',
            onPressed: () => data.toggleFavorite(live.id),
            icon: Icon(live.isFavorite ? Icons.star_rounded : Icons.star_border_rounded),
          ),
          IconButton(
            tooltip: 'More actions',
            onPressed: () => _showMore(context, live),
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _PreviewCard(doc: live),
          const SizedBox(height: 18),
          Text(
            live.name,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaPill(icon: live.type == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.image_rounded, label: live.type.toUpperCase()),
              _MetaPill(icon: Icons.layers_rounded, label: '$pages page${pages == 1 ? '' : 's'}'),
              _MetaPill(icon: Icons.data_usage_rounded, label: _size(live.sizeBytes)),
              if (searchable) const _MetaPill(icon: Icons.text_snippet_rounded, label: 'OCR searchable'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Modified ${_date(live.modifiedAt)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _open(context, live),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Share.shareXFiles([XFile(live.filePath)]),
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Quick actions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _ActionGrid(
            doc: live,
            onListen: () => _listen(context, live),
            onEditPages: live.type == 'pdf'
                ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => PdfPageEditorScreen(doc: live)))
                : null,
            onExtract: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TextExtractionScreen(imagePath: live.filePath, documentId: live.id))),
            onTranslate: searchable
                ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => TranslationScreen(initialText: live.extractedText!)))
                : null,
            onPrint: () => _print(context, live),
            onDuplicate: () => _duplicate(context, live),
          ),
          if (searchable) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.text_snippet_rounded, color: AppColors.brandPrimary),
                      const SizedBox(width: 8),
                      Text('Searchable text', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 10),
                    Text(
                      live.extractedText!.trim(),
                      maxLines: 6,
                      overflow: TextOverflow.fade,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TextExtractionScreen(imagePath: live.filePath, documentId: live.id))),
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('Open full extracted text'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => _delete(context, live),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Move to Recently Deleted'),
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

  static String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

class _PreviewCard extends StatelessWidget {
  final DocumentItem doc;
  const _PreviewCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exists = doc.thumbnailPath != null && File(doc.thumbnailPath!).existsSync();
    return Container(
      height: 270,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: exists
          ? Image.file(File(doc.thumbnailPath!), fit: BoxFit.contain)
          : Center(
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  doc.type == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                  size: 50,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 5),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  final DocumentItem doc;
  final VoidCallback onListen;
  final VoidCallback? onEditPages;
  final VoidCallback onExtract;
  final VoidCallback? onTranslate;
  final VoidCallback onPrint;
  final VoidCallback onDuplicate;

  const _ActionGrid({
    required this.doc,
    required this.onListen,
    required this.onEditPages,
    required this.onExtract,
    required this.onTranslate,
    required this.onPrint,
    required this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    final actions = <(String, IconData, VoidCallback)>[
      ('Extract Text', Icons.text_fields_rounded, onExtract),
      if (onTranslate != null) ('Translate', Icons.translate_rounded, onTranslate!),
      ('Listen', Icons.volume_up_rounded, onListen),
      if (onEditPages != null) ('Edit Pages', Icons.layers_rounded, onEditPages!),
      ('Print', Icons.print_rounded, onPrint),
      ('Make a Copy', Icons.copy_all_rounded, onDuplicate),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.15,
      ),
      itemBuilder: (_, index) {
        final action = actions[index];
        return OutlinedButton.icon(
          onPressed: action.$3,
          icon: Icon(action.$2, size: 20),
          label: Text(action.$1, maxLines: 1, overflow: TextOverflow.ellipsis),
        );
      },
    );
  }
}
