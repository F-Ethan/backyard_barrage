import 'package:backyard_barrage/seasons/season.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('player winter is Ethan\'s 3D kid, turning with the aim', () {
    String path(String pose) =>
        SeasonAssets.pose(player: true, season: Season.winter, pose: pose);
    const dir = 'characters/player/ethan3d/';
    expect(path('turn_30l'), '${dir}aim_00_profile_512.png');
    expect(path('turn_15l'), '${dir}aim_00_profile_512.png');
    expect(path('charge'), '${dir}aim_01_512.png');
    expect(path('turn_15r'), '${dir}aim_02_512.png');
    expect(path('turn_30r'), '${dir}aim_03_34front_512.png');
    for (final pose in SeasonAssets.poseNames) {
      expect(path(pose), startsWith(dir), reason: pose);
      expect(SeasonAssets.crop(path(pose)), (20.5, 0, 471), reason: pose);
    }
    expect(SeasonAssets.uprightKo(player: true, season: Season.winter), isTrue);
    expect(SeasonAssets.playerDrawScale(Season.winter), greaterThan(1));
  });

  test('player winter runs on a two-frame cycle; others hold one frame', () {
    expect(SeasonAssets.walkCycle(player: true, season: Season.winter), [
      'characters/player/ethan3d/run_00_flipped_512.png',
      'characters/player/ethan3d/run_01_flipped_512.png',
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
}
