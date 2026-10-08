import 'package:backyard_barrage/game/crew_carry.dart';
import 'package:backyard_barrage/meta/difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<int> carry(
    List<int> hp,
    Difficulty d, {
    bool carries = true,
    int heal = 0,
    bool revive = false,
  }) => CrewCarry.next(
    hp: hp,
    maxHp: 3,
    difficulty: d,
    carries: carries,
    healBonus: heal,
    reviveOne: revive,
  );

  test('Arcade and Easy start every wave at full health', () {
    expect(carry([1, 0, 2], Difficulty.hard, carries: false), [3, 3, 3]);
    expect(carry([1, 0, 2], Difficulty.easy), [3, 3, 3]);
  });

  test('Normal heals the standing crew by one and leaves the KOd out', () {
    expect(carry([1, 0, 3], Difficulty.normal), [2, 0, 3]);
  });

  test('Hard carries health as it is', () {
    expect(carry([1, 0, 2], Difficulty.hard), [1, 0, 2]);
  });

  test('Patch up adds to the heal and never passes full', () {
    expect(carry([1, 2], Difficulty.hard, heal: 1), [2, 3]);
    expect(carry([1, 2], Difficulty.normal, heal: 2), [3, 3]);
  });

  test('Second wind brings back exactly one KOd kid at 1 HP', () {
    expect(carry([0, 2, 0], Difficulty.hard, revive: true), [1, 2, 0]);
    expect(carry([2, 2], Difficulty.hard, revive: true), [2, 2]);
  });
}
