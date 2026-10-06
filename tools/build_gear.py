"""Builds addon/Amisia/GearData.lua: every WoW Forever item a levelling character can wear, with
where it comes from. The addon's gear window (/amisia gear) reads it, asks the client for the
item's stats and picks the best item per slot and level range.

    python tools/build_gear.py [--att DIR] [--refresh-att] [--wago DIR] [--sv <Amisia.lua>...]
                               [--refresh-wowsrc] [--no-wowsrc] [--itemsparse CSV] [--out FILE]

Runs on the N100: everything it needs by default comes from the AllTheThings download and the
files in the repo. PC-only inputs are optional and only add to it.

What an item is (slot, armour or weapon type, required level, quality, bind type):
  - the Amisia item scan (`/amisia scan`): the scan dumps in the repo root, the SavedVariables
    Syncthing brings to ~/addons/_SavedVariables/Amisia.lua, those of an installed Forever client,
    or the files given with --sv. A scanned item's fields win, because the scan reads the live client;
  - else AllTheThings' export of the Forever client's item table (tools/att_data.py).
  The scanned stats go into ST; an item no scan given here has seen keeps the stats of the current
  GearData.lua (earlier scans), so a rebuild without SavedVariables loses none.

Where an item comes from (tools/att_data.py reads all of it, MIT licence, see LICENSES/):
  - AllTheThings' Forever data: quest rewards with minimum level, faction, zone and dungeon; boss
    drops per dungeon; rares, vendors and zone drops with their NPC; world drops; PvP rank gear;
    crafted items per profession. The authors' Classic folders (zzOLD) fill what the Forever
    folders do not have yet. ATT gives no quest level (the minimum level stands in), no NPC levels
    and no recipe skill (0 = not known).
  - The Amisia item collector (`scan.sources`): drops, merchants, quests and the auction house as a
    player met them. These names are German.
  - Optional, PC only (the Forever AddOns folder; skipped when missing): OneForAll (dungeon bosses,
    dungeon quests, Merchant's Favor recipes) and AtlasLootClassic (Forever dungeon tables, Classic
    recipes with their skill).
  - wowsrc.com dungeon loot pages (drop chances), kept parsed in tools/gear_wowsrc.json;
    --refresh-wowsrc downloads them again, --no-wowsrc leaves them out.

Instance ids (what GetInstanceInfo reports) come from the client tables UiMapAssignment and
AreaTable (<Table>[.<build>].csv in --wago, default ~/addons/_wago, downloaded by hand from
wago.tools, then the copies ATT ships), from tools/forever_dungeons.json (with
forever_dungeons_client.json) and from the collector's drop notes; a dungeon without one is placed
by its name.

AMISIA_WOW_ROOT overrides the WoW install path.
"""
import argparse
import glob
import html
import json
import os
import re
import sys
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import att_data  # noqa: E402  (the AllTheThings reader)
import build_scan  # noqa: E402  (scan dump parsing is shared)

WOW_ROOT = os.environ.get('AMISIA_WOW_ROOT', r'C:\Program Files (x86)\World of Warcraft')
FOREVER_ADDONS = os.path.join(WOW_ROOT, '_classic_beta_', 'Interface', 'AddOns')
WOWSRC_JSON = os.path.join(HERE, 'gear_wowsrc.json')
FOREVER_JS = os.path.join(ROOT, 'data', 'forever.js')
FOREVER_ZONES = os.path.join(HERE, 'forever_zones.json')
FACTS = os.path.join(HERE, 'forever_dungeons.json')
ITEMSPARSE_JSON = os.path.join(HERE, 'gear_itemsparse.json')
WAGO = os.path.expanduser('~/addons/_wago')
# ItemSparse class bits of the nine Classic classes; a mask holding all of them limits nothing.
ALL_CLASSES = 1 | 2 | 4 | 8 | 16 | 64 | 128 | 256 | 1024
OUT = os.path.join(ROOT, 'addon', 'Amisia', 'GearData.lua')
GEAR_LUA = os.path.join(ROOT, 'addon', 'Amisia', 'Gear.lua')
USER_AGENT = att_data.USER_AGENT

# Equipment slots worth planning. Shirts, tabards, bags and ammo are left out.
EQUIP = {
    'INVTYPE_HEAD', 'INVTYPE_NECK', 'INVTYPE_SHOULDER', 'INVTYPE_CLOAK', 'INVTYPE_CHEST', 'INVTYPE_ROBE',
    'INVTYPE_WRIST', 'INVTYPE_HAND', 'INVTYPE_WAIST', 'INVTYPE_LEGS', 'INVTYPE_FEET', 'INVTYPE_FINGER',
    'INVTYPE_TRINKET', 'INVTYPE_WEAPON', 'INVTYPE_2HWEAPON', 'INVTYPE_WEAPONMAINHAND',
    'INVTYPE_WEAPONOFFHAND', 'INVTYPE_SHIELD', 'INVTYPE_HOLDABLE', 'INVTYPE_RANGED', 'INVTYPE_RANGEDRIGHT',
    'INVTYPE_THROWN', 'INVTYPE_RELIC',
}
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
# The name PvP rank gear gets as a source: ATT lists it per faction, not per quartermaster.
PVP_SOURCE = 'Rank Quartermaster'


def log(*a):
    print(*a, file=sys.stderr)


# ---------------------------------------------------------------- stat weights
# The level brackets RXP's Forever weights are cut into.
BRACKETS = [(1, 9), (10, 19), (20, 29), (30, 39), (40, 49), (50, 60)]
CLASS_ORDER = ['WARRIOR', 'PALADIN', 'HUNTER', 'ROGUE', 'PRIEST', 'SHAMAN', 'MAGE', 'WARLOCK', 'DRUID']
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
def itemsparse_path(arg):
    """--itemsparse: a CSV file, or a folder holding ItemSparse.csv or ItemSparse.<build>.csv (the
    newest build)."""
    if not os.path.isdir(arg):
        return arg
    path = att_data.wago_csv(arg, 'ItemSparse')
    if not path:
        raise SystemExit(f'no ItemSparse[.<build>].csv in {arg}')
    return path


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


def is_pvp_vendor(title):
    """PvP rank quartermasters: their gear needs an honour rank, not just gold."""
    title = str(title or '')
    return 'Quartermaster' in title and ('Armor' in title or 'Accessories' in title) or 'Legacy' in title


def zone_name(const):
    """A map constant as a name: STORMWIND_CITY -> Stormwind City (the fallback when the client
    has no name for the uiMapID)."""
    return ' '.join(w.capitalize() for w in const.split('_')).replace("'S ", "'s ")


def load_facts(path=FACTS):
    """The dungeon facts with the client's instance ids filled in (build_dungeons.merge)."""
    import build_dungeons
    with open(path, encoding='utf-8') as fh:
        return build_dungeons.merge(json.load(fh), build_dungeons.load_client())


class Places:
    """Dungeons and raids by ATT instance, name or instance id: (name, instance id, area id).

    The name is the one tools/forever_dungeons.json gives a dungeon (else ATT's); the instance id
    comes from the client's UiMapAssignment and AreaTable tables (via the ATT reader), the facts file
    (with tools/forever_dungeons_client.json), or what the collector's drop notes reported (learn())."""

    def __init__(self, att, facts=()):
        self.facts = list(facts or ())
        self.att = {}       # ATT instance id -> [name, instance id, area id]
        self.by_key = {}    # dungeon_key(name) -> the same list
        for iid in sorted(att.get('instances', {})):
            i = att['instances'][iid]
            fact = self._fact(i['name'], i.get('area')) or self._fact(i.get('stem'), None)
            name = fact['name'] if fact else i['name']
            place = [name, i.get('mapID') or (fact or {}).get('inst'), i.get('area') or (fact or {}).get('area')]
            self.att[iid] = place
            for n in [name, i['name']] + list((fact or {}).get('aliases') or []):
                self.by_key.setdefault(dungeon_key(n), place)
        for f in self.facts:
            place = self.by_key.get(dungeon_key(f['name'])) or [f['name'], f.get('inst'), f.get('area')]
            for n in [f['name']] + list(f.get('aliases') or []):
                self.by_key.setdefault(dungeon_key(n), place)

    def _fact(self, name, area):
        if area:
            for f in self.facts:
                if f.get('area') == area:
                    return f
        key = dungeon_key(name or '')
        for f in self.facts:
            if key and key in {dungeon_key(n) for n in [f['name']] + list(f.get('aliases') or [])}:
                return f
        return None

    def of_att(self, iid):
        return tuple(self.att[iid]) if iid in self.att else (None, None, None)

    def of_name(self, name):
        """By name: exactly, else by containment ("Scarlet Monastery - Armory")."""
        key = dungeon_key(name or '')
        place = self.by_key.get(key)
        if place is None and key:
            near = sorted((abs(len(k) - len(key)), k) for k in self.by_key if k and (k in key or key in k))
            place = self.by_key[near[0][1]] if near else None
        return tuple(place) if place else (None, None, None)

    def of_instance(self, inst):
        for place in self.att.values():
            if inst and place[1] == inst:
                return tuple(place)
        return (None, None, None)

    def learn(self, inst, name):
        """An instance id a drop note reported for a dungeon name: kept where the id was unknown."""
        if not inst or not name:
            return
        place = self.by_key.get(dungeon_key(name))
        if place is not None and not place[1]:
            place[1] = inst


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


PREV_STUB = r'''
return function(src)
    local ns = {}
    local f = assert(loadstring(src, "@GearData.lua"))
    setfenv(f, {})
    f("Amisia", ns)
    local d, out = ns.GEAR, {}
    if not d then return out end
    for id, row in pairs(d.I) do
        local only = true
        for i = 11, #row do
            local rec = d.S[row[i]]
            if not rec or rec[1] ~= "Q" then only = false end
        end
        out[id] = { "INVTYPE_" .. row[1], row[2], row[3], row[4], row[5], row[6], row[7], row[8], only and #row > 10 }
    end
    return out
end
'''


def previous_items(path=OUT):
    """{item id: item dict} of the I table of a generated GearData.lua: what earlier scans said about
    the items (slot, class, subclass, quality, bind, item level, class mask). Its level column is the
    planner's level, not the item's required level; for an item whose only sources were quests it
    holds a quest level, so there it is given as 0 (unknown) and the quest data sets it again."""
    if not os.path.exists(path):
        return {}
    from lupa.lua51 import LuaRuntime
    lua = LuaRuntime(register_eval=False, register_builtins=False, unpack_returned_tuples=True)
    with open(path, encoding='utf-8') as fh:
        rows = lua.execute(PREV_STUB)(fh.read())
    out = {}
    for iid, r in rows.items():
        loc, cls, sub, level, q, bind, ilvl, mask, quest_only = (r[i] for i in range(1, 10))
        out[int(iid)] = {'name': '', 'q': int(q or 0), 'ilvl': int(ilvl or 0), 'min': 0 if quest_only else int(level or 0),
                         'classID': int(cls or 0), 'subclassID': int(sub or 0), 'equipLoc': loc, 'icon': '',
                         'bind': int(bind or 0), 'classes': int(mask or 0), 'stats': ''}
    return out


def item_master(scan_items, att_items, prev_items=None, names=None):
    """The items the build knows: ATT's export of the client's item table; over it what the last
    GearData.lua said (earlier scans; the required level stays ATT's where ATT has one); over both a
    scanned item's fields (the scan reads the live client). names fills missing names."""
    out = {iid: dict(it) for iid, it in (att_items or {}).items()}
    for iid, it in (prev_items or {}).items():
        base = out.get(iid)
        out[iid] = dict(it)
        if base:
            out[iid].update(name=base.get('name') or '', min=base.get('min') or it['min'], skill=base.get('skill') or 0,
                            classes=it.get('classes') or base.get('classes') or 0)
    for iid, name in (names or {}).items():
        if iid in out and not out[iid].get('name'):
            out[iid]['name'] = name
    for iid, it in (scan_items or {}).items():
        if not it.get('equipLoc') and iid in out:
            # an itemNames-only record (name and quality): what else ATT knows stays
            out[iid].update({k: v for k, v in it.items() if v})
            continue
        base = out.get(iid, {})
        out[iid] = dict(base, **it)
        for k in ('classes', 'skill'):
            if base.get(k):
                out[iid][k] = base[k]
    return out


def is_junk(name):
    """Test, unused and old items by name; ATT's export marks retired ones "OLD<name>"."""
    name = name or ''
    return bool(build_scan.JUNK_NAME.search(name)) or bool(re.match(r'OLD[A-Z]', name))


def build(scan_items, collected, att, ofa=({}, {}), atlas_dungeons=(), atlas_crafts=None, wowsrc=None,
          itemsparse=None, forever_raids=None, facts=None, prev_items=None):
    """Joins the sources to the items. att is the neutral form of tools/att_data.py (att_data.empty_db()
    for none); ofa, atlas_dungeons and atlas_crafts are the optional PC sources. Returns the source
    records, the kept items {id: (item, source numbers, level, class mask, speed, skill line)}, the
    zone names, link counts, what was left out and why, wowsrc names without an item, and the ids to
    ask the client for."""
    items = item_master(scan_items, att.get('items'), prev_items, att.get('item_names'))
    places = Places(att, facts)
    quests, npcs = att.get('quests', {}), att.get('npcs', {})
    map_names = {}
    for const, ui in sorted((att.get('maps') or {}).items()):
        map_names.setdefault(ui, zone_name(const))
    src = Sources()
    found = {}   # item id -> list of source numbers
    stats = {}

    def note(item, num, kind):
        lst = found.setdefault(item, [])
        if num not in lst:
            lst.append(num)
            stats[kind] = stats.get(kind, 0) + 1

    zone_rows = {}

    def zone_ref(ui):
        """A uiMapID as a zone key; the name is the fallback for a client without one."""
        if not ui or ui <= 0:
            return None
        zone_rows.setdefault(ui, map_names.get(ui, ''))
        return ui

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

    for iid, it in (att.get('items') or {}).items():
        name_id(it.get('name'), iid)
    for iid, name in (att.get('item_names') or {}).items():
        name_id(name, iid)

    def npc_zone(n, fallback=None):
        """Where an NPC stands: its own zone, else the map of its first point."""
        z = n.get('zone') if n else None
        if not z and n and n.get('points'):
            z = n['points'][0][0]
        return z or fallback

    def quest_rec(qid, q):
        dname = places.of_att(q['inst'])[0] if q.get('inst') is not None else None
        if dname in RAIDS:
            return None
        zone = q.get('zone')
        if q.get('points') and not q.get('inside'):
            zone = q['points'][0][0]
        return src.add('Q', q.get('name') or f'Quest {qid}', 0, q.get('minLevel') or 0, q.get('faction') or None,
                       zone_ref(zone), qid, q.get('classes') or 0, dname)

    # --- AllTheThings: quest rewards
    for qid in sorted(quests):
        q = quests[qid]
        if not q.get('rewards'):
            continue
        num = quest_rec(qid, q)
        if num is None:
            continue
        for item in q['rewards']:
            note(item, num, 'quest')

    # --- boss, rare and named mob drops
    for item, nid, kind, iid, zone, _old, boss in att.get('drops', []):
        n = npcs.get(nid) if nid is not None else None
        name = (n or {}).get('name') or boss
        if iid is not None:
            dname, inst, area = places.of_att(iid)
            if dname in RAIDS or not dname:
                continue
            note(item, src.add('D', dname, name or 'Trash', None, inst, area), 'dungeon')
        elif not name:
            continue
        elif kind == 'rare':
            note(item, src.add('R', name, 0, zone_ref(npc_zone(n, zone)), nid), 'rare')
        else:
            note(item, src.add('W', name, 0, 0, zone_ref(npc_zone(n, zone)), nid), 'world')

    # --- zone drops: trash inside a dungeon, the named mobs outside, or a drop of the whole zone
    for item, crs, iid, zone, _old in att.get('zone_drops', []):
        if iid is not None:
            dname = places.of_att(iid)[0]
            if dname and dname not in RAIDS:
                note(item, src.add('W', f'Trash ({dname})', 0, 0), 'world')
            continue
        named = [(c, npcs.get(c)) for c in crs if (npcs.get(c) or {}).get('name')]
        if not named or len(crs) > WORLD_DROP_NPCS:
            note(item, src.add('W', None, 0, 0, zone_ref(zone)), 'world')
            continue
        for c, n in named:
            note(item, src.add('W', n['name'], 0, 0, zone_ref(npc_zone(n, zone)), c), 'world')

    # --- vendors (PvP rank quartermasters as P), world drops, PvP rank gear
    for item, nid, _old in att.get('sold', []):
        n = npcs.get(nid) or {}
        kind = 'P' if is_pvp_vendor(n.get('title')) else 'V'
        num = src.add(kind, n.get('name') or f'NPC {nid}', zone_ref(npc_zone(n)), n.get('faction') or None,
                      n.get('title'), None, nid)
        note(item, num, 'pvp' if kind == 'P' else 'vendor')
    for item in att.get('world', []):
        note(item, src.add('W', None, 0, 0), 'world')
    for item, fac in att.get('pvp', []):
        note(item, src.add('P', PVP_SOURCE, None, fac or None), 'pvp')

    # --- OneForAll dungeons and dungeon quests (PC, optional)
    for dname, d in ((ofa or ({}, {}))[0] or {}).items():
        for boss in d.get('bosses') or []:
            for tup in boss.get('loot') or []:
                if isinstance(tup, list) and tup and isinstance(tup[0], int):
                    pname, inst, area = places.of_name(dname)
                    note(tup[0], src.add('D', pname or dname, boss.get('name') or '?', None, inst, area), 'dungeon')
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
    crafted = {}   # item -> professions a PC source named with a skill
    for prof, recipes in ((ofa or ({}, {}))[1] or {}).items():
        key = OFA_PROF.get(prof)
        for r in (recipes or {}).values():
            item = r.get('craftedItemID')
            if key and item:
                note(item, src.add('C', key, r.get('requiredSkill') or 0), 'craft')
                crafted.setdefault(item, set()).add(key)

    # --- AtlasLoot: Forever dungeons and Classic recipes (PC, optional)
    for dname, lr, boss, item, comment, *ids in atlas_dungeons or ():
        inst, area = (ids + [None, None])[:2]
        pname, pinst, parea = places.of_name(dname)
        if not inst and not area:
            inst, area = pinst, parea
        note(item, src.add('D', pname or dname, boss, None, inst, area), 'dungeon')
        name_id(re.sub(r'\s*\(.*$', '', comment.replace('{FOREVER}', '')), item)
    for item, profs in (atlas_crafts or {}).items():
        for key, skill in profs:
            note(item, src.add('C', key, skill), 'craft')
            crafted.setdefault(item, set()).add(key)

    # --- ATT's crafted items: the profession without a skill, unless a source above has one
    for item, key in att.get('crafted', []):
        if key not in crafted.get(item, ()):
            note(item, src.add('C', key, 0), 'craft')

    # --- wowsrc dungeon pages: drop chances, and loot of dungeons the other sources lack
    unmatched = []
    missing = set()   # gear the sources name that no item table knows: /amisia scan gear asks for it
    for d in (wowsrc or {}).get('dungeons', []):
        for boss in d['bosses']:
            bname = 'Trash' if boss['name'].lower() == 'trash' else boss['name']
            for it in boss['items']:
                ids = by_name.get(norm_name(it['n']))
                iid = pick_id(ids, items, it.get('nw'))
                if not iid:
                    unmatched.append(f"{d['name']}: {it['n']}" + ('' if ids else ' (no item id)'))
                    if ids:
                        missing.add(pick_id(ids, {i: True for i in ids}, it.get('nw')))
                    continue
                if drop_chance(it.get('d')) < 1:
                    # below one percent nobody farms it: a random drop like the world drops
                    note(iid, src.add('W', f"{d['name']}: {bname} {it.get('d')}", 0, 0), 'world')
                else:
                    pname, inst, area = places.of_name(d['name'])
                    note(iid, src.add('D', pname or d['name'], bname, it.get('d'), inst, area), 'dungeon')

    # --- the collector: what players met in the Forever client
    notes = {iid: [n for n in (build_scan.parse_note(t) for t in texts) if n] for iid, texts in collected.items()}
    for ns in notes.values():
        for n in ns:
            if n['kind'] == 'drop' and n.get('itype') == 'party':
                places.learn(n['instance'], n['place'])
    for iid, ns in notes.items():
        for n in ns:
            if n['kind'] == 'ah':
                note(iid, src.add('A'), 'ah')
            elif n['kind'] == 'quest':
                q = quests.get(n['id']) if n['id'] else None
                num = quest_rec(n['id'], q) if q else None
                if q and num is None:
                    continue   # a raid quest
                if num is None:
                    # a quest the data does not know: the player's level stands in for the quest level
                    num = src.add('Q', n['name'] or '?', n['level'] or 0, 0, None, None, n['id'])
                note(iid, num, 'quest')
            elif n['kind'] == 'vendor':
                npc = npcs.get(n['id']) if n['id'] else None
                name = (npc and npc.get('name')) or n['name'] or '?'
                zone_key = zone_ref(npc_zone(npc)) if npc else zone_text_ref(n['place'])
                note(iid, src.add('V', name, zone_key, (npc or {}).get('faction') or None,
                                  (npc or {}).get('title'), None, n['id'] or None), 'vendor')
            else:
                if n['itype'] == 'raid':
                    continue
                npc = npcs.get(n['id']) if n['id'] else None
                name = (npc and npc.get('name')) or n['name'] or (f"NPC {n['id']}" if n['id'] else None)
                if not name:
                    continue
                if n['itype'] == 'party':
                    dname, inst, area = places.of_instance(n['instance'])
                    if not dname:
                        dname, inst, area = places.of_name(n['place'])
                    if dname in RAIDS:
                        continue
                    note(iid, src.add('D', dname or n['place'] or '?', name, None, n['instance'] or inst or None,
                                      area), 'dungeon')
                elif npc and 'rare' in npc.get('kinds', ()):
                    note(iid, src.add('R', name, 0, zone_ref(npc_zone(npc)), n['id']), 'rare')
                else:
                    zone_key = zone_ref(npc_zone(npc)) if npc else zone_text_ref(n['place'])
                    note(iid, src.add('W', name, 0, 0, zone_key, n['id'] or None), 'world')

    # --- Forever raids the site has recorded: raid, boss, instance, area, phase 1, no token
    for rname, boss, iid, inst, area in forever_raids or []:
        note(iid, src.add('X', rname, boss, inst or 0, area or 0, 1, 0), 'raid')

    # --- keep what the item table knows and a character can wear
    keep = {}
    dropped = {'unknown item': 0, 'not gear': 0, 'quality': 0, 'junk': 0, 'raid level': 0}
    itemsparse = itemsparse or {}
    classes, delays, skills = itemsparse.get('classes', {}), itemsparse.get('delay', {}), itemsparse.get('skill', {})
    for iid, nums in found.items():
        nums = merge_dungeon_sources(nums, src.rows)
        it = items.get(iid)
        kinds = {src.rows[n - 1][0] for n in nums}
        if not it or not it.get('equipLoc') and not it.get('classID'):
            dropped['unknown item'] += 1
            # worth asking the client when a dungeon, crafting or quest source names it
            if kinds & {'D', 'C', 'Q'}:
                missing.add(iid)
            continue
        if it['equipLoc'] not in EQUIP or it['classID'] not in (build_scan.CLASS_WEAPON, build_scan.CLASS_ARMOR):
            dropped['not gear'] += 1
            continue
        if iid in TEST_ITEMS or is_junk(it.get('name')):
            dropped['junk'] += 1
            continue
        if iid < FOREVER_IDS and it['ilvl'] > CLASSIC_MAX_ILVL and 'X' not in kinds:
            dropped['raid level'] += 1
            continue
        if kinds <= {'P'} and it['q'] < 3:
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
        if not mask and it.get('classes') and it['classes'] & ALL_CLASSES != ALL_CLASSES:
            mask = it['classes'] & ALL_CLASSES
        speed = round(int(delays.get(str(iid), 0)) / 1000, 2)
        line, rank = skills.get(str(iid), (it.get('skill') or 0, 0))
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


def previous_stats(path=OUT):
    """{item id: stat text} of the ST table of a generated GearData.lua: what earlier scans saw."""
    if not os.path.exists(path):
        return {}
    with open(path, encoding='utf-8') as fh:
        text = fh.read()
    m = re.search(r'\n    ST = \{\n(.*?)\n    \},', text, re.S)
    if not m:
        return {}
    # stat texts are KEY=value pairs: no quotes or escapes in them
    return {int(i): v for i, v in re.findall(r'^\s*\[(\d+)\] = "([^"\\]*)",$', m.group(1), re.M)}


def write_lua(out, src, keep, zone_rows, info, missing=(), old_stats=None):
    used = sorted({n for k in keep.values() for n in k[1]})
    renum = {n: i + 1 for i, n in enumerate(used)}
    zones_used = {}
    lines = [
        '-- GENERATED by tools/build_gear.py. Do not edit; rebuild instead.',
        '-- Sources: ' + ', '.join(info.get('sources') or [att_data.ATT_SOURCE, 'the Amisia item scan']) + '.',
        'local _, ns = ...',
        '',
        '-- S: source records. Q quest {name, quest level (0 unknown), minimum level, faction, zone, quest id, class mask,',
        '-- dungeon},',
        '-- D dungeon {dungeon, boss, drop chance, instance id, area id}, X raid {raid, boss, instance id, area id,',
        '-- phase, token}, R rare mob {name, level, zone, npc id}, W world drop {mob or nil,',
        '-- min level, max level, zone, npc id}, V vendor {name, zone, faction, title, phase (nil), npc id}, P PvP rank vendor (as V),',
        '-- C crafted {profession, skill}, A seen at the auction house. Zones are uiMapIDs (localised in game), negative keys',
        '-- are zones the collector wrote down by name (Z holds the names).',
        '-- ST: [itemID] = the client stats the scan saw, scored keys only ("STRENGTH=5;RESISTANCE0_NAME=40"). M: ids the',
        '-- sources name but no item table knows yet; /amisia scan gear asks the client for them.',
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
        # D and X records hold instance and area ids, no zone (an instance id can equal a uiMapID)
        for v in rec[1:] if rec[0] not in ('D', 'X') else ():
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
        st = compact_stats(keep[iid][0].get('stats'), keys) or (old_stats or {}).get(iid)
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
    """The scan dumps in the repo root, the SavedVariables Syncthing brings to the N100 and those of
    an installed Forever client: whichever exist."""
    paths = [os.path.join(ROOT, f) for f in ('Amisia_teil1.lua', 'Amisia_teil2.lua')]
    paths.append(build_scan.DEFAULT_SV)
    paths += sorted(glob.glob(os.path.join(WOW_ROOT, '_classic_beta_', 'WTF', 'Account', '*', 'SavedVariables', 'Amisia.lua')))
    return [p for p in paths if os.path.exists(p)]


def optional(what, fn, path, empty):
    """A PC-only source: read when its file is there, else empty."""
    if not os.path.exists(path):
        log(f'{what}: not found ({path}), left out')
        return empty
    return fn(path)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--att', default=att_data.ATT_CACHE, help=f'AllTheThings download (default {att_data.ATT_CACHE})')
    ap.add_argument('--refresh-att', action='store_true', help='download the AllTheThings Forever files first')
    ap.add_argument('--wago', default=WAGO, help='folder with client tables from wago.tools (UiMapAssignment, AreaTable; default ~/addons/_wago)')
    ap.add_argument('--sv', nargs='*', help='Amisia SavedVariables files with item scans (default: repo dumps, '
                                            '~/addons/_SavedVariables/Amisia.lua, installed Forever client)')
    ap.add_argument('--out', default=OUT)
    ap.add_argument('--refresh-wowsrc', action='store_true', help='download the wowsrc.com dungeon pages again')
    ap.add_argument('--no-wowsrc', action='store_true', help='leave the wowsrc.com dungeon pages out')
    ap.add_argument('--show-unmatched', action='store_true')
    ap.add_argument('--itemsparse', help='ItemSparse CSV export of the Forever client (wago.tools, with hotfixes), or a '
                                         'folder holding ItemSparse[.<build>].csv; refreshes tools/gear_itemsparse.json')
    args = ap.parse_args(argv)

    if args.refresh_att:
        att_data.refresh(args.att)
    if not os.path.isdir(os.path.join(args.att, 'dungeons & raids')):
        raise SystemExit(f'no AllTheThings download in {args.att}: run with --refresh-att')
    att = att_data.load(args.att, wago=args.wago)
    log(f'AllTheThings {(att["commit"] or "?")[:10]}: {len(att["items"])} items, {len(att["quests"])} quests, '
        f'{len(att["npcs"])} NPCs, {len(att["instances"])} instances'
        + (f'; files that failed: {sorted(att["errors"])}' if att['errors'] else ''))

    svs = args.sv if args.sv is not None else default_svs()
    scan_items, collected = {}, {}
    if svs:
        scan_items, _, collected = build_scan.collect([build_scan.load_sv(p) for p in svs])
    log(f'scan: {len(scan_items)} items from {len(svs)} file(s), {len(collected)} with collector notes')

    wowsrc = {}
    if not args.no_wowsrc:
        if args.refresh_wowsrc or not os.path.exists(WOWSRC_JSON):
            refresh_wowsrc()
        with open(WOWSRC_JSON, encoding='utf-8') as fh:
            wowsrc = json.load(fh)

    if args.itemsparse:
        refresh_itemsparse(itemsparse_path(args.itemsparse), item_master(scan_items, att['items'], previous_items(OUT)))
    itemsparse = {}
    if os.path.exists(ITEMSPARSE_JSON):
        with open(ITEMSPARSE_JSON, encoding='utf-8') as fh:
            itemsparse = json.load(fh)
    else:
        log('no tools/gear_itemsparse.json: weapon speeds come from tooltips in game')

    ofa = optional('OneForAll', load_oneforall, os.path.join(FOREVER_ADDONS, 'OneForAll'), ({}, {}))
    atlas_dungeons = optional('AtlasLoot dungeons', load_atlas_forever_dungeons,
                              os.path.join(FOREVER_ADDONS, 'AtlasLootClassic_DungeonsAndRaids', 'data.lua'), [])
    atlas_crafts = optional('AtlasLoot recipes', load_atlas_crafts,
                            os.path.join(FOREVER_ADDONS, 'AtlasLootClassic', 'Data', 'Profession.lua'), {})
    forever_raids = load_forever_raids()
    log(f'oneforall: {len(ofa[0])} dungeons; atlasloot: {len(atlas_dungeons)} forever dungeon rows, '
        f'{len(atlas_crafts)} crafted items; wowsrc: {len(wowsrc.get("dungeons", []))} dungeons; '
        f'forever raids: {len(forever_raids)} drops')

    # what earlier scans said, kept in the generated file: the item table and the stats
    last = args.out if os.path.exists(args.out) else OUT
    prev_items, old_stats = previous_items(last), previous_stats(last)
    log(f'last build ({os.path.relpath(last, ROOT)}): {len(prev_items)} items, {len(old_stats)} with stats')
    src, keep, zone_rows, stats, dropped, unmatched, missing = build(
        scan_items, collected, att, ofa, atlas_dungeons, atlas_crafts, wowsrc, itemsparse, forever_raids, load_facts(),
        prev_items)
    sources = [att_data.ATT_SOURCE + (f' at {att["commit"][:10]}' if att.get('commit') else ''), 'the Amisia item scan']
    if ofa[0] or ofa[1]:
        sources.append('OneForAll')
    if atlas_dungeons or atlas_crafts:
        sources.append('AtlasLootClassic (GPL-2.0)')
    if wowsrc:
        sources.append('wowsrc.com')
    n_src = write_lua(args.out, src, keep, zone_rows, {'built': time.strftime('%Y-%m-%d'), 'sources': sources},
                      missing, old_stats)
    scanned = sum(1 for k in keep.values() if k[0].get('stats'))
    kept_old = sum(1 for i, k in keep.items() if not k[0].get('stats') and i in old_stats)
    log(f'stats: {scanned} of {len(keep)} items from the scan, {kept_old} kept from the last build; '
        f'{len(missing)} ids for /amisia scan gear')
    # GearWeights.lua is Amisia's own since 2.5 (tools/build_bis.py); this build never writes it
    log(f'links found: {stats}')
    log(f'left out: {dropped}')
    no_id = sum(1 for u in unmatched if u.endswith('(no item id)'))
    log(f'wowsrc items left out: {len(unmatched) - no_id} not in the item tables, {no_id} without an item id')
    if args.show_unmatched:
        for u in unmatched:
            log('  ' + u)
    log(f'{os.path.relpath(args.out, ROOT)}: {len(keep)} items, {n_src} sources, {os.path.getsize(args.out) // 1024} KB')


if __name__ == '__main__':
    main()
