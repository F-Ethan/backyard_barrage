import 'package:flutter/painting.dart';

/// UI v2 palette from `docs/UI_MODERN.md`.
class BarrageColors {
  const BarrageColors._();

  static const ink = Color(0xFF1A2332);
  static const inkMuted = Color(0xFF5B6B7C);
  static const cream = Color(0xFFFFF8F0);
  static const player = Color(0xFF3D7CFF);
  static const blueDeep = Color(0xFF2B5FD9);
  static const winterCool = Color(0xFF7EC8FF);
  static const summerMint = Color(0xFF7DDEB5);
  static const summerTeal = Color(0xFF4ECDC4);
  static const winterSky = Color(0xFFA8D4F0);
  static const summerSky = Color(0xFF87CEEB);
  static const coin = Color(0xFFF1C40F);
  static const heart = Color(0xFFFF5A6B);
  static const charge = Color(0xFFFFE66D);

  /// Light label on the blue primary pill.
  static const onPrimary = Color(0xFFFFF8F0);

  static const scrim = Color(0xCC1A2332);
}

/// Type roles from `docs/UI_MODERN.md`: bold titles, medium body, ink on cream.
class BarrageType {
  const BarrageType._();

  static const title = TextStyle(
    color: BarrageColors.ink,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    height: 1.15,
  );

  static const heading = TextStyle(
    color: BarrageColors.ink,
    fontSize: 18,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );

  static const body = TextStyle(
    color: BarrageColors.ink,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  static const muted = TextStyle(
    color: BarrageColors.inkMuted,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  static const button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.2,
    height: 1.1,
  );
}
