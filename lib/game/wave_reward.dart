import '../meta/power_up.dart';

/// One thing a wave paid, for the wave report's reward pills.
class WaveReward {
  const WaveReward.coins(this.amount, this.source) : item = null;
  const WaveReward.item(PowerUp this.item, this.source, {this.amount = 1});

  /// Coins earned, or how many of [item].
  final int amount;

  /// The power-up given, or null for coins.
  final PowerUp? item;

  /// Where it came from: "Knockouts", "Wave 7 clear", "Hound scared off",
  /// "Magmo beaten", "Dropped by a rival".
  final String source;

  bool get isCoins => item == null;

  /// "+1 Freeze all" or "+45".
  String get label => isCoins ? '+$amount' : '+$amount ${item!.label}';

  @override
  String toString() => '$source: $label';
}
