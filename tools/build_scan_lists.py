"""The id lists of the scans by id and the names they found (spec 2026-11-10-quest-und-npc-scan, D-104).

    python3 tools/build_scan_lists.py [--wago DIR] [--sv FILE...] [--scan-archive FILE] [--data DIR]
                                       [--lists FILE] [--names FILE]

Writes two lazy data files of the addon:

- `Amisia/Data/ScanLists.lua` (`ns.Data("SCAN_LISTS")`): what /amisia scan quests and /amisia scan
  npcs ask for. Q: every quest id of the client table QuestV2 (as ranges "<step>.<length>", base 36,
  steps from the end of the previous range). NA: phase A of the NPC scan, every NPC id the shipped data
  names (the bosses of DungeonData.lua and BisData.lua, the quest givers of QuestData.lua, the rares,
  mobs and vendors of GearData.lua, the NPC points "U:<id>" of MapData.lua; "<step>,<step>", base 36,
  steps from the previous id). NB: phase B, the id ranges where Forever's new NPCs live: the ids of
  that data from FOREVER_MIN up, in clusters no more than GAP apart, each padded by PAD ({from, to}).
  The data files are read as the addon reads them, so this build runs after the others.
- `Amisia/Data/ScanNames.lua` (`ns.Data("SCAN_NAMES")`): the names the scans found, per language other
  than English (the data's names are English already): L = {deDE = {Q = {[quest id] = title},
  N = {[NPC id] = name}}}. From tools/scan_archive.json and the SavedVariables (id_scans of
  build_scan_archive.py). The addon shows them where the data has only the English name (quest titles
  the client has not loaded, boss names on the dungeon pages, quest givers).

Without QuestV2 the quest list is empty; without a scan the names file holds no names. Requires lupa.
"""
import argparse
import csv
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import build_scan_archive  # noqa: E402  (the scan archive, b36)
import lua_data  # noqa: E402  (the lazy form, reading data files)

DATA = os.path.join(ROOT, 'Amisia', 'Data')
LISTS = os.path.join(DATA, 'ScanLists.lua')
NAMES = os.path.join(DATA, 'ScanNames.lua')
FOREVER_MIN = 200000    # NPC ids from here on are new in Forever (Classic's highest are far below)
GAP = 1000              # ids closer than this belong to one range of phase B
PAD = 250               # each range of phase B reaches this far beyond the ids we know
MAX_NAME = 80

b36 = build_scan_archive.b36


def log(*a):
    print(*a, file=sys.stderr)


# ---------------------------------------------------------------- the quest list
def quest_ids(wago):
    """(build, sorted ids) of the client table QuestV2 in wago, or (None, [])."""
    import att_data
    path = att_data.wago_csv(wago, 'QuestV2') if wago else None
    if not path:
        return None, []
    ids = set()
    with open(path, encoding='utf-8-sig', newline='') as fh:
        for row in csv.DictReader(fh):
            if (row.get('ID') or '').isdigit() and int(row['ID']) > 0:
                ids.add(int(row['ID']))
    base = os.path.basename(path)
    build = base[len('QuestV2.'):-len('.csv')] if base.count('.') > 1 else ''
    return build, sorted(ids)


def stepped_ranges(ids):
    """Sorted ids as "<step>.<length>,..." (base 36, the step from the end of the previous range)."""
    out, prev = [], 0
    for first, last in build_scan_archive.ranges(ids):
        out.append(b36(first - prev) + '.' + b36(last - first + 1))
        prev = last
    return ','.join(out)


def steps(ids):
    """Sorted ids as "<step>,<step>,..." (base 36, the step from the previous id)."""
    out, prev = [], 0
    for i in sorted(set(ids)):
        out.append(b36(i - prev))
        prev = i
    return ','.join(out)


# ---------------------------------------------------------------- the NPCs our data names
def _load(path):
    if not os.path.exists(path):
        return None
    with open(path, encoding='utf-8') as fh:
        return lua_data.load(fh.read(), os.path.basename(path))


def _values(t):
    return list(t.values()) if t is not None and hasattr(t, 'values') else []


def _keys(t):
    return list(t.keys()) if t is not None and hasattr(t, 'keys') else []


def _int(v):
    try:
        v = int(v)
    except (TypeError, ValueError):
        return None
    return v if 0 < v <= 9999999 else None


def data_npcs(data=DATA):
    """{NPC id: set of where from} of every NPC the shipped data files name."""
    out = {}

    def add(v, src):
        v = _int(v)
        if v:
            out.setdefault(v, set()).add(src)

    ns = _load(os.path.join(data, 'DungeonData.lua'))
    if ns is not None and ns.DUNGEON_FACTS is not None:
        for e in _values(ns.DUNGEON_FACTS.list):
            for v in _values(e.npcs):
                if v is not False:
                    add(v, 'dungeon boss')
    ns = _load(os.path.join(data, 'BisData.lua'))
    B = ns.BIS if ns is not None else None
    if B is not None:
        for v in _values(B.EN):
            add(v, 'boss')
        for e in _values(B.DG):
            for k in _keys(e.bossNames):
                add(k, 'boss')
    ns = _load(os.path.join(data, 'QuestData.lua'))
    if ns is not None and ns.QUEST_DATA is not None:
        for k in _keys(ns.QUEST_DATA.N):
            add(k, 'quest giver')
    ns = _load(os.path.join(data, 'GearData.lua'))
    if ns is not None and ns.GEAR is not None:
        for r in _values(ns.GEAR.S):
            kind = r[1]
            if kind == 'R':
                add(r[5], 'rare')
            elif kind == 'W':
                add(r[6], 'mob')
            elif kind in ('V', 'P'):
                add(r[7], 'vendor')
    ns = _load(os.path.join(data, 'MapData.lua'))
    if ns is not None and ns.MAP is not None:
        for k in _keys(ns.MAP.P):
            if isinstance(k, str) and k.startswith('U:'):
                add(k[2:], 'map point')
    return out


def ranges_b(ids, low=FOREVER_MIN, gap=GAP, pad=PAD):
    """The ranges of phase B: the ids from low up, in clusters no more than gap apart, each padded by pad,
    overlapping ones joined: [[from, to], ...]."""
    big = sorted(i for i in set(ids) if i >= low)
    out = []
    for i in big:
        if out and i - out[-1][1] <= gap:
            out[-1][1] = i
        else:
            out.append([i, i])
    padded = []
    for a, b in out:
        a, b = max(low, a - pad), b + pad
        if padded and a <= padded[-1][1] + 1:
            padded[-1][1] = max(b, padded[-1][1])
        else:
            padded.append([a, b])
    return padded


# ---------------------------------------------------------------- the files
def lua_str(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'


def lists_text(build, qids, npcs, nb):
    lines = [
        '-- GENERATED by tools/build_scan_lists.py. Do not edit; rebuild instead.',
        f'-- Sources: the WoW Forever client table QuestV2 ({build or "none"}) and the NPC ids the other data files',
        '-- name (DungeonData, BisData, QuestData, GearData, MapData).',
        'local _, ns = ...',
        '',
        '-- What the scans by id ask for (Collect/ScanQuests.lua, ScanNpcs.lua; D-104). Q: every quest id of the',
        '-- client, ranges "<step>.<length>" (steps from the end of the previous range); NA: the NPCs of phase A,',
        '-- "<step>,<step>" (steps from the previous id); every number base 36. NB: the id ranges of phase B',
        f'-- {{ from, to }} (the ids from {FOREVER_MIN} up in clusters no more than {GAP} apart, padded by {PAD}).',
        'ns.SCAN_LISTS = {',
        f'    client = {lua_str(build or "")}, q = {len(qids)}, na = {len(npcs)}, nb = {sum(b - a + 1 for a, b in nb)},',
        f'    Q = "{stepped_ranges(qids)}",',
        f'    NA = "{steps(npcs)}",',
        '    NB = { ' + ', '.join(f'{{ {a}, {b} }}' for a, b in nb) + ' },',
        '}',
    ]
    return lua_data.lazy('\n'.join(lines) + '\n', 'SCAN_LISTS', len(qids) + len(npcs))


def clean(name):
    name = ' '.join(str(name or '').replace('|', ' ').split())
    return name[:MAX_NAME]


def names_parts(scans):
    """{loc: {'Q': {id: title}, 'N': {id: name}}} of the scans, English left out."""
    out = {}
    for loc, part in (scans.get('quests') or {}).items():
        if loc in ('enUS', 'enGB'):
            continue
        for qid, f in part.items():
            t = clean(f.get('title'))
            if t and not t.startswith('<'):
                out.setdefault(loc, {'Q': {}, 'N': {}})['Q'][qid] = t
    for loc, part in (scans.get('npcs') or {}).items():
        if loc in ('enUS', 'enGB'):
            continue
        for nid, f in part.items():
            t = clean(f.get('name'))
            if t:
                out.setdefault(loc, {'Q': {}, 'N': {}})['N'][nid] = t
    return out


def names_text(parts):
    n = sum(len(p['Q']) + len(p['N']) for p in parts.values())
    lines = [
        '-- GENERATED by tools/build_scan_lists.py. Do not edit; rebuild instead.',
        '-- Sources: the Amisia quest and NPC scans by id (tools/scan_archive.json and the SavedVariables), as the',
        '-- client showed them in its language.',
        'local _, ns = ...',
        '',
        '-- The names the scans by id found, per language (English left out: the data has those): L = { deDE =',
        '-- { Q = { [quest id] = title }, N = { [NPC id] = name } } }. The addon shows them where the data has only',
        '-- the English name (D-104).',
        'ns.SCAN_NAMES = {',
        '    L = {',
    ]
    for loc in sorted(parts):
        p = parts[loc]
        lines.append(f'        {loc} = {{')
        for key in ('Q', 'N'):
            lines.append(f'            {key} = {{')
            for i in sorted(p[key]):
                lines.append(f'                [{i}] = {lua_str(p[key][i])},')
            lines.append('            },')
        lines.append('        },')
    lines += ['    },', '}']
    return lua_data.lazy('\n'.join(lines) + '\n', 'SCAN_NAMES', n)


def write(path, text):
    if os.path.exists(path):
        with open(path, encoding='utf-8') as fh:
            if fh.read() == text:
                return False
    with open(path, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(text)
    return True


def build(wago, svs=None, archive=build_scan_archive.ARCHIVE, data=DATA, lists=LISTS, names=NAMES):
    """Writes both files; returns (quest ids, phase A ids, phase B ranges, names parts)."""
    import build_scan
    build_id, qids = quest_ids(wago)
    found = data_npcs(data)
    npcs = sorted(found)
    nb = ranges_b(npcs)
    dbs = [build_scan.load_sv(p) for p in (build_scan_archive.default_svs() if svs is None else svs)]
    scans = build_scan_archive.id_scans(archive, dbs)
    parts = names_parts(scans)
    wrote = write(lists, lists_text(build_id, qids, npcs, nb))
    log(f'quests: {len(qids)} ids of QuestV2 {build_id or "(missing)"}; NPCs phase A: {len(npcs)} '
        f'({", ".join(f"{k} {v}" for k, v in sorted(count_sources(found).items()))}); phase B: {len(nb)} ranges, '
        f'{sum(b - a + 1 for a, b in nb)} ids -> {os.path.relpath(lists, ROOT)}' + ('' if wrote else ' (unchanged)'))
    wrote = write(names, names_text(parts))
    log('names: ' + (', '.join(f'{loc} {len(p["Q"])} quests, {len(p["N"])} NPCs' for loc, p in sorted(parts.items())) or 'none yet')
        + f' -> {os.path.relpath(names, ROOT)}' + ('' if wrote else ' (unchanged)'))
    return qids, npcs, nb, parts


def count_sources(found):
    out = {}
    for srcs in found.values():
        for s in srcs:
            out[s] = out.get(s, 0) + 1
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--wago', default=None, help='folder with the client table QuestV2 (default: tools/client_tables.py)')
    ap.add_argument('--sv', nargs='*', help='Amisia SavedVariables (default: ~/addons/_SavedVariables/Amisia.lua ...)')
    ap.add_argument('--scan-archive', default=build_scan_archive.ARCHIVE)
    ap.add_argument('--data', default=DATA, help='the folder of the data files read for the NPC ids')
    ap.add_argument('--lists', default=LISTS)
    ap.add_argument('--names', default=NAMES)
    args = ap.parse_args(argv)
    if args.wago is None:
        import client_tables
        args.wago = client_tables.default_dir()
    build(args.wago, args.sv, args.scan_archive, args.data, args.lists, args.names)
    return 0


if __name__ == '__main__':
    sys.exit(main())
