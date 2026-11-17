#!/usr/bin/env python3
"""Makes the welcome image that replaces Microsoft's welcome-dark/light.png.

    python tools/make_welcome_image.py

Reads layers/assets/common/forge-logo.png (the original logo) and writes
layers/assets/common/forge-logo-welcome.png:

* the empty transparent margin is cropped away,
* the longest side is 300 px (the web part shows the image up to 420 px wide,
  so going much smaller looks soft),
* a 256-colour palette with transparency. The logo is 368 KB as a full-colour
  PNG and about 135 KB after a plain resize; as a palette image it is about
  38 KB, and at the size it is shown it looks the same.

A web part carries the image twice (dark and light), so this matters for the
size of every generated solution package.
Needs Pillow.
"""
from pathlib import Path

from PIL import Image

COMMON = Path(__file__).resolve().parent.parent / "layers" / "assets" / "common"
SIZE = 300


def main():
    logo = Image.open(COMMON / "forge-logo.png").convert("RGBA")
    visible = logo.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    image = logo.crop(visible)
    image.thumbnail((SIZE, SIZE), Image.LANCZOS)
    image = image.quantize(colors=256, method=Image.Quantize.FASTOCTREE)
    out = COMMON / "forge-logo-welcome.png"
    image.save(out, optimize=True)
    print(f"wrote {out} ({image.size[0]}x{image.size[1]}, {out.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
