/// One-use items bought in the shop and fired from a HUD button mid-fight.
/// A button only shows while the player owns at least one.
enum PowerUp {
  frostArmor('Frost armor', 'Your crew takes no damage for 3 seconds.', 25),
  fortCracker(
    'Fort cracker',
    'Your next throw knocks down any rival fort it hits.',
    30,
  ),
  freezeAll('Freeze all', 'Every rival freezes for 2.5 seconds.', 35),
  powerThrow('Power throw', 'Your next charge starts at full power.', 15),
  bigSplat('Big splat', 'Your next throw splats three times as wide.', 20),
  hotCocoa('Hot cocoa', 'Every standing kid regains 1 HP.', 30);

  const PowerUp(this.label, this.detail, this.cost);

  final String label;
  final String detail;
  final int cost;

  /// Most of one item a wallet can hold.
  static const int maxStack = 3;

  /// Seconds Frost armor lasts.
  static const double armorSeconds = 3;

  /// Seconds Freeze all holds the rivals.
  static const double freezeSeconds = 2.5;

  /// Blast radius multiplier for Big splat.
  static const double splatScale = 3;

  static PowerUp? tryParse(String? name) {
    for (final p in PowerUp.values) {
      if (p.name == name) return p;
    }
    return null;
  }
}
