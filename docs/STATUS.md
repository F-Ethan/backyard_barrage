# Backyard Barrage — Art Pack Status

**Updated:** 2026-10-01 (CT)  
**Pack:** MVP draft visual assets  
**Style source:** `docs/STYLE.md` (followed; not contradicted)  
**Generator note:** Cursor `GenerateImage` / `CallDynamicTool` was **not available** in this executor toolset (MCP server `cursor` unreachable; no dynamic GenerateImage bridge). Assets were produced as **original procedural drafts** via Pillow (`scripts/generate_mvp_drafts.py`) using the STYLE.md palette exactly. Treat as draft until Ethan/CEO approve; a later pass can re-author with GenerateImage or a human illustrator using these as composition guides.

**Alpha:** Characters, forts, projectiles, VFX, UI sprites use true transparent PNG (RGBA, corner alpha 0). World backgrounds are opaque full-bleed landscapes (correct for BG layers). No cream/`#FFF8F0` or green-screen fill required for sprites.

---

## Delivered MVP draft set (20/20)

| # | Path | Status | Notes |
|---|------|--------|-------|
| 1 | `assets/images/characters/player/player_idle_winter_draft.png` | **draft** | 512×512, blue coat `#3D7CFF`, sandy hair, 3/4 facing right |
| 2 | `assets/images/characters/player/player_throw_winter_draft.png` | **draft** | Same kid mid-throw snowball, facing right |
| 3 | `assets/images/characters/player/player_idle_summer_draft.png` | **draft** | Blue tee summer variant |
| 4 | `assets/images/characters/enemy/enemy_idle_winter_draft.png` | **draft** | Violet coat `#9B59B6`, facing left |
| 5 | `assets/images/characters/enemy/enemy_throw_winter_draft.png` | **draft** | Enemy throw, facing left |
| 6 | `assets/images/world/backyard_bg_winter_draft.png` | **draft** | 1280×720, snow backyard, fence/bushes, empty mid, no characters |
| 7 | `assets/images/world/backyard_bg_summer_draft.png` | **draft** | Same layout, grass + subtle hose/pool hint |
| 8 | `assets/images/forts/fort_stage_1_draft.png` | **draft** | Left-side wood fort, small |
| 9 | `assets/images/forts/fort_stage_2_draft.png` | **draft** | +crates/sandbags |
| 10 | `assets/images/forts/fort_stage_3_draft.png` | **draft** | Battlements + blue pennant |
| 11 | `assets/images/projectiles/snowball_draft.png` | **draft** | White + `#5B7C99` rim |
| 12 | `assets/images/projectiles/water_balloon_draft.png` | **draft** | Pink `#FF6B9D` + cyan sheen |
| 13 | `assets/images/vfx/impact_snow_draft.png` | **draft** | White poof + spark stars |
| 14 | `assets/images/vfx/impact_splash_draft.png` | **draft** | Cyan/pink splash |
| 15 | `assets/images/vfx/charge_glow_draft.png` | **draft** | Yellow `#FFE66D` ring |
| 16 | `assets/images/ui/wordmark_backyard_barrage_draft.png` | **draft** | “Backyard Barrage” bold rounded on cream plate |
| 17 | `assets/images/ui/btn_primary_draft.png` | **draft** | Cream + navy outline + 3D lip |
| 18 | `assets/images/ui/heart_draft.png` | **draft** | HP `#E74C3C` |
| 19 | `assets/images/ui/coin_draft.png` | **draft** | Currency `#F1C40F` |
| 20 | `assets/images/ui/app_icon_1024_draft.png` | **draft** | 1024×1024 rounded icon, kid + backyard motif |

**Intended-final:** none yet — all filenames carry `_draft`. Finals should drop `_draft` after approval and optional polish pass.

---

## Missing (not in this MVP draft pack)

### Character poses / variants
- Player: walk, charge, hit, KO (winter + summer)
- Enemy: idle/throw summer; walk, charge, hit, KO (winter + summer)
- Shared pose sheet completeness for both seasons

### World / props
- Parallax layers (sky / fence / ground split)
- Prop packs under `assets/images/props/winter/` and `.../summer/` (empty folders only)

### Forts / combat UI
- Fort HP / fort bar UI chrome
- Mirrored right-side fort variants (or document flip-in-engine)

### UI still needed
- Season chips (snowflake / sun)
- Shop card frames (cream + wood border)
- Secondary / disabled / pressed button states
- Settings / pause icons
- Win / lose banners

### VFX / projectiles
- KO swirl + stars
- Charge stages (1–3 intensity)
- Trail / afterimage sprites

### Audio
- Studio does **not** generate final SFX here — see `docs/AUDIO_HANDOFF.md`
- `assets/audio/music/` and `assets/audio/sfx/` empty

---

## Showcase absolute paths

- App icon: `/workspace/backyard-barrage/assets/images/ui/app_icon_1024_draft.png`
- Winter BG: `/workspace/backyard-barrage/assets/images/world/backyard_bg_winter_draft.png`
- Player idle: `/workspace/backyard-barrage/assets/images/characters/player/player_idle_winter_draft.png`
- Wordmark: `/workspace/backyard-barrage/assets/images/ui/wordmark_backyard_barrage_draft.png`

---

## Regen

```bash
/workspace/.venv-art/bin/python /workspace/backyard-barrage/scripts/generate_mvp_drafts.py
```
