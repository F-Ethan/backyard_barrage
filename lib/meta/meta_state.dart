import '../seasons/season.dart';
import 'difficulty.dart';
import 'play_mode.dart';
import 'skill_tree.dart';

/// One wallet: the skill tree, coins, and best wave for one mode on one
/// difficulty. Each mode × difficulty pair has its own ([PlayerSave]).
///
/// Crew size, fort stage, and throw rank are the team, fort, and throw
/// chains. Season is shared by both modes and stored here so a match can
/// swap it. Arcade defeat clears every node and keeps the unspent coins.
/// Campaign defeat keeps the nodes.
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
    this.resumeWave = 0,
    this.resumeArena,
    this.mode = PlayMode.arcade,
    this.difficulty = Difficulty.normal,
  }) : _season = season.orPlayable {
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
  static const int maxThrowRank = 5;

  /// Snowball body radius before blast ranks.
  static const double baseBlastRadius = 22;

  static const List<double> _poiseScales = [1, 0.82, 0.66, 0.52, 0.40];
  static const List<double> _pressureScales = [1, 1.25, 1.55, 1.9, 2.3];
  static const List<double> _aimScales = [1, 0.72, 0.48, 0.28];
  static const List<double> _gapScales = [1, 0.84, 0.68, 0.52];
  static const List<double> _chargeScales = [1, 0.86, 0.72, 0.58];
  static const List<double> _blastScales = [1, 1.2, 1.45, 1.75, 2.05];

  int coins;
  PlayMode mode;

  /// Never a switched-off season ([Season.playable]).
  Season get season => _season;
  set season(Season value) => _season = value.orPlayable;
  Season _season;

  /// The difficulty this wallet belongs to.
  Difficulty difficulty;

  /// Highest wave cleared in this mode on [difficulty]. 0 when none.
  int bestWave;

  /// Lifetime points. Every coin earned also adds a point, but points are
  /// never spent and never reset. Arcade shows this as its score.
  int score;

  /// Wave to pick up from after leaving through Pause → Menu, or 0 when
  /// there is no run to resume. A defeat clears it.
  int resumeWave;

  /// Arena name of the run to resume, so the scenery comes back too.
  String? resumeArena;

  bool get canResume => resumeWave > 0;

  /// Pay [amount] coins and the matching points.
  void earn(int amount) {
    if (amount <= 0) return;
    coins += amount;
    score += amount;
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

  int get throwRank =>
      _ownedPrefix(SkillBranch.throwSpeed).clamp(0, maxThrowRank);

  /// Extra fort HP from the packed-snow chain, on top of the stage.
  int get fortBonusHp => 4 * _hpRank;

  int get _hpRank {
    var rank = 0;
    if (owns('fort-hp-1')) rank = 1;
    if (owns('fort-hp-2')) rank = 2;
    return rank;
  }

  int get shieldCharges => _ownedPrefix(SkillBranch.shield).clamp(0, 3);

  bool get passesOwnFort => owns('lanes');

  double get blastScale => _scale(_blastScales, SkillBranch.blast);

  double get allyAimScale => _scale(_aimScales, SkillBranch.aim);

  double get allyGapScale => _scale(_gapScales, SkillBranch.reaction);

  double get allyChargeScale => _scale(_chargeScales, SkillBranch.charge);

  /// Hits one of your snowballs applies. The manual thrower reaches 2, then 3.
  /// Teammate bots stay at 1 until the later damage nodes.
  int hitsFor({required bool manualThrow}) {
    final rank = _ownedPrefix(SkillBranch.damage);
    if (manualThrow) {
      if (rank >= 2) return 3;
      if (rank >= 1) return 2;
      return 1;
    }
    if (rank >= 4) return 3;
    if (rank >= 3) return 2;
    return 1;
  }

  /// Multiplier on the base stun lock. Allies use poise. Rivals use pressure.
  double stunScaleFor({required bool ally}) {
    if (ally) return _scale(_poiseScales, SkillBranch.poise);
    return _scale(_pressureScales, SkillBranch.pressure);
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

  int? get nextKidCost => nextKidNode?.cost;

  int? get nextFortCost => nextFortStageNode?.cost;

  int? get nextThrowCost => nextThrowNode?.cost;

  bool get canBuyKid => canBuy(nextKidNode?.id);

  bool get canBuyFort => canBuy(nextFortStageNode?.id);

  bool get canBuyThrow => canBuy(nextThrowNode?.id);

  bool canBuy(String? id) {
    if (id == null) return false;
    final node = SkillTree.node(id);
    if (node == null || owns(id)) return false;
    if (skillLock(id) != SkillLock.open) return false;
    return coins >= node.cost;
  }

  /// Parent chain first, then the second-kid gate. Owned nodes are open.
  SkillLock skillLock(String id) {
    final node = SkillTree.node(id);
    if (node == null || owns(id)) return SkillLock.open;
    final parent = node.parentId;
    if (parent != null && !owns(parent)) return SkillLock.parent;
    if (node.needsTeammate && crewSize < 2) return SkillLock.teammate;
    return SkillLock.open;
  }

  /// Copy for a greyed node. Null when the node is owned or ready to buy.
  String? lockReason(String id) => switch (skillLock(id)) {
    SkillLock.open => null,
    SkillLock.parent => SkillTree.parentLockReason,
    SkillLock.teammate => SkillTree.teammateLockReason,
  };

  bool buy(String id) {
    if (!canBuy(id)) return false;
    final node = SkillTree.node(id)!;
    coins -= node.cost;
    _skills.add(id);
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

  /// Arcade drops every skill. Campaign keeps bought nodes.
  ///
  /// Unspent coins, season, and best wave stay either way. The caller
  /// restarts the match at wave 1.
  void resetRun() {
    if (mode == PlayMode.arcade) {
      _skills.clear();
    }
  }

  /// Replace the owned set with [owned], closing any gap back to the root.
  void replaceSkills(Set<String> owned) {
    final next = _closed(owned);
    _skills
      ..clear()
      ..addAll(next);
  }

  /// Soft currency for knocking out one rival.
  static const int coinsPerKnockout = 8;

  /// Bonus for clearing [wave] (1-based), on top of each knockout.
  static int coinsForWave(int wave) => 12 + wave * 8;

  Map<String, Object> toJson() => {
    'coins': coins,
    'crewSize': crewSize,
    'fortStage': fortStage,
    'throwRank': throwRank,
    'skills': _skills.toList()..sort(),
    'season': season.name,
    'bestWave': bestWave,
    'score': score,
    'resumeWave': resumeWave,
    if (resumeArena != null) 'resumeArena': resumeArena!,
    'difficulty': difficulty.name,
    'mode': mode.name,
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
      coins: _clampInt(_asInt(json['coins']), 0, 999999),
      skills: skills,
      season: Season.tryParse(json['season'] as String?) ?? Season.winter,
      bestWave: _clampInt(_asInt(json['bestWave']), 0, 9999),
      score: _clampInt(_asInt(json['score']), 0, 999999999),
      resumeWave: _clampInt(_asInt(json['resumeWave']), 0, 9999),
      resumeArena: json['resumeArena'] is String
          ? json['resumeArena'] as String
          : null,
      difficulty: _readDifficulty(json['difficulty']),
      mode: PlayMode.tryParse(json['mode'] as String?) ?? PlayMode.arcade,
    );
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

  double _scale(List<double> table, SkillBranch branch) {
    final rank = branch == SkillBranch.fort ? _hpRank : _ownedPrefix(branch);
    final index = rank < 0
        ? 0
        : (rank >= table.length ? table.length - 1 : rank);
    return table[index];
  }

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
