#!/usr/bin/env python3
"""Backyard Barrage — polished character pose pack (STYLE.md).

Extends the MVP draw_kid pipeline with walk / charge / throw / hit / KO.
Same silhouette language, outline weight, palette. Runnable regenerator.
"""
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw
import math

ROOT = Path("/workspace/backyard-barrage")
IMG = ROOT / "assets" / "images"

# STYLE.md palette
PLAYER = (61, 124, 255, 255)      # #3D7CFF
PLAYER2 = (255, 200, 87, 255)     # #FFC857 sandy hair
ENEMY = (155, 89, 182, 255)       # #9B59B6
ENEMY2 = (243, 156, 18, 255)      # #F39C12
INK = (44, 62, 80, 255)           # #2C3E50
SNOWBALL = (255, 255, 255, 255)
SNOWBALL_O = (91, 124, 153, 255)  # #5B7C99
BALLOON = (255, 107, 157, 255)    # #FF6B9D
BALLOON_H = (126, 200, 255, 255)  # #7EC8FF
GLOW = (255, 230, 109, 255)       # #FFE66D
SKIN = (255, 214, 186, 255)
BOOT = (62, 74, 90, 255)
DARK_HAIR = (74, 52, 42, 255)
WHITE = (255, 255, 255, 255)
TRANS = (0, 0, 0, 0)
STAR = (255, 230, 109, 255)
SWIRL = (155, 89, 182, 180)

POSES = ("idle", "walk", "charge", "throw", "hit", "ko")


def new(w, h, fill=TRANS):
    return Image.new("RGBA", (w, h), fill)


def save(im: Image.Image, rel: str):
    path = IMG / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, "PNG")
    print(f"wrote {path} ({im.size[0]}x{im.size[1]})")
    return path


def _darken(c, amt=20):
    return (max(0, c[0] - amt), max(0, c[1] - amt), max(0, c[2] - amt), c[3] if len(c) > 3 else 255)


def _star(d, x, y, r, fill=STAR, outline=INK):
    """4-point sparkle star readable at phone scale."""
    pts = []
    for i in range(8):
        a = math.radians(-90 + i * 45)
        rr = r if i % 2 == 0 else r * 0.38
        pts.append((x + rr * math.cos(a), y + rr * math.sin(a)))
    d.polygon(pts, fill=fill, outline=outline)


def _swirl(d, cx, cy, r, turns=1.4, color=SWIRL, width=4):
    pts = []
    for i in range(48):
        t = i / 47
        ang = t * turns * 2 * math.pi
        rad = r * (0.25 + 0.75 * t)
        pts.append((cx + rad * math.cos(ang), cy + rad * math.sin(ang)))
    if len(pts) > 1:
        d.line(pts, fill=color, width=width)


def draw_kid(
    im,
    cx,
    cy,
    scale,
    facing_right,
    coat,
    hair,
    pose="idle",
    summer=False,
):
    """Chunky 3/4 kid silhouette with pose arcs.

    Poses: idle | walk | charge | throw | hit | ko
    Player faces RIGHT; enemy LEFT (flip via facing_right).
    Oversized head ~40% height. Outline ~3–4px #2C3E50.
    """
    d = ImageDraw.Draw(im)
    s = scale
    flip = 1 if facing_right else -1
    pose = pose.lower()

    # Lean / body offset per pose (enterprise silhouette language)
    lean = 0  # body x shift in local units
    head_dy = 0
    body_dy = 0
    if pose == "walk":
        lean = 4
    elif pose == "charge":
        lean = -10  # lean back
        head_dy = -2
    elif pose == "throw":
        lean = 8  # follow-through forward
    elif pose == "hit":
        lean = -12  # recoil back
        head_dy = 2
    elif pose == "ko":
        lean = -6
        body_dy = 14
        head_dy = 10

    def ox(x):
        return cx + flip * (x + lean) * s

    def oy(y):
        return cy + (y + body_dy) * s

    def box(x0, y0, x1, y1):
        xa, xb = ox(x0), ox(x1)
        return [min(xa, xb), oy(y0), max(xa, xb), oy(y1)]

    def box_abs(x0, y0, x1, y1, lean_off=0):
        """Box with optional extra lean for limbs."""
        xa = cx + flip * (x0 + lean + lean_off) * s
        xb = cx + flip * (x1 + lean + lean_off) * s
        return [min(xa, xb), oy(y0), max(xa, xb), oy(y1)]

    # Soft ground contact shadow (wider for KO sprawl)
    sh_w = 34 if pose == "ko" else 28
    sh_y0, sh_y1 = (62, 76) if pose == "ko" else (58, 72)
    d.ellipse(box(-sh_w, sh_y0, sh_w, sh_y1), fill=(44, 62, 80, 45))

    # --- Legs / boots (pose arcs) ---
    pants = (52, 73, 94, 255)
    if summer and coat == PLAYER:
        pants = (70, 90, 120, 255)
    elif summer and coat == ENEMY:
        pants = (90, 70, 110, 255)
    elif summer:
        pants = (70, 90, 120, 255)

    if pose == "walk":
        # Mid-stride: clear opposite arm/leg (phone-readable)
        # Trailing leg (behind body, lifted heel)
        d.rounded_rectangle(box(-30, 12, -10, 42), radius=8, fill=pants, outline=INK, width=3)
        d.ellipse(box(-36, 38, -8, 56), fill=BOOT, outline=INK, width=3)
        # Leading leg (planted forward, longer stride)
        d.rounded_rectangle(box(8, 18, 28, 52), radius=8, fill=pants, outline=INK, width=3)
        d.ellipse(box(12, 50, 38, 66), fill=BOOT, outline=INK, width=3)
    elif pose == "charge":
        # Weight on back foot, front toe light
        d.rounded_rectangle(box(-24, 20, -6, 52), radius=8, fill=pants, outline=INK, width=3)
        d.ellipse(box(-30, 48, -6, 64), fill=BOOT, outline=INK, width=3)
        d.rounded_rectangle(box(0, 22, 16, 48), radius=8, fill=pants, outline=INK, width=3)
        d.ellipse(box(2, 46, 22, 60), fill=BOOT, outline=INK, width=3)
    elif pose == "throw":
        # Planted front, trailing back
        d.rounded_rectangle(box(-20, 20, -4, 52), radius=8, fill=pants, outline=INK, width=3)
        d.ellipse(box(-24, 48, -2, 62), fill=BOOT, outline=INK, width=3)
        d.rounded_rectangle(box(4, 16, 20, 52), radius=8, fill=pants, outline=INK, width=3)
        d.ellipse(box(6, 48, 28, 64), fill=BOOT, outline=INK, width=3)
    elif pose == "hit":
        # Recoil — legs slightly splayed back
        d.rounded_rectangle(box(-22, 18, -4, 52), radius=8, fill=pants, outline=INK, width=3)
        d.ellipse(box(-28, 48, -4, 62), fill=BOOT, outline=INK, width=3)
        d.rounded_rectangle(box(2, 20, 18, 50), radius=8, fill=pants, outline=INK, width=3)
        d.ellipse(box(4, 48, 24, 62), fill=BOOT, outline=INK, width=3)
    elif pose == "ko":
        # Slumped / seated sprawl
        d.rounded_rectangle(box(-30, 28, -8, 48), radius=8, fill=pants, outline=INK, width=3)
        d.ellipse(box(-36, 42, -10, 58), fill=BOOT, outline=INK, width=3)
        d.rounded_rectangle(box(6, 30, 28, 48), radius=8, fill=pants, outline=INK, width=3)
        d.ellipse(box(10, 42, 34, 58), fill=BOOT, outline=INK, width=3)
    else:
        # Idle boots + legs
        for bx in (-14, 10):
            d.ellipse(box(bx - 10, 48, bx + 12, 62), fill=BOOT, outline=INK, width=3)
        d.rounded_rectangle(box(-18, 18, -2, 52), radius=8, fill=pants, outline=INK, width=3)
        d.rounded_rectangle(box(2, 18, 18, 52), radius=8, fill=pants, outline=INK, width=3)

    # --- Body / coat or tee ---
    body_top = oy(-8 + head_dy * 0.15)
    body_bot = oy(28)
    if summer:
        xa, xb = ox(-26), ox(26)
        d.rounded_rectangle(
            [min(xa, xb), body_top, max(xa, xb), body_bot],
            radius=14, fill=coat, outline=INK, width=4,
        )
        d.ellipse(box(-34, -4, -18, 14), fill=coat, outline=INK, width=3)
        d.ellipse(box(18, -4, 34, 14), fill=coat, outline=INK, width=3)
    else:
        xa, xb = ox(-28), ox(28)
        d.rounded_rectangle(
            [min(xa, xb), body_top, max(xa, xb), body_bot],
            radius=16, fill=coat, outline=INK, width=4,
        )
        d.line([ox(0), oy(-4), ox(0), oy(22)], fill=INK, width=3)
        d.ellipse(box(-10, -10, 10, 2), fill=coat, outline=INK, width=3)
        d.rounded_rectangle(
            box(6, 6, 20, 18), radius=4, fill=_darken(coat), outline=INK, width=2,
        )

    # Soft 1-plane body shade (STYLE: flat fill + 1 soft shadow plane max)
    shade = Image.new("RGBA", im.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    sx0, sx1 = ox(-8), ox(26)
    sd.ellipse([min(sx0, sx1), oy(4), max(sx0, sx1), oy(26)], fill=(44, 62, 80, 28))
    im.alpha_composite(shade)
    d = ImageDraw.Draw(im)

    # Projectile helper (snowball winter / balloon summer)
    def draw_projectile(px0, py0, px1, py1):
        if summer:
            # Water balloon
            bb = box(px0, py0, px1, py1)
            d.ellipse(bb, fill=BALLOON, outline=INK, width=3)
            # highlight
            mx = (bb[0] + bb[2]) / 2
            my = (bb[1] + bb[3]) / 2
            d.ellipse([mx - 8, my - 10, mx - 1, my - 2], fill=BALLOON_H)
            # knot
            d.polygon(
                [(mx - 5, bb[3] - 2), (mx + 5, bb[3] - 2), (mx, bb[3] + 8)],
                fill=BALLOON, outline=INK,
            )
        else:
            d.ellipse(box(px0, py0, px1, py1), fill=SNOWBALL, outline=SNOWBALL_O, width=3)

    # --- Arms by pose ---
    sleeve = coat if not summer else SKIN

    if pose == "walk":
        # Opposite to legs: leading-side arm swings BACK, trailing-side arm FORWARD
        # Forward-swinging arm (trailing side of stride)
        d.rounded_rectangle(box(-8, -6, 12, 8), radius=6, fill=sleeve, outline=INK, width=3)
        d.ellipse(box(10, -4, 36, 22), fill=SKIN, outline=INK, width=3)
        if not summer:
            d.arc(box(10, 8, 36, 24), 0, 180, fill=INK, width=3)
        # Back-swinging arm (leading side)
        d.rounded_rectangle(box(-20, 2, -2, 16), radius=6, fill=sleeve, outline=INK, width=3)
        d.ellipse(box(-46, 6, -18, 32), fill=SKIN, outline=INK, width=3)
        if not summer:
            d.arc(box(-46, 16, -18, 34), 0, 180, fill=INK, width=3)

    elif pose == "charge":
        # Lean back, both arms pulled back holding projectile
        d.rounded_rectangle(box(-40, -28, -14, 4), radius=10, fill=sleeve, outline=INK, width=3)
        d.rounded_rectangle(box(-36, -40, -8, -12), radius=10, fill=sleeve, outline=INK, width=3)
        d.ellipse(box(-42, -48, -16, -24), fill=SKIN, outline=INK, width=3)
        d.ellipse(box(-28, -52, -4, -28), fill=SKIN, outline=INK, width=3)
        draw_projectile(-48, -62, -18, -34)
        # Yellow charge glow hint behind projectile
        glow_im = new(im.size[0], im.size[1])
        gd = ImageDraw.Draw(glow_im)
        gx0, gy0, gx1, gy1 = box(-56, -70, -10, -26)
        for expand, alpha in ((18, 50), (10, 90), (4, 140)):
            gd.ellipse(
                [gx0 - expand, gy0 - expand, gx1 + expand, gy1 + expand],
                outline=(GLOW[0], GLOW[1], GLOW[2], alpha),
                width=4,
            )
        im.alpha_composite(glow_im)
        d = ImageDraw.Draw(im)

    elif pose == "throw":
        # Follow-through forward
        d.ellipse(box(-36, -6, -14, 16), fill=SKIN, outline=INK, width=3)
        d.rounded_rectangle(box(12, -42, 34, -8), radius=10, fill=sleeve, outline=INK, width=3)
        d.ellipse(box(16, -52, 40, -28), fill=SKIN, outline=INK, width=3)
        draw_projectile(22, -60, 46, -36)

    elif pose == "hit":
        # Arms flinch up beside head (chunky mittens)
        d.rounded_rectangle(box(-36, -24, -18, 2), radius=8, fill=sleeve, outline=INK, width=3)
        d.ellipse(box(-44, -38, -16, -12), fill=SKIN, outline=INK, width=3)
        d.rounded_rectangle(box(16, -28, 34, 0), radius=8, fill=sleeve, outline=INK, width=3)
        d.ellipse(box(14, -42, 42, -14), fill=SKIN, outline=INK, width=3)

    elif pose == "ko":
        # Limp arms at sides / down
        d.ellipse(box(-42, 8, -18, 32), fill=SKIN, outline=INK, width=3)
        d.ellipse(box(16, 10, 40, 34), fill=SKIN, outline=INK, width=3)

    else:
        # Idle arms at sides slightly forward
        d.ellipse(box(-38, 0, -16, 22), fill=SKIN, outline=INK, width=3)
        d.ellipse(box(16, 0, 38, 22), fill=SKIN, outline=INK, width=3)
        if not summer:
            d.arc(box(-38, 8, -16, 24), 0, 180, fill=INK, width=3)
            d.arc(box(16, 8, 38, 24), 0, 180, fill=INK, width=3)

    # --- Head (oversized ~40%) ---
    hy0, hy1 = -62 + head_dy, -8 + head_dy
    d.ellipse(box(-30, hy0, 30, hy1), fill=SKIN, outline=INK, width=4)

    # Hair
    if facing_right:
        d.pieslice(box(-32, hy0 - 6, 28, hy0 + 42), 200, 360, fill=hair, outline=INK, width=3)
        d.ellipse(box(-28, hy0 - 4, 8, hy0 + 22), fill=hair, outline=INK, width=2)
        d.ellipse(box(-4, hy0 - 2, 26, hy0 + 20), fill=hair)
    else:
        d.pieslice(box(-28, hy0 - 6, 32, hy0 + 42), 180, 340, fill=hair, outline=INK, width=3)
        d.ellipse(box(-8, hy0 - 4, 28, hy0 + 22), fill=hair, outline=INK, width=2)
        d.ellipse(box(-26, hy0 - 2, 4, hy0 + 20), fill=hair)

    # Face — expression by pose (local +x = toward facing; ox() flips)
    eye_x = ox(10)
    eye_y_mid = oy(-34 + head_dy)

    if pose == "hit":
        # Squint / X eyes optional — use closed arcs + stars nearby
        for ex in (eye_x,):
            d.line([ex - 10, eye_y_mid - 6, ex + 10, eye_y_mid + 6], fill=INK, width=4)
            d.line([ex - 10, eye_y_mid + 6, ex + 10, eye_y_mid - 6], fill=INK, width=4)
        # Open mouth O
        mx = ox(4)
        d.ellipse([mx - 8, oy(-18 + head_dy), mx + 10, oy(-4 + head_dy)], fill=(200, 80, 90, 255), outline=INK, width=3)
    elif pose == "ko":
        # Spiral / X sleepy eyes
        for ex in (eye_x,):
            d.line([ex - 9, eye_y_mid - 5, ex + 9, eye_y_mid + 5], fill=INK, width=3)
            d.line([ex - 9, eye_y_mid + 5, ex + 9, eye_y_mid - 5], fill=INK, width=3)
        # Tongue / open mouth
        mx = ox(2)
        d.ellipse([mx - 10, oy(-16 + head_dy), mx + 12, oy(-2 + head_dy)], outline=INK, width=3)
        d.arc([mx - 8, oy(-10 + head_dy), mx + 10, oy(2 + head_dy)], 0, 180, fill=(220, 100, 120, 255), width=4)
    elif pose == "charge":
        # Determined squint
        d.ellipse([eye_x - 10, oy(-40 + head_dy), eye_x + 10, oy(-26 + head_dy)], fill=WHITE, outline=INK, width=3)
        d.ellipse([eye_x - 3, oy(-35 + head_dy), eye_x + 5, oy(-28 + head_dy)], fill=INK)
        d.ellipse([eye_x + 1, oy(-34 + head_dy), eye_x + 4, oy(-31 + head_dy)], fill=WHITE)
        # Brow down
        bx0, bx1 = eye_x - 12, eye_x + 12
        d.line([bx0, oy(-46 + head_dy), bx1, oy(-42 + head_dy)], fill=INK, width=4)
        smile_x = ox(4)
        d.arc(
            [min(smile_x - 10, smile_x + 12), oy(-22 + head_dy), max(smile_x - 10, smile_x + 12), oy(-8 + head_dy)],
            200, 340, fill=INK, width=3,
        )
    else:
        # Default readable eye + smile
        d.ellipse([eye_x - 10, oy(-42 + head_dy), eye_x + 10, oy(-26 + head_dy)], fill=WHITE, outline=INK, width=3)
        d.ellipse([eye_x - 3, oy(-36 + head_dy), eye_x + 5, oy(-28 + head_dy)], fill=INK)
        d.ellipse([eye_x + 1, oy(-35 + head_dy), eye_x + 4, oy(-32 + head_dy)], fill=WHITE)
        bx0, bx1 = eye_x - 12, eye_x + 12
        d.arc([min(bx0, bx1), oy(-50 + head_dy), max(bx0, bx1), oy(-34 + head_dy)], 200, 340, fill=INK, width=3)
        smile_x = ox(4)
        d.arc(
            [min(smile_x - 12, smile_x + 14), oy(-24 + head_dy), max(smile_x - 12, smile_x + 14), oy(-8 + head_dy)],
            20, 160, fill=INK, width=4,
        )

    # Freckles (skip on KO for clarity of swirl)
    if pose not in ("ko",):
        for fx, fy in [(ox(16), oy(-22 + head_dy)), (ox(22), oy(-18 + head_dy)), (ox(14), oy(-16 + head_dy))]:
            d.ellipse([fx - 3, fy - 3, fx + 3, fy + 3], fill=(220, 140, 120, 220))

    # Winter hat + pom
    if not summer:
        hat = coat
        d.ellipse(box(-22, hy0 - 10, 22, hy0 + 14), fill=hat, outline=INK, width=3)
        d.ellipse(box(-6, hy0 - 18, 10, hy0 - 2), fill=WHITE, outline=INK, width=2)

    # --- VFX overlays ---
    if pose == "hit":
        # Recoil stars around head
        hx = cx + flip * lean * s
        hy = oy(-50 + head_dy)
        for ang, rr in ((30, 55), (150, 50), (280, 58)):
            a = math.radians(ang if facing_right else 180 - ang)
            _star(d, hx + math.cos(a) * rr * s / 3.2, hy + math.sin(a) * rr * s / 3.2, 10 * s / 3.6)

    if pose == "ko":
        hx = cx + flip * lean * s
        hy = oy(-55 + head_dy)
        _swirl(d, hx + flip * 8 * s, hy - 8 * s, 28 * s / 3.6, turns=1.6, color=(155, 89, 182, 200), width=max(3, int(3 * s / 3.6)))
        for ang, rr in ((20, 48), (110, 52), (200, 44), (300, 50)):
            a = math.radians(ang)
            _star(d, hx + math.cos(a) * rr * s / 3.2, hy + math.sin(a) * rr * s / 3.2, 9 * s / 3.6)


def make_character(rel, facing_right, coat, hair, pose="idle", summer=False, size=512):
    im = new(size, size)
    draw_kid(
        im,
        size // 2,
        int(size * 0.55),
        size / 140,
        facing_right,
        coat,
        hair,
        pose=pose,
        summer=summer,
    )
    return save(im, rel)


def export_all_poses():
    """Full player + enemy pose sheets, winter + summer."""
    seasons = (("winter", False), ("summer", True))
    written = []

    for season, summer in seasons:
        for pose in POSES:
            rel = f"characters/player/player_{pose}_{season}_draft.png"
            written.append(
                make_character(rel, True, PLAYER, PLAYER2, pose=pose, summer=summer)
            )
            rel_e = f"characters/enemy/enemy_{pose}_{season}_draft.png"
            written.append(
                make_character(rel_e, False, ENEMY, DARK_HAIR, pose=pose, summer=summer)
            )

    return written


def main():
    paths = export_all_poses()
    print(f"DONE {len(paths)} character pose drafts")


if __name__ == "__main__":
    main()
