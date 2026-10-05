#!/usr/bin/env python3
"""Generate outfit colour variants of the bundled Toon Character poses.

Kenney's Toon Characters ship as finished pictures, so there is no garment
layer to tint. What makes recolouring possible anyway is that the art is flat:
each character's clothing occupies a hue band that nothing else on the figure
shares. Rotating only the pixels inside that band repaints the outfit and
leaves skin, hair and boots alone, and because it works in HSV it carries the
anti-aliased edges with it — an exact-colour swap would leave fringes.

Run from the repository root after changing the palette or the pose list:

    python tool/recolour_outfits.py

It is idempotent: variants are always derived from the unmodified originals,
never from a previous run's output.
"""

import colorsys
import os
import sys

try:
    from PIL import Image
except ImportError:  # pragma: no cover - developer tooling
    sys.exit('This tool needs Pillow:  pip install Pillow')

ROOT = 'assets/story/toon'

# The hue band each character's clothing lives in, in degrees.
#
# Measured rather than guessed: see the docstring. Skin sits at 0-40 degrees on
# every character, so every band below is clear of it. The two worth knowing
# about:
#   pal     - only the trousers are separable; the tan gilet shares the skin
#             band, so it keeps its colour.
#   robot   - the whole chassis is one blue, so the "outfit" is the robot.
GARMENT_BANDS = {
    'explorer': (195, 232),
    'scout': (128, 172),
    'friend': (128, 172),
    'pal': (208, 252),
    'robot': (188, 232),
    'monster': (208, 252),
}

# Target hues, all clear of the 0-40 degree skin band so an outfit never
# muddies into the character wearing it.
PALETTE = {
    'blue': 205,
    'green': 140,
    'yellow': 45,
    'purple': 280,
    'pink': 325,
}

POSES = ['idle', 'walk1', 'run1', 'jump', 'cheer1',
         'wide', 'hold', 'talk', 'think', 'duck']

# Below this saturation a pixel is effectively grey (whites, outlines, shadow)
# and carries no hue worth rotating.
GREY_THRESHOLD = 0.12


def recolour(image, low, high, target_hue):
    out = image.copy()
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if s < GREY_THRESHOLD:
                continue
            if not low <= h * 360 <= high:
                continue
            nr, ng, nb = colorsys.hsv_to_rgb(target_hue / 360, s, v)
            pixels[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    return out


def main():
    if not os.path.isdir(ROOT):
        sys.exit(f'Run me from the repository root; {ROOT} not found.')

    written = 0
    for slug, (low, high) in GARMENT_BANDS.items():
        for pose in POSES:
            source = f'{ROOT}/{slug}/{pose}.png'
            if not os.path.exists(source):
                sys.exit(f'missing original: {source}')
            original = Image.open(source).convert('RGBA')
            for name, hue in PALETTE.items():
                variant = recolour(original, low, high, hue)
                # The pack's own files are indexed PNGs. Saving truecolour
                # RGBA instead doubles the size of every variant for art that
                # only holds a couple of hundred colours, so the variants are
                # quantised back to a palette the way the originals are.
                variant = variant.quantize(
                    colors=255, method=Image.Quantize.FASTOCTREE)
                variant.save(f'{ROOT}/{slug}/{pose}-{name}.png',
                             optimize=True, compress_level=9)
                written += 1
    print(f'wrote {written} variants '
          f'({len(GARMENT_BANDS)} characters x {len(POSES)} poses '
          f'x {len(PALETTE)} colours)')


if __name__ == '__main__':
    main()
