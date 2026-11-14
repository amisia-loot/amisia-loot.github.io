"""Builds Amisia_Gear/Data/ProfessionData.lua (WoW Forever): every recipe of every profession for the
addon's professions page - what it makes, its difficulty, how it is learned (trainer, with the
profession, a recipe item and where that item comes from), the reagents when the client table is
there, Forever's camp objects and Merchant's Favor. Runs without a WoW install (on the N100).

    python tools/build_professions.py [--wago DIR] [--att DIR] [--scan-archive FILE] [--sv FILE...] [--trainers FILE]
                                      [--out FILE] [--empty]

Inputs:

- Client tables (CSV, wago.tools format, `<Table>.<build>.csv`; tools/export_db2.ps1 exports them on
  the PC, Syncthing brings them to ~/addons/_wago; or wago.tools' CSV exports; the newest copy of each
  table, tools/client_tables.py): SkillLineAbility (recipe -> profession,
  difficulty), SpellEffect (the item a recipe makes, enchants, camp placement), ItemSparse,
  ItemXItemEffect and ItemEffect (recipe item -> recipe, required rank and reputation, camp objects,
  certifications, writs), SpellName and Spell (only to recognise camp objects and writs; no text
  goes into the file), SpellReagents (optional: reagents; without it the addon asks the client),
  SpellCooldowns (optional: the recipes with a cooldown, CD; without it tools/prof_cooldowns.json).
  SkillLineAbility falls back to the copy AllTheThings ships (.config/.wago).
- AllTheThings' Forever data (MIT, see tools/att_data.py and Amisia/LICENSES/):
  .config/structures/*.lua (trainer recipes per tier, the specialisations' recipes, Merchant's Favor
  recipes with price and standing per faction), profession db/*.lua (recipe item -> recipe), and the zone and dungeon files
  through att_data.load() (vendors, drops, quests of the recipe items; the favor vendors; the vendors
  of reagents and recipe items for the price list V).
- The scan archive (tools/scan_archive.json, the item collector's notes): the merchants the players
  saw selling a reagent or recipe item ("Haendler: Name [npc]"), for V beside AllTheThings, which
  lists only collectible vendor goods (no thread, dyes or vials).
- The trainers the addon read in the game (AmisiaDB.trainers, F-155, D-86), joined from the
  SavedVariables into tools/trainer_archive.json (kept for good; the addon drops a reading the data
  holds, TD): the real learn rank of each recipe a trainer teaches, the trainer (N<npc>), the
  learning cost (L).

Names are not written for recipes and items: the addon asks the client (German). Only NPC and quest
names (English, from AllTheThings' comments) go in, for sources the client cannot name.
Recipes in the Season of Discovery number range (spells 400000-999999) that AllTheThings does not
list for Forever are left out.
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
import att_data  # noqa: E402
import build_scan  # noqa: E402  (parse_note: the collector's merchant notes)
import build_scan_archive  # noqa: E402  (the scan archive: those notes for good)
import lua_data  # noqa: E402  (the lazy form of the data file)

OUT = os.path.join(ROOT, 'Amisia_Gear', 'Data', 'ProfessionData.lua')
TRAINERS = os.path.join(HERE, 'trainer_archive.json')
MAX_TRAINER_TOKENS = 3   # trainers per recipe (N), the newest readings first
WAGO = os.path.expanduser('~/addons/_wago')
ATT_CACHE = att_data.ATT_CACHE

# Skill lines in display order: the crafting professions, the secondary ones, gathering, poisons.
PROFESSIONS = [(171, 'alchemy'), (164, 'blacksmithing'), (333, 'enchanting'), (202, 'engineering'),
               (165, 'leatherworking'), (197, 'tailoring'), (185, 'cooking'), (129, 'firstaid'),
               (356, 'fishing'), (182, 'herbalism'), (186, 'mining'), (393, 'skinning'), (40, 'poisons')]
SKILL_OF = {k: s for s, k in PROFESSIONS}
# AllTheThings' constant names of the professions (structures files, favor vendors)
ATT_PROF = {'ALCHEMY': 171, 'BLACKSMITHING': 164, 'ENCHANTING': 333, 'ENGINEERING': 202,
            'LEATHERWORKING': 165, 'TAILORING': 197, 'COOKING': 185, 'FIRST_AID': 129, 'FISHING': 356,
            'HERBALISM': 182, 'MINING': 186, 'SKINNING': 393, 'POISONS': 40}
TIERS = {'APPRENTICE': 1, 'JOURNEYMAN': 2, 'EXPERT': 3, 'ARTISAN': 4}
# the structures blocks of a specialisation: only its trainer teaches them, and only to a character
# who chose it (token S, never a plain trainer recipe of the route)
SPEC_BLOCKS = {'WEAPONSMITHING', 'ARMORSMITHING', 'GNOMISH_ENGINEERING', 'GOBLIN_ENGINEERING', 'DRAGONSCALE',
               'ELEMENTAL', 'TRIBAL'}
# a spell cooldown from this long on (SpellCooldowns, milliseconds) marks a recipe that cannot be
# repeated for skill points (transmutes, Mooncloth): CD
COOLDOWN_MIN_MS = 10 * 60 * 1000
COOLDOWNS = os.path.join(HERE, 'prof_cooldowns.json')
STANDING = {'Hated': 1, 'Hostile': 2, 'Unfriendly': 3, 'Neutral': 4, 'Friendly': 5, 'Honored': 6,
            'Revered': 7, 'Exalted': 8}
FAVOR_CURRENCY = 3402
SOD_RANGE = (400000, 1000000)
EFFECT_CREATE, EFFECT_ENCHANT, EFFECT_LEARN_TRIGGER = '24', '53', '6'
CAMP_TEXT = re.compile(r'(Campfire|Cooking Fire) nearby|placement of up to', re.I)
OVER = re.compile(r'May be placed over an? ([^.]+?) to replace it', re.I)
WRIT = re.compile(r"^Craftsman's Writ: (.+)$")
CERT = re.compile(r'^(.+) Certification$')
MAX_SOURCES = 6     # sources per recipe item
SOURCE_ORDER = {'F': 0, 'V': 1, 'Q': 2, 'D': 3, 'Z': 4, 'W': 5}
MAX_VENDORS = 6     # vendors per item of the price list V
MAX_REAGENT_SOURCES = 6   # sources per reagent in RS (besides V and the recipes that make it)
MAX_GATHER_MAPS = 8       # zones of a gathered reagent in RS
GATHER_SKILL = {'herbalism': 182, 'mining': 186, 'skinning': 393, 'fishing': 356}


def log(*a):
    print(*a, file=sys.stderr)


def _int(v, default=0):
    try:
        return int(float(v))
    except (TypeError, ValueError):
        return default


def _rows(table, dirs):
    return list(att_data.wago_rows(table, *[d for d in dirs if d]))


def _build_of(dirs):
    for d in dirs:
        path = att_data.wago_csv(d, 'ItemSparse') if d else None
        if path:
            m = re.search(r'\.(\d+(?:\.\d+)+)\.csv$', path)
            return m.group(1) if m else ''
    return ''


# ---------------------------------------------------------------- client tables
def read_client(*dirs, att=None):
    """The client tables of the first folder that has each (the user's export first). att: an
    AllTheThings download whose .config/.wago copy of SkillLineAbility serves when no folder has
    one. Returns the parts combine() needs."""
    dirs = [d for d in dirs if d]
    sla_dirs = dirs + ([os.path.join(att, '.config', '.wago')] if att else [])
    out = {'client': _build_of(dirs), 'sla': {}, 'create': {}, 'enchant': set(), 'teach': {}, 'use': {},
           'items': {}, 'names': {}, 'desc': {}, 'reagents': {}, 'spellEffects': {}, 'reagentTable': False,
           'cooldowns': set(), 'cooldownTable': False}
    for r in _rows('SkillLineAbility', sla_dirs):
        sl, sp = _int(r.get('SkillLine')), _int(r.get('Spell'))
        if sl and sp and (sl, sp) not in out['sla']:
            out['sla'][(sl, sp)] = {'min': _int(r.get('MinSkillLineRank'), 1), 'acquire': _int(r.get('AcquireMethod')),
                                    'yellow': _int(r.get('TrivialSkillLineRankLow')),
                                    'grey': _int(r.get('TrivialSkillLineRankHigh'))}
    for r in _rows('SpellEffect', dirs):
        sp, eff = _int(r.get('SpellID')), str(r.get('Effect') or '')
        out['spellEffects'].setdefault(sp, []).append(r)
        if eff == EFFECT_CREATE and _int(r.get('EffectItemType')) and sp not in out['create']:
            out['create'][sp] = (_int(r.get('EffectItemType')), max(1, _int(r.get('EffectBasePointsF'))))
        elif eff == EFFECT_ENCHANT:
            out['enchant'].add(sp)
    effects = {r['ID']: r for r in _rows('ItemEffect', dirs)}
    for r in _rows('ItemXItemEffect', dirs):
        e = effects.get(r.get('ItemEffectID'))
        if not e:
            continue
        item, sp = _int(r.get('ItemID')), _int(e.get('SpellID'))
        if str(e.get('TriggerType')) == EFFECT_LEARN_TRIGGER:
            out['teach'].setdefault(item, sp)
        elif str(e.get('TriggerType')) == '0':
            out['use'].setdefault(item, sp)
    for r in _rows('ItemSparse', dirs):
        out['items'].setdefault(_int(r.get('ID')), {'name': r.get('Display_lang') or '', 'skill': _int(r.get('RequiredSkill')),
                                           'rank': _int(r.get('RequiredSkillRank')), 'faction': _int(r.get('MinFactionID')),
                                           'standing': _int(r.get('MinReputation')),
                                           # BuyPrice is what VendorStackCount of it cost at a vendor
                                           'buy': _int(r.get('BuyPrice')), 'stack': _int(r.get('VendorStackCount'), 1),
                                           # what a vendor pays for one (the route's estimate, S)
                                           'sell': _int(r.get('SellPrice'))})
    for r in _rows('SpellName', dirs):
        out['names'].setdefault(_int(r.get('ID')), r.get('Name_lang') or '')
    for r in _rows('Spell', dirs):
        out['desc'].setdefault(_int(r.get('ID')), r.get('Description_lang') or '')
    for r in _rows('SpellReagents', dirs):
        out['reagentTable'] = True
        sp, got = _int(r.get('SpellID')), []
        for i in range(8):
            item, n = _int(r.get(f'Reagent_{i}')), _int(r.get(f'ReagentCount_{i}'))
            if item > 0 and n > 0:
                got.append((item, n))
        if sp and got and sp not in out['reagents']:
            out['reagents'][sp] = got
    for r in _rows('SpellCooldowns', dirs):
        out['cooldownTable'] = True
        if max(_int(r.get('RecoveryTime')), _int(r.get('CategoryRecoveryTime'))) >= COOLDOWN_MIN_MS:
            out['cooldowns'].add(_int(r.get('SpellID')))
    return out


def read_cooldown_file(path=COOLDOWNS):
    """The hand-kept recipe spells with a cooldown (tools/prof_cooldowns.json, "spells"): the fallback
    while the client table SpellCooldowns is not exported."""
    if not path or not os.path.exists(path):
        return set()
    with open(path, encoding='utf-8') as fh:
        return {int(x) for x in json.load(fh).get('spells', [])}


# ---------------------------------------------------------------- AllTheThings
_STRUCT_BLOCK = re.compile(r'^\t([A-Z_]+)\s*=')
_RECIPE = re.compile(r'\br\((\d+)')
_ITEM = re.compile(r'\bi\((\d+)')
_COST = re.compile(r'MERCHANTS_FAVOR\s*,\s*(\d+)')
_STANDING = re.compile(r'\{\s*--\s*([A-Z][a-z]+)\s*$')
_PROFDB = re.compile(r'\bi\((\d+),\s*(\d+)\)')
_FAVOR_VENDOR = re.compile(r'\bn\((\d+),\s*\{[^\n]*\n(?:(?!\bn\(\d)[^\n]*\n){0,8}?[^\n]*?\b([A-Z_]+)_RECIPES\.MERCHANTS_FAVOR_RECIPES_(HORDE|ALLIANCE)')


def _read(path):
    with open(path, encoding='utf-8-sig') as fh:
        return att_data.preprocess(fh.read())


def read_structures(base):
    """(trainer {spell: tier 0-4}, favor {item: [(price, standing, 'A'|'H')]}, spec {spell}) from the
    structures files: the trainer lists by tier (other lists, as the master trainers' Shadoweave or
    First Aid's apprentice-journeyman list, tier 0), a specialisation's list (SPEC_BLOCKS) as spec,
    the Merchant's Favor lists by faction and standing. A recipe removed before Forever and the
    profession rank spells (with a "rank" field) are left out."""
    trainer, favor, spec = {}, {}, set()
    folder = os.path.join(base, '.config', 'structures')
    if not os.path.isdir(folder):
        return trainer, favor, spec
    for name in sorted(os.listdir(folder)):
        if not name.endswith('.lua'):
            continue
        block, fac, standing, item, rank_open = None, None, 4, None, None
        for line in _read(os.path.join(folder, name)).split('\n'):
            m = _STRUCT_BLOCK.match(line)
            if m:
                block = m.group(1)
                fac = 'H' if block.endswith('_HORDE') else 'A' if block.endswith('_ALLIANCE') else None
                standing, item, rank_open = 4, None, None
            if block is None:
                continue
            if fac:
                s = _STANDING.search(line)
                if s and s.group(1) in STANDING:
                    standing = STANDING[s.group(1)]
                i = _ITEM.search(line)
                if i:
                    item = int(i.group(1))
                c = _COST.search(line)
                if c and item:
                    entry = (int(c.group(1)), standing, fac)
                    if entry not in favor.setdefault(item, []):
                        favor[item].append(entry)
                continue
            r = _RECIPE.search(line)
            if r:
                spell = int(r.group(1))
                if 'REMOVED' in line or 'DELETED' in line:
                    continue
                # a table opened on this line and not closed: its fields follow ("rank" marks the
                # profession's rank spell)
                code = line.split('--', 1)[0]
                rank_open = spell if '{' in code and '}' not in code else None
                if block in SPEC_BLOCKS:
                    spec.add(spell)
                else:
                    trainer.setdefault(spell, TIERS.get(block, 0))
            elif rank_open and '["rank"]' in line:
                trainer.pop(rank_open, None)
                spec.discard(rank_open)
                rank_open = None
    return trainer, favor, spec


def read_profession_db(base):
    """{recipe item: spell} of the profession db files (item 0 is a trainer line)."""
    out = {}
    folder = os.path.join(base, 'profession db')
    if not os.path.isdir(folder):
        return out
    for name in sorted(os.listdir(folder)):
        if name.endswith('.lua'):
            for a, b in _PROFDB.findall(_read(os.path.join(folder, name))):
                if int(a) > 0:
                    out.setdefault(int(a), int(b))
    return out


def read_favor_vendors(base):
    """{'A': [npc], 'H': [npc]}: the NPCs whose goods are a Merchant's Favor list."""
    out = {'A': set(), 'H': set()}
    for path in att_data.data_files(base):
        src = _read(path)
        if 'MERCHANTS_FAVOR_RECIPES_' not in src:
            continue
        for npc, _, fac in _FAVOR_VENDOR.findall(src):
            out['A' if fac == 'ALLIANCE' else 'H'].add(int(npc))
    return {k: sorted(v) for k, v in out.items()}


def read_att(base, db=None):
    """The parts of an AllTheThings download the professions need. db: att_data.load()'s result
    (read when not given)."""
    if not base or not os.path.isdir(base):
        return empty_att()
    if db is None:
        db = att_data.load(base, items=False)
    trainer, favor, spec = read_structures(base)
    sources = {}

    def add(item, token):
        lst = sources.setdefault(item, [])
        if token not in lst:
            lst.append(token)
    other_cost = db.get('sold_cost') or {}
    sold = {}
    for item, vendor, _old in db['sold']:
        add(item, f'V{vendor}')
        # the price list: only what the vendor sells for gold (not for another currency or items)
        if other_cost.get((item, vendor)) != 'x' and vendor not in sold.setdefault(item, []):
            sold[item].append(vendor)
    for qid, q in sorted(db['quests'].items()):
        for item in q['rewards']:
            add(item, f'Q{qid}')
    for item, npc, _kind, _inst, zone, _old, _boss in db['drops']:
        add(item, f'D{npc}' if npc else (f'Z{zone}' if zone else 'W'))
    for item, crs, _inst, zone, _old in db['zone_drops']:
        if crs:
            for c in crs[:3]:
                add(item, f'D{c}')
        else:
            add(item, f'Z{zone}' if zone else 'W')
    for item in db['world']:
        add(item, 'W')
    npcs = {}
    for nid, n in db['npcs'].items():
        pt = n['points'][0] if n['points'] else None
        npcs[nid] = (n['name'] or '', f'{pt[0]}:{pt[1]}:{pt[2]}' if pt else (str(n['zone']) if n.get('zone') else ''),
                     n['faction'] or '')
    quests = {qid: q['name'] or '' for qid, q in db['quests'].items()}
    # the trainers: the NPCs the zone files list under a profession in the header PROFESSIONS, with a
    # place ({skill line: [npc ids]})
    trainers = {}
    for nid, n in sorted(db['npcs'].items()):
        if not n['points']:
            continue
        for p in sorted(n.get('profs') or ()):
            sl = ATT_PROF.get(p)
            if sl:
                trainers.setdefault(sl, []).append(nid)
    return {'commit': db.get('commit'), 'trainer': trainer, 'spec': spec, 'favor': favor, 'trainers': trainers,
            'profdb': read_profession_db(base),
            'vendors': read_favor_vendors(base), 'sources': sources, 'npcs': npcs, 'quests': quests, 'sold': sold,
            'gathered': db.get('gathered') or {}}


def empty_att():
    return {'commit': None, 'trainer': {}, 'spec': set(), 'favor': {}, 'trainers': {}, 'profdb': {}, 'vendors': {'A': [], 'H': []}, 'sources': {},
            'npcs': {}, 'quests': {}, 'sold': {}, 'gathered': {}}


def read_seen_vendors(path):
    """{item: [npc]}: the merchants the item collector saw selling the item (the scan archive's
    "Haendler: Name [npc] @place" notes; a note without an NPC id is left out)."""
    out = {}
    for item, notes in build_scan_archive.load(path).get('sources', {}).items():
        for text in notes:
            n = build_scan.parse_note(text)
            if n and n['kind'] == 'vendor' and n['id'] and n['id'] not in out.setdefault(item, []):
                out[item].append(n['id'])
    return {k: v for k, v in out.items() if v}


# ---------------------------------------------------------------- combining
def _source_key(t):
    return (SOURCE_ORDER.get(t[0], 9), t)


def unit_price(buy, stack):
    """The copper one item costs at a vendor: BuyPrice is for VendorStackCount of it; rounded up, at
    least 1. 0 when the client names no price (sold for something else)."""
    if buy <= 0:
        return 0
    return max(1, -(-buy // max(1, stack)))


def pick_vendors(ids, npcs, limit=MAX_VENDORS):
    """At most limit of the vendor ids that have a record in npcs ({npc: (name, where, faction)}):
    the ones with a known position first, taken in turn from both factions and the neutral ones so
    that each side keeps its vendors; in that order (position first, then the id)."""
    def key(n):
        return (0 if ':' in npcs[n][1] else 1, n)
    known = sorted({n for n in ids if n in npcs}, key=key)
    out = []
    for placed in (True, False):
        groups = [[n for n in known if (':' in npcs[n][1]) == placed and (npcs[n][2] or '') == f] for f in ('', 'A', 'H')]
        while len(out) < limit and any(groups):
            for g in groups:
                if g and len(out) < limit:
                    out.append(g.pop(0))
    return sorted(out, key=key)


def vendor_prices(client, att, seen, items):
    """V: {item: "copper:npc,..."} of the items (reagents and recipe items) a vendor sells for gold
    (AllTheThings' vendors, the collector's merchants; the Merchant's Favor vendors never) with a
    client price. The npcs are those pick_vendors keeps (they go into N); an item whose vendors no
    record names keeps its price with an empty list."""
    favor = set(att['vendors'].get('A', [])) | set(att['vendors'].get('H', []))
    V = {}
    for item in sorted(items):
        ids = [n for n in list(att['sold'].get(item, [])) + list(seen.get(item, [])) if n not in favor]
        if not ids:
            continue
        it = client['items'].get(item, {})
        price = unit_price(it.get('buy', 0), it.get('stack', 1))
        if not price:
            continue
        V[item] = (price, pick_vendors(ids, att['npcs']))
    return V


# ---------------------------------------------------------------- trainers read in the game (F-155)
def trainers_from_sv(db):
    """{npc: {'t', 'n', 'p', 's': {spell: (rank, cost, level)}}} of a SavedVariables' AmisiaDB.trainers,
    checked as the addon checks it (ns.TrainersLoaded)."""
    out = {}
    tr = db.get('trainers') if isinstance(db, dict) else None
    if not isinstance(tr, dict):
        return out
    def whole(v, lo, hi):
        return isinstance(v, int) and not isinstance(v, bool) and lo <= v <= hi
    for npc, e in tr.items():
        if not whole(npc, 1, 9999999) or not isinstance(e, dict) or not whole(e.get('t'), 1, 4 * 10**9):
            continue
        offers = {}
        for sp, v in (e.get('s') or {}).items() if isinstance(e.get('s'), dict) else ():
            m = re.match(r'^(\d+):(\d+):(\d+)$', v) if isinstance(v, str) else None
            if whole(sp, 1, 99999999) and m:
                offers[sp] = tuple(int(x) for x in m.groups())
        if not offers:
            continue
        name = e.get('n') if isinstance(e.get('n'), str) and '|' not in e['n'] else ''
        pos = e.get('p') if isinstance(e.get('p'), str) and re.match(r'^\d+:\d+:\d+$', e['p']) else ''
        out[npc] = {'t': e['t'], 'n': name[:60], 'p': pos, 's': offers}
    return out


def load_trainer_archive(path=TRAINERS):
    """{'updated', 'trainers': {npc: {'t', 'n', 'p', 's': {spell: (rank, cost, level)}}}}"""
    if not os.path.exists(path):
        return {'updated': None, 'trainers': {}}
    with open(path, encoding='utf-8') as fh:
        raw = json.load(fh)
    out = {}
    for k, e in (raw.get('trainers') or {}).items():
        out[int(k)] = {'t': e['t'], 'n': e.get('n', ''), 'p': e.get('p', ''),
                       's': {int(sp): tuple(int(x) for x in v.split(':')) for sp, v in e.get('s', {}).items()}}
    return {'updated': raw.get('updated'), 'trainers': out}


def join_trainers(arch, read):
    """Joins readings into the archive: a newer reading of a trainer replaces the older, nothing is
    dropped. Returns how many changed."""
    n = 0
    for npc, e in sorted(read.items()):
        have = arch['trainers'].get(npc)
        if (have is None or e['t'] > have['t']) and have != e:
            arch['trainers'][npc] = e
            n += 1
    return n


def _trainer_text(arch):
    tr = {str(npc): {'t': e['t'], 'n': e['n'], 'p': e['p'],
                     's': {str(sp): ':'.join(str(x) for x in v) for sp, v in sorted(e['s'].items())}}
          for npc, e in sorted(arch['trainers'].items())}
    return json.dumps({'updated': arch.get('updated'), 'trainers': tr}, ensure_ascii=False, indent=1) + '\n'


def save_trainer_archive(arch, path=TRAINERS, today=None):
    """Writes the archive when its trainers changed (then with today's date). True when it wrote."""
    old = load_trainer_archive(path)
    if old['trainers'] == arch['trainers'] and os.path.exists(path):
        return False
    arch['updated'] = today or time.strftime('%Y-%m-%d')
    with open(path, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(_trainer_text(arch))
    return True


def update_trainers(svs, path=TRAINERS):
    """Joins the SavedVariables' trainer readings into the archive; returns its trainers."""
    arch = load_trainer_archive(path)
    for p in svs:
        n = join_trainers(arch, trainers_from_sv(build_scan.load_sv(p)))
        log(f'{p}: {n} trainers read new or newer')
    if save_trainer_archive(arch, path):
        log(f'{os.path.relpath(path, ROOT)}: {len(arch["trainers"])} trainers')
    return arch['trainers']


def trainer_offers(trainers):
    """{spell: {'rank', 'cost', 'npcs'}}: the newest reading's rank and cost, and up to
    MAX_TRAINER_TOKENS trainers that teach it (newest first)."""
    by = {}
    for npc, e in trainers.items():
        for sp, (rank, cost, _level) in e['s'].items():
            by.setdefault(sp, []).append((e['t'], npc, rank, cost))
    out = {}
    for sp, lst in by.items():
        lst.sort(key=lambda x: (-x[0], x[1]))
        out[sp] = {'rank': lst[0][2], 'cost': lst[0][3], 'npcs': [x[1] for x in lst[:MAX_TRAINER_TOKENS]]}
    return out


def combine(client, att, seen=None, cooldowns=None, trainers=None):
    """The neutral form render() writes: P, R, I, G, V, S, CD, N, Q, TR, CAMP, FAVOR, L, TD, client,
    source, report. seen: read_seen_vendors()'s merchants (none when not given); cooldowns: the
    hand-kept cooldown recipes (read_cooldown_file()), used only without the client table
    SpellCooldowns; trainers: the trainer archive's readings (load_trainer_archive()['trainers'])."""
    trained = trainer_offers(trainers or {})
    with_trainer = set()      # the recipes that got their trainer (N): their costs go into L
    teach = dict(att['profdb'])
    teach.update(client['teach'])          # the client's own link wins
    spec = att.get('spec') or set()
    att_spells = set(att['trainer']) | spec | set(att['profdb'].values())
    for item in att['favor']:
        if item in teach:
            att_spells.add(teach[item])
    by_spell_items = {}
    for item, sp in teach.items():
        by_spell_items.setdefault(sp, []).append(item)
    report = {'sod dropped': 0, 'reagents': 'table' if client['reagentTable'] else 'client', 'recipes': {}}
    recipes, used_items, dropped = {}, set(), set()
    for (sl, sp), a in sorted(client['sla'].items()):
        if sl not in dict(PROFESSIONS):
            continue
        create = client['create'].get(sp)
        is_enchant = sp in client['enchant']
        taught = sorted(by_spell_items.get(sp, []))
        if not create and not is_enchant and not taught:
            continue                      # a rank spell, a specialisation or a passive: no recipe
        if SOD_RANGE[0] <= sp < SOD_RANGE[1] and sp not in att_spells:
            report['sod dropped'] += 1
            dropped.add(sp)
            continue
        src = []
        if a['acquire'] == 1:
            src.append('A')
        elif sp in att['trainer']:
            src.append(f'T{att["trainer"][sp]}')
        elif sp in spec:
            src.append('S')
        ranks = []
        for item in taught:
            src.append(f'I{item}')
            used_items.add(item)
            r = client['items'].get(item, {}).get('rank', 0)
            if r:
                ranks.append(r)
        learn = min(ranks) if ranks else max(1, a['min'])
        # a trainer read in the game: its rank is the game's own (with a recipe item, the earlier)
        offer = trained.get(sp)
        if offer and a['acquire'] != 1:
            rank = max(1, offer['rank'])
            learn = min(ranks + [rank]) if ranks else rank
            src += [f'N{n}' for n in offer['npcs']]
            with_trainer.add(sp)
            report['trainer recipes'] = report.get('trainer recipes', 0) + 1
        item, count = create if create else (0, 0)
        line = f'{sp}:{item}:{count}:{learn}:{a["yellow"]}:{a["grey"]}:{",".join(src)}'
        recipes.setdefault(sl, []).append((a['yellow'], a['grey'], sp, line))
    R = {}
    for sl, lst in recipes.items():
        R[sl] = [x[3] for x in sorted(lst)]
        report['recipes'][sl] = len(lst)
    P = [(sl, key) for sl, key in PROFESSIONS if sl in R]

    # recipe items: the recipe, the required rank and reputation, the sources
    I, npcs_used, quests_used = {}, set(), set()
    favor_items = set(att['favor'])
    for item in sorted(used_items | (favor_items & set(teach))):
        sp = teach.get(item)
        if sp in dropped:
            continue
        it = client['items'].get(item, {})
        toks = [f'F{p}@{s}{f}' for p, s, f in att['favor'].get(item, [])]
        rest = sorted(att['sources'].get(item, []), key=_source_key)
        toks += rest
        toks = toks[:MAX_SOURCES]
        for t in toks:
            if t[0] in 'VD':
                npcs_used.add(int(t[1:]))
            elif t[0] == 'Q':
                quests_used.add(int(t[1:]))
        I[item] = f'{sp}:{it.get("rank", 0)}:{it.get("faction", 0)}:{it.get("standing", 0)}:{",".join(toks)}'
    for fac in ('A', 'H'):
        npcs_used.update(att['vendors'].get(fac, []))

    G = {}
    if client['reagentTable']:
        listed = {int(l.split(':')[0]) for lst in R.values() for l in lst}
        for sp in sorted(listed):
            if sp in client['reagents']:
                G[sp] = ','.join(f'{i}:{n}' for i, n in client['reagents'][sp])

    # the price list: the reagents and the recipe items vendors sell
    reagents = {i for sp in G for i, _ in client['reagents'][sp]}
    prices = vendor_prices(client, att, seen or {}, reagents | set(I))
    V = {}
    for item, (price, npcs) in prices.items():
        npcs_used.update(npcs)
        V[item] = f'{price}:{",".join(str(n) for n in npcs)}'
    report['prices'] = {'items': len(V), 'recipe items': len(set(V) & set(I)), 'reagents': len(set(V) & reagents)}
    # where a reagent comes from besides vendors (V) and recipes (R): gathered (H<skill line>@<uiMapID>.<uiMapID>),
    # dropped (D<npc> in N, Z<uiMapID>, W), a quest reward (Q<quest>)
    RS = {}
    for item in sorted(reagents):
        toks = []
        g = (att.get('gathered') or {}).get(item)
        if g and GATHER_SKILL.get(g['skill']):
            maps = [m for m in g['maps'] if isinstance(m, int) and m > 0][:MAX_GATHER_MAPS]
            toks.append(f'H{GATHER_SKILL[g["skill"]]}' + ('@' + '.'.join(str(m) for m in maps) if maps else ''))
        rest = [t for t in sorted(att['sources'].get(item, []), key=_source_key) if t[0] in 'DZWQ']
        toks += rest[:MAX_REAGENT_SOURCES - len(toks)]
        for t in toks:
            if t[0] == 'D':
                npcs_used.add(int(t[1:]))
            elif t[0] == 'Q':
                quests_used.add(int(t[1:]))
        if toks:
            RS[item] = ','.join(toks)
    report['reagent sources'] = {'reagents': len(reagents), 'with a source': len(RS),
                                 'gathered': sum(1 for v in RS.values() if v.startswith('H')),
                                 'without any': len(reagents - set(RS) - set(V) - made_items(R))}
    # the route's estimate for a reagent no vendor sells: what a vendor pays for one
    S = {}
    for item in sorted(reagents - set(V)):
        sell = client['items'].get(item, {}).get('sell', 0)
        if sell > 0:
            S[item] = sell
    # the recipes with a cooldown: the client's table, else the hand-kept list
    listed = {int(l.split(':')[0]) for lst in R.values() for l in lst}
    cd_all = client['cooldowns'] if client['cooldownTable'] else set(cooldowns or ())
    CD = sorted(cd_all & listed)
    report['cooldowns'] = {'from': 'table' if client['cooldownTable'] else 'file', 'recipes': len(CD)}
    # the trainers of each skill line of P (their NPCs go into N)
    TR = {}
    for sl, _key in P:
        ids = sorted(set((att.get('trainers') or {}).get(sl, [])))
        if ids:
            TR[sl] = ids
            npcs_used.update(ids)
    # the trainers read in the game: their recipes' learning costs (L), each trainer in N, what the
    # data holds (TD: the reading's time, the addon drops that reading)
    listed = {int(l.split(':')[0]) for lst in R.values() for l in lst}
    L = {sp: o['cost'] for sp, o in sorted(trained.items()) if sp in with_trainer and o['cost'] > 0}
    TD = {}
    for nid, e in sorted((trainers or {}).items()):
        TD[nid] = e['t']
        if any(sp in listed for sp in e['s']):
            npcs_used.add(nid)
    report['trainers'] = {'read': len(TD), 'recipes': report.get('trainer recipes', 0),
                          'offers not in the data': len(set(trained) - listed)}
    N = {}
    for nid in sorted(npcs_used):
        name, where, fac = att['npcs'].get(nid, ('', '', ''))
        e = (trainers or {}).get(nid)
        if e and not name:
            name = e.get('n') or ''
        if e and not re.match(r'^\d+:\d+:\d+$', where or '') and e.get('p'):
            where = e['p']
        N[nid] = f'{name}|{where}|{fac}'
    Q = {qid: att['quests'].get(qid, '') for qid in sorted(quests_used)}

    return {'P': P, 'R': R, 'I': I, 'G': G, 'V': V, 'RS': RS, 'S': S, 'CD': CD, 'N': N, 'Q': Q, 'TR': TR, 'CAMP': camp_objects(client),
            'FAVOR': favor_info(client, att, R), 'L': L, 'TD': TD, 'client': client['client'],
            'source': (att.get('commit') or '')[:10], 'report': report}


def made_items(R):
    """The items the recipes of R make."""
    return {int(l.split(':')[1]) for lst in R.values() for l in lst if int(l.split(':')[1]) > 0}


def camp_objects(client):
    """The camp objects: items whose use spell places something that needs a campfire nearby, or a
    campfire with places for others. Each "item:skillLine:rank:useSpell:recipeSpell:slots:overItem";
    campfires first, then by profession and rank."""
    made_by = {}
    for (sl, sp), _ in client['sla'].items():
        c = client['create'].get(sp)
        if c:
            made_by.setdefault(c[0], sp)
    camp = {}
    for item, use in client['use'].items():
        text = client['desc'].get(use, '')
        if not CAMP_TEXT.search(text):
            continue
        it = client['items'].get(item, {})
        if it.get('skill', 0) not in dict(PROFESSIONS) and 'placement of up to' not in text:
            continue                      # a banner or toy that needs a campfire, no profession's
        slots = 0
        if 'placement of up to' in text:
            for e in client['spellEffects'].get(use, []):
                if str(e.get('Effect')) == '50' and str(e.get('EffectIndex')) == '0':
                    slots = _int(e.get('EffectBasePointsF'))
        camp[item] = {'skill': it.get('skill', 0), 'rank': it.get('rank', 0), 'use': use,
                      'recipe': made_by.get(item, 0), 'slots': slots, 'text': text, 'name': it.get('name', '')}
    by_name = {c['name'].lower(): item for item, c in camp.items()}
    order = [s for s, _ in PROFESSIONS]
    out = []
    for item, c in camp.items():
        m = OVER.search(c['text'])
        over = by_name.get(m.group(1).strip().lower(), 0) if m else 0
        # campfires first (by rank), then by profession in display order, then rank
        prof = 0 if c['slots'] else (order.index(c['skill']) if c['skill'] in order else 99)
        out.append(((0 if c['slots'] else 1, prof, c['rank'], item),
                    f'{item}:{c["skill"]}:{c["rank"]}:{c["use"]}:{c["recipe"]}:{c["slots"]}:{over}'))
    return [x[1] for x in sorted(out)]


def favor_info(client, att, R):
    made = {}
    for lst in R.values():
        for line in lst:
            item = int(line.split(':')[1])
            if item:
                made.setdefault(item, True)
    by_name = {}
    for iid, it in client['items'].items():
        if iid in made:
            by_name.setdefault(it['name'].lower(), iid)
    writ, cert = {}, {}
    for iid, it in sorted(client['items'].items()):
        m = WRIT.match(it['name'])
        if m:
            target = by_name.get(m.group(1).strip().lower())
            if target:
                writ.setdefault(target, iid)
        m = CERT.match(it['name'])
        if m and it.get('skill') in dict(PROFESSIONS):
            cert.setdefault(it['skill'], iid)
    return {'currency': FAVOR_CURRENCY, 'cert': cert, 'writ': writ, 'vendor': att['vendors']}


def empty():
    return {'P': [], 'R': {}, 'I': {}, 'G': {}, 'V': {}, 'RS': {}, 'S': {}, 'CD': [], 'N': {}, 'Q': {}, 'TR': {}, 'CAMP': [],
            'FAVOR': {'currency': FAVOR_CURRENCY, 'cert': {}, 'writ': {}, 'vendor': {'A': [], 'H': []}},
            'L': {}, 'TD': {}, 'client': '', 'source': '', 'report': {}}


# ---------------------------------------------------------------- writing
def lua_str(s):
    s = str(s)
    out = []
    for ch in s:
        if ch == '\\':
            out.append('\\\\')
        elif ch == '"':
            out.append('\\"')
        elif ord(ch) < 32 or ord(ch) == 127:
            out.append('\\%03d' % ord(ch))
        else:
            out.append(ch)
    return '"' + ''.join(out) + '"'


def _num_map(d, per_line=8, indent=4):
    parts = [f'[{k}] = {v}' for k, v in sorted(d.items())]
    rows = [', '.join(parts[i:i + per_line]) for i in range(0, len(parts), per_line)]
    pad = ' ' * indent
    return '{\n' + ''.join(f'{pad}    {r},\n' for r in rows) + pad + '}' if rows else '{}'


def _str_map(d, per_line=4):
    parts = [f'[{k}] = {lua_str(v)}' for k, v in sorted(d.items())]
    rows = [', '.join(parts[i:i + per_line]) for i in range(0, len(parts), per_line)]
    return '{\n' + ''.join(f'        {r},\n' for r in rows) + '    }' if rows else '{}'


def _str_list(lst, indent, per_line=4):
    rows = [', '.join(lua_str(x) for x in lst[i:i + per_line]) for i in range(0, len(lst), per_line)]
    pad = ' ' * indent
    return '{\n' + ''.join(f'{pad}    {r},\n' for r in rows) + pad + '}' if rows else '{}'


def render(data, built):
    out = ['-- GENERATED by tools/build_professions.py. Do not edit; rebuild instead.',
           f'-- Sources: the WoW Forever client tables ({data.get("client") or "none"}) and AllTheThings Forever data',
           f'-- ({att_data.ATT_LICENSE}; see LICENSES/) at {data.get("source") or "none"}.',
           'local _, ns = ...',
           '',
           '-- P: { skill line, key } in display order. R: [skill line] = recipes',
           '-- "spell:item:count:learn:yellow:grey:src" (item 0: an enchant or other spell; src: A learned with',
           '-- the profession, T1-T4 trainer tier, T0 trainer without tier, S a specialisation\'s trainer, I<item>',
           '-- recipe item, N<npc> a trainer read in the game (then learn is that trainer\'s rank), empty unknown).',
           '-- I: [recipe item] = "spell:rank:faction:standing:sources" (F<price>@<standing><A|H> Merchant\'s Favor,',
           '-- V<npc> vendor, Q<quest> quest, D<npc> drop, Z<uiMapID> zone drop, W world drop). G: [spell] =',
           '-- "item:n,..." reagents (only with the SpellReagents table). V: [item] = "copper:npc,..." a reagent or',
           '-- recipe item a vendor sells for gold: the price of one (BuyPrice / VendorStackCount, rounded up) and up',
           '-- to 6 vendors (known position first, both factions), each in N; an item without a vendor is not in V.',
           '-- RS: [reagent] = where it comes from besides V and the recipes: H<skill line>@<uiMapID>.<uiMapID> gathered',
           '-- (herbalism, mining, skinning, fishing; the zones), D<npc> drop (in N), Z<uiMapID> zone drop, W world drop,',
           '-- Q<quest> quest reward.',
           '-- S: [item] = copper a vendor pays for one (SellPrice) of a reagent not in V (the route\'s estimate).',
           '-- CD: [spell] = 1 a recipe with a cooldown (SpellCooldowns, else tools/prof_cooldowns.json): no route step.',
           '-- N: [npc] = "Name|uiMapID:x:y|A/H/" (English).',
           '-- Q: [quest] = English name. CAMP: "item:skillLine:rank:useSpell:recipeSpell:slots:overItem".',
           '-- TR: [skill line] = { npc, ... } the trainers with a place (AllTheThings\' zone files), each in N.',
           '-- L: [spell] = copper a trainer read in the game asks. TD: [npc] = the time of its reading the data holds.',
           'ns.PROFESSIONS = {',
           f'    built = {lua_str(built)}, client = {lua_str(data.get("client") or "")}, source = {lua_str(data.get("source") or "")},',
           '    P = { ' + ', '.join(f'{{ {s}, {lua_str(k)} }}' for s, k in data['P']) + ' },',
           '    R = {']
    for sl, _ in data['P']:
        out.append(f'        [{sl}] = ' + _str_list(data['R'][sl], 8) + ',')
    out.append('    },')
    out.append('    I = ' + _str_map(data['I']) + ',')
    out.append('    G = ' + _str_map(data['G']) + ',')
    out.append('    V = ' + _str_map(data['V']) + ',')
    out.append('    RS = ' + _str_map(data.get('RS') or {}) + ',')
    out.append('    S = ' + _num_map(data['S'], per_line=10) + ',')
    out.append('    CD = ' + _num_map({sp: 1 for sp in data['CD']}, per_line=10) + ',')
    out.append('    N = ' + _str_map(data['N'], 3) + ',')
    out.append('    Q = ' + _str_map(data['Q'], 3) + ',')
    out.append('    TR = ' + _num_map({sl: '{ ' + ', '.join(str(n) for n in ids) + ' }' for sl, ids in (data.get('TR') or {}).items()},
                                  per_line=1) + ',')
    out.append('    CAMP = ' + _str_list(data['CAMP'], 4) + ',')
    out.append('    L = ' + _num_map(data.get('L') or {}, per_line=8) + ',')
    out.append('    TD = ' + _num_map(data.get('TD') or {}, per_line=6) + ',')
    F = data['FAVOR']
    vend = ', '.join(f'{k} = {{ {", ".join(str(n) for n in F["vendor"].get(k, []))} }}' for k in ('A', 'H'))
    out.append(f'    FAVOR = {{ currency = {F["currency"]}, vendor = {{ {vend} }},')
    out.append('        cert = ' + _num_map(F['cert'], indent=8) + ',')
    out.append('        writ = ' + _num_map(F['writ'], indent=8) + ',')
    out.append('    },')
    out.append('}')
    # the addon builds the table on first use (Core/LazyData.lua)
    return lua_data.lazy('\n'.join(out) + '\n', 'PROFESSIONS', len(data['P']))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--wago', default=None, help='client tables (default: the newest copy of each table, tools/client_tables.py)')
    ap.add_argument('--att', default=ATT_CACHE, help=f'AllTheThings download (default {ATT_CACHE})')
    ap.add_argument('--scan-archive', default=build_scan_archive.ARCHIVE,
                    help='the scan archive whose merchant notes add vendors to V (default tools/scan_archive.json; "" for none)')
    ap.add_argument('--sv', nargs='*', help='Amisia SavedVariables with trainers read in the game (default: '
                    'those build_scan_archive finds)')
    ap.add_argument('--trainers', default=TRAINERS, help='the trainer archive (default tools/trainer_archive.json)')
    ap.add_argument('--out', default=OUT)
    ap.add_argument('--empty', action='store_true', help='write the file without data')
    args = ap.parse_args(argv)
    if args.wago is None:
        import client_tables
        args.wago = client_tables.default_dir()
    if args.empty:
        data = empty()
    else:
        if not att_data.wago_csv(args.wago, 'ItemSparse'):
            raise SystemExit(f'no client tables in {args.wago} (or run with --empty)')
        att = read_att(args.att) if os.path.isdir(args.att) else empty_att()
        client = read_client(args.wago, att=args.att)
        if not client['sla']:
            raise SystemExit('no SkillLineAbility table: export it (export_db2.ps1 -Tables SkillLineAbility)')
        seen = read_seen_vendors(args.scan_archive) if args.scan_archive else {}
        svs = build_scan_archive.default_svs() if args.sv is None else args.sv
        trainers = update_trainers(svs, args.trainers)
        data = combine(client, att, seen, read_cooldown_file(), trainers)
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
    rep = data.get('report', {})
    for sl, key in data['P']:
        log(f'  {key}: {len(data["R"][sl])} recipes')
    log(f'  recipe items: {len(data["I"])}, camp objects: {len(data["CAMP"])}, writs: {len(data["FAVOR"]["writ"])}, '
        f'SoD dropped: {rep.get("sod dropped", 0)}, reagents: {rep.get("reagents", "-")}')
    pr = rep.get('prices') or {}
    log(f'  vendor prices: {pr.get("items", 0)} items ({pr.get("reagents", 0)} reagents, {pr.get("recipe items", 0)} recipe items), '
        f'NPCs: {len(data["N"])}')
    tr = rep.get('trainers') or {}
    log(f'  trainers read in the game: {tr.get("read", 0)}, recipes with their rank: {tr.get("recipes", 0)}, '
        f'offers not in the data: {tr.get("offers not in the data", 0)}')
    cd = rep.get('cooldowns') or {}
    log(f'  sell prices (estimate): {len(data["S"])} reagents; cooldown recipes: {cd.get("recipes", 0)} '
        f'(from the {cd.get("from", "-")})')


if __name__ == '__main__':
    main()
