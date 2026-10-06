"""Amisia's own gear scoring for WoW Forever: weights derived from game mechanics, stats of items
no scan has seen, item sets, observed random suffixes, the dungeon facts with their bosses' NPC ids,
the guild's drop base stock and the effort per source kind.

    python tools/build_bis.py [--wago DIR] [--measured FILE] [--werte "AMISIA-WERTE ..."]
                              [--sv Amisia.lua] [--att DIR] [--no-att] [--picks FILE]

Runs on the N100; needs no WoW install. Inputs:

  - the client tables as CSV in wago.tools' format (tools/export_db2.ps1 on the PC, or downloaded
    by hand; files named <Table>.<build>.csv; default ~/addons/_wago). Read when present (TABLES):
    ItemSparse, Item, ItemSet, ItemSetSpell, SpellEffect, SpellItemEnchantment, RandPropPoints,
    LFGDungeons, ContentTuning, DungeonEncounter, the weapon damage tables (ItemDamage*), the armour
    tables (ItemArmorQuality, ItemArmorTotal, ItemArmorShield, ArmorLocation) and the item effects
    (ItemXItemEffect, ItemEffect, SpellName, Spell, SpellMisc). Only the columns and rows the build
    uses go to tools/bis_gamedata.json (committed), so a later build runs from that file alone.
    Not in Forever (2026-10-06): ItemRandomProperties, ItemRandomSuffix and every gt* table
    (gtChanceToMeleeCrit, gtChanceToSpellCrit, gtCombatRatings, gtRegenMPPerSpt); the Journal*
    tables are empty. Random suffixes therefore come from observed item links only, and the stat
    conversions (agility or intellect per percent crit, rating per percent, mana per spirit) are
    documented defaults that in-game measurements override (tools/bis_measured.json, see
    load_measured);
  - addon/Amisia/GearData.lua (tools/build_gear.py): items, sources and scanned stats (read only);
  - tools/forever_dungeons.json: the dungeon facts; AllTheThings' Forever data (tools/att_data.py,
    MIT) for the bosses' NPC ids per dungeon;
  - tools/drop_obs.json: the guild's drop records (tools/build_scan.py) for the base stock;
  - the Amisia SavedVariables (default ~/addons/_SavedVariables/Amisia.lua when present): the
    random suffixes the collector saw (scan.suffix) and the item scan (scan.items) for the check of
    the computed stats;
  - tools/bis_picks.json: hand-kept BiS picks (items the scoring alone misses), checked against the
    client tables (check_picks) and written as ns.BIS.PICK and ns.BIS.PI.

Outputs: addon/Amisia/GearWeights.lua (ns.GEAR_WEIGHTS) and addon/Amisia/BisData.lua (ns.BIS).
The scoring formula exists twice, here (score) and in Gear.lua (Gear.Score); tools/tests/
test_score_parity.py holds them equal.
"""
import argparse
import csv
import glob
import json
import math
import os
import re
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

ADDON = os.path.join(ROOT, 'addon', 'Amisia')
GEAR_DATA = os.path.join(ADDON, 'GearData.lua')
GEAR_LUA = os.path.join(ADDON, 'Gear.lua')
OUT_WEIGHTS = os.path.join(ADDON, 'GearWeights.lua')
OUT_BIS = os.path.join(ADDON, 'BisData.lua')
GAMEDATA = os.path.join(HERE, 'bis_gamedata.json')
MEASURED = os.path.join(HERE, 'bis_measured.json')
PICKS = os.path.join(HERE, 'bis_picks.json')
FACTS = os.path.join(HERE, 'forever_dungeons.json')
DROP_ARCHIVE = os.path.join(HERE, 'drop_obs.json')
WAGO = os.path.expanduser('~/addons/_wago')
SV_DEFAULT = os.path.expanduser('~/addons/_SavedVariables/Amisia.lua')

CLASS_ORDER = ['WARRIOR', 'PALADIN', 'HUNTER', 'ROGUE', 'PRIEST', 'SHAMAN', 'MAGE', 'WARLOCK', 'DRUID']
# Upper ends of Gear.COLUMNS: one weight set per level range of the planner.
BRACKETS = [9, 14, 19, 24, 29, 34, 39, 44, 49, 54, 59, 60]
KINDS = ('Speedrun', 'Hardcore')


def log(*a):
    print(*a, file=sys.stderr)


# ---------------------------------------------------------------- client tables (wago CSV)
# Columns kept per table; a table that is missing loses only its part of the build.
TABLES = {
    'ItemSparse': None,          # read through extract_items
    'Item': ('ID', 'ClassID', 'SubclassID', 'InventoryType'),
    'ItemSet': None,
    'ItemSetSpell': ('ItemSetID', 'SpellID', 'Threshold', 'ChrSpecID'),
    'SpellEffect': ('SpellID', 'EffectIndex', 'Effect', 'EffectAura', 'EffectBasePointsF', 'EffectMiscValue_0',
                    'EffectTriggerSpell'),
    'SpellItemEnchantment': None,
    'RandPropPoints': None,
    'LFGDungeons': ('ID', 'Name_lang', 'TypeID', 'ContentTuningID'),
    'ContentTuning': ('ID', 'MinLevelSquish', 'MaxLevelSquish'),   # or MinLevel/MaxLevel (build_dungeons.tuning_levels)
    # weapon damage per second by item level and quality, armour by item level, quality and slot
    'ItemDamageOneHand': None, 'ItemDamageOneHandCaster': None, 'ItemDamageTwoHand': None,
    'ItemDamageTwoHandCaster': None,
    'ItemArmorQuality': None, 'ItemArmorTotal': None, 'ItemArmorShield': None, 'ArmorLocation': None,
    # item effects: item -> effect (trigger, spell) -> the spell's name, tooltip text, school and effects
    'ItemXItemEffect': ('ItemEffectID', 'ItemID'),
    'ItemEffect': ('ID', 'TriggerType', 'SpellID'),
    'SpellName': ('ID', 'Name_lang'),
    'Spell': ('ID', 'Description_lang'),
    'SpellMisc': ('SpellID', 'SchoolMask'),
    'DungeonEncounter': ('ID', 'Name_lang', 'MapID'),
}
# The item damage tables by their key in the game data cache.
DMG_TABLES = {'1H': 'ItemDamageOneHand', '1HC': 'ItemDamageOneHandCaster', '2H': 'ItemDamageTwoHand',
              '2HC': 'ItemDamageTwoHandCaster'}
# ItemEffect TriggerType: 0 on use, 1 on equip, 2 chance on hit, 5 on use without delay (6 teaches a
# recipe and others are no gear effects).
FX_TRIGGERS = (0, 1, 2, 5)
# Tables wago.tools does not publish for Forever: their parts fall back (see the module text).
NOT_ON_WAGO = ('ItemRandomProperties', 'ItemRandomSuffix', 'gtChanceToMeleeCrit', 'gtChanceToMeleeCritBase',
               'gtChanceToSpellCrit', 'gtChanceToSpellCritBase', 'gtCombatRatings', 'gtRegenMPPerSpt')

# Inventory types of wearable gear (no shirt 4, tabard 19, bag 18, ammo 24, quiver 27).
GEAR_INV = {1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 20, 21, 22, 23, 25, 26, 28}
# ItemSparse stat ids (ItemModType) -> the client's stat key as C_Item.GetItemStats names it,
# without ITEM_MOD_ and _SHORT (the form GearData.lua's ST uses). Checked against the scanned stats
# of the 1,678 scanned items the 1.60.1.70235 table holds.
STAT_KEY = {
    3: 'AGILITY', 4: 'STRENGTH', 5: 'INTELLECT', 6: 'SPIRIT', 7: 'STAMINA', 12: 'DEFENSE_SKILL_RATING',
    13: 'DODGE_RATING', 14: 'PARRY_RATING', 15: 'BLOCK_RATING', 16: 'HIT_MELEE_RATING', 17: 'HIT_RANGED_RATING',
    18: 'HIT_SPELL_RATING', 19: 'CRIT_MELEE_RATING', 20: 'CRIT_RANGED_RATING', 21: 'CRIT_SPELL_RATING',
    28: 'HASTE_MELEE_RATING', 29: 'HASTE_RANGED_RATING', 30: 'HASTE_SPELL_RATING', 31: 'HIT_RATING',
    32: 'CRIT_RATING', 35: 'RESILIENCE_RATING', 36: 'HASTE_RATING', 37: 'EXPERTISE_RATING', 38: 'ATTACK_POWER',
    39: 'RANGED_ATTACK_POWER', 41: 'SPELL_HEALING_DONE', 42: 'SPELL_DAMAGE_DONE', 43: 'MANA_REGENERATION',
    45: 'SPELL_POWER', 46: 'HEALTH_REGEN', 47: 'SPELL_PENETRATION', 48: 'BLOCK_VALUE', 85: 'FIRE_DAMAGE_DONE',
    86: 'NATURE_DAMAGE_DONE', 87: 'FROST_DAMAGE_DONE', 88: 'SHADOW_DAMAGE_DONE', 89: 'ARCANE_DAMAGE_DONE',
    50: 'EXTRA_ARMOR', 51: 'FIRE_RESISTANCE', 52: 'FROST_RESISTANCE', 53: 'HOLY_RESISTANCE', 54: 'SHADOW_RESISTANCE',
    55: 'NATURE_RESISTANCE', 56: 'ARCANE_RESISTANCE',
}
# Stats the computation leaves out: resistances are not scored, and the scan's armour already
# holds the extra armour.
SC_UNSCORED = {'EXTRA_ARMOR', 'FIRE_RESISTANCE', 'FROST_RESISTANCE', 'HOLY_RESISTANCE', 'SHADOW_RESISTANCE',
               'NATURE_RESISTANCE', 'ARCANE_RESISTANCE'}
# RandPropPoints column per inventory type: 0 head, chest, legs, two-hand; 1 shoulder, hands, waist,
# feet, trinket; 2 neck, wrist, finger, cloak, off hand, shield, held; 3 one-hand weapons; 4 ranged.
BUDGET_SLOT = {1: 0, 5: 0, 7: 0, 20: 0, 17: 0, 3: 1, 10: 1, 6: 1, 8: 1, 12: 1, 2: 2, 9: 2, 11: 2, 16: 2,
               14: 2, 23: 2, 13: 3, 21: 3, 22: 3, 15: 4, 25: 4, 26: 4, 28: 4}
BUDGET_QUALITY = {2: 'GoodF', 3: 'SuperiorF', 4: 'EpicF', 5: 'EpicF'}
# Computed stats of a kind of item (item_kind) are kept only when the computation matches the scans of
# that kind this often, over at least SC_MIN_CHECKED scanned items.
SC_MIN_RATE = 0.98
SC_MIN_CHECKED = 10
# Armour and jewellery: the inventory types computed_stats takes without any_slot (their allocations
# alone; full_stats adds armour, weapon damage and equip effects for every slot).
SC_INV = {1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 14, 16, 20, 23}


def find_csv(folder, table):
    """The newest <table>.<build>.csv (or <table>.csv) in folder, or None."""
    if not folder or not os.path.isdir(folder):
        return None
    pat = re.compile(r'^' + re.escape(table) + r'(?:\.([\d.]+))?\.csv$')
    found = []
    for name in os.listdir(folder):
        m = pat.match(name)
        if m:
            build = tuple(int(x) for x in (m.group(1) or '0').split('.') if x)
            found.append((build, name))
    if not found:
        return None
    return os.path.join(folder, max(found)[1])


def build_of(path):
    m = re.search(r'\.(\d+\.\d+\.\d+\.\d+)\.csv$', path or '')
    return m.group(1) if m else None


def rows(path):
    # utf-8-sig: a byte order mark (some exports have one) must not become part of the first column's name
    with open(path, encoding='utf-8-sig') as fh:
        yield from csv.DictReader(fh)


def num(v, f=int):
    try:
        return f(v)
    except (TypeError, ValueError):
        try:
            return f(float(v))
        except (TypeError, ValueError):
            return 0


CASTER_FLAG4 = 0x100       # ItemSparse Flags_4: a caster weapon (staves, spell daggers and maces; see DMG_FACTOR)
CASTER_SP_FLAG4 = 0x200    # ... with spell power: 2 * the item's budget (caster_power)
CASTER_HEAL_FLAG4 = 0x400  # ... with spell damage and healing instead (caster_power)
CASTER_FLAGS4 = CASTER_FLAG4 | CASTER_SP_FLAG4 | CASTER_HEAL_FLAG4
# The ability a spell modifier changes, from the (English) tooltip text of its spell.
ABILITY_RE = (re.compile(r"\byour ([A-Z][A-Za-z' ]+?) (?:ability|abilities|spells?|totems?)\b"),
              re.compile(r"\b(?:of|by|for) ([A-Z][A-Za-z']+(?: (?:[A-Z][A-Za-z']+|of|the))*) by\b"))


def ability_of(text):
    for rx in ABILITY_RE:
        m = rx.search(text or '')
        if m:
            return m.group(1).strip()
    return None


def empty_gamedata():
    return {'build': None, 'date': time.strftime('%Y-%m-%d'), 'missing': [], 'items': {}, 'rpp': {}, 'sets': {},
            'setspells': {}, 'spells': {}, 'lfg': {}, 'enchants': {}, 'picks': {}, 'dmg': {}, 'armor': {},
            'effects': {}, 'fx': {}, 'enc': {}}


def extract(folder, pick_ids=(), keep_ids=None):
    """The compact game data of a folder of wago CSVs: {'build', 'date', 'missing': [tables],
    'items': {id: [inventory type, quality, item level, required level, item set, [[stat id,
    allocation], ...], class, subclass (Item table, None without), weapon delay in ms, damage variance,
    caster bits of Flags_4 (CASTER_FLAGS4)]}, 'rpp': {item level: {'GoodF': [5], 'SuperiorF': [5], 'EpicF': [5]}},
    'sets': {id: {'name', 'items'}}, 'setspells': {set id: [[threshold, spell id], ...]},
    'spells': {spell id: [[effect, aura, points, misc], ...]}, 'lfg': {id: [name, min, max]},
    'enchants': {id: [[effect, points, arg], ...]}, 'picks': {id: {'name', 'inv', 'q', 'ilvl', 'req', 'bind',
    'delay' (seconds), 'cls', 'sub', 'mask', 'stats'}}, 'dmg': {'1H'|'1HC'|'2H'|'2HC': {item level: [quality
    0-6]}}, 'armor': {'q': {item level: [7]}, 'total': {item level: [cloth, leather, mail, plate]}, 'shield':
    {item level: [7]}, 'loc': {inventory type: [cloth, leather, mail, plate]}}, 'effects': {item: [[trigger,
    spell], ...]}, 'fx': {spell: {'name', 'vis' (1: the tooltip shows it), 'school', 'e': [[effect, aura,
    points, misc, triggered spell], ...], 'ab' (the ability a modifier changes, when the text names one)}},
    'enc': {encounter: [name, map]}}.
    Items: gear with stats or an item set, and every gear item of keep_ids (the planner's items and the
    picks: weapons and armour need no stats for their damage and armour); picks for the ids of pick_ids
    (tools/bis_picks.json) that ItemSparse holds, whatever they are (the checks judge)."""
    out = empty_gamedata()
    pick_ids = set(pick_ids or ())
    keep_ids = set(keep_ids or ()) | pick_ids
    paths = {t: find_csv(folder, t) for t in TABLES}
    out['missing'] = sorted([t for t, p in paths.items() if not p] + list(NOT_ON_WAGO))
    out['build'] = next((build_of(p) for p in paths.values() if p and build_of(p)), None)
    if paths['ItemSparse']:
        for r in rows(paths['ItemSparse']):
            inv = num(r.get('InventoryType'))
            if num(r.get('ID')) in pick_ids:
                stats = []
                for i in range(10):
                    sid, alloc = num(r.get(f'StatModifier_bonusStat_{i}')), num(r.get(f'StatPercentEditor_{i}'))
                    if sid > 0 and alloc:
                        stats.append([sid, alloc])
                mask = num(r.get('AllowableClass'))
                out['picks'][num(r['ID'])] = {
                    'name': r.get('Display_lang') or '', 'inv': inv, 'q': num(r.get('OverallQualityID')),
                    'ilvl': num(r.get('ItemLevel')), 'req': num(r.get('RequiredLevel')), 'bind': num(r.get('Bonding')),
                    'delay': round(num(r.get('ItemDelay')) / 1000, 2), 'cls': None, 'sub': None,
                    'mask': mask if mask > 0 else 0, 'stats': stats}
            if inv not in GEAR_INV:
                continue
            stats = []
            for i in range(10):
                sid, alloc = num(r.get(f'StatModifier_bonusStat_{i}')), num(r.get(f'StatPercentEditor_{i}'))
                if sid > 0 and alloc:
                    stats.append([sid, alloc])
            # an item without stats or set adds nothing the build computes, unless it is one of the
            # planner's (its damage or armour)
            if stats or num(r.get('ItemSet')) or num(r.get('ID')) in keep_ids:
                out['items'][num(r['ID'])] = [inv, num(r.get('OverallQualityID')), num(r.get('ItemLevel')),
                                              num(r.get('RequiredLevel')), num(r.get('ItemSet')), stats, None, None,
                                              num(r.get('ItemDelay')), round(num(r.get('DmgVariance'), float), 4),
                                              num(r.get('Flags_4')) & CASTER_FLAGS4]
    if paths['Item'] and (out['picks'] or out['items']):
        for r in rows(paths['Item']):
            iid = num(r.get('ID'))
            p = out['picks'].get(iid)
            if p is not None:
                p['cls'], p['sub'] = num(r.get('ClassID')), num(r.get('SubclassID'))
            it = out['items'].get(iid)
            if it is not None:
                it[6], it[7] = num(r.get('ClassID')), num(r.get('SubclassID'))
    for key, table in DMG_TABLES.items():
        if paths[table]:
            out['dmg'][key] = {num(r.get('ItemLevel')): [round(num(r.get(f'Quality_{q}'), float), 6) for q in range(7)]
                               for r in rows(paths[table])}
    if paths['ItemArmorQuality'] and paths['ItemArmorTotal'] and paths['ArmorLocation']:
        out['armor']['q'] = {num(r['ID']): [round(num(r.get(f'Qualitymod_{q}'), float), 4) for q in range(7)]
                             for r in rows(paths['ItemArmorQuality'])}
        out['armor']['total'] = {num(r.get('ItemLevel')): [round(num(r.get(c), float), 4)
                                                           for c in ('Cloth', 'Leather', 'Mail', 'Plate')]
                                 for r in rows(paths['ItemArmorTotal'])}
        out['armor']['loc'] = {num(r['ID']): [round(num(r.get(c), float), 4) for c in ('Clothmodifier',
                                                                                    'Leathermodifier',
                                                                                    'Chainmodifier', 'Platemodifier')]
                               for r in rows(paths['ArmorLocation'])}
        if paths['ItemArmorShield']:
            out['armor']['shield'] = {num(r.get('ItemLevel')): [round(num(r.get(f'Quality_{q}'), float), 4)
                                                                for q in range(7)]
                                      for r in rows(paths['ItemArmorShield'])}
    if paths['RandPropPoints']:
        for r in rows(paths['RandPropPoints']):
            out['rpp'][num(r['ID'])] = {q: [round(num(r.get(f'{q}_{i}'), float), 4) for i in range(5)]
                                       for q in ('GoodF', 'SuperiorF', 'EpicF')}
    if paths['ItemSet']:
        for r in rows(paths['ItemSet']):
            items = [num(r.get(f'ItemID_{i}')) for i in range(17)]
            items = [i for i in items if i > 0]
            if len(items) >= 2:
                out['sets'][num(r['ID'])] = {'name': r.get('Name_lang') or '', 'items': items}
    wanted = set()
    if paths['ItemSetSpell']:
        for r in rows(paths['ItemSetSpell']):
            sid = num(r.get('ItemSetID'))
            if sid in out['sets']:
                out['setspells'].setdefault(sid, []).append([num(r.get('Threshold')), num(r.get('SpellID'))])
                wanted.add(num(r.get('SpellID')))
        for v in out['setspells'].values():
            v.sort()
    # the effects of the kept items (and picks): which spell, on use, on equip or by chance on hit
    fx_spells = set()
    if paths['ItemXItemEffect'] and paths['ItemEffect'] and (out['items'] or out['picks']):
        effect = {num(r['ID']): (num(r.get('TriggerType')), num(r.get('SpellID'))) for r in rows(paths['ItemEffect'])}
        links = sorted((num(r['ID']), num(r.get('ItemID')), num(r.get('ItemEffectID')))
                       for r in rows(paths['ItemXItemEffect']))
        for _, iid, eid in links:
            if (iid in out['items'] or iid in out['picks']) and eid in effect:
                trig, spell = effect[eid]
                if trig in FX_TRIGGERS and spell > 0:
                    out['effects'].setdefault(iid, []).append([trig, spell])
                    fx_spells.add(spell)
    if paths['SpellEffect'] and (wanted or fx_spells):
        by_spell = {}
        for r in rows(paths['SpellEffect']):
            sp = num(r.get('SpellID'))
            by_spell.setdefault(sp, []).append((num(r.get('EffectIndex')), [
                num(r.get('Effect')), num(r.get('EffectAura')), num(r.get('EffectBasePointsF'), float),
                num(r.get('EffectMiscValue_0')), num(r.get('EffectTriggerSpell'))]))
        for sp in by_spell:
            by_spell[sp] = [e for _, e in sorted(by_spell[sp], key=lambda x: x[0])]
        for sp in wanted:
            if sp in by_spell:
                out['spells'][sp] = [e[:4] for e in by_spell[sp]]
        # an item's spell and the spells it triggers (a proc's effect), one step deep
        todo = set(fx_spells)
        for sp in list(fx_spells):
            todo |= {e[4] for e in by_spell.get(sp, []) if e[4] > 0}
        names = {num(r['ID']): r.get('Name_lang') or '' for r in rows(paths['SpellName'])} if paths['SpellName'] else {}
        texts = {num(r['ID']): r.get('Description_lang') or '' for r in rows(paths['Spell'])} if paths['Spell'] else {}
        school = {num(r.get('SpellID')): num(r.get('SchoolMask')) for r in rows(paths['SpellMisc'])} \
            if paths['SpellMisc'] else {}
        for sp in sorted(todo):
            rec = {'name': names.get(sp, ''), 'vis': 1 if texts.get(sp, '').strip() else 0,
                   'school': school.get(sp, 0), 'e': [[e[0], e[1], round(e[2], 4), e[3], e[4]] for e in by_spell.get(sp, [])]}
            ab = ability_of(texts.get(sp))
            if ab and any(e[1] in (AURA_ADD_FLAT, AURA_ADD_PCT) for e in rec['e']):
                rec['ab'] = ab
            out['fx'][sp] = rec
    if paths['DungeonEncounter']:
        for r in rows(paths['DungeonEncounter']):
            eid = num(r.get('ID'))
            if eid > 0 and eid not in out['enc']:
                out['enc'][eid] = [r.get('Name_lang') or '', num(r.get('MapID'))]
    if paths['SpellItemEnchantment']:
        # the stat enchantments (effect 5); a random property or suffix points at them, once the
        # tables that link the two exist for Forever
        for r in rows(paths['SpellItemEnchantment']):
            effs = []
            for i in range(3):
                e = num(r.get(f'Effect_{i}'))
                if e == 5:
                    effs.append([e, num(r.get(f'EffectPointsMin_{i}')), num(r.get(f'EffectArg_{i}'))])
            if effs:
                out['enchants'][num(r['ID'])] = effs
    # one reader for ContentTuning with tools/build_dungeons.py (squished levels in Forever)
    import build_dungeons
    tuning = build_dungeons.tuning_levels(rows(paths['ContentTuning'])) if paths['ContentTuning'] else {}
    if paths['LFGDungeons']:
        for r in rows(paths['LFGDungeons']):
            if num(r.get('TypeID')) in (0, 2):
                lo, hi = tuning.get(num(r.get('ContentTuningID')), (0, 0))
                out['lfg'][num(r['ID'])] = [r.get('Name_lang') or '', lo, hi]
    return out


NESTED = ('dmg', 'armor')   # {name: {int: ...}} in the cache


def save_gamedata(gd, path=GAMEDATA):
    def keyed(d):
        return {str(k): v for k, v in sorted(d.items())}
    data = {k: (keyed(v) if isinstance(v, dict) and k not in ('date',) + NESTED else v) for k, v in gd.items()}
    for k in NESTED:
        data[k] = {name: keyed(t) for name, t in sorted((gd.get(k) or {}).items())}
    with open(path, 'w', encoding='utf-8', newline='\n') as fh:
        json.dump(data, fh, ensure_ascii=False, sort_keys=True, separators=(',', ':'))
        fh.write('\n')


def load_gamedata(path=GAMEDATA):
    if not os.path.exists(path):
        return None
    with open(path, encoding='utf-8') as fh:
        raw = json.load(fh)
    for k in ('items', 'rpp', 'sets', 'setspells', 'spells', 'lfg', 'enchants', 'picks', 'effects', 'fx', 'enc'):
        raw[k] = {int(i): v for i, v in (raw.get(k) or {}).items()}
    for k in NESTED:
        raw[k] = {name: {int(i): v for i, v in t.items()} for name, t in (raw.get(k) or {}).items()}
    # a cache of an older build: items without class, subclass, delay, variance and caster flag
    for it in raw['items'].values():
        it.extend([None, None, 0, 0, 0][len(it) - 6:] if len(it) < 11 else [])
    return raw


# ---------------------------------------------------------------- stat conversions
# Classic's rules as Forever is expected to keep them; none of these comes from a client table
# (Forever has no gt tables on wago). Every value can be replaced by an in-game measurement
# (tools/bis_measured.json). "per percent" numbers are at level 60; lower levels scale by
# max(level, 10) / 60, Classic's roughly linear curve.
RATING_60 = {'HIT': 10, 'SHIT': 8, 'CRIT': 14, 'HASTE': 10, 'EXP': 10, 'DODGE': 12, 'PARRY': 15, 'BLOCK': 5, 'DEF': 1.5}
AGI_PER_CRIT_60 = {'WARRIOR': 20, 'PALADIN': 20, 'HUNTER': 53, 'ROGUE': 29, 'PRIEST': 20, 'SHAMAN': 20, 'MAGE': 20,
                   'WARLOCK': 20, 'DRUID': 20}
INT_PER_CRIT_60 = {'WARRIOR': 60, 'PALADIN': 54, 'HUNTER': 60, 'ROGUE': 60, 'PRIEST': 59.2, 'SHAMAN': 59.2,
                   'MAGE': 59.5, 'WARLOCK': 60.6, 'DRUID': 60}
# base crit chance in percent before agility / intellect (Classic, roughly)
BASE_CRIT = {'WARRIOR': 0, 'PALADIN': 0.7, 'HUNTER': 0, 'ROGUE': 0, 'PRIEST': 3, 'SHAMAN': 1.7, 'MAGE': 0.2,
             'WARLOCK': 1.7, 'DRUID': 0.9}
BASE_SPELL_CRIT = {'WARRIOR': 0, 'PALADIN': 3.3, 'HUNTER': 3.6, 'ROGUE': 0, 'PRIEST': 0.8, 'SHAMAN': 2.3, 'MAGE': 0.2,
                   'WARLOCK': 1.7, 'DRUID': 1.8}
# mana per point of spirit per five seconds outside the five-second rule (Classic: 13 + spirit / 4
# per two-second tick for priests and mages, 15 + spirit / 5 for the others)
MANA_PER_SPIRIT_5 = {'PRIEST': 0.625, 'MAGE': 0.625, 'PALADIN': 0.5, 'HUNTER': 0.5, 'SHAMAN': 0.5, 'WARLOCK': 0.5,
                     'DRUID': 0.5, 'WARRIOR': 0, 'ROGUE': 0}
# base attributes at level 60 (level 1: 20 each, linear between)
BASE_60 = {
    'WARRIOR': {'STR': 120, 'AGI': 80, 'STA': 110, 'INT': 30, 'SPI': 45},
    'PALADIN': {'STR': 105, 'AGI': 70, 'STA': 100, 'INT': 65, 'SPI': 70},
    'HUNTER': {'STR': 55, 'AGI': 120, 'STA': 90, 'INT': 60, 'SPI': 65},
    'ROGUE': {'STR': 85, 'AGI': 130, 'STA': 75, 'INT': 35, 'SPI': 50},
    'PRIEST': {'STR': 35, 'AGI': 40, 'STA': 50, 'INT': 120, 'SPI': 125},
    'SHAMAN': {'STR': 85, 'AGI': 55, 'STA': 95, 'INT': 90, 'SPI': 100},
    'MAGE': {'STR': 30, 'AGI': 35, 'STA': 45, 'INT': 125, 'SPI': 120},
    'WARLOCK': {'STR': 45, 'AGI': 50, 'STA': 75, 'INT': 110, 'SPI': 115},
    'DRUID': {'STR': 60, 'AGI': 60, 'STA': 70, 'INT': 100, 'SPI': 110},
}
HP_FACTOR = {'WARRIOR': 1.0, 'PALADIN': 0.95, 'HUNTER': 0.9, 'ROGUE': 0.9, 'PRIEST': 0.8, 'SHAMAN': 0.9, 'MAGE': 0.8,
             'WARLOCK': 0.85, 'DRUID': 0.9}


class Conv:
    """The conversions in use: the defaults above, corrected by measurements.

    A measurement corrects a class's curve by its ratio to the default at that level (the shape
    stays Classic's: per percent grows with max(level, 10) / 60; the size is Forever's). A class
    nobody measured takes the mean ratio of the measured classes: the best estimate until it is
    measured itself (assumption: Forever changed the curve by one factor for every class). The base
    crit (crit at 0 agility or intellect, talents included) of a measured class replaces the
    Classic base for that class at every level."""

    def __init__(self, measured=None):
        m = measured or {}
        self.rating60 = dict(RATING_60)
        self.rating60.update({k: float(v) for k, v in (m.get('rating60') or {}).items() if k in RATING_60})
        self.agi_scale = {c: float(v) for c, v in (m.get('agiPerCritScale') or {}).items()}
        self.int_scale = {c: float(v) for c, v in (m.get('intPerCritScale') or {}).items()}
        mean = lambda d: sum(d.values()) / len(d) if d else 1.0  # noqa: E731
        self.agi_default, self.int_default = mean(self.agi_scale), mean(self.int_scale)
        self.base_crit_m = {c: float(v) for c, v in (m.get('baseCrit') or {}).items()}
        self.base_spell_crit_m = {c: float(v) for c, v in (m.get('baseSpellCrit') or {}).items()}
        self.spirit = dict(MANA_PER_SPIRIT_5)
        self.spirit.update({c: float(v) for c, v in (m.get('manaPerSpirit5') or {}).items()})
        self.sources = list(m.get('sources') or [])

    def base_crit(self, cls):
        return self.base_crit_m.get(cls, BASE_CRIT[cls])

    def base_spell_crit(self, cls):
        return self.base_spell_crit_m.get(cls, BASE_SPELL_CRIT[cls])

    def rating_pp(self, kind, level):
        """Percent per point of rating (per skill point for DEF), as Gear.lua's ratingPerPoint."""
        scale = 2 / 52 if level <= 10 else (min(level, 60) - 8) / 52
        return 1 / (self.rating60[kind] * scale)

    def agi_per_crit(self, cls, level):
        return AGI_PER_CRIT_60[cls] * max(level, 10) / 60 * self.agi_scale.get(cls, self.agi_default)

    def int_per_crit(self, cls, level):
        return INT_PER_CRIT_60[cls] * max(level, 10) / 60 * self.int_scale.get(cls, self.int_default)


# The self-test's rating pairs ("<rating>,<bonus %>") -> rating kinds of RATING_60.
WERTE_RATINGS = {'hm': 'HIT', 'hs': 'SHIT', 'cm': 'CRIT', 'am': 'HASTE', 'exp': 'EXP', 'dr': 'DODGE', 'pr': 'PARRY',
                 'br': 'BLOCK', 'def': 'DEF'}
WERTE_STATS = {'str': 'str', 'agi': 'agi', 'sta': 'sta', 'int': 'int', 'spi': 'spi'}


def parse_werte(text):
    """One sample from the self-test's line (SelfTest.lua, section "Werte"):

        AMISIA-WERTE 1 SHAMAN 18 race=Orc hp=509 mana=553 str=53,53,15,0 agi=35,35,11,0 ...
            crit=11.563 rcrit=2.403 sc2=10.2516 ... dodge=5.483 parry=0 block=4.8 ap=156,0,0
            hm=0,0 hs=0,0 cm=0,0 ... dr=0,0 pr=0,0 br=0,0 exp=0,0

    After the tag: the line's version, the class and the level. Attributes are UnitStat's
    base,effective,plus,minus (the effective value counts); crit is the melee crit chance, sc2 the
    spell crit (sc2..sc7 per school, all alike); a rating pair is <rating>,<bonus %>
    (GetCombatRatingBonus). Older test form: cr_<KIND>=<rating>:<bonus>, spellcrit=. Unknown
    tokens are skipped."""
    sample = {'ratings': {}}
    positional = []
    for tok in re.split(r'[\s;]+', str(text or '').strip()):
        if not tok or tok == 'AMISIA-WERTE':
            continue
        k, eq, v = tok.partition('=')
        if not eq:
            positional.append(tok)
            continue
        k = k.lower()
        nums = []
        for part in re.split(r'[,:]', v):
            try:
                x = float(part)
            except ValueError:
                x = None
            # float() takes nan, inf and 1e400: never a measured value
            nums.append(x if x is not None and math.isfinite(x) else None)
        if k.startswith('cr_') and len(nums) >= 2 and None not in nums[:2]:
            sample['ratings'][k[3:].upper()] = nums[:2]
        elif k in WERTE_RATINGS and len(nums) >= 2 and None not in nums[:2]:
            sample['ratings'][WERTE_RATINGS[k]] = nums[:2]
        elif k in WERTE_STATS and nums and nums[0] is not None:
            # base,effective,plus,minus: the effective value
            sample[WERTE_STATS[k]] = nums[1] if len(nums) > 1 and nums[1] is not None else nums[0]
        elif k == 'class':
            sample['class'] = v.upper()
        elif k == 'race':
            sample['race'] = v
        elif k in ('level', 'crit', 'spellcrit', 'rcrit', 'dodge', 'parry', 'block', 'hp', 'mana', 'apstr', 'apagi', 'regen') \
                and nums and nums[0] is not None:
            sample[k] = nums[0]
        elif k.startswith('sc2') and nums and nums[0] is not None:
            sample['spellcrit'] = nums[0]
        elif k == 'ap' and nums and nums[0] is not None:
            sample['ap'] = nums[0]
    # positional: version, class, level
    words = [p for p in positional if re.match(r'^[A-Z]+$', p)]
    numbers = [p for p in positional if re.match(r'^\d+$', p)]
    if words and 'class' not in sample:
        sample['class'] = words[0]
    if len(numbers) >= 2 and 'level' not in sample:
        sample['level'] = float(numbers[1])
    elif len(numbers) == 1 and 'level' not in sample and not words:
        sample['level'] = float(numbers[0])
    return sample


def werte_problem(sample):
    """Why a sample cannot be used (a text), or None: it needs a known class and a whole level
    of 1-60, and every number in it finite."""
    if not isinstance(sample, dict):
        return 'not a sample'
    if sample.get('class') not in CLASS_ORDER:
        return f"unknown class {sample.get('class')!r}"
    lvl = sample.get('level')
    if not isinstance(lvl, (int, float)) or isinstance(lvl, bool) or not math.isfinite(lvl) \
            or lvl != int(lvl) or not 1 <= lvl <= 60:
        return f'level {lvl!r} is not a whole number of 1-60'
    for k, v in sample.items():
        if isinstance(v, float) and not math.isfinite(v):
            return f'{k} is not finite'
    for kind, pair in (sample.get('ratings') or {}).items():
        if not isinstance(pair, (list, tuple)) or len(pair) < 2 or \
                not all(isinstance(x, (int, float)) and math.isfinite(x) for x in pair[:2]):
            return f'rating {kind} is not a pair of finite numbers'
    return None


def derive_measured(samples):
    """Overrides from raw samples.

    - Rating per percent at 60 from any pair with a rating (rating / bonus, scaled by the level
      curve): one sample pins it.
    - Agility (intellect) per percent crit only from two samples of the same class and level with
      different agility (intellect): the slope. One sample cannot separate the base crit from the
      ratio, so it changes nothing (it stays in the file as a check, see `unpinned`)."""
    out = {'rating60': {}, 'agiPerCritScale': {}, 'intPerCritScale': {}, 'baseCrit': {}, 'baseSpellCrit': {}, 'sources': [],
           'unpinned': []}
    base = Conv()
    groups = {}
    for s in samples:
        if werte_problem(s):
            continue
        lvl, cls = s.get('level'), s.get('class')
        lvl = int(lvl)
        scale = 2 / 52 if lvl <= 10 else (min(lvl, 60) - 8) / 52
        for kind, (rating, bonus) in (s.get('ratings') or {}).items():
            if kind in RATING_60 and rating > 0 and bonus > 0:
                out['rating60'][kind] = round(rating / bonus / scale, 3)
        out['sources'].append(f"{cls or '?'} {lvl}")
        if cls in AGI_PER_CRIT_60:
            groups.setdefault((cls, lvl), []).append(s)
    for (cls, lvl), group in sorted(groups.items()):
        pinned = False
        for stat, chance, key, bkey, default in (('agi', 'crit', 'agiPerCritScale', 'baseCrit', base.agi_per_crit),
                                                 ('int', 'spellcrit', 'intPerCritScale', 'baseSpellCrit', base.int_per_crit)):
            pts = sorted({(g[stat], g[chance]) for g in group if g.get(stat) is not None and g.get(chance) is not None})
            if len(pts) >= 2 and pts[-1][0] != pts[0][0] and pts[-1][1] != pts[0][1]:
                per = (pts[-1][0] - pts[0][0]) / (pts[-1][1] - pts[0][1])
                if per > 0:
                    out[key][cls] = round(per / default(cls, lvl), 4)
                    # the crit at none of the stat: base and talents of this character
                    out[bkey][cls] = round(pts[-1][1] - pts[-1][0] / per, 3)
                    pinned = True
        # mana per spirit: GetManaRegen's base value (per second) between two samples with
        # different spirit, times five for the five-second unit of the weights
        pts = sorted({(g['spi'], g['regen']) for g in group if g.get('spi') is not None and g.get('regen') is not None})
        if len(pts) >= 2 and pts[-1][0] != pts[0][0] and pts[-1][1] > pts[0][1]:
            out.setdefault('manaPerSpirit5', {})[cls] = round(5 * (pts[-1][1] - pts[0][1]) / (pts[-1][0] - pts[0][0]), 4)
            pinned = True
        if not pinned:
            out['unpinned'].append(f'{cls} {lvl}')
    return out


def load_measured(path=MEASURED):
    """tools/bis_measured.json: {"overrides": {"rating60": {...}, "agiPerCritScale": {class: f},
    "intPerCritScale": {...}, "manaPerSpirit5": {...}}, "samples": [sample, ...]} (both optional).
    Samples are raw in-game values (see parse_werte); direct overrides win over derived ones."""
    if not path or not os.path.exists(path):
        return {}
    with open(path, encoding='utf-8') as fh:
        raw = json.load(fh)
    # a sample with its original line is read again, so a better parser reaches old samples too
    samples = []
    for s in raw.get('samples') or []:
        if isinstance(s, dict) and s.get('line'):
            s = parse_werte(s['line'])
        why = werte_problem(s)
        if why:
            log(f'{os.path.basename(path)}: sample skipped ({why})')
            continue
        samples.append(s)
    out = derive_measured(samples)
    for k, v in (raw.get('overrides') or {}).items():
        if isinstance(v, dict):
            out.setdefault(k, {}).update(v)
    return out


# ---------------------------------------------------------------- the item data (GearData.lua)
def lua_to_py(v):
    if not hasattr(v, 'items'):
        return v
    keys = list(v.keys())
    if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
        return [lua_to_py(v[k]) for k in range(1, len(keys) + 1)]
    return {k: lua_to_py(v[k]) for k in keys}


def load_gear(path=GEAR_DATA):
    """ns.GEAR of a GearData.lua as Python: {'I': {id: row}, 'S': [records], 'ST': {id: text}, ...}."""
    from lupa.lua51 import LuaRuntime
    lua = LuaRuntime(unpack_returned_tuples=True)
    with open(path, encoding='utf-8') as fh:
        src = fh.read()
    ns = lua.eval('{}')
    lua.eval('function(s, ns) return assert(loadstring(s))("Amisia", ns) end')(src, ns)
    g = ns.GEAR

    def array(t):
        # records hold nils (a world drop without a mob): a list with None in the holes
        keys = [k for k in t.keys() if isinstance(k, int)]
        return [t[i] for i in range(1, max(keys) + 1)] if keys else []
    out = {'I': {}, 'S': [], 'ST': {}, 'built': g.built}
    for k, v in g.I.items():
        out['I'][int(k)] = array(v)
    n = 0
    while g.S[n + 1] is not None:
        n += 1
        out['S'].append(array(g.S[n]))
    if g.ST:
        for k, v in g.ST.items():
            out['ST'][int(k)] = str(v)
    return out


def gear_stat_map(path=GEAR_LUA):
    """Gear.lua's STAT table: client key (without ITEM_MOD_ and _SHORT) -> scoring key."""
    with open(path, encoding='utf-8') as fh:
        src = fh.read()
    block = src[src.index('local STAT = {'):src.index('Gear.STAT = STAT')]
    out = {}
    for k, v in re.findall(r'\b([A-Z][A-Z0-9_]+) = "([A-Z_0-9]+)"', block):
        out[re.sub(r'^ITEM_MOD_|_SHORT$', '', k)] = v
    return out


def parse_stats(text, stat_map):
    """'STRENGTH=5;STAMINA=3' -> {'STR': 5, 'STA': 3} (as Gear.ScannedStats)."""
    s = {}
    for part in (text or '').split(';'):
        k, _, v = part.partition('=')
        key = stat_map.get(k)
        try:
            v = float(v)
        except ValueError:
            continue
        if key and v:
            s[key] = s.get(key, 0) + v
    return s


def computed_stats(gd, iid, any_slot=False):
    """{client key: value} of an item from ItemSparse's allocations and RandPropPoints' budget, or
    None when the tables cannot say (unknown item, quality, item level or stat). Armour and jewellery
    only (SC_INV), any_slot: every slot (full_stats adds armour, damage and equip effects)."""
    it = gd['items'].get(iid)
    if not it:
        return None
    inv, q, ilvl, _, _, stats = it[:6]
    if inv not in SC_INV and not any_slot:
        return None
    if not stats:
        return {}
    col, budget_row = BUDGET_QUALITY.get(q), gd['rpp'].get(ilvl)
    if col is None or budget_row is None or inv not in BUDGET_SLOT:
        return None
    budget = budget_row[col][BUDGET_SLOT[inv]]
    out = {}
    for sid, alloc in stats:
        key = STAT_KEY.get(sid)
        if key is None or key in SC_UNSCORED:
            # an unknown stat id is left out; the check against the scans shows whether it mattered
            continue
        v = math.floor(alloc * budget / 10000 + 0.5)
        if v:
            out[key] = out.get(key, 0) + v
    return out


def stat_text(d):
    return ';'.join(f'{k}={v:g}' for k, v in sorted(d.items()))


# ---------------------------------------------------------------- weapon damage and armour
# The client's weapon damage: damage per second of the item's level and quality (ItemDamage* table of
# its kind), average hit = DPS * speed, minimum = floor(average * (1 - variance / 2)), maximum =
# floor(average * (1 + variance / 2) + 0.5); the tooltip's DPS is (minimum + maximum) / 2 / speed.
# What Forever's base data (1.60.1.70235, exported without the client's hotfixes) does not say,
# measured on 2026-10-06 against the scanned items (C_Item.GetItemStats, the player's SavedVariables;
# every factor reproduces the scans to the hundredth over all item levels, see tools/README.md):
# - caster weapons (Flags_4 & 0x100): the caster tables are copies of the melee tables in that data;
#   the scans are 2/3 of the one-hand and 0.7435 of the two-hand table. A caster table that differs
#   from the melee one (an export with the hotfixes) is taken as it is, without a factor;
# - bows, guns and crossbows: 0.6 of the two-hand table (no ranged table exists any more);
# - thrown weapons: 0.9 of the one-hand table;
# - wands follow none of the tables (1.3 to 1.5 times the one-hand one, changing with the level): no
#   damage, so no computed stats.
DMG_FACTOR = {'1HC': 2 / 3, '2HC': 0.7435, 'ranged': 0.6, 'thrown': 0.9}
WEAPON_INV_1H, WEAPON_INV_RANGED = (13, 21, 22), (15, 26)
SUB_BOW, SUB_GUN, SUB_CROSSBOW, SUB_THROWN, SUB_WAND = 2, 3, 18, 16, 19


def weapon_kind(gd, iid):
    """'1H', '1HC' (caster), '2H', '2HC', 'ranged' (bow, gun, crossbow), 'thrown', 'wand', or None for
    no weapon or an unknown class (no Item table)."""
    it = gd['items'].get(iid)
    if not it or it[6] != 2:
        return None
    inv, sub, caster = it[0], it[7], it[10] & CASTER_FLAG4
    if sub == SUB_WAND:
        return 'wand'
    if sub == SUB_THROWN:
        return 'thrown'
    if sub in (SUB_BOW, SUB_GUN, SUB_CROSSBOW):
        return 'ranged'
    if inv == 17:
        return '2HC' if caster else '2H'
    if inv in WEAPON_INV_1H:
        return '1HC' if caster else '1H'
    return None


def weapon_damage(gd, iid):
    """(minimum, maximum, damage per second) of a weapon as the client computes it, or None (no weapon,
    a wand, no delay, or the tables lack the item level)."""
    kind = weapon_kind(gd, iid)
    it = gd['items'].get(iid)
    if kind is None or kind == 'wand' or not it[8]:
        return None
    q, ilvl, delay, var = it[1], it[2], it[8] / 1000, it[9]
    dmg = gd.get('dmg') or {}
    table, factor = {'1H': ('1H', 1), '2H': ('2H', 1), '1HC': ('1HC', None), '2HC': ('2HC', None),
                     'ranged': ('2H', DMG_FACTOR['ranged']), 'thrown': ('1H', DMG_FACTOR['thrown'])}[kind]
    row = (dmg.get(table) or {}).get(ilvl)
    if row is None or not 0 <= q < len(row):
        return None
    if factor is None:
        melee = (dmg.get(table[:2]) or {}).get(ilvl)
        factor = DMG_FACTOR[kind] if melee == row else 1
    avg = row[q] * factor * delay
    lo = math.floor(avg * (1 - var / 2))
    hi = math.floor(avg * (1 + var / 2) + 0.5)
    return lo, hi, (lo + hi) / 2 / delay


def caster_power(gd, iid):
    """The spell power a caster weapon carries without an allocation (client keys): b = the item's
    budget of its level and quality in RandPropPoints' first column (one- and two-handers alike);
    Flags_4 & 0x200: SPELL_POWER = 2 * b; Flags_4 & 0x400 (healing weapons): SPELL_DAMAGE_DONE =
    floor(2 * b * 0.625) and SPELL_HEALING_DONE = floor(2 * b * 1.88). Measured 2026-10-06 against
    every scanned caster weapon of the player's SavedVariables (exact). {} for any other item."""
    it = gd['items'].get(iid)
    flags = it[10] if it else 0
    if not flags & (CASTER_SP_FLAG4 | CASTER_HEAL_FLAG4):
        return {}
    col, budget_row = BUDGET_QUALITY.get(it[1]), gd['rpp'].get(it[2])
    if col is None or budget_row is None:
        return {}
    power = 2 * budget_row[col][0]
    if flags & CASTER_SP_FLAG4:
        return {'SPELL_POWER': int(power)}
    return {'SPELL_DAMAGE_DONE': math.floor(power * 0.625 + 1e-9), 'SPELL_HEALING_DONE': math.floor(power * 1.88 + 1e-9)}


ARMOUR_SUB = {1: 0, 2: 1, 3: 2, 4: 3}   # Item subclass (cloth, leather, mail, plate) -> column
SUB_SHIELD = 6
INV_ROBE, INV_CHEST = 20, 5


def extra_armour(gd, iid):
    """The extra armour of an item's allocations (stat 50), as computed_stats computes stats; None when
    the budget is unknown."""
    it = gd['items'].get(iid)
    inv, q, ilvl, stats = it[0], it[1], it[2], it[5]
    allocs = [a for sid, a in stats if sid == 50]
    if not allocs:
        return 0
    col, budget_row = BUDGET_QUALITY.get(q), gd['rpp'].get(ilvl)
    if col is None or budget_row is None or inv not in BUDGET_SLOT:
        return None
    budget = budget_row[col][BUDGET_SLOT[inv]]
    return sum(math.floor(a * budget / 10000 + 0.5) for a in allocs)


def armour_value(gd, iid):
    """The armour of an item as the client computes it: quality factor * the material's total of the
    item level * the slot's share, rounded (ItemArmorQuality, ItemArmorTotal, ArmorLocation; a robe
    counts as a chest); shields their ItemArmorShield value of level and quality, rounded (no quality
    factor: checked against the scans); plus the extra armour of the allocations (rings and weapons
    have that alone). 0 for an item without armour, None when the tables or the item's class are
    missing."""
    it = gd['items'].get(iid)
    if not it:
        return None
    arm = gd.get('armor') or {}
    cls, sub, inv, q, ilvl = it[6], it[7], it[0], it[1], it[2]
    if cls is None:
        return None
    extra = extra_armour(gd, iid)
    if extra is None:
        return None
    if cls != 4 or (sub not in ARMOUR_SUB and sub != SUB_SHIELD):
        return extra
    if not arm.get('q') or not arm.get('total'):
        return None
    if sub == SUB_SHIELD:
        row = (arm.get('shield') or {}).get(ilvl)
        if row is None or not 0 <= q < len(row):
            return None
        return math.floor(row[q] + 0.5) + extra
    qrow, total, loc = arm['q'].get(ilvl), arm['total'].get(ilvl), arm['loc'].get(INV_CHEST if inv == INV_ROBE else inv)
    if qrow is None or total is None or loc is None or not 0 <= q < len(qrow):
        return None
    col = ARMOUR_SUB[sub]
    return math.floor(qrow[q] * total[col] * loc[col] + 0.5) + extra


# ---------------------------------------------------------------- item effects (ItemEffect, SpellEffect)
# Auras of plain stats (SpellEffect effect 6 = apply aura); set bonuses (set_bonus_text) and equip effects
# (item_effects) read them alike.
AURA_MOD_STAT, AURA_MOD_RESISTANCE, AURA_MOD_DAMAGE_DONE, AURA_MOD_HEALING_DONE = 29, 22, 13, 135
AURA_MOD_AP, AURA_MOD_RAP, AURA_MOD_POWER_REGEN, AURA_MOD_RATING = 99, 124, 85, 189
AURA_MOD_TARGET_RESISTANCE = 123
AURA_PROC_TRIGGER, AURA_PERIODIC_DAMAGE, AURA_PERIODIC_HEAL, AURA_DAMAGE_SHIELD = 42, 3, 8, 15
AURA_ADD_FLAT, AURA_ADD_PCT, AURA_MOD_SPEED, AURA_MOD_DECREASE_SPEED, AURA_SCHOOL_ABSORB = 107, 108, 31, 33, 69
AURA_MOD_SPEED_ALWAYS = 129
STAT_OF_MISC = {0: 'STRENGTH', 1: 'AGILITY', 2: 'STAMINA', 3: 'INTELLECT', 4: 'SPIRIT'}
# Percent bonuses (hit, crit, spell hit and crit) and defence skill, written as the rating that gives
# the same at level 60 (RATING_60): set bonuses are worn at the end of the levelling, and the
# addon scores ratings already.
AURA_PCT = {54: ('HIT_MELEE_RATING', 'HIT'), 55: ('HIT_SPELL_RATING', 'SHIT'),
            52: ('CRIT_MELEE_RATING', 'CRIT'), 57: ('CRIT_SPELL_RATING', 'SCRIT')}
AURA_MOD_SKILL, SKILL_DEFENSE = 30, 95
# school mask -> damage key of one school (MOD_DAMAGE_DONE with a single school)
SCHOOL_KEY = {2: 'HOLY_DAMAGE_DONE', 4: 'FIRE_DAMAGE_DONE', 8: 'NATURE_DAMAGE_DONE', 16: 'FROST_DAMAGE_DONE',
              32: 'SHADOW_DAMAGE_DONE', 64: 'ARCANE_DAMAGE_DONE'}
MAGIC_SCHOOLS, ALL_SCHOOLS = 126, 127


def aura_stats(effects):
    """(stats, rest) of a spell's effects ([effect, aura, points, misc, ...]): the plain stats it gives
    as client keys (the keys C_Item.GetItemStats names them by: damage and healing alike are
    SPELL_POWER, melee and ranged attack power alike ATTACK_POWER), and whether any effect is something
    else (rest: a proc, a spell modifier, a skill...). Resistances are plain but not scored: left out."""
    out, rest = {}, False
    pts = {}
    for e in effects:
        effect, aura, points, misc = e[0], e[1], e[2], e[3]
        if effect != 6:
            rest = True
            continue
        pts.setdefault((aura, misc), points)
    dmg, heal = pts.get((AURA_MOD_DAMAGE_DONE, MAGIC_SCHOOLS)), pts.get((AURA_MOD_HEALING_DONE, MAGIC_SCHOOLS))
    ap = next((v for (a, _), v in pts.items() if a == AURA_MOD_AP), None)

    def add(key, v):
        v = int(round(v))
        if v:
            out[key] = out.get(key, 0) + v
    for (aura, misc), points in pts.items():
        if aura == AURA_MOD_STAT and misc in STAT_OF_MISC:
            add(STAT_OF_MISC[misc], points)
        elif aura == AURA_MOD_STAT and misc == -1:
            for key in STAT_OF_MISC.values():
                add(key, points)
        elif aura == AURA_MOD_RESISTANCE:
            if misc == 1:
                add('RESISTANCE0_NAME', points)
        elif aura == AURA_MOD_AP:
            add('ATTACK_POWER', points)
        elif aura == AURA_MOD_RAP:
            if ap != points:
                add('RANGED_ATTACK_POWER', points)
        elif aura == AURA_MOD_DAMAGE_DONE and misc in (MAGIC_SCHOOLS, ALL_SCHOOLS):
            add('SPELL_POWER' if misc == MAGIC_SCHOOLS and heal == points else 'SPELL_DAMAGE_DONE', points)
        elif aura == AURA_MOD_DAMAGE_DONE and misc in SCHOOL_KEY:
            add(SCHOOL_KEY[misc], points)
        elif aura == AURA_MOD_HEALING_DONE:
            if not (misc == MAGIC_SCHOOLS and dmg == points):
                add('SPELL_HEALING_DONE', points)
        elif aura == AURA_MOD_POWER_REGEN and misc == 0:
            add('MANA_REGENERATION', points)
        elif aura == AURA_MOD_TARGET_RESISTANCE and misc in (MAGIC_SCHOOLS, ALL_SCHOOLS) and points < 0:
            add('SPELL_PENETRATION', -points)
        elif aura in AURA_PCT:
            key, kind = AURA_PCT[aura]
            add(key, points * RATING_60.get(kind, 14))
        elif aura == AURA_MOD_SKILL and misc == SKILL_DEFENSE:
            add('DEFENSE_SKILL_RATING', points * RATING_60['DEF'])
        else:
            rest = True
    return out, rest


# German words for the short description of an effect the scoring does not count.
SCHOOL_DE = {1: '', 2: 'Heilig', 4: 'Feuer', 8: 'Natur', 16: 'Frost', 32: 'Schatten', 64: 'Arkan'}
STAT_DE = {'STRENGTH': 'Stärke', 'AGILITY': 'Beweglichkeit', 'STAMINA': 'Ausdauer', 'INTELLECT': 'Intelligenz',
           'SPIRIT': 'Willenskraft', 'RESISTANCE0_NAME': 'Rüstung', 'ATTACK_POWER': 'Angriffskraft',
           'RANGED_ATTACK_POWER': 'Distanzangriffskraft', 'SPELL_POWER': 'Zaubermacht',
           'SPELL_DAMAGE_DONE': 'Zauberschaden', 'SPELL_HEALING_DONE': 'Heilung', 'MANA_REGENERATION': 'Mana alle 5 Sek.',
           'SPELL_PENETRATION': 'Zauberdurchschlag', 'HIT_MELEE_RATING': 'Trefferwertung',
           'HIT_SPELL_RATING': 'Zaubertrefferwertung', 'CRIT_MELEE_RATING': 'kritische Trefferwertung',
           'CRIT_SPELL_RATING': 'kritische Zaubertrefferwertung', 'DEFENSE_SKILL_RATING': 'Verteidigungswertung',
           'HOLY_DAMAGE_DONE': 'Heiligschaden', 'FIRE_DAMAGE_DONE': 'Feuerschaden', 'NATURE_DAMAGE_DONE': 'Naturschaden',
           'FROST_DAMAGE_DONE': 'Frostschaden', 'SHADOW_DAMAGE_DONE': 'Schattenschaden', 'ARCANE_DAMAGE_DONE': 'Arkanschaden'}
TRIGGER_DE = {0: 'Benutzen', 1: 'Anlegen', 2: 'Chance bei Treffer', 5: 'Benutzen'}


def _n(v):
    return f'{v:g}'


def _school_damage(school):
    return (SCHOOL_DE.get(school, '') + 'schaden') if SCHOOL_DE.get(school) else 'Schaden'


def describe(gd, spell, depth=0):
    """Short German parts of what a spell does, where its effects say it plainly ("176 Feuerschaden",
    "+10 % Schaden: Stormstrike"); a proc describes the spell it triggers. [] when nothing is plain."""
    fx = (gd.get('fx') or {}).get(spell)
    if not fx:
        return []
    parts, plain = [], []
    school = fx.get('school') or 0
    for e in fx['e']:
        effect, aura, points, misc, trig = e[0], e[1], e[2], e[3], e[4]
        if effect == 2:
            parts.append(f'{_n(points)} {_school_damage(school)}')
        elif effect == 9:
            parts.append(f'{_n(points)} Leben entziehen')
        elif effect == 10:
            parts.append(f'{_n(points)} Heilung')
        elif effect == 19:
            parts.append(f'{_n(points)} zusätzlicher Angriff' if points == 1 else f'{_n(points)} zusätzliche Angriffe')
        elif effect == 30 and misc == 0:
            parts.append(f'{_n(points)} Mana')
        elif effect != 6:
            continue
        elif aura == AURA_PROC_TRIGGER and trig and depth == 0:
            parts.extend(describe(gd, trig, depth + 1))
        elif aura == AURA_PERIODIC_DAMAGE:
            parts.append(f'{_n(points)} {_school_damage(school)} je Tick')
        elif aura == AURA_PERIODIC_HEAL:
            parts.append(f'{_n(points)} Heilung je Tick')
        elif aura == AURA_DAMAGE_SHIELD:
            parts.append(f'{_n(points)} {_school_damage(school)} an Angreifern')
        elif aura == AURA_SCHOOL_ABSORB:
            parts.append(f'absorbiert {_n(points)} Schaden')
        elif aura in (AURA_MOD_SPEED, AURA_MOD_SPEED_ALWAYS) and points > 0:
            parts.append(f'+{_n(points)} % Lauftempo')
        elif aura == AURA_MOD_DECREASE_SPEED and points < 0:
            parts.append(f'verlangsamt um {_n(-points)} %')
        elif aura == AURA_MOD_DAMAGE_DONE and misc in (1, ALL_SCHOOLS):
            parts.append(f'{points:+g} Schaden')
        elif aura in (AURA_ADD_FLAT, AURA_ADD_PCT) and misc == 0 and fx.get('ab'):
            parts.append(f'{points:+g}{" %" if aura == AURA_ADD_PCT else ""} Schaden: {fx["ab"]}')
        elif aura in (AURA_ADD_FLAT, AURA_ADD_PCT) and fx.get('ab'):
            parts.append(f'{fx["ab"]} verbessert')
        else:
            plain.append(e)
    # the plain stats together, so pairs read as one (melee and ranged attack power: attack power)
    stats, _ = aura_stats(plain)
    for key, v in sorted(stats.items()):
        if key in STAT_DE:
            parts.append(f'{v:+g} {STAT_DE[key]}')
    return parts


def item_effects(gd, iid):
    """(stats, texts) of an item's effects: the plain stats of its equip effects (client keys, as
    aura_stats), and one German line for each effect the scoring does not count: "<when>: <spell>
    (<what it does, where plain>)", when = Benutzen, Anlegen, Chance bei Treffer. Effects the tooltip
    does not show (a spell without a description: a hidden condition of another effect) are left out."""
    stats, texts = {}, []
    for trig, spell in (gd.get('effects') or {}).get(iid, []):
        fx = (gd.get('fx') or {}).get(spell)
        if not fx or not fx.get('vis'):
            continue
        rest = True
        if trig == 1:
            s, rest = aura_stats(fx['e'])
            for k, v in s.items():
                stats[k] = stats.get(k, 0) + v
            if not fx['e']:
                rest = True
        if rest:
            parts = describe(gd, spell)
            name = fx.get('name') or f'Zauber {spell}'
            texts.append(f'{TRIGGER_DE.get(trig, "Effekt")}: {name}' + (f' ({", ".join(parts)})' if parts else ''))
    return stats, texts


def full_stats(gd, iid):
    """(stats, unknown) of an item from the client tables: the allocations (computed_stats), the armour
    (RESISTANCE0_NAME, extra armour included, as the scans have it), a weapon's damage per second
    (DAMAGE_PER_SECOND) and the plain stats of its equip effects. unknown: what the tables cannot say
    ('ARMOR', 'DPS'). (None, set()) for an item the tables do not know."""
    base = computed_stats(gd, iid, any_slot=True)
    if base is None:
        return None, set()
    out, unknown = dict(base), set()
    arm = armour_value(gd, iid)
    if arm is None:
        unknown.add('ARMOR')
    elif arm:
        out['RESISTANCE0_NAME'] = arm
    it = gd['items'][iid]
    if it[6] == 2 or (it[6] is None and it[0] in WEAPON_INV_1H + WEAPON_INV_RANGED + (17, 25)):
        dmg = weapon_damage(gd, iid)
        if dmg is None:
            unknown.add('DPS')
        else:
            out['DAMAGE_PER_SECOND'] = round(dmg[2], 4)
        for k, v in caster_power(gd, iid).items():
            out[k] = out.get(k, 0) + v
    fx, _ = item_effects(gd, iid)
    for k, v in fx.items():
        out[k] = out.get(k, 0) + v
    return out, unknown


def item_kind(gd, iid):
    """The kind an item is checked and gated by: 'melee', 'caster', 'ranged', 'thrown', 'wand' (or
    'weapon' without its class), 'armour', 'shield', 'trinket', 'relic' or 'jewellery' (neck, ring, held
    in the off hand). None for an unknown item."""
    it = gd['items'].get(iid)
    if not it:
        return None
    inv, cls, sub = it[0], it[6], it[7]
    if cls == 2:
        k = weapon_kind(gd, iid)
        return {'1H': 'melee', '2H': 'melee', '1HC': 'caster', '2HC': 'caster'}.get(k, k or 'weapon')
    if inv == 12:
        return 'trinket'
    if inv == 28 or (cls == 4 and sub in (7, 8, 9, 10)):
        return 'relic'
    if inv == 14 or (cls == 4 and sub == SUB_SHIELD):
        return 'shield'
    if inv in (2, 11, 23):
        return 'jewellery'
    if inv in WEAPON_INV_1H + WEAPON_INV_RANGED + (17, 25):
        return 'weapon'
    return 'armour'


# Scoring keys the computation cannot produce (sockets).
SC_SKIP = {'SOCK', 'META'}


def check_computed(gd, scanned, stat_map=None, by_kind=None):
    """(rate, checked, misses): how often the computed stats (full_stats) equal what the scan saw, over
    the scanned items the tables know, compared as Gear.lua scores them (its keys; damage per second to
    a thousandth). What the tables cannot say for an item (its armour, a weapon's damage) is left out of
    its comparison; a weapon without damage is not checked. by_kind (a dict) gets {kind: [good,
    checked]} (item_kind)."""
    stat_map = stat_map or gear_stat_map()
    good, misses = 0, []
    for iid, text in sorted(scanned.items()):
        if iid not in gd['items']:
            continue
        calc, unknown = full_stats(gd, iid)
        if 'DPS' in unknown:
            continue
        want = {k: v for k, v in parse_stats(text, stat_map).items() if k not in SC_SKIP and k not in unknown}
        got = parse_stats(stat_text(calc), stat_map) if calc is not None else None
        ok = got is not None and set(got) == set(want) and all(
            abs(got[k] - want[k]) < (1e-3 if k == 'DPS' else 1e-6) for k in want)
        kind = item_kind(gd, iid)
        if by_kind is not None:
            by_kind.setdefault(kind, [0, 0])
            by_kind[kind][1] += 1
        if ok:
            good += 1
            if by_kind is not None:
                by_kind[kind][0] += 1
        else:
            misses.append((iid, got, want))
    n = good + len(misses)
    return (good / n if n else 0.0), n, misses


# ---------------------------------------------------------------- scoring (the twin of Gear.lua)
GROUP = {
    'HEAD': 'HEAD', 'NECK': 'NECK', 'SHOULDER': 'SHOULDER', 'CLOAK': 'BACK', 'CHEST': 'CHEST', 'ROBE': 'CHEST',
    'WRIST': 'WRIST', 'HAND': 'HANDS', 'WAIST': 'WAIST', 'LEGS': 'LEGS', 'FEET': 'FEET', 'FINGER': 'FINGER',
    'TRINKET': 'TRINKET', '2HWEAPON': '2H', 'WEAPON': '1H', 'WEAPONMAINHAND': 'MH', 'WEAPONOFFHAND': 'OHW',
    'SHIELD': 'SHIELD', 'HOLDABLE': 'HELD', 'RANGED': 'RANGED', 'RANGEDRIGHT': 'RANGED', 'THROWN': 'RANGED',
    'RELIC': 'RANGED',
}
ARMOR = {
    'WARRIOR': {1: 1, 2: 1, 3: 1, 4: 40, 6: 1}, 'PALADIN': {1: 1, 2: 1, 3: 1, 4: 40, 6: 1, 7: 1},
    'HUNTER': {1: 1, 2: 1, 3: 40}, 'ROGUE': {1: 1, 2: 1}, 'PRIEST': {1: 1},
    'SHAMAN': {1: 1, 2: 1, 3: 40, 6: 1, 9: 1}, 'MAGE': {1: 1}, 'WARLOCK': {1: 1}, 'DRUID': {1: 1, 2: 1, 8: 1},
}
WEAPON = {
    'WARRIOR': {0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18}, 'PALADIN': {0, 1, 4, 5, 6, 7, 8},
    'HUNTER': {0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18}, 'ROGUE': {2, 3, 4, 7, 13, 15, 16, 18},
    'PRIEST': {4, 10, 15, 19}, 'SHAMAN': {0, 1, 4, 5, 10, 13, 15}, 'MAGE': {7, 10, 15, 19},
    'WARLOCK': {7, 10, 15, 19}, 'DRUID': {4, 5, 10, 13, 15},
}
DUAL_WIELD = {'ROGUE': 10, 'WARRIOR': 20, 'HUNTER': 20}
RELIC = {7: 'PALADIN', 8: 'DRUID', 9: 'SHAMAN'}
CLASS_BIT = {'WARRIOR': 1, 'PALADIN': 2, 'HUNTER': 4, 'ROGUE': 8, 'PRIEST': 16, 'SHAMAN': 64, 'MAGE': 128,
             'WARLOCK': 256, 'DRUID': 1024}
FIRST_SOURCE = 10   # 0-based index of the first source number in a row (Gear.FIRST_SOURCE 11)
BASE_KEYS = ('STR', 'AGI', 'STA', 'INT', 'SPI', 'HP5', 'MP5', 'AP', 'RAP', 'ARMOR', 'BLOCKVAL')
SCHOOLS = ('SP_ARCANE', 'SP_FIRE', 'SP_NATURE', 'SP_FROST', 'SP_SHADOW', 'SP_HOLY')


def usable(cls, row, level):
    loc, class_id, sub = row[0], row[1], row[2]
    group = GROUP.get(loc)
    if not group:
        return False
    if loc == 'RELIC':
        return RELIC.get(sub) == cls
    if class_id == 4:
        if sub == 0 or loc in ('CLOAK', 'HOLDABLE'):
            return True
        frm = ARMOR[cls].get(sub)
        return frm is not None and level >= frm
    if class_id == 2:
        if sub not in WEAPON[cls]:
            return False
        if loc == 'WEAPONOFFHAND':
            return cls in DUAL_WIELD and level >= DUAL_WIELD[cls]
        return True
    return False


def terms(s, w, level, kind, cls, conv):
    """Every term of a score as (key, value, weight, rating kind or None), as Gear.lua's terms()."""
    W = lambda k: w.get(k, 0)  # noqa: E731
    out = []
    for k in BASE_KEYS:
        out.append((k, s.get(k), W(k), None))
    if cls == 'DRUID':
        out.append(('FAP', s.get('FAP'), W('AP'), None))
    out.append(('SPP', s.get('SPP'), W('SP') + W('HEAL'), None))
    out.append(('SPD', s.get('SPD'), W('SP'), None))
    out.append(('HEAL', s.get('HEAL'), W('HEAL'), None))
    for school in SCHOOLS:
        out.append((school, s.get(school), W(school), None))
    crit_w = W('CRIT') + W('SCRIT')
    # generic hit: a melee part (melee rate) and a spell part (spell rate), each under its own room
    out.append(('HIT', s.get('HIT'), W('HIT'), 'HIT'))
    out.append(('HITSP', s.get('HIT'), W('SHIT'), 'SHIT'))
    out.append(('MHIT', s.get('MHIT'), W('HIT'), 'HIT'))
    out.append(('SHIT', s.get('SHIT'), W('SHIT'), 'SHIT'))
    out.append(('CRIT', s.get('CRIT'), crit_w, 'CRIT'))
    out.append(('MCRIT', s.get('MCRIT'), W('CRIT'), 'CRIT'))
    out.append(('SCRIT', s.get('SCRIT'), W('SCRIT'), 'CRIT'))
    haste_w = w['HASTE'] if 'HASTE' in w else 0.8 * crit_w
    out.append(('HASTE', s.get('HASTE'), haste_w, 'HASTE'))
    out.append(('SHASTE', s.get('SHASTE'), haste_w, 'HASTE'))
    out.append(('EXP', s.get('EXP'), w['EXP'] if 'EXP' in w else 0.8 * W('HIT'), 'EXP'))
    for k in ('DODGE', 'PARRY', 'BLOCK', 'DEF'):
        out.append((k, s.get(k), W(k), k))
    out.append(('SOCK', s.get('SOCK'), W('GEM'), None))
    out.append(('META', s.get('META'), W('META'), None))
    out.append(('RES', s.get('RES'), W('RES'), None))
    out.append(('SPEN', s.get('SPEN'), W('SPEN'), None))
    if s.get('DPS') and kind:
        if kind == 'RANGED':
            out.append(('DPS', s.get('DPS'), W('RDPS'), None))
            spd = 'SPD_RANGED'
        else:
            out.append(('DPS', s.get('DPS'), W('DPS') * (w.get('OHDPS', 0.25) if kind == 'OH' else 1), None))
            spd = 'SPD_' + kind
        if s.get('SPEED'):
            out.append(('SPEED', s['SPEED'] - w.get('SPDREF_' + kind, 0), W(spd), None))
    if s.get('SETB'):
        out.append(('SETB', s['SETB'], 1, None))
    return out


def score(s, w, level, kind, cls, conv):
    total = 0.0
    for _, value, weight, rating in terms(s, w, level, kind, cls, conv):
        if value and weight:
            total += value * (conv.rating_pp(rating, level) if rating else 1) * weight
    return total


# ---------------------------------------------------------------- choosing gear (Gear.Best's twin)
DEFAULT_SOURCES = {'X', 'Q', 'D', 'C', 'V', 'W'}   # Bis.lua's default switches (AH, PvP off)
FILTER_OF = {'X': 'X', 'Q': 'Q', 'D': 'D', 'C': 'C', 'V': 'V', 'R': 'W', 'W': 'W', 'A': 'A', 'P': 'P'}
ONE_SLOT = ('HEAD', 'NECK', 'SHOULDER', 'BACK', 'CHEST', 'WRIST', 'HANDS', 'WAIST', 'LEGS', 'FEET')


class Items:
    """The planner's items with their stats: scanned (ST) first, else computed (SC)."""

    def __init__(self, gear, sc_text, stat_map):
        self.gear = gear
        self.stats = {}
        self.computed = set()
        for iid in gear['I']:
            text = gear['ST'].get(iid)
            if text is None and iid in sc_text:
                text = sc_text[iid]
                self.computed.add(iid)
            if text is None:
                continue
            s = parse_stats(text, stat_map)
            row = gear['I'][iid]
            if (row[8] or 0) > 0 and s.get('DPS'):
                s['SPEED'] = float(row[8])
            self.stats[iid] = s

    def candidates(self, cls, level, sources=DEFAULT_SOURCES):
        S = self.gear['S']
        for iid, row in self.gear['I'].items():
            s = self.stats.get(iid)
            if s is None or (row[3] or 0) > level or not usable(cls, row, level):
                continue
            if (row[7] or 0) > 0 and not (row[7] & CLASS_BIT[cls]):
                continue
            if (row[9] or 0) > 0:   # needs a profession to wear (goggles): off by default
                continue
            ok = False
            for n in row[FIRST_SOURCE:]:
                rec = S[n - 1]
                if FILTER_OF.get(rec[0], rec[0]) in sources and not (
                        rec[0] == 'Q' and (len(rec) > 7 and (rec[7] or 0) > 0) and not (rec[7] & CLASS_BIT[cls])):
                    ok = True
                    break
            if ok:
                yield iid, row, s


def best(items, cls, level, w, conv, plan='auto'):
    """The best item per slot, as Gear.Best: {slot: (id, score)} plus 'plan'."""
    lists = {'2H': [], 'MH': [], 'OH': [], 'FINGER': [], 'TRINKET': [], 'RANGED': []}
    one = {k: [] for k in ONE_SLOT}
    dual = cls in DUAL_WIELD and level >= DUAL_WIELD[cls]
    for iid, row, s in items.candidates(cls, level):
        group = GROUP[row[0]]
        if group in ('1H', 'MH'):
            lists['MH'].append((score(s, w, level, 'MH', cls, conv), -iid, iid))
            if group == '1H' and dual:
                lists['OH'].append((score(s, w, level, 'OH', cls, conv), -iid, iid))
        elif group == 'OHW':
            lists['OH'].append((score(s, w, level, 'OH', cls, conv), -iid, iid))
        elif group in ('SHIELD', 'HELD'):
            lists['OH'].append((score(s, w, level, None, cls, conv), -iid, iid))
        elif group == '2H':
            lists['2H'].append((score(s, w, level, '2H', cls, conv), -iid, iid))
        elif group == 'RANGED':
            lists['RANGED'].append((score(s, w, level, 'RANGED', cls, conv), -iid, iid))
        elif group in ('FINGER', 'TRINKET'):
            lists[group].append((score(s, w, level, None, cls, conv), -iid, iid))
        elif group in one:
            one[group].append((score(s, w, level, None, cls, conv), -iid, iid))
    out = {}
    for k, lst in one.items():
        lst = [e for e in lst if e[0] > 0]
        if lst:
            e = max(lst)
            out[k] = (e[2], e[0])
    for k, slots in (('FINGER', ('FINGER1', 'FINGER2')), ('TRINKET', ('TRINKET1', 'TRINKET2'))):
        lst = sorted((e for e in lists[k] if e[0] > 0), reverse=True)
        for slot, e in zip(slots, lst):
            out[slot] = (e[2], e[0])
    if lists['RANGED']:
        e = max(lists['RANGED'])
        out['RANGED'] = (e[2], e[0])
    b2 = max(lists['2H']) if lists['2H'] else None
    bm = max(lists['MH']) if lists['MH'] else None
    boh = None
    for e in sorted(lists['OH'], reverse=True):
        if not bm or e[2] != bm[2]:
            boh = e
            break
    one_hand = (bm[0] if bm else 0) + (boh[0] if boh else 0)
    if b2 and (plan == '2H' or (plan == 'auto' and b2[0] >= one_hand)):
        out['MAINHAND'] = (b2[2], b2[0])
        out['plan'] = '2H'
    else:
        if bm:
            out['MAINHAND'] = (bm[2], bm[0])
        if boh:
            out['OFFHAND'] = (boh[2], boh[0])
        out['plan'] = '1H'
    return out


# ---------------------------------------------------------------- the reference character
def base_attr(cls, level, key):
    b60 = BASE_60[cls][key]
    return 20 + (b60 - 20) * (max(level, 1) - 1) / 59


def reference(items, picks, cls, level, conv):
    """The stats of a character of cls at level wearing picks (stats summed, ratings as percent)."""
    tot = {}
    for slot, v in picks.items():
        if slot == 'plan':
            continue
        for k, x in items.stats[v[0]].items():
            if k in ('DPS', 'SPEED'):
                continue
            tot[k] = tot.get(k, 0) + x
    ref = {'level': level}
    for k in ('STR', 'AGI', 'STA', 'INT', 'SPI'):
        ref[k] = base_attr(cls, level, k) + tot.get(k, 0)
    rp = lambda kind, *keys: sum(tot.get(k, 0) for k in keys) * conv.rating_pp(kind, level)  # noqa: E731
    ref['hit'] = rp('HIT', 'HIT', 'MHIT')
    ref['spellhit'] = rp('SHIT', 'HIT', 'SHIT')
    ref['critRating'] = rp('CRIT', 'CRIT', 'MCRIT')
    ref['spellCritRating'] = rp('CRIT', 'CRIT', 'SCRIT')
    ref['dodgeRating'] = rp('DODGE', 'DODGE')
    ref['parryRating'] = rp('PARRY', 'PARRY')
    ref['block'] = rp('BLOCK', 'BLOCK')
    ref['def'] = rp('DEF', 'DEF')
    ref['AP'] = tot.get('AP', 0)
    ref['RAP'] = tot.get('RAP', 0)
    ref['FAP'] = tot.get('FAP', 0)
    ref['SPP'] = tot.get('SPP', 0)
    ref['SPD'] = tot.get('SPD', 0)
    ref['HEAL'] = tot.get('HEAL', 0)
    for school in SCHOOLS:
        ref[school] = tot.get(school, 0)
    ref['MP5'] = tot.get('MP5', 0)
    ref['ARMOR'] = tot.get('ARMOR', 0)
    ref['BLOCKVAL'] = tot.get('BLOCKVAL', 0)
    weapon = lambda slot: items.stats[picks[slot][0]] if slot in picks else {}  # noqa: E731
    mh, oh, rg = weapon('MAINHAND'), weapon('OFFHAND'), weapon('RANGED')
    ref['wDPS'] = mh.get('DPS') or (1 + 0.75 * level)
    ref['speed'] = mh.get('SPEED') or 2.6
    ref['ohDPS'] = oh.get('DPS', 0)
    ref['rDPS'] = rg.get('DPS') or (1 + 0.6 * level)
    ref['rSpeed'] = rg.get('SPEED') or 2.8
    ref['plan'] = picks.get('plan', '1H')
    return ref


# ---------------------------------------------------------------- the weights: derivation
# Spell tables (Classic values, the average hit of the rank a character has at that level). NUKE is
# Frostbolt's progression; each spec scales it by its own main spell (f) and uses its cast time.
NUKE = [(1, 12), (4, 19), (8, 35), (14, 63), (20, 101), (26, 139), (32, 191), (38, 241), (44, 299), (50, 372),
        (56, 445), (60, 535)]
HEAL_TABLE = [(1, 40), (4, 55), (10, 110), (16, 185), (22, 280), (28, 400), (34, 530), (40, 660), (46, 820),
              (52, 980), (58, 1200), (60, 1300)]


def interp(table, level):
    lo = table[0]
    for pt in table:
        if pt[0] > level:
            span = pt[0] - lo[0]
            return lo[1] + (pt[1] - lo[1]) * (level - lo[0]) / span if span else pt[1]
        lo = pt
    return table[-1][1]


def low_level_penalty(level):
    """Classic's coefficient penalty of spells learnt below level 20."""
    learnt = max(1, level - 2)
    return 1 - max(0, 20 - learnt) * 0.0375


# Per spec: model and parameters, each with the reason in a comment; "why" is the German line the
# addon shows under "Warum diese Gewichte".
SPECS = [
    # Warriors live off weapon damage: specials hit for the weapon's damage, so a slow two-hander wins.
    ('WARRIOR', 'dps', 'Waffen/Furor', 'dps', 'phys', dict(
        ap_str=2, ap_agi=0, r_spec=0.2, plan='2H', mana100=0,
        why='Krieger: Waffenschaden zählt voll, Stärke gibt 2 Angriffskraft, Beweglichkeit nur Krit; langsame Waffen für Spezialangriffe.')),
    ('WARRIOR', 'tank', 'Schutz', 'tank', 'tank', dict(
        parry=True, block=True, armor_mult=1.0, threat='WARRIOR',
        why='Schutzkrieger: Ausdauer, Rüstung und Vermeidung nach effektiver Gesundheit; Bedrohung (Stärke, Treffer) zählt zu 15 %.')),
    # Retribution: Seal of Command scales with weapon speed; mana for seals and judgements.
    ('PALADIN', 'ret', 'Vergeltung', 'dps', 'phys', dict(
        ap_str=2, ap_agi=0, r_spec=0.2, plan='2H', mana100=3.0, sp=0.25,
        why='Vergeltung: Waffenschaden und Stärke zuerst, langsame Zweihänder für Siegel; Intelligenz für das Mana.')),
    ('PALADIN', 'holy', 'Heilig', 'heal', 'heal', dict(
        f=0.75, cast=2.5, eff=3.0, scarce=0.6,
        why='Heilig-Paladin: Heilung zuerst, Intelligenz für Mana und Krit; Willenskraft regeneriert wenig.')),
    ('PALADIN', 'tank', 'Schutz', 'tank', 'tank', dict(
        parry=True, block=True, armor_mult=1.0, threat='PALADIN', sp=0.3, mana100=2.0,
        why='Schutzpaladin: effektive Gesundheit; Zauberschaden und Mana tragen die Bedrohung.')),
    # Hunters shoot: agility gives 2 ranged attack power and crit; the ranged weapon is the weapon.
    ('HUNTER', 'dps', 'Jäger', 'dps', 'phys', dict(
        ranged=True, ap_str=0, ap_agi=2, r_spec=0.12, plan='2H', mana100=4.0, melee_dps=1.4,
        why='Jäger: Distanzwaffe zählt voll, Beweglichkeit gibt 2 Distanzangriffskraft und Krit; Intelligenz für das Mana.')),
    # Rogues dual wield: the off hand hits for half, both hands miss more.
    ('ROGUE', 'dps', 'Schurke', 'dps', 'phys', dict(
        ap_str=1, ap_agi=1, r_spec=0.2, plan='DW', mana100=0,
        why='Schurke: Waffenschaden zählt voll, Beweglichkeit gibt Angriffskraft und Krit, Treffer bis 6 %.')),
    ('PRIEST', 'shadow', 'Schatten', 'dps', 'caster', dict(
        school={'SP_SHADOW': 1}, f=0.9, cast=2.0, eff=1.8, scarce=0.5, wand=True,
        why='Schatten: Schattenschaden und Zauberschaden voll, Intelligenz für Mana und Krit; der Zauberstab zählt beim Leveln.')),
    ('PRIEST', 'disc', 'Disziplin', 'dps', 'caster', dict(
        school={'SP_HOLY': 1}, f=1.0, cast=2.5, eff=1.9, scarce=0.5, wand=True,
        why='Disziplin: Heiligschaden und Zauberschaden voll, dazu Mana und Krit aus Intelligenz.')),
    ('PRIEST', 'holy', 'Heilig', 'heal', 'heal', dict(
        f=1.0, cast=2.5, eff=2.4, scarce=0.6,
        why='Heilig-Priester: Heilung zuerst, Intelligenz und Willenskraft halten das Mana.')),
    ('SHAMAN', 'ele', 'Elementar', 'dps', 'caster', dict(
        school={'SP_NATURE': 1, 'SP_FIRE': 0.3}, f=1.0, cast=2.5, eff=1.9, scarce=0.5,
        why='Elementar: Natur- und Zauberschaden voll, Feuer zu 30 %; Intelligenz für Mana und Krit.')),
    ('SHAMAN', 'enh', 'Verstärkung', 'dps', 'phys', dict(
        ap_str=2, ap_agi=0, r_spec=0.2, plan='2H', mana100=3.0, sp=0.2,
        why='Verstärkung: Waffenschaden und Stärke zuerst, langsame Waffen für Windzorn und Sturmschlag.')),
    ('SHAMAN', 'resto', 'Wiederherstellung', 'heal', 'heal', dict(
        f=0.9, cast=2.5, eff=2.3, scarce=0.6,
        why='Wiederherstellung: Heilung zuerst, Mana alle 5 Sek. und Intelligenz halten durch.')),
    ('MAGE', 'frost', 'Frost', 'dps', 'caster', dict(
        school={'SP_FROST': 1}, f=1.0, cast=2.5, eff=2.0, scarce=0.5, wand=True,
        why='Frost: Frost- und Zauberschaden voll, Intelligenz für Mana und Krit; der Zauberstab zählt beim Leveln.')),
    ('MAGE', 'fire', 'Feuer', 'dps', 'caster', dict(
        school={'SP_FIRE': 1}, f=1.25, cast=3.5, eff=1.9, scarce=0.5, wand=True,
        why='Feuer: Feuer- und Zauberschaden voll, Krit zählt mehr als bei Frost.')),
    ('MAGE', 'arcane', 'Arkan', 'dps', 'caster', dict(
        school={'SP_ARCANE': 1}, f=1.0, cast=3.5, eff=1.6, scarce=0.6, wand=True,
        why='Arkan: Arkan- und Zauberschaden voll, Mana ist knapp, Intelligenz zählt mehr.')),
    ('WARLOCK', 'affli', 'Gebrechen', 'dps', 'caster', dict(
        school={'SP_SHADOW': 1}, f=1.0, cast=3.5, eff=2.4, scarce=0.3, wand=True,
        why='Gebrechen: Schattenschaden und Zauberschaden voll; Lebensentzug spart Mana, Ausdauer zählt.')),
    ('WARLOCK', 'destro', 'Zerstörung', 'dps', 'caster', dict(
        school={'SP_SHADOW': 1, 'SP_FIRE': 0.4}, f=1.05, cast=2.5, eff=2.0, scarce=0.4, wand=True,
        why='Zerstörung: Schatten- und Zauberschaden voll, Feuer zu 40 %, Krit für Schattenblitze.')),
    ('DRUID', 'balance', 'Gleichgewicht', 'dps', 'caster', dict(
        school={'SP_NATURE': 1, 'SP_ARCANE': 0.7}, f=0.85, cast=2.0, eff=1.9, scarce=0.5,
        why='Gleichgewicht: Natur- und Zauberschaden voll, Arkan zu 70 %; Intelligenz für Mana und Krit.')),
    # Feral: weapons only carry feral attack power and stats, the form decides the damage.
    ('DRUID', 'feral', 'Wilder Kampf', 'dps', 'phys', dict(
        ap_str=2, ap_agi=1, r_spec=0, plan='2H', mana100=0.5, form=True,
        why='Wilder Kampf: Stärke gibt 2, Beweglichkeit 1 Angriffskraft und Krit; Waffenschaden zählt in Gestalt nicht.')),
    ('DRUID', 'bear', 'Bär', 'tank', 'tank', dict(
        parry=False, block=False, armor_mult=2.8, threat='DRUID', form=True,
        why='Bär: Rüstung zählt in Gestalt 2,8-fach, Beweglichkeit gibt Ausweichen und Rüstung; Bedrohung zu 15 %.')),
    ('DRUID', 'resto', 'Wiederherstellung', 'heal', 'heal', dict(
        f=1.0, cast=3.0, eff=2.2, scarce=0.6,
        why='Wiederherstellung: Heilung zuerst, Willenskraft und Intelligenz halten das Mana.')),
]
UNIT = {'phys': 'AP', 'caster': 'SP', 'heal': 'HEAL', 'tank': 'STA'}
# How much of the unit one item-budget point of the main stat buys (2 attack power, about 1.2 spell
# damage, 2.2 healing, 1 stamina): the exchange rate for survival in the Hardcore weighting.
UNIT_PER_BUDGET = {'AP': 2.0, 'SP': 1.2, 'HEAL': 2.2, 'STA': 1.0}
HARDCORE_SHARE = 0.3        # Hardcore: survival on top, at 30 % of a tank's view
SPEEDRUN_SURVIVAL = 0.1     # Speedrun: a little survival (stamina, armour, avoidance) for less downtime
THREAT_SHARE = 0.15         # tanks: threat stats count at 15 %
MELEE_MISS, DW_MISS, SPELL_MISS = 8.0, 27.0, 6.0   # percent, against a target two levels higher
TARGET_DODGE = 5.6
HIT_CAP, SPELL_HIT_CAP = 6.0, 6.0
CASTS_PER_BAR_SPIRIT = 0.5  # share of a mana bar's time spent outside the five-second rule
# Share of the time a character casts while a mana bar lasts (the rest: moving, looting, waiting):
# damage dealers levelling 0.6, healers 0.4. A bar lasts its casting time divided by this.
DUTY = {'caster': 0.6, 'heal': 0.4}
# Spirit of a class without mana: health comes back faster between fights (shorter breaks); half
# of what a point of stamina is worth for the Speedrun weighting.
SPIRIT_HEALTH_SHARE = 0.5


def base_hp(cls, level):
    return HP_FACTOR[cls] * (0.45 * level * level + 1.5 * level)


def specials_rate(r60, level):
    """Specials per second that use the weapon's damage: Classic's specials come with the levels."""
    return r60 * min(1.0, max(level - 4, 0) / 36)


def phys_weights(cls, p, ref, conv):
    """Weights in attack power units. Damage per second D = (wDPS + AP/14) * (1 + r*s) * (1 + c) * t:
    white swings plus r specials per second that each hit for a swing (Classic's specials add the
    weapon's damage per hit, AP bonus included, so they scale with the weapon speed s); crit c with
    a double hit, t the share that lands. Each weight is dD/dstat divided by dD/dAP."""
    L = ref['level']
    ranged = p.get('ranged')
    form = p.get('form')
    agi = ref['AGI']
    # attack power as measured in game (tools/bis_measured.json, 2026-10-06): hunter ranged 2 per
    # agility - 10 (no level part), paladin 2 per strength + 3 * level - 20; shaman 2 per strength
    ap = (ref['RAP'] + ref['AP'] + 2 * agi - 10) if ranged else (
        ref['AP'] + ref['FAP'] + p['ap_str'] * ref['STR'] + p['ap_agi'] * agi + (2 * L if form else 3 * L - 20))
    wdps = ref['rDPS'] if ranged else (0.9 * L if form else ref['wDPS'])
    B = wdps + max(ap, 0) / 14
    c = (conv.base_crit(cls) + agi / conv.agi_per_crit(cls, L) + ref['critRating']) / 100
    dw = p.get('plan') == 'DW' and cls in DUAL_WIELD and L >= DUAL_WIELD[cls]
    miss = (0.6 * DW_MISS + 0.4 * MELEE_MISS) if dw else MELEE_MISS
    t = max(0.5, 1 - max(0.0, miss - ref['hit']) / 100 - TARGET_DODGE / 100)
    w = {'AP': 1.0}
    w_crit = 14 * 0.01 * B / (1 + c)
    w_hit = 14 * 0.01 * B / t
    w['CRIT'] = w_crit
    w['HIT'] = w_hit
    w['EXP'] = w_hit
    w['HASTE'] = 14 * 0.01 * B
    w['STR'] = p['ap_str'] if not ranged else 0.1
    w['AGI'] = p['ap_agi'] + w_crit / conv.agi_per_crit(cls, L)
    r = specials_rate(p['r_spec'], L)
    if ranged:
        w['RAP'] = 1.0
        w['RDPS'] = 14.0
        w['DPS'] = p.get('melee_dps', 1.4)
        # one second more weapon speed: every special hits for one second more of the weapon
        w['SPD_RANGED'] = round(14 * r * B / (1 + r * ref['rSpeed']), 3)
        w['SPDREF_RANGED'] = 2.8
    else:
        w['DPS'] = 0.0 if form else 14.0
        w['RDPS'] = 1.0
        if r > 0 and not form:
            for kind, refspd in (('2H', 3.3), ('MH', 2.6)):
                w['SPD_' + kind] = round(14 * r * B / (1 + r * refspd), 3)
                w['SPDREF_' + kind] = refspd
        t1 = 1 - MELEE_MISS / 100 - TARGET_DODGE / 100
        tdw = 1 - DW_MISS / 100 - TARGET_DODGE / 100
        w['OHDPS'] = round(0.5 * tdw / t1, 3)
    if p.get('mana100'):
        mv = p['mana100'] / 100
        w['INT'] = 15 * mv
        w['MP5'] = mv * 12
        w['SPI'] = mv * conv.spirit[cls] * 12 * 0.3
    if p.get('sp'):
        w['SP'] = p['sp']
    return w, {'AP': round(ap), 'wDPS': round(wdps, 1), 'crit': round(c * 100, 1)}


def caster_weights(cls, p, ref, conv, heal=False):
    """Weights in spell damage (or healing) units from a reference spell: B base damage, cast time
    T, coefficient k = T / 3.5 (less below level 20); crit adds half (heals: a half too), hit
    removes misses, mana is worth what it buys while mana runs short (scarce share)."""
    L = ref['level']
    B = interp(HEAL_TABLE if heal else NUKE, L) * p['f']
    T = min(p['cast'], interp([(1, 1.5), (8, 1.8), (14, 2.2), (20, 2.6), (26, 3.0)], L)) if p['cast'] <= 3.0 else p['cast']
    k = min(1.0, T / 3.5) * low_level_penalty(L)
    if heal:
        sp = ref['HEAL'] + ref['SPP']
    else:
        sp = ref['SPD'] + ref['SPP'] + max([ref[s] for s in p['school']] or [0])
    c = (conv.base_spell_crit(cls) + ref['INT'] / conv.int_per_crit(cls, L) + ref['spellCritRating']) / 100
    t = 1.0 if heal else max(0.5, 1 - max(0.0, SPELL_MISS - ref['spellhit']) / 100)
    dmg = B + k * sp
    pool = 18 * L + 15 * ref['INT']
    mv = p['scarce'] * dmg / (k * pool)
    bar_time = pool * p['eff'] * T / B / DUTY['heal' if heal else 'caster']
    w = {}
    unit = 'HEAL' if heal else 'SP'
    w[unit] = 1.0
    if not heal:
        for school, share in p['school'].items():
            w[school] = share
    w['SCRIT'] = round(0.5 * 0.01 * dmg / (k * (1 + 0.5 * c)), 4)
    if not heal:
        w['SHIT'] = round(0.01 * dmg / (k * t), 4)
    w['HASTE'] = round((1 - p['scarce']) * 0.01 * dmg / k, 4)
    w['INT'] = 15 * mv + w['SCRIT'] / conv.int_per_crit(cls, L)
    w['MP5'] = bar_time / 5 * mv
    w['SPI'] = conv.spirit[cls] * CASTS_PER_BAR_SPIRIT * bar_time / 5 * mv
    if not heal and p.get('wand'):
        f = 0.4 if L < 20 else 0.25 if L < 40 else 0.15
        w['RDPS'] = round(f * T / (k * (1 + 0.5 * c) * t), 4)
    w['DPS'] = 0.1
    return w, {unit: round(sp), 'crit': round(c * 100, 1), 'mana': round(pool), 'spell': round(B)}


def tank_weights(cls, p, ref, conv):
    """Weights in stamina units from effective health EH = HP / (1 - armour reduction) /
    (1 - avoidance) against a target two levels higher; threat stats at THREAT_SHARE."""
    L = ref['level']
    hp = base_hp(cls, L) + 10 * ref['STA']
    K = 400 + 85 * (L + 2)
    agi = ref['AGI']
    armor = ref['ARMOR'] * p['armor_mult'] + 2 * agi
    dodge = (agi / conv.agi_per_crit(cls, L) + ref['dodgeRating'] + ref['def'] * 0.04) / 100
    parry = ((5 + ref['parryRating'] + ref['def'] * 0.04) / 100) if p['parry'] else 0
    block = ((5 + ref['block'] + ref['def'] * 0.04) / 100) if p['block'] else 0
    av = min(0.6, 0.05 + dodge + parry + 0.3 * block)
    d_sta = 10 * (armor + K) / K / (1 - av)
    w_av = 0.01 * hp * (armor + K) / K / (1 - av) ** 2 / d_sta
    w = {'STA': 1.0}
    w['ARMOR'] = round(p['armor_mult'] * hp / K / (1 - av) / d_sta, 5)
    w['DODGE'] = w_av
    w['PARRY'] = w_av if p['parry'] else 0
    avoid_per_def = 0.04 * (3 if p['parry'] else 2)
    w['DEF'] = avoid_per_def * w_av + (0.012 * w_av if p['block'] else 0)
    if p['block']:
        w['BLOCK'] = 0.3 * w_av
        hit = 3 * (L + 2) + 0.25 * (L + 2) ** 2
        w['BLOCKVAL'] = round(block * 100 / hit * w_av, 4)
    w['AGI'] = 2 * w['ARMOR'] / p['armor_mult'] + w_av / conv.agi_per_crit(cls, L)
    # threat: the physical weights of the class at the same reference, at THREAT_SHARE, in
    # stamina for half an attack power (one budget point buys 2 attack power or 1 stamina)
    phys, _ = phys_weights(cls, dict(ap_str=2, ap_agi=1 if p.get('form') else 0, r_spec=0, plan='SHIELD',
                                     mana100=0, form=p.get('form')), ref, conv)
    s = THREAT_SHARE * 0.5
    for k in ('STR', 'AP', 'HIT', 'EXP', 'CRIT', 'DPS'):
        if phys.get(k):
            w[k] = w.get(k, 0) + s * phys[k]
    w['AGI'] += s * (phys['AGI'] if p.get('form') else 0)
    if p.get('sp'):
        w['SP'] = p['sp']
    if p.get('mana100'):
        mv = p['mana100'] / 100
        w['INT'] = 15 * mv
        w['MP5'] = 12 * mv
    w['HP5'] = 0.5
    return w, {'HP': round(hp), 'armor': round(armor), 'avoid': round(av * 100, 1)}


SURVIVAL = ('STA', 'ARMOR', 'DODGE', 'PARRY', 'DEF', 'BLOCK')


def derive(cls, model, p, ref, conv):
    """(Speedrun weights, Hardcore weights, reference values to show) for one spec at ref."""
    if model == 'phys':
        w, shown = phys_weights(cls, p, ref, conv)
    elif model == 'caster':
        w, shown = caster_weights(cls, p, ref, conv)
    elif model == 'heal':
        w, shown = caster_weights(cls, p, ref, conv, heal=True)
    else:
        w, shown = tank_weights(cls, p, ref, conv)
        return rounded(w), rounded(w), shown
    tank, _ = tank_weights(cls, dict(parry=cls in ('WARRIOR', 'PALADIN', 'ROGUE', 'HUNTER', 'SHAMAN'),
                                     block=cls in ('WARRIOR', 'PALADIN', 'SHAMAN'), armor_mult=1.0,
                                     threat=cls), ref, conv)
    u = UNIT_PER_BUDGET[UNIT[model]]

    def survival(share):
        # the tank's view of stamina, armour and avoidance at this share, in the spec's unit;
        # agility's dodge and armour part on top
        out = dict(w)
        for k in SURVIVAL:
            if tank.get(k):
                out[k] = out.get(k, 0) + share * u * tank[k]
        out['AGI'] = out.get('AGI', 0) + share * u * (2 * tank['ARMOR'] + tank['DODGE'] / conv.agi_per_crit(cls, ref['level']))
        return out
    speed = survival(SPEEDRUN_SURVIVAL)
    if model == 'phys' and not MANA_PER_SPIRIT_5.get(cls):
        speed['SPI'] = speed.get('SPI', 0) + SPEEDRUN_SURVIVAL * u * SPIRIT_HEALTH_SHARE
    hard = survival(HARDCORE_SHARE)
    if 'SPI' in speed and speed['SPI'] != w.get('SPI'):
        hard['SPI'] = speed['SPI']
    return rounded(speed), rounded(hard), shown


def rounded(w):
    out = {}
    for k, v in w.items():
        if k.startswith('SPDREF_'):
            out[k] = v
        elif v:
            out[k] = round(v, 3) if abs(v) >= 0.01 else round(v, 5)
    return out


def check_signs(cls, key, w):
    for k in ('STR', 'AGI', 'STA', 'INT', 'AP', 'SP', 'HEAL', 'CRIT', 'SCRIT', 'HIT', 'SHIT', 'ARMOR', 'DODGE'):
        if w.get(k, 0) < 0:
            raise SystemExit(f'{cls} {key}: negative weight for {k} ({w[k]})')


def rel_change(a, b):
    worst = 0.0
    for k in set(a) | set(b):
        if k.startswith('SPDREF_'):
            continue
        x, y = a.get(k, 0), b.get(k, 0)
        if max(abs(x), abs(y)) < 1e-6:
            continue
        worst = max(worst, abs(x - y) / max(abs(x), abs(y)))
    return worst


def blend(a, b, step=0.5):
    """a moved by step towards b."""
    return {k: a.get(k, 0) + (b.get(k, 0) - a.get(k, 0)) * step if not k.startswith('SPDREF_') else b.get(k, a.get(k))
            for k in set(a) | set(b)}


def derive_spec(items, cls, model, p, conv, passes=16, tol=0.01):
    """Per bracket: weights at the reference character who wears the best gear of the bracket's
    entry level under these very weights (fixpoint, at most `passes` rounds, each moving the weights
    by a shrinking step towards the new ones; converged when no weight moves 1 % or more). Returns
    (speedrun list, hardcore list, shown list, worst change of the last round)."""
    sr, hc, shown_all, worst = [], [], [], 0.0
    prev = None
    for i, upper in enumerate(BRACKETS):
        entry = 5 if i == 0 else BRACKETS[i - 1] + 1
        w = prev
        change = 0.0
        for n in range(passes):
            picks = {} if w is None else best(items, cls, entry, w, conv, plan='2H' if p.get('plan') == '2H' else 'auto')
            ref = reference(items, picks, cls, upper, conv)
            speed, hard, shown = derive(cls, model, p, ref, conv)
            # the Hardcore part is the survival on top of Speedrun at this reference
            extra = {k: hard.get(k, 0) - speed.get(k, 0) for k in hard if not k.startswith('SPDREF_')}
            if w is None:
                w = speed
                continue
            # a shrinking step: where the best gear flips between two sets, the weights settle
            # between them instead of jumping back and forth
            new = blend(w, speed, 1 / (n + 1)) if rel_change(w, speed) >= tol else speed
            change = rel_change(w, new)
            w = new
            if change < tol:
                break
        if change >= tol:
            raise SystemExit(f'{cls} {model}: the weights did not settle at level {upper} ({change:.1%} after {passes} rounds)')
        speed = rounded(w)
        hard = rounded({k: speed.get(k, 0) + extra.get(k, 0) if not k.startswith('SPDREF_') else speed[k]
                        for k in set(speed) | set(extra)})
        check_signs(cls, model, speed)
        worst = max(worst, change)
        prev = speed
        sr.append(speed)
        hc.append(hard)
        shown_all.append(shown)
    return sr, hc, shown_all, worst


# ---------------------------------------------------------------- Lua output
_LUA_ESCAPES = {'\\': '\\\\', '"': '\\"', '\n': '\\n', '\r': '\\r', '\t': '\\t'}


def lua_str(s):
    out = []
    for ch in str(s):
        if ch in _LUA_ESCAPES:
            out.append(_LUA_ESCAPES[ch])
        elif ord(ch) < 32 or ord(ch) == 127:
            out.append('\\%03d' % ord(ch))
        else:
            out.append(ch)
    return '"' + ''.join(out) + '"'


def lua_num(v):
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, int):
        return str(v)
    return f'{v:g}' if abs(v) >= 1e-4 or v == 0 else f'{v:.6f}'.rstrip('0')


def lua_key(k):
    return k if isinstance(k, str) and re.match(r'^[A-Za-z_][A-Za-z0-9_]*$', k) and k not in (
        'and', 'or', 'not', 'end', 'for', 'if', 'in', 'do', 'nil', 'true', 'false', 'then', 'else', 'repeat',
        'until', 'while', 'local', 'return', 'break', 'function', 'elseif') else '[' + (
        lua_str(k) if isinstance(k, str) else str(k)) + ']'


def lua_val(v):
    if v is None:
        return 'nil'
    if isinstance(v, (bool, int, float)):
        return lua_num(v)
    if isinstance(v, str):
        return lua_str(v)
    if isinstance(v, (list, tuple)):
        return '{ ' + ', '.join(lua_val(x) for x in v) + ' }' if v else '{}'
    if isinstance(v, dict):
        if not v:
            return '{}'
        keys = sorted(v, key=lambda k: (not isinstance(k, str), str(k) if isinstance(k, str) else k))
        return '{ ' + ', '.join(f'{lua_key(k)} = {lua_val(v[k])}' for k in keys) + ' }'
    raise TypeError(type(v))


def weights_table(w):
    return '{' + ', '.join(f'{k} = {lua_num(v)}' for k, v in sorted(w.items())) + '}'


def render_weights(result, conv, info):
    lines = [
        '-- GENERATED by tools/build_bis.py. Do not edit; rebuild instead.',
        "-- Amisia's own weights, derived in tools/build_bis.py from game mechanics and the client's game tables.",
        '-- Conversions (crit per agility and intellect, rating per percent, mana per spirit) are documented defaults',
        '-- until in-game measurements in tools/bis_measured.json correct them: ' + (', '.join(conv.sources) or 'none yet') + '.',
        'local _, ns = ...',
        '',
        '-- Hit, crit, haste, expertise, dodge, parry and block weights are per percent, DEF per defence skill',
        '-- point, the rest per point. SPD_* weigh weapon speed in seconds above SPDREF_* by slot, DPS/RDPS melee and',
        '-- ranged weapon damage, OHDPS the share an off-hand weapon\'s damage counts. ratings: rating per 1 % at 60.',
        '-- unit: what one point of score is worth; ref: the reference character per bracket; why: the reason in short.',
        'ns.GEAR_WEIGHTS = {',
        '    brackets = {' + ', '.join(str(b) for b in BRACKETS) + '},',
        '    order = {' + ', '.join(lua_str(c) for c in CLASS_ORDER) + '},',
        '    ratings = ' + weights_table(conv.rating60) + ',',
        '    built = ' + lua_str(info.get('built', '')) + ',',
        '    specs = {',
    ]
    by_class = {}
    for cls, key, name, role, model, p in SPECS:
        by_class.setdefault(cls, []).append((key, name, role, model, p))
    for cls in CLASS_ORDER:
        lines.append(f'        {cls} = {{')
        for key, name, role, model, p in by_class[cls]:
            sr, hc, shown = result[(cls, key)]
            lines.append(f'            {{ key = {lua_str(key)}, name = {lua_str(name)}, role = {lua_str(role)}, '
                         f'unit = {lua_str(UNIT[model])},')
            lines.append(f'              why = {lua_str(p["why"])},')
            for kind, sets in (('Speedrun', sr), ('Hardcore', hc)):
                lines.append(f'              {kind} = {{')
                for w in sets:
                    lines.append('                ' + weights_table(w) + ',')
                lines.append('              },')
            lines.append('              ref = {')
            for s in shown:
                lines.append('                ' + weights_table(s) + ',')
            lines.append('              },')
            lines[-1] = lines[-1] + ' },'
        lines.append('        },')
    lines += ['    },', '}', '']
    return '\n'.join(lines)


# ---------------------------------------------------------------- item sets
def set_bonus_text(effects):
    """The stat text of a set bonus spell (aura_stats: attribute, armour, attack power, spell damage and
    healing, mana per five, percent hit and crit as level-60 rating, defence), or None when any effect
    is not a plain stat."""
    out, rest = aura_stats(effects)
    return stat_text(out) if out and not rest else None


def build_sets(gd, gear_ids):
    """{set id: {'items': [...], 'b': [[threshold, text or ""], ...]}} for sets with at least two
    planner items; a bonus without a simple effect has "" (counted 0, shown as not scored)."""
    out = {}
    for sid, st in sorted(gd['sets'].items()):
        items = [i for i in st['items'] if i in gear_ids]
        if len(items) < 2:
            continue
        b = []
        for thr, spell in gd['setspells'].get(sid, []):
            b.append([thr, set_bonus_text(gd['spells'].get(spell, [])) or ''])
        out[sid] = {'name': st['name'], 'items': items, 'b': b}
    return out


# ---------------------------------------------------------------- random suffixes (observed)
def observed_suffixes(sv):
    """{item: {suffix id: stat text}} from the collector's scan.suffix in SavedVariables (the full
    stats C_Item.GetItemStats gave for a link with that suffix)."""
    out = {}
    scan = (sv or {}).get('scan') or {}
    for iid, seen in (scan.get('suffix') or {}).items():
        try:
            iid = int(iid)
        except (TypeError, ValueError):
            continue
        if not isinstance(seen, dict):
            continue
        for suf, text in seen.items():
            try:
                suf = int(suf)
            except (TypeError, ValueError):
                continue
            if suf and isinstance(text, str) and re.match(r'^[A-Z0-9_]+=-?[\d.]+(;[A-Z0-9_]+=-?[\d.]+)*$', text):
                out.setdefault(iid, {})[suf] = text
    return out


# ---------------------------------------------------------------- dungeons and their bosses
ATT_NAMES = {'the stockade': 'stockade', 'stormwind stockades': 'stockade', 'the temple of atal\'hakkar': 'st',
             'sunken temple': 'st', 'deadmines': 'deadmines', 'blackrock spire': None,
             'excavation site: wetlands': 'excavation'}


def norm(s):
    return re.sub(r'[^a-z0-9]+', ' ', str(s or '').lower()).strip()


def dungeon_keys(facts):
    """name, alias and part (normalised) -> list of fact keys."""
    out = {}
    for e in facts['dungeons']:
        for n in [e.get('name')] + list(e.get('aliases') or []) + ([e['part']] if e.get('part') else []):
            if n:
                out.setdefault(norm(n), [])
                if e['key'] not in out[norm(n)]:
                    out[norm(n)].append(e['key'])
    return out


def boss_npcs(facts, att, gear):
    """{fact key: [(npc, name), ...]}: every boss NPC AllTheThings lists for the dungeon. An
    instance that hosts several dungeons (Blackrock Spire) gives each boss to the dungeon whose
    item data or facts name it; one neither names stays out."""
    keys = dungeon_keys(facts)
    named = {}   # fact key -> set of boss names (normalised) from the facts and GearData's D records
    for e in facts['dungeons']:
        named[e['key']] = {norm(b) for b in e.get('bosses') or []}
    for rec in gear['S'] if gear else []:
        if rec[0] == 'D' and len(rec) > 2:
            for k in keys.get(norm(rec[1]), []):
                named.setdefault(k, set()).add(norm(rec[2]))
    out = {}
    if not att:
        return out
    by_inst = {}
    for nid, n in att['npcs'].items():
        if 'boss' in n['kinds'] and n.get('inst') is not None and n.get('name'):
            by_inst.setdefault(n['inst'], []).append((nid, n['name']))
    for iid, inst in att['instances'].items():
        name = norm(inst['name'])
        cands = keys.get(name) or ([ATT_NAMES[name]] if ATT_NAMES.get(name) else [])
        if not cands:
            continue
        for nid, bname in sorted(by_inst.get(iid, [])):
            if len(cands) == 1:
                key = cands[0]
            else:
                hit = [k for k in cands if norm(bname) in named.get(k, set())]
                if len(hit) != 1:
                    continue
                key = hit[0]
            out.setdefault(key, [])
            if nid not in [x[0] for x in out[key]]:
                out[key].append((nid, bname))
    return out


FACT_FIELDS = ('key', 'name', 'kind', 'min', 'max', 'size', 'inst', 'area', 'from', 'aliases', 'part', 'lvl')


def build_dungeons(facts, bosses, gd):
    """ns.BIS.DG: the facts with bosses as NPC ids (bossNames: id -> English name); boss names the
    facts know but no NPC id matched stay as names (the planner reads both)."""
    # a level range of the client (ContentTuning); Forever tunes every dungeon to one level (min = max),
    # which is no range: that level is the fact's lvl (build_dungeons.merge), not min and max
    lfg = {norm(v[0]): (v[1], v[2]) for v in (gd or {}).get('lfg', {}).values() if v[1] and v[2] > v[1]}
    out = []
    for e in facts['dungeons']:
        d = {k: e[k] for k in FACT_FIELDS if e.get(k) not in (None, [])}
        if 'min' not in d:
            for n in [e.get('name')] + list(e.get('aliases') or []):
                if norm(n) in lfg:
                    d['min'], d['max'] = lfg[norm(n)]
                    break
        ids = bosses.get(e['key'], [])
        known = {norm(n) for _, n in ids}
        lst = [nid for nid, _ in ids] + [b for b in e.get('bosses') or [] if norm(b) not in known]
        if lst:
            d['bosses'] = lst
        if ids:
            d['bossNames'] = {nid: n for nid, n in ids}
        out.append(d)
    return out


# ---------------------------------------------------------------- the drop base stock
def encounter_npcs(gd, dg):
    """{encounter id: boss NPC id} (ns.BIS.EN): the client's encounters (DungeonEncounter) matched by name
    to the bosses of the dungeons with an NPC id (dg's bossNames). A name several dungeons share is
    matched on the encounter's map (the dungeon's instance id); one that stays ambiguous is left out."""
    by_name = {}
    for d in dg:
        for npc, name in (d.get('bossNames') or {}).items():
            by_name.setdefault(norm(name), []).append((npc, d.get('inst')))
    out = {}
    for eid, (name, mapid) in sorted((gd.get('enc') or {}).items()):
        cands = {npc for npc, _ in by_name.get(norm(name), [])}
        if len(cands) > 1:
            cands = {npc for npc, inst in by_name[norm(name)] if inst == mapid}
        if len(cands) == 1:
            out[eid] = next(iter(cands))
    return out


def base_stock(archive, en=None):
    """(O, OT, OI): kills and sightings per NPC from the archive, its newest day and that day's ids. A
    record known only by its encounter (NPC 0: the corpse's GUID was secret) counts under the boss en
    (encounter -> NPC, encounter_npcs) names for it."""
    O, OT = {}, -1
    en = en or {}
    for h, r in archive.get('k', {}).items():
        OT = max(OT, r['day'])
    OI = {}
    for h, r in archive.get('k', {}).items():
        npc = r['npc'] if r['npc'] > 0 else en.get(r.get('enc') or 0, 0)
        if npc > 0:
            e = O.setdefault(npc, {'k': 0, 'it': {}})
            e['k'] += 1
            for i in r['it']:
                e['it'][int(i)] = e['it'].get(int(i), 0) + 1
        if r['day'] == OT:
            OI[h] = True
    return O, OT, OI


# Effort per source kind ("about one dungeon run = 3"): the tie rule of the planner.
# ---------------------------------------------------------------- BiS picks (tools/bis_picks.json)
# A hand-kept list of best-in-slot items the scoring alone misses (procs, equip effects): per spec,
# level range and slot one item that Gear.Best puts first. Checked against the client tables.
SLOT_KEYS = ('HEAD', 'NECK', 'SHOULDER', 'BACK', 'CHEST', 'WRIST', 'HANDS', 'WAIST', 'LEGS', 'FEET', 'FINGER1',
             'FINGER2', 'TRINKET1', 'TRINKET2', 'MAINHAND', 'OFFHAND', 'RANGED')
# ItemSparse InventoryType -> GearData's equip location (INVTYPE_ without the prefix)
INV_LOC = {1: 'HEAD', 2: 'NECK', 3: 'SHOULDER', 5: 'CHEST', 20: 'ROBE', 6: 'WAIST', 7: 'LEGS', 8: 'FEET', 9: 'WRIST',
           10: 'HAND', 11: 'FINGER', 12: 'TRINKET', 13: 'WEAPON', 14: 'SHIELD', 15: 'RANGED', 16: 'CLOAK',
           17: '2HWEAPON', 21: 'WEAPONMAINHAND', 22: 'WEAPONOFFHAND', 23: 'HOLDABLE', 25: 'THROWN',
           26: 'RANGEDRIGHT', 28: 'RELIC'}
# slot group (GROUP) -> the rows of the planner an item of it may fill
GROUP_SLOTS = {'2H': ('MAINHAND',), '1H': ('MAINHAND', 'OFFHAND'), 'MH': ('MAINHAND',), 'OHW': ('OFFHAND',),
               'SHIELD': ('OFFHAND',), 'HELD': ('OFFHAND',), 'RANGED': ('RANGED',), 'FINGER': ('FINGER1', 'FINGER2'),
               'TRINKET': ('TRINKET1', 'TRINKET2')}
PICK_SOURCE = 'Quelle unbekannt'


class PickError(ValueError):
    """tools/bis_picks.json holds a pick the checks refuse; nothing is written."""


def load_picks(path=PICKS):
    """The raw picks of tools/bis_picks.json ({"picks": [...]}), [] without the file."""
    if not path or not os.path.exists(path):
        return []
    with open(path, encoding='utf-8') as fh:
        data = json.load(fh)
    return list(data.get('picks') or [])


def check_picks(picks, gd):
    """(clean picks, errors): every pick needs a known class and spec (SPECS), a level range within
    1-60 that the item's required level allows, a planner row (SLOT_KEYS) its inventory type fits,
    an item ItemSparse holds that the class can carry, and a note; two picks of one spec and row
    must not overlap in level. source defaults to "Quelle unbekannt"."""
    specs = {(c, k) for c, k, *_ in SPECS}
    table = gd.get('picks') or {}
    ok, errors = [], []
    for n, p in enumerate(picks, 1):
        cls, spec, slot = p.get('class'), p.get('spec'), p.get('slot')
        lo, hi, iid = p.get('from'), p.get('to'), p.get('item')
        where = f'pick {n} ({cls}/{spec} {slot} {iid})'
        if (cls, spec) not in specs:
            errors.append(f'{where}: unknown class/spec (known: {", ".join(sorted(c + "/" + k for c, k in specs))})')
            continue
        if not (isinstance(lo, int) and isinstance(hi, int) and 1 <= lo <= hi <= 60):
            errors.append(f'{where}: level range from/to must be whole numbers with 1 <= from <= to <= 60')
            continue
        if slot not in SLOT_KEYS:
            errors.append(f'{where}: unknown slot (one of {", ".join(SLOT_KEYS)})')
            continue
        note = p.get('note')
        if not isinstance(note, str) or not note.strip():
            errors.append(f'{where}: a note is needed (why the item is the pick)')
            continue
        it = table.get(iid) if isinstance(iid, int) else None
        if it is None:
            errors.append(f'{where}: item not in ItemSparse (download the client tables to ~/addons/_wago)')
            continue
        loc = INV_LOC.get(it['inv'])
        group = GROUP.get(loc) if loc else None
        if not group or slot not in GROUP_SLOTS.get(group, (group,)):
            errors.append(f'{where}: the item (inventory type {it["inv"]}) does not fit the slot {slot}')
            continue
        if it['req'] > lo:
            errors.append(f'{where}: the item needs level {it["req"]}, the range starts at {lo}')
            continue
        if it['cls'] is None or not usable(cls, [loc, it['cls'], it['sub']], hi) or (
                it['mask'] and not it['mask'] & CLASS_BIT[cls]):
            errors.append(f'{where}: the class cannot carry the item (Item table class {it["cls"]}/{it["sub"]}, '
                          f'class mask {it["mask"]})')
            continue
        clash = next((q for q in ok if (q['class'], q['spec'], q['slot']) == (cls, spec, slot)
                      and q['from'] <= hi and lo <= q['to']), None)
        if clash:
            errors.append(f'{where}: levels overlap with the pick of item {clash["item"]} ({clash["from"]}-{clash["to"]})')
            continue
        src = p.get('source')
        ok.append({'class': cls, 'spec': spec, 'from': lo, 'to': hi, 'slot': slot, 'item': iid, 'note': note.strip(),
                   'src': src.strip() if isinstance(src, str) and src.strip() else PICK_SOURCE})
    return ok, errors


def pick_rows(picks, gd, gear_ids):
    """{item: row} for picked items GearData does not list: GearData's row without sources
    (equip location, class, subclass, level, quality, bind, item level, class mask, speed, 0) plus
    the name. The level is ItemSparse's required level, or the lowest pick's from when the table says
    less (its beta data has 1 for items that are not)."""
    out = {}
    for p in picks:
        iid = p['item']
        if iid in gear_ids:
            continue
        it = gd['picks'][iid]
        level = max(it['req'], min(q['from'] for q in picks if q['item'] == iid))
        speed = it['delay'] if it['cls'] == 2 else 0
        out[iid] = [INV_LOC[it['inv']], it['cls'], it['sub'], level, it['q'], it['bind'], it['ilvl'], it['mask'],
                    speed, 0, it['name']]
    return out


EFFORT = {'V': 1, 'C': 2, 'A': 2, 'Q': 2, 'QSTEP': 1, 'D': 3, 'R': 8, 'W': 20, 'P': 25, 'X': 6, 'DMAX': 30}


def render_bis(info, sc, sets, rp, dg, O, OT, OI, missing, rate, picks=(), pick_items=None, fx=None, en=None):
    lines = [
        '-- GENERATED by tools/build_bis.py. Do not edit; rebuild instead.',
        f"-- Client tables of WoW Forever {info.get('gamedata') or '?'} (wago.tools CSV, Blizzard game data); missing "
        'there: ' + (', '.join(missing) or 'none') + '.',
        '-- SC: stats of items no scan has seen, computed from ItemSparse, RandPropPoints, the weapon damage and',
        '-- armour tables and the equip effects (checked against '
        f'{rate}; per kind: {info.get("kinds") or "-"}).',
        '-- SET: item sets with their bonuses (a bonus "" is not scored). RP: random suffixes seen on links',
        '-- (item -> suffix -> stats). FX: effects the scoring does not count (use, chance on hit, other equip',
        '-- effects), German text. EN: the client\'s encounter ids -> boss NPC id.',
        '-- DG: dungeons and raids (tools/forever_dungeons.json) with their bosses\' NPC ids from AllTheThings\' Forever',
        '-- data (MIT, see LICENSES/). O: the guild\'s drop records up to day OT (OI: that day\'s ids). EF: effort per source.',
        '-- PICK: BiS picks from tools/bis_picks.json (the planner puts them first). PI: the rows of picked items',
        '-- GearData.lua lacks (as its I, no sources, plus name).',
        'local _, ns = ...',
        '',
        'ns.BIS = {',
        f"    built = {lua_str(info.get('built', ''))}, gamedata = {lua_str(info.get('gamedata') or '')},",
        '    SC = {',
    ]
    for iid in sorted(sc):
        lines.append(f'        [{iid}] = {lua_str(sc[iid])},')
    lines.append('    },')
    lines.append('    FX = {')
    for iid in sorted(fx or {}):
        lines.append(f'        [{iid}] = {lua_str(fx[iid])},')
    lines.append('    },')
    lines.append('    EN = ' + lua_val(en or {}) + ',')
    lines.append('    SET = {')
    for sid in sorted(sets):
        s = sets[sid]
        lines.append(f'        [{sid}] = {{ name = {lua_str(s["name"])}, items = {lua_val(s["items"])}, '
                     f'b = {lua_val(s["b"])} }},')
    lines.append('    },')
    lines.append('    RP = {')
    for iid in sorted(rp):
        lines.append(f'        [{iid}] = {lua_val(rp[iid])},')
    lines.append('    },')
    lines.append('    DG = {')
    for d in dg:
        lines.append('        ' + lua_val(d) + ',')
    lines.append('    },')
    lines.append('    O = {')
    for npc in sorted(O):
        lines.append(f'        [{npc}] = {lua_val(O[npc])},')
    lines.append('    },')
    lines.append(f'    OT = {OT},')
    lines.append('    OI = ' + lua_val(OI) + ',')
    lines.append('    EF = ' + lua_val(EFFORT) + ',')
    lines.append('    PICK = {')
    for p in picks:
        lines.append('        ' + lua_val(p) + ',')
    lines.append('    },')
    lines.append('    PI = {')
    for iid, row in sorted((pick_items or {}).items()):
        lines.append(f'        [{iid}] = {{ ' + ', '.join(lua_val(v) for v in row[:-1]) + f', name = {lua_str(row[-1])} }},')
    lines.append('    },')
    lines += ['}', '']
    return '\n'.join(lines)


# ---------------------------------------------------------------- main
def write_if_changed(path, text):
    old = None
    if os.path.exists(path):
        with open(path, encoding='utf-8') as fh:
            old = fh.read()
    if old == text:
        return False
    with open(path, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(text)
    return True


def load_sv(path):
    if not path or not os.path.exists(path):
        return None
    import build_scan
    return build_scan.load_sv(path)


def scan_stats(sv):
    """{item: stat text} of the SavedVariables' item scan (scan.items, the tenth field of a line), keys
    in GearData's form (without ITEM_MOD_ and _SHORT)."""
    out = {}
    items = ((sv or {}).get('scan') or {}).get('items') or {}
    pairs = enumerate(items, 1) if isinstance(items, list) else items.items()
    for iid, line in pairs:
        if not isinstance(line, str):
            continue
        try:
            iid = int(iid)
        except (TypeError, ValueError):
            continue
        f = line.split('\t')
        if len(f) < 10 or not f[9]:
            continue
        parts = []
        for part in f[9].split(';'):
            k, eq, v = part.partition('=')
            if eq:
                parts.append(re.sub(r'^ITEM_MOD_|_SHORT$', '', k) + '=' + v)
        if parts:
            out[iid] = ';'.join(parts)
    return out


def run(wago=WAGO, gamedata_path=GAMEDATA, measured_path=MEASURED, gear_path=GEAR_DATA, facts_path=FACTS,
        archive_path=DROP_ARCHIVE, sv_path=SV_DEFAULT, att=None, out_weights=OUT_WEIGHTS, out_bis=OUT_BIS,
        built=None, specs=None, picks_path=None):
    """The whole build; returns a report dict. att: the neutral AllTheThings data (or None).
    picks_path: tools/bis_picks.json (None: no picks); a pick the checks refuse raises PickError
    before anything but the game data cache is written."""
    report = {}
    gd = None
    raw_picks = load_picks(picks_path)
    pick_ids = {p.get('item') for p in raw_picks if isinstance(p.get('item'), int)}
    gear = load_gear(gear_path)
    if wago and find_csv(wago, 'ItemSparse'):
        # every planner item and pick: weapons and armour need no stats for their damage and armour
        gd = extract(wago, pick_ids, keep_ids=set(gear['I']))
        save_gamedata(gd, gamedata_path)
        report['gamedata'] = f'{len(gd["items"])} items from {wago}'
    else:
        gd = load_gamedata(gamedata_path)
        report['gamedata'] = 'cached' if gd else 'none'
    if gd is None:
        gd = dict(empty_gamedata(), missing=sorted(TABLES) + list(NOT_ON_WAGO))
    picks, errors = check_picks(raw_picks, gd)
    if errors:
        raise PickError('; '.join(errors))
    report['picks'] = len(picks)
    conv = Conv(load_measured(measured_path))
    stat_map = gear_stat_map()
    sv = load_sv(sv_path)
    # what the scans saw: GearData's ST, and the SavedVariables' item scan for the planner's items and
    # picks ST lacks (they still get computed stats: the addon has no scan of them)
    scanned = dict(gear['ST'])
    for iid, text in scan_stats(sv).items():
        if (iid in gear['I'] or iid in pick_ids) and iid not in scanned:
            scanned[iid] = text
    # computed stats per kind of item, only where the computation matches the scans of that kind
    # (SC_MIN_RATE over at least SC_MIN_CHECKED items)
    kinds = {}
    rate, checked, misses = check_computed(gd, scanned, stat_map, by_kind=kinds)
    passed = {k for k, (good, n) in kinds.items() if n >= SC_MIN_CHECKED and good / n >= SC_MIN_RATE}
    sc = {}
    for iid in list(gear['I']) + [p['item'] for p in picks if p['item'] not in gear['I']]:
        if iid in gear['ST'] or iid in sc:
            continue
        calc, unknown = full_stats(gd, iid)
        if not calc or 'DPS' in unknown:
            calc = None
        if calc and item_kind(gd, iid) in passed:
            sc[iid] = stat_text(calc)
        elif iid in pick_ids and passed:
            # a pick of a kind without proof: its allocations alone, as the proven kinds compute them
            alloc = computed_stats(gd, iid, any_slot=True)
            if alloc:
                sc[iid] = stat_text(alloc)
    for kind, (good, n) in sorted(kinds.items()):
        if kind not in passed:
            log(f'computed stats of kind {kind}: {good} of {n} scanned items match; no SC for that kind')
    if not passed:
        for m in misses[:10]:
            log('   ', m)
    report['sc'] = (len(sc), round(rate, 4), checked)
    report['sc_kinds'] = {k: list(v) for k, v in sorted(kinds.items())}
    # effects the scoring does not count, for the planner's items and the picks
    fx = {}
    for iid in set(gear['I']) | pick_ids:
        _, texts = item_effects(gd, iid)
        if texts:
            fx[iid] = '; '.join(texts)
    report['fx'] = len(fx)
    items = Items(gear, sc, stat_map)
    result = {}
    worst = 0.0
    for cls, key, name, role, model, p in SPECS:
        if specs and (cls, key) not in specs:
            continue
        sr, hc, shown, w = derive_spec(items, cls, model, p, conv)
        worst = max(worst, w)
        result[(cls, key)] = (sr, hc, shown)
    report['fixpoint'] = round(worst, 4)
    built = built or time.strftime('%Y-%m-%d')
    info = {'built': built, 'gamedata': gd.get('build'),
            'kinds': ', '.join(f'{k} {g}/{n}' + ('' if k in passed else ' (no SC)') for k, (g, n) in sorted(kinds.items()))}
    if not specs:
        write_if_changed(out_weights, render_weights(result, conv, info))
    sets = build_sets(gd, set(gear['I']))
    rp = observed_suffixes(sv)
    with open(facts_path, encoding='utf-8') as fh:
        facts = json.load(fh)
    # the client's level and instance id where the hand facts leave them open (the reader of
    # build_dungeons.py, from the client tables of this build when they are there, else its
    # tools/forever_dungeons_client.json)
    import build_dungeons as dungeon_facts
    if wago and find_csv(wago, 'LFGDungeons'):
        client = dungeon_facts.client_facts(facts, (wago,))
    else:
        client = dungeon_facts.load_client()
    facts = dict(facts, dungeons=dungeon_facts.merge(facts, client))
    bosses = boss_npcs(facts, att, gear)
    dg = build_dungeons(facts, bosses, gd)
    en = encounter_npcs(gd, dg)
    archive = {'k': {}}
    if archive_path and os.path.exists(archive_path):
        import build_scan
        archive = build_scan.load_archive(archive_path)
    O, OT, OI = base_stock(archive, en)
    write_if_changed(out_bis, render_bis(info, sc, sets, rp, dg, O, OT, OI, gd.get('missing') or [],
                                         f'{rate:.1%} of {checked} scanned items', picks,
                                         pick_rows(picks, gd, set(gear['I'])), fx, en))
    report['encounters'] = len(en)
    report.update({'sets': len(sets), 'sets_with_bonus': sum(1 for s in sets.values() if any(b[1] for b in s['b'])),
                   'rp': len(rp), 'dungeons': len(dg), 'boss_npcs': sum(len(v) for v in bosses.values()),
                   'base_npcs': len(O), 'missing': gd.get('missing')})
    return report, result


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--wago', default=WAGO, help='folder of wago.tools CSVs (default ~/addons/_wago)')
    ap.add_argument('--measured', default=MEASURED, help='in-game measurements (default tools/bis_measured.json)')
    ap.add_argument('--werte', action='append', default=[],
                    help='an AMISIA-WERTE line from the self-test; added to the samples of --measured')
    ap.add_argument('--sv', default=SV_DEFAULT, help='Amisia SavedVariables for observed random suffixes')
    ap.add_argument('--att', default=None, help='AllTheThings download (default ~/addons/_cache/att)')
    ap.add_argument('--picks', default=PICKS, help='hand-kept BiS picks (default tools/bis_picks.json)')
    ap.add_argument('--no-att', action='store_true', help='build without AllTheThings (no boss NPC ids)')
    args = ap.parse_args(argv)
    if args.werte:
        # every line is checked before the file is touched: a bad line saved would break every build
        parsed = []
        for line in args.werte:
            s = parse_werte(line)
            why = werte_problem(s)
            if why:
                log(f'--werte refused, nothing saved: {why}: {line.strip()}')
                return 2
            parsed.append((s, line))
        data = {}
        if os.path.exists(args.measured):
            with open(args.measured, encoding='utf-8') as fh:
                data = json.load(fh)
        data.setdefault('samples', [])
        for s, line in parsed:
            s["line"] = line.strip()
            if s not in data['samples']:
                data['samples'].append(s)
        with open(args.measured, 'w', encoding='utf-8', newline='\n') as fh:
            json.dump(data, fh, indent=1, sort_keys=True)
            fh.write('\n')
        log(f'{len(args.werte)} sample(s) added to {os.path.relpath(args.measured, ROOT)}')
    att = None
    if not args.no_att:
        import att_data
        base = args.att or att_data.ATT_CACHE
        if os.path.isdir(base):
            att = att_data.load(base, items=False, wago=args.wago)
        else:
            log(f'no AllTheThings download in {base}: dungeon bosses stay without NPC ids')
    try:
        report, _ = run(wago=args.wago, measured_path=args.measured, sv_path=args.sv, att=att, picks_path=args.picks)
    except PickError as e:
        log(f'{os.path.relpath(args.picks, ROOT) if args.picks else "picks"} refused, nothing written: {e}')
        return 2
    for k, v in report.items():
        log(f'{k}: {v}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
