# Backyard Barrage progress

Flutter + Flame landscape arena game (winter snowballs / summer water balloons), publisher GameLogic / Ethan. Version `0.1.0` on `main`. This file tracks leftovers so agents do not drop them.

## Shipped

Playable MVP loop on the gameplay branch:

- **Season switch.** Main menu season chips (also on the shop and the defeat screen). Winter and summer swap the backyard, kid outerwear poses, projectile (snowball vs water balloon), and impact VFX. Combat rules stay the same. Last season is saved.
- **Walk poses and rival AI.** Kids use the walk sprite while they move. Each rival prefers a living player kid in their row lane, telegraphs a short windup, then lobs with the same lane physics as the player. On Normal they throw about every 1.5–3 seconds and take one grid step every three throws. Easy stretches the gap and steps less. Hard throws about every 1–1.5 seconds and steps every two throws. Higher waves shorten the gap a little and tighten where the lob lands. One player kid is the active thrower.
- **Crew of 1 to 3.** You start with one kid. A wave clears when every rival is KO'd (2 rivals on wave 1, then 3). The run ends when every player kid is KO'd. Hearts show remaining HP per kid (2 hits to KO). The active kid has a blue ground ring.
- **Shop between waves.** Wins pay soft currency. The shop sells Extra kid (slots 2 and 3), Fort (stages 1–3), and Throw speed (5 ranks). Purchases, coins, season, and best wave persist with `shared_preferences`.
- **Forts.** Each side has a fort on the two cover cells (columns 1 and 2, cover row). Intact `fort_stage_{1,2,3}_draft.png` hides kids standing on those cells. A lob that meets the footprint is blocked unless it is at the top of its arc, in which case it sails over. Enemy lobs chip the player fort; player lobs chip the enemy fort (stage 1, refills each wave). On Normal and Easy a player's own lob never chips their fort. Hard turns that friendly chip on. The first hit swaps in `fort_stage_{n}_damaged_draft.png`. At 0 HP the fort shows `fort_collapsed_draft.png` and stops providing cover until the next wave refills it.
- **Controls.** Each half of the yard is a 4×8 grid (more rows than columns) with a neutral band in the middle. Left thumb is a virtual stick: it steps the selected kid one cell at a time (about one column every 120ms, hard-capped; a little freer on Easy, a little slower on Hard) and aims while the right thumb is charging. A yard tap only moves that kid when the touch starts on or near them. Aim is clamped to about ±45° from horizontal and picks the row the lob commits to; hits still use a ±1 row band around that row. Right thumb is a virtual stick: hold to charge, release to throw. Player lobs keep a slow pace (about 920 px/s before throw rank) and full power from the back line reaches the far edge of the 1280-wide yard. Enemy lobs stay on the faster ballistic lane. Charge is still a half-bell: a tap is about 1/3, about 1 second is half, and a full hold is about 3 seconds. Modern UI shows a charge glow that grows across the screen. Classic UI keeps a wood-style power bar. The selected kid uses the Studio pickup pose. KO'd kids use the KO pose, grey out, drop, and get an X, and they cannot be selected or charged.
- **Pause.** Arena Pause button freezes the fight, including the short KO / wave-clear banner timer. Resume continues. Pause also opens Settings or returns to the menu.
- **Settings.** SFX, music, haptics, Modern UI, and Difficulty (Easy / Normal / Hard). Stored in `backyard_barrage_settings_v1`, beside the meta save key. Menu and pause both open it. Normal is the default.
- **Haptics.** Charge release, hit, KO, and a successful purchase. Flutter `HapticFeedback`, no-op when the toggle is off or the platform has no vibrator.
- **UI kit v2.** Menus, shop, pause, settings, and the fight HUD use `assets/images/ui_modern/` by default (pill buttons, soft sheet, season chips, glass HUD, image toggles). Hearts, coins, the fort meter, the wave label, Pause, and the two thumb sticks are Flutter overlays so they stay screen-sized on the letterboxed yard. Settings → Modern UI (stored with the other toggles in `backyard_barrage_settings_v1`) flips those screens to the classic wood kit in `assets/images/ui/` without leaving the match. Classic fight HUD keeps a literal power bar; modern replaces it with the charge glow.
- **Audio.** Studio procedural pack is wired through `flame_audio` (not stubbed): throw whoosh, seasonal impact (snow / wet), hit, KO, win / lose stingers, UI tap, purchase coin, menu loop, `battle_loop_winter.wav` in winter, and `battle_loop_summer.wav` in summer. Toggles gate playback. Music beds were refreshed in place (menu ~7.83s, winter battle ~6.92s, summer battle ~6.67s). Filenames and playback paths are unchanged. All 12 files are present (9 sfx, 3 music).
- **App icon E2b.** Studio master (908081 bytes, identical pixels) at `assets/images/ui/app_icon_1024.png` and `app_icon_1024_draft.png`. Half snowball | half water balloon on a winter/summer split. iOS AppIcon, Android `ic_launcher` mipmaps, and macOS AppIcon are resized from that file. The 1024 platform slots are the same bytes.

## Known gaps

Document out-of-scope bugs, doc drift, and follow-ups here. Add a row when you notice something you are not fixing in the current PR. Remove or rewrite a row when it is actually fixed.

- **Enemy fort has no HUD meter.** The enemy fort uses the stage-1 art and shows damage on the sprite. Hearts, coins, and the player fort bar are the screen-space meters.
- **KO and wave-clear banners still scale with the yard.** The short center banner is drawn in the 1280×720 world, so it shrinks with the letterbox. Hearts, coins, fort, wave, hint, Pause, and the thumb sticks are screen-space.
- **No committed-row highlight on the yard.** Aim shows as the arrow by the kid. The enemy row you will hit is not marked on the grid.
- **Thumb sticks are fixed in the bottom corners.** They do not appear under the finger the way a floating CoD stick does. On a very short landscape phone they sit close to the top HUD chips.
- **Classic power bar is drawn, not a wood PNG.** The wood kit has no power-bar sprite, so the classic meter is an ink/cream/charge-yellow bar.
- **Player and enemy lobs do not share a flight model.** Player shots are scripted (pace `ThrowPhysics.playerTravelSpeed`, range from charge, row from aim). Enemy shots are still the #10 ballistic lane. Tuning those constants is a feel pass, not a second control scheme.
- **App icon still lives under the classic UI folder.** `assets/images/ui/app_icon_1024.png` is the launcher icon. Game screens use that folder only when Settings → Modern UI is off.
- **Props folders are empty.** `assets/images/props/winter/` and `props/summer/` exist so the asset list analyzes, but they have no sprites yet.
- **App icon is unused inside the game UI.** E2b is the store/launcher icon only. `web/favicon.png` and `web/icons/` are still the Flutter defaults.
- **Walk and throw are single frames.** No multi-frame cycles yet (`docs/STATUS.md`).
- **No CI yet.** No `.github/workflows` — analyze/test are local (`flutter analyze`, `flutter test`).
- **Classic kit has no icon, toggle, or HUD-chip sprites.** Pause, settings, close, and the on/off switches are drawn in the classic ink/cream style when Modern UI is off. Buttons, panels, chips, hearts, coins, the wordmark, shop cards, and the fort meter use the classic PNGs.
- **Draft art otherwise.** Other PNGs are still `*_draft.png` until approved finals replace them (`docs/STATUS.md`). The app icon final name is the exception above.
- **README was art-pack oriented.** Rewritten as a game README in the agent-docs bootstrap; keep it game-focused if you touch it again.
