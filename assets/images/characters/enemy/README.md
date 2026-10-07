# Backyard Barrage enemies (v1, approved by Ethan 2026-10-07)

Two enemies, three frames each. All face LEFT, toward the player.

- frostkid/frostkid_idle.png, frostkid_windup.png, frostkid_throw.png
- ghost/ghost_idle.png, ghost_windup.png, ghost_throw.png

Each is a 1024x1024 transparent PNG with feet/base on y=941 (92% down), plus a _512 preview.
The throw frames include the snowball leaving the hand, so in-game you may hide the drawn ball and spawn the real projectile instead.
These are starting assets. Ethan may send a new 3D build later, and these could be replaced.

**Wired set:** the game draws the later v2 exports (full aim/idle/windup/throw/hit/KO sets) from `assets/images/characters/rivals/{ghost,frostkid}/`. The ghost windup there is this folder's v1 `ghost_windup_512.png`, rescaled to the v2 framing because v2 has no ghost windup. This folder stays as the raw v1 reference and is not loaded.
