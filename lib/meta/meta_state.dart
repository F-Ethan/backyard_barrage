import 'dart:math' as math;

import '../seasons/season.dart';
import 'difficulty.dart';
import 'power_up.dart';
import 'play_mode.dart';
import 'run_ledger.dart';
import 'skill_effects.dart';
import 'skill_tree.dart';

/// One wallet: the skill tree, coins, and best wave for one mode on one
/// difficulty. Each mode × difficulty pair has its own ([PlayerSave]).
///
/// Crew size, fort stage, and throw rank are the team, fort, and throw
/// chains. Season is shared by both modes and stored here so a match can
/// swap it. [PlayMode.arcade] (shown as Campaign) defeat clears every node
/// and keeps the unspent coins. [PlayMode.campaign] (shown as Arcade) goes
/// back to its stage checkpoint ([restoreCheckpoint]).
class MetaState {
  MetaState({
    this.coins = 0,
    int crewSize = 1,
    int fortStage = 1,
    int throwRank = 0,
    Set<String>? skills,
    Season season = Season.winter,
    this.bestWave = 0,
    this.score = 0,
    int? bestScore,
    this.resumeWave = 0,
    this.resumeArena,
    this.resumeCrewHp,
    Map<PowerUp, int>? items,
    this.mode = PlayMode.arcade,
    this.difficulty = Difficulty.normal,
    RunLedger? ledger,
  }) : _season = season.orPlayable,
       bestScore = math.max(bestScore ?? 0, score),
       ledger = ledger ?? RunLedger() {
    if (items != null) replaceItems(items);
    if (skills != null) {
      _skills.addAll(_closed(skills));
    } else {
      _skills.addAll(
        SkillTree.legacyNodes(
          crewSize: crewSize,
          fortStage: fortStage,
          throwRank: throwRank,
        ),
      );
    }
  }

  static const int maxCrew = 3;
  static const int maxFortStage = 3;

  /// Hand-made throw ranks. The chain keeps going past this.
  static const int maxThrowRank = 5;

  /// Snowball body radius before blast ranks.
  static const double baseBlastRadius = 22;

  /// Most coins a wallet holds.
  static const int maxCoins = 999999999;

  int coins;

  /// Lost kids, Revive purchases, and the Arcade checkpoint.
  RunLedger ledger;
  PlayMode mode;

  /// Never a switched-off season ([Season.playable]).
  Season get season => _season;
  set season(Season value) => _season = value.orPlayable;
  Season _season;

  /// The difficulty this wallet belongs to.
  Difficulty difficulty;

  /// Highest wave cleared in this mode on [difficulty]. 0 when none.
  int bestWave;

  /// Lifetime points. Every coin earned adds a point, clearing a wave adds
  /// [waveClearPoints] plus a thrift bonus on unspent coins, and a defeat
  /// takes [defeatPenalty] away (never below 0). Points are never spent.
  /// Arcade shows this as its score. [startOver] sets it back to 0.
  int score;

  /// Highest [score] this wallet has reached. A defeat or a start-over
  /// never lowers it.
  int bestScore;

  void _noteScore() {
    if (score > bestScore) bestScore = score;
  }

  /// Wave to pick up from after leaving through Pause → Menu, or 0 when
  /// there is no run to resume. A defeat clears it.
  int resumeWave;

  /// Arena name of the run to resume, so the scenery comes back too.
  String? resumeArena;

  /// Each kid's HP going into the resumed wave, so leaving cannot heal the
  /// crew in Campaign. 0 means that kid sits the wave out. Null starts
  /// everyone at full health.
  List<int>? resumeCrewHp;

  bool get canResume => resumeWave > 0;

  /// Extra HP each standing kid regains between waves (Patch up).
  int get healPerWave {
    if (owns('mend-2')) return 2;
    if (owns('mend-1')) return 1;
    return 0;
  }

  /// One knocked-out teammate rejoins each wave at 1 HP (Second wind).
  bool get reviveOne => owns('revive-1');
  final Map<PowerUp, int> _items = {};

  /// One-use power-ups in this wallet. They stay until used. A Campaign
  /// defeat clears them with the skills; Arcade goes back to the
  /// checkpoint's items.
  Map<PowerUp, int> get items => Map.unmodifiable(_items);

  int itemCount(PowerUp item) => _items[item] ?? 0;

  void replaceItems(Map<PowerUp, int> next) {
    _items.clear();
    for (final entry in next.entries) {
      final n = entry.value.clamp(0, PowerUp.maxHeld);
      if (n > 0) _items[entry.key] = n;
    }
  }

  /// What [item] costs now. Revive starts at twice the third kid's price
  /// and goes up 1.5× with every one bought.
  int itemCost(PowerUp item) {
    if (item != PowerUp.revive) return item.cost;
    final base = 2 * SkillTree.node('team-3')!.cost;
    return _round5(base * math.pow(1.5, ledger.reviveBought).toDouble());
  }

  bool canBuyItem(PowerUp item) => coins >= itemCost(item);

  bool buyItem(PowerUp item) {
    if (!canBuyItem(item)) return false;
    coins -= itemCost(item);
    _items[item] = itemCount(item) + 1;
    if (item == PowerUp.revive) ledger.reviveBought += 1;
    return true;
  }

  /// Adds one random item for free (a hound or boss reward) and returns
  /// it. A free Revive does not raise the Revive price.
  PowerUp grantRandomItem(math.Random rng) {
    final item = PowerUp.values[rng.nextInt(PowerUp.values.length)];
    _items[item] = itemCount(item) + 1;
    return item;
  }

  /// Spend one. False when there is none.
  bool useItem(PowerUp item) {
    final n = itemCount(item);
    if (n <= 0) return false;
    if (n == 1) {
      _items.remove(item);
    } else {
      _items[item] = n - 1;
    }
    return true;
  }

  /// Pay [amount] coins and the matching points.
  void earn(int amount) {
    if (amount <= 0) return;
    coins = math.min(coins + amount, maxCoins);
    score += amount;
    _noteScore();
    ledger.earnedSinceCheckpoint += amount;
  }

  /// Points for clearing [wave]: how far the run got.
  static int waveClearPoints(int wave) => 10 * wave;

  /// Points lost to a defeat on [wave].
  static int defeatPenalty(int wave) => 50 * wave;

  /// Score for clearing [wave]: distance, plus a tenth of the unspent coins
  /// (spending less scores more). Returns the points added.
  int scoreWaveClear(int wave) {
    final points = waveClearPoints(wave) + coins ~/ 10;
    score += points;
    _noteScore();
    return points;
  }

  /// Score for a defeat on [wave]. Returns the points taken (never below 0).
  int scoreDefeat(int wave) {
    final taken = math.min(score, defeatPenalty(wave));
    score -= taken;
    return taken;
  }

  final Set<String> _skills = {};

  Set<String> get skills => Set.unmodifiable(_skills);

  bool owns(String id) => _skills.contains(id);

  int get crewSize => 1 + _ownedPrefix(SkillBranch.team).clamp(0, 2);

  int get fortStage {
    if (owns('fort-3')) return 3;
    if (owns('fort-2')) return 2;
    return 1;
  }

  int get throwRank => _ownedPrefix(SkillBranch.throwSpeed);

  /// Extra fort HP from the packed-snow chain, on top of the stage.
  int get fortBonusHp => SkillEffects.fortHp(_hpRank);

  int get _hpRank {
    var rank = 0;
    while (owns('fort-hp-${rank + 1}')) {
      rank += 1;
    }
    return rank;
  }

  int get shieldCharges =>
      SkillEffects.shield(_ownedPrefix(SkillBranch.shield));

  bool get passesOwnFort => owns('lanes');

  /// Extra forts bought (More forts), on top of the main fort.
  int get extraForts => _ownedPrefix(SkillBranch.moreForts);

  double get blastScale => SkillEffects.blast(_ownedPrefix(SkillBranch.blast));

  double get allyAimScale => SkillEffects.aim(_ownedPrefix(SkillBranch.aim));

  double get allyGapScale =>
      SkillEffects.gap(_ownedPrefix(SkillBranch.reaction));

  double get allyChargeScale =>
      SkillEffects.charge(_ownedPrefix(SkillBranch.charge));

  /// Hits one of your snowballs applies. The manual thrower reaches 2, then 3.
  /// Teammate bots stay at 1 until the later damage nodes.
  int hitsFor({required bool manualThrow}) {
    final rank = _ownedPrefix(SkillBranch.damage);
    return manualThrow
        ? SkillEffects.manualHits(rank)
        : SkillEffects.botHits(rank);
  }

  /// Multiplier on the base stun lock. Allies use poise. Rivals use pressure.
  double stunScaleFor({required bool ally}) {
    if (ally) return SkillEffects.poise(_ownedPrefix(SkillBranch.poise));
    return SkillEffects.pressure(_ownedPrefix(SkillBranch.pressure));
  }

  SkillNode? nextIn(SkillBranch branch) {
    for (final node in SkillTree.chain(branch)) {
      if (!owns(node.id)) return node;
    }
    return null;
  }

  /// Next crew node. Null when the crew is already three.
  SkillNode? get nextKidNode => nextIn(SkillBranch.team);

  /// Next fort stage, not the later HP nodes.
  SkillNode? get nextFortStageNode {
    for (final id in ['fort-2', 'fort-3']) {
      if (!owns(id)) return SkillTree.node(id);
    }
    return null;
  }

  SkillNode? get nextThrowNode => nextIn(SkillBranch.throwSpeed);

  int? get nextKidCost => _costOrNull(nextKidNode);

  int? get nextFortCost => _costOrNull(nextFortStageNode);

  int? get nextThrowCost => _costOrNull(nextThrowNode);

  int? _costOrNull(SkillNode? node) => node == null ? null : costOf(node.id);

  /// What node [id] costs now. Crew nodes go up 1.5× for every teammate
  /// lost so far; everything else is the catalog price.
  int costOf(String id) {
    final node = SkillTree.node(id);
    if (node == null) return 0;
    if (node.branch != SkillBranch.team || ledger.kidLosses == 0) {
      return node.cost;
    }
    return _round5(node.cost * math.pow(1.5, ledger.kidLosses).toDouble());
  }

  static int _round5(double price) => ((price / 5) + 0.5).floor() * 5;

  bool get canBuyKid => canBuy(nextKidNode?.id);

  bool get canBuyFort => canBuy(nextFortStageNode?.id);

  bool get canBuyThrow => canBuy(nextThrowNode?.id);

  bool canBuy(String? id) {
    if (id == null) return false;
    final node = SkillTree.node(id);
    if (node == null || owns(id)) return false;
    if (skillLock(id) != SkillLock.open) return false;
    return coins >= costOf(id);
  }

  /// Parent chain first, then the second-kid gate. Owned nodes are open.
  SkillLock skillLock(String id) {
    final node = SkillTree.node(id);
    if (node == null || owns(id)) return SkillLock.open;
    final parent = node.parentId;
    if (parent != null && !owns(parent)) return SkillLock.parent;
    if (node.branch == SkillBranch.recovery) {
      if (difficulty == Difficulty.easy) return SkillLock.easyHeals;
    }
    if (node.needsTeammate && crewSize < 2) return SkillLock.teammate;
    return SkillLock.open;
  }

  /// Copy for a greyed node. Null when the node is owned or ready to buy.
  String? lockReason(String id) => switch (skillLock(id)) {
    SkillLock.open => null,
    SkillLock.parent => SkillTree.parentLockReason,
    SkillLock.teammate => SkillTree.teammateLockReason,
    SkillLock.easyHeals => SkillTree.easyHealsReason,
  };

  bool buy(String id) {
    if (!canBuy(id)) return false;
    coins -= costOf(id);
    _skills.add(id);
    return true;
  }

  /// True when a node should not show in the shop at all: it can never be
  /// bought on this difficulty (Easy already gives Recovery for free).
  bool hidesNode(String id) =>
      difficulty == Difficulty.easy &&
      SkillTree.node(id)?.branch == SkillBranch.recovery;

  /// A teammate was knocked out and not brought back: their spot in the
  /// crew opens up again, and the crew nodes cost more from now on.
  /// Returns false when there was no teammate to lose.
  bool loseKid() {
    final owned = [
      for (final node in SkillTree.chain(SkillBranch.team))
        if (owns(node.id)) node.id,
    ];
    if (owned.isEmpty) return false;
    _skills.remove(owned.last);
    ledger.kidLosses += 1;
    return true;
  }

  bool buyExtraKid() {
    final next = nextKidNode;
    if (next == null) return false;
    return buy(next.id);
  }

  bool buyFort() {
    final next = nextFortStageNode;
    if (next == null) return false;
    return buy(next.id);
  }

  bool buyThrowSpeed() {
    final next = nextThrowNode;
    if (next == null) return false;
    return buy(next.id);
  }

  void noteWaveCleared(int wave) {
    if (wave > bestWave) bestWave = wave;
  }

  /// Waves in one Arcade stage.
  static const int stageLength = 5;

  /// 1-based stage for [wave]: waves 1–5 are stage 1, 6–10 stage 2.
  static int stageOf(int wave) => (math.max(wave, 1) - 1) ~/ stageLength + 1;

  /// First wave of [wave]'s stage.
  static int stageStart(int wave) => (stageOf(wave) - 1) * stageLength + 1;

  /// True when [wave] opens a stage.
  static bool opensStage(int wave) => stageStart(wave) == wave;

  /// Lock in the build at the start of [wave]'s stage (Arcade).
  ///
  /// [exact] locks in at [wave] itself (a boss wave gets its own
  /// checkpoint, so a loss retries just the boss).
  void takeCheckpoint(int wave, {bool exact = false}) {
    ledger
      ..checkpointWave = exact ? wave : stageStart(wave)
      ..checkpointCoins = coins
      ..checkpointSkills = Set.of(_skills)
      ..checkpointItems = Map.of(_items)
      ..checkpointKidLosses = ledger.kidLosses
      ..checkpointReviveBought = ledger.reviveBought
      ..earnedSinceCheckpoint = 0;
  }

  /// Back to the checkpoint build after an Arcade defeat: every skill and
  /// item bought since is refunded, and half the coins earned since are
  /// lost. The checkpoint then holds the new coin total for the retry.
  /// Without a checkpoint (an older save), the run goes back to the start
  /// of [lostOn]'s stage and only the coin half is taken.
  CheckpointResult restoreCheckpoint({int lostOn = 1}) {
    final wave = ledger.hasCheckpoint
        ? ledger.checkpointWave
        : stageStart(lostOn);
    final earned = ledger.earnedSinceCheckpoint;
    final kept = earned ~/ 2;
    final spent = ledger.hasCheckpoint
        ? math.max(0, ledger.checkpointCoins + earned - coins)
        : 0;
    if (ledger.hasCheckpoint) {
      replaceSkills(ledger.checkpointSkills);
      replaceItems(ledger.checkpointItems);
      ledger.kidLosses = ledger.checkpointKidLosses;
      ledger.reviveBought = ledger.checkpointReviveBought;
      coins = ledger.checkpointCoins + kept;
    } else {
      coins = math.max(0, coins - (earned - kept));
    }
    takeCheckpoint(wave, exact: true);
    return CheckpointResult(
      wave: wave,
      coinsLost: earned - kept,
      refunded: spent,
    );
  }

  /// A fresh Arcade run from wave 1: no coins, skills, or items, prices
  /// back to the start, and the run score at 0. [bestScore] and the best
  /// wave stay.
  void startOver() {
    coins = 0;
    score = 0;
    _skills.clear();
    _items.clear();
    ledger = RunLedger();
    resumeWave = 0;
    resumeArena = null;
    resumeCrewHp = null;
  }

  /// A defeat. [PlayMode.arcade] (shown as Campaign) drops every skill and
  /// item and starts over at wave 1; unspent coins stay. [PlayMode.campaign] (shown
  /// as Arcade) goes back to its stage checkpoint.
  ///
  /// Season and best wave stay either way. The caller restarts the match
  /// at [CheckpointResult.wave].
  CheckpointResult resetRun({int lostOn = 1}) {
    if (mode == PlayMode.campaign) return restoreCheckpoint(lostOn: lostOn);
    _skills.clear();
    _items.clear();
    ledger
      ..kidLosses = 0
      ..reviveBought = 0
      ..clearCheckpoint();
    return const CheckpointResult(wave: 1, coinsLost: 0, refunded: 0);
  }

  /// Replace the owned set with [owned], closing any gap back to the root.
  void replaceSkills(Set<String> owned) {
    final next = _closed(owned);
    _skills
      ..clear()
      ..addAll(next);
  }

  /// Soft currency for knocking out one rival on wave 1–5. Each later
  /// stage pays one more ([coinsForKnockout]).
  static const int coinsPerKnockout = 4;

  static int coinsForKnockout(int wave) => coinsPerKnockout + stageOf(wave) - 1;

  /// Bonus for clearing [wave] (1-based), on top of each knockout. Grows
  /// 10% a wave on top of the old linear 6 + 4w, so later skill ranks stay
  /// in reach for a run that keeps winning.
  static int coinsForWave(int wave) {
    final w = math.max(wave, 1);
    return ((6 + w * 4) * math.pow(1.1, w - 1)).round();
  }

  Map<String, Object> toJson() => {
    'coins': coins,
    'crewSize': crewSize,
    'fortStage': fortStage,
    'throwRank': throwRank,
    'skills': _skills.toList()..sort(),
    'season': season.name,
    'bestWave': bestWave,
    'score': score,
    'bestScore': bestScore,
    'resumeWave': resumeWave,
    'items': {for (final e in _items.entries) e.key.name: e.value},
    'resumeArena': ?resumeArena,
    'resumeCrewHp': ?resumeCrewHp,
    'difficulty': difficulty.name,
    'mode': mode.name,
    'ledger': ledger.toJson(),
  };

  factory MetaState.fromJson(Map<String, dynamic> json) {
    final crew = _clampInt(_asInt(json['crewSize'], 1), 1, maxCrew);
    final fort = _clampInt(_asInt(json['fortStage'], 1), 1, maxFortStage);
    final thrown = _clampInt(_asInt(json['throwRank']), 0, maxThrowRank);
    final Set<String> skills;
    if (json.containsKey('skills')) {
      final raw = json['skills'];
      skills = {
        if (raw is List)
          for (final id in raw)
            if (id is String && SkillTree.node(id) != null) id,
      };
    } else {
      skills = SkillTree.legacyNodes(
        crewSize: crew,
        fortStage: fort,
        throwRank: thrown,
      );
    }
    return MetaState(
      coins: _clampInt(_asInt(json['coins']), 0, maxCoins),
      skills: skills,
      season: Season.tryParse(json['season'] as String?) ?? Season.winter,
      bestWave: _clampInt(_asInt(json['bestWave']), 0, 9999),
      score: _clampInt(_asInt(json['score']), 0, 999999999),
      bestScore: _clampInt(_asInt(json['bestScore']), 0, 999999999),
      resumeWave: _clampInt(_asInt(json['resumeWave']), 0, 9999),
      items: _readItems(json['items']),
      resumeArena: json['resumeArena'] is String
          ? json['resumeArena'] as String
          : null,
      resumeCrewHp: json['resumeCrewHp'] is List
          ? [
              for (final v in json['resumeCrewHp'] as List)
                _clampInt(_asInt(v), 0, 99),
            ]
          : null,
      difficulty: _readDifficulty(json['difficulty']),
      mode: PlayMode.tryParse(json['mode'] as String?) ?? PlayMode.arcade,
      ledger: RunLedger.fromJson(json['ledger']),
    );
  }

  static Map<PowerUp, int>? _readItems(Object? raw) {
    if (raw is! Map) return null;
    return {
      for (final entry in raw.entries)
        ?PowerUp.tryParse(entry.key is String ? entry.key as String : null):
            _clampInt(_asInt(entry.value), 0, PowerUp.maxHeld),
    };
  }

  static Difficulty _readDifficulty(Object? raw) {
    for (final mode in Difficulty.values) {
      if (mode.name == raw) return mode;
    }
    return Difficulty.normal;
  }

  /// Best waves from a save written before wallets split by difficulty.
  /// A `bestWaves` map (per difficulty) wins; a lone `bestWave` counts as
  /// Normal, the default setting.
  static Map<Difficulty, int> legacyBestWaves(Map<String, dynamic> json) {
    final raw = json['bestWaves'];
    if (raw is Map) {
      return {
        for (final mode in Difficulty.values)
          if (raw[mode.name] != null)
            mode: _clampInt(_asInt(raw[mode.name]), 0, 9999),
      };
    }
    final single = _clampInt(_asInt(json['bestWave']), 0, 9999);
    return {if (single > 0) Difficulty.normal: single};
  }

  int _ownedPrefix(SkillBranch branch) {
    var count = 0;
    for (final node in SkillTree.chain(branch)) {
      if (branch == SkillBranch.fort && node.id.startsWith('fort-hp')) break;
      if (!owns(node.id)) break;
      count += 1;
    }
    return count;
  }

  int get fortHpRank => _hpRank;

  static Set<String> _closed(Set<String> owned) {
    final closed = <String>{};
    for (final id in owned) {
      var cursor = SkillTree.node(id);
      while (cursor != null) {
        if (!closed.add(cursor.id)) break;
        final parent = cursor.parentId;
        cursor = parent == null ? null : SkillTree.node(parent);
      }
    }
    return closed;
  }

  static int _asInt(Object? value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }

  static int _clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}

/// What a defeat did to the wallet.
class CheckpointResult {
  const CheckpointResult({
    required this.wave,
    required this.coinsLost,
    required this.refunded,
  });

  /// Wave the retry starts on.
  final int wave;

  /// Coins taken back (half of those earned since the checkpoint).
  final int coinsLost;

  /// Coins handed back for skills and items bought since the checkpoint.
  final int refunded;
}
