import 'package:backyard_barrage/seasons/season.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('player winter aim sweep uses the 3D pack with sheet charge', () {
    expect(
      SeasonAssets.pose(player: true, season: Season.winter, pose: 'turn_30l'),
      'characters/player/player_turn_30l_winter_3d_v1.png',
    );
    expect(
      SeasonAssets.pose(player: true, season: Season.winter, pose: 'turn_15l'),
      'characters/player/player_turn_15l_winter_3d_v1.png',
    );
    expect(
      SeasonAssets.pose(player: true, season: Season.winter, pose: 'charge'),
      'characters/player/player_charge_winter_3d_from_sheet.png',
    );
    expect(
      SeasonAssets.pose(player: true, season: Season.winter, pose: 'turn_15r'),
      'characters/player/player_turn_15r_winter_3d_v1.png',
    );
    expect(
      SeasonAssets.pose(player: true, season: Season.winter, pose: 'turn_30r'),
      'characters/player/player_turn_30r_winter_3d_v1.png',
    );
  });

  test('hero still is not an aim-sweep frame', () {
    for (final pose in SeasonAssets.poseNames) {
      expect(
        SeasonAssets.pose(player: true, season: Season.winter, pose: pose),
        isNot(contains('player_charge_winter_3d_v1.png')),
      );
    }
  });

  test('every player winter pose is 3D art, never a 2D draft', () {
    for (final pose in SeasonAssets.poseNames) {
      final path = SeasonAssets.pose(
        player: true,
        season: Season.winter,
        pose: pose,
      );
      expect(path, contains('_3d_'), reason: pose);
      expect(SeasonAssets.crop(path), isNotNull, reason: pose);
    }
    expect(SeasonAssets.uprightKo(player: true, season: Season.winter), isTrue);
  });

  test('left-pointing 3D frames mirror so the player faces the rivals', () {
    String path(String pose) =>
        SeasonAssets.pose(player: true, season: Season.winter, pose: pose);
    for (final pose in ['turn_30l', 'turn_15l', 'charge', 'idle', 'throw']) {
      expect(SeasonAssets.mirror(path(pose)), isTrue, reason: pose);
    }
    for (final pose in ['turn_15r', 'turn_30r']) {
      expect(SeasonAssets.mirror(path(pose)), isFalse, reason: pose);
    }
    expect(
      SeasonAssets.mirror(
        SeasonAssets.pose(player: false, season: Season.winter, pose: 'idle'),
      ),
      isFalse,
    );
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
}
