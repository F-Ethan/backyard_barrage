# Backyard Barrage

Seasonal backyard arena game — snowballs in winter, water balloons in summer.

Built with **Flutter** + **Flame** for iOS and Android (landscape-only).

## Requirements

- Flutter 3.38+ (Dart 3.10+)
- Xcode (iOS) / Android SDK

## Run

```bash
cd backyard_barrage
flutter pub get
flutter run
```

Prefer a landscape device or simulator. Orientation is locked to landscape on Android, iOS, and via `SystemChrome`.

## Project layout

```
lib/
  main.dart          # entry + landscape lock
  app.dart           # MaterialApp + GameWidget
  game/              # FlameGame + combat (placeholder)
  meta/              # upgrades / progression (scaffold)
  seasons/           # winter / summer skins (scaffold)
  ui/                # menus / HUD (scaffold)
assets/
  images/
  audio/
docs/
  MVP_PLAN.md
```

## Docs

See [docs/MVP_PLAN.md](docs/MVP_PLAN.md) for the full MVP plan (platforms, seasons, combat loop, progression).

## Org / bundle

- Org: `dev.gamelogic`
- Application / bundle id: `dev.gamelogic.backyardbarrage`
