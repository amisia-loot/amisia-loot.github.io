"""Builds Amisia_Gear/Data/DungeonQuestData.lua (WoW Forever): the quests of every dungeon and raid of
tools/forever_dungeons.json for the addon's dungeon planner - where each quest starts (the quest
giver with map points, inside the dungeon, by an item or at an object), where it is turned in, its
level, faction, races, profession, pre-quests, breadcrumbs, gear rewards and objective. Runs without
a WoW install (on the N100).

    python tools/build_dungeonquests.py [--att DIR] [--refresh-att] [--json FILE] [--sv FILE...]

The input is pluggable: every reader turns its source into one neutral form (see NEUTRAL below),
and render() writes the Lua file from that form only.

- --att DIR (default ~/addons/_cache/att, or $AMISIA_ATT_CACHE): AllTheThings' hand-kept Forever
  data, the folder .contrib/.db/forever of https://github.com/ATTWoWAddon/AllTheThings (MIT licence;
  the copyright line and the licence text ship in Amisia/LICENSES/). --refresh-att downloads that
  folder through the GitHub API (the repository is far too large to clone). The shared reader
  tools/att_data.py runs the files (a Lua builder language) in a sandbox; read_att() takes the
  quests of its Forever folders from there.
- --sv FILE... (default ~/addons/_SavedVariables/Amisia.lua and an installed Forever client's): the
  source collector's quest records (AmisiaDB.collect.q, Collector.lua). Only the fields the record
  marks as the client's own count (never what was heard from the guild); they go before the data:
  the giver's name (German) and place, the turn-in NPC and place, the quest level, the objective
  text. They are joined into tools/quest_obs.json, which keeps them after the addon prunes its table
  (--obs-archive "" for none).
- --scan-archive FILE (default tools/scan_archive.json, "" for none): the quest scan by id (D-104): the
  level the client gives a quest, where the data and the own observations have none, and the XP it saw
  (field 23). Its dungeon and raid quests that no source places go into the one dungeon their text
  names (D-109, place_scanned(); --no-place-scanned for none): the names come from the facts, the
  client tables of --wago (English) and --de-dirs (<Table>.<build>.deDE.csv) and the NPC scan; --report
  lists what was placed and what was not, and why.
- --hints FILE (default tools/quest_hints.json, "" for none): hand-kept hints for quests whose start or
  turn-in no source knows (DECISIONS D-65), in own words: the dungeon where a start item lies, the
  turn-in NPC (an id of the data, or a name), the spots in the dungeon where the start item can lie
  (German and English). They fill gaps only: the data's own values stay, own observations go first.
- --json FILE: the neutral form as JSON (hand-made data, tests).
- Without any input the file is written empty: the addon then says the quest data is missing.

No data of other quest databases goes in.
"""
import argparse
import copy
import csv
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
import build_scan  # noqa: E402  (the SavedVariables sandbox, the collector's field checks)

FACTS = os.path.join(HERE, 'forever_dungeons.json')
OUT = os.path.join(ROOT, 'Amisia_Gear', 'Data', 'DungeonQuestData.lua')
OBS_ARCHIVE = os.path.join(HERE, 'quest_obs.json')
HINTS = os.path.join(HERE, 'quest_hints.json')
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
#                                 'rewards' [item ids], 'startItems' [(item id, NPC name or None, uiMapID
#                                 or None, fact key or None): where the item that starts it drops],
#                                 'startObject' (name or None), 'races' (mask, bit race id - 1, 0 any),
#                                 'skill' (skill line or 0), 'ender' (turn-in NPC name or None),
#                                 'enderPoints' [(uiMapID, x, y)], 'objective' (text or None),
#                                 'spots' ([(German, English)]: where in the dungeon the start item can lie,
#                                 from the hand-kept hints, D-65)}}}
MAX_POINTS = 4
MAX_OBJECTIVE = 300
NEAR = 150   # an observed point replaces a data point within 1.5 % of it


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


def drop_sources(db, keys):
    """{item id: [(NPC name or None, uiMapID or None, fact key or None)]}: where the data says an item
    drops (an NPC's loot, or a zone drop with the mobs that drop it), the Forever records only, each
    place once, the ones with an NPC name first."""
    out = {}

    def add(item, npc, zone, inst):
        name, where = None, zone
        if npc is not None:
            rec = db['npcs'].get(npc) or {}
            name = rec.get('name') or db.get('npc_names', {}).get(npc)
            if where is None and rec.get('points'):
                where = rec['points'][0][0]
        e = (name, where, keys.get(inst) if inst is not None else None)
        lst = out.setdefault(item, [])
        if e not in lst and any(e):
            lst.append(e)
    for item, npc, kind, inst, zone, old, _boss in db['drops']:
        if not old and kind != 'vendor':
            add(item, npc, zone, inst)
    for item, crs, inst, zone, old in db['zone_drops']:
        if not old:
            for c in crs or [None]:
                add(item, c, zone, inst)
    for lst in out.values():
        lst.sort(key=lambda e: e[0] is None)
    return out


def read_att(base, facts, commit=None):
    """The neutral form from a download of AllTheThings' .contrib/.db/forever folder: the quests of
    the Forever folders (Classic zzOLD folders, where a download still has them, stay out here)."""
    db = att_data.load(base, items=False)
    report = {'files': len(db['files']), 'instances without facts': [], 'quests': 0, 'errors': db['errors']}
    # an instance whose wings are dungeons of their own (the facts' part and att_wing, D-106): its quests go
    # to the wings Places.quest_wings() names, its start items to its first wing
    places = build_gear.Places(db, facts)
    parts = set()
    keys = {}
    for iid, inst in db['instances'].items():
        if inst['old'] or not inst['file'].startswith('dungeons'):
            continue
        place = places.of_att(iid)
        if place[0] and build_gear.dungeon_key(place[0]) in places.wings:
            parts.add(iid)
            keys[iid] = fact_key_of(facts, places.split(place)[0])
            continue
        key = fact_key_of(facts, inst['stem'], inst.get('area'))
        if key:
            keys[iid] = key
        elif inst['stem'] not in report['instances without facts']:
            report['instances without facts'].append(inst['stem'])
    drops = drop_sources(db, keys)
    inside_maps = {m for iid, i in db['instances'].items() if iid in keys for m in i['maps']}
    quests, dungeons = {}, {}
    for qid, q in db['quests'].items():
        if q['old']:
            continue
        pts = q['points'][:MAX_POINTS]
        start = ''
        if pts:
            start = 'I' if q['inside'] else 'O'
        elif q['givers']:
            # the quest names no place: where the data has its giver (an NPC record with points, or
            # one listed inside the quest's own dungeon)
            npcs = [db['npcs'][g] for g in q['givers'] if g in db['npcs'] and not db['npcs'][g]['old']]
            for r in npcs:
                for p in r['points']:
                    if p not in pts and len(pts) < MAX_POINTS:
                        pts.append(p)
            if pts:
                start = 'I' if all(p[0] in inside_maps for p in pts) else 'O'
            elif q['inst'] in keys and any(r['inst'] == q['inst'] for r in npcs):
                start = 'I'
        elif q['startItem']:
            start = 'X'
        key = keys.get(q['inst']) if q['inst'] is not None else None
        wing_keys = [key] if key else []
        if q['inst'] in parts:
            wing_keys = [fact_key_of(facts, p[0]) for p in places.quest_wings(places.of_att(q['inst']), q)]
            key = wing_keys[0]
        pre = list(q['pre'])
        one = q.get('sqreq') == 1 and len(pre) > 1
        sitems, sobj = [], None
        if not q['givers']:
            for item in q.get('startItems') or []:
                src = (drops.get(item) or [(None, None, None)])[0]
                if (item,) + src not in sitems:
                    sitems.append((item,) + src)
            sobj = next((db['object_names'][o] for o in q.get('objects') or [] if o in db.get('object_names', {})), None)
        quests[qid] = {'name': q['name'] or f'Quest {qid}', 'minLevel': q['minLevel'], 'level': 0,
                       'faction': q['faction'], 'classes': q['classes'], 'start': start, 'giver': q['giver'],
                       'points': pts, 'preAll': [] if one else pre, 'preOne': pre if one else [],
                       'alt': list(q['alt']), 'breadcrumb': bool(q.get('breadcrumb')), 'dungeon': key,
                       'rewards': list(q['rewards']), 'startItems': sitems, 'startObject': sobj,
                       'races': int(q.get('races') or 0), 'skill': int(q.get('skill') or 0),
                       'ender': None, 'enderPoints': [], 'objective': None}
        for k in wing_keys:
            dungeons.setdefault(k, []).append(qid)
    report['quests'] = len(quests)
    # what apply_observed needs of the data: NPC and object names, NPC places, the dungeon maps
    ctx = {'npc_names': dict(db.get('npc_names') or {}), 'object_names': dict(db.get('object_names') or {}),
           'npc_points': {n: list(r['points']) for n, r in db['npcs'].items() if r['points'] and not r['old']},
           'inside_maps': sorted(inside_maps)}
    for n, r in db['npcs'].items():
        if r.get('name'):
            ctx['npc_names'].setdefault(n, r['name'])
    return {'source': ATT_SOURCE, 'commit': commit or db.get('commit'), 'dungeons': dungeons, 'quests': quests,
            'context': ctx}, report


refresh_att = att_data.refresh


def read_json(path):
    with open(path, encoding='utf-8') as fh:
        data = json.load(fh)
    data['quests'] = {int(k): v for k, v in data.get('quests', {}).items()}
    for v in data['quests'].values():
        v['points'] = [tuple(p) for p in v.get('points') or []]
        v['enderPoints'] = [tuple(p) for p in v.get('enderPoints') or []]
        v['startItems'] = [tuple(e) + (None,) * (4 - len(e)) for e in v.get('startItems') or []]
    return data


def empty():
    return {'source': 'none yet', 'commit': None, 'dungeons': {}, 'quests': {}}


# ---------------------------------------------------------------- the source collector (own observations)
# AmisiaDB.collect.q (Collector.lua): one string per quest, fields split by ";", the free-text title
# last; own is a bit mask of the fields after it that the client saw itself (bit 0 the first).
#   version 2: day;own;giver;giverPos;ender;enderPos;rewards;choices;questLevel;minPlayerLevel;faction;pre;giverName;title
#   version 3: ...;pre;giverName;enderName;objective;title (objective with ";" as ",")
# NPC ids are negative for game objects. Only own fields are read here; heard ones never count.
QUEST_FIELDS = {
    2: ('giver', 'gpos', 'ender', 'epos', 'rewards', 'choices', 'qlevel', 'minlvl', 'fac', 'pre', 'gname', 'title'),
    3: ('giver', 'gpos', 'ender', 'epos', 'rewards', 'choices', 'qlevel', 'minlvl', 'fac', 'pre', 'gname', 'ename',
        'objective', 'title'),
}
# the fields this build takes
OBS_FIELDS = ('giver', 'gpos', 'ender', 'epos', 'qlevel', 'gname', 'ename', 'objective')
_MAX_ID = 9999999
_UI_CODE = re.compile(r'\|c[0-9a-fA-F]{8}|\|r|\|H[^|]*\|h|\|h|\|T[^|]*\|t|\|A[^|]*\|a|\|n')
_CTRL = re.compile(r'[\x00-\x1f\x7f|]')


def clean_text(s, limit=MAX_OBJECTIVE):
    """A text the client showed as plain text: colour codes, links, textures and every "|" or control
    character gone, runs of white space as one, at most limit characters (at a whole word where one is
    near)."""
    if not isinstance(s, str):
        return None
    s = _CTRL.sub(' ', _UI_CODE.sub('', s))
    s = re.sub(r'\s+', ' ', s).strip()
    if len(s) > limit:
        cut = s[:limit]
        sp = cut.rfind(' ')
        s = (cut[:sp] if sp > limit - 40 else cut).rstrip()
    return s or None


def _pos(v):
    """A collector place "uiMapID:x:y" as (map, x, y); None for empty or a map without x and y."""
    if not v or not build_scan._pos_ok(v):
        return None
    p = [int(x) for x in v.split(':')]
    return tuple(p) if len(p) == 3 else None


def parse_quest_record(text, ver=None):
    """The own fields of one collector quest record as a dict (with 'day'), or None when the record is
    broken. ver: collect.ver of the table; the other layout is tried when the record does not fit.
    Values: giver/ender ids (negative: a game object), gpos/epos (map, x, y), qlevel, gname/ename,
    objective (clean_text)."""
    if not isinstance(text, str) or len(text.encode('utf-8')) > 4000:
        return None
    order = [3, 2] if (ver or 2) >= 3 else [2, 3]
    for v in order:
        r = _parse_layout(text, QUEST_FIELDS[v])
        if r is not None:
            return r
    return None


def _parse_layout(text, fields):
    f = text.split(';', len(fields) + 1)
    if len(f) != len(fields) + 2:
        return None
    day, own = build_scan._num(f[0], 0, 99999), build_scan._num(f[1], 0, (1 << len(fields)) - 1)
    if day is None or own is None:
        return None
    raw = dict(zip(fields, f[2:]))
    val = {'giver': build_scan._num(raw['giver'], -_MAX_ID, _MAX_ID), 'ender': build_scan._num(raw['ender'], -_MAX_ID, _MAX_ID),
           'qlevel': build_scan._num(raw['qlevel'], 0, 99), 'minlvl': build_scan._num(raw['minlvl'], 0, 99),
           'pre': build_scan._num(raw['pre'], 0, _MAX_ID)}
    if any(v is None for v in val.values()):
        return None
    if not build_scan._pos_ok(raw['gpos']) or not build_scan._pos_ok(raw['epos']) or raw['fac'] not in ('', 'A', 'H', 'AH'):
        return None
    if not build_scan._text_ok(raw['gname'], ';') or ('ename' in raw and not build_scan._text_ok(raw['ename'], ';')):
        return None
    if 'objective' in raw and (len(raw['objective']) > 2 * MAX_OBJECTIVE + 100):
        return None
    out = {'day': day}
    for i, name in enumerate(fields):
        if not own >> i & 1 or name not in OBS_FIELDS:
            continue
        if name in ('giver', 'ender', 'qlevel'):
            v = val[name] or None
        elif name in ('gpos', 'epos'):
            v = _pos(raw[name])
        elif name == 'objective':
            v = clean_text(raw[name])
        else:
            v = raw[name] or None
        if v is not None:
            out[name] = v
    return out


def _join(have, rec):
    """Joins one record into what is known of a quest: per field the newer day wins (a tie: rec)."""
    if have is None:
        return dict(rec)
    newer = rec['day'] >= have['day']
    out = dict(have)
    for k, v in rec.items():
        if k != 'day' and (newer or k not in have):
            out[k] = v
    out['day'] = max(have['day'], rec['day'])
    return out


def read_observed(dbs, base=None):
    """{quest id: own fields} of the SavedVariables' collector records (dbs: load_sv results), joined
    over base (the archive) and over each other."""
    out = {int(k): dict(v) for k, v in (base or {}).items()}
    for db in dbs:
        c = db.get('collect') if isinstance(db, dict) else None
        if not isinstance(c, dict):
            continue
        ver = c.get('ver') if isinstance(c.get('ver'), int) else None
        if ver == 1:
            continue   # version 1 had no own mask: all heard
        t = c.get('q')
        if isinstance(t, list):
            t = {i + 1: v for i, v in enumerate(t)}
        for k, v in (t or {}).items():
            if not isinstance(k, int) or isinstance(k, bool) or not 1 <= k <= _MAX_ID:
                continue
            r = parse_quest_record(v, ver)
            if r is not None and len(r) > 1:
                out[k] = _join(out.get(k), r)
    return out


def load_obs_archive(path=OBS_ARCHIVE):
    """{quest id: own fields} of the archive (places stored as "uiMapID:x:y")."""
    if not path or not os.path.exists(path):
        return {}
    with open(path, encoding='utf-8') as fh:
        arch = json.load(fh)
    out = {}
    for k, v in (arch.get('q') or {}).items():
        rec = dict(v)
        for p in ('gpos', 'epos'):
            if p in rec:
                rec[p] = _pos(rec[p])
        out[int(k)] = {f: x for f, x in rec.items() if x is not None}
    return out


def obs_archive_text(obs, updated):
    """The archive as JSON, one quest per line."""
    def one(r):
        return json.dumps({f: (':'.join(map(str, v)) if isinstance(v, (tuple, list)) else v) for f, v in sorted(r.items())},
                          ensure_ascii=False)
    lines = [f'  "{k}": {one(obs[k])}' for k in sorted(obs)]
    return '{"v": 1, "updated": ' + json.dumps(updated) + ', "q": {\n' + ',\n'.join(lines) + ('\n' if lines else '') + '}}\n'


def save_obs_archive(obs, path=OBS_ARCHIVE, today=None):
    """Writes the archive when what it holds changed (then with today's date). True when it wrote."""
    if not path:
        return False
    if os.path.exists(path) and load_obs_archive(path) == obs:
        return False
    with open(path, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(obs_archive_text(obs, today or time.strftime('%Y-%m-%d')))
    return True


def apply_observed(data, obs):
    """Puts the own observations before the data, in place: the giver's name and place (an observed
    point first; data points near it fall away), the turn-in NPC (the observed name, else the data's
    name for that id) with the observed place or the data's places of that NPC, the quest level where
    the data has none, the objective. Returns how many quests took something."""
    ctx = data.get('context') or {}
    npc_names, obj_names = ctx.get('npc_names') or {}, ctx.get('object_names') or {}
    npc_points, inside = ctx.get('npc_points') or {}, set(ctx.get('inside_maps') or [])
    n = 0
    for qid, o in obs.items():
        q = data['quests'].get(qid)
        if q is None:
            continue
        before = copy.deepcopy(q)
        giver = o.get('giver')
        if o.get('gname'):
            if giver is not None and giver < 0:
                q['startObject'] = o['gname']
            else:
                q['giver'] = o['gname']
        if o.get('gpos'):
            p = tuple(o['gpos'])
            rest = [x for x in q.get('points') or [] if not (x[0] == p[0] and abs(x[1] - p[1]) <= NEAR and abs(x[2] - p[2]) <= NEAR)]
            q['points'] = ([p] + rest)[:MAX_POINTS]
            if q.get('start') in ('', None) or (q.get('start') == 'X' and giver is not None and giver > 0):
                q['start'] = 'I' if p[0] in inside else 'O'
        ender = o.get('ender')
        name = o.get('ename')
        if not name and ender:
            name = npc_names.get(ender) if ender > 0 else obj_names.get(-ender)
        if name:
            q['ender'] = name
        if o.get('epos'):
            q['enderPoints'] = [tuple(o['epos'])]
        elif ender and ender > 0 and npc_points.get(ender):
            q['enderPoints'] = [tuple(x) for x in npc_points[ender][:MAX_POINTS]]
        if o.get('qlevel') and not q.get('level'):
            q['level'] = o['qlevel']
        if o.get('objective'):
            q['objective'] = clean_text(o['objective'])
        if q != before:
            n += 1
    return n


def apply_scanned(data, scans):
    """The quest scan by id (D-104, build_scan_archive.id_scans) where the data and the own observations
    know no level: the client's difficulty level (any language; the same number everywhere). In place;
    returns how many quests took one."""
    levels = scanned_levels(scans)
    n = 0
    for qid, q in data['quests'].items():
        if not q.get('level') and levels.get(qid):
            q['level'] = levels[qid]
            n += 1
    return n


def scanned_levels(scans):
    """{quest id: level} of the quest scan: the quest level where the client gave one, else the
    difficulty level; 0 and missing left out."""
    out = {}
    for part in ((scans or {}).get('quests') or {}).values():
        for qid, f in part.items():
            lvl = f.get('qlevel') or f.get('level') or 0
            if 0 < lvl <= 99:
                out.setdefault(qid, lvl)
    return out


def apply_scanned_xp(data, scans):
    """The XP the quest scan saw (field 23, the scanning character's level unknown) for every quest that
    has none yet. In place; returns how many took one."""
    xp = {}
    for part in ((scans or {}).get('quests') or {}).values():
        for qid, f in part.items():
            v = f.get('xp') or 0
            if 0 < v <= 10000000:
                xp[qid] = max(xp.get(qid, 0), int(v))
    n = 0
    for qid, q in data['quests'].items():
        if not q.get('xp') and xp.get(qid):
            q['xp'] = xp[qid]
            n += 1
    return n


# ---------------------------------------------------------------- dungeon quests of the quest scan (D-109)
# A scanned quest the client tags as a dungeon or raid quest ("D", "R") that no source places in a
# dungeon joins the dungeon its own text names: its title and objective name exactly one dungeon, by
# the dungeon's name or the name of one of its bosses, in the scan's language or in English (Forever's
# German texts keep many English names). Names are compared word by word after a light German stemming
# (case, endings -e/-en/-er/-es/-em/-n/-s/-ses: "Gefängnisses von Alcaz", "der Unteren
# Schwarzfelsspitze", "Varrox Bleakhoofs Kopf"), whole words only, a longer name inside the text
# winning over a shorter one within it. The turn-in place the text names decides the faction where it
# is a town of one faction (FACTION_PLACES).
SCAN_TAGS = ('D', 'R')
ARTICLES = {'der', 'die', 'das', 'the', 'den', 'dem', 'des'}
ENDINGS = ('ses', 'es', 'en', 'er', 'em', 'e', 'n', 's')
# the German names of the wings of an instance that hosts several dungeons (the addon's own words, the
# same as Gear/Dungeons.lua shows); a wing's name counts only beside the instance's name
WING_DE = {'Graveyard': 'Friedhof', 'Library': 'Bibliothek', 'Armory': 'Waffenkammer', 'Cathedral': 'Kathedrale'}
# Towns and home zones of one faction, in English (own knowledge of the game, D-109); the German names
# come from the client's AreaTable in deDE by the English name. A quest text naming only towns of one
# faction (where it is handed in) belongs to that faction. Left out on purpose: places whose German name
# is an ordinary word (Refuge Pointe, "Die Zuflucht": Marshal's Refuge is "Marshals Zuflucht"; The
# Sepulcher, "Das Grabmal") and neutral towns (Ratchet, Gadgetzan, Booty Bay, Everlook, Dalaran).
FACTION_PLACES = {
    'A': ['Stormwind', 'Stormwind City', 'Ironforge', 'Darnassus', 'Theramore', 'Theramore Isle', 'Menethil Harbor',
          'Thelsamar', 'Auberdine', 'Astranaar', 'Goldshire', 'Lakeshire', 'Darkshire', 'Southshore',
          'Aerie Peak', "Nijel's Point", 'Feathermoon', 'Feathermoon Stronghold', 'Thalanaar', 'Talonbranch Glade',
          'Chillwind Camp', "Morgan's Vigil", 'Sentinel Hill', 'Kharanos', 'Dolanaar', "Rut'theran Village",
          'Stonetalon Peak', 'Nethergarde Keep', 'Elwynn Forest', 'Dun Morogh', 'Teldrassil'],
    'H': ['Orgrimmar', 'Thunder Bluff', 'Undercity', 'Kargath', 'Stonard', 'Hammerfall', 'Tarren Mill', 'Brill',
          "Grom'gol Base Camp", "Grom'gol", 'Splintertree Post', 'The Crossroads', 'Camp Taurajo', 'Freewind Post',
          'Brackenwall Village', 'Camp Mojache', 'Shadowprey Village', 'Shadowprey', 'Revantusk Village', 'Flame Crest',
          'Bloodvenom Post', "Zoram'gar Outpost", 'Sun Rock Retreat', 'Razor Hill', 'Bloodhoof Village', 'Durotar',
          'Mulgore', 'Tirisfal Glades'],
}
_WORD = re.compile(r"[^\W_]+(?:['\-][^\W_]+)*")
REPORT = os.path.expanduser('~/addons/_cache/dungeonquest_scan_report.txt')


def stem(word):
    """A word compared without case and without up to two German endings (the stem keeps 4 letters)."""
    w = word.casefold()
    for _ in range(2):
        for e in ENDINGS:
            if w.endswith(e) and len(w) - len(e) >= 4:
                w = w[:-len(e)]
                break
        else:
            break
    return w


def stems(text):
    """The stems of the whole words of a text (apostrophes and hyphens inside a word kept)."""
    return [stem(w) for w in _WORD.findall((text or '').replace('’', "'"))]


def name_stems(name, drop_article=True):
    """The stems of a name, a leading article dropped; () for an empty name."""
    s = stems(name)
    if drop_article:
        words = _WORD.findall((name or '').replace('’', "'"))
        if words and words[0].casefold() in ARTICLES:
            s = s[1:]
    return tuple(s)


def _rows(path):
    if not path or not os.path.exists(path):
        return []
    with open(path, encoding='utf-8-sig', newline='') as fh:
        return list(csv.DictReader(fh))


def locale_csv(dirs, table, locale):
    """The newest <table>.<build>.<locale>.csv of the first folder holding one, or None."""
    pat = re.compile(r'^' + re.escape(table) + r'\.(\d+(?:\.\d+)*)\.' + re.escape(locale) + r'\.csv$')
    for d in dirs:
        if not d or not os.path.isdir(d):
            continue
        found = sorted((tuple(int(x) for x in m.group(1).split('.')), name)
                       for name in os.listdir(d) for m in [pat.match(name)] if m)
        if found:
            return os.path.join(d, found[-1][1])
    return None


def dungeon_names(facts, client, wago=None, de_dirs=(), scans=None):
    """The names the rule looks for: {'names': [(stems, kind, frozenset(keys), name)], 'places':
    [(stems, faction, name)], 'tables': [files read]}. kind: 'dungeon' (a dungeon's or an instance's
    name: the facts' names and aliases, the client's Map and LFGDungeons names in English and German),
    'boss' (a boss's name in English, the client's DungeonEncounter name in German and the NPC scan's name
    of its NPC), 'wing' (a wing's German name, counting only beside its instance's name).
    Left out: a dungeon name that is also the name of a map outside any instance (Dalaran, the city and
    the dungeon); a boss name that starts with an article ("Die Sieben", "Das Gewölbe") and a one-word
    boss name the German client translates ("Zunder", "Plünderung": ordinary words), so a one-word
    boss name counts only where both languages write it alike (a proper name: "Onyxia", "Noxxion")."""
    import att_data
    cl = (client or {}).get('dungeons') or {}
    read = []

    def table(name, locale=None):
        path = locale_csv(de_dirs, name, locale) if locale else (att_data.wago_csv(wago, name) if wago else None)
        rows = _rows(path)
        if rows:
            read.append(os.path.basename(path))
        return rows
    map_en = {r['ID']: r for r in table('Map')}
    map_de = {r['ID']: r for r in table('Map', 'deDE')}
    lfg_en = table('LFGDungeons')
    lfg_de = {r['ID']: r.get('Name_lang') for r in table('LFGDungeons', 'deDE')}
    enc_de = {r['ID']: r.get('Name_lang') for r in table('DungeonEncounter', 'deDE')}
    area_en, area_de = table('AreaTable'), {r['ID']: r.get('AreaName_lang') for r in table('AreaTable', 'deDE')}
    cities = {name_stems(r.get('MapName_lang')) for part in (map_en, map_de) for r in part.values()
              if r.get('InstanceType') == '0' and r.get('MapName_lang')}
    lfg_by_name = {}
    for r in lfg_en:
        lfg_by_name.setdefault(r.get('Name_lang'), []).append(r['ID'])
    npc_names = {}
    for part in ((scans or {}).get('npcs') or {}).values():
        for nid, f in part.items():
            if f.get('name'):
                npc_names.setdefault(nid, f['name'])
    out = {}

    def add(name, kind, key):
        s = name_stems(name)
        if not s:
            return
        out.setdefault((s, kind), [set(), name])[0].add(key)
    for e in facts:
        key = e['key']
        c = cl.get(key) or {}
        dnames = [e.get('name'), e.get('part')] + list(e.get('aliases') or []) + list(c.get('lfg') or [])
        for lname in c.get('lfg') or []:
            dnames += [lfg_de.get(i) for i in lfg_by_name.get(lname, [])]
        inst = str(c.get('inst') or e.get('inst') or '')
        dnames += [map_en.get(inst, {}).get('MapName_lang'), map_de.get(inst, {}).get('MapName_lang')]
        for n in dnames:
            if n and name_stems(n) not in cities:
                add(n, 'dungeon', key)
        if e.get('wing'):
            add(WING_DE.get(e['wing'], e['wing']), 'wing', key)
            add(e['wing'], 'wing', key)
        order, enc, npcs = c.get('order') or [], c.get('enc') or [], c.get('npcs') or []
        for i, en in enumerate(order):
            de = [enc_de.get(str(enc[i])) if i < len(enc) else None, npc_names.get(npcs[i]) if i < len(npcs) and npcs[i] else None]
            for n in [en] + de:
                if not n:
                    continue
                words = _WORD.findall(n)
                if not words or words[0].casefold() in ARTICLES:
                    continue
                if len(words) == 1 and any(d and d != en for d in de):
                    continue
                add(n, 'boss', key)
    names = sorted(((s, kind, frozenset(keys), name) for (s, kind), (keys, name) in out.items()), key=lambda t: (t[0], t[1]))
    by_en = {}
    for r in area_en:
        by_en.setdefault(r.get('AreaName_lang'), []).append(r['ID'])
    places = {}
    for fac, lst in FACTION_PLACES.items():
        for en in lst:
            for n in [en] + [area_de.get(i) for i in by_en.get(en, [])]:
                s = name_stems(n) if n else ()
                if s:
                    places.setdefault(s, (fac, n))
    return {'names': names, 'places': sorted((s, f, n) for s, (f, n) in places.items()), 'tables': read,
            'keys': sorted(e['key'] for e in facts)}


def _hits(tokens, entries):
    """[(start, end, entry)] of every entry whose stems occur in tokens; a hit inside a longer one dropped."""
    found = []
    for ent in entries:
        s = ent[0]
        n = len(s)
        for i in range(len(tokens) - n + 1):
            if tuple(tokens[i:i + n]) == s:
                found.append((i, i + n, ent))
    return [h for h in found if not any(o is not h and o[0] <= h[0] and h[1] <= o[1] and (o[1] - o[0]) > (h[1] - h[0])
                                        for o in found)]


def scan_dungeon_of(text, names):
    """(dungeon key or None, why, the names found) of a quest text by the rule of D-109. why: 'one' (placed),
    'none' (no dungeon named), 'two' (two dungeons named), 'wing' (only an instance of several dungeons
    named, not which of them)."""
    hits = _hits(stems(text), names)
    sets = [h[2][2] for h in hits if h[2][1] != 'wing']
    found = sorted({h[2][3] for h in hits})
    multi = [s for s in sets if len(s) > 1]
    singles = {k for s in sets if len(s) == 1 for k in s}
    # a wing's name picks its wing of an instance named beside it
    for h in hits:
        if h[2][1] == 'wing':
            for k in h[2][2]:
                if any(k in m for m in multi):
                    singles.add(k)
    if len(singles) > 1:
        return None, 'two', found
    if len(singles) == 1:
        k = next(iter(singles))
        if all(k in m for m in multi):
            return k, 'one', found
        return None, 'two', found
    if multi:
        common = frozenset.intersection(*multi)
        if len(common) == 1:
            return next(iter(common)), 'one', found
        return None, ('wing' if common else 'two'), found
    return None, 'none', found


def faction_of_text(text, places):
    """'A' or 'H' when the text names towns of one faction only, else ''."""
    facs = {h[2][1] for h in _hits(stems(text), places)}
    return next(iter(facs)) if len(facs) == 1 else ''


def objective_of_scan(obj):
    """The objective of a scanned quest for field 21: the client's text without its "Anforderungen" list
    (the scan names only counts there) and without the quest log's "on this quest" line."""
    if not isinstance(obj, str):
        return None
    head = re.split(r'\s*/\s*(?:Anforderungen|Requirements):', obj, maxsplit=1)[0]
    head = re.sub(r'^\s*(?:Ihr befindet Euch auf dieser Quest\.|You are on this quest\.)\s*/\s*', '', head)
    return clean_text(head)


def place_scanned(data, scans, names, hints=None):
    """Puts the scanned dungeon and raid quests no source places into the dungeon their text names (D-109),
    in place. A quest a source knows keeps all it has and only gets its dungeon; a quest no source knows
    gets the scan's level, rewards, XP and objective, the English title of an English scan where there is
    one, no giver, no place, and the faction of the towns its text names (else both). Two quests of one
    title in one dungeon, one with a faction and the other without: the other is of the other faction.
    A hint's "dungeon" (tools/quest_hints.json, D-65) places a quest by hand ("" keeps it out).
    Returns the report {'placed': [(qid, key, title, faction, how)], 'left': [(qid, why, title, found)]}."""
    hints = hints or {}
    Q, D = data['quests'], data['dungeons']
    placed_ids = {q for ids in D.values() for q in ids}
    parts = (scans or {}).get('quests') or {}
    en = parts.get('enUS') or parts.get('enGB') or {}
    report = {'placed': [], 'left': []}
    seen = set()
    for loc in sorted(parts, key=lambda x: (x not in ('deDE',), x)):
        for qid in sorted(parts[loc]):
            f = parts[loc][qid]
            if qid in seen or f.get('tag') not in SCAN_TAGS or qid in placed_ids:
                continue
            seen.add(qid)
            title = f.get('title') or ''
            text = title + ' / ' + (f.get('obj') or '')
            hint = hints.get(qid) or {}
            if 'dungeon' in hint:
                key, why, found = (hint['dungeon'] or None), ('hint' if hint['dungeon'] else 'hint-out'), []
            else:
                key, why, found = scan_dungeon_of(text, names['names'])
            if not key or key not in (set(names.get('keys') or ()) or set(D)):
                report['left'].append((qid, why if not key else 'unknown key', title, found))
                continue
            q = Q.get(qid)
            how = 'source' if q else 'scan'
            if q is None:
                items = []
                for it in list(f.get('rewards') or []) + list(f.get('choices') or []):
                    i = it[0] if isinstance(it, (list, tuple)) else it
                    if isinstance(i, int) and i > 0 and i not in items:
                        items.append(i)
                q = {'name': (en.get(qid) or {}).get('title') or None, 'minLevel': 0, 'level': 0,
                     'faction': faction_of_text(text, names['places']), 'classes': 0, 'start': '', 'giver': None,
                     'points': [], 'preAll': [], 'preOne': [], 'alt': [], 'breadcrumb': False, 'rewards': items,
                     'startItems': [], 'startObject': None, 'races': 0, 'skill': 0, 'ender': None, 'enderPoints': [],
                     'objective': objective_of_scan(f.get('obj')), 'scanned': True}
                Q[qid] = q
            q['dungeon'] = key
            D.setdefault(key, []).append(qid)
            placed_ids.add(qid)
            report['placed'].append([qid, key, title, q.get('faction') or '', how])
    # the faction of the other one of a pair of one title in one dungeon
    titles = {}
    for loc in parts:
        for qid, f in parts[loc].items():
            titles.setdefault(qid, f.get('title'))
    for row in report['placed']:
        qid, key = row[0], row[1]
        q = Q[qid]
        if not q.get('scanned') or q.get('faction'):
            continue
        same = [o for o in D.get(key, []) if o != qid and titles.get(o) and titles.get(o) == titles.get(qid)]
        if len(same) == 1 and (Q.get(same[0]) or {}).get('faction') in ('A', 'H'):
            q['faction'] = 'H' if Q[same[0]]['faction'] == 'A' else 'A'
            row[3] = q['faction'] + ' (pair)'
    report['placed'] = [tuple(r) for r in report['placed']]
    return report


def report_text(report):
    """The report of place_scanned as text, one quest per line."""
    lines = [f'Dungeon quests of the quest scan (D-109): {len(report["placed"])} placed, {len(report["left"])} not placed.', '']
    by = {}
    for qid, key, title, fac, how in report['placed']:
        by.setdefault(key, []).append((qid, title, fac, how))
    lines.append('Placed (dungeon: quest, title, faction, record):')
    for key in sorted(by):
        lines.append(f'  {key}: {len(by[key])}')
        for qid, title, fac, how in by[key]:
            lines.append(f'    {qid} {title} [{fac or "both"}] ({how})')
    lines += ['', 'Not placed (why: none = no dungeon named, two = two dungeons named, wing = only the instance, not the wing):']
    for qid, why, title, found in report['left']:
        lines.append(f'  {qid} {why}: {title}' + (f'  (names: {", ".join(found)})' if found else ''))
    return '\n'.join(lines) + '\n'


# ---------------------------------------------------------------- hand-kept hints (D-65)
MAX_SPOTS = 8
MAX_SPOT = 300


def load_hints(path=HINTS):
    """tools/quest_hints.json: {quest id: hint}, each hint's 'spots' resolved to [(German, English)]."""
    if not path or not os.path.exists(path):
        return {}
    with open(path, encoding='utf-8') as fh:
        raw = json.load(fh)
    spots = raw.get('spots') or {}
    out = {}
    for k, h in (raw.get('q') or {}).items():
        h = dict(h)
        if h.get('spots'):
            s = spots.get(h['spots'])
            if not s:
                raise SystemExit(f'{os.path.basename(path)}: quest {k} names unknown spots {h["spots"]!r}')
            de, en = s.get('deDE') or [], s.get('enUS') or []
            if len(de) != len(en) or not de:
                raise SystemExit(f'{os.path.basename(path)}: spots {h["spots"]!r} need as many German as English lines')
            h['spots'] = [(clean_text(a, MAX_SPOT), clean_text(b, MAX_SPOT)) for a, b in zip(de, en)][:MAX_SPOTS]
        out[int(k)] = h
    return out


def apply_hints(data, hints):
    """Fills the data's gaps from the hand-kept hints, in place (before the own observations): the
    dungeon of a start item, the turn-in NPC (name and places of an NPC id of the data, or a name), the
    spots. Returns how many quests took something."""
    ctx = data.get('context') or {}
    npc_names, npc_points = ctx.get('npc_names') or {}, ctx.get('npc_points') or {}
    n = 0
    for qid, h in hints.items():
        q = data['quests'].get(qid)
        if q is None:
            continue
        before = copy.deepcopy(q)
        dun = h.get('startItemDungeon')
        if dun and q.get('startItems'):
            q['startItems'] = [tuple(e[:3]) + ((e[3] if len(e) > 3 and e[3] else dun),) for e in q['startItems']]
        ender = h.get('ender')
        if ender and not q.get('ender'):
            q['ender'] = npc_names.get(ender) or h.get('enderName')
            if not q.get('enderPoints') and npc_points.get(ender):
                q['enderPoints'] = [tuple(x) for x in npc_points[ender][:MAX_POINTS]]
        elif h.get('enderName') and not q.get('ender'):
            q['ender'] = h['enderName']
        if h.get('spots'):
            q['spots'] = list(h['spots'])
        if q != before:
            n += 1
    return n


def _spots(v):
    lua_str = build_gear.lua_str
    if not v:
        return 'nil'
    return '{ ' + ', '.join('{ ' + lua_str(a) + ', ' + lua_str(b) + ' }' for a, b in v[:MAX_SPOTS]) + ' }'


# ---------------------------------------------------------------- output
def complete(data):
    """Drops pre-quests the data has no record of and the quest itself, sorts the lists (the addon
    walks what it gets) and takes breadcrumbs out of the "all of" pre-quests (a way to the quest,
    never a must): a breadcrumb names the quests it leads to among the quests that exclude it
    (field 13: once one of them is done, the breadcrumb is no longer possible)."""
    Q = data['quests']
    for qid, q in Q.items():
        for k in ('preAll', 'preOne', 'alt'):
            q[k] = sorted({p for p in q.get(k) or [] if p in Q and p != qid})
    for qid, q in Q.items():
        crumbs = [p for p in q['preAll'] if Q[p].get('breadcrumb')]
        if crumbs:
            q['preAll'] = [p for p in q['preAll'] if p not in crumbs]
            for p in crumbs:
                if qid not in Q[p]['alt']:
                    Q[p]['alt'] = sorted(Q[p]['alt'] + [qid])
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


def kept(data):
    """The quests that go in: the dungeon quests, their pre-quests, the breadcrumbs that lead to one
    of them and their pre-quests (data after complete())."""
    Q = data['quests']
    keep = set()
    for ids in data['dungeons'].values():
        for qid in ids:
            keep.add(qid)
            keep.update(ancestors(Q, qid))
    while True:
        more = {b for b, q in Q.items() if b not in keep and q.get('breadcrumb') and keep & set(q.get('alt') or [])}
        if not more:
            return keep
        for b in more:
            keep.add(b)
            keep.update(ancestors(Q, b))


def _lua_list(v):
    return 'nil' if not v else '{ ' + ', '.join(str(int(x)) for x in v) + ' }'


def _points(v):
    return ' '.join(f'{m}:{x}:{y}' for m, x, y in (v or [])[:MAX_POINTS]) or None


def _start_items(v):
    lua_val = build_gear.lua_val
    if not v:
        return 'nil'
    rows = []
    for e in v:
        e = tuple(e) + (None,) * (4 - len(e))
        rows.append('{ ' + ', '.join([str(int(e[0])), lua_val(e[1]), lua_val(e[2]), lua_val(e[3])]) + ' }')
    return '{ ' + ', '.join(rows) + ' }'


HEADER = [
    '-- D: [dungeon key of DungeonData.lua] = its quests.',
    '-- Q: [quest id] = { [1] name (English), [2] required level, [3] quest level (0 unknown), [4] faction ("A", "H",',
    '-- "" both), [5] class mask (0 all), [6] start ("O" outside, "I" inside the dungeon, "X" by an item, "" unknown),',
    '-- [7] giver, [8] points (up to four "uiMapID:x:y", x and y in hundredths of a percent), [9] pre-quests all of,',
    '-- [10] pre-quests one of, [11] dungeon key (nil for a pre-quest only), [12] gear rewards, [13] quests that',
    '-- exclude this one (one of them done: this one is no longer possible; for a breadcrumb: the quests it leads to),',
    '-- [14] breadcrumb (true: only points to the next quest, never a must), [15] start items',
    '-- ({ { itemID, NPC name that drops it, uiMapID, dungeon key }, ... }, unknown parts nil), [16] start object',
    '-- name, [17] race mask (bit race id - 1, 0 any of the faction), [18] required profession skill line (0 none),',
    '-- [19] turn-in NPC name, [20] turn-in points (as [8]), [21] objective text (as the client showed it), [22] spots',
    '-- in the dungeon where the start item can lie ({ { German, English }, ... }, hand-kept hints, D-65), [23] XP',
    '-- the quest scan saw (at the scanning character\'s level, not known), [24] true: placed in its dungeon by',
    '-- the quest scan\'s text alone (D-109; no source knows its giver, place or English name) }.',
    '-- Names and places the Amisia collector saw itself go first (German where it saw them); nil is unknown.',
]


def render(data, built):
    lua_str, lua_val = build_gear.lua_str, build_gear.lua_val
    data = complete(copy.deepcopy(data))
    keep = kept(data)
    commit = (data.get('commit') or '')[:10]
    lines = [
        '-- GENERATED by tools/build_dungeonquests.py. Do not edit; rebuild instead.',
        f'-- Source: {data["source"]}' + (f' at {commit}' if commit else '')
        + ('; hand-kept hints (tools/quest_hints.json, D-65)' if data.get('hinted') else '')
        + ('; own observations of the Amisia collector' if data.get('observed') else '')
        + ('; levels, XP and dungeon quests of the Amisia quest scan.' if data.get('scanned') else '.'),
        'local _, ns = ...',
        '',
    ] + HEADER + [
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
        objective = clean_text(q.get('objective')) if q.get('objective') else None
        parts = [lua_str(q.get('name') or f'Quest {qid}'), str(int(q.get('minLevel') or 0)), str(int(q.get('level') or 0)),
                 lua_str(q.get('faction') or ''), str(int(q.get('classes') or 0)), lua_str(q.get('start') or ''),
                 lua_val(q.get('giver')), lua_val(_points(q.get('points'))), _lua_list(q.get('preAll')),
                 _lua_list(q.get('preOne')), lua_val(q.get('dungeon')), _lua_list(q.get('rewards')), _lua_list(q.get('alt')),
                 'true' if q.get('breadcrumb') else 'nil', _start_items(q.get('startItems')), lua_val(q.get('startObject')),
                 str(int(q.get('races') or 0)), str(int(q.get('skill') or 0)), lua_val(q.get('ender')),
                 lua_val(_points(q.get('enderPoints'))), lua_val(objective), _spots(q.get('spots')),
                 str(int(q['xp'])) if q.get('xp') else 'nil', 'true' if q.get('scanned') else 'nil']
        while parts[-1] == 'nil':
            parts.pop()
        lines.append(f'        [{qid}] = {{ {", ".join(parts)} }},')
    lines += ['    },', '}', '']
    text = '\n'.join(lines)
    if re.search(r'[\x00-\x08\x0b-\x1f\x7f]', text):
        raise SystemExit('control characters in the output')
    return text


def default_svs():
    """The SavedVariables Syncthing brings to the N100 and those of an installed Forever client."""
    return [p for p in build_gear.default_svs() if os.path.basename(p) == 'Amisia.lua']


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--att', default=None, help=f'AllTheThings download (default {ATT_CACHE} when it exists)')
    ap.add_argument('--refresh-att', action='store_true', help='download the AllTheThings Forever folder first')
    ap.add_argument('--json', default=None, help='the neutral form as JSON')
    ap.add_argument('--empty', action='store_true', help='write the file without data')
    ap.add_argument('--sv', nargs='*', help='Amisia SavedVariables with collector records (default: '
                                            '~/addons/_SavedVariables/Amisia.lua and an installed Forever client\'s)')
    ap.add_argument('--hints', default=HINTS, help='the hand-kept quest hints ("" for none)')
    ap.add_argument('--obs-archive', default=OBS_ARCHIVE, help='the archive of own quest observations ("" for none)')
    ap.add_argument('--scan-archive', default=os.path.join(HERE, 'scan_archive.json'),
                    help='the scan archive with the quest scan by id ("" for none)')
    ap.add_argument('--wago', default=None, help='folder of the client table CSVs in English (default: the chosen '
                                                 'copies, tools/client_tables.py)')
    ap.add_argument('--de-dirs', nargs='*', default=None, help='folders of the client tables in German '
                                                               '(<Table>.<build>.deDE.csv; default ~/addons/_cache/wago, ~/addons/_wago)')
    ap.add_argument('--no-place-scanned', dest='place_scanned', action='store_false',
                    help='do not place the scanned dungeon quests by their text (D-109)')
    ap.add_argument('--report', default=None,
                    help=f'the report of the scanned dungeon quests (default {REPORT} when --out is the '
                         'addon\'s file, else none; "" none)')
    ap.add_argument('--out', default=OUT)
    args = ap.parse_args(argv)
    if args.wago is None:
        import client_tables
        args.wago = client_tables.default_dir()
    if args.de_dirs is None:
        import build_dungeons
        args.de_dirs = list(build_dungeons.DE_DIRS)
    if args.report is None:
        # a build into another file (a test, a trial) must not replace the report of the real build
        args.report = REPORT if os.path.abspath(args.out) == os.path.abspath(OUT) else ''
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
    if not args.empty:
        svs = args.sv if args.sv is not None else default_svs()
        hints = load_hints(args.hints)
        # the quest scan by id (D-104): the dungeon quests no source places (D-109), then levels and XP
        import build_scan_archive
        scans = build_scan_archive.id_scans(args.scan_archive, [build_scan.load_sv(p) for p in svs])
        if args.place_scanned:
            import build_dungeons
            names = dungeon_names(facts, build_dungeons.load_client(), args.wago, args.de_dirs, scans)
            rep = place_scanned(data, scans, names, hints)
            data['placed'] = len(rep['placed']) > 0
            by = {}
            for _qid, key, *_ in rep['placed']:
                by[key] = by.get(key, 0) + 1
            why = {}
            for _qid, w, *_ in rep['left']:
                why[w] = why.get(w, 0) + 1
            log(f'quest scan: {len(rep["placed"])} dungeon quests placed by their text ('
                + (', '.join(f'{k} {n}' for k, n in sorted(by.items())) or 'none') + f'); {len(rep["left"])} not placed ('
                + (', '.join(f'{k} {n}' for k, n in sorted(why.items())) or 'none') + f'); names from {len(names["tables"])} client tables')
            if args.report:
                os.makedirs(os.path.dirname(os.path.abspath(args.report)), exist_ok=True)
                with open(args.report, 'w', encoding='utf-8', newline='\n') as fh:
                    fh.write(report_text(rep))
                log(f'  report: {args.report}')
        hinted = apply_hints(data, hints)
        data['hinted'] = hinted > 0
        if hinted:
            log(f'hints: {hinted} quests from {os.path.relpath(args.hints, ROOT)}')
        obs = read_observed([build_scan.load_sv(p) for p in svs], load_obs_archive(args.obs_archive))
        if save_obs_archive(obs, args.obs_archive):
            log(f'{os.path.relpath(args.obs_archive, ROOT)}: {len(obs)} quests observed')
        took = apply_observed(data, obs)
        data['observed'] = took > 0
        log(f'collector: {len(obs)} quests with own observations from {len(svs)} file(s) and the archive; {took} taken')
        # the quest scan by id (D-104): levels the data and the observations lack, the XP it saw
        lv = apply_scanned(data, scans)
        xp = apply_scanned_xp(data, scans)
        data['scanned'] = lv > 0 or xp > 0 or data.get('placed', False)
        log(f'quest scan: {xp} quest XP values taken')
        log(f'quest scan: {lv} quest levels taken; '
            f'{sum(1 for q in data["quests"].values() if not q.get("level"))} of {len(data["quests"])} quests still without a level')
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
