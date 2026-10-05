#!/usr/bin/env python3
"""Backyard Barrage — original MVP draft art (STYLE.md palette). Procedural drafts."""
from __future__ import annotations
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math

ROOT = Path("/workspace/backyard-barrage")
IMG = ROOT / "assets" / "images"

# STYLE.md palette
SKY_W = (168, 212, 240, 255)      # #A8D4F0
SKY_S = (135, 206, 235, 255)      # #87CEEB
SNOW = (244, 248, 252, 255)       # #F4F8FC
GRASS = (107, 191, 89, 255)       # #6BBF59
DIRT = (196, 164, 132, 255)       # #C4A484
PLAYER = (61, 124, 255, 255)      # #3D7CFF
PLAYER2 = (255, 200, 87, 255)     # #FFC857 sandy hair
ENEMY = (155, 89, 182, 255)       # #9B59B6
ENEMY2 = (243, 156, 18, 255)      # #F39C12
FORT = (139, 94, 60, 255)         # #8B5E3C
FORT_SNOW = (232, 241, 248, 255)  # #E8F1F8
BALLOON = (255, 107, 157, 255)    # #FF6B9D
BALLOON_H = (126, 200, 255, 255)  # #7EC8FF
SNOWBALL = (255, 255, 255, 255)
SNOWBALL_O = (91, 124, 153, 255)  # #5B7C99
INK = (44, 62, 80, 255)           # #2C3E50
CREAM = (255, 248, 240, 255)      # #FFF8F0
COIN = (241, 196, 15, 255)        # #F1C40F
HEART = (231, 76, 60, 255)        # #E74C3C
GLOW = (255, 230, 109, 255)       # #FFE66D
SKIN = (255, 214, 186, 255)
SKIN_SHADOW = (240, 190, 160, 255)
DARK_HAIR = (74, 52, 42, 255)
WHITE = (255, 255, 255, 255)
TRANS = (0, 0, 0, 0)
BOOT = (62, 74, 90, 255)
NAVY_UI = (44, 62, 80, 255)


def new(w, h, fill=TRANS):
    return Image.new("RGBA", (w, h), fill)


def save(im: Image.Image, rel: str):
    path = IMG / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, "PNG")
    print(f"wrote {path} ({im.size[0]}x{im.size[1]})")
    return path


def outline_ellipse(draw, bbox, fill, outline=INK, width=4):
    draw.ellipse(bbox, fill=fill, outline=outline, width=width)


def outline_rounded(draw, bbox, fill, outline=INK, width=4, radius=18):
    draw.rounded_rectangle(bbox, radius=radius, fill=fill, outline=outline, width=width)


def draw_kid(im, cx, cy, scale, facing_right, coat, hair, throw=False, summer=False, pose=None):
    """Delegate to shared pose pipeline (generate_poses_polish) so proportions stay locked."""
    from generate_poses_polish import draw_kid as _draw
    if pose is None:
        pose = "throw" if throw else "idle"
    _draw(im, cx, cy, scale, facing_right, coat, hair, pose=pose, summer=summer)


def make_character(rel, facing_right, coat, hair, throw=False, summer=False, size=512, pose=None):
    from generate_poses_polish import make_character as _make
    if pose is None:
        pose = "throw" if throw else "idle"
    return _make(rel, facing_right, coat, hair, pose=pose, summer=summer, size=size)


def make_world(rel, winter=True, w=1280, h=720):
    im = new(w, h)
    d = ImageDraw.Draw(im)
    sky = SKY_W if winter else SKY_S
    d.rectangle([0, 0, w, h], fill=sky)

    # Soft clouds
    for cx, cy, rw, rh in [(180, 90, 140, 50), (520, 70, 180, 55), (900, 100, 160, 48), (1100, 60, 120, 40)]:
        d.ellipse([cx, cy, cx + rw, cy + rh], fill=(255, 255, 255, 180 if winter else 140))

    # Distant house edge left
    d.rectangle([0, 280, 160, 480], fill=(232, 210, 190, 255), outline=INK, width=3)
    d.polygon([(0, 280), (80, 220), (160, 280)], fill=(200, 90, 90, 255), outline=INK)
    d.rectangle([40, 340, 100, 400], fill=(160, 200, 230, 255), outline=INK, width=2)

    # Fence mid-back
    fence_y = 420
    d.rectangle([0, fence_y, w, fence_y + 18], fill=DIRT, outline=INK, width=2)
    for x in range(40, w, 70):
        d.rectangle([x, fence_y - 50, x + 14, fence_y + 20], fill=DIRT, outline=INK, width=2)
        d.ellipse([x - 2, fence_y - 62, x + 16, fence_y - 44], fill=DIRT, outline=INK, width=2)
        if winter:
            d.ellipse([x - 4, fence_y - 66, x + 18, fence_y - 52], fill=FORT_SNOW)

    # Bushes
    for bx in (200, 380, 900, 1080):
        d.ellipse([bx, 390, bx + 120, 460], fill=(76, 150, 70, 255) if not winter else (180, 200, 190, 255), outline=INK, width=3)
        d.ellipse([bx + 40, 370, bx + 140, 450], fill=(90, 170, 85, 255) if not winter else (200, 215, 205, 255), outline=INK, width=2)
        if winter:
            d.ellipse([bx + 20, 365, bx + 80, 400], fill=FORT_SNOW)

    # Ground
    if winter:
        d.rectangle([0, 480, w, h], fill=SNOW)
        # Snowbanks
        for sx in (0, 250, 700, 1050):
            d.ellipse([sx, 450, sx + 280, 540], fill=SNOW, outline=(200, 210, 220, 255), width=2)
        # Subtle tracks empty mid
        d.arc([480, 540, 800, 620], 200, 340, fill=(220, 230, 240, 255), width=4)
    else:
        d.rectangle([0, 480, w, h], fill=GRASS)
        # Darker grass patches
        for gx in (100, 400, 750, 1000):
            d.ellipse([gx, 500, gx + 200, 580], fill=(90, 170, 75, 180))
        # No pool or hose. Those outlined circles read as leftover joysticks.

    # Empty mid-ground play area (no characters) — soft path
    if winter:
        d.ellipse([300, 520, 980, 680], fill=(250, 252, 255, 200))
    else:
        d.ellipse([300, 520, 980, 680], fill=(120, 200, 100, 120))

    return save(im, rel)


def make_fort(rel, stage, size=640):
    """Left-side wood fort stages 1→3."""
    im = new(size, size)
    d = ImageDraw.Draw(im)
    # Shadow
    d.ellipse([40, size - 80, size - 80, size - 30], fill=(44, 62, 80, 50))

    base_h = 120 + stage * 70
    base_w = 180 + stage * 50
    left = 60
    bottom = size - 70
    top = bottom - base_h

    # Main boards
    d.rounded_rectangle([left, top, left + base_w, bottom], radius=8, fill=FORT, outline=INK, width=4)
    # Vertical planks
    plank = base_w // (3 + stage)
    for i in range(3 + stage):
        x = left + 10 + i * plank
        d.line([x, top + 8, x, bottom - 8], fill=(110, 75, 48, 255), width=3)

    # Horizontal braces
    for yoff in (0.3, 0.6):
        y = int(top + base_h * yoff)
        d.rectangle([left + 8, y, left + base_w - 8, y + 12], fill=(120, 80, 50, 255), outline=INK, width=2)

    if stage >= 2:
        # Crate / sandbag stack
        crate_y = bottom - 90
        d.rounded_rectangle([left + base_w - 20, crate_y, left + base_w + 70, bottom - 10], radius=6, fill=(160, 120, 70, 255), outline=INK, width=3)
        d.line([left + base_w + 5, crate_y + 40, left + base_w + 55, crate_y + 40], fill=INK, width=2)
        # Sandbags
        for i in range(3):
            sx = left - 30 + i * 28
            d.ellipse([sx, bottom - 50, sx + 40, bottom - 10], fill=(180, 160, 120, 255), outline=INK, width=2)

    if stage >= 3:
        # Taller battlement + flag pole
        batt = top - 50
        d.rectangle([left + 20, batt, left + base_w - 20, top + 5], fill=FORT, outline=INK, width=3)
        for i in range(4):
            bx = left + 30 + i * ((base_w - 60) // 4)
            d.rectangle([bx, batt - 25, bx + 28, batt + 5], fill=FORT, outline=INK, width=2)
        # Soft fabric flag (not weapon) — blue pennant
        pole_x = left + base_w // 2
        d.line([pole_x, batt - 80, pole_x, batt], fill=INK, width=4)
        d.polygon([(pole_x, batt - 78), (pole_x + 50, batt - 60), (pole_x, batt - 42)], fill=PLAYER, outline=INK)
        # Extra crates
        d.rounded_rectangle([left - 50, bottom - 70, left + 10, bottom - 8], radius=5, fill=(150, 110, 65, 255), outline=INK, width=3)

    # Snow caps
    d.ellipse([left - 10, top - 25, left + base_w // 2, top + 15], fill=FORT_SNOW, outline=(200, 210, 220, 255), width=2)
    d.ellipse([left + base_w // 3, top - 30, left + base_w + 15, top + 10], fill=FORT_SNOW)

    # Peek window
    wx = left + base_w // 2 - 20
    wy = top + base_h // 3
    d.rounded_rectangle([wx, wy, wx + 40, wy + 36], radius=6, fill=(60, 80, 100, 255), outline=INK, width=3)

    return save(im, rel)


def make_snowball(rel, size=256):
    im = new(size, size)
    d = ImageDraw.Draw(im)
    m = size // 2
    r = int(size * 0.38)
    d.ellipse([m - r, m - r, m + r, m + r], fill=SNOWBALL, outline=SNOWBALL_O, width=6)
    # Soft highlight
    d.ellipse([m - r // 2, m - r // 2, m, m], fill=(255, 255, 255, 220))
    # Texture dots
    for dx, dy in [(-20, 10), (15, 25), (-5, 35), (25, -5)]:
        d.ellipse([m + dx - 4, m + dy - 4, m + dx + 4, m + dy + 4], fill=(230, 235, 240, 255))
    return save(im, rel)


def make_balloon(rel, size=256):
    im = new(size, size)
    d = ImageDraw.Draw(im)
    m = size // 2
    # Balloon body
    d.ellipse([m - 70, m - 90, m + 70, m + 50], fill=BALLOON, outline=INK, width=5)
    # Highlight sheen
    d.ellipse([m - 40, m - 70, m - 5, m - 20], fill=BALLOON_H)
    # Knot
    d.polygon([(m - 12, m + 48), (m + 12, m + 48), (m, m + 70)], fill=BALLOON, outline=INK)
    # String
    d.line([m, m + 70, m, m + 100], fill=INK, width=3)
    return save(im, rel)


def make_impact_snow(rel, size=256):
    im = new(size, size)
    d = ImageDraw.Draw(im)
    m = size // 2
    # Poof bursts
    for i, (ang, rad, rr) in enumerate([(0, 20, 40), (45, 35, 30), (90, 25, 35), (135, 40, 28), (180, 22, 38), (225, 38, 32), (270, 28, 36), (315, 42, 30)]):
        a = math.radians(ang)
        x = m + int(math.cos(a) * rad)
        y = m + int(math.sin(a) * rad)
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(255, 255, 255, 230), outline=SNOWBALL_O, width=3)
    d.ellipse([m - 30, m - 30, m + 30, m + 30], fill=(244, 248, 252, 255), outline=SNOWBALL_O, width=3)
    # Stars
    for ang in (30, 150, 270):
        a = math.radians(ang)
        x = m + int(math.cos(a) * 90)
        y = m + int(math.sin(a) * 90)
        d.regular_polygon((x, y, 10), 4, rotation=ang, fill=GLOW, outline=INK)
    return save(im, rel)


def make_impact_splash(rel, size=256):
    im = new(size, size)
    d = ImageDraw.Draw(im)
    m = size // 2
    cols = [BALLOON, BALLOON_H, (255, 150, 200, 255), (100, 180, 255, 255)]
    for i, (ang, rad, rr) in enumerate([(0, 30, 28), (40, 50, 22), (80, 35, 30), (120, 55, 20), (160, 28, 26), (200, 48, 24), (240, 32, 28), (280, 52, 18), (320, 36, 25)]):
        a = math.radians(ang)
        x = m + int(math.cos(a) * rad)
        y = m + int(math.sin(a) * rad)
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=cols[i % len(cols)], outline=INK, width=3)
    d.ellipse([m - 35, m - 25, m + 35, m + 35], fill=BALLOON_H, outline=INK, width=3)
    return save(im, rel)


def make_charge_glow(rel, size=256):
    im = new(size, size)
    d = ImageDraw.Draw(im)
    m = size // 2
    # Concentric rings
    for r, w, a in [(100, 10, 120), (80, 12, 180), (55, 14, 220), (30, 8, 255)]:
        col = (GLOW[0], GLOW[1], GLOW[2], a)
        # Draw ring as thick arc approximation
        ring = new(size, size)
        rd = ImageDraw.Draw(ring)
        rd.ellipse([m - r, m - r, m + r, m + r], outline=GLOW, width=w)
        im = Image.alpha_composite(im, ring)
    d = ImageDraw.Draw(im)
    d.ellipse([m - 18, m - 18, m + 18, m + 18], fill=(255, 250, 200, 255), outline=INK, width=3)
    # Spark ticks
    for ang in range(0, 360, 45):
        a = math.radians(ang)
        x0 = m + int(math.cos(a) * 70)
        y0 = m + int(math.sin(a) * 70)
        x1 = m + int(math.cos(a) * 95)
        y1 = m + int(math.sin(a) * 95)
        d.line([x0, y0, x1, y1], fill=GLOW, width=4)
    return save(im, rel)


def try_font(size):
    for path in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    ):
        p = Path(path)
        if p.exists():
            return ImageFont.truetype(str(p), size)
    return ImageFont.load_default()


def make_wordmark(rel, w=1024, h=384):
    im = new(w, h)
    d = ImageDraw.Draw(im)
    # Soft cream plate optional behind — keep mostly transparent with cream chip
    d.rounded_rectangle([40, 40, w - 40, h - 40], radius=40, fill=(*CREAM[:3], 230), outline=INK, width=6)
    font_big = try_font(96)
    font_sm = try_font(72)
    # Shadow text
    for dx, dy in ((4, 4),):
        d.text((w // 2 + dx, h // 2 - 40 + dy), "Backyard", font=font_big, fill=(44, 62, 80, 80), anchor="mm")
        d.text((w // 2 + dx, h // 2 + 50 + dy), "Barrage", font=font_sm, fill=(44, 62, 80, 80), anchor="mm")
    d.text((w // 2, h // 2 - 40), "Backyard", font=font_big, fill=PLAYER, anchor="mm")
    d.text((w // 2, h // 2 + 50), "Barrage", font=font_sm, fill=ENEMY, anchor="mm")
    # Snowball / balloon accents
    d.ellipse([80, 140, 140, 200], fill=SNOWBALL, outline=SNOWBALL_O, width=4)
    d.ellipse([w - 150, 120, w - 80, 200], fill=BALLOON, outline=INK, width=4)
    return save(im, rel)


def make_button(rel, w=512, h=160):
    im = new(w, h)
    d = ImageDraw.Draw(im)
    # 3D lip
    d.rounded_rectangle([16, 24, w - 16, h - 12], radius=28, fill=(200, 190, 175, 255), outline=INK, width=5)
    d.rounded_rectangle([16, 12, w - 16, h - 28], radius=28, fill=CREAM, outline=INK, width=5)
    return save(im, rel)


def make_heart(rel, size=256):
    im = new(size, size)
    d = ImageDraw.Draw(im)
    # Classic heart from two circles + triangle
    s = size
    d.ellipse([int(s * 0.12), int(s * 0.18), int(s * 0.55), int(s * 0.58)], fill=HEART, outline=INK, width=5)
    d.ellipse([int(s * 0.45), int(s * 0.18), int(s * 0.88), int(s * 0.58)], fill=HEART, outline=INK, width=5)
    d.polygon([
        (int(s * 0.15), int(s * 0.42)),
        (int(s * 0.85), int(s * 0.42)),
        (int(s * 0.50), int(s * 0.88)),
    ], fill=HEART, outline=INK)
    # Re-outline tip
    d.line([(int(s * 0.15), int(s * 0.42)), (int(s * 0.50), int(s * 0.88))], fill=INK, width=5)
    d.line([(int(s * 0.85), int(s * 0.42)), (int(s * 0.50), int(s * 0.88))], fill=INK, width=5)
    # Highlight
    d.ellipse([int(s * 0.22), int(s * 0.28), int(s * 0.38), int(s * 0.42)], fill=(255, 180, 170, 200))
    return save(im, rel)


def make_coin(rel, size=256):
    im = new(size, size)
    d = ImageDraw.Draw(im)
    m = size // 2
    r = int(size * 0.40)
    d.ellipse([m - r, m - r, m + r, m + r], fill=COIN, outline=INK, width=6)
    d.ellipse([m - r + 14, m - r + 14, m + r - 14, m + r - 14], outline=(200, 150, 20, 255), width=4)
    font = try_font(90)
    d.text((m, m), "$", font=font, fill=INK, anchor="mm")
    return save(im, rel)


def make_app_icon(rel, size=1024):
    im = new(size, size, SKY_W)
    d = ImageDraw.Draw(im)
    # Rounded mask feel — draw cream border ring
    # Ground snow
    d.ellipse([-100, int(size * 0.55), size + 100, size + 80], fill=SNOW)
    # Fence bit
    d.rectangle([0, int(size * 0.52), size, int(size * 0.55)], fill=DIRT, outline=INK, width=4)
    # Bush
    d.ellipse([int(size * 0.7), int(size * 0.45), int(size * 0.95), int(size * 0.65)], fill=(180, 200, 190, 255), outline=INK, width=4)
    # Kid centered large
    draw_kid(im, size // 2 - 40, int(size * 0.58), size / 110, True, PLAYER, PLAYER2, throw=True, summer=False)
    # Balloon accent
    d.ellipse([int(size * 0.72), int(size * 0.22), int(size * 0.88), int(size * 0.40)], fill=BALLOON, outline=INK, width=6)
    d.polygon([(int(size * 0.78), int(size * 0.40)), (int(size * 0.82), int(size * 0.40)), (int(size * 0.80), int(size * 0.46))], fill=BALLOON, outline=INK)
    # Soft outer rounded corners via mask
    mask = new(size, size, (0, 0, 0, 0))
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, size - 1, size - 1], radius=180, fill=(255, 255, 255, 255))
    out = new(size, size, TRANS)
    out.paste(im, (0, 0), mask)
    # Navy outline ring
    od = ImageDraw.Draw(out)
    od.rounded_rectangle([8, 8, size - 9, size - 9], radius=175, outline=INK, width=14)
    return save(out, rel)


def main():
    # Core MVP sheets (full pose pack: scripts/generate_poses_polish.py)
    make_character("characters/player/player_idle_winter_draft.png", True, PLAYER, PLAYER2, False, False)
    make_character("characters/player/player_throw_winter_draft.png", True, PLAYER, PLAYER2, True, False)
    make_character("characters/player/player_idle_summer_draft.png", True, PLAYER, PLAYER2, False, True)
    make_character("characters/player/player_throw_summer_draft.png", True, PLAYER, PLAYER2, True, True)
    make_character("characters/enemy/enemy_idle_winter_draft.png", False, ENEMY, DARK_HAIR, False, False)
    make_character("characters/enemy/enemy_throw_winter_draft.png", False, ENEMY, DARK_HAIR, True, False)
    make_character("characters/enemy/enemy_idle_summer_draft.png", False, ENEMY, DARK_HAIR, False, True)
    make_character("characters/enemy/enemy_throw_summer_draft.png", False, ENEMY, DARK_HAIR, True, True)

    make_world("world/backyard_bg_winter_draft.png", winter=True)
    make_world("world/backyard_bg_summer_draft.png", winter=False)

    make_fort("forts/fort_stage_1_draft.png", 1)
    make_fort("forts/fort_stage_2_draft.png", 2)
    make_fort("forts/fort_stage_3_draft.png", 3)

    make_snowball("projectiles/snowball_draft.png")
    make_balloon("projectiles/water_balloon_draft.png")
    make_impact_snow("vfx/impact_snow_draft.png")
    make_impact_splash("vfx/impact_splash_draft.png")
    make_charge_glow("vfx/charge_glow_draft.png")

    make_wordmark("ui/wordmark_backyard_barrage_draft.png")
    make_button("ui/btn_primary_draft.png")
    make_heart("ui/heart_draft.png")
    make_coin("ui/coin_draft.png")
    make_app_icon("ui/app_icon_1024_draft.png")
    print("DONE MVP drafts (+ summer throw variants)")


if __name__ == "__main__":
    main()
