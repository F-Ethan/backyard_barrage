import 'dart:async';

import '../audio/game_audio.dart';
import '../meta/game_settings.dart';
import '../seasons/season.dart';
import 'game_haptics.dart';

/// Settings-aware SFX, music, and haptics for menus and the arena.
class FeelBus {
  FeelBus({
    GameSettings settings = const GameSettings(),
    GameAudio? audio,
    GameHaptics? haptics,
  }) : settings = settings,
       audio = audio ?? GameAudio(),
       haptics = haptics ?? GameHaptics() {
    apply(settings);
  }

  GameSettings settings;
  final GameAudio audio;
  final GameHaptics haptics;

  bool _inBattle = false;
  Season _battleSeason = Season.winter;

  void apply(GameSettings next) {
    settings = next;
    haptics.enabled = next.hapticsEnabled;
    audio.sfxEnabled = next.sfxEnabled;
    audio.musicEnabled = next.musicEnabled;
  }

  void uiTap() {
    unawaited(audio.playSfx(AudioCues.uiTap));
  }

  void playerReleased() {
    unawaited(haptics.chargeRelease());
    unawaited(audio.playSfx(AudioCues.throwWhoosh));
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
