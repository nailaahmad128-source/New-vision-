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
        child: SizedBox(
          width: 44,
          height: 52,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(doc.thumbnailPath!),
                fit: BoxFit.cover,
              ),
              _StatusBadges(doc: doc),
            ],
          ),
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Icon(
              switch (doc.type) {
                'image' => Icons.image_rounded,
                'docx' => Icons.description_rounded,
                'xlsx' => Icons.table_chart_rounded,
                'pptx' => Icons.slideshow_rounded,
                _ => Icons.picture_as_pdf_rounded,
              },
              color: theme.colorScheme.primary,
              size: 22,
            ),
          ),
          _StatusBadges(doc: doc),
        ],
      ),
    );
  }
}

/// Small favorite/OCR indicators drawn over a thumbnail so a document's
/// status is visible at a glance in the list, not only inside its menu.
class _StatusBadges extends StatelessWidget {
  final DocumentItem doc;
  const _StatusBadges({required this.doc});

  @override
  Widget build(BuildContext context) {
    if (!doc.isFavorite && !doc.isSearchable) return const SizedBox.shrink();
    return Positioned(
      top: 2,
      right: 2,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (doc.isSearchable)
            const Icon(Icons.text_fields_rounded, size: 11, color: Colors.white, shadows: [Shadow(blurRadius: 2, color: Colors.black54)]),
          if (doc.isFavorite) ...[
            if (doc.isSearchable) const SizedBox(width: 2),
            const Icon(Icons.star_rounded, size: 13, color: Colors.amber, shadows: [Shadow(blurRadius: 2, color: Colors.black54)]),
          ],
        ],
      ),
    );
  }
}
