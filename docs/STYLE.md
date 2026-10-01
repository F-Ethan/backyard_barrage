# Backyard Barrage — Style Sheet (MVP)

**Status:** Draft v1 — original IP look (NOT SnowCraft / classic red-vs-green war)

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

## World
- Wide landscape backyard: house edge optional left, fence mid, bushes
- Winter overlay: snow banks, snow on fence
- Summer overlay: grass, optional hose/pool corner hint (subtle)

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
- Wordmark: bold rounded sans, stacked or single line "Backyard Barrage"
- Buttons: cream fill, navy outline, slight 3D bottom lip
- Season chips: snowflake / sun icons
- Shop cards: cream panels with wood border

## Audio
Studio does **not** generate final SFX in this pack — handoff list in `docs/AUDIO_HANDOFF.md`.

## Draft vs final
Generated PNGs labeled in filenames; treat first pass as **draft** until Ethan/CEO approve.
