"""Builds addon/Amisia/BisDataTBC.lua and addon/Amisia/BisWeightsTBC.lua: every item a TBC
Anniversary character can get from the loot tables (raids, dungeons normal and heroic, reputation,
badge vendors, world epics, crafting), where it comes from, and Amisia's own stat weights for
level 70. The addon's gear page scores them with the client's stats and shows the best items per
slot. Runs without a WoW install.

    python tools/build_bis.py [--refresh-atlas] [--item-csv <Item.csv> --itemsparse <ItemSparse.csv>]
                              [--wow-root <path>] [--sv <Amisia.lua>...]

Sources (named with their licences in tools/README.md and in the header of BisDataTBC.lua):
  - The TBC files of a GPL-2.0 loot table collection on GitHub (ATLAS_REPO): the dungeon and raid
    tables, reputation rewards, badge vendors and world epics, the TBC crafting tables with the
    recipe list (spell -> made item, profession, skill) and the tier tokens.
    --refresh-atlas downloads them into tools/cache/atlasloot-tbc/ (not in git) and keeps what is
    read from them in tools/bis_atlas_tbc.json, so a build needs no network and repeats exactly.
  - The Amisia loot tables: the raid phases (PHASES.tbc in index.html) and the German raid boss
    names (data/bossnames.js). With --wow-root the German names of every boss come from the locale
    files of the installed copy of those tables instead (PC only).
  - Optional: wago.tools exports of the Anniversary client's Item and ItemSparse tables (--item-csv,
    --itemsparse; downloaded by hand in a browser) fill item type, level, quality, class limits and
    weapon speed and leave out what cannot be worn; the selection is kept in tools/bis_tbc_items.json.
    Without them the addon fills those fields in game from the client.
  - Optional: Amisia item scans from Anniversary (--sv): the client's stats go into the file (ST).
"""
import argparse
import csv
import json
import os
import re
import sys
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import build_gear  # noqa: E402  (source interning, Lua output, scanned stats)
import build_scan  # noqa: E402

ATLAS_REPO = 'Hoizame/AtlasLootClassic'
ATLAS_RAW = 'https://raw.githubusercontent.com/{repo}/{ref}/{path}'
ATLAS_FILES = {
    'dungeons': 'AtlasLootClassic_DungeonsAndRaids/data-tbc.lua',
    'factions': 'AtlasLootClassic_Factions/data-tbc.lua',
    'collections': 'AtlasLootClassic_Collections/data-tbc.lua',
    'crafting': 'AtlasLootClassic_Crafting/data-tbc.lua',
    'tokens': 'AtlasLootClassic/Data/Token.lua',
    'professions': 'AtlasLootClassic/Data/Profession.lua',
}
CACHE_DIR = os.path.join(HERE, 'cache', 'atlasloot-tbc')
ATLAS_JSON = os.path.join(HERE, 'bis_atlas_tbc.json')
ITEMS_JSON = os.path.join(HERE, 'bis_tbc_items.json')
BOSSNAMES_JS = os.path.join(ROOT, 'data', 'bossnames.js')
INDEX_HTML = os.path.join(ROOT, 'index.html')
OUT = os.path.join(ROOT, 'addon', 'Amisia', 'BisDataTBC.lua')
OUT_WEIGHTS = os.path.join(ROOT, 'addon', 'Amisia', 'BisWeightsTBC.lua')
USER_AGENT = build_gear.USER_AGENT
WOW_ROOT = os.environ.get('AMISIA_WOW_ROOT', r'C:\Program Files (x86)\World of Warcraft')

CAP = 70
CLASS_ORDER = build_gear.CLASS_ORDER
CLASS_BIT = {'WARRIOR': 1, 'PALADIN': 2, 'HUNTER': 4, 'ROGUE': 8, 'PRIEST': 16, 'SHAMAN': 64, 'MAGE': 128,
             'WARLOCK': 256, 'DRUID': 1024}
ALL_CLASSES = build_gear.ALL_CLASSES

# The site's raid zones (index.html PHASES.tbc names them) -> the tables' instance ids.
ZONE_INSTANCE = {'kara': 532, 'gruul': 565, 'mag': 544, 'ssc': 548, 'tk': 550, 'hyjal': 534, 'bt': 564,
                 'za': 568, 'swp': 580}
# English instance names; in game the client names them through their area id.
INSTANCE_NAMES = {
    543: 'Hellfire Ramparts', 542: 'The Blood Furnace', 540: 'The Shattered Halls', 557: 'Mana-Tombs',
    558: 'Auchenai Crypts', 556: 'Sethekk Halls', 555: 'Shadow Labyrinth', 547: 'The Slave Pens',
    546: 'The Underbog', 545: 'The Steamvault', 560: 'Old Hillsbrad Foothills', 269: 'The Black Morass',
    552: 'The Arcatraz', 553: 'The Botanica', 554: 'The Mechanar', 585: "Magisters' Terrace",
    532: 'Karazhan', 568: "Zul'Aman", 544: "Magtheridon's Lair", 565: "Gruul's Lair", 548: 'Serpentshrine Cavern',
    550: 'Tempest Keep', 534: 'Hyjal Summit', 564: 'Black Temple', 580: 'Sunwell Plateau',
}
# The reputation tables -> English faction name and the side that can earn it.
FACTIONS = {
    'TheAldor': ('The Aldor', ''), 'TheScryers': ('The Scryers', ''), 'TheShatar': ("The Sha'tar", ''),
    'LowerCity': ('Lower City', ''), 'KeepersOfTime': ('Keepers of Time', ''), 'TheVioletEye': ('The Violet Eye', ''),
    'TheScaleOfTheSands': ('The Scale of the Sands', ''), 'CenarionExpedition': ('Cenarion Expedition', ''),
    'TheConsortium': ('The Consortium', ''), 'AshtongueDeathsworn': ('Ashtongue Deathsworn', ''),
    'ShatteredSunOffensive': ('Shattered Sun Offensive', ''), 'ShatariSkyguard': ("Sha'tari Skyguard", ''),
    'Netherwing': ('Netherwing', ''), 'Sporeggar': ('Sporeggar', ''), 'Ogrila': ("Ogri'la", ''),
    'Tranquillien': ('Tranquillien', 'H'), 'Thrallmar': ('Thrallmar', 'H'), 'TheMaghar': ("The Mag'har", 'H'),
    'HonorHold': ('Honor Hold', 'A'), 'Kurenai': ('Kurenai', 'A'),
}
# Badge of Justice vendors by table, with their phase. G'eras stands in Shattrath City (uiMapID 111).
BADGE_VENDORS = {'BadgeofJustice': 1, 'BadgeofJustice4': 4, 'BadgeofJusticeP5': 5}
SHATTRATH = 111
ZONES = {SHATTRATH: 'Shattrath City'}
VENDOR = ("G'eras", SHATTRATH, '', 'Abzeichen der Gerechtigkeit')
# World epics drop from level 70-73 mobs anywhere in Outland.
WORLD = ('W', None, 70, 73, 0)
# The crafting professions and recipe sections that make gear; enchants, gems, potions, bags and
# parts stay out.
CRAFT_TABLES = {'BlacksmithingBC', 'TailoringBC', 'LeatherworkingBC', 'EngineeringBC', 'JewelcraftingBC', 'AlchemyBC'}
GEAR_SECTION = re.compile(r'^(Weapons|Armor)( - |$)|smith$|^Stones$')
# Recipes themselves, badges and the like are no gear (the client filters the rest in game).
RECIPE_NAME = re.compile(r'^(Pattern|Plans|Design|Schematic|Formula|Recipe|Manual|Technique)\s*:')
NOT_GEAR_IDS = {29434}   # Badge of Justice

# Item.csv InventoryType -> equip location; shirts, tabards, bags, ammo and quivers stay out.
INVENTORY_TYPE = {1: 'HEAD', 2: 'NECK', 3: 'SHOULDER', 5: 'CHEST', 6: 'WAIST', 7: 'LEGS', 8: 'FEET', 9: 'WRIST',
                  10: 'HAND', 11: 'FINGER', 12: 'TRINKET', 13: 'WEAPON', 14: 'SHIELD', 15: 'RANGED', 16: 'CLOAK',
                  17: '2HWEAPON', 20: 'ROBE', 21: 'WEAPONMAINHAND', 22: 'WEAPONOFFHAND', 23: 'HOLDABLE', 25: 'THROWN',
                  26: 'RANGEDRIGHT', 28: 'RELIC'}


def log(*a):
    print(*a, file=sys.stderr)


# ---------------------------------------------------------------- stat weights (Amisia's own)
# Level 70. Ratings per percent (as the planner scores them), DEF per defence point, the rest per
# point; GEM and META per socket. unit names the stat a point of score is worth. Starting values
# after the usual rules of thumb (strength gives warriors 2 attack power, hit up to the cap counts
# high, healers value healing and mana); change them here and rebuild.
OWN_TBC = [
    ('WARRIOR', 'dps', 'Waffen/Furor', 'dps', 'AP',
     dict(STR=2.0, AGI=1.0, AP=1, CRIT=29, HIT=24, HASTE=19, EXP=25, STA=0.05, DPS=14, OHDPS=0.5, GEM=16, META=30)),
    ('WARRIOR', 'tank', 'Schutz', 'tank', 'STA',
     dict(STA=1, DEF=2.0, DODGE=18, PARRY=15, BLOCK=6, BLOCKVAL=0.5, ARMOR=0.06, AGI=0.6, STR=0.4, HIT=8, EXP=10,
          AP=0.1, DPS=3, GEM=12, META=20)),
    ('PALADIN', 'holy', 'Heilig', 'heal', 'HEAL',
     dict(HEAL=1, INT=1.1, MP5=2.0, SCRIT=14, HASTE=10, SPI=0.1, STA=0.1, GEM=18, META=20)),
    ('PALADIN', 'tank', 'Schutz', 'tank', 'STA',
     dict(STA=1, DEF=2.0, DODGE=18, PARRY=15, BLOCK=8, BLOCKVAL=0.6, ARMOR=0.06, SP=0.6, INT=0.3, AGI=0.5, HIT=6,
          EXP=6, MP5=1, DPS=1, GEM=12, META=20)),
    ('PALADIN', 'ret', 'Vergeltung', 'dps', 'AP',
     dict(STR=2.2, AGI=0.9, AP=1, CRIT=22, HIT=25, HASTE=15, EXP=22, SP=0.4, INT=0.3, MP5=1, DPS=14, GEM=18, META=30)),
    ('HUNTER', 'dps', 'Jäger', 'dps', 'AP',
     dict(AGI=1.6, AP=1, RAP=1, CRIT=22, HIT=25, HASTE=18, INT=0.4, MP5=1.5, RDPS=14, DPS=0.5, GEM=13, META=30)),
    ('ROGUE', 'dps', 'Schurke', 'dps', 'AP',
     dict(AGI=1.8, STR=1.1, AP=1, CRIT=22, HIT=25, HASTE=19, EXP=25, STA=0.05, DPS=14, OHDPS=0.5, GEM=14, META=30)),
    ('PRIEST', 'holy', 'Heilig/Disziplin', 'heal', 'HEAL',
     dict(HEAL=1, SPI=0.8, INT=0.8, MP5=2.0, SCRIT=8, HASTE=12, STA=0.1, GEM=18, META=20)),
    ('PRIEST', 'shadow', 'Schatten', 'dps', 'SP',
     dict(SP=1, SP_SHADOW=1, SHIT=14, SCRIT=8, HASTE=12, INT=0.2, SPI=0.15, MP5=0.8, STA=0.05, GEM=9, META=20)),
    ('SHAMAN', 'ele', 'Elementar', 'dps', 'SP',
     dict(SP=1, SP_NATURE=1, SHIT=14, SCRIT=13, HASTE=12, INT=0.3, MP5=0.8, GEM=9, META=20)),
    ('SHAMAN', 'enh', 'Verstärkung', 'dps', 'AP',
     dict(STR=2.0, AGI=0.9, AP=1, CRIT=22, HIT=25, HASTE=20, EXP=25, INT=0.3, MP5=1, DPS=14, OHDPS=0.5, GEM=16, META=30)),
    ('SHAMAN', 'resto', 'Wiederherstellung', 'heal', 'HEAL',
     dict(HEAL=1, MP5=2.2, INT=0.8, SCRIT=10, HASTE=14, SPI=0.2, STA=0.1, GEM=18, META=20)),
    ('MAGE', 'arcane', 'Arkan', 'dps', 'SP',
     dict(SP=1, SP_ARCANE=1, SHIT=14, SCRIT=11, HASTE=13, INT=0.7, SPI=0.3, MP5=0.5, GEM=9, META=20)),
    ('MAGE', 'fire', 'Feuer', 'dps', 'SP',
     dict(SP=1, SP_FIRE=1, SHIT=14, SCRIT=11, HASTE=13, INT=0.4, SPI=0.2, MP5=0.5, GEM=9, META=20)),
    ('MAGE', 'frost', 'Frost', 'dps', 'SP',
     dict(SP=1, SP_FROST=1, SHIT=14, SCRIT=11, HASTE=13, INT=0.4, SPI=0.2, MP5=0.5, GEM=9, META=20)),
    ('WARLOCK', 'affli', 'Gebrechen', 'dps', 'SP',
     dict(SP=1, SP_SHADOW=1, SHIT=15, SCRIT=5, HASTE=12, INT=0.2, SPI=0.2, STA=0.1, GEM=9, META=20)),
    ('WARLOCK', 'destro', 'Zerstörung', 'dps', 'SP',
     dict(SP=1, SP_SHADOW=1, SP_FIRE=0.3, SHIT=15, SCRIT=13, HASTE=12, INT=0.2, SPI=0.1, STA=0.1, GEM=9, META=20)),
    ('DRUID', 'balance', 'Gleichgewicht', 'dps', 'SP',
     dict(SP=1, SP_ARCANE=0.6, SP_NATURE=0.4, SHIT=14, SCRIT=11, HASTE=12, INT=0.4, SPI=0.2, MP5=0.6, GEM=9, META=20)),
    # feral attack power counts through AP for druids (Gear.Score)
    ('DRUID', 'feral', 'Wilder Kampf (Katze)', 'dps', 'AP',
     dict(STR=2.2, AGI=2.0, AP=1, CRIT=22, HIT=25, HASTE=10, EXP=25, GEM=16, META=30)),
    ('DRUID', 'bear', 'Bär', 'tank', 'STA',
     dict(STA=1, AGI=1.0, ARMOR=0.1, DODGE=15, DEF=1.0, STR=0.4, AP=0.1, HIT=6, EXP=8, CRIT=3, GEM=12, META=20)),
    ('DRUID', 'resto', 'Wiederherstellung', 'heal', 'HEAL',
     dict(HEAL=1, SPI=0.9, INT=0.8, MP5=1.6, HASTE=12, SCRIT=4, STA=0.1, GEM=18, META=20)),
]


def write_weights(out, specs=OWN_TBC):
    lines = [
        '-- GENERATED by tools/build_bis.py. Do not edit; rebuild instead.',
        "-- Amisia's own weights for TBC Anniversary at level 70 (OWN_TBC in tools/build_bis.py); no",
        '-- weights of anyone else are used. Shared under the licence of the addon.',
        'local _, ns = ...',
        'if ns.IsForever and ns.IsForever() then return end',
        '',
        '-- Hit, crit, haste, expertise, dodge, parry and block weights are per percent, DEF per defence point,',
        '-- GEM and META per socket, the rest per point. OHDPS is the share of off-hand weapon damage that',
        '-- counts; unit names the stat one point of score is worth.',
        'ns.GEAR_WEIGHTS = {',
        f'    brackets = {{{CAP}}},',
        '    order = {' + ', '.join(build_gear.lua_str(c) for c in CLASS_ORDER) + '},',
        '    specs = {',
    ]
    by_class = {}
    for cls, key, name, role, unit, w in specs:
        by_class.setdefault(cls, []).append((key, name, role, unit, w))
    for cls in CLASS_ORDER:
        lines.append(f'        {cls} = {{')
        for key, name, role, unit, w in by_class.get(cls, []):
            body = ', '.join(f'{k} = {v:g}' for k, v in sorted(w.items()))
            lines.append(f'            {{ key = {build_gear.lua_str(key)}, name = {build_gear.lua_str(name)}, '
                         f'role = {build_gear.lua_str(role)},')
            lines.append(f'              all = {{{body}, unit = {build_gear.lua_str(unit)}}} }},')
        lines.append('        },')
    lines += ['    },', '}']
    with open(out, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write('\n'.join(lines) + '\n')


# ---------------------------------------------------------------- loot tables: download and read
def refresh_atlas(dest=CACHE_DIR, ref='master'):
    """Downloads the TBC files of the loot tables. Returns {name: text} and the commit they are from."""
    os.makedirs(dest, exist_ok=True)

    def get(url):
        req = urllib.request.Request(url, headers={'User-Agent': USER_AGENT})
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.read().decode('utf-8')

    commit = ref
    try:
        commit = json.loads(get(f'https://api.github.com/repos/{ATLAS_REPO}/commits/{ref}'))['sha']
    except Exception as exc:  # noqa: BLE001 - the commit is only recorded, the files are what counts
        log(f'loot tables: could not read the commit of {ref}: {exc}')
    texts = {}
    for name, path in ATLAS_FILES.items():
        text = get(ATLAS_RAW.format(repo=ATLAS_REPO, ref=commit, path=path))
        with open(os.path.join(dest, name + '.lua'), 'w', encoding='utf-8', newline='\n') as fh:
            fh.write(text)
        texts[name] = text
    with open(os.path.join(dest, 'COMMIT'), 'w', encoding='utf-8') as fh:
        fh.write(commit + '\n')
    log(f'loot tables: {len(texts)} files of {ATLAS_REPO}@{commit[:10]} -> {os.path.relpath(dest, ROOT)}')
    return texts, commit


# Just enough of the loot tables' own addon for its data files to run: locales answer their own key, difficulties
# and table types become markers the reader below understands.
ATLAS_STUB = r'''
local GAME = 20500
setmetatable(_G, { __index = function(t, k)
    if type(k) == "string" and (k:find("^ATLASLOOT_") or k:find("^FACTION_")) then return k end
end })
format = string.format
UNKNOWN = "Unknown"
function UnitFactionGroup() return "Alliance" end
C_Map = { GetAreaInfo = function(id) return "Area " .. tostring(id) end }
RAID_CLASS_COLORS = setmetatable({}, { __index = function() return { colorStr = "ffffffff", r = 1, g = 1, b = 1 } end })
local AL = setmetatable({}, { __index = function(t, k) return k end })
DIFFS, ADDED = {}, {}
local nextDiff = 0
local Data = {}
function Data:AddDifficulty(name, short) nextDiff = nextDiff + 1; DIFFS[nextDiff] = tostring(short or name); return nextDiff end
function Data:AddItemTableType(a) return "ITTYPE:" .. tostring(a) end
function Data:AddExtraItemTableType(a) return "EXTRA:" .. tostring(a) end
function Data:AddContentType(name) return "CT:" .. tostring(name) end
local function pick(cond, ret, other)
    if cond then if ret == nil then return true end return ret end
    return other
end
AtlasLoot = {
    CLASSIC_VERSION_NUM = 11300, BC_VERSION_NUM = 20500, WRATH_VERSION_NUM = 30400, CATA_VERSION_NUM = 40400,
    Locales = AL, IngameLocales = AL,
    ItemDB = { Add = function(self, name)
        local d = setmetatable({}, { __index = Data })
        ADDED[#ADDED + 1] = d
        return d
    end },
    Data = { Profession = { GetColorSkillRankNoSpell = function() return "" end } },
    GameVersion_LT = function(self, v, ret, other) return pick(GAME < v, ret, other) end,
    GameVersion_GE = function(self, v, ret, other) return pick(GAME >= v, ret, other) end,
    GameVersion_EQ = function(self, v, ret, other) return pick(GAME == v, ret, other) end,
    GetGameVersion = function() return GAME end,
    ReturnForGameVersion = function(...) return nil end,
    GetGameVersionDataTable = function(self) TOKEN, TOKEN_DATA = {}, {}; return TOKEN, TOKEN_DATA end,
    GetColoredClassNames = function() return {} end,
    AddInitFunc = function() end,
}
CLASS_ICONS = {}
for _, c in ipairs({ "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID", "DEATHKNIGHT" }) do
    CLASS_ICONS[c] = "CLASS:" .. c
end
'''

# Walks the loaded tables into plain data: per table its fields and per entry (boss, section) the
# item lists by difficulty or table type.
ATLAS_WALK = r'''
local function keysSorted(t)
    local ks = {}
    for k in pairs(t) do ks[#ks + 1] = k end
    table.sort(ks, function(a, b)
        if type(a) == type(b) then return a < b end
        return type(a) == "number"
    end)
    return ks
end
local function entryList(list)
    local out = {}
    for _, i in ipairs(keysSorted(list)) do
        local e = list[i]
        if type(e) == "table" then
            local v = e[2]
            if type(v) == "number" or type(v) == "string" then
                out[#out + 1] = { v, e.IT_ALLIANCE or e.ATLASLOOT_IT_ALLIANCE, e.IT_HORDE or e.ATLASLOOT_IT_HORDE }
            end
        end
    end
    return out
end
return function()
    local out = {}
    for _, d in ipairs(ADDED) do
        for _, key in ipairs(keysSorted(d)) do
            local t = d[key]
            if type(key) == "string" and type(t) == "table" then
                local rec = { key = key, MapID = t.MapID, InstanceID = t.InstanceID, ContentType = t.ContentType,
                    ContentPhaseBC = t.ContentPhaseBC, FactionID = t.FactionID, name = t.name, TableType = t.TableType,
                    entries = {} }
                for _, i in ipairs(keysSorted(t.items or {})) do
                    local e = t.items[i]
                    if type(e) == "table" and not e.ExtraList and not e.IgnoreAsSource then
                        local entry = { name = e.name, ContentPhaseBC = e.ContentPhaseBC, lists = {} }
                        for k, v in pairs(e) do
                            if type(v) == "table" and (type(k) == "number" or (type(k) == "string" and k:find("^ITTYPE:"))) then
                                local label = type(k) == "number" and DIFFS[k] or k
                                entry.lists[label] = entryList(v)
                            end
                        end
                        rec.entries[#rec.entries + 1] = entry
                    end
                end
                out[#out + 1] = rec
            end
        end
    end
    return out
end
'''


def _runtime():
    from lupa.lua51 import LuaRuntime
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(ATLAS_STUB)
    return lua


def _run(lua, text, name, private=None):
    chunk = lua.eval('function(s, n) return assert(loadstring(s, "@" .. n)) end')(text, name)
    chunk('AtlasLootClassic_' + name, private if private is not None else lua.eval('{}'))


def _plain(v):
    """A lupa value as plain Python, with the stub's markers as strings."""
    return build_scan.lua_to_py(v)


def comment_names(text):
    """English names from the tables' line comments: { slot, id }, -- Name."""
    out = {}
    for iid, name in re.findall(r'\{\s*\d+\s*,\s*(\d+)\s*[,}][^\n]*?--\s*([^\n]+?)\s*$', text, re.M):
        name = re.sub(r'\s*\(\d+\)$', '', name).strip()
        if name and not name.startswith(('{', '[')):
            out.setdefault(int(iid), name)
    return out


def read_tables(text, name):
    lua = _runtime()
    _run(lua, text, name)
    return _plain(lua.execute(ATLAS_WALK)())


def read_tokens(text):
    """{token id: {class token or '': [item ids]}} of the TBC block: class tokens split by class,
    plain item lists (quest rewards of a head, spheres) for everyone."""
    lua = _runtime()
    private = lua.eval('{ CLASS_ICON_PATH_ITEM_DB = CLASS_ICONS }')
    _run(lua, text, 'Data_Token', private)
    bcc = lua.globals().TOKEN_DATA['BCC']
    out = {}
    for tid, entry in _plain(bcc).items():
        if not isinstance(entry, (list, dict)):
            continue
        items = entry if isinstance(entry, list) else [entry[k] for k in sorted(k for k in entry if isinstance(k, int))]
        kind = entry.get('type') if isinstance(entry, dict) else None
        classes, cur = {}, None
        for v in items:
            if isinstance(v, str) and v.startswith('CLASS:'):
                cur = v[6:]
                classes.setdefault(cur, [])
            elif isinstance(v, int) and v > 0 and cur:
                classes[cur].append(v)
            elif v == 0:
                cur = None
        if classes:
            out[int(tid)] = {c: ids for c, ids in classes.items() if ids}
        elif kind in (None, 3) and all(isinstance(v, int) and v > 0 for v in items) and items:
            # a quest reward head or a sphere: any of the listed items, for every class
            out[int(tid)] = {'': [v for v in items]}
    return out


def read_professions(text):
    """{spell id: (made item, the tables' profession number, skill)} of the TBC recipe block."""
    block = text[text.index('PROFESSION_DATA.BCC'):text.index('PROFESSION_DATA.WRATH')]
    out = {}
    for spell, item, prof, skill in re.findall(r'\[(\d+)\] = \{ *(\d+), *(\d+), *(\d+),', block):
        out[int(spell)] = (int(item), int(prof), int(skill))
    return out


def parse_atlas(texts):
    """What the build needs from the loot table files, as plain JSON-able data."""
    names = {}
    for key in ('dungeons', 'factions', 'collections'):
        names.update(comment_names(texts[key]))
    instances = []
    for t in read_tables(texts['dungeons'], 'DungeonsAndRaids'):
        ct = str(t.get('ContentType') or '')
        kind = 'dungeon' if 'Dungeons' in ct else 'raid'
        inst = t.get('InstanceID') or 0
        bosses = []
        for e in t['entries']:
            lists = e.get('lists') or {}
            normal, heroic = [], []
            for label, entries in sorted(lists.items()):
                ids = [x[0] for x in entries if isinstance(x[0], int) and x[0] > 0]
                (heroic if label == 'HEROIC' else normal).extend(ids)
            if normal or heroic:
                bosses.append({'name': e.get('name') or '?', 'normal': normal, 'heroic': heroic,
                               'phase': e.get('ContentPhaseBC') or 0})
        instances.append({'key': t['key'], 'name': INSTANCE_NAMES.get(inst) or t.get('name') or split_key(t['key']),
                          'inst': inst, 'area': t.get('MapID') or 0, 'kind': kind if inst else 'world',
                          'phase': t.get('ContentPhaseBC') or 0, 'bosses': bosses})
    factions = []
    for t in read_tables(texts['factions'], 'Factions'):
        if t['key'] not in FACTIONS:
            continue
        ranks = {}
        for e in t['entries']:
            for label, entries in sorted((e.get('lists') or {}).items()):
                rank, side = None, ''
                if label in ('horde', 'alliance'):
                    side = 'H' if label == 'horde' else 'A'
                for x in entries:
                    if isinstance(x[0], str):
                        m = re.match(r'f\d+rep(\d)', x[0])
                        if m:
                            rank = int(m.group(1))
                    elif isinstance(x[0], int) and x[0] > 0 and rank:
                        ranks.setdefault(f'{rank}{side}', []).append(x[0])
        fname, side = FACTIONS[t['key']]
        factions.append({'key': t['key'], 'name': fname, 'id': t.get('FactionID') or 0, 'side': side,
                         'ranks': {k: sorted(set(v)) for k, v in sorted(ranks.items())}})
    vendors, world = [], []
    for t in read_tables(texts['collections'], 'Collections'):
        ids = sorted({x[0] for e in t['entries'] for entries in (e.get('lists') or {}).values()
                      for x in entries if isinstance(x[0], int) and x[0] > 0})
        if t['key'] in BADGE_VENDORS:
            vendors.append({'key': t['key'], 'phase': BADGE_VENDORS[t['key']], 'items': ids})
        elif t['key'] == 'WorldEpicsBC':
            world = ids
    spells = read_professions(texts['professions'])
    crafts, missing_spells = [], 0
    spell_names = comment_names(texts['crafting'])
    for t in read_tables(texts['crafting'], 'Crafting'):
        if t['key'] not in CRAFT_TABLES:
            continue
        for e in t['entries']:
            if not GEAR_SECTION.search(str(e.get('name') or '')):
                continue
            for entries in (e.get('lists') or {}).values():
                for x in entries:
                    spell = x[0]
                    if not isinstance(spell, int):
                        continue
                    made = spells.get(spell)
                    if not made:
                        missing_spells += 1
                        continue
                    item, prof, skill = made
                    if prof in build_gear.ATLAS_PROF:
                        crafts.append({'item': item, 'prof': build_gear.ATLAS_PROF[prof], 'skill': skill})
                        if spell in spell_names:
                            names.setdefault(item, spell_names[spell])
    crafts = sorted({(c['item'], c['prof'], c['skill']) for c in crafts})
    tokens = read_tokens(texts['tokens'])
    for tid, name in re.findall(r'^\s*\[(\d+)\]\s*=\s*\{[^\n]*--\s*([^\n]+?)\s*$', texts['tokens'], re.M):
        if int(tid) in tokens:
            names.setdefault(int(tid), name)
    if missing_spells:
        log(f'loot tables: {missing_spells} recipe spells without a made item')
    return {
        'instances': instances, 'factions': factions, 'vendors': vendors, 'world': world,
        'crafts': [{'item': i, 'prof': p, 'skill': s} for i, p, s in crafts],
        'tokens': {str(k): v for k, v in sorted(tokens.items())},
        'names': {str(k): v for k, v in sorted(names.items())},
    }


def split_key(key):
    return re.sub(r'(?<=[a-z])(?=[A-Z])', ' ', key)


def load_cached_texts(path=CACHE_DIR):
    """The downloaded files and their commit, or (None, None) when the download is incomplete."""
    texts = {}
    for name in ATLAS_FILES:
        p = os.path.join(path, name + '.lua')
        if not os.path.exists(p):
            return None, None
        with open(p, encoding='utf-8') as fh:
            texts[name] = fh.read()
    commit = None
    if os.path.exists(os.path.join(path, 'COMMIT')):
        with open(os.path.join(path, 'COMMIT'), encoding='utf-8') as fh:
            commit = fh.read().strip() or None
    return texts, commit


# ---------------------------------------------------------------- phases and German boss names
def raid_phases(index=INDEX_HTML):
    """{instance id: phase} from PHASES.tbc of the site."""
    with open(index, encoding='utf-8') as fh:
        src = fh.read()
    block = re.search(r'const PHASES = \{tbc: \[(.*?)\]\};', src, re.S).group(1)
    out = {}
    for num, zones in re.findall(r"name: 'Phase (\d+)', zones: \[([^\]]*)\]", block):
        for z in re.findall(r"'(\w+)'", zones):
            if z in ZONE_INSTANCE:
                out[ZONE_INSTANCE[z]] = int(num)
    return out


ROMANCE_CHARS = set('áàâãéèêíìîóòôõúùûçñ')
ROMANCE_WORDS = {'el', 'la', 'le', 'les', 'de', 'del', 'do', 'da', 'dos', 'o', 'os', 'il', 'du', 'des', 'y', 'su', 'e', 'et'}
GERMAN_WORDS = {'der', 'die', 'das', 'aus', 'von', 'und', 'dem', 'den'}
GERMAN_BITS = ('sch', 'ch', 'tz', 'ei', 'eu', 'au', 'ie', 'w', 'k', 'z')


def german_score(cand, english):
    """How German a localized name looks, counted on the words it does not share with English."""
    shared = {w.lower() for w in re.findall(r"[\w']+", english)}
    sc = 0.0
    for w in re.findall(r"[\w']+", cand):
        lw = w.lower()
        if lw in shared:
            continue
        if re.match(r"^[dl]'", lw):
            sc -= 3
        if lw in ROMANCE_WORDS:
            sc -= 2
            continue
        if lw in GERMAN_WORDS:
            sc += 2
            continue
        sc += 3 * sum(c in 'äöüß' for c in lw)
        sc -= 3 * sum(c in ROMANCE_CHARS for c in lw)
        sc += 0.5 * sum(lw.count(b) for b in GERMAN_BITS)
        if re.search(r'[aoe]s?$', lw) and not re.search(r'(er|en|el)$', lw):
            sc -= 0.5
    return sc


def latin_bossnames(path=BOSSNAMES_JS, game='tbc'):
    """{English boss: [names in Latin script]} out of the site's boss name table, which holds every
    language without saying which. A boss listed only in other scripts has its English name in
    German too."""
    with open(path, encoding='utf-8') as fh:
        src = fh.read()
    m = re.search(r'__BOSSNAMES\["' + game + r'"\]=(\{.*?\});', src)
    table = json.loads(m.group(1)) if m else {}
    by_en = {}
    for loc, en in table.items():
        by_en.setdefault(en, [])
        if all(ord(c) < 0x250 for c in loc):
            by_en[en].append(loc)
    return by_en


def german_from_bossnames(path=BOSSNAMES_JS, game='tbc'):
    """{English boss: German} out of the site's boss name table. A name is taken only when it
    clearly looks German (above zero and a point ahead of the next); otherwise the English name
    stays, which is also right for the many bosses whose German name is the English one."""
    out = {}
    for en, cands in latin_bossnames(path, game).items():
        if not cands:
            continue
        ranked = sorted(cands, key=lambda c: (-german_score(c, en), c))
        top = german_score(ranked[0], en)
        nxt = german_score(ranked[1], en) if len(ranked) > 1 else -99
        if top > 0 and top - nxt >= 1:
            out[en] = ranked[0]
    return out


def german_from_wow(wow_root):
    """{English: German} from the German locale files of the installed loot tables (PC only)."""
    import build_bossnames
    out = {}
    for flavor in ('_anniversary_', '_classic_era_', '_classic_beta_'):
        for mod in ('AtlasLootClassic_DungeonsAndRaids', 'AtlasLootClassic'):
            p = os.path.join(wow_root, flavor, 'Interface', 'AddOns', mod, 'Locales', 'constants.de.lua')
            if os.path.exists(p):
                with open(p, encoding='utf-8') as fh:
                    for en, de in build_bossnames.AL_LINE.findall(fh.read()):
                        if de:
                            out.setdefault(en, de)
    return out


# ---------------------------------------------------------------- optional client tables
def refresh_items(item_csv, sparse_csv, ids, path=ITEMS_JSON):
    """Keeps, for the ids the tables name, what the addon would otherwise ask the client: equip
    location, class, subclass, level, quality, bind, item level, class mask, weapon speed and the
    profession needed to wear it. Ids that are no armour or weapon are listed as not gear.

    Both exports come from wago.tools for the Anniversary build (product wow_anniversary), e.g.
    https://wago.tools/db2/Item/csv?build=<build> and .../ItemSparse/csv?build=<build>."""
    def num(row, *names):
        for n in names:
            v = row.get(n)
            if v not in (None, ''):
                try:
                    return int(float(v))
                except ValueError:
                    pass
        return 0
    base = {}
    with open(item_csv, encoding='utf-8') as fh:
        for row in csv.DictReader(fh):
            iid = num(row, 'ID')
            if iid in ids:
                base[iid] = (num(row, 'ClassID'), num(row, 'SubclassID'), num(row, 'InventoryType'))
    items, not_gear = {}, []
    with open(sparse_csv, encoding='utf-8') as fh:
        for row in csv.DictReader(fh):
            iid = num(row, 'ID')
            if iid not in ids:
                continue
            cls, sub, inv = base.get(iid, (0, 0, num(row, 'InventoryType')))
            loc = INVENTORY_TYPE.get(inv)
            if not loc or cls not in (build_scan.CLASS_WEAPON, build_scan.CLASS_ARMOR):
                not_gear.append(iid)
                continue
            mask = num(row, 'AllowableClass')
            mask = mask & ALL_CLASSES if mask > 0 and mask & ALL_CLASSES != ALL_CLASSES else 0
            delay = num(row, 'ItemDelay')
            speed = round(delay / 1000, 2) if delay > 0 and cls == build_scan.CLASS_WEAPON else 0
            items[str(iid)] = [loc, cls, sub, num(row, 'RequiredLevel'), num(row, 'OverallQualityID'), num(row, 'Bonding'),
                               num(row, 'ItemLevel'), mask, speed, num(row, 'RequiredSkill')]
    with open(path, 'w', encoding='utf-8') as fh:
        json.dump({'source': [os.path.basename(item_csv), os.path.basename(sparse_csv)], 'items': items,
                   'not_gear': sorted(not_gear)}, fh, indent=0, sort_keys=True)
    log(f'items: {len(items)} gear, {len(not_gear)} not gear -> {os.path.relpath(path, ROOT)}')


# ---------------------------------------------------------------- joining
def build(atlas, phases, german, items_info=None, scan_items=None):
    """Sources and item rows from the parsed tables. Returns (sources, rows, report)."""
    src = build_gear.Sources()
    found = {}            # item id -> source numbers
    masks = {}            # item id -> class bits, or 0 once a source is open to every class
    names = {int(k): v for k, v in (atlas.get('names') or {}).items()}
    tokens = {int(k): v for k, v in (atlas.get('tokens') or {}).items()}
    report = {'kinds': {}, 'phases': {}, 'tokens without pieces': [], 'bosses without German name': [],
              'not gear': 0}
    items_info = items_info or {}
    info = items_info.get('items', {})
    not_gear = set(items_info.get('not_gear', []))
    scan_items = scan_items or {}

    def skip(iid):
        if iid in NOT_GEAR_IDS or iid in not_gear:
            return True
        return bool(RECIPE_NAME.search(names.get(iid, '')))

    def note(iid, num, mask=0):
        lst = found.setdefault(iid, [])
        if num not in lst:
            lst.append(num)
        masks[iid] = 0 if (mask == 0 or masks.get(iid) == 0) else (masks.get(iid, 0) | mask)

    used_tokens = set()
    for inst in atlas['instances']:
        raid = inst['kind'] != 'dungeon'
        phase = phases.get(inst['inst']) or inst.get('phase') or 1
        for boss in inst['bosses']:
            en = boss['name']
            bname = german.get(en, en)
            if raid and en not in german and inst['kind'] == 'raid':
                report['bosses without German name'].append(f"{inst['name']}: {en}")
            for heroic, ids in ((0, boss['normal']), (1, boss['heroic'])):
                if not ids:
                    continue
                bphase = max(phase, boss.get('phase') or 0)
                if raid:
                    rec = ('X', inst['name'], bname, inst['inst'], inst['area'], bphase, 0)
                else:
                    rec = ('D', inst['name'], bname, None, inst['inst'], inst['area'], heroic,
                           bphase if bphase > 1 else None)
                for iid in ids:
                    if iid in tokens:
                        used_tokens.add(iid)
                        trec = rec[:6] + (iid,) if raid else rec
                        num = src.add(*trec)
                        for cls, pieces in tokens[iid].items():
                            for piece in pieces:
                                if not skip(piece):
                                    note(piece, num, CLASS_BIT.get(cls, 0) if cls else 0)
                        continue
                    if skip(iid):
                        report['not gear'] += 1
                        continue
                    note(iid, src.add(*rec))
    for t, by_class in tokens.items():
        if t in used_tokens and not any(by_class.values()):
            report['tokens without pieces'].append(t)
    for fac in atlas['factions']:
        for key, ids in fac['ranks'].items():
            rank, side = int(key[0]), key[1:] or fac['side']
            num = src.add('F', fac['name'], rank, fac['id'], side)
            for iid in ids:
                if not skip(iid):
                    note(iid, num)
    for v in atlas['vendors']:
        num = src.add('V', *VENDOR, v['phase'])
        for iid in v['items']:
            if not skip(iid):
                note(iid, num)
    if atlas.get('world'):
        num = src.add(*WORLD)
        for iid in atlas['world']:
            if not skip(iid):
                note(iid, num)
    for c in atlas['crafts']:
        if not skip(c['item']):
            note(c['item'], src.add('C', c['prof'], c['skill']))

    rows = {}
    for iid, nums in found.items():
        row = info.get(str(iid))
        if items_info and row is None:
            # the client tables do not know it as gear
            report['not gear'] += 1
            continue
        if row is None and iid in scan_items:
            it = scan_items[iid]
            if it['equipLoc'] and it['equipLoc'] not in build_gear.EQUIP:
                report['not gear'] += 1
                continue
            row = [it['equipLoc'].replace('INVTYPE_', ''), it['classID'], it['subclassID'], it['min'], it['q'],
                   it['bind'], it['ilvl'], 0, 0, 0]
        if row is None:
            row = ['', 0, 0, 0, 0, 0, 0, 0, 0, 0]
        row = list(row)
        if masks.get(iid):
            row[7] = masks[iid] if not row[7] else (row[7] & masks[iid]) or masks[iid]
        rows[iid] = (row, nums)
    for iid, (_, nums) in rows.items():
        for n in nums:
            rec = src.rows[n - 1]
            report['kinds'][rec[0]] = report['kinds'].get(rec[0], 0) + 1
        ph = min(phase_of(src.rows[n - 1]) for n in nums)
        report['phases'][ph] = report['phases'].get(ph, 0) + 1
    return src, rows, report


def phase_of(rec):
    if rec[0] in ('X', 'V'):
        return rec[5] or 1
    if rec[0] == 'D' and len(rec) > 7:
        return rec[7] or 1
    return 1


# ---------------------------------------------------------------- Lua output
def write_lua(out, src, rows, built, stats=None):
    used = sorted({n for _, nums in rows.values() for n in nums})
    renum = {n: i + 1 for i, n in enumerate(used)}
    lua_str, lua_val = build_gear.lua_str, build_gear.lua_val
    lines = [
        '-- GENERATED by tools/build_bis.py. Do not edit; rebuild instead.',
        '-- Sources: AtlasLootClassic (GPL-2.0), the Amisia loot tables, the Amisia item scan.',
        'local _, ns = ...',
        'if ns.IsForever and ns.IsForever() then return end',
        '',
        '-- S: source records. X raid {raid, boss, instance id, area id, phase, token item id or 0}, D dungeon',
        '-- {dungeon, boss, drop chance, instance id, area id, heroic 1/0, phase when above 1}, F reputation',
        '-- {faction, standing 5 friendly .. 8 exalted, faction id, side A/H/""}, V vendor {name, zone, side,',
        '-- title, phase}, C crafted {profession, skill}, W world drop {nil, min level, max level, zone}. Names',
        '-- are English (raid bosses German where known); the client names raids and dungeons by area id.',
        '-- Z: zone names by uiMapID. ST: [itemID] = the client stats a scan saw ("STRENGTH=5;...").',
        '-- I: [itemID] = {equipLoc, classID, subclassID, level, quality, bind, item level, class mask, weapon',
        '-- speed, profession needed to wear it, source...}. An empty equipLoc means unknown: the addon fills',
        '-- the row from the client (Gear.FillRow). Class mask 0 means every class; set pieces of a tier',
        '-- token carry their class.',
        'ns.GEAR = {',
        f'    game = "tbc", cap = {CAP}, built = {lua_str(built)},',
        '    S = {',
    ]
    for n in used:
        lines.append('        {' + ', '.join(lua_val(v) for v in src.rows[n - 1]) + '},')
    lines.append('    },')
    lines.append('    Z = {')
    for k in sorted(ZONES):
        lines.append(f'        [{k}] = {lua_str(ZONES[k])},')
    lines.append('    },')
    lines.append('    I = {')
    for iid in sorted(rows):
        row, nums = rows[iid]
        vals = [lua_str(row[0])] + [f'{v:g}' if isinstance(v, float) else str(v) for v in row[1:]]
        vals += [str(renum[n]) for n in sorted(nums, key=lambda n: renum[n])]
        lines.append(f'        [{iid}] = {{' + ', '.join(vals) + '},')
    lines.append('    },')
    if stats:
        lines.append('    ST = {')
        for iid in sorted(stats):
            if iid in rows and stats[iid]:
                lines.append(f'        [{iid}] = {lua_str(stats[iid])},')
        lines.append('    },')
    lines.append('}')
    text = '\n'.join(lines) + '\n'
    if re.search(r'[\x00-\x08\x0b-\x1f\x7f]', text):
        raise SystemExit('control characters in the output')
    with open(out, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(text)
    return len(used)


def scanned_stats(scan_items, ids):
    """{item id: compact stat text} from Amisia item scans made on Anniversary."""
    keys = build_gear.scored_stat_keys()
    out = {}
    for iid in ids:
        it = scan_items.get(iid)
        st = build_gear.compact_stats(it.get('stats'), keys) if it else ''
        if st:
            out[iid] = st
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--refresh-atlas', action='store_true', help='download the TBC loot table files again (see tools/README.md)')
    ap.add_argument('--atlas-ref', default='master', help='branch, tag or commit to download (default master)')
    ap.add_argument('--item-csv', help='Item.csv of the Anniversary client (wago.tools)')
    ap.add_argument('--itemsparse', help='ItemSparse.csv of the Anniversary client (wago.tools)')
    ap.add_argument('--wow-root', help='WoW install: German boss names from the installed loot tables')
    ap.add_argument('--sv', nargs='*', help='Amisia SavedVariables with an item scan made on Anniversary')
    ap.add_argument('--out', default=OUT)
    ap.add_argument('--out-weights', default=OUT_WEIGHTS)
    args = ap.parse_args(argv)

    if args.refresh_atlas or not os.path.exists(ATLAS_JSON):
        # without --refresh-atlas a missing JSON is read again from a complete earlier download
        texts, commit = load_cached_texts() if not args.refresh_atlas else (None, None)
        if texts is None:
            texts, commit = refresh_atlas(ref=args.atlas_ref)
        parsed = parse_atlas(texts)
        parsed = {'source': f'https://github.com/{ATLAS_REPO}', 'license': 'GPL-2.0', 'commit': commit or args.atlas_ref,
                  'fetched': time.strftime('%Y-%m-%d'), **parsed}
        with open(ATLAS_JSON, 'w', encoding='utf-8') as fh:
            json.dump(parsed, fh, ensure_ascii=False, indent=1, sort_keys=True)
        log(f'loot tables: read -> {os.path.relpath(ATLAS_JSON, ROOT)}')
    with open(ATLAS_JSON, encoding='utf-8') as fh:
        atlas = json.load(fh)

    if bool(args.item_csv) != bool(args.itemsparse):
        raise SystemExit('--item-csv and --itemsparse go together')
    if args.item_csv:
        ids = set()
        for inst in atlas['instances']:
            for b in inst['bosses']:
                ids.update(b['normal'] + b['heroic'])
        for f in atlas['factions']:
            for v in f['ranks'].values():
                ids.update(v)
        for v in atlas['vendors']:
            ids.update(v['items'])
        ids.update(atlas['world'])
        ids.update(c['item'] for c in atlas['crafts'])
        for by_class in atlas['tokens'].values():
            for pieces in by_class.values():
                ids.update(pieces)
        refresh_items(args.item_csv, args.itemsparse, ids)
    items_info = None
    if os.path.exists(ITEMS_JSON):
        with open(ITEMS_JSON, encoding='utf-8') as fh:
            items_info = json.load(fh)

    german = german_from_bossnames()
    if args.wow_root:
        german.update(german_from_wow(args.wow_root))
    phases = raid_phases()
    scan_items = {}
    if args.sv:
        scan_items, _, _ = build_scan.collect([build_scan.load_sv(p) for p in args.sv])
    src, rows, report = build(atlas, phases, german, items_info, scan_items)
    stats = scanned_stats(scan_items, list(rows)) if scan_items else {}
    n_src = write_lua(args.out, src, rows, atlas.get('fetched') or time.strftime('%Y-%m-%d'), stats)
    write_weights(args.out_weights)
    log(f'items per source kind: {dict(sorted(report["kinds"].items()))}')
    log(f'items by first phase: {dict(sorted(report["phases"].items()))}')
    log(f'left out as no gear: {report["not gear"]}')
    if report['tokens without pieces']:
        log(f'tokens without set pieces: {report["tokens without pieces"]}')
    if report['bosses without German name']:
        listed = latin_bossnames()
        unsure, same, absent = [], [], []
        for b in report['bosses without German name']:
            en = b.split(': ', 1)[1]
            (unsure if listed.get(en) else same if en in listed else absent).append(b)
        log(f'raid bosses kept in English: {len(same)} have no other Latin name (German = English), '
            f'{len(unsure)} unsure, {len(absent)} not in data/bossnames.js (--wow-root on the PC names them):')
        for b in unsure:
            log('  unsure: ' + b)
        for b in absent:
            log('  not listed: ' + b)
    log(f'{os.path.relpath(args.out, ROOT)}: {len(rows)} items, {n_src} sources, {os.path.getsize(args.out) // 1024} KB; '
        f'{os.path.relpath(args.out_weights, ROOT)}: {os.path.getsize(args.out_weights) // 1024} KB')


if __name__ == '__main__':
    main()
