import 'package:flutter/material.dart';

import '../feel/feel_bus.dart';
import '../meta/game_settings.dart';
import '../meta/meta_state.dart';
import '../meta/save_store.dart';
import '../meta/settings_store.dart';
import '../seasons/season.dart';
import 'barrage_colors.dart';
import 'draft_button.dart';
import 'season_chip.dart';
import 'settings_panel.dart';
import 'ui_assets.dart';

class MainMenu extends StatefulWidget {
  const MainMenu({
    super.key,
    required this.saveStore,
    required this.settingsStore,
    required this.feel,
    required this.onPlay,
  });

  final SaveStore saveStore;
  final SettingsStore settingsStore;
  final FeelBus feel;
  final ValueChanged<MetaState> onPlay;

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  MetaState? _meta;
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
    setState(() => _meta = loaded);
    await widget.feel.enterMenu();
  }

  Future<void> _setSeason(Season season) async {
    final meta = _meta;
    if (meta == null || meta.season == season) return;
    setState(() => meta.season = season);
    await widget.saveStore.save(meta);
  }

  Future<void> _play() async {
    final meta = _meta;
    if (meta == null) return;
    await widget.saveStore.save(meta);
    widget.onPlay(meta);
  }

  Future<void> _commitSettings(GameSettings next) async {
    widget.feel.apply(next);
    if (mounted) setState(() {});
    await widget.settingsStore.save(next);
    await widget.feel.syncMusic();
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta;
    final season = meta?.season ?? Season.winter;
    final summer = season == Season.summer;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: summer
                ? const [BarrageColors.summerMint, BarrageColors.cream]
                : const [BarrageColors.winterCool, BarrageColors.cream],
          ),
        ),
        child: Stack(
        children: [
          SafeArea(
            child: meta == null
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: 520,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              UiAssets.wordmark,
                              height: 112,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Snowballs & water balloons',
                              style: BarrageType.body,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Playing: ${meta.season.label}',
                              key: const Key('season-label'),
                              style: BarrageType.heading,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SeasonChip(
                                  key: const Key('season-winter'),
                                  season: Season.winter,
                                  selected: meta.season == Season.winter,
                                  onTap: () => _setSeason(Season.winter),
                                ),
                                const SizedBox(width: 12),
                                SeasonChip(
                                  key: const Key('season-summer'),
                                  season: Season.summer,
                                  selected: meta.season == Season.summer,
                                  onTap: () => _setSeason(Season.summer),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Crew ${meta.crewSize}/${MetaState.maxCrew}'
                              ' · Fort ${meta.fortStage}/${MetaState.maxFortStage}'
                              ' · Throw ${meta.throwRank}/${MetaState.maxThrowRank}',
                              style: BarrageType.muted.copyWith(
                                color: BarrageColors.ink,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Coins ${meta.coins} · Best wave ${meta.bestWave}',
                              style: BarrageType.muted.copyWith(fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            DraftImageButton(
                              key: const Key('play-button'),
                              label: 'Play',
                              onPressed: _play,
                              feel: widget.feel,
                            ),
                            const SizedBox(height: 10),
                            DraftImageButton(
                              key: const Key('menu-settings'),
                              label: 'Settings',
                              asset: UiAssets.secondary,
                              leading: UiAssets.iconSettings,
                              width: 210,
                              height: 64,
                              feel: widget.feel,
                              onPressed: () =>
                                  setState(() => _settingsOpen = true),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          if (_settingsOpen)
            SettingsOverlay(
              settings: widget.feel.settings,
              feel: widget.feel,
              onChanged: _commitSettings,
              onClose: () => setState(() => _settingsOpen = false),
            ),
        ],
        ),
      ),
    );
  }
}
