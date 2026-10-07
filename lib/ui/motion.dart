import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'barrage_theme.dart';

/// Entrance helpers on top of `flutter_animate`. Every helper returns the
/// child untouched under reduced motion, so screens settle on frame one.
extension BarrageEntrance on Widget {
  /// Fade + rise. [index] staggers siblings by the motion stagger token.
  /// The stagger is an effect delay (inside the controller timeline), not an
  /// `Animate.delay` timer.
  Widget enterRise(
    BuildContext context, {
    int index = 0,
    double rise = 0.12,
    Key? key,
  }) {
    final motion = context.motion;
    if (motion.reduced) return this;
    final delay = motion.stagger * index;
    return animate(key: key)
        .fadeIn(delay: delay, duration: motion.slow, curve: motion.enter)
        .slideY(
          begin: rise,
          end: 0,
          delay: delay,
          duration: motion.slow,
          curve: motion.enter,
        );
  }

  /// Panel pop for sheets and banners: fade + springy scale + small slide.
  Widget enterPop(
    BuildContext context, {
    double scaleFrom = 0.92,
    double slideFrom = 0.04,
    Key? key,
  }) {
    final motion = context.motion;
    if (motion.reduced) return this;
    return animate(key: key)
        .fadeIn(duration: motion.medium, curve: motion.enter)
        .scale(
          begin: Offset(scaleFrom, scaleFrom),
          end: const Offset(1, 1),
          duration: motion.slow,
          curve: motion.spring,
        )
        .slideY(
          begin: slideFrom,
          end: 0,
          duration: motion.slow,
          curve: motion.enter,
        );
  }
}

/// Modal chrome shared by pause, settings, shop, and defeat: the scrim fades
/// in and the sheet pops. [child] is the sheet.
class ModalShell extends StatelessWidget {
  const ModalShell({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final motion = context.motion;
    Widget scrim = ColoredBox(color: tokens.scrim);
    if (!motion.reduced) {
      scrim = scrim.animate().fadeIn(
        duration: motion.medium,
        curve: motion.enter,
      );
    }
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Swallow taps so nothing under the modal reacts.
          AbsorbPointer(child: scrim),
          SafeArea(
            child: Padding(
              padding: padding ?? EdgeInsets.all(tokens.space.md),
              child: Center(child: child.enterPop(context)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Frosted cream sheet drawn in Flutter (no stretched PNG corners).
class SheetSurface extends StatelessWidget {
  const SheetSurface({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: tokens.radii.sheetAll,
        border: Border.all(color: tokens.hairline),
        boxShadow: tokens.shadowLifted,
      ),
      child: ClipRRect(
        borderRadius: tokens.radii.sheetAll,
        child: Padding(
          padding:
              padding ??
              EdgeInsets.fromLTRB(
                tokens.space.xl,
                tokens.space.xl,
                tokens.space.xl,
                tokens.space.lg,
              ),
          child: child,
        ),
      ),
    );
  }
}

/// [AnimatedSwitcher] that is a plain pass-through under reduced motion, so
/// the old child never lingers for a frame.
class MotionSwitcher extends StatelessWidget {
  const MotionSwitcher({
    super.key,
    required this.child,
    this.slide = const Offset(0, 0.04),
    this.scaleFrom = 1,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final Offset slide;
  final double scaleFrom;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    if (motion.reduced) return child;
    return AnimatedSwitcher(
      duration: motion.medium,
      reverseDuration: motion.fast,
      switchInCurve: motion.enter,
      switchOutCurve: motion.exit,
      layoutBuilder: (current, previous) =>
          Stack(alignment: alignment, children: [...previous, ?current]),
      transitionBuilder: (child, animation) {
        Widget out = FadeTransition(opacity: animation, child: child);
        if (slide != Offset.zero) {
          out = SlideTransition(
            position: Tween(begin: slide, end: Offset.zero).animate(animation),
            child: out,
          );
        }
        if (scaleFrom != 1) {
          out = ScaleTransition(
            scale: Tween(begin: scaleFrom, end: 1.0).animate(animation),
            child: out,
          );
        }
        return out;
      },
      child: child,
    );
  }
}

/// Springy press feedback: shrinks while held, bounces back on release.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    required this.onTap,
    this.enabled = true,
    this.pressedScale = 0.94,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final double pressedScale;
  final HitTestBehavior behavior;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  bool get _live => widget.enabled && widget.onTap != null;

  void _set(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _live ? (_) => _set(true) : null,
      onTapUp: _live ? (_) => _set(false) : null,
      onTapCancel: _live ? () => _set(false) : null,
      onTap: _live ? widget.onTap : null,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: _down ? motion.fast : motion.slow,
        curve: _down ? motion.enter : motion.settle,
        child: widget.child,
      ),
    );
  }
}
