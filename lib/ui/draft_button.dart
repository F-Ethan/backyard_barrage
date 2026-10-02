import 'package:flutter/material.dart';

import '../feel/feel_bus.dart';
import 'barrage_colors.dart';
import 'ui_kit.dart';

/// Pill CTA. Art and label color follow the active [UiKit].
class DraftImageButton extends StatefulWidget {
  const DraftImageButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.width = 224,
    this.height = 70,
    this.secondary = false,
    this.feel,
    this.expand = false,
    this.leadingKind,
    this.fontSize = 16,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final double width;
  final double height;
  final bool secondary;
  final FeelBus? feel;
  final bool expand;
  final UiIconKind? leadingKind;
  final double fontSize;

  @override
  State<DraftImageButton> createState() => _DraftImageButtonState();
}

class _DraftImageButtonState extends State<DraftImageButton> {
  bool _down = false;

  bool get _canTap => widget.enabled && widget.onPressed != null;

  void _setDown(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final kit = UiKitScope.of(context);
    final primary = !widget.secondary;
    final pressedArt = primary && _down && _canTap && kit.modern;
    final scale = _down && _canTap && !pressedArt ? 0.98 : 1.0;
    final labelColor = kit.labelOn(primary);
    final asset = pressedArt
        ? kit.primaryPressed
        : (primary ? kit.primary : kit.secondary);
    final leading = widget.leadingKind;
    final button = Opacity(
      opacity: _canTap ? 1 : 0.45,
      child: GestureDetector(
        onTapDown: _canTap ? (_) => _setDown(true) : null,
        onTapUp: _canTap ? (_) => _setDown(false) : null,
        onTapCancel: _canTap ? () => _setDown(false) : null,
        onTap: _canTap
            ? () {
                widget.feel?.uiTap();
                widget.onPressed?.call();
              }
            : null,
        child: Transform.scale(
          scale: scale,
          child: SizedBox(
            width: widget.expand ? null : widget.width,
            height: widget.expand ? null : widget.height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(child: Image.asset(asset, fit: BoxFit.fill)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (leading != null) ...[
                        _KitGlyph(kind: leading, size: 26, color: labelColor),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BarrageType.button.copyWith(
                            color: labelColor,
                            fontSize: widget.fontSize,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!widget.expand) return button;
    return SizedBox.expand(child: button);
  }
}

/// Circular icon. Modern kit uses the v2 sprite; classic draws an ink glyph.
class KitIconButton extends StatelessWidget {
  const KitIconButton({
    super.key,
    required this.kind,
    required this.onPressed,
    this.feel,
    this.size = 56,
    this.semanticLabel,
  });

  final UiIconKind kind;
  final VoidCallback onPressed;
  final FeelBus? feel;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: () {
          feel?.uiTap();
          onPressed();
        },
        child: _KitGlyph(kind: kind, size: size),
      ),
    );
  }
}

class UiGlyph extends StatelessWidget {
  const UiGlyph({
    super.key,
    required this.kind,
    required this.size,
    this.color,
  });

  final UiIconKind kind;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      _KitGlyph(kind: kind, size: size, color: color);
}

class _KitGlyph extends StatelessWidget {
  const _KitGlyph({required this.kind, required this.size, this.color});

  final UiIconKind kind;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final kit = UiKitScope.of(context);
    final asset = kit.iconAsset(kind);
    if (asset != null) {
      return Image.asset(asset, width: size, height: size);
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kit.cream,
        shape: BoxShape.circle,
        border: Border.all(color: kit.ink, width: 3),
      ),
      child: Icon(
        kit.iconData(kind),
        color: color ?? kit.ink,
        size: size * 0.52,
      ),
    );
  }
}
