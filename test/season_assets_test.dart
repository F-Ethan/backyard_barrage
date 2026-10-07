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

  test('player winter throw stays on the 2D draft', () {
    expect(
      SeasonAssets.pose(player: true, season: Season.winter, pose: 'throw'),
      'characters/player/player_throw_winter_draft.png',
    );
    expect(
      SeasonAssets.pose(player: true, season: Season.winter, pose: 'idle'),
      'characters/player/player_idle_winter_draft.png',
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
