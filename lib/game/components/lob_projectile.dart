import 'package:flame/components.dart';

import '../arena_grid.dart';
import '../throw_physics.dart';
import 'fort_component.dart';
import 'kid_component.dart';

typedef ProjectileHit = void Function(LobProjectile shot, KidComponent target);
typedef FortBlocked = void Function(LobProjectile shot);
typedef ProjectileGround = void Function(LobProjectile shot);

/// Snowball or water balloon.
///
/// Hit checks follow the existing lane path ([hitPosition]). The sprite
/// draws a lob that joins that path at a fort and again before the target
/// half. A miss keeps going until it meets the landing row's ground.
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
    this.onGround,
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
    this.groundTrack = false,
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
       facing = velocity.x < 0 ? -1.0 : 1.0,
       _hit = position.clone(),
       _scriptRow = landingRow,
       super(
         sprite: sprite,
         position: position,
         size: Vector2.all(radius * 2.2),
         anchor: Anchor.center,
         priority: ArenaGrid.depthOrder(position.y),
       );

  Vector2 velocity;
  final List<KidComponent> targets;
  final ProjectileHit onHit;
  final FortComponent? fort;
  final List<FortComponent> forts;
  final FortBlocked? onFortHit;

  /// Missed every kid and fort. The ball has reached the ground.
  final ProjectileGround? onGround;
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

  /// +1 toward the enemy half, -1 toward the player half.
  final double facing;
  final bool friendlyFortDamage;
  final bool scripted;

  /// Straight depth line for hits. The sprite lofts above [hitPosition].
  final bool groundTrack;
  final double travelSpeed;
  final double flightRange;
  final double apexFraction;
  final double settleFraction;
  final double landingY;
  final double apexY;

  /// World point used for kids, forts, and the row lock.
  Vector2 get hitPosition => _hit;

  final Vector2 _hit;
  int _scriptRow;
  double _traveled = 0;
  double _age = 0;
  bool _rangeDone = false;
  bool _falling = false;

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
      y: _hit.y,
      vy: velocity.y,
    );
  }

  bool get atArcPeak {
    if (groundTrack) {
      if (flightRange <= 1) return false;
      return (_traveled / flightRange - apexFraction).abs() <= 0.06;
    }
    if (scripted) {
      if (flightRange <= 1) return false;
      final u = _traveled / flightRange;
      return (u - apexFraction).abs() <= 0.045;
    }
    return ThrowPhysics.nearArcPeak(velocityY: velocity.y, launchVy: launchVy);
  }

  bool get _behindFort {
    final side = owner?.side;
    if (side == null) return false;
    return ArenaGrid.columnIsBehindFort(side, throwerColumn);
  }

  double get _groundY => ThrowPhysics.impactGroundY(landingRow);

  @override
  void update(double dt) {
    super.update(dt);
    if (_spent) return;
    _age += dt;
    if (_age > 6) {
      _land();
      return;
    }

    if (_falling) {
      _stepFall(dt);
      position.setFrom(_hit);
      priority = ArenaGrid.depthOrder(_hit.y);
      if (_hit.y >= _groundY) _land();
      return;
    }

    if (groundTrack) {
      _stepGround(dt);
    } else if (scripted) {
      _stepScript(dt);
    } else {
      velocity.y += ThrowPhysics.gravity * dt;
      _hit.x += velocity.x * dt;
      _hit.y += velocity.y * dt;
    }
    _syncVisual();
    // Ground-track height, not the lofted picture. Over the hit box paints
    // behind the kid. Under it stays in front.
    priority = ArenaGrid.depthOrder(_hit.y);
    if (_spent) return;
    if (groundTrack && _rangeDone) {
      _beginFall();
    }

    if (blockedByFort) {
      for (final cover in _fortList) {
        if (_meetFort(cover)) return;
      }
    }

    for (final target in List<KidComponent>.of(targets)) {
      if (identical(target, owner) || target.isKo) continue;
      if (groundTrack) {
        if (!ThrowPhysics.snowballContacts(
          ground: _hit,
          shotRadius: radius,
          kidCenter: target.hitCenter,
          kidRadius: target.hitRadius,
        )) {
          continue;
        }
      } else {
        final targetRow = ArenaGrid.nearestCell(
          target.side,
          target.position,
        ).row;
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
          _hit,
          radius,
          target.hitCenter,
          target.hitRadius,
        )) {
          continue;
        }
      }
      final shelter = _shelterFor(target);
      if (shelter != null && !_clearedForts.contains(shelter) && !atArcPeak) {
        _stopOnFort(shelter, damage: owner?.side != shelter.side);
        return;
      }
      _spent = true;
      position.setFrom(_hit);
      onHit(this, target);
      removeFromParent();
      return;
    }

    if (_hit.y >= _groundY) {
      _land();
      return;
    }
    if (_shouldStartFall()) _beginFall();
  }

  void _syncVisual() {
    if (groundTrack && !_falling) {
      final u = flightRange <= 1 ? 1.0 : (_traveled / flightRange);
      position.setValues(_hit.x, _hit.y - ThrowPhysics.loftAt(u, flightRange));
      return;
    }
    position.setValues(
      _hit.x,
      ThrowPhysics.flightVisualY(
        collisionY: _hit.y,
        worldX: _hit.x,
        originX: originX,
        originY: originY,
        range: flightRange,
        facingRight: facing > 0,
        behindFort: _behindFort,
        scripted: scripted,
        apexY: apexY,
        landingY: landingY,
        apexFraction: apexFraction,
        settleFraction: settleFraction,
      ),
    );
  }

  bool _shouldStartFall() {
    if (_rangeDone) return true;
    // Past the last place a kid can stand. Drop on-screen instead of
    // flying out of the yard at body height.
    if (facing > 0 && _hit.x > ThrowPhysics.yardFarEdge - 16) return true;
    if (facing < 0 && _hit.x < 16) return true;
    return false;
  }

  void _beginFall() {
    _falling = true;
    final drop = velocity.y > 40 ? velocity.y : 40.0;
    velocity.setValues(facing * 80, drop);
  }

  void _stepFall(double dt) {
    velocity.y += ThrowPhysics.gravity * dt;
    _hit.x += velocity.x * dt;
    _hit.y += velocity.y * dt;
  }

  void _land() {
    if (_spent) return;
    _spent = true;
    _hit.y = _groundY;
    position.setFrom(_hit);
    onGround?.call(this);
    removeFromParent();
  }

  void _stepGround(double dt) {
    final pace = travelSpeed > 0 ? travelSpeed.abs() : velocity.x.abs();
    if (flightRange <= 1 || pace <= 0) {
      _rangeDone = true;
      return;
    }
    final step = pace * dt;
    if (_traveled + step >= flightRange) {
      _traveled = flightRange;
      _hit.x = originX + facing * flightRange;
      _hit.y = landingY;
      velocity.setValues(facing * pace, 0);
      _rangeDone = true;
      return;
    }
    _traveled += step;
    final u = _traveled / flightRange;
    _hit.x = originX + facing * _traveled;
    _hit.y = originY + (landingY - originY) * u;
    velocity.setValues(facing * pace, 0);
  }

  void _stepScript(double dt) {
    final speed = travelSpeed > 0 ? travelSpeed : facing * velocity.x;
    final pace = speed.abs();
    if (flightRange <= 1) {
      _rangeDone = true;
      return;
    }
    final step = pace * dt;
    if (_traveled + step >= flightRange) {
      _placeScript(flightRange);
      _rangeDone = true;
      return;
    }
    _traveled += step;
    _placeScript(_traveled);
  }

  void _placeScript(double traveled) {
    _traveled = traveled;
    final u = flightRange <= 1 ? 1.0 : traveled / flightRange;
    _hit.x = originX + facing * traveled;
    _hit.y = ThrowPhysics.playerArcY(
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
    final pace = travelSpeed > 0 ? travelSpeed : 0.0;
    velocity = ThrowPhysics.playerArcVelocity(
      facing: facing,
      speed: pace > 0 ? pace : velocity.x.abs(),
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
    if (cover.isCollapsed) return false;
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
      collapsed: cover.isCollapsed,
    );
    if (result == FortShotResult.none) return false;
    _stopOnFort(cover, damage: result == FortShotResult.damaged);
    return true;
  }

  void _stopOnFort(FortComponent cover, {required bool damage}) {
    _spent = true;
    struckFort = cover;
    fortDamage = damage;
    position.setFrom(_hit);
    onFortHit?.call(this);
    removeFromParent();
  }

  bool _centerInFootprint(FortComponent cover) {
    final box = cover.footprint;
    return _hit.x >= box.left &&
        _hit.x <= box.right &&
        _hit.y >= box.top &&
        _hit.y <= box.bottom;
  }

  bool _apexWillClear(FortComponent cover) {
    final double apexX;
    if (scripted || groundTrack) {
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
