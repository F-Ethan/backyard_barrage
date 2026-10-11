import '../meta/meta_state.dart';
import '../meta/power_up.dart';

/// One kid's state at a moment: hearts, shield, and their own upgrades.
class KidState {
  const KidState({
    this.kid = 0,
    required this.hp,
    required this.maxHp,
    required this.shield,
    required this.upgrades,
    this.inCrew = true,
  });

  /// Where [kid] stands in [meta] going into the next wave: full hearts,
  /// a full shield, and whatever they own now.
  factory KidState.fresh(MetaState meta, int kid) => KidState(
    kid: kid,
    hp: meta.kidMaxHp(kid),
    maxHp: meta.kidMaxHp(kid),
    shield: meta.kidShield(kid),
    upgrades: meta.kidUpgrades(kid),
    inCrew: meta.inCrew(kid),
  );

  /// Which crew kid (0 Mike, 1 Beth, 2 Ruben).
  final int kid;
  final int hp;
  final int maxHp;
  final int shield;
  final KidUpgrades upgrades;

  /// False when the crew no longer has this kid (a checkpoint from before
  /// they joined).
  final bool inCrew;
}

/// The wallet side of the crew at a moment: each kid, the power-ups held,
/// and the team's shared ranks. Taken just before and just after a loss,
/// so the defeat summary can show what changed.
class CrewSnapshot {
  const CrewSnapshot({
    required this.kids,
    required this.items,
    required this.teamRanks,
  });

  factory CrewSnapshot.of(MetaState meta, List<KidState> kids) => CrewSnapshot(
    kids: kids,
    items: Map.of(meta.items),
    teamRanks: meta.teamRanks,
  );

  final List<KidState> kids;
  final Map<PowerUp, int> items;
  final int teamRanks;
}
