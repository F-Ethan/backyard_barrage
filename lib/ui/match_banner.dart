import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../game/components/overlay_banner.dart';
import 'barrage_colors.dart';
import 'barrage_theme.dart';

/// Screen-space center banner (KO, Wave N, wave clear, Crew down).
///
/// Sized from the screen, not the 1280×720 yard, so it keeps readable type on
/// a letterboxed phone. Enters with a springy pop; leaves on the next cut so
/// the game's banner timing stays exactly as it was.
class MatchBanner extends StatelessWidget {
  const MatchBanner({super.key, required this.spec});

  final BannerSpec? spec;

  @override
  Widget build(BuildContext context) {
    final spec = this.spec;
    if (spec == null) return const SizedBox.shrink();
    final tokens = context.tokens;
    final motion = context.motion;
    final size = MediaQuery.sizeOf(context);
    final base = (size.shortestSide * 0.11).clamp(30.0, 64.0);
    final titleSize = base * spec.emphasis.clamp(0.8, 1.4);
    final accent = spec.accent;
    final card = ConstrainedBox(
      key: Key('match-banner-${spec.serial}'),
      constraints: BoxConstraints(maxWidth: (size.width * 0.8).clamp(0, 720)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: accent ? tokens.ink : tokens.surface,
          borderRadius: tokens.radii.sheetAll,
          border: Border.all(
            color: accent ? spec.color.withValues(alpha: 0.6) : tokens.hairline,
            width: accent ? 2 : 1,
          ),
          boxShadow: tokens.shadowLifted,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.space.xxl,
            vertical: tokens.space.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                spec.label,
                key: const Key('match-banner-title'),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: BarrageType.display.copyWith(
                  fontSize: titleSize,
                  color: accent ? spec.color : tokens.ink,
                  letterSpacing: 0.6,
                ),
              ),
              if (spec.subtitle != null) ...[
                SizedBox(height: tokens.space.xs),
                Text(
                  spec.subtitle!,
                  key: const Key('match-banner-subtitle'),
                  textAlign: TextAlign.center,
                  style: BarrageType.heading.copyWith(
                    fontSize: (titleSize * 0.42).clamp(16.0, 26.0),
                    fontWeight: FontWeight.w500,
                    color: accent ? tokens.onPrimary : tokens.inkMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    Widget banner = card;
    if (!motion.reduced) {
      banner = card
          .animate(key: ValueKey(spec.serial))
          .fadeIn(duration: motion.fast, curve: motion.enter)
          .scale(
            begin: Offset(accent ? 0.55 : 0.8, accent ? 0.55 : 0.8),
            end: const Offset(1, 1),
            duration: motion.slow,
            curve: motion.spring,
          )
          .slideY(
            begin: 0.25,
            end: 0,
            duration: motion.slow,
            curve: motion.enter,
          );
      if (accent) {
        banner = banner
            .animate(key: ValueKey('shake-${spec.serial}'))
            .shake(
              delay: motion.medium,
              duration: motion.medium,
              hz: 5,
              rotation: 0.03,
            );
      }
    }
    return IgnorePointer(
      child: Align(
        // Slightly above center, where the canvas banner used to sit.
        alignment: const Alignment(0, -0.12),
        child: banner,
      ),
    );
  }
}
