import 'package:flutter/material.dart';

import 'barrage_colors.dart';

/// Spacing scale (logical px). Cards pad 16–24, buttons 12–16.
@immutable
class BarrageSpace {
  const BarrageSpace();

  double get xs => 4;
  double get sm => 8;
  double get md => 12;
  double get lg => 16;
  double get xl => 24;
  double get xxl => 32;
}

/// Corner radii from the UI v2 shape language.
@immutable
class BarrageRadii {
  const BarrageRadii();

  /// HUD chips, small pills that are not stadiums.
  double get chip => 16;

  /// Cards and list rows.
  double get card => 22;

  /// Modal sheets.
  double get sheet => 30;

  BorderRadius get chipAll => BorderRadius.circular(chip);
  BorderRadius get cardAll => BorderRadius.circular(card);
  BorderRadius get sheetAll => BorderRadius.circular(sheet);
}

/// Motion durations and curves. Read them through [BarrageMotion.of] so
/// reduced motion collapses them to zero.
@immutable
class BarrageMotionTokens {
  const BarrageMotionTokens({
    this.fast = const Duration(milliseconds: 140),
    this.medium = const Duration(milliseconds: 260),
    this.slow = const Duration(milliseconds: 420),
    this.stagger = const Duration(milliseconds: 60),
  });

  final Duration fast;
  final Duration medium;
  final Duration slow;

  /// Gap between items in a staggered entrance.
  final Duration stagger;

  Curve get enter => Curves.easeOutCubic;
  Curve get exit => Curves.easeInCubic;
  Curve get spring => Curves.easeOutBack;
  Curve get settle => Curves.elasticOut;
}

/// Design tokens for every Flutter screen. Lives on [ThemeData.extensions];
/// [BarrageTokens.of] falls back to [standard] so widgets work without the
/// app theme (tests pump bare MaterialApps).
@immutable
class BarrageTokens extends ThemeExtension<BarrageTokens> {
  const BarrageTokens({
    this.ink = BarrageColors.ink,
    this.inkMuted = BarrageColors.inkMuted,
    this.surface = BarrageColors.cream,
    this.surfaceFrost = BarrageColors.frost,
    this.primary = BarrageColors.player,
    this.primaryDeep = BarrageColors.blueDeep,
    this.onPrimary = BarrageColors.onPrimary,
    this.accent = BarrageColors.violet,
    this.hairline = BarrageColors.hairline,
    this.scrim = BarrageColors.scrim,
    this.coin = BarrageColors.coin,
    this.heart = BarrageColors.heart,
    this.charge = BarrageColors.charge,
    this.ownedTint = BarrageColors.ownedTint,
    this.lockedFill = BarrageColors.lockedFill,
    this.lockedRail = BarrageColors.lockedRail,
    this.space = const BarrageSpace(),
    this.radii = const BarrageRadii(),
    this.motion = const BarrageMotionTokens(),
  });

  static const standard = BarrageTokens();

  final Color ink;
  final Color inkMuted;
  final Color surface;
  final Color surfaceFrost;
  final Color primary;
  final Color primaryDeep;
  final Color onPrimary;
  final Color accent;
  final Color hairline;
  final Color scrim;
  final Color coin;
  final Color heart;
  final Color charge;
  final Color ownedTint;
  final Color lockedFill;
  final Color lockedRail;
  final BarrageSpace space;
  final BarrageRadii radii;
  final BarrageMotionTokens motion;

  /// Resting card / sheet elevation: one soft shadow, no hard lip.
  List<BoxShadow> get shadowSoft => const [
    BoxShadow(color: Color(0x1F1A2332), blurRadius: 24, offset: Offset(0, 8)),
  ];

  /// Lifted elements (HUD chips, banners) over the busy yard.
  List<BoxShadow> get shadowLifted => const [
    BoxShadow(color: Color(0x291A2332), blurRadius: 28, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x141A2332), blurRadius: 6, offset: Offset(0, 2)),
  ];

  /// Blue-tinted glow under primary CTAs.
  List<BoxShadow> get shadowPrimary => const [
    BoxShadow(color: Color(0x553D7CFF), blurRadius: 20, offset: Offset(0, 8)),
  ];

  LinearGradient get primaryGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5A92FF), BarrageColors.player, BarrageColors.blueDeep],
    stops: [0, 0.55, 1],
  );

  static BarrageTokens of(BuildContext context) =>
      Theme.of(context).extension<BarrageTokens>() ?? standard;

  @override
  BarrageTokens copyWith({
    Color? ink,
    Color? inkMuted,
    Color? surface,
    Color? primary,
    BarrageMotionTokens? motion,
  }) {
    return BarrageTokens(
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      surface: surface ?? this.surface,
      surfaceFrost: surfaceFrost,
      primary: primary ?? this.primary,
      primaryDeep: primaryDeep,
      onPrimary: onPrimary,
      accent: accent,
      hairline: hairline,
      scrim: scrim,
      coin: coin,
      heart: heart,
      charge: charge,
      ownedTint: ownedTint,
      lockedFill: lockedFill,
      lockedRail: lockedRail,
      space: space,
      radii: radii,
      motion: motion ?? this.motion,
    );
  }

  @override
  BarrageTokens lerp(covariant BarrageTokens? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return BarrageTokens(
      ink: c(ink, other.ink),
      inkMuted: c(inkMuted, other.inkMuted),
      surface: c(surface, other.surface),
      surfaceFrost: c(surfaceFrost, other.surfaceFrost),
      primary: c(primary, other.primary),
      primaryDeep: c(primaryDeep, other.primaryDeep),
      onPrimary: c(onPrimary, other.onPrimary),
      accent: c(accent, other.accent),
      hairline: c(hairline, other.hairline),
      scrim: c(scrim, other.scrim),
      coin: c(coin, other.coin),
      heart: c(heart, other.heart),
      charge: c(charge, other.charge),
      ownedTint: c(ownedTint, other.ownedTint),
      lockedFill: c(lockedFill, other.lockedFill),
      lockedRail: c(lockedRail, other.lockedRail),
      space: t < 0.5 ? space : other.space,
      radii: t < 0.5 ? radii : other.radii,
      motion: t < 0.5 ? motion : other.motion,
    );
  }
}

/// Resolved motion for a build: token durations, or zero under reduced
/// motion (`MediaQuery.disableAnimations`) or [BarrageMotion.debugDisable].
@immutable
class BarrageMotion {
  const BarrageMotion._(this.tokens, {required this.reduced});

  factory BarrageMotion.of(BuildContext context) {
    final tokens = BarrageTokens.of(context).motion;
    final reduced =
        debugDisable || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return BarrageMotion._(tokens, reduced: reduced);
  }

  /// Widget tests flip this on (see `test/flutter_test_config.dart`) so
  /// screens render their settled state on the first frame and leave no
  /// `flutter_animate` start timers behind. Motion tests turn it back off.
  static bool debugDisable = false;

  final BarrageMotionTokens tokens;

  /// True when animations should be near-instant.
  final bool reduced;

  Duration get fast => reduced ? Duration.zero : tokens.fast;
  Duration get medium => reduced ? Duration.zero : tokens.medium;
  Duration get slow => reduced ? Duration.zero : tokens.slow;
  Duration get stagger => reduced ? Duration.zero : tokens.stagger;

  Curve get enter => tokens.enter;
  Curve get exit => tokens.exit;
  Curve get spring => tokens.spring;
  Curve get settle => tokens.settle;
}

extension BarrageThemeContext on BuildContext {
  BarrageTokens get tokens => BarrageTokens.of(this);
  BarrageMotion get motion => BarrageMotion.of(this);
}

/// App theme: Fredoka through the text theme, tokens on the extension.
abstract final class BarrageTheme {
  static ThemeData light() {
    const tokens = BarrageTokens.standard;
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: BarrageType.family,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: tokens.primary,
            brightness: Brightness.light,
          ).copyWith(
            primary: tokens.primary,
            onPrimary: tokens.onPrimary,
            secondary: tokens.accent,
            surface: tokens.surface,
            onSurface: tokens.ink,
          ),
      scaffoldBackgroundColor: tokens.surface,
    );
    final text = base.textTheme
        .apply(
          fontFamily: BarrageType.family,
          bodyColor: tokens.ink,
          displayColor: tokens.ink,
        )
        .copyWith(
          displayLarge: BarrageType.display.copyWith(fontSize: 56),
          displayMedium: BarrageType.display,
          headlineMedium: BarrageType.title,
          titleLarge: BarrageType.heading.copyWith(fontSize: 22),
          titleMedium: BarrageType.heading,
          bodyLarge: BarrageType.body.copyWith(fontSize: 16),
          bodyMedium: BarrageType.body,
          bodySmall: BarrageType.muted,
          labelLarge: BarrageType.button,
          labelSmall: BarrageType.overline,
        );
    return base.copyWith(textTheme: text, extensions: const [tokens]);
  }
}
