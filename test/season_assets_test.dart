import 'dart:io';

import 'package:backyard_barrage/game/components/hound_component.dart';
import 'package:backyard_barrage/game/game_art.dart';
import 'package:backyard_barrage/game/rival_type.dart';
import 'package:backyard_barrage/meta/power_up.dart';
import 'package:backyard_barrage/seasons/season.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('player winter is Ethan\'s 3D kid, turning with the aim', () {
    String path(String pose) =>
        SeasonAssets.pose(player: true, season: Season.winter, pose: pose);
    const dir = 'characters/player/ethan3d/';
    expect(path('turn_30l'), '${dir}kid_aim_away_01_512.png');
    expect(path('turn_15l'), '${dir}kid_aim_away_00_512.png');
    expect(path('charge'), '${dir}aim_01_512.png');
    expect(path('turn_15r'), '${dir}aim_02_512.png');
    expect(path('turn_30r'), '${dir}aim_03_34front_512.png');
    for (final pose in SeasonAssets.poseNames) {
      expect(path(pose), startsWith(dir), reason: pose);
      expect(SeasonAssets.crop(path(pose)), (20.5, 0, 471), reason: pose);
    }
    expect(path('idle'), '${dir}kid_idle_512.png');
    expect(path('throw'), '${dir}kid_throw_follow_512.png');
    expect(path('hit'), '${dir}kid_hit_512.png');
    expect(path('ko'), '${dir}kid_ko_512.png');
    expect(
      SeasonAssets.uprightKo(player: true, season: Season.winter),
      isFalse,
      reason: 'the kid has a lying-down KO frame now',
    );
    expect(SeasonAssets.playerDrawScale(Season.winter), greaterThan(1));
  });

  test('player winter runs on a four-frame cycle; others hold one frame', () {
    expect(SeasonAssets.walkCycle(player: true, season: Season.winter), [
      for (final i in ['00', '01', '02', '03'])
        'characters/player/ethan3d/kid_run_${i}_512.png',
    ]);
    expect(
      SeasonAssets.walkCycle(player: false, season: Season.winter),
      isNull,
    );
    expect(SeasonAssets.walkCycle(player: true, season: Season.summer), isNull);
  });

  test('2D drafts use the whole image and their own KO frame', () {
    final draft = SeasonAssets.pose(
      player: false,
      season: Season.winter,
      pose: 'idle',
    );
    expect(SeasonAssets.crop(draft), isNull);
    expect(
      SeasonAssets.uprightKo(player: false, season: Season.winter),
      isFalse,
    );
    expect(
      SeasonAssets.uprightKo(player: true, season: Season.summer),
      isFalse,
    );
  });

  test('summer and enemy aim poses stay on 2D drafts', () {
    const aimPoses = ['turn_30l', 'turn_15l', 'charge', 'turn_15r', 'turn_30r'];
    for (final pose in aimPoses) {
      expect(
        SeasonAssets.pose(player: true, season: Season.summer, pose: pose),
        'characters/player/player_${pose}_summer_draft.png',
      );
      expect(
        SeasonAssets.pose(player: false, season: Season.winter, pose: pose),
        'characters/enemy/enemy_${pose}_winter_draft.png',
      );
      expect(
        SeasonAssets.pose(player: false, season: Season.summer, pose: pose),
        'characters/enemy/enemy_${pose}_summer_draft.png',
      );
    }
  });

  test('every image the game loads is on disk and bundled', () {
    final spec = File('pubspec.yaml').readAsStringSync();
    bool bundled(String path) =>
        spec.contains('- assets/images/$path\n') ||
        spec.contains(
          '- assets/images/${path.substring(0, path.lastIndexOf('/') + 1)}\n',
        );
    final paths = <String>[
      ...GameArt.flameImages,
      for (final item in PowerUp.values) GameArt.powerUp(item),
      GameArt.frostCrust,
      SeasonAssets.projectile(Season.winter),
      ...?SeasonAssets.walkCycle(player: true, season: Season.winter),
      for (final pose in SeasonAssets.poseNames)
        SeasonAssets.pose(player: true, season: Season.winter, pose: pose),
      for (final type in RivalType.values) ...[
        for (final pose in SeasonAssets.poseNames)
          ?SeasonAssets.rivalPose(type, pose),
        ...?SeasonAssets.rivalWalkCycle(type),
      ],
      for (final frame in HoundComponent.frames)
        HoundComponent.framePath(frame),
    ];
    for (final path in paths) {
      expect(File('assets/images/$path').existsSync(), isTrue, reason: path);
      expect(bundled(path), isTrue, reason: '$path is not in pubspec');
    }
  });
}
