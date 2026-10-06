"""Draws the addon's icons from scratch, as genuine 32-bit TGAs (WoW reads textures by file
extension, so a PNG renamed to .tga stays invisible):

- addon/Amisia/Media/Icons/Amisia.tga (128x128): the window portrait and the addon list icon. The
  golden A over the infinity loop of the guild logo, on the logo's turquoise stone. Round; the
  portrait frame of the client lays its own gold ring over the edge.
- addon/Amisia/Media/Icons/Minimap.tga (64x64): the same with a gold rim of its own.

    python tools/make_icons.py [--preview DIR]

Requires Pillow and tools/fonts/Cinzel.ttf (SIL Open Font License 1.1, tools/fonts/OFL.txt; the
font is only used to draw the images, it does not ship in the addon). Drawn at 4x and scaled down
for clean edges; the stone's grain comes from a fixed seed, so a rerun gives the same files.
"""
import argparse
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ICONS = os.path.join(os.path.dirname(HERE), 'addon', 'Amisia', 'Media', 'Icons')
FONT = os.path.join(HERE, 'fonts', 'Cinzel.ttf')
SCALE = 4

GOLD_TOP, GOLD_MID, GOLD_LOW = (255, 244, 196), (236, 184, 84), (128, 80, 22)
OUTLINE = (46, 26, 6)
STONE_HI, STONE_MID, STONE_EDGE = (74, 178, 190), (24, 106, 124), (4, 26, 34)


def lerp(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(len(a)))


def gold_at(t):
    """The gold of the letter at height t (0 top, 1 bottom): bright top, warm middle, dark foot."""
    return lerp(GOLD_TOP, GOLD_MID, t / 0.55) if t < 0.55 else lerp(GOLD_MID, GOLD_LOW, (t - 0.55) / 0.45)


def grain(big, seed):
    """Soft marble grain, 0..255: noise blurred at two scales, with thin dark veins."""
    rnd = random.Random(seed)
    def layer(cell, blur):
        small = Image.new('L', (big // cell + 2, big // cell + 2))
        small.putdata([rnd.randrange(256) for _ in range(small.width * small.height)])
        return small.resize((big + 2 * cell, big + 2 * cell), Image.BICUBIC).crop((cell, cell, cell + big, cell + big)) \
            .filter(ImageFilter.GaussianBlur(blur))
    coarse, fine = layer(48, 10), layer(12, 3)
    mix = ImageChops.blend(coarse, fine, 0.5)
    # veins: where the coarse noise crosses its middle
    veins = coarse.point(lambda v: max(0, 255 - abs(v - 128) * 26))
    return mix, veins.filter(ImageFilter.GaussianBlur(1.5))


def stone(big, radius, seed=7):
    c = big / 2
    img = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    px = img.load()
    mix, veins = grain(big, seed)
    mp, vp = mix.load(), veins.load()
    for y in range(big):
        for x in range(big):
            dx, dy = x + 0.5 - c, y + 0.5 - c
            r = math.hypot(dx, dy)
            if r > radius:
                continue
            # light from the upper middle, dark towards the rim
            t = math.hypot(dx, dy + 0.35 * radius) / (1.35 * radius)
            base = lerp(STONE_HI, STONE_MID, t / 0.55) if t < 0.55 else lerp(STONE_MID, STONE_EDGE, (t - 0.55) / 0.45)
            g = (mp[x, y] - 128) / 128.0
            col = tuple(max(0, min(255, int(v * (1 + 0.22 * g)))) for v in base)
            col = lerp(col, (6, 44, 54), vp[x, y] / 255.0 * 0.28)
            # the rim falls off into shadow
            edge = max(0.0, (r - 0.82 * radius) / (0.18 * radius))
            col = lerp(col, (2, 14, 18), edge ** 1.6 * 0.8)
            px[x, y] = col + (255,)
    return img


def lemniscate(big, cx, cy, w, h, width):
    """The infinity loop of the logo as a mask: a lemniscate of Gerono stroked with a round pen."""
    mask = Image.new('L', (big, big), 0)
    d = ImageDraw.Draw(mask)
    pts = []
    for i in range(721):
        s = 2 * math.pi * i / 720
        pts.append((cx + w / 2 * math.sin(s), cy + h / 2 * math.sin(2 * s)))
    d.line(pts, fill=255, width=int(width), joint='curve')
    r = width / 2
    for x, y in pts[::6]:
        d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    return mask


def letter_mask(big, glyph_h, cx, top):
    font = ImageFont.truetype(FONT, int(glyph_h * 1.42))
    try:
        font.set_variation_by_name('Black')
    except Exception:
        try:
            font.set_variation_by_axes([900])
        except Exception:
            pass
    mask = Image.new('L', (big, big), 0)
    d = ImageDraw.Draw(mask)
    l, t, r, b = d.textbbox((0, 0), 'A', font=font)
    d.text((cx - (l + r) / 2, top - t), 'A', font=font, fill=255)
    return mask


def gilded(big, mask, top, bottom):
    """Gold with a bevel on the shape of mask: a vertical gold ramp, lit edges top left, dark edges
    bottom right, a dark outline and a soft shadow below."""
    fill = Image.new('RGBA', (big, big))
    fp = fill.load()
    span = max(1, bottom - top)
    for y in range(big):
        col = gold_at((y - top) / span) + (255,)
        for x in range(big):
            fp[x, y] = col
    soft = mask.filter(ImageFilter.GaussianBlur(3 * SCALE / 2))
    off = 2 * SCALE // 2
    lit = ImageChops.subtract(soft, ImageChops.offset(soft, off, off))      # edges facing top left
    shade = ImageChops.subtract(soft, ImageChops.offset(soft, -off, -off))  # edges facing bottom right
    fill = Image.composite(Image.new('RGBA', (big, big), (255, 250, 225, 255)), fill, lit.point(lambda v: min(255, v * 3)))
    fill = Image.composite(Image.new('RGBA', (big, big), (70, 40, 8, 255)), fill, shade.point(lambda v: min(200, v * 3)))
    out = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    shadow = mask.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(3 * SCALE))
    out.alpha_composite(Image.merge('RGBA', (*[Image.new('L', (big, big), 0)] * 3, shadow.point(lambda v: int(v * 0.85)))),
                        (SCALE, 2 * SCALE))
    outline = mask.filter(ImageFilter.MaxFilter(2 * (SCALE // 2) * 2 + 1))
    out.alpha_composite(Image.merge('RGBA', (*[Image.new('L', (big, big), v) for v in OUTLINE], outline)))
    fill.putalpha(mask)
    out.alpha_composite(fill)
    return out


def emblem(big):
    """The A over the loop, centred in a square of side big."""
    c = big / 2
    glyph_h = big * 0.56
    top = c - glyph_h * 0.62
    a = letter_mask(big, glyph_h, c, top)
    loop = lemniscate(big, c, top + glyph_h * 1.02, big * 0.52, big * 0.20, big * 0.045)
    out = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    out.alpha_composite(gilded(big, loop, top + glyph_h * 0.9, top + glyph_h * 1.15))
    out.alpha_composite(gilded(big, a, top, top + glyph_h))
    return out


def round_mask(img, radius):
    big = img.width
    c = big / 2
    mask = Image.new('L', (big, big), 0)
    ImageDraw.Draw(mask).ellipse([c - radius, c - radius, c + radius, c + radius], fill=255)
    img.putalpha(ImageChops.multiply(img.getchannel('A'), mask))
    return img


def portrait(size):
    big = size * SCALE
    img = stone(big, big / 2)
    img.alpha_composite(emblem(big))
    return round_mask(img, big / 2).resize((size, size), Image.LANCZOS)


def minimap(size):
    big = size * SCALE
    c = big / 2
    outer, inner = c - 1 * SCALE, c - 5 * SCALE
    img = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # the gold rim, lit from the top left
    rim = Image.new('RGBA', (big, big))
    rp = rim.load()
    for y in range(big):
        for x in range(big):
            t = ((x - c) + (y - c)) / (2 * outer) * 0.5 + 0.5
            rp[x, y] = lerp((246, 214, 130), (128, 88, 28), t) + (255,)
    img = round_mask(rim, outer)
    st = stone(big, inner)
    img.alpha_composite(st)
    d = ImageDraw.Draw(img)
    d.ellipse([c - inner, c - inner, c + inner, c + inner], outline=(40, 26, 8, 255), width=SCALE)
    em = emblem(int(inner * 2.3))
    img.alpha_composite(em, (int(c - em.width / 2), int(c - em.height / 2)))
    return round_mask(img, outer).resize((size, size), Image.LANCZOS)


def write_tga(img, path):
    """Uncompressed 32-bit TGA, top-left origin (descriptor 0x28), pixels as BGRA."""
    w, h = img.size
    header = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, w & 255, w >> 8, h & 255, h >> 8, 32, 0x28])
    r, g, b, a = img.split()
    with open(path, 'wb') as fh:
        fh.write(header + Image.merge('RGBA', (b, g, r, a)).tobytes())


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--preview', help='also write PNGs (4x, nearest) into this folder')
    ap.add_argument('--out', default=ICONS, help='folder for the TGAs (default: the addon icons)')
    args = ap.parse_args()
    for name, img in (('Amisia', portrait(128)), ('Minimap', minimap(64))):
        path = os.path.join(args.out, name + '.tga')
        write_tga(img, path)
        assert os.path.getsize(path) == 18 + img.width * img.height * 4
        if args.preview:
            img.save(os.path.join(args.preview, name + '.png'))
            img.resize((img.width * 3, img.height * 3), Image.LANCZOS).save(os.path.join(args.preview, name + '_big.png'))
        print(f'{os.path.relpath(path)}: {img.width}x{img.height}')


if __name__ == '__main__':
    main()
