#!/usr/bin/env python3
"""Generate the menu bar template icon: a curled armadillo shell —
a ball with four tapered claw-shaped cuts sweeping from the top rim
toward the lower left. Writes a black+alpha PNG; the app loads it as
an NSImage template so macOS tints it per menu bar appearance."""

import math
from pathlib import Path
from PIL import Image
import numpy as np

W = 512
OUT = Path(__file__).parent.parent / "Sources" / "LokaliteApp" / "Resources" / "MenuBarIcon.png"

BALL_CENTER = (258, 268)
BALL_RADIUS = 208
CLAW_ARC_CENTER = (500, 170)
# (arc radius, max thickness, tip angle, base angle) per claw,
# angles in degrees around CLAW_ARC_CENTER, y-down. Claws taper from a
# wide base at the top rim to a point at the tip (bottom-center).
CLAWS = [
    (145, 40, 152, 246),
    (205, 48, 145, 256),
    (265, 57, 140, 266),
    (322, 64, 146, 276),
]
TAPER_POWER = 0.5  # thickness ~ progress^power from tip to base

Y, X = np.mgrid[:W, :W].astype(np.float64)


def build():
    ball = (X - BALL_CENTER[0]) ** 2 + (Y - BALL_CENTER[1]) ** 2 <= BALL_RADIUS**2
    px, py = CLAW_ARC_CENTER
    d = np.sqrt((X - px) ** 2 + (Y - py) ** 2)
    ang = np.degrees(np.arctan2(Y - py, X - px)) % 360
    claws = np.zeros((W, W), dtype=bool)
    for radius, tmax, a1, a2 in CLAWS:
        f = np.clip((ang - a1) / (a2 - a1), 0, 1)
        t = tmax * f**TAPER_POWER
        claws |= (np.abs(d - radius) <= t / 2) & (ang >= a1) & (ang <= a2)
    return ball & ~claws


def export(mask_bool, size=216, margin=1.04):
    ys, xs = np.where(mask_bool)
    im = Image.fromarray((mask_bool * 255).astype(np.uint8))
    im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    w, h = im.size
    side = int(max(w, h) * margin)
    sq = Image.new("L", (side, side), 0)
    sq.paste(im, ((side - w) // 2, (side - h) // 2))
    mask = sq.resize((size, size), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(Image.new("RGBA", (size, size), (0, 0, 0, 255)), (0, 0), mask)
    out.save(OUT)
    print(f"Saved {OUT}")


if __name__ == "__main__":
    export(build())
