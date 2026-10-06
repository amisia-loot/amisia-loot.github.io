"""Builds addon/Amisia/ProfessionData.lua (WoW Forever): every recipe of every profession for the
addon's professions page - what it makes, its difficulty, how it is learned (trainer, with the
profession, a recipe item and where that item comes from), the reagents when the client table is
there, Forever's camp objects and Merchant's Favor. Runs without a WoW install (on the N100).

    python tools/build_professions.py [--wago DIR] [--att DIR] [--out FILE] [--empty]

Inputs:

- Client tables (CSV, wago.tools format, `<Table>.<build>.csv`; tools/export_db2.ps1 exports them on
  the PC, Syncthing brings them to ~/addons/_wago): SkillLineAbility (recipe -> profession,
  difficulty), SpellEffect (the item a recipe makes, enchants, camp placement), ItemSparse,
  ItemXItemEffect and ItemEffect (recipe item -> recipe, required rank and reputation, camp objects,
  certifications, writs), SpellName and Spell (only to recognise camp objects and writs; no text
  goes into the file), SpellReagents (optional: reagents; without it the addon asks the client).
  SkillLineAbility falls back to the copy AllTheThings ships (.config/.wago).
- AllTheThings' Forever data (MIT, see tools/att_data.py and addon/Amisia/LICENSES/):
  .config/structures/*.lua (trainer recipes per tier, Merchant's Favor recipes with price and
  standing per faction), profession db/*.lua (recipe item -> recipe), and the zone and dungeon files
  through att_data.load() (vendors, drops, quests of the recipe items; the favor vendors).

Names are not written for recipes and items: the addon asks the client (German). Only NPC and quest
names (English, from AllTheThings' comments) go in, for sources the client cannot name.
Recipes in the Season of Discovery number range (spells 400000-999999) that AllTheThings does not
list for Forever are left out.
"""
import argparse
import os
import re
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import att_data  # noqa: E402

OUT = os.path.join(ROOT, 'addon', 'Amisia', 'ProfessionData.lua')
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
           'items': {}, 'names': {}, 'desc': {}, 'reagents': {}, 'spellEffects': {}, 'reagentTable': False}
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
                                           'standing': _int(r.get('MinReputation'))})
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
    return out


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
    """(trainer {spell: tier 0-4}, favor {item: [(price, standing, 'A'|'H')]}, rank spells) from the
    structures files: the trainer lists by tier (other lists, as a specialisation's, tier 0), the
    Merchant's Favor lists by faction and standing. A recipe removed before Forever and the
    profession rank spells (with a "rank" field) are left out."""
    trainer, favor = {}, {}
    folder = os.path.join(base, '.config', 'structures')
    if not os.path.isdir(folder):
        return trainer, favor
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
                trainer.setdefault(spell, TIERS.get(block, 0))
            elif rank_open and '["rank"]' in line:
                trainer.pop(rank_open, None)
                rank_open = None
    return trainer, favor


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
    trainer, favor = read_structures(base)
    sources = {}

    def add(item, token):
        lst = sources.setdefault(item, [])
        if token not in lst:
            lst.append(token)
    for item, vendor, _old in db['sold']:
        add(item, f'V{vendor}')
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
    return {'commit': db.get('commit'), 'trainer': trainer, 'favor': favor, 'profdb': read_profession_db(base),
            'vendors': read_favor_vendors(base), 'sources': sources, 'npcs': npcs, 'quests': quests}


def empty_att():
    return {'commit': None, 'trainer': {}, 'favor': {}, 'profdb': {}, 'vendors': {'A': [], 'H': []}, 'sources': {},
            'npcs': {}, 'quests': {}}


# ---------------------------------------------------------------- combining
def _source_key(t):
    return (SOURCE_ORDER.get(t[0], 9), t)


def combine(client, att):
    """The neutral form render() writes: P, R, I, G, N, Q, CAMP, FAVOR, client, source, report."""
    teach = dict(att['profdb'])
    teach.update(client['teach'])          # the client's own link wins
    att_spells = set(att['trainer']) | set(att['profdb'].values())
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
        ranks = []
        for item in taught:
            src.append(f'I{item}')
            used_items.add(item)
            r = client['items'].get(item, {}).get('rank', 0)
            if r:
                ranks.append(r)
        learn = min(ranks) if ranks else max(1, a['min'])
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
    N = {}
    for nid in sorted(npcs_used):
        name, where, fac = att['npcs'].get(nid, ('', '', ''))
        N[nid] = f'{name}|{where}|{fac}'
    Q = {qid: att['quests'].get(qid, '') for qid in sorted(quests_used)}

    G = {}
    if client['reagentTable']:
        listed = {int(l.split(':')[0]) for lst in R.values() for l in lst}
        for sp in sorted(listed):
            if sp in client['reagents']:
                G[sp] = ','.join(f'{i}:{n}' for i, n in client['reagents'][sp])

    return {'P': P, 'R': R, 'I': I, 'G': G, 'N': N, 'Q': Q, 'CAMP': camp_objects(client),
            'FAVOR': favor_info(client, att, R), 'client': client['client'], 'source': (att.get('commit') or '')[:10],
            'report': report}


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
    return {'P': [], 'R': {}, 'I': {}, 'G': {}, 'N': {}, 'Q': {}, 'CAMP': [],
            'FAVOR': {'currency': FAVOR_CURRENCY, 'cert': {}, 'writ': {}, 'vendor': {'A': [], 'H': []}},
            'client': '', 'source': '', 'report': {}}


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
           '-- the profession, T1-T4 trainer tier, T0 trainer without tier, I<item> recipe item, empty unknown).',
           '-- I: [recipe item] = "spell:rank:faction:standing:sources" (F<price>@<standing><A|H> Merchant\'s Favor,',
           '-- V<npc> vendor, Q<quest> quest, D<npc> drop, Z<uiMapID> zone drop, W world drop). G: [spell] =',
           '-- "item:n,..." reagents (only with the SpellReagents table). N: [npc] = "Name|uiMapID:x:y|A/H/" (English).',
           '-- Q: [quest] = English name. CAMP: "item:skillLine:rank:useSpell:recipeSpell:slots:overItem".',
           'ns.PROFESSIONS = {',
           f'    built = {lua_str(built)}, client = {lua_str(data.get("client") or "")}, source = {lua_str(data.get("source") or "")},',
           '    P = { ' + ', '.join(f'{{ {s}, {lua_str(k)} }}' for s, k in data['P']) + ' },',
           '    R = {']
    for sl, _ in data['P']:
        out.append(f'        [{sl}] = ' + _str_list(data['R'][sl], 8) + ',')
    out.append('    },')
    out.append('    I = ' + _str_map(data['I']) + ',')
    out.append('    G = ' + _str_map(data['G']) + ',')
    out.append('    N = ' + _str_map(data['N'], 3) + ',')
    out.append('    Q = ' + _str_map(data['Q'], 3) + ',')
    out.append('    CAMP = ' + _str_list(data['CAMP'], 4) + ',')
    F = data['FAVOR']
    vend = ', '.join(f'{k} = {{ {", ".join(str(n) for n in F["vendor"].get(k, []))} }}' for k in ('A', 'H'))
    out.append(f'    FAVOR = {{ currency = {F["currency"]}, vendor = {{ {vend} }},')
    out.append('        cert = ' + _num_map(F['cert'], indent=8) + ',')
    out.append('        writ = ' + _num_map(F['writ'], indent=8) + ',')
    out.append('    },')
    out.append('}')
    return '\n'.join(out) + '\n'


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--wago', default=WAGO, help=f'client tables (default {WAGO})')
    ap.add_argument('--att', default=ATT_CACHE, help=f'AllTheThings download (default {ATT_CACHE})')
    ap.add_argument('--out', default=OUT)
    ap.add_argument('--empty', action='store_true', help='write the file without data')
    args = ap.parse_args(argv)
    if args.empty:
        data = empty()
    else:
        if not att_data.wago_csv(args.wago, 'ItemSparse'):
            raise SystemExit(f'no client tables in {args.wago} (or run with --empty)')
        att = read_att(args.att) if os.path.isdir(args.att) else empty_att()
        client = read_client(args.wago, att=args.att)
        if not client['sla']:
            raise SystemExit('no SkillLineAbility table: export it (export_db2.ps1 -Tables SkillLineAbility)')
        data = combine(client, att)
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


if __name__ == '__main__':
    main()
