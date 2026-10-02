#!/usr/bin/env python3
"""Backyard Barrage — Modern UI kit v2 (UI_MODERN.md). Soft, pill, glass — no wood frames.

Output: assets/images/ui_modern/
Regen: /workspace/.venv-art/bin/python scripts/generate_ui_modern.py
"""
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import math

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "images" / "ui_modern"

# UI_MODERN.md palette
INK = (26, 35, 50, 255)            # #1A2332
INK_MUTED = (91, 107, 124, 255)    # #5B6B7C
CREAM = (255, 248, 240, 255)       # #FFF8F0
CREAM_SOFT = (255, 252, 248, 240)  # frosted cream
WHITE = (255, 255, 255, 255)
BLUE = (61, 124, 255, 255)         # #3D7CFF
BLUE_DEEP = (43, 95, 217, 255)     # #2B5FD9
BLUE_LIGHT = (126, 200, 255, 255)  # #7EC8FF
MINT = (125, 222, 181, 255)        # #7DDEB5
TEAL = (78, 205, 196, 255)         # #4ECDC4
HEART = (255, 90, 107, 255)        # #FF5A6B
HEART_EMPTY = (255, 200, 205, 255)
COIN = (241, 196, 15, 255)         # #F1C40F
COIN_RIM = (210, 160, 20, 255)
TRANS = (0, 0, 0, 0)
SHADOW = (0, 0, 0, 36)             # ~14% soft
HAIRLINE = (26, 35, 50, 40)        # ink @ ~16%
TRACK_OFF = (200, 208, 218, 255)
KNOB = (255, 255, 255, 255)


def new(w, h, fill=TRANS):
    return Image.new("RGBA", (w, h), fill)


def save(im: Image.Image, name: str):
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    im.save(path, "PNG")
    print(f"wrote {path} ({im.size[0]}x{im.size[1]})")
    return path


def try_font(size: int):
    for path in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf",
    ):
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def soft_shadow_layer(w, h, box, radius, blur=10, alpha=36):
    """Soft drop shadow for a rounded rect; returns RGBA layer to composite under face."""
    sh = new(w, h)
    d = ImageDraw.Draw(sh)
    d.rounded_rectangle(box, radius=radius, fill=(0, 0, 0, alpha))
    return sh.filter(ImageFilter.GaussianBlur(blur))



def composite_rounded(base, box, radius, fill):
    """Alpha-composite a rounded rect onto base (respects fill alpha)."""
    layer = new(base.size[0], base.size[1])
    ImageDraw.Draw(layer).rounded_rectangle(box, radius=radius, fill=fill)
    return Image.alpha_composite(base, layer)


def composite_ellipse(base, box, fill):
    layer = new(base.size[0], base.size[1])
    ImageDraw.Draw(layer).ellipse(box, fill=fill)
    return Image.alpha_composite(base, layer)

def lerp_color(c0, c1, t):
    return tuple(int(c0[i] + (c1[i] - c0[i]) * t) for i in range(4))


def fill_hgradient(im, box, c0, c1, radius):
    """Horizontal gradient rounded rect via mask."""
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    if w <= 0 or h <= 0:
        return
    grad = new(w, h)
    gd = ImageDraw.Draw(grad)
    for x in range(w):
        t = x / max(w - 1, 1)
        gd.line([(x, 0), (x, h)], fill=lerp_color(c0, c1, t))
    mask = new(w, h)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, fill=WHITE)
    im.paste(grad, (x0, y0), mask)


# ---------------------------------------------------------------------------
# Buttons — stadium / pill
# ---------------------------------------------------------------------------

def make_btn_primary(name="btn_primary_v2.png", w=512, h=160):
    im = new(w, h)
    # Soft shadow under pill
    r = h // 2 - 8
    face = [24, 20, w - 24, h - 28]
    sh = soft_shadow_layer(w, h, [face[0], face[1] + 10, face[2], face[3] + 10], r, blur=12, alpha=40)
    im = Image.alpha_composite(im, sh)
    d = ImageDraw.Draw(im)
    # Pill body — blue fill
    d.rounded_rectangle(face, radius=r, fill=BLUE)
    # Soft top sheen (composite so blue shows through)
    im = composite_rounded(
        im,
        [face[0] + 12, face[1] + 8, face[2] - 12, face[1] + 36],
        r - 10,
        (255, 255, 255, 55),
    )
    d = ImageDraw.Draw(im)
    d.rounded_rectangle(face, radius=r, outline=(255, 248, 240, 100), width=3)
    return save(im, name)


def make_btn_primary_pressed(name="btn_primary_pressed_v2.png", w=512, h=160):
    im = new(w, h)
    r = h // 2 - 8
    face = [24, 28, w - 24, h - 20]  # sunk slightly
    d = ImageDraw.Draw(im)
    d.rounded_rectangle(face, radius=r, fill=BLUE_DEEP)
    im = composite_rounded(
        im,
        [face[0] + 12, face[1] + 6, face[2] - 12, face[1] + 28],
        r - 10,
        (255, 255, 255, 30),
    )
    return save(im, name)


def make_btn_secondary(name="btn_secondary_v2.png", w=512, h=160):
    im = new(w, h)
    r = h // 2 - 8
    face = [24, 24, w - 24, h - 24]
    # Soft cream fill ghost
    sh = soft_shadow_layer(w, h, [face[0], face[1] + 6, face[2], face[3] + 6], r, blur=8, alpha=22)
    im = Image.alpha_composite(im, sh)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle(face, radius=r, fill=(255, 248, 240, 200))
    d.rounded_rectangle(face, radius=r, outline=BLUE, width=4)
    # Inner soft hairline
    d.rounded_rectangle(
        [face[0] + 6, face[1] + 6, face[2] - 6, face[3] - 6],
        radius=r - 6,
        outline=(61, 124, 255, 50),
        width=2,
    )
    return save(im, name)


# ---------------------------------------------------------------------------
# Modal panel
# ---------------------------------------------------------------------------

def make_panel_modal(name="panel_modal_v2.png", w=1024, h=768):
    im = new(w, h)
    margin = 48
    box = [margin, margin, w - margin, h - margin]
    radius = 32
    sh = soft_shadow_layer(w, h, [box[0] + 4, box[1] + 12, box[2] + 4, box[3] + 12], radius, blur=18, alpha=45)
    im = Image.alpha_composite(im, sh)
    d = ImageDraw.Draw(im)
    # Frosted cream sheet
    d.rounded_rectangle(box, radius=radius, fill=CREAM)
    # Soft top frost (composited white sheen, not opaque gray bar)
    im = composite_rounded(
        im,
        [box[0] + 6, box[1] + 6, box[2] - 6, box[1] + 56],
        26,
        (255, 255, 255, 50),
    )
    d = ImageDraw.Draw(im)
    d.rounded_rectangle(box, radius=radius, outline=HAIRLINE, width=3)
    hx0, hx1 = w // 2 - 48, w // 2 + 48
    d.rounded_rectangle([hx0, margin + 18, hx1, margin + 28], radius=5, fill=(26, 35, 50, 50))
    return save(im, name)


# ---------------------------------------------------------------------------
# Shop card
# ---------------------------------------------------------------------------

def make_shop_card(name="shop_card_v2.png", w=512, h=640):
    """Soft elevated card with fully transparent art well + price pill hint."""
    im = new(w, h)
    box = [28, 24, w - 28, h - 24]
    radius = 28
    well = [48, 48, w - 48, h - 180]
    well_r = 20
    price_y0, price_y1 = h - 150, h - 70

    # Build opaque cream face with well punched out
    face = new(w, h)
    fd = ImageDraw.Draw(face)
    fd.rounded_rectangle(box, radius=radius, fill=CREAM)
    # Punch well to transparent
    well_mask = new(w, h)
    ImageDraw.Draw(well_mask).rounded_rectangle(well, radius=well_r, fill=WHITE)
    px = face.load()
    wm = well_mask.load()
    for yy in range(h):
        for xx in range(w):
            if wm[xx, yy][3] > 0:
                px[xx, yy] = (0, 0, 0, 0)

    # Soft shadow only under non-well card pixels (mask shadow by card-without-well)
    card_mask = new(w, h)
    ImageDraw.Draw(card_mask).rounded_rectangle(box, radius=radius, fill=WHITE)
    cm = card_mask.load()
    for yy in range(h):
        for xx in range(w):
            if wm[xx, yy][3] > 0:
                cm[xx, yy] = (0, 0, 0, 0)
    sh_raw = new(w, h)
    ImageDraw.Draw(sh_raw).rounded_rectangle(
        [box[0], box[1] + 10, box[2], box[3] + 10], radius=radius, fill=(0, 0, 0, 38)
    )
    sh_raw = sh_raw.filter(ImageFilter.GaussianBlur(14))
    # Keep shadow only where card body exists (approx: full card footprint for elevation)
    full_card_mask = new(w, h)
    ImageDraw.Draw(full_card_mask).rounded_rectangle(box, radius=radius, fill=WHITE)
    sh = new(w, h)
    sh.paste(sh_raw, (0, 0), full_card_mask)

    result = Image.alpha_composite(im, sh)
    result = Image.alpha_composite(result, face)
    rd2 = ImageDraw.Draw(result)
    rd2.rounded_rectangle(box, radius=radius, outline=HAIRLINE, width=2)
    rd2.rounded_rectangle(well, radius=well_r, outline=(26, 35, 50, 30), width=2)
    # Price pill on cream footer (below well)
    rd2.rounded_rectangle(
        [64, price_y0, w - 64, price_y1],
        radius=40,
        fill=(61, 124, 255, 40),
    )
    # Note: Draw with alpha overwrites — composite price fill
    result = composite_rounded(
        result, [64, price_y0, w - 64, price_y1], 40, (61, 124, 255, 36)
    )
    rd2 = ImageDraw.Draw(result)
    rd2.rounded_rectangle(
        [64, price_y0, w - 64, price_y1],
        radius=40,
        outline=(61, 124, 255, 110),
        width=2,
    )
    cx, cy, cr = 110, (price_y0 + price_y1) // 2, 22
    rd2.ellipse([cx - cr, cy - cr, cx + cr, cy + cr], fill=COIN)
    result = composite_ellipse(
        result, [cx - cr + 5, cy - cr + 4, cx + 2, cy - 2], (255, 255, 255, 120)
    )
    rd2 = ImageDraw.Draw(result)
    rd2.rounded_rectangle([150, cy - 10, w - 90, cy + 10], radius=8, fill=(26, 35, 50, 40))
    # Ensure art well is fully transparent (no shadow bleed)
    clear_mask = new(w, h)
    ImageDraw.Draw(clear_mask).rounded_rectangle(well, radius=well_r, fill=WHITE)
    rp = result.load()
    cm = clear_mask.load()
    for yy in range(h):
        for xx in range(w):
            if cm[xx, yy][3] > 128:
                rp[xx, yy] = (0, 0, 0, 0)
    # Re-draw well rim on top of cleared area
    rd2 = ImageDraw.Draw(result)
    rd2.rounded_rectangle(well, radius=well_r, outline=(26, 35, 50, 35), width=2)
    return save(result, name)


# ---------------------------------------------------------------------------
# Season chips
# ---------------------------------------------------------------------------

def _snowflake(d, cx, cy, size, color):
    for ang in range(0, 360, 60):
        rad = math.radians(ang)
        x2 = cx + size * math.cos(rad)
        y2 = cy + size * math.sin(rad)
        d.line([(cx, cy), (x2, y2)], fill=color, width=3)
        # small branches
        mid = 0.55
        mx, my = cx + size * mid * math.cos(rad), cy + size * mid * math.sin(rad)
        for da in (-35, 35):
            r2 = math.radians(ang + da)
            d.line([(mx, my), (mx + size * 0.35 * math.cos(r2), my + size * 0.35 * math.sin(r2))], fill=color, width=2)


def _sun(d, cx, cy, r, color):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)
    for ang in range(0, 360, 45):
        rad = math.radians(ang)
        x1 = cx + (r + 4) * math.cos(rad)
        y1 = cy + (r + 4) * math.sin(rad)
        x2 = cx + (r + 14) * math.cos(rad)
        y2 = cy + (r + 14) * math.sin(rad)
        d.line([(x1, y1), (x2, y2)], fill=color, width=3)


def make_chip(name, on, winter, w=256, h=96):
    im = new(w, h)
    r = h // 2 - 4
    box = [8, 8, w - 8, h - 8]
    if on:
        sh = soft_shadow_layer(w, h, [box[0], box[1] + 4, box[2], box[3] + 4], r, blur=6, alpha=30)
        im = Image.alpha_composite(im, sh)
        if winter:
            fill_hgradient(im, box, BLUE_LIGHT + (255,), BLUE, r)
        else:
            fill_hgradient(im, box, MINT, TEAL, r)
        d = ImageDraw.Draw(im)
        d.rounded_rectangle(box, radius=r, outline=(255, 255, 255, 100), width=2)
        icon_c = WHITE
    else:
        d = ImageDraw.Draw(im)
        d.rounded_rectangle(box, radius=r, fill=(240, 236, 230, 220))
        d.rounded_rectangle(box, radius=r, outline=(26, 35, 50, 35), width=2)
        icon_c = INK_MUTED

    d = ImageDraw.Draw(im)
    cx, cy = 44, h // 2
    if winter:
        _snowflake(d, cx, cy, 16, icon_c)
    else:
        _sun(d, cx, cy, 10, icon_c if on else INK_MUTED)
    # Soft label bar hint (engine overlays text)
    d.rounded_rectangle([72, h // 2 - 10, w - 28, h // 2 + 10], radius=8, fill=(255, 255, 255, 70 if on else 40))
    return save(im, name)


# ---------------------------------------------------------------------------
# Fort bars — slim modern
# ---------------------------------------------------------------------------

def make_fort_bar_empty(name="fort_bar_empty_v2.png", w=512, h=64):
    im = new(w, h)
    box = [8, 14, w - 8, h - 14]
    r = (box[3] - box[1]) // 2
    sh = soft_shadow_layer(w, h, [box[0], box[1] + 3, box[2], box[3] + 3], r, blur=4, alpha=28)
    im = Image.alpha_composite(im, sh)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle(box, radius=r, fill=(255, 255, 255, 200))
    d.rounded_rectangle(box, radius=r, outline=HAIRLINE, width=2)
    # Inner frosted well
    d.rounded_rectangle([12, 18, w - 12, h - 18], radius=r - 4, fill=(230, 236, 244, 180))
    return save(im, name)


def make_fort_bar_fill(name="fort_bar_fill_v2.png", w=512, h=64):
    im = new(w, h)
    box = [14, 20, w - 14, h - 20]
    r = (box[3] - box[1]) // 2
    fill_hgradient(im, box, BLUE_LIGHT + (255,), BLUE, r)
    im = composite_rounded(
        im,
        [box[0] + 6, box[1] + 2, box[2] - 6, box[1] + 10],
        max(r - 2, 2),
        (255, 255, 255, 70),
    )
    return save(im, name)


# ---------------------------------------------------------------------------
# Heart / coin
# ---------------------------------------------------------------------------

def _heart_poly(cx, cy, s):
    """Return polygon points for a modern rounded heart."""
    pts = []
    for t in range(0, 360, 3):
        rad = math.radians(t)
        # classic parametric heart, scaled
        x = 16 * math.sin(rad) ** 3
        y = -(13 * math.cos(rad) - 5 * math.cos(2 * rad) - 2 * math.cos(3 * rad) - math.cos(4 * rad))
        pts.append((cx + x * s / 16, cy + y * s / 16))
    return pts


def make_heart(name="heart_v2.png", empty=False, w=256, h=256):
    im = new(w, h)
    cx, cy = w // 2, h // 2 + 8
    pts = _heart_poly(cx, cy, 95)
    # Soft shadow
    sh = new(w, h)
    ImageDraw.Draw(sh).polygon(pts, fill=(0, 0, 0, 40))
    sh = sh.filter(ImageFilter.GaussianBlur(6))
    # offset shadow
    offset = new(w, h)
    offset.paste(sh, (0, 4))
    im = Image.alpha_composite(im, offset)
    d = ImageDraw.Draw(im)
    if empty:
        d.polygon(pts, fill=(255, 248, 240, 220), outline=HEART, width=6)
        # inner empty
        pts_in = _heart_poly(cx, cy, 70)
        d.polygon(pts_in, fill=TRANS)
        # re-draw as outline-only: punch center
        mask = new(w, h)
        ImageDraw.Draw(mask).polygon(pts, fill=WHITE)
        inner = new(w, h)
        ImageDraw.Draw(inner).polygon(_heart_poly(cx, cy, 72), fill=WHITE)
        # Rebuild empty heart as stroke ring
        im2 = new(w, h)
        im2 = Image.alpha_composite(im2, offset)
        d2 = ImageDraw.Draw(im2)
        d2.polygon(pts, fill=(255, 200, 205, 80), outline=HEART, width=8)
        # soft inner rim
        d2.polygon(_heart_poly(cx, cy, 78), outline=(255, 90, 107, 100), width=3)
        return save(im2, name)
    else:
        d.polygon(pts, fill=HEART)
        # highlight
        d.ellipse([cx - 50, cy - 55, cx - 10, cy - 20], fill=(255, 255, 255, 90))
        return save(im, name)


def make_coin(name="coin_v2.png", w=256, h=256):
    im = new(w, h)
    cx, cy, r = w // 2, h // 2, 90
    sh = new(w, h)
    ImageDraw.Draw(sh).ellipse([cx - r, cy - r + 6, cx + r, cy + r + 6], fill=(0, 0, 0, 40))
    sh = sh.filter(ImageFilter.GaussianBlur(8))
    im = Image.alpha_composite(im, sh)
    d = ImageDraw.Draw(im)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=COIN)
    d.ellipse([cx - r + 8, cy - r + 8, cx + r - 8, cy + r - 8], outline=COIN_RIM, width=5)
    # Flat modern "$" or star mark — soft circle + bar
    d.ellipse([cx - 28, cy - 28, cx + 28, cy + 28], fill=(255, 230, 120, 255))
    d.rounded_rectangle([cx - 8, cy - 36, cx + 8, cy + 36], radius=4, fill=COIN_RIM)
    d.rounded_rectangle([cx - 22, cy - 10, cx + 22, cy + 4], radius=3, fill=COIN_RIM)
    # highlight
    d.ellipse([cx - 55, cy - 70, cx - 10, cy - 30], fill=(255, 255, 255, 100))
    return save(im, name)


# ---------------------------------------------------------------------------
# HUD chip bg
# ---------------------------------------------------------------------------

def make_hud_chip_bg(name="hud_chip_bg_v2.png", w=256, h=96):
    im = new(w, h)
    box = [8, 12, w - 8, h - 12]
    r = 18
    sh = soft_shadow_layer(w, h, [box[0], box[1] + 3, box[2], box[3] + 3], r, blur=5, alpha=30)
    im = Image.alpha_composite(im, sh)
    d = ImageDraw.Draw(im)
    # Glass frosted white
    d.rounded_rectangle(box, radius=r, fill=(255, 255, 255, 210))
    d.rounded_rectangle(box, radius=r, outline=(255, 255, 255, 160), width=2)
    # subtle top frost
    d.rounded_rectangle(
        [box[0] + 3, box[1] + 2, box[2] - 3, box[1] + 22],
        radius=12,
        fill=(255, 255, 255, 70),
    )
    d.rounded_rectangle(box, radius=r, outline=(26, 35, 50, 25), width=1)
    return save(im, name)


# ---------------------------------------------------------------------------
# Toggles
# ---------------------------------------------------------------------------

def make_toggle(name, on, w=256, h=128):
    im = new(w, h)
    # Track stadium
    track = [24, 36, w - 24, h - 36]
    tr = (track[3] - track[1]) // 2
    d = ImageDraw.Draw(im)
    if on:
        fill_hgradient(im, track, BLUE_LIGHT + (255,), BLUE, tr)
    else:
        d.rounded_rectangle(track, radius=tr, fill=TRACK_OFF)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle(track, radius=tr, outline=(26, 35, 50, 30), width=2)
    # Knob
    kr = tr - 6
    if on:
        kx = track[2] - tr
    else:
        kx = track[0] + tr
    ky = (track[1] + track[3]) // 2
    # knob shadow
    sh = new(w, h)
    ImageDraw.Draw(sh).ellipse([kx - kr, ky - kr + 3, kx + kr, ky + kr + 3], fill=(0, 0, 0, 50))
    sh = sh.filter(ImageFilter.GaussianBlur(4))
    im = Image.alpha_composite(im, sh)
    d = ImageDraw.Draw(im)
    d.ellipse([kx - kr, ky - kr, kx + kr, ky + kr], fill=KNOB)
    d.ellipse([kx - kr, ky - kr, kx + kr, ky + kr], outline=(26, 35, 50, 35), width=2)
    d.ellipse([kx - kr + 6, ky - kr + 4, kx - 4, ky - 2], fill=(255, 255, 255, 180))
    return save(im, name)


# ---------------------------------------------------------------------------
# Icons — line-ish filled
# ---------------------------------------------------------------------------

def make_icon_pause(name="icon_pause_v2.png", w=256, h=256):
    im = new(w, h)
    # Soft circle bg
    d = ImageDraw.Draw(im)
    cx, cy, r = w // 2, h // 2, 100
    sh = new(w, h)
    ImageDraw.Draw(sh).ellipse([cx - r, cy - r + 4, cx + r, cy + r + 4], fill=(0, 0, 0, 30))
    sh = sh.filter(ImageFilter.GaussianBlur(6))
    im = Image.alpha_composite(im, sh)
    d = ImageDraw.Draw(im)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255, 230))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=HAIRLINE, width=3)
    # Two bars
    bw, bh = 28, 88
    gap = 22
    d.rounded_rectangle([cx - gap - bw, cy - bh // 2, cx - gap, cy + bh // 2], radius=8, fill=INK)
    d.rounded_rectangle([cx + gap, cy - bh // 2, cx + gap + bw, cy + bh // 2], radius=8, fill=INK)
    return save(im, name)


def make_icon_settings(name="icon_settings_v2.png", w=256, h=256):
    im = new(w, h)
    cx, cy, r = w // 2, h // 2, 100
    sh = new(w, h)
    ImageDraw.Draw(sh).ellipse([cx - r, cy - r + 4, cx + r, cy + r + 4], fill=(0, 0, 0, 30))
    sh = sh.filter(ImageFilter.GaussianBlur(6))
    im = Image.alpha_composite(im, sh)
    d = ImageDraw.Draw(im)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255, 230))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=HAIRLINE, width=3)
    # Gear: outer teeth via rotated rects + hub
    teeth = 8
    for i in range(teeth):
        ang = math.radians(i * (360 / teeth))
        # tooth as rounded rect along radius
        tx = cx + 58 * math.cos(ang)
        ty = cy + 58 * math.sin(ang)
        tw, th = 22, 28
        # approximate tooth with ellipse
        d.ellipse([tx - 14, ty - 14, tx + 14, ty + 14], fill=INK)
    d.ellipse([cx - 48, cy - 48, cx + 48, cy + 48], fill=INK)
    d.ellipse([cx - 22, cy - 22, cx + 22, cy + 22], fill=WHITE)
    d.ellipse([cx - 14, cy - 14, cx + 14, cy + 14], fill=INK)
    return save(im, name)


def make_icon_close(name="icon_close_v2.png", w=256, h=256):
    im = new(w, h)
    cx, cy, r = w // 2, h // 2, 100
    sh = new(w, h)
    ImageDraw.Draw(sh).ellipse([cx - r, cy - r + 4, cx + r, cy + r + 4], fill=(0, 0, 0, 30))
    sh = sh.filter(ImageFilter.GaussianBlur(6))
    im = Image.alpha_composite(im, sh)
    d = ImageDraw.Draw(im)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255, 230))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=HAIRLINE, width=3)
    # X
    s = 48
    lw = 14
    for dx, dy in ((-1, -1), (-1, 1)):
        # draw thick line via polygon
        pass
    # two diagonals as thick lines
    d.line([(cx - s, cy - s), (cx + s, cy + s)], fill=INK, width=lw)
    d.line([(cx + s, cy - s), (cx - s, cy + s)], fill=INK, width=lw)
    # round caps
    for px, py in [(cx - s, cy - s), (cx + s, cy + s), (cx + s, cy - s), (cx - s, cy + s)]:
        d.ellipse([px - lw // 2, py - lw // 2, px + lw // 2, py + lw // 2], fill=INK)
    return save(im, name)


# ---------------------------------------------------------------------------
# Wordmark
# ---------------------------------------------------------------------------

def make_wordmark(name="wordmark_backyard_barrage_v2.png", w=1024, h=384):
    im = new(w, h)
    # Soft accent blob behind text
    blob = new(w, h)
    bd = ImageDraw.Draw(blob)
    bd.rounded_rectangle([80, 60, w - 80, h - 60], radius=48, fill=(61, 124, 255, 28))
    blob = blob.filter(ImageFilter.GaussianBlur(8))
    im = Image.alpha_composite(im, blob)

    font_lg = try_font(92)
    font_sm = try_font(72)
    d = ImageDraw.Draw(im)

    line1 = "Backyard"
    line2 = "Barrage"
    # Measure
    def center_text(text, font, y, fill=INK):
        bbox = d.textbbox((0, 0), text, font=font)
        tw = bbox[2] - bbox[0]
        x = (w - tw) // 2
        # soft shadow
        d.text((x + 2, y + 3), text, font=font, fill=(0, 0, 0, 40))
        d.text((x, y), text, font=font, fill=fill)

    center_text(line1, font_lg, 70, INK)
    center_text(line2, font_lg, 175, BLUE)
    # Soft underline accent
    d.rounded_rectangle([w // 2 - 120, 290, w // 2 + 120, 300], radius=5, fill=BLUE)
    # Tiny mint/winter dots as seasonal wink
    d.ellipse([w // 2 - 160, 288, w // 2 - 140, 308], fill=BLUE_LIGHT)
    d.ellipse([w // 2 + 140, 288, w // 2 + 160, 308], fill=MINT)
    return save(im, name)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    make_btn_primary()
    make_btn_primary_pressed()
    make_btn_secondary()
    make_panel_modal()
    make_shop_card()
    make_chip("chip_season_winter_v2.png", on=True, winter=True)
    make_chip("chip_season_summer_v2.png", on=True, winter=False)
    make_chip("chip_season_winter_off_v2.png", on=False, winter=True)
    make_chip("chip_season_summer_off_v2.png", on=False, winter=False)
    make_fort_bar_empty()
    make_fort_bar_fill()
    make_heart("heart_v2.png", empty=False)
    make_heart("heart_empty_v2.png", empty=True)
    make_coin()
    make_hud_chip_bg()
    make_toggle("toggle_on_v2.png", on=True)
    make_toggle("toggle_off_v2.png", on=False)
    make_icon_pause()
    make_icon_settings()
    make_icon_close()
    make_wordmark()
    print(f"\nDone. {len(list(OUT.glob('*.png')))} PNGs in {OUT}")


if __name__ == "__main__":
    main()
