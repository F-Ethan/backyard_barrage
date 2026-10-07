import 'package:backyard_barrage/app.dart';
import 'package:backyard_barrage/audio/game_audio.dart';
import 'package:backyard_barrage/feel/feel_bus.dart';
import 'package:backyard_barrage/feel/game_haptics.dart';
import 'package:backyard_barrage/game/components/overlay_banner.dart';
import 'package:backyard_barrage/meta/save_store.dart';
import 'package:backyard_barrage/meta/settings_store.dart';
import 'package:backyard_barrage/ui/barrage_theme.dart';
import 'package:backyard_barrage/ui/coin_amount.dart';
import 'package:backyard_barrage/ui/match_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'recording_audio.dart';

/// UI motion is off by default in tests (`flutter_test_config.dart`). These
/// cases turn it on, pump through the animations, and check that reduced
/// motion still settles instantly.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void enableMotion() {
    BarrageMotion.debugDisable = false;
    addTearDown(() => BarrageMotion.debugDisable = true);
  }

  Future<void> useSurface(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() async {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await tester.binding.setSurfaceSize(null);
    });
  }

  Future<Widget> app() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return BackyardBarrageApp(
      saveStore: SaveStore(preferences: prefs),
      settingsStore: SettingsStore(preferences: prefs),
      feel: FeelBus(
        audio: GameAudio(playback: RecordingPlayback()),
        haptics: GameHaptics(pulse: RecordingPulse()),
      ),
    );
  }

  testWidgets('home staggers in and the settings sheet pops', (tester) async {
    enableMotion();
    await tester.pumpWidget(await app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(Animate), findsWidgets);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('play-arcade')), findsOneWidget);

    await tester.tap(find.byKey(const Key('menu-settings')));
    await tester.pump();
    expect(find.byKey(const Key('settings-sheet')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byKey(const Key('settings-back')));
    await tester.pump();
    // The sheet animates out instead of cutting.
    expect(find.byKey(const Key('settings-sheet')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('settings-sheet')), findsNothing);
  });

  testWidgets('reduced motion renders the settled home with no entrances', (
    tester,
  ) async {
    enableMotion();
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(await app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byKey(const Key('play-arcade')), findsOneWidget);
    expect(find.byType(Animate), findsNothing);
    expect(
      BarrageMotion.of(
        tester.element(find.byKey(const Key('play-arcade'))),
      ).reduced,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('menu-settings')));
    await tester.pump();
    expect(find.byKey(const Key('settings-sheet')), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings-back')));
    await tester.pump();
    expect(find.byKey(const Key('settings-sheet')), findsNothing);
  });

  testWidgets('coin amounts tick up, or jump under reduced motion', (
    tester,
  ) async {
    enableMotion();
    Widget coins(int amount) => MaterialApp(
      home: Scaffold(
        body: Center(child: CoinAmount(amount: amount)),
      ),
    );
    await tester.pumpWidget(coins(10));
    expect(find.text('10'), findsOneWidget);

    await tester.pumpWidget(coins(50));
    expect(find.text('10'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('50'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('50'), findsOneWidget);

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(coins(90));
    expect(find.text('90'), findsOneWidget);
  });

  testWidgets('the center banner is screen-sized Flutter text', (tester) async {
    enableMotion();
    await useSurface(tester, const Size(640, 360));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatchBanner(
            spec: BannerSpec(
              label: 'Wave 3 clear!',
              subtitle: '+12 coins',
              fontSize: 42,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final title = tester.widget<Text>(
      find.byKey(const Key('match-banner-title')),
    );
    expect(title.data, 'Wave 3 clear!');
    // 11% of the short side, floored at 30pt; never the letterboxed world.
    expect(title.style!.fontSize, greaterThanOrEqualTo(30));
    expect(find.text('+12 coins'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatchBanner(
            spec: BannerSpec(
              label: 'KO!',
              fontSize: 56,
              color: const Color(0xFFFFE66D),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final ko = tester.widget<Text>(find.byKey(const Key('match-banner-title')));
    expect(ko.data, 'KO!');
    expect(ko.style!.color, const Color(0xFFFFE66D));
    expect(ko.style!.fontSize, greaterThan(title.style!.fontSize!));
  });

  for (final size in const [Size(640, 360), Size(844, 390), Size(1280, 720)]) {
    testWidgets(
      'home lays out at ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        await useSurface(tester, size);
        await tester.pumpWidget(await app());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
        final arcade = tester.getRect(find.byKey(const Key('play-arcade')));
        final campaign = tester.getRect(find.byKey(const Key('play-campaign')));
        final settings = tester.getRect(find.byKey(const Key('menu-settings')));
        // Big tap targets, on screen, not overlapping.
        expect(arcade.height, greaterThanOrEqualTo(64));
        expect(campaign.top, greaterThanOrEqualTo(arcade.bottom));
        expect(campaign.bottom, lessThanOrEqualTo(size.height));
        expect(settings.right, lessThanOrEqualTo(size.width));
        // Text is laid out at its real size, not shrunk by a FittedBox.
        expect(
          find.ancestor(
            of: find.byKey(const Key('play-arcade')),
            matching: find.byType(FittedBox),
          ),
          findsNothing,
        );
      },
    );
  }
}
