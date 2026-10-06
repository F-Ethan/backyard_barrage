import 'package:flutter/material.dart';

import '../ads/remove_ads.dart';
import '../feel/feel_bus.dart';
import '../meta/game_settings.dart';
import '../meta/meta_state.dart';
import '../meta/play_mode.dart';
import '../meta/player_save.dart';
import '../meta/save_store.dart';
import '../meta/settings_store.dart';
import '../seasons/season.dart';
import 'barrage_colors.dart';
import 'draft_button.dart';
import 'season_home_backdrop.dart';
import 'settings_panel.dart';
import 'ui_kit.dart';

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

  Future<void> _setSeason(Season season) async {
    final profile = _profile;
    if (profile == null || profile.season == season) return;
    widget.feel.uiTap();
    setState(() {
      profile.season = season;
      profile.arcade.season = season;
      profile.campaign.season = season;
    });
    await widget.saveStore.saveProfile(profile);
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
            child: SeasonHomeBackdrop(
              key: Key('home-backdrop-${season.name}'),
              season: season,
            ),
          ),
          SafeArea(
            child: profile == null
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: 700,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              UiKitScope.of(context).wordmark,
                              height: 76,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Snowballs & water balloons',
                              style: BarrageType.body,
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _CampaignBest(
                                wave: profile.campaign.bestWave,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final mode in PlayMode.values) ...[
                                  if (mode == PlayMode.campaign)
                                    const SizedBox(width: 12),
                                  Expanded(
                                    child: _ModeCard(
                                      mode: mode,
                                      wallet: profile.wallet(mode),
                                      onTap: () => _play(mode),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: const Color(0xE6FFF8F0),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 12),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${season.label} yard',
                                          key: const Key('season-label'),
                                          style: BarrageType.muted.copyWith(
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        _SeasonLink(
                                          key: const Key('season-winter'),
                                          label: 'Winter',
                                          selected: season == Season.winter,
                                          onTap: () =>
                                              _setSeason(Season.winter),
                                        ),
                                        _SeasonLink(
                                          key: const Key('season-summer'),
                                          label: 'Summer',
                                          selected: season == Season.summer,
                                          onTap: () =>
                                              _setSeason(Season.summer),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                DraftImageButton(
                                  key: const Key('menu-settings'),
                                  label: 'Settings',
                                  secondary: true,
                                  leadingKind: UiIconKind.settings,
                                  width: 168,
                                  height: 48,
                                  feel: widget.feel,
                                  onPressed: () =>
                                      setState(() => _settingsOpen = true),
                                ),
                              ],
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
              onAdPrivacy: widget.onAdPrivacy,
              removeAds: widget.removeAds,
            ),
        ],
      ),
    );
  }
}

class _CampaignBest extends StatelessWidget {
  const _CampaignBest({required this.wave});

  final int wave;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE6FFF8F0),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 18, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 46,
              decoration: BoxDecoration(
                color: BarrageColors.blueDeep,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CAMPAIGN BEST',
                  style: BarrageType.muted.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  '$wave',
                  key: const Key('campaign-best-wave'),
                  style: const TextStyle(
                    color: BarrageColors.blueDeep,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.wallet,
    required this.onTap,
  });

  final PlayMode mode;
  final MetaState wallet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BarrageColors.cream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0x241A2332)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('play-${mode.name}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mode.label, style: BarrageType.heading),
              const SizedBox(height: 4),
              Text(
                mode.blurb,
                style: BarrageType.body.copyWith(fontSize: 13, height: 1.25),
              ),
              const SizedBox(height: 8),
              Text(
                '${wallet.coins} coins · best wave ${wallet.bestWave}',
                key: Key('${mode.name}-wallet'),
                style: BarrageType.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeasonLink extends StatelessWidget {
  const _SeasonLink({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? BarrageColors.player : BarrageColors.inkMuted,
            decoration: selected ? TextDecoration.underline : null,
            decorationColor: BarrageColors.player,
          ),
        ),
      ),
    );
  }
}
