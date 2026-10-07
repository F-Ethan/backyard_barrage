import 'dart:async';

import 'package:backyard_barrage/ui/barrage_theme.dart';

/// Runs before every test file in `test/`.
///
/// UI motion is disabled by default so screens render their settled state on
/// the first frame and `flutter_animate` leaves no start timers pending when
/// a test ends. `test/motion_test.dart` turns it back on to cover the
/// animated paths and pumps through them.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  BarrageMotion.debugDisable = true;
  await testMain();
}
