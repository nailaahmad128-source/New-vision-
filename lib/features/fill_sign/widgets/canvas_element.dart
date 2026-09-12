import 'package:flutter/material.dart';

/// A single element (signature image or text) positioned on top of a PDF
/// page. Supports drag-to-move and drag-the-corner-to-resize. While the
/// user is actively touching this element, [onInteractionLock] is called
/// so the parent InteractiveViewer can disable its own pan/scale — this is
/// what lets normal two-finger pinch zoom coexist with single-finger
/// element dragging without either one "stealing" the other's gesture.
class CanvasElement extends StatefulWidget {
  final Widget child;
  final Offset position; // top-left, in local (unscaled) page pixels
  final Size size;
  final bool selected;
  final ValueChanged<Offset> onMove;
  final ValueChanged<Size> onResize;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<bool> onInteractionLock;

  const CanvasElement({
    super.key,
    required this.child,
    required this.position,
    required this.size,
    required this.selected,
    required this.onMove,
    required this.onResize,
    required this.onTap,
    required this.onDelete,
    required this.onInteractionLock,
  });

  @override
  State<CanvasElement> createState() => _CanvasElementState();
}

class _CanvasElementState extends State<CanvasElement> {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx,
      top: widget.position.dy,
      width: widget.size.width,
      height: widget.size.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onPanStart: (_) => widget.onInteractionLock(true),
        onPanUpdate: (details) => widget.onMove(widget.position + details.delta),
        onPanEnd: (_) => widget.onInteractionLock(false),
        onPanCancel: () => widget.onInteractionLock(false),
        child: Container(
          decoration: BoxDecoration(
            border: widget.selected
                ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: widget.child),
              if (widget.selected) ...[
                Positioned(
                  top: -14, right: -14,
                  child: GestureDetector(
                    onTap: widget.onDelete,
                    child: Container(
                      width: 26, height: 26,
                      decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -14, right: -14,
                  child: GestureDetector(
                    onPanStart: (_) => widget.onInteractionLock(true),
                    onPanUpdate: (details) {
                      final newSize = Size(
                        (widget.size.width + details.delta.dx).clamp(24, 2000),
                        (widget.size.height + details.delta.dy).clamp(24, 2000),
                      );
                      widget.onResize(newSize);
                    },
                    onPanEnd: (_) => widget.onInteractionLock(false),
                    onPanCancel: () => widget.onInteractionLock(false),
                    child: Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.open_in_full_rounded, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
