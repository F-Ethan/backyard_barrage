import 'dart:ui';

/// Each kid's own color, matching their coat (blue kid, green girl, red
/// boy): on the skill menu's kid buttons and the wave report.
abstract final class KidColors {
  /// Kid 1 blue, Kid 2 green, Kid 3 red.
  static const List<Color> bright = [
    Color(0xFF3D7CFF),
    Color(0xFF2ECC71),
    Color(0xFFE74C3C),
  ];

  /// Darker shades of the same colors, readable as text on cream.
  static const List<Color> deep = [
    Color(0xFF2B5FD9),
    Color(0xFF1E8449),
    Color(0xFFB03A2E),
  ];

  static Color of(int kid) => bright[kid % bright.length];

  static Color deepOf(int kid) => deep[kid % deep.length];
}
