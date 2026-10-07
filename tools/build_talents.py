"""The talent trees of WoW Forever for Amisia's talent calculator, from the client's own tables.

    python tools/build_talents.py [--wago DIR ...] [--out FILE]

Forever (1.60.1, codename Camelot) keeps its talents in the trait system (C_Traits), not in the old
Talent/TalentTab tables (those still hold Classic's talents and are not read): one TraitTree per
class (SkillLineXTraitTree names its skill line, SkillRaceClassInfo the class), split into three
node groups that are the three classic trees (TraitNodeGroupDisplayInfo: group, skill line = name
of the tree, order). Per node: TraitNode (PosX/PosY on a 600 grid), TraitNodeXTraitNodeEntry ->
TraitNodeEntry (MaxRanks) -> TraitDefinition (SpellID, override name/description/icon); the value
of each rank from TraitDefinitionEffectPoints and CurvePoint (rank -> value). Prerequisites from
TraitEdge (type 2 "sufficient": one full source is enough, type 3 "required": every source must be
full; type 0 is only drawn by the client and not read). Row locks from TraitNodeGroupXTraitCond and
TraitNodeXTraitCond -> TraitCond ("Available": SpentAmountRequired points of the tree's currency
spent in the counting group TraitNodeGroupID, which holds the nodes of the rows above). Points:
the currency of the tree (TraitTreeXTraitCurrency -> TraitCurrency.SourcedMax) and its sources
(TraitCurrencySource: one per level; the sources tied to a node entry are the ranks of the legacy
perk "Talented", which give the points earlier, never more than SourcedMax).

The descriptions are the spells' (Spell, enUS) with their placeholders resolved from SpellEffect,
SpellMisc/SpellDuration, SpellRadius and SpellAuraOptions (resolve_text). What changes with the
rank is written as {1}, {2}, ... with the values per rank beside it. The addon shows the client's
own (German) text where it gets one (C_Traits.GetTraitDescription) and this one otherwise.

Reads <Table>.csv or <Table>.<build>.csv (tools/export_db2.ps1 on the PC, or wago.tools) from the
folders given with --wago (default ~/addons/_wago); the first folder with a table wins.
Writes addon/Amisia/Data/TalentData.lua (ns.TALENTS).
"""
import argparse
import collections
import csv
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from att_data import wago_csv  # noqa: E402
import lua_data  # noqa: E402  (the lazy form of the data file)

OUT = os.path.join(ROOT, 'addon', 'Amisia', 'Data', 'TalentData.lua')
WAGO = os.path.expanduser('~/addons/_wago')

REQUIRED = [
    'TraitNode', 'TraitNodeEntry', 'TraitNodeXTraitNodeEntry', 'TraitDefinition', 'TraitDefinitionEffectPoints',
    'CurvePoint', 'TraitEdge', 'TraitNodeGroup', 'TraitNodeGroupXTraitNode', 'TraitNodeGroupXTraitCond', 'TraitCond',
    'TraitNodeGroupDisplayInfo', 'TraitCurrency', 'TraitCurrencySource', 'TraitTreeXTraitCurrency',
    'SkillLineXTraitTree', 'SkillLine', 'SkillRaceClassInfo', 'ChrClasses',
    'Spell', 'SpellName', 'SpellMisc', 'SpellEffect',
]
# read when present: without them a spec id, a few node locks and some placeholders stay empty
OPTIONAL = ['TraitNodeXTraitCond', 'ChrSpecialization', 'SpellDuration', 'SpellRadius', 'SpellAuraOptions']
TABLES = REQUIRED + OPTIONAL

GRID = 600            # the client's distance between two rows or columns
MAX_ROWS, MAX_COLS = 10, 4
AVAILABLE = 0         # TraitCond.CondType "Available"
EDGE_SUFFICIENT, EDGE_REQUIRED = 2, 3
UNKNOWN = '?'


# ---------------------------------------------------------------- reading
def find_table(dirs, table):
    for d in dirs:
        path = wago_csv(d, table)
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
    path = find_table(dirs, 'TraitNode')
    m = re.search(r'\.(\d+(?:\.\d+)+)\.csv$', path or '')
    return m.group(1) if m else ''


def num(v, default=0):
    try:
        f = float(v)
    except (TypeError, ValueError):
        return default
    return int(f) if f == int(f) else f


def load(dirs):
    missing = [t for t in REQUIRED if not find_table(dirs, t)]
    if missing:
        raise SystemExit('build_talents: client tables missing in %s: %s (export them with '
                         'tools/export_db2.ps1 -Tables %s)' % (', '.join(dirs), ', '.join(missing), ','.join(missing)))
    return {t: read_table(dirs, t) or [] for t in TABLES}


# ---------------------------------------------------------------- spell data for the descriptions
class Spells:
    """Spell names, descriptions, icons, effects, durations, radii and aura options (difficulty 0
    rows first)."""

    def __init__(self, t):
        self.name = {num(r['ID']): r['Name_lang'] for r in t['SpellName']}
        self.desc = {num(r['ID']): r.get('Description_lang', '') for r in t['Spell']}
        self.misc = {}
        for r in t['SpellMisc']:
            sid = num(r['SpellID'])
            if sid not in self.misc or num(r.get('DifficultyID')) == 0:
                self.misc[sid] = r
        self.effect = {}
        for r in t['SpellEffect']:
            key = (num(r['SpellID']), num(r['EffectIndex']))
            if key not in self.effect or num(r.get('DifficultyID')) == 0:
                self.effect[key] = r
        self.duration = {num(r['ID']): num(r['Duration']) for r in t['SpellDuration']}
        self.radius = {num(r['ID']): num(r['Radius']) for r in t['SpellRadius']}
        self.aura = {}
        for r in t['SpellAuraOptions']:
            sid = num(r['SpellID'])
            if sid not in self.aura or num(r.get('DifficultyID')) == 0:
                self.aura[sid] = r

    def icon(self, sid):
        m = self.misc.get(sid)
        return num(m['SpellIconFileDataID']) if m else 0

    def points(self, sid, index):
        e = self.effect.get((sid, index - 1))
        return None if e is None else num(e.get('EffectBasePointsF'))

    def period(self, sid, index):
        e = self.effect.get((sid, index - 1))
        return None if e is None or not num(e.get('EffectAuraPeriod')) else num(e['EffectAuraPeriod'])

    def radius_of(self, sid, index):
        e = self.effect.get((sid, index - 1))
        r = e and (self.radius.get(num(e.get('EffectRadiusIndex_0'))) or self.radius.get(num(e.get('EffectRadiusIndex_1'))))
        return r or None

    def duration_ms(self, sid):
        m = self.misc.get(sid)
        d = m and self.duration.get(num(m.get('DurationIndex')))
        return d if d and d > 0 else None

    def aura_field(self, sid, field):
        a = self.aura.get(sid)
        v = a and num(a.get(field))
        return v or None


# ---------------------------------------------------------------- placeholders
def fmt(v, decimals=None):
    if decimals is not None:
        return ('%.' + str(decimals) + 'f') % v
    if abs(v - round(v)) < 1e-9:
        return str(int(round(v)))
    return ('%.2f' % v).rstrip('0').rstrip('.')


def fmt_duration(ms):
    if ms >= 60000 and ms % 60000 == 0:
        return '%s min' % fmt(ms / 60000)
    return '%s sec' % fmt(ms / 1000)


class Ctx:
    """What a description is resolved for: the node's spell, its rank curves (effect index ->
    [value per rank]) and the number of ranks."""

    def __init__(self, spell, curves, ranks):
        self.spell, self.curves, self.ranks = spell, curves or {}, max(1, ranks)


def _value(spells, ctx, sid, letter, index):
    """The raw values per rank of one value token, or None. sid None: the node's own spell, whose
    s/m values follow the rank curves. letter in s m o t a d u n h."""
    n = ctx.ranks if ctx is not None else 1
    own = sid is None or (ctx is not None and sid == ctx.spell)
    if sid is None:
        if ctx is None:
            return None
        sid = ctx.spell
    if letter in 'sm':
        curve = ctx.curves.get(index) if own and ctx is not None else None
        if curve:
            return list(curve)
        bp = spells.points(sid, index)
        return None if bp is None else [bp] * n
    if letter == 'o':
        base = _value(spells, ctx, None if own else sid, 's', index)
        period, dur = spells.period(sid, index), spells.duration_ms(sid)
        if base is None or not period or not dur:
            return None
        return [b * dur / period for b in base]
    single = None
    if letter == 't':
        p = spells.period(sid, index)
        single = None if p is None else p / 1000
    elif letter == 'a':
        single = spells.radius_of(sid, index)
    elif letter == 'd':
        single = spells.duration_ms(sid)
    elif letter == 'u':
        single = spells.aura_field(sid, 'CumulativeAura')
    elif letter == 'n':
        single = spells.aura_field(sid, 'ProcCharges')
    elif letter == 'h':
        single = spells.aura_field(sid, 'ProcChance')
    return None if single is None else [single] * n


_VALUE = re.compile(r'(\d*)([smoatdunhSMOATDUNH])(\d?)')
_INDEXED = set('smoat')


def _bracket(text, i):
    """Index after the bracket group that starts at text[i] == '[' (nesting counted)."""
    depth = 0
    for j in range(i, len(text)):
        if text[j] == '[':
            depth += 1
        elif text[j] == ']':
            depth -= 1
            if depth == 0:
                return j + 1
    return len(text)


def _closing_brace(text, i):
    depth = 0
    for j in range(i, len(text)):
        if text[j] == '{':
            depth += 1
        elif text[j] == '}':
            depth -= 1
            if depth == 0:
                return j
    return -1


def _conditional(text, i):
    """$?cond[a]?cond[b][c] starting at text[i] == '?': (the else part or '', index after it).
    Without the player's state (auras, known spells) the last part is the one taken."""
    j, n = i, len(text)
    while j < n and text[j] == '?':
        k = text.find('[', j)
        if k < 0:
            return None, n
        j = _bracket(text, k)
        if j < n and text[j] == '[':
            e = _bracket(text, j)
            return text[j + 1:e - 1], e
        if j < n and text[j] == '?':
            continue
        return '', j
    return None, j


def _eval(expr):
    if not re.fullmatch(r'[0-9.+\-*/() e]+', expr or ''):
        return None
    try:
        v = eval(expr, {'__builtins__': {}}, {})  # noqa: S307 - digits and operators only
    except Exception:
        return None
    return float(v) if isinstance(v, (int, float)) and math.isfinite(v) else None


class _NoSpells:
    name, desc = {}, {}

    def __getattr__(self, _):
        return lambda *a, **k: None


def _token(m, ctx, spells):
    sid = int(m.group(1)) if m.group(1) else None
    letter = m.group(2).lower()
    index = int(m.group(3)) if m.group(3) else 1
    if letter not in _INDEXED and m.group(3):
        return None
    return _value(spells, ctx, sid, letter, index)


def _expression(inner, ctx, spells):
    """${...}: the tokens become raw numbers (signed; durations in seconds) per rank, then the
    arithmetic is evaluated per rank. None when anything is not plain arithmetic."""
    n = ctx.ranks if ctx is not None else 1
    parts = [[] for _ in range(n)]
    i = 0
    while i < len(inner):
        ch = inner[i]
        if ch != '$':
            for p in parts:
                p.append(ch)
            i += 1
            continue
        m = _VALUE.match(inner[i + 1:])
        if not m:
            return None
        vals = _token(m, ctx, spells)
        if vals is None:
            return None
        if m.group(2).lower() == 'd':
            vals = [v / 1000 for v in vals]
        for r in range(n):
            parts[r].append('(%r)' % float(vals[r] if r < len(vals) else vals[0]))
        i += 1 + m.end()
    out = []
    for p in parts:
        v = _eval(''.join(p))
        if v is None:
            return None
        out.append(v)
    return out


def resolve_text(text, ctx, spells, depth=1):
    """Resolves the placeholders of a description. Returns (text, values, unknown): text with {k}
    where a value changes with the rank, values[k-1] the shown values per rank, unknown the number
    of placeholders that stayed '?'. spells is a Spells (anything else: none known)."""
    if not isinstance(spells, Spells):
        spells = _NoSpells()
    values, state = [], {'unknown': 0, 'last': None}
    text = _resolve(text, ctx, spells, depth, values, state)
    return text.replace('|R', '|r').replace('|C', '|c'), values, state['unknown']


def _resolve(text, ctx, spells, depth, values, state):
    out = []

    def unknown():
        state['unknown'] += 1
        out.append(UNKNOWN)

    def emit(vals, decimals=None, is_duration=False):
        if vals is None:
            unknown()
            return
        shown = [fmt_duration(v) if is_duration else fmt(abs(v), decimals) for v in vals]
        if len(set(shown)) == 1:
            out.append(shown[0])
            state['last'] = abs(vals[0])
        else:
            values.append(shown)
            out.append('{%d}' % len(values))
            state['last'] = None

    i, n = 0, len(text)
    while i < n:
        ch = text[i]
        if ch != '$':
            out.append(ch)
            i += 1
            continue
        i += 1
        rest = text[i:]
        if rest.startswith('{'):
            end = _closing_brace(text, i)
            if end < 0:
                unknown()
                break
            inner, i = text[i + 1:end], end + 1
            m = re.match(r'\.(\d)', text[i:])
            decimals = None
            if m:
                decimals, i = int(m.group(1)), i + 2
            emit(_expression(inner, ctx, spells), decimals)
            continue
        if rest.startswith('?'):
            part, i = _conditional(text, i)
            if part is None:
                unknown()
            else:
                out.append(_resolve(part, ctx, spells, depth, values, state))
            continue
        m = re.match(r'@(spelldesc|spelltooltip|spellname)(\d+)', rest)
        if m:
            i += m.end()
            sid = int(m.group(2))
            if m.group(1) == 'spellname' and sid in spells.name:
                out.append(spells.name[sid])
            elif m.group(1) != 'spellname' and depth > 0 and sid in spells.desc:
                sub = {'unknown': 0, 'last': None}
                out.append(_resolve(spells.desc[sid], Ctx(sid, {}, 1), spells, depth - 1, [], sub))
                state['unknown'] += sub['unknown']
            else:
                unknown()
            continue
        m = re.match(r'<\w+>', rest)
        if m:
            i += m.end()
            unknown()
            continue
        m = re.match(r'([/*])(\d+(?:\.\d+)?);', rest)
        if m:
            op, k = m.group(1), float(m.group(2))
            i += m.end()
            vm = _VALUE.match(text[i:])
            if not vm:
                unknown()
                continue
            i += vm.end()
            vals = _token(vm, ctx, spells)
            if vals is not None:
                vals = [v / k if op == '/' else v * k for v in vals]
            emit(vals)
            continue
        m = re.match(r'([lL])([^:;$]*):([^;$]*);', rest)
        if m:
            i += m.end()
            out.append(m.group(2) if state['last'] == 1 else m.group(3))
            continue
        m = _VALUE.match(rest)
        if m and not re.match(r'[a-zA-Z]', rest[m.end():m.end() + 1]):
            i += m.end()
            emit(_token(m, ctx, spells), is_duration=(m.group(2).lower() == 'd'))
            continue
        m = re.match(r'[a-zA-Z]+\d*', rest)
        if m:
            i += m.end()
        unknown()
    return ''.join(out)


# ---------------------------------------------------------------- the trees
def curve_values(points, ranks):
    """The value of each rank 1..ranks from a curve's points (rank -> value), linear in between,
    held beyond the ends."""
    pts = sorted(points)
    out = []
    for r in range(1, ranks + 1):
        if not pts:
            out.append(0)
            continue
        if r <= pts[0][0]:
            out.append(pts[0][1])
            continue
        if r >= pts[-1][0]:
            out.append(pts[-1][1])
            continue
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            if x0 <= r <= x1:
                out.append(y0 + (y1 - y0) * (r - x0) / (x1 - x0) if x1 != x0 else y1)
                break
    return out


def build(dirs, log=None):
    log = log or (lambda *a: None)
    t = load(dirs)
    spells = Spells(t)
    classes_by_id = {num(r['ID']): r['Filename'] for r in t['ChrClasses']}
    class_of_skill = {}
    for r in t['SkillRaceClassInfo']:
        mask = num(r['ClassMask'])
        if mask > 0 and mask & (mask - 1) == 0:
            class_of_skill.setdefault(num(r['SkillID']), mask.bit_length())
    spec_of_class = {}
    for r in sorted(t['ChrSpecialization'], key=lambda r: (num(r['OrderIndex']), num(r['ID']))):
        spec_of_class.setdefault(num(r['ClassID']), num(r['ID']))
    skill = {num(r['ID']): r for r in t['SkillLine']}

    nodes_of_tree = collections.defaultdict(list)
    for r in t['TraitNode']:
        nodes_of_tree[num(r['TraitTreeID'])].append(r)
    entry_of_node = {}
    for r in sorted(t['TraitNodeXTraitNodeEntry'], key=lambda r: (num(r['_Index']), num(r['ID']))):
        entry_of_node.setdefault(num(r['TraitNodeID']), num(r['TraitNodeEntryID']))
    entries = {num(r['ID']): r for r in t['TraitNodeEntry']}
    defs = {num(r['ID']): r for r in t['TraitDefinition']}
    curve_points = collections.defaultdict(list)
    for r in t['CurvePoint']:
        curve_points[num(r['CurveID'])].append((float(r['Pos_0']), num(r['Pos_1'])))
    effect_points = collections.defaultdict(list)
    for r in t['TraitDefinitionEffectPoints']:
        effect_points[num(r['TraitDefinitionID'])].append(r)
    group_nodes = collections.defaultdict(set)
    for r in t['TraitNodeGroupXTraitNode']:
        group_nodes[num(r['TraitNodeGroupID'])].add(num(r['TraitNodeID']))
    groups_of_node = collections.defaultdict(set)
    for g, ns in group_nodes.items():
        for n in ns:
            groups_of_node[n].add(g)
    conds = {num(r['ID']): r for r in t['TraitCond']}
    group_conds = collections.defaultdict(list)
    for r in t['TraitNodeGroupXTraitCond']:
        group_conds[num(r['TraitNodeGroupID'])].append(num(r['TraitCondID']))
    node_conds = collections.defaultdict(list)
    for r in t['TraitNodeXTraitCond']:
        node_conds[num(r['TraitNodeID'])].append(num(r['TraitCondID']))
    incoming = collections.defaultdict(list)
    for r in t['TraitEdge']:
        kind = num(r['Type'])
        if kind in (EDGE_SUFFICIENT, EDGE_REQUIRED):
            incoming[num(r['RightTraitNodeID'])].append((num(r['LeftTraitNodeID']), kind))
    display = collections.defaultdict(list)
    for r in t['TraitNodeGroupDisplayInfo']:
        display[num(r['TraitTreeID'])].append(r)
    currency_of_tree = {num(r['TraitTreeID']): num(r['TraitCurrencyID']) for r in t['TraitTreeXTraitCurrency']}
    currencies = {num(r['ID']): r for r in t['TraitCurrency']}

    out = {'build': build_of(dirs), 'classes': {}, 'max': 0, 'levels': [], 'talented': [], 'unknown': 0}
    currency = None
    for r in sorted(t['SkillLineXTraitTree'], key=lambda r: num(r['TraitTreeID'])):
        tree, sk = num(r['TraitTreeID']), num(r['SkillLineID'])
        cid = class_of_skill.get(sk)
        cls = classes_by_id.get(cid)
        groups = sorted(display.get(tree, []), key=lambda d: num(d['OrderIndex']))
        if not cls or len(groups) != 3:
            log('tree %d: no class or not three trees, skipped' % tree)
            continue
        if cls in out['classes']:
            log('tree %d: second tree for %s, skipped' % (tree, cls))
            continue
        currency = currency or currency_of_tree.get(tree)
        tree_index = {}
        trees = []
        for i, d in enumerate(groups, 1):
            g = num(d['TraitNodeGroupID'])
            s = skill.get(num(d['SkillLineID']), {})
            trees.append({'group': g, 'name': s.get('DisplayName_lang', ''), 'icon': num(s.get('SpellIconFileID'))})
            for n in group_nodes[g]:
                tree_index[n] = i
        raw = [x for x in nodes_of_tree[tree] if num(x['ID']) in tree_index and num(x['ID']) in entry_of_node]
        if not raw:
            continue
        ymin = min(num(x['PosY']) for x in raw)
        xmin = {}
        for x in raw:
            ti = tree_index[num(x['ID'])]
            xmin[ti] = min(xmin.get(ti, 10 ** 9), num(x['PosX']))
        kept, cells = [], {}
        for x in sorted(raw, key=lambda x: num(x['ID'])):
            nid = num(x['ID'])
            ti = tree_index[nid]
            row = int(round((num(x['PosY']) - ymin) / GRID))
            col = int(round((num(x['PosX']) - xmin[ti]) / GRID))
            if not (0 <= row < MAX_ROWS and 0 <= col < MAX_COLS):
                log('%s: node %d at %s/%s lies off the grid (an old, replaced node), left out'
                    % (cls, nid, x['PosX'], x['PosY']))
                continue
            if (ti, row, col) in cells:
                log('%s: node %d shares a cell with node %d, left out' % (cls, nid, cells[(ti, row, col)]))
                continue
            cells[(ti, row, col)] = nid
            kept.append((nid, ti, row, col))
        kept_ids = {k[0] for k in kept}
        gates_used = {}
        nodes = []
        for nid, ti, row, col in kept:
            entry = entries[entry_of_node[nid]]
            d = defs.get(num(entry['TraitDefinitionID']), {})
            sid = num(d.get('SpellID'))
            ranks = max(1, num(entry['MaxRanks']))
            curves = {}
            for p in effect_points.get(num(d.get('ID')), []):
                vals = curve_values(curve_points.get(num(p['CurveID']), []), ranks)
                if num(p['OperationType']) == 1:
                    bp = spells.points(sid, num(p['EffectIndex']) + 1) or 0
                    vals = [bp * v for v in vals]
                curves[num(p['EffectIndex']) + 1] = vals
            raw_desc = d.get('OverrideDescription_lang') or spells.desc.get(sid, '')
            desc, values, unknown = resolve_text(raw_desc, Ctx(sid, curves, ranks), spells)
            out['unknown'] += unknown
            gates = set()
            for c in [c for g in groups_of_node[nid] for c in group_conds.get(g, [])] + node_conds.get(nid, []):
                cond = conds.get(c)
                if not cond or num(cond['CondType']) != AVAILABLE or num(cond['SpentAmountRequired']) <= 0:
                    continue
                counting = num(cond['TraitNodeGroupID'])
                if not counting:
                    log('%s: node %d has a lock without a counting group, ignored' % (cls, nid))
                    continue
                gates.add((counting, num(cond['SpentAmountRequired'])))
                gates_used[counting] = sorted(group_nodes[counting] & kept_ids)
            pre = []
            for src, kind in sorted(incoming.get(nid, [])):
                if src in kept_ids:
                    pre.append(src if kind == EDGE_SUFFICIENT else -src)
            nodes.append({
                'node': nid, 'entry': num(entry['ID']), 'spell': sid,
                'icon': num(d.get('OverrideIcon')) or spells.icon(sid),
                'tree': ti, 'row': row, 'col': col, 'max': ranks,
                'gates': sorted(gates, key=lambda g: (g[1], g[0])), 'pre': pre,
                'name': d.get('OverrideName_lang') or spells.name.get(sid, ''),
                'desc': desc, 'values': values,
            })
        nodes.sort(key=lambda n: (n['tree'], n['row'], n['col']))
        out['classes'][cls] = {'id': cid, 'tree': tree, 'spec': spec_of_class.get(cid, 0), 'trees': trees,
                               'gates': gates_used, 'nodes': nodes}
    cur = currencies.get(currency, {})
    out['max'] = num(cur.get('SourcedMax'))
    levels, talented = [], []
    for r in t['TraitCurrencySource']:
        if num(r['TraitCurrencyID']) != currency or num(r['PlayerLevel']) <= 0:
            continue
        lvl, amount = num(r['PlayerLevel']), max(1, num(r['Amount']))
        (talented if num(r['TraitNodeEntryID']) else levels).extend([lvl] * amount)
    out['levels'] = sorted(levels)
    out['talented'] = sorted(talented, reverse=True)
    return out


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


def lua_list(items):
    return '{ ' + ', '.join(items) + ' }' if items else '{}'


def render_lua(data):
    L = [
        '-- Generated by tools/build_talents.py from the WoW Forever client tables (build %s). Do not edit;' % (data['build'] or '?'),
        '-- rebuild instead. Text is the client\'s enUS; the addon prefers the client\'s own text at runtime.',
        '-- classes[CLASS] = { id, tree = TraitTree, spec = ChrSpecialization, trees = { { group, name, icon } x3 },',
        '--   gates = { [counting group] = { node ids } }, nodes = { { node, entry, spell, icon, tree, row, col,',
        '--   max ranks, gates = { group, points, ... } or 0, pre = { node (sufficient) or -node (required) } or 0,',
        '--   name, text with {k}, values = { { per rank } } } } }',
        '-- levels: the levels that give a point; talented: the level each rank of the Talented perk gives one.',
        'local _, ns = ...',
        '',
        'ns.TALENTS = {',
        '    build = %s, max = %d,' % (lua_str(data['build']), data['max']),
        '    levels = %s,' % lua_list([str(x) for x in data['levels']]),
        '    talented = %s,' % lua_list([str(x) for x in data['talented']]),
        '    classes = {',
    ]
    for cls, c in sorted(data['classes'].items(), key=lambda kv: kv[1]['id']):
        L.append('        %s = { id = %d, tree = %d, spec = %d,' % (cls, c['id'], c['tree'], c['spec']))
        L.append('            trees = %s,' % lua_list(
            ['{ %d, %s, %d }' % (t['group'], lua_str(t['name']), t['icon']) for t in c['trees']]))
        L.append('            gates = {')
        for g in sorted(c['gates']):
            L.append('                [%d] = %s,' % (g, lua_list([str(n) for n in c['gates'][g]])))
        L.append('            },')
        L.append('            nodes = {')
        for n in c['nodes']:
            gates = lua_list(['%d, %d' % g for g in n['gates']]) if n['gates'] else '0'
            pre = lua_list([str(p) for p in n['pre']]) if n['pre'] else '0'
            parts = [str(n[k]) for k in ('node', 'entry', 'spell', 'icon', 'tree', 'row', 'col', 'max')]
            parts += [gates, pre, lua_str(n['name']), lua_str(n['desc'])]
            if n['values']:
                parts.append(lua_list([lua_list([lua_str(v) for v in vals]) for vals in n['values']]))
            L.append('                { %s },' % ', '.join(parts))
        L.append('            },')
        L.append('        },')
    L += ['    },', '}', '']
    # the addon builds the table on first use (Core/LazyData.lua)
    return lua_data.lazy('\n'.join(L), 'TALENTS', len(data['classes']))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--wago', action='append', default=None,
                    help='folder of the client table CSVs (repeatable; default ~/addons/_wago)')
    ap.add_argument('--out', default=OUT, help='output Lua file (default addon/Amisia/Data/TalentData.lua)')
    args = ap.parse_args(argv)
    dirs = args.wago or [WAGO]
    data = build(dirs, log=lambda m: print('  ' + m))
    with open(args.out, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(render_lua(data))
    nodes = sum(len(c['nodes']) for c in data['classes'].values())
    print('TalentData.lua: build %s, %d classes, %d talents, %d points (levels %s-%s, Talented from %s), '
          '%d placeholders unresolved' % (data['build'], len(data['classes']), nodes, data['max'],
                                          data['levels'][0] if data['levels'] else '?',
                                          data['levels'][-1] if data['levels'] else '?',
                                          data['talented'][-1] if data['talented'] else '-', data['unknown']))


if __name__ == '__main__':
    main()
