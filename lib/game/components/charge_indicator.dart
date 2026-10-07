import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../arena_grid.dart';
import '../throw_physics.dart';

/// Aim preview near the throwing kid: charge glow at the hand, then the
/// ball's own flight drawn as bright dots from the hand, up over the loft,
/// and down to where it lands at the current power. Past the landing, faint
/// dots carry the aim line on across the yard. A landing mark sits on the
/// floor under the end; when [target] is set the arc stops at that rival
/// and their feet get a lock ring. Difficulty decides how much of this
/// shows ([showPath], [target]). The power bar lives in the HUD.
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

  /// How far the ball flies at the current power. Sets the loft shape, the
  /// same way [LobProjectile] draws it.
  double range = 0;

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
      _renderFlightPath(canvas, start, end, aimEnd ?? end, target);
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

  void _renderFlightPath(
    Canvas canvas,
    Vector2 start,
    Vector2 end,
    Vector2 aim,
    Vector2? hit,
  ) {
    const lift = ArenaGrid.bodyLift;
    final hand = anchorWorld;
    final handLift = start.y - hand.y;
    final reach = end.x - start.x;
    final flight = range > 1 ? range : reach;

    // Track height (the hit path) [d] pixels forward of the hand.
    double trackY(double d) {
      if (reach <= 1) return start.y;
      return start.y + (end.y - start.y) * (d / reach).clamp(0.0, 1.0);
    }

    // Where the ball is drawn [d] pixels forward: the track, lifted by the
    // loft, easing down from the hand. Matches LobProjectile._syncVisual.
    Offset drawnAt(double d) {
      final u = (d / flight).clamp(0.0, 1.0);
      final y = trackY(d) - ThrowPhysics.loftAt(u, flight) - handLift * (1 - u);
      return Offset(start.x + d, y);
    }

    var stop = reach;
    if (hit != null && hit.x > start.x && hit.x < end.x) {
      stop = hit.x - start.x;
    }

    const gap = 20.0;
    final dot = Paint()..color = _charge.withValues(alpha: 0.95);
    final rim = Paint()..color = _ink.withValues(alpha: 0.35);
    final faint = Paint()..color = _ink.withValues(alpha: 0.3);

    // Bright arc from just past the hand to the landing (or the rival).
    for (var d = 18.0; d < stop - 6; d += gap) {
      final p = drawnAt(d);
      canvas.drawCircle(p.translate(0, 1.5), 4.5, rim);
      canvas.drawCircle(p, 4, dot);
    }

    // Faint aim line onward at throw height, so the pan reads at any power.
    final aimReach = aim.x - start.x;
    for (var d = reach + gap; d < aimReach - 4; d += gap) {
      final u = aimReach <= 1 ? 1.0 : d / aimReach;
      canvas.drawCircle(
        Offset(start.x + d, start.y + (aim.y - start.y) * u),
        3,
        faint,
      );
    }

    final to = Offset(end.x, end.y + lift);
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
