import 'package:flutter/material.dart';

/// A single signature/text element positioned on top of a PDF page.
///
/// The element owns its drag/resize gesture state so parent rebuilds do not
/// change the reference point of an active gesture.
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
  static const double _minSize = 24.0;
  static const double _maxSize = 2000.0;

  Offset? _dragStartPosition;
  Offset _dragAccumulated = Offset.zero;

  Size? _resizeStartSize;
  Offset _resizeAccumulated = Offset.zero;

  void _startMove(DragStartDetails details) {
    _dragStartPosition = widget.position;
    _dragAccumulated = Offset.zero;
    widget.onInteractionLock(true);
  }

  void _updateMove(DragUpdateDetails details) {
    final start = _dragStartPosition;
    if (start == null) return;

    _dragAccumulated += details.delta;

    widget.onMove(
      start + _dragAccumulated,
    );
  }

  void _endMove() {
    _dragStartPosition = null;
    _dragAccumulated = Offset.zero;
    widget.onInteractionLock(false);
  }

  void _startResize(DragStartDetails details) {
    _resizeStartSize = widget.size;
    _resizeAccumulated = Offset.zero;
    widget.onInteractionLock(true);
  }

  void _updateResize(DragUpdateDetails details) {
    final start = _resizeStartSize;
    if (start == null) return;

    _resizeAccumulated += details.delta;

    final newSize = Size(
      (start.width + _resizeAccumulated.dx)
          .clamp(_minSize, _maxSize)
          .toDouble(),
      (start.height + _resizeAccumulated.dy)
          .clamp(_minSize, _maxSize)
          .toDouble(),
    );

    widget.onResize(newSize);
  }

  void _endResize() {
    _resizeStartSize = null;
    _resizeAccumulated = Offset.zero;
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
                Positioned(
                  top: -14,
                  right: -14,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onDelete,
                    child: Container(
                      width: 28,
                      height: 28,
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
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.open_in_full_rounded,
                        color: Colors.white,
                        size: 15,
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
