import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../game/components/kid_component.dart';
import 'season.dart';

/// Sprites for one season, shared by every kid on that side.
class SeasonKit {
  SeasonKit({
    required this.season,
    required this.background,
    required this.projectile,
    required this.impact,
    required this.playerPoses,
    required this.enemyPoses,
  });

  final Season season;
  final Sprite background;
  final Sprite projectile;
  final Sprite impact;
  final KidPoseSprites playerPoses;
  final KidPoseSprites enemyPoses;
}

Future<SeasonKit> loadSeasonKit(FlameGame game, Season season) async {
  Future<KidPoseSprites> poses(bool player) async {
    final entries = await Future.wait([
      for (final pose in SeasonAssets.poseNames)
        game.loadSprite(
          SeasonAssets.pose(player: player, season: season, pose: pose),
        ),
    ]);
    final byName = {
      for (var i = 0; i < SeasonAssets.poseNames.length; i++)
        SeasonAssets.poseNames[i]: entries[i],
    };
    return KidPoseSprites(
      idle: byName['idle']!,
      walk: byName['walk']!,
      charge: byName['charge']!,
      throwPose: byName['throw']!,
      hit: byName['hit']!,
      ko: byName['ko']!,
    );
  }

  final background = game.loadSprite(SeasonAssets.background(season));
  final projectile = game.loadSprite(SeasonAssets.projectile(season));
  final impact = game.loadSprite(SeasonAssets.impact(season));
  final playerPoses = poses(true);
  final enemyPoses = poses(false);
  return SeasonKit(
    season: season,
    background: await background,
    projectile: await projectile,
    impact: await impact,
    playerPoses: await playerPoses,
    enemyPoses: await enemyPoses,
  );
}
