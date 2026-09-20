"""Builds data/forever.js from Amisia SavedVariables files.

    python tools/build_scan.py <Amisia.lua>... [--out data/forever.js] [--no-icons]

Each file is the addon's saved table: `scan.items` from `/amisia scan` (name, quality, item level,
required level, class, subclass, equip location, icon, bind type per item) and the raid sessions
with what lay in opened loot windows (`drops`, by source name). The loot tables are built from
those drops: a zone per raid instance, a boss per drop source, trash folded into "Trash (Zone)".

tools/forever_zones.json maps instance names to zone keys, short names and colours;
tools/forever_bosses.json marks sources as "trash" or renames them. Unknown zones and sources
are reported and given defaults so the file still builds.

--catalog adds every scanned item worth awarding (epic or better, or rare from --catalog-ilvl up)
that has no observed drop yet, under the boss "Unknown source", so loot can be recorded before
the boss tables exist. The boss tables replace that source as raids get recorded.

Icons: the scan stores icon file ids. --listfile <community-listfile.csv> (wowdev/wow-listfile)
turns them into icon names; the ones used are kept in tools/icon-fileids.json, so later builds
work without the big file. Anything still unnamed falls back to Wowhead by item id (cached in tools/icon-cache.json) and are packed into a
sprite next to the data file with Pillow. --no-icons skips that and writes the icon names only.
"""
import argparse
import hashlib
import io
import json
import os
import re
import sys
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ZONES_CFG = os.path.join(HERE, 'forever_zones.json')
BOSSES_CFG = os.path.join(HERE, 'forever_bosses.json')
ICON_CACHE = os.path.join(HERE, 'icon-cache.json')
ICON_FILEIDS = os.path.join(HERE, 'icon-fileids.json')
DEFAULT_COLOR = ['#8f86a3', '#6a617a']
UNKNOWN_ZONE = {'key': 'unknown', 'name': 'Unknown source', 'short': '?', 'color': DEFAULT_COLOR}
UNKNOWN_BOSS = 'Unknown source'
JUNK_NAME = re.compile(r'\(test\)|\btest\b|deprecated|^monster - |\[ph\]|^zz|\(old\)|^old |unused|^qa', re.I)
SPRITE_COLS = 24
SPRITE_CELL = 40

SLOT_BY_EQUIP = {
    'INVTYPE_HEAD': 'head', 'INVTYPE_NECK': 'neck', 'INVTYPE_SHOULDER': 'shoulder', 'INVTYPE_CLOAK': 'back',
    'INVTYPE_CHEST': 'chest', 'INVTYPE_ROBE': 'chest', 'INVTYPE_WRIST': 'wrist', 'INVTYPE_HAND': 'hands',
    'INVTYPE_WAIST': 'waist', 'INVTYPE_LEGS': 'legs', 'INVTYPE_FEET': 'feet', 'INVTYPE_FINGER': 'finger',
    'INVTYPE_TRINKET': 'trinket', 'INVTYPE_WEAPON': 'weapon', 'INVTYPE_2HWEAPON': 'weapon',
    'INVTYPE_WEAPONMAINHAND': 'weapon', 'INVTYPE_WEAPONOFFHAND': 'offhand', 'INVTYPE_SHIELD': 'offhand',
    'INVTYPE_HOLDABLE': 'offhand', 'INVTYPE_RANGED': 'ranged', 'INVTYPE_RANGEDRIGHT': 'ranged',
    'INVTYPE_THROWN': 'ranged', 'INVTYPE_RELIC': 'relic',
}


# ---------------------------------------------------------------- SavedVariables
def lua_to_py(v):
    """Recursively converts a lupa table: 1..n arrays become lists, everything else dicts."""
    if not hasattr(v, 'items'):
        return v
    keys = list(v.keys())
    if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
        return [lua_to_py(v[k]) for k in range(1, len(keys) + 1)]
    return {k: lua_to_py(v[k]) for k in keys}


def load_sv(path):
    from lupa.lua51 import LuaRuntime
    lua = LuaRuntime(unpack_returned_tuples=True)
    with open(path, encoding='utf-8') as fh:
        lua.execute(fh.read())
    db = lua.globals().AmisiaDB
    if db is None:
        raise SystemExit(f'{path}: no AmisiaDB table in this file')
    return lua_to_py(db)


def parse_item_line(line):
    f = str(line).split('\t')
    f += [''] * (9 - len(f))
    num = lambda x: int(x) if str(x).lstrip('-').isdigit() else 0
    return {'name': f[0], 'q': num(f[1]), 'ilvl': num(f[2]), 'min': num(f[3]), 'classID': num(f[4]),
            'subclassID': num(f[5]), 'equipLoc': f[6], 'icon': f[7], 'bind': num(f[8])}


def collect(dbs):
    """Union of the scans (a later file wins) and every session with its drops."""
    items, sessions, names = {}, [], {}
    for db in dbs:
        scan = (db.get('scan') or {}).get('items') or {}
        for k, line in scan.items():
            try:
                items[int(k)] = parse_item_line(line)
            except (TypeError, ValueError):
                continue
        for k, v in (db.get('itemNames') or {}).items():
            try:
                names[int(k)] = {'name': str(v.get('n') or ''), 'q': int(v.get('q') or 0)}
            except (TypeError, ValueError, AttributeError):
                continue
        for s in (db.get('sessions') or []):
            drops = []
            for src in (s.get('drops') or {}).values():
                for item, count in (src.get('items') or {}).items():
                    drops.append({'src': str(src.get('src') or '?'), 'item': int(item), 'count': int(count or 1)})
            sessions.append({'zone': str(s.get('zone') or '?'), 'instance': int(s.get('instanceID') or 0),
                             'date': str(s.get('date') or ''), 'drops': drops})
    for k, v in names.items():
        if k not in items:
            items[k] = {'name': v['name'], 'q': v['q'], 'ilvl': 0, 'min': 0, 'classID': 0, 'subclassID': 0, 'equipLoc': '', 'icon': '', 'bind': 0}
    return items, sessions


# ---------------------------------------------------------------- zones and bosses
def slug(name):
    return re.sub(r'[^a-z0-9]+', '', name.lower())[:12] or 'zone'


def zones_and_bosses(sessions, zones_cfg, bosses_cfg):
    """Zones in first-seen order, bosses per zone in first-seen order, trash last."""
    zones, zone_key, bosses, seen, warnings = [], {}, [], set(), []
    trash_zones = []
    for s in sessions:
        if not s['drops']:
            continue
        zname = s['zone']
        if zname not in zone_key:
            cfg = zones_cfg.get(zname)
            if not cfg:
                warnings.append(f'unknown zone "{zname}" (instance {s["instance"]}): add it to tools/forever_zones.json')
                cfg = {'key': slug(zname), 'short': zname[:8], 'color': DEFAULT_COLOR}
            zone_key[zname] = cfg['key']
            zones.append({'key': cfg['key'], 'name': zname, 'short': cfg.get('short', zname[:8]), 'color': cfg.get('color', DEFAULT_COLOR)})
        for d in s['drops']:
            rule = bosses_cfg.get(d['src'])
            if rule == 'trash' or d['src'] == '?':
                if zname not in trash_zones:
                    trash_zones.append(zname)
                continue
            name = rule if isinstance(rule, str) else d['src']
            if rule is None and d['src'] not in seen:
                warnings.append(f'source "{d["src"]}" in {zname} is listed as a boss: mark it "trash" or rename it in tools/forever_bosses.json if that is wrong')
            if name not in seen:
                seen.add(name)
                bosses.append({'name': name, 'zone': zone_key[zname]})
    for zname in trash_zones:
        bosses.append({'name': f'Trash ({zname})', 'zone': zone_key[zname]})
    return zones, bosses, warnings


def boss_name_for(src, zname, bosses_cfg):
    rule = bosses_cfg.get(src)
    if rule == 'trash' or src == '?':
        return f'Trash ({zname})'
    return rule if isinstance(rule, str) else src


def slot_of(it):
    if it['classID'] == 9:
        return 'recipe'
    if it['classID'] == 15 and it['subclassID'] == 5:
        return 'mount'
    return SLOT_BY_EQUIP.get(it['equipLoc'], 'other')


def build_items(items, sessions, bosses, zones, bosses_cfg=None):
    bosses_cfg = bosses_cfg or {}
    known = {b['name'] for b in bosses}
    sources = {}
    order = []
    for s in sessions:
        for d in s['drops']:
            name = boss_name_for(d['src'], s['zone'], bosses_cfg)
            if name not in known:
                continue
            lst = sources.setdefault(d['item'], [])
            if name not in lst:
                lst.append(name)
            if d['item'] not in order:
                order.append(d['item'])
    out = []
    for item in sorted(order):
        it = items.get(item) or {'name': f'Item {item}', 'q': 0, 'ilvl': 0, 'min': 0, 'classID': 0, 'subclassID': 0, 'equipLoc': '', 'icon': '', 'bind': 0}
        out.append({'id': item, 'name': it['name'] or f'Item {item}', 'slot': slot_of(it), 'icon': it['icon'],
                    'sources': sources[item], 'q': it['q'], 'ilvl': it['ilvl']})
    return out


def add_catalog(out_items, items, zones, bosses, min_rare_ilvl=60):
    """Adds awardable scanned items without an observed drop under the "Unknown source" boss."""
    have = {it['id'] for it in out_items}
    added = 0
    for item in sorted(items):
        it = items[item]
        if item in have or not it['name'] or JUNK_NAME.search(it['name']):
            continue
        slot = slot_of(it)
        if slot in ('other', 'mount') or (slot == 'recipe' and it['q'] < 4):
            continue
        if not (it['q'] >= 4 or (it['q'] == 3 and it['ilvl'] >= min_rare_ilvl)):
            continue
        out_items.append({'id': item, 'name': it['name'], 'slot': slot, 'icon': it['icon'],
                          'sources': [UNKNOWN_BOSS], 'q': it['q'], 'ilvl': it['ilvl']})
        added += 1
    if added:
        zones.append(dict(UNKNOWN_ZONE))
        bosses.append({'name': UNKNOWN_BOSS, 'zone': UNKNOWN_ZONE['key']})
    return added


# ---------------------------------------------------------------- icons
def fileid_names(items, listfile=None, cache_path=ICON_FILEIDS):
    """Icon name per icon file id: from the cache, topped up from the community listfile when given."""
    cache = load_json(cache_path, {})
    want = {str(it['icon']) for it in items if str(it.get('icon') or '').isdigit()} - set(cache)
    if want and listfile:
        with open(listfile, encoding='utf-8', errors='replace') as fh:
            for line in fh:
                fid, _, path = line.partition(';')
                if fid in want and path.lower().startswith('interface/icons/'):
                    cache[fid] = os.path.splitext(os.path.basename(path.strip()))[0].lower()
        save_json(cache_path, cache)
    return cache


def load_json(path, default):
    if os.path.exists(path):
        with open(path, encoding='utf-8') as fh:
            return json.load(fh)
    return default


def save_json(path, data):
    with open(path, 'w', encoding='utf-8') as fh:
        json.dump(data, fh, indent=1, sort_keys=True)


def fetch(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Amisia loot ledger build)'})
    with urllib.request.urlopen(req, timeout=20) as r:
        return r.read()


def icon_names(items, cache_path=ICON_CACHE, log=print, fileids=None, wowhead=True):
    """Icon name per item: a name stays, a file id is looked up in `fileids`, the rest asks Wowhead (cached)."""
    cache = load_json(cache_path, {})
    fileids = fileids or {}
    for it in items:
        icon = str(it.get('icon') or '')
        if icon and not icon.isdigit():
            it['icon'] = icon.lower()
            continue
        if icon in fileids:
            it['icon'] = fileids[icon]
            continue
        key = str(it['id'])
        if key not in cache and not wowhead:
            it['icon'] = ''
            continue
        if key not in cache:
            try:
                xml = fetch(f'https://www.wowhead.com/item={it["id"]}&xml').decode('utf-8', 'replace')
                m = re.search(r'<icon[^>]*>([^<]+)</icon>', xml)
                cache[key] = m.group(1).strip().lower() if m else ''
            except Exception as exc:  # noqa: BLE001 - one bad item must not stop the build
                log(f'icon lookup failed for {it["id"]}: {exc}')
                cache[key] = ''
            save_json(cache_path, cache)
        it['icon'] = cache.get(key) or ''
    return items


def build_sprite(items, out_dir, log=print):
    """Packs every item icon into one JPEG and gives each item its cell index `s`."""
    from PIL import Image
    icon_dir = os.path.join(HERE, 'icons')
    os.makedirs(icon_dir, exist_ok=True)
    names = []
    for it in items:
        if it['icon'] and it['icon'] not in names:
            names.append(it['icon'])
    cols = SPRITE_COLS
    rows = max(1, (len(names) + cols - 1) // cols)
    sheet = Image.new('RGB', (cols * SPRITE_CELL, rows * SPRITE_CELL), (20, 16, 28))
    index = {}
    for i, name in enumerate(names):
        path = os.path.join(icon_dir, name + '.jpg')
        if not os.path.exists(path):
            try:
                with open(path, 'wb') as fh:
                    fh.write(fetch('https://wow.zamimg.com/images/wow/icons/large/' + urllib.parse.quote(name) + '.jpg'))
            except Exception as exc:  # noqa: BLE001
                log(f'icon download failed for {name}: {exc}')
                continue
        try:
            img = Image.open(path).convert('RGB').resize((SPRITE_CELL, SPRITE_CELL))
        except Exception as exc:  # noqa: BLE001
            log(f'icon unreadable for {name}: {exc}')
            continue
        sheet.paste(img, ((i % cols) * SPRITE_CELL, (i // cols) * SPRITE_CELL))
        index[name] = i
    buf = io.BytesIO()
    sheet.save(buf, 'JPEG', quality=85)
    digest = hashlib.sha1(buf.getvalue()).hexdigest()[:8]
    file_name = f'forever.{digest}.jpg'
    with open(os.path.join(out_dir, file_name), 'wb') as fh:
        fh.write(buf.getvalue())
    for it in items:
        if it['icon'] in index:
            it['s'] = index[it['icon']]
        else:
            it.pop('s', None)   # no picture: the site shows an empty frame instead of someone else's icon
    return {'file': f'data/{file_name}', 'cols': cols, 'rows': rows, 'n': len(names)}


# ---------------------------------------------------------------- output
def write_js(out, zones, bosses, items, sprite):
    data = {'zones': zones, 'bosses': bosses, 'items': items}
    if sprite:
        data['sprite'] = sprite
    with open(out, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write('window.__LOOT=window.__LOOT||{};window.__LOOT["forever"]=' + json.dumps(data, ensure_ascii=False, separators=(',', ':')) + ';\n')


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('files', nargs='+', help='Amisia.lua SavedVariables files')
    ap.add_argument('--out', default=os.path.join(ROOT, 'data', 'forever.js'))
    ap.add_argument('--no-icons', action='store_true', help='skip Wowhead lookups and the sprite')
    ap.add_argument('--catalog', action='store_true', help='add awardable scanned items without a drop under "Unknown source"')
    ap.add_argument('--catalog-ilvl', type=int, default=60, help='lowest item level for rare items in the catalog (default 60)')
    ap.add_argument('--listfile', help='community-listfile.csv from wowdev/wow-listfile, names the icon file ids')
    ap.add_argument('--no-wowhead', action='store_true', help='never ask Wowhead for an icon name')
    args = ap.parse_args(argv)
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    dbs = [load_sv(p) for p in args.files]
    items, sessions = collect(dbs)
    zones_cfg = load_json(ZONES_CFG, {})
    bosses_cfg = load_json(BOSSES_CFG, {})
    zones, bosses, warnings = zones_and_bosses(sessions, zones_cfg, bosses_cfg)
    out_items = build_items(items, sessions, bosses, zones, bosses_cfg)
    catalog = add_catalog(out_items, items, zones, bosses, args.catalog_ilvl) if args.catalog else 0
    sprite = None
    if not args.no_icons:
        icon_names(out_items, fileids=fileid_names(out_items, args.listfile), wowhead=not args.no_wowhead)
        sprite = build_sprite(out_items, os.path.dirname(os.path.abspath(args.out)))
    write_js(args.out, zones, bosses, out_items, sprite)
    print(f'{len(items)} scanned items, {len(sessions)} sessions, {len(zones)} zones, {len(bosses)} bosses, {len(out_items) - catalog} items with drops, {catalog} catalog items -> {args.out}')
    if not args.no_icons:
        print(f'  {sum(1 for it in out_items if "s" not in it)} items without a picture')
    for w in warnings:
        print('  ' + w)
    return 0


if __name__ == '__main__':
    sys.exit(main())
