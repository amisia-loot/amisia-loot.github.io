"""The permanent enchantments of WoW Forever for Amisia's enchant suggestions (F-128, spec
docs/specs/2026-10-31-verzauberungen.md), from the client's own tables only (D-03), never from the net.

    python tools/build_enchants.py [--wago DIR ...] [--out FILE] [--empty]

- An enchantment is a SpellItemEnchantment row a spell puts on an item for good (SpellEffect 53
  "enchant item"; 54, the temporary oils and stones, stays out: spec question 2).
- Its sources: a recipe of Enchanting or Engineering (SkillLineAbility: the spell, the skill rank), or
  an item whose use effect is the spell (ItemXItemEffect -> ItemEffect, trigger 0: armour kits, scopes,
  shield spikes, counterweights, librams). Recipe items (class 9) are no source of their own (the
  professions data names them); items the client has no name for and QA/test items fall out.
- What fits: SpellEquippedItems of the source's spell (item class, inventory types, subclasses).
  A source without such a row fits nothing and falls out.
- Its stats as the client names item stats (ItemSparse keys without ITEM_MOD_, build_bis.STAT_KEY):
  effect 5 (a stat), 4 with school 0 (armour), 2 (weapon damage: WDMG, the addon divides it by the
  weapon's speed), 3 (an equip spell: its auras through build_bis.aura_stats). Anything else (a proc,
  a use spell, a resistance) marks the enchantment as "has an effect the scoring does not count".

Reads <Table>.csv or <Table>.<build>.csv from the folders given with --wago (default: the newest copy of each
table, tools/client_tables.py).
Writes Amisia/Data/EnchantData.lua (ns.ENCHANT, lazy).
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
import build_bis  # noqa: E402
import lua_data  # noqa: E402

OUT = os.path.join(ROOT, 'Amisia', 'Data', 'EnchantData.lua')
WAGO = os.path.expanduser('~/addons/_wago')

REQUIRED = ['SpellEffect', 'SpellItemEnchantment', 'SpellEquippedItems', 'SkillLineAbility', 'ItemEffect',
            'ItemXItemEffect', 'Item', 'ItemSparse']

EFFECT_ENCHANT_ITEM = 53
TRIGGER_USE = 0
SKILLS = {333: 'enchanting', 202: 'engineering'}
ITEM_CLASS_RECIPE = 9
# enchantment effect types (SpellItemEnchantment.Effect_n)
E_NONE, E_DAMAGE, E_EQUIP_SPELL, E_RESISTANCE, E_STAT = 0, 2, 3, 4, 5
# InventoryType -> the equip location the client names (C_Item.GetItemInfoInstant, without INVTYPE_)
INVTYPE = {1: 'HEAD', 2: 'NECK', 3: 'SHOULDER', 4: 'BODY', 5: 'CHEST', 6: 'WAIST', 7: 'LEGS', 8: 'FEET', 9: 'WRIST',
           10: 'HAND', 11: 'FINGER', 12: 'TRINKET', 13: 'WEAPON', 14: 'SHIELD', 15: 'RANGED', 16: 'CLOAK',
           17: '2HWEAPON', 19: 'TABARD', 20: 'ROBE', 21: 'WEAPONMAINHAND', 22: 'WEAPONOFFHAND', 23: 'HOLDABLE',
           25: 'THROWN', 26: 'RANGEDRIGHT', 28: 'RELIC'}
TEST_NAME = re.compile(r'^(QA|TEST|Test|\[PH\])|Deprecated|DEPRECATED|\bOLD\b|zzOLD', re.I)


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
    m = re.search(r'\.(\d+(?:\.\d+)+)\.csv$', find_table(dirs, 'SpellItemEnchantment') or '')
    return m.group(1) if m else ''


def load_client(dirs):
    missing = [t for t in REQUIRED if not find_table(dirs, t)]
    if missing:
        raise SystemExit('build_enchants: client tables missing in %s: %s (export them with '
                         'tools/export_db2.ps1 -Tables %s)' % (', '.join(dirs), ', '.join(missing), ','.join(missing)))
    return {t: read_table(dirs, t) for t in REQUIRED}


def bits(mask, names=None):
    """The set bits of mask as a sorted list (of names when given)."""
    out = []
    mask = num(mask)
    if mask <= 0:
        return out
    for i in range(32):
        if mask & (1 << i):
            out.append(names.get(i) if names is not None else i)
    return [x for x in out if x is not None]


def enchant_stats(row, spell_effects):
    """({client key: value}, fx): the stats of an enchantment and whether it has more than the
    scoring counts."""
    stats, fx = {}, False

    def add(key, v):
        v = num(v)
        if v:
            stats[key] = stats.get(key, 0) + v
    for i in range(3):
        effect, points, arg = num(row.get(f'Effect_{i}')), num(row.get(f'EffectPointsMin_{i}')), num(row.get(f'EffectArg_{i}'))
        if effect == E_NONE:
            continue
        if effect == E_STAT and arg in build_bis.STAT_KEY and build_bis.STAT_KEY[arg] not in build_bis.SC_UNSCORED:
            add(build_bis.STAT_KEY[arg], points)
        elif effect == E_STAT and arg == 50:
            add('RESISTANCE0_NAME', points)
        elif effect == E_RESISTANCE and arg == 0:
            add('RESISTANCE0_NAME', points)
        elif effect == E_DAMAGE:
            add('WDMG', points)
        elif effect == E_EQUIP_SPELL and arg in spell_effects:
            got, rest = build_bis.aura_stats(spell_effects[arg])
            for k, v in got.items():
                add(k, v)
            fx = fx or rest or not got
        else:
            fx = True
    return stats, fx


def build(dirs):
    t = load_client(dirs)
    spell_effects, enchant_of = {}, {}
    for r in t['SpellEffect']:
        sp = num(r.get('SpellID'))
        spell_effects.setdefault(sp, []).append((num(r.get('EffectIndex')), [
            num(r.get('Effect')), num(r.get('EffectAura')), num(r.get('EffectBasePointsF')), num(r.get('EffectMiscValue_0'))]))
        if num(r.get('Effect')) == EFFECT_ENCHANT_ITEM and num(r.get('EffectMiscValue_0')) > 0:
            enchant_of.setdefault(sp, num(r.get('EffectMiscValue_0')))
    spell_effects = {sp: [e for _, e in sorted(v, key=lambda x: x[0])] for sp, v in spell_effects.items()}
    fits = {}
    for r in t['SpellEquippedItems']:
        sp = num(r.get('SpellID'))
        cls = num(r.get('EquippedItemClass'), -1)
        if sp in enchant_of and cls in (2, 4):
            fits[sp] = (cls, bits(r.get('EquippedItemInvTypes'), INVTYPE), bits(r.get('EquippedItemSubclass')))
    sparse = {num(r['ID']): r for r in t['ItemSparse']}
    item_class = {num(r['ID']): num(r.get('ClassID'), -1) for r in t['Item']}
    effects = {num(r['ID']): (num(r.get('TriggerType')), num(r.get('SpellID'))) for r in t['ItemEffect']}

    sources = []
    for r in t['SkillLineAbility']:
        sp, skill = num(r.get('Spell')), num(r.get('SkillLine'))
        if skill in SKILLS and sp in enchant_of and sp in fits:
            sources.append({'kind': 'r', 'id': sp, 'enchant': enchant_of[sp], 'skill': skill,
                            'level': num(r.get('MinSkillLineRank')), 'fits': fits[sp]})
    seen = set()
    for r in sorted(t['ItemXItemEffect'], key=lambda x: num(x['ID'])):
        item = num(r.get('ItemID'))
        trig, sp = effects.get(num(r.get('ItemEffectID')), (None, 0))
        if trig != TRIGGER_USE or sp not in enchant_of or sp not in fits or item in seen:
            continue
        s = sparse.get(item)
        name = (s or {}).get('Display_lang') or ''
        if not name or TEST_NAME.search(name) or item_class.get(item) == ITEM_CLASS_RECIPE:
            continue
        seen.add(item)
        sources.append({'kind': 'i', 'id': item, 'enchant': enchant_of[sp], 'skill': 0,
                        'level': num(s.get('RequiredLevel')), 'fits': fits[sp]})
    sources.sort(key=lambda x: (x['enchant'], x['kind'], x['id']))

    rows = {num(r['ID']): r for r in t['SpellItemEnchantment']}
    enchants = {}
    for src in sources:
        e = src['enchant']
        if e in enchants or e not in rows:
            continue
        stats, fx = enchant_stats(rows[e], spell_effects)
        enchants[e] = {'stats': stats, 'fx': fx, 'name': rows[e].get('Name_lang') or '',
                       'ilvl': num(rows[e].get('ItemLevelMin'))}
    sources = [s for s in sources if s['enchant'] in enchants]
    return {'build': build_of(dirs), 'enchants': enchants, 'sources': sources}


def empty_data():
    return {'build': '', 'enchants': {}, 'sources': []}


# ---------------------------------------------------------------- output
def lua_str(s):
    return '"' + str(s).replace('\\', '\\\\').replace('"', '\\"') + '"'


def stats_text(stats):
    return ';'.join(f'{k}={v:g}' for k, v in sorted(stats.items()))


def render_lua(data, built=None):
    L = [
        '-- Generated by tools/build_enchants.py from the WoW Forever client tables (build %s): SpellEffect,' % (data['build'] or '?'),
        '-- SpellItemEnchantment, SpellEquippedItems, SkillLineAbility, ItemEffect, ItemXItemEffect, Item,',
        '-- ItemSparse. Do not edit; rebuild instead.',
        '-- E: [enchantment] = "stats|fx|item level|English name": stats as the client names item stats',
        '-- ("AGILITY=3;STAMINA=2", WDMG weapon damage), fx 1 when it does more than the scoring counts,',
        '-- item level the lowest the enchanted item may have (0: any).',
        '-- S: "kind:id:enchantment:skill:level:item class:equip locations:subclasses": kind r a recipe',
        '-- (id the spell, skill its skill line, level the skill rank) or i an item (id the item, level the',
        '-- level it needs); what fits: item class (2 weapon, 4 armour), INVTYPE_ names, subclass numbers',
        '-- (empty: any).',
        'local _, ns = ...',
        '',
        'ns.ENCHANT = {',
        '    build = %s, built = %s,' % (lua_str(data['build']), lua_str(built or time.strftime('%Y-%m-%d'))),
        '    E = {',
    ]
    for e in sorted(data['enchants']):
        d = data['enchants'][e]
        L.append('        [%d] = %s,' % (e, lua_str('%s|%d|%d|%s' % (stats_text(d['stats']), 1 if d['fx'] else 0, d['ilvl'],
                                                                     d['name'].replace('|', '/')))))
    L += ['    },', '    S = {']
    for s in data['sources']:
        cls, inv, sub = s['fits']
        L.append('        %s,' % lua_str('%s:%d:%d:%d:%d:%d:%s:%s' % (s['kind'], s['id'], s['enchant'], s['skill'], s['level'],
                                                                     cls, ','.join(inv), ','.join(str(x) for x in sub))))
    L += ['    },', '}', '']
    return lua_data.lazy('\n'.join(L), 'ENCHANT', len(data['sources']))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--wago', action='append', default=None, help='client tables (default: the newest copy of each table, tools/client_tables.py); may repeat')
    ap.add_argument('--empty', action='store_true', help='write the file without data')
    ap.add_argument('--out', default=OUT)
    args = ap.parse_args(argv)
    if args.empty:
        data = empty_data()
    else:
        if not args.wago:
            import client_tables
            args.wago = [client_tables.default_dir()]
        data = build([os.path.expanduser(d) for d in args.wago])
    with open(args.out, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(render_lua(data))
    kinds = {k: sum(1 for s in data['sources'] if s['kind'] == k) for k in ('r', 'i')}
    print(f"build_enchants: {len(data['enchants'])} enchantments, {kinds['r']} recipes, {kinds['i']} items "
          f"-> {os.path.relpath(args.out, ROOT)}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
