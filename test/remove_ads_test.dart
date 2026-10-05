import 'package:backyard_barrage/ads/remove_ads.dart';
import 'package:backyard_barrage/app.dart';
import 'package:backyard_barrage/meta/save_store.dart';
import 'package:backyard_barrage/meta/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a purchase is remembered on the next launch', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final catalog = _FakeCatalog(price: r'$0.99');
    final controller = RemoveAdsController(
      catalog: catalog,
      preferences: prefs,
    );

    await controller.prepare();
    expect(controller.owned, isFalse);
    expect(controller.priceLabel, r'$0.99');

    await controller.buy();
    expect(controller.owned, isTrue);
    expect(catalog.buys, 1);
    expect(prefs.getBool(RemoveAdsController.storageKey), isTrue);

    final again = RemoveAdsController(
      catalog: _FakeCatalog(price: r'$0.99'),
      preferences: prefs,
    );
    await again.prepare();
    expect(again.owned, isTrue);
  });

  test('a missing product does not throw and does not grant ads-off', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final catalog = _FakeCatalog(price: null);
    final controller = RemoveAdsController(
      catalog: catalog,
      preferences: prefs,
    );

    await controller.prepare();
    await controller.buy();

    expect(controller.owned, isFalse);
    expect(catalog.buys, 0);
    expect(controller.note, RemoveAdsCopy.unavailable);
  });

  test('restore grants the entitlement and a miss does not clear it', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final granting = _FakeCatalog(
      price: r'$1.99',
      restoreResult: RemoveAdsRestore.granted,
    );
    final controller = RemoveAdsController(
      catalog: granting,
      preferences: prefs,
    );

    await controller.prepare();
    expect(controller.owned, isTrue);
    expect(prefs.getBool(RemoveAdsController.storageKey), isTrue);

    final offline = RemoveAdsController(
      catalog: _FakeCatalog(
        price: r'$1.99',
        restoreResult: RemoveAdsRestore.failed,
      ),
      preferences: prefs,
    );
    await offline.prepare();
    expect(offline.owned, isTrue);
    expect(offline.note, isNull);

    await offline.restore();
    expect(offline.owned, isTrue);
  });

  test('an empty restore tells the player when nothing was found', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = RemoveAdsController(
      catalog: _FakeCatalog(
        price: r'$0.99',
        restoreResult: RemoveAdsRestore.empty,
      ),
      preferences: prefs,
    );

    await controller.prepare();
    expect(controller.owned, isFalse);
    expect(controller.note, isNull);

    await controller.restore();
    expect(controller.owned, isFalse);
    expect(controller.note, RemoveAdsCopy.restoreEmpty);
  });

  testWidgets('settings shows the store price, then ads removed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final catalog = _FakeCatalog(price: r'$1.99');
    final removeAds = RemoveAdsController(catalog: catalog, preferences: prefs);
    await removeAds.prepare();

    await tester.pumpWidget(
      BackyardBarrageApp(
        saveStore: SaveStore(preferences: prefs),
        settingsStore: SettingsStore(preferences: prefs),
        removeAds: removeAds,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(const Key('menu-settings')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('remove-ads')));
    expect(find.text(r'Remove Ads · $1.99'), findsOneWidget);
    expect(find.byKey(const Key('restore-purchases')), findsOneWidget);

    await tester.tap(find.byKey(const Key('remove-ads')));
    await tester.pump();
    expect(find.text('Ads removed'), findsOneWidget);
    expect(removeAds.owned, isTrue);
  });

  testWidgets('settings stays calm when the product is missing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final removeAds = RemoveAdsController(
      catalog: _FakeCatalog(
        price: null,
        restoreResult: RemoveAdsRestore.failed,
      ),
      preferences: prefs,
    );
    await removeAds.prepare();

    await tester.pumpWidget(
      BackyardBarrageApp(
        saveStore: SaveStore(preferences: prefs),
        settingsStore: SettingsStore(preferences: prefs),
        removeAds: removeAds,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('menu-settings')));
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('remove-ads-note')));
    expect(find.text(RemoveAdsCopy.unavailable), findsOneWidget);
    expect(find.text('Remove Ads'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('restore-purchases')));
    await tester.tap(find.byKey(const Key('restore-purchases')));
    await tester.pump();
    expect(find.text(RemoveAdsCopy.restoreFailed), findsOneWidget);
    expect(removeAds.owned, isFalse);
  });
}

class _FakeCatalog implements RemoveAdsCatalog {
  _FakeCatalog({
    required this.price,
    this.restoreResult = RemoveAdsRestore.empty,
  });

  final String? price;
  final RemoveAdsRestore restoreResult;
  int buys = 0;

  @override
  void Function()? onOwned;

  @override
  void Function(String message)? onStatus;

  @override
  void start() {}

  @override
  Future<String?> loadPrice() async => price;

  @override
  Future<bool> buy() async {
    buys++;
    if (price == null) return false;
    onOwned?.call();
    return true;
  }

  @override
  Future<RemoveAdsRestore> restore() async {
    if (restoreResult == RemoveAdsRestore.granted) {
      onOwned?.call();
    }
    return restoreResult;
  }
}
