import '../seasons/season.dart';
import 'difficulty.dart';
import 'meta_state.dart';
import 'play_mode.dart';

/// Every wallet plus the shared season and the last mode played.
///
/// There is one wallet per mode per difficulty (six in all). Coins, skills,
/// and the best wave never cross between them: Campaign play does not touch
/// Arcade, and a run on Easy does not touch Normal or Hard.
///
/// Older saves migrate on load. A v2 save (one wallet per mode) moves each
/// wallet's coins and skills into Normal, and its per-difficulty bests into
/// the matching wallets. A v1 flat save becomes the [PlayMode.arcade] Normal
/// wallet.
class PlayerSave {
  PlayerSave({
    Season season = Season.winter,
    this.mode = PlayMode.arcade,
    Map<PlayMode, Map<Difficulty, MetaState>>? wallets,
  }) : _season = season.orPlayable {
    for (final m in PlayMode.values) {
      final row = _wallets[m] = {};
      for (final d in Difficulty.values) {
        final given = wallets?[m]?[d];
        row[d] = (given ?? MetaState())
          ..mode = m
          ..difficulty = d
          ..season = _season;
      }
    }
  }

  /// Skin for the yard and the home screen. Every wallet uses it. A season
  /// that is switched off ([Season.playable]) reads back as a playable one.
  Season get season => _season;
  set season(Season value) {
    _season = value.orPlayable;
    for (final wallet in allWallets) {
      wallet.season = _season;
    }
  }

  Season _season;

  /// Last mode the player started. Home still offers both.
  PlayMode mode;

  final Map<PlayMode, Map<Difficulty, MetaState>> _wallets = {};

  MetaState wallet(PlayMode which, Difficulty difficulty) =>
      _wallets[which]![difficulty]!;

  Iterable<MetaState> get allWallets =>
      _wallets.values.expand((row) => row.values);

  /// Copy one wallet's coins, skills, and best wave. Every other wallet
  /// stays as it was.
  void apply(WalletSnap snap) {
    season = snap.season;
    mode = snap.mode;
    wallet(snap.mode, snap.difficulty)
      ..coins = snap.coins
      ..bestWave = snap.bestWave
      ..score = snap.score
      ..resumeWave = snap.resumeWave
      ..resumeArena = snap.resumeArena
      ..replaceSkills(snap.skills);
  }

  Map<String, Object> toJson() => {
    'v': 3,
    'season': season.name,
    'mode': mode.name,
    'wallets': {
      for (final m in PlayMode.values)
        m.name: {
          for (final d in Difficulty.values) d.name: wallet(m, d).toJson(),
        },
    },
  };

  factory PlayerSave.fromJson(Map<String, dynamic> json) {
    final season = Season.tryParse(json['season'] as String?) ?? Season.winter;
    final mode = PlayMode.tryParse(json['mode'] as String?) ?? PlayMode.arcade;

    final v3 = _asMap(json['wallets']);
    if (v3 != null) {
      return PlayerSave(
        season: season,
        mode: mode,
        wallets: {
          for (final m in PlayMode.values)
            m: {
              for (final d in Difficulty.values)
                if (_asMap(_asMap(v3[m.name])?[d.name]) case final raw?)
                  d: MetaState.fromJson(raw),
            },
        },
      );
    }

    final nested = json.containsKey('arcade') || json.containsKey('campaign');
    if (!nested) {
      // v1: one flat wallet, before modes existed.
      final legacy = MetaState.fromJson(json);
      return PlayerSave(
        season: legacy.season,
        mode: PlayMode.arcade,
        wallets: {PlayMode.arcade: _splitLegacy(legacy, json)},
      );
    }

    // v2: one wallet per mode, shared by every difficulty.
    return PlayerSave(
      season: season,
      mode: mode,
      wallets: {
        for (final m in PlayMode.values)
          if (_asMap(json[m.name]) case final raw?)
            m: _splitLegacy(MetaState.fromJson(raw), raw),
      },
    );
  }

  /// A pre-split wallet keeps its coins and skills on Normal. Each
  /// difficulty's best wave (from [raw]) moves into that difficulty.
  static Map<Difficulty, MetaState> _splitLegacy(
    MetaState legacy,
    Map<String, dynamic> raw,
  ) {
    final bests = MetaState.legacyBestWaves(raw);
    return {
      for (final d in Difficulty.values)
        d: d == Difficulty.normal
            ? (legacy..bestWave = bests[d] ?? 0)
            : MetaState(bestWave: bests[d] ?? 0),
    };
  }

  static Map<String, dynamic>? _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }
}

/// Fields copied at the moment of a save so a later edit cannot race it.
class WalletSnap {
  WalletSnap({
    required this.mode,
    required this.difficulty,
    required this.season,
    required this.coins,
    required this.bestWave,
    required this.score,
    required this.skills,
    this.resumeWave = 0,
    this.resumeArena,
  });

  factory WalletSnap.from(MetaState state) {
    return WalletSnap(
      mode: state.mode,
      difficulty: state.difficulty,
      season: state.season,
      coins: state.coins,
      bestWave: state.bestWave,
      score: state.score,
      resumeWave: state.resumeWave,
      resumeArena: state.resumeArena,
      skills: Set<String>.from(state.skills),
    );
  }

  final PlayMode mode;
  final Difficulty difficulty;
  final Season season;
  final int coins;
  final int bestWave;
  final int score;
  final Set<String> skills;
  final int resumeWave;
  final String? resumeArena;
}
