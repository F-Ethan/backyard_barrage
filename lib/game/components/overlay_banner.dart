import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Center banner for KO, wave intro, wave clear, and defeat.
///
/// The game publishes one of these on `BackyardBarrageGame.bannerListenable`
/// and the Flutter HUD draws it in screen space (`lib/ui/match_banner.dart`),
/// so it keeps readable type instead of shrinking with the 1280×720 yard.
@immutable
class BannerSpec {
  BannerSpec({
    required this.label,
    this.subtitle,
    this.fontSize = 42,
    this.color = const Color(0xFF1A2332),
  }) : serial = _nextSerial++;

  static int _nextSerial = 0;

  final String label;
  final String? subtitle;

  /// World-space size the game asked for. The overlay reads it as emphasis:
  /// 56 is a headline beat (KO, Wave N), 42–48 a summary.
  final double fontSize;

  /// Title color the game asked for. Anything that is not ink renders as the
  /// accent (dark pill) style so light colors keep their contrast.
  final Color color;

  /// Unique per show, so the overlay replays its entrance even when the same
  /// text appears twice in a row.
  final int serial;

  /// 1.0 for the 42pt summary size.
  double get emphasis => fontSize / 42;

  bool get accent => color.toARGB32() != 0xFF1A2332;
}
