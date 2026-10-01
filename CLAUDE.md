# Backyard Barrage — Agent working rules

Backyard Barrage is a Flutter + Flame **landscape** arena game: kids lob snowballs in winter and water balloons in summer. Core loop is charge-hold → aim → lob. Later meta includes kid count (1→3), fort upgrades, and throw speed. Publisher is GameLogic / Ethan.

This file is the committed agent contract. `.claude/` is gitignored local memory — do not commit it.

## Source of truth

Always read these before diverging from plan or art:

- [`docs/MVP_PLAN.md`](docs/MVP_PLAN.md) — gameplay / MVP scope
- [`docs/STYLE.md`](docs/STYLE.md) — visual language (colors, camera, kid-safe)
- [`docs/STATUS.md`](docs/STATUS.md) — art pack inventory and draft status
- [`docs/AUDIO_HANDOFF.md`](docs/AUDIO_HANDOFF.md) — audio needs (not shipped yet)
- [`PROGRESS.md`](PROGRESS.md) → **Known gaps** — leftovers and out-of-scope issues

If a task conflicts with these docs, stop and flag it rather than silently diverging.

## Process

These rules are non-negotiable.

- **Never work or push commits directly to `main` for new features** (the bootstrap agent-docs push is the exception). Do not force-push `main`.
- **Every new feature or fix is a branch + PR.** Branch from the latest `origin/main`. Open a pull request targeting `main`. Do not land work by committing straight to `main`.
- **Document out-of-scope issues explicitly.** If you find a bug, missing asset, or follow-up that is not part of the current change, add it to `PROGRESS.md` → **Known gaps**. Do not silently skip it, and do not expand the PR to “while we’re here” unless the user asked.
- **Kid-safe only.** Projectiles are snowballs and water balloons. No blood, gore, or weaponized violence.
- **Camera:** keep the **3/4 side-arena** view (NOT pure top-down). Match the draft art style in `docs/STYLE.md` (player blue `#3D7CFF`, enemy violet `#9B59B6`).
- **Landscape only** on iOS + Android (ship targets). macOS / Chrome are fine for local playtest.

## Stack

| Concern | What this repo uses |
|---|---|
| App | Flutter / Dart (`sdk: ^3.10.7`), Material |
| Game | `flame` |
| Audio | `flame_audio` (dependency present; assets not shipped yet) |
| Lint | `flutter_lints` via `analysis_options.yaml` |

Platform folders: `ios/`, `android/` (ship), plus `macos/`, `web/` for local playtest. Do not add a second game engine next to Flame.

## Layout

```
lib/
├── main.dart                      # entry
├── app.dart                       # MaterialApp / GameWidget host
├── game/
│   ├── backyard_barrage_game.dart # FlameGame root
│   ├── throw_physics.dart         # charge / lob math
│   └── components/                # kids, projectiles, HUD, VFX overlays
├── meta/                          # upgrades / shop (placeholder)
├── seasons/                       # winter ↔ summer (placeholder)
└── ui/                            # Flutter overlays / menus (placeholder)
assets/
├── images/                        # nested folders; filenames *_draft.png
│   ├── characters/player|enemy/
│   ├── world/  forts/  projectiles/  vfx/  ui/
│   └── props/winter|summer/       # empty for now
└── audio/music|sfx/               # empty — see AUDIO_HANDOFF
docs/                              # MVP_PLAN, STYLE, STATUS, AUDIO_HANDOFF
test/                              # flutter_test
scripts/                           # Pillow draft generators (art pack)
```

## Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d macos          # or chrome / a connected device
```

## Art

- Assets live under `assets/images/`. `pubspec.yaml` already lists nested folders — do not invent new top-level asset roots without updating pubspec.
- Do **not** invent sprites. Use existing `*_draft.png` files, or note the gap in `PROGRESS.md` / `docs/STATUS.md`.
- When finals replace drafts, drop `_draft` from the filename and update load paths once.

## Done when

- The change is on a feature branch with a PR to `main`.
- `flutter analyze` / `flutter test` are green for touched logic.
- Anything you did not fix is listed in `PROGRESS.md` → **Known gaps**.
