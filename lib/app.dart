import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'ads/end_ad.dart';
import 'ads/remove_ads.dart';
import 'feel/feel_bus.dart';
import 'game/backyard_barrage_game.dart';
import 'meta/meta_state.dart';
import 'meta/save_store.dart';
import 'meta/settings_store.dart';
import 'ui/barrage_colors.dart';
import 'ui/defeat_overlay.dart';
import 'ui/ui_kit.dart';
import 'ui/main_menu.dart';
import 'ui/match_hud.dart';
import 'ui/pause_overlay.dart';
import 'ui/settings_panel.dart';
import 'ui/shop_overlay.dart';

class BackyardBarrageApp extends StatefulWidget {
  const BackyardBarrageApp({
    super.key,
    this.saveStore,
    this.settingsStore,
    this.feel,
    this.endAd = const NoEndAd(),
    this.removeAds,
  });

  final SaveStore? saveStore;
  final SettingsStore? settingsStore;
  final FeelBus? feel;
  final EndAd endAd;
  final RemoveAdsController? removeAds;

  @override
  State<BackyardBarrageApp> createState() => _BackyardBarrageAppState();
}

class _BackyardBarrageAppState extends State<BackyardBarrageApp> {
  late final SaveStore _store = widget.saveStore ?? SaveStore();
  late final SettingsStore _settingsStore =
      widget.settingsStore ?? SettingsStore();
  late final FeelBus _feel = widget.feel ?? FeelBus();
  late final RemoveAdsController _removeAds =
      widget.removeAds ?? RemoveAdsController();
  MetaState? _running;

  @override
  void initState() {
    super.initState();
    unawaited(_bootAds());
  }

  Future<void> _bootAds() async {
    await _removeAds.prepare();
    if (!mounted) return;
    await widget.endAd.prepare();
  }

  @override
  void dispose() {
    if (widget.removeAds == null) _removeAds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final running = _running;
    return MaterialApp(
      title: 'Backyard Barrage',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: BarrageColors.player,
              brightness: Brightness.light,
            ).copyWith(
              primary: BarrageColors.player,
              onPrimary: BarrageColors.onPrimary,
              surface: BarrageColors.cream,
              onSurface: BarrageColors.ink,
            ),
        scaffoldBackgroundColor: BarrageColors.cream,
        textTheme: Typography.material2021().black.apply(
          bodyColor: BarrageColors.ink,
          displayColor: BarrageColors.ink,
        ),
        useMaterial3: true,
      ),
      home: UiKitScope(
        settings: _feel.settingsListenable,
        child: running == null
            ? MainMenu(
                saveStore: _store,
                settingsStore: _settingsStore,
                feel: _feel,
                onPlay: (meta) => setState(() => _running = meta),
                onAdPrivacy: widget.endAd.showPrivacyOptions,
                removeAds: _removeAds,
              )
            : GameScreen(
                meta: running,
                saveStore: _store,
                settingsStore: _settingsStore,
                feel: _feel,
                endAd: widget.endAd,
                onAdPrivacy: widget.endAd.showPrivacyOptions,
                removeAds: _removeAds,
                adsRemoved: () => _removeAds.owned,
                onExit: () {
                  unawaited(_feel.enterMenu());
                  setState(() => _running = null);
                },
              ),
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.meta,
    required this.saveStore,
    required this.settingsStore,
    required this.feel,
    required this.onExit,
    this.endAd = const NoEndAd(),
    this.onAdPrivacy,
    this.removeAds,
    this.adsRemoved,
    this.game,
  });

  final MetaState meta;
  final SaveStore saveStore;
  final SettingsStore settingsStore;
  final FeelBus feel;
  final VoidCallback onExit;
  final EndAd endAd;
  final Future<void> Function()? onAdPrivacy;
  final RemoveAdsController? removeAds;
  final bool Function()? adsRemoved;
  final BackyardBarrageGame? game;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final BackyardBarrageGame game;

  @override
  void initState() {
    super.initState();
    game =
        widget.game ??
        BackyardBarrageGame(
          meta: widget.meta,
          saveStore: widget.saveStore,
          settingsStore: widget.settingsStore,
          feel: widget.feel,
          onExitToMenu: widget.onExit,
          endAd: widget.endAd,
          adsRemoved: widget.adsRemoved,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget<BackyardBarrageGame>(
        game: game,
        overlayBuilderMap: {
          'hud': (context, game) => MatchHud(game: game),
          'pause': (context, game) => PauseOverlay(game: game),
          'settings': (context, game) => SettingsOverlay(
            settings: game.feel.settings,
            feel: game.feel,
            onChanged: game.commitSettings,
            onClose: game.closeSettings,
            onAdPrivacy: widget.onAdPrivacy,
            removeAds: widget.removeAds,
          ),
          'shop': (context, game) => ShopOverlay(game: game),
          'defeat': (context, game) => DefeatOverlay(game: game),
        },
      ),
    );
  }
}
