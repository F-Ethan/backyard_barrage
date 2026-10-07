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
    profile.arcade.coins = 3;
    profile.arcade.replaceBestWaves({Difficulty.normal: 2});
    profile.campaign.coins = 11;
    profile.campaign.replaceBestWaves({Difficulty.normal: 6});
    profile.campaign.mode = PlayMode.campaign;
    await store.saveProfile(profile);

    await tester.pumpWidget(BackyardBarrageApp(saveStore: store));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('campaign-best-wave')), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('3 coins · best wave 2'), findsOneWidget);
    expect(find.text('11 coins · best wave 6'), findsOneWidget);
  });

  testWidgets('campaign bests show per difficulty with the picked one lit', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SaveStore(preferences: prefs);
    final profile = await store.load();
    profile.campaign.replaceBestWaves({
      Difficulty.easy: 9,
      Difficulty.normal: 4,
    });
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

    await tester.tap(find.byKey(const Key('difficulty-easy')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(big().data, '9');
    expect(find.text('0 coins · best wave 0'), findsOneWidget);

    // Picking a mode with no clears still shows it, at 0.
    await tester.tap(find.byKey(const Key('difficulty-hard')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(big().data, '0');
    expect(find.byKey(const Key('campaign-best-hard')), findsOneWidget);
  });
}
