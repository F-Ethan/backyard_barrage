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
