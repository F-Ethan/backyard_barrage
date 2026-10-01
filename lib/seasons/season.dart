/// Winter snowballs or summer water balloons. Same rules, different art.
enum Season {
  winter,
  summer;

  String get label => switch (this) {
        Season.winter => 'Winter',
        Season.summer => 'Summer',
      };

  static Season? tryParse(String? name) {
    for (final season in Season.values) {
      if (season.name == name) return season;
    }
    return null;
  }
}

/// Asset paths relative to `assets/images/`.
class SeasonAssets {
  const SeasonAssets._();

  static const poseNames = ['idle', 'walk', 'charge', 'throw', 'hit', 'ko'];

  static String background(Season season) => switch (season) {
        Season.winter => 'world/backyard_bg_winter_draft.png',
        Season.summer => 'world/backyard_bg_summer_draft.png',
      };

  static String projectile(Season season) => switch (season) {
        Season.winter => 'projectiles/snowball_draft.png',
        Season.summer => 'projectiles/water_balloon_draft.png',
      };

  static String impact(Season season) => switch (season) {
        Season.winter => 'vfx/impact_snow_draft.png',
        Season.summer => 'vfx/impact_splash_draft.png',
      };

  static String pose({
    required bool player,
    required Season season,
    required String pose,
  }) {
    final who = player ? 'player' : 'enemy';
    return 'characters/$who/${who}_${pose}_${season.name}_draft.png';
  }

  /// Flutter [Image.asset] path for a season chip.
  static String chipAsset(Season season, {required bool selected}) {
    final suffix = selected ? '' : '_off';
    return 'assets/images/ui/chip_season_${season.name}${suffix}_draft.png';
  }
}
