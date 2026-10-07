import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/painting.dart';

import '../../seasons/season.dart';
import '../arena_grid.dart';

/// A short spray of snow chunks or water drops at an impact. Kid-safe:
/// soft round bits that arc out, fall, and fade.
class SplashParticles extends ParticleSystemComponent {
  SplashParticles({
    required Vector2 position,
    required Season season,
    required math.Random rng,
    double? depthY,
    int count = 12,
    double power = 1,
  }) : super(
         position: position,
         priority: ArenaGrid.depthOrder(depthY ?? position.y) + 2,
         particle: Particle.generate(
           count: count,
           lifespan: 0.55,
           generator: (i) {
             final angle = -math.pi * (0.1 + 0.8 * rng.nextDouble());
             final speed = (140 + rng.nextDouble() * 200) * power;
             final radius = 2.5 + rng.nextDouble() * 3.5;
             final color = _palette(season)[i % 3];
             return AcceleratedParticle(
               speed: Vector2(math.cos(angle), math.sin(angle)) * speed,
               acceleration: Vector2(0, 900),
               child: _FadingDot(radius: radius, color: color),
             );
           },
         ),
       );

  static List<Color> _palette(Season season) => switch (season) {
    Season.winter => const [
      Color(0xFFFFFFFF),
      Color(0xFFE8F4FF),
      Color(0xFFC9E4FA),
    ],
    Season.summer => const [
      Color(0xFF7EC8FF),
      Color(0xFF4ECDC4),
      Color(0xFFDDF4FF),
    ],
  };
}

class _FadingDot extends Particle {
  _FadingDot({required this.radius, required this.color});

  final double radius;
  final Color color;
  final Paint _paint = Paint();

  @override
  void render(Canvas canvas) {
    final fade = (1 - progress).clamp(0.0, 1.0);
    _paint.color = color.withValues(alpha: fade);
    canvas.drawCircle(Offset.zero, radius * (0.6 + 0.4 * fade), _paint);
  }
}
