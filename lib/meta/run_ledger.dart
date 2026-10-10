import 'power_up.dart';

/// Per-wallet counters that change prices, plus the Arcade checkpoint.
///
/// Kept apart from [MetaState]'s coins and skills so a save snapshot can
/// copy it in one go.
class RunLedger {
  RunLedger({
    this.kidLosses = 0,
    this.reviveBought = 0,
    this.checkpointWave = 0,
    this.checkpointCoins = 0,
    Set<String>? checkpointSkills,
    Map<PowerUp, int>? checkpointItems,
    this.checkpointKidLosses = 0,
    this.checkpointReviveBought = 0,
    this.earnedSinceCheckpoint = 0,
    List<int>? kidRevives,
    List<int>? checkpointKidRevives,
  }) : checkpointSkills = checkpointSkills ?? {},
       checkpointItems = checkpointItems ?? {},
       kidRevives = _three(kidRevives),
       checkpointKidRevives = _three(checkpointKidRevives);

  static List<int> _three(List<int>? from) => [
    for (var i = 0; i < 3; i++) from != null && i < from.length ? from[i] : 0,
  ];

  /// Times each kid has been revived between waves. Each revive of the
  /// same kid costs twice the last.
  final List<int> kidRevives;
  final List<int> checkpointKidRevives;

  int revivesOf(int kid) => kid >= 0 && kid < 3 ? kidRevives[kid] : 0;

  void addRevive(int kid) {
    if (kid >= 0 && kid < 3) kidRevives[kid] += 1;
  }

  /// Unused since kids stay in the crew when knocked out; kept so older
  /// saves still read.
  int kidLosses;

  /// Revive potions bought so far. Each one makes the next cost more.
  int reviveBought;

  /// First wave of the stage the checkpoint belongs to. 0 when none.
  int checkpointWave;

  /// The build locked in at the checkpoint.
  int checkpointCoins;
  Set<String> checkpointSkills;
  Map<PowerUp, int> checkpointItems;
  int checkpointKidLosses;
  int checkpointReviveBought;

  /// Coins earned since the checkpoint. A loss keeps half.
  int earnedSinceCheckpoint;

  bool get hasCheckpoint => checkpointWave > 0;

  RunLedger copy() => RunLedger(
    kidLosses: kidLosses,
    reviveBought: reviveBought,
    checkpointWave: checkpointWave,
    checkpointCoins: checkpointCoins,
    checkpointSkills: Set.of(checkpointSkills),
    checkpointItems: Map.of(checkpointItems),
    checkpointKidLosses: checkpointKidLosses,
    checkpointReviveBought: checkpointReviveBought,
    earnedSinceCheckpoint: earnedSinceCheckpoint,
    kidRevives: List.of(kidRevives),
    checkpointKidRevives: List.of(checkpointKidRevives),
  );

  /// Forget the checkpoint (a fresh run).
  void clearCheckpoint() {
    checkpointWave = 0;
    checkpointCoins = 0;
    checkpointSkills = {};
    checkpointItems = {};
    checkpointKidLosses = 0;
    checkpointReviveBought = 0;
    earnedSinceCheckpoint = 0;
    checkpointKidRevives.setAll(0, [0, 0, 0]);
  }

  Map<String, Object> toJson() => {
    'kidLosses': kidLosses,
    'reviveBought': reviveBought,
    'kidRevives': kidRevives,
    if (hasCheckpoint)
      'checkpoint': {
        'wave': checkpointWave,
        'coins': checkpointCoins,
        'skills': checkpointSkills.toList()..sort(),
        'items': {for (final e in checkpointItems.entries) e.key.name: e.value},
        'kidLosses': checkpointKidLosses,
        'reviveBought': checkpointReviveBought,
        'earned': earnedSinceCheckpoint,
        'kidRevives': checkpointKidRevives,
      },
  };

  factory RunLedger.fromJson(Object? raw) {
    if (raw is! Map) return RunLedger();
    final cp = raw['checkpoint'];
    List<int>? revives(Object? list) =>
        list is List ? [for (final v in list) _int(v, 0, 99)] : null;
    final ledger = RunLedger(
      kidLosses: _int(raw['kidLosses'], 0, 999),
      reviveBought: _int(raw['reviveBought'], 0, 999),
      kidRevives: revives(raw['kidRevives']),
      checkpointKidRevives: cp is Map ? revives(cp['kidRevives']) : null,
    );
    if (cp is Map) {
      ledger
        ..checkpointWave = _int(cp['wave'], 0, 9999)
        ..checkpointCoins = _int(cp['coins'], 0, 999999999)
        ..checkpointSkills = {
          if (cp['skills'] is List)
            for (final id in cp['skills'] as List)
              if (id is String) id,
        }
        ..checkpointItems = {
          if (cp['items'] is Map)
            for (final e in (cp['items'] as Map).entries)
              ?PowerUp.tryParse(e.key is String ? e.key as String : null): _int(
                e.value,
                0,
                PowerUp.maxHeld,
              ),
        }
        ..checkpointKidLosses = _int(cp['kidLosses'], 0, 999)
        ..checkpointReviveBought = _int(cp['reviveBought'], 0, 999)
        ..earnedSinceCheckpoint = _int(cp['earned'], 0, 999999999);
    }
    return ledger;
  }

  static int _int(Object? value, int min, int max) {
    final n = value is num ? value.toInt() : 0;
    return n < min ? min : (n > max ? max : n);
  }
}
