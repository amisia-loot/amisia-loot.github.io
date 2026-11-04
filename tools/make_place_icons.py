"""Draws the map pins of F-105 as genuine 32-bit TGAs, Amisia's own art (2026-11-04, before that
OneForAll's icons; see DECISIONS D-04):

- Amisia/Media/Icons/place_flight.tga (64x64): the flight master's winged boot;
- place_ship_a.tga, place_ship_h.tga (64x64): a ship seen from above, its sails in the faction's
  colour (blue Alliance, red for Horde and the neutral routes);
- place_zeppelin.tga (128x64): a zeppelin seen from above, twice as wide as high.

    python tools/make_place_icons.py [--preview DIR] [--out DIR]

Every shape is drawn eight times larger and scaled down (smooth edges), then gets a dark rim like
the client's map marks. Requires Pillow. A changed texture needs a full client restart before WoW
shows it; /reload is not enough.
"""
import argparse
import math
import os

from PIL import Image, ImageDraw, ImageFilter

import make_icons

SS = 8                         # supersampling
RIM = (22, 14, 10, 235)        # the dark rim around every pin
WOOD, WOOD_LIGHT, WOOD_DARK = (112, 72, 40), (146, 98, 56), (64, 40, 22)
SILVER, SILVER_LIGHT, SILVER_DARK = (196, 196, 202), (232, 232, 238), (128, 128, 138)
SAIL = {'a': ((44, 104, 206), (150, 190, 245)), 'h': ((176, 30, 26), (236, 120, 96))}


class Canvas:
    """A see-through canvas in pin units (w x h), drawn SS times larger."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new('RGBA', (w * SS, h * SS), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def _pts(self, pts):
        return [(x * SS, y * SS) for x, y in pts]

    def poly(self, pts, fill):
        self.d.polygon(self._pts(pts), fill=fill)

    def ellipse(self, box, fill):
        x0, y0, x1, y1 = box
        self.d.ellipse([x0 * SS, y0 * SS, x1 * SS, y1 * SS], fill=fill)

    def rect(self, box, fill, r=0):
        x0, y0, x1, y1 = box
        self.d.rounded_rectangle([x0 * SS, y0 * SS, x1 * SS, y1 * SS], radius=r * SS, fill=fill)

    def line(self, pts, fill, width):
        self.d.line(self._pts(pts), fill=fill, width=max(1, round(width * SS)), joint='curve')

    def done(self, rim=1.6):
        """The picture at pin size with its dark rim."""
        small = self.img.resize((self.w, self.h), Image.LANCZOS)
        grow = self.img.getchannel('A').filter(ImageFilter.MaxFilter(2 * round(rim * SS) + 1))
        grow = grow.resize((self.w, self.h), Image.LANCZOS)
        out = Image.new('RGBA', (self.w, self.h), RIM[:3] + (0,))
        out.putalpha(grow.point(lambda a: a * RIM[3] // 255))
        out.alpha_composite(small)
        return out


def feather(c, base, angle, length, width, fill, vein):
    """A feather from base pointing at angle (degrees, y down), widest at 55 %."""
    a = math.radians(angle)
    dx, dy = math.cos(a), math.sin(a)
    px, py = -dy, dx
    bx, by = base

    def at(t, s):
        return (bx + dx * length * t + px * width * s / 2, by + dy * length * t + py * width * s / 2)
    c.poly([at(0, 0.5), at(0.55, 1), at(0.9, 0.55), at(1, 0), at(0.9, -0.55), at(0.55, -1), at(0, -0.5)], fill)
    c.line([at(0.05, 0), at(0.92, 0)], vein, 0.7)


def flight():
    c = Canvas(64, 64)
    # the wing behind the boot: four feathers fanning up and back from the heel
    for angle, length in ((-172, 29), (-150, 31), (-127, 29), (-104, 23), (-84, 15)):
        feather(c, (32, 32), angle, length, 10, SILVER_LIGHT, SILVER_DARK)
    for angle, length in ((-161, 19), (-138, 20), (-115, 17)):
        feather(c, (32, 32), angle, length, 7, SILVER, SILVER_DARK)
    # the boot, toe to the right
    boot = [(30, 22), (43, 22), (43, 37), (47, 40), (55, 42), (60, 44.5), (61.5, 48.5), (60.5, 53), (28, 53),
            (27, 46), (29, 38)]
    c.poly(boot, SILVER)
    c.poly([(30, 22), (36, 22), (35, 38), (33, 46), (28, 47), (29, 38)], SILVER_LIGHT)
    c.poly([(28, 50), (61.2, 50), (60.5, 53), (28, 53)], SILVER_DARK)            # the sole
    c.rect((28.5, 20.5, 44.5, 26.5), WOOD, 1.2)                               # the cuff
    c.rect((28.5, 20.5, 44.5, 22.5), WOOD_LIGHT, 1)
    c.line([(44, 40), (50, 43.5)], SILVER_DARK, 0.8)                           # the instep
    return c.done()


def ship(side):
    c = Canvas(64, 64)
    sail, sail_light = SAIL[side]
    hull = [(4, 32), (10, 24.5), (38, 22), (51, 24.5), (61, 32), (51, 39.5), (38, 42), (10, 39.5)]
    c.poly(hull, WOOD_DARK)
    c.poly([(7, 32), (12, 26.5), (38, 24.5), (49.5, 27), (57.5, 32), (49.5, 37), (38, 39.5), (12, 37.5)], WOOD)
    for y in (29, 32, 35):                                                      # the planks
        c.line([(12, y), (50, y)], WOOD_DARK, 0.6)
    c.line([(60, 32), (64, 32)], WOOD_LIGHT, 1.2)                              # the bowsprit
    # the sails seen from above: bars across the deck, the middle one the largest
    for x, half in ((19, 12.5), (32, 15), (44, 11.5)):
        c.rect((x - 3, 32 - half, x + 3, 32 + half), sail, 2)
        c.rect((x - 1, 32 - half + 1.5, x + 1, 32 + half - 1.5), sail_light, 1)
    c.ellipse((30.5, 30.5, 33.5, 33.5), WOOD_DARK)                             # the main mast
    return c.done()


def zeppelin():
    c = Canvas(128, 64)
    # the tail fins first, then the balloon over them
    c.poly([(96, 32), (118, 17), (123, 19), (113, 32), (123, 45), (118, 47)], SILVER_DARK)
    c.poly([(99, 32), (117, 20), (111, 32), (117, 44)], SILVER)
    c.ellipse((6, 15, 108, 49), SILVER_DARK)
    c.ellipse((8, 17, 106, 47), SILVER)
    c.ellipse((14, 19, 100, 31), SILVER_LIGHT)                                  # the light on top
    c.rect((12, 30.5, 102, 33.5), SILVER_DARK, 1.5)                             # the seam
    for x in (24, 38, 52, 66, 80, 92):                                          # the ribs
        half = 15.5 * math.sqrt(max(0.0, 1 - ((x - 57) / 50) ** 2))
        c.line([(x, 32 - half), (x + 1.5, 32), (x, 32 + half)], SILVER_DARK, 0.7)
    c.rect((44, 28, 70, 36), WOOD, 2)                                           # the gondola's roof
    c.rect((46, 29.5, 68, 34.5), WOOD_LIGHT, 1.5)
    return c.done()


PICTURES = {'place_flight': flight, 'place_ship_a': lambda: ship('a'), 'place_ship_h': lambda: ship('h'),
            'place_zeppelin': zeppelin}


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--preview', help='also write PNGs (and one enlarged sheet) into this folder')
    ap.add_argument('--out', default=make_icons.ICONS, help='folder for the TGAs (default: the addon icons)')
    args = ap.parse_args()
    made = []
    for name, draw in PICTURES.items():
        img = draw()
        path = os.path.join(args.out, name + '.tga')
        make_icons.write_tga(img, path)
        assert os.path.getsize(path) == 18 + img.width * img.height * 4
        made.append(img)
        if args.preview:
            img.save(os.path.join(args.preview, name + '.png'))
        print(f'{os.path.relpath(path)}: {img.width}x{img.height}')
    if args.preview:
        sheet = Image.new('RGBA', (sum(i.width for i in made) * 3 + 30 * len(made), 64 * 3), (40, 35, 50, 255))
        x = 0
        for img in made:
            sheet.alpha_composite(img.resize((img.width * 3, img.height * 3), Image.LANCZOS), (x, 0))
            x += img.width * 3 + 30
        sheet.save(os.path.join(args.preview, 'place_icons.png'))


if __name__ == '__main__':
    main()
