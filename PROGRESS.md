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
- **UI kit v2.** Menus, shop, pause, settings, and the fight HUD use `assets/images/ui_modern/` (pill buttons, soft sheet, season chips, glass HUD, image toggles). Hearts, coins, the fort meter, the wave label, and Pause are Flutter overlays so they stay screen-sized on the letterboxed yard. The legacy wood kit in `assets/images/ui/` is unchanged on disk.
- **Audio.** Studio procedural pack is wired through `flame_audio` (not stubbed): throw whoosh, seasonal impact (snow / wet), hit, KO, win / lose stingers, UI tap, purchase coin, menu loop, `battle_loop_winter.wav` in winter, and `battle_loop_summer.wav` in summer. Toggles gate playback. Music beds were refreshed in place (menu ~7.83s, winter battle ~6.92s, summer battle ~6.67s). Filenames and playback paths are unchanged. All 12 files are present (9 sfx, 3 music).
- **App icon E2b.** Studio master (908081 bytes, identical pixels) at `assets/images/ui/app_icon_1024.png` and `app_icon_1024_draft.png`. Half snowball | half water balloon on a winter/summer split. iOS AppIcon, Android `ic_launcher` mipmaps, and macOS AppIcon are resized from that file. The 1024 platform slots are the same bytes.

## Known gaps

Document out-of-scope bugs, doc drift, and follow-ups here. Add a row when you notice something you are not fixing in the current PR. Remove or rewrite a row when it is actually fixed.

- **KO and wave-clear banners still scale with the yard.** The short center banner is drawn in the 1280×720 world, so it shrinks with the letterbox. Hearts, coins, fort, wave, hint, and Pause are screen-space.
- **Legacy UI kit is unused by screens.** `assets/images/ui/` draft buttons, wood panels, season chips, and the wood fort bar stay in the pack. Live UI is `assets/images/ui_modern/`. The app icon still lives under `assets/images/ui/`.
- **Props folders are empty.** `assets/images/props/winter/` and `props/summer/` exist so the asset list analyzes, but they have no sprites yet.
- **App icon is unused inside the game UI.** E2b is the store/launcher icon only. `web/favicon.png` and `web/icons/` are still the Flutter defaults.
- **Walk and throw are single frames.** No multi-frame cycles yet (`docs/STATUS.md`).
- **No CI yet.** No `.github/workflows` — analyze/test are local (`flutter analyze`, `flutter test`).
- **Draft art otherwise.** Other PNGs are still `*_draft.png` until approved finals replace them (`docs/STATUS.md`). The app icon final name is the exception above.
- **README was art-pack oriented.** Rewritten as a game README in the agent-docs bootstrap; keep it game-focused if you touch it again.
