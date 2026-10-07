import 'package:backyard_barrage/game/arena_grid.dart';
import 'package:backyard_barrage/game/rival_type.dart';
import 'package:backyard_barrage/meta/difficulty.dart';
import 'package:backyard_barrage/seasons/season.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RivalRoster', () {
    test('wave 1 is ghosts only on every difficulty', () {
      for (final d in Difficulty.values) {
        expect(RivalRoster.forWave(wave: 1, count: 1, difficulty: d), [
          RivalType.snowGhost,
        ]);
      }
    });

    test('harder modes meet the special rivals sooner', () {
      int firstWave(RivalType type, Difficulty d) {
        for (var wave = 1; wave < 30; wave++) {
          final lineup = RivalRoster.forWave(
            wave: wave,
            count: 5,
            difficulty: d,
          );
          if (lineup.contains(type)) return wave;
        }
        return -1;
      }

      for (final type in [RivalType.frostKid, RivalType.rusher]) {
        expect(
          firstWave(type, Difficulty.hard),
          lessThan(firstWave(type, Difficulty.normal)),
        );
        expect(
          firstWave(type, Difficulty.normal),
          lessThan(firstWave(type, Difficulty.easy)),
        );
      }
    });

    test('slot 0 stays a ghost and the special share keeps growing', () {
      var lastShare = 0;
      for (var wave = 1; wave <= 20; wave++) {
        final lineup = RivalRoster.forWave(
          wave: wave,
          count: 5,
          difficulty: Difficulty.normal,
        );
        expect(lineup, hasLength(5));
        expect(lineup.first, RivalType.snowGhost);
        final share = lineup.where((t) => t != RivalType.snowGhost).length;
        expect(share, greaterThanOrEqualTo(lastShare));
        lastShare = share;
      }
      expect(lastShare, 4, reason: 'long runs keep changing past wave 7');
    });
  });

  group('RivalProfile', () {
    test('frost kid hangs back, aims true, and glints', () {
      final p = RivalProfile.of(RivalType.frostKid);
      expect(p.holdColumn, ArenaGrid.columnsPerSide - 1);
      expect(p.jitterScale, lessThan(1));
      expect(p.windupScale, greaterThan(1));
      expect(p.glint, isTrue);
      expect(p.hitsToKo(1), 1, reason: 'never below one hit');
      expect(p.hitsToKo(3), 2);
    });

    test('rusher holds the front line and throws quick and loose', () {
      final p = RivalProfile.of(RivalType.rusher);
      expect(p.holdColumn, 0);
      expect(p.gapScale, lessThan(1));
      expect(p.jitterScale, greaterThan(1));
    });

    test('ghost is the baseline', () {
      final p = RivalProfile.of(RivalType.snowGhost);
      expect(p.holdColumn, isNull);
      expect(p.hitsToKo(2), 2);
    });
  });

  group('rival art', () {
    test('ghost and frost kid have their own renders; rusher uses 2D', () {
      for (final pose in SeasonAssets.poseNames) {
        expect(
          SeasonAssets.rivalPose(RivalType.snowGhost, pose),
          startsWith('characters/rivals/ghost/'),
        );
        expect(
          SeasonAssets.rivalPose(RivalType.frostKid, pose),
          startsWith('characters/rivals/frostkid/'),
        );
        expect(SeasonAssets.rivalPose(RivalType.rusher, pose), isNull);
      }
    });

    test('rivals charge on their windup so the look never switches', () {
      for (final pose in ['charge', 'turn_30l', 'turn_15r']) {
        expect(
          SeasonAssets.rivalPose(RivalType.frostKid, pose),
          endsWith('frostkid_windup_draft.png'),
        );
        expect(
          SeasonAssets.rivalPose(RivalType.snowGhost, pose),
          endsWith('ghost_windup_draft.png'),
        );
      }
      expect(
        SeasonAssets.crop(SeasonAssets.rivalPose(RivalType.snowGhost, 'idle')!),
        (20.5, 0, 471),
      );
    });
  });
}
