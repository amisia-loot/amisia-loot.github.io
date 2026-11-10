"""What a new client build brings: the client tables of two builds on disk compared (D-103).

    python3 tools/build_diff.py [OLD NEW] [--out FILE] [--short N]
    python3 tools/build.py diff [OLD NEW]

OLD defaults to the build main's data was made from (the build line of Data/TalentData.lua on main,
as tools/auto_data.py reads it), NEW to the newest build any client table on disk has. A table of a
build is the file <Table>.<build>.csv of the three places tools/client_tables.py knows (the user's
export, the wago.tools exports, AllTheThings' copies); where more than one has it, the one with more
rows. Nothing here touches the network.

Rows are matched by their ID column. A field counts as changed only when both builds have its column
and the values differ: numbers compared as numbers with a small tolerance (the exports write floats
differently: 0.4 and 0.40000000596 are the same float), text as text. A column only one build has is
named, not counted. The report (English, like the other tools' output) has a short head (the first
lines: tools/auto_data.py puts them into ~/addons/_auto/amisia-data.txt) and then the sections:
items (new by quality and slot, removed, changed fields), quests (QuestV2: ids, with the names
Amisia's quest data knows), dungeons and bosses (Map, DungeonEncounter, LFGDungeons), the spells of
talents and professions whose rows changed (counts and the first entries only), flight points
(TaxiNodes), and every table's counts of new, removed and changed rows.
"""
import argparse
import csv
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import client_tables  # noqa: E402

QUEST_DATA = os.path.join(ROOT, 'Amisia', 'Data', 'QuestData.lua')
REL_TOL, ABS_TOL = 1e-5, 1e-6
TOP = 25                    # entries listed per section; the rest only counted
SHORT = 8                   # lines of the short head
QUALITY = {0: 'poor', 1: 'common', 2: 'uncommon', 3: 'rare', 4: 'epic', 5: 'legendary', 6: 'artifact', 7: 'heirloom'}
SLOT = {0: 'none', 1: 'head', 2: 'neck', 3: 'shoulder', 4: 'shirt', 5: 'chest', 6: 'waist', 7: 'legs', 8: 'feet',
        9: 'wrist', 10: 'hands', 11: 'finger', 12: 'trinket', 13: 'one-hand', 14: 'shield', 15: 'ranged', 16: 'back',
        17: 'two-hand', 18: 'bag', 19: 'tabard', 20: 'robe', 21: 'main hand', 22: 'off hand', 23: 'held in off hand',
        24: 'ammo', 25: 'thrown', 26: 'ranged (wand, gun)', 27: 'quiver', 28: 'relic'}
# item fields worth naming one by one; the rest of a changed item is "other"
ITEM_FIELDS = ('ItemLevel', 'RequiredLevel', 'OverallQualityID', 'InventoryType', 'Display_lang', 'ItemSet',
               'AllowableClass', 'RequiredSkill', 'RequiredSkillRank', 'Bonding', 'ItemDelay')
PROFESSION_CATEGORIES = (9, 11)  # SkillLine.CategoryID: secondary skills, professions
STAT = re.compile(r'^Stat(Modifier_bonusStat|PercentEditor|PercentageOfSocket)_\d+$')
NUM = re.compile(r'^-?\d+(\.\d+)?([eE][-+]?\d+)?$')


# ---------------------------------------------------------------- files and tables
def builds_on_disk(srcs=None):
    """Every build any client table file of the places has, oldest first."""
    found = set()
    for _, folder in (client_tables.sources() if srcs is None else srcs):
        for files in client_tables.files_of(folder).values():
            found.update(v for v, _ in files if v)
    return sorted(found, key=client_tables.version_key)


def table_files(build, srcs=None, rows=None):
    """{table: path} of the files of exactly this build; where more places have a table, the one with
    more rows (a tie to the order of the places)."""
    rows = rows or client_tables.Rows()
    best = {}
    for _, folder in (client_tables.sources() if srcs is None else srcs):
        for table, files in client_tables.files_of(folder).items():
            for version, path in files:
                if version != build:
                    continue
                n = rows(path)
                if table not in best or n > best[table][0]:
                    best[table] = (n, path)
    return {t: p for t, (n, p) in best.items() if n >= 0}


def read_table(path):
    """(columns, {id: row dict}) of a CSV file keyed by its ID column; (columns, None) without one."""
    with open(path, encoding='utf-8-sig', newline='') as fh:
        reader = csv.DictReader(fh)
        cols = list(reader.fieldnames or [])
        if 'ID' not in cols:
            return cols, None
        out = {}
        for r in reader:
            try:
                out[int(r['ID'])] = r
            except (TypeError, ValueError):
                continue
    return cols, out


def same(a, b):
    """Two field values are the same: equal text, or numbers equal within the tolerance."""
    a, b = (a or '').strip(), (b or '').strip()
    if a == b:
        return True
    if NUM.match(a) and NUM.match(b):
        x, y = float(a), float(b)
        return abs(x - y) <= max(ABS_TOL, REL_TOL * max(abs(x), abs(y)))
    return False


def diff_rows(old, new, cols):
    """(new ids, removed ids, {id: [changed fields]}) over the columns cols (those both builds have)."""
    added = sorted(set(new) - set(old))
    removed = sorted(set(old) - set(new))
    changed = {}
    for i in sorted(set(old) & set(new)):
        a, b = old[i], new[i]
        fields = [c for c in cols if c != 'ID' and not same(a.get(c), b.get(c))]
        if fields:
            changed[i] = fields
    return added, removed, changed


class Build:
    """The tables of one build, read when first asked for."""

    def __init__(self, build, files):
        self.build, self.files, self.cache = build, files, {}

    def has(self, table):
        return table in self.files

    def get(self, table):
        if table not in self.cache:
            self.cache[table] = read_table(self.files[table]) if table in self.files else ([], None)
        return self.cache[table]

    def rows(self, table):
        return self.get(table)[1] or {}


def compare(old, new, table):
    """{'new', 'removed', 'changed', 'cols_added', 'cols_removed'} of one table both builds have, or None."""
    if not (old.has(table) and new.has(table)):
        return None
    oc, orows = old.get(table)
    nc, nrows = new.get(table)
    if orows is None or nrows is None:
        return None
    cols = [c for c in nc if c in oc]
    added, removed, changed = diff_rows(orows, nrows, cols)
    return {'new': added, 'removed': removed, 'changed': changed,
            'cols_added': [c for c in nc if c not in oc], 'cols_removed': [c for c in oc if c not in nc]}


# ---------------------------------------------------------------- names
def _int(v):
    try:
        return int(float(v))
    except (TypeError, ValueError):
        return 0


def quest_names(path=QUEST_DATA):
    """{quest id: English name} of Amisia's quest data (Q entries "zone;name;..."); empty without it."""
    try:
        with open(path, encoding='utf-8') as fh:
            text = fh.read()
    except OSError:
        return {}
    return {int(m.group(1)): m.group(2) for m in re.finditer(r'\[(\d+)\]="\d+;([^;"]*);', text)}


def _clip(items, n=TOP):
    items = list(items)
    return items[:n], max(0, len(items) - n)


def _more(rest):
    return f' (and {rest} more)' if rest else ''


def _counts(d):
    return ', '.join(f'{k} {v}' for k, v in sorted(d.items(), key=lambda kv: (-kv[1], kv[0])))


# ---------------------------------------------------------------- sections
def items_section(old, new):
    """(head line or None, lines) of ItemSparse (names, quality, slot, level) with Item's class."""
    c = compare(old, new, 'ItemSparse')
    if c is None:
        return None, [f'Items: ItemSparse not in both builds ({_which(old, new, "ItemSparse")})']
    rows_n, rows_o = new.rows('ItemSparse'), old.rows('ItemSparse')

    def name(i, rows):
        return (rows.get(i) or {}).get('Display_lang') or f'item {i}'
    lines = []
    by_q, by_slot = {}, {}
    for i in c['new']:
        r = rows_n[i]
        q = QUALITY.get(_int(r.get('OverallQualityID')), r.get('OverallQualityID'))
        by_q[q] = by_q.get(q, 0) + 1
        s = SLOT.get(_int(r.get('InventoryType')), r.get('InventoryType'))
        by_slot[s] = by_slot.get(s, 0) + 1
    lines.append(f'Items: {len(c["new"])} new, {len(c["removed"])} removed, {len(c["changed"])} changed')
    if c['new']:
        lines.append(f'  new by quality: {_counts(by_q)}')
        lines.append(f'  new by slot: {_counts(by_slot)}')
        best = sorted(c['new'], key=lambda i: (-_int(rows_n[i].get('OverallQualityID')), -_int(rows_n[i].get('ItemLevel')), i))
        shown, rest = _clip(best)
        for i in shown:
            r = rows_n[i]
            lines.append(f'    {i} {name(i, rows_n)} ({QUALITY.get(_int(r.get("OverallQualityID")), "?")}, '
                         f'{SLOT.get(_int(r.get("InventoryType")), "?")}, item level {r.get("ItemLevel")}, '
                         f'level {r.get("RequiredLevel")})')
        if rest:
            lines.append(f'    ... and {rest} more')
    if c['removed']:
        shown, rest = _clip(c['removed'])
        lines.append('  removed: ' + ', '.join(f'{i} {name(i, rows_o)}' for i in shown) + _more(rest))
    fields = {}
    for fl in c['changed'].values():
        for f in fl:
            fields[f] = fields.get(f, 0) + 1
    if c['changed']:
        lines.append(f'  changed fields (items with the field): {_counts(fields)}')
        shown, rest = _clip(c['changed'])
        for i in shown:
            fl = c['changed'][i]
            parts = [f'{f} {rows_o[i].get(f)} -> {rows_n[i].get(f)}' for f in fl
                     if f in ITEM_FIELDS or STAT.match(f) or f.startswith('Flags')]
            others = [f for f in fl if not (f in ITEM_FIELDS or STAT.match(f) or f.startswith('Flags'))]
            lines.append(f'    {i} {name(i, rows_n)}: ' + ', '.join(parts + others))
        if rest:
            lines.append(f'    ... and {rest} more')
    for k in ('cols_added', 'cols_removed'):
        if c[k]:
            lines.append(f'  columns {k[5:]}: {", ".join(c[k])}')
    by_qid = {}
    for i in c['new']:
        q = _int(rows_n[i].get('OverallQualityID'))
        by_qid[q] = by_qid.get(q, 0) + 1
    top_q = ', '.join(f'{by_qid[q]} {QUALITY.get(q, q)}' for q in sorted(by_qid, reverse=True)[:3])
    head = (f'Items: {len(c["new"])} new' + (f' ({top_q})' if top_q else '') + f', {len(c["removed"])} removed, '
            f'{len(c["changed"])} changed' + (' (' + ', '.join(f'{f} {n}' for f, n in sorted(
                fields.items(), key=lambda kv: (-kv[1], kv[0]))[:4]) + (', ...' if len(fields) > 4 else '') + ')'
                if fields else ''))
    return head, lines


def _which(old, new, table):
    have = [b.build for b in (old, new) if b.has(table)]
    return 'only in ' + have[0] if have else 'in neither'


def quests_section(old, new, names=None):
    c = compare(old, new, 'QuestV2')
    if c is None:
        n = len(new.rows('QuestV2'))
        return None, [f'Quests: QuestV2 not in both builds ({_which(old, new, "QuestV2")}'
                      + (f', {n} quest ids in {new.build}' if n else '') + ')']
    names = quest_names() if names is None else names

    def q(i):
        return f'{i} {names[i]}' if names.get(i) else str(i)
    lines = [f'Quests (QuestV2): {len(c["new"])} new, {len(c["removed"])} removed']
    for k in ('new', 'removed'):
        if c[k]:
            shown, rest = _clip(c[k], 40)
            lines.append(f'  {k}: ' + ', '.join(q(i) for i in shown) + _more(rest))
    if c['new'] or c['removed']:
        lines.append('  (names only where Amisia\'s quest data knows the quest; the table has none)')
    return f'Quests: {len(c["new"])} new, {len(c["removed"])} removed', lines


def dungeons_section(old, new):
    lines, head = [], []
    maps = new.rows('Map')
    cm = compare(old, new, 'Map')
    if cm is None:
        lines.append(f'Dungeons: Map not in both builds ({_which(old, new, "Map")})')
    else:
        inst = [i for i in cm['new'] if _int(maps[i].get('InstanceType')) in (1, 2)]
        gone = [i for i in cm['removed'] if _int(old.rows('Map')[i].get('InstanceType')) in (1, 2)]
        lines.append(f'Dungeons and raids (Map): {len(inst)} new, {len(gone)} removed')
        for i in inst:
            kind = 'raid' if _int(maps[i].get('InstanceType')) == 2 else 'dungeon'
            size = _int(maps[i].get('MaxPlayers'))
            lines.append(f'    {i} {maps[i].get("MapName_lang")} ({kind}' + (f', {size} players' if size else '') + ')')
        for i in gone:
            lines.append(f'    removed {i} {old.rows("Map")[i].get("MapName_lang")}')
        if inst:
            head.append(f'{len(inst)} new dungeons/raids (' + ', '.join(maps[i].get('MapName_lang') or str(i) for i in inst[:4])
                        + (', ...' if len(inst) > 4 else '') + ')')
    ce = compare(old, new, 'DungeonEncounter')
    if ce is None:
        lines.append(f'Bosses: DungeonEncounter not in both builds ({_which(old, new, "DungeonEncounter")})')
    else:
        enc, eo = new.rows('DungeonEncounter'), old.rows('DungeonEncounter')
        lines.append(f'Bosses (DungeonEncounter): {len(ce["new"])} new, {len(ce["removed"])} removed, '
                     f'{len(ce["changed"])} changed')

        def where(r, rows):
            m = (rows.get(_int(r.get('MapID'))) or {}).get('MapName_lang')
            return m or f'map {r.get("MapID")}'
        shown, rest = _clip(ce['new'], 40)
        for i in shown:
            lines.append(f'    {i} {enc[i].get("Name_lang")} ({where(enc[i], maps)})')
        if rest:
            lines.append(f'    ... and {rest} more')
        for i in ce['removed'][:TOP]:
            lines.append(f'    removed {i} {eo[i].get("Name_lang")}')
        for i in list(ce['changed'])[:TOP]:
            lines.append(f'    changed {i} {enc[i].get("Name_lang")}: {", ".join(ce["changed"][i])}')
        if ce['new']:
            head.append(f'{len(ce["new"])} new bosses')
    cl = compare(old, new, 'LFGDungeons')
    if cl and cl['new']:
        lf = new.rows('LFGDungeons')
        shown, rest = _clip(cl['new'])
        lines.append('  new in the dungeon finder (LFGDungeons): ' + ', '.join(
            f'{lf[i].get("Name_lang")}' for i in shown) + _more(rest))
    return ('Dungeons: ' + ', '.join(head)) if head else None, lines


def _spell_rows_changed(old, new):
    """{spell id: [tables]} of the spells whose rows changed, were added or removed in the spell tables."""
    out = {}
    for table, key in (('Spell', 'ID'), ('SpellName', 'ID'), ('SpellMisc', 'SpellID'), ('SpellEffect', 'SpellID')):
        c = compare(old, new, table)
        if c is None:
            continue
        rows_o, rows_n = old.rows(table), new.rows(table)
        for i in list(c['changed']) + c['new'] + c['removed']:
            r = rows_n.get(i) or rows_o.get(i) or {}
            sid = _int(r.get(key))
            if sid:
                out.setdefault(sid, set()).add(table)
    return out


def spells_section(old, new):
    """The spells of professions (SkillLineAbility) and talents (TraitDefinition) that are new or whose
    rows changed: counts and the first entries."""
    changed = _spell_rows_changed(old, new)
    names = new.rows('SpellName')
    lines, head = [], []

    def nm(s):
        return (names.get(s) or old.rows('SpellName').get(s) or {}).get('Name_lang') or f'spell {s}'
    def spells(build, table, col):
        rows = build.rows(table).values()
        if table == 'SkillLineAbility':
            # professions and secondary skills only (SkillLine.CategoryID 11 and 9), not class spells or mounts
            prof = {i for i, r in build.rows('SkillLine').items() if _int(r.get('CategoryID')) in PROFESSION_CATEGORIES}
            rows = [r for r in rows if _int(r.get('SkillLine')) in prof]
        return {_int(r.get(col)) for r in rows} - {0}
    for label, table, col in (('Profession spells', 'SkillLineAbility', 'Spell'),
                              ('Talent spells', 'TraitDefinition', 'SpellID')):
        if not new.has(table):
            lines.append(f'{label}: {table} not in {new.build}')
            continue
        now = spells(new, table, col)
        before = spells(old, table, col) if old.has(table) else None
        added = sorted(now - before) if before is not None else []
        gone = sorted(before - now) if before is not None else []
        ch = sorted(s for s in now & (before or now) if s in changed)
        lines.append(f'{label} ({table}): {len(added)} new, {len(gone)} removed, {len(ch)} changed'
                     + ('' if before is not None else f' ({table} not in {old.build}: changes only)'))
        for k, lst in (('new', added), ('removed', gone), ('changed', ch)):
            if lst:
                shown, rest = _clip(lst, 15)
                lines.append(f'  {k}: ' + ', '.join(
                    f'{s} {nm(s)}' + (f' [{"/".join(sorted(changed[s]))}]' if k == 'changed' else '')
                    for s in shown) + _more(rest))
        if added or ch:
            head.append(f'{label.lower()} {len(added)} new, {len(ch)} changed')
    return ('Spells: ' + '; '.join(head)) if head else None, lines


def flights_section(old, new):
    c = compare(old, new, 'TaxiNodes')
    if c is None:
        n = len(new.rows('TaxiNodes'))
        return None, [f'Flight points: TaxiNodes not in both builds ({_which(old, new, "TaxiNodes")}'
                      + (f', {n} nodes in {new.build}' if n else '') + ')']
    rn, ro = new.rows('TaxiNodes'), old.rows('TaxiNodes')
    lines = [f'Flight points (TaxiNodes): {len(c["new"])} new, {len(c["removed"])} removed, {len(c["changed"])} changed']
    for i in c['new']:
        lines.append(f'    {i} {rn[i].get("Name_lang")}')
    for i in c['removed']:
        lines.append(f'    removed {i} {ro[i].get("Name_lang")}')
    for i, fl in list(c['changed'].items())[:TOP]:
        lines.append(f'    changed {i} {rn[i].get("Name_lang")}: {", ".join(fl)}')
    head = None
    if c['new'] or c['removed']:
        head = (f'Flight points: {len(c["new"])} new' + (' (' + ', '.join(rn[i].get('Name_lang') or str(i) for i in c['new'][:4])
                                                        + ')' if c['new'] else '') + f', {len(c["removed"])} removed')
    return head, lines


def tables_section(old, new):
    lines = ['Every table (new / removed / changed rows):']
    only_old = sorted(t for t in old.files if t not in new.files)
    only_new = sorted(t for t in new.files if t not in old.files)
    moved = 0
    for t in sorted(set(old.files) & set(new.files)):
        c = compare(old, new, t)
        if c is None:
            lines.append(f'  {t:<28} no ID column: not compared')
            continue
        n = (len(c['new']), len(c['removed']), len(c['changed']))
        if any(n):
            moved += 1
            lines.append(f'  {t:<28} {n[0]:>6} {n[1]:>6} {n[2]:>6}'
                         + (f'  columns +{",".join(c["cols_added"])}' if c['cols_added'] else '')
                         + (f'  columns -{",".join(c["cols_removed"])}' if c['cols_removed'] else ''))
    same_n = len(set(old.files) & set(new.files)) - moved
    lines.append(f'  unchanged: {same_n} tables')
    if only_old:
        lines.append(f'  only in {old.build}: {", ".join(only_old)}')
    if only_new:
        lines.append(f'  only in {new.build}: {", ".join(only_new)}')
    head = (f'Tables: {len(set(old.files) & set(new.files))} compared, {moved} with changes'
            + (f'; only in {new.build}: {", ".join(only_new)}' if only_new else '')
            + (f'; only in {old.build}: {", ".join(only_old)}' if only_old else ''))
    return head, lines


def report(old_build, new_build, srcs=None, quest_name_map=None):
    """(short lines, full lines) of what new_build brings against old_build."""
    rows = client_tables.Rows()
    old = Build(old_build, table_files(old_build, srcs, rows))
    new = Build(new_build, table_files(new_build, srcs, rows))
    title = f'New in {new_build} against {old_build} (client tables; tools/build_diff.py)'
    if not old.files or not new.files:
        miss = [b.build for b in (old, new) if not b.files]
        line = f'{title}: no client table of {", ".join(miss)} on disk'
        return [line], [line]
    heads, body = [], []
    for fn in (items_section, quests_section, dungeons_section, flights_section, spells_section, tables_section):
        head, lines = fn(old, new) if fn is not quests_section else fn(old, new, quest_name_map)
        if head:
            heads.append(head)
        body += [''] + lines
    short = [title] + (heads or ['nothing new in the tables that matter to players'])
    return short[:SHORT], short + body


def main_build():
    """The build main's data was made from (tools/auto_data.py's reading of Data/TalentData.lua)."""
    import auto_data
    return auto_data.data_build(auto_data.git('show', 'main:Amisia/Data/TalentData.lua', check=False))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('builds', nargs='*', help='OLD NEW (default: the build of the data on main, the newest on disk)')
    ap.add_argument('--out', default=None, help='also write the full report into this file')
    ap.add_argument('--short', action='store_true', help='print only the short head')
    args = ap.parse_args(argv)
    if len(args.builds) not in (0, 2):
        raise SystemExit('give no build or two: OLD NEW')
    if args.builds:
        old, new = args.builds
    else:
        on_disk = builds_on_disk()
        old, new = main_build(), (on_disk[-1] if on_disk else None)
        if not old or not new:
            raise SystemExit(f'no builds to compare (main: {old}, newest on disk: {new})')
    for b in (old, new):
        if not re.match(r'^\d+\.\d+\.\d+\.\d+$', b or ''):
            raise SystemExit(f'not a build: {b!r}')
    if old == new:
        print(f'{new}: the data on main is of the newest build on disk; nothing to compare')
        return 0
    short, full = report(old, new)
    text = '\n'.join(full) + '\n'
    if args.out:
        with open(args.out, 'w', encoding='utf-8', newline='\n') as fh:
            fh.write(text)
    print('\n'.join(short) if args.short else text, end='\n' if args.short else '')
    return 0


if __name__ == '__main__':
    sys.exit(main())
