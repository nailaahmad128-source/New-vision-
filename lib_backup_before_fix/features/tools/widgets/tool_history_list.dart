import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/tools_catalog.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/document_item.dart';

/// Recent activity for one tool.
/// Tool results live in the tool-results folder, not in Library.
class ToolHistorySection extends StatelessWidget {
  final ToolId toolId;

  const ToolHistorySection({
    super.key,
    required this.toolId,
  });

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppDataController>();
    final entries = data.historyForTool(toolId.name);
    final theme = Theme.of(context);

    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: EmptyState(
          icon: Icons.history_rounded,
          title: 'No history yet',
          message: 'Your activity with this tool will appear here.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent', style: theme.textTheme.titleMedium),
            TextButton(
              onPressed: () => data.clearHistoryForTool(toolId.name),
              child: const Text('Clear'),
            ),
          ],
        ),
        ...entries.map((e) {
          final resultPath = e.resultFilePath;
          final resultName = e.resultFileName ?? e.title;
          final resultSize = e.resultSizeBytes;
          final hasFileResult =
              resultPath != null && resultPath.isNotEmpty;
          final hasNoteOnly =
              !hasFileResult && e.note != null && e.note!.isNotEmpty;

          return Card(
            child: ListTile(
              leading: Icon(
                e.success
                    ? Icons.check_circle_rounded
                    : Icons.error_rounded,
                color: e.success
                    ? Colors.green
                    : theme.colorScheme.error,
              ),
              title: Text(
                resultName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                hasNoteOnly
                    ? '${e.note} · ${formatRelativeDate(e.createdAt)}'
                    : hasFileResult
                        ? '${resultSize != null ? formatBytes(resultSize) : ''} · ${formatRelativeDate(e.createdAt)}'
                        : formatRelativeDate(e.createdAt),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: hasFileResult
                  ? PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded),
                      onSelected: (value) async {
                        final file = File(resultPath);
                        if (!await file.exists()) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('File not found')),
                            );
                          }
                          return;
                        }

                        final doc = DocumentItem(
                          id: e.id,
                          name: resultName,
                          filePath: resultPath,
                          sizeBytes: resultSize ?? await file.length(),
                          createdAt: e.createdAt,
                          modifiedAt: e.createdAt,
                          type: resultName.toLowerCase().endsWith('.pdf')
                              ? 'pdf'
                              : 'image',
                          sourceToolId: toolId.name,
                        );

                        try {
                          switch (value) {
                            case 'files':
                              final bytes = await file.readAsBytes();
                              final savedPath = await FilePicker.saveFile(
                                dialogTitle: 'Save file',
                                fileName: resultName,
                                bytes: bytes,
                              );
                              if (savedPath != null && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('File saved successfully'),
                                  ),
                                );
                              }
                              break;

                            case 'library':
                              final saved =
                                  await data.saveToolResultToLibrary(doc);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      saved == null
                                          ? 'File not found'
                                          : 'Saved to Library',
                                    ),
                                  ),
                                );
                              }
                              break;

                            case 'rename':
                              final controller =
                                  TextEditingController(text: resultName);

                              final newName = await showDialog<String>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
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
                                      onPressed: () =>
                                          Navigator.pop(dialogContext),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () {
                                        final value =
                                            controller.text.trim();
                                        if (value.isNotEmpty) {
                                          Navigator.pop(
                                            dialogContext,
                                            value,
                                          );
                                        }
                                      },
                                      child: const Text('Rename'),
                                    ),
                                  ],
                                ),
                              );

                              controller.dispose();

                              if (newName == null ||
                                  newName.isEmpty ||
                                  newName == resultName) {
                                break;
                              }

                              await data.renameToolResult(doc, newName);

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('File renamed'),
                                  ),
                                );
                              }
                              break;

                            case 'share':
                              await Share.shareXFiles([
                                XFile(resultPath),
                              ]);
                              break;

                            case 'delete':
                              final confirmed =
                                  await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Delete file?'),
                                  content: Text(
                                    'Delete "$resultName"?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(
                                            dialogContext,
                                            false,
                                          ),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(
                                            dialogContext,
                                            true,
                                          ),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                await data.deleteToolResult(doc);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('File deleted'),
                                    ),
                                  );
                                }
                              }
                              break;
                          }
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Operation failed: $error'),
                              ),
                            );
                          }
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
                    )
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => data.removeHistoryEntry(e.id),
                      tooltip: 'Remove from history',
                    ),
              onTap: hasFileResult
                  ? () => OpenFilex.open(resultPath)
                  : hasNoteOnly
                      ? () async {
                          await Clipboard.setData(
                            ClipboardData(text: e.note!),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied to clipboard'),
                              ),
                            );
                          }
                        }
                      : null,
            ),
          );
        }),
      ],
    );
  }
}

/// Full-screen history page for tools whose main screen is a
/// camera/canvas/full-bleed interface.
class ToolHistoryScreen extends StatelessWidget {
  final ToolId toolId;
  final String title;

  const ToolHistoryScreen({
    super.key,
    required this.toolId,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ToolHistorySection(toolId: toolId),
          ],
        ),
      ),
    );
  }
}
