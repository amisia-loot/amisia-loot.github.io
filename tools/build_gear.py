"""Builds Amisia/Data/GearData.lua: every WoW Forever item a levelling character can wear, with
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
    and no recipe skill.
  - The Amisia item collector (`scan.sources`): drops, merchants, quests and the auction house as a
    player met them. These names are German.
  - The Amisia source collector (`collect`, shared in the guild): quests with giver, rewards and
    level, vendors, drops of non-boss NPCs. Below ATT: a quest or NPC ATT knows keeps ATT's record,
    the observation adds what ATT lacks (so a quest reward ATT lists as missing gets its source).
  - The client tables (--wago): the item every recipe makes (SpellEffect) and the skill it needs,
    the higher of SkillLineAbility's MinSkillLineRank and the RequiredSkillRank of the recipe item
    that teaches it (ItemXItemEffect, ItemSparse).
  - wowsrc.com dungeon loot pages (drop chances), kept parsed in tools/gear_wowsrc.json;
    --refresh-wowsrc downloads them again, --no-wowsrc leaves them out.

Instance ids (what GetInstanceInfo reports) come from the client tables UiMapAssignment and
AreaTable (<Table>[.<build>].csv in --wago, default the newest copy of each table of the export,
wago.tools' CSV exports and the copies ATT ships, tools/client_tables.py), from tools/forever_dungeons.json (with
forever_dungeons_client.json) and from the collector's drop notes; a dungeon without one is placed
by its name.

AMISIA_WOW_ROOT overrides the WoW install path.
"""
import argparse
import csv
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
import lua_data  # noqa: E402  (the lazy form of the data file)
import build_scan  # noqa: E402  (scan dump parsing is shared)
import build_scan_archive  # noqa: E402  (the scan archive the builds read under the SavedVariables)

WOW_ROOT = os.environ.get('AMISIA_WOW_ROOT', r'C:\Program Files (x86)\World of Warcraft')
# Forever moved from the beta product folder to its own (2026-10-31); the old one still counts
# while it exists.
FOREVER_FLAVORS = ('_forever_', '_classic_beta_')
WOWSRC_JSON = os.path.join(HERE, 'gear_wowsrc.json')
FOREVER_JS = os.path.join(ROOT, 'Amisia-Website', 'data', 'forever.js')
FOREVER_ZONES = os.path.join(HERE, 'forever_zones.json')
FACTS = os.path.join(HERE, 'forever_dungeons.json')
ITEMSPARSE_JSON = os.path.join(HERE, 'gear_itemsparse.json')
# the quest types the addon learned from the quest log (AmisiaDB.questtags), kept for good
QUEST_TAGS = os.path.join(HERE, 'quest_tag_archive.json')
QUEST_TAG_CODES = ('G', 'D', 'R', 'P')
WAGO = os.path.expanduser('~/addons/_wago')
# ItemSparse class bits of the nine Classic classes; a mask holding all of them limits nothing.
ALL_CLASSES = 1 | 2 | 4 | 8 | 16 | 64 | 128 | 256 | 1024
OUT = os.path.join(ROOT, 'Amisia', 'Data', 'GearData.lua')
GEAR_LUA = os.path.join(ROOT, 'Amisia', 'Gear', 'Gear.lua')
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
# The crafting professions by skill line, as the addon names them.
CRAFT_SKILLS = {171: 'alchemy', 164: 'blacksmithing', 333: 'enchanting', 202: 'engineering', 165: 'leatherworking',
                197: 'tailoring', 185: 'cooking', 129: 'firstaid', 755: 'jewelcrafting'}
# The name PvP rank gear gets as a source: ATT lists it per faction, not per quartermaster.
PVP_SOURCE = 'Rank Quartermaster'


def log(*a):
    print(*a, file=sys.stderr)


# ---------------------------------------------------------------- recipes (client tables)
def client_crafts(wago_dir, att_crafted=()):
    """{profession key: [(item, skill)]} of the client's recipes: the item a recipe makes (SpellEffect)
    and the skill it needs, the higher of SkillLineAbility's MinSkillLineRank and the RequiredSkillRank
    of the recipe item that teaches it. Recipes in the Season of Discovery spell range count only for
    items AllTheThings lists as crafted for Forever (as in build_professions.py). Empty without the
    tables."""
    import build_professions
    client = build_professions.read_client(wago_dir)
    if not client['sla'] or not client['create']:
        return {}
    need = {}
    for r in att_data.wago_rows('ItemSparse', wago_dir):
        try:
            rank = int(r.get('RequiredSkillRank') or 0)
        except ValueError:
            continue
        if rank:
            need[int(r['ID'])] = rank
    taught = {}
    for item, spell in client['teach'].items():
        taught[spell] = max(taught.get(spell, 0), need.get(item, 0))
    lo, hi = build_professions.SOD_RANGE
    forever = {item for item, _ in att_crafted}
    out = {}
    for (line, spell), v in client['sla'].items():
        key, made = CRAFT_SKILLS.get(line), client['create'].get(spell)
        if not key or not made or (lo <= spell < hi and made[0] not in forever):
            continue
        skill = max(v['min'], taught.get(spell, 0), 1)
        rows = out.setdefault(key, {})
        rows[made[0]] = min(skill, rows.get(made[0], skill))
    return {k: sorted(rows.items()) for k, rows in sorted(out.items())}


# ---------------------------------------------------------------- the site's Forever raids
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
def client_item_ids(wago_dir):
    """The item ids of the client's own ItemSparse table; None without the table."""
    path = att_data.wago_csv(wago_dir, 'ItemSparse') if wago_dir and os.path.isdir(wago_dir) else None
    if not path:
        return None
    with open(path, encoding='utf-8', newline='') as fh:
        return {int(r['ID']) for r in csv.DictReader(fh) if (r.get('ID') or '').isdigit()}


def client_reputation(wago_dir):
    """{item id: (faction id, standing)} of the client's ItemSparse table: the reputation an item
    asks for (MinFactionID, MinReputation 0 hated .. 7 exalted); {} without the table."""
    path = att_data.wago_csv(wago_dir, 'ItemSparse') if wago_dir and os.path.isdir(wago_dir) else None
    if not path:
        return {}
    out = {}
    with open(path, encoding='utf-8', newline='') as fh:
        for r in csv.DictReader(fh):
            try:
                iid, fac, rep = int(r['ID']), int(r.get('MinFactionID') or 0), int(r.get('MinReputation') or 0)
            except ValueError:
                continue
            if fac > 0 and 0 <= rep <= 7:
                out[iid] = (fac, rep)
    return out


def client_known(ids, wago_dir):
    """The ids of ids the client's own ItemSparse table has (an id it lacks does not exist in Forever:
    /amisia scan gear would ask for it in vain). Without the table, all of them."""
    known = client_item_ids(wago_dir)
    if known is None:
        return list(ids)
    kept = [i for i in ids if i in known]
    if len(kept) < len(ids):
        log(f'scan gear: {len(ids) - len(kept)} ids left out, the client has no such item')
    return kept


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

    The export is the user's own: tools/export_db2.ps1 on the PC (product wow_classic_beta, with
    hotfixes), or wago.tools' ItemSparse CSV export (tools/fetch_tables.py, D-101)."""
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


# ---------------------------------------------------------------- learned quest types (AmisiaDB.questtags)
def quest_tags_from_sv(db):
    """{quest id: code} of a SavedVariables' AmisiaDB.questtags (G group or elite, D dungeon, R raid,
    P PvP), checked as the addon checks it."""
    q = db.get('questtags') if isinstance(db, dict) else None
    lst = q.get('list') if isinstance(q, dict) else None
    if not isinstance(lst, dict):
        return {}
    return {k: v for k, v in lst.items()
            if isinstance(k, int) and not isinstance(k, bool) and 0 < k <= 9999999 and v in QUEST_TAG_CODES}


def load_quest_tags(path=QUEST_TAGS):
    if not os.path.exists(path):
        return {'updated': None, 'tags': {}}
    with open(path, encoding='utf-8') as fh:
        arch = json.load(fh)
    arch.setdefault('tags', {})
    return arch


def update_quest_tags(dbs, path=QUEST_TAGS, today=None):
    """Joins the SavedVariables' learned quest types into the archive (a later file wins, nothing is
    dropped) and writes it when it changed; returns {quest id: code}."""
    arch = load_quest_tags(path)
    tags = dict(arch['tags'])
    for db in dbs:
        for qid, code in quest_tags_from_sv(db).items():
            tags[str(qid)] = code
    if tags != arch['tags'] or not os.path.exists(path):
        arch = {'updated': today or time.strftime('%Y-%m-%d'),
                'tags': dict(sorted(tags.items(), key=lambda kv: int(kv[0])))}
        with open(path, 'w', encoding='utf-8', newline='\n') as fh:
            fh.write(json.dumps(arch, indent=1) + '\n')
        log(f'{os.path.relpath(path, ROOT)}: {len(tags)} learned quest types')
    return {int(k): v for k, v in tags.items() if v in QUEST_TAG_CODES}


# ---------------------------------------------------------------- the quest scan by id (D-104)
def scan_quest_info(scans):
    """{quest id: (level, type code)} of the quest scan (build_scan_archive.id_scans): the quest level
    where the client gave one, else the difficulty level (0 unknown), and G/D/R/P or ''."""
    out = {}
    for part in ((scans or {}).get('quests') or {}).values():
        for qid, f in part.items():
            lvl = f.get('qlevel') or f.get('level') or 0
            old = out.get(qid, (0, ''))
            out[qid] = (old[0] or (lvl if 0 < lvl <= 99 else 0), old[1] or f.get('tag') or '')
    return out


def apply_quest_scan(src, info):
    """The quest records of src (Q: name, quest level, minimum level, faction, zone, quest id, ...) with
    the scanned level where theirs is 0. In place; returns how many took one."""
    n = 0
    for i, rec in enumerate(src.rows):
        if rec[0] != 'Q' or len(rec) < 7 or rec[2]:
            continue
        lvl = (info.get(rec[6]) or (0, ''))[0]
        if lvl:
            src.rows[i] = rec[:2] + (lvl,) + rec[3:]
            n += 1
    return n


def scan_quest_tags(qtags, info):
    """The learned quest types with the scanned ones where the quest log taught none."""
    out = dict(qtags)
    for qid, (_, tag) in info.items():
        if tag in QUEST_TAG_CODES and qid not in out:
            out[qid] = tag
    return out


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
        # an instance whose wings are dungeons of their own (the facts' part and att_wing: the halves of
        # Blackrock Spire, the Scarlet Monastery's four wings; D-106): dungeon_key(part) -> {ATT wing
        # header: fact}, the facts in their order; its ATT instance's place carries the part's name and
        # split() gives a boss the wing it stands in
        self.wings, self.first_wing = {}, {}
        for f in self.facts:
            if f.get('part') and f.get('att_wing'):
                pk = dungeon_key(f['part'])
                self.wings.setdefault(pk, {})[f['att_wing']] = f
                self.first_wing.setdefault(pk, f)
        self.npc_wing = {}    # ATT NPC id -> its wing header
        self.boss_wing = {}   # (part key, norm_name(boss)) -> wing header (ATT's NPCs and encounters)
        part_iids = {}
        for iid in sorted(att.get('instances', {})):
            i = att['instances'][iid]
            pk = next((k for k in (dungeon_key(i['name']), dungeon_key(i.get('stem') or '')) if k in self.wings), None)
            if pk:
                part = next(iter(self.wings[pk].values()))['part']
                place = [part, i.get('mapID') or self.first_wing[pk].get('inst'), i.get('area')]
                part_iids[iid] = pk
                self.att[iid] = place
                for n in [part, i['name']]:
                    self.by_key.setdefault(dungeon_key(n), place)
                continue
            fact = self._fact(i['name'], i.get('area')) or self._fact(i.get('stem'), None)
            name = fact['name'] if fact else i['name']
            place = [name, i.get('mapID') or (fact or {}).get('inst'), i.get('area') or (fact or {}).get('area')]
            self.att[iid] = place
            for n in [name, i['name']] + list((fact or {}).get('aliases') or []):
                self.by_key.setdefault(dungeon_key(n), place)
        for nid, n in sorted((att.get('npcs') or {}).items()):
            pk = part_iids.get(n.get('inst'))
            if pk and n.get('wing') in self.wings[pk]:
                self.npc_wing[nid] = n['wing']
                if n.get('name'):
                    self.boss_wing.setdefault((pk, norm_name(n['name'])), n['wing'])
        for eid, e in sorted((att.get('encounters') or {}).items()):
            pk = part_iids.get(e.get('inst'))
            if pk and e.get('wing') in self.wings[pk] and e.get('name'):
                self.boss_wing.setdefault((pk, norm_name(e['name'])), e['wing'])
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

    def split(self, place, boss=None, npc=None, wing=None):
        """place (name, instance id, area id) as of_att()/of_name()/of_instance() give it; for the part of
        an instance whose wings are dungeons of their own (D-106) the place of the wing: the given ATT wing
        header, else the wing of the NPC (its ATT header), else of the boss's name (ATT's NPCs and
        encounters of the instance), else the part's first wing (the facts' order: Lower Blackrock Spire,
        the Graveyard; trash and unknown names). Any other place stays as it is."""
        name = place[0] if place else None
        pk = dungeon_key(name or '')
        wings = self.wings.get(pk)
        if not wings:
            return place
        w = wing if wing in wings else None
        if w is None and npc is not None:
            w = self.npc_wing.get(npc)
        if w is None and boss:
            w = self.boss_wing.get((pk, norm_name(boss)))
        f = wings.get(w) or self.first_wing[pk]
        return (f['name'], place[1] or f.get('inst'), place[2] or f.get('area'))

    def quest_wings(self, place, q):
        """The wings a quest of a part's instance belongs to (D-106): its own ATT wing header, else the
        wings of the NPCs its objectives name (every wing it needs, in the facts' order), else the part's
        first wing. [place] for a place of no such instance."""
        pk = dungeon_key((place or (None,))[0] or '')
        wings = self.wings.get(pk)
        if not wings:
            return [place]
        if q.get('wing') in wings:
            return [self.split(place, wing=q['wing'])]
        need = {self.npc_wing.get(t) for t in q.get('targets') or []} & set(wings)
        if not need:
            return [self.split(place)]
        return [self.split(place, wing=f['att_wing']) for f in self.facts if f.get('att_wing') in need
                and f is wings[f['att_wing']]]

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
        rows = lua.execute(PREV_STUB)(lua_data.eager(fh.read()))
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


def build(scan_items, collected, att, crafts=None, wowsrc=None,
          itemsparse=None, forever_raids=None, facts=None, prev_items=None, observed=None):
    """Joins the sources to the items. att is the neutral form of tools/att_data.py (att_data.empty_db()
    for none); crafts client_crafts' form (None for none); observed the source
    collector's records (build_scan.collect_observed). Returns the source
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
        # a quest of an instance of several wings names the first wing it belongs to (D-106)
        dname = places.quest_wings((dname, None, None), q)[0][0] if dname else None
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
            dname, inst, area = places.split(places.of_att(iid), name, nid)
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

    # --- the client's recipes with their skill (client_crafts)
    crafted = {}   # item -> professions a source named with a skill
    for key, rows in sorted((crafts or {}).items()):
        for item, skill in rows:
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
                    pname, inst, area = places.split(places.of_name(d['name']), bname)
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
                    dname, inst, area = places.split((dname, inst, area), name, n['id'] or None)
                    if dname in RAIDS:
                        continue
                    note(iid, src.add('D', dname or n['place'] or '?', name, None, n['instance'] or inst or None,
                                      area), 'dungeon')
                elif npc and 'rare' in npc.get('kinds', ()):
                    note(iid, src.add('R', name, 0, zone_ref(npc_zone(npc)), n['id']), 'rare')
                else:
                    zone_key = zone_ref(npc_zone(npc)) if npc else zone_text_ref(n['place'])
                    note(iid, src.add('W', name, 0, 0, zone_key, n['id'] or None), 'world')

    # --- the source collector (Collector.lua): quests, vendors and world drops the guild saw. What
    # ATT knows about a quest or NPC wins (the same record comes out, so it is one source); the
    # observation fills in what ATT lacks: a quest or vendor ATT does not have, a reward ATT does
    # not list, a mob nobody named.
    obs = observed or {}
    for qid, q in sorted((obs.get('q') or {}).items()):
        rewards = list(q['rewards']) + list(q['choices'])
        if not rewards:
            continue
        aq = quests.get(qid)
        num = quest_rec(qid, aq) if aq else None
        if aq and num is None:
            continue   # a raid quest
        if num is None:
            fac = q['fac'] if q['fac'] in ('A', 'H') else None
            zone = zone_ref(q['gpos'][0]) if q['gpos'] else None
            # the lowest player level that was offered the quest stands in for its minimum level
            num = src.add('Q', q['title'] or f'Quest {qid}', q['qlevel'] or 0, q['minlvl'] or 0, fac, zone, qid)
        for item in rewards:
            note(item, num, 'quest')
    for nid, v in sorted((obs.get('s') or {}).items()):
        n = npcs.get(nid)
        if n:
            title = n.get('title')
            kind = 'P' if is_pvp_vendor(title) else 'V'
            num = src.add(kind, n.get('name') or v['name'] or f'NPC {nid}', zone_ref(npc_zone(n)), n.get('faction') or None,
                          title, None, nid)
        else:
            kind = 'V'
            num = src.add('V', v['name'] or f'NPC {nid}', zone_ref(v['pos'][0]) if v['pos'] else None, None, None, None, nid)
        for item in sorted(v['items']):
            note(item, num, 'pvp' if kind == 'P' else 'vendor')
    for nid, w in sorted((obs.get('w') or {}).items()):
        n = npcs.get(nid)
        name = (n and n.get('name')) or w['name'] or f'NPC {nid}'
        if w['inst']:
            dname, inst, area = places.of_instance(w['inst'])
            if not dname or dname in RAIDS:
                continue
            if n and 'boss' in n.get('kinds', ()):
                dname, inst, area = places.split((dname, inst, area), name, nid)
                num = src.add('D', dname, name, None, inst, area)
                kind = 'dungeon'
            else:
                num = src.add('W', f'Trash ({dname})', 0, 0)
                kind = 'world'
        else:
            zone = zone_ref(npc_zone(n)) if n else (zone_ref(w['pos'][0]) if w['pos'] else None)
            if w['class'] in ('r', 'R') or (n and 'rare' in n.get('kinds', ())):
                num, kind = src.add('R', name, 0, zone, nid), 'rare'
            else:
                num, kind = src.add('W', name, 0, 0, zone, nid), 'world'
        for item in sorted(w['items']):
            note(item, num, kind)

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
    # the lazy text is compacted (lua_data.compact): no indentation, no blank around "=" and ","
    m = re.search(r'\n\s*ST\s*=\s*\{\n(.*?)\n\s*\},', text, re.S)
    if not m:
        return {}
    # stat texts are KEY=value pairs: no quotes or escapes in them
    return {int(i): v for i, v in re.findall(r'^\s*\[(\d+)\]\s*=\s*"([^"\\]*)",$', m.group(1), re.M)}


def client_has(client, iid):
    """Whether the client's own item table holds an id: client is a set of ids or a list of [from, to]
    ranges (the scan archive's); None: unknown, so every id counts as known."""
    if client is None:
        return True
    if isinstance(client, (set, frozenset)):
        return iid in client
    lo, hi = 0, len(client)
    while lo < hi:
        mid = (lo + hi) // 2
        if client[mid][1] < iid:
            lo = mid + 1
        else:
            hi = mid
    return lo < len(client) and client[lo][0] <= iid <= client[lo][1]


def clean_name(name):
    """An item name as the data may hold it: plain text, no codes, at most 64 bytes."""
    name = re.sub(r'\|c[0-9a-fA-F]{8}|\|r', '', str(name or '')).replace('|', '').strip()
    return name if 0 < len(name.encode('utf-8')) <= 64 else ''


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
        '-- RP: [itemID] = faction id * 10 + the standing it asks for (0 hated .. 7 exalted), from the client\'s',
        '-- ItemSparse (MinFactionID, MinReputation). QT: [questID] = the quest type the addon learned from the quest',
        '-- log (G group or elite, D dungeon, R raid, P PvP; tools/quest_tag_archive.json), for the quests of S.',
        '-- N, IC: [itemID] = the name (as the German client showed it) and the icon file id the scan saw, only for',
        '-- the items the client\'s own item table lacks: the server alone describes those and may no longer do so.',
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
    # the reputation an item asks for, from the client's own item table
    rep = info.get('rep') or {}
    lines.append('    RP = {')
    for iid in sorted(keep):
        if iid in rep:
            fac, standing = rep[iid]
            lines.append(f'        [{iid}] = {fac * 10 + standing},')
    lines.append('    },')
    qtags = info.get('qtags') or {}
    lines.append('    QT = {')
    # a quest record holds its id seventh (a short one, as the collector's, none)
    quest_ids = {src.rows[n - 1][6] for n in used if src.rows[n - 1][0] == 'Q' and len(src.rows[n - 1]) > 6}
    for qid in sorted(quest_ids & set(qtags)):
        lines.append(f'        [{qid}] = {lua_str(qtags[qid])},')
    lines.append('    },')
    # name and icon of the items only the server describes (the addon's own tooltip, D-59)
    unknown = [iid for iid in sorted(keep) if not client_has(info.get('client'), iid)]
    lines.append('    N = {')
    for iid in unknown:
        name = clean_name(keep[iid][0].get('name'))
        if name:
            lines.append(f'        [{iid}] = {lua_str(name)},')
    lines.append('    },')
    lines.append('    IC = {')
    for iid in unknown:
        icon = str(keep[iid][0].get('icon') or '')
        if icon.isdigit() and int(icon) > 0:
            lines.append(f'        [{iid}] = {icon},')
    lines.append('    },')
    lines.append('    M = {')
    for i in range(0, len(missing), 20):
        lines.append('        ' + ', '.join(str(x) for x in missing[i:i + 20]) + ',')
    lines.append('    },')
    lines.append('}')
    # the addon builds the table on first use (Core/LazyData.lua)
    with open(out, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(lua_data.lazy('\n'.join(lines) + '\n', 'GEAR', len(keep)))
    return len(used)


def default_svs():
    """The scan dumps in the repo root, the SavedVariables Syncthing brings to the N100 and those of
    an installed Forever client: whichever exist."""
    paths = [os.path.join(ROOT, f) for f in ('Amisia_teil1.lua', 'Amisia_teil2.lua')]
    paths.append(build_scan.DEFAULT_SV)
    for flavor in FOREVER_FLAVORS:
        paths += sorted(glob.glob(os.path.join(WOW_ROOT, flavor, 'WTF', 'Account', '*', 'SavedVariables', 'Amisia.lua')))
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
    ap.add_argument('--wago', default=None, help='folder with the client tables (ItemSparse, UiMapAssignment, AreaTable, ...; default: the newest copy of each table, tools/client_tables.py)')
    ap.add_argument('--sv', nargs='*', help='Amisia SavedVariables files with item scans (default: repo dumps, '
                                            '~/addons/_SavedVariables/Amisia.lua, installed Forever client)')
    ap.add_argument('--scan-archive', default=build_scan_archive.ARCHIVE,
                    help='the scan archive read under the SavedVariables (default tools/scan_archive.json; "" for none)')
    ap.add_argument('--out', default=OUT)
    ap.add_argument('--refresh-wowsrc', action='store_true', help='download the wowsrc.com dungeon pages again')
    ap.add_argument('--no-wowsrc', action='store_true', help='leave the wowsrc.com dungeon pages out')
    ap.add_argument('--show-unmatched', action='store_true')
    ap.add_argument('--itemsparse', help='ItemSparse CSV export of the Forever client (wago.tools, with hotfixes), or a '
                                         'folder holding ItemSparse[.<build>].csv; refreshes tools/gear_itemsparse.json')
    args = ap.parse_args(argv)
    if args.wago is None:
        import client_tables
        args.wago = client_tables.default_dir()

    if args.refresh_att:
        att_data.refresh(args.att)
    if not os.path.isdir(os.path.join(args.att, 'dungeons & raids')):
        raise SystemExit(f'no AllTheThings download in {args.att}: run with --refresh-att')
    att = att_data.load(args.att, wago=args.wago)
    log(f'AllTheThings {(att["commit"] or "?")[:10]}: {len(att["items"])} items, {len(att["quests"])} quests, '
        f'{len(att["npcs"])} NPCs, {len(att["instances"])} instances'
        + (f'; files that failed: {sorted(att["errors"])}' if att['errors'] else ''))

    svs = args.sv if args.sv is not None else default_svs()
    scan_items, collected, observed = {}, {}, {}
    dbs = [build_scan.load_sv(p) for p in svs]
    # the scan archive under the files (theirs win): what the addon trimmed after a build is kept there
    scan_dbs = build_scan_archive.with_archive(dbs, args.scan_archive)
    if scan_dbs:
        scan_items, _, collected = build_scan.collect(scan_dbs)
    if svs:
        # own observations, heard ones only where two accounts agree, item ids the client has
        item_ok = build_scan.observed_item_filter(args.wago)
        if item_ok is None:
            log(f'no ItemSparse in {args.wago}: the source collector\'s item ids are not checked against the client')
        observed = build_scan.collect_observed(dbs, item_ok)
    log(f'scan: {len(scan_items)} items from {len(svs)} file(s)' + (' and the scan archive' if len(scan_dbs) > len(dbs) else '')
        + f', {len(collected)} with collector notes; source collector: '
        f'{len((observed or {}).get("q", {}))} quests, {len((observed or {}).get("s", {}))} vendors, '
        f'{len((observed or {}).get("w", {}))} mobs')

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

    crafts = client_crafts(args.wago, att.get('crafted', []))
    log(f'client recipes: {sum(len(r) for r in crafts.values())} crafted items with their skill')
    forever_raids = load_forever_raids()
    log(f'wowsrc: {len(wowsrc.get("dungeons", []))} dungeons; '
        f'forever raids: {len(forever_raids)} drops')

    # what earlier scans said, kept in the generated file: the item table and the stats
    last = args.out if os.path.exists(args.out) else OUT
    prev_items, old_stats = previous_items(last), previous_stats(last)
    log(f'last build ({os.path.relpath(last, ROOT)}): {len(prev_items)} items, {len(old_stats)} with stats')
    src, keep, zone_rows, stats, dropped, unmatched, missing = build(
        scan_items, collected, att, crafts, wowsrc, itemsparse, forever_raids, load_facts(),
        prev_items, observed)
    missing = client_known(missing, args.wago)
    sources = [att_data.ATT_SOURCE + (f' at {att["commit"][:10]}' if att.get('commit') else ''), 'the Amisia item scan']
    if crafts:
        sources.append('the WoW Forever client tables (recipes)')
    if wowsrc:
        sources.append('wowsrc.com')
    rep = client_reputation(args.wago)
    qtags = update_quest_tags(dbs)
    # the quest scan by id (D-104): levels where the sources have none, types the quest log did not teach
    qinfo = scan_quest_info(build_scan_archive.id_scans(args.scan_archive or None, dbs))
    took = apply_quest_scan(src, qinfo)
    qtags = scan_quest_tags(qtags, qinfo)
    no_level = sum(1 for r in src.rows if r[0] == 'Q' and len(r) > 2 and not r[2])
    log(f'quest scan: {len(qinfo)} quests scanned, {took} quest levels taken; {no_level} quest sources still without a level')
    # the ids of the client's item table: the export, else the scan archive's ranges
    client = client_item_ids(args.wago)
    if client is None and args.scan_archive and os.path.exists(args.scan_archive):
        client = (build_scan_archive.load(args.scan_archive).get('client') or {}).get('ids')
    n_src = write_lua(args.out, src, keep, zone_rows, {'built': time.strftime('%Y-%m-%d'), 'sources': sources,
                                                      'rep': rep, 'qtags': qtags, 'client': client}, missing, old_stats)
    log(f'reputation: {sum(1 for i in keep if i in rep)} of {len(keep)} items ask for a standing')
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
