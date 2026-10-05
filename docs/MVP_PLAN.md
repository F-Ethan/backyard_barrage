# Backyard Barrage — MVP Plan

**Status:** Name locked (working title)  
**Platforms:** iOS + Android (Flutter), landscape-only  
**Seasons in MVP:** Winter (snowballs) + Summer (water balloons)  
**Out of MVP:** Real-time multiplayer, spring/fall, web client, river map  

---

## 1. Product summary

Backyard Barrage is a short-session landscape arena game: charge-and-lob projectiles across a backyard, grow your kid crew and fort between rounds, and switch between winter snowballs and summer water balloons.

**One-liner (store):** Seasonal backyard fights — snowballs in winter, water balloons in summer.

**Differentiation (not a cheap SnowCraft clone):**
- Original name, art, audio, UI
- Upgrade meta (kids + fort + throw) front and center
- Dual-season skins on one ruleset
- Landscape mobile-first controls

---

## 2. MVP goals

1. Fun charge-throw loop in under 30 seconds to first splat  
2. Clear progression: 1 kid → more kids, fort upgrades, throw speed  
3. Two seasons selectable (Winter / Summer)  
4. Ship on App Store + Play Store with GameLogic / Ethan as publisher  
5. Soft monetization path ready (ads or cosmetics later — none required to finish a run)

**Success metrics (post-launch soft launch):**
- D1 retention > 25%  
- Median session > 4 minutes  
- Crash-free sessions > 99%  

---

## 3. Core gameplay (MVP)

### 3.1 Match loop
1. Pick season (Winter / Summer) — or default last played  
2. Enter backyard arena (landscape)  
3. Control one kid; hold to charge, release on the swivel to throw  
4. KO all enemies → win round → earn currency → upgrade shop → next wave  
5. Lose all kids → run over → summary + retry  

### 3.2 Combat rules
| Rule | MVP value |
| --- | --- |
| Player starts with | 1 kid |
| Hits to KO | 3. Enemy: brush-off (~1s), knockdown then up, then out. Ally: a hit stuns ~2.8s on Hard; Easy is half of that and Normal is three quarters. A second hit during that stun KOs |
| Throw | Hold the right third of the screen to charge. Release throws. There is no aim stick |
| Charge | Hard: tap ≈ 1/3 power, ~1s ≈ 1/2, ~3s full. Easy fills that hold in half the time (2×). Normal fills it in two thirds (1.5×). Half-bell ease toward max. While held, the aim sweeps ±20° over about 3.6s |
| Throw depth | Release samples the swivel. The ball's ground track slides to that depth. Power sets how far it goes |
| Hit | A small body hitbox. The ball can pass in front of or behind a kid. Overlap of the ground track is what counts. The snowball image draws behind a kid when that track is over the hit box, and in front when it is under. Drawn size does not change the hit |
| Depth | Kids and snowballs draw smaller toward the far edge (75% of the near-edge size) and full size toward the camera. Scale is anchored at a kid's feet. Rivals still take about 1.2s per column |
| Walk | Left two-thirds of the screen. Drag and the selected kid follows the finger inside their half, at the locked rate of six times the old cell walk. Difficulty does not change that speed. A tap on a kid selects them |
| Active thrower | One kid is selected and shows a soft glow. The others throw on Easy |
| Enemy count | Wave 1 is 1 rival. Later waves are 3 |
| Win | All enemies KO’d |
| Lose | All player kids KO’d |

### 3.3 Controls (touch, landscape)
- At the start of each round, both crews walk in from off-screen to their spots. Input stays locked until they arrive.
- Right third of the screen: hold to charge the selected kid, release to throw. A short hold is still about 1/3 power. While the hold lasts, the aim sweeps through about ±20° over about 3.6 seconds. Letting go samples that angle, so timing sets the depth and the charge sets the distance. The kid stays upright and does not roll. The sweep swaps the upright sprite in four equal bands from the far end of the row to the near end: turn-back, the existing charge pose, turn-quarter, then turn-front. Those sprites are not mirrored. The aim arrow still shows the angle.
- Left two-thirds: drag and the selected kid follows the finger inside their half. They are not snapped to a cell. A tap on a living kid selects them and keeps their feet until the finger moves. A tap on open ground sends them to that spot. The yard's columns and rows still place forts, rivals, and throw lanes.
- Kids you are not controlling throw and step like Easy rivals.
- Each side stays on its own half. The middle band is neutral. The yard grid still places rivals and forts. It does not lock the player's feet or the snowball's hit row.
- A loss resets the run: wave progress and every skill node (crew, fort, throw, and the rest of the tree) go back to a new game. Unspent coins carry into the next run's wallet. Season and best wave stay. Retry starts at wave 1.
- Lock orientation: landscape left/right only  

### 3.4 AI (simple)
- Rivals target a living player kid, throw on the difficulty timer, and step with the Easy / Normal / Hard lane rules
- Charge: Easy bots take longer than the player's full charge. Normal bots match it. Hard bots keep a short windup (about 0.3–0.55s), so Hard still charges faster than the player
- Throw about every 3s on Normal (slower on Easy, about 1–1.5s on Hard)
- After a throw, step one row toward a living opponent if nobody is within one row. Easy does that every other throw. Normal does it every throw. Hard steps onto the closest opponent's exact row every throw
- A lob that falls short steps one column closer. A hit steps one column back, or off that row if they are already at the back line
- They will not step onto a teammate
- Player kids who are not selected use that same Easy brain, mirrored so "closer" is toward the rivals
- Per-wave: slightly shorter gaps and tighter landing scatter  

### 3.5 Skill tree (between waves, and from the defeat screen)
Each rival KO pays 8 coins. Clearing the wave pays a bonus on top (`12 + wave * 8`). Spend that soft currency in the tree, which replaces the three-card shop. Each branch is a short chain: a node unlocks after its parent, and costs rise along the chain. Balance numbers live in `PROGRESS.md`.

| Branch | Effect |
| --- | --- |
| Team | Crew 1→2→3 |
| Fort | Stages 2 and 3, then extra HP |
| Throw | Faster charge / harder lob, 5 ranks |
| Poise | Shorter stun on your kids |
| Pressure | Longer stun on enemies |
| Aim / Reaction / Charge | Teammate bot aim, throw gap, and windup |
| Shield | Block 1 hit with no stun, then more charges |
| Lanes | Your snowballs pass your own fort. Until this node, the base fort rule stays |
| Blast | Larger hit radius |
| Damage | Your throws land extra hits, then teammate bots do too |

Fort cover shelters 1–2 kids on the cover columns. The blocking box is under half of that side and about one row tall, so the rows above and below and the columns beside the fort stay open. On Easy and Normal a lob that peaks past your own fort clears it. Hard skips that clear, so a full lob from behind your own fort can still chip it. The other side's fort still stops a ball that flies through its box. The fort's row is random inside the mid band (not flush with the top or bottom of the yard, and not on the back line). Enough hits collapse it. A collapsed fort does not block shots from either side. HP refills, and the row is rolled again, at the start of the next wave.

### 3.6 Seasons
Same rules; swap:
- Projectile art + VFX + SFX  
- Arena tint / props (snow vs grass + sprinkler/pool hint)  
- Kid outerwear (coat vs tee)  

Player **chooses** season on main menu. No real-world lock in MVP.

### 3.7 Explicitly deferred
- Spring / fall seasons  
- Park & river maps  
- Online PvP / matchmaking  
- Global leaderboards (can stub local high score)  
- Accounts / cloud save (local save only for MVP)  
- Web build  

---

## 4. Screens & UX flow

1. **Splash / title** — Backyard Barrage  
2. **Main menu** — Play, Season toggle (Winter/Summer), Upgrades preview, Settings  
3. **Arena HUD** — kid HP pips, fort bar, charge bar, pause  
4. **Wave clear** — coins earned, Continue  
5. **Skill tree** — buy the next node in a branch, Continue to next wave  
6. **Defeat summary** — a short coin beat for the unspent amount, then waves cleared, coins carried over, Skills / Retry / Menu  
7. **Settings** — SFX/music, haptics, credits  

Accessibility: large hit targets; consider OpenDyslexic-friendly UI font option later.

---

## 5. Tech stack

| Layer | Choice | Why |
| --- | --- | --- |
| Client | **Flutter** (iOS + Android) | Matches Ethan’s shipping stack (QRVault, Bookmark, etc.) |
| Game loop | Flutter + **Flame** (or CustomPainter + Ticker) | Flame preferred for sprites, collisions, game loop |
| Physics | Simple custom arc + AABB / circle hits | No full Box2D needed for MVP |
| State / meta | `shared_preferences` or Hive / Isar | Persist upgrades, coins, settings |
| Audio | `flame_audio` or `audioplayers` | SFX + loop |
| Ads (post-MVP hook) | Google Mobile Ads | Same pattern as other apps when ready |
| Backend | **None for MVP** | Local only |
| CI | Codemagic / GitHub Actions (optional) | Store builds |
| Stores | App Store + Google Play | Landscape tablet + phone |

**Repo suggestion:** `backyard-barrage` under GameLogic projects.  
**Bundle IDs (placeholder):** `dev.gamelogic.backyardbarrage` (confirm before create).

**Device matrix MVP:** mid iPhone + mid Android phone, landscape; one small phone for thumb reach.

---

## 6. Architecture sketch

```
lib/
  main.dart
  app.dart                 # routes, theme
  meta/                    # currency, upgrades, save
  seasons/                 # winter/summer asset maps
  game/
    backyard_game.dart     # FlameGame
    components/            # kid, projectile, fort, arena
    systems/               # input, ai, combat, waves
  ui/                      # menus, shop, HUD overlays
  audio/
  assets/
```

**Determinism:** keep wave RNG seedable later for daily challenges; not required MVP.

---

## 7. Assets (MVP checklist)

### 7.1 Art — characters
- Kid base: idle, walk, charge, throw, hit, KO (simple)  
- Variants: Winter coat / Summer tee (recolor or swap layer)  
- Enemy kids: alternate palette (readable vs player)  
- Max 3 on-screen per side for MVP readability  

### 7.2 Art — world
- 1 backyard arena BG (wide landscape)  
- Winter overlay props (snow banks)  
- Summer overlay props (grass, optional pool edge / hose)  
- Fort stages 1–3 (player side)  

### 7.3 Art — VFX / projectiles
- Snowball + water balloon sprites  
- Impact splat/poof  
- Charge glow  
- KO effect  

### 7.4 UI
- Title wordmark  
- Buttons (play, season chips, shop cards)  
- Hearts / HP, fort bar, coin icon  
- App icon (1024)  
- Store screenshots templates (5–8)  

### 7.5 Audio
- Throw whoosh  
- Impact (snow vs wet pop)  
- Hit / KO  
- Win / lose stingers  
- Short menu + battle loops (or one loop, pitch/EQ swap)  

### 7.6 Style rules (own product)
- Unique silhouette & palette (not red-vs-green SnowCraft clones)  
- Big readable shapes for phone landscape  
- Consistent outline weight  
- Tone: playful backyard, kid-safe (no realistic weapons; “lawn darts” deferred — balloons/snow only)  

**Pipeline:** placeholders first (colored capsules) → Studio polish pass → store kit.

---

## 8. Monetization (after soft loop works)

MVP ships **free, no IAP required**. Hook points:
- Optional rewarded ad for +coins after defeat  
- Cosmetic kid hats (seasonal) later  
Avoid pay-to-win throw power.

---

## 9. Legal / positioning

- Original code, art, audio, name  
- Do not use SnowCraft / Snowbrawl assets or branding  
- Store text: “inspired by classic backyard snowball games” OK; do not imply official remake  
- Age rating target: 4+ / Everyone (cartoon conflict)  
- Privacy: no account → simple privacy policy (local data)  

---

## 10. Milestone plan

| Phase | Deliverable | Rough effort |
| --- | --- | --- |
| M0 | Repo + Flame sandbox, landscape lock, placeholder kids throw | 1–2 days |
| M1 | Hits, KO, waves, win/lose | 2–3 days |
| M2 | Meta: coins, 1→3 kids, throw speed, fort 3 stages | 2–3 days |
| M3 | Season swap Winter/Summer assets + SFX | 2–4 days (art-bound) |
| M4 | Menus, save/load, polish, haptics | 2 days |
| M5 | Store listing, screenshots, TestFlight + internal Play track | 2–3 days |

**Total calendar (with Studio parallel):** ~2–4 weeks part-time toward playable store build.

---

## 11. Test plan (MVP)

- Charge feel on small and large phones  
- Aim readable in both seasons  
- Upgrades actually change outcomes  
- Fort cover understandable  
- No soft-lock in shop with 0 coins  
- Background audio interruption  
- App switch mid-fight resume/pause  

---

## 12. Open decisions (resolve during M0–M1)

1. Flame vs minimal CustomPainter — **default Flame**  
2. Fort: blocks projectiles vs HP-only shelter — **recommend projectile block + HP**  
3. Local high-score table in MVP? — **yes, simple**  
4. Exact bundle ID / publisher account — confirm  
5. Final subtitle: “Snowballs & Water Balloons” vs “Seasonal Yard Fights”  

---

## 13. Next actions

1. Create Flutter+Flame repo `backyard-barrage`  
2. Style brief → Studio (palette, kid rules, fort stages)  
3. Prototype throw arc until “one more try” feels true  
4. Only then commission final art  

---

*Working title locked: Backyard Barrage. Seasons: Winter + Summer. Mobile Flutter iOS/Android. Plan version: 2026-10-01.*
