import 'skill_effects.dart';

/// Branches of the between-wave skill tree. Each branch is a short chain:
/// a node can be bought only after its parent.
enum SkillBranch {
  team('Team'),
  health('Health'),
  recovery('Recovery'),
  fort('Fort'),
  moreForts('More forts'),
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
      SkillBranch.health,
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
      SkillBranch.moreForts,
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
enum SkillLock { open, parent, teammate, easyHeals, recruit }

/// One purchase. Each rank in a chain costs more than the one before
/// ([SkillTree.rankCost]): ×2.5 through the hand-made ranks, then ×3 for as
/// many ranks again, then ×4, and so on. Balance lives next to each node.
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
    SkillBranch.team ||
    SkillBranch.health ||
    SkillBranch.damage ||
    SkillBranch.fort ||
    SkillBranch.moreForts ||
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

  static const parentLockReason = 'Buy the one above first.';

  static const teammateLockReason = 'Get a friend on your team first.';
  static const easyHealsReason = 'On Easy, everyone heals for free.';
  static const recruitLockReason = 'Get this kid on your team first.';

  /// Price of the [rank]th node (1-based) in a chain that starts at [base]
  /// and has [handLength] hand-made ranks, rounded to the nearest 5.
  static int rankCost(int base, int rank, {int handLength = 1 << 30}) {
    if (rank <= 1) return base;
    var price = base.toDouble();
    for (var r = 2; r <= rank; r++) {
      price *= stepFor(r, handLength);
    }
    return _round5(price);
  }

  /// Price step into [rank]: ×2.5 within the hand-made ranks, then ×3 for
  /// the next [handLength] ranks, ×4 for the next, and so on.
  static double stepFor(int rank, int handLength) {
    final tier = (rank - 1) ~/ handLength;
    return tier == 0 ? 2.5 : tier + 2.0;
  }

  /// Generated ranks stop once a price would pass this.
  static const int maxPrice = 50000000;

  static int _round5(double price) => ((price / 5) + 0.5).floor() * 5;

  /// Number of hand-made ranks in [branch], before the generated ones.
  static int handLength(SkillBranch branch) => [
    for (final node in _hand)
      if (node.branch == branch) node,
  ].length;

  /// 1-based rank of [id] within its chain, or 0 when unknown.
  static int rankOf(String id) {
    final node = byId[id];
    if (node == null) return 0;
    return chain(node.branch).indexOf(node) + 1;
  }

  static final List<SkillNode> nodes = [..._hand, ..._generated()];

  /// The hand-made ranks only, in catalog order.
  static List<SkillNode> get handNodes => _hand;

  static const List<SkillNode> _hand = [
    SkillNode(
      id: 'team-2',
      branch: SkillBranch.team,
      title: 'Second kid',
      detail: 'A friend joins your team next wave.',
      cost: 20,
    ),
    SkillNode(
      id: 'team-3',
      branch: SkillBranch.team,
      title: 'Third kid',
      detail: 'One more friend. Now there are three of you.',
      cost: 50,
      parentId: 'team-2',
    ),
    // Health (each kid): more max hearts.
    SkillNode(
      id: 'hp-1',
      branch: SkillBranch.health,
      title: 'Tough kid',
      detail: 'This kid gets 1 more heart.',
      cost: 30,
    ),
    SkillNode(
      id: 'hp-2',
      branch: SkillBranch.health,
      title: 'Tough kid II',
      detail: 'One more heart again.',
      cost: 75,
      parentId: 'hp-1',
    ),
    SkillNode(
      id: 'hp-3',
      branch: SkillBranch.health,
      title: 'Tough kid III',
      detail: 'One more heart. Six in all.',
      cost: 190,
      parentId: 'hp-2',
    ),
    // Recovery: both modes carry health between waves on Normal and Hard
    // (see CrewCarry). These soften that.
    SkillNode(
      id: 'mend-1',
      branch: SkillBranch.recovery,
      title: 'Patch up',
      detail: 'After each wave, your kids get 1 heart back.',
      cost: 20,
    ),
    SkillNode(
      id: 'mend-2',
      branch: SkillBranch.recovery,
      title: 'Patch up II',
      detail: 'After each wave, your kids get 2 hearts back.',
      cost: 50,
      parentId: 'mend-1',
    ),
    SkillNode(
      id: 'revive-1',
      branch: SkillBranch.recovery,
      title: 'Second wind',
      detail: 'A knocked-out friend comes back next wave with 1 heart.',
      cost: 125,
      parentId: 'mend-2',
    ),
    SkillNode(
      id: 'fort-2',
      branch: SkillBranch.fort,
      title: 'Bigger fort',
      detail: 'Build a bigger snow fort. It takes more hits.',
      cost: 15,
    ),
    SkillNode(
      id: 'fort-3',
      branch: SkillBranch.fort,
      title: 'Biggest fort',
      detail: 'Build the biggest snow fort.',
      cost: 40,
      parentId: 'fort-2',
    ),
    SkillNode(
      id: 'fort-hp-1',
      branch: SkillBranch.fort,
      title: 'Packed snow',
      detail: 'Pack the snow tight. Your fort takes 4 more hits.',
      cost: 95,
      parentId: 'fort-3',
    ),
    SkillNode(
      id: 'fort-hp-2',
      branch: SkillBranch.fort,
      title: 'Ice blocks',
      detail: 'Add ice blocks. Your fort takes 4 more hits.',
      cost: 235,
      parentId: 'fort-hp-1',
    ),
    // Extra forts: each stands on a random spot in your half every wave,
    // at your fort's stage.
    SkillNode(
      id: 'fort-extra-1',
      branch: SkillBranch.moreForts,
      title: 'Second fort',
      detail: 'Build another snow fort somewhere in your yard.',
      cost: 60,
    ),
    SkillNode(
      id: 'fort-extra-2',
      branch: SkillBranch.moreForts,
      title: 'Third fort',
      detail: 'One more fort. Three places to hide.',
      cost: 150,
      parentId: 'fort-extra-1',
    ),
    SkillNode(
      id: 'throw-1',
      branch: SkillBranch.throwSpeed,
      title: 'Quicker throw',
      detail: 'Gets its throw ready faster, and it flies harder.',
      cost: 10,
    ),
    SkillNode(
      id: 'throw-2',
      branch: SkillBranch.throwSpeed,
      title: 'Quicker throw II',
      detail: 'Gets its throw ready even faster.',
      cost: 25,
      parentId: 'throw-1',
    ),
    SkillNode(
      id: 'throw-3',
      branch: SkillBranch.throwSpeed,
      title: 'Quicker throw III',
      detail: 'Gets its throw ready even faster.',
      cost: 65,
      parentId: 'throw-2',
    ),
    SkillNode(
      id: 'throw-4',
      branch: SkillBranch.throwSpeed,
      title: 'Quicker throw IV',
      detail: 'Gets its throw ready even faster.',
      cost: 155,
      parentId: 'throw-3',
    ),
    SkillNode(
      id: 'throw-5',
      branch: SkillBranch.throwSpeed,
      title: 'Quicker throw V',
      detail: 'Its fastest throw yet.',
      cost: 390,
      parentId: 'throw-4',
    ),
    SkillNode(
      id: 'poise-1',
      branch: SkillBranch.poise,
      title: 'Shake it off',
      detail: 'Gets back up faster after a hit.',
      cost: 12,
    ),
    SkillNode(
      id: 'poise-2',
      branch: SkillBranch.poise,
      title: 'Shake it off II',
      detail: 'Gets back up even faster.',
      cost: 30,
      parentId: 'poise-1',
    ),
    SkillNode(
      id: 'poise-3',
      branch: SkillBranch.poise,
      title: 'Shake it off III',
      detail: 'Gets back up even faster.',
      cost: 75,
      parentId: 'poise-2',
    ),
    SkillNode(
      id: 'poise-4',
      branch: SkillBranch.poise,
      title: 'Shake it off IV',
      detail: 'Gets back up even faster.',
      cost: 190,
      parentId: 'poise-3',
    ),
    SkillNode(
      id: 'pressure-1',
      branch: SkillBranch.pressure,
      title: 'Heavy hit',
      detail: 'Kids you hit stay dizzy longer.',
      cost: 12,
    ),
    SkillNode(
      id: 'pressure-2',
      branch: SkillBranch.pressure,
      title: 'Heavy hit II',
      detail: 'Kids you hit stay dizzy even longer.',
      cost: 30,
      parentId: 'pressure-1',
    ),
    SkillNode(
      id: 'pressure-3',
      branch: SkillBranch.pressure,
      title: 'Heavy hit III',
      detail: 'Kids you hit stay dizzy even longer.',
      cost: 75,
      parentId: 'pressure-2',
    ),
    SkillNode(
      id: 'pressure-4',
      branch: SkillBranch.pressure,
      title: 'Heavy hit IV',
      detail: 'Kids you hit stay dizzy even longer.',
      cost: 190,
      parentId: 'pressure-3',
    ),
    SkillNode(
      id: 'aim-1',
      branch: SkillBranch.aim,
      title: 'Sharper aim',
      detail: 'Aims better when it throws on its own.',
      cost: 12,
    ),
    SkillNode(
      id: 'aim-2',
      branch: SkillBranch.aim,
      title: 'Sharper aim II',
      detail: 'Aims even better on its own.',
      cost: 30,
      parentId: 'aim-1',
    ),
    SkillNode(
      id: 'aim-3',
      branch: SkillBranch.aim,
      title: 'Sharper aim III',
      detail: 'Aims even better on its own.',
      cost: 75,
      parentId: 'aim-2',
    ),
    SkillNode(
      id: 'react-1',
      branch: SkillBranch.reaction,
      title: 'Quicker pals',
      detail: 'Throws more often when it plays on its own.',
      cost: 12,
    ),
    SkillNode(
      id: 'react-2',
      branch: SkillBranch.reaction,
      title: 'Quicker pals II',
      detail: 'Throws even more often on its own.',
      cost: 30,
      parentId: 'react-1',
    ),
    SkillNode(
      id: 'react-3',
      branch: SkillBranch.reaction,
      title: 'Quicker pals III',
      detail: 'Throws even more often on its own.',
      cost: 75,
      parentId: 'react-2',
    ),
    SkillNode(
      id: 'charge-1',
      branch: SkillBranch.charge,
      title: 'Faster pals',
      detail: 'Gets its throw ready faster when it plays on its own.',
      cost: 12,
    ),
    SkillNode(
      id: 'charge-2',
      branch: SkillBranch.charge,
      title: 'Faster pals II',
      detail: 'Gets ready even faster on its own.',
      cost: 30,
      parentId: 'charge-1',
    ),
    SkillNode(
      id: 'charge-3',
      branch: SkillBranch.charge,
      title: 'Faster pals III',
      detail: 'Gets ready even faster on its own.',
      cost: 75,
      parentId: 'charge-2',
    ),
    SkillNode(
      id: 'shield-1',
      branch: SkillBranch.shield,
      title: 'Shield',
      detail: 'Blocks 1 hit every wave.',
      cost: 20,
    ),
    SkillNode(
      id: 'shield-2',
      branch: SkillBranch.shield,
      title: 'Shield II',
      detail: 'Blocks 2 hits every wave.',
      cost: 50,
      parentId: 'shield-1',
    ),
    SkillNode(
      id: 'shield-3',
      branch: SkillBranch.shield,
      title: 'Shield III',
      detail: 'Blocks 3 hits every wave.',
      cost: 125,
      parentId: 'shield-2',
    ),
    SkillNode(
      id: 'lanes',
      branch: SkillBranch.lanes,
      title: 'Open fort',
      detail: 'Your snowballs fly right through your own fort.',
      cost: 40,
    ),
    SkillNode(
      id: 'blast-1',
      branch: SkillBranch.blast,
      title: 'Wider splat',
      detail: 'Your snowballs make a bigger splat, so they hit more easily.',
      cost: 12,
    ),
    SkillNode(
      id: 'blast-2',
      branch: SkillBranch.blast,
      title: 'Wider splat II',
      detail: 'An even bigger splat.',
      cost: 30,
      parentId: 'blast-1',
    ),
    SkillNode(
      id: 'blast-3',
      branch: SkillBranch.blast,
      title: 'Wider splat III',
      detail: 'An even bigger splat.',
      cost: 75,
      parentId: 'blast-2',
    ),
    SkillNode(
      id: 'blast-4',
      branch: SkillBranch.blast,
      title: 'Wider splat IV',
      detail: 'An even bigger splat.',
      cost: 190,
      parentId: 'blast-3',
    ),
    SkillNode(
      id: 'damage-1',
      branch: SkillBranch.damage,
      title: 'Harder hit',
      detail: 'Snowballs hit twice as hard.',
      cost: 25,
    ),
    SkillNode(
      id: 'damage-2',
      branch: SkillBranch.damage,
      title: 'Harder hit II',
      detail: 'Snowballs hit 3 times as hard.',
      cost: 65,
      parentId: 'damage-1',
    ),
    SkillNode(
      id: 'damage-3',
      branch: SkillBranch.damage,
      title: 'Harder hit III',
      detail: 'Snowballs hit 4 times as hard.',
      cost: 155,
      parentId: 'damage-2',
    ),
    SkillNode(
      id: 'damage-4',
      branch: SkillBranch.damage,
      title: 'Harder hit IV',
      detail: 'Snowballs hit 5 times as hard.',
      cost: 390,
      parentId: 'damage-3',
    ),
  ];

  static final Map<String, SkillNode> byId = {
    for (final node in nodes) node.id: node,
  };

  static final Map<SkillBranch, List<SkillNode>> _chains = {
    for (final branch in SkillBranch.values)
      branch: List.unmodifiable([
        for (final node in nodes)
          if (node.branch == branch) node,
      ]),
  };

  static List<SkillNode> chain(SkillBranch branch) => _chains[branch]!;

  /// Branches each kid owns separately; the rest are shared by the team.
  /// One kid can go for defence while another hits harder.
  static const Set<SkillBranch> personal = {
    SkillBranch.health,
    SkillBranch.shield,
    SkillBranch.poise,
    SkillBranch.throwSpeed,
    SkillBranch.damage,
    SkillBranch.aim,
    SkillBranch.reaction,
    SkillBranch.charge,
  };

  static bool isPersonal(SkillBranch branch) => personal.contains(branch);

  /// A kid's own branches that keep them standing.
  static const Set<SkillBranch> personalDefense = {
    SkillBranch.health,
    SkillBranch.shield,
    SkillBranch.poise,
  };

  /// A kid's own branches that make them a better teammate when the game
  /// plays them (aim, Quicker pals, Faster pals). The rest of their own
  /// branches (Throw, Harder hit) are attack.
  static const Set<SkillBranch> personalCrew = {
    SkillBranch.aim,
    SkillBranch.reaction,
    SkillBranch.charge,
  };

  /// Saved key for kid [kid] owning node [id] (for example `k1:shield-2`).
  static String kidKey(int kid, String id) => 'k$kid:$id';

  /// Splits a saved key into the kid (null for a team node) and node id.
  static (int?, String) parseKey(String key) {
    final match = RegExp(r'^k(\d):(.+)$').firstMatch(key);
    if (match == null) return (null, key);
    return (int.parse(match.group(1)!), match.group(2)!);
  }

  /// Personal ranks cost this much of the catalog price, because each kid
  /// buys them separately.
  static const double personalPriceScale = 0.6;

  /// Chains that keep going past their hand-made ranks. Team (the crew
  /// stays at three), Recovery, and Lanes stop where they are.
  static List<SkillNode> _generated() {
    final out = <SkillNode>[];
    for (final branch in SkillBranch.values) {
      final hand = [
        for (final node in _hand)
          if (node.branch == branch) node,
      ];
      final n = hand.length;
      final namer = _names(branch, n);
      if (namer == null) continue;
      var price = hand.first.cost.toDouble();
      for (var r = 2; r <= n; r++) {
        price *= stepFor(r, n);
      }
      var parent = hand.last.id;
      for (var r = n + 1; ; r++) {
        price *= stepFor(r, n);
        final cost = _round5(price);
        if (cost > maxPrice) break;
        final (id, title, detail) = namer(r);
        out.add(
          SkillNode(
            id: id,
            branch: branch,
            title: title,
            detail: detail,
            cost: cost,
            parentId: parent,
          ),
        );
        parent = id;
      }
    }
    return out;
  }

  static (String, String, String) Function(int rank)? _names(
    SkillBranch branch,
    int hand,
  ) {
    return switch (branch) {
      SkillBranch.team ||
      SkillBranch.health ||
      SkillBranch.recovery ||
      SkillBranch.lanes ||
      SkillBranch.moreForts => null,
      SkillBranch.throwSpeed => (r) => (
        'throw-$r',
        'Quicker throw ${roman(r)}',
        'Gets its throw ready even faster.',
      ),
      SkillBranch.poise => (r) => (
        'poise-$r',
        'Shake it off ${roman(r)}',
        'Gets back up even faster.',
      ),
      SkillBranch.pressure => (r) => (
        'pressure-$r',
        'Heavy hit ${roman(r)}',
        'Kids you hit stay dizzy even longer.',
      ),
      SkillBranch.aim => (r) => (
        'aim-$r',
        'Sharper aim ${roman(r)}',
        'Aims even better on its own.',
      ),
      SkillBranch.reaction => (r) => (
        'react-$r',
        'Quicker pals ${roman(r)}',
        'Throws even more often on its own.',
      ),
      SkillBranch.charge => (r) => (
        'charge-$r',
        'Faster pals ${roman(r)}',
        'Gets ready even faster on its own.',
      ),
      SkillBranch.shield => (r) => (
        'shield-$r',
        'Shield ${roman(r)}',
        'Blocks ${SkillEffects.shield(r)} hits every wave.',
      ),
      SkillBranch.blast => (r) => (
        'blast-$r',
        'Wider splat ${roman(r)}',
        'An even bigger splat.',
      ),
      SkillBranch.damage => (r) => (
        'damage-$r',
        'Harder hit ${roman(r)}',
        'Snowballs hit ${SkillEffects.kidHits(r)} times as hard.',
      ),
      // The fort chain is two stages, then packed-snow HP ranks.
      SkillBranch.fort => (r) => (
        'fort-hp-${r - 2}',
        'Ice blocks ${roman(r - 2)}',
        'More ice blocks. Your fort takes 4 more hits.',
      ),
    };
  }

  static String roman(int n) {
    const values = [10, 9, 5, 4, 1];
    const symbols = ['X', 'IX', 'V', 'IV', 'I'];
    final out = StringBuffer();
    var left = n;
    for (var i = 0; i < values.length; i++) {
      while (left >= values[i]) {
        out.write(symbols[i]);
        left -= values[i];
      }
    }
    return out.toString();
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
