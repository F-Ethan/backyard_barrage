import 'package:backyard_barrage/app.dart';
import 'package:backyard_barrage/meta/save_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('main menu offers play and season chips', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SaveStore(preferences: prefs);

    await tester.pumpWidget(BackyardBarrageApp(saveStore: store));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Playing: Winter'), findsOneWidget);
    expect(find.byKey(const Key('season-summer')), findsOneWidget);

    await tester.tap(find.byKey(const Key('season-summer')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Playing: Summer'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(BackyardBarrageApp(saveStore: store));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Playing: Summer'), findsOneWidget);
  });
}
