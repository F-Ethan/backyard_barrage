import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:backyard_barrage/app.dart';
import 'package:backyard_barrage/audio/game_audio.dart';
import 'package:backyard_barrage/feel/feel_bus.dart';
import 'package:backyard_barrage/feel/game_haptics.dart';
import 'package:backyard_barrage/game/backyard_barrage_game.dart';
import 'package:backyard_barrage/game/combat_rules.dart';
import 'package:backyard_barrage/game/throw_physics.dart';
import 'package:backyard_barrage/meta/meta_state.dart';
import 'package:backyard_barrage/meta/save_store.dart';
import 'package:backyard_barrage/meta/settings_store.dart';
import 'package:backyard_barrage/seasons/season.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'recording_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> primeSprites(BackyardBarrageGame game) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 4, 4),
      Paint()..color = const Color(0xFF3D7CFF),
    );
    final image = await recorder.endRecording().toImage(4, 4);
    final paths = <String>[
      for (final season in Season.values) ...[
        SeasonAssets.background(season),
        SeasonAssets.projectile(season),
        SeasonAssets.impact(season),
        for (final player in [true, false])
          for (final pose in SeasonAssets.poseNames)
            SeasonAssets.pose(player: player, season: season, pose: pose),
      ],
      for (final stage in [1, 2, 3]) 'forts/fort_stage_${stage}_draft.png',
      'vfx/charge_glow_draft.png',
      'ui/heart_draft.png',
      'ui/heart_empty_draft.png',
      'ui/coin_draft.png',
      'ui/fort_bar_empty_draft.png',
      'ui/fort_bar_fill_draft.png',
    ];
    for (final path in paths) {
      game.images.add(path, image.clone());
    }
    image.dispose();
  }

  Future<
    ({
      BackyardBarrageGame game,
      SaveStore store,
      RecordingPlayback playback,
      RecordingPulse pulses,
    })
  >
  boot(WidgetTester tester, MetaState meta) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SaveStore(preferences: prefs);
    final settings = SettingsStore(preferences: prefs);
    final playback = RecordingPlayback();
    final pulses = RecordingPulse();
    final feel = FeelBus(
      audio: GameAudio(playback: playback),
      haptics: GameHaptics(pulse: pulses),
    );
    final game = BackyardBarrageGame(
      meta: meta,
      saveStore: store,
      settingsStore: settings,
      feel: feel,
      random: math.Random(1),
    );
    await primeSprites(game);
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          meta: meta,
          saveStore: store,
          settingsStore: settings,
          feel: feel,
          onExit: () {},
          game: game,
        ),
      ),
    );
    for (var i = 0; i < 8 && !game.isLoaded; i++) {
      await tester.pump();
    }
    expect(game.isLoaded, isTrue, reason: 'arena failed to finish loading');
    return (game: game, store: store, playback: playback, pulses: pulses);
  }

  testWidgets('summer crew and fort spawn from the save', (tester) async {
    final booted = await boot(
      tester,
      MetaState(season: Season.summer, crewSize: 2, fortStage: 2, throwRank: 1),
    );
    final game = booted.game;
    expect(game.players, hasLength(2));
    expect(game.enemies, hasLength(2));
    expect(game.fort.stage, 2);
    expect(game.fort.hp, CombatRules.fortMaxHp(2));
    expect(game.players.first.hp, CombatRules.hitsToKo);

    final kid = game.players.first;
    kid.setWalking(true);
    expect(kid.sprite, kid.walkSprite);
    kid.showChargePose();
    expect(kid.sprite, kid.chargeSprite);
  });

  testWidgets('clearing a wave opens the shop and the next wave grows', (
    tester,
  ) async {
    final game = (await boot(tester, MetaState())).game;

    for (final enemy in game.enemies) {
      enemy.takeHit();
      enemy.takeHit();
    }
    game.resolveKnockouts();
    expect(game.phase, MatchPhase.clearing);
    expect(game.meta.coins, MetaState.coinsForWave(1));

    game.update(0.7);
    game.update(0.6);
    await tester.pump();
    expect(find.text('Next wave'), findsOneWidget);
    expect(find.byKey(const Key('buy-throw')), findsOneWidget);

    await tester.tap(find.byKey(const Key('buy-throw')));
    await tester.pump();
    expect(game.meta.throwRank, 1);

    await tester.tap(find.byKey(const Key('next-wave')));
    await tester.pump();
    expect(game.wave, 2);
    expect(game.enemies, hasLength(3));
    expect(game.players.single.hp, CombatRules.hitsToKo);
    expect(game.fort.hp, CombatRules.fortMaxHp(1));
    expect(game.phase, MatchPhase.fight);
  });

  testWidgets('a wiped crew can retry at full HP', (tester) async {
    final game = (await boot(tester, MetaState(crewSize: 1))).game;
    final kid = game.players.single;
    kid.takeHit();
    kid.takeHit();
    game.resolveKnockouts();
    expect(game.phase, MatchPhase.defeat);

    game.update(0.7);
    await tester.pump();
    expect(find.byKey(const Key('retry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('retry')));
    await tester.pump();
    expect(game.wave, 1);
    expect(game.players.single.hp, CombatRules.hitsToKo);
    expect(game.phase, MatchPhase.fight);
    expect(game.enemies, hasLength(2));
  });

  testWidgets('pause freezes the clear timer until resume', (tester) async {
    final game = (await boot(tester, MetaState())).game;
    for (final enemy in game.enemies) {
      enemy.takeHit();
      enemy.takeHit();
    }
    game.resolveKnockouts();
    expect(game.phase, MatchPhase.clearing);

    game.pauseMatch();
    await tester.pump();
    expect(game.phase, MatchPhase.paused);
    expect(game.paused, isTrue);
    expect(find.byKey(const Key('resume-button')), findsOneWidget);

    game.update(5);
    expect(game.phase, MatchPhase.paused);
    expect(find.text('Next wave'), findsNothing);

    await tester.tap(find.byKey(const Key('resume-button')));
    await tester.pump();
    expect(game.phase, MatchPhase.clearing);
    expect(game.paused, isFalse);

    game.update(0.7);
    game.update(0.6);
    await tester.pump();
    expect(find.text('Next wave'), findsOneWidget);
  });

  testWidgets('buying from the shop pulses haptics and plays the coin cue', (
    tester,
  ) async {
    final booted = await boot(tester, MetaState(coins: 40));
    final game = booted.game;
    for (final enemy in game.enemies) {
      enemy.takeHit();
      enemy.takeHit();
    }
    game.resolveKnockouts();
    game.update(0.7);
    game.update(0.6);
    await tester.pump();

    booted.pulses.kinds.clear();
    booted.playback.sfx.clear();
    await tester.tap(find.byKey(const Key('buy-throw')));
    await tester.pump();
    expect(game.meta.throwRank, 1);
    expect(booted.pulses.kinds, ['medium']);
    expect(booted.playback.sfx, contains('sfx/purchase_coin.wav'));
    expect(booted.playback.loops, contains('music/battle_loop_winter.wav'));
  });

  testWidgets('a wide phone fits the full backyard instead of cropping it', (
    tester,
  ) async {
    await _useSurface(tester, const Size(844, 390));
    final game = (await boot(
      tester,
      MetaState(crewSize: 3, throwRank: 5),
    )).game;
    game.wave = 2;
    game.startWave();
    game.updateTree(0);
    _expectFullBackyard(game);
  });

  testWidgets('a taller window still fits the backyard without vertical crop', (
    tester,
  ) async {
    await _useSurface(tester, const Size(900, 600));
    final game = (await boot(
      tester,
      MetaState(crewSize: 3, throwRank: 5),
    )).game;
    game.wave = 2;
    game.startWave();
    game.updateTree(0);
    _expectFullBackyard(game);
  });

  testWidgets('fight HUD stays screen-sized on a short phone', (tester) async {
    await _useSurface(tester, const Size(844, 390));
    final game = (await boot(tester, MetaState(coins: 40, crewSize: 3))).game;
    await tester.pump();
    expect(game.phase, MatchPhase.fight);
    expect(game.overlays.isActive('hud'), isTrue);
    expect(find.byKey(const Key('pause-button')), findsOneWidget);
    expect(find.byKey(const Key('hud-crew')), findsOneWidget);
    expect(find.byKey(const Key('hud-fort')), findsOneWidget);
    expect(find.byKey(const Key('hud-coins')), findsOneWidget);
    expect(find.text('Wave 1'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('hud-coins')),
        matching: find.text('40'),
      ),
      findsOneWidget,
    );
    expect(tester.getSize(find.byKey(const Key('pause-button'))).height, 56);
    expect(
      tester.getSize(find.byKey(const Key('hud-heart-you-0-0'))).width,
      20,
    );
    expect(
      game.world.children.whereType<TextComponent>(),
      isEmpty,
    );

    final before = game.hudRevision.value;
    game.players.first.takeHit();
    game.update(0.016);
    await tester.pump();
    expect(game.hudRevision.value, isNot(before));
    expect(find.byKey(const Key('hud-heart-you-0-1')), findsOneWidget);
  });

  testWidgets('the design resolution fills a 1280x720 window', (tester) async {
    await _useSurface(tester, const Size(1280, 720));
    final game = (await boot(tester, MetaState())).game;
    _expectFullBackyard(game);
    expect(game.camera.viewport.size.x, closeTo(1280, 1));
    expect(game.camera.viewport.size.y, closeTo(720, 1));
  });
}

Future<void> _useSurface(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void _expectFullBackyard(BackyardBarrageGame game) {
  final visible = game.camera.visibleWorldRect;
  expect(visible.left, closeTo(0, 0.5));
  expect(visible.top, closeTo(0, 0.5));
  expect(visible.right, closeTo(BackyardBarrageGame.worldWidth, 0.5));
  expect(visible.bottom, closeTo(BackyardBarrageGame.worldHeight, 0.5));

  final canvas = game.canvasSize;
  final scale = math.min(
    canvas.x / BackyardBarrageGame.worldWidth,
    canvas.y / BackyardBarrageGame.worldHeight,
  );
  final viewport = game.camera.viewport;
  expect(viewport.size.x, closeTo(BackyardBarrageGame.worldWidth * scale, 1));
  expect(viewport.size.y, closeTo(BackyardBarrageGame.worldHeight * scale, 1));

  final barX = (canvas.x - viewport.size.x) / 2;
  final barY = (canvas.y - viewport.size.y) / 2;
  final worldOrigin = game.camera.globalToLocal(Vector2(barX, barY));
  final worldCenter = game.camera.globalToLocal(
    Vector2(canvas.x / 2, canvas.y / 2),
  );
  expect(worldOrigin.x, closeTo(0, 1.5));
  expect(worldOrigin.y, closeTo(0, 1.5));
  expect(worldCenter.x, closeTo(BackyardBarrageGame.worldWidth / 2, 1.5));
  expect(worldCenter.y, closeTo(BackyardBarrageGame.worldHeight / 2, 1.5));

  for (final kid in [...game.players, ...game.enemies]) {
    expect(visible.inflate(1).contains(kid.toAbsoluteRect().topLeft), isTrue);
    expect(
      visible.inflate(1).contains(kid.toAbsoluteRect().bottomRight),
      isTrue,
    );
    expect(game.camera.canSee(kid), isTrue);
  }
  final fort = game.fort.toAbsoluteRect();
  expect(visible.inflate(1).contains(fort.topLeft), isTrue);
  expect(visible.inflate(1).contains(fort.bottomRight), isTrue);

  final kid = game.players.first;
  final velocity = ThrowPhysics.launchVelocity(
    charge: 1,
    aimDirection: Vector2(1, -0.9),
    speedScale: CombatRules.projectileSpeedScale(game.meta.throwRank),
  );
  final apexY =
      kid.throwOrigin.y -
      (velocity.y * velocity.y) / (2 * ThrowPhysics.gravity);
  expect(apexY, greaterThan(visible.top));
  expect(apexY, lessThan(kid.throwOrigin.y));
  expect(visible.contains(Offset(kid.throwOrigin.x, apexY)), isTrue);
  expect(
    visible.contains(Offset(kid.throwOrigin.x, kid.throwOrigin.y)),
    isTrue,
  );
}
