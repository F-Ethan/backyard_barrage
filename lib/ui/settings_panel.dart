import 'package:flutter/material.dart';

import '../feel/feel_bus.dart';
import '../meta/game_settings.dart';
import 'barrage_colors.dart';
import 'draft_button.dart';
import 'kit_panel.dart';
import 'ui_assets.dart';

/// SFX, music, haptics, and a credits stub. Shared by the menu and pause.
class SettingsOverlay extends StatefulWidget {
  const SettingsOverlay({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.onClose,
    this.feel,
  });

  final GameSettings settings;
  final Future<void> Function(GameSettings next) onChanged;
  final VoidCallback onClose;
  final FeelBus? feel;

  @override
  State<SettingsOverlay> createState() => _SettingsOverlayState();
}

class _SettingsOverlayState extends State<SettingsOverlay> {
  late GameSettings _settings = widget.settings;

  @override
  void didUpdateWidget(SettingsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _settings = widget.settings;
    }
  }

  Future<void> _set(GameSettings next) async {
    setState(() => _settings = next);
    await widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = (size.width - 32).clamp(280.0, 560.0).toDouble();
    final height = (size.height - 24).clamp(220.0, 420.0).toDouble();
    return Material(
      color: BarrageColors.scrim,
      child: SafeArea(
        child: Center(
          child: SizedBox(
            width: width,
            height: height,
            child: KitPanel(
              padding: const EdgeInsets.fromLTRB(36, 28, 28, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Settings', style: BarrageType.title),
                      ),
                      KitIconButton(
                        key: const Key('settings-back'),
                        asset: UiAssets.iconClose,
                        semanticLabel: 'Back',
                        size: 48,
                        feel: widget.feel,
                        onPressed: widget.onClose,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _ToggleRow(
                            label: 'Sound effects',
                            value: _settings.sfxEnabled,
                            switchKey: const Key('sfx-toggle'),
                            onChanged: (value) =>
                                _set(_settings.copyWith(sfxEnabled: value)),
                          ),
                          _ToggleRow(
                            label: 'Music',
                            value: _settings.musicEnabled,
                            switchKey: const Key('music-toggle'),
                            onChanged: (value) =>
                                _set(_settings.copyWith(musicEnabled: value)),
                          ),
                          _ToggleRow(
                            label: 'Haptics',
                            value: _settings.hapticsEnabled,
                            switchKey: const Key('haptics-toggle'),
                            onChanged: (value) =>
                                _set(_settings.copyWith(hapticsEnabled: value)),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Sound, music, and haptics for this device.',
                            textAlign: TextAlign.center,
                            style: BarrageType.muted,
                          ),
                          const SizedBox(height: 12),
                          const Text('Credits', style: BarrageType.heading),
                          const SizedBox(height: 2),
                          const Text(
                            'GameLogic',
                            style: BarrageType.body,
                          ),
                          const Text('Ethan', style: BarrageType.muted),
                          const Text(
                            'Snowballs and water balloons.',
                            textAlign: TextAlign.center,
                            style: BarrageType.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Image toggle from `toggle_on_v2` / `toggle_off_v2`.
class BarrageToggle extends StatelessWidget {
  const BarrageToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 84,
          height: 48,
          child: Center(
            child: Image.asset(
              value ? UiAssets.toggleOn : UiAssets.toggleOff,
              width: 76,
              height: 38,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.switchKey,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final Key switchKey;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Expanded(child: Text(label, style: BarrageType.body)),
          BarrageToggle(
            key: switchKey,
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
