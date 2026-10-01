#!/usr/bin/env python3
"""Backyard Barrage — MVP UI kit (STYLE.md). Regenerable Pillow drafts.

Sizes (documented in STATUS.md):
  fort bar empty/fill : 512×64
  season chips on/off : 256×96
  shop card frame     : 512×640
  shop card wide      : 768×512
  buttons             : 512×160
  heart / heart empty : 256×256
  coin                : 256×256
  panel modal         : 1024×768
"""
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math

ROOT = Path("/workspace/backyard-barrage")
IMG = ROOT / "assets" / "images" / "ui"

# STYLE.md palette
INK = (44, 62, 80, 255)           # #2C3E50
CREAM = (255, 248, 240, 255)      # #FFF8F0
CREAM_DIM = (230, 222, 210, 255)  # muted cream for off chips
LIP = (200, 190, 175, 255)        # button 3D lip
COIN = (241, 196, 15, 255)        # #F1C40F
COIN_RIM = (200, 150, 20, 255)
HEART = (231, 76, 60, 255)        # #E74C3C
HEART_HL = (255, 180, 170, 200)
WOOD = (139, 94, 60, 255)         # #8B5E3C fort wood
WOOD_LIGHT = (196, 164, 132, 255) # #C4A484
PLAYER = (61, 124, 255, 255)      # #3D7CFF
SKY_W = (168, 212, 240, 255)      # winter chip accent
SKY_S = (255, 200, 87, 255)       # sun warm (PLAYER2-ish)
SUN = (241, 196, 15, 255)
SNOW_CAP = (232, 241, 248, 255)
TRANS = (0, 0, 0, 0)
WHITE = (255, 255, 255, 255)

# Shared outline / radius language (enterprise kit)
OW = 5          # outline weight at button/chip master
RADIUS_BTN = 28
RADIUS_CHIP = 20
RADIUS_PANEL = 48
RADIUS_CARD = 36


def new(w, h, fill=TRANS):
    return Image.new("RGBA", (w, h), fill)


def save(im: Image.Image, name: str):
    path = IMG / name
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, "PNG")
    print(f"wrote {path} ({im.size[0]}x{im.size[1]})")
    return path


def try_font(size: int):
    for path in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    ):
        p = Path(path)
        if p.exists():
            return ImageFont.truetype(str(p), size)
    return ImageFont.load_default()


# ---------------------------------------------------------------------------
# Buttons
# ---------------------------------------------------------------------------

def make_btn_primary(name="btn_primary_draft.png", w=512, h=160):
    """Cream fill, navy outline, slight 3D bottom lip (raised)."""
    im = new(w, h)
    d = ImageDraw.Draw(im)
    # Lip (shadow layer)
    d.rounded_rectangle([16, 24, w - 16, h - 12], radius=RADIUS_BTN, fill=LIP, outline=INK, width=OW)
    # Face
    d.rounded_rectangle([16, 12, w - 16, h - 28], radius=RADIUS_BTN, fill=CREAM, outline=INK, width=OW)
    return save(im, name)


def make_btn_primary_pressed(name="btn_primary_pressed_draft.png", w=512, h=160):
    """Pressed: face sunk into lip, darker cream, thinner top margin."""
    im = new(w, h)
    d = ImageDraw.Draw(im)
    # Flat sunk base
    d.rounded_rectangle([16, 20, w - 16, h - 16], radius=RADIUS_BTN, fill=LIP, outline=INK, width=OW)
    # Face flush / slightly inset
    d.rounded_rectangle([20, 24, w - 20, h - 20], radius=RADIUS_BTN - 4, fill=CREAM_DIM, outline=INK, width=OW)
    return save(im, name)


def make_btn_secondary(name="btn_secondary_draft.png", w=512, h=160):
    """Quieter secondary: thinner lip, soft cream, same outline language."""
    im = new(w, h)
    d = ImageDraw.Draw(im)
    lip2 = (210, 200, 188, 255)
    # Smaller lip
    d.rounded_rectangle([20, 22, w - 20, h - 16], radius=RADIUS_BTN - 4, fill=lip2, outline=INK, width=4)
    d.rounded_rectangle([20, 14, w - 20, h - 28], radius=RADIUS_BTN - 4, fill=CREAM, outline=INK, width=4)
    # Inner hairline to feel quieter / outlined-only feel
    d.rounded_rectangle([28, 22, w - 28, h - 36], radius=RADIUS_BTN - 10, outline=(44, 62, 80, 60), width=2)
    return save(im, name)


# ---------------------------------------------------------------------------
# Fort HP bar
# ---------------------------------------------------------------------------

def make_fort_bar_empty(name="fort_bar_empty_draft.png", w=512, h=64):
    """Wood-framed cream trough for fort HP."""
    im = new(w, h)
    d = ImageDraw.Draw(im)
    # Outer wood frame
    d.rounded_rectangle([4, 6, w - 4, h - 6], radius=16, fill=WOOD, outline=INK, width=4)
    # Inner lighter wood rim
    d.rounded_rectangle([12, 12, w - 12, h - 12], radius=12, fill=WOOD_LIGHT, outline=INK, width=3)
    # Cream empty well
    d.rounded_rectangle([18, 16, w - 18, h - 16], radius=10, fill=CREAM, outline=INK, width=3)
    # Subtle board lines on wood rim (left/right caps)
    for x in (8, w - 10):
        d.line([(x, 10), (x, h - 10)], fill=(100, 70, 45, 180), width=2)
    return save(im, name)


def make_fort_bar_fill(name="fort_bar_fill_draft.png", w=512, h=64):
    """Fill layer only — green-grass HP strip sized to sit inside empty well.
    Transparent outside; engine scales width by HP %.
    """
    im = new(w, h)
    d = ImageDraw.Draw(im)
    # Match empty well inset so composite aligns
    fill = (107, 191, 89, 255)  # GRASS #6BBF59 — healthy fort
    fill_hi = (140, 210, 120, 255)
    d.rounded_rectangle([20, 18, w - 20, h - 18], radius=8, fill=fill, outline=INK, width=2)
    # Soft highlight stripe (flat plane, not gradient photoreal)
    d.rounded_rectangle([24, 20, w - 24, 30], radius=4, fill=fill_hi)
    # Wood end-cap accents so fill reads as fort boards when partial
    d.rectangle([22, 20, 30, h - 20], fill=(139, 94, 60, 120))
    return save(im, name)


# ---------------------------------------------------------------------------
# Season chips
# ---------------------------------------------------------------------------

def _draw_snowflake(d, cx, cy, r, color=INK, width=3):
    """Simple 6-point snowflake."""
    for i in range(6):
        ang = math.radians(i * 60)
        x1 = cx + r * math.cos(ang)
        y1 = cy + r * math.sin(ang)
        d.line([(cx, cy), (x1, y1)], fill=color, width=width)
        # Small side ticks
        mx = cx + r * 0.55 * math.cos(ang)
        my = cy + r * 0.55 * math.sin(ang)
        perp = ang + math.pi / 2
        t = r * 0.28
        d.line(
            [(mx - t * math.cos(perp), my - t * math.sin(perp)),
             (mx + t * math.cos(perp), my + t * math.sin(perp))],
            fill=color, width=max(2, width - 1),
        )
    d.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=color)


def _draw_sun(d, cx, cy, r, fill=SUN, outline=INK, width=3):
    """Chunky sun with rays."""
    # Rays
    for i in range(8):
        ang = math.radians(i * 45)
        x0 = cx + (r + 2) * math.cos(ang)
        y0 = cy + (r + 2) * math.sin(ang)
        x1 = cx + (r + 12) * math.cos(ang)
        y1 = cy + (r + 12) * math.sin(ang)
        d.line([(x0, y0), (x1, y1)], fill=outline, width=width + 1)
        d.line([(x0, y0), (x1, y1)], fill=fill, width=width - 1)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill, outline=outline, width=width)
    # Tiny highlight
    d.ellipse([cx - r // 2, cy - r // 2, cx - 2, cy - 2], fill=(255, 230, 140, 200))


def make_season_chip(name, season="winter", selected=True, w=256, h=96):
    im = new(w, h)
    d = ImageDraw.Draw(im)
    if selected:
        fill = CREAM
        accent = SKY_W if season == "winter" else (255, 236, 180, 255)
        ow = OW
        # Selected: cream + accent stripe + full ink outline + lip
        d.rounded_rectangle([6, 14, w - 6, h - 6], radius=RADIUS_CHIP, fill=LIP, outline=INK, width=ow)
        d.rounded_rectangle([6, 6, w - 6, h - 14], radius=RADIUS_CHIP, fill=fill, outline=INK, width=ow)
        # Accent pill behind icon
        d.rounded_rectangle([14, 16, 78, h - 24], radius=14, fill=accent, outline=INK, width=3)
    else:
        # Dim / unselected — flatter, no lip, muted fill + soft ink
        fill = (215, 208, 198, 220)
        ow = 3
        d.rounded_rectangle([10, 14, w - 10, h - 14], radius=RADIUS_CHIP - 4, fill=fill, outline=(44, 62, 80, 90), width=ow)
        d.rounded_rectangle([18, 22, 70, h - 22], radius=10, fill=(200, 195, 188, 200), outline=(44, 62, 80, 70), width=2)

    icon_cx, icon_cy = 44 if not selected else 46, h // 2 - (4 if selected else 0)
    ink = INK if selected else (44, 62, 80, 90)
    if season == "winter":
        _draw_snowflake(d, icon_cx, icon_cy, 16 if not selected else 18,
                        color=(120, 145, 165, 160) if not selected else INK,
                        width=2 if not selected else 3)
    else:
        _draw_sun(d, icon_cx, icon_cy, 12 if not selected else 14,
                  fill=(210, 190, 120, 160) if not selected else SUN,
                  outline=(44, 62, 80, 100) if not selected else INK,
                  width=2 if not selected else 3)

    # Label
    font = try_font(28 if selected else 24)
    label = "WINTER" if season == "winter" else "SUMMER"
    tx, ty = 150, h // 2 - (4 if selected else 0)
    if selected:
        d.text((tx + 2, ty + 2), label, font=font, fill=(44, 62, 80, 70), anchor="mm")
        d.text((tx, ty), label, font=font, fill=INK, anchor="mm")
    else:
        d.text((tx, ty), label, font=font, fill=(44, 62, 80, 90), anchor="mm")
    return save(im, name)


# ---------------------------------------------------------------------------
# Shop card frames
# ---------------------------------------------------------------------------

def make_shop_card(name, w=512, h=640, wide=False):
    """Cream panel with wood border; transparent center for item art."""
    if wide:
        w, h = 768, 512
    im = new(w, h)
    d = ImageDraw.Draw(im)

    # Outer wood frame
    d.rounded_rectangle([8, 8, w - 8, h - 8], radius=RADIUS_CARD, fill=WOOD, outline=INK, width=6)
    # Light wood inner bevel
    d.rounded_rectangle([22, 22, w - 22, h - 22], radius=RADIUS_CARD - 10, fill=WOOD_LIGHT, outline=INK, width=4)
    # Cream panel
    d.rounded_rectangle([36, 36, w - 36, h - 36], radius=RADIUS_CARD - 16, fill=CREAM, outline=INK, width=4)

    # Transparent art well (punch hole in center)
    # Build mask: keep frame, clear center rounded rect
    art_pad_x = int(w * 0.12)
    art_top = int(h * 0.12)
    art_bot = int(h * (0.62 if not wide else 0.72))
    well = [art_pad_x, art_top, w - art_pad_x, art_bot]

    # Draw well as "empty" — use destination-out by compositing
    hole = new(w, h, TRANS)
    hd = ImageDraw.Draw(hole)
    # Opaque where we want to keep
    hd.rectangle([0, 0, w, h], fill=(255, 255, 255, 255))
    hd.rounded_rectangle(well, radius=20, fill=(0, 0, 0, 0))
    # Also leave a price strip area at bottom as cream (already cream)
    # Apply alpha: where hole is transparent, clear im
    # Simpler: redraw cream around well, then well stays as drawn cream —
    # Task wants transparent center — so punch it.
    r, g, b, a = im.split()
    # Create alpha mask for hole region
    alpha_mask = Image.new("L", (w, h), 255)
    ad = ImageDraw.Draw(alpha_mask)
    ad.rounded_rectangle(well, radius=20, fill=0)
    # Combine: existing alpha * mask conceptually — set alpha to 0 in well
    from PIL import ImageChops
    a = ImageChops.multiply(a, alpha_mask)
    im = Image.merge("RGBA", (r, g, b, a))
    d = ImageDraw.Draw(im)

    # Wood nail dots at corners of art well (decorative)
    for nx, ny in (
        (well[0] - 8, well[1] - 8),
        (well[2] + 8, well[1] - 8),
        (well[0] - 8, well[3] + 8),
        (well[2] + 8, well[3] + 8),
    ):
        d.ellipse([nx - 5, ny - 5, nx + 5, ny + 5], fill=WOOD, outline=INK, width=2)

    # Inner dashed-feel border for art well (ink outline on cream edge)
    d.rounded_rectangle(well, radius=20, outline=INK, width=3)

    # Price / label strip hint at bottom (cream stays; faint wood rule)
    strip_y = int(h * 0.72) if not wide else int(h * 0.78)
    d.line([(48, strip_y), (w - 48, strip_y)], fill=WOOD_LIGHT, width=3)
    d.line([(48, strip_y + 3), (w - 48, strip_y + 3)], fill=INK, width=1)

    return save(im, name)


# ---------------------------------------------------------------------------
# Hearts & coin (unified kit)
# ---------------------------------------------------------------------------

def _heart_shape(d, s, fill, outline=INK, width=5, highlight=True):
    """Unified heart geometry for full + empty."""
    d.ellipse([int(s * 0.12), int(s * 0.18), int(s * 0.55), int(s * 0.58)], fill=fill, outline=outline, width=width)
    d.ellipse([int(s * 0.45), int(s * 0.18), int(s * 0.88), int(s * 0.58)], fill=fill, outline=outline, width=width)
    d.polygon([
        (int(s * 0.15), int(s * 0.42)),
        (int(s * 0.85), int(s * 0.42)),
        (int(s * 0.50), int(s * 0.88)),
    ], fill=fill, outline=outline)
    d.line([(int(s * 0.15), int(s * 0.42)), (int(s * 0.50), int(s * 0.88))], fill=outline, width=width)
    d.line([(int(s * 0.85), int(s * 0.42)), (int(s * 0.50), int(s * 0.88))], fill=outline, width=width)
    # Cover interior seam lines by re-filling lobes without outline
    d.ellipse([int(s * 0.12) + width, int(s * 0.18) + width, int(s * 0.55) - width, int(s * 0.58) - width], fill=fill)
    d.ellipse([int(s * 0.45) + width, int(s * 0.18) + width, int(s * 0.88) - width, int(s * 0.58) - width], fill=fill)
    d.polygon([
        (int(s * 0.18), int(s * 0.40)),
        (int(s * 0.82), int(s * 0.40)),
        (int(s * 0.50), int(s * 0.82)),
    ], fill=fill)
    if highlight and fill[3] > 0 and fill[:3] != CREAM[:3]:
        d.ellipse([int(s * 0.22), int(s * 0.28), int(s * 0.38), int(s * 0.42)], fill=HEART_HL)


def make_heart(name="heart_draft.png", size=256):
    im = new(size, size)
    d = ImageDraw.Draw(im)
    _heart_shape(d, size, HEART, outline=INK, width=5, highlight=True)
    return save(im, name)


def make_heart_empty(name="heart_empty_draft.png", size=256):
    """Empty HP heart — cream fill + ink outline (or transparent fill with thick outline)."""
    im = new(size, size)
    d = ImageDraw.Draw(im)
    # Cream fill so it reads on dark/light HUDs, ink outline
    _heart_shape(d, size, CREAM, outline=INK, width=5, highlight=False)
    # Inner dashed feel — thinner second outline in wood-cream
    s = size
    d.ellipse([int(s * 0.20), int(s * 0.26), int(s * 0.50), int(s * 0.52)], outline=(44, 62, 80, 80), width=2)
    d.ellipse([int(s * 0.50), int(s * 0.26), int(s * 0.80), int(s * 0.52)], outline=(44, 62, 80, 80), width=2)
    return save(im, name)


def make_coin(name="coin_draft.png", size=256):
    im = new(size, size)
    d = ImageDraw.Draw(im)
    m = size // 2
    r = int(size * 0.40)
    d.ellipse([m - r, m - r, m + r, m + r], fill=COIN, outline=INK, width=6)
    d.ellipse([m - r + 14, m - r + 14, m + r - 14, m + r - 14], outline=COIN_RIM, width=4)
    font = try_font(90)
    d.text((m, m), "$", font=font, fill=INK, anchor="mm")
    return save(im, name)


# ---------------------------------------------------------------------------
# Modal panel
# ---------------------------------------------------------------------------

def make_panel_modal(name="panel_modal_draft.png", w=1024, h=768):
    """Large cream modal, 9-slice friendly (generous margins, even corners)."""
    im = new(w, h)
    d = ImageDraw.Draw(im)
    # Soft outer shadow lip
    d.rounded_rectangle([24, 36, w - 24, h - 16], radius=RADIUS_PANEL, fill=LIP, outline=INK, width=6)
    # Main cream face
    d.rounded_rectangle([24, 20, w - 24, h - 36], radius=RADIUS_PANEL, fill=CREAM, outline=INK, width=6)
    # Inner guide (helps 9-slice / content inset) — very subtle
    d.rounded_rectangle([48, 44, w - 48, h - 60], radius=RADIUS_PANEL - 16, outline=(44, 62, 80, 40), width=2)
    # Top accent wood rule (ties to shop cards)
    d.rounded_rectangle([56, 52, w - 56, 68], radius=6, fill=WOOD_LIGHT, outline=WOOD, width=2)
    return save(im, name)


# ---------------------------------------------------------------------------
# Showcase composite (fort bar empty + fill) — optional helper for review
# ---------------------------------------------------------------------------

def make_fort_bar_showcase(name="_showcase_fort_bar_draft.png", fill_pct=0.7):
    """Composite for parent report only — not a required deliverable name."""
    empty = Image.open(IMG / "fort_bar_empty_draft.png").convert("RGBA")
    fill = Image.open(IMG / "fort_bar_fill_draft.png").convert("RGBA")
    w, h = empty.size
    # Clip fill to percentage width (from left, inside well)
    clip_w = int(20 + (w - 40) * fill_pct)
    cropped = fill.crop((0, 0, clip_w, h))
    out = empty.copy()
    out.paste(cropped, (0, 0), cropped)
    return save(out, name)


def main():
    IMG.mkdir(parents=True, exist_ok=True)

    # Re-export unified kit basics
    make_btn_primary()
    make_btn_primary_pressed()
    make_btn_secondary()
    make_heart()
    make_heart_empty()
    make_coin()

    # Fort bar
    make_fort_bar_empty()
    make_fort_bar_fill()

    # Season chips
    make_season_chip("chip_season_winter_draft.png", season="winter", selected=True)
    make_season_chip("chip_season_summer_draft.png", season="summer", selected=True)
    make_season_chip("chip_season_winter_off_draft.png", season="winter", selected=False)
    make_season_chip("chip_season_summer_off_draft.png", season="summer", selected=False)

    # Shop frames
    make_shop_card("shop_card_frame_draft.png", wide=False)
    make_shop_card("shop_card_frame_wide_draft.png", wide=True)

    # Modal
    make_panel_modal()

    # Review composite
    # make_fort_bar_showcase()  # review helper; not a kit deliverable

    print("DONE UI kit")


if __name__ == "__main__":
    main()
