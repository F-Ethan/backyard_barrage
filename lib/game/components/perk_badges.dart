import 'dart:math' as math;
import 'dart:ui' hide TextStyle;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle;

import '../../meta/power_up.dart';
import '../enemy_perks.dart';
import 'kid_component.dart';

/// Little icons over a rival's head for each perk it still holds. A
/// team-wide potion gets a ring that empties as its countdown runs, with
/// the seconds left, so the crew knows who to knock out first. Shields
/// show on the kid's own shield badge instead.
class PerkBadges extends PositionComponent {
  PerkBadges({
    required this.host,
    required this.perks,
    required this.icons,
    required this.countdownSeconds,
  }) : super(priority: 10);

  final KidComponent host;
  final List<HeldPerk> perks;
  final Map<PowerUp, Sprite> icons;

  /// Full countdown, so the ring can show how much is left.
  final double countdownSeconds;

  static const double iconSize = 30;

  /// Icon for a perk: its power-up, or the bolt for Quick hands.
  Sprite? _icon(EnemyPerk perk) => switch (perk) {
    EnemyPerk.quickHands => icons[PowerUp.powerThrow],
    EnemyPerk.shield => null,
    _ => icons[perk.item!],
  };

  @override
  void render(Canvas canvas) {
    if (host.isKo) return;
    final shown = [
      for (final held in perks)
        if (!held.spent && _icon(held.perk) != null) held,
    ];
    if (shown.isEmpty) return;
    final total = shown.length * (iconSize + 4) - 4;
    var x = host.size.x / 2 - total / 2;
    // Above the overhead health bar.
    const y = -iconSize - 26;
    for (final held in shown) {
      final icon = _icon(held.perk)!;
      icon.render(canvas, position: Vector2(x, y), size: Vector2.all(iconSize));
      if (held.perk.area) _renderCountdown(canvas, held, x, y);
      x += iconSize + 4;
    }
  }

  void _renderCountdown(Canvas canvas, HeldPerk held, double x, double y) {
    final center = Offset(x + iconSize / 2, y + iconSize / 2);
    final left = (held.countdown / countdownSeconds).clamp(0.0, 1.0);
    final urgent = held.countdown <= 3;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: iconSize / 2 + 4),
      -math.pi / 2,
      2 * math.pi * left,
      false,
      Paint()
        ..color = urgent ? const Color(0xFFFF4D4D) : const Color(0xFFFFE66D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    final text = TextPainter(
      text: TextSpan(
        text: '${held.countdown.ceil()}',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: urgent ? const Color(0xFFFF4D4D) : const Color(0xFF1A2332),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, Offset(center.dx - text.width / 2, y - text.height - 2));
  }
}
