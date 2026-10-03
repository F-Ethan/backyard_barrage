import 'package:backyard_barrage/meta/meta_state.dart';
import 'package:backyard_barrage/meta/save_store.dart';
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

    test('a defeat wipe clears the run and keeps season and best wave', () {
      final meta = MetaState(
        coins: 80,
        crewSize: 3,
        fortStage: 3,
        throwRank: 4,
        season: Season.summer,
        bestWave: 6,
      );
      meta.resetRun();
      expect(meta.coins, 0);
      expect(meta.crewSize, 1);
      expect(meta.fortStage, 1);
      expect(meta.throwRank, 0);
      expect(meta.season, Season.summer);
      expect(meta.bestWave, 6);
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
    });
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
