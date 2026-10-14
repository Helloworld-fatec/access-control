import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Faixa listrada preto/amarelo (estilo "atenção") para decorar telas.
class WarningStripe extends StatelessWidget {
  const WarningStripe({super.key, this.height = 14});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _StripePainter()),
    );
  }
}

class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final yellow = Paint()..color = AppColors.yellow;
    final black = Paint()..color = AppColors.black;
    canvas.drawRect(Offset.zero & size, black);

    final w = size.height * 1.5;
    for (double x = -size.height; x < size.width + size.height; x += w * 2) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + size.height, 0)
        ..lineTo(x + size.height + w, 0)
        ..lineTo(x + w, size.height)
        ..close();
      canvas.drawPath(path, yellow);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
