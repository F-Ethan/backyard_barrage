import 'package:backyard_barrage/meta/meta_state.dart';
import 'package:backyard_barrage/meta/save_store.dart';
import 'package:backyard_barrage/meta/skill_tree.dart';
import 'package:backyard_barrage/seasons/season.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MetaState', () {
    test('starts with one kid, stage-1 fort, and no throw rank', () {
      final meta = MetaState();
      expect(meta.crewSize, 1);
      expect(meta.fortStage, 1);
      expect(meta.throwRank, 0);
      expect(meta.coins, 0);
      expect(meta.canBuyKid, isFalse);
      expect(meta.canBuyFort, isFalse);
      expect(meta.canBuyThrow, isFalse);
    });

    test('zero coins cannot buy and does not change state', () {
      final meta = MetaState();
      expect(meta.buyExtraKid(), isFalse);
      expect(meta.buyFort(), isFalse);
      expect(meta.buyThrowSpeed(), isFalse);
      expect(meta.crewSize, 1);
      expect(meta.fortStage, 1);
      expect(meta.throwRank, 0);
      expect(meta.coins, 0);
    });

    test('purchases spend coins and stop at the MVP caps', () {
      final meta = MetaState(coins: 500);
      expect(meta.buyExtraKid(), isTrue);
      expect(meta.buyExtraKid(), isTrue);
      expect(meta.buyExtraKid(), isFalse);
      expect(meta.crewSize, MetaState.maxCrew);

      expect(meta.buyFort(), isTrue);
      expect(meta.buyFort(), isTrue);
      expect(meta.buyFort(), isFalse);
      expect(meta.fortStage, MetaState.maxFortStage);

      for (var i = 0; i < MetaState.maxThrowRank; i++) {
        expect(meta.buyThrowSpeed(), isTrue);
      }
      expect(meta.buyThrowSpeed(), isFalse);
      expect(meta.throwRank, MetaState.maxThrowRank);
      expect(meta.coins, greaterThanOrEqualTo(0));
    });

    test('a defeat wipe keeps unspent coins and clears skills', () {
      final meta = MetaState(
        coins: 80,
        crewSize: 3,
        fortStage: 3,
        throwRank: 4,
        season: Season.summer,
        bestWave: 6,
      );
      meta.buy('shield-1');
      meta.resetRun();
      expect(meta.coins, 80 - 36);
      expect(meta.skills, isEmpty);
      expect(meta.crewSize, 1);
      expect(meta.fortStage, 1);
      expect(meta.throwRank, 0);
      expect(meta.shieldCharges, 0);
      expect(meta.season, Season.summer);
      expect(meta.bestWave, 6);
      expect(meta.buyThrowSpeed(), isTrue);
      expect(meta.throwRank, 1);
    });

    test('a node stays locked until its parent is owned', () {
      final meta = MetaState(coins: 500);
      expect(meta.buy('team-3'), isFalse);
      expect(meta.buy('damage-2'), isFalse);
      expect(meta.buy('lanes'), isTrue);
      expect(meta.passesOwnFort, isTrue);
      expect(meta.buy('team-2'), isTrue);
      expect(meta.buy('team-3'), isTrue);
      expect(meta.crewSize, 3);
      expect(meta.stunScaleFor(ally: true), 1);
      expect(meta.buy('poise-1'), isTrue);
      expect(meta.stunScaleFor(ally: true), 0.82);
      expect(meta.stunScaleFor(ally: false), 1);
      expect(meta.hitsFor(manualThrow: true), 1);
      expect(meta.hitsFor(manualThrow: false), 1);
      expect(meta.buy('damage-1'), isTrue);
      expect(meta.hitsFor(manualThrow: true), 2);
      expect(meta.hitsFor(manualThrow: false), 1);
      expect(meta.buy('damage-2'), isTrue);
      expect(meta.hitsFor(manualThrow: true), 3);
      expect(meta.buy('damage-3'), isTrue);
      expect(meta.hitsFor(manualThrow: false), 2);
      expect(meta.blastScale, 1);
      expect(meta.shieldCharges, 0);
    });

    test('the full tree is a long save, not one short run', () {
      final total = SkillTree.nodes.fold<int>(
        0,
        (sum, node) => sum + node.cost,
      );
      expect(total, 2620);
      var waves = 0;
      for (var wave = 1; wave <= 20; wave++) {
        waves += MetaState.coinsForWave(wave);
      }
      expect(waves, 1920);
      expect(waves, lessThan(total));
      expect(MetaState.coinsForWave(1), greaterThanOrEqualTo(16));
    });

    test('wave rewards grow and best wave only moves forward', () {
      expect(MetaState.coinsForWave(2), greaterThan(MetaState.coinsForWave(1)));
      final meta = MetaState();
      meta.noteWaveCleared(2);
      meta.noteWaveCleared(1);
      expect(meta.bestWave, 2);
    });

    test('json round trip clamps junk values', () {
      final restored = MetaState.fromJson({
        'coins': -4,
        'crewSize': 9,
        'fortStage': 0,
        'throwRank': 40,
        'season': 'nope',
        'bestWave': 3,
      });
      expect(restored.coins, 0);
      expect(restored.crewSize, MetaState.maxCrew);
      expect(restored.fortStage, 1);
      expect(restored.throwRank, MetaState.maxThrowRank);
      expect(restored.season, Season.winter);
      expect(restored.bestWave, 3);

      final saved = MetaState(
        coins: 12,
        crewSize: 2,
        fortStage: 3,
        throwRank: 4,
        season: Season.summer,
        bestWave: 6,
      );
      final again = MetaState.fromJson(saved.toJson());
      expect(again.coins, 12);
      expect(again.crewSize, 2);
      expect(again.fortStage, 3);
      expect(again.throwRank, 4);
      expect(again.season, Season.summer);
      expect(again.bestWave, 6);
      expect(again.owns('team-2'), isTrue);
      expect(again.owns('throw-4'), isTrue);
      expect(again.owns('fort-3'), isTrue);
    });

    test(
      'an older save without a skill list restores crew, fort, and throw',
      () {
        final restored = MetaState.fromJson({
          'coins': 15,
          'crewSize': 2,
          'fortStage': 3,
          'throwRank': 2,
          'season': 'summer',
          'bestWave': 4,
        });
        expect(restored.coins, 15);
        expect(restored.crewSize, 2);
        expect(restored.fortStage, 3);
        expect(restored.throwRank, 2);
        expect(restored.owns('team-2'), isTrue);
        expect(restored.owns('team-3'), isFalse);
        expect(restored.owns('fort-hp-1'), isFalse);
      },
    );
  });

  test('save store round trip', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SaveStore(preferences: prefs);
    final state = MetaState(
      coins: 18,
      crewSize: 2,
      fortStage: 2,
      throwRank: 1,
      season: Season.summer,
      bestWave: 4,
    );
    await store.save(state);
    final loaded = await store.load();
    expect(loaded.coins, 18);
    expect(loaded.crewSize, 2);
    expect(loaded.fortStage, 2);
    expect(loaded.throwRank, 1);
    expect(loaded.season, Season.summer);
    expect(loaded.bestWave, 4);
  });
}
