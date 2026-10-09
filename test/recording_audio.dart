import 'package:backyard_barrage/audio/game_audio.dart';
import 'package:backyard_barrage/feel/game_haptics.dart';

class RecordingPlayback extends AudioPlayback {
  final sfx = <String>[];
  final loops = <String>[];
  int stops = 0;

  /// Volume of each one-shot, by file.
  final volumes = <String, double>{};

  @override
  Future<void> playSfx(String relativePath, {double volume = 1}) async {
    sfx.add(relativePath);
    volumes[relativePath] = volume;
  }

  @override
  Future<void> playLoop(String relativePath, {double volume = 0.5}) async {
    loops.add(relativePath);
  }

  @override
  Future<void> stopLoop() async {
    stops += 1;
  }

  final sfxLoops = <String>[];
  int sfxLoopStops = 0;

  @override
  Future<void> startSfxLoop(String relativePath) async {
    sfxLoops.add(relativePath);
  }

  @override
  Future<void> stopSfxLoop() async {
    sfxLoopStops += 1;
  }
}

class RecordingPulse extends HapticPulse {
  final kinds = <String>[];

  @override
  Future<void> light() async => kinds.add('light');

  @override
  Future<void> medium() async => kinds.add('medium');

  @override
  Future<void> heavy() async => kinds.add('heavy');
}
