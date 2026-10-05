import 'remove_ads.dart';
import 'remove_ads_web.dart' if (dart.library.io) 'remove_ads_io.dart';

RemoveAdsCatalog createRemoveAdsCatalog() => createPlatformRemoveAdsCatalog();
