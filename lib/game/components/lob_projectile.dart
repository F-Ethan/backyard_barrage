import 'dart:ui';

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
    this.passOwnFort = false,
    this.manualThrow = false,
    this.scripted = false,
    this.groundTrack = false,
    this.travelSpeed = 0,
    this.flightRange = 0,
    this.apexFraction = 0.22,
    this.settleFraction = 0.42,
    this.landingY = 0,
    this.apexY = 0,
    double? trackY,
    double? launchVy,
  }) : launchVy = launchVy ?? velocity.y,
       originX = position.x,
       originY = trackY ?? position.y,
       handLift = (trackY ?? position.y) - position.y,
       facing = velocity.x < 0 ? -1.0 : 1.0,
       _hit = Vector2(position.x, trackY ?? position.y),
       _scriptRow = landingRow,
       super(
         sprite: sprite,
         position: position,
         size: Vector2.all(radius * 2.2),
         anchor: Anchor.center,
         priority: ArenaGrid.depthOrder(position.y),
       ) {
    _applyDepth();
  }

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

  /// Start of the hit path (the thrower's body height on a ground track).
  final double originY;

  /// How far the hand sits above [originY]. The drawn ball leaves the hand
  /// and eases onto the track by the landing.
  final double handLift;

  /// +1 toward the enemy half, -1 toward the player half.
  final double facing;
  final bool friendlyFortDamage;

  /// Bought lane node. Your own shots pass your fort. The base rule stays
  /// when this is false.
  final bool passOwnFort;

  /// The kid the player was controlling when this shot left their hand.
  final bool manualThrow;

  /// Fort cracker: knocks down any rival fort this shot strikes.
  bool cracker = false;
  final bool scripted;

  /// Straight depth line for hits. The sprite climbs and drops above it.
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
  final Vector2 _prevHit = Vector2.zero();
  int _scriptRow;
  double _traveled = 0;
  double _age = 0;
  bool _rangeDone = false;
  bool _falling = false;

  /// Set when this shot strikes a fort, before [onFortHit].
  FortComponent? struckFort;

  /// Set when this shot strikes a kid, before [onHit].
  KidComponent? struckKid;

  /// True when the strike should chip the fort. Blocks without damage leave
  /// this false (a player lob into their own fort on Normal / Easy).
  bool fortDamage = false;

  bool _spent = false;

  /// True once this shot has hit, been blocked, or landed.
  bool get spent => _spent;
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
      _applyDepth();
      if (_hit.y >= _groundY) _land();
      return;
    }

    _prevHit.setFrom(_hit);
    if (groundTrack) {
      _stepGround(dt);
    } else if (scripted) {
      _stepScript(dt);
    } else {
      velocity.y += ThrowPhysics.gravity * dt;
      _hit.x += velocity.x * dt;
      _hit.y += velocity.y * dt;
    }
    _trail.add(position.clone());
    if (_trail.length > _trailLength) _trail.removeAt(0);
    _syncVisual();
    // Ground-track height, not the lofted picture. Over the hit box paints
    // behind the kid. Under it stays in front. Scale uses that same height.
    _applyDepth();
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
        if (!ThrowPhysics.snowballSweepContacts(
          from: _prevHit,
          to: _hit,
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
        // Splash on the wall the kid is hiding behind, not on the kid.
        final wall = shelter.hitRect;
        _stopOnFort(
          shelter,
          damage: owner?.side != shelter.side,
          at: Vector2(position.x.clamp(wall.left, wall.right), wall.center.dy),
        );
        return;
      }
      _spent = true;
      // The splash goes where the ball is drawn. The hit path sits below it.
      struckKid = target;
      onHit(this, target);
      removeFromParent();
      return;
    }

    // A ground track runs at body height and lands only after its range
    // (via the fall). Its start can sit below the landing row's floor on an
    // up-screen throw, so the floor check would end it in the hand.
    if (!groundTrack && _hit.y >= _groundY) {
      _land();
      return;
    }
    if (_shouldStartFall()) _beginFall();
  }

  void _applyDepth() {
    priority = ArenaGrid.depthOrder(_hit.y);
    final factor = ArenaGrid.depthScale(_hit.y, groundTrack: true);
    scale.setValues(factor, factor);
  }

  void _syncVisual() {
    if (groundTrack && !_falling) {
      final u = flightRange <= 1 ? 1.0 : (_traveled / flightRange);
      final uu = u.clamp(0.0, 1.0);
      position.setValues(
        _hit.x,
        ThrowPhysics.drawnLobY(
              originY: originY,
              landingY: landingY,
              u: u,
              range: flightRange,
            ) -
            handLift * (1 - uu),
      );
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

  /// Where the ball's shadow sits on the yard floor: under the hit path,
  /// at foot level. This is the honest depth of the shot.
  Vector2 get shadowPosition => Vector2(_hit.x, _hit.y + ArenaGrid.bodyLift);

  static final Paint _shadowPaint = Paint()..color = const Color(0x3D1A2332);

  /// Recent drawn positions, newest last, for a soft motion trail.
  final List<Vector2> _trail = [];
  static const int _trailLength = 5;

  static final Paint _trailPaint = Paint();

  @override
  void render(Canvas canvas) {
    if (groundTrack && !_spent) {
      final sx0 = scale.x == 0 ? 1.0 : scale.x;
      final sy0 = scale.y == 0 ? 1.0 : scale.y;
      for (var i = 0; i < _trail.length; i++) {
        final ghost = _trail[i];
        final t = (i + 1) / (_trail.length + 1);
        _trailPaint.color = const Color(0xFFFFFFFF).withValues(alpha: 0.28 * t);
        canvas.drawCircle(
          Offset(
            (ghost.x - position.x) / sx0 + size.x / 2,
            (ghost.y - position.y) / sy0 + size.y / 2,
          ),
          size.x * 0.32 * (0.5 + 0.5 * t),
          _trailPaint,
        );
      }
      // Local space: anchor is the center, and the component is scaled.
      final sx = scale.x == 0 ? 1.0 : scale.x;
      final sy = scale.y == 0 ? 1.0 : scale.y;
      final floor = shadowPosition;
      final local = Offset(
        (floor.x - position.x) / sx + size.x / 2,
        (floor.y - position.y) / sy + size.y / 2,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: local,
          width: size.x * 0.8,
          height: size.x * 0.3,
        ),
        _shadowPaint,
      );
    }
    super.render(canvas);
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
    if (passOwnFort &&
        cover.side == KidSide.player &&
        owner?.side == KidSide.player) {
      return false;
    }
    if (_clearedForts.contains(cover)) return false;
    if (!_centerInFootprint(cover)) return false;

    final ownerSide = owner?.side;
    final sameSide = ownerSide != null && ownerSide == cover.side;
    final behind =
        sameSide && ArenaGrid.columnIsBehindFort(ownerSide, throwerColumn);
    if (sameSide && !behind) return false;

    // Easy and Normal: a shot that peaks past your own fort has already
    // lofted over it. Hard skips this so a full lob from behind can still
    // chip that fort. The other side's fort still stops a ball that flies
    // through it.
    if (groundTrack && sameSide && flightRange > 1 && !friendlyFortDamage) {
      final apexX = originX + facing * flightRange * apexFraction;
      if (ThrowPhysics.peaksPastFort(
        apexX: apexX,
        footprint: cover.footprint,
        facingRight: facing > 0,
      )) {
        return false;
      }
    }

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

  void _stopOnFort(FortComponent cover, {required bool damage, Vector2? at}) {
    _spent = true;
    struckFort = cover;
    fortDamage = damage;
    position.setFrom(at ?? _hit);
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
