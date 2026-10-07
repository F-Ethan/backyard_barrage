# Backyard Barrage — Modern UI Kit (v2)

**Status:** Draft v2 — Flutter-ready rules for a **new / modern** look (NOT throwback snowball-war / woodsy classic).  
**Audience:** Broad + younger; kid-safe; seasonal but contemporary.  
**Assets:** `assets/images/ui_modern/` (adopt without wiping `assets/images/ui/` yet).  
**Generator:** `scripts/generate_ui_modern.py`  
**Style pointers:** `docs/STYLE.md` UI section → this kit.

---

## Design intent

- Soft product UI (mobile game HUD / shop / pause), not carved wood or thick comic 3D bevels.
- Season identity via **chips + gradients** (cool winter blue / warm mint-summer), not wood frames.
- Type-forward: bold rounded sans titles; generous padding; high-contrast ink on cream / frosted panels.
- Landscape-mobile friendly; compact HUD; no gore; **not** SnowCraft red/green.

---

## Palette (UI v2)

| Role | Hex | Use |
|------|-----|-----|
| Ink | `#1A2332` | Primary text / icons (higher contrast than v1 `#2C3E50`) |
| Ink muted | `#5B6B7C` | Secondary labels, off chips |
| Cream | `#FFF8F0` | Panels, modal sheets |
| Frost white | `#FFFFFFF2` / `#FFFFFF` @ ~95% | Glass HUD chips |
| Player blue | `#3D7CFF` | Primary CTA fill / accents |
| Blue deep | `#2B5FD9` | Primary pressed / shadow tint |
| Violet | `#9B59B6` | Enemy / seasonal accent (sparingly in UI) |
| Balloon pink | `#FF6B9D` | Soft accent (shop sale, hearts optional) |
| Winter cool | `#7EC8FF` → `#3D7CFF` | Winter chip / fort fill gradient |
| Summer mint | `#7DDEB5` → `#4ECDC4` | Summer chip / warm-mint accent (not army green) |
| Heart | `#FF5A6B` | Modern heart fill |
| Coin | `#F1C40F` | Currency |
| Hairline | `#1A2332` @ 12–18% | Soft borders instead of thick outlines |
| Shadow soft | black @ 8–14% blur | Elevation (not hard wood lip) |

Avoid: heavy wood `#8B5E3C` frames, thick comic bevels, classic red-vs-green war UI.

---

## Shape language (Flutter-ready)

| Element | Radius | Elevation / border |
|---------|--------|--------------------|
| Cards / panels | **24–32 pt** (large soft round) | Soft shadow **or** hairline border — pick one, not both heavy |
| Modal sheet | **28–32 pt** corners | Frosted cream; optional top handle hint |
| Primary button | **Stadium / pill** (height/2) | Soft drop shadow; blue fill or cream+blue accent rim |
| Secondary button | Same stadium | Ghost: hairline + transparent/cream soft fill |
| Chips | Pill (height/2) | Season gradient fill when on; muted cream when off |
| HUD chip bg | 16–20 pt | Glass-like frosted rect |
| Fort bar | Slim capsule (~32 pt height visual) | No wood trough |
| Toggle track | Stadium | On = blue; off = muted gray fill |

**Do not:** thick 3D bottom lips, carved wood borders, comic double-outline bevels.

---

## Typography

- **Titles:** Bold rounded sans (Flutter: e.g. rounded / soft geometric family; asset wordmark uses DejaVu Bold as placeholder).
- **Body / HUD:** Medium weight; generous letter-spacing on chips OK.
- **Ink:** `#1A2332` on `#FFF8F0` or frosted white — aim WCAG-ish contrast for landscape phone.
- **Padding:** Prefer 16–24 pt inner padding on cards; 12–16 on buttons; avoid cramped comic balloons.

---

## Components

### Buttons
- **Primary:** Pill `btn_primary_v2.png` (512×160); pressed `btn_primary_pressed_v2.png` — deeper blue, less shadow.
- **Secondary:** Soft outline ghost `btn_secondary_v2.png` — cream/transparent fill, blue or ink hairline.
- Flutter: prefer `StadiumBorder` / `BorderRadius.circular(height/2)`; nine-slice or stretch horizontally.

### Modal / pause / settings
- `panel_modal_v2.png` (1024×768) — frosted cream rounded sheet.
- Clean modal sheet: icon rows, toggle tracks (`toggle_on_v2` / `toggle_off_v2`), close `icon_close_v2`.
- Icons: `icon_pause_v2`, `icon_settings_v2` — simple filled line-ish, ink on transparent.

### Shop
- `shop_card_v2.png` (512×640) — soft elevated card, **transparent art well**, price pill area at bottom.
- Flat card **grid** with soft elevation; price as pill chip (coin + number overlay in Flutter).

### Season chips
- `chip_season_winter_v2.png` / `chip_season_summer_v2.png` (+ `_off`) 256×96.
- Winter: cool blue gradient + snowflake glyph.
- Summer: warm mint–teal gradient + sun glyph (mint, **not** army green).

### HUD
- Compact glass-like bars: `hud_chip_bg_v2.png` clusters hearts/coins.
- Hearts: `heart_v2.png` / `heart_empty_v2.png` (256²) — modern rounded heart, not comic thick outline.
- Coin: `coin_v2.png` — flat gold disc + soft highlight.
- Fort: `fort_bar_empty_v2.png` + `fort_bar_fill_v2.png` (512×64) — slim modern capsule; scale fill width by HP%.

### Wordmark
- `wordmark_backyard_barrage_v2.png` — cleaner modern stacked/single-line title; blue accent underline or soft blob (no wood plaque).

---

## Asset inventory (`assets/images/ui_modern/`)

| File | Size | Notes |
|------|------|-------|
| `btn_primary_v2.png` | 512×160 | Pill, blue fill, soft shadow |
| `btn_primary_pressed_v2.png` | 512×160 | Deeper blue, flattened |
| `btn_secondary_v2.png` | 512×160 | Ghost outline |
| `panel_modal_v2.png` | 1024×768 | Frosted cream sheet |
| `shop_card_v2.png` | 512×640 | Soft card + transparent well + price hint |
| `chip_season_winter_v2.png` | 256×96 | On |
| `chip_season_summer_v2.png` | 256×96 | On |
| `chip_season_winter_off_v2.png` | 256×96 | Off |
| `chip_season_summer_off_v2.png` | 256×96 | Off |
| `fort_bar_empty_v2.png` | 512×64 | Slim trough |
| `fort_bar_fill_v2.png` | 512×64 | Cool blue fill layer |
| `heart_v2.png` | 256×256 | Filled |
| `heart_empty_v2.png` | 256×256 | Outline / empty |
| `coin_v2.png` | 256×256 | Flat modern coin |
| `hud_chip_bg_v2.png` | 256×96 | Glass HUD cluster bg |
| `toggle_on_v2.png` | 256×128 | Blue track + knob |
| `toggle_off_v2.png` | 256×128 | Muted track + knob |
| `icon_pause_v2.png` | 256×256 | |
| `icon_settings_v2.png` | 256×256 | |
| `icon_close_v2.png` | 256×256 | |
| `wordmark_backyard_barrage_v2.png` | 1024×384 | Modern wordmark |

Legacy v1 wood/comic kit remains under `assets/images/ui/` and is not loaded by the live screens. Flutter uses **ui_modern/**.

---

## Flutter adoption notes

1. Point asset paths at `assets/images/ui_modern/` (or copy into Flutter `assets/`).
2. Buttons: horizontal stretch; keep aspect ~3.2:1; center label with 16–20 pt horizontal padding.
3. Modal: 9-slice or `DecoratedBox` with `BorderRadius.circular(28–32)` matching sheet.
4. Fort bar: stack empty + fill; clip fill width by HP fraction; vertical align centers.
5. Season: toggle chip assets on/off; do not tint wood frames.
6. Keep character / world / audio packs unchanged — UI only.

---

## Flutter implementation (modern UI pass)

- Tokens: `lib/ui/barrage_theme.dart` (`BarrageTokens` ThemeExtension, `BarrageMotion`). Palette swatches: `lib/ui/barrage_colors.dart`.
- Type: Fredoka (SIL OFL 1.1) bundled in `assets/fonts/fredoka/` and wired through `ThemeData.textTheme`; the wordmark is set in Fredoka in code.
- Drawn in Flutter (stadiums/radii per this doc): buttons, modal sheet, HUD chips, toggles, season segmented pill, shop cards, wordmark. Still PNG: icons, hearts, coin, fort bar.
- Motion respects `MediaQuery.disableAnimations` (durations collapse to zero).

## Anti-patterns (explicit)

- No heavy wood frames or sandbag UI chrome.
- No thick comic 3D bevel / double-lip buttons as default primary.
- No SnowCraft red/green team UI.
- No gore; hearts are abstract lives, not injury.

---

## Regen

```bash
python3 scripts/generate_ui_modern.py
```
