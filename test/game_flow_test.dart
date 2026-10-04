import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:backyard_barrage/app.dart';
import 'package:backyard_barrage/audio/game_audio.dart';
import 'package:backyard_barrage/feel/feel_bus.dart';
import 'package:backyard_barrage/feel/game_haptics.dart';
import 'package:backyard_barrage/game/arena_grid.dart';
import 'package:backyard_barrage/game/backyard_barrage_game.dart';
import 'package:backyard_barrage/game/combat_rules.dart';
import 'package:backyard_barrage/game/components/fort_component.dart';
import 'package:backyard_barrage/game/components/kid_component.dart';
import 'package:backyard_barrage/game/components/lob_projectile.dart';
import 'package:backyard_barrage/game/throw_physics.dart';
import 'package:backyard_barrage/meta/meta_state.dart';
import 'package:backyard_barrage/meta/save_store.dart';
import 'package:backyard_barrage/meta/settings_store.dart';
import 'package:backyard_barrage/seasons/season.dart';
import 'package:backyard_barrage/ui/ui_kit.dart';
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
      for (final stage in [1, 2, 3]) ...[
        'forts/fort_stage_${stage}_draft.png',
        'forts/fort_stage_${stage}_damaged_draft.png',
      ],
      'forts/fort_collapsed_draft.png',
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
        home: UiKitScope(
          settings: feel.settingsListenable,
          child: GameScreen(
            meta: meta,
            saveStore: store,
            settingsStore: settings,
            feel: feel,
            onExit: () {},
            game: game,
          ),
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

  testWidgets('clearing a wave opens the shop and the next wave grows', (
    tester,
  ) async {
    final game = (await boot(tester, MetaState())).game;

    knockOut(game.enemies);
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
    expect(game.meta.coins, 0);
    expect(game.meta.crewSize, 1);
    expect(game.meta.fortStage, 1);
    expect(game.meta.throwRank, 0);
    expect(game.meta.bestWave, 3);
    expect(game.meta.season, Season.summer);
    expect(game.wave, 1);

    game.update(0.7);
    await tester.pump();
    expect(find.byKey(const Key('retry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('retry')));
    await tester.pump();
    expect(game.wave, 1);
    expect(game.players, hasLength(1));
    expect(game.players.single.hp, CombatRules.hitsToKo);
    expect(game.phase, MatchPhase.fight);
    expect(game.enemies, hasLength(2));
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

  testWidgets('right side charges; modern UI glows and classic keeps a bar', (
    tester,
  ) async {
    final game = (await boot(tester, MetaState())).game;
    await tester.pump();
    expect(find.byKey(const Key('charge-zone')), findsOneWidget);
    expect(find.byKey(const Key('move-zone')), findsOneWidget);
    expect(find.byKey(const Key('power-bar')), findsNothing);
    expect(
      find.text('Tap the left side to step  ·  hold the right side to throw'),
      findsOneWidget,
    );

    game.pressChargeZone();
    game.update(0.12);
    await tester.pump();
    expect(game.charge, closeTo(1 / 3, 0.04));
    expect(find.byKey(const Key('charge-glow')), findsOneWidget);

    game.feel.apply(game.feel.settings.copyWith(modernUi: false));
    await tester.pump();
    expect(find.byKey(const Key('power-bar')), findsOneWidget);
    expect(find.byKey(const Key('charge-glow')), findsNothing);

    game.update(0.9);
    expect(game.charge, closeTo(0.5, 0.06));
    game.update(2);
    expect(game.charge, greaterThan(0.98));
    game.releaseChargeZone();
    expect(game.charge, 0);
  });

  testWidgets('a tap steps one row and a hold keeps walking that way', (
    tester,
  ) async {
    final game = (await boot(tester, MetaState(crewSize: 2))).game;
    final kid = game.players.first;
    final start = kid.position.clone();
    final cell = ArenaGrid.nearestCell(KidSide.player, start);
    final below = ArenaGrid.cellCenter(
      KidSide.player,
      cell.column,
      cell.row + 3,
    );

    game.pressMoveZone(below);
    game.releaseMoveZone();
    game.update(0.05);
    final cap = ThrowPhysics.kidMoveSpeed() * 0.05 + 1.5;
    expect((kid.position.y - start.y).abs(), greaterThan(0));
    expect(start.distanceTo(kid.position), lessThanOrEqualTo(cap));
    expect(kid.position.x, closeTo(start.x, 0.5));

    game.update(2);
    final oneRow = ArenaGrid.cellCenter(
      KidSide.player,
      cell.column,
      cell.row + 1,
    );
    expect(kid.position.x, closeTo(oneRow.x, 0.5));
    expect(kid.position.y, closeTo(oneRow.y, 0.5));

    final heldFrom = kid.position.clone();
    game.pressMoveZone(below);
    game.update(0.05);
    game.update(2);
    game.update(2);
    expect(kid.position.y, greaterThan(heldFrom.y + ArenaGrid.rowStep));
    expect(kid.position.y, closeTo(below.y, 0.5));
    game.releaseMoveZone();

    final back = kid.position.clone();
    final backCell = ArenaGrid.nearestCell(KidSide.player, back);
    final ahead = ArenaGrid.cellCenter(
      KidSide.player,
      backCell.column + 2,
      backCell.row,
    );
    game.pressMoveZone(ahead);
    game.releaseMoveZone();
    game.update(0.05);
    game.update(2);
    final oneColumn = ArenaGrid.cellCenter(
      KidSide.player,
      backCell.column + 1,
      backCell.row,
    );
    expect(kid.position.x, closeTo(oneColumn.x, 0.5));
    expect(kid.position.y, closeTo(oneColumn.y, 0.5));
    game.pressMoveZone(ahead);
    game.update(2);
    game.update(2);
    expect(kid.position.x, closeTo(ahead.x, 0.5));
    expect(kid.position.y, closeTo(ahead.y, 0.5));
    game.releaseMoveZone();

    final frozen = kid.position.clone();
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

  testWidgets('rivals take three hits; an ally stun can end on the next hit', (
    tester,
  ) async {
    final game = (await boot(tester, MetaState(crewSize: 2))).game;
    final enemy = game.enemies.first;
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
  });

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
