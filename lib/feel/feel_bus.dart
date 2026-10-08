import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio/game_audio.dart';
import '../meta/game_settings.dart';
import '../seasons/season.dart';
import '../meta/power_up.dart';
import 'game_haptics.dart';

/// Settings-aware SFX, music, and haptics for menus and the arena.
class FeelBus {
  FeelBus({
    GameSettings settings = const GameSettings(),
    GameAudio? audio,
    GameHaptics? haptics,
  }) : settings = settings,
       settingsListenable = ValueNotifier(settings),
       audio = audio ?? GameAudio(),
       haptics = haptics ?? GameHaptics() {
    apply(settings);
  }

  GameSettings settings;
  final ValueNotifier<GameSettings> settingsListenable;
  final GameAudio audio;
  final GameHaptics haptics;

  bool _inBattle = false;
  Season _battleSeason = Season.winter;

  void apply(GameSettings next) {
    settings = next;
    haptics.enabled = next.hapticsEnabled;
    audio.sfxEnabled = next.sfxEnabled;
    audio.musicEnabled = next.musicEnabled;
    if (settingsListenable.value != next) {
      settingsListenable.value = next;
    }
  }

  void uiTap() {
    unawaited(audio.playSfx(AudioCues.uiTap));
  }

  /// Closing a sheet or heading back to the menu.
  void uiBack() {
    unawaited(audio.playSfx(AudioCues.uiBack));
  }

  /// [fullPower] swaps the whoosh for the full-power throw.
  void playerReleased({bool fullPower = false}) {
    unawaited(haptics.chargeRelease());
    unawaited(
      audio.playSfx(
        fullPower ? AudioCues.throwFullPower : AudioCues.throwWhoosh,
      ),
    );
  }

  /// The hum while the player holds a charge. Idempotent.
  void chargeHum(bool on) {
    unawaited(
      on ? audio.startSfxLoop(AudioCues.chargeHum) : audio.stopSfxLoop(),
    );
  }

  void enemyReleased() {
    unawaited(audio.playSfx(AudioCues.throwWhoosh));
  }

  void impact(Season season) {
    unawaited(audio.playSfx(_impactCue(season)));
  }

  void kidHit({required bool knockedOut, required Season season}) {
    if (knockedOut) {
      unawaited(haptics.ko());
      unawaited(audio.playSfx(AudioCues.koCollapse));
    } else {
      unawaited(haptics.hit());
      unawaited(audio.playSfx(AudioCues.hitOuch));
    }
    impact(season);
  }

  /// A power-up fired from the HUD. Distinct from buying one.
  void powerUpUsed(PowerUp item) {
    unawaited(haptics.hit());
    unawaited(
      audio.playSfx(switch (item) {
        PowerUp.frostArmor => AudioCues.powerUpArmor,
        PowerUp.freezeAll => AudioCues.powerUpFreeze,
        PowerUp.hotCocoa => AudioCues.powerUpCocoa,
        PowerUp.fortCracker ||
        PowerUp.powerThrow ||
        PowerUp.bigSplat => AudioCues.powerUpPower,
      }),
    );
  }

  /// A snowball thumps a fort that is still standing.
  void fortHit() {
    unawaited(audio.playSfx(AudioCues.fortHit));
  }

  /// A fort comes down (worn out, or Fort cracker).
  void fortCollapsed() {
    unawaited(haptics.ko());
    unawaited(audio.playSfx(AudioCues.fortCollapse));
  }

  /// Frost armor turns a hit away.
  void armorBlocked() {
    unawaited(audio.playSfx(AudioCues.armorBlock));
  }

  /// Coins pop over a knocked-out rival.
  void coinPop() {
    unawaited(audio.playSfx(AudioCues.coinPop));
  }

  /// The "Wave N" banner.
  void waveStart() {
    unawaited(audio.playSfx(AudioCues.waveStart));
  }

  /// A frost kid's glint as it winds up.
  void frostGlint() {
    unawaited(audio.playSfx(AudioCues.frostGlint));
  }

  void houndGrowl() {
    unawaited(audio.playSfx(AudioCues.houndGrowl));
  }

  void houndLeap() {
    unawaited(audio.playSfx(AudioCues.houndLeap));
  }

  void houndSnap() {
    unawaited(audio.playSfx(AudioCues.houndSnap));
  }

  void houndWhimper() {
    unawaited(audio.playSfx(AudioCues.houndWhimper));
  }

  void purchased() {
    unawaited(haptics.purchase());
    unawaited(audio.playSfx(AudioCues.purchaseCoin));
  }

  void waveCleared() {
    unawaited(audio.playSfx(AudioCues.winStinger));
  }

  void defeated() {
    unawaited(audio.playSfx(AudioCues.loseStinger));
  }

  Future<void> enterMenu() async {
    _inBattle = false;
    await audio.startLoop(AudioCues.menuLoop);
  }

  Future<void> enterBattle(Season season) async {
    _inBattle = true;
    _battleSeason = season;
    final cue = season == Season.summer
        ? AudioCues.battleSummer
        : AudioCues.battleWinter;
    await audio.startLoop(cue);
  }

  /// Restarts or stops the loop that matches where the player is.
  Future<void> syncMusic({Season? battleSeason}) async {
    if (battleSeason != null) {
      await enterBattle(battleSeason);
      return;
    }
    if (_inBattle) {
      await enterBattle(_battleSeason);
      return;
    }
    await enterMenu();
  }

  static String _impactCue(Season season) {
    return season == Season.summer ? AudioCues.impactWet : AudioCues.impactSnow;
  }
}
