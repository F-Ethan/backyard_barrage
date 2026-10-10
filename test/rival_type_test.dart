import 'dart:math' as math;

import 'package:backyard_barrage/game/arena_grid.dart';
import 'package:backyard_barrage/game/rival_type.dart';
import 'package:backyard_barrage/seasons/season.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RivalRoster', () {
    test('one rival is always a snowman', () {
      for (var seed = 0; seed < 20; seed++) {
        expect(RivalRoster.forWave(count: 1, rng: math.Random(seed)), [
          RivalType.snowGhost,
        ]);
      }
    });

    test('snowman, random special, snowman... for every slot', () {
      for (var seed = 0; seed < 50; seed++) {
        final lineup = RivalRoster.forWave(count: 5, rng: math.Random(seed));
        expect(lineup, hasLength(5));
        for (var i = 0; i < lineup.length; i++) {
          if (i.isEven) {
            expect(lineup[i], RivalType.snowGhost, reason: 'slot $i');
          } else {
            expect(
              RivalRoster.specials,
              contains(lineup[i]),
              reason: 'slot $i',
            );
          }
        }
      }
    });

    test('the special slots are re-rolled and use both specials', () {
      final seen = <RivalType>{};
      final rng = math.Random(7);
      for (var wave = 0; wave < 40; wave++) {
        seen.addAll(RivalRoster.forWave(count: 2, rng: rng).skip(1));
      }
      expect(seen, RivalRoster.specials.toSet());
    });
  });

  group('RivalProfile', () {
    test('frost kid hangs back, aims true, and glints', () {
      final p = RivalProfile.of(RivalType.frostKid);
      expect(p.holdColumn, ArenaGrid.columnsPerSide - 1);
      expect(p.jitterScale, lessThan(1));
      expect(p.windupScale, greaterThan(1));
      expect(p.glint, isTrue);
      expect(p.hitsToKo(1), 1);
      expect(p.hitsToKo(3), 1, reason: 'one snowball on every difficulty');
      expect(p.reaimAt, isNotNull);
      expect(
        p.jitterScale,
        lessThan(RivalProfile.of(RivalType.snowGhost).jitterScale / 2),
      );
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
    test('no rival needs a stand-in tint now', () {
      for (final type in RivalType.values) {
        expect(RivalProfile.of(type).aura, isNull, reason: type.name);
      }
    });

    test('every rival draws from its own renders', () {
      for (final pose in SeasonAssets.poseNames) {
        expect(
          SeasonAssets.rivalPose(RivalType.snowGhost, pose),
          startsWith('characters/rivals/ghost/'),
        );
        expect(
          SeasonAssets.rivalPose(RivalType.frostKid, pose),
          startsWith('characters/rivals/frostkid/'),
        );
        expect(
          SeasonAssets.rivalPose(RivalType.rusher, pose),
          startsWith('characters/rivals/rusher/'),
        );
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
