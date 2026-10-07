"""Builds addon/Amisia/Data/DungeonQuestData.lua (WoW Forever): the quests of every dungeon and raid of
tools/forever_dungeons.json for the addon's dungeon planner - where each quest starts (the quest
giver with map points, inside the dungeon, or by an item), its level, faction, pre-quests and gear
rewards. Runs without a WoW install (on the N100).

    python tools/build_dungeonquests.py [--att DIR] [--refresh-att] [--json FILE]

The input is pluggable: every reader turns its source into one neutral form (see NEUTRAL below),
and render() writes the Lua file from that form only.

- --att DIR (default ~/addons/_cache/att): AllTheThings' hand-kept Forever data, the folder
  .contrib/.db/forever of https://github.com/ATTWoWAddon/AllTheThings (MIT licence; the copyright
  line and the licence text ship in addon/Amisia/LICENSES/). --refresh-att downloads that folder
  through the GitHub API (the repository is far too large to clone). The shared reader
  tools/att_data.py runs the files (a Lua builder language) in a sandbox; read_att() takes the
  quests of its Forever folders from there.
- --json FILE: the neutral form as JSON (hand-made data, tests).
- Without any input the file is written empty: the addon then says the quest data is missing.

No data of other quest databases goes in.
"""
import argparse
import copy
import json
import os
import re
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import att_data  # noqa: E402  (the AllTheThings reader)
import build_gear  # noqa: E402  (dungeon name keys, Lua strings)

FACTS = os.path.join(HERE, 'forever_dungeons.json')
OUT = os.path.join(ROOT, 'addon', 'Amisia', 'Data', 'DungeonQuestData.lua')
ATT_CACHE = att_data.ATT_CACHE
ATT_SOURCE = att_data.ATT_SOURCE

# NEUTRAL: {'source': text for the header, 'commit': text or None,
#           'dungeons': {fact key: [quest ids]},
#           'quests': {quest id: {'name', 'minLevel', 'level', 'faction' ('A', 'H', ''), 'classes' (mask),
#                                 'start' ('O' outside, 'I' inside, 'X' by an item, '' unknown), 'giver',
#                                 'points' ([(uiMapID, x, y) in hundredths of a percent]), 'preAll' [ids]
#                                 (all of them), 'preOne' [ids] (any one of them: ATT's sourceQuests with
#                                 sourceQuestNumRequired 1), 'alt' [ids] (the quests that exclude this one:
#                                 ATT's altQuests), 'breadcrumb' (bool), 'dungeon' (fact key or None),
#                                 'rewards' [item ids]}}}
MAX_POINTS = 4


def log(*a):
    print(*a, file=sys.stderr)


def load_facts(path=FACTS):
    with open(path, encoding='utf-8') as fh:
        return json.load(fh)['dungeons']


def fact_key_of(facts, name=None, area=None):
    """The fact key of a dungeon by its area id or its name (name or alias), else None."""
    if area:
        for e in facts:
            if e.get('area') == area:
                return e['key']
    if name:
        k = build_gear.dungeon_key(name)
        for e in facts:
            for n in [e.get('name')] + list(e.get('aliases') or []):
                if n and build_gear.dungeon_key(n) == k:
                    return e['key']
    return None


def hundredths(v):
    return max(0, min(10000, int(v * 100 + 0.5)))


# ---------------------------------------------------------------- AllTheThings reader
# The shared reader (tools/att_data.py) runs the downloaded files in its sandbox; this turns its
# neutral form into the one of this script.
clean_name = att_data.clean_name


def read_att(base, facts, commit=None):
    """The neutral form from a download of AllTheThings' .contrib/.db/forever folder: the quests of
    the Forever folders (the Classic zzOLD folders stay out here)."""
    db = att_data.load(base, items=False)
    report = {'files': len(db['files']), 'instances without facts': [], 'quests': 0, 'errors': db['errors']}
    keys = {}
    for iid, inst in db['instances'].items():
        if inst['old'] or not inst['file'].startswith('dungeons'):
            continue
        key = fact_key_of(facts, inst['stem'], inst.get('area'))
        if key:
            keys[iid] = key
        elif inst['stem'] not in report['instances without facts']:
            report['instances without facts'].append(inst['stem'])
    quests, dungeons = {}, {}
    for qid, q in db['quests'].items():
        if q['old']:
            continue
        pts = q['points'][:MAX_POINTS]
        start = ''
        if pts:
            start = 'I' if q['inside'] else 'O'
        elif not q['givers'] and q['startItem']:
            start = 'X'
        key = keys.get(q['inst']) if q['inst'] is not None else None
        pre = list(q['pre'])
        one = q.get('sqreq') == 1 and len(pre) > 1
        quests[qid] = {'name': q['name'] or f'Quest {qid}', 'minLevel': q['minLevel'], 'level': 0,
                       'faction': q['faction'], 'classes': q['classes'], 'start': start, 'giver': q['giver'],
                       'points': pts, 'preAll': [] if one else pre, 'preOne': pre if one else [],
                       'alt': list(q['alt']), 'breadcrumb': bool(q.get('breadcrumb')), 'dungeon': key,
                       'rewards': list(q['rewards'])}
        if key:
            dungeons.setdefault(key, []).append(qid)
    report['quests'] = len(quests)
    return {'source': ATT_SOURCE, 'commit': commit or db.get('commit'), 'dungeons': dungeons, 'quests': quests}, report


refresh_att = att_data.refresh


def read_json(path):
    with open(path, encoding='utf-8') as fh:
        data = json.load(fh)
    data['quests'] = {int(k): v for k, v in data.get('quests', {}).items()}
    for v in data['quests'].values():
        v['points'] = [tuple(p) for p in v.get('points') or []]
    return data


def empty():
    return {'source': 'none yet', 'commit': None, 'dungeons': {}, 'quests': {}}


# ---------------------------------------------------------------- output
def complete(data):
    """Drops pre-quests the data has no record of, the quest itself and breadcrumbs among the "all of"
    pre-quests (a way to the quest, never a must), and sorts the lists (the addon walks what it gets)."""
    Q = data['quests']
    for qid, q in Q.items():
        for k in ('preAll', 'preOne', 'alt'):
            q[k] = sorted({p for p in q.get(k) or [] if p in Q and p != qid})
        q['preAll'] = [p for p in q['preAll'] if not Q[p].get('breadcrumb')]
    for key in data['dungeons']:
        data['dungeons'][key] = sorted(set(data['dungeons'][key]))
    return data


def ancestors(Q, qid):
    """Every pre-quest of a quest once, nearest first; a loop ends."""
    out, seen, todo = [], {qid}, [qid]
    while todo:
        q = Q.get(todo.pop(0))
        if not q:
            continue
        for p in (q.get('preAll') or []) + (q.get('preOne') or []):
            if p not in seen:
                seen.add(p)
                out.append(p)
                todo.append(p)
    return out


def _lua_list(v):
    return 'nil' if not v else '{ ' + ', '.join(str(int(x)) for x in v) + ' }'


def render(data, built):
    lua_str, lua_val = build_gear.lua_str, build_gear.lua_val
    data = complete(copy.deepcopy(data))
    # only the dungeon quests and their pre-quests go in
    keep = set()
    for ids in data['dungeons'].values():
        for qid in ids:
            keep.add(qid)
            keep.update(ancestors(data['quests'], qid))
    commit = (data.get('commit') or '')[:10]
    lines = [
        '-- GENERATED by tools/build_dungeonquests.py. Do not edit; rebuild instead.',
        f'-- Source: {data["source"]}' + (f' at {commit}.' if commit else '.'),
        'local _, ns = ...',
        '',
        '-- D: [dungeon key of DungeonData.lua] = its quests.',
        '-- Q: [quest id] = { name (English), required level, quest level (0 unknown), faction ("A", "H", "" both),',
        '-- class mask (0 all), start ("O" outside, "I" inside the dungeon, "X" by an item, "" unknown), giver,',
        '-- points (up to four "uiMapID:x:y", x and y in hundredths of a percent), pre-quests all of, pre-quests',
        '-- one of, dungeon key (nil for a pre-quest only), gear rewards, quests that exclude this one (one of them',
        '-- done: this one is no longer possible) }.',
        'ns.DUNGEON_QUESTS = {',
        f'    built = {lua_str(built)}, source = {lua_str(commit or data["source"][:20])},',
        '    D = {',
    ]
    for key in sorted(data['dungeons']):
        k = key if key.isidentifier() else f'[{lua_str(key)}]'
        lines.append(f'        {k} = {_lua_list(data["dungeons"][key])},')
    lines += ['    },', '    Q = {']
    for qid in sorted(keep):
        q = data['quests'].get(qid)
        if not q:
            continue
        pts = ' '.join(f'{m}:{x}:{y}' for m, x, y in (q.get('points') or [])[:MAX_POINTS]) or None
        parts = [lua_str(q.get('name') or f'Quest {qid}'), str(int(q.get('minLevel') or 0)), str(int(q.get('level') or 0)),
                 lua_str(q.get('faction') or ''), str(int(q.get('classes') or 0)), lua_str(q.get('start') or ''),
                 lua_val(q.get('giver')), lua_val(pts), _lua_list(q.get('preAll')), _lua_list(q.get('preOne')),
                 lua_val(q.get('dungeon')), _lua_list(q.get('rewards')), _lua_list(q.get('alt'))]
        lines.append(f'        [{qid}] = {{ {", ".join(parts)} }},')
    lines += ['    },', '}', '']
    text = '\n'.join(lines)
    if re.search(r'[\x00-\x08\x0b-\x1f\x7f]', text):
        raise SystemExit('control characters in the output')
    return text


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--att', default=None, help=f'AllTheThings download (default {ATT_CACHE} when it exists)')
    ap.add_argument('--refresh-att', action='store_true', help='download the AllTheThings Forever folder first')
    ap.add_argument('--json', default=None, help='the neutral form as JSON')
    ap.add_argument('--empty', action='store_true', help='write the file without data')
    ap.add_argument('--out', default=OUT)
    args = ap.parse_args(argv)
    facts = load_facts()
    report = {}
    if args.json:
        data = read_json(args.json)
    elif args.empty:
        data = empty()
    else:
        base = args.att or ATT_CACHE
        commit = None
        if args.refresh_att:
            commit = refresh_att(base)
        elif os.path.exists(os.path.join(base, 'COMMIT')):
            with open(os.path.join(base, 'COMMIT'), encoding='utf-8') as fh:
                commit = fh.read().strip() or None
        if not os.path.isdir(os.path.join(base, 'dungeons & raids')):
            raise SystemExit(f'no AllTheThings download in {base}: run with --refresh-att (or --empty)')
        data, report = read_att(base, facts, commit)
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
        log(f'wrote {os.path.relpath(args.out, ROOT)} ({os.path.getsize(args.out) // 1024} KB)')
    for key in sorted(data['dungeons']):
        log(f'  {key}: {len(data["dungeons"][key])} quests')
    missing = [e['key'] for e in facts if e['key'] not in data['dungeons']]
    if missing:
        log(f'  without quests (data missing): {", ".join(missing)}')
    if report.get('instances without facts'):
        log(f'  instances without facts: {report["instances without facts"]}')


if __name__ == '__main__':
    main()
