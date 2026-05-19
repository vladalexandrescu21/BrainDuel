import 'dart:math';
import 'package:flutter/material.dart';

/// Draws a field of small static stars/dots over the background.
/// Deterministic positions so no random repaints.
class StarBackground extends StatelessWidget {
  final Widget child;

  const StarBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _StarsPainter(),
            ),
          ),
        ),
      ],
    );
  }
}

class _StarsPainter extends CustomPainter {
  // Deterministic star positions as fractions of width/height
  static const List<(double, double, double)> _stars = [
    (0.05, 0.08, 1.4),
    (0.18, 0.03, 1.0),
    (0.32, 0.11, 1.8),
    (0.47, 0.05, 1.2),
    (0.63, 0.09, 1.6),
    (0.78, 0.02, 1.0),
    (0.91, 0.07, 1.4),
    (0.12, 0.18, 1.2),
    (0.55, 0.22, 1.8),
    (0.84, 0.16, 1.0),
    (0.03, 0.35, 1.4),
    (0.27, 0.42, 1.2),
    (0.72, 0.38, 1.6),
    (0.95, 0.30, 1.0),
    (0.10, 0.55, 1.8),
    (0.43, 0.60, 1.2),
    (0.66, 0.52, 1.0),
    (0.88, 0.48, 1.4),
    (0.20, 0.70, 1.6),
    (0.51, 0.76, 1.0),
    (0.77, 0.68, 1.2),
    (0.07, 0.82, 1.4),
    (0.35, 0.88, 1.8),
    (0.60, 0.85, 1.0),
    (0.92, 0.78, 1.2),
    (0.15, 0.95, 1.4),
    (0.70, 0.92, 1.6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.08);
    final brightPaint = Paint()..color = Colors.white.withOpacity(0.14);

    for (final (fx, fy, r) in _stars) {
      final x = fx * size.width;
      final y = fy * size.height;
      canvas.drawCircle(Offset(x, y), r, r > 1.5 ? brightPaint : paint);
    }
  }

  @override
  bool shouldRepaint(_StarsPainter oldDelegate) => false;
}
