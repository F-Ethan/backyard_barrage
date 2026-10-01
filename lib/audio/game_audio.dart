import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';

/// Cue names from `docs/AUDIO_HANDOFF.md`.
///
/// Playback is a no-op until a matching file exists under `assets/audio/`.
abstract final class AudioCues {
  static const throwWhoosh = 'throw_whoosh';
  static const impactSnow = 'impact_snow';
  static const impactWet = 'impact_wet';
  static const hitOuch = 'hit_ouch';
  static const koCollapse = 'ko_collapse';
  static const winStinger = 'win_stinger';
  static const loseStinger = 'lose_stinger';
  static const uiTap = 'ui_tap';
  static const purchaseCoin = 'purchase_coin';
  static const menuLoop = 'menu_loop';
  static const battleWinter = 'battle_loop_winter';
  static const battleSummer = 'battle_loop_summer';

  static const oneShots = <String>[
    throwWhoosh,
    impactSnow,
    impactWet,
    hitOuch,
    koCollapse,
    winStinger,
    loseStinger,
    uiTap,
    purchaseCoin,
  ];

  static const loops = <String>[menuLoop, battleWinter, battleSummer];
}

abstract class AudioAssetLookup {
  const AudioAssetLookup();

  Future<bool> exists(String assetPath);
}

/// Reads the Flutter asset manifest. Missing cues stay silent.
class BundleAudioLookup extends AudioAssetLookup {
  const BundleAudioLookup();

  static Set<String>? _cached;

  @override
  Future<bool> exists(String assetPath) async {
    final assets = _cached ??= await _load();
    return assets.contains(assetPath);
  }

  Future<Set<String>> _load() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      return manifest.listAssets().toSet();
    } catch (_) {
      return const {};
    }
  }
}

class EmptyAudioLookup extends AudioAssetLookup {
  const EmptyAudioLookup();

  @override
  Future<bool> exists(String assetPath) async => false;
}

abstract class AudioPlayback {
  const AudioPlayback();

  Future<void> playSfx(String relativePath);
  Future<void> playLoop(String relativePath, {double volume = 0.5});
  Future<void> stopLoop();
}

class FlameAudioPlayback extends AudioPlayback {
  FlameAudioPlayback();

  bool _bgmReady = false;

  @override
  Future<void> playSfx(String relativePath) {
    return FlameAudio.play(relativePath);
  }

  @override
  Future<void> playLoop(String relativePath, {double volume = 0.5}) async {
    if (!_bgmReady) {
      await FlameAudio.bgm.initialize();
      _bgmReady = true;
    }
    await FlameAudio.bgm.play(relativePath, volume: volume);
  }

  @override
  Future<void> stopLoop() async {
    if (!_bgmReady) return;
    await FlameAudio.bgm.stop();
  }
}

class SilentAudioPlayback extends AudioPlayback {
  const SilentAudioPlayback();

  @override
  Future<void> playSfx(String relativePath) async {}

  @override
  Future<void> playLoop(String relativePath, {double volume = 0.5}) async {}

  @override
  Future<void> stopLoop() async {}
}

/// flame_audio hooks. SFX and music stay silent when the file is absent
/// or the matching settings toggle is off.
class GameAudio {
  GameAudio({AudioAssetLookup? lookup, AudioPlayback? playback})
    : _lookup = lookup ?? const BundleAudioLookup(),
      _playback = playback ?? FlameAudioPlayback();

  static const _extensions = ['.ogg', '.wav', '.mp3'];

  final AudioAssetLookup _lookup;
  final AudioPlayback _playback;
  final Map<String, String?> _resolved = {};

  bool sfxEnabled = true;
  bool musicEnabled = true;
  String? _currentLoop;
  Future<void>? _warming;

  Future<void> warmUp() {
    return _warming ??= _resolveAll();
  }

  Future<void> _resolveAll() async {
    for (final cue in AudioCues.oneShots) {
      _resolved[cue] = await _resolve('sfx', cue);
    }
    for (final cue in AudioCues.loops) {
      _resolved[cue] = await _resolve('music', cue);
    }
  }

  Future<String?> _resolve(String folder, String cue) async {
    for (final ext in _extensions) {
      final relative = '$folder/$cue$ext';
      if (await _lookup.exists('assets/audio/$relative')) return relative;
    }
    return null;
  }

  /// Relative path that would play for [cue], or null when no file is bundled.
  Future<String?> resolvedFile(String cue) async {
    await warmUp();
    return _fileFor(cue);
  }

  String? _fileFor(String cue) => _resolved[cue];

  Future<void> playSfx(String cue) async {
    if (!sfxEnabled) return;
    await warmUp();
    final file = _resolved[cue];
    if (file == null) return;
    try {
      await _playback.playSfx(file);
    } catch (_) {}
  }

  Future<void> startLoop(String cue) async {
    await warmUp();
    if (!musicEnabled) {
      await stopMusic();
      return;
    }
    final file = _fileFor(cue);
    if (file == null) {
      await stopMusic();
      return;
    }
    if (file == _currentLoop) return;
    try {
      await _playback.playLoop(file, volume: 0.5);
      _currentLoop = file;
    } catch (_) {
      _currentLoop = null;
    }
  }

  Future<void> stopMusic() async {
    if (_currentLoop == null) return;
    _currentLoop = null;
    try {
      await _playback.stopLoop();
    } catch (_) {}
  }
}
