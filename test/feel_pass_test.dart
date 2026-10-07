import 'package:backyard_barrage/app.dart';
import 'package:backyard_barrage/audio/game_audio.dart';
import 'package:backyard_barrage/feel/feel_bus.dart';
import 'package:backyard_barrage/feel/game_haptics.dart';
import 'package:backyard_barrage/meta/difficulty.dart';
import 'package:backyard_barrage/meta/game_settings.dart';
import 'package:backyard_barrage/meta/save_store.dart';
import 'package:backyard_barrage/meta/settings_store.dart';
import 'package:backyard_barrage/seasons/season.dart';
import 'package:backyard_barrage/ui/settings_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'recording_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('settings sit beside the meta save and round-trip', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final metaStore = SaveStore(preferences: prefs);
    final settingsStore = SettingsStore(preferences: prefs);

    final profile = await metaStore.load();
    profile.arcade.coins = 9;
    await metaStore.save(profile.arcade);
    await settingsStore.save(
      const GameSettings(
        sfxEnabled: false,
        musicEnabled: false,
        hapticsEnabled: false,
      ),
    );

    final again = SettingsStore(preferences: prefs);
    final loaded = await again.load();
    expect(loaded.sfxEnabled, isFalse);
    expect(loaded.musicEnabled, isFalse);
    expect(loaded.hapticsEnabled, isFalse);
    expect(await SaveStore(preferences: prefs).load(), isNotNull);
    expect((await SaveStore(preferences: prefs).load()).arcade.coins, 9);
    expect(SettingsStore.storageKey, isNot(SaveStore.storageKey));
  });

  test('missing settings keys default to on', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final loaded = await SettingsStore(preferences: prefs).load();
    expect(loaded.sfxEnabled, isTrue);
    expect(loaded.musicEnabled, isTrue);
    expect(loaded.hapticsEnabled, isTrue);
    expect(loaded.difficulty, Difficulty.normal);
  });

  test('haptics no-op when disabled and fire when enabled', () async {
    final pulse = RecordingPulse();
    final haptics = GameHaptics(enabled: false, pulse: pulse);
    await haptics.chargeRelease();
    await haptics.hit();
    await haptics.ko();
    await haptics.purchase();
    expect(pulse.kinds, isEmpty);

    haptics.enabled = true;
    await haptics.chargeRelease();
    await haptics.hit();
    await haptics.ko();
    await haptics.purchase();
    expect(pulse.kinds, ['light', 'medium', 'heavy', 'medium']);
  });

  testWidgets('studio wavs resolve and toggles gate playback', (tester) async {
    final playback = RecordingPlayback();
    final audio = GameAudio(playback: playback);

    expect(
      await audio.resolvedFile(AudioCues.throwWhoosh),
      'sfx/throw_whoosh.wav',
    );
    expect(
      await audio.resolvedFile(AudioCues.impactSnow),
      'sfx/impact_snow.wav',
    );
    expect(await audio.resolvedFile(AudioCues.impactWet), 'sfx/impact_wet.wav');
    expect(await audio.resolvedFile(AudioCues.hitOuch), 'sfx/hit_ouch.wav');
    expect(
      await audio.resolvedFile(AudioCues.koCollapse),
      'sfx/ko_collapse.wav',
    );
    expect(
      await audio.resolvedFile(AudioCues.winStinger),
      'sfx/win_stinger.wav',
    );
    expect(
      await audio.resolvedFile(AudioCues.loseStinger),
      'sfx/lose_stinger.wav',
    );
    expect(await audio.resolvedFile(AudioCues.uiTap), 'sfx/ui_tap.wav');
    expect(
      await audio.resolvedFile(AudioCues.purchaseCoin),
      'sfx/purchase_coin.wav',
    );
    expect(await audio.resolvedFile(AudioCues.menuLoop), 'music/menu_loop.wav');
    expect(
      await audio.resolvedFile(AudioCues.battleWinter),
      'music/battle_loop_winter.wav',
    );
    expect(
      await audio.resolvedFile(AudioCues.battleSummer),
      'music/battle_loop_summer.wav',
    );

    final feel = FeelBus(
      audio: audio,
      haptics: GameHaptics(pulse: RecordingPulse()),
    );
    feel.playerReleased();
    feel.kidHit(knockedOut: false, season: Season.winter);
    feel.kidHit(knockedOut: true, season: Season.summer);
    feel.waveCleared();
    feel.defeated();
    await feel.enterMenu();
    await feel.enterBattle(Season.summer);
    await tester.pump();

    expect(
      playback.sfx,
      containsAll([
        'sfx/throw_whoosh.wav',
        'sfx/hit_ouch.wav',
        'sfx/impact_snow.wav',
        'sfx/ko_collapse.wav',
        'sfx/impact_wet.wav',
        'sfx/win_stinger.wav',
        'sfx/lose_stinger.wav',
      ]),
    );
    expect(playback.loops, [
      'music/menu_loop.wav',
      'music/battle_loop_summer.wav',
    ]);

    playback.sfx.clear();
    playback.loops.clear();
    feel.apply(const GameSettings(sfxEnabled: false, musicEnabled: false));
    feel.uiTap();
    await feel.syncMusic();
    await tester.pump();
    expect(playback.sfx, isEmpty);
    expect(playback.loops, isEmpty);
    expect(playback.stops, greaterThan(0));
  });

  testWidgets('settings toggles persist across a menu reload', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SaveStore(preferences: prefs);
    final settings = SettingsStore(preferences: prefs);
    FeelBus feel() => FeelBus(
      audio: GameAudio(playback: RecordingPlayback()),
      haptics: GameHaptics(pulse: RecordingPulse()),
    );

    await tester.pumpWidget(
      BackyardBarrageApp(
        saveStore: store,
        settingsStore: settings,
        feel: feel(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(const Key('menu-settings')));
    await tester.pump();
    expect(find.text('Credits'), findsOneWidget);
    expect(find.text('GameLogic'), findsOneWidget);

    await tester.tap(find.byKey(const Key('haptics-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    final saved = await settings.load();
    expect(saved.hapticsEnabled, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      BackyardBarrageApp(
        saveStore: store,
        settingsStore: settings,
        feel: feel(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('menu-settings')));
    await tester.pump();

    final toggle = tester.widget<BarrageToggle>(
      find.byKey(const Key('haptics-toggle')),
    );
    expect(toggle.value, isFalse);
  });

  testWidgets('a stale classic-kit save still loads and the toggle is gone', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      SettingsStore.storageKey:
          '{"sfx":false,"music":true,"haptics":true,"modernUi":false}',
    });
    final prefs = await SharedPreferences.getInstance();
    final store = SaveStore(preferences: prefs);
    final settings = SettingsStore(preferences: prefs);
    final loaded = await settings.load();
    expect(loaded.sfxEnabled, isFalse);
    expect(loaded.toJson().containsKey('modernUi'), isFalse);

    await tester.pumpWidget(
      BackyardBarrageApp(
        saveStore: store,
        settingsStore: settings,
        feel: FeelBus(
          audio: GameAudio(playback: RecordingPlayback()),
          haptics: GameHaptics(pulse: RecordingPulse()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('menu-settings')));
    await tester.pump();
    expect(find.byKey(const Key('settings-sheet')), findsOneWidget);
    expect(find.byKey(const Key('ui-style-toggle')), findsNothing);
    expect(find.text('Modern UI'), findsNothing);
    expect(
      tester.widget<BarrageToggle>(find.byKey(const Key('sfx-toggle'))).value,
      isFalse,
    );
  });

  testWidgets('difficulty is picked on the home screen and persists', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SaveStore(preferences: prefs);
    final settings = SettingsStore(preferences: prefs);
    FeelBus feel() => FeelBus(
      audio: GameAudio(playback: RecordingPlayback()),
      haptics: GameHaptics(pulse: RecordingPulse()),
    );

    await tester.pumpWidget(
      BackyardBarrageApp(
        saveStore: store,
        settingsStore: settings,
        feel: feel(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // On home, without opening Settings.
    expect(find.byKey(const Key('difficulty-normal')), findsOneWidget);
    expect(find.byKey(const Key('difficulty-easy')), findsOneWidget);
    expect(find.byKey(const Key('difficulty-hard')), findsOneWidget);

    await tester.tap(find.byKey(const Key('difficulty-hard')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect((await settings.load()).difficulty, Difficulty.hard);

    // The settings sheet does not add a second picker.
    await tester.tap(find.byKey(const Key('menu-settings')));
    await tester.pump();
    expect(find.byKey(const Key('difficulty-hard')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      BackyardBarrageApp(
        saveStore: store,
        settingsStore: settings,
        feel: feel(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect((await settings.load()).difficulty, Difficulty.hard);
    expect(find.byKey(const Key('ui-style-toggle')), findsNothing);
  });
}
