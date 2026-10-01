# Backyard Barrage

Flutter + Flame **landscape** arena game: kids lob **snowballs** (winter) and **water balloons** (summer). Charge-hold → aim → lob. Publisher: **GameLogic / Ethan**.

- GitHub: https://github.com/F-Ethan/backyard_-barrage
- Agent contract: [`CLAUDE.md`](CLAUDE.md) (see also [`AGENTS.md`](AGENTS.md))
- Leftovers: [`PROGRESS.md`](PROGRESS.md)
- Plan / art: [`docs/MVP_PLAN.md`](docs/MVP_PLAN.md) · [`docs/STYLE.md`](docs/STYLE.md) · [`docs/STATUS.md`](docs/STATUS.md)
- Audio needs: [`docs/AUDIO_HANDOFF.md`](docs/AUDIO_HANDOFF.md)

Kid-safe: snowballs and water balloons only — no blood or gore. Camera is **3/4 side-arena** (not pure top-down). Player blue `#3D7CFF`, enemy violet `#9B59B6`.

## Run

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d macos    # or chrome / iOS / Android device
```

Ship targets are **landscape iOS + Android**. macOS and Chrome are for local playtest.

## Assets

Draft PNGs live under `assets/images/` (characters, world, forts, projectiles, VFX, UI). Filenames stay `*_draft.png` until approved. Props and audio folders are empty for now — see `docs/STATUS.md` and `docs/AUDIO_HANDOFF.md`. Nested folders are already listed in `pubspec.yaml`.

## Working on the repo

Never commit feature work straight to `main`. Branch from `origin/main`, open a PR. Document out-of-scope issues in `PROGRESS.md` → **Known gaps**.
