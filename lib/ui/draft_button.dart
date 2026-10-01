import 'package:flutter/material.dart';

import 'barrage_colors.dart';

class DraftImageButton extends StatelessWidget {
  const DraftImageButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.width = 220,
    this.height = 52,
    this.asset = 'assets/images/ui/btn_primary_draft.png',
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final double width;
  final double height;
  final String asset;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && onPressed != null;
    return Opacity(
      opacity: canTap ? 1 : 0.45,
      child: GestureDetector(
        onTap: canTap ? onPressed : null,
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Image.asset(asset, fit: BoxFit.fill),
              ),
              Text(
                label,
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
    );
  }
}
