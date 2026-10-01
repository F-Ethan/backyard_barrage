import 'package:flutter/services.dart';

abstract class HapticPulse {
  const HapticPulse();

  Future<void> light();
  Future<void> medium();
  Future<void> heavy();
}

/// Flutter haptics. Platforms without a vibrator no-op.
class FlutterHapticPulse extends HapticPulse {
  const FlutterHapticPulse();

  Future<void> _run(Future<void> Function() pulse) async {
    try {
      await pulse();
    } catch (_) {}
  }

  @override
  Future<void> light() => _run(HapticFeedback.lightImpact);

  @override
  Future<void> medium() => _run(HapticFeedback.mediumImpact);

  @override
  Future<void> heavy() => _run(HapticFeedback.heavyImpact);
}

class GameHaptics {
  GameHaptics({this.enabled = true, HapticPulse? pulse})
    : _pulse = pulse ?? const FlutterHapticPulse();

  bool enabled;
  final HapticPulse _pulse;

  Future<void> chargeRelease() => _go(_pulse.light);

  Future<void> hit() => _go(_pulse.medium);

  Future<void> ko() => _go(_pulse.heavy);

  Future<void> purchase() => _go(_pulse.medium);

  Future<void> _go(Future<void> Function() pulse) async {
    if (!enabled) return;
    await pulse();
  }
}
