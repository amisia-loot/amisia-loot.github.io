"""The buffs of the lineup (F-224, spec docs/specs/2026-11-17-raid-buffs-im-planer.md, D-149): what the
classes placed in the planner can bring to the raid, in three blocks (buffs, on the boss, utility). From the
client's own tables only (D-03), never from the net.

    python tools/build_raidbuffs.py [--wago DIR ...] [--talents FILE] [--out FILE]

- The list below names each entry by English spell names (one row per thing an officer thinks of, so
  "remove curse" holds the mage's and the druid's spell), its block, whether it reaches the raid or only the
  caster's group (kept here: SpellEffect cannot tell it reliably, ranks and NPC copies mix), the roles a
  talent entry needs (Leader of the Pack: tank or melee), and in one case a fixed class (Blood Pact is the
  imp's spell, in no class skill line).
- The class comes from the tables: SkillLineAbility puts a spell into a skill line, SkillRaceClassInfo
  names the skill line's class (a single class bit of ClassMask), ChrClasses the token of the class id.
- "Talent" comes from the tables too: the name (or `via`, the talent that gives it: Moonkin Form for the
  Moonkin Aura) is a node of the class's talent tree in Amisia_Gear/Data/TalentData.lua, which
  tools/build_talents.py writes from the trait tables before this runs (build.py data).
- Per entry one spell id for the name and icon the addon asks the client for: the highest id with the
  first name in the class's skill line; its icon (SpellMisc.SpellIconFileDataID) rides along in case the
  client gives none.
- A name no class has (gone in a new build) is dropped and reported; an entry left without a class is
  dropped. tools/tests/test_build_raidbuffs.py fails on either with the tables on disk.

Reads <Table>.csv or <Table>.<build>.csv from the folders given with --wago (default: the newest copy of each
table, tools/client_tables.py).
Writes Amisia_Gear/Data/RaidBuffData.lua (ns.RAIDBUFFS, lazy).
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
import modules  # noqa: E402  (where each Data/* file stands, F-228)

OUT = modules.data_file('RaidBuffData.lua')
TALENTS = modules.data_file('TalentData.lua')
WAGO = os.path.expanduser('~/addons/_wago')

REQUIRED = ['SpellName', 'SkillLineAbility', 'SkillRaceClassInfo', 'ChrClasses']
OPTIONAL = ['SpellMisc']

BLOCKS = ('buff', 'boss', 'util')
SCOPES = ('raid', 'group')
ROLES = set('THMR')

# key, block, scope, English spell names (the first gives name and icon), options:
#   roles  the roles a placed player of the class needs for it (talent entries: the spec's role gates)
#   cls    a fixed class for a spell in no class skill line (the warlock's imp)
#   via    the talent that gives the spell when its own name is no talent node
ENTRIES = [
    # buffs
    ('int', 'buff', 'raid', ['Arcane Intellect', 'Arcane Brilliance'], {}),
    ('sta', 'buff', 'raid', ['Power Word: Fortitude', 'Prayer of Fortitude'], {}),
    ('spirit', 'buff', 'raid', ['Divine Spirit', 'Prayer of Spirit'], {}),
    ('shadow', 'buff', 'raid', ['Shadow Protection', 'Prayer of Shadow Protection'], {}),
    ('wild', 'buff', 'raid', ['Mark of the Wild', 'Gift of the Wild'], {}),
    ('kings', 'buff', 'raid', ['Blessing of Kings', 'Greater Blessing of Kings'], {}),
    ('might', 'buff', 'raid', ['Blessing of Might'], {}),
    ('wisdom', 'buff', 'raid', ['Blessing of Wisdom'], {}),
    ('devotion', 'buff', 'group', ['Devotion Aura'], {}),
    ('retri', 'buff', 'group', ['Retribution Aura'], {}),
    ('conc', 'buff', 'group', ['Concentration Aura'], {}),
    ('fireres', 'buff', 'group', ['Fire Resistance Aura'], {}),
    ('battle', 'buff', 'group', ['Battle Shout'], {}),
    ('command', 'buff', 'group', ['Commanding Shout'], {}),
    ('windfury', 'buff', 'group', ['Windfury Totem'], {}),
    ('soe', 'buff', 'group', ['Strength of Earth Totem'], {}),
    ('goa', 'buff', 'group', ['Grace of Air Totem'], {}),
    ('manaspring', 'buff', 'group', ['Mana Spring Totem'], {}),
    ('healstream', 'buff', 'group', ['Healing Stream Totem'], {}),
    ('flametongue', 'buff', 'group', ['Flametongue Totem'], {}),
    ('tremor', 'buff', 'group', ['Tremor Totem'], {}),
    ('poisontotem', 'buff', 'group', ['Poison Cleansing Totem'], {}),
    ('trueshot', 'buff', 'group', ['Trueshot Aura'], {}),
    ('lotp', 'buff', 'group', ['Leader of the Pack'], {'roles': 'TM'}),
    ('moonkin', 'buff', 'group', ['Moonkin Aura'], {'roles': 'R', 'via': 'Moonkin Form'}),
    ('bloodpact', 'buff', 'group', ['Blood Pact'], {'cls': 'WARLOCK'}),
    # on the boss
    ('sunder', 'boss', 'raid', ['Sunder Armor'], {}),
    ('expose', 'boss', 'raid', ['Expose Armor'], {}),
    ('faerie', 'boss', 'raid', ['Faerie Fire'], {}),
    ('elements', 'boss', 'raid', ['Curse of the Elements'], {}),
    ('reckless', 'boss', 'raid', ['Curse of Recklessness'], {}),
    ('mark', 'boss', 'raid', ["Hunter's Mark"], {}),
    ('demo', 'boss', 'raid', ['Demoralizing Shout', 'Demoralizing Roar'], {}),
    ('thunder', 'boss', 'raid', ['Thunder Clap'], {}),
    ('jow', 'boss', 'raid', ['Judgement of Wisdom'], {}),
    ('jol', 'boss', 'raid', ['Judgement of Light'], {}),
    ('scorch', 'boss', 'raid', ['Improved Scorch'], {}),
    ('chill', 'boss', 'raid', ["Winter's Chill"], {}),
    ('weaving', 'boss', 'raid', ['Shadow Weaving'], {}),
    ('vtouch', 'boss', 'raid', ['Vampiric Touch'], {}),
    # utility
    ('rebirth', 'util', 'raid', ['Rebirth'], {}),
    ('soulstone', 'util', 'raid', ['Create Soulstone'], {}),
    ('healthstone', 'util', 'raid', ['Create Healthstone'], {}),
    ('curse', 'util', 'raid', ['Remove Curse', 'Remove Lesser Curse'], {}),
    ('magic', 'util', 'raid', ['Dispel Magic', 'Cleanse'], {}),
    ('poison', 'util', 'raid', ['Cure Poison', 'Abolish Poison', 'Purify', 'Cleanse'], {}),
    ('disease', 'util', 'raid', ['Cure Disease', 'Abolish Disease', 'Purify', 'Cleanse'], {}),
    ('tranq', 'util', 'raid', ['Tranquilizing Shot'], {}),
    ('fearward', 'util', 'raid', ['Fear Ward'], {}),
    ('innervate', 'util', 'raid', ['Innervate'], {}),
    ('manatide', 'util', 'group', ['Mana Tide Totem'], {'roles': 'H'}),
]


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
    m = re.search(r'\.(\d+(?:\.\d+)+)\.csv$', find_table(dirs, 'SpellName') or '')
    return m.group(1) if m else ''


def load_client(dirs):
    missing = [t for t in REQUIRED if not find_table(dirs, t)]
    if missing:
        raise SystemExit('build_raidbuffs: client tables missing in %s: %s (export them with '
                         'tools/export_db2.ps1 -Tables %s)' % (', '.join(dirs), ', '.join(missing), ','.join(missing)))
    return {t: read_table(dirs, t) for t in REQUIRED + OPTIONAL}


NODE = re.compile(r'\{\d+,\d+,\d+,[^"]*?"((?:[^"\\]|\\.)*)",')


def talent_names(path=TALENTS):
    """{ class token: { talent node names } } from the generated TalentData.lua (empty without it)."""
    if not path or not os.path.exists(path):
        return {}
    with open(path, encoding='utf-8') as fh:
        src = fh.read()
    starts = [(m.start(), m.group(1)) for m in re.finditer(r'(?m)^([A-Z]+)=\{id=\d+', src)]
    out = {}
    for i, (pos, cls) in enumerate(starts):
        end = starts[i + 1][0] if i + 1 < len(starts) else len(src)
        out[cls] = {m.group(1).replace('\\"', '"') for m in NODE.finditer(src, pos, end)}
    return out


def class_spells(t):
    """{ spell id: { class token } } of the spells in a class's skill line."""
    tokens = {num(r.get('ID')): (r.get('Filename') or '').upper() for r in t['ChrClasses']}
    skill_class = {}
    for r in t['SkillRaceClassInfo']:
        m = num(r.get('ClassMask'))
        if m > 0 and m & (m - 1) == 0:
            cid = m.bit_length()
            if tokens.get(cid):
                skill_class.setdefault(num(r.get('SkillID')), set()).add(tokens[cid])
    out = {}
    for r in t['SkillLineAbility']:
        for cls in skill_class.get(num(r.get('SkillLine')), ()):
            out.setdefault(num(r.get('Spell')), set()).add(cls)
    return out


def build(dirs, talents=TALENTS):
    t = load_client(dirs)
    by_name = {}
    for r in t['SpellName']:
        by_name.setdefault(r.get('Name_lang') or '', []).append(num(r['ID']))
    in_line = set(num(r.get('Spell')) for r in t['SkillLineAbility'])
    of_class = class_spells(t)
    icons = {num(r.get('SpellID')): num(r.get('SpellIconFileDataID')) for r in (t.get('SpellMisc') or [])}
    tal = talent_names(talents) if isinstance(talents, str) or talents is None else talents
    entries, dropped = [], []
    for key, block, scope, names, opts in ENTRIES:
        classes = []           # [ (class token, talent) ] in the order of the names
        spell = 0
        for name in names:
            ids = by_name.get(name, [])
            if opts.get('cls'):
                found = {opts['cls']: [i for i in ids if i in in_line] or ids}
            else:
                found = {}
                for i in ids:
                    for cls in of_class.get(i, ()):
                        found.setdefault(cls, []).append(i)
            if not found or not any(found.values()):
                dropped.append('%s: "%s" belongs to no class' % (key, name))
                continue
            for cls in sorted(found):
                if not spell and name == names[0]:
                    spell = max(found[cls])
                talent = name in tal.get(cls, ()) or (opts.get('via') or '') in tal.get(cls, ())
                if cls not in [c for c, _ in classes]:
                    classes.append((cls, talent))
        if not classes:
            dropped.append('%s: no class left, dropped' % key)
            continue
        if not spell:
            # the first name is gone: the next one that resolved gives name and icon
            for name in names[1:]:
                ids = [i for i in by_name.get(name, []) if of_class.get(i) or opts.get('cls')]
                if ids:
                    spell = max(ids)
                    break
        entries.append({'key': key, 'block': block, 'scope': scope, 'spell': spell, 'icon': icons.get(spell, 0),
                        'roles': opts.get('roles', ''), 'classes': classes})
    return {'build': build_of(dirs), 'entries': entries, 'dropped': dropped}


def empty_data():
    return {'build': '', 'entries': [], 'dropped': []}


# ---------------------------------------------------------------- output
def lua_str(s):
    return '"' + str(s).replace('\\', '\\\\').replace('"', '\\"') + '"'


def render_lua(data, built=None):
    L = [
        '-- Generated by tools/build_raidbuffs.py from the WoW Forever client tables (build %s): SpellName,' % (data['build'] or '?'),
        '-- SkillLineAbility, SkillRaceClassInfo, ChrClasses, SpellMisc and the talent trees of Data/TalentData.lua.',
        '-- Do not edit; rebuild instead. The buffs of the lineup (F-224, D-149), in the order shown:',
        '-- { key, block buff/boss/util, scope raid/group, spell id (name and icon), icon file id or 0,',
        '--   roles a placed player needs ("" any), { class token, talent 1/0, ... } }',
        'local _, ns = ...',
        '',
        'ns.RAIDBUFFS = {',
        '    build = %s, built = %s,' % (lua_str(data['build']), lua_str(built or time.strftime('%Y-%m-%d'))),
        '    entries = {',
    ]
    for e in data['entries']:
        cls = ', '.join('%s, %d' % (lua_str(c), 1 if talent else 0) for c, talent in e['classes'])
        L.append('        { %s, %s, %s, %d, %d, %s, { %s } },' % (lua_str(e['key']), lua_str(e['block']), lua_str(e['scope']),
                                                                 e['spell'], e['icon'], lua_str(e['roles']), cls))
    L += ['    },', '}', '']
    return lua_data.lazy('\n'.join(L), 'RAIDBUFFS', len(data['entries']))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--wago', action='append', default=None, help='client tables (default: the newest copy of each table, tools/client_tables.py); may repeat')
    ap.add_argument('--talents', default=TALENTS, help='the generated talent data (default: %(default)s)')
    ap.add_argument('--empty', action='store_true', help='write the file without data')
    ap.add_argument('--out', default=OUT)
    args = ap.parse_args(argv)
    if args.empty:
        data = empty_data()
    else:
        if not args.wago:
            import client_tables
            args.wago = [client_tables.default_dir()]
        dirs = [os.path.expanduser(d) for d in args.wago]
        data = build(dirs, args.talents)
        for line in data['dropped']:
            print('build_raidbuffs: ' + line, file=sys.stderr)
    with open(args.out, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(render_lua(data))
    blocks = {b: sum(1 for e in data['entries'] if e['block'] == b) for b in BLOCKS}
    print(f"build_raidbuffs: {len(data['entries'])} entries (buffs {blocks['buff']}, boss {blocks['boss']}, "
          f"utility {blocks['util']}), {len(data['dropped'])} dropped -> {os.path.relpath(args.out, ROOT)}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
