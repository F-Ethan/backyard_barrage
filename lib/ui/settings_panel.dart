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
    return Material(
      color: const Color(0xCC2C3E50),
      child: SafeArea(
        child: Center(
          child: SizedBox(
            width: 560,
            height: 400,
            child: KitPanel(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const Text(
                      'Settings',
                      style: TextStyle(
                        color: BarrageColors.ink,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
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
                    const SizedBox(height: 4),
                    const Text(
                      'SFX and music play when audio files are added.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: BarrageColors.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Credits',
                      style: TextStyle(
                        color: BarrageColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'GameLogic',
                      style: TextStyle(
                        color: BarrageColors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'Ethan',
                      style: TextStyle(
                        color: BarrageColors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Text(
                      'Snowballs and water balloons.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: BarrageColors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DraftImageButton(
                      key: const Key('settings-back'),
                      label: 'Back',
                      asset: UiAssets.secondary,
                      width: 160,
                      height: 44,
                      feel: widget.feel,
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),
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
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: BarrageColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Switch(
          key: switchKey,
          value: value,
          activeThumbColor: const Color(0xFF3D7CFF),
          activeTrackColor: const Color(0x733D7CFF),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
