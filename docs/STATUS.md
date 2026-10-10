# Backyard Barrage — Art Pack Status

**Updated:** 2026-10-07  
**Pack:** MVP draft + character pose polish + **UI kit pass** + mild turn yaws

**Game wiring:** The arena loads both seasons (backgrounds, idle/walk/charge/throw/hit/KO/turn poses, snowball vs water balloon, snow vs splash) and fort stages 1–3. The charge sweep swaps five upright poses from the up-screen end of the row to the down-screen end: turn-30l, turn-15l, the charge pose, turn-15r, turn-30r. Player winter uses the 3D aim pack (`docs/TURN_YAWS.md`, `docs/HANDOFF_3D_TURNS.md`); summer and enemy stay on the 2D HQ drafts. Flutter menus, shop, pause, settings, and the screen-space HUD use **`assets/images/ui_modern/`** (see `docs/UI_MODERN.md`). The legacy wood/comic kit under `assets/images/ui/` is kept, including the locked app icon; those draft buttons, chips, and frames are no longer on the live screens.  
**Style source:** `docs/STYLE.md` (followed)  
**Generators:**
- `scripts/generate_mvp_drafts.py` — world/forts/VFX/UI basics + shared character import
- `scripts/generate_poses_polish.py` — full pose sheet (idle/walk/charge/throw/hit/KO × winter/summer × player/enemy)
- `scripts/generate_ui_kit.py` — HUD/shop UI kit (bars, chips, frames, buttons, hearts, modal)

**Alpha:** Characters, forts, projectiles, VFX, UI sprites use true transparent PNG (RGBA, corner alpha 0). World backgrounds are opaque full-bleed landscapes. Shop card frames have transparent art wells. No cream/`#FFF8F0` or green-screen fill on sprites (cream is intentional UI panel fill).

**GenerateImage:** Not used this pass — Cursor GenerateImage bridge unavailable; consistency prioritized via shared Pillow draw pipeline.

---

## UI kit (MVP) — 2026-10-01

All under `assets/images/ui/`. Shared language: ink `#2C3E50` ~4–6px outline, cream `#FFF8F0`, wood `#8B5E3C` / `#C4A484`, button lip, radii aligned (btn 28 / chip 20 / card 36 / panel 48).

| File | Size | Status | Notes |
|------|------|--------|-------|
| `wordmark_backyard_barrage_draft.png` | 1024×384 | draft (kept) | Existing wordmark |
| `app_icon_1024.png` | 1024×1024 | locked | Summer\|winter clash master, 1947595 bytes. Center crop of the portrait source. SHA-256 `86621c0890c82418a4260b93b956927495c01653ae08034704f5e377d992ff1f`. Not the launcher source. |
| `app_icon_1024_draft.png` | 1024×1024 | locked (same pixels) | Identical bytes (1947595). Draft filename kept for pipeline continuity. |
| `app_icon_1024_fill.png` | 1024×1024 | playtest | Same clash with the navy side bars cropped out. Source for iOS, Android, and macOS launcher sizes. The 1024 slots are these bytes. |
| `btn_primary_draft.png` | 512×160 | **improved draft** | Cream + ink + 3D lip; re-exported |
| `btn_primary_pressed_draft.png` | 512×160 | **new draft** | Sunk / dim cream pressed |
| `btn_secondary_draft.png` | 512×160 | **new draft** | Quieter lip + inner hairline |
| `fort_bar_empty_draft.png` | 512×64 | **new draft** | Wood/cream trough |
| `fort_bar_fill_draft.png` | 512×64 | **new draft** | Grass fill layer (scale width by HP%) |
| `chip_season_winter_draft.png` | 256×96 | **new draft** | Selected + snowflake |
| `chip_season_summer_draft.png` | 256×96 | **new draft** | Selected + sun |
| `chip_season_winter_off_draft.png` | 256×96 | **new draft** | Dim unselected |
| `chip_season_summer_off_draft.png` | 256×96 | **new draft** | Dim unselected |
| `shop_card_frame_draft.png` | 512×640 | **new draft** | Wood border, transparent art well |
| `shop_card_frame_wide_draft.png` | 768×512 | **new draft** | Wide landscape variant |
| `heart_draft.png` | 256×256 | **improved draft** | Unified geometry; re-exported |
| `heart_empty_draft.png` | 256×256 | **new draft** | Cream fill + ink outline |
| `coin_draft.png` | 256×256 | **improved draft** | Same outline weight; re-exported |
| `panel_modal_draft.png` | 1024×768 | **new draft** | Cream modal, 9-slice friendly |

**Intended-final:** `app_icon_1024.png` is the locked master and stays byte-identical. Launcher slots are resizes of `app_icon_1024_fill.png`. Other filenames in this table are still `_draft`.

---

## Character pose pack — polish pass 2026-10-01, HQ mild turn yaws 2026-10-07

2D pose drafts are 512×512 RGBA. Player faces RIGHT (blue `#3D7CFF`); enemy faces LEFT (violet `#9B59B6`). Outline `#2C3E50` ~3–4px. Winter = coat+beanie+pom; summer = tee (balloon projectile on charge/throw). Soft ground contact shadow + 1 soft body shade plane. Mild aim yaws for summer and for the enemy are the Studio HQ drafts (`docs/TURN_YAWS.md`). Player winter aim uses the 1024×1024 3D pack instead: `player_turn_{30l,15l,15r,30r}_winter_3d_v1.png` plus `player_charge_winter_3d_from_sheet.png` as the sweep center. `player_charge_winter_3d_v1.png` is the hero still and is not in the strip. Sheet: `assets/images/characters/turn_yaw_sheet_3d_winter.png`. The older player-winter 2D contact sheet `turn_yaw_sheet_hq.png` and `turn_yaw_sheet_mild.png` stay as reference.

### Player (`assets/images/characters/player/`)

| File | Status | Notes |
|------|--------|-------|
| `player_idle_winter_draft.png` | **improved draft** | Re-exported; proportions locked to shared pipeline |
| `player_idle_summer_draft.png` | **improved draft** | Tee variant; re-exported |
| `player_walk_winter_draft.png` | **new draft** | Mid-stride, opposite arm/leg |
| `player_walk_summer_draft.png` | **new draft** | Same arc, summer tee |
| `player_charge_winter_draft.png` | **HQ draft** | Kept on disk. Player-winter aim center is now `player_charge_winter_3d_from_sheet.png` |
| `player_charge_winter_3d_from_sheet.png` | **3D aim center** | 1024×1024. 0° frame in the player-winter sweep. White backdrop keyed out |
| `player_charge_winter_3d_v1.png` | **hero still** | 1024×1024 approved single. Not used in the aim sweep |
| `player_charge_summer_draft.png` | **HQ draft** | Aim-sweep center. Lean back, water balloon + glow |
| `player_throw_winter_draft.png` | **improved draft** | Follow-through forward; re-exported |
| `player_throw_summer_draft.png` | **new draft** | Follow-through + balloon |
| `player_hit_winter_draft.png` | **new draft** | Recoil, X-eye, impact stars |
| `player_hit_summer_draft.png` | **new draft** | Same arc, tee |
| `player_ko_winter_draft.png` | **new draft** | Slump + swirl + stars |
| `player_ko_summer_draft.png` | **new draft** | Slump + swirl + stars, tee |
| `player_pickup_winter_draft.png` | **playtest draft** | Selected / held-up pose (Studio) |
| `player_pickup_summer_draft.png` | **playtest draft** | Selected / held-up pose, tee |
| `player_turn_30l_winter_draft.png` | **HQ playtest draft** | Kept on disk. Player-winter sweep uses `player_turn_30l_winter_3d_v1.png` |
| `player_turn_30l_winter_3d_v1.png` | **3D aim** | 1024×1024. Up-screen end of the player-winter sweep |
| `player_turn_30l_summer_draft.png` | **HQ playtest draft** | Same yaw, tee |
| `player_turn_15l_winter_draft.png` | **HQ playtest draft** | Kept on disk. Player-winter sweep uses `player_turn_15l_winter_3d_v1.png` |
| `player_turn_15l_winter_3d_v1.png` | **3D aim** | 1024×1024. Between 30l and the sheet charge |
| `player_turn_15l_summer_draft.png` | **HQ playtest draft** | Same yaw, tee |
| `player_turn_15r_winter_draft.png` | **HQ playtest draft** | Kept on disk. Player-winter sweep uses `player_turn_15r_winter_3d_v1.png` |
| `player_turn_15r_winter_3d_v1.png` | **3D aim** | 1024×1024. Between the sheet charge and 30r |
| `player_turn_15r_summer_draft.png` | **HQ playtest draft** | Same yaw, tee |
| `player_turn_30r_winter_draft.png` | **HQ playtest draft** | Kept on disk. Player-winter sweep uses `player_turn_30r_winter_3d_v1.png` |
| `player_turn_30r_winter_3d_v1.png` | **3D aim** | 1024×1024. Down-screen end of the player-winter sweep |
| `player_turn_30r_summer_draft.png` | **HQ playtest draft** | Same yaw, tee |

### Ethan 3D kid (raw, not wired)

`assets/images/characters/player/ethan3d/` — approved aim wind-up (profile to 3/4 front) and run stills for Ethan's own 3D kid. Full frames are 1024×1024 transparent PNGs with feet at about y=941, plus 512 previews and review contact sheets. Not in `pubspec.yaml` and not loaded. Idle and throw are not included. See the folder README.

### Enemy (`assets/images/characters/enemy/`)

| File | Status | Notes |
|------|--------|-------|
| `enemy_idle_winter_draft.png` | **improved draft** | Violet coat; facing left; re-exported |
| `enemy_idle_summer_draft.png` | **new draft** | Violet tee |
| `enemy_walk_winter_draft.png` | **new draft** | Mid-stride mirror |
| `enemy_walk_summer_draft.png` | **new draft** | Mid-stride, summer |
| `enemy_charge_winter_draft.png` | **HQ draft** | Aim-sweep center. Lean back + snowball + glow. Drawn facing left |
| `enemy_charge_summer_draft.png` | **HQ draft** | Aim-sweep center. Lean back + balloon + glow |
| `enemy_throw_winter_draft.png` | **improved draft** | Follow-through; re-exported |
| `enemy_throw_summer_draft.png` | **new draft** | Follow-through + balloon |
| `enemy_hit_winter_draft.png` | **new draft** | Recoil + stars |
| `enemy_hit_summer_draft.png` | **new draft** | Recoil + stars, tee |
| `enemy_ko_winter_draft.png` | **new draft** | Slump + swirl |
| `enemy_ko_summer_draft.png` | **new draft** | Slump + swirl, tee |
| `enemy_pickup_winter_draft.png` | **playtest draft** | Held-up pose, loaded with the enemy sheet |
| `enemy_pickup_summer_draft.png` | **playtest draft** | Held-up pose, tee |
| `enemy_turn_30l_winter_draft.png` | **HQ playtest draft** | Up-screen end. Drawn facing left; not a mirror of the player sheet |
| `enemy_turn_30l_summer_draft.png` | **HQ playtest draft** | Same yaw, tee |
| `enemy_turn_15l_winter_draft.png` | **HQ playtest draft** | Milder screen-left |
| `enemy_turn_15l_summer_draft.png` | **HQ playtest draft** | Same yaw, tee |
| `enemy_turn_15r_winter_draft.png` | **HQ playtest draft** | Milder screen-right |
| `enemy_turn_15r_summer_draft.png` | **HQ playtest draft** | Same yaw, tee |
| `enemy_turn_30r_winter_draft.png` | **HQ playtest draft** | Down-screen end. Drawn facing left; not mirrored |
| `enemy_turn_30r_summer_draft.png` | **HQ playtest draft** | Same yaw, tee |

---

### Rivals (`assets/images/characters/rivals/`) — 2026-10-07

Owner renders, 512² RGBA with the feet on y≈471, facing screen-left. Wired with a square crop `(20.5, 0, 471)` and a draw scale (ghost 1.12, frost kid 1.18).

| Folder | Frames |
| --- | --- |
| `ghost/` (snow ghost, standard rival) | `aim_00`, `aim_15a`, `aim_15b`, `aim_30a`, `aim_30b`, `idle`, `windup` (v1, rescaled), `throw`, `hit`, `ko` |
| `frostkid/` (long range) | same set plus `windup` |

Both rivals charge on `windup` (snowball raised); the `aim_*` frames are a smoother sculpt and are not drawn. `ghost/ghost_windup_draft.png` is the v1 `characters/enemy/ghost/ghost_windup_512.png` rescaled ×0.961 onto the v2 feet line. `rusher/` (2026-10-09): `idle`, `windup`, `throw`, `hit`, `ko`, `walk_00`–`03`, an ice brute with an amber core. Ghost and rusher loop four `walk_*` frames; the frost kid walk is being redrawn. The ghost and frost kid `throw` frames are the v2 no-ball versions, so only the real projectile shows. `hellhound/` adds `land` and `hit` (redo v2).

### Finals (2026-10-09)

| Path | What |
| --- | --- |
| `forts/fort_stage_{1,2,3}{,_damaged}.png`, `forts/fort_collapsed.png` | Player forts, blue flag, 640² on y=611 |
| `forts/rival/rival_*` | Rival forts, violet flag (the rival fort uses stage 1) |
| `projectiles/snowball.png` | Snowball, 256² |
| `vfx/ice_bubble.png`, `vfx/frost_crust_overlay.png` | Frost armor bubble; Freeze all screen-edge frost (1280×720) |
| `props/winter/*.png` | Eight props, 512², standing on y=496 |
| `ui/powerups/pu_*.png` | Seven round power-up icons, 256² |
| `characters/player/ethan3d/kid_*_512.png` | Kid idle, throw follow-through, hit, KO, two aim-away frames, four-frame run |
| `characters/player/team_green/`, `team_red/` | Kid 2 (green girl) and Kid 3 (red boy): the same 13 frames as the blue kid, 512², same foot line (2026-10-10) |
| `props/shield/iron_shield.png` | Iron shield held while Shield hits remain, 256² (2026-10-10) |
| `projectiles/bunker_buster.png` | Fort cracker ball, 256² (2026-10-10) |
| `vfx/boss/ogre_snowball.png` | The ogre's thrown snowball, 256² (2026-10-10) |

`hellhound/` (Ice hound event, 2026-10-08): `idle`, `run_00`–`run_03`, `jump_00` (crouch), `jump_01` (air), `bite_00`, `bite_01`, the 512 versions with the same square crop. `jump_02` (same as `idle`) and `look` are not copied; the landing uses `idle`.

## Non-character MVP (world / forts / VFX)

| Path | Status |
|------|--------|
| `assets/images/world/backyard_bg_winter_draft.png` | draft |
| `assets/images/world/backyard_bg_summer_draft.png` | draft |
| `assets/images/forts/fort_stage_{1,2,3}_draft.png` | draft |
| `assets/images/forts/fort_stage_{1,2,3}_damaged_draft.png` | playtest draft |
| `assets/images/forts/fort_collapsed_draft.png` | playtest draft |
| `assets/images/projectiles/snowball_draft.png` | draft |
| `assets/images/projectiles/water_balloon_draft.png` | draft |
| `assets/images/vfx/impact_snow_draft.png` | draft |
| `assets/images/vfx/impact_splash_draft.png` | draft |
| `assets/images/vfx/charge_glow_draft.png` | draft |

---

## Still missing (gaps)

### Characters
- Multi-frame walk/throw cycles (currently single keyframe per pose)
- Alternate enemy variants / boss kid
- Hurt tint / flash overlays (engine-side OK)

### World / props
- Parallax layers; prop packs under `props/winter/` and `props/summer/`

### Forts / UI
- Mirrored right-side forts (or flip-in-engine)
- Win/lose banners; optional season chip labels localization

### VFX
- Standalone KO swirl sprite; charge intensity stages 1–3; trails

### Audio
- Procedural MVP pack is in `assets/audio/` (SFX, menu loop, winter and summer battle loops). Finals can replace those files in place. See `docs/AUDIO_HANDOFF.md`.

---

## Showcase absolute paths (UI kit)

- Fort bar composite (empty + 70% fill): layer `fort_bar_empty_draft.png` + `fort_bar_fill_draft.png`
  - `/workspace/backyard-barrage/assets/images/ui/fort_bar_empty_draft.png`
  - `/workspace/backyard-barrage/assets/images/ui/fort_bar_fill_draft.png`
- Season winter on: `/workspace/backyard-barrage/assets/images/ui/chip_season_winter_draft.png`
- Season summer on: `/workspace/backyard-barrage/assets/images/ui/chip_season_summer_draft.png`
- Shop card frame: `/workspace/backyard-barrage/assets/images/ui/shop_card_frame_draft.png`
- Primary button: `/workspace/backyard-barrage/assets/images/ui/btn_primary_draft.png`

---

## Regen

```bash
# UI kit (HUD/shop)
/workspace/.venv-art/bin/python /workspace/backyard-barrage/scripts/generate_ui_kit.py

# Full character pose sheet (24 PNGs)
/workspace/.venv-art/bin/python /workspace/backyard-barrage/scripts/generate_poses_polish.py

# Full MVP pack (world/forts/VFX/UI basics + core character sheets via shared draw_kid)
/workspace/.venv-art/bin/python /workspace/backyard-barrage/scripts/generate_mvp_drafts.py
```
