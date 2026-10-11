import 'dart:async';

import 'package:flutter/material.dart';

import '../ads/remove_ads.dart';
import '../feel/feel_bus.dart';
import '../game/kid_colors.dart';
import '../meta/game_settings.dart';
import 'barrage_colors.dart';
import 'barrage_theme.dart';
import 'draft_button.dart';
import 'motion.dart';
import 'new_game.dart';
import 'parental_gate.dart';

/// SFX, music, haptics, difficulty, and credits. Shared by the menu and
/// pause.
class SettingsOverlay extends StatefulWidget {
  const SettingsOverlay({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.onClose,
    this.feel,
    this.onAdPrivacy,
    this.removeAds,
    this.onNewGame,
  });

  final GameSettings settings;
  final Future<void> Function(GameSettings next) onChanged;
  final VoidCallback onClose;
  final FeelBus? feel;
  final Future<void> Function()? onAdPrivacy;
  final RemoveAdsController? removeAds;

  /// Arcade in a match: start a new game (asks first). Null hides it.
  final VoidCallback? onNewGame;

  @override
  State<SettingsOverlay> createState() => _SettingsOverlayState();
}

class _SettingsOverlayState extends State<SettingsOverlay> {
  late GameSettings _settings = widget.settings;

  @override
  void didUpdateWidget(SettingsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _settings = widget.settings;
    }
  }

  Future<void> _set(GameSettings next) async {
    setState(() => _settings = next);
    await widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final size = MediaQuery.sizeOf(context);
    final height = (size.height - 32).clamp(220.0, 520.0).toDouble();
    return ModalShell(
      key: const Key('settings-sheet'),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: height),
        child: SheetSurface(
          padding: EdgeInsets.fromLTRB(
            tokens.space.xl,
            tokens.space.lg,
            tokens.space.lg,
            tokens.space.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Settings', style: BarrageType.title),
                  ),
                  KitIconButton(
                    key: const Key('settings-back'),
                    kind: UiIconKind.close,
                    semanticLabel: 'Back',
                    size: 48,
                    feel: widget.feel,
                    onPressed: widget.onClose,
                  ),
                ],
              ),
              SizedBox(height: tokens.space.xs),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(right: tokens.space.sm),
                  child: Column(
                    children: [
                      if (widget.onNewGame != null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Arcade run',
                                style: BarrageType.heading.copyWith(
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            NewGameButton(
                              key: const Key('settings-new-game'),
                              onPressed: () async {
                                if (await confirmNewGame(
                                  context,
                                  feel: widget.feel,
                                )) {
                                  widget.onNewGame?.call();
                                }
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: tokens.space.sm),
                      ],
                      _LeadKidRow(
                        lead: _settings.leadKid,
                        onChanged: (kid) =>
                            _set(_settings.copyWith(leadKid: kid)),
                      ),
                      SizedBox(height: tokens.space.xs),
                      _ToggleRow(
                        label: 'Sound effects',
                        icon: Icons.volume_up_rounded,
                        value: _settings.sfxEnabled,
                        switchKey: const Key('sfx-toggle'),
                        onChanged: (value) =>
                            _set(_settings.copyWith(sfxEnabled: value)),
                      ),
                      _ToggleRow(
                        label: 'Music',
                        icon: Icons.music_note_rounded,
                        value: _settings.musicEnabled,
                        switchKey: const Key('music-toggle'),
                        onChanged: (value) =>
                            _set(_settings.copyWith(musicEnabled: value)),
                      ),
                      _ToggleRow(
                        label: 'Haptics',
                        icon: Icons.vibration_rounded,
                        value: _settings.hapticsEnabled,
                        switchKey: const Key('haptics-toggle'),
                        onChanged: (value) =>
                            _set(_settings.copyWith(hapticsEnabled: value)),
                      ),
                      SizedBox(height: tokens.space.sm),
                      const Text(
                        'Who you start as, sound, music, and haptics for this device. Difficulty is picked on the home screen.',
                        textAlign: TextAlign.center,
                        style: BarrageType.muted,
                      ),
                      SizedBox(height: tokens.space.lg),
                      const Text('Credits', style: BarrageType.heading),
                      SizedBox(height: tokens.space.xs),
                      const Text('GameLogic', style: BarrageType.body),
                      const Text('Ethan', style: BarrageType.muted),
                      const Text(
                        'Snowballs and water balloons.',
                        textAlign: TextAlign.center,
                        style: BarrageType.muted,
                      ),
                      if (widget.removeAds != null)
                        _RemoveAdsSection(
                          removeAds: widget.removeAds!,
                          feel: widget.feel,
                        ),
                      if (widget.onAdPrivacy != null) ...[
                        SizedBox(height: tokens.space.md),
                        DraftImageButton(
                          key: const Key('ad-privacy'),
                          label: 'Ad privacy',
                          secondary: true,
                          leadingIcon: Icons.privacy_tip_rounded,
                          width: 200,
                          height: 48,
                          fontSize: 15,
                          feel: widget.feel,
                          onPressed: () => widget.onAdPrivacy!.call(),
                        ),
                      ],
                      SizedBox(height: tokens.space.md),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoveAdsSection extends StatelessWidget {
  const _RemoveAdsSection({required this.removeAds, this.feel});

  final RemoveAdsController removeAds;
  final FeelBus? feel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ListenableBuilder(
      listenable: removeAds,
      builder: (context, _) {
        final owned = removeAds.owned;
        final price = removeAds.priceLabel;
        final canBuy = !owned && price != null && !removeAds.buying;
        final label = owned
            ? 'Ads removed'
            : price != null
            ? 'Remove Ads · $price'
            : 'Remove Ads';
        final note =
            removeAds.note ??
            (!owned && price == null ? RemoveAdsCopy.unavailable : null);
        return Column(
          children: [
            SizedBox(height: tokens.space.md),
            DraftImageButton(
              key: const Key('remove-ads'),
              label: label,
              leadingIcon: owned ? Icons.check_circle_rounded : null,
              enabled: canBuy,
              width: 260,
              height: 52,
              fontSize: 15,
              feel: feel,
              onPressed: canBuy
                  ? () async {
                      if (await askGrownUp(context, feel: feel)) {
                        unawaited(removeAds.buy());
                      }
                    }
                  : null,
            ),
            if (note != null) ...[
              SizedBox(height: tokens.space.sm),
              Text(
                note,
                key: const Key('remove-ads-note'),
                textAlign: TextAlign.center,
                style: BarrageType.muted,
              ),
            ],
            SizedBox(height: tokens.space.sm),
            DraftImageButton(
              key: const Key('restore-purchases'),
              label: 'Restore Purchases',
              secondary: true,
              leadingIcon: Icons.restore_rounded,
              width: 260,
              height: 52,
              fontSize: 15,
              feel: feel,
              onPressed: () async {
                if (await askGrownUp(context, feel: feel)) {
                  unawaited(removeAds.restore());
                }
              },
            ),
          ],
        );
      },
    );
  }
}

/// Stadium switch from the v2 shape language: blue track when on, muted
/// track when off; the knob springs across.
class BarrageToggle extends StatelessWidget {
  const BarrageToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final motion = context.motion;
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 72,
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: motion.medium,
              curve: motion.enter,
              width: 60,
              height: 34,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: value ? tokens.primary : tokens.lockedRail,
                borderRadius: BorderRadius.circular(999),
              ),
              child: AnimatedAlign(
                duration: motion.medium,
                curve: motion.spring,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    shape: BoxShape.circle,
                    boxShadow: tokens.shadowSoft,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Start as": which kid you control when a wave starts.
class _LeadKidRow extends StatelessWidget {
  const _LeadKidRow({required this.lead, required this.onChanged});

  final int lead;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      children: [
        Icon(Icons.person_pin_rounded, color: tokens.primary),
        SizedBox(width: tokens.space.sm),
        const Expanded(child: Text('Start as', style: BarrageType.body)),
        for (var kid = 0; kid < KidColors.names.length; kid++) ...[
          SizedBox(width: tokens.space.xs),
          Semantics(
            button: true,
            selected: kid == lead,
            label: 'Start as ${KidColors.nameOf(kid)}',
            child: PressScale(
              key: Key('lead-kid-$kid'),
              pressedScale: 0.94,
              onTap: () => onChanged(kid),
              child: AnimatedContainer(
                duration: context.motion.fast,
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.space.md,
                  vertical: tokens.space.xs + 2,
                ),
                decoration: BoxDecoration(
                  color: kid == lead ? KidColors.of(kid) : tokens.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: KidColors.of(kid), width: 2),
                ),
                child: Text(
                  KidColors.nameOf(kid),
                  style: BarrageType.button.copyWith(
                    fontSize: 14,
                    color: kid == lead
                        ? tokens.onPrimary
                        : KidColors.deepOf(kid),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.switchKey,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final bool value;
  final Key switchKey;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Icon(icon, size: 22, color: tokens.inkMuted),
          SizedBox(width: tokens.space.md),
          Expanded(child: Text(label, style: BarrageType.body)),
          BarrageToggle(key: switchKey, value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
