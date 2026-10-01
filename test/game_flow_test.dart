import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:backyard_barrage/app.dart';
import 'package:backyard_barrage/game/backyard_barrage_game.dart';
import 'package:backyard_barrage/game/combat_rules.dart';
import 'package:backyard_barrage/meta/meta_state.dart';
import 'package:backyard_barrage/meta/save_store.dart';
import 'package:backyard_barrage/seasons/season.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<({BackyardBarrageGame game, SaveStore store})> boot(
    WidgetTester tester,
    MetaState meta,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SaveStore(preferences: prefs);
    final game = BackyardBarrageGame(
      meta: meta,
      saveStore: store,
      random: math.Random(1),
    );
    await primeSprites(game);
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          meta: meta,
          saveStore: store,
          onExit: () {},
          game: game,
        ),
      ),
    );
    for (var i = 0; i < 8 && !game.isLoaded; i++) {
      await tester.pump();
    }
    expect(game.isLoaded, isTrue, reason: 'arena failed to finish loading');
    return (game: game, store: store);
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
}