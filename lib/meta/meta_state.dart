import '../seasons/season.dart';

/// Persistent soft-currency meta: crew size, fort, throw speed, last season.
class MetaState {
  MetaState({
    this.coins = 0,
    this.crewSize = 1,
    this.fortStage = 1,
    this.throwRank = 0,
    this.season = Season.winter,
    this.bestWave = 0,
  });

  static const int maxCrew = 3;
  static const int maxFortStage = 3;
  static const int maxThrowRank = 5;

  /// Cost to grow the crew from 1→2, then 2→3.
  static const List<int> kidUnlockCosts = [30, 60];

  /// Cost to raise the fort from stage 1→2, then 2→3.
  static const List<int> fortUpgradeCosts = [25, 55];

  int coins;
  int crewSize;
  int fortStage;
  int throwRank;
  Season season;
  int bestWave;

  int? get nextKidCost =>
      crewSize >= maxCrew ? null : kidUnlockCosts[crewSize - 1];

  int? get nextFortCost =>
      fortStage >= maxFortStage ? null : fortUpgradeCosts[fortStage - 1];

  /// Ranks 1 through [maxThrowRank]. Rank 0 is the starting throw.
  int? get nextThrowCost =>
      throwRank >= maxThrowRank ? null : 12 + throwRank * 8;

  bool get canBuyKid => _canAfford(nextKidCost);
  bool get canBuyFort => _canAfford(nextFortCost);
  bool get canBuyThrow => _canAfford(nextThrowCost);

  bool buyExtraKid() {
    final cost = nextKidCost;
    if (!_canAfford(cost)) return false;
    coins -= cost!;
    crewSize += 1;
    return true;
  }

  bool buyFort() {
    final cost = nextFortCost;
    if (!_canAfford(cost)) return false;
    coins -= cost!;
    fortStage += 1;
    return true;
  }

  bool buyThrowSpeed() {
    final cost = nextThrowCost;
    if (!_canAfford(cost)) return false;
    coins -= cost!;
    throwRank += 1;
    return true;
  }

  void noteWaveCleared(int wave) {
    if (wave > bestWave) bestWave = wave;
  }

  /// Soft currency for clearing [wave] (1-based).
  static int coinsForWave(int wave) => 12 + wave * 8;

  Map<String, Object> toJson() => {
        'coins': coins,
        'crewSize': crewSize,
        'fortStage': fortStage,
        'throwRank': throwRank,
        'season': season.name,
        'bestWave': bestWave,
      };

  factory MetaState.fromJson(Map<String, dynamic> json) {
    return MetaState(
      coins: _clampInt(_asInt(json['coins']), 0, 999999),
      crewSize: _clampInt(_asInt(json['crewSize'], 1), 1, maxCrew),
      fortStage: _clampInt(_asInt(json['fortStage'], 1), 1, maxFortStage),
      throwRank: _clampInt(_asInt(json['throwRank']), 0, maxThrowRank),
      season: Season.tryParse(json['season'] as String?) ?? Season.winter,
      bestWave: _clampInt(_asInt(json['bestWave']), 0, 9999),
    );
  }

  bool _canAfford(int? cost) => cost != null && coins >= cost;

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
