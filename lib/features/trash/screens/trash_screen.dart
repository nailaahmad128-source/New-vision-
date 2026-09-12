import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/trash_item.dart';

class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppDataController>();
    final items = data.trashItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recently Deleted'),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => _confirmEmptyTrash(context, data),
              child: const Text('Empty'),
            ),
        ],
      ),
      body: SafeArea(
        child: items.isEmpty
            ? const EmptyState(
                icon: Icons.delete_outline_rounded,
                title: 'Nothing here',
                message: 'Files you delete from your Library appear here for 30 days before being permanently removed.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) => _TrashTile(item: items[i], data: data),
              ),
      ),
    );
  }

  void _confirmEmptyTrash(BuildContext context, AppDataController data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Empty Recently Deleted?'),
        content: const Text('All files here will be permanently deleted. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () {
              data.emptyTrash();
              Navigator.pop(ctx);
            },
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }
}

class _TrashTile extends StatelessWidget {
  final TrashItem item;
  final AppDataController data;
  const _TrashTile({required this.item, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = item.purgeAt.difference(DateTime.now());
    return Card(
      child: ListTile(
        leading: Icon(
          item.type == 'image' ? Icons.image_rounded : Icons.picture_as_pdf_rounded,
          color: theme.colorScheme.error,
        ),
        title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${formatBytes(item.sizeBytes)} · ${formatCountdown(remaining)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.restore_rounded),
              tooltip: 'Restore',
              onPressed: () => data.restoreFromTrash(item.id),
            ),
            IconButton(
              icon: Icon(Icons.delete_forever_rounded, color: theme.colorScheme.error),
              tooltip: 'Delete forever',
              onPressed: () => _confirmDeleteForever(context),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteForever(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete forever?'),
        content: Text('"${item.name}" will be permanently deleted. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () {
              data.deleteForever(item.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
