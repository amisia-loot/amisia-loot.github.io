"""The lists of Amisia's raid check (F-098, spec docs/specs/2026-10-12-raid-check.md): which buff
is a flask, an elixir, food ("Well Fed") or one of the class buffs, and which worn slots an
enchanter enchants. From the client's own tables only (D-03), never from the net.

    python tools/build_raidcheck.py [--wago DIR ...] [--out FILE] [--empty]

- Flasks: the items of class 0 (consumable) subclass 3 (flask); their use spell (ItemXItemEffect ->
  ItemEffect.SpellID) is the buff the raider carries.
- Elixirs: class 0 subclass 2; only use spells that apply an aura (SpellEffect 6) for 10 minutes or
  more (SpellMisc.DurationIndex -> SpellDuration), so healing potions and "Cure Poison" fall out,
  and not only utility auras (water breathing, water walking, detection, languages: UTILITY_AURAS).
- Food: class 0 subclass 5; the use spell ("Nutritious Food", "Food") triggers the buff through
  EffectTriggerSpell (two steps at most); every triggered aura of 10 minutes or more counts, and
  every spell named "Well Fed" (enUS). Drinks without such a buff fall out.
- Class buffs: a small list of English names (below), resolved against SpellName to every rank;
  each group names the class that gives it. The addon compares spell ids, never names, so it works
  on every client language.
- Enchantable slots: with the table SpellEquippedItems (tools/export_db2.ps1 asks for it since
  2.29.0) the slots the enchanting recipes (SkillLineAbility skill line 333, SpellEffect 53 "enchant
  item") target; without it the fixed list of the spec (back, chest, wrist, hands, feet, main hand,
  shield). Head, shoulders and legs never count (their enchants come from reputation and quests).

Reads <Table>.csv or <Table>.<build>.csv from the folders given with --wago (default ~/addons/_wago).
Writes Amisia/Data/RaidCheckData.lua (ns.RAIDCHECK, lazy).
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
import lua_data  # noqa: E402

OUT = os.path.join(ROOT, 'Amisia', 'Data', 'RaidCheckData.lua')
WAGO = os.path.expanduser('~/addons/_wago')

REQUIRED = ['Item', 'ItemEffect', 'ItemXItemEffect', 'SpellEffect', 'SpellMisc', 'SpellDuration', 'SpellName']
OPTIONAL = ['SpellEquippedItems', 'SkillLineAbility']

CONSUMABLE = 0
SUB_ELIXIR, SUB_FLASK, SUB_FOOD = 2, 3, 5
EFFECT_APPLY_AURA = 6
EFFECT_ENCHANT_ITEM = 53
# the aura types of utility elixirs (they supply nobody for a raid): stealth and invisibility
# detection, tracking (detect undead/demon), water breathing, water walking, languages
UTILITY_AURAS = {17, 19, 44, 82, 104, 244, 299}
LONG_MS = 600000           # an elixir's or food's buff lasts at least 10 minutes
TRIGGER_DEPTH = 2
WELL_FED = 'Well Fed'
ENCHANTING = 333

# the class buffs: key, the class that gives it, talent (only when someone in the raid carries it),
# the English spell names (every rank of each)
BUFFS = [
    ('int', 'MAGE', False, ['Arcane Intellect', 'Arcane Brilliance']),
    ('sta', 'PRIEST', False, ['Power Word: Fortitude', 'Prayer of Fortitude']),
    ('wild', 'DRUID', False, ['Mark of the Wild', 'Gift of the Wild']),
    ('spirit', 'PRIEST', True, ['Divine Spirit', 'Prayer of Spirit']),
    ('bless', 'PALADIN', False, ['Blessing of Kings', 'Blessing of Might', 'Blessing of Wisdom', 'Blessing of Salvation',
                                 'Greater Blessing of Kings', 'Greater Blessing of Might', 'Greater Blessing of Wisdom',
                                 'Greater Blessing of Salvation']),
]

# the inventory slots of the fixed list (spec, until SpellEquippedItems is exported): back, chest,
# wrist, hands, feet, main hand, shield (the off hand, only when it holds a shield)
FIXED_SLOTS = [15, 5, 9, 10, 8, 16, 17]
SHIELD_SLOT = 17
NEVER_SLOTS = {1, 3, 7}    # head, shoulders, legs: not counted (spec question 4)
# InventoryType -> inventory slot of the worn item
INVTYPE_SLOT = {1: 1, 2: 2, 3: 3, 5: 5, 20: 5, 6: 6, 7: 7, 8: 8, 9: 9, 10: 10, 11: 11, 12: 13, 13: 16, 21: 16, 17: 16,
                14: 17, 22: 17, 23: 17, 15: 18, 26: 18, 16: 15}
ITEM_CLASS_WEAPON, ITEM_CLASS_ARMOR = 2, 4
ARMOR_SUB_SHIELD = 6


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
    m = re.search(r'\.(\d+(?:\.\d+)+)\.csv$', find_table(dirs, 'Item') or '')
    return m.group(1) if m else ''


def load_client(dirs):
    missing = [t for t in REQUIRED if not find_table(dirs, t)]
    if missing:
        raise SystemExit('build_raidcheck: client tables missing in %s: %s (export them with '
                         'tools/export_db2.ps1 -Tables %s)' % (', '.join(dirs), ', '.join(missing), ','.join(missing)))
    return {t: read_table(dirs, t) for t in REQUIRED + OPTIONAL}


def enchant_slots(t, effects_of):
    """The enchanted slots from SpellEquippedItems (None when the tables lack it or say nothing)."""
    equipped, abilities = t.get('SpellEquippedItems'), t.get('SkillLineAbility')
    if not equipped or not abilities:
        return None
    recipes = {num(r.get('Spell')) for r in abilities if num(r.get('SkillLine')) == ENCHANTING}
    recipes = {s for s in recipes if any(num(e.get('Effect')) == EFFECT_ENCHANT_ITEM for e in effects_of.get(s, []))}
    slots = set()
    for r in equipped:
        if num(r.get('SpellID')) not in recipes:
            continue
        cls, sub, inv = num(r.get('EquippedItemClass'), -1), num(r.get('EquippedItemSubclass')), num(r.get('EquippedItemInvTypes'))
        if cls == ITEM_CLASS_WEAPON:
            slots.add(16)
        elif cls == ITEM_CLASS_ARMOR:
            if sub & (1 << ARMOR_SUB_SHIELD) and not inv:
                slots.add(SHIELD_SLOT)
            for bit, slot in INVTYPE_SLOT.items():
                if inv & (1 << bit):
                    slots.add(slot)
    slots -= NEVER_SLOTS
    return [s for s in FIXED_SLOTS if s in slots] + sorted(slots - set(FIXED_SLOTS)) if slots else None


def build(dirs):
    t = load_client(dirs)
    items = {num(r['ID']): r for r in t['Item']}
    effects = {r['ID']: r for r in t['ItemEffect']}
    use = {}
    for r in t['ItemXItemEffect']:
        e = effects.get(r.get('ItemEffectID'))
        if e and num(e.get('SpellID')):
            use.setdefault(num(r['ItemID']), []).append(num(e['SpellID']))
    effects_of = {}
    for r in t['SpellEffect']:
        effects_of.setdefault(num(r['SpellID']), []).append(r)
    durations = {num(r['ID']): num(r.get('Duration')) for r in t['SpellDuration']}
    duration = {}
    for r in t['SpellMisc']:
        duration[num(r['SpellID'])] = durations.get(num(r.get('DurationIndex')), 0)
    names = {num(r['ID']): r.get('Name_lang') or '' for r in t['SpellName']}

    def aura(sid):
        return any(num(e.get('Effect')) == EFFECT_APPLY_AURA for e in effects_of.get(sid, []))

    def long_aura(sid):
        d = duration.get(sid, 0)
        return aura(sid) and (d >= LONG_MS or d < 0)

    def raid_aura(sid):
        """An aura that is not only a utility one (water breathing, detection, ...)."""
        return any(num(e.get('Effect')) == EFFECT_APPLY_AURA and num(e.get('EffectAura')) not in UTILITY_AURAS
                   for e in effects_of.get(sid, []))

    def of_kind(sub):
        return sorted(i for i, r in items.items() if num(r.get('ClassID'), -1) == CONSUMABLE and num(r.get('SubclassID'), -1) == sub)

    flask, elixir, food = {}, {}, {}
    for i in of_kind(SUB_FLASK):
        for sid in use.get(i, []):
            flask.setdefault(sid, i)
    for i in of_kind(SUB_ELIXIR):
        for sid in use.get(i, []):
            if long_aura(sid) and raid_aura(sid):
                elixir.setdefault(sid, i)
    for i in of_kind(SUB_FOOD):
        for first in use.get(i, []):
            todo = [(first, 0)]
            while todo:
                sid, depth = todo.pop()
                if depth > 0 and long_aura(sid):
                    food.setdefault(sid, i)
                if depth < TRIGGER_DEPTH:
                    for e in effects_of.get(sid, []):
                        nxt = num(e.get('EffectTriggerSpell'))
                        if nxt and nxt != sid:
                            todo.append((nxt, depth + 1))
    for sid, name in names.items():
        if name == WELL_FED:
            food.setdefault(sid, 0)
    by_name = {}
    for sid, name in names.items():
        by_name.setdefault(name, []).append(sid)
    buffs = []
    for key, cls, talent, wanted in BUFFS:
        spells = sorted({sid for n in wanted for sid in by_name.get(n, [])})
        buffs.append({'key': key, 'class': cls, 'talent': talent, 'spells': spells})
    slots = enchant_slots(t, effects_of)
    return {'build': build_of(dirs), 'flask': flask, 'elixir': elixir, 'food': food, 'buffs': buffs,
            'slots': slots or list(FIXED_SLOTS), 'slotsFrom': 'table' if slots else 'list'}


def empty_data():
    return {'build': '', 'flask': {}, 'elixir': {}, 'food': {}, 'buffs': [], 'slots': list(FIXED_SLOTS), 'slotsFrom': 'list'}


# ---------------------------------------------------------------- output
def lua_str(s):
    return '"' + str(s).replace('\\', '\\\\').replace('"', '\\"') + '"'


def spell_map(m):
    """{ [spell] = item, ... } in spell order, eight per line."""
    keys = sorted(m)
    if not keys:
        return '{}'
    lines = []
    for k in range(0, len(keys), 8):
        lines.append('        ' + ' '.join('[%d] = %d,' % (s, m[s]) for s in keys[k:k + 8]))
    return '{\n' + '\n'.join(lines) + '\n    }'


def render_lua(data, built=None):
    L = [
        '-- Generated by tools/build_raidcheck.py from the WoW Forever client tables (build %s): Item,' % (data['build'] or '?'),
        '-- ItemEffect, ItemXItemEffect, SpellEffect, SpellMisc, SpellDuration, SpellName (and SpellEquippedItems,',
        '-- SkillLineAbility for the enchanted slots when exported). Do not edit; rebuild instead.',
        '-- flask/elixir/food: [buff spell id] = item id (0: a "Well Fed" spell no item names);',
        '-- buffs: { key, class token, talent 1/0 (counted only when someone in the raid carries it), { spell ids } };',
        '-- slots: the inventory slots an enchanter enchants (%s; slot 17 only with a shield).' % (
            'from SpellEquippedItems' if data['slotsFrom'] == 'table' else 'the fixed list of the spec'),
        'local _, ns = ...',
        '',
        'ns.RAIDCHECK = {',
        '    build = %s, built = %s, slotsFrom = %s, shield = %d,' % (lua_str(data['build']), lua_str(built or time.strftime('%Y-%m-%d')),
                                                                      lua_str(data['slotsFrom']), SHIELD_SLOT),
        '    flask = %s,' % spell_map(data['flask']),
        '    elixir = %s,' % spell_map(data['elixir']),
        '    food = %s,' % spell_map(data['food']),
        '    buffs = {',
    ]
    for b in data['buffs']:
        L.append('        { %s, %s, %d, { %s } },' % (lua_str(b['key']), lua_str(b['class']), 1 if b['talent'] else 0,
                                                    ', '.join(str(s) for s in b['spells'])))
    L += ['    },', '    slots = { %s },' % ', '.join(str(s) for s in data['slots']), '}', '']
    n = len(data['flask']) + len(data['elixir']) + len(data['food'])
    return lua_data.lazy('\n'.join(L), 'RAIDCHECK', n)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--wago', action='append', default=None, help=f'client tables (default {WAGO}); may repeat')
    ap.add_argument('--empty', action='store_true', help='write the file without data')
    ap.add_argument('--out', default=OUT)
    args = ap.parse_args(argv)
    if args.empty:
        data = empty_data()
    else:
        dirs = [os.path.expanduser(d) for d in (args.wago or [WAGO])]
        data = build(dirs)
        if data['slotsFrom'] == 'list':
            print('build_raidcheck: no SpellEquippedItems in the client tables: the fixed slot list '
                  '(export it on the PC: tools/export_db2.ps1 -Tables SpellEquippedItems)', file=sys.stderr)
    with open(args.out, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(render_lua(data))
    print(f"build_raidcheck: {len(data['flask'])} flasks, {len(data['elixir'])} elixirs, {len(data['food'])} food buffs, "
          f"{len(data['buffs'])} class buff groups, slots from the {data['slotsFrom']} -> {os.path.relpath(args.out, ROOT)}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
