import 'package:backyard_barrage/app.dart';
import 'package:backyard_barrage/meta/play_mode.dart';
import 'package:backyard_barrage/meta/save_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('main menu keeps the season and offers both modes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SaveStore(preferences: prefs);

    await tester.pumpWidget(BackyardBarrageApp(saveStore: store));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('play-arcade')), findsOneWidget);
    expect(find.byKey(const Key('play-campaign')), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Winter yard'), findsOneWidget);
    expect(find.byKey(const Key('home-backdrop-winter')), findsOneWidget);
    expect(find.byKey(const Key('season-summer')), findsOneWidget);
    expect(find.text('Skills wipe on defeat. Coins stay.'), findsOneWidget);
    expect(find.text('Skills stay. Restart at wave 1.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('season-summer')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Summer yard'), findsOneWidget);
    expect(find.byKey(const Key('home-backdrop-summer')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(BackyardBarrageApp(saveStore: store));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Summer yard'), findsOneWidget);
    expect(find.byKey(const Key('home-backdrop-summer')), findsOneWidget);
  });

  testWidgets('home shows each wallet and the campaign best wave', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SaveStore(preferences: prefs);
    final profile = await store.load();
    profile.arcade.coins = 3;
    profile.arcade.bestWave = 2;
    profile.campaign.coins = 11;
    profile.campaign.bestWave = 6;
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
}
