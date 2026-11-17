#!/usr/bin/env python3
"""Cuts the Teams icons out of an icon sheet.

    python tools/make_teams_icons.py <sheet.png>

The sheet holds a colour icon (left) and a white outline icon (right) on a
checkerboard that is part of the picture (no real transparency). Writes into
layers/assets/common/:

    teams-color-192.png     192x192, 256-colour palette, transparent corners
    teams-outline-32.png    32x32, white shape on transparent

The coordinates below are for the sheet "Mentenaz Forge Icon Set.png"
(1254x1254). Another sheet needs its own regions.
Needs Pillow and numpy.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "layers" / "assets" / "common"

COLOR_REGION = (0, 860, 200, 1054)     # x0, x1, y0, y1
OUTLINE_REGION = (860, 1254, 520, 960)


def flood(candidate, seeds):
    """The 4-connected part of `candidate` reachable from `seeds`."""
    region = seeds & candidate
    while True:
        grown = region.copy()
        grown[1:, :] |= region[:-1, :]
        grown[:-1, :] |= region[1:, :]
        grown[:, 1:] |= region[:, :-1]
        grown[:, :-1] |= region[:, 1:]
        grown &= candidate
        if (grown == region).all():
            return region
        region = grown


def erode(mask, steps):
    for _ in range(steps):
        e = mask.copy()
        e[1:, :] &= mask[:-1, :]
        e[:-1, :] &= mask[1:, :]
        e[:, 1:] &= mask[:, :-1]
        e[:, :-1] &= mask[:, 1:]
        mask = e
    return mask


def square(img):
    w, h = img.size
    s = max(w, h)
    out = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    out.paste(img, ((s - w) // 2, (s - h) // 2))
    return out


def shrink(img, size):
    # Premultiplied alpha, so the edge does not pick up a dark or light halo.
    return img.convert("RGBa").resize((size, size), Image.LANCZOS).convert("RGBA")


def colour_icon(rgb):
    x0, x1, y0, y1 = COLOR_REGION
    sub = rgb[y0:y1, x0:x1]
    mx, mn = sub.max(2), sub.min(2)
    sat = (mx - mn) / np.maximum(mx, 1)
    # The checkerboard is grey. Everything grey that touches the edge of the
    # region is background; the icon's own rim is saturated, so it stops there.
    candidate = (sat < 0.12) & (mx > 110)
    seeds = np.zeros_like(candidate)
    seeds[0, :] = seeds[-1, :] = seeds[:, 0] = seeds[:, -1] = True
    icon = erode(~flood(candidate, seeds), 2)
    ys, xs = np.where(icon)
    rgba = np.dstack([sub.astype(np.uint8), (icon * 255).astype(np.uint8)])
    img = Image.fromarray(rgba, "RGBA").crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    # A 256-colour palette keeps it to ~14 KB instead of ~65 KB; Teams shows it small.
    return shrink(square(img), 192).quantize(colors=256, method=Image.Quantize.FASTOCTREE)


def outline_icon(rgb):
    x0, x1, y0, y1 = OUTLINE_REGION
    sub = rgb[y0:y1, x0:x1]
    # The shape is pure white, the checkerboard never gets above ~215.
    alpha = (np.clip((sub.min(2) - 225) / 25.0, 0, 1) * 255).astype(np.uint8)
    ys, xs = np.where(alpha > 128)
    white = np.full(alpha.shape + (3,), 255, np.uint8)
    img = Image.fromarray(np.dstack([white, alpha]), "RGBA")
    img = img.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    return shrink(square(img), 32)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    rgb = np.asarray(Image.open(sys.argv[1]).convert("RGB")).astype(np.int32)
    OUT.mkdir(parents=True, exist_ok=True)
    colour_icon(rgb).save(OUT / "teams-color-192.png", optimize=True)
    outline_icon(rgb).save(OUT / "teams-outline-32.png", optimize=True)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
