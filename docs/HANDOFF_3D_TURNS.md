# Handoff: 3D winter aim-turn sprites (pose-locked charge)

**For:** Code Manager  
**From:** Art / Studio (Ethan-approved)  
**Date:** 2026-10-06 (CT)

## Decision (approved)

- **Pose locked:** same charge / aim pose across mild yaws — not unique poses per angle.
- **Yaw set:** `30L | 15L | charge (0°) | 15R | 30R` (mild only; no full front/back).
- **Throw** is a **separate** pose later — do not invent throw frames from this pack.
- **One kid only** for now (original winter player). Team faces / variants deferred.
- **Canon charge** remains the approved single render; sheet center is reference-only.

## Delivered assets (absolute paths)

### Aim-turn frames (1024×1024 + 512 preview)

| Yaw | 1024 PNG | 512 PNG |
|-----|----------|---------|
| 30L | `/workspace/backyard-barrage/assets/images/characters/player/player_turn_30l_winter_3d_v1.png` | `.../player_turn_30l_winter_3d_v1_512.png` |
| 15L | `/workspace/backyard-barrage/assets/images/characters/player/player_turn_15l_winter_3d_v1.png` | `.../player_turn_15l_winter_3d_v1_512.png` |
| 15R | `/workspace/backyard-barrage/assets/images/characters/player/player_turn_15r_winter_3d_v1.png` | `.../player_turn_15r_winter_3d_v1_512.png` |
| 30R | `/workspace/backyard-barrage/assets/images/characters/player/player_turn_30r_winter_3d_v1.png` | `.../player_turn_30r_winter_3d_v1_512.png` |

### Canon charge (do not replace with sheet center)

- `/workspace/backyard-barrage/assets/images/characters/player/player_charge_winter_3d_v1.png`
- `/workspace/backyard-barrage/assets/images/characters/player/player_charge_winter_3d_v1_512.png`

### Sheet center (archived for comparison only — not game canon)

- `/workspace/backyard-barrage/assets/images/characters/player/player_charge_winter_3d_from_sheet.png`
- `/workspace/backyard-barrage/assets/images/characters/player/player_charge_winter_3d_from_sheet_512.png`

Center-from-sheet **differs** from canon charge (re-render on the turn sheet; ~31% pixels differ at Δ>10). **Use `player_charge_winter_3d_v1.png` as the 0° charge frame.**

### Clean comparison strip

Aim-sweep order left → right: **30L, 15L, CANON charge, 15R, 30R**

- `/workspace/backyard-barrage/assets/images/characters/turn_yaw_sheet_3d_winter.png` (2560×548)

### Source sheet (split source)

- `/workspace/backyard-barrage/assets/images/characters/turn_yaw_sheet_3d_winter_v3.png`
- `/workspace/backyard-barrage/assets/images/characters/turn_yaw_sheet_3d_winter_v3_master.jpg`

Raw equal panels (label bar stripped):  
`/workspace/backyard-barrage/assets/images/characters/player/_raw_3d/turn_yaw_v3_panels/`

## Processing notes

- Sheet split into **5 equal** horizontal panels (1280×720 → 256px-wide cells).
- Bottom **label bar excluded** (crop `y < 535`; labels lived ~537–569).
- Each panel → content crop → pad to **1024×1024** white, character ~**80%** frame height (`scripts/postprocess_3d_sprites.py` `to_square_1024`), plus `_512.png`.

### Crop caveat (15R / 30R boundary)

Equal fifths put the **15R|30R** seam at `x=1024`. Soft silhouette pixels touch that seam (~34 content px at `x=1023`, ~40 at `x=1024`). Possible **1–2 px soft-edge fringing** between 15R and 30R; characters remain usable. 30L / 15L / charge had clear margins.

## Out of scope (do not expect in this pack)

- Throw / release / follow-through frames
- Summer variants
- Enemy turns
- Team faces (A/B/C) — deferred
- App icon

## Suggested Code Manager wiring

Aim-sweep: `30l → 15l → charge(v1) → 15r → 30r` using the paths above. Keep throw on the existing throw pose pipeline when Art delivers 3D throw.

## Update (same turn): aim-set identity

For **in-game aim sweep**, use the **sheet-consistent** 0° frame so the face does not pop:
- `/workspace/backyard-barrage/assets/images/characters/player/player_charge_winter_3d_from_sheet.png`

Keep `/workspace/backyard-barrage/assets/images/characters/player/player_charge_winter_3d_v1.png` as the **hero still / marketing charge** (Ethan’s approved single). Do not mix v1 into the yaw animation strip until Art regenerates turns to match v1’s face.
