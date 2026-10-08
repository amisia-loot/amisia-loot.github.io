"""The mage scrolls of WoW Forever ("Comprehension", German "Arkanes Verständnis") for Amisia's
scrolls page, from the client's own tables and AllTheThings (MIT).

    python tools/build_magescrolls.py [--wago DIR ...] [--att DIR] [--refresh-att] [--out FILE] [--empty]

What they are: a mage finds untranslated scrolls ("Scroll: KWYJIBO", "Scroll: DOST OREM", ...) and
deciphers them with the Comprehension skill, a skill line of its own (SkillLine "Comprehension").
Each scroll needs a Comprehension rank (ItemSparse.RequiredSkill/RequiredSkillRank); the ranks of the
scrolls are the tiers. Deciphering ("Comprehend Scroll", one SkillLineAbility per tier) raises the
skill: yellow from TrivialSkillLineRankLow, grey from TrivialSkillLineRankHigh, matched to the tiers
in rank order. What a scroll turns into is decided by the server (no client table says it); the
data lists the mage-only scrolls the client knows as possible results ("Scroll of Imbue Frost",
"Scroll of Rat Familiar", ...), with their use spell and its text (Spell, enUS, placeholders resolved
as build_talents.py does). Helpers: the Comprehension Charm and the spell that conjures it, the item
whose use spell raises the skill (an aura 30 on the skill line), Study (a library turns research
into a Bundle of Scrolls) and Research.

AllTheThings (tools/att_data.py, sandboxed; cache ~/addons/_cache/att, --refresh-att): which scrolls
are world drops ("world drops/"), and the library books ("expansion features/library books.lua"):
books found in the world that a librarian (Stormwind, Undercity) takes for a Comprehension Charm,
and the "Friend of the Library" quests for N books.

Reads <Table>.csv or <Table>.<build>.csv from the folders given with --wago (default ~/addons/_wago;
tools/export_db2.ps1 on the PC). Writes addon/Amisia/Data/MageScrollData.lua (ns.MAGESCROLLS, lazy).
"""
import argparse
import csv
import os
import re
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import att_data  # noqa: E402
import build_talents  # noqa: E402  (the spell text resolver)
import lua_data  # noqa: E402

OUT = os.path.join(ROOT, 'addon', 'Amisia', 'Data', 'MageScrollData.lua')
WAGO = os.path.expanduser('~/addons/_wago')

REQUIRED = ['ItemSparse', 'Item', 'SkillLine', 'SkillLineAbility', 'Spell', 'SpellName', 'SpellMisc', 'SpellEffect',
            'ItemEffect', 'ItemXItemEffect']
OPTIONAL = ['SpellDuration', 'SpellRadius', 'SpellAuraOptions']

SKILL_NAME = 'Comprehension'
CHARM_NAME = 'Comprehension Charm'
MAGE = 128                 # ChrClasses mask bit of the mage
CONSUMABLE = 0             # Item.ClassID
EFFECT_CREATE_ITEM = 24
EFFECT_APPLY_AURA = 6
AURA_MOD_SKILL = 30
MAX_RESULT_ILVL = 60       # scrolls above are Season of Discovery's raid items, not Forever's
ATT_DIRS = ('expansion features', 'world drops')
LIBRARY_FILE = 'expansion features/library books.lua'


def num(v, default=0):
    try:
        f = float(v)
    except (TypeError, ValueError):
        return default
    return int(f) if f == int(f) else f


def find_table(dirs, table):
    for d in dirs:
        path = att_data.wago_csv(d, table)
        if path:
            return path
    return None


def read_table(dirs, table):
    path = find_table(dirs, table)
    if not path:
        return None
    with open(path, encoding='utf-8-sig', newline='') as fh:
        return list(csv.DictReader(fh))


def build_of(dirs):
    m = re.search(r'\.(\d+(?:\.\d+)+)\.csv$', find_table(dirs, 'ItemSparse') or '')
    return m.group(1) if m else ''


def load_client(dirs):
    missing = [t for t in REQUIRED if not find_table(dirs, t)]
    if missing:
        raise SystemExit('build_magescrolls: client tables missing in %s: %s (export them with '
                         'tools/export_db2.ps1 -Tables %s)' % (', '.join(dirs), ', '.join(missing), ','.join(missing)))
    return {t: read_table(dirs, t) or [] for t in REQUIRED + OPTIONAL}


def clean(text):
    return re.sub(r'\s+', ' ', (text or '').replace('\r', ' ').replace('\n', ' ')).strip()


def build(dirs, att=None):
    """The data from the client tables in dirs and the neutral form of an AllTheThings download
    (att_data.load(..., dirs=ATT_DIRS); None: without sources)."""
    t = load_client(dirs)
    spells = build_talents.Spells(t)
    sparse = {num(r['ID']): r for r in t['ItemSparse']}
    item = {num(r['ID']): r for r in t['Item']}

    skill = next((num(r['ID']) for r in t['SkillLine'] if r.get('DisplayName_lang') == SKILL_NAME), 0)
    if not skill:
        raise SystemExit('build_magescrolls: no skill line "%s" in the client tables' % SKILL_NAME)

    # the use spells of the items
    effects = {r['ID']: r for r in t['ItemEffect']}
    use = {}
    for r in t['ItemXItemEffect']:
        e = effects.get(r.get('ItemEffectID'))
        if e and num(e.get('SpellID')):
            use.setdefault(num(r['ItemID']), []).append(num(e['SpellID']))
    by_spell = {}
    for r in t['SpellEffect']:
        by_spell.setdefault(num(r['SpellID']), []).append(r)

    def creates(sid):
        return [num(r.get('EffectItemType')) for r in by_spell.get(sid, [])
                if num(r.get('Effect')) == EFFECT_CREATE_ITEM and num(r.get('EffectItemType'))]

    def text_of(sid):
        raw = spells.desc.get(sid, '')
        if not raw:
            return ''
        text, _, _ = build_talents.resolve_text(raw, build_talents.Ctx(sid, {}, 1), spells)
        return clean(text)

    def is_mage_item(r):
        return num(r.get('AllowableClass')) == MAGE

    # the untranslated scrolls and their tiers
    scrolls = sorted(({'item': i, 'rank': num(r.get('RequiredSkillRank')), 'ilvl': num(r.get('ItemLevel')),
                       'name': r.get('Display_lang') or ''}
                      for i, r in sparse.items() if num(r.get('RequiredSkill')) == skill),
                     key=lambda s: (s['rank'], s['item']))
    ranks = sorted({s['rank'] for s in scrolls})
    recipes = sorted((r for r in t['SkillLineAbility'] if num(r.get('SkillLine')) == skill
                      and num(r.get('TrivialSkillLineRankHigh')) > 0),
                     key=lambda r: (num(r['TrivialSkillLineRankHigh']), num(r['Spell'])))
    tiers = []
    for i, rank in enumerate(ranks):
        r = recipes[i] if len(recipes) == len(ranks) else None
        tiers.append({'rank': rank, 'yellow': num(r['TrivialSkillLineRankLow']) if r else 0,
                      'grey': num(r['TrivialSkillLineRankHigh']) if r else 0, 'spell': num(r['Spell']) if r else 0})
    for s in scrolls:
        s['tier'] = ranks.index(s['rank']) + 1

    # the helpers: the charm and its spell, the skill booster, the abilities of the skill line
    charm = next((i for i, r in sparse.items() if r.get('Display_lang') == CHARM_NAME and is_mage_item(r)), 0)
    conjure = next((sid for sid in sorted(by_spell) if charm and charm in creates(sid)), 0)
    boost, boost_spell = 0, 0
    for i in sorted(sparse):
        for sid in use.get(i, []):
            for r in by_spell.get(sid, []):
                if num(r.get('Effect')) == EFFECT_APPLY_AURA and num(r.get('EffectAura')) == AURA_MOD_SKILL \
                        and num(r.get('EffectMiscValue_0')) == skill and not boost:
                    boost, boost_spell = i, sid
    abilities = []
    for r in sorted(t['SkillLineAbility'], key=lambda r: num(r['Spell'])):
        sid = num(r.get('Spell'))
        if num(r.get('SkillLine')) == skill and num(r.get('TrivialSkillLineRankHigh')) == 0 and sid:
            abilities.append({'spell': sid, 'name': spells.name.get(sid, ''), 'text': text_of(sid), 'makes': creates(sid)})
    bundle = next((m for a in abilities for m in a['makes']), 0)
    study = next((a['spell'] for a in abilities if a['makes']), 0)

    # what the scrolls may turn into: the mage-only consumable scrolls of the client
    skip = {s['item'] for s in scrolls} | {boost, charm}
    results = []
    for i, r in sorted(sparse.items()):
        name = r.get('Display_lang') or ''
        if i in skip or not is_mage_item(r) or not name.startswith('Scroll') or num(r.get('RequiredSkill')):
            continue
        if num(item.get(i, {}).get('ClassID'), -1) != CONSUMABLE or num(r.get('ItemLevel')) > MAX_RESULT_ILVL:
            continue
        sid = (use.get(i) or [0])[0]
        results.append({'item': i, 'level': num(r.get('RequiredLevel')), 'ilvl': num(r.get('ItemLevel')), 'spell': sid,
                        'name': name, 'text': text_of(sid) if sid else ''})
    results.sort(key=lambda x: (x['level'], x['ilvl'], x['item']))

    data = {'build': build_of(dirs), 'skill': skill, 'tiers': tiers, 'scrolls': scrolls, 'results': results,
            'charm': charm, 'conjure': conjure, 'boost': boost, 'boostSpell': boost_spell, 'bundle': bundle, 'study': study,
            'abilities': abilities, 'books': [], 'friends': [], 'librarians': [], 'att': None}
    # English fallback names of the helpers (the addon shows the client's own)
    data['names'] = {k: (sparse.get(data[k], {}).get('Display_lang') or '') for k in ('charm', 'boost', 'bundle')}
    data['names']['conjure'] = spells.name.get(conjure, '')
    if att:
        data['att'] = (att.get('commit') or '')[:10] or None
        world = set(att.get('world') or [])
        for s in scrolls:
            s['world'] = s['item'] in world
        givers = set()
        for qid, q in sorted(att['quests'].items()):
            if q.get('file') != LIBRARY_FILE:
                continue
            givers.update(q.get('givers') or [])
            if q.get('startItems'):
                data['books'].append({'quest': qid, 'item': q['startItems'][0], 'faction': q.get('faction') or '',
                                      'maps': q.get('maps') or [], 'name': q.get('name') or '',
                                      'charm': bool(charm and charm in (q.get('rewards') or []))})
            elif q.get('sqreq'):
                data['friends'].append({'quest': qid, 'need': q['sqreq'], 'level': q.get('minLevel') or 0,
                                        'name': q.get('name') or '', 'rewards': q.get('rewards') or []})
        data['friends'].sort(key=lambda f: (f['need'], f['quest']))
        for npc in sorted(givers):
            n = att['npcs'].get(npc)
            if n and n.get('points'):
                m, x, y = n['points'][0]
                data['librarians'].append({'npc': npc, 'faction': n.get('faction') or '', 'map': m, 'x': x, 'y': y,
                                           'name': n.get('name') or ''})
    return data


# ---------------------------------------------------------------- output
def lua_str(s):
    return build_talents.lua_str(s)


def lua_list(items):
    return build_talents.lua_list(items)


def render_lua(data, built=None):
    L = [
        '-- Generated by tools/build_magescrolls.py from the WoW Forever client tables (build %s) and' % (data['build'] or '?'),
        '-- AllTheThings (%s; MIT, see LICENSES/). Do not edit; rebuild instead. Texts are the client\'s' % (data['att'] or 'not read'),
        '-- enUS; the addon shows the client\'s own names and texts where it gets them.',
        '-- tiers: { rank, yellow, grey, spell }; scrolls: { item, rank, tier, item level, world drop 1/0, name };',
        '-- results: { item, level, item level, use spell, name, text }; abilities: { spell, name, text };',
        '-- books: { quest, book item, faction, { uiMapIDs }, name, gives a charm 1/0 };',
        '-- friends: { quest, books needed, level, name, { reward items } };',
        '-- librarians: { npc, faction, uiMapID, x, y (hundredths of a percent), name }.',
        'local _, ns = ...',
        '',
        'ns.MAGESCROLLS = {',
        '    build = %s, built = %s, att = %s, skill = %d,' % (lua_str(data['build']), lua_str(built or time.strftime('%Y-%m-%d')),
                                                             lua_str(data['att'] or ''), data['skill']),
        '    charm = %d, conjure = %d, boost = %d, boostSpell = %d, bundle = %d, study = %d,' % (
            data['charm'], data['conjure'], data['boost'], data['boostSpell'], data['bundle'], data.get('study', 0)),
        '    names = { %s },' % ', '.join('%s = %s' % (k, lua_str(data.get('names', {}).get(k, '')))
                                      for k in ('charm', 'boost', 'bundle', 'conjure')),
        '    tiers = %s,' % lua_list(['{ %d, %d, %d, %d }' % (x['rank'], x['yellow'], x['grey'], x['spell']) for x in data['tiers']]),
        '    scrolls = {',
    ]
    for s in data['scrolls']:
        L.append('        { %d, %d, %d, %d, %d, %s },' % (s['item'], s['rank'], s['tier'], s['ilvl'], 1 if s.get('world') else 0,
                                                       lua_str(s['name'])))
    L += ['    },', '    results = {']
    for r in data['results']:
        L.append('        { %d, %d, %d, %d, %s, %s },' % (r['item'], r['level'], r['ilvl'], r['spell'], lua_str(r['name']),
                                                       lua_str(r['text'])))
    L += ['    },', '    abilities = {']
    for a in data['abilities']:
        L.append('        { %d, %s, %s },' % (a['spell'], lua_str(a['name']), lua_str(a['text'])))
    L += ['    },', '    books = {']
    for b in data['books']:
        L.append('        { %d, %d, %s, %s, %s, %d },' % (b['quest'], b['item'], lua_str(b['faction']),
                                                       lua_list([str(m) for m in b['maps']]), lua_str(b['name']),
                                                       1 if b['charm'] else 0))
    L += ['    },', '    friends = {']
    for f in data['friends']:
        L.append('        { %d, %d, %d, %s, %s },' % (f['quest'], f['need'], f['level'], lua_str(f['name']),
                                                   lua_list([str(i) for i in f['rewards']])))
    L += ['    },', '    librarians = {']
    for n in data['librarians']:
        L.append('        { %d, %s, %d, %d, %d, %s },' % (n['npc'], lua_str(n['faction']), n['map'], n['x'], n['y'],
                                                       lua_str(n['name'])))
    L += ['    },', '}', '']
    return lua_data.lazy('\n'.join(L), 'MAGESCROLLS', len(data['scrolls']))


def empty_data():
    return {'build': '', 'names': {}, 'skill': 0, 'tiers': [], 'scrolls': [], 'results': [], 'charm': 0, 'conjure': 0, 'boost': 0,
            'boostSpell': 0, 'bundle': 0, 'study': 0, 'abilities': [], 'books': [], 'friends': [], 'librarians': [], 'att': None}


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--wago', action='append', default=None, help=f'client tables (default {WAGO}); may repeat')
    ap.add_argument('--att', default=None, help=f'AllTheThings download (default {att_data.ATT_CACHE} when it exists)')
    ap.add_argument('--refresh-att', action='store_true', help='download the AllTheThings Forever folder first')
    ap.add_argument('--no-att', action='store_true', help='without AllTheThings (no sources, no library books)')
    ap.add_argument('--empty', action='store_true', help='write the file without data')
    ap.add_argument('--out', default=OUT)
    args = ap.parse_args(argv)
    if args.empty:
        data = empty_data()
    else:
        dirs = [os.path.expanduser(d) for d in (args.wago or [WAGO])]
        att = None
        if not args.no_att:
            base = os.path.expanduser(args.att or att_data.ATT_CACHE)
            if args.refresh_att:
                att_data.refresh(base)
            if os.path.exists(os.path.join(base, 'COMMIT')):
                att = att_data.load(base, items=False, dirs=ATT_DIRS)
                for f, err in att['errors'].items():
                    print(f'build_magescrolls: {f}: {err}', file=sys.stderr)
            else:
                print(f'build_magescrolls: no AllTheThings download in {base} (--refresh-att): no sources', file=sys.stderr)
        data = build(dirs, att)
    text = render_lua(data)
    with open(args.out, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(text)
    print(f"build_magescrolls: {len(data['scrolls'])} scrolls in {len(data['tiers'])} tiers, {len(data['results'])} results, "
          f"{len(data['books'])} library books -> {os.path.relpath(args.out, ROOT)}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
