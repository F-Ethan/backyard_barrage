import 'package:flutter/material.dart';

import '../feel/feel_bus.dart';
import 'barrage_colors.dart';
import 'ui_assets.dart';

class DraftImageButton extends StatefulWidget {
  const DraftImageButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.width = 220,
    this.height = 52,
    this.asset = UiAssets.primary,
    this.feel,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final double width;
  final double height;
  final String asset;
  final FeelBus? feel;

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
    final pressedArt = widget.asset == UiAssets.primary && _down && _canTap;
    final scale = _down && _canTap && !pressedArt ? 0.97 : 1.0;
    return Opacity(
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
            width: widget.width,
            height: widget.height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    pressedArt ? UiAssets.primaryPressed : widget.asset,
                    fit: BoxFit.fill,
                  ),
                ),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: BarrageColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
