import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'ads/end_ad.dart';
import 'ads/remove_ads.dart';
import 'feel/feel_bus.dart';
import 'game/backyard_barrage_game.dart';
import 'meta/meta_state.dart';
import 'meta/play_mode.dart';
import 'meta/save_store.dart';
import 'meta/settings_store.dart';
import 'ui/barrage_theme.dart';
import 'ui/defeat_overlay.dart';
import 'ui/main_menu.dart';
import 'ui/match_hud.dart';
import 'ui/pause_overlay.dart';
import 'ui/settings_panel.dart';
import 'ui/shop_overlay.dart';
import 'ui/wave_report.dart';

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
  late final ThemeData _theme = BarrageTheme.light();
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
      theme: _theme,
      home: Builder(
        builder: (context) {
          final motion = context.motion;
          final Widget screen = running == null
              ? MainMenu(
                  key: const ValueKey('menu'),
                  saveStore: _store,
                  settingsStore: _settingsStore,
                  feel: _feel,
                  onPlay: (meta) => setState(() => _running = meta),
                  onAdPrivacy: widget.endAd.showPrivacyOptions,
                  removeAds: _removeAds,
                )
              : GameScreen(
                  key: ObjectKey(running),
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
                );
          if (motion.reduced) return screen;
          // Fade-through: the old screen fades out quickly, the new one
          // fades and settles up from 96% scale.
          return AnimatedSwitcher(
            duration: motion.slow,
            reverseDuration: motion.fast,
            switchInCurve: motion.enter,
            switchOutCurve: motion.exit,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween(begin: 0.96, end: 1.0).animate(animation),
                child: child,
              ),
            ),
            child: screen,
          );
        },
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

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final BackyardBarrageGame game;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive ||
          AppLifecycleState.hidden ||
          AppLifecycleState.paused ||
          AppLifecycleState.detached:
        game.onAppBackgrounded();
      case AppLifecycleState.resumed:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) game.onBackPressed();
      },
      child: Scaffold(
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
              onNewGame: game.meta.mode == PlayMode.campaign
                  ? game.startNewGame
                  : null,
            ),
            'report': (context, game) => WaveReport(game: game),
            'shop': (context, game) => ShopOverlay(game: game),
            'defeat': (context, game) => DefeatOverlay(game: game),
          },
        ),
      ),
    );
  }
}
