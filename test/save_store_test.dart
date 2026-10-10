import 'dart:convert';

import 'package:backyard_barrage/meta/difficulty.dart';
import 'package:backyard_barrage/meta/play_mode.dart';
import 'package:backyard_barrage/meta/save_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<SharedPreferences> prefsWith([Map<String, Object> values = const {}]) {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  test('coins earned while a save waits are not undone', () async {
    final prefs = await prefsWith();
    final store = SaveStore(preferences: prefs);
    final profile = await store.load();
    // The game plays on the very wallet the menu loaded.
    final wallet = profile.wallet(PlayMode.campaign, Difficulty.normal)
      ..coins = 10;
    final pending = store.save(wallet);
    wallet.earn(50);
    await pending;
    expect(wallet.coins, 60, reason: 'the queued save must not revert it');

    await store.save(wallet);
    final back = await SaveStore(preferences: prefs).load();
    expect(back.wallet(PlayMode.campaign, Difficulty.normal).coins, 60);
  });

  test('one failed write does not stop the saves after it', () async {
    final prefs = await prefsWith();
    final store = SaveStore(preferences: prefs);
    final wallet = (await store.load()).wallet(
      PlayMode.arcade,
      Difficulty.normal,
    );
    store.debugFailNextWrite = true;
    wallet.coins = 5;
    await store.save(wallet); // fails quietly
    wallet.coins = 99;
    await store.save(wallet);
    final back = await SaveStore(preferences: prefs).load();
    expect(back.wallet(PlayMode.arcade, Difficulty.normal).coins, 99);
  });

  test('a wrong-typed field spoils only its own wallet', () async {
    final prefs = await prefsWith({
      SaveStore.storageKey: jsonEncode({
        'v': 3,
        'season': 7,
        'mode': ['campaign'],
        'wallets': {
          'arcade': {
            'normal': {'coins': 'lots', 'season': 5, 'mode': 3},
          },
          'campaign': {
            'normal': {'coins': 77},
          },
        },
      }),
    });
    final profile = await SaveStore(preferences: prefs).load();
    expect(profile.wallet(PlayMode.campaign, Difficulty.normal).coins, 77);
    expect(profile.wallet(PlayMode.arcade, Difficulty.normal).coins, 0);
  });

  test('an unreadable save is kept aside before a fresh one starts', () async {
    final prefs = await prefsWith({SaveStore.storageKey: '{not json'});
    final store = SaveStore(preferences: prefs);
    final profile = await store.load();
    expect(profile.wallet(PlayMode.arcade, Difficulty.normal).coins, 0);
    expect(prefs.getString(SaveStore.corruptKey), '{not json');
  });
}
