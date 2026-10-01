import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/backyard_barrage_game.dart';

class BackyardBarrageApp extends StatelessWidget {
  const BackyardBarrageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Backyard Barrage',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final BackyardBarrageGame _game;

  @override
  void initState() {
    super.initState();
    _game = BackyardBarrageGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget<BackyardBarrageGame>(game: _game),
    );
  }
}
