import 'package:flutter/material.dart';

import '../game/backyard_barrage_game.dart';
import '../game/components/kid_component.dart';
import 'barrage_colors.dart';
import 'coin_amount.dart';
import 'draft_button.dart';
import 'ui_kit.dart';

/// Screen-space fight chrome. Hearts, coins, the fort meter, and pause stay
/// at logical pixels so the 1280×720 letterbox does not shrink them.
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
      ]),
      builder: (context, _) {
        final phase = game.phase;
        final show = phase == MatchPhase.fight || phase == MatchPhase.clearing;
        if (!show) return const SizedBox.shrink();
        final fort = game.fort;
        final fraction = fort.maxHp <= 0 ? 0.0 : fort.hp / fort.maxHp;
        final fighting = phase == MatchPhase.fight;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
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
                        const SizedBox(width: 8),
                        _HudChip(
                          key: const Key('hud-crew'),
                          child: _HeartCluster(
                            label: 'You',
                            kids: game.players,
                            idPrefix: 'you',
                          ),
                        ),
                        const SizedBox(width: 8),
                        _HudChip(
                          key: const Key('hud-fort'),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Wave ${game.wave}',
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
                        const SizedBox(width: 8),
                        _HudChip(
                          key: const Key('hud-rivals'),
                          child: _HeartCluster(
                            label: 'Rivals',
                            kids: game.enemies,
                            idPrefix: 'rival',
                          ),
                        ),
                        const SizedBox(width: 8),
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
                if (fighting) ...[
                  const SizedBox(height: 6),
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _HudChip(
                      child: Text(
                        'Left thumb moves and aims  ·  hold Throw',
                        key: Key('hud-hint'),
                        style: BarrageType.muted,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _ThrowButton(game: game),
                  ),
                  const SizedBox(height: 8),
                  _PowerBar(charge: game.chargeListenable.value),
                ],
              ],
            ),
          ),
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
    final chip = UiKitScope.of(context).hudChip;
    return DecoratedBox(
      decoration: BoxDecoration(
        image: chip == null
            ? null
            : DecorationImage(image: AssetImage(chip), fit: BoxFit.fill),
        color: chip == null ? const Color(0xF2FFF8F0) : null,
        borderRadius: chip == null ? BorderRadius.circular(16) : null,
        border: chip == null
            ? Border.all(color: const Color(0xFF2C3E50), width: 3)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: child,
      ),
    );
  }
}

class _HeartCluster extends StatelessWidget {
  const _HeartCluster({
    required this.label,
    required this.kids,
    required this.idPrefix,
  });

  final String label;
  final List<KidComponent> kids;
  final String idPrefix;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: BarrageType.muted.copyWith(fontSize: 12)),
        const SizedBox(width: 6),
        for (var row = 0; row < kids.length; row++) ...[
          if (row > 0) const SizedBox(width: 6),
          for (var i = 0; i < kids[row].maxHp; i++)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Image.asset(
                i < kids[row].hp
                    ? UiKitScope.of(context).heart
                    : UiKitScope.of(context).heartEmpty,
                key: Key('hud-heart-$idPrefix-$row-$i'),
                width: 20,
                height: 20,
              ),
            ),
        ],
      ],
    );
  }
}

class _FortMeter extends StatelessWidget {
  const _FortMeter({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final kit = UiKitScope.of(context);
    final amount = fraction.clamp(0.0, 1.0);
    return SizedBox(
      width: 148,
      height: 22,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(kit.fortEmpty, fit: BoxFit.fill),
          ClipRect(
            clipper: _WidthClipper(amount),
            child: Image.asset(kit.fortFill, fit: BoxFit.fill),
          ),
        ],
      ),
    );
  }
}

class _ThrowButton extends StatelessWidget {
  const _ThrowButton({required this.game});

  final BackyardBarrageGame game;

  @override
  Widget build(BuildContext context) {
    final kit = UiKitScope.of(context);
    return GestureDetector(
      key: const Key('throw-button'),
      onTapDown: (_) => game.pressThrowButton(),
      onTapUp: (_) => game.releaseThrowButton(),
      onTapCancel: game.releaseThrowButton,
      child: SizedBox(
        width: 168,
        height: 72,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(child: Image.asset(kit.primary, fit: BoxFit.fill)),
            Text(
              'Throw',
              style: BarrageType.button.copyWith(
                color: kit.labelOn(true),
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PowerBar extends StatelessWidget {
  const _PowerBar({required this.charge});

  final double charge;

  @override
  Widget build(BuildContext context) {
    final kit = UiKitScope.of(context);
    final amount = charge.clamp(0.0, 1.0);
    return SizedBox(
      key: const Key('power-bar'),
      height: 28,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xCC1A2332),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kit.cream, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: constraints.maxWidth * amount,
                  height: constraints.maxHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: amount >= 0.995 ? Colors.white : kit.charge,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
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
