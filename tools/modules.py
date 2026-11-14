"""Amisia's modules (F-202, D-130): which addon file belongs to the core and which to a module, and a
static check that the core never needs a module and the modules need each other only behind a check.

    python3 tools/modules.py            every forbidden reference, one line each (exit code 1 if any)
    python3 tools/modules.py files      the files of each module in TOC order
    python3 tools/modules.py symbols    the ns symbols each module defines

Three parts: "core" (the addon Amisia), "raid" (Amisia_Raid) and "gear" (Amisia_Gear, Ausrüstung &
Dungeons). A module may use the core freely; the core may use no module; raid and gear may use each
other only guarded. The rules of the check are in check() below; tools/tests/test_module_deps.py runs it.
"""
import functools
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON = os.path.join(ROOT, 'Amisia')
MODULES = ('core', 'raid', 'gear')
# the order in which the bodies run once the parts are addons of their own (core, then raid, then gear)
ORDER = {'core': 0, 'raid': 1, 'gear': 2}
# the addon folder of each part (step 2 of F-202 moves the files there)
FOLDERS = {'core': 'Amisia', 'raid': 'Amisia_Raid', 'gear': 'Amisia_Gear'}

# Raid files: the raid pages and windows outside Raid/ (Raid/* is raid but for the ones in CORE_FILES).
RAID_FILES = {
    'UI/Pages/Raids.lua', 'UI/Pages/Lineup.lua', 'UI/Pages/RaidCheck.lua', 'UI/Pages/RaidLogRolls.lua',
    'UI/Pages/RaidLog.lua', 'UI/Pages/Rolls.lua', 'UI/Pages/RaidNote.lua', 'UI/Pages/Awards.lua',
    'UI/Pages/Stats.lua', 'UI/Pages/Points.lua', 'UI/Pages/SoftRes.lua', 'UI/Pages/Bank.lua',
    'UI/Pages/Members.lua', 'UI/Pages/Calendar.lua', 'UI/SoftResImport.lua', 'UI/Signup.lua',
    'UI/RaidCalendar.lua',
    # the setup assistant sets the raid's loot, roll and point settings only
    'UI/Setup.lua',
    # Forever-only raid features: they keep their camelot mark, but belong to the raid module
    'Raid/Handover.lua', 'UI/Pages/Export.lua',
    # the self-tests of the raid parts only (calendar, lineup and raid check readers)
    'Core/SelfTestCalendar.lua', 'Core/SelfTestCalendarWrite.lua', 'Core/SelfTestGroup.lua',
    'Locales/enUS_raid.lua', 'Locales/enUS_raid2.lua', 'Locales/enUS_raidcheck.lua',
}
# Core files under Raid/ (the alts are the core's, spec F-202).
CORE_FILES = {'Raid/Alts.lua'}
# Gear files without the camelot mark.
GEAR_FILES = {'Locales/enUS_gear.lua', 'Locales/enUS_world.lua'}


def toc_entries(toc='Amisia.toc'):
    """(path with /, camelot mark) of every file line of a TOC, in order."""
    out = []
    with open(os.path.join(ADDON, toc), encoding='utf-8') as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            name = line.split(' [')[0].replace('\\', '/')
            out.append((name, 'AllowLoadGameType camelot' in line))
    return out


@functools.lru_cache(maxsize=None)
def _camelot():
    return dict(toc_entries())


def module_of(path, camelot=None):
    """The part a file belongs to: "core", "raid" or "gear" (path relative to Amisia/, with /)."""
    if camelot is None:
        camelot = _camelot().get(path, False)
    if path in CORE_FILES:
        return 'core'
    if path in RAID_FILES:
        return 'raid'
    if camelot or path in GEAR_FILES:
        return 'gear'
    if path.startswith('Raid/'):
        return 'raid'
    return 'core'


def files_by_module():
    """{module: [paths in TOC order]} of the .lua files of Amisia.toc."""
    out = {m: [] for m in MODULES}
    for name, camelot in toc_entries():
        if name.endswith('.lua'):
            out[module_of(name, camelot)].append(name)
    return out


def may_use(user, owner):
    """Whether a file of part user may use a symbol of part owner without a guard."""
    return owner == user or owner == 'core'


# ---------------------------------------------------------------------------
# Lua tokens
# ---------------------------------------------------------------------------
KEYWORDS = set('and break do else elseif end false for function if in local nil not or repeat return then '
               'true until while'.split())
TOKEN = re.compile(r'''
    (?P<ws>[ \t\r]+)
  | (?P<nl>\n)
  | (?P<lcomment>--\[(?P<ceq>=*)\[)
  | (?P<comment>--[^\n]*)
  | (?P<lstr>\[(?P<seq>=*)\[)
  | (?P<str>"(?:\\.|\\\n|[^"\\\n])*"|'(?:\\.|\\\n|[^'\\\n])*')
  | (?P<num>0[xX][0-9a-fA-F]+|\d+\.?\d*(?:[eE][+-]?\d+)?|\.\d+(?:[eE][+-]?\d+)?)
  | (?P<name>[A-Za-z_][A-Za-z0-9_]*)
  | (?P<op>\.\.\.|\.\.|==|~=|<=|>=|[-+*/%^#<>=(){}\[\];:,.])
''', re.X)


class Tok:
    __slots__ = ('kind', 'value', 'line', 'bol')

    def __init__(self, kind, value, line, bol):
        self.kind, self.value, self.line, self.bol = kind, value, line, bol

    def __repr__(self):
        return '%s:%r@%d' % (self.kind, self.value, self.line)


def tokenize(src):
    """The tokens of a Lua source without comments: kind (name, kw, op, str, num), value, line and
    whether it is the first token of its line."""
    out = []
    i, n, line, bol = 0, len(src), 1, True
    while i < n:
        m = TOKEN.match(src, i)
        if not m:
            raise ValueError('cannot read Lua at line %d: %r' % (line, src[i:i + 20]))
        kind = m.lastgroup
        if kind in ('ceq', 'seq'):
            kind = 'lcomment' if m.group('lcomment') else 'lstr'
        text = m.group(0)
        if kind in ('lcomment', 'lstr'):
            close = ']' + (m.group('ceq') if kind == 'lcomment' else m.group('seq')) + ']'
            e = src.find(close, m.end())
            e = n if e < 0 else e + len(close)
            text = src[i:e]
            if kind == 'lstr':
                out.append(Tok('str', text, line, bol))
                bol = False
            line += text.count('\n')
            i = e
            continue
        i = m.end()
        if kind == 'nl':
            line, bol = line + 1, True
            continue
        if kind in ('ws', 'comment'):
            continue
        if kind == 'name' and text in KEYWORDS:
            kind = 'kw'
        out.append(Tok(kind, text, line, bol))
        line += text.count('\n')
        bol = False
    return out


def _is(t, kind, value=None):
    return t is not None and t.kind == kind and (value is None or t.value == value)


# ---------------------------------------------------------------------------
# Definitions: which part defines ns.X (and ns.X.Y, when another part than X's adds Y)
# ---------------------------------------------------------------------------
def _at(toks, i):
    return toks[i] if 0 <= i < len(toks) else None


def _ns_path(toks, i):
    """At toks[i] == "ns" (not after . or :): (["X"] or ["X", "Y"], index after the path)."""
    parts, j = [], i + 1
    while len(parts) < 2 and _is(_at(toks, j), 'op', '.') and _is(_at(toks, j + 1), 'name'):
        parts.append(toks[j + 1].value)
        j += 2
    return parts, j


def _starts_name(toks, i):
    """Whether toks[i] is a name that is not a field (not after . or :)."""
    prev = _at(toks, i - 1)
    return toks[i].kind == 'name' and not (_is(prev, 'op', '.') or _is(prev, 'op', ':'))


def aliases_of(toks):
    """{local name: ns path tuple} for "local A = ns.X", "local A, B = ns.X, ns.Y.Z" and "A = ns.X"."""
    out = {}
    i = 0
    while i < len(toks):
        t = toks[i]
        j = i
        if _is(t, 'kw', 'local'):
            j = i + 1
        if j > i or (_starts_name(toks, i) and _is(_at(toks, i + 1), 'op', '=')
                     and (i == 0 or toks[i].bol or _is(_at(toks, i - 1), 'op', ';'))):
            names = []
            while _is(_at(toks, j), 'name'):
                names.append(toks[j].value)
                if _is(_at(toks, j + 1), 'op', ','):
                    j += 2
                else:
                    j += 1
                    break
            if names and _is(_at(toks, j), 'op', '='):
                k = j + 1
                for name in names:
                    if _is(_at(toks, k), 'name', 'ns') and _starts_name(toks, k):
                        path, e = _ns_path(toks, k)
                        if path == ['HasModule'] and _is(_at(toks, e), 'op', '(') and _is(_at(toks, e + 1), 'str') \
                                and _is(_at(toks, e + 2), 'op', ')'):
                            path, e = ['mod:' + toks[e + 1].value.strip('"\'')], e + 3
                        nxt = _at(toks, e)
                        # only the reference alone ("local A = ns.X", not "ns.X and ns.X()" or "ns.X(...)")
                        alone = nxt is None or nxt.bol or _is(nxt, 'op', ',') or _is(nxt, 'op', ';') \
                            or (nxt.kind == 'kw' and nxt.value not in ('and', 'or'))
                        if path and alone:
                            out[name] = tuple(path)
                        k = e
                    else:
                        break
                    if _is(_at(toks, k), 'op', ','):
                        k += 1
                    else:
                        break
        i += 1
    return out


def definitions(toks, aliases):
    """The ns paths a file assigns: ("X",) for "ns.X =" / "function ns.X(", ("X", "Y") for "ns.X.Y =",
    "function ns.X.Y(", "function ns.X:Y(" and the same through a local alias of ns.X."""
    out = []
    for i, t in enumerate(toks):
        if not _starts_name(toks, i):
            continue
        # ns.LazyData("NAME", ...) of the generated data (Core/LazyData.lua) makes ns.NAME
        if t.value == 'ns' and _is(_at(toks, i + 1), 'op', '.') and _is(_at(toks, i + 2), 'name', 'LazyData') \
                and _is(_at(toks, i + 3), 'op', '(') and _is(_at(toks, i + 4), 'str'):
            out.append((toks[i + 4].value.strip('"\''),))
        if t.value == 'ns':
            base, j = (), i
        elif t.value in aliases and len(aliases[t.value]) == 1 and not aliases[t.value][0].startswith('mod:'):
            base, j = aliases[t.value], i
        else:
            continue
        parts, k = list(base), j + 1
        while len(parts) < 2 and (_is(_at(toks, k), 'op', '.') or _is(_at(toks, k), 'op', ':')) \
                and _is(_at(toks, k + 1), 'name'):
            parts.append(toks[k + 1].value)
            k += 2
        if len(parts) == len(base):
            continue
        prev = _at(toks, i - 1)
        nxt = _at(toks, k)
        if _is(prev, 'kw', 'function') and _is(nxt, 'op', '('):
            out.append(tuple(parts))
        elif _is(nxt, 'op', '=') or (_is(nxt, 'op', ',') and t.value == 'ns' and len(parts) == 1):
            # "ns.X = ..." or the first of "ns.X, ns.Y = ..."
            out.append(tuple(parts))
        elif _is(prev, 'op', ',') and t.value == 'ns' and len(parts) == 1 and (_is(nxt, 'op', '=') or _is(nxt, 'op', ',')):
            out.append(tuple(parts))
    return out


def read_files():
    """[(path, module, tokens, aliases)] of the .lua files of Amisia.toc in TOC order."""
    out = []
    for name, camelot in toc_entries():
        if not name.endswith('.lua'):
            continue
        with open(os.path.join(ADDON, name), encoding='utf-8') as fh:
            toks = tokenize(fh.read())
        out.append((name, module_of(name, camelot), toks, aliases_of(toks)))
    return out


def owners(files):
    """{ns path tuple: module}: ("X",) belongs to the part of the first file in TOC order that assigns
    ns.X; ("X", "Y") is listed only when a part other than X's adds Y to it."""
    top, sub = {}, {}
    for name, mod, toks, aliases in files:
        for path in definitions(toks, aliases):
            if len(path) == 1:
                top.setdefault(path, mod)
            else:
                sub.setdefault(path, mod)
    out = dict(top)
    for path, mod in sub.items():
        if path[:1] in top and top[path[:1]] != mod:
            out[path] = mod
    return out


# ---------------------------------------------------------------------------
# References and their guards
# ---------------------------------------------------------------------------
USE_AFTER = {'.', ':', '(', '[', '{'}
OPEN, CLOSE = {'(', '[', '{'}, {')', ']', '}'}
# tokens at which an expression (and with it an "X and ..." guard) ends, at the depth it was made
EXPR_END_KW = {'local', 'return', 'if', 'then', 'do', 'end', 'else', 'elseif', 'for', 'while', 'repeat',
               'until', 'or', 'break', 'in'}
EXPR_END_OP = {';', ',', '='}
VALUE_END = {')', ']', '}'}


class Frame:
    __slots__ = ('kind', 'guards', 'neg', 'negacc', 'returns', 'plain')

    def __init__(self, kind, guards=(), neg=None):
        self.kind, self.guards, self.neg = kind, set(guards), neg
        self.negacc = set(neg or ())   # what the conditions so far, all false, make sure of
        self.returns = False   # a "return" stands in the block itself (it then always leaves)
        self.plain = True      # an if without elseif/else


def _ref_at(toks, i, aliases, own):
    """A reference starting at toks[i]: (symbol, index after it) or None. symbol is an ns path tuple
    with an owner (("X", "Y") when Y has its own owner, else ("X",)), or a module guard "mod:raid"
    for ns.HasModule("raid")."""
    t = toks[i]
    if not _starts_name(toks, i):
        return None
    if t.value == 'ns':
        parts, j = _ns_path(toks, i)
        if not parts:
            return None
        if parts == ['HasModule'] and _is(_at(toks, j), 'op', '(') and _is(_at(toks, j + 1), 'str') \
                and _is(_at(toks, j + 2), 'op', ')'):
            return 'mod:' + toks[j + 1].value.strip('"\''), j + 3
        if len(parts) == 2 and tuple(parts) in own:
            return tuple(parts), j
        return (parts[0],), (i + 3)
    if t.value in aliases:
        path = aliases[t.value]
        if path[0].startswith('mod:'):
            return path[0], i + 1
        if len(path) == 1 and _is(_at(toks, i + 1), 'op', '.') and _is(_at(toks, i + 2), 'name') \
                and (path[0], toks[i + 2].value) in own:
            return (path[0], toks[i + 2].value), i + 3
        if len(path) == 2 and path not in own:
            path = path[:1]
        return path, i + 1
    return None


def _operands(toks, a, b, word):
    """toks[a:b] split at the "and"/"or" (word) outside brackets: [(start, end)]."""
    out, depth, s = [], 0, a
    for i in range(a, b):
        t = toks[i]
        if t.kind == 'op' and t.value in OPEN:
            depth += 1
        elif t.kind == 'op' and t.value in CLOSE:
            depth -= 1
        elif depth == 0 and _is(t, 'kw', word):
            out.append((s, i))
            s = i + 1
    out.append((s, b))
    return out


def _plain_ref(toks, a, b, aliases, own):
    """The symbol when toks[a:b] is exactly one reference (or ns.HasModule("x")), else None."""
    if a >= b:
        return None
    tt = _type_test(toks, a, aliases, own)
    if tt and tt[1] == b:
        return tt[0]
    r = _ref_at(toks, a, aliases, own)
    if r and r[1] + 2 == b and _not_nil(toks, r[1]):
        return r[0]
    return r[0] if r and r[1] == b else None


def _type_test(toks, i, aliases, own):
    """At toks[i] == "type": (symbol, index after) for 'type(R) == "table"' or '"function"', else None."""
    if not (_is(_at(toks, i), 'name', 'type') and _starts_name(toks, i) and _is(_at(toks, i + 1), 'op', '(')):
        return None
    r = _ref_at(toks, i + 2, aliases, own) if i + 2 < len(toks) else None
    if not r or isinstance(r[0], str):
        return None
    e = r[1]
    if _is(_at(toks, e), 'op', ')') and _is(_at(toks, e + 1), 'op', '==') and _is(_at(toks, e + 2), 'str') \
            and _at(toks, e + 2).value.strip('"\'') in ('table', 'function'):
        return r[0], e + 3
    return None


def _not_nil(toks, i):
    """Whether toks[i:i + 2] is "~= nil" (a test like the reference alone)."""
    return _is(_at(toks, i), 'op', '~=') and _is(_at(toks, i + 1), 'kw', 'nil')


def _cond_tests(toks, a, b, aliases, own):
    """What a condition toks[a:b] makes sure of. pos: the references that hold inside its block, the
    operands of a chain "R and S and ..." that are a reference alone. neg: the references that hold
    after "if <cond> then return end", the operands "not R" of a chain "... or not R or ...", or None."""
    pos = set()
    ors = _operands(toks, a, b, 'or')
    if len(ors) == 1:
        for s, e in _operands(toks, a, b, 'and'):
            sym = _plain_ref(toks, s, e, aliases, own)
            if sym:
                pos.add(sym)
    neg = []
    for s, e in ors:
        if _is(_at(toks, s), 'kw', 'not'):
            sym = _plain_ref(toks, s + 1, e, aliases, own)
            if sym:
                neg.append(sym)
    return pos, (neg or None)


def references(path, toks, aliases, own):
    """Every reference to a symbol of own in a file: (line, symbol, guarded, used, body). used: the
    reference is indexed, called or given fields (ns.X.f(), ns.X:f(), ns.X[k], X.f with X = ns.X); a
    plain read (if ns.X then, ns.X and ..., local X = ns.X) is no use. guarded: it sits in a guard of
    its symbol, see check(). body: it runs when the file's body runs (in ns.Load's function, not in a
    function of its own)."""
    out = []
    stack = [Frame('file')]
    expr = []           # [(symbol, depth, past or)] of "R and" / "not R or" guards still open
    depth = 0
    i, n = 0, len(toks)
    pending_cond = None  # ("if"|"elseif", start index) while reading a condition
    while i < n:
        t = toks[i]
        prev = _at(toks, i - 1)
        # a new statement on a new line after a finished value ends the open expression guards
        if t.bol and prev is not None and (prev.kind in ('name', 'str', 'num') or _is(prev, 'kw', 'end')
                                           or (prev.kind == 'op' and prev.value in VALUE_END)
                                           or _is(prev, 'kw', 'true') or _is(prev, 'kw', 'false')
                                           or _is(prev, 'kw', 'nil')) \
                and (t.kind == 'name' or t.kind == 'kw'):
            expr = [g for g in expr if g[1] < depth]
        top = stack[-1]
        if t.kind == 'kw':
            v = t.value
            if v == 'or':
                expr = [g for g in expr if g[1] < depth or g[2]]
            elif v in EXPR_END_KW:
                expr = [g for g in expr if g[1] < depth]
            if v == 'return':
                top.returns = True
            if v in ('if', 'elseif'):
                pending_cond = (v, i + 1)
            elif v == 'then' and pending_cond:
                kind, a = pending_cond
                pending_cond = None
                pos, neg = _cond_tests(toks, a, i, aliases, own)
                if kind == 'if':
                    stack.append(Frame('if', pos, neg))
                else:
                    top.guards, top.plain = pos | top.negacc, False
                    top.negacc |= set(neg or ())
            elif v == 'else':
                if top.kind == 'if':
                    top.guards, top.plain = set(top.negacc), False
            elif v in ('function', 'do', 'repeat'):
                stack.append(Frame(v))
            elif v in ('end', 'until'):
                if len(stack) > 1:
                    f = stack.pop()
                    if f.kind == 'if' and f.plain and f.neg and f.returns:
                        stack[-1].guards |= set(f.neg)
            i += 1
            continue
        if t.kind == 'op':
            if t.value in OPEN:
                depth += 1
            elif t.value in CLOSE:
                expr = [g for g in expr if g[1] < depth]
                depth -= 1
            elif t.value in EXPR_END_OP:
                expr = [g for g in expr if g[1] < depth]
            i += 1
            continue
        tt = _type_test(toks, i, aliases, own)
        if tt and _is(_at(toks, tt[1]), 'kw', 'and'):
            expr.append((tt[0], depth, False))
        r = _ref_at(toks, i, aliases, own)
        if not r:
            i += 1
            continue
        sym, e = r
        negated = _is(prev, 'kw', 'not')
        if isinstance(sym, str):          # ns.HasModule("x")
            if _is(_at(toks, e), 'kw', 'and') and not negated:
                expr.append((sym, depth, False))
            elif _is(_at(toks, e), 'kw', 'or') and negated:
                expr.append((sym, depth, True))
            i = e
            continue
        nxt = _at(toks, e)
        used = nxt is not None and ((nxt.kind == 'op' and nxt.value in USE_AFTER) or nxt.kind == 'str')
        if sym in own or (used and len(sym) == 1 and t.value == 'ns'):
            guards = set()
            for f in stack:
                guards |= f.guards
            guards |= {g[0] for g in expr}
            body = sum(1 for f in stack if f.kind == 'function') <= 1
            out.append((t.line, sym, sym in guards or ('mod:' + own.get(sym, '?')) in guards, used, body))
        after = e + 2 if _not_nil(toks, e) else e
        if _is(_at(toks, after), 'kw', 'and') and not used and not negated:
            expr.append((sym, depth, False))
        elif _is(_at(toks, e), 'kw', 'or') and negated:
            expr.append((sym, depth, True))
        i = e
    return out


def check(files=None):
    """The forbidden references: [(file, line, file's part, symbol, symbol's part)].

    Symbols: ns.X belongs to the part of the first file (TOC order) that assigns it ("ns.X =",
    "function ns.X(", ns.LazyData("X", ...)); ns.X.Y gets its own part when another part than X's adds
    Y to X ("function ns.W.Foo(" in a raid file). A use is a reference that is called, indexed or given
    fields: ns.X(), ns.X.f(), ns.X[k], and the same through a local alias (local G = ns.Gear); a bare
    read (if ns.X then, ns.X and ..., local A = ns.X) uses nothing.

    Rule 1, direction: a use of a symbol of another part is allowed when that part is the core. Else
    (core -> raid, core -> gear, raid <-> gear) it must be guarded, and so must a use of a symbol no
    file assigns. Guarded, a simple rule on the tokens (no data flow), with R the symbol itself, an
    alias of it, or ns.HasModule("raid"/"gear") (or an alias of that) for every symbol of that part:
      - inside "if C then ... end" where C is "R" or a chain "R and S and ..." with R as one operand
        ("R ~= nil" and 'type(R) == "table"' count as R); in an elseif or else branch also each R of an
        earlier condition "not R [or ...]";
      - after "R and" in the same expression ("ns.Gear and ns.Gear.Available()"), or after "not R or"
        ("not ns.Prof or not ns.Prof.Available()"); the expression ends at a comma, "=", ";", a
        keyword such as then/local/return, a closing bracket of its level or a new statement line;
      - after "if not R [or ...] then ... return end" in the same block or an outer one (an if without
        elseif/else whose block holds a return).
    A guarded use is "the feature quietly is not there" when the other part is not loaded. Pages, cards,
    settings and slash commands go through the registry, events through ns.Fire/ns.Listen and
    ns.OnEvent: they name no symbol of the other part and need no guard.

    Rule 2, load order: once the parts are addons of their own the bodies run core, then raid, then gear
    (F-202 step 2). A reference, guarded or not, that runs while a file's body runs (in ns.Load's
    function, not in a function of its own) may not name a symbol of a part that runs later: it would
    always be nil there ("local Layer = ns.Layer" in a core file). Look it up inside the function.
    """
    files = files or read_files()
    own = owners(files)
    bad = []
    for name, mod, toks, aliases in files:
        for line, sym, guarded, used, body in references(name, toks, aliases, own):
            owner = own.get(sym, '?')   # "?": no file assigns it (a typo, or code that is gone)
            if used and not may_use(mod, owner) and not guarded:
                bad.append((name, line, mod, '.'.join(('ns',) + sym), owner))
            elif body and owner != '?' and ORDER[owner] > ORDER[mod]:
                bad.append((name, line, mod + ' (body)', '.'.join(('ns',) + sym), owner))
    return bad


def main(argv):
    cmd = argv[1] if len(argv) > 1 else 'check'
    if cmd == 'files':
        for mod, names in files_by_module().items():
            print('%s (%d)' % (mod, len(names)))
            for name in names:
                print('  ' + name)
        return 0
    if cmd == 'symbols':
        own = owners(read_files())
        for mod in MODULES:
            syms = sorted('.'.join(('ns',) + p) for p, m in own.items() if m == mod)
            print('%s (%d): %s' % (mod, len(syms), ' '.join(syms)))
        return 0
    bad = check()
    counts = {}
    for name, line, mod, sym, owner in bad:
        print('%s:%d  %s -> %s  %s' % (name, line, mod, owner, sym))
        counts[(mod, owner)] = counts.get((mod, owner), 0) + 1
    for (mod, owner), k in sorted(counts.items()):
        print('%s -> %s: %d' % (mod, owner, k))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
