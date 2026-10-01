import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/backyard_barrage_game.dart';
import 'meta/meta_state.dart';
import 'meta/save_store.dart';
import 'ui/defeat_overlay.dart';
import 'ui/main_menu.dart';
import 'ui/shop_overlay.dart';

class BackyardBarrageApp extends StatefulWidget {
  const BackyardBarrageApp({super.key, this.saveStore});

  final SaveStore? saveStore;

  @override
  State<BackyardBarrageApp> createState() => _BackyardBarrageAppState();
}

class _BackyardBarrageAppState extends State<BackyardBarrageApp> {
  late final SaveStore _store = widget.saveStore ?? SaveStore();
  MetaState? _running;

  @override
  Widget build(BuildContext context) {
    final running = _running;
    return MaterialApp(
      title: 'Backyard Barrage',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3D7CFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: running == null
          ? MainMenu(
              saveStore: _store,
              onPlay: (meta) => setState(() => _running = meta),
            )
          : GameScreen(
              meta: running,
              saveStore: _store,
              onExit: () => setState(() => _running = null),
            ),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.meta,
    required this.saveStore,
    required this.onExit,
    this.game,
  });

  final MetaState meta;
  final SaveStore saveStore;
  final VoidCallback onExit;
  final BackyardBarrageGame? game;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final BackyardBarrageGame game;

  @override
  void initState() {
    super.initState();
    game = widget.game ??
        BackyardBarrageGame(
          meta: widget.meta,
          saveStore: widget.saveStore,
          onExitToMenu: widget.onExit,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget<BackyardBarrageGame>(
        game: game,
        overlayBuilderMap: {
          'shop': (context, game) => ShopOverlay(game: game),
          'defeat': (context, game) => DefeatOverlay(game: game),
        },
      ),
    );
  }
}
