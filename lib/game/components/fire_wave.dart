import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../arena_grid.dart';
import '../../meta/meta_state.dart';
import 'fort_component.dart';
import 'kid_component.dart';

/// The magma elemental's heat wave. After the long, marked windup it
/// sweeps the whole lane almost at once, to the yard's far edge, so the
/// only dodge is leaving the lane during the windup. It is twice a
/// snowball's hit size, so it can catch two kids at once, and it passes
/// through kids (each is hit once) and through forts (each loses
/// [fortDamage] HP once). The fire lingers on the lane a moment after.
class FireWave extends PositionComponent {
  FireWave({
    required this.sprite,
    required this.laneY,
    required double startX,
    required this.players,
    required this.forts,
    required this.onKidHit,
    required this.onFortHit,
  }) : _frontX = startX,
       super(priority: ArenaGrid.depthOrder(laneY) + 2);

  final Sprite sprite;

  /// Track height of the lane (a kid's hit-center height on that row).
  final double laneY;
  final List<KidComponent> players;
  final List<FortComponent> forts;
  final void Function(KidComponent kid) onKidHit;
  final void Function(FortComponent fort) onFortHit;

  /// Where the crest stops: the yard's left edge.
  static const double stopX = 20;

  /// Fast enough to cross the yard in about a third of a second.
  static const double speed = 3000;

  /// Half-height of the wave's hit band: twice a snowball's radius.
  static double get hitHalfHeight => MetaState.baseBlastRadius * 2;

  static const int fortDamage = 2;

  /// Seconds the fire lingers and fades once it stops.
  static const double fadeSeconds = 0.6;

  double _frontX;
  double _fade = 0;
  final Set<KidComponent> _hitKids = {};
  final Set<FortComponent> _hitForts = {};

  double get frontX => _frontX;
  bool get stopped => _frontX <= stopX;

  @override
  void update(double dt) {
    super.update(dt);
    if (stopped) {
      _fade += dt;
      if (_fade >= fadeSeconds) removeFromParent();
      return;
    }
    // Sweep everything the crest passed this frame, so a fast wave or a
    // slow frame cannot skip over a kid.
    final from = _frontX;
    _frontX = math.max(stopX, _frontX - speed * dt);
    for (final kid in players) {
      if (kid.isKo || _hitKids.contains(kid)) continue;
      final center = kid.hitCenter;
      if (center.x < _frontX - 34 || center.x > from + 34) continue;
      if ((center.y - laneY).abs() > hitHalfHeight + kid.hitRadius * 0.5) {
        continue;
      }
      _hitKids.add(kid);
      onKidHit(kid);
    }
    for (final cover in forts) {
      if (cover.isCollapsed || _hitForts.contains(cover)) continue;
      final box = cover.shieldFootprint;
      if (box.right < _frontX || box.left > from) continue;
      if (laneY + hitHalfHeight < box.top ||
          laneY - hitHalfHeight > box.bottom) {
        continue;
      }
      _hitForts.add(cover);
      onFortHit(cover);
    }
  }

  @override
  void render(Canvas canvas) {
    final scale = ArenaGrid.depthScale(laneY, groundTrack: true);
    final height = 96 * scale;
    final width = height * 4;
    final alpha = stopped ? (1 - _fade / fadeSeconds).clamp(0.0, 1.0) : 1.0;
    // The crest is the art's left edge; the trail runs back toward the boss.
    final feet = laneY + ArenaGrid.bodyLift;
    sprite.render(
      canvas,
      position: Vector2(_frontX - 12, feet - height),
      size: Vector2(width, height),
      overridePaint: Paint()..color = Color.fromRGBO(255, 255, 255, alpha),
    );
  }
}

/// Glowing path marked on the ground while the magma elemental leans back,
/// so the crew sees where the wave will run.
class WaveWarning extends PositionComponent {
  WaveWarning({required this.laneY, required double startX, this.seconds = 1.3})
    : _startX = startX,
      super(priority: ArenaGrid.depthOrder(laneY) - 1);

  final double laneY;
  final double seconds;
  final double _startX;
  double _age = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= seconds) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final feet = laneY + ArenaGrid.bodyLift;
    final pulse = 0.5 + 0.5 * math.sin(_age * 14);
    final band = Rect.fromLTRB(
      FireWave.stopX,
      feet - FireWave.hitHalfHeight * 0.6,
      _startX,
      feet + FireWave.hitHalfHeight * 0.3,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(band, const Radius.circular(18)),
      Paint()
        ..color = Color.fromRGBO(255, 120, 40, 0.18 + 0.22 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    final edge = Paint()
      ..color = Color.fromRGBO(255, 160, 60, 0.55 + 0.35 * pulse)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    // A hard line where the wave stops, so the safe ground is obvious.
    canvas.drawLine(
      Offset(band.left, band.top),
      Offset(band.left, band.bottom),
      edge,
    );
  }
}
