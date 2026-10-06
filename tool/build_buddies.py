#!/usr/bin/env python3
"""Compose the hero's companions from Kenney's Monster Builder Pack.

The companions were animal portraits — heads in circles — which read as a
floating face next to a hero drawn head to foot. Kenney has no full-body
animal set in the flat-vector style the heroes are drawn in; the Monster
Builder Pack is by the same artist in the same register and *is* full-body, so
the companions are little monsters.

The pack ships as parts rather than finished creatures, so each companion is
composed here once and saved as a single picture. The app then draws a
companion the same way it draws a hero: one `Image.asset`, nothing to assemble
at runtime and nothing to get out of step.

Run from the repository root:

    python tool/build_buddies.py

The pack is downloaded on first run and cached next to this script.
"""

import io
import os
import sys
import urllib.request
import zipfile

try:
    from PIL import Image
except ImportError:  # pragma: no cover - developer tooling
    sys.exit('This tool needs Pillow:  pip install Pillow')

PACK_URL = ('https://kenney.nl/media/pages/assets/monster-builder-pack/'
            '663e4ef6de-1677495438/kenney_monster-builder-pack.zip')
CACHE = 'tool/.cache/kenney_monster-builder-pack.zip'
DEST = 'assets/story/pets'

# Each companion: the parts it is built from. Spread across the pack's six
# colourways so a row of them reads as six different creatures rather than six
# shades of one, and every face chosen from the pack's cheerful half — it ships
# angry, dead and psycho eyes too, which are not what should be following a
# four-year-old's hero around.
BUDDIES = {
    'pip':    ('body_greenB',  'arm_greenC',  'leg_greenA',  'eye_cute_light', 'mouth_closed_happy',  'detail_green_horn_large'),
    'bloop':  ('body_blueD',   'arm_blueA',   'leg_blueC',   'eye_human_blue', 'mouthB',              'detail_blue_antenna_large'),
    'sunny':  ('body_yellowA', 'arm_yellowE', 'leg_yellowB', 'eye_closed_happy', 'mouthH',            'detail_yellow_ear_round'),
    'berry':  ('body_redC',    'arm_redB',    'leg_redD',    'eye_cute_dark',  'mouthE',              'detail_red_horn_small'),
    'snow':   ('body_whiteE',  'arm_whiteD',  'leg_whiteE',  'eye_human',      'mouthE',              'detail_white_ear'),
    'shadow': ('body_darkF',   'arm_darkC',   'leg_darkA',   'eye_yellow',     'mouthJ',              'detail_dark_antenna_small'),
    'mint':   ('body_greenE',  'arm_greenA',  'leg_greenD',  'eye_cute_light', 'mouthA',              'detail_green_ear'),
    'sky':    ('body_blueA',   'arm_blueE',   'leg_blueB',   'eye_blue',       'mouth_closed_happy',  'detail_blue_ear_round'),
    'rusty':  ('body_redF',    'arm_redE',    'leg_redA',    'eye_human_red',  'mouth_closed_happy',  'detail_red_ear'),
    'cloud':  ('body_whiteA',  'arm_whiteB',  'leg_whiteC',  'eye_closed_happy',    'mouthA',           'detail_white_antenna_small'),
}

# Tuned by eye against the pack's own preview: legs tuck 55% behind the body,
# arms 65%, so the limbs read as attached rather than stuck on.
LEG_OVERLAP = 0.55
ARM_OVERLAP = 0.65
BODY_WIDTH = 150          # px before the final crop
CELL = (300, 340)


def load_pack():
    if not os.path.exists(CACHE):
        os.makedirs(os.path.dirname(CACHE), exist_ok=True)
        print(f'downloading {PACK_URL}')
        urllib.request.urlretrieve(PACK_URL, CACHE)
    return zipfile.ZipFile(CACHE)


def compose(pack, body, arm, leg, eye, mouth, detail):
    def part(name):
        return Image.open(
            io.BytesIO(pack.read(f'PNG/Default/{name}.png'))).convert('RGBA')

    canvas = Image.new('RGBA', CELL, (0, 0, 0, 0))
    b = part(body)
    scale = BODY_WIDTH / b.width

    def sized(image):
        return image.resize(
            (max(1, int(image.width * scale)), max(1, int(image.height * scale))),
            Image.LANCZOS)

    b = sized(b)
    bx, by = (CELL[0] - b.width) // 2, 80

    d = sized(part(detail))
    inset = int(b.width * 0.12)
    top = by - d.height + int(d.height * 0.35)
    canvas.alpha_composite(d, (bx + inset, top))
    canvas.alpha_composite(d.transpose(Image.FLIP_LEFT_RIGHT),
                           (bx + b.width - d.width - inset, top))

    l = sized(part(leg))
    ly = by + b.height - int(l.height * LEG_OVERLAP)
    canvas.alpha_composite(l, (bx + int(b.width * 0.14), ly))
    canvas.alpha_composite(l.transpose(Image.FLIP_LEFT_RIGHT),
                           (bx + b.width - l.width - int(b.width * 0.14), ly))

    a = sized(part(arm))
    ax = int(a.width * ARM_OVERLAP)
    ay = by + int(b.height * 0.22)
    canvas.alpha_composite(a, (bx - a.width + ax, ay))
    canvas.alpha_composite(a.transpose(Image.FLIP_LEFT_RIGHT),
                           (bx + b.width - ax, ay))

    canvas.alpha_composite(b, (bx, by))

    e = sized(part(eye))
    canvas.alpha_composite(e, (bx + (b.width - e.width) // 2,
                               by + int(b.height * 0.22)))
    m = sized(part(mouth))
    canvas.alpha_composite(m, (bx + (b.width - m.width) // 2,
                               by + int(b.height * 0.62)))

    # Crop to what was actually drawn, so the app can place a companion by its
    # own edges rather than guessing at transparent padding.
    return canvas.crop(canvas.getbbox())


def main():
    if not os.path.isdir(DEST):
        sys.exit(f'Run me from the repository root; {DEST} not found.')
    pack = load_pack()

    for name, parts in BUDDIES.items():
        image = compose(pack, *parts)
        image.quantize(colors=255, method=Image.Quantize.FASTOCTREE).save(
            f'{DEST}/{name}.png', optimize=True, compress_level=9)
    # The pack's licence travels with the art it covers.
    open(f'{DEST}/License.txt', 'wb').write(pack.read('License.txt'))
    print(f'wrote {len(BUDDIES)} companions to {DEST}')


if __name__ == '__main__':
    main()
