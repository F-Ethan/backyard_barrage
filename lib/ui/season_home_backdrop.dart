import 'package:flutter/material.dart';

import '../seasons/season.dart';

/// Full-bleed home yard. Winter is frost and snow. Summer is sun and grass.
/// Drawn in Flutter so the seasonal look does not need new sprites.
class SeasonHomeBackdrop extends StatelessWidget {
  const SeasonHomeBackdrop({super.key, required this.season});

  final Season season;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _YardPainter(season),
      child: const SizedBox.expand(),
    );
  }
}

class _YardPainter extends CustomPainter {
  _YardPainter(this.season);

  final Season season;

  @override
  void paint(Canvas canvas, Size size) {
    if (season == Season.summer) {
      _paintSummer(canvas, size);
    } else {
      _paintWinter(canvas, size);
    }
  }

  void _paintWinter(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7EB6E8), Color(0xFFD7ECFA), Color(0xFFF4F8FC)],
          stops: [0, 0.62, 1],
        ).createShader(rect),
    );

    _hill(canvas, size, top: 0.58, color: const Color(0xFFE7F1F8), lift: 0.06);
    _hill(canvas, size, top: 0.70, color: const Color(0xFFF4F8FC), lift: 0.045);
    _hill(canvas, size, top: 0.84, color: const Color(0xFFFFFFFF), lift: 0.03);

    const flakes = <(double, double, double)>[
      (0.08, 0.12, 3.2),
      (0.16, 0.28, 2.1),
      (0.22, 0.08, 1.6),
      (0.31, 0.22, 2.6),
      (0.40, 0.14, 1.8),
      (0.48, 0.32, 2.4),
      (0.57, 0.10, 3.0),
      (0.66, 0.24, 1.7),
      (0.74, 0.16, 2.8),
      (0.83, 0.30, 2.0),
      (0.90, 0.12, 1.5),
      (0.94, 0.36, 2.5),
      (0.12, 0.46, 1.8),
      (0.28, 0.42, 1.4),
      (0.62, 0.44, 2.2),
      (0.86, 0.48, 1.6),
    ];
    final flake = Paint()..color = const Color(0xFFFFFFFF);
    final arm = Paint()
      ..color = const Color(0xFFEFF6FC)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (final (x, y, r) in flakes) {
      final center = Offset(size.width * x, size.height * y);
      canvas.drawCircle(center, r, flake);
      canvas.drawLine(
        center + Offset(-r * 1.8, 0),
        center + Offset(r * 1.8, 0),
        arm,
      );
      canvas.drawLine(
        center + Offset(0, -r * 1.8),
        center + Offset(0, r * 1.8),
        arm,
      );
    }
  }

  void _paintSummer(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF87CEEB), Color(0xFFD7F3C4), Color(0xFF6BBF59)],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );

    final sun = Offset(size.width * 0.84, size.height * 0.16);
    canvas.drawCircle(
      sun,
      size.shortestSide * 0.11,
      Paint()..color = const Color(0x55FFE66D),
    );
    canvas.drawCircle(
      sun,
      size.shortestSide * 0.055,
      Paint()..color = const Color(0xFFFFE66D),
    );

    _cloud(canvas, Offset(size.width * 0.18, size.height * 0.16), 1);
    _cloud(canvas, Offset(size.width * 0.42, size.height * 0.10), 0.72);

    _hill(canvas, size, top: 0.62, color: const Color(0xFF5EAE4C), lift: 0.05);
    _hill(canvas, size, top: 0.74, color: const Color(0xFF6BBF59), lift: 0.04);

    final tuft = Paint()
      ..color = const Color(0xFF3E8E38)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const tufts = <(double, double)>[
      (0.06, 0.78),
      (0.14, 0.86),
      (0.24, 0.80),
      (0.70, 0.82),
      (0.80, 0.90),
      (0.92, 0.78),
    ];
    for (final (x, y) in tufts) {
      final base = Offset(size.width * x, size.height * y);
      canvas.drawLine(base, base + const Offset(-4, -12), tuft);
      canvas.drawLine(base, base + const Offset(0, -14), tuft);
      canvas.drawLine(base, base + const Offset(4, -11), tuft);
    }

    _flower(
      canvas,
      Offset(size.width * 0.10, size.height * 0.72),
      const Color(0xFFFF6B9D),
    );
    _flower(
      canvas,
      Offset(size.width * 0.30, size.height * 0.88),
      const Color(0xFFFFE66D),
    );
    _flower(
      canvas,
      Offset(size.width * 0.88, size.height * 0.70),
      const Color(0xFFFF6B9D),
    );
    _flower(
      canvas,
      Offset(size.width * 0.76, size.height * 0.92),
      const Color(0xFFFFFFFF),
    );
  }

  void _hill(
    Canvas canvas,
    Size size, {
    required double top,
    required Color color,
    required double lift,
  }) {
    final path = Path()
      ..moveTo(0, size.height * (top + lift))
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * (top - lift),
        size.width * 0.5,
        size.height * top,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * (top + lift * 1.4),
        size.width,
        size.height * (top - lift * 0.2),
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _cloud(Canvas canvas, Offset origin, double scale) {
    final paint = Paint()..color = const Color(0xEEFFFFFF);
    canvas.drawCircle(origin, 18 * scale, paint);
    canvas.drawCircle(
      origin + Offset(16 * scale, 4 * scale),
      14 * scale,
      paint,
    );
    canvas.drawCircle(
      origin + Offset(-16 * scale, 6 * scale),
      12 * scale,
      paint,
    );
  }

  void _flower(Canvas canvas, Offset origin, Color petal) {
    final stem = Paint()
      ..color = const Color(0xFF3E8E38)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(origin, origin + const Offset(0, 16), stem);
    final bloom = Paint()..color = petal;
    canvas.drawCircle(origin + const Offset(-4, -2), 4, bloom);
    canvas.drawCircle(origin + const Offset(4, -2), 4, bloom);
    canvas.drawCircle(origin + const Offset(0, -6), 4, bloom);
    canvas.drawCircle(origin + const Offset(0, 1), 4, bloom);
    canvas.drawCircle(origin, 2.4, Paint()..color = const Color(0xFFFFC857));
  }

  @override
  bool shouldRepaint(covariant _YardPainter oldDelegate) =>
      oldDelegate.season != season;
}
