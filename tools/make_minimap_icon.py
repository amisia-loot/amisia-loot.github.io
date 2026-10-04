"""Draws addon/Amisia/Media/Icons/Minimap.tga: the golden A of the addon logo on the guild's
turquoise stone with a gold rim, round, 64x64, as a genuine 32-bit TGA (WoW reads textures by file
extension, so a PNG renamed to .tga stays invisible).

    python tools/make_minimap_icon.py [--preview out.png]

Requires Pillow. Drawn at 4x and scaled down for clean edges.
"""
import argparse
import math
import os

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ICONS = os.path.join(os.path.dirname(HERE), 'addon', 'Amisia', 'Media', 'Icons')
SIZE, SCALE = 64, 4


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(len(a)))


def draw(letter_path):
    big = SIZE * SCALE
    c = big / 2
    img = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    px = img.load()
    rim_outer, rim_inner = c - 1 * SCALE, c - 4.5 * SCALE
    gold_hi, gold_lo = (240, 206, 120), (138, 98, 34)
    stone_mid, stone_edge = (38, 120, 136), (9, 40, 52)
    for y in range(big):
        for x in range(big):
            dx, dy = x + 0.5 - c, y + 0.5 - c
            r = math.hypot(dx, dy)
            if r > rim_outer:
                continue
            if r > rim_inner:
                # gold rim, lit from the top left
                t = (dx + dy) / (2 * rim_outer) * 0.5 + 0.5
                px[x, y] = lerp(gold_hi, gold_lo, t) + (255,)
            else:
                # turquoise stone, brighter towards the upper middle
                t = min(1.0, math.hypot(dx, dy + 0.25 * c) / rim_inner)
                px[x, y] = lerp(stone_mid, stone_edge, t ** 1.4) + (255,)
    # a thin dark line between stone and rim
    d = ImageDraw.Draw(img)
    d.ellipse([c - rim_inner, c - rim_inner, c + rim_inner, c + rim_inner], outline=(40, 26, 8, 255), width=SCALE)

    letter = Image.open(letter_path).convert('RGBA')
    side = int(big * 0.70)
    letter = letter.resize((side, side), Image.LANCZOS)
    pos = (int(c - side / 2), int(c - side / 2 - 1 * SCALE))
    # soft shadow under the letter
    shadow = Image.new('RGBA', letter.size, (0, 0, 0, 0))
    shadow.putalpha(letter.getchannel('A').point(lambda a: int(a * 0.75)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(2 * SCALE))
    img.alpha_composite(shadow, (pos[0] + SCALE, pos[1] + 2 * SCALE))
    img.alpha_composite(letter, pos)
    # nothing may spill outside the round button
    mask = Image.new('L', (big, big), 0)
    ImageDraw.Draw(mask).ellipse([c - rim_outer, c - rim_outer, c + rim_outer, c + rim_outer], fill=255)
    img.putalpha(Image.composite(img.getchannel('A'), Image.new('L', (big, big), 0), mask))
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def write_tga(img, path):
    """Uncompressed 32-bit TGA, top-left origin (descriptor 0x28), pixels as BGRA."""
    w, h = img.size
    header = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, w & 255, w >> 8, h & 255, h >> 8, 32, 0x28])
    r, g, b, a = img.split()
    with open(path, 'wb') as fh:
        fh.write(header + Image.merge('RGBA', (b, g, r, a)).tobytes())


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--preview', help='also write a PNG for looking at')
    args = ap.parse_args()
    img = draw(os.path.join(ICONS, 'Amisia.tga'))
    out = os.path.join(ICONS, 'Minimap.tga')
    write_tga(img, out)
    size = os.path.getsize(out)
    assert size == 18 + SIZE * SIZE * 4, size
    if args.preview:
        img.resize((256, 256), Image.NEAREST).save(args.preview)
    print(f'{os.path.relpath(out)}: {size} bytes')


if __name__ == '__main__':
    main()
