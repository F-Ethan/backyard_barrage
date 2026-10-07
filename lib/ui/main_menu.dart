import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ads/remove_ads.dart';
import '../feel/feel_bus.dart';
import '../meta/difficulty.dart';
import '../meta/game_settings.dart';
import '../meta/meta_state.dart';
import '../meta/play_mode.dart';
import '../meta/player_save.dart';
import '../meta/save_store.dart';
import '../meta/settings_store.dart';
import '../seasons/season.dart';
import 'barrage_colors.dart';
import 'barrage_theme.dart';
import 'difficulty_picker.dart';
import 'draft_button.dart';
import 'motion.dart';
import 'season_home_backdrop.dart';
import 'settings_panel.dart';

/// Landscape size classes for the home screen.
enum _MenuSize {
  /// Small phone landscape (~640×360).
  compact,

  /// Typical phone landscape (~844×390 to ~932×430).
  regular,

  /// Tablets and desktop playtest windows.
  wide;

  static _MenuSize of(BoxConstraints box) {
    if (box.maxHeight < 400 || box.maxWidth < 720) return compact;
    if (box.maxWidth >= 1100 && box.maxHeight >= 600) return wide;
    return regular;
  }
}

class MainMenu extends StatefulWidget {
  const MainMenu({
    super.key,
    required this.saveStore,
    required this.settingsStore,
    required this.feel,
    required this.onPlay,
    this.onAdPrivacy,
    this.removeAds,
  });

  final SaveStore saveStore;
  final SettingsStore settingsStore;
  final FeelBus feel;
  final ValueChanged<MetaState> onPlay;
  final Future<void> Function()? onAdPrivacy;
  final RemoveAdsController? removeAds;

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  PlayerSave? _profile;
  bool _settingsOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await widget.saveStore.load();
    final settings = await widget.settingsStore.load();
    widget.feel.apply(settings);
    if (!mounted) return;
    setState(() => _profile = loaded);
    await widget.feel.enterMenu();
  }

  /// Difficulty is picked here and nowhere else, so a run keeps one mode
  /// and its best wave counts for that mode.
  Future<void> _setDifficulty(Difficulty next) async {
    if (widget.feel.settings.difficulty == next) return;
    widget.feel.uiTap();
    await _commitSettings(widget.feel.settings.copyWith(difficulty: next));
  }

  Future<void> _play(PlayMode mode) async {
    final profile = _profile;
    if (profile == null) return;
    final slot = profile.wallet(mode);
    slot.mode = mode;
    slot.season = profile.season;
    profile.mode = mode;
    widget.feel.uiTap();
    await widget.saveStore.save(slot);
    widget.onPlay(slot);
  }

  Future<void> _commitSettings(GameSettings next) async {
    widget.feel.apply(next);
    if (mounted) setState(() {});
    await widget.settingsStore.save(next);
    await widget.feel.syncMusic();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final season = profile?.season ?? Season.winter;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MotionSwitcher(
              slide: Offset.zero,
              child: SeasonHomeBackdrop(
                key: Key('home-backdrop-${season.name}'),
                season: season,
              ),
            ),
          ),
          SafeArea(
            child: profile == null
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, box) => _HomeLayout(
                      size: _MenuSize.of(box),
                      profile: profile,
                      feel: widget.feel,
                      difficulty: widget.feel.settings.difficulty,
                      onDifficulty: _setDifficulty,
                      onPlay: _play,
                      onSettings: () => setState(() => _settingsOpen = true),
                    ),
                  ),
          ),
          Positioned.fill(
            child: MotionSwitcher(
              slide: Offset.zero,
              child: _settingsOpen
                  ? SettingsOverlay(
                      key: const ValueKey('menu-settings-open'),
                      settings: widget.feel.settings,
                      feel: widget.feel,
                      onChanged: _commitSettings,
                      onClose: () => setState(() => _settingsOpen = false),
                      onAdPrivacy: widget.onAdPrivacy,
                      removeAds: widget.removeAds,
                    )
                  : const SizedBox.shrink(key: ValueKey('menu-settings-shut')),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeLayout extends StatelessWidget {
  const _HomeLayout({
    required this.size,
    required this.profile,
    required this.feel,
    required this.difficulty,
    required this.onDifficulty,
    required this.onPlay,
    required this.onSettings,
  });

  final _MenuSize size;
  final PlayerSave profile;
  final FeelBus feel;
  final Difficulty difficulty;
  final ValueChanged<Difficulty> onDifficulty;
  final ValueChanged<PlayMode> onPlay;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final compact = size == _MenuSize.compact;
    final wide = size == _MenuSize.wide;
    final gutter = compact ? tokens.space.md : tokens.space.xl;
    Widget rise(int index, Widget child) =>
        child.enterRise(context, index: index);

    final topBar = Row(
      children: [
        rise(
          0,
          _DifficultyBar(
            value: difficulty,
            onChanged: onDifficulty,
            compact: compact,
          ),
        ),
        const Spacer(),
        rise(
          1,
          DraftImageButton(
            key: const Key('menu-settings'),
            label: 'Settings',
            secondary: true,
            leadingKind: UiIconKind.settings,
            width: compact ? 136 : 160,
            height: compact ? 44 : 50,
            fontSize: compact ? 14 : 16,
            feel: feel,
            onPressed: onSettings,
          ),
        ),
      ],
    );

    final brand = LayoutBuilder(
      builder: (context, box) {
        final wordSize = (box.maxHeight * 0.17).clamp(28.0, wide ? 76.0 : 60.0);
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                rise(2, Wordmark(fontSize: wordSize)),
                SizedBox(height: tokens.space.sm),
                rise(
                  3,
                  Text(
                    Season.choosable
                        ? 'Snowballs & water balloons'
                        : 'Backyard snowball fights',
                    style: BarrageType.heading.copyWith(
                      fontSize: compact ? 15 : (wide ? 22 : 18),
                      fontWeight: FontWeight.w500,
                      color: tokens.ink.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                SizedBox(height: compact ? tokens.space.md : tokens.space.xl),
                rise(
                  4,
                  _CampaignBest(
                    wallet: profile.campaign,
                    difficulty: difficulty,
                    compact: compact,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    final modes = Column(
      children: [
        for (final mode in PlayMode.values) ...[
          if (mode != PlayMode.values.first)
            SizedBox(height: compact ? tokens.space.sm : tokens.space.md),
          Expanded(
            child: rise(
              mode == PlayMode.values.first ? 3 : 5,
              _ModeCard(
                mode: mode,
                wallet: profile.wallet(mode),
                difficulty: difficulty,
                primary: mode == PlayMode.arcade,
                compact: compact,
                wide: wide,
                onTap: () => onPlay(mode),
              ),
            ),
          ),
        ],
      ],
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            gutter,
            compact ? tokens.space.sm : tokens.space.lg,
            gutter,
            gutter,
          ),
          child: Column(
            children: [
              topBar,
              SizedBox(height: compact ? tokens.space.sm : tokens.space.md),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 5, child: brand),
                    SizedBox(
                      width: compact ? tokens.space.md : tokens.space.xl,
                    ),
                    Expanded(
                      flex: wide ? 5 : 6,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: wide ? 440 : double.infinity,
                          ),
                          child: modes,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two-line title set in Fredoka, matching the v2 wordmark layout (ink
/// "Backyard", blue "Barrage", blue underline with the season dots).
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.fontSize = 52});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final style = BarrageType.display.copyWith(
      fontSize: fontSize,
      height: 0.98,
      shadows: const [
        Shadow(color: Color(0x33FFFFFF), offset: Offset(0, 2), blurRadius: 0),
      ],
    );
    return Semantics(
      header: true,
      label: 'Backyard Barrage',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Backyard', style: style.copyWith(color: tokens.ink)),
          Text('Barrage', style: style.copyWith(color: tokens.primary)),
          SizedBox(height: fontSize * 0.12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Dot(color: BarrageColors.winterCool, size: fontSize * 0.16),
              SizedBox(width: fontSize * 0.1),
              Container(
                width: fontSize * 2.4,
                height: math.max(4, fontSize * 0.09),
                decoration: BoxDecoration(
                  color: tokens.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              SizedBox(width: fontSize * 0.1),
              _Dot(color: BarrageColors.summerMint, size: fontSize * 0.16),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Difficulty pills, plus a one-line summary of the picked mode when there
/// is room. The summary also tells the player what changed on a switch.
class _DifficultyBar extends StatelessWidget {
  const _DifficultyBar({
    required this.value,
    required this.onChanged,
    required this.compact,
  });

  final Difficulty value;
  final ValueChanged<Difficulty> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DifficultyPicker(value: value, onChanged: onChanged, compact: compact),
        if (!compact) ...[
          SizedBox(width: tokens.space.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: MotionSwitcher(
              child: Text(
                value.summary,
                key: ValueKey('difficulty-summary-${value.name}'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: BarrageType.muted.copyWith(
                  fontSize: 13,
                  color: tokens.inkMuted,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Campaign best wave on each difficulty. The picked difficulty is large
/// and blue; the others show beside it, small and grey, only once they
/// have a cleared wave.
class _CampaignBest extends StatelessWidget {
  const _CampaignBest({
    required this.wallet,
    required this.difficulty,
    required this.compact,
  });

  final MetaState wallet;
  final Difficulty difficulty;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final shown = [
      for (final mode in Difficulty.values)
        if (mode == difficulty || wallet.bestWaveFor(mode) > 0) mode,
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.92),
        borderRadius: tokens.radii.cardAll,
        border: Border.all(color: tokens.hairline),
        boxShadow: tokens.shadowSoft,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.space.md,
          tokens.space.sm,
          tokens.space.lg + tokens.space.xs,
          tokens.space.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 36 : 44,
              height: compact ? 36 : 44,
              decoration: BoxDecoration(
                gradient: tokens.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.emoji_events_rounded,
                color: tokens.onPrimary,
                size: compact ? 20 : 24,
              ),
            ),
            SizedBox(width: tokens.space.md),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'CAMPAIGN BEST',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BarrageType.overline,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final mode in shown) ...[
                        if (mode != shown.first)
                          SizedBox(width: tokens.space.md),
                        _BestEntry(
                          mode: mode,
                          wave: wallet.bestWaveFor(mode),
                          current: mode == difficulty,
                          compact: compact,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BestEntry extends StatelessWidget {
  const _BestEntry({
    required this.mode,
    required this.wave,
    required this.current,
    required this.compact,
  });

  final Difficulty mode;
  final int wave;
  final bool current;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final motion = context.motion;
    final big = compact ? 30.0 : 38.0;
    final small = compact ? 18.0 : 22.0;
    return Column(
      key: Key('campaign-best-${mode.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedDefaultTextStyle(
          duration: motion.medium,
          curve: motion.enter,
          style: BarrageType.display.copyWith(
            color: current ? tokens.primaryDeep : tokens.inkMuted,
            fontSize: current ? big : small,
            height: 1,
          ),
          child: Text(
            '$wave',
            key: current ? const Key('campaign-best-wave') : null,
          ),
        ),
        SizedBox(height: tokens.space.xs / 2),
        AnimatedContainer(
          duration: motion.medium,
          curve: motion.enter,
          padding: EdgeInsets.symmetric(
            horizontal: tokens.space.xs + 2,
            vertical: 1,
          ),
          decoration: BoxDecoration(
            color: current ? tokens.primary : const Color(0x00000000),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            mode.label.toUpperCase(),
            style: BarrageType.overline.copyWith(
              fontSize: 10,
              color: current ? tokens.onPrimary : tokens.inkMuted,
            ),
          ),
        ),
      ],
    );
  }
}

/// Big tappable play card for one [PlayMode]. Arcade is the blue primary;
/// Campaign is the cream secondary with a blue Play pill.
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.wallet,
    required this.difficulty,
    required this.primary,
    required this.compact,
    required this.wide,
    required this.onTap,
  });

  final PlayMode mode;
  final MetaState wallet;
  final Difficulty difficulty;
  final bool primary;
  final bool compact;
  final bool wide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final ink = primary ? tokens.onPrimary : tokens.ink;
    final soft = primary
        ? tokens.onPrimary.withValues(alpha: 0.82)
        : tokens.inkMuted;
    final titleSize = compact ? 22.0 : (wide ? 34.0 : 26.0);
    final icon = switch (mode) {
      PlayMode.arcade => Icons.bolt_rounded,
      PlayMode.campaign => Icons.flag_rounded,
    };
    final playPill = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? tokens.space.md : tokens.space.lg,
        vertical: compact ? tokens.space.sm : tokens.space.md,
      ),
      decoration: BoxDecoration(
        color: primary ? tokens.surface : null,
        gradient: primary ? null : tokens.primaryGradient,
        borderRadius: BorderRadius.circular(999),
        boxShadow: primary ? tokens.shadowSoft : tokens.shadowPrimary,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_arrow_rounded,
            size: compact ? 22 : 28,
            color: primary ? tokens.primaryDeep : tokens.onPrimary,
          ),
          const SizedBox(width: 2),
          Text(
            'Play',
            style: BarrageType.button.copyWith(
              fontSize: compact ? 16 : 20,
              color: primary ? tokens.primaryDeep : tokens.onPrimary,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      label: 'Play ${mode.label}',
      child: PressScale(
        key: Key('play-${mode.name}'),
        pressedScale: 0.97,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: primary ? tokens.primaryGradient : null,
            color: primary ? null : tokens.surface.withValues(alpha: 0.96),
            borderRadius: tokens.radii.cardAll,
            border: Border.all(
              color: primary
                  ? const Color(0x33FFFFFF)
                  : tokens.primary.withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: primary ? tokens.shadowPrimary : tokens.shadowSoft,
          ),
          padding: EdgeInsets.fromLTRB(
            compact ? tokens.space.md : tokens.space.xl,
            compact ? tokens.space.sm : tokens.space.lg,
            compact ? tokens.space.md : tokens.space.lg,
            compact ? tokens.space.sm : tokens.space.lg,
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 40 : 56,
                height: compact ? 40 : 56,
                decoration: BoxDecoration(
                  color: primary ? const Color(0x2EFFFFFF) : tokens.ownedTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: compact ? 24 : 32,
                  color: primary ? tokens.onPrimary : tokens.primary,
                ),
              ),
              SizedBox(width: compact ? tokens.space.md : tokens.space.lg),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BarrageType.title.copyWith(
                        fontSize: titleSize,
                        color: ink,
                        height: 1.05,
                      ),
                    ),
                    SizedBox(height: tokens.space.xs),
                    Text(
                      mode.blurb,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: BarrageType.body.copyWith(
                        fontSize: compact ? 13 : (wide ? 17 : 15),
                        color: ink,
                      ),
                    ),
                    SizedBox(height: tokens.space.xs),
                    Text(
                      // The lit difficulty pill says which mode this is.
                      '${wallet.coins} coins · best wave '
                      '${wallet.bestWaveFor(difficulty)}',
                      key: Key('${mode.name}-wallet'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BarrageType.muted.copyWith(
                        color: soft,
                        fontSize: compact ? 12 : 14,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: tokens.space.sm),
              playPill,
            ],
          ),
        ),
      ),
    );
  }
}
