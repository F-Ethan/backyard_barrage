import 'dart:ui' as ui;

import 'package:backyard_barrage/game/arena_grid.dart';
import 'package:backyard_barrage/game/components/fort_component.dart';
import 'package:backyard_barrage/game/components/kid_component.dart';
import 'package:backyard_barrage/game/components/lob_projectile.dart';
import 'package:backyard_barrage/game/throw_physics.dart';
import 'package:backyard_barrage/meta/difficulty.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Sprite sprite;

  setUpAll(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 4, 4),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    final image = await recorder.endRecording().toImage(4, 4);
    sprite = Sprite(image);
  });

  test('a scripted miss arches, then splats on the ground once', () {
    final lane = ArenaGrid.laneY(4);
    final origin = Vector2(220, lane);
    var splats = 0;
    Vector2? splatAt;
    final shot = LobProjectile(
      sprite: sprite,
      position: origin.clone(),
      velocity: Vector2(ThrowPhysics.playerTravelSpeed, 0),
      targets: <KidComponent>[],
      onHit: (_, _) {},
      onGround: (lob) {
        splats += 1;
        splatAt = lob.position.clone();
      },
      scripted: true,
      travelSpeed: ThrowPhysics.playerTravelSpeed,
      flightRange: 360,
      throwerRow: 4,
      throwerColumn: 2,
      landingRow: 4,
      landingY: lane,
      apexY: lane - ThrowPhysics.playerLoft,
      apexFraction: ThrowPhysics.playerApexFraction,
      settleFraction: ThrowPhysics.playerSettleFraction,
    );

    var sawArch = false;
    for (var i = 0; i < 180 && splats == 0; i++) {
      shot.update(1 / 60);
      if (shot.hitPosition.x > origin.x + 140 &&
          shot.hitPosition.x < origin.x + 300 &&
          shot.position.y < shot.hitPosition.y - 24) {
        sawArch = true;
      }
    }

    expect(sawArch, isTrue);
    expect(splats, 1);
    final ground = ThrowPhysics.impactGroundY(4);
    expect(splatAt!.y, closeTo(ground, 1));
    expect(splatAt!.x, greaterThan(origin.x + 300));
    expect(splatAt!.x, lessThan(origin.x + 360 + 80));
    shot.update(1 / 60);
    expect(splats, 1);
  });

  test(
    'a fast miss still splats on the ground instead of vanishing in the air',
    () {
      final lane = ArenaGrid.laneY(3);
      var splats = 0;
      Vector2? splatAt;
      final shot = LobProjectile(
        sprite: sprite,
        position: Vector2(1100, lane),
        velocity: Vector2(-2400, -40),
        targets: <KidComponent>[],
        onHit: (_, _) {},
        onGround: (lob) {
          splats += 1;
          splatAt = lob.position.clone();
        },
        flightRange: 900,
        throwerRow: 3,
        landingRow: 3,
        landingY: lane,
      );

      for (var i = 0; i < 240 && splats == 0; i++) {
        shot.update(1 / 60);
      }

      expect(splats, 1);
      expect(splatAt!.y, closeTo(ThrowPhysics.impactGroundY(3), 1));
      expect(splatAt!.y, greaterThan(lane));
    },
  );

  test(
    'Hard chips a full lob into your own fort; Easy and Normal clear it',
    () {
      final poses = KidPoseSprites(
        idle: sprite,
        walk: sprite,
        charge: sprite,
        throwPose: sprite,
        hit: sprite,
        ko: sprite,
        pickup: sprite,
        turnBack: sprite,
        turnQuarter: sprite,
        turnFront: sprite,
      );
      final kid = KidComponent(
        side: KidSide.player,
        poses: poses,
        position: ArenaGrid.cellCenter(KidSide.player, 0, ArenaGrid.coverRow),
        size: Vector2.all(ArenaGrid.kidSize),
      );
      final fort = FortComponent(
        side: KidSide.player,
        sprite: sprite,
        position: ArenaGrid.fortAnchor(),
        size: ArenaGrid.fortDrawSize,
      );
      fort.placeOnRow(ArenaGrid.coverRow);
      final lob = ThrowPhysics.planPlayerLob(
        throwerRow: ArenaGrid.coverRow,
        throwerColumn: 0,
        aimDirection: Vector2(1, 0),
        charge: 1,
        facingRight: true,
        originY: kid.throwOrigin.y,
      );
      expect(
        ThrowPhysics.peaksPastFort(
          apexX: lob.apexWorldX(kid.throwOrigin.x),
          footprint: fort.footprint,
          facingRight: true,
        ),
        isTrue,
      );

      for (final difficulty in [
        Difficulty.easy,
        Difficulty.normal,
        Difficulty.hard,
      ]) {
        final chip = DifficultyTuning.of(difficulty).friendlyFortDamage;
        final before = fort.hp;
        var fortHits = 0;
        final shot = LobProjectile(
          sprite: sprite,
          position: kid.throwOrigin.clone(),
          velocity: lob.velocity.clone(),
          targets: <KidComponent>[],
          owner: kid,
          blockedByFort: true,
          forts: [fort],
          friendlyFortDamage: chip,
          groundTrack: lob.groundTrack,
          throwerRow: lob.throwerRow,
          throwerColumn: lob.throwerColumn,
          peakRow: lob.peakRow,
          landingRow: lob.landingRow,
          apexRise: lob.apexRise,
          landingDrop: lob.landingDrop,
          launchVy: lob.velocity.y,
          travelSpeed: lob.travelSpeed,
          flightRange: lob.range,
          apexFraction: lob.apexFraction,
          settleFraction: lob.settleFraction,
          landingY: lob.landingY,
          apexY: lob.apexY,
          onHit: (_, _) {},
          onFortHit: (hit) {
            fortHits += 1;
            if (hit.fortDamage) fort.takeHit();
          },
        );
        for (
          var i = 0;
          i < 40 && shot.hitPosition.x < fort.footprint.right + 30;
          i++
        ) {
          shot.update(1 / 60);
        }
        if (difficulty == Difficulty.hard) {
          expect(chip, isTrue);
          expect(fortHits, 1);
          expect(shot.fortDamage, isTrue);
          expect(shot.struckFort, fort);
          expect(fort.hp, before - 1);
        } else {
          expect(chip, isFalse);
          expect(fortHits, 0);
          expect(shot.fortDamage, isFalse);
          expect(shot.struckFort, isNull);
          expect(shot.hitPosition.x, greaterThan(fort.footprint.right));
          expect(fort.hp, before);
        }
      }
    },
  );

  test('a snowball over a hit box paints behind the kid', () {
    final poses = KidPoseSprites(
      idle: sprite,
      walk: sprite,
      charge: sprite,
      throwPose: sprite,
      hit: sprite,
      ko: sprite,
      pickup: sprite,
      turnBack: sprite,
      turnQuarter: sprite,
      turnFront: sprite,
    );
    final kid = KidComponent(
      side: KidSide.enemy,
      poses: poses,
      position: ArenaGrid.cellCenter(KidSide.enemy, 2, 4),
      size: Vector2.all(ArenaGrid.kidSize),
    );
    expect(kid.priority, ArenaGrid.depthOrder(kid.hitCenter.y));
    expect(kid.anchor, Anchor.bottomCenter);
    final hitRadius = kid.hitRadius;

    kid.position = ArenaGrid.cellCenter(KidSide.enemy, 2, 0);
    kid.syncDepth();
    expect(kid.scale.x, closeTo(ArenaGrid.depthScaleFar, 0.001));
    expect(kid.scale.y, kid.scale.x);
    expect(kid.hitRadius, hitRadius);

    kid.position = ArenaGrid.cellCenter(KidSide.enemy, 2, ArenaGrid.rows - 1);
    kid.syncDepth();
    expect(kid.scale.x, closeTo(ArenaGrid.depthScaleNear, 0.001));
    expect(kid.scale.y, kid.scale.x);
    expect(kid.hitRadius, hitRadius);

    kid.position = ArenaGrid.cellCenter(KidSide.enemy, 2, 4);
    kid.syncDepth();

    LobProjectile shotAt(double depth) {
      return LobProjectile(
        sprite: sprite,
        position: Vector2(180, depth),
        velocity: Vector2(500, 0),
        targets: [kid],
        onHit: (_, _) {},
        groundTrack: true,
        travelSpeed: 500,
        flightRange: 900,
        landingY: depth,
        throwerRow: 4,
        landingRow: 4,
      );
    }

    final over = shotAt(kid.hitCenter.y - 36);
    over.update(1 / 60);
    expect(over.priority, lessThan(kid.priority));
    expect(over.priority, ArenaGrid.depthOrder(over.hitPosition.y));
    expect(over.scale.x, over.scale.y);
    expect(over.radius, 22);
    expect(
      over.scale.x,
      closeTo(
        ArenaGrid.depthScale(over.hitPosition.y, groundTrack: true),
        0.001,
      ),
    );

    final farShot = shotAt(ArenaGrid.laneY(0));
    expect(farShot.scale.x, closeTo(ArenaGrid.depthScaleFar, 0.001));
    final nearShot = shotAt(ArenaGrid.laneY(ArenaGrid.rows - 1));
    expect(nearShot.scale.x, closeTo(ArenaGrid.depthScaleNear, 0.001));

    final under = shotAt(kid.hitCenter.y + 36);
    under.update(1 / 60);
    expect(under.priority, greaterThan(kid.priority));
    expect(under.priority, ArenaGrid.depthOrder(under.hitPosition.y));
  });
}
