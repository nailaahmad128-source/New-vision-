import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Horizontal reorderable strip of scanned pages for Smart Scanner's batch
/// mode. Tap a thumbnail to select it, drag to reorder, or use its menu to
/// adjust corners, rotate, duplicate, or delete that page. A trailing tile
/// adds another page via camera or gallery.
class PageThumbnailStrip extends StatelessWidget {
  final List<Uint8List> pages;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<int> onDelete;
  final ValueChanged<int> onDuplicate;
  final ValueChanged<int> onAdjustCrop;
  final ValueChanged<int> onRotate;
  final VoidCallback onAddPressed;

  const PageThumbnailStrip({
    super.key,
    required this.pages,
    required this.selectedIndex,
    required this.onSelect,
    required this.onReorder,
    required this.onDelete,
    required this.onDuplicate,
    required this.onAdjustCrop,
    required this.onRotate,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        itemCount: pages.length + 1,
        onReorder: (oldIndex, newIndex) {
          if (oldIndex >= pages.length) return; // the trailing add-tile can't be dragged
          if (newIndex > pages.length) newIndex = pages.length;
          onReorder(oldIndex, newIndex);
        },
        itemBuilder: (context, index) {
          if (index == pages.length) {
            return Padding(
              key: const ValueKey('page-strip-add-tile'),
              padding: const EdgeInsets.only(right: 4),
              child: _AddTile(onTap: onAddPressed),
            );
          }
          final selected = index == selectedIndex;
          return ReorderableDragStartListener(
            key: ValueKey('page-strip-$index'),
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => onSelect(index),
                child: _PageThumb(
                  bytes: pages[index],
                  pageNumber: index + 1,
                  selected: selected,
                  onAdjustCrop: () => onAdjustCrop(index),
                  onRotate: () => onRotate(index),
                  onDuplicate: () => onDuplicate(index),
                  onDelete: pages.length > 1 ? () => onDelete(index) : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PageThumb extends StatelessWidget {
  final Uint8List bytes;
  final int pageNumber;
  final bool selected;
  final VoidCallback onAdjustCrop;
  final VoidCallback onRotate;
  final VoidCallback onDuplicate;
  final VoidCallback? onDelete;

  const _PageThumb({
    required this.bytes,
    required this.pageNumber,
    required this.selected,
    required this.onAdjustCrop,
    required this.onRotate,
    required this.onDuplicate,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 84,
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.brandPrimary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: selected ? 2.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.memory(bytes, fit: BoxFit.cover),
        ),
        Positioned(
          left: 6,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: .55), borderRadius: BorderRadius.circular(8)),
            child: Text('$pageNumber', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ),
        Positioned(
          right: 2,
          top: 2,
          child: Material(
            color: Colors.black.withValues(alpha: .45),
            shape: const CircleBorder(),
            child: PopupMenuButton<String>(
              tooltip: 'Page options',
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 16),
              onSelected: (value) {
                switch (value) {
                  case 'crop':
                    onAdjustCrop();
                  case 'rotate':
                    onRotate();
                  case 'duplicate':
                    onDuplicate();
                  case 'delete':
                    onDelete?.call();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'crop', child: Text('Adjust corners')),
                const PopupMenuItem(value: 'rotate', child: Text('Rotate')),
                const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                if (onDelete != null) const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 84,
        height: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          color: AppColors.brandPrimary.withValues(alpha: .08),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: AppColors.brandPrimary, size: 26),
              SizedBox(height: 2),
              Text('Add', style: TextStyle(color: AppColors.brandPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
