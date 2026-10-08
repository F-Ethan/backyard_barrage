import 'package:flutter/material.dart';

import '../feel/feel_bus.dart';
import 'barrage_colors.dart';
import 'barrage_theme.dart';
import 'motion.dart';
import 'ui_assets.dart';

/// Pause, settings, and close glyphs.
enum UiIconKind { pause, settings, close }

extension UiIconKindAssets on UiIconKind {
  /// v2 circular icon sprite.
  String get asset => switch (this) {
    UiIconKind.pause => UiAssets.iconPause,
    UiIconKind.settings => UiAssets.iconSettings,
    UiIconKind.close => UiAssets.iconClose,
  };

  /// Tintable glyph for inline use (inside pills).
  IconData get icon => switch (this) {
    UiIconKind.pause => Icons.pause_rounded,
    UiIconKind.settings => Icons.settings_rounded,
    UiIconKind.close => Icons.close_rounded,
  };
}

/// Stadium CTA from the v2 shape language: blue gradient primary or
/// cream ghost secondary, soft shadow, springy press, `FeelBus.uiTap`.
///
/// The name predates the kit; the pill is drawn, not a stretched PNG.
class DraftImageButton extends StatelessWidget {
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
    this.leadingIcon,
    this.trailingIcon,
    this.fontSize = 16,
    this.back = false,
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
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final double fontSize;

  /// Plays the back sound instead of the tap (closing, leaving).
  final bool back;

  bool get _canTap => enabled && onPressed != null;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final motion = context.motion;
    final primary = !secondary;
    final live = _canTap;
    final labelColor = primary
        ? (live ? tokens.onPrimary : tokens.inkMuted)
        : (live ? tokens.ink : tokens.inkMuted);
    final leading = leadingIcon ?? leadingKind?.icon;
    final iconSize = (fontSize + 6).clamp(14.0, 30.0);
    final decoration = BoxDecoration(
      gradient: primary && live ? tokens.primaryGradient : null,
      color: primary
          ? (live ? null : tokens.lockedFill)
          : tokens.surface.withValues(alpha: live ? 0.96 : 0.7),
      borderRadius: BorderRadius.circular(999),
      border: primary
          ? null
          : Border.all(
              color: live
                  ? tokens.primary.withValues(alpha: 0.45)
                  : tokens.hairline,
              width: 1.5,
            ),
      boxShadow: !live
          ? null
          : primary
          ? tokens.shadowPrimary
          : tokens.shadowSoft,
    );
    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.space.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (leading != null) ...[
            Icon(leading, size: iconSize, color: labelColor),
            SizedBox(width: tokens.space.sm),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BarrageType.button.copyWith(
                color: labelColor,
                fontSize: fontSize,
              ),
            ),
          ),
          if (trailingIcon != null) ...[
            SizedBox(width: tokens.space.xs),
            Icon(trailingIcon, size: iconSize, color: labelColor),
          ],
        ],
      ),
    );
    final pill = AnimatedContainer(
      duration: motion.medium,
      curve: motion.enter,
      width: expand ? null : width,
      height: expand ? null : height,
      alignment: Alignment.center,
      decoration: decoration,
      child: content,
    );
    final button = Semantics(
      button: true,
      enabled: live,
      label: label,
      excludeSemantics: true,
      child: PressScale(
        enabled: live,
        onTap: live
            ? () {
                back ? feel?.uiBack() : feel?.uiTap();
                onPressed?.call();
              }
            : null,
        child: pill,
      ),
    );
    if (!expand) return button;
    return SizedBox.expand(child: button);
  }
}

/// Round v2 icon sprite with a springy press.
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
      child: PressScale(
        pressedScale: 0.88,
        onTap: () {
          kind == UiIconKind.close ? feel?.uiBack() : feel?.uiTap();
          onPressed();
        },
        child: UiGlyph(kind: kind, size: size),
      ),
    );
  }
}

/// The v2 circular icon sprite at [size].
class UiGlyph extends StatelessWidget {
  const UiGlyph({super.key, required this.kind, required this.size});

  final UiIconKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(kind.asset, width: size, height: size);
  }
}

/// Small pill label (season tag, "Owned", price chip).
class TagPill extends StatelessWidget {
  const TagPill({
    super.key,
    required this.child,
    this.color,
    this.borderColor,
    this.padding,
  });

  final Widget child;
  final Color? color;
  final Color? borderColor;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? tokens.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor ?? tokens.hairline),
      ),
      child: Padding(
        padding:
            padding ??
            EdgeInsets.symmetric(
              horizontal: tokens.space.md,
              vertical: tokens.space.xs + 2,
            ),
        child: child,
      ),
    );
  }
}
