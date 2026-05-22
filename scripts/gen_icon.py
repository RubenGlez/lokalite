#!/usr/bin/env python3
"""Generate the Lokalite app icon: a premium combination-lock dial."""

import math
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, Image as PILImage
import numpy as np

SIZE = 1024
CX = CY = SIZE // 2
LIGHT = -math.pi * 0.6   # light from upper-left

OUT_PNG  = Path(__file__).parent.parent / "assets" / "AppIcon.png"
OUT_ICNS = Path(__file__).parent.parent / "assets" / "AppIcon.icns"


# ── helpers ──────────────────────────────────────────────────────────────────

def blank():
    return np.zeros((SIZE, SIZE, 4), dtype=np.float32)


def dist_grid():
    Y, X = np.mgrid[:SIZE, :SIZE]
    return np.sqrt((X - CX) ** 2 + (Y - CY) ** 2)


def angle_grid():
    Y, X = np.mgrid[:SIZE, :SIZE]
    return np.arctan2(Y - CY, X - CX)


DIST   = dist_grid()
ANGLES = angle_grid()


def metallic(inner, outer, base, specular=0.45, warmth=0.0):
    """RGBA array slice for a metallic ring lit from LIGHT angle."""
    mask = (DIST >= inner) & (DIST < outer)
    cos  = np.cos(ANGLES - LIGHT)              # -1..1
    brt  = 0.72 + specular * (cos + 1) / 2    # 0.72..1.17

    r, g, b = base
    out = blank()
    out[:,:,0] = np.where(mask, np.clip(r * brt + warmth * 18, 0, 255), 0)
    out[:,:,1] = np.where(mask, np.clip(g * brt, 0, 255), 0)
    out[:,:,2] = np.where(mask, np.clip(b * brt, 0, 255), 0)
    out[:,:,3] = np.where(mask, 255, 0)
    return out


def groove(r, width=4):
    """Thin dark groove (shadow) just inside radius r."""
    mask = (DIST >= r - width) & (DIST < r)
    out  = blank()
    t    = (DIST - (r - width)) / width        # 0=inner edge, 1=outer edge
    out[:,:,3] = np.where(mask, 180 * (1 - t), 0)
    return out


def rim_light(r, width=3):
    """Bright rim highlight just outside radius r."""
    mask = (DIST >= r) & (DIST < r + width)
    cos  = np.cos(ANGLES - LIGHT)
    intensity = np.clip((cos + 1) / 2, 0, 1)
    out  = blank()
    out[:,:,0] = np.where(mask, 220 * intensity, 0)
    out[:,:,1] = np.where(mask, 225 * intensity, 0)
    out[:,:,2] = np.where(mask, 230 * intensity, 0)
    out[:,:,3] = np.where(mask, 220 * intensity, 0)
    return out


def composite(base_img, layer_arr):
    layer = Image.fromarray(np.clip(layer_arr, 0, 255).astype(np.uint8), "RGBA")
    return Image.alpha_composite(base_img, layer)


# ── background ───────────────────────────────────────────────────────────────

def make_background():
    t = np.clip(DIST / (SIZE * 0.58), 0, 1)
    arr = blank()
    arr[:,:,0] = np.clip(14 - 6 * t, 0, 255)
    arr[:,:,1] = np.clip(14 - 5 * t, 0, 255)
    arr[:,:,2] = np.clip(18 - 7 * t, 0, 255)
    arr[:,:,3] = 255
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


# ── dial geometry ─────────────────────────────────────────────────────────────
#
#  r=462  outer rim
#  r=456  bezel outer
#  r=370  bezel inner / groove start
#  r=362  dial outer
#  r=248  dial inner / groove start
#  r=240  plate outer
#  r=0    plate center

BEZEL_OUT  = 456
BEZEL_IN   = 372
DIAL_OUT   = 364
DIAL_IN    = 250
PLATE_R    = 242
CENTER_R   = 44


def make_icon():
    img = make_background()

    # ── outer bezel ──────────────────────────────────────────────────────────
    img = composite(img, metallic(BEZEL_IN, BEZEL_OUT, (44, 47, 54), specular=0.55))
    img = composite(img, groove(BEZEL_OUT, width=6))

    # ── dial ring ────────────────────────────────────────────────────────────
    img = composite(img, metallic(DIAL_IN, DIAL_OUT, (56, 60, 70), specular=0.5))
    img = composite(img, groove(DIAL_OUT, width=5))
    img = composite(img, groove(DIAL_IN, width=5))

    # ── inner plate ──────────────────────────────────────────────────────────
    plate = blank()
    mask  = DIST < PLATE_R
    plate[:,:,0] = np.where(mask, 10, 0)
    plate[:,:,1] = np.where(mask, 10, 0)
    plate[:,:,2] = np.where(mask, 13, 0)
    plate[:,:,3] = np.where(mask, 255, 0)
    img = composite(img, plate)
    img = composite(img, groove(PLATE_R, width=4))

    # ── tick marks ───────────────────────────────────────────────────────────
    tick_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    tick_draw  = ImageDraw.Draw(tick_layer)

    n_ticks = 60
    for i in range(n_ticks):
        ang      = math.radians(i * 360 / n_ticks - 90)
        major    = (i % 5 == 0)
        tick_len = 26 if major else 13
        r_outer  = BEZEL_IN - 8
        r_inner  = r_outer - tick_len
        x1 = CX + r_outer * math.cos(ang)
        y1 = CY + r_outer * math.sin(ang)
        x2 = CX + r_inner * math.cos(ang)
        y2 = CY + r_inner * math.sin(ang)
        col = (195, 200, 210, 200) if major else (100, 105, 115, 140)
        w   = 3 if major else 2
        tick_draw.line([(x1, y1), (x2, y2)], fill=col, width=w)

    img = Image.alpha_composite(img, tick_layer)

    # ── dial notches (3 × combination positions) ─────────────────────────────
    notch_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    notch_draw  = ImageDraw.Draw(notch_layer)
    for pos_deg in (0, 120, 240):
        ang    = math.radians(pos_deg - 90)
        half   = math.radians(6)
        r_out  = DIAL_OUT - 6
        r_in   = r_out - 28
        # dark filled arc segment
        for dang in np.linspace(-half, half, 14):
            a = ang + dang
            xo = CX + r_out * math.cos(a)
            yo = CY + r_out * math.sin(a)
            xi = CX + r_in  * math.cos(a)
            yi = CY + r_in  * math.sin(a)
            notch_draw.line([(xo, yo), (xi, yi)], fill=(0, 0, 0, 180), width=2)

    img = Image.alpha_composite(img, notch_layer)

    # ── center amber glow ────────────────────────────────────────────────────
    glow_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    glow_draw  = ImageDraw.Draw(glow_layer)

    # outer soft glow ring
    glow_draw.ellipse(
        [CX - 90, CY - 90, CX + 90, CY + 90],
        fill=(245, 160, 20, 60),
    )
    # inner bright dot
    glow_draw.ellipse(
        [CX - CENTER_R, CY - CENTER_R, CX + CENTER_R, CY + CENTER_R],
        fill=(252, 195, 60, 255),
    )
    # tiny white hot-spot
    glow_draw.ellipse(
        [CX - 14, CY - 22, CX + 14, CY - 2],
        fill=(255, 245, 200, 200),
    )

    blurred_glow = glow_layer.filter(ImageFilter.GaussianBlur(radius=18))
    img = Image.alpha_composite(img, blurred_glow)
    img = Image.alpha_composite(img, glow_layer)

    # ── outer rim light ───────────────────────────────────────────────────────
    img = composite(img, rim_light(BEZEL_OUT, width=3))

    # ── subtle drop shadow on whole dial ─────────────────────────────────────
    shadow_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    shadow_draw  = ImageDraw.Draw(shadow_layer)
    shadow_draw.ellipse([CX - BEZEL_OUT, CY - BEZEL_OUT, CX + BEZEL_OUT, CY + BEZEL_OUT],
                        fill=(0, 0, 0, 120))
    blurred_shadow = shadow_layer.filter(ImageFilter.GaussianBlur(radius=28))
    # shift shadow down-right
    shadow_shifted = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    shadow_shifted.paste(blurred_shadow, (14, 18))
    # insert behind dial by compositing on background copy
    bg_with_shadow = Image.alpha_composite(make_background(), shadow_shifted)
    # merge: use the dial content from img but with the shadowed bg
    mask_arr = blank()
    mask_arr[:,:,3] = np.where(DIST < BEZEL_OUT + 4, 0, 255)
    bg_mask = Image.fromarray(mask_arr.astype(np.uint8), "RGBA")
    result = Image.alpha_composite(bg_with_shadow, img)

    return result


# ── export ────────────────────────────────────────────────────────────────────

def export_icns(src: Path, dst: Path):
    iconset = dst.with_suffix(".iconset")
    iconset.mkdir(exist_ok=True)
    specs = [
        ("icon_16x16.png",       16),
        ("icon_16x16@2x.png",    32),
        ("icon_32x32.png",       32),
        ("icon_32x32@2x.png",    64),
        ("icon_128x128.png",    128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png",    256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png",    512),
        ("icon_512x512@2x.png", 1024),
    ]
    img = Image.open(src)
    for fname, sz in specs:
        img.resize((sz, sz), PILImage.LANCZOS).save(iconset / fname)
    subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(dst)], check=True)
    for f in iconset.iterdir():
        f.unlink()
    iconset.rmdir()
    print(f"Created {dst}")


if __name__ == "__main__":
    icon = make_icon()
    icon.save(OUT_PNG)
    print(f"Saved {OUT_PNG}")
    export_icns(OUT_PNG, OUT_ICNS)
