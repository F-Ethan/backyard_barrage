/// How a loss treats the skill tree. Coins never move between modes.
enum PlayMode {
  arcade,
  campaign;

  String get label => switch (this) {
    PlayMode.arcade => 'Arcade',
    PlayMode.campaign => 'Campaign',
  };

  /// One line on the home card. Matches the defeat rules.
  String get blurb => switch (this) {
    PlayMode.arcade => 'Skills wipe on defeat. Coins stay.',
    PlayMode.campaign => 'Skills stay. Restart at wave 1.',
  };

  static PlayMode? tryParse(String? name) {
    for (final mode in PlayMode.values) {
      if (mode.name == name) return mode;
    }
    return null;
  }
}
