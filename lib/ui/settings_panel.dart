import 'package:flutter/material.dart';

import '../feel/feel_bus.dart';
import '../meta/difficulty.dart';
import '../meta/game_settings.dart';
import 'barrage_colors.dart';
import 'draft_button.dart';
import 'kit_panel.dart';
import 'ui_kit.dart';

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
    final height = (size.height - 24).clamp(220.0, 520.0).toDouble();
    final kit = UiKit.from(_settings);
    return Material(
      key: Key(kit.modern ? 'ui-kit-modern' : 'ui-kit-classic'),
      color: kit.scrim,
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
                        kind: UiIconKind.close,
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
                          _ToggleRow(
                            label: 'Modern UI',
                            value: _settings.modernUi,
                            switchKey: const Key('ui-style-toggle'),
                            onChanged: (value) =>
                                _set(_settings.copyWith(modernUi: value)),
                          ),
                          const SizedBox(height: 8),
                          _DifficultyPicker(
                            value: _settings.difficulty,
                            onChanged: (value) =>
                                _set(_settings.copyWith(difficulty: value)),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Sound, music, and haptics for this device. Modern UI is the new kit; turn it off for the classic wood look. Difficulty changes how often rivals throw and whether your own lobs can chip your fort.',
                            textAlign: TextAlign.center,
                            style: BarrageType.muted,
                          ),
                          const SizedBox(height: 12),
                          const Text('Credits', style: BarrageType.heading),
                          const SizedBox(height: 2),
                          const Text('GameLogic', style: BarrageType.body),
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
    final kit = UiKitScope.of(context);
    final onAsset = kit.toggleOn;
    final offAsset = kit.toggleOff;
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 84,
          height: 48,
          child: Center(
            child: onAsset != null && offAsset != null
                ? Image.asset(value ? onAsset : offAsset, width: 76, height: 38)
                : _ClassicSwitch(on: value, ink: kit.ink, cream: kit.cream),
          ),
        ),
      ),
    );
  }
}

class _ClassicSwitch extends StatelessWidget {
  const _ClassicSwitch({
    required this.on,
    required this.ink,
    required this.cream,
  });

  final bool on;
  final Color ink;
  final Color cream;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: on ? ink : cream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ink, width: 3),
      ),
      child: Align(
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: on ? cream : ink,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _DifficultyPicker extends StatelessWidget {
  const _DifficultyPicker({required this.value, required this.onChanged});

  final Difficulty value;
  final ValueChanged<Difficulty> onChanged;

  @override
  Widget build(BuildContext context) {
    final kit = UiKitScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Difficulty', style: BarrageType.body),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final mode in Difficulty.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _DifficultyChip(
                    key: Key('difficulty-${mode.name}'),
                    label: switch (mode) {
                      Difficulty.easy => 'Easy',
                      Difficulty.normal => 'Normal',
                      Difficulty.hard => 'Hard',
                    },
                    selected: value == mode,
                    ink: kit.ink,
                    cream: kit.cream,
                    onTap: () => onChanged(mode),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({
    super.key,
    required this.label,
    required this.selected,
    required this.ink,
    required this.cream,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color ink;
  final Color cream;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? ink : cream,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ink, width: 3),
          ),
          child: Text(
            label,
            style: BarrageType.body.copyWith(
              color: selected ? cream : ink,
              fontSize: 15,
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
          BarrageToggle(key: switchKey, value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
