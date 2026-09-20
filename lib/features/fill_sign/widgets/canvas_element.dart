import 'package:flutter/material.dart';

/// A single signature/text element placed on a PDF page.
///
/// Supports:
/// - tap to select
/// - single-finger drag to move
/// - bottom-right handle to resize
/// - delete button
///
/// While the element is being manipulated, the parent InteractiveViewer is
/// temporarily locked so the element receives the gesture reliably.
class CanvasElement extends StatefulWidget {
  final Widget child;
  final Offset position;
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
  Offset? _resizeStartFocal;
  Size? _resizeStartSize;

  static const double _minSize = 24.0;
  static const double _maxSize = 2000.0;

  void _startMove(DragStartDetails details) {
    widget.onInteractionLock(true);
  }

  void _updateMove(DragUpdateDetails details) {
    // Apply only the current gesture delta. This keeps movement stable
    // even when the parent rebuilds the element during dragging.
    widget.onMove(widget.position + details.delta);
  }

  void _endMove() {
    widget.onInteractionLock(false);
  }

  void _startResize(DragStartDetails details) {
    _resizeStartFocal = details.globalPosition;
    _resizeStartSize = widget.size;
    widget.onInteractionLock(true);
  }

  void _updateResize(DragUpdateDetails details) {
    final startFocal = _resizeStartFocal;
    final startSize = _resizeStartSize;

    if (startFocal == null || startSize == null) return;

    final dx = details.globalPosition.dx - startFocal.dx;
    final dy = details.globalPosition.dy - startFocal.dy;

    widget.onResize(
      Size(
        (startSize.width + dx).clamp(_minSize, _maxSize),
        (startSize.height + dy).clamp(_minSize, _maxSize),
      ),
    );
  }

  void _endResize() {
    _resizeStartFocal = null;
    _resizeStartSize = null;
    widget.onInteractionLock(false);
  }

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
        onPanStart: _startMove,
        onPanUpdate: _updateMove,
        onPanEnd: (_) => _endMove(),
        onPanCancel: _endMove,
        child: Container(
          decoration: BoxDecoration(
            border: widget.selected
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: widget.child),

              if (widget.selected) ...[
                // Delete button.
                Positioned(
                  top: -14,
                  right: -14,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onDelete,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                  ),
                ),

                // Resize handle.
                Positioned(
                  bottom: -14,
                  right: -14,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: _startResize,
                    onPanUpdate: _updateResize,
                    onPanEnd: (_) => _endResize(),
                    onPanCancel: _endResize,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.open_in_full_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
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
