# Backyard Barrage — MVP Art Pack

Original cozy backyard snowball / water-balloon game art for Ethan’s Flutter + Flame title.  
**Not** SnowCraft / classic red-vs-green soldier aesthetic — player is blue (`#3D7CFF`), enemy is violet (`#9B59B6`).

Style bible: [`docs/STYLE.md`](docs/STYLE.md)  
Pack status: [`docs/STATUS.md`](docs/STATUS.md)  
Audio handoff: [`docs/AUDIO_HANDOFF.md`](docs/AUDIO_HANDOFF.md)

## Layout

```
backyard-barrage/
  assets/images/
    characters/player/   # idle / throw (winter + summer idle)
    characters/enemy/    # idle / throw winter
    world/               # 16:9 backyard BGs
    forts/               # stages 1–3
    projectiles/         # snowball, water balloon
    vfx/                 # impact + charge glow
    ui/                  # wordmark, button, heart, coin, app icon
  assets/audio/          # empty — see AUDIO_HANDOFF
  docs/
  scripts/generate_mvp_drafts.py
```

All shipped PNGs are labeled `*_draft.png` until approved.

## Drop into Flutter

1. Copy (or symlink) this pack’s `assets/images/` into your Flutter project, e.g.:

   ```bash
   # from your Flutter app root
   mkdir -p assets/images
   cp -R /workspace/backyard-barrage/assets/images/* assets/images/
   ```

2. Declare folders (or globs) in `pubspec.yaml`:

   ```yaml
   flutter:
     assets:
       - assets/images/characters/player/
       - assets/images/characters/enemy/
       - assets/images/world/
       - assets/images/forts/
       - assets/images/projectiles/
       - assets/images/vfx/
       - assets/images/ui/
   ```

3. Load in Flame / Flutter, examples:

   ```dart
   // Flame
   final player = await images.load('characters/player/player_idle_winter_draft.png');
   final bg = await images.load('world/backyard_bg_winter_draft.png');

   // Or with flutter AssetImage / Image.asset
   Image.asset('assets/images/ui/app_icon_1024_draft.png');
   ```

4. Prefer sprites with transparent backgrounds (characters, forts, projectiles, VFX, UI). World BGs are opaque full-frame — draw them as the bottom layer.

5. When finals replace drafts, rename without `_draft` and update load paths once.

## Kid-safe

No blood; projectiles are snowballs and water balloons only.
