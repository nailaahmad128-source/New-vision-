import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/document_item.dart';
import '../utils/format_utils.dart';

class DocumentTile extends StatelessWidget {
  final DocumentItem doc;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;
  final VoidCallback onRename;

  const DocumentTile({
    super.key,
    required this.doc,
    required this.onTap,
    required this.onDelete,
    required this.onToggleFavorite,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 6,
        ),
        onTap: onTap,

        leading: _Thumb(doc: doc),

        title: Text(
          doc.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall,
        ),

        subtitle: Text(
          [
            formatBytes(doc.sizeBytes),
            if (doc.pageCount != null) '${doc.pageCount} pages',
            formatRelativeDate(doc.modifiedAt),
          ].join(' · '),
          style: theme.textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          tooltip: 'More options',

          onSelected: (value) async {
            switch (value) {
              case 'share':
                await Share.shareXFiles([
                  XFile(doc.filePath),
                ]);
                break;

              case 'favorite':
                onToggleFavorite();
                break;

              case 'rename':
                onRename();
                break;

              case 'delete':
                onDelete();
                break;
            }
          },

          itemBuilder: (context) => [
            const PopupMenuItem<String>(
              value: 'share',
              child: ListTile(
                leading: Icon(Icons.ios_share_rounded),
                title: Text('Share'),
                contentPadding: EdgeInsets.zero,
              ),
            ),

            PopupMenuItem<String>(
              value: 'favorite',
              child: ListTile(
                leading: Icon(
                  Icons.star_rounded,
                  color: Colors.amber,
                ),
                title: Text('Favorite'),
                contentPadding: EdgeInsets.zero,
              ),
            ),

            const PopupMenuItem<String>(
              value: 'rename',
              child: ListTile(
                leading: Icon(Icons.drive_file_rename_outline_rounded),
                title: Text('Rename'),
                contentPadding: EdgeInsets.zero,
              ),
            ),

            const PopupMenuDivider(),

            const PopupMenuItem<String>(
              value: 'delete',
              child: ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                ),
                title: Text('Delete'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),

        // Favorite ہونے پر چھوٹا star نام کے ساتھ نہیں،
        // صرف تین ڈاٹس میں Favorite action موجود ہوگا۔
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final DocumentItem doc;

  const _Thumb({required this.doc});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(12);

    if (doc.thumbnailPath != null &&
        File(doc.thumbnailPath!).existsSync()) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.file(
          File(doc.thumbnailPath!),
          width: 44,
          height: 52,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: 44,
      height: 52,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: radius,
      ),
      child: Icon(
        doc.type == 'image'
            ? Icons.image_rounded
            : Icons.picture_as_pdf_rounded,
        color: theme.colorScheme.primary,
        size: 22,
      ),
    );
  }
}
