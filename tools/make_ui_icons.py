"""Makes the hub's own symbols (D-81): gold line art for the tabs and the side bar's pages, genuine
32-bit TGAs (WoW reads textures by file extension, so a PNG renamed to .tga stays invisible).

Each symbol is an icon of Lucide (lucide.dev, ISC; the SVGs are kept in tools/art/lucide, fetched
once from unpkg's lucide-static at LUCIDE_VERSION when missing). It is drawn at RENDER px with a
thicker stroke, coloured with a gold gradient (light at the top, deep at the bottom) over a soft dark
rim so it reads on the dark hub, scaled down to SIZE and written to
Amisia/Media/Icons/ui/<key>.tga. The keys are those of ns.Theme.NAV_ICONS and T.TAB_ICONS
("tab_<group>" for a tab). Also Amisia's own shapes of the item slots: slot_ring (a thin rounded
frame, white, coloured by the addon) and slot_mask (the rounded icon inside it).

    python tools/make_ui_icons.py [--preview DIR] [--offline]

Requires Pillow and resvg-py (pip install resvg-py, no system libraries). A new texture needs a full
client restart before WoW shows it; /reload is not enough.
"""
import argparse
import os
import re
import urllib.request

from PIL import Image, ImageFilter
import resvg_py

from make_icons import write_tga

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), 'Amisia', 'Media', 'Icons', 'ui')
SVGS = os.path.join(HERE, 'art', 'lucide')
LUCIDE_VERSION = '0.460.0'
SIZE = 64
RENDER = 256
STROKE = '2.4'                 # Lucide draws 2 on 24; a little thicker reads better at 16 px
TOP, BOTTOM = (255, 236, 170), (201, 144, 46)   # the gold gradient
RIM = (24, 14, 4)              # the dark rim under it
RIM_GROW, RIM_BLUR, RIM_ALPHA = 13, 4, 0.85

# key -> Lucide icon
ICONS = {
    # the tabs (T.TAB_ICONS)
    'tab_gear': 'shield', 'tab_dungeons': 'swords', 'tab_prof': 'hammer', 'tab_talents': 'sparkles',
    'tab_raid': 'dices', 'tab_guild': 'users', 'tab_amisia': 'settings',
    # Raid
    'overview': 'layout-dashboard', 'lineup': 'list-ordered', 'raidcheck': 'clipboard-check', 'softres': 'bookmark',
    'rolls': 'dices', 'awards': 'gift', 'raidlog': 'scroll-text', 'points': 'coins', 'stats': 'chart-column',
    'raids': 'archive', 'export': 'share-2', 'raidnote': 'notebook-pen',
    # Ausrüstung, Berufe, Talente
    'planner': 'shirt', 'gear': 'shield-half', 'professions': 'hammer', 'scrolls': 'scroll', 'talents': 'sparkles',
    # Dungeons & Raids
    'dungeons': 'castle', 'raidjournal': 'skull', 'quests': 'flag', 'map': 'map',
    # Gilde, Amisia
    'members': 'users', 'calendar': 'calendar-days', 'bank': 'landmark', 'duels': 'swords', 'tools': 'wrench',
    'settings': 'settings', 'about': 'info', 'feedback': 'message-square',
    # the side windows
    'win_talents': 'network', 'win_rolls': 'dice-5', 'win_softres': 'clipboard-list', 'win_layer': 'layers',
    # the professions page (D-82): the filter menu's button and the favourite star
    'prof_filter': 'filter', 'prof_star': 'star',
}


def svg_of(name, offline=False):
    path = os.path.join(SVGS, name + '.svg')
    if not os.path.exists(path):
        if offline:
            raise SystemExit(f'missing {path} (run without --offline once)')
        url = f'https://unpkg.com/lucide-static@{LUCIDE_VERSION}/icons/{name}.svg'
        with urllib.request.urlopen(url, timeout=30) as r:
            text = r.read().decode('utf-8')
        os.makedirs(SVGS, exist_ok=True)
        with open(path, 'w', encoding='utf-8') as fh:
            fh.write(text)
    with open(path, encoding='utf-8') as fh:
        return fh.read()


def mask(svg):
    """The icon's strokes as an alpha mask at RENDER px (white, the stroke a little thicker)."""
    svg = svg.replace('currentColor', '#ffffff')
    svg = re.sub(r'stroke-width="[\d.]+"', f'stroke-width="{STROKE}"', svg, count=1)
    png = bytes(resvg_py.svg_to_bytes(svg_string=svg, width=RENDER, height=RENDER))
    from io import BytesIO
    return Image.open(BytesIO(png)).convert('RGBA').getchannel('A')


def draw(alpha):
    """Gold gradient strokes over a soft dark rim, scaled to SIZE."""
    w, h = alpha.size
    grad = Image.new('RGBA', (w, h))
    px = grad.load()
    for y in range(h):
        t = y / (h - 1)
        c = tuple(round(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3))
        for x in range(w):
            px[x, y] = c + (255,)
    gold = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    gold.paste(grad, (0, 0), alpha)
    rim_a = alpha.filter(ImageFilter.MaxFilter(RIM_GROW)).filter(ImageFilter.GaussianBlur(RIM_BLUR))
    rim_a = rim_a.point(lambda a: round(a * RIM_ALPHA))
    rim = Image.new('RGBA', (w, h), RIM + (0,))
    rim.putalpha(rim_a)
    out = Image.alpha_composite(rim, gold)
    return out.resize((SIZE, SIZE), Image.LANCZOS)


# the item slots' frame (D-81 Nachtrag): a thin rounded ring (white, coloured by the addon) and the
# rounded mask for the icon inside it, drawn SHAPE_SCALE times larger and scaled to SIZE
SHAPE_SCALE = 8
RING_RADIUS, RING_STROKE = 12, 3        # at SIZE px
MASK_INSET, MASK_RADIUS = 2, 10


def rounded(fill, inset, radius, stroke=None):
    from PIL import ImageDraw
    big = SIZE * SHAPE_SCALE
    img = Image.new('RGBA', (big, big), (255, 255, 255, 0))
    d = ImageDraw.Draw(img)
    box = [inset * SHAPE_SCALE, inset * SHAPE_SCALE, big - 1 - inset * SHAPE_SCALE, big - 1 - inset * SHAPE_SCALE]
    if fill:
        d.rounded_rectangle(box, radius=radius * SHAPE_SCALE, fill=(255, 255, 255, 255))
    else:
        d.rounded_rectangle(box, radius=radius * SHAPE_SCALE, outline=(255, 255, 255, 255), width=stroke * SHAPE_SCALE)
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def circle_ring(stroke):
    """A round ring (white, coloured by the addon) over the full square: the frame of a boss's
    portrait (F-154); the portrait is a model, which no mask cuts, so the ring only frames it."""
    from PIL import ImageDraw
    big = SIZE * SHAPE_SCALE
    img = Image.new('RGBA', (big, big), (255, 255, 255, 0))
    ImageDraw.Draw(img).ellipse([0, 0, big - 1, big - 1], outline=(255, 255, 255, 255), width=stroke * SHAPE_SCALE)
    return img.resize((SIZE, SIZE), Image.LANCZOS)


BOSS_RING_STROKE = 4                    # at SIZE px


SHAPES = {
    'slot_ring': lambda: rounded(False, 0, RING_RADIUS, RING_STROKE),
    'slot_mask': lambda: rounded(True, MASK_INSET, MASK_RADIUS),
    'boss_ring': lambda: circle_ring(BOSS_RING_STROKE),
}


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--out', default=OUT)
    ap.add_argument('--preview', help='also write a contact sheet PNG into this folder')
    ap.add_argument('--offline', action='store_true', help='only the SVGs kept in tools/art/lucide')
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    done = []
    for key, name in ICONS.items():
        img = draw(mask(svg_of(name, args.offline)))
        write_tga(img, os.path.join(args.out, key + '.tga'))
        done.append((key, img))
    for key, make in SHAPES.items():
        img = make()
        write_tga(img, os.path.join(args.out, key + '.tga'))
        done.append((key, img))
    if args.preview:
        os.makedirs(args.preview, exist_ok=True)
        cols = 8
        rows = (len(done) + cols - 1) // cols
        sheet = Image.new('RGBA', (cols * 80, rows * 80), (18, 14, 10, 255))
        for i, (_, img) in enumerate(done):
            sheet.alpha_composite(img, ((i % cols) * 80 + 8, (i // cols) * 80 + 8))
        sheet.save(os.path.join(args.preview, 'ui_icons.png'))
    print(f'{len(done)} icons in {args.out}')


if __name__ == '__main__':
    main()
