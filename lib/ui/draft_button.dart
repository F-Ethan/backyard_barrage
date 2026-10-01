import 'package:flutter/material.dart';

import '../feel/feel_bus.dart';
import 'barrage_colors.dart';
import 'ui_assets.dart';

/// Pill CTA from the v2 kit. Primary art is blue, so its label is cream.
class DraftImageButton extends StatefulWidget {
  const DraftImageButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.width = 224,
    this.height = 70,
    this.asset = UiAssets.primary,
    this.feel,
    this.expand = false,
    this.leading,
    this.fontSize = 16,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final double width;
  final double height;
  final String asset;
  final FeelBus? feel;
  final bool expand;
  final String? leading;
  final double fontSize;

  @override
  State<DraftImageButton> createState() => _DraftImageButtonState();
}

class _DraftImageButtonState extends State<DraftImageButton> {
  bool _down = false;

  bool get _canTap => widget.enabled && widget.onPressed != null;

  bool get _primary => widget.asset == UiAssets.primary;

  void _setDown(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final pressedArt = _primary && _down && _canTap;
    final scale = _down && _canTap && !pressedArt ? 0.98 : 1.0;
    final labelColor = _primary ? BarrageColors.onPrimary : BarrageColors.ink;
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
                Positioned.fill(
                  child: Image.asset(
                    pressedArt ? UiAssets.primaryPressed : widget.asset,
                    fit: BoxFit.fill,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.leading != null) ...[
                        Image.asset(widget.leading!, width: 28, height: 28),
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

/// Circular kit icon (`icon_pause_v2`, `icon_settings_v2`, `icon_close_v2`).
class KitIconButton extends StatelessWidget {
  const KitIconButton({
    super.key,
    required this.asset,
    required this.onPressed,
    this.feel,
    this.size = 56,
    this.semanticLabel,
  });

  final String asset;
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
        child: Image.asset(asset, width: size, height: size),
      ),
    );
  }
}