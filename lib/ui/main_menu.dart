import 'package:flutter/material.dart';

import '../meta/meta_state.dart';
import '../meta/save_store.dart';
import '../seasons/season.dart';
import 'barrage_colors.dart';
import 'draft_button.dart';
import 'season_chip.dart';

class MainMenu extends StatefulWidget {
  const MainMenu({
    super.key,
    required this.saveStore,
    required this.onPlay,
  });

  final SaveStore saveStore;
  final ValueChanged<MetaState> onPlay;

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  MetaState? _meta;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await widget.saveStore.load();
    if (!mounted) return;
    setState(() => _meta = loaded);
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

  @override
  Widget build(BuildContext context) {
    final meta = _meta;
    final season = meta?.season ?? Season.winter;
    return Scaffold(
      backgroundColor: season == Season.summer
          ? BarrageColors.summerSky
          : BarrageColors.winterSky,
      body: SafeArea(
        child: meta == null
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/ui/wordmark_backyard_barrage_draft.png',
                      height: 72,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Snowballs & water balloons',
                      style: TextStyle(
                        color: BarrageColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Playing: ${meta.season.label}',
                      key: const Key('season-label'),
                      style: const TextStyle(
                        color: BarrageColors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
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
                      style: const TextStyle(
                        color: BarrageColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Coins ${meta.coins} · Best wave ${meta.bestWave}',
                      style: const TextStyle(
                        color: BarrageColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    DraftImageButton(
                      key: const Key('play-button'),
                      label: 'Play',
                      onPressed: _play,
                    ),
                    const Spacer(),
                  ],
                ),
              ),
      ),
    );
  }
}
