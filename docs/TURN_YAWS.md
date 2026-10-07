# Turn / yaw poses (mild set)

**Status:** Ethan-approved direction — mild yaws only (no front/back). Regenerator: `scripts/generate_turn_yaws.py`.

## Default facing (unchanged)

Existing charge / idle sheets already face **across the yard**:

| Role  | Default look | Screen |
|-------|--------------|--------|
| Player | `+x` (right) | looking right toward enemy fort |
| Enemy  | `−x` (left)  | looking left toward player fort |

**Do not regenerate default.** Keep `*_charge_*` / idle as the center of the aim sweep. Do **not** mirror player sprites for enemy (mirroring points them at their own fort). Enemy sheets use `face_sign = −1` the same way as `generate_poses_polish.py`.

## Mild yaw assets

Sixteen drafts at `512×512` transparent PNG:

```
characters/{player|enemy}/{player|enemy}_turn_{30l|15l|15r|30r}_{winter|summer}_draft.png
```

Angles are **relative to that kid’s default across-yard facing**, named by **screen-left / screen-right**:

| Token | Approx yaw from default | Screen feel |
|-------|-------------------------|-------------|
| `30l` | ~30° toward screen-**LEFT**  | a bit toward camera / up-screen along the row |
| `15l` | ~15° left                   | milder toward-camera hint |
| *(default charge)* | 0° | straight across the yard |
| `15r` | ~15° toward screen-**RIGHT** | milder away-from-camera hint |
| `30r` | ~30° right                  | a bit away from camera / down-screen along the row |

### Aim-sweep order (left → right along the row)

```
30l → 15l → (existing charge / default) → 15r → 30r
```

Visual deltas are **exaggerated for phone readability** (still the same mild-angle contract): eye placement (incl. a small second-eye peek on `30l` only), hair / pom / bangs shift, shoulder / chest bias, projectile clearly left/right of head, body lean + foot plant. Kids stay **profile-ish / mild ¾ across the yard** — never full frontal, never back-of-coat.

## Hard rules

- **Never** face fully toward the camera (old `front`).
- **Never** show the back of the coat (old `back`).
- Obsolete `turn_front_*`, `turn_back_*`, and `turn_quarter_*` drafts are removed; do not reintroduce them.
- Winter = coat + pom + snowball; summer = tee + water balloon. Same silhouette / outline weight as STYLE.md.

## Contact sheet

Player winter strip for review:

`assets/images/characters/turn_yaw_sheet_mild.png`

Labels left → right: `30l`, `15l`, `default`, `15r`, `30r`.
