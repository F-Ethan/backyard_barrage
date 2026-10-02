import 'package:flutter/material.dart';

import '../meta/game_settings.dart';
import 'ui_assets.dart';

/// Pause, settings, and close glyphs. Classic has no icon sprites for these.
enum UiIconKind { pause, settings, close }

/// Classic wood kit (`assets/images/ui/`) or the modern kit
/// (`assets/images/ui_modern/`). Screens read this from [UiKitScope].
class UiKit {
  const UiKit({required this.modern});

  factory UiKit.from(GameSettings settings) => UiKit(modern: settings.modernUi);

  final bool modern;

  static const _classic = 'assets/images/ui';

  String get primary =>
      modern ? UiAssets.primary : '$_classic/btn_primary_draft.png';

  String get primaryPressed => modern
      ? UiAssets.primaryPressed
      : '$_classic/btn_primary_pressed_draft.png';

  String get secondary =>
      modern ? UiAssets.secondary : '$_classic/btn_secondary_draft.png';

  String get panel =>
      modern ? UiAssets.panel : '$_classic/panel_modal_draft.png';

  String get shopCard =>
      modern ? UiAssets.shopCard : '$_classic/shop_card_frame_draft.png';

  String get coin => modern ? UiAssets.coin : '$_classic/coin_draft.png';

  String get wordmark => modern
      ? UiAssets.wordmark
      : '$_classic/wordmark_backyard_barrage_draft.png';

  String get heart => modern ? UiAssets.heart : '$_classic/heart_draft.png';

  String get heartEmpty =>
      modern ? UiAssets.heartEmpty : '$_classic/heart_empty_draft.png';

  String get fortEmpty =>
      modern ? UiAssets.fortEmpty : '$_classic/fort_bar_empty_draft.png';

  String get fortFill =>
      modern ? UiAssets.fortFill : '$_classic/fort_bar_fill_draft.png';

  /// Frosted HUD chip. The classic pack has no matching sprite.
  String? get hudChip => modern ? UiAssets.hudChip : null;

  String? get toggleOn => modern ? UiAssets.toggleOn : null;

  String? get toggleOff => modern ? UiAssets.toggleOff : null;

  String chip(String seasonName, {required bool selected}) {
    final suffix = selected ? '' : '_off';
    if (modern) {
      return 'assets/images/ui_modern/chip_season_$seasonName${suffix}_v2.png';
    }
    return '$_classic/chip_season_$seasonName${suffix}_draft.png';
  }

  String? iconAsset(UiIconKind kind) {
    if (!modern) return null;
    return switch (kind) {
      UiIconKind.pause => UiAssets.iconPause,
      UiIconKind.settings => UiAssets.iconSettings,
      UiIconKind.close => UiAssets.iconClose,
    };
  }

  IconData iconData(UiIconKind kind) {
    return switch (kind) {
      UiIconKind.pause => Icons.pause_rounded,
      UiIconKind.settings => Icons.settings_rounded,
      UiIconKind.close => Icons.close_rounded,
    };
  }

  Color get ink => modern ? const Color(0xFF1A2332) : const Color(0xFF2C3E50);

  Color get inkMuted =>
      modern ? const Color(0xFF5B6B7C) : const Color(0xFF5D6D7E);

  Color get cream => const Color(0xFFFFF8F0);

  Color get onPrimary => cream;

  Color get scrim => modern ? const Color(0xCC1A2332) : const Color(0xCC2C3E50);

  Color get charge => const Color(0xFFFFE66D);

  Color get player => const Color(0xFF3D7CFF);

  /// Primary pills are blue in the modern kit and cream in the classic kit.
  Color labelOn(bool primaryButton) {
    if (primaryButton && modern) return onPrimary;
    return ink;
  }
}

/// Live UI kit. Dependents rebuild when settings change; the game widget does
/// not, so flipping the toggle does not reload the match.
class UiKitScope extends InheritedNotifier<ValueNotifier<GameSettings>> {
  const UiKitScope({
    required ValueNotifier<GameSettings> settings,
    required super.child,
    super.key,
  }) : super(notifier: settings);

  static UiKit of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<UiKitScope>();
    final settings = scope?.notifier?.value ?? const GameSettings();
    return UiKit.from(settings);
  }
}
