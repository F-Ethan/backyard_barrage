# Backyard Barrage progress

Flutter + Flame landscape arena game (winter snowballs / summer water balloons), publisher GameLogic / Ethan. Version `0.1.0` on `main`. This file tracks leftovers so agents do not drop them.

## Shipped

Playable MVP loop on the gameplay branch:

- **Season switch.** Main menu season chips (also on the shop and the defeat screen). Winter and summer swap the backyard, kid outerwear poses, projectile (snowball vs water balloon), and impact VFX. Combat rules stay the same. Last season is saved.
- **Walk poses and rival AI.** Kids use the walk sprite while they move. Each rival picks a random living player kid, sometimes sidesteps, then charges with jittered aim and lobs with the same physics as the player. Higher waves charge faster and aim tighter. The player still has one active thrower at a time (drag sideways to move that kid, hold to aim, release to throw).
- **Crew of 1 to 3.** You start with one kid. A wave clears when every rival is KO'd (2 rivals on wave 1, then 3). The run ends when every player kid is KO'd. Hearts show remaining HP per kid (2 hits to KO). The active kid has a blue ground ring.
- **Shop between waves.** Wins pay soft currency. The shop sells Extra kid (slots 2 and 3), Fort (stages 1–3), and Throw speed (5 ranks). Purchases, coins, season, and best wave persist with `shared_preferences`.
- **Player fort.** `fort_stage_{1,2,3}_draft.png` on the player side. Enemy lobs are blocked while the fort has HP; HP refills at the start of the next wave. The HUD fort bar uses `fort_bar_empty_draft` / `fort_bar_fill_draft`.
- **Pause.** Arena Pause button freezes the fight, including the short KO / wave-clear banner timer. Resume continues. Pause also opens Settings or returns to the menu.
- **Settings.** SFX, music, and haptics toggles plus a GameLogic / Ethan credits stub. Stored in `backyard_barrage_settings_v1`, beside the meta save key. Menu and pause both open it.
- **Haptics.** Charge release, hit, KO, and a successful purchase. Flutter `HapticFeedback`, no-op when the toggle is off or the platform has no vibrator.
- **UI kit.** Wordmark on the title. Coin icon in the HUD, shop, and defeat. Primary, pressed, and secondary buttons. Shop portrait frames on the upgrade cards and the wide frame on the wave-clear header. `panel_modal` behind shop, pause, settings, and defeat.
- **Audio.** Studio procedural pack is wired through `flame_audio` (not stubbed): throw whoosh, seasonal impact (snow / wet), hit, KO, win / lose stingers, UI tap, purchase coin, menu loop, and the winter battle loop. Toggles gate playback. **Summer arena reuses `battle_loop_winter.wav`** until a summer bed exists.

## Known gaps

Document out-of-scope bugs, doc drift, and follow-ups here. Add a row when you notice something you are not fixing in the current PR. Remove or rewrite a row when it is actually fixed.

- **No summer battle bed.** `battle_loop_summer` was not in the Studio pack. Summer fights play `battle_loop_winter.wav` instead of silence.
- **Props folders are empty.** `assets/images/props/winter/` and `props/summer/` exist so the asset list analyzes, but they have no sprites yet.
- **App icon is unused in UI.** `app_icon_1024_draft.png` is still only a store/icon asset.
- **Walk and throw are single frames.** No multi-frame cycles yet (`docs/STATUS.md`).
- **No CI yet.** No `.github/workflows` — analyze/test are local (`flutter analyze`, `flutter test`).
- **Draft art only.** All PNGs are still `*_draft.png` until approved finals replace them (`docs/STATUS.md`).
- **README was art-pack oriented.** Rewritten as a game README in the agent-docs bootstrap; keep it game-focused if you touch it again.
