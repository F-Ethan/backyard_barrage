import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:backyard_barrage/ads/end_ad.dart';
import 'package:backyard_barrage/app.dart';
import 'package:backyard_barrage/audio/game_audio.dart';
import 'package:backyard_barrage/feel/feel_bus.dart';
import 'package:backyard_barrage/feel/game_haptics.dart';
import 'package:backyard_barrage/game/arena_grid.dart';
import 'package:backyard_barrage/game/backyard_barrage_game.dart';
import 'package:backyard_barrage/game/combat_rules.dart';
import 'package:backyard_barrage/game/components/coin_pop.dart';
import 'package:backyard_barrage/game/components/enemy_controller.dart';
import 'package:backyard_barrage/game/components/fort_component.dart';
import 'package:backyard_barrage/game/components/kid_component.dart';
import 'package:backyard_barrage/game/components/lob_projectile.dart';
import 'package:backyard_barrage/game/components/splash_particles.dart';
import 'package:backyard_barrage/game/rival_type.dart';
import 'package:backyard_barrage/game/throw_physics.dart';
import 'package:backyard_barrage/meta/difficulty.dart';
import 'package:backyard_barrage/meta/meta_state.dart';
import 'package:backyard_barrage/meta/play_mode.dart';
import 'package:backyard_barrage/meta/save_store.dart';
import 'package:backyard_barrage/meta/settings_store.dart';
import 'package:backyard_barrage/meta/skill_tree.dart';
import 'package:backyard_barrage/seasons/arena.dart';
import 'package:backyard_barrage/seasons/season.dart';
import 'package:backyard_barrage/ui/barrage_theme.dart';
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
      for (final type in RivalType.values)
        for (final pose in SeasonAssets.poseNames)
          ?SeasonAssets.rivalPose(type, pose),
      for (final stage in [1, 2, 3]) ...[
        'forts/fort_stage_${stage}_draft.png',
        'forts/fort_stage_${stage}_damaged_draft.png',
      ],
      'forts/fort_collapsed_draft.png',
      for (final arena in Arena.values) arena.background,
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
  boot(
    WidgetTester tester,
    MetaState meta, {
    bool settle = true,
    EndAd endAd = const NoEndAd(),
    bool Function()? adsRemoved,
  }) async {
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
      endAd: endAd,
      adsRemoved: adsRemoved,
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
    if (settle) game.finishEntrance();
    return (game: game, store: store, playback: playback, pulses: pulses);
  }

  testWidgets('summer crew and fort spawn from the save', (tester) async {
    final booted = await boot(
      tester,
      MetaState(season: Season.summer, crewSize: 2, fortStage: 2, throwRank: 1),
    );
    final game = booted.game;
    expect(game.players, hasLength(2));
    expect(game.enemies, hasLength(1));
    expect(game.fort.stage, 2);
    expect(game.fort.hp, CombatRules.fortMaxHp(2));
    expect(game.players.first.hp, CombatRules.hitsToKo);

    final kid = game.players.first;
    expect(kid.selected, isTrue);
    expect(kid.sprite, kid.pickupSprite);
    kid.setWalking(true);
    expect(kid.sprite, kid.walkSprite);
    kid.showChargePose();
    expect(kid.sprite, kid.chargeSprite);
    expect(
      game.fort.coverRow,
      inInclusiveRange(ArenaGrid.fortRowMin, ArenaGrid.fortRowMax),
    );
    expect(
      game.enemyFort.coverRow,
      inInclusiveRange(ArenaGrid.fortRowMin, ArenaGrid.fortRowMax),
    );
    kid.position = ArenaGrid.cellCenter(
      KidSide.player,
      ArenaGrid.coverColumnA,
      game.fort.coverRow,
    );
    expect(game.fort.shelters(kid), isTrue);
    expect(game.players[1].sprite, isNot(game.players[1].pickupSprite));
    expect(game.fort.shelters(game.players[1]), isFalse);
  });

  testWidgets('an end ad shows after the coin beat, then waits three minutes', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 1, 1);
    final ads = _RecordingEndAd();
    final game = (await boot(tester, MetaState(), endAd: ads)).game;
    game.adClock = () => now;
    final before = game.fightSeconds;
    game.update(1.25);
    expect(game.fightSeconds, closeTo(before + 1.25, 0.02));

    knockOut(game.players);
    game.resolveKnockouts();
    expect(game.phase, MatchPhase.defeat);
    expect(game.coinCarryLabel, isNull);
    expect(ads.calls, 0);
    game.update(0.7);
    expect(game.coinCarryLabel, isNotNull);
    expect(ads.calls, 0);
    game.update(1.5);
    expect(game.coinCarryLabel, isNull);
    expect(ads.calls, 1);
    expect(ads.lastSeconds, closeTo(game.fightSeconds, 0.01));

    game.exitToMenu();
    expect(ads.calls, 1);
    await tester.pump();

    game.retryFromDefeat();
    game.finishEntrance();
    knockOut(game.players);
    game.resolveKnockouts();
    game.update(0.7);
    game.update(1.5);
    expect(ads.calls, 1);

    now = now.add(const Duration(minutes: 3));
    game.retryFromDefeat();
    game.finishEntrance();
    knockOut(game.players);
    game.resolveKnockouts();
    game.update(0.7);
    game.update(1.5);
    expect(ads.calls, 2);
  });

  testWidgets('leaving mid-fight does not show an ad', (tester) async {
    final ads = _RecordingEndAd();
    final game = (await boot(tester, MetaState(), endAd: ads)).game;
    game.exitToMenu();
    expect(game.phase, MatchPhase.fight);
    expect(ads.calls, 0);

    game.pauseMatch();
    game.exitToMenu();
    expect(ads.calls, 1);
  });

  testWidgets('remove ads skips the end interstitial', (tester) async {
    final ads = _RecordingEndAd();
    final game = (await boot(
      tester,
      MetaState(),
      endAd: ads,
      adsRemoved: () => true,
    )).game;
    knockOut(game.players);
    game.resolveKnockouts();
    expect(game.phase, MatchPhase.defeat);
    expect(game.coinCarryLabel, isNull);
    expect(ads.calls, 0);
    game.update(0.7);
    expect(game.coinCarryLabel, isNotNull);
    expect(ads.calls, 0);
    game.update(1.5);
    expect(game.coinCarryLabel, isNull);
    expect(ads.calls, 0);

    game.exitToMenu();
    expect(ads.calls, 0);
  });

  testWidgets('a wave-clear shop does not offer an ad', (tester) async {
    final ads = _RecordingEndAd();
    final game = (await boot(tester, MetaState(), endAd: ads)).game;

    for (var cleared = 0; cleared < 3; cleared++) {
      knockOut(game.enemies);
      game.resolveKnockouts();
      game.update(0.7);
      game.update(0.6);
      expect(game.phase, MatchPhase.shop);
      expect(ads.calls, 0);
      game.continueFromShop();
      game.finishEntrance();
    }

    game.pauseMatch();
    expect(game.phase, MatchPhase.paused);
    expect(ads.calls, 0);
    game.exitToMenu();
    expect(ads.calls, 1);
  });

  testWidgets('a missed interstitial does not start the cooldown', (
    tester,
  ) async {
    final ads = _RecordingEndAd()..shown = false;
    final game = (await boot(tester, MetaState(), endAd: ads)).game;

    knockOut(game.players);
    game.resolveKnockouts();
    game.update(0.7);
    game.update(1.5);
    expect(ads.calls, 1);
    await tester.pump();

    ads.shown = true;
    game.retryFromDefeat();
    game.finishEntrance();
    knockOut(game.players);
    game.resolveKnockouts();
    game.update(0.7);
    game.update(1.5);
    expect(ads.calls, 2);
  });

  testWidgets('easy charges twice as fast and halves your stun', (
    tester,
  ) async {
    final game = (await boot(tester, MetaState())).game;
    game.feel.apply(game.feel.settings.copyWith(difficulty: Difficulty.easy));
    final kid = game.players.single;
    game.pressChargeZone();
    game.update(CombatRules.playerChargeSeconds(0) / 2);
    expect(game.chargeListenable.value, 1);

    final rival = game.enemies.single;
    final shot = LobProjectile(
      sprite: kid.sprite!,
      position: kid.position.clone(),
      velocity: Vector2(-1, 0),
      targets: [kid],
      owner: rival,
      onHit: (_, _) {},
    );
    game.applySnowballHit(shot: shot, target: kid);
    expect(
      kid.stunRemaining,
      closeTo(CombatRules.allyStunSeconds * 0.5, 0.001),
    );
  });

  testWidgets('rival hits to KO follow difficulty and allies stay at three', (
    tester,
  ) async {
    final game = (await boot(tester, MetaState())).game;
    expect(
      game.enemies.single.maxHp,
      DifficultyTuning.of(Difficulty.normal).enemyHitsToKo,
    );
    expect(game.players.single.maxHp, CombatRules.hitsToKo);

    for (final difficulty in Difficulty.values) {
      game.feel.apply(game.feel.settings.copyWith(difficulty: difficulty));
      game.startWave();
      game.finishEntrance();
      final hits = DifficultyTuning.of(difficulty).enemyHitsToKo;
      final rival = game.enemies.single;
      expect(rival.maxHp, hits);
      expect(rival.hp, hits);
      expect(game.players.single.maxHp, CombatRules.hitsToKo);
      expect(game.players.single.hp, CombatRules.hitsToKo);
      if (difficulty == Difficulty.easy) {
        rival.takeHit();
        expect(rival.isKo, isTrue);
      }
    }
  });

  testWidgets('difficulty shortens ally stun and leaves rival stun alone', (
    tester,
  ) async {
    final game = (await boot(tester, MetaState())).game;
    game.feel.apply(game.feel.settings.copyWith(difficulty: Difficulty.hard));
    game.startWave();
    game.finishEntrance();
    final kid = game.players.single;
    final rival = game.enemies.single;
    expect(rival.maxHp, 3);

    final rivalShot = LobProjectile(
      sprite: kid.sprite!,
      position: kid.position.clone(),
      velocity: Vector2(-1, 0),
      targets: [kid],
      owner: rival,
      onHit: (_, _) {},
    );
    final allyShot = LobProjectile(
      sprite: kid.sprite!,
      position: rival.position.clone(),
      velocity: Vector2(1, 0),
      targets: [rival],
      owner: kid,
      onHit: (_, _) {},
    );

    for (final difficulty in Difficulty.values) {
      game.feel.apply(game.feel.settings.copyWith(difficulty: difficulty));
      kid.revive();
      game.applySnowballHit(shot: rivalShot, target: kid);
      expect(
        kid.stunRemaining,
        closeTo(
          CombatRules.allyStunSeconds *
              DifficultyTuning.of(difficulty).allyStunScale,
          0.001,
        ),
      );

      rival.revive();
      game.applySnowballHit(shot: allyShot, target: rival);
      expect(rival.isKo, isFalse);
      expect(
        rival.stunRemaining,
        closeTo(CombatRules.enemyBrushOffSeconds, 0.001),
      );
    }
  });

  testWidgets('each wave opens with a Wave N banner during the walk-on', (
    tester,
  ) async {
    final game = (await boot(tester, MetaState(), settle: false)).game;
    expect(game.phase, MatchPhase.entering);
    expect(game.bannerListenable.value?.label, 'Wave 1');
    await tester.pump();
    // The banner is screen-space Flutter text now, not a world component.
    expect(
      tester.widget<Text>(find.byKey(const Key('match-banner-title'))).data,
      'Wave 1',
    );
    expect(game.world.children.whereType<TextComponent>(), isEmpty);

    game.finishEntrance();
    expect(game.phase, MatchPhase.fight);
    game.update(0.016);
    expect(game.bannerListenable.value, isNull);
    await tester.pump();
    expect(find.byKey(const Key('match-banner-title')), findsNothing);

    knockOut(game.enemies);
    game.resolveKnockouts();
    game.update(0.7);
    game.update(0.6);
    game.continueFromShop();
    expect(game.phase, MatchPhase.entering);
    expect(game.wave, 2);
    game.update(0.016);
    expect(game.bannerListenable.value?.label, 'Wave 2');

    game.finishEntrance();
    game.update(0.016);
    expect(game.bannerListenable.value, isNull);
  });

  testWidgets('easy and normal rivals keep the unscaled windup', (
    tester,
  ) async {
    final game = (await boot(tester, MetaState())).game;
    final rival = game.enemies.single;
    final brain = rival.children.whereType<EnemyController>().single;

    game.feel.apply(game.feel.settings.copyWith(difficulty: Difficulty.easy));
    expect(brain.windupSeconds, closeTo(4.5, 0.001));

    game.feel.apply(game.feel.settings.copyWith(difficulty: Difficulty.normal));
    expect(brain.windupSeconds, closeTo(3, 0.001));
  });

  testWidgets('normal fills a charge in two thirds of the hold', (
    tester,
  ) async {
    final game = (await boot(tester, MetaState())).game;
    game.feel.apply(game.feel.settings.copyWith(difficulty: Difficulty.normal));
    game.pressChargeZone();
    game.update(CombatRules.playerChargeSeconds(0) * 2 / 3);
    expect(game.chargeListenable.value, 1);
  });

  testWidgets('clearing a wave opens the shop and the next wave grows', (
    tester,
  ) async {
    final game = (await boot(tester, MetaState())).game;

    expect(game.enemies, hasLength(1));
    knockOut(game.enemies);
    game.resolveKnockouts();
    expect(game.phase, MatchPhase.clearing);
    expect(
      game.meta.coins,
      MetaState.coinsForWave(1) + MetaState.coinsPerKnockout,
    );
    // Every coin earned in the fight also lands on the lifetime score.
    expect(game.meta.score, game.meta.coins);
    expect(game.meta.bestWave, 1);

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
    expect(game.phase, MatchPhase.entering);
    game.finishEntrance();
    expect(game.wave, 2);
    expect(game.enemies, hasLength(2));
    expect(game.players.single.hp, CombatRules.hitsToKo);
    expect(game.fort.hp, CombatRules.fortMaxHp(1));
    expect(game.phase, MatchPhase.fight);

    game.wave = 4;
    game.startWave();
    game.finishEntrance();
    expect(game.enemies, hasLength(3));
    expect(game.enemies.first.maxHp, 2);

    game.wave = 5;
    game.startWave();
    game.finishEntrance();
    expect(game.enemies, hasLength(3));
    expect(game.enemies.first.maxHp, 3);

    game.wave = 6;
    game.startWave();
    game.finishEntrance();
    expect(game.enemies, hasLength(4));

    game.wave = 9;
    game.startWave();
    game.finishEntrance();
    expect(game.enemies, hasLength(5));
    expect(game.enemies.first.maxHp, 3);
    final spots = game.enemies.map((kid) => kid.position.clone()).toList();
    for (var i = 0; i < spots.length; i++) {
      for (var j = i + 1; j < spots.length; j++) {
        expect(spots[i].distanceTo(spots[j]), greaterThan(20));
      }
    }
  });

  test('arena pick covers every map and can skip the current one', () {
    final rng = math.Random(4);
    final seen = {for (var i = 0; i < 40; i++) Arena.pick(rng)};
    expect(seen, Arena.values.toSet());
    for (var i = 0; i < 20; i++) {
      expect(Arena.pick(rng, except: Arena.park), isNot(Arena.park));
    }
    for (final arena in Arena.values) {
      expect(arena.background, startsWith('world/arena_'));
    }
  });

  testWidgets('a run plays on its arena and a retry moves to another', (
    tester,
  ) async {
    final game = (await boot(tester, MetaState())).game;
    final first = game.arena;
    expect(game.backgroundColor(), first.sky);

    knockOut(game.players);
    game.resolveKnockouts();
    game.update(0.7);
    game.update(1.5);
    await tester.pump();
    await tester.tap(find.byKey(const Key('retry')));
    await tester.pump();
    expect(game.arena, isNot(first));
    expect(game.backgroundColor(), game.arena.sky);

    // The map holds from wave to wave inside a run.
    final kept = game.arena;
    game.finishEntrance();
    knockOut(game.enemies);
    game.resolveKnockouts();
    game.update(0.7);
    game.update(0.6);
    await tester.pump();
    await tester.tap(find.text('Next wave'));
    await tester.pump();
    expect(game.wave, 2);
    expect(game.arena, kept);
  });

  testWidgets('a Hard wave mixes rival types and each takes its post', (
    tester,
  ) async {
    final game = (await boot(tester, MetaState())).game;
    game.feel.apply(game.feel.settings.copyWith(difficulty: Difficulty.hard));
    game.wave = 5;
    game.startWave();
    game.finishEntrance();
    final types = [for (final e in game.enemies) game.rivalTypeOf(e)];
    expect(types.first, RivalType.snowGhost);
    expect(types, containsAll([RivalType.frostKid, RivalType.rusher]));
    final base = DifficultyTuning.of(
      Difficulty.hard,
      wave: 5,
      rivalCurve: true,
    ).enemyHitsToKo;
    for (final e in game.enemies) {
      final type = game.rivalTypeOf(e);
      final profile = RivalProfile.of(type);
      expect(e.maxHp, profile.hitsToKo(base), reason: type.name);
      expect(e.glint, profile.glint, reason: type.name);
      final hold = profile.holdColumn;
      if (hold != null) {
        expect(
          ArenaGrid.nearestCell(KidSide.enemy, e.position).column,
          hold,
          reason: '${type.name} walks on to its post',
        );
      }
      final brain = e.children.whereType<EnemyController>().single;
      expect(brain.profile.gapScale, profile.gapScale);
    }
  });

  testWidgets('a wiped crew can retry at full HP', (tester) async {
    final game = (await boot(
      tester,
      MetaState(
        coins: 40,
        crewSize: 2,
        fortStage: 2,
        throwRank: 2,
        bestWave: 3,
        season: Season.summer,
      ),
    )).game;
    expect(game.wave, 1);
    for (final kid in game.players) {
      kid.takeHit();
      kid.takeHit();
    }
    game.resolveKnockouts();
    expect(game.phase, MatchPhase.defeat);
    expect(game.meta.coins, 40);
    expect(game.meta.crewSize, 1);
    expect(game.meta.fortStage, 1);
    expect(game.meta.throwRank, 0);
    expect(game.meta.bestWave, 3);
    expect(game.meta.season, Season.winter);
    expect(game.wave, 1);

    expect(game.carriedCoins, 40);
    expect(game.meta.coins, 40);
    expect(game.coinCarryLabel, isNull);

    game.update(0.7);
    expect(game.coinCarryLabel, 'Carried over 40');
    expect(find.byKey(const Key('retry')), findsNothing);

    game.update(1.5);
    await tester.pump();
    expect(game.coinCarryLabel, isNull);
    expect(find.byKey(const Key('retry')), findsOneWidget);
    expect(
      find.text('Skills reset. Unspent coins carry over.'),
      findsOneWidget,
    );
    // Summer is switched off, so defeat offers no season choice.
    expect(find.byKey(const Key('season-summer')), findsNothing);

    await tester.tap(find.byKey(const Key('retry')));
    await tester.pump();
    expect(game.phase, MatchPhase.entering);
    game.finishEntrance();
    expect(game.wave, 1);
    expect(game.players, hasLength(1));
    expect(game.players.single.hp, CombatRules.hitsToKo);
    expect(game.phase, MatchPhase.fight);
    expect(game.enemies, hasLength(1));
  });

  testWidgets('campaign defeat keeps skills and restarts at wave 1', (
    tester,
  ) async {
    final meta = MetaState(
      mode: PlayMode.campaign,
      coins: 40,
      crewSize: 2,
      fortStage: 2,
      throwRank: 1,
      bestWave: 5,
      season: Season.summer,
    );
    final booted = await boot(tester, meta);
    final game = booted.game;
    await booted.store.save(
      MetaState(
        mode: PlayMode.arcade,
        coins: 77,
        crewSize: 2,
        bestWave: 3,
        season: Season.summer,
      ),
    );

    game.wave = 4;
    knockOut(game.players);
    game.resolveKnockouts();
    expect(game.phase, MatchPhase.defeat);
    expect(game.meta.coins, 40);
    expect(game.meta.crewSize, 2);
    expect(game.meta.fortStage, 2);
    expect(game.meta.throwRank, 1);
    expect(game.meta.bestWave, 5);
    expect(game.wave, 4);

    game.update(0.7);
    game.update(1.5);
    await tester.pump();
    expect(find.text('Skills stay. You restart at wave 1.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('retry')));
    await tester.pump();
    expect(game.phase, MatchPhase.entering);
    game.finishEntrance();
    expect(game.wave, 1);
    expect(game.players, hasLength(2));
    expect(game.players.first.hp, CombatRules.hitsToKo);
    expect(game.players.last.hp, CombatRules.hitsToKo);
    expect(game.fort.stage, 2);
    expect(game.enemies, hasLength(1));

    await game.persist();
    final profile = await SaveStore(
      preferences: await SharedPreferences.getInstance(),
    ).load();
    expect(profile.wallet(PlayMode.arcade, Difficulty.normal).coins, 77);
    expect(profile.wallet(PlayMode.arcade, Difficulty.normal).bestWave, 3);
    expect(
      profile.wallet(PlayMode.arcade, Difficulty.normal).owns('fort-2'),
      isFalse,
    );
    expect(profile.wallet(PlayMode.campaign, Difficulty.normal).coins, 40);
    expect(profile.wallet(PlayMode.campaign, Difficulty.normal).bestWave, 5);
    expect(profile.wallet(PlayMode.campaign, Difficulty.normal).crewSize, 2);
    expect(profile.wallet(PlayMode.campaign, Difficulty.normal).fortStage, 2);
    expect(profile.wallet(PlayMode.campaign, Difficulty.normal).throwRank, 1);
    expect(profile.season, Season.winter);
  });

  testWidgets('coins spent on the defeat skill tree start the next run', (
    tester,
  ) async {
    final game = (await boot(tester, MetaState(coins: 40, crewSize: 2))).game;
    knockOut(game.players);
    game.resolveKnockouts();
    game.update(0.7);
    game.update(1.5);
    await tester.pump();

    await tester.tap(find.byKey(const Key('open-skills')));
    await tester.pump();
    expect(find.byKey(const Key('buy-throw')), findsOneWidget);
    await tester.tap(find.byKey(const Key('buy-throw')));
    await tester.pump();
    expect(game.meta.throwRank, 1);
    expect(game.meta.coins, 24);
    expect(game.wave, 1);

    await tester.tap(find.byKey(const Key('next-wave')));
    await tester.pump();
    expect(find.byKey(const Key('retry')), findsOneWidget);
    expect(game.phase, MatchPhase.defeat);

    await tester.tap(find.byKey(const Key('retry')));
    await tester.pump();
    expect(game.phase, MatchPhase.entering);
    game.finishEntrance();
    expect(game.meta.throwRank, 1);
    expect(game.meta.coins, 24);
    expect(game.meta.crewSize, 1);
    expect(game.players, hasLength(1));
    expect(game.wave, 1);
    expect(game.phase, MatchPhase.fight);
  });

  testWidgets('a shield blocks one hit and a harder throw lands three', (
    tester,
  ) async {
    final game = (await boot(
      tester,
      MetaState(skills: {'shield-1', 'damage-1', 'damage-2'}),
    )).game;
    final kid = game.players.single;
    expect(kid.shieldHits, 1);
    kid.takeHit();
    expect(kid.hp, CombatRules.hitsToKo);
    expect(kid.shieldHits, 0);
    expect(kid.isStunned, isFalse);

    final enemy = game.enemies.first;
    final before = enemy.hp;
    game.applySnowballHit(
      shot: LobProjectile(
        sprite: kid.sprite!,
        position: enemy.position.clone(),
        velocity: Vector2(10, 0),
        targets: [enemy],
        owner: kid,
        manualThrow: true,
        onHit: (_, _) {},
      ),
      target: enemy,
    );
    expect(before, DifficultyTuning.of(Difficulty.normal).enemyHitsToKo);
    expect(enemy.isKo, isTrue);
  });

  testWidgets('the skill tree fits a short phone', (tester) async {
    await _useSurface(tester, const Size(844, 390));
    final game = (await boot(tester, MetaState())).game;
    knockOut(game.enemies);
    game.resolveKnockouts();
    game.update(0.7);
    game.update(0.6);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('buy-throw')), findsOneWidget);
    expect(find.text('Next wave'), findsOneWidget);
    final sheet = tester.getRect(find.byKey(const Key('shop-sheet')));
    final crew = tester.getRect(find.byKey(const Key('skill-group-crew')));
    final fight = tester.getRect(find.byKey(const Key('skill-group-fight')));
    final defense = tester.getRect(
      find.byKey(const Key('skill-group-defense')),
    );
    final branch = tester.getRect(
      find.byKey(const Key('skill-branch-throwSpeed')),
    );
    final node = tester.getRect(find.byKey(const Key('open-throw-1')));
    final child = tester.getRect(find.byKey(const Key('locked-throw-2')));
    final margin = sheet.width * 0.045;
    expect(fight.left, greaterThan(crew.right - 4));
    expect(defense.left, greaterThan(fight.right - 4));
    expect((crew.center.dy - fight.center.dy).abs(), lessThan(8));
    expect(branch.top, greaterThan(fight.bottom));
    expect(branch.right, lessThanOrEqualTo(node.left + 8));
    expect(child.top, greaterThan(node.bottom - 4));
    expect(node.left, greaterThanOrEqualTo(sheet.left + margin));
    expect(node.right, lessThanOrEqualTo(sheet.right - margin));
    expect(branch.left, greaterThanOrEqualTo(sheet.left + margin));
    // The open branch's chain shows once, in the middle. The branch list
    // does not repeat it under the selected tile.
    for (final node in SkillTree.chain(SkillBranch.throwSpeed).take(2)) {
      expect(find.text(node.title), findsOneWidget, reason: node.title);
    }
    // Summer is switched off, so the shop offers no season choice.
    expect(find.byKey(const Key('season-winter')), findsNothing);
    await tester.tap(find.byKey(const Key('skill-group-crew')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('skill-branch-team')));
    await tester.pump();
    expect(find.byKey(const Key('skill-team-2')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('aim stays grey until a second kid is bought', (tester) async {
    await _useSurface(tester, const Size(844, 390));
    final game = (await boot(tester, MetaState(coins: 400))).game;
    knockOut(game.enemies);
    game.resolveKnockouts();
    game.update(0.7);
    game.update(0.6);
    await tester.pump();

    expect(find.byKey(const Key('skill-group-fight')), findsOneWidget);
    expect(find.byKey(const Key('skill-branch-throwSpeed')), findsOneWidget);
    expect(find.text('Aim'), findsNothing);
    expect(find.text('Poise'), findsOneWidget);

    await tester.tap(find.byKey(const Key('skill-group-crew')));
    await tester.pump();
    expect(find.text('Aim'), findsOneWidget);
    expect(find.text('Throw'), findsNothing);
    expect(find.byKey(const Key('skill-branch-team')), findsOneWidget);

    await tester.tap(find.byKey(const Key('skill-branch-aim')));
    await tester.pump();
    expect(find.byKey(const Key('locked-aim-1')), findsOneWidget);
    expect(find.text('Buy a second kid first.'), findsWidgets);
    expect(find.text('Locked'), findsWidgets);
    await tester.tap(find.byKey(const Key('skill-aim-1')));
    await tester.pump();
    expect(game.meta.owns('aim-1'), isFalse);
    expect(game.meta.crewSize, 1);

    await tester.tap(find.byKey(const Key('skill-branch-team')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('skill-team-2')));
    await tester.pump();
    expect(game.meta.crewSize, 2);

    await tester.tap(find.byKey(const Key('skill-branch-aim')));
    await tester.pump();
    expect(find.byKey(const Key('locked-aim-1')), findsNothing);
    expect(find.byKey(const Key('open-aim-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('skill-aim-1')));
    await tester.pump();
    expect(game.meta.owns('aim-1'), isTrue);
    expect(game.meta.allyAimScale, 0.72);
  });

  testWidgets('pause freezes the clear timer until resume', (tester) async {
    final game = (await boot(tester, MetaState())).game;
    knockOut(game.enemies);
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
    knockOut(game.enemies);
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

  testWidgets('with motion on, the shop pops in and a purchase celebrates', (
    tester,
  ) async {
    BarrageMotion.debugDisable = false;
    addTearDown(() => BarrageMotion.debugDisable = true);
    final game = (await boot(tester, MetaState(coins: 40))).game;
    knockOut(game.enemies);
    game.resolveKnockouts();
    await tester.pump();
    // KO! banner is up while the clear timer runs.
    expect(game.bannerListenable.value?.label, 'KO!');
    game.update(0.7);
    game.update(0.6);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Next wave'), findsOneWidget);

    final before = game.meta.coins;
    await tester.tap(find.byKey(const Key('buy-throw')));
    await tester.pump();
    expect(game.meta.throwRank, 1);
    expect(find.byKey(const Key('shop-coin-delta')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(
      find.descendant(
        of: find.byKey(const Key('shop-sheet')),
        matching: find.text('${game.meta.coins}'),
      ),
      findsOneWidget,
    );
    expect(game.meta.coins, lessThan(before));
    expect(tester.takeException(), isNull);
  });

  testWidgets('right side charges and the screen glows', (tester) async {
    final game = (await boot(tester, MetaState())).game;
    // The bell anchors below are the unscaled 3s hold. Hard keeps that hold.
    game.feel.apply(game.feel.settings.copyWith(difficulty: Difficulty.hard));
    await tester.pump();
    expect(find.byKey(const Key('charge-zone')), findsOneWidget);
    expect(find.byKey(const Key('move-zone')), findsOneWidget);
    expect(find.byKey(const Key('power-bar')), findsNothing);
    expect(
      find.text('Drag on the left to move  ·  hold the right side to throw'),
      findsOneWidget,
    );

    game.pressChargeZone();
    game.update(0.12);
    await tester.pump();
    expect(game.charge, greaterThan(1 / 3));
    expect(game.charge, lessThan(0.4));
    expect(find.byKey(const Key('charge-glow')), findsOneWidget);
    expect(find.byKey(const Key('power-bar')), findsNothing);

    game.update(0.9);
    // A steady climb: 1.02s into the 3s rank-0 hold.
    expect(game.charge, closeTo(1 / 3 + 2 / 3 * (1.02 / 3), 0.02));
    game.update(2);
    expect(game.charge, greaterThan(0.98));
    game.releaseChargeZone();
    expect(game.charge, 0);
  });

  testWidgets('a drag on the left follows the finger', (tester) async {
    final game = (await boot(tester, MetaState(crewSize: 2))).game;
    final kid = game.players.first;
    final mate = game.players[1];
    final planted = kid.position.clone();
    game.pressMoveZone(kid.hitCenter);
    game.update(0.3);
    expect(kid.position.x, closeTo(planted.x, 0.5));
    expect(kid.position.y, closeTo(planted.y, 0.5));
    game.releaseMoveZone();

    final before = kid.position.distanceTo(mate.position);
    game.pressMoveZone(kid.position.clone());
    game.dragMoveZone(mate.position.clone());
    game.update(0.8);
    final gap = kid.position.distanceTo(mate.position);
    expect(gap, greaterThanOrEqualTo(BackyardBarrageGame.kidSpacing - 1));
    expect(gap, lessThan(before - 20));
    game.releaseMoveZone();

    final start = kid.position.clone();
    // Open ground inside the home half, farther than the old one-frame step.
    final below = Vector2(start.x, start.y + 80);

    game.pressMoveZone(below);
    game.update(0.05);
    final oldCap = ThrowPhysics.kidMoveSpeed() * 0.05 + 1.5;
    expect(kid.position.y, greaterThan(start.y));
    expect(kid.position.x, closeTo(start.x, 1));
    expect(start.distanceTo(kid.position), greaterThan(oldCap * 2));

    game.update(0.6);
    expect(kid.position.x, closeTo(below.x, 1));
    expect(kid.position.y, closeTo(below.y, 1));

    final corner = ArenaGrid.cellCenter(KidSide.player, 3, 7);
    game.dragMoveZone(corner);
    game.update(1.2);
    final home = ArenaGrid.clampToRect(ArenaGrid.field(KidSide.player), corner);
    expect(kid.position.x, closeTo(home.x, 1.5));
    expect(kid.position.y, closeTo(home.y, 1.5));

    game.releaseMoveZone();
    final stopped = kid.position.clone();
    game.update(0.4);
    expect(kid.position.x, closeTo(stopped.x, 0.5));
    expect(kid.position.y, closeTo(stopped.y, 0.5));

    final frozen = kid.position.clone();
    game.pressMoveZone(start);
    game.pressChargeZone();
    game.update(0.3);
    expect(game.isCharging, isTrue);
    expect(kid.position.x, closeTo(frozen.x, 0.5));
    expect(kid.position.y, closeTo(frozen.y, 0.5));
    game.releaseChargeZone();
    expect(game.charge, 0);
  });

  testWidgets('release during the swivel picks the throw depth', (
    tester,
  ) async {
    final game = (await boot(tester, MetaState())).game;
    final kid = game.players.first;
    final start = kid.position.clone();
    final row = ArenaGrid.nearestCell(KidSide.player, start).row;

    game.pressMoveZone(kid.hitCenter);
    expect(game.isCharging, isFalse);
    expect(game.selectedKid, kid);

    game.pressChargeZone();
    game.update(ThrowPhysics.swivelPeriod / 4);
    expect(game.charge, greaterThan(0.3));
    game.releaseChargeZone();
    expect(game.isCharging, isFalse);
    game.update(0);

    final lob = game.world.children.whereType<LobProjectile>().single;
    expect(lob.groundTrack, isTrue);
    expect(lob.landingRow, lessThan(row));
    expect(kid.angle, closeTo(0, 0.001));
  });

  /// Rivals hold still so aim tests can place them.
  void freezeRivals(BackyardBarrageGame game) {
    for (final enemy in game.enemies) {
      for (final brain in enemy.children.whereType<EnemyController>()) {
        brain.removeFromParent();
      }
    }
    game.update(0);
  }

  testWidgets('the sweep lingers while the line is on a rival', (tester) async {
    final game = (await boot(tester, MetaState())).game;
    freezeRivals(game);
    final kid = game.players.first;
    final rival = game.enemies.first;
    const step = 0.1;
    final free = ThrowPhysics.sweepWave(
      2 * math.pi * step / ThrowPhysics.swivelPeriod,
    );

    // Off the line: the sweep moves at full speed.
    rival.position = Vector2(1000, kid.position.y + ArenaGrid.rowStep * 3);
    game.pressMoveZone(kid.hitCenter);
    game.releaseMoveZone();
    game.pressChargeZone();
    game.update(step);
    final open = ThrowPhysics.aimElevation(
      game.chargeHud.aimDir,
      facingRight: true,
    );
    expect(open, closeTo(free * ThrowPhysics.maxAimRadians, 1e-6));
    game.releaseChargeZone();
    for (final shot in game.world.children.whereType<LobProjectile>()) {
      shot.removeFromParent();
    }
    game.update(0);

    // Dead on the flat line: the sweep slows by the friction factor.
    rival.position = Vector2(1000, kid.position.y);
    game.pressChargeZone();
    game.update(step);
    final sticky = ThrowPhysics.aimElevation(
      game.chargeHud.aimDir,
      facingRight: true,
    );
    expect(sticky.abs(), lessThan(open.abs() * 0.5));
    expect(sticky, greaterThan(0));
  });

  testWidgets('the preview locks a rival only when the throw reaches them', (
    tester,
  ) async {
    final game = (await boot(tester, MetaState())).game;
    freezeRivals(game);
    final kid = game.players.first;
    final rival = game.enemies.first;
    rival.position = Vector2(1000, kid.position.y);
    game.pressMoveZone(kid.hitCenter);
    game.releaseMoveZone();

    game.pressChargeZone();
    game.update(0.01);
    expect(game.aimTarget, isNull, reason: 'a tap falls short');
    expect(game.chargeHud.target, isNull);
    game.releaseChargeZone();
    for (final shot in game.world.children.whereType<LobProjectile>()) {
      shot.removeFromParent();
    }

    final reach = (rival.hitCenter.x - kid.throwOrigin.x) + 10;
    expect(
      ThrowPhysics.rangeForCharge(1),
      greaterThan(reach),
      reason: 'full power reaches the rival',
    );
    expect(
      game.assistedElevation(kid, 0, ThrowPhysics.rangeForCharge(1)),
      closeTo(0, 1e-9),
      reason: 'already on target, no nudge',
    );
  });

  testWidgets('the throw preview thins out on Normal and Hard', (tester) async {
    final booted = await boot(tester, MetaState());
    final game = booted.game;
    freezeRivals(game);
    final kid = game.players.first;
    final rival = game.enemies.first;
    rival.position = Vector2(1000, kid.position.y);
    game.pressMoveZone(kid.hitCenter);
    game.releaseMoveZone();

    Future<void> holdUntilLocked(Difficulty difficulty) async {
      game.feel.apply(game.feel.settings.copyWith(difficulty: difficulty));
      game.pressChargeZone();
      for (var i = 0; i < 300 && game.aimTarget == null; i++) {
        game.update(1 / 60);
      }
      expect(game.aimTarget, rival);
    }

    // Drop the charge without throwing, so no ball ends the wave.
    void letGo() {
      game.pauseMatch();
      game.resumeMatch();
      expect(game.isCharging, isFalse);
    }

    await holdUntilLocked(Difficulty.easy);
    expect(game.chargeHud.showPath, isTrue);
    expect(game.chargeHud.target, isNotNull);
    letGo();

    await holdUntilLocked(Difficulty.normal);
    expect(game.chargeHud.showPath, isTrue);
    expect(game.chargeHud.target, isNull);
    letGo();

    await holdUntilLocked(Difficulty.hard);
    expect(game.chargeHud.showPath, isFalse);
    expect(game.chargeHud.target, isNull);
    letGo();
  });

  testWidgets('the aim line spans the yard from the first frame', (
    tester,
  ) async {
    final game = (await boot(tester, MetaState())).game;
    freezeRivals(game);
    final kid = game.players.first;
    game.pressMoveZone(kid.hitCenter);
    game.releaseMoveZone();
    game.pressChargeZone();
    game.update(1 / 60);
    final hud = game.chargeHud;
    expect(hud.aimEnd!.x, closeTo(ThrowPhysics.yardFarEdge, 0.01));
    expect(hud.trackEnd!.x, lessThan(hud.aimEnd!.x));
  });

  testWidgets('a near miss is nudged onto the rival, a clear miss is not', (
    tester,
  ) async {
    final game = (await boot(tester, MetaState())).game;
    freezeRivals(game);
    final kid = game.players.first;
    final rival = game.enemies.first;
    final window = ArenaGrid.rowStep * ThrowPhysics.depthWindowFraction;
    final range = ThrowPhysics.rangeForCharge(1);
    final start = Vector2(kid.throwOrigin.x, kid.hitCenter.y);

    rival.position = Vector2(1000, kid.position.y + window + 8);
    final nudged = game.assistedElevation(kid, 0, range);
    final miss = ThrowPhysics.trackMiss(
      start: start,
      elevation: nudged,
      range: range,
      facingRight: true,
      target: rival.hitCenter,
    );
    expect(miss!.abs(), lessThan(0.01));

    rival.position = Vector2(
      1000,
      kid.position.y + window + ThrowPhysics.aimAssistPx + 10,
    );
    expect(game.assistedElevation(kid, 0, range), 0);
  });

  /// Throws a full-power flat lob at a rival parked on the line, running
  /// the real game loop. Returns whether hit-stop was ever seen.
  Future<bool> throwAtParkedRival(
    WidgetTester tester,
    BackyardBarrageGame game,
  ) async {
    freezeRivals(game);
    final kid = game.players.first;
    final rival = game.enemies.first;
    rival.position = Vector2(900, kid.position.y);
    rival.syncDepth();
    game.pressMoveZone(kid.hitCenter);
    game.releaseMoveZone();
    game.pressChargeZone();
    for (var i = 0; i < 400 && game.aimTarget == null; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.aimTarget, rival);
    final hpBefore = rival.hp;
    game.releaseChargeZone();
    var sawStop = false;
    for (var i = 0; i < 90 && rival.hp == hpBefore; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    sawStop = game.hitStopRemaining > 0;
    expect(rival.hp, lessThan(hpBefore));
    // Effects added on the hit frame mount on the next one.
    await tester.pump(const Duration(milliseconds: 16));
    return sawStop;
  }

  testWidgets('a landed hit freezes the yard briefly and sprays', (
    tester,
  ) async {
    final game = (await boot(tester, MetaState())).game;
    game.reduceMotion = () => false;
    final stopped = await throwAtParkedRival(tester, game);
    expect(stopped, isTrue);
    expect(game.world.children.whereType<SplashParticles>(), isNotEmpty);
    await tester.pump(const Duration(milliseconds: 400));
    expect(game.hitStopRemaining, lessThanOrEqualTo(0));
    expect(game.camera.viewfinder.position, Vector2.zero());
  });

  testWidgets('reduce motion skips hit-stop and shake', (tester) async {
    final game = (await boot(tester, MetaState())).game;
    game.reduceMotion = () => true;
    final stopped = await throwAtParkedRival(tester, game);
    expect(stopped, isFalse);
    expect(game.camera.viewfinder.position, Vector2.zero());
  });

  testWidgets('a rival knockout floats the coin reward', (tester) async {
    final game = (await boot(tester, MetaState())).game;
    game.reduceMotion = () => true;
    for (final rival in game.enemies) {
      rival.hp = 1;
    }
    await throwAtParkedRival(tester, game);
    expect(game.enemies.first.isKo, isTrue);
    final pop = game.world.children.whereType<CoinPop>().single;
    expect(pop.amount, MetaState.coinsPerKnockout);
  });

  testWidgets('the charge sweep swaps upright yaw poses', (tester) async {
    final game = (await boot(tester, MetaState())).game;
    final kid = game.players.first;
    final enemy = game.enemies.first;
    final period = ThrowPhysics.swivelPeriod;

    // Hold time where the triangle sweep equals [sine], after the up-screen
    // peak and before the down-screen end of the same cycle.
    double holdForSine(double sine) => period * (2 - sine) / 4;

    game.pressChargeZone();
    expect(kid.chargeYaw, ChargeYaw.across);
    expect(kid.sprite, kid.chargeSprite);
    expect(kid.angle, closeTo(0, 0.001));
    expect(kid.scale.x, greaterThan(0));

    var held = 0.0;
    void advanceTo(double t) {
      game.update(t - held);
      held = t;
    }

    advanceTo(period / 4);
    expect(kid.chargeYaw, ChargeYaw.yaw30l);
    expect(kid.sprite, kid.turn30lSprite);
    expect(kid.angle, closeTo(0, 0.001));
    expect(kid.scale.x, greaterThan(0));

    advanceTo(holdForSine(0.4));
    expect(kid.chargeYaw, ChargeYaw.yaw15l);
    expect(kid.sprite, kid.turn15lSprite);

    advanceTo(period / 2);
    expect(kid.chargeYaw, ChargeYaw.across);
    expect(kid.sprite, kid.chargeSprite);

    advanceTo(holdForSine(-0.4));
    expect(kid.chargeYaw, ChargeYaw.yaw15r);
    expect(kid.sprite, kid.turn15rSprite);
    expect(kid.angle, closeTo(0, 0.001));

    advanceTo(holdForSine(-0.8));
    expect(game.isCharging, isTrue);
    expect(kid.chargeYaw, ChargeYaw.yaw30r);
    expect(kid.sprite, kid.turn30rSprite);
    expect(kid.angle, closeTo(0, 0.001));
    expect(kid.scale.x, greaterThan(0));

    // Rivals keep their own art. The sweep does not mirror either side.
    expect(enemy.scale.x, greaterThan(0));
    expect(enemy.angle, closeTo(0, 0.001));
    game.releaseChargeZone();
  });

  testWidgets(
    'hard rivals take three hits; an ally stun can end on the next hit',
    (tester) async {
      final game = (await boot(tester, MetaState(crewSize: 2))).game;
      game.feel.apply(game.feel.settings.copyWith(difficulty: Difficulty.hard));
      game.startWave();
      game.finishEntrance();
      final enemy = game.enemies.first;
      expect(enemy.maxHp, 3);
      enemy.takeHit();
      expect(enemy.isKo, isFalse);
      expect(enemy.isDown, isFalse);
      expect(enemy.isStunned, isTrue);
      expect(
        enemy.stunRemaining,
        closeTo(CombatRules.enemyBrushOffSeconds, 0.001),
      );
      expect(enemy.sprite, enemy.hitSprite);
      game.update(CombatRules.enemyBrushOffSeconds + 0.05);
      expect(enemy.isStunned, isFalse);
      expect(enemy.hp, 2);

      enemy.takeHit();
      expect(enemy.isKo, isFalse);
      expect(enemy.isDown, isTrue);
      expect(enemy.sprite, enemy.koSprite);
      expect(enemy.paint.colorFilter, isNull);
      expect(
        enemy.stunRemaining,
        closeTo(CombatRules.enemyKnockdownSeconds, 0.001),
      );
      game.update(CombatRules.enemyKnockdownSeconds + 0.05);
      expect(enemy.isDown, isFalse);
      expect(enemy.isStunned, isFalse);
      expect(enemy.isKo, isFalse);
      expect(enemy.sprite, isNot(enemy.koSprite));

      enemy.takeHit();
      expect(enemy.isKo, isTrue);
      expect(enemy.sprite, enemy.koSprite);
      expect(enemy.paint.colorFilter, KidComponent.knockoutFilter);

      final ally = game.players[1];
      ally.takeHit();
      expect(ally.isKo, isFalse);
      expect(ally.isFragile, isTrue);
      expect(ally.stunRemaining, closeTo(CombatRules.allyStunSeconds, 0.001));
      ally.takeHit();
      expect(ally.isKo, isTrue);

      final lead = game.players.first;
      lead.takeHit();
      expect(lead.isKo, isFalse);
      expect(lead.isFragile, isTrue);
      game.pressMoveZone(lead.hitCenter);
      game.releaseMoveZone();
      expect(game.selectedKid, lead);
      expect(game.isCharging, isFalse);
      final pos = lead.position.clone();
      final cell = ArenaGrid.nearestCell(KidSide.player, pos);
      game.pressMoveZone(
        ArenaGrid.cellCenter(KidSide.player, cell.column, cell.row + 1),
      );
      game.pressChargeZone();
      expect(game.isCharging, isFalse);
      game.update(0.4);
      expect(lead.position.x, closeTo(pos.x, 0.5));
      expect(lead.position.y, closeTo(pos.y, 0.5));
      game.releaseMoveZone();

      lead.update(CombatRules.allyStunSeconds);
      expect(lead.isStunned, isFalse);
      expect(lead.isFragile, isFalse);
      expect(lead.hp, CombatRules.hitsToKo - 1);
      lead.takeHit();
      expect(lead.isKo, isFalse);
      expect(lead.isFragile, isTrue);
      expect(lead.hp, 1);
    },
  );

  testWidgets('a KO kid is greyed out and a living fort shelters cover', (
    tester,
  ) async {
    final game = (await boot(tester, MetaState(crewSize: 2))).game;
    final down = game.players[1];
    down.takeHit();
    down.takeHit();
    expect(down.isKo, isTrue);
    expect(down.sprite, down.koSprite);
    expect(down.paint.colorFilter, KidComponent.knockoutFilter);
    expect(down.opacity, 1);
    down.update(KidComponent.koFadeDelay - 0.1);
    expect(down.opacity, 1);
    down.update(0.2);
    expect(down.opacity, lessThan(1));
    expect(down.opacity, greaterThan(0));
    down.update(KidComponent.koFadeSeconds);
    expect(down.opacity, 0);
    down.revive();
    expect(down.opacity, 1);
    expect(down.isKo, isFalse);
    down.takeHit();
    down.takeHit();
    expect(down.isKo, isTrue);
    game.debugPointerDown(down.hitCenter);
    expect(game.selectedKid, isNot(down));

    final cover = game.players.first;
    cover.position = ArenaGrid.cellCenter(
      KidSide.player,
      ArenaGrid.coverColumnA,
      game.fort.coverRow,
    );
    expect(game.fort.shelters(cover), isTrue);
    final before = game.fort.hp;
    var hitKid = false;
    var hitFort = false;
    LobProjectile(
      sprite: cover.sprite!,
      position: cover.hitCenter.clone(),
      velocity: Vector2.zero(),
      targets: game.players,
      blockedByFort: true,
      fort: game.fort,
      onHit: (_, _) => hitKid = true,
      onFortHit: (_) {
        hitFort = true;
        game.fort.takeHit();
      },
    ).update(1 / 60);
    expect(hitFort, isTrue);
    expect(hitKid, isFalse);
    expect(cover.hp, CombatRules.hitsToKo);
    expect(game.fort.hp, lessThan(before));
    expect(game.fort.showingDamage, isTrue);

    while (game.fort.hp > 0) {
      game.fort.takeHit();
    }
    expect(game.fort.isCollapsed, isTrue);
    expect(game.fort.shelters(cover), isFalse);

    expect(
      _shotStopped(
        cover: game.fort,
        owner: cover,
        velocity: Vector2(500, 0),
        throwerColumn: 0,
      ),
      isFalse,
    );
    final rival = game.enemies.first;
    expect(
      _shotStopped(
        cover: game.fort,
        owner: rival,
        velocity: Vector2(-500, 0),
        throwerColumn: 3,
      ),
      isFalse,
    );
    while (game.enemyFort.hp > 0) {
      game.enemyFort.takeHit();
    }
    expect(
      _shotStopped(
        cover: game.enemyFort,
        owner: cover,
        velocity: Vector2(500, 0),
        throwerColumn: 0,
      ),
      isFalse,
    );
  });

  testWidgets('a standing fort still blocks and a collapsed one does not', (
    tester,
  ) async {
    final game = (await boot(tester, MetaState())).game;
    final kid = game.players.first;
    expect(
      _shotStopped(
        cover: game.fort,
        owner: kid,
        velocity: Vector2(500, 0),
        throwerColumn: 0,
      ),
      isTrue,
    );
    while (game.fort.hp > 0) {
      game.fort.takeHit();
    }
    expect(game.fort.isCollapsed, isTrue);
    expect(
      _shotStopped(
        cover: game.fort,
        owner: kid,
        velocity: Vector2(500, 0),
        throwerColumn: 0,
      ),
      isFalse,
    );
    expect(
      _shotStopped(
        cover: game.fort,
        owner: game.enemies.first,
        velocity: Vector2(-500, 0),
        throwerColumn: 3,
      ),
      isFalse,
    );
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
    game.finishEntrance();
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
    game.finishEntrance();
    game.updateTree(0);
    _expectFullBackyard(game);
  });

  testWidgets('both crews walk on before the fight takes input', (
    tester,
  ) async {
    final game = (await boot(
      tester,
      MetaState(crewSize: 2),
      settle: false,
    )).game;
    expect(game.phase, MatchPhase.entering);
    expect(game.players.first.sprite, game.players.first.walkSprite);
    expect(game.players.first.position.x, lessThan(0));
    expect(
      game.enemies.first.position.x,
      greaterThan(BackyardBarrageGame.worldWidth),
    );

    final planted = game.players.first.position.clone();
    game.pressChargeZone();
    game.releaseChargeZone();
    game.pressMoveZone(ArenaGrid.slot(KidSide.player, 0));
    game.update(0);
    expect(game.isCharging, isFalse);
    expect(game.players.first.position.x, planted.x);
    expect(game.players.first.position.y, planted.y);

    game.finishEntrance();
    expect(game.phase, MatchPhase.fight);
    final lead = ArenaGrid.slot(KidSide.player, 0);
    final mate = ArenaGrid.slot(KidSide.player, 1);
    final rival = ArenaGrid.slot(KidSide.enemy, 0);
    expect(game.players[0].position.x, closeTo(lead.x, 0.5));
    expect(game.players[0].position.y, closeTo(lead.y, 0.5));
    expect(game.players[1].position.x, closeTo(mate.x, 0.5));
    expect(game.players[1].position.y, closeTo(mate.y, 0.5));
    expect(game.enemies.first.position.x, closeTo(rival.x, 0.5));
    expect(game.enemies.first.position.y, closeTo(rival.y, 0.5));
    expect(game.players.first.sprite, game.players.first.pickupSprite);
    expect(game.enemies.first.sprite, game.enemies.first.idleSprite);

    game.pressChargeZone();
    expect(game.isCharging, isTrue);
  });

  testWidgets('a charge held through the walk-on starts when they arrive', (
    tester,
  ) async {
    final game = (await boot(tester, MetaState(), settle: false)).game;
    expect(game.phase, MatchPhase.entering);
    await tester.pump();
    expect(find.byKey(const Key('charge-zone')), findsOneWidget);

    game.pressChargeZone();
    expect(game.isCharging, isFalse);

    game.finishEntrance();
    expect(game.phase, MatchPhase.fight);
    expect(game.isCharging, isTrue);
    // The walk-on skip advances one 0.25s tick after the charge starts,
    // which is already inside the 15l band.
    expect(game.players.first.chargeYaw, ChargeYaw.yaw15l);
    expect(game.players.first.sprite, game.players.first.turn15lSprite);
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
    expect(game.world.children.whereType<TextComponent>(), isEmpty);

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

class _RecordingEndAd extends EndAd {
  int calls = 0;
  double lastSeconds = 0;
  bool shown = true;

  @override
  Future<bool> onRunEnded({required double fightSeconds}) async {
    calls += 1;
    lastSeconds = fightSeconds;
    return shown;
  }
}

void knockOut(Iterable<KidComponent> kids) {
  for (final kid in kids) {
    var guard = 0;
    while (!kid.isKo && guard < 8) {
      kid.takeHit();
      guard += 1;
    }
    expect(kid.isKo, isTrue);
  }
}

bool _shotStopped({
  required FortComponent cover,
  required KidComponent owner,
  required Vector2 velocity,
  required int throwerColumn,
}) {
  final box = cover.footprint;
  final y = (box.top + box.bottom) / 2;
  final startX = velocity.x < 0 ? box.right + 8 : box.left - 8;
  var stopped = false;
  LobProjectile(
    sprite: owner.sprite!,
    position: Vector2(startX, y),
    velocity: velocity.clone(),
    targets: <KidComponent>[],
    owner: owner,
    blockedByFort: true,
    forts: [cover],
    throwerColumn: throwerColumn,
    throwerRow: cover.coverRow,
    landingRow: cover.coverRow,
    onHit: (_, _) {},
    onFortHit: (_) => stopped = true,
  ).update(0.08);
  return stopped;
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
  final cell = ArenaGrid.nearestCell(kid.side, kid.position);
  final lob = ThrowPhysics.planPlayerLob(
    throwerRow: cell.row,
    throwerColumn: cell.column,
    aimDirection: Vector2(1, 0),
    charge: 1,
    facingRight: true,
    speedScale: CombatRules.projectileSpeedScale(game.meta.throwRank),
    originY: kid.throwOrigin.y,
  );
  final apexY = kid.throwOrigin.y - lob.apexRise;
  expect(apexY, greaterThan(visible.top));
  expect(apexY, lessThan(kid.throwOrigin.y));
  expect(visible.contains(Offset(kid.throwOrigin.x, apexY)), isTrue);
  expect(
    visible.contains(Offset(kid.throwOrigin.x, kid.throwOrigin.y)),
    isTrue,
  );
}
