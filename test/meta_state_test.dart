import 'dart:convert';

import 'package:backyard_barrage/meta/difficulty.dart';
import 'package:backyard_barrage/meta/meta_state.dart';
import 'package:backyard_barrage/meta/power_up.dart';
import 'package:backyard_barrage/meta/play_mode.dart';
import 'package:backyard_barrage/meta/player_save.dart';
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
      final meta = MetaState(coins: 2000);
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
      expect(meta.coins, 80 - SkillTree.node('shield-1')!.cost);
      expect(meta.skills, isEmpty);
      expect(meta.crewSize, 1);
      expect(meta.fortStage, 1);
      expect(meta.throwRank, 0);
      expect(meta.shieldCharges, 0);
      expect(meta.season, Season.winter);
      expect(meta.bestWave, 6);
      expect(meta.buyThrowSpeed(), isTrue);
      expect(meta.throwRank, 1);
    });

    test('campaign defeat keeps skills, coins, and the best wave', () {
      final meta = MetaState(
        mode: PlayMode.campaign,
        coins: 80,
        crewSize: 3,
        fortStage: 2,
        throwRank: 2,
        season: Season.summer,
        bestWave: 6,
      );
      meta.buy('shield-1');
      meta.resetRun();
      expect(meta.mode, PlayMode.campaign);
      expect(meta.coins, 80 - SkillTree.node('shield-1')!.cost);
      expect(meta.owns('team-2'), isTrue);
      expect(meta.owns('team-3'), isTrue);
      expect(meta.owns('fort-2'), isTrue);
      expect(meta.owns('throw-2'), isTrue);
      expect(meta.owns('shield-1'), isTrue);
      expect(meta.crewSize, 3);
      expect(meta.fortStage, 2);
      expect(meta.throwRank, 2);
      expect(meta.season, Season.winter);
      expect(meta.bestWave, 6);
    });

    test('arcade and campaign wallets do not share coins or skills', () {
      final profile = PlayerSave(
        season: Season.winter,
        wallets: {
          PlayMode.arcade: {
            Difficulty.normal: MetaState(coins: 100, bestWave: 2),
          },
          PlayMode.campaign: {
            Difficulty.normal: MetaState(coins: 100, crewSize: 2, bestWave: 5),
          },
        },
      );
      expect(
        profile.wallet(PlayMode.arcade, Difficulty.normal).buyExtraKid(),
        isTrue,
      );
      profile.wallet(PlayMode.arcade, Difficulty.normal).resetRun();
      expect(
        profile.wallet(PlayMode.arcade, Difficulty.normal).coins,
        100 - SkillTree.node('team-2')!.cost,
      );
      expect(
        profile.wallet(PlayMode.arcade, Difficulty.normal).skills,
        isEmpty,
      );
      expect(profile.wallet(PlayMode.arcade, Difficulty.normal).bestWave, 2);
      expect(profile.wallet(PlayMode.campaign, Difficulty.normal).coins, 100);
      expect(profile.wallet(PlayMode.campaign, Difficulty.normal).crewSize, 2);
      expect(profile.wallet(PlayMode.campaign, Difficulty.normal).bestWave, 5);

      profile.wallet(PlayMode.campaign, Difficulty.normal).noteWaveCleared(7);
      profile.wallet(PlayMode.campaign, Difficulty.normal).resetRun();
      expect(profile.wallet(PlayMode.campaign, Difficulty.normal).bestWave, 7);
      expect(profile.wallet(PlayMode.campaign, Difficulty.normal).crewSize, 2);
      expect(profile.wallet(PlayMode.campaign, Difficulty.normal).coins, 100);
      expect(profile.wallet(PlayMode.arcade, Difficulty.normal).bestWave, 2);
      expect(
        profile.wallet(PlayMode.arcade, Difficulty.normal).coins,
        100 - SkillTree.node('team-2')!.cost,
      );
    });

    test('skill ids and costs stay stable for saves', () {
      expect(
        [for (final node in SkillTree.nodes) '${node.id}:${node.cost}'],
        [
          'team-2:20',
          'team-3:50',
          'mend-1:20',
          'mend-2:50',
          'revive-1:125',
          'fort-2:15',
          'fort-3:40',
          'fort-hp-1:95',
          'fort-hp-2:235',
          'throw-1:10',
          'throw-2:25',
          'throw-3:65',
          'throw-4:155',
          'throw-5:390',
          'poise-1:12',
          'poise-2:30',
          'poise-3:75',
          'poise-4:190',
          'pressure-1:12',
          'pressure-2:30',
          'pressure-3:75',
          'pressure-4:190',
          'aim-1:12',
          'aim-2:30',
          'aim-3:75',
          'react-1:12',
          'react-2:30',
          'react-3:75',
          'charge-1:12',
          'charge-2:30',
          'charge-3:75',
          'shield-1:20',
          'shield-2:50',
          'shield-3:125',
          'lanes:40',
          'blast-1:12',
          'blast-2:30',
          'blast-3:75',
          'blast-4:190',
          'damage-1:25',
          'damage-2:65',
          'damage-3:155',
          'damage-4:390',
        ],
      );
      expect(
        [
          for (final node in SkillTree.nodes)
            if (node.needsTeammate) node.id,
        ],
        [
          'revive-1',
          'aim-1',
          'aim-2',
          'aim-3',
          'react-1',
          'react-2',
          'react-3',
          'charge-1',
          'charge-2',
          'charge-3',
          'damage-3',
          'damage-4',
        ],
      );
    });

    test('branches sit in three shop groups', () {
      expect(SkillGroup.values.map((group) => group.label), [
        'Crew',
        'Fight',
        'Defense',
      ]);
      final seen = <SkillBranch>{};
      for (final group in SkillGroup.values) {
        for (final branch in group.branches) {
          expect(seen.add(branch), isTrue, reason: branch.name);
          expect(SkillGroup.of(branch), group);
        }
      }
      expect(seen, SkillBranch.values.toSet());
    });

    test('teammate skills stay locked until the crew has a second kid', () {
      final solo = MetaState(coins: 900);
      for (final id in ['aim-1', 'react-1', 'charge-1']) {
        expect(solo.skillLock(id), SkillLock.teammate, reason: id);
        expect(solo.lockReason(id), SkillTree.teammateLockReason, reason: id);
        expect(solo.buy(id), isFalse, reason: id);
        expect(solo.owns(id), isFalse, reason: id);
      }
      expect(solo.skillLock('aim-2'), SkillLock.parent);
      expect(solo.lockReason('aim-2'), SkillTree.parentLockReason);
      expect(solo.buy('damage-1'), isTrue);
      expect(solo.buy('damage-2'), isTrue);
      expect(solo.hitsFor(manualThrow: true), 3);
      expect(solo.skillLock('damage-3'), SkillLock.teammate);
      expect(solo.lockReason('damage-3'), SkillTree.teammateLockReason);
      expect(solo.skillLock('damage-4'), SkillLock.parent);
      expect(solo.buy('damage-3'), isFalse);
      expect(solo.hitsFor(manualThrow: false), 1);
      expect(solo.allyAimScale, 1);
      expect(solo.skillLock('throw-1'), SkillLock.open);
      expect(solo.skillLock('fort-2'), SkillLock.open);

      expect(solo.buy('team-2'), isTrue);
      expect(solo.crewSize, 2);
      expect(solo.skillLock('aim-1'), SkillLock.open);
      expect(solo.lockReason('aim-1'), isNull);
      expect(solo.buy('aim-1'), isTrue);
      expect(solo.allyAimScale, 0.72);
      expect(solo.buy('react-1'), isTrue);
      expect(solo.allyGapScale, 0.84);
      expect(solo.buy('charge-1'), isTrue);
      expect(solo.allyChargeScale, 0.86);
      expect(solo.buy('damage-3'), isTrue);
      expect(solo.hitsFor(manualThrow: false), 2);
      expect(solo.skillLock('damage-4'), SkillLock.open);
      expect(solo.buy('damage-4'), isTrue);
      expect(solo.hitsFor(manualThrow: false), 3);
    });

    test('a save that already owns teammate nodes does not gain a kid', () {
      final saved = MetaState(
        coins: 50,
        skills: {'aim-1', 'react-2', 'charge-1', 'damage-3'},
      );
      expect(saved.crewSize, 1);
      expect(saved.owns('team-2'), isFalse);
      expect(saved.allyAimScale, 0.72);
      expect(saved.allyGapScale, 0.68);
      expect(saved.allyChargeScale, 0.86);
      expect(saved.hitsFor(manualThrow: true), 3);
      expect(saved.hitsFor(manualThrow: false), 2);
      expect(saved.skillLock('aim-1'), SkillLock.open);
      expect(saved.skillLock('aim-2'), SkillLock.teammate);
      expect(saved.buy('aim-2'), isFalse);
      expect(saved.owns('aim-2'), isFalse);
      expect(saved.owns('team-2'), isFalse);

      final again = MetaState.fromJson(saved.toJson());
      expect(again.skills, saved.skills);
      expect(again.crewSize, 1);
      expect(again.owns('team-2'), isFalse);
      expect(again.allyAimScale, 0.72);
      expect(again.hitsFor(manualThrow: false), 2);
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
      expect(total, 3437);
      var waves = 0;
      for (var wave = 1; wave <= 20; wave++) {
        waves += MetaState.coinsForWave(wave);
      }
      expect(waves, 960);
      expect(waves * 2, lessThan(total), reason: 'several long runs');
      expect(MetaState.coinsForWave(1), 10);
      expect(MetaState.coinsPerKnockout, 4);
    });

    test('each rank in a chain costs 2.5x the last, rounded to 5', () {
      for (final branch in SkillBranch.values) {
        final chain = SkillTree.chain(branch);
        final base = chain.first.cost;
        for (var i = 0; i < chain.length; i++) {
          expect(
            chain[i].cost,
            SkillTree.rankCost(base, i + 1),
            reason: chain[i].id,
          );
        }
      }
      expect(SkillTree.rankCost(10, 1), 10);
      expect(SkillTree.rankCost(10, 2), 25);
      expect(SkillTree.rankCost(10, 3), 65);
      expect(SkillTree.rankCost(10, 4), 155);
      expect(SkillTree.rankCost(10, 5), 390);
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
      expect(again.season, Season.winter);
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

  test('save store round trip keeps the other wallet', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SaveStore(preferences: prefs);
    final arcade = MetaState(
      mode: PlayMode.arcade,
      coins: 18,
      crewSize: 2,
      fortStage: 2,
      throwRank: 1,
      season: Season.summer,
      bestWave: 4,
    );
    await store.save(arcade);
    await store.save(
      MetaState(
        mode: PlayMode.campaign,
        coins: 9,
        crewSize: 3,
        season: Season.summer,
        bestWave: 6,
      ),
    );
    final loaded = await SaveStore(preferences: prefs).load();
    expect(loaded.season, Season.winter);
    expect(loaded.mode, PlayMode.campaign);
    expect(loaded.wallet(PlayMode.arcade, Difficulty.normal).coins, 18);
    expect(loaded.wallet(PlayMode.arcade, Difficulty.normal).crewSize, 2);
    expect(loaded.wallet(PlayMode.arcade, Difficulty.normal).fortStage, 2);
    expect(loaded.wallet(PlayMode.arcade, Difficulty.normal).throwRank, 1);
    expect(loaded.wallet(PlayMode.arcade, Difficulty.normal).bestWave, 4);
    expect(
      loaded.wallet(PlayMode.arcade, Difficulty.normal).skills,
      isNot(contains('team-3')),
    );
    expect(loaded.wallet(PlayMode.campaign, Difficulty.normal).coins, 9);
    expect(loaded.wallet(PlayMode.campaign, Difficulty.normal).crewSize, 3);
    expect(loaded.wallet(PlayMode.campaign, Difficulty.normal).bestWave, 6);
    expect(
      loaded.wallet(PlayMode.campaign, Difficulty.normal).owns('team-3'),
      isTrue,
    );
  });

  test('an older single-meta save migrates into arcade', () async {
    final legacy = {
      'coins': 21,
      'crewSize': 2,
      'fortStage': 1,
      'throwRank': 1,
      'skills': ['team-2', 'throw-1'],
      'season': 'summer',
      'bestWave': 4,
    };
    SharedPreferences.setMockInitialValues({
      SaveStore.storageKey: jsonEncode(legacy),
    });
    final prefs = await SharedPreferences.getInstance();
    final store = SaveStore(preferences: prefs);
    final profile = await store.load();
    expect(profile.mode, PlayMode.arcade);
    expect(profile.season, Season.winter);
    expect(profile.wallet(PlayMode.arcade, Difficulty.normal).coins, 21);
    expect(profile.wallet(PlayMode.arcade, Difficulty.normal).crewSize, 2);
    expect(profile.wallet(PlayMode.arcade, Difficulty.normal).throwRank, 1);
    expect(profile.wallet(PlayMode.arcade, Difficulty.normal).bestWave, 4);
    expect(
      profile.wallet(PlayMode.arcade, Difficulty.normal).owns('team-2'),
      isTrue,
    );
    expect(profile.wallet(PlayMode.campaign, Difficulty.normal).coins, 0);
    expect(
      profile.wallet(PlayMode.campaign, Difficulty.normal).skills,
      isEmpty,
    );
    expect(profile.wallet(PlayMode.campaign, Difficulty.normal).bestWave, 0);

    profile.wallet(PlayMode.campaign, Difficulty.normal).coins = 8;
    profile.wallet(PlayMode.campaign, Difficulty.normal).bestWave = 2;
    profile.wallet(PlayMode.campaign, Difficulty.normal).mode =
        PlayMode.campaign;
    await store.save(profile.wallet(PlayMode.campaign, Difficulty.normal));
    final again = await SaveStore(preferences: prefs).load();
    expect(again.wallet(PlayMode.arcade, Difficulty.normal).coins, 21);
    expect(
      again.wallet(PlayMode.arcade, Difficulty.normal).owns('throw-1'),
      isTrue,
    );
    expect(again.wallet(PlayMode.campaign, Difficulty.normal).coins, 8);
    expect(again.wallet(PlayMode.campaign, Difficulty.normal).bestWave, 2);
    expect(again.wallet(PlayMode.campaign, Difficulty.normal).skills, isEmpty);
    expect(again.season, Season.winter);
    final raw =
        jsonDecode(prefs.getString(SaveStore.storageKey)!)
            as Map<String, dynamic>;
    expect(raw['v'], 3);
    final wallets = raw['wallets'] as Map<String, dynamic>;
    for (final m in PlayMode.values) {
      final row = wallets[m.name] as Map<String, dynamic>;
      expect(row.keys, unorderedEquals(Difficulty.values.map((d) => d.name)));
    }
  });

  group('a wallet per mode and difficulty', () {
    test('six wallets, and nothing crosses between them', () {
      final profile = PlayerSave();
      final seen = <MetaState>{};
      for (final m in PlayMode.values) {
        for (final d in Difficulty.values) {
          final w = profile.wallet(m, d);
          expect(w.mode, m);
          expect(w.difficulty, d);
          seen.add(w);
        }
      }
      expect(seen, hasLength(6));

      final easyCampaign = profile.wallet(PlayMode.arcade, Difficulty.easy);
      easyCampaign.earn(500);
      expect(easyCampaign.buyExtraKid(), isTrue);
      easyCampaign.noteWaveCleared(9);
      for (final w in profile.allWallets) {
        if (identical(w, easyCampaign)) continue;
        expect(w.coins, 0);
        expect(w.skills, isEmpty);
        expect(w.bestWave, 0);
        expect(w.score, 0);
      }
    });

    test('v3 saves round-trip every wallet', () {
      final profile = PlayerSave();
      profile.wallet(PlayMode.arcade, Difficulty.hard)
        ..earn(40)
        ..noteWaveCleared(3);
      profile.wallet(PlayMode.campaign, Difficulty.easy).earn(70);
      final back = PlayerSave.fromJson(profile.toJson());
      final hard = back.wallet(PlayMode.arcade, Difficulty.hard);
      expect(hard.coins, 40);
      expect(hard.score, 40);
      expect(hard.bestWave, 3);
      expect(hard.difficulty, Difficulty.hard);
      expect(back.wallet(PlayMode.campaign, Difficulty.easy).score, 70);
      expect(back.wallet(PlayMode.arcade, Difficulty.normal).coins, 0);
    });

    test('a v2 save keeps its wallet on Normal and splits the bests', () {
      final back = PlayerSave.fromJson({
        'v': 2,
        'season': 'winter',
        'mode': 'arcade',
        'arcade': {
          'coins': 55,
          'skills': ['team-2'],
          'bestWaves': {'easy': 9, 'normal': 4, 'hard': 2},
        },
        'campaign': {'coins': 11, 'bestWave': 6},
      });
      final normal = back.wallet(PlayMode.arcade, Difficulty.normal);
      expect(normal.coins, 55);
      expect(normal.owns('team-2'), isTrue);
      expect(normal.bestWave, 4);
      final easy = back.wallet(PlayMode.arcade, Difficulty.easy);
      expect(easy.coins, 0);
      expect(easy.skills, isEmpty);
      expect(easy.bestWave, 9);
      expect(back.wallet(PlayMode.arcade, Difficulty.hard).bestWave, 2);
      // A lone old best wave counts as Normal.
      expect(back.wallet(PlayMode.campaign, Difficulty.normal).bestWave, 6);
      expect(back.wallet(PlayMode.campaign, Difficulty.normal).coins, 11);
      expect(back.wallet(PlayMode.campaign, Difficulty.hard).bestWave, 0);
    });
  });

  test('score follows every coin earned and is never spent or reset', () {
    final meta = MetaState();
    meta.earn(30);
    meta.earn(12);
    expect(meta.coins, 42);
    expect(meta.score, 42);
    expect(meta.buyExtraKid(), isTrue);
    expect(meta.coins, lessThan(42));
    meta.resetRun();
    expect(meta.score, 42);
    expect(MetaState.fromJson(meta.toJson()).score, 42);
  });

  test(
    'the modes are labelled Campaign (skills wipe) and Arcade (skills stay)',
    () {
      expect(PlayMode.arcade.label, 'Campaign');
      expect(PlayMode.arcade.blurb, 'Skills wipe on defeat. Coins stay.');
      expect(PlayMode.arcade.showsScore, isFalse);
      expect(PlayMode.campaign.label, 'Arcade');
      expect(PlayMode.campaign.blurb, 'Skills stay. Restart at wave 1.');
      expect(PlayMode.campaign.showsScore, isTrue);
    },
  );

  test('summer is switched off: saves and setters land on winter', () {
    expect(Season.playable, [Season.winter]);
    expect(Season.choosable, isFalse);
    expect(MetaState.fromJson({'season': 'summer'}).season, Season.winter);
    final save = PlayerSave.fromJson({
      'season': 'summer',
      'arcade': <String, dynamic>{},
      'campaign': <String, dynamic>{},
    });
    expect(save.season, Season.winter);
    save.season = Season.summer;
    expect(save.season, Season.winter);
  });

  test('a run bookmark survives a save and the wallet split', () {
    final profile = PlayerSave();
    profile.wallet(PlayMode.arcade, Difficulty.hard)
      ..resumeWave = 5
      ..resumeArena = 'park';
    final back = PlayerSave.fromJson(profile.toJson());
    final hard = back.wallet(PlayMode.arcade, Difficulty.hard);
    expect(hard.resumeWave, 5);
    expect(hard.resumeArena, 'park');
    expect(back.wallet(PlayMode.arcade, Difficulty.normal).canResume, isFalse);
    final snap = WalletSnap.from(hard);
    final other = PlayerSave()..apply(snap);
    expect(other.wallet(PlayMode.arcade, Difficulty.hard).resumeWave, 5);
  });

  group('Recovery skills', () {
    test('Campaign on Normal and Hard can buy them', () {
      for (final d in [Difficulty.normal, Difficulty.hard]) {
        final meta = MetaState(coins: 999, difficulty: d);
        expect(meta.lockReason('mend-1'), isNull, reason: d.name);
        expect(meta.buy('mend-1'), isTrue);
        expect(meta.healPerWave, 1);
        expect(meta.buy('mend-2'), isTrue);
        expect(meta.healPerWave, 2);
        expect(
          meta.lockReason('revive-1'),
          SkillTree.teammateLockReason,
          reason: 'a revive needs a teammate',
        );
        expect(meta.buy('team-2'), isTrue);
        expect(meta.buy('revive-1'), isTrue);
        expect(meta.reviveOne, isTrue);
      }
    });

    test('Arcade and Easy lock them with a reason', () {
      final arcade = MetaState(coins: 999, mode: PlayMode.campaign);
      expect(arcade.lockReason('mend-1'), SkillTree.campaignOnlyReason);
      expect(arcade.buy('mend-1'), isFalse);
      final easy = MetaState(coins: 999, difficulty: Difficulty.easy);
      expect(easy.lockReason('mend-1'), SkillTree.easyHealsReason);
      expect(easy.buy('mend-1'), isFalse);
    });

    test('Recovery sits in the Crew tab after Team', () {
      expect(SkillGroup.crew.branches.take(2), [
        SkillBranch.team,
        SkillBranch.recovery,
      ]);
      expect(SkillTree.chain(SkillBranch.recovery).map((n) => n.id), [
        'mend-1',
        'mend-2',
        'revive-1',
      ]);
    });
  });

  test('a resume bookmark keeps the crew health', () {
    final meta = MetaState()
      ..resumeWave = 3
      ..resumeCrewHp = [2, 0];
    final back = MetaState.fromJson(meta.toJson());
    expect(back.resumeCrewHp, [2, 0]);
    final save = PlayerSave()..apply(WalletSnap.from(meta));
    expect(save.wallet(PlayMode.arcade, Difficulty.normal).resumeCrewHp, [
      2,
      0,
    ]);
  });
  group('power-ups', () {
    test('buy up to the stack cap, spend one at a time', () {
      final meta = MetaState(coins: 500);
      for (var i = 0; i < PowerUp.maxStack; i++) {
        expect(meta.buyItem(PowerUp.freezeAll), isTrue);
      }
      expect(meta.buyItem(PowerUp.freezeAll), isFalse, reason: 'stack full');
      expect(meta.itemCount(PowerUp.freezeAll), PowerUp.maxStack);
      expect(meta.coins, 500 - PowerUp.freezeAll.cost * PowerUp.maxStack);
      expect(meta.useItem(PowerUp.freezeAll), isTrue);
      expect(meta.itemCount(PowerUp.freezeAll), PowerUp.maxStack - 1);
      expect(meta.useItem(PowerUp.hotCocoa), isFalse, reason: 'none owned');
      expect(MetaState(coins: 1).buyItem(PowerUp.powerThrow), isFalse);
    });

    test('items survive a save, the wallet split, and a defeat', () {
      final meta = MetaState(coins: 100)..buyItem(PowerUp.bigSplat);
      final back = MetaState.fromJson(meta.toJson());
      expect(back.itemCount(PowerUp.bigSplat), 1);
      final save = PlayerSave()..apply(WalletSnap.from(meta));
      expect(
        save
            .wallet(PlayMode.arcade, Difficulty.normal)
            .itemCount(PowerUp.bigSplat),
        1,
      );
      meta.resetRun();
      expect(meta.itemCount(PowerUp.bigSplat), 1);
    });
  });
}
