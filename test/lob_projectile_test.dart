import 'dart:ui' as ui;

import 'package:backyard_barrage/game/arena_grid.dart';
import 'package:backyard_barrage/game/components/kid_component.dart';
import 'package:backyard_barrage/game/components/lob_projectile.dart';
import 'package:backyard_barrage/game/throw_physics.dart';
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

  test('a fast miss still splats on the ground instead of vanishing in the air', () {
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
  });
}
