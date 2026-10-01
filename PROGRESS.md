# Backyard Barrage progress

Flutter + Flame landscape arena game (winter snowballs / summer water balloons), publisher GameLogic / Ethan. Version `0.1.0` on `main`. This file tracks leftovers so agents do not drop them.

## Shipped

Playable MVP loop on the gameplay branch:

- **Season switch.** Main menu season chips (also on the shop and the defeat screen). Winter and summer swap the backyard, kid outerwear poses, projectile (snowball vs water balloon), and impact VFX. Combat rules stay the same. Last season is saved.
- **Walk poses and rival AI.** Kids use the walk sprite while they move. Each rival picks a random living player kid, sometimes sidesteps, then charges with jittered aim and lobs with the same physics as the player. Higher waves charge faster and aim tighter. The player still has one active thrower at a time (drag sideways to move that kid, hold to aim, release to throw).
- **Crew of 1 to 3.** You start with one kid. A wave clears when every rival is KO'd (2 rivals on wave 1, then 3). The run ends when every player kid is KO'd. Hearts show remaining HP per kid (2 hits to KO).
- **Shop between waves.** Wins pay soft currency. The shop sells Extra kid (slots 2 and 3), Fort (stages 1–3), and Throw speed (5 ranks). Purchases, coins, season, and best wave persist with `shared_preferences`.
- **Player fort.** `fort_stage_{1,2,3}_draft.png` on the player side. Enemy lobs are blocked while the fort has HP; HP refills at the start of the next wave. The HUD fort bar uses `fort_bar_empty_draft` / `fort_bar_fill_draft`.

## Known gaps

Document out-of-scope bugs, doc drift, and follow-ups here. Add a row when you notice something you are not fixing in the current PR. Remove or rewrite a row when it is actually fixed.

- **Audio not shipped.** `assets/audio/music/` and `assets/audio/sfx/` are empty; see `docs/AUDIO_HANDOFF.md`. `flame_audio` is a dependency but unused.
- **Props folders are empty.** `assets/images/props/winter/` and `props/summer/` exist so the asset list analyzes, but they have no sprites yet.
- **Some UI kit art is still unused.** Shop card frames, the modal panel, and the pressed primary button are on disk. The shop and defeat screens use the cream/ink panel plus primary and secondary buttons instead.
- **No pause, settings, or haptics.** The MVP plan lists them. This slice stops at menu → fight → shop → defeat.
- **Walk and throw are single frames.** No multi-frame cycles yet (`docs/STATUS.md`).
- **No CI yet.** No `.github/workflows` — analyze/test are local (`flutter analyze`, `flutter test`).
- **Draft art only.** All PNGs are still `*_draft.png` until approved finals replace them (`docs/STATUS.md`).
- **README was art-pack oriented.** Rewritten as a game README in the agent-docs bootstrap; keep it game-focused if you touch it again.
