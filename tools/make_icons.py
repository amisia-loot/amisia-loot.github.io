"""Makes the addon's icon, a genuine 32-bit TGA (WoW reads textures by file extension, so a PNG
renamed to .tga stays invisible), from the picture the user chose (2026-10-15):

- tools/art/Amisia.png (the source, any size, with a see-through ground) ->
  Amisia/Media/Icons/Amisia.tga (128x128): the addon's one icon, everywhere it shows (window
  portraits, addon list and compartment, minimap button). The picture is scaled to fit inside the
  round portrait (every visible pixel within FIT of the radius), so the client's round mask and gold
  ring cut nothing off; the ground stays see-through (the windows and the minimap button lay a black
  disc under it, W.DISC).

    python tools/make_icons.py [--preview DIR]

Requires Pillow. A changed texture needs a full client restart before WoW shows it; /reload is not
enough.
"""
import argparse
import math
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ICONS = os.path.join(os.path.dirname(HERE), 'Amisia', 'Media', 'Icons')
SOURCE = os.path.join(HERE, 'art', 'Amisia.png')
SIZE = 128
FIT = 0.90       # the farthest visible pixel, as a share of the radius
VISIBLE = 24     # alpha from which a pixel counts as visible


def fitted(src, size):
    """src scaled and centred on a size x size see-through square, every visible pixel inside the
    circle of radius FIT * size / 2."""
    src = src.convert('RGBA')
    box = src.getchannel('A').point(lambda a: 255 if a >= VISIBLE else 0).getbbox()
    src = src.crop(box)
    w, h = src.size
    alpha = src.getchannel('A').load()
    cx, cy = w / 2, h / 2
    far = max(math.hypot(x + 0.5 - cx, y + 0.5 - cy) for y in range(h) for x in range(w) if alpha[x, y] >= VISIBLE)
    scale = FIT * size / 2 / far
    pic = src.resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.LANCZOS)
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.alpha_composite(pic, (round((size - pic.width) / 2), round((size - pic.height) / 2)))
    return out


def write_tga(img, path):
    """Uncompressed 32-bit TGA, top-left origin (descriptor 0x28), pixels as BGRA."""
    w, h = img.size
    header = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, w & 255, w >> 8, h & 255, h >> 8, 32, 0x28])
    r, g, b, a = img.split()
    with open(path, 'wb') as fh:
        fh.write(header + Image.merge('RGBA', (b, g, r, a)).tobytes())


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--preview', help='also write PNGs into this folder')
    ap.add_argument('--out', default=ICONS, help='folder for the TGA (default: the addon icons)')
    args = ap.parse_args()
    img = fitted(Image.open(SOURCE), SIZE)
    path = os.path.join(args.out, 'Amisia.tga')
    write_tga(img, path)
    assert os.path.getsize(path) == 18 + img.width * img.height * 4
    if args.preview:
        img.save(os.path.join(args.preview, 'Amisia.png'))
        on = Image.new('RGBA', img.size, (0, 0, 0, 0))
        disc = Image.new('L', img.size, 0)
        from PIL import ImageDraw
        ImageDraw.Draw(disc).ellipse([0, 0, img.width - 1, img.height - 1], fill=255)
        on.paste((0, 0, 0, 255), mask=disc)
        on.alpha_composite(img)
        on.resize((img.width * 3, img.height * 3), Image.LANCZOS).save(os.path.join(args.preview, 'Amisia_on_black.png'))
    print(f'{os.path.relpath(path)}: {img.width}x{img.height}')


if __name__ == '__main__':
    main()
