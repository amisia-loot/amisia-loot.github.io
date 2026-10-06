"""Builds data/forever.js from Amisia SavedVariables files.

    python tools/build_scan.py <Amisia.lua>... [--out data/forever.js] [--no-icons]

Each file is the addon's saved table: `scan.items` from `/amisia scan` (name, quality, item level,
required level, class, subclass, equip location, icon, bind type per item) and the raid sessions
with what lay in opened loot windows (`drops`, by source name). The loot tables are built from
those drops: a zone per raid instance, a boss per drop source, trash folded into "Trash (Zone)".

tools/forever_zones.json maps instance names to zone keys, short names and colours;
tools/forever_bosses.json marks sources as "trash" or renames them. Unknown zones and sources
are reported and given defaults so the file still builds.

The item collector writes down where an item was met (`scan.sources`): a drop outside a recorded
raid, a merchant, a quest or the auction house. A "Drop: <name>" source becomes a boss in the zone
"Seen in the world"; the other sources are kept as the item's `via` line, which the site shows.
The source collector's records (`collect`: quests, vendors, world drops; collect_observed) are added
to those notes the same way: what an account saw itself, heard values only where two accounts hold
them alike, and only item ids the client's ItemSparse has that can be worn or are recipes (--wago).

--catalog adds every scanned item worth awarding (epic or better, or rare from --catalog-ilvl up)
that has no observed drop yet, under the boss "Unknown source", so loot can be recorded before
the boss tables exist. The boss tables replace that source as raids get recorded.

Drop records of the guild (boss kills with the items of their loot window, no player names) are
kept for good in the archive tools/drop_obs.json: from the SavedVariables (`drops.k`), from the
site's "Download observations" file (--obs) and from the addon's text "Drops für die Website"
(--drops, DZ/DN/DK lines). The same kill from several sources is one record (items at their largest
count, the smaller origin). data/forever.js gets per boss {npc, name, zone, kills, obs: {item: kills
with it}} as `obsBosses`, their dungeons and raids as `obsZones`, scanned names of observed items
outside the loot tables as `obsItems`, the newest day in the archive (never after today) as
`obsThrough` and the ids of that day as `obsIds`: the site adds only the kills it imported after
that day and not among those ids (a corpse looted on both sides of midnight is one kill, of the
earlier day), so nothing counts twice. Records without an NPC
(the addon's fallback ids) stay in the archive but have no table.

Without SavedVariables files on the command line only the observations change: the drop records
of ~/addons/_SavedVariables/Amisia.lua (when Syncthing brings it to the N100) and of --obs/--drops
go into the archive, and the observation keys of the existing --out file are replaced in place; the
item catalog of the last full build stays. Nothing here needs the client tables (wago CSVs).

Icons: the scan stores icon file ids. --listfile <community-listfile.csv> (wowdev/wow-listfile)
turns them into icon names; the ones used are kept in tools/icon-fileids.json, so later builds
work without the big file. Anything still unnamed falls back to Wowhead by item id (cached in tools/icon-cache.json) and are packed into a
sprite next to the data file with Pillow. --no-icons skips that and writes the icon names only.
"""
import argparse
import datetime
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
DROP_ARCHIVE = os.path.join(HERE, 'drop_obs.json')
# The addon's SavedVariables as Syncthing would bring them to the N100 (read for the drop records only)
DEFAULT_SV = os.path.expanduser('~/addons/_SavedVariables/Amisia.lua')
# The client tables from wago.tools (ItemSparse, Item): the source collector's item ids are checked against them
WAGO = os.path.expanduser('~/addons/_wago')
DAY0 = datetime.date(2026, 1, 1)   # day 0 of the drop records (UTC), as in the addon
DEFAULT_COLOR = ['#8f86a3', '#6a617a']
UNKNOWN_ZONE = {'key': 'unknown', 'name': 'Unknown source', 'short': '?', 'color': DEFAULT_COLOR}
UNKNOWN_BOSS = 'Unknown source'
FIELD_ZONE = {'key': 'field', 'name': 'Seen in the world', 'short': 'World', 'color': ['#7c9a6d', '#5d7452']}
DROP_PREFIX = 'Drop: '
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

# The scan stores the client's item class and subclass. They name what an item is beyond its slot,
# which decides who may wear it: a warrior wants plate, a rogue wants leather and a dagger.
WEAPON_TYPE = {
    0: 'Axe', 1: 'Two-hand axe', 2: 'Bow', 3: 'Gun', 4: 'Mace', 5: 'Two-hand mace', 6: 'Polearm',
    7: 'Sword', 8: 'Two-hand sword', 9: 'Warglaive', 10: 'Staff', 13: 'Fist weapon', 15: 'Dagger',
    16: 'Thrown', 18: 'Crossbow', 19: 'Wand', 20: 'Fishing pole',
}
ARMOR_TYPE = {1: 'Cloth', 2: 'Leather', 3: 'Mail', 4: 'Plate', 6: 'Shield', 7: 'Libram', 8: 'Idol', 9: 'Totem', 10: 'Sigil', 11: 'Relic'}
CLASS_WEAPON, CLASS_ARMOR = 2, 4
# bindType 1 binds when picked up, 2 when equipped, 3 when used.
BIND_NAME = {1: 'BoP', 2: 'BoE', 3: 'BoU'}


# ---------------------------------------------------------------- SavedVariables
def lua_to_py(v):
    """Recursively converts a lupa table: 1..n arrays become lists, everything else dicts."""
    if not hasattr(v, 'items'):
        return v
    keys = list(v.keys())
    if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
        return [lua_to_py(v[k]) for k in range(1, len(keys) + 1)]
    return {k: lua_to_py(v[k]) for k in keys}


# A SavedVariables file is Lua the client wrote, but it comes from another machine: it runs in a
# sandbox (as tools/att_data.py runs AllTheThings): lupa without its python bridge, an empty
# environment of its own, the dangerous globals gone, string methods out of reach, and an
# instruction budget (a real file of 2.4 MB needs a small fraction of it).
SV_SANDBOX = r'''
local loadstring, setfenv, pcall, tostring, error = loadstring, setfenv, pcall, tostring, error
local sethook = debug.sethook
local strmeta = getmetatable("")
for _, k in ipairs({ "os", "io", "require", "package", "debug", "dofile", "loadfile", "load", "loadstring",
                     "setfenv", "getfenv", "python", "collectgarbage", "module", "newproxy", "string" }) do
    _G[k] = nil
end
return function(src, name, budget)
    local f, err = loadstring(src, "@" .. name)
    if not f then return nil, tostring(err) end
    local env = {}
    setfenv(f, env)
    local index = strmeta.__index
    strmeta.__index = nil
    sethook(function() error("the file runs too long", 0) end, "", budget)
    local ok, e = pcall(f)
    sethook()
    strmeta.__index = index
    if not ok then return nil, tostring(e) end
    return env
end
'''
SV_BUDGET = 200000000   # Lua instructions


def load_sv(path):
    from lupa.lua51 import LuaRuntime
    lua = LuaRuntime(register_eval=False, register_builtins=False, unpack_returned_tuples=True)
    run = lua.execute(SV_SANDBOX)
    with open(path, encoding='utf-8') as fh:
        res = run(fh.read(), os.path.basename(path), SV_BUDGET)
    env, err = res if isinstance(res, tuple) else (res, None)
    if env is None:
        raise SystemExit(f'{path}: {err}')
    db = env['AmisiaDB']
    if db is None or not hasattr(db, 'items'):
        raise SystemExit(f'{path}: no AmisiaDB table in this file')
    return lua_to_py(db)


def parse_item_line(line):
    f = str(line).split('\t')
    f += [''] * (10 - len(f))
    num = lambda x: int(x) if str(x).lstrip('-').isdigit() else 0
    # the tenth field, only on gear from Amisia 1.3.0 on, holds the client's stats: "KEY=value;..."
    return {'name': f[0], 'q': num(f[1]), 'ilvl': num(f[2]), 'min': num(f[3]), 'classID': num(f[4]),
            'subclassID': num(f[5]), 'equipLoc': f[6], 'icon': f[7], 'bind': num(f[8]), 'stats': f[9]}


NOTE_RE = re.compile(r'^(?P<kind>Drop|Haendler|Händler|Quest): (?P<name>.*?)'
                     r'(?: \[(?P<id>\d+)\])?(?: L(?P<level>\d+))?'
                     r'(?: @(?P<place>.*?))?(?: #(?P<itype>[a-z]+):(?P<instance>\d+))?$')


def parse_note(text):
    """A collector note as a dict: kind (drop, vendor, quest, ah), name, id (NPC or quest), level
    (the player's, on quests), place (zone or instance name), itype (party/raid) and instance id.
    Older notes carry only the name."""
    text = str(text).strip()
    if text in ('Auktionshaus', 'Auction House'):
        return {'kind': 'ah'}
    m = NOTE_RE.match(text)
    if not m:
        return None
    kind = {'Drop': 'drop', 'Haendler': 'vendor', 'Händler': 'vendor', 'Quest': 'quest'}[m.group('kind')]
    num = lambda x: int(x) if x else None
    name = m.group('name').strip()
    return {'kind': kind, 'name': None if name in ('', '?') else name, 'id': num(m.group('id')),
            'level': num(m.group('level')), 'place': m.group('place'), 'itype': m.group('itype'),
            'instance': num(m.group('instance'))}


def note_label(text):
    """A note for people: the name with the place, without ids."""
    n = parse_note(text)
    if not n or n['kind'] == 'ah':
        return str(text)
    prefix = str(text).split(':', 1)[0]
    who = n['name'] or (f"NPC {n['id']}" if n['id'] and n['kind'] != 'quest' else '?')
    return f"{prefix}: {who}" + (f" ({n['place']})" if n['place'] else '')


def collect(dbs):
    """Union of the scans (a later file wins), the collector's sources, and every session with its drops."""
    items, sessions, names, collected = {}, [], {}, {}
    for db in dbs:
        scan = (db.get('scan') or {}).get('items') or {}
        for k, line in scan.items():
            try:
                items[int(k)] = parse_item_line(line)
            except (TypeError, ValueError):
                continue
        for k, v in ((db.get('scan') or {}).get('sources') or {}).items():
            try:
                item = int(k)
            except (TypeError, ValueError):
                continue
            seen = collected.setdefault(item, [])
            for src in (v if isinstance(v, list) else [v]):
                src = str(src).strip()
                if src and src not in seen:
                    seen.append(src)
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
    return items, sessions, collected


# ---------------------------------------------------------------- the source collector
# AmisiaDB.collect (Collector.lua, table version 2): one string per record, fields split by ";", the
# free text last. own is a bit mask of the fields after it that the client saw itself (bit 0 the
# first field); the others, if they hold anything, were heard from the guild.
#   q: day;own;giver;giverPos;ender;enderPos;rewards;choices;questLevel;minPlayerLevel;faction;pre;giverName;title
#   s: day;own;pos;items(id:price:flags:rep,...);name
#   w: day;own;class;pos;instance;items(id:count,...);name
# The check and the merge are the addon's (tools/tests/test_collect_records.py holds them side by
# side): one canonical form, so a record reads back to exactly the same string.
COLLECT_FIELDS = {
    'q': ('giver', 'gpos', 'ender', 'epos', 'rewards', 'choices', 'qlevel', 'minlvl', 'fac', 'pre', 'gname', 'title'),
    's': ('pos', 'items', 'name'),
    'w': ('class', 'pos', 'inst', 'items', 'name'),
}
COLLECT_LIMITS = {'rewards': 8, 'vItems': 48, 'wItems': 16, 'wCount': 99, 'maxLen': 2000, 'name': 48}
_MAX_ID = 9999999
_NUM = re.compile(r'-?[0-9]+')
_LUA_SPACE = re.compile(r'[ \t\n\v\f\r]+')
_CTRL = re.compile(r'[\x00-\x1f\x7f|]')
_CLASSES = ('', 'n', 'e', 'r', 'R', 'b')
_CLASS_RANK = {c: i for i, c in enumerate(_CLASSES)}
_FLAGS = ('', 'L', 'x', 'Lx')


def _num(s, lo, hi):
    """The addon's num(): a decimal integer in its one spelling ("00", "-0", "+1" are not)."""
    if not isinstance(s, str) or len(s) > 10 or not _NUM.fullmatch(s):
        return None
    v = int(s)
    if str(v) != s or not lo <= v <= hi:
        return None
    return v


def _pos_ok(s):
    if s == '':
        return True
    parts = s.split(':')
    if len(parts) == 3:
        return (_num(parts[0], 1, 999999) is not None and _num(parts[1], 0, 10000) is not None
                and _num(parts[2], 0, 10000) is not None)
    return len(parts) == 1 and _num(s, 1, 999999) is not None


def _clean(v, sep=None):
    """Drops.lua's cleanName (no control characters or bars, trimmed, 48 bytes at most at a whole
    character) and Collector.lua's clean (the separators of the field as spaces, runs of spaces as one)."""
    if not isinstance(v, str):
        return ''
    v = _CTRL.sub('', v).strip(' \t\n\v\f\r')
    raw = v.encode('utf-8')
    if len(raw) > COLLECT_LIMITS['name']:
        v = raw[:COLLECT_LIMITS['name']].decode('utf-8', 'ignore').strip(' \t\n\v\f\r')
    if sep:
        v = _LUA_SPACE.sub(' ', re.sub('[' + re.escape(sep) + ']', ' ', v)).strip(' \t\n\v\f\r')
    return v


def _text_ok(s, sep=None):
    return isinstance(s, str) and (s == '' or _clean(s, sep) == s)


def _id_list(s, limit):
    out = []
    if s == '':
        return out
    for e in s.split(','):
        v = _num(e, 1, _MAX_ID)
        if v is None or len(out) >= limit or (out and out[-1] >= v):
            return None
        out.append(v)
    return out


def _empty(v):
    return v in ('', 0) or (isinstance(v, (list, dict)) and not v)


def _parse_raw(kind, text):
    """A record as the addon's parse gives it (positions as their strings), or None."""
    fields = COLLECT_FIELDS.get(kind)
    if not fields or not isinstance(text, str) or len(text.encode('utf-8')) > COLLECT_LIMITS['maxLen']:
        return None
    f = text.split(';', len(fields) + 1)
    if len(f) != len(fields) + 2:
        return None
    r = {'day': _num(f[0], 0, 99999), 'own': _num(f[1], 0, (1 << len(fields)) - 1)}
    if r['day'] is None or r['own'] is None:
        return None
    f = f[2:]
    if kind == 'q':
        r.update(giver=_num(f[0], -_MAX_ID, _MAX_ID), gpos=f[1], ender=_num(f[2], -_MAX_ID, _MAX_ID), epos=f[3],
                 rewards=_id_list(f[4], COLLECT_LIMITS['rewards']), choices=_id_list(f[5], COLLECT_LIMITS['rewards']),
                 qlevel=_num(f[6], 0, 99), minlvl=_num(f[7], 0, 99), fac=f[8], pre=_num(f[9], 0, _MAX_ID), gname=f[10], title=f[11])
        if any(r[k] is None for k in ('giver', 'ender', 'rewards', 'choices', 'qlevel', 'minlvl', 'pre')):
            return None
        if not _pos_ok(r['gpos']) or not _pos_ok(r['epos']) or r['fac'] not in ('', 'A', 'H', 'AH'):
            return None
        if not _text_ok(r['gname'], ';') or not _text_ok(r['title']):
            return None
    elif kind == 's':
        r.update(pos=f[0], items={}, name=f[2])
        if not _pos_ok(r['pos']) or not _text_ok(r['name']):
            return None
        if f[1]:
            last = 0
            for e in f[1].split(','):
                m = re.fullmatch(r'([0-9]+):([0-9]+):([A-Za-z]*):(.*)', e, re.S)
                if not m:
                    return None
                iid, price = _num(m.group(1), 1, _MAX_ID), _num(m.group(2), 0, 2147483647)
                flags, rep = m.group(3), m.group(4)
                if iid is None or price is None or flags not in _FLAGS or iid <= last:
                    return None
                if rep:
                    rm = re.fullmatch(r'([0-9])@(.+)', rep, re.S)
                    if not rm or _num(rm.group(1), 1, 8) is None or _clean(rm.group(2), ',;:@') != rm.group(2):
                        return None
                last = iid
                if len(r['items']) >= COLLECT_LIMITS['vItems']:
                    return None
                r['items'][iid] = {'price': price, 'flags': flags, 'rep': rep}
    else:
        r.update({'class': f[0], 'pos': f[1], 'inst': _num(f[2], 0, 99999), 'items': {}, 'name': f[4]})
        if r['class'] not in _CLASSES or not _pos_ok(r['pos']) or r['inst'] is None or not _text_ok(r['name']):
            return None
        if f[3]:
            last = 0
            for e in f[3].split(','):
                m = re.fullmatch(r'([0-9]+):([0-9]+)', e)
                if not m:
                    return None
                iid, c = _num(m.group(1), 1, _MAX_ID), _num(m.group(2), 1, COLLECT_LIMITS['wCount'])
                if iid is None or c is None or iid <= last:
                    return None
                last = iid
                if len(r['items']) >= COLLECT_LIMITS['wItems']:
                    return None
                r['items'][iid] = c
    for i, name in enumerate(fields):
        if r['own'] >> i & 1 and _empty(r[name]):
            return None
    return r


def format_collect_record(kind, r):
    """A record dict (positions as strings) as the addon writes it."""
    own = r.get('own', 0)
    if kind == 'q':
        parts = [r['day'], own, r['giver'], r['gpos'], r['ender'], r['epos'], ','.join(map(str, r['rewards'])),
                 ','.join(map(str, r['choices'])), r['qlevel'], r['minlvl'], r['fac'], r['pre'], r['gname'], r['title']]
    elif kind == 's':
        items = ','.join(f"{i}:{x['price']}:{x['flags']}:{x['rep']}" for i, x in sorted(r['items'].items()))
        parts = [r['day'], own, r['pos'], items, r['name']]
    else:
        items = ','.join(f'{i}:{c}' for i, c in sorted(r['items'].items()))
        parts = [r['day'], own, r['class'], r['pos'], r['inst'], items, r['name']]
    return ';'.join(str(p) for p in parts)


def _parse_canonical(kind, text):
    r = _parse_raw(kind, text)
    if r is None or format_collect_record(kind, r) != text:
        return None
    return r


def _pos_tuple(v):
    """A position "map:x:y" or "map" as (map, x, y) or (map, None, None); None when empty."""
    if not v:
        return None
    p = [int(x) for x in v.split(':')]
    return (p[0], p[1], p[2]) if len(p) == 3 else (p[0], None, None)


def _public(r):
    out = dict(r)
    for k in ('gpos', 'epos', 'pos'):
        if k in out:
            out[k] = _pos_tuple(out[k])
    return out


def parse_collect_record(kind, text):
    """One collector record as a dict (positions as tuples, own the mask), or None when it is not a
    valid record in its one canonical form (the addon's check)."""
    r = _parse_canonical(kind, text)
    return _public(r) if r is not None else None


def mark_collect_record(kind, text, how):
    """The record with its own mask set as the addon's CollectMark does: every field that holds
    something ('own') or none ('heard'); None when it is not valid."""
    r = _parse_canonical(kind, text)
    if r is None:
        return None
    r['own'] = sum(1 << i for i, f in enumerate(COLLECT_FIELDS[kind]) if not _empty(r[f])) if how == 'own' else 0
    return format_collect_record(kind, r)


# The join of Collector.lua: per field an own value beats a heard one; two own or two heard values
# join (ids and texts: the smaller one there; lists: the union, capped at the smallest ids; levels
# and instance: the larger; minimum level and pre-quest: the smallest above 0; prices: the lower).
def _pick_text(a, b):
    if a == '':
        return b
    return a if b == '' or a.encode('utf-8') <= b.encode('utf-8') else b


def _pick_id(a, b):
    if a == 0:
        return b
    if b == 0:
        return a
    return min(a, b)


def _union(a, b, limit):
    return sorted(set(a) | set(b))[:limit]


def _flags(a, b):
    return ('L' if 'L' in a + b else '') + ('x' if 'x' in a + b else '')


def _vendor_items(a, b):
    out = {i: dict(x) for i, x in a.items()}
    for i, x in b.items():
        if i in out:
            y = out[i]
            out[i] = {'price': min(y['price'], x['price']), 'flags': _flags(y['flags'], x['flags']), 'rep': _pick_text(y['rep'], x['rep'])}
        else:
            out[i] = dict(x)
    return {i: out[i] for i in sorted(out)[:COLLECT_LIMITS['vItems']]}


def _world_items(a, b):
    out = dict(a)
    for i, c in b.items():
        out[i] = max(out.get(i, 0), c)
    return {i: out[i] for i in sorted(out)[:COLLECT_LIMITS['wItems']]}


def _list(a, b):
    return _union(a, b, COLLECT_LIMITS['rewards'])


_JOIN = {
    'q': {'giver': _pick_id, 'gpos': _pick_text, 'ender': _pick_id, 'epos': _pick_text, 'rewards': _list, 'choices': _list,
          'qlevel': max, 'minlvl': _pick_id, 'fac': lambda a, b: ('A' if 'A' in a + b else '') + ('H' if 'H' in a + b else ''),
          'pre': _pick_id, 'gname': _pick_text, 'title': _pick_text},
    's': {'pos': _pick_text, 'items': _vendor_items, 'name': _pick_text},
    'w': {'class': lambda a, b: a if _CLASS_RANK[a] >= _CLASS_RANK[b] else b, 'pos': _pick_text, 'inst': max,
          'items': _world_items, 'name': _pick_text},
}


def _merge_raw(kind, a, b):
    out = {'day': max(a['day'], b['day']), 'own': 0}
    for i, f in enumerate(COLLECT_FIELDS[kind]):
        oa, ob = a['own'] >> i & 1, b['own'] >> i & 1
        v = _JOIN[kind][f](a[f], b[f]) if oa == ob else (a[f] if oa else b[f])
        out[f] = v
        if (oa or ob) and not _empty(v):
            out['own'] |= 1 << i
    return out


def merge_collect(kind, x, y):
    """Two record strings as one, as the addon merges them; None when either is not valid."""
    a, b = _parse_canonical(kind, x), _parse_canonical(kind, y)
    if a is None or b is None:
        return None
    return format_collect_record(kind, _merge_raw(kind, a, b))


def observed_item_filter(wago_dir):
    """A test for item ids by the client's own tables in wago_dir (ItemSparse, Item; downloaded from
    wago.tools): the id is in ItemSparse, and it can be worn (an inventory type) or is a recipe
    (class 9), as the addon keeps them. None when the folder has no ItemSparse."""
    import csv
    import att_data
    path = att_data.wago_csv(wago_dir, 'ItemSparse') if wago_dir else None
    if not path:
        return None
    kinds = {}
    with open(path, encoding='utf-8', newline='') as fh:
        for row in csv.DictReader(fh):
            if (row.get('ID') or '').isdigit():
                kinds[int(row['ID'])] = int(row.get('InventoryType') or 0)
    classes = {}
    item = att_data.wago_csv(wago_dir, 'Item')
    if item:
        with open(item, encoding='utf-8', newline='') as fh:
            for row in csv.DictReader(fh):
                if (row.get('ID') or '').isdigit():
                    classes[int(row['ID'])] = int(row.get('ClassID') or 0)

    def ok(iid):
        return iid in kinds and (kinds[iid] != 0 or classes.get(iid) == 9)
    return ok


def _source_of(db, index):
    """Which account a SavedVariables file is: the addon's random client id (drops.me); a copy of a
    file is the same account."""
    me = (db.get('drops') or {}).get('me') if isinstance(db.get('drops'), dict) else None
    return me if isinstance(me, str) and me else f'#file{index}'


def _agreed(kind, field, per_source):
    """The heard values of a field that two accounts or more hold alike, joined; lists and item
    tables entry by entry."""
    join = _JOIN[kind][field]
    if field in ('rewards', 'choices'):
        count = {}
        for vals in per_source.values():
            for i in set().union(*vals):
                count[i] = count.get(i, 0) + 1
        return sorted(i for i, n in count.items() if n >= 2)[:COLLECT_LIMITS['rewards']]
    if field == 'items':
        seen = {}
        for vals in per_source.values():
            entries = set()
            for v in vals:
                for i, x in v.items():
                    entries.add((i, tuple(sorted(x.items())) if isinstance(x, dict) else None))
            for e in entries:
                seen[e] = seen.get(e, 0) + 1
        out = {}
        for (i, x), n in seen.items():
            if n < 2:
                continue
            if x is None:   # world items: the id agrees, the largest count of the accounts that saw it
                out[i] = max(c for vals in per_source.values() for v in vals for j, c in v.items() if j == i)
            else:
                out[i] = dict(x) if i not in out else _vendor_items({i: out[i]}, {i: dict(x)})[i]
        cap = COLLECT_LIMITS['vItems'] if kind == 's' else COLLECT_LIMITS['wItems']
        return {i: out[i] for i in sorted(out)[:cap]}
    count = {}
    for vals in per_source.values():
        for v in set(vals):
            count[v] = count.get(v, 0) + 1
    good = sorted(v for v, n in count.items() if n >= 2)
    out = None
    for v in good:
        out = v if out is None else join(out, v)
    return out


_EMPTY = {'rewards': [], 'choices': [], 'items': {}, 'giver': 0, 'ender': 0, 'qlevel': 0, 'minlvl': 0, 'pre': 0, 'inst': 0}
_EMPTY = {f: _EMPTY.get(f, '') for fields in COLLECT_FIELDS.values() for f in fields}


def collect_observed(dbs, item_ok=None):
    """The collector records of the SavedVariables for the builds: {'q': {questID: record},
    's': {npcID: record}, 'w': {npcID: record}}, each field taken as follows (in any file order the
    same):

    - what an account saw itself (its own values) counts; the own values of several files join;
    - a heard value (from the guild exchange, which any member can fill with anything) counts only
      where no file has an own value and two accounts or more hold it alike (list entries one by one);
      the files of one account (the same drops.me) are one source;
    - item ids item_ok rejects (not in the client's tables, nor wearable nor a recipe) are left out.

    Broken records are left out; a record with nothing left is too. Version 1 tables (no own mask)
    count as heard, as in the addon."""
    per = {'q': {}, 's': {}, 'w': {}}
    for index, db in enumerate(dbs):
        c = db.get('collect') if isinstance(db, dict) else None
        if not isinstance(c, dict):
            continue
        src = _source_of(db, index)
        for kind in per:
            t = c.get(kind)
            if isinstance(t, list):
                t = {i + 1: v for i, v in enumerate(t)}
            for k, v in (t or {}).items():
                if not isinstance(k, int) or isinstance(k, bool) or not 1 <= k <= _MAX_ID or not isinstance(v, str):
                    continue
                if c.get('ver') == 1:
                    v = re.sub(r'^([0-9]+;)', r'\g<1>0;', v, count=1)
                r = _parse_canonical(kind, v)
                if r is not None:
                    per[kind].setdefault(k, []).append((src, r))
    out = {'q': {}, 's': {}, 'w': {}}
    for kind, recs in per.items():
        fields = COLLECT_FIELDS[kind]
        for rid, lst in recs.items():
            res = {'day': max(r['day'] for _, r in lst)}
            for i, f in enumerate(fields):
                own = [r[f] for _, r in lst if r['own'] >> i & 1]
                if own:
                    v = own[0]
                    for x in own[1:]:
                        v = _JOIN[kind][f](v, x)
                else:
                    heard = {}
                    for src, r in lst:
                        if not _empty(r[f]):
                            heard.setdefault(src, []).append(r[f])
                    v = _agreed(kind, f, heard) if len(heard) >= 2 else None
                    if v is None:
                        v = _EMPTY[f]
                res[f] = v
            if item_ok is not None:
                for f in ('rewards', 'choices'):
                    if f in res:
                        res[f] = [i for i in res[f] if item_ok(i)]
                if 'items' in res:
                    res['items'] = {i: x for i, x in res['items'].items() if item_ok(i)}
            if all(_empty(res[f]) for f in fields):
                continue
            out[kind][rid] = _public(res)
    return out


def observed_notes(obs):
    """The collector records as item notes in the form of scan.sources (for the site's via line and the
    field drops): quests and vendors by name and id, mobs by name."""
    notes = {}

    def add(item, text):
        lst = notes.setdefault(item, [])
        if text not in lst:
            lst.append(text)

    for qid, q in sorted(obs.get('q', {}).items()):
        for item in q['rewards'] + q['choices']:
            add(item, f"Quest: {q['title'] or '?'} [{qid}]")
    for npc, v in sorted(obs.get('s', {}).items()):
        for item in v['items']:
            add(item, f"Haendler: {v['name'] or '?'} [{npc}]")
    for npc, w in sorted(obs.get('w', {}).items()):
        for item in w['items']:
            add(item, f"Drop: {w['name'] or '?'} [{npc}]")
    return notes


def add_notes(collected, notes):
    """Adds notes to the collected sources, each once."""
    for item, texts in notes.items():
        lst = collected.setdefault(item, [])
        for t in texts:
            if t not in lst:
                lst.append(t)
    return collected


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


def type_of(it):
    """Armour or weapon type, or '' when the slot already says everything (rings, trinkets, necks)."""
    if it['classID'] == CLASS_WEAPON:
        return WEAPON_TYPE.get(it['subclassID'], '')
    if it['classID'] == CLASS_ARMOR:
        return ARMOR_TYPE.get(it['subclassID'], '')
    return ''


def item_row(item, items, sources):
    it = items.get(item) or {'name': f'Item {item}', 'q': 0, 'ilvl': 0, 'min': 0, 'classID': 0, 'subclassID': 0, 'equipLoc': '', 'icon': '', 'bind': 0}
    row = {'id': item, 'name': it['name'] or f'Item {item}', 'slot': slot_of(it), 'icon': it['icon'],
           'sources': sources, 'q': it['q'], 'ilvl': it['ilvl']}
    sub = type_of(it)
    if sub:
        row['sub'] = sub
    bind = BIND_NAME.get(it['bind'])
    if bind:
        row['bind'] = bind
    if it['min']:
        row['lvl'] = it['min']
    return row


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
    return [item_row(item, items, sources[item]) for item in sorted(order)]


def add_field_sources(out_items, items, collected, zones, bosses, min_quality=3):
    """Items the collector saw drop outside a recorded raid: one boss per mob, in its own zone.

    The collector notes every item it meets, down to grey quest litter, so only loot worth awarding
    gets in — blue or better, the same line the addon draws for the loot windows in a raid.
    """
    have = {it['id'] for it in out_items}
    rows, seen = [], []
    for item in sorted(collected):
        it = items.get(item)
        if item in have or not it or it['q'] < min_quality or JUNK_NAME.search(it['name'] or ''):
            continue
        notes = [parse_note(s) for s in collected[item] if s.startswith(DROP_PREFIX)]
        mobs = [n['name'] for n in notes if n and n['name'] and n.get('itype') != 'raid']
        if not mobs:
            continue
        rows.append(item_row(item, items, mobs))
        for m in mobs:
            if m not in seen:
                seen.append(m)
    if not rows:
        return 0
    zones.append(dict(FIELD_ZONE))
    for m in seen:
        bosses.append({'name': m, 'zone': FIELD_ZONE['key']})
    out_items.extend(rows)
    return len(rows)


def add_via(out_items, collected):
    """The collector's other notes — merchant, quest, auction house — as the item's `via` line."""
    for it in out_items:
        via = [note_label(s) for s in collected.get(it['id'], []) if not s.startswith(DROP_PREFIX)]
        if via:
            it['via'] = via


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
        out_items.append(item_row(item, items, [UNKNOWN_BOSS]))
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


# ---------------------------------------------------------------- the guild's drop records
HEX8 = re.compile(r'^[0-9a-f]{8}$')
DROP_MAX_ITEMS, DROP_MAX_COUNT, DROP_MAX_NAME = 30, 200, 48


def drop_day(text):
    """Days since 2026-01-01 of "YYYY-MM-DD", or None."""
    m = re.match(r'^(\d{4})-(\d{2})-(\d{2})$', str(text or ''))
    if not m:
        return None
    try:
        d = datetime.date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
    except ValueError:
        return None
    day = (d - DAY0).days
    return day if day >= 0 else None


def drop_date(day):
    return (DAY0 + datetime.timedelta(days=day)).isoformat()


def _today():
    return (datetime.datetime.now(datetime.timezone.utc).date() - DAY0).days


def _int(v, lo, hi):
    if isinstance(v, bool):
        return None
    if isinstance(v, float) and v.is_integer():
        v = int(v)
    if isinstance(v, str) and v.isdigit():
        v = int(v)
    return v if isinstance(v, int) and lo <= v <= hi else None


def _pairs(v):
    """Key and value of a converted Lua table: a dict as it is, a list from key 1 on."""
    if isinstance(v, dict):
        return list(v.items())
    if isinstance(v, list):
        return list(enumerate(v, 1))
    return []


def clean_drop_name(v):
    """A boss or instance name as the addon keeps it: no control characters or bars, 48 at most."""
    if not isinstance(v, str):
        return None
    v = re.sub(r'[\x00-\x1f\x7f|]', '', v).strip()[:DROP_MAX_NAME].strip()
    return v or None


def check_record(r, today=None):
    """A kill record {npc, inst, diff, day, o, src, [enc], it} as the archive keeps it, or None.
    G records have an NPC, E records (the addon's fallback ids) have none."""
    if not isinstance(r, dict):
        return None
    today = _today() if today is None else today
    npc, inst = _int(r.get('npc'), 0, 9999999), _int(r.get('inst'), 1, 99999)
    # never a day after today (UTC): a wrong clock must not move obsThrough into the future
    diff, day = _int(r.get('diff'), 0, 255), _int(r.get('day'), 0, today)
    o, src, enc = r.get('o'), r.get('src'), r.get('enc')
    if None in (npc, inst, diff, day) or not isinstance(o, str) or not HEX8.match(o) or src not in ('G', 'E'):
        return None
    if (src == 'G' and npc < 1) or (src == 'E' and npc != 0):
        return None
    if enc in (None, 0):
        enc = None
    elif _int(enc, 1, 99999999) is None:
        return None
    items = {}
    for k, n in _pairs(r.get('it')):
        k, n = _int(k, 1, 9999999), _int(n, 1, DROP_MAX_COUNT)
        if k is None or n is None:
            return None
        items[k] = n
    if not isinstance(r.get('it'), (dict, list)) or len(items) > DROP_MAX_ITEMS:
        return None
    out = {'npc': npc, 'inst': inst, 'diff': diff, 'day': day, 'o': o, 'src': src, 'it': items}
    if enc is not None:
        out['enc'] = _int(enc, 1, 99999999)
    return out


def merge_record(store, h, r):
    """Merges record r under id h as the addon does: the same id is one kill; each item at its
    larger count, the smaller origin, the earlier day (a corpse looted on both sides of midnight is
    one kill), enc and the NPC filled in when missing. 'new', 'merged' or 'same'."""
    cur = store.get(h)
    if cur is None:
        store[h] = dict(r, it=dict(r['it']))
        return 'new'
    changed = False
    for i, n in r['it'].items():
        had = cur['it'].get(i)
        if (had or 0) < n and (had is not None or len(cur['it']) < DROP_MAX_ITEMS):
            cur['it'][i] = n
            changed = True
    if r['o'] < cur['o']:
        cur['o'], changed = r['o'], True
    if r['day'] < cur['day']:
        cur['day'], changed = r['day'], True
    if cur.get('enc') is None and r.get('enc') is not None:
        cur['enc'], changed = r['enc'], True
    if cur['npc'] == 0 and r['npc'] > 0 and cur['src'] == r['src']:
        cur['npc'], changed = r['npc'], True
    return 'merged' if changed else 'same'


def _part():
    return {'k': {}, 'npc': {}, 'inst': {}, 'enc': {}, 'bad': 0}


def obs_from_text(text):
    """The DZ/DN/DK lines of the addon's text "Drops für die Website"."""
    part = _part()
    for raw in str(text).splitlines():
        f = raw.strip().split()
        if not f or f[0] not in ('DZ', 'DN', 'DK'):
            continue
        if f[0] == 'DZ':
            inst, name = (_int(f[1], 1, 99999) if len(f) > 1 else None), clean_drop_name(' '.join(f[3:]))
            if inst and len(f) > 3 and f[2] in ('party', 'raid') and name:
                part['inst'][inst] = [f[2], name]
            else:
                part['bad'] += 1
        elif f[0] == 'DN':
            npc = _int(f[1], 0, 9999999) if len(f) > 1 else None
            enc = _int(f[2], 0, 99999999) if len(f) > 2 else None
            name = clean_drop_name(' '.join(f[3:]))
            if npc is None or enc is None or not name:
                part['bad'] += 1
            elif npc > 0:
                part['npc'][npc] = name
            elif enc > 0:
                part['enc'][enc] = name
        else:
            r, items = None, {}
            if len(f) == 9 and HEX8.match(f[1]):
                ok = True
                if f[8] != '-':
                    for p in f[8].split(','):
                        m = re.match(r'^(\d+):(\d+)$', p)
                        if not m:
                            ok = False
                            break
                        i = int(m.group(1))
                        items[i] = max(items.get(i, 0), int(m.group(2)))
                if ok:
                    r = check_record({'npc': f[2], 'inst': f[3], 'diff': f[4], 'day': drop_day(f[5]), 'o': f[6], 'src': f[7], 'it': items})
            if r is None:
                part['bad'] += 1
            else:
                merge_record(part['k'], f[1], r)
    return part


def _names(part, npc, inst, enc):
    for k, v in _pairs(npc):
        k, v = _int(k, 1, 9999999), clean_drop_name(v)
        if k and v:
            part['npc'][k] = v
    for k, v in _pairs(inst):
        k = _int(k, 1, 99999)
        if k and isinstance(v, list) and len(v) == 2 and v[0] in ('party', 'raid') and clean_drop_name(v[1]):
            part['inst'][k] = [v[0], clean_drop_name(v[1])]
    for k, v in _pairs(enc):
        k, v = _int(k, 1, 99999999), clean_drop_name(v)
        if k and v:
            part['enc'][k] = v


def obs_from_sv(db):
    """The drop records of a SavedVariables table (AmisiaDB.drops), without the own-record marker."""
    part = _part()
    d = db.get('drops') if isinstance(db, dict) else None
    if not isinstance(d, dict):
        return part
    for h, r in _pairs(d.get('k')):
        rec = check_record(r) if isinstance(h, str) and HEX8.match(h) else None
        if rec is None:
            part['bad'] += 1
        else:
            merge_record(part['k'], h, rec)
    _names(part, d.get('npc'), d.get('inst'), d.get('enc'))
    return part


def obs_from_site(js):
    """The site's "Download observations" file: {v, k: [[id, npc, inst, diff, day, origin, G|E, [item, n, ...]]], names, zones}."""
    part = _part()
    js = js if isinstance(js, dict) else {}
    for x in js.get('k') or []:
        r = None
        if isinstance(x, list) and len(x) == 8 and isinstance(x[0], str) and HEX8.match(x[0]) and isinstance(x[7], list) and len(x[7]) % 2 == 0:
            r = check_record({'npc': x[1], 'inst': x[2], 'diff': x[3], 'day': x[4], 'o': x[5], 'src': x[6],
                              'it': {x[7][i]: x[7][i + 1] for i in range(0, len(x[7]), 2)}})
        if r is None:
            part['bad'] += 1
        else:
            merge_record(part['k'], x[0], r)
    _names(part, js.get('names'), js.get('zones'), None)
    return part


def empty_archive():
    return {'v': 1, 'k': {}, 'npc': {}, 'inst': {}, 'enc': {}}


def merge_obs(arch, part):
    """Merges a part into the archive; names only where none is known. {'new': n, 'merged': n}."""
    stats = {'new': 0, 'merged': 0}
    for h in sorted(part['k']):
        res = merge_record(arch['k'], h, part['k'][h])
        if res in stats:
            stats[res] += 1
    for key in ('npc', 'inst', 'enc'):
        for k, v in part[key].items():
            arch[key].setdefault(k, v)
    return stats


def load_archive(path):
    """tools/drop_obs.json, or an empty archive when there is none yet."""
    arch = empty_archive()
    if not os.path.exists(path):
        return arch
    with open(path, encoding='utf-8') as fh:
        raw = json.load(fh)
    for h, r in (raw.get('k') or {}).items():
        rec = check_record(r, today=10 ** 6) if HEX8.match(str(h)) else None
        if rec is not None:
            arch['k'][h] = rec
    part = _part()
    _names(part, raw.get('npc'), raw.get('inst'), raw.get('enc'))
    for key in ('npc', 'inst', 'enc'):
        arch[key] = part[key]
    return arch


def save_archive(path, arch):
    def keyed(d):
        return {str(k): v for k, v in d.items()}
    out = {'v': 1, 'k': {h: dict(r, it=keyed(r['it'])) for h, r in arch['k'].items()},
           'npc': keyed(arch['npc']), 'inst': keyed(arch['inst']), 'enc': keyed(arch['enc'])}
    with open(path, 'w', encoding='utf-8', newline='\n') as fh:
        json.dump(out, fh, indent=1, sort_keys=True, ensure_ascii=False)
        fh.write('\n')


def base_records(arch, today=None):
    """The archive's records the loot tables count: none dated after today (UTC; a wrong clock of one
    client must not move obsThrough into the future, which would hide every later kill on the site)."""
    today = _today() if today is None else today
    return {h: r for h, r in arch['k'].items() if r['day'] <= today}


def edge_ids(arch, through, today=None):
    """The ids of the base's last day (obsIds): the site skips them when a client dated the same corpse
    a day later (looted after midnight), so a kill counts once."""
    if through is None:
        return []
    return sorted(h for h, r in base_records(arch, today).items() if r['day'] == through)


def obs_tables(arch, zones_cfg, known=None, today=None):
    """The loot tables from the archive: (zones, bosses, newest day, warnings). A boss per NPC with its
    kills and per item the number of kills that had it; its zone is the instance of its newest kill:
    a zone of the data file with the same name (known), else named by tools/forever_zones.json (by
    name, or by "instance"), else by the addon's DZ line. Records after today stay out."""
    known = {z['name']: z for z in known or [] if isinstance(z, dict) and z.get('name') and z.get('key')}
    recs = base_records(arch, today)
    through = max((r['day'] for r in recs.values()), default=None)
    per = {}
    for h in sorted(recs):
        r = recs[h]
        if r['npc'] <= 0:
            continue
        b = per.setdefault(r['npc'], {'kills': 0, 'obs': {}, 'inst': r['inst'], 'day': r['day']})
        b['kills'] += 1
        for i in r['it']:
            b['obs'][i] = b['obs'].get(i, 0) + 1
        if r['day'] > b['day']:
            b['inst'], b['day'] = r['inst'], r['day']
    by_inst = {cfg['instance']: (name, cfg) for name, cfg in zones_cfg.items() if isinstance(cfg, dict) and cfg.get('instance')}
    zones, zone_of, warnings = {}, {}, []
    for npc in sorted(per):
        inst = per[npc]['inst']
        if inst in zone_of:
            continue
        kind, name = arch['inst'].get(inst) or [None, None]
        cfg = known.get(name) if name else None
        if not isinstance(cfg, dict):
            cfg = zones_cfg.get(name) if name else None
        if not isinstance(cfg, dict) and inst in by_inst:
            name, cfg = name or by_inst[inst][0], by_inst[inst][1]
        if not isinstance(cfg, dict):
            name = name or f'Instance {inst}'
            warnings.append(f'unknown zone "{name}" (instance {inst}) of the drop records: add it to tools/forever_zones.json')
            cfg = {'key': slug(name), 'short': name[:8], 'color': DEFAULT_COLOR}
        zone = {'key': cfg['key'], 'name': name, 'short': cfg.get('short', name[:8]), 'color': cfg.get('color', DEFAULT_COLOR),
                'inst': inst, 'kind': kind or ('raid' if cfg.get('raid') else None)}
        zone_of[inst] = zone['key']
        zones.setdefault(zone['key'], zone)
    zone_list = sorted(zones.values(), key=lambda z: (z['name'], z['key']))
    order = {z['key']: i for i, z in enumerate(zone_list)}
    bosses = [{'npc': npc, 'name': arch['npc'].get(npc) or f'Boss {npc}', 'zone': zone_of[b['inst']], 'kills': b['kills'],
               'obs': {str(i): n for i, n in sorted(b['obs'].items())}} for npc, b in per.items()]
    bosses.sort(key=lambda x: (order[x['zone']], x['name'], x['npc']))
    return zone_list, bosses, through, warnings


OBS_KEYS = ('obsZones', 'obsBosses', 'obsItems', 'obsThrough', 'obsIds')


def set_observations(data, arch, zones_cfg, items=None, today=None):
    """Puts the observation keys into the data of data/forever.js (replacing older ones). items: the
    scanned items of a full build, which name the observed items outside the loot tables; without
    them (an update in place) the named rows of the last full build stay. Returns the warnings."""
    old = {r['id']: r for r in data.get('obsItems') or [] if isinstance(r, dict) and 'id' in r}
    for k in OBS_KEYS:
        data.pop(k, None)
    zones, bosses, through, warnings = obs_tables(arch, zones_cfg, data.get('zones'), today)
    if not bosses:
        return warnings
    have = {it['id'] for it in data.get('items') or []}
    rows = []
    for i in sorted({int(i) for b in bosses for i in b['obs']} - have):
        if items is not None and i in items:
            row = item_row(i, items, [])
            row.pop('sources', None)
            rows.append(row)
        elif items is None and i in old:
            rows.append(old[i])
    data['obsZones'], data['obsBosses'] = zones, bosses
    if rows:
        data['obsItems'] = rows
    data['obsThrough'] = through
    data['obsIds'] = edge_ids(arch, through, today)
    return warnings


# ---------------------------------------------------------------- output
JS_PREFIX = 'window.__LOOT=window.__LOOT||{};window.__LOOT["forever"]='


def js_text(data):
    return JS_PREFIX + json.dumps(data, ensure_ascii=False, separators=(',', ':')) + ';\n'


def read_js(path):
    with open(path, encoding='utf-8') as fh:
        txt = fh.read()
    if not txt.startswith(JS_PREFIX):
        raise SystemExit(f'{path}: not a data file of build_scan.py')
    return json.loads(txt[len(JS_PREFIX):].rstrip().rstrip(';'))


def write_js(out, zones, bosses, items, sprite, extra=None):
    data = {'zones': zones, 'bosses': bosses, 'items': items}
    if sprite:
        data['sprite'] = sprite
    data.update(extra or {})
    with open(out, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(js_text(data))


def gather_drops(arch, sv_dbs, obs_files, drop_files, log=print):
    """Merges the drop records of SavedVariables tables, site downloads and addon texts into the archive."""
    total = {'new': 0, 'merged': 0}
    # the client's own records first, then its texts, then the site's download: the first name of a
    # boss or an instance stays
    parts = [obs_from_sv(db) for db in sv_dbs]
    for p in drop_files:
        with open(p, encoding='utf-8') as fh:
            parts.append(obs_from_text(fh.read()))
    for p in obs_files:
        with open(p, encoding='utf-8') as fh:
            parts.append(obs_from_site(json.load(fh)))
    bad = 0
    for part in parts:
        bad += part['bad']
        s = merge_obs(arch, part)
        total['new'] += s['new']
        total['merged'] += s['merged']
    log(f'drop records: {len(arch["k"])} in the archive, {total["new"]} new, {total["merged"]} merged'
        + (f', {bad} broken skipped' if bad else ''))
    return total


def update_in_place(args, zones_cfg):
    """No SavedVariables named: the drop records go into the archive and only the observation keys of
    the existing data file change. The SavedVariables Syncthing brings to the N100 are read for their
    drop records when they are there."""
    arch = load_archive(args.archive)
    dbs = []
    if os.path.exists(DEFAULT_SV):
        try:
            dbs.append(load_sv(DEFAULT_SV))
        except (SystemExit, Exception) as exc:  # noqa: BLE001 - a broken file must not stop the rest
            print(f'  {DEFAULT_SV}: not read ({exc})')
    gather_drops(arch, dbs, args.obs, args.drops)
    save_archive(args.archive, arch)
    if not os.path.exists(args.out):
        print(f'{args.out} does not exist: run a full build with the SavedVariables first')
        return 1
    with open(args.out, encoding='utf-8') as fh:
        before = fh.read()
    data = read_js(args.out)
    warnings = set_observations(data, arch, zones_cfg)
    text = js_text(data)
    if text != before:
        with open(args.out, 'w', encoding='utf-8', newline='\n') as fh:
            fh.write(text)
        print(f'{len(data.get("obsBosses") or [])} bosses with drop tables -> {args.out} (bump BUILD_ID in index.html)')
    else:
        print(f'{args.out} unchanged')
    for w in warnings:
        print('  ' + w)
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('files', nargs='*', help='Amisia.lua SavedVariables files (none: update the drop observations only)')
    ap.add_argument('--out', default=os.path.join(ROOT, 'data', 'forever.js'))
    ap.add_argument('--archive', default=DROP_ARCHIVE, help='the archive of drop records (default tools/drop_obs.json)')
    ap.add_argument('--obs', action='append', default=[], help='the site\'s "Download observations" file (repeatable)')
    ap.add_argument('--drops', action='append', default=[], help='a text "Drops für die Website" of the addon (repeatable)')
    ap.add_argument('--no-icons', action='store_true', help='skip Wowhead lookups and the sprite')
    ap.add_argument('--catalog', action='store_true', help='add awardable scanned items without a drop under "Unknown source"')
    ap.add_argument('--catalog-ilvl', type=int, default=60, help='lowest item level for rare items in the catalog (default 60)')
    ap.add_argument('--field-quality', type=int, default=3, help='lowest quality for a drop the collector saw outside a raid (default 3, blue)')
    ap.add_argument('--listfile', help='community-listfile.csv from wowdev/wow-listfile, names the icon file ids')
    ap.add_argument('--no-wowhead', action='store_true', help='never ask Wowhead for an icon name')
    ap.add_argument('--wago', default=WAGO, help='folder with the client tables ItemSparse and Item from wago.tools (default '
                                                 '~/addons/_wago): item ids of the source collector they lack are left out')
    args = ap.parse_args(argv)
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    zones_cfg = load_json(ZONES_CFG, {})
    if not args.files:
        return update_in_place(args, zones_cfg)
    dbs = [load_sv(p) for p in args.files]
    items, sessions, collected = collect(dbs)
    # what the source collector saw (quests, vendors, world drops) joins the notes
    item_ok = observed_item_filter(args.wago)
    if item_ok is None:
        print(f'no ItemSparse in {args.wago}: the source collector\'s item ids are not checked against the client')
    add_notes(collected, observed_notes(collect_observed(dbs, item_ok)))
    bosses_cfg = load_json(BOSSES_CFG, {})
    zones, bosses, warnings = zones_and_bosses(sessions, zones_cfg, bosses_cfg)
    out_items = build_items(items, sessions, bosses, zones, bosses_cfg)
    field = add_field_sources(out_items, items, collected, zones, bosses, args.field_quality)
    catalog = add_catalog(out_items, items, zones, bosses, args.catalog_ilvl) if args.catalog else 0
    add_via(out_items, collected)
    # the guild's drop records: the archive with these SavedVariables, downloads and texts
    arch = load_archive(args.archive)
    gather_drops(arch, dbs, args.obs, args.drops)
    save_archive(args.archive, arch)
    obs = {'items': out_items}
    warnings += set_observations(obs, arch, zones_cfg, items=items)
    del obs['items']
    obs_items = obs.get('obsItems') or []
    sprite = None
    if not args.no_icons:
        icon_names(out_items + obs_items, fileids=fileid_names(out_items + obs_items, args.listfile), wowhead=not args.no_wowhead)
        sprite = build_sprite(out_items + obs_items, os.path.dirname(os.path.abspath(args.out)))
    write_js(args.out, zones, bosses, out_items, sprite, obs)
    print(f'{len(items)} scanned items, {len(sessions)} sessions, {len(collected)} collected sources, {len(zones)} zones, {len(bosses)} bosses, '
          f'{len(out_items) - catalog - field} items with raid drops, {field} seen in the world, {catalog} catalog items -> {args.out}')
    if not args.no_icons:
        print(f'  {sum(1 for it in out_items if "s" not in it)} items without a picture')
    for w in warnings:
        print('  ' + w)
    return 0


if __name__ == '__main__':
    sys.exit(main())
