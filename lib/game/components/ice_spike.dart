import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../arena_grid.dart';
import 'kid_component.dart';

enum SpikeState { crack, rising, up, sinking }

/// One ice spike from the ogre's slam. It bursts straight up where a kid
/// was standing, with no path to follow. The ground cracks for [warnSeconds]
/// first, so a kid who steps off the crack is safe. Anyone still inside
/// [hitRadiusX] by [hitRadiusY] when it bursts is hit once.
class IceSpike extends PositionComponent {
  IceSpike({
    required this.frames,
    required Vector2 feet,
    required this.warnSeconds,
    required this.players,
    required this.onKidHit,
    this.onBurst,
  }) : super(
         position: feet.clone(),
         anchor: Anchor.bottomCenter,
         priority: ArenaGrid.depthOrder(feet.y - ArenaGrid.bodyLift) + 1,
       );

  /// Small, half, and full spike frames.
  final List<Sprite> frames;
  final double warnSeconds;
  final List<KidComponent> players;
  final void Function(KidComponent kid) onKidHit;
  final void Function()? onBurst;

  static const double riseSeconds = 0.15;
  static const double upSeconds = 0.55;
  static const double sinkSeconds = 0.3;

  /// Half-width and half-depth of the burst, in pixels around the crack.
  static const double hitRadiusX = 52;
  static double get hitRadiusY => ArenaGrid.rowStep * 0.6;

  SpikeState _state = SpikeState.crack;
  double _clock = 0;

  SpikeState get state => _state;

  @override
  void update(double dt) {
    super.update(dt);
    _clock += dt;
    switch (_state) {
      case SpikeState.crack:
        if (_clock >= warnSeconds) {
          _state = SpikeState.rising;
          _clock = 0;
          _burst();
        }
      case SpikeState.rising:
        if (_clock >= riseSeconds) {
          _state = SpikeState.up;
          _clock = 0;
        }
      case SpikeState.up:
        if (_clock >= upSeconds) {
          _state = SpikeState.sinking;
          _clock = 0;
        }
      case SpikeState.sinking:
        if (_clock >= sinkSeconds) removeFromParent();
    }
  }

  void _burst() {
    onBurst?.call();
    for (final kid in players) {
      if (kid.isKo) continue;
      final dx = (kid.position.x - position.x) / hitRadiusX;
      final dy = (kid.position.y - position.y) / hitRadiusY;
      if (dx * dx + dy * dy <= 1) onKidHit(kid);
    }
  }

  @override
  void render(Canvas canvas) {
    final scale = ArenaGrid.depthScale(position.y, groundTrack: false);
    if (_state == SpikeState.crack) {
      _renderCrack(canvas, scale);
      return;
    }
    final frame = switch (_state) {
      SpikeState.rising => _clock < riseSeconds / 2 ? frames[0] : frames[1],
      _ => frames[2],
    };
    final alpha = _state == SpikeState.sinking
        ? (1 - _clock / sinkSeconds).clamp(0.0, 1.0)
        : 1.0;
    final side = 150 * scale;
    frame.render(
      canvas,
      position: Vector2(-side / 2, -side * 0.97),
      size: Vector2.all(side),
      overridePaint: Paint()..color = Color.fromRGBO(255, 255, 255, alpha),
    );
  }

  /// A pulsing cracked ellipse on the snow: the warning.
  void _renderCrack(Canvas canvas, double scale) {
    final t = (_clock / warnSeconds).clamp(0.0, 1.0);
    final pulse = 0.5 + 0.5 * math.sin(_clock * 18);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: hitRadiusX * 2 * scale,
      height: hitRadiusY * 2 * scale,
    );
    canvas.drawOval(
      rect,
      Paint()..color = Color.fromRGBO(120, 200, 255, 0.15 + 0.25 * t * pulse),
    );
    final line = Paint()
      ..color = Color.fromRGBO(40, 110, 180, 0.5 + 0.4 * t)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final rng = math.Random(hashCode);
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 + rng.nextDouble() * 0.5;
      final r = (0.4 + 0.6 * t) * rect.width / 2;
      canvas.drawLine(
        Offset.zero,
        Offset(math.cos(a) * r, math.sin(a) * r * rect.height / rect.width),
        line,
      );
    }
  }
}
