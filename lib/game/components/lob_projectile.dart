import 'package:flame/components.dart';

import '../arena_grid.dart';
import '../throw_physics.dart';
import 'fort_component.dart';
import 'kid_component.dart';

typedef ProjectileHit = void Function(LobProjectile shot, KidComponent target);
typedef FortBlocked = void Function(LobProjectile shot);

/// Snowball or water balloon.
///
/// Enemy shots integrate gravity and stay in the thrower's row lane.
/// Player shots follow a scripted lane: constant pace, aim picks the row.
class LobProjectile extends SpriteComponent {
  LobProjectile({
    required Sprite sprite,
    required Vector2 position,
    required this.velocity,
    required this.targets,
    required this.onHit,
    this.fort,
    this.forts = const [],
    this.onFortHit,
    this.blockedByFort = false,
    this.radius = 22,
    this.owner,
    this.throwerRow = 0,
    this.throwerColumn = 0,
    this.peakRow = 0,
    this.landingRow = 0,
    this.apexRise = 0,
    this.landingDrop = 0,
    this.friendlyFortDamage = false,
    this.scripted = false,
    this.travelSpeed = 0,
    this.flightRange = 0,
    this.apexFraction = 0.22,
    this.settleFraction = 0.42,
    this.landingY = 0,
    this.apexY = 0,
    double? launchVy,
  }) : launchVy = launchVy ?? velocity.y,
       originX = position.x,
       originY = position.y,
       _scriptRow = landingRow,
       super(
         sprite: sprite,
         position: position,
         size: Vector2.all(radius * 2.2),
         anchor: Anchor.center,
         priority: 20,
       );

  Vector2 velocity;
  final List<KidComponent> targets;
  final ProjectileHit onHit;
  final FortComponent? fort;
  final List<FortComponent> forts;
  final FortBlocked? onFortHit;
  final bool blockedByFort;
  final double radius;
  final KidComponent? owner;
  final int throwerRow;
  final int throwerColumn;
  final int peakRow;
  final int landingRow;
  final double apexRise;
  final double landingDrop;
  final double launchVy;
  final double originX;
  final double originY;
  final bool friendlyFortDamage;
  final bool scripted;
  final double travelSpeed;
  final double flightRange;
  final double apexFraction;
  final double settleFraction;
  final double landingY;
  final double apexY;

  int _scriptRow;
  double _traveled = 0;

  /// Set when this shot strikes a fort, before [onFortHit].
  FortComponent? struckFort;

  /// True when the strike should chip the fort. Blocks without damage leave
  /// this false (a player lob into their own fort on Normal / Easy).
  bool fortDamage = false;

  bool _spent = false;
  final Set<FortComponent> _clearedForts = {};

  List<FortComponent> get _fortList {
    if (forts.isNotEmpty) return forts;
    final single = fort;
    if (single != null) return [single];
    return const [];
  }

  int get shotRow {
    if (scripted) return _scriptRow;
    return ThrowPhysics.lobRow(
      throwerRow: throwerRow,
      peakRow: peakRow,
      landingRow: landingRow,
      originY: originY,
      apexRise: apexRise,
      landingDrop: landingDrop,
      y: position.y,
      vy: velocity.y,
    );
  }

  bool get atArcPeak {
    if (scripted) {
      if (flightRange <= 1) return false;
      final u = _traveled / flightRange;
      return (u - apexFraction).abs() <= 0.045;
    }
    return ThrowPhysics.nearArcPeak(velocityY: velocity.y, launchVy: launchVy);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_spent) return;

    if (scripted) {
      _stepScript(dt);
      if (_spent) return;
    } else {
      velocity.y += ThrowPhysics.gravity * dt;
      position += velocity * dt;
    }

    if (blockedByFort) {
      for (final cover in _fortList) {
        if (_meetFort(cover)) return;
      }
    }

    for (final target in List<KidComponent>.of(targets)) {
      if (identical(target, owner) || target.isKo) continue;
      final targetRow = ArenaGrid.nearestCell(target.side, target.position).row;
      if (scripted) {
        if (!ThrowPhysics.playerCanHit(
          landingRow: landingRow,
          shotRow: shotRow,
          targetRow: targetRow,
        )) {
          continue;
        }
      } else {
        if (!ThrowPhysics.inThrowLane(throwerRow, targetRow)) continue;
        if (shotRow != targetRow) continue;
      }
      if (!ThrowPhysics.circlesOverlap(
        position,
        radius,
        target.hitCenter,
        target.hitRadius,
      )) {
        continue;
      }
      final shelter = _shelterFor(target);
      if (shelter != null && !_clearedForts.contains(shelter) && !atArcPeak) {
        _stopOnFort(shelter, damage: owner?.side != shelter.side);
        return;
      }
      _spent = true;
      onHit(this, target);
      removeFromParent();
      return;
    }

    if (position.x < -80 ||
        position.x > 1360 ||
        position.y < -120 ||
        position.y > 820) {
      removeFromParent();
    }
  }

  void _stepScript(double dt) {
    final speed = travelSpeed > 0 ? travelSpeed : velocity.x.abs();
    final facing = velocity.x < 0 ? -1.0 : 1.0;
    _traveled += speed * dt;
    if (_traveled >= flightRange) {
      _spent = true;
      removeFromParent();
      return;
    }
    final u = flightRange <= 1 ? 1.0 : _traveled / flightRange;
    position.x = originX + facing * _traveled;
    position.y = ThrowPhysics.playerArcY(
      originY: originY,
      apexY: apexY,
      landingY: landingY,
      u: u,
      apexFraction: apexFraction,
      settleFraction: settleFraction,
    );
    _scriptRow = ThrowPhysics.playerArcRow(
      throwerRow: throwerRow,
      landingRow: landingRow,
      u: u,
      settleFraction: settleFraction,
    );
    velocity = ThrowPhysics.playerArcVelocity(
      facing: facing,
      speed: speed,
      originY: originY,
      apexY: apexY,
      landingY: landingY,
      u: u,
      apexFraction: apexFraction,
      settleFraction: settleFraction,
      range: flightRange,
    );
  }

  /// True when the shot was stopped. Peak-aligned shots are marked clear
  /// and keep flying.
  bool _meetFort(FortComponent cover) {
    if (_clearedForts.contains(cover)) return false;
    if (!_centerInFootprint(cover)) return false;

    final ownerSide = owner?.side;
    final sameSide = ownerSide != null && ownerSide == cover.side;
    final behind =
        sameSide && ArenaGrid.columnIsBehindFort(ownerSide, throwerColumn);
    if (sameSide && !behind) return false;

    if (atArcPeak) {
      _clearedForts.add(cover);
      return false;
    }
    if (velocity.y < 0 && _apexWillClear(cover)) return false;

    final friendly =
        friendlyFortDamage && sameSide && cover.side == KidSide.player;
    final result = ThrowPhysics.resolveFortShot(
      overlaps: true,
      atPeak: false,
      sameSide: sameSide,
      throwerBehind: behind,
      friendlyDamage: friendly,
    );
    if (result == FortShotResult.none) return false;
    _stopOnFort(cover, damage: result == FortShotResult.damaged);
    return true;
  }

  void _stopOnFort(FortComponent cover, {required bool damage}) {
    _spent = true;
    struckFort = cover;
    fortDamage = damage;
    onFortHit?.call(this);
    removeFromParent();
  }

  bool _centerInFootprint(FortComponent cover) {
    final box = cover.footprint;
    return position.x >= box.left &&
        position.x <= box.right &&
        position.y >= box.top &&
        position.y <= box.bottom;
  }

  bool _apexWillClear(FortComponent cover) {
    final double apexX;
    if (scripted) {
      final facing = velocity.x < 0 ? -1.0 : 1.0;
      apexX = originX + facing * flightRange * apexFraction;
    } else {
      apexX = ThrowPhysics.apexX(
        originX: originX,
        velocity: velocity,
        launchVy: launchVy,
      );
    }
    final box = cover.footprint;
    return apexX >= box.left && apexX <= box.right;
  }

  FortComponent? _shelterFor(KidComponent target) {
    for (final cover in _fortList) {
      if (cover.shelters(target)) return cover;
    }
    return null;
  }
}
