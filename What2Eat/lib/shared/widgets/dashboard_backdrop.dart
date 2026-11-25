import 'package:flutter/material.dart';

class DashboardBackdrop extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFD85C).withValues(alpha: .08);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .78, 0)
        ..cubicTo(size.width * .60, 35, size.width * .97, 45, size.width, 125)
        ..lineTo(size.width, 0)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height * .65)
        ..cubicTo(
          size.width * .13,
          size.height * .6,
          size.width * .17,
          size.height * .9,
          size.width * .34,
          size.height,
        )
        ..lineTo(0, size.height)
        ..close(),
      paint..color = const Color(0xFFEEF1E4).withValues(alpha: .6),
    );
  }

  @override
  bool shouldRepaint(covariant DashboardBackdrop oldDelegate) => false;
}
