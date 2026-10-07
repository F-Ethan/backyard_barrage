import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Winter maps. A run picks one at random and keeps it for every wave.
///
/// Each map has the yard's snow on the lower half and a river down the
/// middle, inside the neutral band between the two crews.
enum Arena {
  backyard,
  park;

  String get label => switch (this) {
    Arena.backyard => 'Backyard',
    Arena.park => 'Park',
  };

  /// Path under `assets/images/`. A 16:9 centre crop of the source art.
  String get background => 'world/arena_${name}_draft.png';

  /// Letterbox colour beside the 1280×720 yard on wide screens: the sky.
  Color get sky => switch (this) {
    Arena.backyard => const Color(0xFF71B5EC),
    Arena.park => const Color(0xFF283460),
  };

  /// Any arena, or one other than [except] when there is a choice, so a
  /// retry tends to change the scenery.
  static Arena pick(math.Random rng, {Arena? except}) {
    final pool = [
      for (final arena in Arena.values)
        if (arena != except) arena,
    ];
    final from = pool.isEmpty ? Arena.values : pool;
    return from[rng.nextInt(from.length)];
  }
}
