import 'package:backyard_barrage/meta/difficulty.dart';
import 'package:backyard_barrage/app.dart';
import 'package:backyard_barrage/meta/play_mode.dart';
import 'package:backyard_barrage/meta/save_store.dart';
import 'package:backyard_barrage/seasons/season.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home is winter only and offers both modes', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SaveStore(preferences: prefs);
    final profile = await store.load();
    profile.season = Season.summer;
    await store.saveProfile(profile);

    await tester.pumpWidget(BackyardBarrageApp(saveStore: store));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('play-arcade')), findsOneWidget);
    expect(find.byKey(const Key('play-campaign')), findsOneWidget);
    // A save left on summer comes back as winter, with no season switch.
    expect(find.byKey(const Key('home-backdrop-winter')), findsOneWidget);
    expect(find.byKey(const Key('season-summer')), findsNothing);
    expect(find.text('Skills wipe on defeat. Coins stay.'), findsOneWidget);
    expect(find.text('Skills stay. Restart at wave 1.'), findsOneWidget);
  });

  testWidgets('home shows each wallet and the campaign best wave', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SaveStore(preferences: prefs);
    final profile = await store.load();
    profile.wallet(PlayMode.arcade, Difficulty.normal).coins = 3;
    profile.wallet(PlayMode.arcade, Difficulty.normal).bestWave = 2;
    profile.wallet(PlayMode.campaign, Difficulty.normal).coins = 11;
    profile.wallet(PlayMode.campaign, Difficulty.normal).bestWave = 6;
    profile.wallet(PlayMode.campaign, Difficulty.normal).mode =
        PlayMode.campaign;
    await store.saveProfile(profile);

    await tester.pumpWidget(BackyardBarrageApp(saveStore: store));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('campaign-best-wave')), findsOneWidget);
    // Each card shows its own coins, and its own headline number.
    Finder coinsOn(String mode) => find.descendant(
      of: find.byKey(Key('$mode-coins')),
      matching: find.byType(Text),
    );
    expect(tester.widget<Text>(coinsOn('arcade')).data, '3');
    expect(tester.widget<Text>(coinsOn('campaign')).data, '11');
    expect(find.text('Best wave 2'), findsOneWidget);
    expect(find.text('Score 0'), findsOneWidget);
    expect(find.text('Campaign'), findsOneWidget);
    expect(find.text('Arcade'), findsOneWidget);
  });

  testWidgets('campaign bests show per difficulty with the picked one lit', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SaveStore(preferences: prefs);
    final profile = await store.load();
    // Campaign is the skills-wipe mode (code name `arcade`).
    profile.wallet(PlayMode.arcade, Difficulty.easy).bestWave = 9;
    profile.wallet(PlayMode.arcade, Difficulty.normal).bestWave = 4;
    profile.wallet(PlayMode.campaign, Difficulty.easy).earn(25);
    await store.saveProfile(profile);

    await tester.pumpWidget(BackyardBarrageApp(saveStore: store));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Normal is picked: its 4 is the big number; Easy's 9 shows beside it;
    // Hard has no clear yet, so it is left out.
    Text big() =>
        tester.widget<Text>(find.byKey(const Key('campaign-best-wave')));
    expect(big().data, '4');
    expect(find.byKey(const Key('campaign-best-easy')), findsOneWidget);
    expect(find.byKey(const Key('campaign-best-hard')), findsNothing);
    expect(find.text('Score 0'), findsOneWidget);

    // Easy has its own wallets: Campaign best 9, Arcade score 25.
    await tester.tap(find.byKey(const Key('difficulty-easy')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(big().data, '9');
    expect(find.text('Best wave 9'), findsOneWidget);
    expect(find.text('Score 25'), findsOneWidget);

    // Picking a mode with no clears still shows it, at 0.
    await tester.tap(find.byKey(const Key('difficulty-hard')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(big().data, '0');
    expect(find.byKey(const Key('campaign-best-hard')), findsOneWidget);
  });
}
