import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;
  final bool extendBehind;

  const AppBackground({super.key, required this.child, this.extendBehind = false});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: dark ? const Color(0xFF101A17) : const Color(0xFFF7F4E9)),
        CustomPaint(painter: _DoodlePainter(dark: dark)),
        if (extendBehind) child else SafeArea(child: child),
      ],
    );
  }
}

class _DoodlePainter extends CustomPainter {
  final bool dark;
  _DoodlePainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..color = (dark ? Colors.white : const Color(0xFF557268)).withValues(alpha: .075);

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = (dark ? Colors.white : const Color(0xFF557268)).withValues(alpha: .035);

    const gap = 105.0;
    for (double y = 35; y < size.height + gap; y += gap) {
      for (double x = 22; x < size.width + gap; x += gap) {
        final i = ((x / gap).round() + (y / gap).round()) % 6;
        final o = Offset(x, y);
        switch (i) {
          case 0:
            canvas.drawRect(Rect.fromCenter(center: o, width: 24, height: 30), paint);
            canvas.drawLine(o + const Offset(-7, -5), o + const Offset(7, -5), paint);
            canvas.drawLine(o + const Offset(-7, 2), o + const Offset(5, 2), paint);
            break;
          case 1:
            canvas.drawCircle(o, 14, paint);
            canvas.drawLine(o + const Offset(-9, 0), o + const Offset(9, 0), paint);
            canvas.drawLine(o + const Offset(0, -9), o + const Offset(0, 9), paint);
            break;
          case 2:
            final path = Path()
              ..moveTo(x - 12, y + 8)
              ..lineTo(x, y - 12)
              ..lineTo(x + 12, y + 8)
              ..close();
            canvas.drawPath(path, paint);
            canvas.drawCircle(o, 3, fill);
            break;
          case 3:
            canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: 34, height: 22), const Radius.circular(5)), paint);
            canvas.drawCircle(o, 5, paint);
            break;
          case 4:
            canvas.drawLine(o + const Offset(-14, 10), o + const Offset(0, -10), paint);
            canvas.drawLine(o + const Offset(0, -10), o + const Offset(14, 10), paint);
            canvas.drawCircle(o, 3, paint);
            break;
          default:
            canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: 26, height: 30), const Radius.circular(7)), paint);
            canvas.drawLine(o + const Offset(-7, -7), o + const Offset(7, -7), paint);
            canvas.drawLine(o + const Offset(-7, 0), o + const Offset(7, 0), paint);
            canvas.drawLine(o + const Offset(-7, 7), o + const Offset(3, 7), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter oldDelegate) => oldDelegate.dark != dark;
}
