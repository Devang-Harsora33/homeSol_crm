import 'package:flutter/material.dart';

class LocationRadiusPainter extends CustomPainter {
  final double selectedRange;
  final bool isDark;

  LocationRadiusPainter({required this.selectedRange, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width * 0.3).clamp(20.0, 50.0);

    final radiusPaint = Paint()
      ..color = const Color(0xFFdbc163).withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, radiusPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFFdbc163)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, borderPaint);

    final centerPaint = Paint()
      ..color = const Color(0xFFdbc163)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, centerPaint);

    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is LocationRadiusPainter &&
        (oldDelegate.selectedRange != selectedRange ||
            oldDelegate.isDark != isDark);
  }
}
