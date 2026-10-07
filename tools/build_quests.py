"""Builds addon/Amisia/Data/QuestData.lua (WoW Forever): every quest of the world for the addon's quest
tracker - zone, name, required level, faction, class and race limits, profession, the quest giver
and where it stands, pre-quests, quests it excludes, gear rewards. Runs without a WoW install (on
the N100).

    python tools/build_quests.py [--att DIR] [--refresh-att] [--json FILE] [--empty]

- --att DIR (default ~/addons/_cache/att): AllTheThings' hand-kept Forever data, the folder
  .contrib/.db/forever of https://github.com/ATTWoWAddon/AllTheThings (MIT licence; the copyright
  line and the licence text ship in addon/Amisia/LICENSES/). --refresh-att downloads it through the
  GitHub API. The shared reader tools/att_data.py runs the files in its sandbox; this build reads
  its usual folders (the Forever ones and the Classic zzOLD ones the authors have not moved yet, a
  Forever record winning). The class and profession quests live in the zone files there; the
  folders character/ and zzOLD/10 - Professions held no other quest at f8d7232/bf0a1ad.
- --json FILE: the neutral form as JSON (hand-made data, tests).
- Without any input (--empty) the file is written empty: the addon then says the data is missing.

The output is compact: one string per quest, the givers once in an NPC table (name and places), only
gear among the rewards, English zone names only as the fallback for the client's own. The size goes
to the log. No data of other quest databases goes in.
"""
import argparse
import json
import os
import re
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import att_data  # noqa: E402  (the AllTheThings reader)
import lua_data  # noqa: E402  (the lazy form of the data file)
import build_gear  # noqa: E402  (Lua strings)

OUT = os.path.join(ROOT, 'addon', 'Amisia', 'Data', 'QuestData.lua')
ATT_CACHE = att_data.ATT_CACHE
MAX_POINTS = 4
GEAR_CLASSES = (2, 4)      # weapon, armour
NOT_GEAR = ('', 'INVTYPE_AMMO', 'INVTYPE_BAG', 'INVTYPE_QUIVER')

# NEUTRAL: {'source': text for the header, 'commit': text or None,
#           'zones': {uiMapID: English name},
#           'npcs': {NPC id: {'name', 'points' [(uiMapID, x, y) in hundredths of a percent]}},
#           'quests': {quest id: QUEST_DEFAULTS with values}}
QUEST_DEFAULTS = {'zone': 0, 'name': '', 'minLevel': 0, 'faction': '', 'classes': 0, 'races': 0, 'skill': 0,
                  'giver': 0, 'points': [], 'start': '', 'pre': [], 'sqreq': 0, 'alt': [], 'rewards': [],
                  'breadcrumb': False, 'repeatable': False, 'old': False}


def log(*a):
    print(*a, file=sys.stderr)


def empty():
    return {'source': 'none yet', 'commit': None, 'zones': {}, 'npcs': {}, 'quests': {}}


_SMALL = {'of', 'the', 'and', 'in'}


def zone_name(const):
    """"ELWYNN_FOREST" -> "Elwynn Forest", "THE_BARRENS" -> "The Barrens"."""
    words = const.lower().split('_')
    return ' '.join(w if i and w in _SMALL else w.capitalize() for i, w in enumerate(words))


def read_att(base, commit=None):
    """The neutral form from a download of AllTheThings' .contrib/.db/forever folder."""
    db = att_data.load(base, items=True)
    items = db['items']
    report = {'files': len(db['files']), 'errors': db['errors']}

    def gear(i):
        it = items.get(i)
        return it is not None and it['classID'] in GEAR_CLASSES and it['equipLoc'] not in NOT_GEAR

    npcs, quests, used_maps = {}, {}, set()
    for qid, q in db['quests'].items():
        giver = q['givers'][0] if q['givers'] else 0
        npc = db['npcs'].get(giver) if giver else None
        gpts = list((npc or {}).get('points') or [])[:MAX_POINTS]
        own = list(q['points'][:MAX_POINTS])
        # the quest's own points only where the giver's do not say the same
        points = own if (not giver or not set(own) <= set(gpts)) else []
        start = ''
        if own:
            start = 'I' if q['inside'] else 'O'
        elif gpts:
            start = 'I' if (npc or {}).get('inst') is not None else 'O'
        elif not q['givers'] and q['startItem']:
            start = 'X'
        eff = own or gpts
        zone = q['zone'] or (eff[0][0] if eff else 0)
        if giver:
            npcs[giver] = {'name': (npc or {}).get('name') or q['giver'] or f'NPC {giver}', 'points': gpts}
        for p in eff:
            used_maps.add(p[0])
        if zone:
            used_maps.add(zone)
        quests[qid] = dict(QUEST_DEFAULTS, zone=zone or 0, name=q['name'] or f'Quest {qid}', minLevel=q['minLevel'] or 0,
                           faction=q['faction'] or '', classes=q['classes'] or 0, races=q.get('races') or 0,
                           skill=q.get('skill') or 0, giver=giver, points=points, start=start, pre=list(q['pre']),
                           sqreq=q.get('sqreq') or 0,
                           alt=list(q['alt']), rewards=[i for i in q['rewards'] if gear(i)],
                           breadcrumb=bool(q.get('breadcrumb')), repeatable=bool(q.get('repeatable')), old=bool(q['old']))
    zones = {}
    for const, mid in sorted(db['maps'].items()):
        if isinstance(mid, (int, float)) and int(mid) in used_maps:
            zones.setdefault(int(mid), zone_name(const))
    for inst in db['instances'].values():
        for m in inst['maps']:
            if m in used_maps:
                zones[m] = inst['name']
    report['quests'] = len(quests)
    return {'source': att_data.ATT_SOURCE, 'commit': commit or db.get('commit'), 'zones': zones, 'npcs': npcs,
            'quests': quests}, report


def read_json(path):
    with open(path, encoding='utf-8') as fh:
        data = json.load(fh)
    out = empty()
    out.update({k: data[k] for k in ('source', 'commit') if k in data})
    out['zones'] = {int(k): v for k, v in data.get('zones', {}).items()}
    out['npcs'] = {int(k): {'name': v.get('name') or '', 'points': [tuple(p) for p in v.get('points') or []]}
                   for k, v in data.get('npcs', {}).items()}
    out['quests'] = {int(k): dict(QUEST_DEFAULTS, **{**v, 'points': [tuple(p) for p in v.get('points') or []]})
                     for k, v in data.get('quests', {}).items()}
    return out


# ---------------------------------------------------------------- output
def _text(s):
    """A name as one field: the separators of the record become commas, controls go."""
    return re.sub(r'[\x00-\x1f\x7f]', '', str(s or '')).replace(';', ',').strip()


def _ids(v):
    return ','.join(str(int(x)) for x in v)


def _points(v):
    return ' '.join(f'{int(m)}:{int(x)}:{int(y)}' for m, x, y in list(v)[:MAX_POINTS])


def record(q, known, qid=None):
    # a quest is no pre-quest of itself (the source lists a few that way)
    pre = sorted({p for p in q.get('pre') or [] if p in known and p != qid})
    need = int(q.get('sqreq') or 0)
    flags = ('B' if q.get('breadcrumb') else '') + ('R' if q.get('repeatable') else '') + ('C' if q.get('old') else '')
    if 0 < need < len(pre):
        flags += f'N{need}'
    alt = sorted({p for p in q.get('alt') or [] if p in known})
    return ';'.join([str(int(q.get('zone') or 0)), _text(q.get('name')), str(int(q.get('minLevel') or 0)),
                     q.get('faction') or '', str(int(q.get('classes') or 0)), str(int(q.get('races') or 0)),
                     str(int(q.get('skill') or 0)), str(int(q.get('giver') or 0)), _points(q.get('points') or []),
                     q.get('start') or '', _ids(pre), _ids(alt), _ids(q.get('rewards') or []), flags])


def render(data, built):
    lua_str = build_gear.lua_str
    Q = data['quests']
    known = set(Q)
    givers = sorted({int(q.get('giver') or 0) for q in Q.values()} - {0})
    commit = (data.get('commit') or '')[:10]
    lines = [
        '-- GENERATED by tools/build_quests.py. Do not edit; rebuild instead.',
        f'-- Source: {data["source"]}' + (f' at {commit}.' if commit else '.'),
        'local _, ns = ...',
        '',
        '-- Z: [uiMapID] = English zone name (the fallback; the client\'s own name wins).',
        '-- N: [NPC id] = "name;points", points "uiMapID:x:y" apart by spaces, x and y in hundredths of a percent.',
        '-- Q: [quest id] = "zone;name;minLevel;faction;classes;races;skill;giver;points;start;pre;alt;rewards;flags":',
        '-- zone uiMapID (0 unknown); faction A, H or empty (both); classes and races as masks (bit id - 1, 0 all);',
        '-- skill the skill line it needs (0 none); giver an NPC id of N (0 none); points the quest\'s own start where',
        '-- the giver\'s differ; start O outside, I inside a dungeon, X by an item, empty unknown; pre the quests to',
        '-- finish first (all of them, or as many as the flag N<n> says); alt the quests that exclude this one; rewards',
        '-- gear item ids; flags B breadcrumb, R repeatable, C Classic data the source has not moved to its Forever',
        '-- files yet, N<n> only n of pre needed (any one of them for N1).',
        'ns.QUEST_DATA = {',
        f'    built = {lua_str(built)}, source = {lua_str(commit or data["source"][:20])}, count = {len(Q)},',
        '    Z = {',
    ]
    for z in sorted(data.get('zones') or {}):
        lines.append(f'        [{int(z)}] = {lua_str(_text(data["zones"][z]))},')
    lines += ['    },', '    N = {']
    for g in givers:
        n = (data.get('npcs') or {}).get(g) or {}
        lines.append(f'        [{g}] = {lua_str(_text(n.get("name") or f"NPC {g}") + ";" + _points(n.get("points") or []))},')
    lines += ['    },', '    Q = {']
    for qid in sorted(Q):
        lines.append(f'        [{int(qid)}] = {lua_str(record(Q[qid], known, qid))},')
    lines += ['    },', '}', '']
    text = '\n'.join(lines)
    if re.search(r'[\x00-\x08\x0b-\x1f\x7f]', text):
        raise SystemExit('control characters in the output')
    # the addon builds the table on first use (Core/LazyData.lua)
    return lua_data.lazy(text, 'QUEST_DATA', len(Q))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--att', default=None, help=f'AllTheThings download (default {ATT_CACHE})')
    ap.add_argument('--refresh-att', action='store_true', help='download the AllTheThings Forever folder first')
    ap.add_argument('--json', default=None, help='the neutral form as JSON')
    ap.add_argument('--empty', action='store_true', help='write the file without data')
    ap.add_argument('--out', default=OUT)
    args = ap.parse_args(argv)
    report = {}
    if args.json:
        data = read_json(args.json)
    elif args.empty:
        data = empty()
    else:
        base = args.att or ATT_CACHE
        commit = att_data.refresh(base) if args.refresh_att else att_data.commit_of(base)
        if not os.path.isdir(os.path.join(base, 'zones')):
            raise SystemExit(f'no AllTheThings download in {base}: run with --refresh-att (or --empty)')
        data, report = read_att(base, commit)
    text = render(data, time.strftime('%Y-%m-%d'))
    old = None
    if os.path.exists(args.out):
        with open(args.out, encoding='utf-8') as fh:
            old = fh.read()
    if old is not None and re.sub(r'built = "[^"]*"', '', old) == re.sub(r'built = "[^"]*"', '', text):
        log(f'{os.path.relpath(args.out, ROOT)} is current')
    else:
        with open(args.out, 'w', encoding='utf-8', newline='\n') as fh:
            fh.write(text)
        log(f'wrote {os.path.relpath(args.out, ROOT)}')
    Q = data['quests']
    size = len(text.encode('utf-8'))
    q_bytes = sum(len(record(q, set(Q), qid).encode('utf-8')) for qid, q in Q.items())
    log(f'  {len(Q)} quests ({sum(1 for q in Q.values() if q.get("old"))} from the Classic folders), '
        f'{len({q.get("giver") for q in Q.values()} - {0})} givers, {len(data.get("zones") or {})} zones')
    log(f'  size {size / 1024:.0f} KB (quest strings {q_bytes / 1024:.0f} KB)')
    log(f'  without a start place: {sum(1 for q in Q.values() if not q.get("start"))}, by an item: '
        f'{sum(1 for q in Q.values() if q.get("start") == "X")}, with gear rewards: '
        f'{sum(1 for q in Q.values() if q.get("rewards"))}, with pre-quests: {sum(1 for q in Q.values() if q.get("pre"))}')
    if report.get('errors'):
        log(f'  files that failed: {sorted(report["errors"])}')


if __name__ == '__main__':
    main()
