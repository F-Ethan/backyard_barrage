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
3. Control your living kids; charge → aim → release to throw  
4. KO all enemies → win round → earn currency → upgrade shop → next wave  
5. Lose all kids → run over → summary + retry  

### 3.2 Combat rules
| Rule | MVP value |
| --- | --- |
| Player starts with | 1 kid |
| Hits to KO | 2 |
| Throw | Press-hold charge, release to lob (arc + gravity) |
| Active thrower | One kid charging at a time |
| Enemy count | Starts ~2–3, scales by wave |
| Win | All enemies KO’d |
| Lose | All player kids KO’d |

### 3.3 Controls (touch, landscape)
- Tap-drag on own kid to select / move into position  
- Hold on kid (or throw button) to charge; aim with drag; release to fire  
- Left thumb: move/select · Right thumb: charge/aim (tune in playtest)  
- Lock orientation: landscape left/right only  

### 3.4 AI (simple)
- Target random living player kid  
- Charge with jittered aim  
- Occasional sidestep  
- Per-wave: slightly faster charge / better accuracy  

### 3.5 Upgrades (between waves)
Spend soft currency earned from wins:

| Upgrade | Effect | Cap (MVP) |
| --- | --- | --- |
| Extra kid | +1 max crew (unlock slots 2, 3) | 3 kids |
| Throw speed | Faster charge / projectile | 3–5 ranks |
| Fort | Cover + fort HP / stages | 3 stages |
| (Optional) Balloon/snow size | Larger hit radius | 3 ranks |

Fort provides partial cover on player side; projectiles can be blocked by fort HP until destroyed that wave (or regenerates between waves — pick one in build; recommend regenerate between waves for clarity).

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
5. **Upgrade shop** — buy ranks, Continue to next wave  
6. **Defeat / Victory run summary** — waves cleared, coins, Retry / Menu  
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
