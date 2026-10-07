import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../arena_grid.dart';

/// Aim preview near the throwing kid: charge glow at the hand, a faint
/// dotted aim line on the yard floor across the whole yard, a bright stretch
/// of it out to where the ball lands at the current power, and a landing
/// mark. When [target] is set the bright stretch stops at that rival and
/// their feet get a lock ring. Difficulty decides how much of this shows
/// ([showPath], [target]). The power bar lives in the screen-space HUD.
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

  /// Where the ball lands at the current power.
  Vector2? trackEnd;

  /// The aim line carried to the far side of the yard.
  Vector2? aimEnd;

  /// False hides the floor path, landing mark, and ring (Hard).
  bool showPath = true;

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
    if (showPath && start != null && end != null) {
      _renderFloorPath(canvas, start, end, aimEnd ?? end, target);
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
    Vector2 aim,
    Vector2? hit,
  ) {
    const lift = ArenaGrid.bodyLift;
    final from = Offset(start.x, start.y + lift);
    var to = Offset(end.x, end.y + lift);
    final far = Offset(aim.x, aim.y + lift);
    if (hit != null && hit.x > start.x && hit.x < end.x) {
      final u = (hit.x - start.x) / (end.x - start.x);
      to = Offset.lerp(from, to, u)!;
    }

    // Dots on one fixed spacing from the hand, skipping the stretch under
    // the thrower's own body. Bright up to the landing, faint past it.
    const gap = 22.0;
    const skip = 60.0;
    final reach = (to - from).distance;
    final total = (far - from).distance;
    final faint = Paint()..color = _ink.withValues(alpha: 0.3);
    final dot = Paint()..color = _charge.withValues(alpha: 0.9);
    final rim = Paint()..color = _ink.withValues(alpha: 0.35);
    for (var d = skip; d < total - 4; d += gap) {
      final p = Offset.lerp(from, far, d / total)!;
      if (d < reach - 10) {
        canvas.drawCircle(p.translate(0, 1.5), 4.5, rim);
        canvas.drawCircle(p, 4, dot);
      } else if (d > reach + 14) {
        canvas.drawCircle(p, 3, faint);
      }
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
