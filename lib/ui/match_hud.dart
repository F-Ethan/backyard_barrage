import 'package:flutter/material.dart';

import '../game/backyard_barrage_game.dart';
import '../game/game_art.dart';
import '../meta/meta_state.dart';
import '../meta/play_mode.dart';
import 'barrage_colors.dart';
import 'barrage_theme.dart';
import 'coin_amount.dart';
import 'draft_button.dart';
import 'match_banner.dart';
import 'power_up_ui.dart';
import 'ui_assets.dart';

/// Screen-space fight chrome. Hearts, coins, the fort meter, pause, and the
/// center banner stay at logical pixels so the 1280×720 letterbox does not
/// shrink them.
class MatchHud extends StatelessWidget {
  const MatchHud({super.key, required this.game});

  final BackyardBarrageGame game;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        game.phaseListenable,
        game.hudRevision,
        game.chargeListenable,
        game.bannerListenable,
      ]),
      builder: (context, _) {
        final phase = game.phase;
        final show =
            phase == MatchPhase.entering ||
            phase == MatchPhase.fight ||
            phase == MatchPhase.clearing;
        // The banner also runs through the defeat beat, after the fight
        // chrome is gone. Pause and the other modals stack above the HUD.
        final banner = MatchBanner(spec: game.bannerListenable.value);
        if (!show) return banner;
        final fort = game.fort;
        final fraction = fort.maxHp <= 0 ? 0.0 : fort.hp / fort.maxHp;
        final fighting = phase == MatchPhase.fight;
        final chargeZone = fighting || phase == MatchPhase.entering;
        final charge = game.chargeListenable.value;
        final tokens = context.tokens;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (chargeZone) _PlayZones(game: game),
            if (fighting && charge > 0)
              Positioned.fill(
                child: IgnorePointer(child: _ChargeGlow(charge: charge)),
              ),
            // Freeze all: frost creeps in from the edges while it lasts.
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  key: const Key('freeze-frost'),
                  opacity: fighting && game.freezeLeft > 0 ? 0.85 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Image.asset(
                    'assets/images/${GameArt.frostCrust}',
                    fit: BoxFit.fill,
                  ),
                ),
              ),
            ),
            if (fighting)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: SafeArea(
                  child: Padding(
                    // Bottom-left, under the left thumb. The top inset
                    // keeps a tall stack clear of the status chips.
                    padding: EdgeInsets.fromLTRB(
                      tokens.space.md,
                      120,
                      0,
                      tokens.space.lg,
                    ),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: PowerUpBar(game: game),
                    ),
                  ),
                ),
              ),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.space.md,
                  tokens.space.sm,
                  tokens.space.md,
                  tokens.space.sm,
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            KitIconButton(
                              key: const Key('pause-button'),
                              kind: UiIconKind.pause,
                              semanticLabel: 'Pause',
                              feel: game.feel,
                              onPressed: game.pauseMatch,
                            ),
                            SizedBox(width: tokens.space.sm),
                            _HudChip(
                              key: const Key('hud-fort'),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    game.meta.mode == PlayMode.campaign
                                        ? 'Stage ${MetaState.stageOf(game.wave)} · Wave ${game.wave}'
                                        : 'Wave ${game.wave}',
                                    key: const Key('hud-wave'),
                                    style: BarrageType.heading.copyWith(
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _FortMeter(fraction: fraction),
                                ],
                              ),
                            ),
                            SizedBox(width: tokens.space.sm),
                            _HudChip(
                              key: const Key('hud-rivals'),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Hearts show over each kid now; the
                                  // chip just counts who is left.
                                  Text(
                                    'Rivals ${game.enemies.where((kid) => !kid.isBoss && !kid.isKo).length}',
                                    key: const Key('hud-rivals-left'),
                                    style: BarrageType.heading.copyWith(
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (game.rivalsWaiting > 0) ...[
                                    const SizedBox(width: 6),
                                    TagPill(
                                      key: const Key('hud-rivals-waiting'),
                                      child: Text(
                                        '+${game.rivalsWaiting} waiting',
                                        style: BarrageType.overline,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            SizedBox(width: tokens.space.sm),
                            _HudChip(
                              key: const Key('hud-coins'),
                              child: CoinAmount(
                                amount: game.meta.coins,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (game.boss != null) ...[
                      const SizedBox(height: 6),
                      _BossBar(game: game),
                    ],
                    if (fighting) ...[
                      const SizedBox(height: 6),
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _HudChip(
                          child: Text(
                            'Drag on the left to move  ·  hold the right side to throw',
                            key: Key('hud-hint'),
                            style: BarrageType.muted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            banner,
          ],
        );
      },
    );
  }
}

class _HudChip extends StatelessWidget {
  const _HudChip({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surfaceFrost,
        borderRadius: tokens.radii.chipAll,
        border: Border.all(color: tokens.hairline),
        boxShadow: tokens.shadowSoft,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space.md,
          vertical: tokens.space.sm,
        ),
        child: child,
      ),
    );
  }
}

/// The boss's name and a bar that drains with each hit.
class _BossBar extends StatelessWidget {
  const _BossBar({required this.game});

  final BackyardBarrageGame game;

  @override
  Widget build(BuildContext context) {
    final boss = game.boss!;
    final tokens = context.tokens;
    final fraction = boss.maxHp <= 0 ? 0.0 : boss.hp / boss.maxHp;
    return _HudChip(
      key: const Key('boss-bar'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            game.bossType?.label ?? 'Boss',
            style: BarrageType.heading.copyWith(
              fontSize: 14,
              color: const Color(0xFF9B59B6),
            ),
          ),
          SizedBox(width: tokens.space.sm),
          SizedBox(
            width: 180,
            height: 12,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: tokens.lockedFill),
                  FractionallySizedBox(
                    key: const Key('boss-bar-fill'),
                    alignment: Alignment.centerLeft,
                    widthFactor: fraction.clamp(0.0, 1.0),
                    child: const ColoredBox(color: Color(0xFF9B59B6)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FortMeter extends StatelessWidget {
  const _FortMeter({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    final amount = fraction.clamp(0.0, 1.0);
    return SizedBox(
      width: 148,
      height: 22,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: amount),
        duration: motion.slow,
        curve: motion.enter,
        builder: (context, value, _) => Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(UiAssets.fortEmpty, fit: BoxFit.fill),
            ClipRect(
              clipper: _WidthClipper(value),
              child: Image.asset(UiAssets.fortFill, fit: BoxFit.fill),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChargeGlow extends StatelessWidget {
  const _ChargeGlow({required this.charge});

  final double charge;

  @override
  Widget build(BuildContext context) {
    final t = charge.clamp(0.0, 1.0);
    return DecoratedBox(
      key: const Key('charge-glow'),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          radius: 0.18 + t * 1.25,
          colors: [
            BarrageColors.charge.withValues(alpha: 0.10 + t * 0.38),
            BarrageColors.charge.withValues(alpha: 0.05 + t * 0.18),
            BarrageColors.charge.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
    );
  }
}

/// Left two-thirds step the selected kid. The right third charges a throw.
class _PlayZones extends StatelessWidget {
  const _PlayZones({required this.game});

  final BackyardBarrageGame game;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chargeWidth =
            constraints.maxWidth *
            (1 - BackyardBarrageGame.chargeScreenFraction);
        return Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              right: chargeWidth,
              child: Listener(
                key: const Key('move-zone'),
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) {
                  game.pressMoveZone(game.screenToWorld(event.localPosition));
                },
                onPointerMove: (event) {
                  game.dragMoveZone(game.screenToWorld(event.localPosition));
                },
                onPointerUp: (_) => game.releaseMoveZone(),
                onPointerCancel: (_) => game.releaseMoveZone(),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: chargeWidth,
              child: Listener(
                key: const Key('charge-zone'),
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => game.pressChargeZone(),
                onPointerUp: (_) => game.releaseChargeZone(),
                onPointerCancel: (_) => game.releaseChargeZone(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WidthClipper extends CustomClipper<Rect> {
  const _WidthClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * fraction, size.height);
  }

  @override
  bool shouldReclip(covariant _WidthClipper oldClipper) {
    return oldClipper.fraction != fraction;
  }
}
