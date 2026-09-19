import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import '../../../core/services/ads_service.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../core/utils/format_utils.dart';
import '../../../models/document_item.dart';

/// Shown right after a tool finishes. Kept as its own screen (rather than a
/// dialog) so the user has a clean, unhurried moment to open/share/save —
/// and so an interstitial, if one is due, has a natural, non-disruptive
/// place to appear (never mid-processing).
class ToolResultScreen extends StatefulWidget {
  final List<DocumentItem> results;
  final String successTitle;

  const ToolResultScreen({
    super.key,
    required this.results,
    this.successTitle = 'Done!',
  });

  @override
  State<ToolResultScreen> createState() => _ToolResultScreenState();
}

class _ToolResultScreenState extends State<ToolResultScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdsService>().maybeShowInterstitialAfterToolAction();
    });
  }

  Future<void> _saveToFiles(DocumentItem doc) async {
    try {
      final file = File(doc.filePath);
      if (!await file.exists()) return;

      final bytes = await file.readAsBytes();

      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Save file',
        fileName: doc.name,
        bytes: bytes,
      );

      if (!mounted || savedPath == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File saved successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save file: $e')),
      );
    }
  }

  Future<void> _saveToLibrary(DocumentItem doc) async {
    try {
      final data = context.read<AppDataController>();
      final saved = await data.saveToolResultToLibrary(doc);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved == null
                ? 'File not found'
                : 'Saved to Library',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save to Library: $e')),
      );
    }
  }

  Future<void> _rename(DocumentItem doc) async {
    final controller = TextEditingController(text: doc.name);

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename file'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'File name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (!mounted || name == null || name.isEmpty || name == doc.name) {
      return;
    }

    try {
      final data = context.read<AppDataController>();
      await data.renameToolResult(doc, name);

      setState(() {
        final index = widget.results.indexOf(doc);
        if (index >= 0) {
          widget.results[index] = doc.copyWith(
            name: name,
            filePath: p.join(
              p.dirname(doc.filePath),
              name,
            ),
          );
        }
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File renamed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not rename file: $e')),
      );
    }
  }

  Future<void> _delete(DocumentItem doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text('Delete "${doc.name}" from this tool result?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await context.read<AppDataController>().deleteToolResult(doc);

    setState(() {
      widget.results.remove(doc);
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('File deleted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Result'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, color: theme.colorScheme.primary, size: 44),
              ),
              const SizedBox(height: 20),
              Text(widget.successTitle, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                widget.results.length == 1
                    ? 'Ready to open or share'
                    : '${widget.results.length} files ready to open or share',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: widget.results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final doc = widget.results[i];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          switch (doc.type) {
                            'image' => Icons.image_rounded,
                            'docx' => Icons.description_rounded,
                            'xlsx' => Icons.table_chart_rounded,
                            'pptx' => Icons.slideshow_rounded,
                            _ => Icons.picture_as_pdf_rounded,
                          },
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(doc.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(formatBytes(doc.sizeBytes)),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded),
                          onSelected: (value) async {
                            switch (value) {
                              case 'files':
                                await _saveToFiles(doc);
                                break;
                              case 'library':
                                await _saveToLibrary(doc);
                                break;
                              case 'rename':
                                await _rename(doc);
                                break;
                              case 'share':
                                await Share.shareXFiles([
                                  XFile(doc.filePath),
                                ]);
                                break;
                              case 'delete':
                                await _delete(doc);
                                break;
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'files',
                              child: ListTile(
                                leading: Icon(Icons.folder_open_rounded),
                                title: Text('Save to Files'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'library',
                              child: ListTile(
                                leading: Icon(Icons.library_books_rounded),
                                title: Text('Save to Library'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'rename',
                              child: ListTile(
                                leading: Icon(Icons.edit_rounded),
                                title: Text('Rename'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'share',
                              child: ListTile(
                                leading: Icon(Icons.share_rounded),
                                title: Text('Share'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete_rounded),
                                title: Text('Delete'),
                              ),
                            ),
                          ],
                        ),
                        onTap: () => OpenFilex.open(doc.filePath),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
