"""Builds addon/Amisia/GearData.lua: every WoW Forever item a levelling character can wear, with
where it comes from. The addon's gear window (/amisia gear) reads it, asks the client for the
item's stats and picks the best item per slot and level range.

    python tools/build_gear.py [--sv <Amisia.lua>...] [--refresh-wowsrc] [--out addon/Amisia/GearData.lua]

What an item is (slot, armour or weapon type, required level, quality, bind type) comes from the
Amisia item scan (`/amisia scan`), because Forever changed a lot of Classic items and the scan
reads the Forever client. An item that is not in a scan is left out. By default the scan dumps
in the repo root and the SavedVariables of the installed Forever client are read.

Where an item comes from is joined from:
  - QuestieDB (Forever flavour, installed in the Classic Era AddOns folder): quest rewards with
    quest level, faction and zone, vendors, and drops by NPC. Its drop assignments are Classic's.
  - OneForAll (Forever AddOns folder): dungeon bosses, dungeon quests and Merchant's Favor recipes.
  - AtlasLootClassic (Forever AddOns folder): the Forever dungeon tables and the Classic crafting
    recipes (spell -> made item, profession, skill).
  - wowsrc.com dungeon loot pages (rare and better per boss with the drop chance), kept parsed in
    tools/gear_wowsrc.json. --refresh-wowsrc downloads them again; the site allows crawling.
  - The Amisia item collector (`scan.sources`): drops, merchants, quests and the auction house as a
    player met them. These names are German.

AMISIA_WOW_ROOT overrides the WoW install path.
"""
import argparse
import base64
import glob
import html
import json
import os
import re
import struct
import sys
import time
import urllib.request
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import build_scan  # noqa: E402  (scan dump parsing is shared)

WOW_ROOT = os.environ.get('AMISIA_WOW_ROOT', r'C:\Program Files (x86)\World of Warcraft')
FOREVER_ADDONS = os.path.join(WOW_ROOT, '_classic_beta_', 'Interface', 'AddOns')
QUESTIE_TOC = os.path.join(WOW_ROOT, '_classic_era_', 'Interface', 'AddOns', 'QuestieDB', 'QuestieDB_Forever.toc')
WOWSRC_JSON = os.path.join(HERE, 'gear_wowsrc.json')
FOREVER_JS = os.path.join(ROOT, 'data', 'forever.js')
FOREVER_ZONES = os.path.join(HERE, 'forever_zones.json')
ITEMSPARSE_JSON = os.path.join(HERE, 'gear_itemsparse.json')
# Questie/ItemSparse class bits of the nine Classic classes; a mask holding all of them limits nothing.
ALL_CLASSES = 1 | 2 | 4 | 8 | 16 | 64 | 128 | 256 | 1024
RXP_WEIGHTS = os.path.join(FOREVER_ADDONS, 'RXPGuides', 'DB', 'forever', 'StatWeights.lua')
OUT = os.path.join(ROOT, 'addon', 'Amisia', 'GearData.lua')
OUT_WEIGHTS = os.path.join(ROOT, 'addon', 'Amisia', 'GearWeights.lua')
GEAR_LUA = os.path.join(ROOT, 'addon', 'Amisia', 'Gear.lua')
USER_AGENT = 'AmisiaGuildTool/1.0 (+https://amisia-loot.github.io)'

# Equipment slots worth planning. Shirts, tabards, bags and ammo are left out.
EQUIP = {
    'INVTYPE_HEAD', 'INVTYPE_NECK', 'INVTYPE_SHOULDER', 'INVTYPE_CLOAK', 'INVTYPE_CHEST', 'INVTYPE_ROBE',
    'INVTYPE_WRIST', 'INVTYPE_HAND', 'INVTYPE_WAIST', 'INVTYPE_LEGS', 'INVTYPE_FEET', 'INVTYPE_FINGER',
    'INVTYPE_TRINKET', 'INVTYPE_WEAPON', 'INVTYPE_2HWEAPON', 'INVTYPE_WEAPONMAINHAND',
    'INVTYPE_WEAPONOFFHAND', 'INVTYPE_SHIELD', 'INVTYPE_HOLDABLE', 'INVTYPE_RANGED', 'INVTYPE_RANGEDRIGHT',
    'INVTYPE_THROWN', 'INVTYPE_RELIC',
}
# Questie race bits: Human 1, Orc 2, Dwarf 4, Night Elf 8, Undead 16, Tauren 32, Gnome 64, Troll 128.
ALLIANCE_RACES, HORDE_RACES = 1 | 4 | 8 | 64, 2 | 16 | 32 | 128
# Questie NPC ranks: 0 normal, 1 elite, 2 rare elite, 3 boss, 4 rare.
RARE_RANKS = {2, 4}
# Hall of Legends and Champions' Hall, where the PvP rank vendors stand.
PVP_HALLS = {2917, 2918}
# An item dropped by more NPCs than this outside instances is a world drop, not a named mob's loot.
WORLD_DROP_NPCS = 6
# The planner is about levelling: Classic raids and their quests stay out. Their items are in the
# Forever client too, which is why the scan finds them.
RAIDS = {"Molten Core", "Onyxia's Lair", "Blackwing Lair", "Zul'Gurub", "Ruins of Ahn'Qiraj",
         "Temple of Ahn'Qiraj", "Naxxramas"}
# Classic items above this item level come from raids or raid quests (AQ rings, Path of the
# Protector, Darkmoon decks); Forever's own items (id 200000 and up) are not capped.
CLASSIC_MAX_ILVL = 65
FOREVER_IDS = 200000
# GM and test items the client knows but no player gets (names come in the client's language, so by id).
TEST_ITEMS = {8350}   # The 1 Ring
# AtlasLoot profession numbers -> the key the addon translates.
ATLAS_PROF = {1: 'firstaid', 2: 'blacksmithing', 3: 'leatherworking', 4: 'alchemy', 6: 'cooking',
              8: 'tailoring', 9: 'engineering', 10: 'enchanting', 14: 'jewelcrafting'}
OFA_PROF = {'Alchemy': 'alchemy', 'Blacksmithing': 'blacksmithing', 'Leatherworking': 'leatherworking',
            'Tailoring': 'tailoring', 'Engineering': 'engineering', 'Enchanting': 'enchanting', 'Cooking': 'cooking'}


def log(*a):
    print(*a, file=sys.stderr)


# ---------------------------------------------------------------- stat weights
# The level brackets RXP's Forever weights are cut into.
BRACKETS = [(1, 9), (10, 19), (20, 29), (30, 39), (40, 49), (50, 60)]
CLASS_ORDER = ['WARRIOR', 'PALADIN', 'HUNTER', 'ROGUE', 'PRIEST', 'SHAMAN', 'MAGE', 'WARLOCK', 'DRUID']
# RXP stat keys -> the short keys the addon scores with. Hit, crit, dodge and parry weights are per
# percent, defence per skill point, everything else per point; the addon turns ratings into
# percent for the level it scores for.
RXP_KEY = {
    'ITEM_MOD_STRENGTH_SHORT': 'STR', 'ITEM_MOD_AGILITY_SHORT': 'AGI', 'ITEM_MOD_STAMINA_SHORT': 'STA',
    'ITEM_MOD_INTELLECT_SHORT': 'INT', 'ITEM_MOD_SPIRIT_SHORT': 'SPI', 'ITEM_MOD_HEALTH_REGEN_SHORT': 'HP5',
    'ITEM_MOD_POWER_REGEN0_SHORT': 'MP5', 'STAT_SPELLDAMAGE': 'SP', 'STAT_SPELLDAMAGE_ARCANE': 'SP_ARCANE',
    'STAT_SPELLDAMAGE_FIRE': 'SP_FIRE', 'STAT_SPELLDAMAGE_NATURE': 'SP_NATURE', 'STAT_SPELLDAMAGE_FROST': 'SP_FROST',
    'STAT_SPELLDAMAGE_SHADOW': 'SP_SHADOW', 'ITEM_MOD_SPELL_HEALING_DONE': 'HEAL',
    'ITEM_MOD_HIT_SPELL_RATING_SHORT': 'SHIT', 'ITEM_MOD_CRIT_SPELL_RATING_SHORT': 'SCRIT',
    'ITEM_MOD_ATTACK_POWER_SHORT': 'AP', 'ITEM_MOD_RANGED_ATTACK_POWER_SHORT': 'RAP',
    'ITEM_MOD_HIT_RATING_SHORT': 'HIT', 'ITEM_MOD_CRIT_RATING_SHORT': 'CRIT',
    'ITEM_MOD_DAMAGE_PER_SECOND_SHORT': 'DPS', 'ITEM_MOD_DAMAGE_PER_SECOND_SHORT_RANGED': 'RDPS',
    'ITEM_MOD_CR_SPEED_SHORT_2H': 'SPD_2H', 'ITEM_MOD_CR_SPEED_SHORT_MH': 'SPD_MH',
    'ITEM_MOD_CR_SPEED_SHORT_OH': 'SPD_OH', 'ITEM_MOD_CR_SPEED_SHORT_RANGED': 'SPD_RANGED',
    'RESISTANCE0_NAME': 'ARMOR', 'ITEM_MOD_DEFENSE_SKILL_RATING_SHORT': 'DEF',
    'ITEM_MOD_DODGE_RATING_SHORT': 'DODGE', 'ITEM_MOD_PARRY_RATING_SHORT': 'PARRY',
}
# Healers and tanks have no RXP weights (it is a levelling guide); these are ours, the same for
# every level. Weapon damage barely matters to them. SP weighs spell damage and HEAL healing; spell
# power, which Forever gives healing gear, counts for both.
HEALER = {'INT': 1.0, 'SPI': 0.6, 'HEAL': 1.0, 'MP5': 2.5, 'STA': 0.4, 'SCRIT': 6.0, 'HASTE': 4.0,
          'ARMOR': 0.005, 'DPS': 0.1}
TANK = {'STA': 1.5, 'ARMOR': 0.1, 'DEF': 1.5, 'DODGE': 12.0, 'PARRY': 10.0, 'BLOCK': 6.0, 'BLOCKVAL': 0.6,
        'STR': 1.0, 'AGI': 1.0, 'HIT': 4.0, 'EXP': 4.0, 'AP': 0.3, 'DPS': 4.0, 'HP5': 1.0}
OWN = {
    'heal_priest': dict(HEALER, SPI=0.9),
    'heal_druid': dict(HEALER, SPI=0.8),
    'heal_shaman': dict(HEALER, SPI=0.3, MP5=3.0),
    'heal_paladin': dict(HEALER, INT=1.1, SPI=0.2, SCRIT=8.0),
    'tank_warrior': TANK,
    'tank_paladin': dict(TANK, SP=0.5, INT=0.3, MP5=1.5),
    'tank_bear': {'STA': 1.5, 'AGI': 1.6, 'ARMOR': 0.12, 'DODGE': 12.0, 'STR': 1.2, 'DEF': 1.2, 'HIT': 4.0,
                  'EXP': 4.0, 'AP': 0.4, 'CRIT': 3.0, 'HP5': 1.0},
}
# class token, spec key, German name, role, RXP (Class, Spec) or one of OWN
SPECS = [
    ('WARRIOR', 'dps', 'Waffen/Furor', 'dps', ('Warrior', None)),
    ('WARRIOR', 'tank', 'Schutz', 'tank', 'tank_warrior'),
    ('PALADIN', 'ret', 'Vergeltung', 'dps', ('Paladin', 'Retribution')),
    ('PALADIN', 'holy', 'Heilig', 'heal', 'heal_paladin'),
    ('PALADIN', 'tank', 'Schutz', 'tank', 'tank_paladin'),
    ('HUNTER', 'dps', 'Jäger', 'dps', ('Hunter', None)),
    ('ROGUE', 'dps', 'Schurke', 'dps', ('Rogue', None)),
    ('PRIEST', 'shadow', 'Schatten', 'dps', ('Priest', 'Shadow')),
    ('PRIEST', 'disc', 'Disziplin', 'dps', ('Priest', 'Discipline')),
    ('PRIEST', 'holy', 'Heilig', 'heal', 'heal_priest'),
    ('SHAMAN', 'ele', 'Elementar', 'dps', ('Shaman', 'Elemental')),
    ('SHAMAN', 'enh', 'Verstärkung', 'dps', ('Shaman', 'Enhancement')),
    ('SHAMAN', 'resto', 'Wiederherstellung', 'heal', 'heal_shaman'),
    ('MAGE', 'frost', 'Frost', 'dps', ('Mage', 'Frost')),
    ('MAGE', 'fire', 'Feuer', 'dps', ('Mage', 'Fire')),
    ('MAGE', 'arcane', 'Arkan', 'dps', ('Mage', 'Arcane')),
    ('WARLOCK', 'affli', 'Gebrechen', 'dps', ('Warlock', 'Affliction')),
    ('WARLOCK', 'destro', 'Zerstörung', 'dps', ('Warlock', 'Destruction')),
    ('DRUID', 'balance', 'Gleichgewicht', 'dps', ('Druid', 'Balance')),
    ('DRUID', 'feral', 'Wilder Kampf', 'dps', ('Druid', 'Feral Combat')),
    ('DRUID', 'bear', 'Bär', 'tank', 'tank_bear'),
    ('DRUID', 'resto', 'Wiederherstellung', 'heal', 'heal_druid'),
]


def load_rxp_weights(path=RXP_WEIGHTS):
    """{(class, spec or None, kind, min level): {short key: weight}} from RXP's Forever StatWeights.lua."""
    from lupa.lua51 import LuaRuntime
    lua = LuaRuntime(unpack_returned_tuples=True)
    addon = lua.eval("{game = 'FOREVER'}")
    with open(path, encoding='utf-8') as fh:
        lua.eval('function(s) return assert(loadstring(s)) end')(fh.read())('RXPGuides', addon)
    out = {}
    for title, w in build_scan.lua_to_py(addon.statWeights).items():
        # RXP labels its Fire and Frost "Hardcore" sets Speedrun; the key's own word is right
        kind = 'Hardcore' if ' Hardcore ' in title else 'Speedrun'
        spec = (w.get('Spec') or '').strip() or None
        weights = {RXP_KEY[k]: round(float(v), 4) for k, v in w.items() if k in RXP_KEY and v}
        out[(w['Class'], spec, kind, int(w['MIN_LEVEL']))] = weights
    return out


def write_weights(out, rxp):
    lines = [
        '-- GENERATED by tools/build_gear.py. Do not edit; rebuild instead.',
        '-- DPS spec weights per level bracket come from RestedXP Guides (DB/forever/StatWeights.lua),',
        '-- licensed CC BY-NC-SA 4.0 (https://creativecommons.org/licenses/by-nc-sa/4.0/); this file is',
        "-- shared under the same licence. Healer and tank weights are Amisia's own.",
        'local _, ns = ...',
        'if not ns.IsForever() then return end',
        '',
        '-- Hit, crit, haste, expertise, dodge, parry and block weights are per percent, DEF per defence skill',
        '-- point, the rest per point. SPD_* weigh weapon speed by slot, DPS/RDPS melee and ranged weapon damage.',
        'ns.GEAR_WEIGHTS = {',
        '    brackets = {' + ', '.join(str(b) for _, b in BRACKETS) + '},',
        '    order = {' + ', '.join(lua_str(c) for c in CLASS_ORDER) + '},',
        '    specs = {',
    ]

    def table(w):
        return '{' + ', '.join(f'{k} = {v:g}' for k, v in sorted(w.items())) + '}'

    by_class = {}
    for cls, key, name, role, srcw in SPECS:
        by_class.setdefault(cls, []).append((key, name, role, srcw))
    for cls in CLASS_ORDER:
        lines.append(f'        {cls} = {{')
        for key, name, role, srcw in by_class[cls]:
            lines.append(f'            {{ key = {lua_str(key)}, name = {lua_str(name)}, role = {lua_str(role)},')
            if isinstance(srcw, str):
                lines.append(f'              all = {table(OWN[srcw])} }},')
                continue
            for kind in ('Speedrun', 'Hardcore'):
                lines.append(f'              {kind} = {{')
                for lo, _ in BRACKETS:
                    w = rxp.get((srcw[0], srcw[1], kind, lo))
                    if w is None:
                        raise SystemExit(f'RXP has no {kind} weights for {srcw} from level {lo}')
                    lines.append('                ' + table(w) + ',')
                lines.append('              },')
            lines[-1] = lines[-1] + ' },'
        lines.append('        },')
    lines += ['    },', '}']
    with open(out, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write('\n'.join(lines) + '\n')


# ---------------------------------------------------------------- QuestieDB (baked TOC store)
def _cbor(b, i=0):
    ib = b[i]
    mt, ai = ib >> 5, ib & 31
    i += 1
    if ai < 24:
        val = ai
    elif ai == 24:
        val = b[i]
        i += 1
    elif ai == 25:
        val = struct.unpack('>H', b[i:i + 2])[0]
        i += 2
    elif ai == 26:
        if mt == 7:
            return struct.unpack('>f', b[i:i + 4])[0], i + 4
        val = struct.unpack('>I', b[i:i + 4])[0]
        i += 4
    elif ai == 27:
        if mt == 7:
            return struct.unpack('>d', b[i:i + 8])[0], i + 8
        val = struct.unpack('>Q', b[i:i + 8])[0]
        i += 8
    else:
        raise ValueError('indefinite CBOR length is not used by QuestieDB')
    if mt == 0:
        return val, i
    if mt == 1:
        return -1 - val, i
    if mt in (2, 3):
        return b[i:i + val].decode('utf-8', 'replace'), i + val
    if mt == 4:
        out = []
        for _ in range(val):
            v, i = _cbor(b, i)
            out.append(v)
        return out, i
    if mt == 5:
        out = {}
        for _ in range(val):
            k, i = _cbor(b, i)
            v, i = _cbor(b, i)
            out[k] = v
        return out, i
    if mt == 6:
        return _cbor(b, i)
    if ai == 25:  # half float
        s, e, f = (val >> 15) & 1, (val >> 10) & 31, val & 1023
        v = (f / 1024) * 2 ** -14 if e == 0 else (1 + f / 1024) * 2 ** (e - 15)
        return (-v if s else v), i
    return {20: False, 21: True, 22: None}.get(val), i


def load_questie(toc=QUESTIE_TOC):
    """{'Item'|'Quest'|'Npc': {id: {fieldIndex: value}}} from QuestieDB's baked metadata store.

    Each entity row is base64 CBOR in `## X-<Entity>-<id>-S`; table fields sit in
    `X-<Entity>-<id>-<field>` and the row's `p` bitmask says which exist. Long values are split
    into `~N~` plus numbered parts. The id list is zlib-compressed."""
    meta = {}
    with open(toc, encoding='utf-8') as fh:
        for line in fh:
            if line.startswith('## X-'):
                k, _, v = line[3:].rstrip('\n').partition(': ')
                meta[k] = v

    def stored(key):
        v = meta.get(key)
        if v and v.startswith('~') and v.endswith('~'):
            v = ''.join(meta[f'{key}-{j}'] for j in range(1, int(v.strip('~')) + 1))
        return v

    def decode(v):
        return _cbor(base64.b64decode(v))[0]

    out = {}
    for ent in ('Item', 'Quest', 'Npc'):
        ids = _cbor(zlib.decompress(base64.b64decode(stored(f'X-{ent}-IDS'))))[0]
        rows = {}
        for i in ids:
            s = stored(f'X-{ent}-{i}-S')
            row = decode(s) if s else {}
            if isinstance(row, list):
                row = {n + 1: v for n, v in enumerate(row) if v is not None}
            p = row.pop('p', 0) or 0
            fi = 1
            while p:
                if p & 1:
                    t = stored(f'X-{ent}-{i}-{fi}')
                    if t:
                        row[fi] = decode(t)
                p >>= 1
                fi += 1
            rows[i] = row
        out[ent] = rows
    return out


def questie_zones(toc=QUESTIE_TOC):
    """(area id -> name, dungeon area ids, area id -> uiMapID) from QuestieDB's Forever zone files."""
    zdir = os.path.join(os.path.dirname(toc), 'support', 'Forever', 'Zones')
    names, dungeons, uimap, by_key = {}, {}, {}, {}
    with open(os.path.join(zdir, 'zoneIds.lua'), encoding='utf-8') as fh:
        for key, num in re.findall(r'^\s*([A-Z][A-Z0-9_]+)\s*=\s*(\d+)', fh.read(), re.M):
            names.setdefault(int(num), key.replace('_', ' ').title().replace("'S", "'s"))
            by_key.setdefault(key, int(num))
    with open(os.path.join(zdir, 'dungeons.lua'), encoding='utf-8') as fh:
        for area, name, alts in re.findall(r'\[(\d+)\]\s*=\s*\{"([^"]+)",(\{[^}]*\}|nil)', fh.read()):
            dungeons[int(area)] = name
            for a in re.findall(r'\d+', alts):
                dungeons[int(a)] = name
            names[int(area)] = name
    with open(os.path.join(zdir, 'areaIdToUiMapId.lua'), encoding='utf-8') as fh:
        for area, ui in re.findall(r'\[(\d+)\]\s*=\s*(\d+)', fh.read()):
            uimap.setdefault(int(area), int(ui))
    instances = {}
    with open(os.path.join(zdir, 'instanceIdToAreaId.lua'), encoding='utf-8') as fh:
        for inst, key in re.findall(r'\[(\d+)\]\s*=\s*ZoneDB\.zoneIDs\.([A-Z0-9_]+)', fh.read()):
            if key in by_key:
                instances[int(inst)] = by_key[key]
    return names, dungeons, uimap, instances


# ---------------------------------------------------------------- OneForAll
def load_oneforall(base=os.path.join(FOREVER_ADDONS, 'OneForAll')):
    from lupa.lua51 import LuaRuntime
    lua = LuaRuntime(unpack_returned_tuples=True)
    flt = lua.eval('{}')
    loader = lua.eval('function(s, n) return assert(loadstring(s, n)) end')
    for rel in ['Data.lua', 'ProfessionData.lua', 'DungeonJournalData.lua'] + sorted(
            os.path.relpath(p, base) for p in glob.glob(os.path.join(base, 'Data', 'Dungeons', '*.lua'))):
        with open(os.path.join(base, rel), encoding='utf-8') as fh:
            loader(fh.read(), '@' + rel)('OneForAll', flt)
    py = build_scan.lua_to_py
    return py(flt.DUNGEON_JOURNAL_DB) or {}, py(flt.PROFESSION_DATA) or {}


# ---------------------------------------------------------------- AtlasLoot
def load_atlas_forever_dungeons(path=os.path.join(FOREVER_ADDONS, 'AtlasLootClassic_DungeonsAndRaids', 'data.lua')):
    """[(dungeon name, (min, recMin, recMax) or None, boss name, item id, comment, instance id, area id)]
    for the Forever-only dungeons; the ids are None where the table has none."""
    with open(path, encoding='utf-8') as fh:
        src = fh.read()
    out = []
    for m in re.finditer(r'data\["(\w+)"\] = \{(.*?)\n\}\n', src, re.S):
        body = m.group(2)
        if 'FOREVER_DUNGEON_CONTENT' not in body:
            continue
        name = re.search(r'name = "([^"]+)"', body).group(1)
        lr = re.search(r'LevelRange = \{ *(\d+), *(\d+), *(\d+)', body)
        lr = tuple(int(x) for x in lr.groups()) if lr else None
        inst = re.search(r'\n\s*InstanceID = (\d+)', body)
        area = re.search(r'\n\s*MapID = (\d+)', body)
        inst, area = (int(inst.group(1)) if inst else None), (int(area.group(1)) if area else None)
        for boss, rows in re.findall(r'name = "([^"]+)",\s*\[NORMAL_DIFF\] = \{(.*?)\n\t\t\t\}', body, re.S):
            for item, comment in re.findall(r'\{ *\d+, *(\d+) *\}, *-- *([^\n]*)', rows):
                out.append((name, lr, boss, int(item), comment.strip(), inst, area))
    return out


def load_forever_raids(path=FOREVER_JS, zones_cfg=None):
    """[(raid name, boss, item id, instance id, area id)] from the site's Forever tables, for the zones
    tools/forever_zones.json marks "raid": true (with optional "instance" and "area" ids)."""
    if zones_cfg is None:
        with open(FOREVER_ZONES, encoding='utf-8') as fh:
            zones_cfg = json.load(fh)
    if not os.path.exists(path):
        return []
    with open(path, encoding='utf-8') as fh:
        s = fh.read()
    data = json.loads(s[s.index('={') + 1:].rstrip().rstrip(';'))
    raid_zones = {}
    for z in data.get('zones', []):
        cfg = zones_cfg.get(z['name'])
        if isinstance(cfg, dict) and cfg.get('raid'):
            raid_zones[z['key']] = (z['name'], cfg.get('instance') or 0, cfg.get('area') or 0)
    boss_zone = {b['name']: b['zone'] for b in data.get('bosses', [])}
    out = []
    for it in data.get('items', []):
        for boss in it.get('sources') or []:
            z = raid_zones.get(boss_zone.get(boss))
            if z:
                out.append((z[0], boss, it['id'], z[1], z[2]))
    return sorted(set(out))


def load_atlas_crafts(path=os.path.join(FOREVER_ADDONS, 'AtlasLootClassic', 'Data', 'Profession.lua')):
    """{made item id: [(profession key, required skill)]} from the CLASSIC recipe block.

    Spell ids from 100000 up are Season of Discovery and later Era recipes, which Forever does
    not have; its own new recipes come from OneForAll."""
    with open(path, encoding='utf-8') as fh:
        src = fh.read()
    block = src[src.index('PROFESSION_DATA.CLASSIC'):src.index('PROFESSION_DATA.BCC')]
    out = {}
    for spell, item, prof, skill in re.findall(r'\[(\d+)\] = \{ *(\d+), *(\d+), *(\d+),', block):
        if int(spell) >= 100000 or int(prof) not in ATLAS_PROF:
            continue
        out.setdefault(int(item), []).append((ATLAS_PROF[int(prof)], int(skill)))
    return out


# ---------------------------------------------------------------- wowsrc.com
def refresh_wowsrc(path=WOWSRC_JSON):
    """Downloads every dungeon loot page wowsrc lists and keeps what lies in each boss section."""
    def get(url):
        req = urllib.request.Request(url, headers={'User-Agent': USER_AGENT})
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.read().decode('utf-8')
    sitemap = get('https://wowsrc.com/sitemap-0.xml')
    slugs = sorted(set(re.findall(r'https://wowsrc.com/loot/([a-z0-9-]+)/', sitemap)))
    dungeons = []
    for slug in slugs:
        page = get(f'https://wowsrc.com/loot/{slug}/')
        dungeons.append(parse_wowsrc(page, slug))
        time.sleep(1)
    with open(path, 'w', encoding='utf-8') as fh:
        json.dump({'fetched': time.strftime('%Y-%m-%d'), 'dungeons': dungeons}, fh, ensure_ascii=False, indent=1)
    log(f'wowsrc: {len(dungeons)} dungeons -> {os.path.relpath(path, ROOT)}')


def parse_wowsrc(page, slug):
    name = html.unescape(re.search(r'<h1[^>]*>(.*?)</h1>', page, re.S).group(1)).strip()
    bosses = []
    for boss, body in re.findall(r'<section class="bc" id="[^"]*"[^>]*>\s*<h2[^>]*>(.*?)</h2>(.*?)</section>', page, re.S):
        items = []
        for tip in re.findall(r'data-tip="([^"]*)"', body):
            d = json.loads(html.unescape(tip))
            items.append({'n': d.get('n'), 'l': d.get('l'), 'd': d.get('d'), 'nw': bool(d.get('nw'))})
        bosses.append({'name': html.unescape(boss).strip(), 'items': items})
    return {'slug': slug, 'name': name, 'bosses': bosses}


# ---------------------------------------------------------------- ItemSparse (client item table)
def refresh_itemsparse(csv_path, scan_items, path=ITEMSPARSE_JSON):
    """Keeps what the addon needs from an ItemSparse export: class limits, weapon speed and the
    profession an item needs to be worn (engineering goggles).

    The export comes from wago.tools (product wow_classic_beta, with hotfixes):
    https://wago.tools/db2/ItemSparse/csv?build=<build>&useHotfixes=1"""
    import csv
    classes, delay, skill = {}, {}, {}
    with open(csv_path, encoding='utf-8') as fh:
        for row in csv.DictReader(fh):
            iid = int(row['ID'])
            it = scan_items.get(iid)
            if not it or it['equipLoc'] not in EQUIP:
                continue
            mask = int(row.get('AllowableClass') or -1)
            if mask > 0 and mask & ALL_CLASSES != ALL_CLASSES:
                classes[str(iid)] = mask & ALL_CLASSES
            d = int(row.get('ItemDelay') or 0)
            if d > 0 and it['classID'] == build_scan.CLASS_WEAPON:
                delay[str(iid)] = d
            line = int(row.get('RequiredSkill') or 0)
            if line > 0:
                skill[str(iid)] = [line, int(row.get('RequiredSkillRank') or 0)]
    with open(path, 'w', encoding='utf-8') as fh:
        json.dump({'source': os.path.basename(csv_path), 'classes': classes, 'delay': delay, 'skill': skill}, fh,
                  indent=0, sort_keys=True)
    log(f'itemsparse: {len(classes)} class-limited items, {len(delay)} weapon speeds, {len(skill)} need a profession '
        f'-> {os.path.relpath(path, ROOT)}')


# ---------------------------------------------------------------- joining
class Sources:
    """Interns source records so items can point at them by number."""

    def __init__(self):
        self.rows, self.index = [], {}

    def add(self, *rec):
        rec = tuple(rec)
        while rec and rec[-1] is None:
            rec = rec[:-1]
        if rec not in self.index:
            self.index[rec] = len(self.rows) + 1
            self.rows.append(rec)
        return self.index[rec]


def faction_of(races):
    races = races or 0
    a, h = bool(races & ALLIANCE_RACES), bool(races & HORDE_RACES)
    return 'A' if a and not h else 'H' if h and not a else None


def npc_faction(npc):
    f = str(npc.get(13) or '')
    return 'A' if f == 'A' else 'H' if f == 'H' else None


def is_pvp_vendor(npc):
    """PvP rank quartermasters: their gear needs an honour rank, not just gold."""
    title = str(npc.get(14) or '')
    return (npc.get(9) in PVP_HALLS or 'Quartermaster' in title and ('Armor' in title or 'Accessories' in title)
            or 'Legacy' in title)


def norm_name(s):
    return re.sub(r'[^a-z0-9]+', '', (s or '').lower())


def drop_chance(text):
    """Percent from a dungeon page's chance ("12.5%", "<0.1%"); unknown counts as certain."""
    m = re.search(r'([\d.]+)', str(text or ''))
    if not m:
        return 100.0
    v = float(m.group(1))
    return v / 2 if str(text).lstrip().startswith('<') else v


def dungeon_key(name):
    """Dungeon names differ between the sources ("The Deadmines", "Deadmines", "Scarlet Monastery -
    Armory"); this key compares them by containment."""
    return re.sub(r'^the', '', norm_name(name))


def pick_id(ids, scan_items, new_in_forever=False):
    """The item id a dungeon page's name means: one the Forever scan knows, the Forever remake
    (id 200000 and up) when the page marks the item new, else the Classic original."""
    ids = sorted(i for i in (ids or ()) if i in scan_items)
    if not ids:
        return None
    if new_in_forever:
        return ids[-1]
    old = [i for i in ids if i < 200000]
    return old[0] if old else ids[0]


def merge_dungeon_sources(nums, rows):
    """One boss is often listed by several sources. A dungeon page with a drop chance wins over the
    others for that dungeon; otherwise the same boss is kept once, and "Trash" goes when a boss of
    that dungeon is named."""
    recs = [(n, rows[n - 1]) for n in nums]
    with_chance = [dungeon_key(r[1]) for _, r in recs if r[0] == 'D' and len(r) > 3 and r[3]]
    named = {dungeon_key(r[1]) for _, r in recs if r[0] == 'D' and r[2] != 'Trash'}
    out, seen = [], set()

    def related(a, b):
        return a in b or b in a

    for n, r in recs:
        if r[0] == 'D':
            key = dungeon_key(r[1])
            chance = len(r) > 3 and r[3]
            # a record with a drop chance always stays; the others give way to it, and trash to a boss
            if not chance and any(related(key, k) for k in with_chance):
                continue
            if not chance and r[2] == 'Trash' and any(related(key, k) for k in named):
                continue
            sig = (key, norm_name(r[2]))
            if sig in seen:
                continue
            seen.add(sig)
        out.append(n)
    return out


def build(scan_items, collected, questie, zones, ofa, atlas_dungeons, atlas_crafts, wowsrc, itemsparse=None,
          forever_raids=None):
    zone_names, dungeon_areas, uimap = zones[:3]
    instances = zones[3] if len(zones) > 3 else {}
    area_instance = {}
    for inst, area in sorted(instances.items()):
        area_instance.setdefault(area, inst)

    def place_of(dname, area=None):
        """(instance id, area id) of a dungeon, by its area or else by its name; None where unknown.
        "Here" in game finds the dungeon through them (GetInstanceInfo)."""
        if not area:
            key = dungeon_key(dname)
            exact = sorted(a for a, n in dungeon_areas.items() if dungeon_key(n) == key)
            near = sorted(a for a, n in dungeon_areas.items() if key and (key in dungeon_key(n) or dungeon_key(n) in key))
            # an area with an instance id first: a dungeon's other areas are only aliases
            area = sorted(exact or near or [None], key=lambda a: (a not in area_instance, a or 0))[0]
        return area_instance.get(area) if area else None, area or None
    q_items, q_quests, q_npcs = questie['Item'], questie['Quest'], questie['Npc']
    src = Sources()
    found = {}   # item id -> list of source numbers
    stats = {}

    def note(item, num, kind):
        lst = found.setdefault(item, [])
        if num not in lst:
            lst.append(num)
            stats[kind] = stats.get(kind, 0) + 1

    def zone(area):
        if not area or area <= 0:
            return None
        return uimap.get(area) or None, zone_names.get(area)

    zone_rows = {}

    def zone_ref(area):
        z = zone(area)
        if not z or not (z[0] or z[1]):
            return None
        key = z[0] or -area
        zone_rows.setdefault(key, z[1] or '')
        return key

    text_zones = {}

    def zone_text_ref(name):
        """A zone the collector wrote down by name (the client's language) gets a key of its own."""
        if not name:
            return None
        if name not in text_zones:
            text_zones[name] = -(1000000 + len(text_zones))
            zone_rows[text_zones[name]] = name
        return text_zones[name]

    # English item names, for matching the wowsrc pages. One name can belong to a Classic item and a
    # Forever remake of it, so every id is kept and the match is picked later.
    by_name = {}

    def name_id(name, iid):
        by_name.setdefault(norm_name(name), set()).add(iid)

    for iid, row in q_items.items():
        name_id(row.get(1), iid)

    # Boss names the dungeon sources know, so a Questie drop can tell a boss from trash
    known_bosses = {}
    for dname, d in (ofa[0] or {}).items():
        for boss in d.get('bosses') or []:
            known_bosses.setdefault(dungeon_key(dname), set()).add(norm_name(boss.get('name')))
    for dname, _, boss, *_ in atlas_dungeons:
        known_bosses.setdefault(dungeon_key(dname), set()).add(norm_name(boss))
    for d in (wowsrc or {}).get('dungeons', []):
        for boss in d['bosses']:
            known_bosses.setdefault(dungeon_key(d['name']), set()).add(norm_name(boss['name']))

    def is_boss(dname, npc_name):
        key, name = dungeon_key(dname), norm_name(npc_name)
        return any(name in bosses for k, bosses in known_bosses.items() if k in key or key in k)

    # --- QuestieDB: quests, vendors, NPC drops
    for iid, row in q_items.items():
        for qid in row.get(6) or []:
            q = q_quests.get(qid)
            if not q:
                continue
            area = q.get(17) if isinstance(q.get(17), int) else 0
            if dungeon_areas.get(area) in RAIDS:
                continue
            num = src.add('Q', q.get(1) or f'Quest {qid}', q.get(5) or 0, q.get(4) or 0, faction_of(q.get(6)),
                          zone_ref(area), qid, q.get(7) or 0)
            note(iid, num, 'quest')
        for nid in row.get(14) or []:
            n = q_npcs.get(nid)
            if not n:
                continue
            title = n.get(14) or None
            kind = 'P' if is_pvp_vendor(n) else 'V'
            num = src.add(kind, n.get(1) or f'NPC {nid}', zone_ref(n.get(9) or 0), npc_faction(n), title, None, nid)
            note(iid, num, 'pvp' if kind == 'P' else 'vendor')
        drops = [dict(q_npcs[n], id=n) for n in (row.get(2) or []) if n in q_npcs]
        if not drops:
            continue
        drops = [n for n in drops if dungeon_areas.get(n.get(9) or 0) not in RAIDS]
        inside = [n for n in drops if (n.get(9) or 0) in dungeon_areas]
        outside = [n for n in drops if n not in inside]
        for n in inside:
            dname = dungeon_areas[n.get(9)]
            boss = n.get(1) if is_boss(dname, n.get(1)) or len(inside) == 1 or (n.get(6) or 0) == 3 else None
            if boss:
                note(iid, src.add('D', dname, boss, None, *place_of(dname, n.get(9))), 'dungeon')
            else:
                # trash loot is a random drop: listed with the world drops
                note(iid, src.add('W', f'Trash ({dname})', n.get(4) or 0, n.get(5) or 0), 'world')
        rares = [n for n in outside if (n.get(6) or 0) in RARE_RANKS]
        for n in rares:
            note(iid, src.add('R', n.get(1), n.get(4) or 0, zone_ref(n.get(9) or 0), n['id']), 'rare')
        common = [n for n in outside if n not in rares]
        if len(common) > WORLD_DROP_NPCS:
            lv = sorted(x for n in common for x in (n.get(4) or 0, n.get(5) or 0) if x)
            note(iid, src.add('W', None, lv[0] if lv else 0, lv[-1] if lv else 0), 'world')
        else:
            for n in common:
                note(iid, src.add('W', n.get(1), n.get(4) or 0, n.get(5) or 0, zone_ref(n.get(9) or 0), n['id']), 'world')

    # --- OneForAll dungeons and dungeon quests
    for dname, d in (ofa[0] or {}).items():
        for boss in d.get('bosses') or []:
            for tup in boss.get('loot') or []:
                if isinstance(tup, list) and tup and isinstance(tup[0], int):
                    note(tup[0], src.add('D', dname, boss.get('name') or '?', None, *place_of(dname)), 'dungeon')
                    if len(tup) > 1:
                        name_id(tup[1], tup[0])
        for q in d.get('quests') or []:
            fac = {'Alliance': 'A', 'Horde': 'H'}.get(q.get('faction'))
            for tup in q.get('rewardItems') or []:
                if isinstance(tup, list) and tup and isinstance(tup[0], int):
                    num = src.add('Q', q.get('name') or '?', q.get('level') or 0, q.get('requires') or 0, fac, None,
                                  q.get('id'), 0, dname)
                    note(tup[0], num, 'quest')
                    if len(tup) > 1:
                        name_id(tup[1], tup[0])
    for prof, recipes in (ofa[1] or {}).items():
        key = OFA_PROF.get(prof)
        for r in (recipes or {}).values():
            item = r.get('craftedItemID')
            if key and item:
                note(item, src.add('C', key, r.get('requiredSkill') or 0), 'craft')

    # --- AtlasLoot: Forever dungeons and Classic recipes
    for dname, lr, boss, item, comment, *ids in atlas_dungeons:
        inst, area = (ids + [None, None])[:2]
        if not inst and not area:
            inst, area = place_of(dname)
        note(item, src.add('D', dname, boss, None, inst, area), 'dungeon')
        name_id(re.sub(r'\s*\(.*$', '', comment.replace('{FOREVER}', '')), item)
    for item, profs in atlas_crafts.items():
        for key, skill in profs:
            note(item, src.add('C', key, skill), 'craft')

    # --- wowsrc dungeon pages: drop chances, and loot of dungeons the other sources lack
    unmatched = []
    missing = set()   # gear the sources name that no scan has seen: /amisia scan gear asks for it
    for d in (wowsrc or {}).get('dungeons', []):
        for boss in d['bosses']:
            bname = 'Trash' if boss['name'].lower() == 'trash' else boss['name']
            for it in boss['items']:
                ids = by_name.get(norm_name(it['n']))
                iid = pick_id(ids, scan_items, it.get('nw'))
                if not iid:
                    # no id for the name at all, or an item the scan never saw (Forever still hides
                    # many items from the client until they are revealed; a new scan picks them up)
                    unmatched.append(f"{d['name']}: {it['n']}" + ('' if ids else ' (no item id)'))
                    if ids:
                        missing.add(pick_id(ids, {i: True for i in ids}, it.get('nw')))
                    continue
                if drop_chance(it.get('d')) < 1:
                    # below one percent nobody farms it: a random drop like the world drops
                    note(iid, src.add('W', f"{d['name']}: {bname} {it.get('d')}", 0, 0), 'world')
                else:
                    note(iid, src.add('D', d['name'], bname, it.get('d'), *place_of(d['name'])), 'dungeon')

    # --- the collector: what players met in the Forever client
    for iid, notes in collected.items():
        for text in notes:
            n = build_scan.parse_note(text)
            if not n:
                continue
            if n['kind'] == 'ah':
                note(iid, src.add('A'), 'ah')
            elif n['kind'] == 'quest':
                q = q_quests.get(n['id']) if n['id'] else None
                if q:
                    area = q.get(17) if isinstance(q.get(17), int) else 0
                    if dungeon_areas.get(area) in RAIDS:
                        continue
                    num = src.add('Q', q.get(1) or n['name'], q.get(5) or 0, q.get(4) or 0, faction_of(q.get(6)),
                                  zone_ref(area), n['id'], q.get(7) or 0)
                else:
                    # a quest Questie does not know: the player's level stands in for the quest level
                    num = src.add('Q', n['name'] or '?', n['level'] or 0, 0, None, None, n['id'])
                note(iid, num, 'quest')
            elif n['kind'] == 'vendor':
                npc = q_npcs.get(n['id']) if n['id'] else None
                name = (npc and npc.get(1)) or n['name'] or '?'
                zone_key = zone_ref(npc.get(9) or 0) if npc else zone_text_ref(n['place'])
                note(iid, src.add('V', name, zone_key, npc_faction(npc) if npc else None,
                                  (npc.get(14) or None) if npc else None, None, n['id'] or None), 'vendor')
            else:
                if n['itype'] == 'raid':
                    continue
                npc = q_npcs.get(n['id']) if n['id'] else None
                name = (npc and npc.get(1)) or n['name'] or (f"NPC {n['id']}" if n['id'] else None)
                if not name:
                    continue
                if n['itype'] == 'party':
                    area = instances.get(n['instance'])
                    dname = dungeon_areas.get(area) if area else None
                    if dname in RAIDS:
                        continue
                    note(iid, src.add('D', dname or n['place'] or '?', name, None, n['instance'] or None, area), 'dungeon')
                elif npc and (npc.get(6) or 0) in RARE_RANKS:
                    note(iid, src.add('R', name, npc.get(4) or 0, zone_ref(npc.get(9) or 0), n['id']), 'rare')
                else:
                    lo = (npc.get(4) or 0) if npc else 0
                    hi = (npc.get(5) or 0) if npc else 0
                    zone_key = zone_ref(npc.get(9) or 0) if npc else zone_text_ref(n['place'])
                    note(iid, src.add('W', name, lo, hi, zone_key, n['id'] or None), 'world')

    # --- Forever raids the site has recorded: raid, boss, instance, area, phase 1, no token
    for rname, boss, iid, inst, area in forever_raids or []:
        note(iid, src.add('X', rname, boss, inst or 0, area or 0, 1, 0), 'raid')

    # --- keep what the Forever scan knows and a character can wear
    keep = {}
    dropped = {'not scanned': 0, 'not gear': 0, 'quality': 0, 'junk': 0, 'raid level': 0}
    itemsparse = itemsparse or {}
    classes, delays, skills = itemsparse.get('classes', {}), itemsparse.get('delay', {}), itemsparse.get('skill', {})
    for iid, nums in found.items():
        nums = merge_dungeon_sources(nums, src.rows)
        it = scan_items.get(iid)
        if not it:
            dropped['not scanned'] += 1
            # worth asking the client again when Questie calls it a weapon or armour, or a dungeon
            # or crafting source names it
            q = q_items.get(iid)
            kinds = {src.rows[n - 1][0] for n in nums}
            if (q and q.get(12) in (2, 4)) or (not q and kinds & {'D', 'C', 'Q'}):
                missing.add(iid)
            continue
        if it['equipLoc'] not in EQUIP or it['classID'] not in (build_scan.CLASS_WEAPON, build_scan.CLASS_ARMOR):
            dropped['not gear'] += 1
            continue
        if iid in TEST_ITEMS or build_scan.JUNK_NAME.search(it['name'] or ''):
            dropped['junk'] += 1
            continue
        kinds = {src.rows[n - 1][0] for n in nums}
        if iid < FOREVER_IDS and it['ilvl'] > CLASSIC_MAX_ILVL and 'X' not in kinds:
            dropped['raid level'] += 1
            continue
        if kinds == {'P'} and it['q'] < 3:
            dropped['quality'] += 1
            continue
        # grey is never worth it, white only as a quest reward or crafted
        if it['q'] < 1 or (it['q'] == 1 and not kinds & {'Q', 'C'}):
            dropped['quality'] += 1
            continue
        level = it['min'] or 0
        # a quest is done about four levels below its own level, and never before it can be taken
        quest_levels = [max(src.rows[n - 1][3] or 0, (src.rows[n - 1][2] or 0) - 4)
                        for n in nums if src.rows[n - 1][0] == 'Q']
        if kinds == {'Q'} and quest_levels:
            level = max(level, min(quest_levels))
        # an item that binds on pickup and is only crafted needs the skill yourself: about five
        # points per level, as a levelling profession grows
        if kinds == {'C'} and it['bind'] == 1:
            skill = min(src.rows[n - 1][2] or 0 for n in nums)
            level = max(level, min(60, -(-skill // 5)))
        mask = int(classes.get(str(iid), 0))
        speed = round(int(delays.get(str(iid), 0)) / 1000, 2)
        line, rank = skills.get(str(iid), (0, 0))
        if line:
            # worn only with the profession, so not before that skill is reached
            level = max(level, min(60, -(-rank // 5)))
        keep[iid] = (it, nums, level, mask, speed, line)
    return src, keep, zone_rows, stats, dropped, unmatched, sorted(missing)


# ---------------------------------------------------------------- scanned stats
def scored_stat_keys(path=GEAR_LUA):
    """The client stat keys Gear.lua scores (its STAT table), without ITEM_MOD_ and _SHORT."""
    with open(path, encoding='utf-8') as fh:
        src = fh.read()
    block = src[src.index('local STAT = {'):src.index('Gear.STAT = STAT')]
    return {re.sub(r'^ITEM_MOD_|_SHORT$', '', k) for k in re.findall(r'\b([A-Z][A-Z0-9_]+) = "', block)}


def compact_stats(text, keys):
    """A scan's stat field, cut to what the planner scores: "STRENGTH_SHORT=5;FIRE_RESISTANCE_SHORT=3"
    becomes "STRENGTH=5". Gear.lua reads it back through STAT["ITEM_MOD_" .. key] or STAT[key]."""
    out = []
    for part in (text or '').split(';'):
        k, _, v = part.partition('=')
        k = re.sub(r'_SHORT$', '', k)
        if k in keys and v:
            out.append(f'{k}={v}')
    return ';'.join(out)


# ---------------------------------------------------------------- Lua output
_LUA_ESCAPES = {'\\': '\\\\', '"': '\\"', '\n': '\\n', '\r': '\\r', '\t': '\\t'}


def lua_str(s):
    """A Lua string literal: quotes, backslashes and every control character escaped, so a name
    with a line break or a stray control byte cannot break the generated file."""
    out = []
    for ch in str(s):
        if ch in _LUA_ESCAPES:
            out.append(_LUA_ESCAPES[ch])
        elif ord(ch) < 32 or ord(ch) == 127:
            out.append('\\%03d' % ord(ch))
        else:
            out.append(ch)
    return '"' + ''.join(out) + '"'


def lua_val(v):
    if v is None:
        return 'nil'
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, (int, float)):
        return str(v)
    return lua_str(v)


def write_lua(out, src, keep, zone_rows, info, missing=()):
    used = sorted({n for k in keep.values() for n in k[1]})
    renum = {n: i + 1 for i, n in enumerate(used)}
    zones_used = {}
    lines = [
        '-- GENERATED by tools/build_gear.py. Do not edit; rebuild instead.',
        '-- Sources: QuestieDB (GPL-3.0), OneForAll, AtlasLootClassic (GPL-2.0), wowsrc.com, the Amisia item scan.',
        'local _, ns = ...',
        'if not ns.IsForever() then return end',
        '',
        '-- S: source records. Q quest {name, quest level, minimum level, faction, zone, quest id, class mask, dungeon},',
        '-- D dungeon {dungeon, boss, drop chance, instance id, area id}, X raid {raid, boss, instance id, area id,',
        '-- phase, token}, R rare mob {name, level, zone, npc id}, W world drop {mob or nil,',
        '-- min level, max level, zone, npc id}, V vendor {name, zone, faction, title, phase (nil), npc id}, P PvP rank vendor (as V),',
        '-- C crafted {profession, skill}, A seen at the auction house. Zones are uiMapIDs (localised in game) or negative area ids.',
        '-- ST: [itemID] = the client stats the scan saw, scored keys only ("STRENGTH=5;RESISTANCE0_NAME=40"). M: ids the',
        '-- sources name but no scan has seen yet; /amisia scan gear asks the client for them.',
        '-- I: [itemID] = {equipLoc, classID, subclassID, level, quality, bind, item level, class mask, weapon speed,',
        '-- profession needed to wear it (skill line, 0 none), source...}. Level is the required level, or later: the',
        '-- level its quest can be taken (quest-only items) or the profession skill / 5. Class mask 0 means every',
        '-- class (bits as in S.Q); speed 0 for non-weapons.',
        'ns.GEAR = {',
        f'    game = "forever", cap = 60, built = {lua_str(info["built"])},',
        '    S = {',
    ]
    for n in used:
        rec = src.rows[n - 1]
        lines.append('        {' + ', '.join(lua_val(v) for v in rec) + '},')
        for v in rec[1:]:
            if isinstance(v, int) and v in zone_rows:
                zones_used[v] = zone_rows[v]
    lines.append('    },')
    lines.append('    Z = {')
    for k in sorted(zones_used):
        lines.append(f'        [{k}] = {lua_str(zones_used[k])},')
    lines.append('    },')
    lines.append('    I = {')
    for iid in sorted(keep):
        it, nums, level, mask, speed, line = keep[iid]
        vals = [lua_str(it['equipLoc'].replace('INVTYPE_', '')), it['classID'], it['subclassID'], level, it['q'],
                it['bind'], it['ilvl'], mask, f'{speed:g}', line] + sorted(renum[n] for n in nums)
        lines.append(f'        [{iid}] = {{' + ', '.join(str(v) for v in vals) + '},')
    lines.append('    },')
    # the client's stats from the scan, cut to what the planner scores
    keys = scored_stat_keys()
    lines.append('    ST = {')
    for iid in sorted(keep):
        st = compact_stats(keep[iid][0].get('stats'), keys)
        if st:
            lines.append(f'        [{iid}] = {lua_str(st)},')
    lines.append('    },')
    lines.append('    M = {')
    for i in range(0, len(missing), 20):
        lines.append('        ' + ', '.join(str(x) for x in missing[i:i + 20]) + ',')
    lines.append('    },')
    lines.append('}')
    with open(out, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write('\n'.join(lines) + '\n')
    return len(used)


def default_svs():
    paths = [os.path.join(ROOT, f) for f in ('Amisia_teil1.lua', 'Amisia_teil2.lua')]
    paths += sorted(glob.glob(os.path.join(WOW_ROOT, '_classic_beta_', 'WTF', 'Account', '*', 'SavedVariables', 'Amisia.lua')))
    return [p for p in paths if os.path.exists(p)]


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--sv', nargs='*', help='Amisia SavedVariables files with item scans (default: repo dumps + installed Forever client)')
    ap.add_argument('--out', default=OUT)
    ap.add_argument('--refresh-wowsrc', action='store_true', help='download the wowsrc.com dungeon pages again')
    ap.add_argument('--show-unmatched', action='store_true')
    ap.add_argument('--itemsparse', help='ItemSparse CSV export of the Forever client (wago.tools, with hotfixes); '
                                         'refreshes tools/gear_itemsparse.json')
    args = ap.parse_args(argv)

    svs = args.sv or default_svs()
    if not svs:
        raise SystemExit('no Amisia SavedVariables with an item scan found; pass --sv')
    scan_items, _, collected = build_scan.collect([build_scan.load_sv(p) for p in svs])
    log(f'scan: {len(scan_items)} items from {len(svs)} file(s), {len(collected)} with collector notes')

    if args.refresh_wowsrc or not os.path.exists(WOWSRC_JSON):
        refresh_wowsrc()
    with open(WOWSRC_JSON, encoding='utf-8') as fh:
        wowsrc = json.load(fh)

    if args.itemsparse:
        refresh_itemsparse(args.itemsparse, scan_items)
    itemsparse = {}
    if os.path.exists(ITEMSPARSE_JSON):
        with open(ITEMSPARSE_JSON, encoding='utf-8') as fh:
            itemsparse = json.load(fh)
    else:
        log('no tools/gear_itemsparse.json: class limits and weapon speeds come from tooltips in game')

    questie = load_questie()
    zones = questie_zones()
    ofa = load_oneforall()
    atlas_dungeons = load_atlas_forever_dungeons()
    atlas_crafts = load_atlas_crafts()
    forever_raids = load_forever_raids()
    log(f'questie: {len(questie["Item"])} items, {len(questie["Quest"])} quests, {len(questie["Npc"])} npcs; '
        f'oneforall: {len(ofa[0])} dungeons; atlasloot: {len(atlas_dungeons)} forever dungeon rows, '
        f'{len(atlas_crafts)} crafted items; wowsrc: {len(wowsrc.get("dungeons", []))} dungeons; '
        f'forever raids: {len(forever_raids)} drops')

    src, keep, zone_rows, stats, dropped, unmatched, missing = build(
        scan_items, collected, questie, zones, ofa, atlas_dungeons, atlas_crafts, wowsrc, itemsparse, forever_raids)
    n_src = write_lua(args.out, src, keep, zone_rows, {'built': time.strftime('%Y-%m-%d')}, missing)
    with_stats = sum(1 for k in keep.values() if k[0].get('stats'))
    log(f'stats from the scan: {with_stats} of {len(keep)} items; {len(missing)} ids for /amisia scan gear')
    write_weights(OUT_WEIGHTS, load_rxp_weights())
    log(f'links found: {stats}')
    log(f'left out: {dropped}')
    no_id = sum(1 for u in unmatched if u.endswith('(no item id)'))
    log(f'wowsrc items left out: {len(unmatched) - no_id} not in the scan (hidden by Forever until revealed), '
        f'{no_id} without an item id')
    if args.show_unmatched:
        for u in unmatched:
            log('  ' + u)
    log(f'{os.path.relpath(args.out, ROOT)}: {len(keep)} items, {n_src} sources, {os.path.getsize(args.out) // 1024} KB')


if __name__ == '__main__':
    main()
