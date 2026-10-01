# Backyard Barrage progress

Flutter + Flame landscape arena game (winter snowballs / summer water balloons), publisher GameLogic / Ethan. Version `0.1.0` on `main`. This file tracks leftovers so agents do not drop them.

## Known gaps

Document out-of-scope bugs, doc drift, and follow-ups here. Add a row when you notice something you are not fixing in the current PR. Remove or rewrite a row when it is actually fixed.

- **Summer season not wired in-game.** Winter throw loop is playable (charge → aim → lob, 2-hit KO stub). Summer character / projectile / BG assets exist on disk but season switch is not hooked up in the game yet.
- **Walk poses unused.** Player/enemy walk drafts are in `assets/images/characters/` but movement does not use them yet.
- **Upgrades / meta not implemented.** Multi-kid (1→3), fort upgrades, throw-speed upgrades, and shop UI are planned in `docs/MVP_PLAN.md` but not built. `lib/meta/` and `lib/ui/` are placeholders (`.gitkeep`).
- **Enemy AI is a stub.** Opponent exists for the KO loop; smarter aim / dodge / multi-enemy behavior is still open.
- **UI kit on disk, unused.** Season chips, fort HP bars, shop frames, modal panel, pressed/secondary buttons live under `assets/images/ui/` — HUD currently uses hearts only.
- **Audio not shipped.** `assets/audio/music/` and `assets/audio/sfx/` are empty; see `docs/AUDIO_HANDOFF.md`. `flame_audio` is a dependency but unused.
- **Props folders empty.** `assets/images/props/winter/` and `props/summer/` have no sprites yet.
- **README was art-pack oriented.** Rewritten as a game README in the agent-docs bootstrap; keep it game-focused if you touch it again.
- **No CI yet.** No `.github/workflows` — analyze/test are local (`flutter analyze`, `flutter test`).
- **Draft art only.** All PNGs are still `*_draft.png` until approved finals replace them (`docs/STATUS.md`).
