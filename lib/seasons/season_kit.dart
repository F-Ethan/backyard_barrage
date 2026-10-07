import 'dart:ui';

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
        _loadPose(
          game,
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
      pickup: byName['pickup']!,
      turn30l: byName['turn_30l']!,
      turn15l: byName['turn_15l']!,
      turn15r: byName['turn_15r']!,
      turn30r: byName['turn_30r']!,
      uprightKo: SeasonAssets.uprightKo(player: player, season: season),
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

Future<Sprite> _loadPose(FlameGame game, String path) async {
  final crop = SeasonAssets.crop(path);
  final srcPosition = crop == null ? null : Vector2(crop.$1, crop.$2);
  final srcSize = crop == null ? null : Vector2.all(crop.$3);
  if (!SeasonAssets.mirror(path)) {
    return game.loadSprite(path, srcPosition: srcPosition, srcSize: srcSize);
  }
  final image = await game.images.load(path);
  return MirroredSprite(image, srcPosition: srcPosition, srcSize: srcSize);
}

/// A sprite drawn flipped left-to-right inside its own destination box.
class MirroredSprite extends Sprite {
  MirroredSprite(super.image, {super.srcPosition, super.srcSize});

  @override
  void render(
    Canvas canvas, {
    Vector2? position,
    Vector2? size,
    Anchor anchor = Anchor.topLeft,
    Paint? overridePaint,
    double? bleed,
  }) {
    final drawSize = size ?? srcSize;
    final left = (position?.x ?? 0) - anchor.x * drawSize.x;
    final centerX = left + drawSize.x / 2;
    canvas.save();
    canvas.translate(centerX, 0);
    canvas.scale(-1, 1);
    canvas.translate(-centerX, 0);
    super.render(
      canvas,
      position: position,
      size: size,
      anchor: anchor,
      overridePaint: overridePaint,
      bleed: bleed,
    );
    canvas.restore();
  }
}
