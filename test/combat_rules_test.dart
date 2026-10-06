import 'package:backyard_barrage/game/combat_rules.dart';
import 'package:backyard_barrage/game/throw_physics.dart';
import 'package:flame/extensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CombatRules', () {
    test('enemy count climbs across six waves, then holds', () {
      expect(CombatRules.enemyCountForWave(1), 1);
      expect(CombatRules.enemyCountForWave(2), 2);
      expect(CombatRules.enemyCountForWave(3), 3);
      expect(CombatRules.enemyCountForWave(4), 3);
      expect(CombatRules.enemyCountForWave(5), 3);
      expect(CombatRules.enemyCountForWave(6), 4);
      expect(CombatRules.enemyCountForWave(7), 5);
      expect(CombatRules.enemyCountForWave(8), 5);

      final early = WavePlan.forWave(3);
      final faster = WavePlan.forWave(4);
      final tougher = WavePlan.forWave(5);
      final more = WavePlan.forWave(6);
      expect(early.fasterThrows, isFalse);
      expect(early.bonusHp, 0);
      expect(faster.fasterThrows, isTrue);
      expect(faster.quickerSteps, isTrue);
      expect(faster.bonusHp, 0);
      expect(tougher.bonusHp, 1);
      expect(tougher.rivalCount, faster.rivalCount);
      expect(more.rivalCount, greaterThan(tougher.rivalCount));
      expect(more.bonusHp, tougher.bonusHp);
    });

    test('fort HP grows by stage and refills to that max', () {
      expect(CombatRules.fortMaxHp(1), 6);
      expect(CombatRules.fortMaxHp(2), greaterThan(CombatRules.fortMaxHp(1)));
      expect(CombatRules.fortMaxHp(3), greaterThan(CombatRules.fortMaxHp(2)));
    });

    test('throw rank shortens charge and raises lob speed', () {
      expect(CombatRules.playerChargeSeconds(0), 3);
      expect(
        CombatRules.playerChargeSeconds(5),
        lessThan(CombatRules.playerChargeSeconds(0)),
      );
      expect(CombatRules.playerChargeSeconds(5), greaterThanOrEqualTo(1.7));
      expect(CombatRules.projectileSpeedScale(0), 1);
      expect(
        CombatRules.projectileSpeedScale(5),
        greaterThan(CombatRules.projectileSpeedScale(1)),
      );
    });

    test('later waves aim tighter', () {
      expect(
        CombatRules.enemyAimJitterRadians(4),
        lessThan(CombatRules.enemyAimJitterRadians(1)),
      );
      expect(CombatRules.enemyAimJitterRadians(20), 0.08);
    });

    test('round ends when one side is gone', () {
      expect(
        CombatRules.roundOutcome(livingPlayers: 1, livingEnemies: 2),
        RoundOutcome.ongoing,
      );
      expect(
        CombatRules.roundOutcome(livingPlayers: 2, livingEnemies: 0),
        RoundOutcome.waveClear,
      );
      expect(
        CombatRules.roundOutcome(livingPlayers: 0, livingEnemies: 0),
        RoundOutcome.defeat,
      );
    });

    test('enemy shots stick in a living fort and miss once it is down', () {
      final rect = Rect.fromLTWH(100, 200, 80, 120);
      expect(
        CombatRules.fortAbsorbsShot(
          fortHp: 3,
          fromEnemy: true,
          fortRect: rect,
          center: Vector2(140, 260),
          radius: 10,
        ),
        isTrue,
      );
      expect(
        CombatRules.fortAbsorbsShot(
          fortHp: 0,
          fromEnemy: true,
          fortRect: rect,
          center: Vector2(140, 260),
          radius: 10,
        ),
        isFalse,
      );
      expect(
        CombatRules.fortAbsorbsShot(
          fortHp: 3,
          fromEnemy: false,
          fortRect: rect,
          center: Vector2(140, 260),
          radius: 10,
        ),
        isFalse,
      );
      expect(ThrowPhysics.circleHitsRect(Vector2(140, 40), 10, rect), isFalse);
    });

    test('three hits KO, with the SnowCraft stun windows', () {
      expect(CombatRules.hitsToKo, 3);
      expect(CombatRules.enemyBrushOffSeconds, inInclusiveRange(0.8, 1.2));
      expect(
        CombatRules.enemyKnockdownSeconds,
        greaterThan(CombatRules.enemyBrushOffSeconds),
      );
      expect(CombatRules.allyStunSeconds, closeTo(2.8125, 0.001));

      final brush = CombatRules.resolveHit(
        ally: false,
        hp: 3,
        maxHp: 3,
        stunned: false,
        fragile: false,
      );
      expect(brush.knockedOut, isFalse);
      expect(brush.knockdown, isFalse);
      expect(brush.hp, 2);
      expect(brush.lockSeconds, CombatRules.enemyBrushOffSeconds);

      final down = CombatRules.resolveHit(
        ally: false,
        hp: brush.hp,
        maxHp: 3,
        stunned: true,
        fragile: false,
      );
      expect(down.knockedOut, isFalse);
      expect(down.knockdown, isTrue);
      expect(down.hp, 1);
      expect(down.lockSeconds, CombatRules.enemyKnockdownSeconds);

      final ko = CombatRules.resolveHit(
        ally: false,
        hp: down.hp,
        maxHp: 3,
        stunned: true,
        fragile: false,
      );
      expect(ko.knockedOut, isTrue);
      expect(ko.hp, 0);

      final stun = CombatRules.resolveHit(
        ally: true,
        hp: 3,
        maxHp: 3,
        stunned: false,
        fragile: false,
      );
      expect(stun.knockedOut, isFalse);
      expect(stun.fragile, isTrue);
      expect(stun.hp, 2);
      expect(stun.lockSeconds, CombatRules.allyStunSeconds);

      final fragileKo = CombatRules.resolveHit(
        ally: true,
        hp: stun.hp,
        maxHp: 3,
        stunned: true,
        fragile: true,
      );
      expect(fragileKo.knockedOut, isTrue);
      expect(fragileKo.hp, 0);

      final after = CombatRules.resolveHit(
        ally: true,
        hp: 2,
        maxHp: 3,
        stunned: false,
        fragile: false,
      );
      expect(after.knockedOut, isFalse);
      expect(after.fragile, isTrue);
      expect(after.hp, 1);
    });

    test('fewer enemy hits KO sooner and keep the brush-off length', () {
      final one = CombatRules.resolveHit(
        ally: false,
        hp: 1,
        maxHp: 1,
        stunned: false,
        fragile: false,
      );
      expect(one.knockedOut, isTrue);
      expect(one.lockSeconds, 0);

      final brush = CombatRules.resolveHit(
        ally: false,
        hp: 2,
        maxHp: 2,
        stunned: false,
        fragile: false,
      );
      expect(brush.knockedOut, isFalse);
      expect(brush.knockdown, isFalse);
      expect(brush.hp, 1);
      expect(brush.lockSeconds, CombatRules.enemyBrushOffSeconds);

      final ko = CombatRules.resolveHit(
        ally: false,
        hp: brush.hp,
        maxHp: 2,
        stunned: true,
        fragile: false,
      );
      expect(ko.knockedOut, isTrue);
      expect(ko.hp, 0);
    });

    test('taller forts reach higher', () {
      final anchor = Vector2(280, 670);
      final size = Vector2.all(360);
      final low = CombatRules.fortHitRect(
        stage: 1,
        anchorBottomCenter: anchor,
        spriteSize: size,
      );
      final high = CombatRules.fortHitRect(
        stage: 3,
        anchorBottomCenter: anchor,
        spriteSize: size,
      );
      expect(high.top, lessThan(low.top));
      expect(high.bottom, closeTo(low.bottom, 0.01));
    });
  });
}
