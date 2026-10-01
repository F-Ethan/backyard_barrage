import 'package:backyard_barrage/game/combat_rules.dart';
import 'package:backyard_barrage/game/throw_physics.dart';
import 'package:flame/extensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CombatRules', () {
    test('enemy count starts at 2 and caps at 3', () {
      expect(CombatRules.enemyCountForWave(1), 2);
      expect(CombatRules.enemyCountForWave(2), 3);
      expect(CombatRules.enemyCountForWave(8), 3);
    });

    test('fort HP grows by stage and refills to that max', () {
      expect(CombatRules.fortMaxHp(1), 6);
      expect(CombatRules.fortMaxHp(2), greaterThan(CombatRules.fortMaxHp(1)));
      expect(CombatRules.fortMaxHp(3), greaterThan(CombatRules.fortMaxHp(2)));
    });

    test('throw rank shortens charge and raises lob speed', () {
      expect(CombatRules.playerChargeSeconds(0), 0.85);
      expect(
        CombatRules.playerChargeSeconds(5),
        lessThan(CombatRules.playerChargeSeconds(0)),
      );
      expect(CombatRules.projectileSpeedScale(0), 1);
      expect(
        CombatRules.projectileSpeedScale(5),
        greaterThan(CombatRules.projectileSpeedScale(1)),
      );
    });

    test('later waves charge faster and aim tighter', () {
      expect(
        CombatRules.enemyChargeSeconds(4),
        lessThan(CombatRules.enemyChargeSeconds(1)),
      );
      expect(
        CombatRules.enemyAimJitterRadians(4),
        lessThan(CombatRules.enemyAimJitterRadians(1)),
      );
      expect(CombatRules.enemyAimJitterRadians(20), 0.08);
      expect(CombatRules.enemyChargeSeconds(20), 0.55);
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
      expect(
        ThrowPhysics.circleHitsRect(Vector2(140, 40), 10, rect),
        isFalse,
      );
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
