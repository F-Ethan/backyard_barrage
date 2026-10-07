import 'package:flutter/painting.dart';

/// UI v2 palette from `docs/UI_MODERN.md`. Raw swatches; screens read the
/// semantic roles through `BarrageTokens` (see `barrage_theme.dart`).
class BarrageColors {
  const BarrageColors._();

  static const ink = Color(0xFF1A2332);
  static const inkMuted = Color(0xFF5B6B7C);
  static const cream = Color(0xFFFFF8F0);
  static const frost = Color(0xF2FFFFFF);
  static const player = Color(0xFF3D7CFF);
  static const blueDeep = Color(0xFF2B5FD9);
  static const violet = Color(0xFF9B59B6);
  static const balloonPink = Color(0xFFFF6B9D);
  static const winterCool = Color(0xFF7EC8FF);
  static const summerMint = Color(0xFF7DDEB5);
  static const summerTeal = Color(0xFF4ECDC4);
  static const winterSky = Color(0xFFA8D4F0);
  static const summerSky = Color(0xFF87CEEB);
  static const coin = Color(0xFFF1C40F);
  static const heart = Color(0xFFFF5A6B);
  static const charge = Color(0xFFFFE66D);

  /// Soft border instead of thick outlines (ink at ~14%).
  static const hairline = Color(0x241A2332);

  /// Owned skill / selected tint.
  static const ownedTint = Color(0xFFE7F2FF);

  /// Locked skill fill and rail.
  static const lockedFill = Color(0xFFEFEBE4);
  static const lockedRail = Color(0xFFD5D0C8);

  /// Light label on the blue primary pill.
  static const onPrimary = Color(0xFFFFF8F0);

  static const scrim = Color(0xCC1A2332);
}

/// Type roles from `docs/UI_MODERN.md`: bold rounded titles, medium body,
/// ink on cream. The family comes from the app theme (bundled Fredoka).
class BarrageType {
  const BarrageType._();

  static const family = 'Fredoka';

  static const display = TextStyle(
    fontFamily: family,
    color: BarrageColors.ink,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.05,
    letterSpacing: 0.2,
  );

  static const title = TextStyle(
    fontFamily: family,
    color: BarrageColors.ink,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.15,
  );

  static const heading = TextStyle(
    fontFamily: family,
    color: BarrageColors.ink,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static const body = TextStyle(
    fontFamily: family,
    color: BarrageColors.ink,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.25,
  );

  static const muted = TextStyle(
    fontFamily: family,
    color: BarrageColors.inkMuted,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.25,
  );

  /// Small caps-style label above a stat.
  static const overline = TextStyle(
    fontFamily: family,
    color: BarrageColors.inkMuted,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    height: 1.2,
  );

  static const button = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1.1,
  );
}
