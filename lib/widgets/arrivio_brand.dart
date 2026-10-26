import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum BrandLockupSize { compact, large }

class ArrivioBrand extends StatelessWidget {
  const ArrivioBrand({
    super.key,
    this.lockupSize = BrandLockupSize.compact,
    this.centered = false,
  });
  final BrandLockupSize lockupSize;
  final bool centered;
  @override
  Widget build(BuildContext context) {
    final large = lockupSize == BrandLockupSize.large;
    final markSize = large ? 64.0 : 34.0;
    final wordSize = large ? 29.0 : 19.0;
    final lockup = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ArrivioMark(size: markSize),
        SizedBox(width: large ? 14 : 10),
        RichText(
          text: TextSpan(
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: wordSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
            ),
            children: const [
              TextSpan(text: 'Arrivio'),
              TextSpan(
                text: 'AI',
                style: TextStyle(color: AppTheme.blue),
              ),
            ],
          ),
        ),
      ],
    );
    return Semantics(
      label: 'ArrivioAI',
      image: true,
      child: centered ? Center(child: lockup) : lockup,
    );
  }
}

class ArrivioMark extends StatelessWidget {
  const ArrivioMark({super.key, required this.size});
  final double size;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _ArrivioMarkPainter());
}

class _ArrivioMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 64;
    canvas.scale(scale);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 64, 64),
        const Radius.circular(18),
      ),
      Paint()..color = AppTheme.navy,
    );
    final route = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(15, 43)
      ..cubicTo(22, 43, 23, 21, 35, 21)
      ..cubicTo(42, 21, 43, 34, 49, 34);
    canvas.drawPath(path, route);
    canvas.drawCircle(
      const Offset(49, 34),
      7,
      Paint()..color = const Color(0xFF5BC3F6),
    );
    canvas.drawCircle(
      const Offset(49, 34),
      2.5,
      Paint()..color = AppTheme.navy,
    );
    canvas.drawCircle(
      const Offset(15, 43),
      4,
      Paint()..color = const Color(0xFFB9E8FF),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
