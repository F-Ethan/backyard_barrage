import 'dart:math' as math;

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
        final modern = UiKitScope.of(context).modern;
        final charge = game.chargeListenable.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (fighting && modern && charge > 0)
              Positioned.fill(
                child: IgnorePointer(child: _ChargeGlow(charge: charge)),
              ),
            SafeArea(
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
                            'Left thumb aims and steps  ·  right thumb charges',
                            key: Key('hud-hint'),
                            style: BarrageType.muted,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (!modern) _PowerBar(charge: charge),
                    ],
                  ],
                ),
              ),
            ),
            if (fighting)
              SafeArea(
                child: Stack(
                  children: [
                    Positioned(
                      left: 10,
                      bottom: modern ? 10 : 46,
                      child: _MoveStick(game: game),
                    ),
                    Positioned(
                      right: 10,
                      bottom: modern ? 10 : 46,
                      child: _ThrowStick(game: game, charge: charge),
                    ),
                  ],
                ),
              ),
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
            const Color(0xFFFFE66D).withValues(alpha: 0.10 + t * 0.38),
            const Color(0xFFFFE66D).withValues(alpha: 0.05 + t * 0.18),
            const Color(0xFFFFE66D).withValues(alpha: 0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
    );
  }
}

/// Right thumb. Hold anywhere on the ring to charge; release throws.
class _ThrowStick extends StatefulWidget {
  const _ThrowStick({required this.game, required this.charge});

  final BackyardBarrageGame game;
  final double charge;

  @override
  State<_ThrowStick> createState() => _ThrowStickState();
}

class _ThrowStickState extends State<_ThrowStick> {
  static const double _size = 148;
  int _pointers = 0;

  void _down(PointerDownEvent event) {
    _pointers += 1;
    if (_pointers == 1) widget.game.pressThrowButton();
    setState(() {});
  }

  void _up(PointerEvent event) {
    _pointers = math.max(0, _pointers - 1);
    if (_pointers == 0) widget.game.releaseThrowButton();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final charge = widget.charge.clamp(0.0, 1.0);
    final held = _pointers > 0 || charge > 0;
    return Semantics(
      button: true,
      label: 'Charge throw',
      child: Listener(
        key: const Key('throw-stick'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: SizedBox(
          width: _size,
          height: _size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(
                0xFFFFE66D,
              ).withValues(alpha: held ? 0.16 + charge * 0.28 : 0.10),
              border: Border.all(
                color: const Color(
                  0xFFFFE66D,
                ).withValues(alpha: held ? 0.85 : 0.45),
                width: held ? 4 : 3,
              ),
            ),
            child: Center(
              child: Container(
                width: 28 + charge * 36,
                height: 28 + charge * 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(
                    0xFFFFE66D,
                  ).withValues(alpha: 0.35 + charge * 0.55),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Left thumb. Deflect to step, or to aim while the right thumb is charging.
class _MoveStick extends StatefulWidget {
  const _MoveStick({required this.game});

  final BackyardBarrageGame game;

  @override
  State<_MoveStick> createState() => _MoveStickState();
}

class _MoveStickState extends State<_MoveStick> {
  static const double _size = 128;
  static const double _reach = 36;
  int? _pointer;
  Offset _knob = Offset.zero;

  void _down(PointerDownEvent event) {
    _pointer = event.pointer;
    _apply(event.localPosition);
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    _apply(event.localPosition);
  }

  void _apply(Offset local) {
    const center = Offset(_size / 2, _size / 2);
    var delta = local - center;
    if (delta.distance > _reach) {
      delta = Offset.fromDirection(delta.direction, _reach);
    }
    setState(() => _knob = delta);
    widget.game.setMoveStick(delta);
  }

  void _end(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    setState(() => _knob = Offset.zero);
    widget.game.clearMoveStick();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Aim and move',
      child: Listener(
        key: const Key('move-stick'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _end,
        onPointerCancel: _end,
        child: SizedBox(
          width: _size,
          height: _size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF3D7CFF).withValues(alpha: 0.16),
              border: Border.all(
                color: const Color(0xFF3D7CFF).withValues(alpha: 0.55),
                width: 3,
              ),
            ),
            child: Center(
              child: Transform.translate(
                offset: _knob,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF3D7CFF).withValues(alpha: 0.82),
                  ),
                ),
              ),
            ),
          ),
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
    final amount = charge.clamp(0.0, 1.0);
    return SizedBox(
      key: const Key('power-bar'),
      height: 28,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF8B5E3C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2C3E50), width: 3),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F0),
              borderRadius: BorderRadius.circular(4),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: constraints.maxWidth * amount,
                    height: constraints.maxHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: amount >= 0.995
                            ? const Color(0xFFFFFFFF)
                            : const Color(0xFFFFE66D),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                );
              },
            ),
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
