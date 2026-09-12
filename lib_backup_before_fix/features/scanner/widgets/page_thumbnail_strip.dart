import 'dart:typed_data';
import 'package:flutter/material.dart';

class PageThumbnailStrip extends StatelessWidget {
  final List<Uint8List> pages;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final void Function(int oldIndex, int newIndex) onMove;
  final void Function(int index) onDelete;
  final void Function(int index) onDuplicate;
  final Future<void> Function(int index) onAdjustCorners;
  final Future<void> Function(int index) onRotate;

  const PageThumbnailStrip({super.key, required this.pages, required this.selectedIndex, required this.onSelect, required this.onMove, required this.onDelete, required this.onDuplicate, required this.onAdjustCorners, required this.onRotate});

  @override
  Widget build(BuildContext context) {
    if (pages.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 108,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        itemCount: pages.length,
        buildDefaultDragHandles: false,
        onReorder: onMove,
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return ReorderableDelayedDragStartListener(
            key: ValueKey('scan-page-$index-${pages[index].length}'),
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onSelect(index),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 72,
                      height: 94,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor, width: selected ? 2.5 : 1),
                      ),
                      child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(pages[index], fit: BoxFit.cover)),
                    ),
                    Positioned(left: 6, top: 6, child: Container(width: 22, height: 22, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.black.withValues(alpha: .65), shape: BoxShape.circle), child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)))),
                    Positioned(right: -6, top: -8, child: Material(color: Theme.of(context).colorScheme.surface, shape: const CircleBorder(), elevation: 2, child: PopupMenuButton<String>(padding: EdgeInsets.zero, iconSize: 18, icon: const Icon(Icons.more_horiz_rounded), onSelected: (value) async { switch (value) { case 'adjust': await onAdjustCorners(index); case 'rotate': await onRotate(index); case 'duplicate': onDuplicate(index); case 'delete': onDelete(index); } }, itemBuilder: (_) => const [PopupMenuItem(value: 'adjust', child: Text('Adjust corners')), PopupMenuItem(value: 'rotate', child: Text('Rotate 90°')), PopupMenuItem(value: 'duplicate', child: Text('Duplicate')), PopupMenuItem(value: 'delete', child: Text('Delete'))]))),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
