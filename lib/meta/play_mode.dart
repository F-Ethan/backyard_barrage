/// How a loss treats the skill tree. Coins never move between modes.
///
/// The code names predate the player-facing names, and saves store them,
/// so they stay. [PlayMode.arcade] is the run that wipes skills on defeat
/// and shows as **Campaign** (its best wave is the headline). [PlayMode.campaign]
/// keeps skills and shows as **Arcade** (it shows a lifetime score).
enum PlayMode {
  arcade,
  campaign;

  String get label => switch (this) {
    PlayMode.arcade => 'Campaign',
    PlayMode.campaign => 'Arcade',
  };

  /// One line on the home card. Matches the defeat rules.
  String get blurb => switch (this) {
    PlayMode.arcade => 'Skills wipe on defeat. Coins stay.',
    PlayMode.campaign => 'Skills stay. Restart at wave 1.',
  };

  /// Campaign is ranked by highest wave. Arcade is ranked by score.
  bool get showsScore => this == PlayMode.campaign;

  static PlayMode? tryParse(String? name) {
    for (final mode in PlayMode.values) {
      if (mode.name == name) return mode;
    }
    return null;
  }
}
