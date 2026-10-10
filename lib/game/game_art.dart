import '../meta/power_up.dart';

/// Image paths (under `assets/images/`) for the yard art that is not tied to
/// a season: forts, effects, props, and power-up icons.
abstract final class GameArt {
  /// The player's fort ([rival] false, blue flag) or the rival fort (violet
  /// flag) at [stage], intact or [damaged].
  static String fort(int stage, {bool damaged = false, bool rival = false}) {
    final name = 'fort_stage_$stage${damaged ? '_damaged' : ''}.png';
    return rival ? 'forts/rival/rival_$name' : 'forts/$name';
  }

  static String fortCollapsed({bool rival = false}) => rival
      ? 'forts/rival/rival_fort_collapsed.png'
      : 'forts/fort_collapsed.png';

  /// Frost armor: a faceted ice bubble drawn around each kid.
  static const iceBubble = 'vfx/ice_bubble.png';

  /// The iron shield a kid holds while their Shield skill (or a rival's
  /// Shield perk) still has hits to block.
  static const ironShield = 'props/shield/iron_shield.png';

  /// The shield after it has blocked a hit, and broken on the ground
  /// after its last.
  static const ironShieldCracked = 'props/shield/iron_shield_cracked.png';
  static const ironShieldDestroyed = 'props/shield/iron_shield_destroyed.png';

  /// The spiked ball a throw flies as while Fort cracker is armed.
  static const bunkerBuster = 'projectiles/bunker_buster.png';

  /// Freeze all: frost that creeps in from the screen edges (1280x720).
  static const frostCrust = 'vfx/frost_crust_overlay.png';

  /// Winter yard props, 512² and standing on y=496.
  static const props = [
    'props/winter/snowman.png',
    'props/winter/sled.png',
    'props/winter/mailbox.png',
    'props/winter/fence.png',
    'props/winter/pine_shrub.png',
    'props/winter/snowball_pile.png',
    'props/winter/bucket.png',
    'props/winter/shovel_drift.png',
  ];

  /// Round icon for [item] (256², transparent corners).
  static String powerUp(PowerUp item) => 'ui/powerups/pu_${_slug(item)}.png';

  static String _slug(PowerUp item) => switch (item) {
    PowerUp.frostArmor => 'frost_armor',
    PowerUp.fortCracker => 'fort_cracker',
    PowerUp.freezeAll => 'freeze_all',
    PowerUp.powerThrow => 'power_throw',
    PowerUp.bigSplat => 'big_splat',
    PowerUp.hotCocoa => 'hot_cocoa',
    PowerUp.revive => 'revive',
  };

  /// Every path the game loads through Flame's image cache, for
  /// preloading and tests.
  static List<String> get flameImages => [
    for (final rival in [false, true]) ...[
      for (final stage in [1, 2, 3]) ...[
        fort(stage, rival: rival),
        fort(stage, damaged: true, rival: rival),
      ],
      fortCollapsed(rival: rival),
    ],
    iceBubble,
    ironShield,
    ironShieldCracked,
    ironShieldDestroyed,
    bunkerBuster,
    ...props,
    // Also drawn as the ball on a throw that carries that power-up.
    for (final item in PowerUp.values) powerUp(item),
  ];
}
