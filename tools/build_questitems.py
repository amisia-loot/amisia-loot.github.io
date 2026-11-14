"""Builds Amisia_Gear/Data/QuestItemData.lua (WoW Forever): per quest item the quests that use it, for the
window "Questgegenstände aufräumen" and the quest item line in the item tooltip (F-173, D-105). Runs
without a WoW install (on the N100).

    python tools/build_questitems.py [--att DIR] [--wago DIR] [--sv FILE...] [--archive FILE] [--empty]

Three kinds of link, each item to each quest once (the strongest kind wins: S, then O, then D):

- S: the item starts the quest, by the client table ItemSparse (StartQuestID). --wago (default: the
  newest copy of each table, tools/client_tables.py) holds ItemSparse and Item.
- O: Amisia saw it on the account of the user's PC: the item was required at the quest's turn-in dialog
  or named as an item objective of the quest in the quest log and found in the bags
  (AmisiaDB.questItems.links of the SavedVariables, --sv, default ~/addons/_SavedVariables/Amisia.lua
  and an installed client's). They are joined into tools/quest_item_archive.json (committed; a link
  stays once seen), so a pruned or lost file still builds the same data; --archive "" for none.
- D: AllTheThings (MIT, ~/addons/_cache/att or $AMISIA_ATT_CACHE): the quest's own provider items, the
  items it hands out (qi, qis) and the provider items of its objectives (tools/att_data.py, 'items').

Only items of the item class Quest (12) go in: by the client table Item, else AllTheThings' item export;
an item neither knows stays (the addon checks the class itself). The addon treats O and D from this file
alike ("laut Daten"): only its own observation on the player's account and the start quest the client
names for a bag item count as sure (D-105). Whether a quest is done, in the log, repeatable or of
another faction or class the addon reads from the client and from QuestData.lua (same quest ids);
nothing of that is repeated here. The size and the numbers by kind go to the log.
"""
import argparse
import csv
import json
import os
import re
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import att_data  # noqa: E402  (the AllTheThings reader)
import lua_data  # noqa: E402  (the lazy form of the data file)

OUT = os.path.join(ROOT, 'Amisia_Gear', 'Data', 'QuestItemData.lua')
ARCHIVE = os.path.join(HERE, 'quest_item_archive.json')
QUEST_CLASS = 12
KINDS = 'SOD'              # the order of strength
MAX_ID = 9999999
MAX_QUESTS = 8             # quests per item, as the addon keeps them (AmisiaDB.questItems)
REQUIRED = ['Item', 'ItemSparse']


def log(*a):
    print(*a, file=sys.stderr)


def _id(v):
    try:
        v = int(v)
    except (TypeError, ValueError):
        return None
    return v if 0 < v <= MAX_ID else None


# ---------------------------------------------------------------- client tables
def read_client(wago):
    """({item: classID} of the table Item, {item: start quest} of ItemSparse); empty without them."""
    classes, starts = {}, {}
    if not wago:
        return classes, starts
    path = att_data.wago_csv(wago, 'Item')
    if path:
        with open(path, encoding='utf-8', newline='') as fh:
            for r in csv.DictReader(fh):
                i, c = _id(r.get('ID')), r.get('ClassID')
                if i and str(c or '').lstrip('-').isdigit():
                    classes[i] = int(c)
    path = att_data.wago_csv(wago, 'ItemSparse')
    if path:
        with open(path, encoding='utf-8', newline='') as fh:
            for r in csv.DictReader(fh):
                i, q = _id(r.get('ID')), _id(r.get('StartQuestID'))
                if i and q:
                    starts[i] = q
    return classes, starts


# ---------------------------------------------------------------- own observations
def links_from_sv(db):
    """{item: [quest, ...]} of a SavedVariables' AmisiaDB.questItems.links ("q1,q2"), checked as the
    addon checks it."""
    qi = db.get('questItems') if isinstance(db, dict) else None
    links = qi.get('links') if isinstance(qi, dict) else None
    out = {}
    if not isinstance(links, dict):
        return out
    for k, v in links.items():
        item = _id(k) if not isinstance(k, bool) else None
        if not item or not isinstance(v, str) or not re.fullmatch(r'\d+(,\d+)*', v):
            continue
        qs = [q for q in (_id(x) for x in v.split(',')) if q][:MAX_QUESTS]
        if qs:
            out[item] = sorted(set(qs))
    return out


def load_archive(path=ARCHIVE):
    if not path or not os.path.exists(path):
        return {'updated': None, 'links': {}}
    with open(path, encoding='utf-8') as fh:
        arch = json.load(fh)
    arch.setdefault('links', {})
    return arch


def update_archive(dbs, path=ARCHIVE, today=None):
    """Joins the SavedVariables' own item links into the archive (a link once seen stays) and writes it
    when it changed; returns {item: [quest, ...]}."""
    arch = load_archive(path)
    links = {str(k): sorted({int(q) for q in v}) for k, v in arch['links'].items()}
    for db in dbs:
        for item, qs in links_from_sv(db).items():
            links[str(item)] = sorted(set(links.get(str(item), [])) | set(qs))
    if path and (links != arch['links'] or not os.path.exists(path)):
        arch = {'updated': today or time.strftime('%Y-%m-%d'),
                'links': dict(sorted(links.items(), key=lambda kv: int(kv[0])))}
        with open(path, 'w', encoding='utf-8', newline='\n') as fh:
            fh.write(json.dumps(arch, indent=1) + '\n')
        log(f'{os.path.relpath(path, ROOT)}: {len(links)} items with own links')
    return {int(k): v for k, v in links.items()}


# ---------------------------------------------------------------- the links
def build(att_quests, starts, observed, classes, att_classes=None):
    """{item: {quest: kind}} of the quest-class items. att_quests: {quest: [item, ...]} (D); starts:
    {item: quest} (S); observed: {item: [quest, ...]} (O); classes: {item: classID} of the client table;
    att_classes the same of AllTheThings' item export (where the client table lacks the item)."""
    att_classes = att_classes or {}
    out = {}

    def put(item, quest, kind):
        item, quest = _id(item), _id(quest)
        if not item or not quest:
            return
        have = out.setdefault(item, {})
        old = have.get(quest)
        if old is None or KINDS.index(kind) < KINDS.index(old):
            have[quest] = kind
    for quest, items in att_quests.items():
        for item in items:
            put(item, quest, 'D')
    for item, quests in observed.items():
        for quest in quests:
            put(item, quest, 'O')
    for item, quest in starts.items():
        put(item, quest, 'S')

    def quest_class(item):
        c = classes.get(item)
        if c is None:
            c = att_classes.get(item)
        return c is None or c == QUEST_CLASS
    return {i: q for i, q in out.items() if quest_class(i)}


def record(links):
    """"S123,D456,O789": the quests of one item, by quest id."""
    return ','.join(f'{k}{q}' for q, k in sorted(links.items())[:MAX_QUESTS])


def counts(data):
    by = {k: 0 for k in KINDS}
    for links in data.values():
        for k in set(links.values()):
            by[k] += 1
    return by


def render(data, built, source):
    lines = [
        '-- GENERATED by tools/build_questitems.py. Do not edit; rebuild instead.',
        f'-- Sources: {source}.',
        'local _, ns = ...',
        '',
        '-- I: [item id] = "<kind><quest id>,...": the quests a quest item (item class 12) belongs to, by quest id;',
        '-- kind S the item starts the quest (client table ItemSparse), O seen by Amisia at the turn-in or in the',
        '-- quest log on the author\'s account, D AllTheThings (provider, handed out, objective). The addon reads',
        '-- done, in the log, repeatable, faction and class from the client and QuestData.lua.',
        'ns.QUEST_ITEMS = {',
        f'    built = "{built}", count = {len(data)},',
        '    I = {',
    ]
    for item in sorted(data):
        lines.append(f'        [{item}] = "{record(data[item])}",')
    lines += ['    },', '}', '']
    return lua_data.lazy('\n'.join(lines), 'QUEST_ITEMS', len(data))


def default_svs():
    import build_gear
    return [p for p in build_gear.default_svs() if os.path.basename(p) == 'Amisia.lua']


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--att', default=None, help='AllTheThings download (default the cache)')
    ap.add_argument('--wago', default=None, help='client tables (default: the newest copy of each table, tools/client_tables.py)')
    ap.add_argument('--sv', nargs='*', help='Amisia SavedVariables with own item links')
    ap.add_argument('--archive', default=ARCHIVE, help='the archive of own item links ("" for none)')
    ap.add_argument('--empty', action='store_true', help='write the file without data')
    ap.add_argument('--out', default=OUT)
    args = ap.parse_args(argv)
    data, source = {}, 'none yet'
    if not args.empty:
        if args.wago is None:
            import client_tables
            args.wago = client_tables.default_dir()
        classes, starts = read_client(args.wago)
        base = args.att or att_data.ATT_CACHE
        att_quests, att_classes, commit = {}, {}, None
        if os.path.isdir(os.path.join(base, 'zones')):
            db = att_data.load(base, items=True)
            att_quests = {q: r.get('items') or [] for q, r in db['quests'].items()}
            att_classes = {i: it['classID'] for i, it in db['items'].items()}
            commit = db.get('commit')
        else:
            log(f'no AllTheThings download in {base}: links from the client tables and own observations only')
        import build_scan
        svs = args.sv if args.sv is not None else default_svs()
        observed = update_archive([build_scan.load_sv(p) for p in svs], args.archive or None)
        data = build(att_quests, starts, observed, classes, att_classes)
        parts = []
        if starts:
            parts.append('the WoW Forever client tables (ItemSparse, Item)')
        if att_quests:
            parts.append(att_data.ATT_SOURCE + (f' at {commit[:10]}' if commit else ''))
        if observed:
            parts.append("Amisia's own observations (tools/quest_item_archive.json)")
        source = '; '.join(parts) or 'none yet'
        log(f'client tables: {len(classes)} item classes, {len(starts)} start items; '
            f'AllTheThings: {sum(1 for v in att_quests.values() if v)} quests with items; own: {len(observed)} items')
    text = render(data, time.strftime('%Y-%m-%d'), source)
    old = None
    if os.path.exists(args.out):
        with open(args.out, encoding='utf-8') as fh:
            old = fh.read()
    if old is not None and re.sub(r'built="[^"]*"', '', old) == re.sub(r'built="[^"]*"', '', text):
        log(f'{os.path.relpath(args.out, ROOT)} is current')
    else:
        with open(args.out, 'w', encoding='utf-8', newline='\n') as fh:
            fh.write(text)
        log(f'wrote {os.path.relpath(args.out, ROOT)}')
    by = counts(data)
    log(f'  {len(data)} quest items linked: S {by["S"]}, O {by["O"]}, D {by["D"]} (items with that kind); '
        f'{sum(1 for v in data.values() if len(v) > 1)} with more than one quest; size {len(text.encode("utf-8")) / 1024:.0f} KB')


if __name__ == '__main__':
    main()
