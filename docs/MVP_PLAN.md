# Backyard Barrage — MVP Plan

**Status:** Name locked (working title)  
**Platforms:** iOS + Android (Flutter), landscape-only  
**Seasons in MVP:** Winter (snowballs) + Summer (water balloons). **Summer is switched off** (`Season.playable`) until its art matches the 3D winter pack; the game ships winter-only until then.  
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
1. Pick Campaign or Arcade, and a season (Winter / Summer) — or default last played  
2. Enter backyard arena (landscape)  
3. Control one kid; hold to charge, release on the swivel to throw  
4. KO all enemies → win round → earn currency → upgrade shop → next wave  
5. Lose all kids → Campaign wipes skills (coins stay) and retries at wave 1, or Arcade goes back to its stage checkpoint → summary + retry  

### 3.2 Combat rules
| Rule | MVP value |
| --- | --- |
| Player starts with | 1 kid |
| Hits to KO | Allies take 3. A hit stuns for a share of the 2.8s base lock: Easy half (1.4s), Normal three quarters (2.1s), Hard 0.4 (~1.1s, because Hard rivals throw every 1–1.5s). A second hit during that stun KOs. Enemies take 1 hit on Easy, 2 on Normal, and 3 on Hard. On Hard: brush-off (~1s), knockdown then up, then out. Enemy stun length does not change with difficulty |
| Throw | Hold the right third of the screen to charge. Release throws. There is no aim stick |
| Charge | Tap ≈ 1/3 power, climbing at a steady rate to full (no plateau at the start). At rank 0 the base hold is 3s: Easy fills it in half (1.5s), Normal in two thirds (2s), Hard in 0.7 (2.1s). A power meter (an upright bar with quarter ticks, orange at full) stands beside the thrower on every difficulty. While power builds the kid aims straight ahead. From 85% charge the aim pans at a constant speed (about 12°/s) and bounces off the angles that reach the back and front lanes at the rivals' distance, so it turns around at the yard edge instead of stalling there. It eases down to 35% speed while the line is on a rival and back up off it |
| Throw depth | Release samples the swivel. The swept angle is the ball's ground track: a straight line on the yard, not rounded to a lane. Power sets how far along it the ball goes. A release that misses a reachable rival by a few pixels of depth is nudged onto them |
| Hit | A small body hitbox. The ball can pass in front of or behind a kid. Overlap of the ground track is what counts, within half a row of depth either side (no dead band between rows), checked along the whole stretch the ball covered that frame. Rivals aim at a kid's real position, not their nearest lane. The ball casts a shadow on the floor under its track. The snowball image draws behind a kid when that track is over the hit box, and in front when it is under. Drawn size does not change the hit |
| Depth | Kids and snowballs draw smaller toward the far edge (75% of the near-edge size) and full size toward the camera. Scale is anchored at a kid's feet. Rivals still take about 1.2s per column |
| Walk | Left two-thirds of the screen. Drag and the selected kid follows the finger inside their half, out to about 60px from the river bank (the limit slants with the bank, so the back rows reach further), at the locked rate of six times the old cell walk. Difficulty does not change that speed. A tap on a kid selects them |
| Active thrower | One kid is selected and shows a soft glow. The others throw on Easy |
| Enemy count | Waves 1–6 climb: 1, 2, 3, then 3 with faster throws and steps, then 3 with those buffs plus 1 HP on the difficulty base, then 4. Wave 7+ holds at 5 with the buffs |
| Win | All enemies KO’d. If snowballs are still in the air when the last kid on either side goes down, the result waits (up to 4s) for them to land, and their hits still count; nobody starts a new throw meanwhile |
| Lose | All player kids KO’d |

### 3.3 Controls (touch, landscape)
- At the start of each round, both crews walk in from off-screen to their spots. Input stays locked until they arrive.
- Right third of the screen: hold to charge the selected kid, release to throw. A short hold is still about 1/3 power. The kid aims straight ahead until the charge reaches 85%; then the aim pans up and down the rival half, turning around at the back and front lanes. Preview by difficulty: Easy draws a faint aim line across the yard, a bright stretch out to a landing mark at the current power, and a ring on the rival the throw will hit. Normal draws the line and landing mark without the ring. Hard draws no floor preview, only the aim arrow, the glow, and the power meter. Letting go samples that angle, so timing sets the depth and the charge sets the distance. The kid stays upright and does not roll. The sweep swaps the upright sprite in five equal bands from the up-screen end of the row to the down-screen end: turn-30l, turn-15l, the existing charge pose, turn-15r, then turn-30r. Player winter is Ethan's 3D kid: straight across is `aim_01`, up-screen holds the profile (`aim_00`), and down-screen turns toward the camera through `aim_02` to `aim_03` (3/4 front). All frames face the rivals; nothing is mirrored. Walking loops two run frames. Enemy sprites are never mirrored from player art. The aim arrow still shows the angle.
- Left two-thirds: drag and the selected kid follows the finger inside their half. They are not snapped to a cell. A tap on a living kid selects them and keeps their feet until the finger moves. A tap on open ground sends them to that spot. The yard's columns and rows still place forts, rivals, and throw lanes.
- Kids you are not controlling throw and step like Easy rivals. While a teammate winds up it looks up and down the yard with the same turn frames as your kid's sweep, settling on its target by the release.
- Each side stays on its own half. The middle band is neutral. The yard grid still places rivals and forts. It does not lock the player's feet or the snowball's hit row.
- Campaign loss: wave progress and every skill node (crew, fort, throw, and the rest of the tree) go back to a new game. Unspent coins stay in the Campaign wallet. Retry starts at wave 1. Campaign is ranked by highest wave.
- Both modes carry crew health between waves by difficulty: Easy brings everyone back full; Normal heals each standing kid 1 HP; Hard carries health as it is. On Normal and Hard a teammate still knocked out after the carry **leaves the crew** at the wave clear: their Team node reopens in the shop, and every crew node costs 1.5× more for each teammate lost so far (`RunLedger.kidLosses`). The first wave of a run starts full. The Recovery chain (Crew tab, Normal and Hard) adds Patch up (+1 HP per wave), Patch up II (+2), and Second wind (one knocked-out teammate rejoins each wave at 1 HP). Rules live in `CrewCarry`.
- Arcade is played in **stages** of five waves (1–5, 6–10, 11–15, …). The first wave of each stage locks in a checkpoint: skills, items, coins, and the price counters. An Arcade loss goes back to that checkpoint: everything bought since is refunded, half the coins earned since are lost, and Retry (or Play on the home card) starts at the stage's first wave with a full crew. The defeat screen shows coins refunded, coins lost, and the score penalty.
- Arcade is ranked by **score**: every coin earned adds a point, clearing wave *w* adds 10 × *w* plus a tenth of the unspent coins (spending less scores more), and a defeat on wave *w* takes 50 × *w* (never below 0). The wallet keeps its **best score**, which never goes down.
- **Start over** (Arcade defeat screen, after a confirm): back to wave 1 with 0 coins, no skills, no items, price counters reset, and the score at 0, to try a new build for a better score. The best score and best wave stay.
- Leaving through Pause → Menu bookmarks the run in that wallet: the card's button reads **Resume** with the wave, and Play picks up on that wave (the next one if it was already cleared) on the same arena. A defeat clears the bookmark.
- Every mode × difficulty pair has its own wallet (coins, skills, best wave, score): six in all. Nothing earned in one carries to another, so Easy progress never reaches Normal or Hard, and Campaign never touches Arcade. Code names are swapped from the shown names (`PlayMode.arcade` shows as Campaign) because saves store them.
- Season is shared. The home screen shows the Campaign best for the picked difficulty large and highlighted, with any other difficulty that has a cleared wave beside it, small and grey. Each mode card shows that mode's coins for the picked difficulty, then Best wave (Campaign) or Score (Arcade). The defeat screen shows the same headline number.
- Difficulty is picked only on the home screen (Easy / Normal / Hard pills, top left, with a one-line summary on larger screens). Settings and Pause do not offer it, so a run stays on one difficulty.
- Lock orientation: landscape left/right only  

### 3.4 AI (simple)
- Rivals target a living player kid, throw on the difficulty timer, and step with the Easy / Normal / Hard lane rules. A rival locks its aim when its windup starts: where the target stands then, off by up to 0.9 / 0.6 / 0.35 rows (Easy / Normal / Hard, center-weighted; frost kids tighter, rushers looser). Moving during the windup dodges it
- People vs snowmen: rivals come in types. **Snow ghost** is the standard lobber. **Frost kid** is the sniper: it works back to the column behind its fort and stays on it (it only changes rows, and steps back after a hit), winds up longer with a glint on the ball, aims very true (0.15× the scatter), and looks again once 60% into its windup, moving its aim to where its target stands then, so only a late step dodges. It goes down to one snowball on every difficulty. **Rusher** holds the front line and is fast and sloppy: 0.55× the windup and gap, 1.6× the step speed, and 2.2× the aim scatter. Each wave's lineup comes from `RivalRoster`: snowmen in slots 1, 3, 5 and a random special (frost kid or rusher) in slots 2 and 4, re-rolled every wave. One rival is always a snowman; each added rival changes the mix.
- **Ice hound** (rare yard event, `HoundComponent`). From wave 3, a wave has a 12% / 18% / 25% chance (Easy / Normal / Hard) of a hound 4–9s into the fight, on a random living kid's lane. It runs in on its gallop frames, stands at the right edge for a second with a frosty dashed line along its lane, runs to the river, crouches, leaps across, and hunts left. A kid in its catch box gets pounced and bitten: a one-hit knockout on every difficulty (kid-safe: a cartoon frost snap). The catch box grows with difficulty: ±0.45 / 0.7 / 1.0 rows off the lane, pouncing from 90 / 120 / 160px. A player snowball that hits it before the leap scares it off and pays one random power-up; Frost armor turns the bite away.
- **When hounds come.** Two programs. The roll: a fixed chance per wave, arriving 4–10s in (the next ones 4–8s apart), so a quick wave still meets it: waves 3–4 12% / 18% / 25% (Easy / Normal / Hard), waves 5–9 50% / 60% / 70%, and from wave 10 one sure hound per ten waves plus a 20% / 25% / 30% chance of one more. Lingering: one more hound somewhere in each five minutes after the first minute (by 5 minutes a second, by 15 minutes four), up to four in a wave. Each hound is warned by its own howl 2–6s earlier. No hounds on boss waves.
- **Bosses** (`lib/game/boss.dart`). Every Arcade stage ends on a boss from wave 10 (waves 10, 15, 20, …; Campaign uses the same waves). The boss is random, never the same one twice running. The first boss comes alone; each later boss brings one more rival than the last. A boss takes 8 / 12 / 16 snowballs (Easy / Normal / Hard) the first time and 25% more each time one comes back, counted in throws: its health is multiplied by how many hits the player's own throw lands (Harder hit), so damage skills do not melt it. A hit is a short flinch, never a stun or knockdown. Its lobs are big balls (drawn 1.8× their hit size) that burst where they land into a shockwave: two hearts lost in the middle (or for the kid struck), one for anyone in the ring (95px, a row and a half deep). It throws every 2.6 / 2.1 / 1.6s. It walks rows on its home column, lobs on a timer, and does a special every 7–10s, always after a long, readable windup. No hounds on a boss wave. A boss wave is its own Arcade checkpoint, so a loss retries just the boss. Knocking the boss out pays three random power-ups, and clearing the wave pays 3× the wave bonus. The HUD shows the boss's name and a health bar; the wave opens on a "BOSS!" banner with the intro sting and a roar.
  - **Magmo (magma elemental)** lobs magma balls (lava-and-steam landing). Its heat wave: it lines up with a kid's row, leans back glowing for 1.3s while the lane is marked on the ground, then pushes both arms out and the wave sweeps the whole lane to the yard's far edge in about a third of a second. The windup is the time to leave the lane. It hits a band twice a snowball's size (it can catch two kids), passes through kids (each hit once) and forts (each loses 2 HP once), and the fire lingers a moment.
  - **Grumblefrost (ice ogre)** throws giant snowballs (1.6× splash). Its slam: it crouches (0.6s), hops (0.5s), and crashes down with a screen shake and a shockwave ring. The ground then cracks under every standing kid for 1.0 / 0.8 / 0.6s (Easy / Normal / Hard), and an ice spike bursts straight up there, with no path to follow; stepping off the crack dodges it.
- **Big waves.** From wave 11 there is one more rival every five waves, with no cap (wave 100 has 23). Five start the wave; the rest wait offstage and walk on every 3s while fewer than eight stand on the yard. With eight up, the next one walks on the moment one goes down. The HUD shows "+N waiting" beside the rivals' hearts, and the wave is only clear once the waiting ones are down too.
- Charge: Easy bots hold about 4.5s at rank 0. Normal bots hold the unscaled rank-0 charge, about 3s. Hard bots keep a short windup (about 0.3–0.55s), so Hard still charges faster than the player
- Throw about every 3s on Normal (slower on Easy, about 1–1.5s on Hard)
- After a throw, step one row toward a living opponent if nobody is within one row. Easy does that every other throw. Normal does it every throw. Hard steps onto the closest opponent's exact row every throw
- A lob that falls short steps one column closer. A hit steps one column back, or off that row if they are already at the back line
- They will not step onto a teammate
- Player kids who are not selected use that same Easy brain, mirrored so "closer" is toward the rivals
- Per-wave: slightly shorter gaps and tighter landing scatter  

### 3.5 Skill tree (between waves, and from the defeat screen)
Each rival KO pays 4 coins on waves 1–5 and one more each later stage. Clearing the wave pays a bonus on top: `(6 + 4w) × 1.1^(w−1)`, so it is 10 on wave 1, about 115 on wave 10, and about 2,000 on wave 30. Spend that soft currency in the tree, which replaces the three-card shop. The shop has three tabs: Crew (Team, Recovery, Aim, Reaction, Charge), Fight (Throw, Poise, Pressure, Blast, Damage), and Defense (Fort, Shield, Lanes). One chain shows at a time. Aim, Reaction, Charge, and Damage ranks that only help teammates stay locked until the player owns a second kid. A node unlocks after its parent. Within the hand-made ranks each costs 2.5× the one before, rounded to the nearest 5 (for example Quicker throw 10 → 25 → 65 → 155 → 390). Most chains then keep going: the next ranks (as many again as the hand-made ones) cost 3× each, then 4×, then 5×, until a price would pass 50,000,000. Their effects keep growing on a slower curve with floors and caps (`SkillEffects`). Team (the crew stays at three), Recovery, and Lanes stop where they are. The shop shows the last rank owned and the next three. The hand-made tree is 3,437 coins. On Easy the Recovery branch is hidden (Easy already heals everyone). Balance numbers live in `PROGRESS.md`.

| Branch | Effect |
| --- | --- |
| Team | Crew 1→2→3 |
| Recovery | Normal and Hard (Easy already heals): Patch up +1 HP, Patch up II +2 HP to every standing kid between waves; Second wind brings one knocked-out teammate back at 1 HP each wave (needs a second kid) |
| Fort | Stages 2 and 3, then extra HP |
| More forts | Second fort (60), third fort (150). Each stands on a random spot in your half every wave, at your fort's stage and HP, at least a column pair or two rows away from every other fort |
| Throw | Faster charge / harder lob, 5 ranks |
| Poise | Shorter stun on your kids |
| Pressure | Longer stun on enemies |
| Aim / Reaction / Charge | Teammate bot aim, throw gap, and windup |
| Shield | Block 1 hit with no stun, then more charges |
| Lanes | Your snowballs pass your own fort. Until this node, the base fort rule stays |
| Blast | Larger hit radius |
| Damage | Your throws land extra hits, then teammate bots do too |

Fort cover shelters 1–2 kids on the cover columns. The blocking box is under half of that side and about one row tall, so the rows above and below and the columns beside the fort stay open. On Easy and Normal a lob that peaks past your own fort clears it. Hard skips that clear, so a full lob from behind your own fort can still chip it. The other side's fort still stops a ball that flies through its box. The fort's row is random inside the mid band (not flush with the top or bottom of the yard, and not on the back line). Enough hits collapse it. A collapsed fort does not block shots from either side. HP refills, and the row is rolled again, at the start of the next wave.

### 3.5a Power-ups (one-use items)

The shop's Items tab sells one-use power-ups (up to 3 of each per wallet): Frost armor (crew takes no damage for 3s, 25), Fort cracker (next throw knocks down a rival fort it hits, 30), Freeze all (every rival frozen 2.5s, 35), Power throw (next charge starts full, 15), Big splat (next throw splats 3× as wide, 20), Hot cocoa (+1 HP to every standing kid, 30), and Revive (one knocked-out teammate gets back up with full health; 100, twice the third kid's price, then 1.5× more for each one bought). In a fight, a round button per owned item sits in the bottom-left corner within reach of the left thumb (stacking upward, then into a second column); it lights while armed. Items stay until used. A Campaign defeat clears them with the skills (and resets the Revive price); Arcade goes back to its checkpoint's items. Scaring a hound off with a snowball pays one random item; beating a boss will pay three. A wallet with every item full gets coins instead.

### 3.6 Seasons
Same rules; swap:
- Projectile art + VFX + SFX  
- Arena tint / props (snow vs grass)  
- Kid outerwear (coat vs tee)  

While summer is on, the player **chooses** season with a small toggle on the home screen, the shop, and the defeat screen; with only winter playable, those toggles are hidden. No real-world lock in MVP. The home backdrop follows the season.

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
2. **Main menu** — Campaign and Arcade, the difficulty pills, Settings. The yard behind the menu follows the season. Highest Campaign wave is shown large.  
3. **Arena HUD** — kid HP pips, fort bar, charge bar, pause  
4. **Wave clear** — coins earned, Continue  
5. **Skill tree** — buy the next node in a branch, Continue to next wave  
6. **Defeat summary** — a short coin beat for the unspent amount, then waves cleared, coins carried over, Skills / Retry / Menu. Campaign has wiped skills and retries at wave 1. Arcade is back at its stage checkpoint and retries the stage.  
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
- Summer overlay props (grass)  
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

## Audience and ads (Oct 2026)

General-audience listing, rated 4+, marketed as a family game, not in Apple's Kids Category. Because the game is aimed at kids, it is treated as directed to children: no iOS tracking prompt, no tracking in the privacy manifest, every ad request tagged with child age treatment and a G content ceiling, non-personalised, and only after consent allows ads. Remove Ads and Restore Purchases ask a grown-up question first.

## Readability (Oct 2026)

- A kid with shield charges shows a blue shield badge with the hits left over its head.
- A throw carrying Power throw, Big splat, or Fort cracker is drawn as that power-up's icon. Big splat flies as a normal-size ball and bursts where it lands: one hit on every rival in the splash, two near its middle.
- Sizes: the snowman draws smallest (1.0), the frost kid 1.03, and the rusher brute 1.15 (about 10% taller than the snowman).
- Backgrounding (home, app switcher, a call, locking) pauses the fight behind the pause menu, stops the charge hum, and saves the run, so iOS closing the app resumes there. Android back opens and closes the pause menu. An Arcade run always resumes at its checkpoint, even after leaving from the defeat screen.
