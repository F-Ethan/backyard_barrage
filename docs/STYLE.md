# Backyard Barrage — Style Sheet (MVP)

**Status:** Draft v1.1 — original IP look (NOT SnowCraft / classic red-vs-green war); pose arcs documented

## Name
Backyard Barrage

## Tone
Playful, cozy backyard, kid-safe. Big readable silhouettes for phone **landscape**. Soft humor, no gore.

## Palette (hex)
| Role | Hex | Use |
|------|-----|-----|
| Sky winter | `#A8D4F0` | Winter BG sky |
| Sky summer | `#87CEEB` | Summer BG sky |
| Snow | `#F4F8FC` | Ground / snowbanks |
| Grass | `#6BBF59` | Summer ground |
| Dirt / fence | `#C4A484` | Fence wood |
| Player primary | `#3D7CFF` | Player kid / coat accents (blue — unique vs classic red) |
| Player secondary | `#FFC857` | Hair / warm accents |
| Enemy primary | `#9B59B6` | Enemy kids (violet — not green army) |
| Enemy secondary | `#F39C12` | Enemy accents |
| Fort wood | `#8B5E3C` | Fort boards |
| Fort snow cap | `#E8F1F8` | Fort snow |
| Balloon fill | `#FF6B9D` | Water balloon |
| Balloon highlight | `#7EC8FF` | Water sheen |
| Snowball | `#FFFFFF` outline `#5B7C99` | Projectile |
| UI ink | `#2C3E50` | Text / outlines |
| UI cream | `#FFF8F0` | Panels |
| Coin | `#F1C40F` | Currency |
| Heart | `#E74C3C` | HP |
| Charge glow | `#FFE66D` | Throw charge |

## Outline & shape language
- Consistent dark outline ≈ 3–4px at master size (`#2C3E50`)
- Rounded, chunky limbs; oversized heads (~40% of height) for readability
- Flat fill + 1 soft shadow plane max
- No photorealism; no blood; hit = stars / swirl / splat

## Characters
- **Player kid:** Blue jacket (winter) / blue tee (summer); sandy hair `#FFC857`; freckles optional
- **Enemy kids:** Violet hoodie / tee; darker hair; same pose sheet as player
- Pose set: idle, walk, charge, throw, hit, KO
- Face toward camera-ish 3/4 view facing opponent (player faces right; enemy faces left)

### Pose arcs (polish pass — keep readable at phone landscape)
- **idle:** feet planted, arms soft at sides
- **walk:** mid-stride; leading leg forward + trailing leg back; **opposite** arm swing
- **charge:** lean **back**, both arms pulled with snowball (winter) or water balloon (summer); optional yellow `#FFE66D` charge glow rings
- **throw:** follow-through **forward** (arm + projectile toward facing)
- **hit:** recoil lean back; flinch arms up; X-eye + impact stars OK
- **KO:** slumped / seated; swirl + stars above head (no gore)
- Winter vs summer = clothing + projectile only; **same body proportions / outline weight**
- Soft ground contact shadow on every sheet; max one soft body shade plane
- Master canvas: 512×512 transparent PNG; regenerate via `scripts/generate_poses_polish.py`

## World
- Wide landscape backyard: house edge optional left, fence mid, bushes
- Winter overlay: snow banks, snow on fence
- Summer overlay: grass. No pool or hose; those circles read as control pads.

## Forts
- Stages 1→3: taller / more sandbags or crates; same wood palette
- Player-side left; mirrorable

## Projectiles / VFX
- Snowball: round white + blue-gray rim
- Water balloon: pink/magenta with highlight
- Impact: white poof (winter) / cyan-pink splash (summer)
- Charge: yellow ring
- KO: swirl + stars

## UI
Screens follow [`docs/UI_MODERN.md`](UI_MODERN.md) (kit v2 in `assets/images/ui_modern/`). Pill primary buttons, soft cream sheets, glass HUD chips. Ink `#1A2332`, primary `#3D7CFF`. The older wood/comic frames in `assets/images/ui/` stay on disk and are not the live UI.

## Audio
Studio does **not** generate final SFX in this pack — handoff list in `docs/AUDIO_HANDOFF.md`.

## Draft vs final
Generated PNGs labeled in filenames; treat first pass as **draft** until Ethan/CEO approve.
