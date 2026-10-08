/// Branches of the between-wave skill tree. Each branch is a short chain:
/// a node can be bought only after its parent.
enum SkillBranch {
  team('Team'),
  recovery('Recovery'),
  fort('Fort'),
  throwSpeed('Throw'),
  poise('Poise'),
  pressure('Pressure'),
  aim('Aim'),
  reaction('Reaction'),
  charge('Charge'),
  shield('Shield'),
  lanes('Lanes'),
  blast('Blast'),
  damage('Damage');

  const SkillBranch(this.label);

  final String label;
}

/// Shop tabs. Each group holds a few branches; the shop shows one chain.
enum SkillGroup {
  crew('Crew'),
  fight('Fight'),
  defense('Defense');

  const SkillGroup(this.label);

  final String label;

  List<SkillBranch> get branches => switch (this) {
    SkillGroup.crew => const [
      SkillBranch.team,
      SkillBranch.recovery,
      SkillBranch.aim,
      SkillBranch.reaction,
      SkillBranch.charge,
    ],
    SkillGroup.fight => const [
      SkillBranch.throwSpeed,
      SkillBranch.poise,
      SkillBranch.pressure,
      SkillBranch.blast,
      SkillBranch.damage,
    ],
    SkillGroup.defense => const [
      SkillBranch.fort,
      SkillBranch.shield,
      SkillBranch.lanes,
    ],
  };

  static SkillGroup of(SkillBranch branch) {
    for (final group in SkillGroup.values) {
      if (group.branches.contains(branch)) return group;
    }
    throw StateError('No skill group for ${branch.name}');
  }
}

/// Why a node cannot be bought yet. Coins are separate: an open node can
/// still be too expensive.
enum SkillLock { open, parent, teammate, easyHeals }

/// One purchase. Each rank in a chain costs 2.5× the one before, rounded
/// to the nearest 5 ([SkillTree.rankCost]), so the top rank is a real
/// saving goal. Balance lives next to each node.
class SkillNode {
  const SkillNode({
    required this.id,
    required this.branch,
    required this.title,
    required this.detail,
    required this.cost,
    this.parentId,
  });

  final String id;
  final SkillBranch branch;
  final String title;
  final String detail;
  final int cost;
  final String? parentId;

  /// True when the rank only helps teammates. Buying it needs a second kid.
  /// This is not a [parentId]: an older save can own the node without `team-2`.
  bool get needsTeammate => switch (branch) {
    SkillBranch.aim || SkillBranch.reaction || SkillBranch.charge => true,
    SkillBranch.recovery => id == 'revive-1',
    SkillBranch.damage => id == 'damage-3' || id == 'damage-4',
    SkillBranch.team ||
    SkillBranch.fort ||
    SkillBranch.throwSpeed ||
    SkillBranch.poise ||
    SkillBranch.pressure ||
    SkillBranch.shield ||
    SkillBranch.lanes ||
    SkillBranch.blast => false,
  };
}

/// Catalog. A full clear of every chain is a few long runs of saving,
/// because a defeat refunds nothing that was already spent.
class SkillTree {
  const SkillTree._();

  static const parentLockReason = 'Unlock the node above first.';

  static const teammateLockReason = 'Buy a second kid first.';
  static const easyHealsReason = 'Easy already heals everyone between waves.';

  /// Price of the [rank]th node (1-based) in a chain that starts at [base]:
  /// ×2.5 per rank, rounded to the nearest 5.
  static int rankCost(int base, int rank) {
    if (rank <= 1) return base;
    var price = base.toDouble();
    for (var i = 1; i < rank; i++) {
      price *= 2.5;
    }
    return ((price / 5) + 0.5).floor() * 5;
  }

  static const List<SkillNode> nodes = [
    SkillNode(
      id: 'team-2',
      branch: SkillBranch.team,
      title: 'Second kid',
      detail: 'A teammate joins the crew next wave.',
      cost: 20,
    ),
    SkillNode(
      id: 'team-3',
      branch: SkillBranch.team,
      title: 'Third kid',
      detail: 'The crew is full. Three kids on your side.',
      cost: 50,
      parentId: 'team-2',
    ),
    // Recovery: both modes carry health between waves on Normal and Hard
    // (see CrewCarry). These soften that.
    SkillNode(
      id: 'mend-1',
      branch: SkillBranch.recovery,
      title: 'Patch up',
      detail: 'Every standing kid regains 1 HP between waves.',
      cost: 20,
    ),
    SkillNode(
      id: 'mend-2',
      branch: SkillBranch.recovery,
      title: 'Patch up II',
      detail: 'Every standing kid regains 2 HP between waves.',
      cost: 50,
      parentId: 'mend-1',
    ),
    SkillNode(
      id: 'revive-1',
      branch: SkillBranch.recovery,
      title: 'Second wind',
      detail: 'One knocked-out teammate rejoins each wave at 1 HP.',
      cost: 125,
      parentId: 'mend-2',
    ),
    SkillNode(
      id: 'fort-2',
      branch: SkillBranch.fort,
      title: 'Bigger fort',
      detail: 'Stage 2. More HP, still refills each wave.',
      cost: 15,
    ),
    SkillNode(
      id: 'fort-3',
      branch: SkillBranch.fort,
      title: 'Biggest fort',
      detail: 'Stage 3. The tallest wall you can build.',
      cost: 40,
      parentId: 'fort-2',
    ),
    SkillNode(
      id: 'fort-hp-1',
      branch: SkillBranch.fort,
      title: 'Packed snow',
      detail: '+4 fort HP on top of the stage.',
      cost: 95,
      parentId: 'fort-3',
    ),
    SkillNode(
      id: 'fort-hp-2',
      branch: SkillBranch.fort,
      title: 'Ice blocks',
      detail: '+4 more fort HP.',
      cost: 235,
      parentId: 'fort-hp-1',
    ),
    SkillNode(
      id: 'throw-1',
      branch: SkillBranch.throwSpeed,
      title: 'Quicker throw',
      detail: 'Rank 1. A shorter charge and a harder lob.',
      cost: 10,
    ),
    SkillNode(
      id: 'throw-2',
      branch: SkillBranch.throwSpeed,
      title: 'Quicker throw II',
      detail: 'Rank 2.',
      cost: 25,
      parentId: 'throw-1',
    ),
    SkillNode(
      id: 'throw-3',
      branch: SkillBranch.throwSpeed,
      title: 'Quicker throw III',
      detail: 'Rank 3.',
      cost: 65,
      parentId: 'throw-2',
    ),
    SkillNode(
      id: 'throw-4',
      branch: SkillBranch.throwSpeed,
      title: 'Quicker throw IV',
      detail: 'Rank 4.',
      cost: 155,
      parentId: 'throw-3',
    ),
    SkillNode(
      id: 'throw-5',
      branch: SkillBranch.throwSpeed,
      title: 'Quicker throw V',
      detail: 'Rank 5. The fastest charge.',
      cost: 390,
      parentId: 'throw-4',
    ),
    SkillNode(
      id: 'poise-1',
      branch: SkillBranch.poise,
      title: 'Shake it off',
      detail: 'Your stun is 82% of the base lock.',
      cost: 12,
    ),
    SkillNode(
      id: 'poise-2',
      branch: SkillBranch.poise,
      title: 'Shake it off II',
      detail: 'Your stun is 66% of the base lock.',
      cost: 30,
      parentId: 'poise-1',
    ),
    SkillNode(
      id: 'poise-3',
      branch: SkillBranch.poise,
      title: 'Shake it off III',
      detail: 'Your stun is 52% of the base lock.',
      cost: 75,
      parentId: 'poise-2',
    ),
    SkillNode(
      id: 'poise-4',
      branch: SkillBranch.poise,
      title: 'Shake it off IV',
      detail: 'Your stun is 40% of the base lock.',
      cost: 190,
      parentId: 'poise-3',
    ),
    SkillNode(
      id: 'pressure-1',
      branch: SkillBranch.pressure,
      title: 'Heavy hit',
      detail: 'Enemy stun is 1.25× the base lock.',
      cost: 12,
    ),
    SkillNode(
      id: 'pressure-2',
      branch: SkillBranch.pressure,
      title: 'Heavy hit II',
      detail: 'Enemy stun is 1.55×.',
      cost: 30,
      parentId: 'pressure-1',
    ),
    SkillNode(
      id: 'pressure-3',
      branch: SkillBranch.pressure,
      title: 'Heavy hit III',
      detail: 'Enemy stun is 1.9×.',
      cost: 75,
      parentId: 'pressure-2',
    ),
    SkillNode(
      id: 'pressure-4',
      branch: SkillBranch.pressure,
      title: 'Heavy hit IV',
      detail: 'Enemy stun is 2.3×.',
      cost: 190,
      parentId: 'pressure-3',
    ),
    SkillNode(
      id: 'aim-1',
      branch: SkillBranch.aim,
      title: 'Sharper aim',
      detail: 'Teammate bots scatter 72% as much.',
      cost: 12,
    ),
    SkillNode(
      id: 'aim-2',
      branch: SkillBranch.aim,
      title: 'Sharper aim II',
      detail: 'Teammate scatter is 48%.',
      cost: 30,
      parentId: 'aim-1',
    ),
    SkillNode(
      id: 'aim-3',
      branch: SkillBranch.aim,
      title: 'Sharper aim III',
      detail: 'Teammate scatter is 28%.',
      cost: 75,
      parentId: 'aim-2',
    ),
    SkillNode(
      id: 'react-1',
      branch: SkillBranch.reaction,
      title: 'Quicker pals',
      detail: 'Teammate bots wait 84% as long between throws.',
      cost: 12,
    ),
    SkillNode(
      id: 'react-2',
      branch: SkillBranch.reaction,
      title: 'Quicker pals II',
      detail: 'Teammate wait is 68%.',
      cost: 30,
      parentId: 'react-1',
    ),
    SkillNode(
      id: 'react-3',
      branch: SkillBranch.reaction,
      title: 'Quicker pals III',
      detail: 'Teammate wait is 52%.',
      cost: 75,
      parentId: 'react-2',
    ),
    SkillNode(
      id: 'charge-1',
      branch: SkillBranch.charge,
      title: 'Faster pals',
      detail: 'Teammate charge is 86% of the Easy windup.',
      cost: 12,
    ),
    SkillNode(
      id: 'charge-2',
      branch: SkillBranch.charge,
      title: 'Faster pals II',
      detail: 'Teammate charge is 72% of the Easy windup.',
      cost: 30,
      parentId: 'charge-1',
    ),
    SkillNode(
      id: 'charge-3',
      branch: SkillBranch.charge,
      title: 'Faster pals III',
      detail: 'Teammate charge is 58% of the Easy windup.',
      cost: 75,
      parentId: 'charge-2',
    ),
    SkillNode(
      id: 'shield-1',
      branch: SkillBranch.shield,
      title: 'Shield',
      detail: 'Each of your kids blocks 1 hit a wave. No stun, no damage.',
      cost: 20,
    ),
    SkillNode(
      id: 'shield-2',
      branch: SkillBranch.shield,
      title: 'Shield II',
      detail: 'Blocks 2 hits a wave.',
      cost: 50,
      parentId: 'shield-1',
    ),
    SkillNode(
      id: 'shield-3',
      branch: SkillBranch.shield,
      title: 'Shield III',
      detail: 'Blocks 3 hits a wave.',
      cost: 125,
      parentId: 'shield-2',
    ),
    SkillNode(
      id: 'lanes',
      branch: SkillBranch.lanes,
      title: 'Open fort',
      detail:
          'Your snowballs pass through your own fort. The base rule stays until you buy this.',
      cost: 40,
    ),
    SkillNode(
      id: 'blast-1',
      branch: SkillBranch.blast,
      title: 'Wider splat',
      detail: 'Snowball hit radius is 1.2×.',
      cost: 12,
    ),
    SkillNode(
      id: 'blast-2',
      branch: SkillBranch.blast,
      title: 'Wider splat II',
      detail: 'Hit radius is 1.45×.',
      cost: 30,
      parentId: 'blast-1',
    ),
    SkillNode(
      id: 'blast-3',
      branch: SkillBranch.blast,
      title: 'Wider splat III',
      detail: 'Hit radius is 1.75×.',
      cost: 75,
      parentId: 'blast-2',
    ),
    SkillNode(
      id: 'blast-4',
      branch: SkillBranch.blast,
      title: 'Wider splat IV',
      detail: 'Hit radius is 2.05×.',
      cost: 190,
      parentId: 'blast-3',
    ),
    SkillNode(
      id: 'damage-1',
      branch: SkillBranch.damage,
      title: 'Harder hit',
      detail: 'Your snowballs count as 2 hits.',
      cost: 25,
    ),
    SkillNode(
      id: 'damage-2',
      branch: SkillBranch.damage,
      title: 'Harder hit II',
      detail: 'Your snowballs count as 3 hits.',
      cost: 65,
      parentId: 'damage-1',
    ),
    SkillNode(
      id: 'damage-3',
      branch: SkillBranch.damage,
      title: 'Harder hit III',
      detail: 'Teammate bots also hit for 2.',
      cost: 155,
      parentId: 'damage-2',
    ),
    SkillNode(
      id: 'damage-4',
      branch: SkillBranch.damage,
      title: 'Harder hit IV',
      detail: 'Teammate bots also hit for 3.',
      cost: 390,
      parentId: 'damage-3',
    ),
  ];

  static final Map<String, SkillNode> byId = {
    for (final node in nodes) node.id: node,
  };

  static List<SkillNode> chain(SkillBranch branch) {
    return [
      for (final node in nodes)
        if (node.branch == branch) node,
    ];
  }

  static SkillNode? node(String id) => byId[id];

  /// Nodes implied by an older save that stored crew, fort, and throw only.
  static Set<String> legacyNodes({
    required int crewSize,
    required int fortStage,
    required int throwRank,
  }) {
    final owned = <String>{};
    if (crewSize >= 2) owned.add('team-2');
    if (crewSize >= 3) owned.add('team-3');
    if (fortStage >= 2) owned.add('fort-2');
    if (fortStage >= 3) owned.add('fort-3');
    for (var rank = 1; rank <= throwRank; rank++) {
      owned.add('throw-$rank');
    }
    return owned;
  }
}
