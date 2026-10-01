# Backyard Barrage — Art Pack Status

**Updated:** 2026-10-01  
**Pack:** MVP draft + character pose polish + **UI kit pass**

**Game wiring:** The arena now loads both seasons (backgrounds, idle/walk/charge/throw/hit/KO poses, snowball vs water balloon, snow vs splash), fort stages 1–3, and the HUD pieces for hearts, the fort bar, coins, season chips, and buttons. Shop card frames, the modal panel, and the pressed primary button are still unused. Audio and prop sprites are still absent.  
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
| `app_icon_1024_draft.png` | 1024×1024 | draft (kept) | Existing app icon |
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

**Intended-final:** none yet — all filenames still `_draft`.

---

## Character pose pack (24/24) — polish pass 2026-10-01

All 512×512 RGBA. Player faces RIGHT (blue `#3D7CFF`); enemy faces LEFT (violet `#9B59B6`). Outline `#2C3E50` ~3–4px. Winter = coat+beanie+pom; summer = tee (balloon projectile on charge/throw). Soft ground contact shadow + 1 soft body shade plane.

### Player (`assets/images/characters/player/`)

| File | Status | Notes |
|------|--------|-------|
| `player_idle_winter_draft.png` | **improved draft** | Re-exported; proportions locked to shared pipeline |
| `player_idle_summer_draft.png` | **improved draft** | Tee variant; re-exported |
| `player_walk_winter_draft.png` | **new draft** | Mid-stride, opposite arm/leg |
| `player_walk_summer_draft.png` | **new draft** | Same arc, summer tee |
| `player_charge_winter_draft.png` | **new draft** | Lean back, snowball + yellow charge glow |
| `player_charge_summer_draft.png` | **new draft** | Lean back, water balloon + glow |
| `player_throw_winter_draft.png` | **improved draft** | Follow-through forward; re-exported |
| `player_throw_summer_draft.png` | **new draft** | Follow-through + balloon |
| `player_hit_winter_draft.png` | **new draft** | Recoil, X-eye, impact stars |
| `player_hit_summer_draft.png` | **new draft** | Same arc, tee |
| `player_ko_winter_draft.png` | **new draft** | Slump + swirl + stars |
| `player_ko_summer_draft.png` | **new draft** | Slump + swirl + stars, tee |

### Enemy (`assets/images/characters/enemy/`)

| File | Status | Notes |
|------|--------|-------|
| `enemy_idle_winter_draft.png` | **improved draft** | Violet coat; facing left; re-exported |
| `enemy_idle_summer_draft.png` | **new draft** | Violet tee |
| `enemy_walk_winter_draft.png` | **new draft** | Mid-stride mirror |
| `enemy_walk_summer_draft.png` | **new draft** | Mid-stride, summer |
| `enemy_charge_winter_draft.png` | **new draft** | Lean back + snowball + glow |
| `enemy_charge_summer_draft.png` | **new draft** | Lean back + balloon + glow |
| `enemy_throw_winter_draft.png` | **improved draft** | Follow-through; re-exported |
| `enemy_throw_summer_draft.png` | **new draft** | Follow-through + balloon |
| `enemy_hit_winter_draft.png` | **new draft** | Recoil + stars |
| `enemy_hit_summer_draft.png` | **new draft** | Recoil + stars, tee |
| `enemy_ko_winter_draft.png` | **new draft** | Slump + swirl |
| `enemy_ko_summer_draft.png` | **new draft** | Slump + swirl, tee |

---

## Non-character MVP (world / forts / VFX)

| Path | Status |
|------|--------|
| `assets/images/world/backyard_bg_winter_draft.png` | draft |
| `assets/images/world/backyard_bg_summer_draft.png` | draft |
| `assets/images/forts/fort_stage_{1,2,3}_draft.png` | draft |
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
