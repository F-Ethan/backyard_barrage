import 'dart:ui';

/// Each kid's own color, so the crew can be told apart: on the ground ring
/// in the yard, the skill menu's kid buttons, and the wave report.
abstract final class KidColors {
  /// Kid 1 green, Kid 2 yellow, Kid 3 red.
  static const List<Color> bright = [
    Color(0xFF2ECC71),
    Color(0xFFF1C40F),
    Color(0xFFE74C3C),
  ];

  /// Darker shades of the same colors, readable as text on cream.
  static const List<Color> deep = [
    Color(0xFF1E8449),
    Color(0xFF9A7D0A),
    Color(0xFFB03A2E),
  ];

  static Color of(int kid) => bright[kid % bright.length];

  static Color deepOf(int kid) => deep[kid % deep.length];
}
