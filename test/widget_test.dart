import 'package:backyard_barrage/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app builds GameScreen smoke', (tester) async {
    // Landscape lock / immersive chrome need binding; pump app only.
    await tester.pumpWidget(const BackyardBarrageApp());
    expect(find.byType(GameScreen), findsOneWidget);
  });
}
