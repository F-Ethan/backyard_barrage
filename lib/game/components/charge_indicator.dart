import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../arena_grid.dart';

/// Aim preview near the throwing kid: charge glow at the hand, a dotted
/// line on the yard floor along the swept track, and a landing mark where
/// the ball comes down. When the line will hit a rival, the line stops at
/// them and their feet get a lock ring. The power bar lives in the
/// screen-space HUD.
class ChargeIndicator extends PositionComponent {
  ChargeIndicator({Sprite? glowSprite})
    : _glowSprite = glowSprite,
      super(priority: 2000);

  final Sprite? _glowSprite;
  double charge = 0;
  bool visibleCharge = false;
  Vector2 aimDir = Vector2(1, -0.5);
  Vector2 anchorWorld = Vector2.zero();

  /// Body-height start and end of the ground track. The floor marks draw
  /// [ArenaGrid.bodyLift] below these, where feet stand.
  Vector2? trackStart;
  Vector2? trackEnd;

  /// Hit center of the rival this release would hit, if any.
  Vector2? target;

  static const _ink = Color(0xFF1A2332);
  static const _charge = Color(0xFFFFE66D);
  static const _cream = Color(0xFFFFF8F0);

  @override
  void render(Canvas canvas) {
    if (!visibleCharge) return;

    final glow = _glowSprite;
    if (glow != null) {
      final scale = 0.55 + charge * 0.55;
      final size = 90.0 * scale;
      glow.render(
        canvas,
        position: Vector2(anchorWorld.x - size / 2, anchorWorld.y - size / 2),
        size: Vector2.all(size),
      );
    }

    final start = trackStart;
    final end = trackEnd;
    if (start != null && end != null) {
      _renderFloorPath(canvas, start, end, target);
    }

    final dir = aimDir.clone();
    if (dir.length2 < 1e-6) {
      dir.setValues(1, -0.5);
    }
    dir.normalize();
    final tip = Offset(
      anchorWorld.x + dir.x * (55 + charge * 40),
      anchorWorld.y + dir.y * (55 + charge * 40),
    );
    final arrow = Paint()
      ..color = const Color(0xEEFFE66D)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(anchorWorld.x, anchorWorld.y), tip, arrow);
  }

  void _renderFloorPath(
    Canvas canvas,
    Vector2 start,
    Vector2 end,
    Vector2? hit,
  ) {
    const lift = ArenaGrid.bodyLift;
    final from = Offset(start.x, start.y + lift);
    var to = Offset(end.x, end.y + lift);
    if (hit != null && hit.x > start.x && hit.x < end.x) {
      final u = (hit.x - start.x) / (end.x - start.x);
      to = Offset.lerp(from, to, u)!;
    }

    // Dots, skipping the stretch under the thrower's own body.
    final dot = Paint()..color = _charge.withValues(alpha: 0.9);
    final rim = Paint()..color = _ink.withValues(alpha: 0.35);
    final length = (to - from).distance;
    const gap = 22.0;
    for (var d = 60.0; d < length - 10; d += gap) {
      final p = Offset.lerp(from, to, d / length)!;
      canvas.drawCircle(p.translate(0, 1.5), 4.5, rim);
      canvas.drawCircle(p, 4, dot);
    }

    if (hit != null) {
      final feet = Offset(hit.x, hit.y + lift);
      final ring = Rect.fromCenter(center: feet, width: 92, height: 30);
      canvas.drawOval(
        ring,
        Paint()
          ..color = _ink.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7,
      );
      canvas.drawOval(
        ring,
        Paint()
          ..color = _charge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
      return;
    }

    // Landing mark: a soft target cross on the floor.
    final mark = Rect.fromCenter(center: to, width: 46, height: 16);
    canvas.drawOval(mark, Paint()..color = _ink.withValues(alpha: 0.18));
    canvas.drawOval(
      mark,
      Paint()
        ..color = _cream.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    final tick = Paint()
      ..color = _cream.withValues(alpha: 0.85)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final half = mark.width / 2 * math.sqrt1_2;
    canvas.drawLine(to.translate(-half, 0), to.translate(half, 0), tick);
  }
}
