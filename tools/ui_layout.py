"""UI snapshots and layout rules of the Amisia addon, from the test stub's recorded frames.

    python3 tools/ui_layout.py rules [--locale deDE|enUS]
    python3 tools/ui_layout.py snapshots [--out DIR] [--compare DIR] [--scale N] [--locale enUS]

Every registered page is opened in the raider, officer and expert view of the scene
(addon/tests/ui_scene.lua), and the side windows (roll window, award dialog, soft-reserve window,
gear window, self-test) once each. addon/tests/uidump.lua hands the stub's frame tree over as JSON
(anchors, sizes, texts, font objects, atlases); this file solves the anchors, checks the layout rules
and draws each window into a PNG.

Rules (RULES below), each over every shot:
  bounds     every visible frame, texture and text lies inside its page (the content inset of the
             main window) or its window; the client template's own parts and the side tabs are left
             out (they hang outside on purpose)
  overlap    no two visible interactive widgets (buttons, chips, edit boxes, check boxes, pickers,
             lists, arrows, scroll frames) overlap, unless one holds the other
  text       every one-line text fits its width (a bounded font string) and every label of a button
             or chip fits the widget with its padding; wrapped text with a fixed height fits that
             height. The width of a text is estimated per character (Friz Quadrata-like widths times
             the font object's size, times the locale's factor), on the safe side
  minwidth   every button and chip is at least as wide as its text plus the padding on both sides
  atlas      only atlases of the style allow-list (ns.Theme.ATLASES) are used
  nav        every visible page has a row in the page list, inside the list
The locales the rules run in: LOCALES (German and English).
"""
import argparse
import html
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TESTS = os.path.join(ROOT, 'addon', 'tests')
DEFAULT_OUT = '/tmp/amisia-snapshots'
VIEWS = ('raider', 'officer', 'expert')

# The client locales the rules run in and their width factor (1.0: the widths below as they are).
# Every shot is taken in each locale: German (deDE) and English (enUS, every other client locale).
LOCALES = {'deDE': 1.0, 'enUS': 1.0}

sys.path.insert(0, TESTS)
from textwidth import FONTS, font_size, plain, text_width, wrap_lines  # noqa: E402,F401 - shared with the stub

# the colour a font object draws in when no text colour is set
FONT_COLOR = {'Normal': (255, 209, 0), 'Highlight': (255, 255, 255), 'Disable': (128, 128, 128)}
# text padding inside a button or chip, each side (as ns.Theme.CHIP_PAD, which W.FitChip uses)
PAD = 8
CODE = re.compile(r'\|c[0-9a-fA-F]{8}|\|r|\|H[^|]*\|h|\|h|\|T([^|]*)\|t|\|A([^|]*)\|a|\|n')


# ---------------------------------------------------------------- capture
DRIVER = r'''
local view, mode = ...
local S = dofile(ADDON_DIR .. "/../tests/ui_scene.lua")
local dump = dofile(ADDON_DIR .. "/../tests/uidump.lua")
S.setup()
for k, v in pairs(S.VIEWS[view]) do NS.Set(k, v) end
local out = {}
local function shot(name, root, marks, extra)
    out[#out + 1] = { name = name, json = dump(root, marks), extra = extra or "{}" }
end
if mode == "pages" then
    NS.ShowPage("overview")
    local F = AmisiaFrame
    local panels = {}
    for _, p in ipairs(NS.panels) do panels[#panels + 1] = p end
    table.sort(panels, function(a, b) return (a.order or 99) < (b.order or 99) end)
    local visible = {}
    for _, p in ipairs(panels) do
        if NS.Visible(p) then visible[#visible + 1] = p.key end
    end
    local todo = {}
    for _, p in ipairs(panels) do
        if NS.Visible(p) then todo[#todo + 1] = { key = p.key, name = p.key, open = function() NS.ShowPage(p.key) end } end
    end
    for _, st in ipairs(S.STATES or {}) do
        local p = NS.Panel(st.page)
        if p and (st.always or NS.Visible(p)) then todo[#todo + 1] = { key = st.page, name = st.name, open = st.open } end
    end
    for _, p in ipairs(todo) do
        do
            p.open()
            local page
            for _, k in ipairs(F.content.kids or {}) do if k.shown then page = k end end
            local marks = { window = F, content = F.content, nav = F.nav, page = page }
            for _, e in ipairs(F.navOrder or {}) do
                if e.button and e.button.shown then marks["nav:" .. e.button.key] = e.button end
            end
            local keys = {}
            for i, k in ipairs(visible) do keys[i] = ("%q"):format(k) end
            local G, FT = NS.Theme.LAYOUT, NS.Theme.FONT
            local grid = ('{"ROW_H":%s,"LINE_H":%s,"GAP":%s,"TEXT_X":%s,"COLHEAD_H":%s,"EMPTY_Y":%s,"hint":%q,"head":%q}'):format(
                G.ROW_H, G.LINE_H, G.GAP, G.TEXT_X, G.COLHEAD_H, G.EMPTY_Y, FT.hint, FT.head)
            shot(p.name, F, marks, ('{"page":%q,"current":%q,"visible":[%s],"grid":%s}'):format(p.key, NS.CurrentPage() or "",
                table.concat(keys, ","), grid))
        end
    end
else
    for _, w in ipairs(S.WINDOWS) do
        if w.view == view then
            local ok, frame = pcall(w.open)
            if ok and frame then
                shot(w.key, frame, { window = frame })
                frame:Hide()
            else
                out[#out + 1] = { name = w.key, json = "null", extra = ('{"error":%q}'):format(tostring(frame)) }
            end
        end
    end
end
local atlases = {}
for name in pairs(STUB.atlasCalls) do atlases[#atlases + 1] = name end
table.sort(atlases)
local allow = {}
for _, a in ipairs((NS.Theme and NS.Theme.ATLASES) or {}) do allow[#allow + 1] = a end
return out, atlases, allow
'''


def _runtime(locale):
    import run as addon_run  # addon/tests/run.py, the stub loader
    factor = LOCALES.get(locale, 1.0)

    def setup(lua):
        lua.globals().STUB.locale = locale
        lua.globals().STUB.measure = lambda text, font: text_width(text, font, factor)
    lua = addon_run.fresh('', setup=setup)
    addon_run.RUNTIMES.clear()
    return lua


def capture(view, mode, locale='deDE'):
    """The shots of one view: mode 'pages' (every visible page of the main window) or 'windows'
    (the side windows of the scene for this view). Returns (shots, atlases used, allow-list)."""
    lua = _runtime(locale)
    out, atlases, allow = lua.execute(DRIVER, view, mode)
    shots = []
    for i in range(1, len(out) + 1):
        e = out[i]
        data = json.loads(e['json'])
        extra = json.loads(e['extra'])
        shots.append({'name': str(e['name']), 'view': view, 'locale': locale,
                      'nodes': data['nodes'] if data else [], 'marks': data['marks'] if data else {},
                      'extra': extra})
    used = [atlases[i] for i in range(1, len(atlases) + 1)]
    allowed = [allow[i] for i in range(1, len(allow) + 1)]
    return shots, used, allowed


def capture_all(locale='deDE'):
    shots, used, allowed = [], set(), set()
    for view in VIEWS:
        for mode in ('pages', 'windows'):
            s, u, a = capture(view, mode, locale)
            shots += s
            used |= set(u)
            allowed |= set(a)
    return shots, sorted(used), sorted(allowed)


# ---------------------------------------------------------------- geometry
HCLASS = {'LEFT': 'L', 'TOPLEFT': 'L', 'BOTTOMLEFT': 'L', 'RIGHT': 'R', 'TOPRIGHT': 'R', 'BOTTOMRIGHT': 'R'}
VCLASS = {'TOP': 'T', 'TOPLEFT': 'T', 'TOPRIGHT': 'T', 'BOTTOM': 'B', 'BOTTOMLEFT': 'B', 'BOTTOMRIGHT': 'B'}
INTERACTIVE = {'button', 'chip', 'edit', 'check', 'picker', 'list', 'arrow', 'scroll', 'plain'}


class Tree:
    """The nodes of one shot with their rectangles (left, top, right, bottom; y grows downwards),
    the root (id 1) at 0,0 with its own size."""

    def __init__(self, nodes, marks=None, factor=1.0):
        self.nodes = {n['id']: n for n in nodes}
        self.marks = marks or {}
        self.factor = factor
        self.kids = {}
        for n in nodes:
            if n.get('parent'):
                self.kids.setdefault(n['parent'], []).append(n['id'])
        self.scroll_parent = {}
        for n in nodes:
            if n.get('scrollChild'):
                self.scroll_parent[n['scrollChild']] = n['id']
        self._rect, self._busy = {}, set()
        # the nodes a rule found fault with (drawn with a red frame)
        self.bad = set()

    def node(self, i):
        return self.nodes.get(i)

    def natural(self, n):
        """Width and height a node has of its own (set size, template size, a text's extent)."""
        w = n.get('w', n.get('tplW'))
        h = n.get('h', n.get('tplH'))
        if n['kind'] == 'FontString':
            text = n.get('text', '')
            if w is None:
                w = text_width(text, n.get('font'), self.factor)
            if h is None:
                h = font_size(n.get('font')) * max(1, plain(text)[0].count('\n') + 1)
        return w, h

    def rect(self, i):
        if i in self._rect:
            return self._rect[i]
        n = self.nodes.get(i)
        if n is None:
            return None
        if i == 1:
            w, h = self.natural(n)
            r = (0.0, 0.0, float(w or 0), float(h or 0))
            self._rect[i] = r
            return r
        if i in self._busy:
            return None
        self._busy.add(i)
        try:
            r = self._solve(n)
        finally:
            self._busy.discard(i)
        self._rect[i] = r
        return r

    def _solve(self, n):
        pts = n.get('points') or []
        w, h = self.natural(n)
        if not pts:
            sp = self.scroll_parent.get(n['id'])
            if sp is not None:
                pr = self.rect(sp)
                if pr is None:
                    return None
                return (pr[0], pr[1], pr[0] + (w or 0), pr[1] + (h or 0))
            return None
        xs, ys = {}, {}
        for point, rel, rel_point, x, y in pts:
            if rel is None:
                rel = n.get('parent')
            elif rel == -1:
                rel = 1
            rr = self.rect(rel) if rel is not None else None
            if rr is None:
                return None
            l, t, r, b = rr
            hc = HCLASS.get(rel_point, 'C')
            vc = VCLASS.get(rel_point, 'C')
            ex = l if hc == 'L' else r if hc == 'R' else (l + r) / 2
            ey = t if vc == 'T' else b if vc == 'B' else (t + b) / 2
            xs[HCLASS.get(point, 'C')] = ex + (x or 0)
            ys[VCLASS.get(point, 'C')] = ey - (y or 0)
        if 'L' in xs and 'R' in xs:
            left, right = xs['L'], xs['R']
        else:
            w = w or 0
            if 'L' in xs:
                left = xs['L']
            elif 'R' in xs:
                left = xs['R'] - w
            elif 'C' in xs:
                left = xs['C'] - w / 2
            else:
                return None
            right = left + w
        if n['kind'] == 'FontString' and n.get('h') is None and n.get('text') and self.wraps(n) \
                and (n.get('w') is not None or ('L' in xs and 'R' in xs)):
            # a wrapping text grows downwards line by line
            lines = wrap_lines(n['text'], n.get('font'), right - left, self.factor)
            if n.get('maxLines'):
                lines = min(lines, int(n['maxLines']))
            h = lines * font_size(n.get('font'))
        if 'T' in ys and 'B' in ys:
            top, bottom = ys['T'], ys['B']
        else:
            h = h or 0
            if 'T' in ys:
                top = ys['T']
            elif 'B' in ys:
                top = ys['B'] - h
            elif 'C' in ys:
                top = ys['C'] - h / 2
            else:
                return None
            bottom = top + h
        return (left, top, right, bottom)

    def wraps(self, n):
        """A font string wraps: as set, else the client's default (on), except a template's label
        (a button's text, a header's), which stays one line."""
        if n.get('wordWrap') is not None:
            return n['wordWrap']
        return not self.tpl_part(n['id'])

    def bounded_width(self, n):
        """The width a font string is held to (two anchors across or a set width), or None."""
        if n.get('w') is not None:
            return n['w']
        hs = {HCLASS.get(p[0], 'C') for p in n.get('points') or []}
        if 'L' in hs and 'R' in hs:
            r = self.rect(n['id'])
            return r[2] - r[0] if r else None
        return None

    def bounded_height(self, n):
        if n.get('h') is not None:
            return n['h']
        vs = {VCLASS.get(p[0], 'C') for p in n.get('points') or []}
        if 'T' in vs and 'B' in vs:
            r = self.rect(n['id'])
            return r[3] - r[1] if r else None
        return None

    def visible(self, i):
        while i is not None:
            n = self.nodes.get(i)
            if n is None or not n.get('shown'):
                return False
            if i == 1:
                return True
            i = n.get('parent')
        return True

    def ancestors(self, i):
        out = []
        n = self.nodes.get(i)
        while n is not None and n.get('parent') is not None:
            out.append(n['parent'])
            n = self.nodes.get(n['parent'])
        return out

    def under(self, i, top):
        """Node i lies in the subtree of top (or is top)."""
        return i == top or top in self.ancestors(i)

    def clip(self, i):
        """The rectangle node i is clipped to: the scroll frames it lies in, or None."""
        box = None
        for a in self.ancestors(i):
            n = self.nodes.get(a)
            if n and n['kind'] == 'ScrollFrame':
                r = self.rect(a)
                if r:
                    box = r if box is None else (max(box[0], r[0]), max(box[1], r[1]), min(box[2], r[2]), min(box[3], r[3]))
        return box

    def tpl_part(self, i):
        """A part a client template made, or inside one."""
        if self.nodes[i].get('tplPart'):
            return True
        return any(self.nodes[a].get('tplPart') for a in self.ancestors(i) if a in self.nodes)

    def path(self, i):
        """A readable name of a node: its mark, global name or role, up the tree."""
        names = {v: k for k, v in self.marks.items()}
        parts = []
        cur = i
        while cur is not None and len(parts) < 6:
            n = self.nodes.get(cur)
            if n is None:
                break
            label = names.get(cur) or n.get('name') or n.get('role') or n['kind']
            if n['kind'] == 'FontString' and n.get('text'):
                label += '"' + plain(n['text'])[0][:24] + '"'
            parts.append(label)
            if cur in names or n.get('name'):
                break
            cur = n.get('parent')
        return '/'.join(reversed(parts))


def _area(a, b):
    w = min(a[2], b[2]) - max(a[0], b[0])
    h = min(a[3], b[3]) - max(a[1], b[1])
    return w * h if w > 0.5 and h > 0.5 else 0


def _clipped(tree, i):
    r = tree.rect(i)
    c = tree.clip(i)
    if r is None or c is None:
        return r
    out = (max(r[0], c[0]), max(r[1], c[1]), min(r[2], c[2]), min(r[3], c[3]))
    return out if out[2] > out[0] and out[3] > out[1] else None


# ---------------------------------------------------------------- rules
TOL = 0.5


def rule_bounds(tree, shot):
    out = []
    window = tree.marks.get('window', 1)
    content = tree.marks.get('content')
    wr = tree.rect(window)
    cr = tree.rect(content) if content else None
    for i, n in tree.nodes.items():
        if i == window or not tree.visible(i) or tree.tpl_part(i):
            continue
        if n.get('role') == 'tab' or any(tree.nodes[a].get('role') == 'tab' for a in tree.ancestors(i)):
            continue
        if n.get('layer') == 'HIGHLIGHT':
            continue
        r = _clipped(tree, i)
        if r is None or (r[2] - r[0] < 0.5 and r[3] - r[1] < 0.5):
            continue
        inside_page = content is not None and tree.under(i, content) and i != content
        box, what = (cr, 'page') if inside_page else (wr, 'window')
        if box is None:
            continue
        if r[0] < box[0] - TOL or r[2] > box[2] + TOL or r[1] < box[1] - TOL or r[3] > box[3] + TOL:
            tree.bad.add(i)
            out.append(f'{tree.path(i)} leaves the {what}: x {r[0]:.0f}..{r[2]:.0f} of {box[0]:.0f}..{box[2]:.0f}, '
                       f'y {r[1]:.0f}..{r[3]:.0f} of {box[1]:.0f}..{box[3]:.0f}')
    return out


def rule_overlap(tree, shot):
    out = []
    items = []
    for i, n in tree.nodes.items():
        if n.get('role') in INTERACTIVE and tree.visible(i) and not tree.tpl_part(i):
            r = _clipped(tree, i)
            if r and r[2] - r[0] > 0.5 and r[3] - r[1] > 0.5:
                items.append((i, r))
    for a in range(len(items)):
        ia, ra = items[a]
        anc_a = set(tree.ancestors(ia))
        for b in range(a + 1, len(items)):
            ib, rb = items[b]
            if ib in anc_a or ia in tree.ancestors(ib):
                continue
            if _area(ra, rb) > 0:
                tree.bad.update((ia, ib))
                out.append(f'{tree.path(ia)} and {tree.path(ib)} overlap: '
                           f'{ra[0]:.0f},{ra[1]:.0f}..{ra[2]:.0f},{ra[3]:.0f} / {rb[0]:.0f},{rb[1]:.0f}..{rb[2]:.0f},{rb[3]:.0f}')
    return out


def _widget_of(tree, i):
    """The button or chip a font string labels (its parent), or None."""
    p = tree.nodes.get(tree.nodes[i].get('parent'))
    if p and p.get('role') in ('button', 'chip', 'check', 'tab'):
        return p
    return None


def in_list_row(tree, i):
    """A cell of a W.List row: data that may end in the client's ellipsis (the tooltip or the detail
    shows it whole), unlike a label. A chip or button in the row is still a label."""
    p = tree.nodes.get(tree.nodes[i].get('parent'))
    if p is None or p.get('role') != 'plain':
        return False
    return any(tree.nodes[a].get('role') == 'list' for a in tree.ancestors(i))


def rule_text(tree, shot):
    out = []
    f = tree.factor
    for i, n in tree.nodes.items():
        if n['kind'] != 'FontString' or not n.get('text') or not tree.visible(i):
            continue
        text = n['text']
        if not plain(text)[0].strip('\x00 ').strip():
            continue
        est = text_width(text, n.get('font'), f)
        bw = tree.bounded_width(n)
        wrap = tree.wraps(n)
        if bw is not None:
            if not wrap and est > bw + TOL and not in_list_row(tree, i):
                tree.bad.add(i)
                out.append(f'{tree.path(i)}: {est:.0f} px of text in {bw:.0f} px (cut off)')
            elif wrap:
                bh = tree.bounded_height(n)
                lines = wrap_lines(text, n.get('font'), bw, f)
                if n.get('maxLines') and lines > n['maxLines'] and est > bw:
                    tree.bad.add(i)
                    out.append(f'{tree.path(i)}: {lines} lines of text, {int(n["maxLines"])} allowed')
                elif bh is not None and lines * font_size(n.get('font')) > bh + TOL + 2:
                    tree.bad.add(i)
                    out.append(f'{tree.path(i)}: {lines} lines need {lines * font_size(n.get("font"))} px, '
                               f'{bh:.0f} px high')
            continue
        w = _widget_of(tree, i)
        if w is not None:
            wr = tree.rect(w['id'])
            r = tree.rect(i)
            if wr and r and (r[0] < wr[0] - TOL or r[2] > wr[2] + TOL):
                tree.bad.add(i)
                out.append(f'{tree.path(i)}: {est:.0f} px of text sticks out of its {w.get("role")} '
                           f'({wr[2] - wr[0]:.0f} px)')
    return out


def rule_minwidth(tree, shot):
    out = []
    for i, n in tree.nodes.items():
        if n.get('role') not in ('button', 'chip') or not tree.visible(i) or tree.tpl_part(i):
            continue
        labels = [k for k in tree.kids.get(i, []) if tree.nodes[k]['kind'] == 'FontString'
                  and tree.nodes[k].get('text') and tree.visible(k)]
        if not labels:
            continue
        r = tree.rect(i)
        if not r:
            continue
        width = r[2] - r[0]
        for k in labels:
            ln = tree.nodes[k]
            need = text_width(ln['text'], ln.get('font'), tree.factor) + 2 * PAD
            if width + TOL < need:
                tree.bad.add(i)
                out.append(f'{tree.path(k)}: the {n["role"]} is {width:.0f} px, its text needs {need:.0f} '
                           f'(text {need - 2 * PAD:.0f} + {PAD} each side)')
    return out


def rule_nav(tree, shot):
    out = []
    extra = shot.get('extra') or {}
    if 'visible' not in extra:
        return out
    if extra.get('current') != extra.get('page'):
        out.append(f'page {extra.get("page")} did not open (shows {extra.get("current")})')
    nav = tree.marks.get('nav')
    nr = tree.rect(nav) if nav else None
    for key in extra['visible']:
        b = tree.marks.get('nav:' + key)
        if b is None:
            out.append(f'page {key} has no row in the page list')
            continue
        r = tree.rect(b)
        if nr and r and (r[1] < nr[1] - TOL or r[3] > nr[3] + TOL or r[0] < nr[0] - TOL or r[2] > nr[2] + TOL):
            out.append(f'the page list row of {key} lies outside the list: y {r[1]:.0f}..{r[3]:.0f} of {nr[1]:.0f}..{nr[3]:.0f}')
    return out


# every page must be built with W.Page (on once all pages are)
REQUIRE_SCAFFOLD = False


def rule_grid(tree, shot):
    """The page scaffold (W.Page, ns.Theme.LAYOUT): every page is built with it; its head row starts
    at the page's top and is ROW_H high; what a band holds sits centred on it; hint lines and footer
    lines are in the hint font, a line TEXT_X in from the edge; column heads are COLHEAD_H high in the
    head font; the footer ends at the page's bottom and nothing of the content reaches into it; every
    empty state is placed by the scaffold."""
    extra = shot.get('extra') or {}
    grid = extra.get('grid')
    page = tree.marks.get('page')
    if not grid or page is None:
        return []
    out = []
    pn = tree.nodes.get(page)
    if pn is None or pn.get('lrole') != 'page':
        if not REQUIRE_SCAFFOLD:
            return out
        tree.bad.add(page)
        return [f'page {extra.get("page")} is not built with W.Page']
    pr = tree.rect(page)
    if pr is None:
        return out

    def bad(i, text):
        tree.bad.add(i)
        out.append(f'{tree.path(i)} {text}')

    footer = None
    for i, n in tree.nodes.items():
        role = n.get('lrole')
        if n.get('emptyState') and role != 'empty' and tree.visible(i) and tree.under(i, page):
            bad(i, 'is an empty state not placed by the page scaffold (p:Empty)')
        if not role or not tree.visible(i) or not tree.under(i, page):
            continue
        r = tree.rect(i)
        if r is None:
            continue
        if role == 'headband':
            if n.get('parent') == page and (abs(r[1] - pr[1]) > TOL or abs((r[3] - r[1]) - grid['ROW_H']) > TOL):
                bad(i, f'the head row lies at y {r[1] - pr[1]:.0f}, {r[3] - r[1]:.0f} high '
                       f'(0, {grid["ROW_H"]} on every page)')
        elif role in ('head', 'band') and n.get('lband'):
            br = tree.rect(int(n['lband']))
            if br and abs((r[1] + r[3]) / 2 - (br[1] + br[3]) / 2) > TOL:
                bad(i, f'is not centred on its band: y {r[1]:.0f}..{r[3]:.0f}, the band {br[1]:.0f}..{br[3]:.0f}')
        elif role == 'line':
            if n.get('font') != grid['hint']:
                bad(i, f'is a line in {n.get("font")}, lines are in {grid["hint"]}')
            if abs(r[0] - (pr[0] + grid['TEXT_X'])) > TOL:
                bad(i, f'starts at x {r[0] - pr[0]:.0f}, lines start at {grid["TEXT_X"]}')
        elif role == 'colhead':
            if abs((r[3] - r[1]) - grid['COLHEAD_H']) > TOL:
                bad(i, f'is {r[3] - r[1]:.0f} high, column heads are {grid["COLHEAD_H"]}')
            for k, m in tree.nodes.items():
                if m['kind'] == 'FontString' and m.get('text') and tree.visible(k) and tree.under(k, i) \
                        and m.get('font') != grid['head']:
                    bad(k, f'is a column head in {m.get("font")}, column heads are in {grid["head"]}')
        elif role == 'foot':
            if n.get('font') != grid['hint']:
                bad(i, f'is a footer line in {n.get("font")}, footer lines are in {grid["hint"]}')
        elif role == 'footer':
            if abs(r[3] - pr[3]) > TOL:
                bad(i, f'ends {pr[3] - r[3]:.0f} px above the page bottom (the footer ends at it)')
            elif r[3] - r[1] > 0.5:
                footer = (i, r)
    if footer:
        fi, fr = footer
        for i, n in tree.nodes.items():
            if not tree.visible(i) or tree.under(i, fi) or i in tree.ancestors(fi) or not tree.under(i, page):
                continue
            texted = n['kind'] == 'FontString' and plain(n.get('text') or '')[0].strip()
            if not (texted or n.get('role') in INTERACTIVE):
                continue
            if tree.tpl_part(i) or n.get('layer') == 'HIGHLIGHT':
                continue
            r = _clipped(tree, i)
            if r and _area(r, fr) > 0:
                bad(i, f'reaches into the footer: y {r[1]:.0f}..{r[3]:.0f}, the footer {fr[1]:.0f}..{fr[3]:.0f}')
    return out


RULES = {'bounds': rule_bounds, 'overlap': rule_overlap, 'text': rule_text, 'minwidth': rule_minwidth,
         'nav': rule_nav, 'grid': rule_grid}


def check_shot(shot, factor=1.0):
    """{rule: [finding, ...]} of one shot."""
    if not shot['nodes']:
        return {'open': ['the window did not open: ' + str((shot.get('extra') or {}).get('error'))]}
    tree = Tree(shot['nodes'], shot['marks'], factor)
    found = {}
    for name, fn in RULES.items():
        res = fn(tree, shot)
        if res:
            found[name] = res
    shot['bad_nodes'] = sorted(tree.bad)
    return found


def check_atlases(used, allowed):
    if not allowed:
        return ['no allow-list: ns.Theme.ATLASES is missing']
    return [f'atlas {a} is not in the style allow-list (ns.Theme.ATLASES)' for a in used if a not in allowed]


def run_rules(locales=None):
    """Every rule over every shot in every locale. Returns a list of 'locale view/shot rule: text'."""
    out = []
    for loc in (locales or LOCALES):
        shots, used, allowed = capture_all(loc)
        for s in shots:
            for rule, items in check_shot(s, LOCALES.get(loc, 1.0)).items():
                for it in items:
                    out.append(f'{loc} {s["view"]}/{s["name"]} {rule}: {it}')
        for it in check_atlases(used, allowed):
            out.append(f'{loc} atlas: {it}')
    return out


# ---------------------------------------------------------------- drawing
ROLE_STYLE = {
    'chip': ((110, 22, 18), (226, 182, 87)), 'button': ((150, 28, 20), (240, 200, 110)),
    'edit': ((18, 28, 48), (120, 150, 200)), 'picker': ((40, 25, 60), (170, 130, 220)),
    'check': ((60, 60, 10), (240, 220, 60)), 'arrow': ((90, 60, 0), (255, 160, 40)),
    'list': (None, (80, 200, 120)), 'scroll': (None, (80, 200, 220)), 'tab': ((70, 70, 80), (180, 180, 200)),
    'plain': (None, (120, 120, 150)),
}
# the built-in face of Pillow has no Latin-1 letters: umlauts are drawn as the letter with two dots
UMLAUT = {'ä': 'a', 'ö': 'o', 'ü': 'u', 'Ä': 'A', 'Ö': 'O', 'Ü': 'U'}


def _glyph(ch):
    """The character Pillow's face can draw, and whether two dots go over it."""
    if ch in UMLAUT:
        return UMLAUT[ch], True
    if ch == 'ß':
        return 'B', False
    if ord(ch) < 128:
        return ch, False
    import unicodedata
    base = ''.join(c for c in unicodedata.normalize('NFD', ch) if not unicodedata.combining(c))
    return (base if base and ord(base[0]) < 128 else ('-' if ch in '–—·' else '?'))[0], False
LAYERS = {'BACKGROUND': 0, 'BORDER': 1, 'ARTWORK': 2, None: 2, 'OVERLAY': 3}


def _font(size):
    from PIL import ImageFont
    return ImageFont.load_default(size=max(6, int(round(size))))


def _rgb(c, default):
    if not c:
        return default
    vals = [x if isinstance(x, (int, float)) else 1 for x in c] + [1, 1, 1]
    return tuple(int(max(0, min(1, v)) * 255) for v in vals[:3])


def _segments(text, base):
    """(text, colour) runs of a text with |c codes."""
    out, color = [], base
    pos = 0
    s = str(text or '')
    for m in re.finditer(r'\|c([0-9a-fA-F]{8})|\|r', s):
        if m.start() > pos:
            out.append((s[pos:m.start()], color))
        color = tuple(int(m.group(1)[k:k + 2], 16) for k in (2, 4, 6)) if m.group(1) else base
        pos = m.end()
    out.append((s[pos:], color))
    return out


def render(shot, path, scale=1, mono=False):
    """Draws a shot into a PNG at its window's size (plus room for the side tabs). Each character
    takes the advance the width estimate gives it (so a text drawn wider than its box is one the rules
    call too wide); mono draws every character in a 0.6 em cell instead."""
    from PIL import Image, ImageDraw
    tree = Tree(shot['nodes'], shot['marks'])
    root = tree.marks.get('window', 1)
    wr = tree.rect(root)
    pad_l, pad_t, pad_r, pad_b = 10, 10, 60, 10
    W = int((wr[2] - wr[0] + pad_l + pad_r) * scale)
    H = int((wr[3] - wr[1] + pad_t + pad_b) * scale)
    img = Image.new('RGB', (W, H), (14, 12, 18))
    d = ImageDraw.Draw(img, 'RGBA')
    ox, oy = pad_l - wr[0], pad_t - wr[1]

    def box(r):
        return [(r[0] + ox) * scale, (r[1] + oy) * scale, (r[2] + ox) * scale - 1, (r[3] + oy) * scale - 1]

    label_font = _font(7 * scale)

    def draw_text(n, r, clip):
        font = n.get('font')
        size = font_size(font) * scale
        fnt = _font(size)
        fam = next((k for k in FONT_COLOR if k in (font or 'Highlight')), 'Highlight')
        base = _rgb(n.get('textColor'), FONT_COLOR[fam])

        def adv(ch):
            return 0.6 * size if mono else text_width(ch, font) * scale

        text = plain_keep_colors(n['text'])
        bw = tree.bounded_width(n)
        lines = text.split('\n')
        if bw is not None and tree.wraps(n):
            lines = wrap_colored(lines, font, bw)
            if n.get('maxLines'):
                lines = lines[:int(n['maxLines'])]
        x0, y0 = (r[0] + ox) * scale, (r[1] + oy) * scale
        total_h = len(lines) * size
        y = y0 + max(0, ((r[3] - r[1]) * scale - total_h) / 2)
        for line in lines:
            chars = plain(line)[0]
            width = sum(size + 2 * scale if ch == '\x00' else adv(ch) for ch in chars)
            just = n.get('justifyH') or 'LEFT'
            if bw is not None and just == 'CENTER':
                x = x0 + ((r[2] - r[0]) * scale - width) / 2
            elif bw is not None and just == 'RIGHT':
                x = x0 + (r[2] - r[0]) * scale - width
            else:
                x = x0
            # a one-line text held to a width ends where the client would put its ellipsis
            cut = None
            if bw is not None and not tree.wraps(n) and in_list_row(tree, n['id']) and width > (r[2] - r[0]) * scale + 0.5:
                x, cut = x0, x0 + (r[2] - r[0]) * scale
            ended = False
            for seg, color in _segments(line, base):
                for ch in plain(seg)[0]:
                    if ended:
                        break
                    if ch == '\x00':
                        d.rectangle([x, y + 1, x + size - 2, y + size - 1], outline=(150, 150, 150))
                        x += size + 2 * scale
                        continue
                    cell = adv(ch)
                    if cut is not None and x + cell > cut - adv('.') * 3:
                        d.text((x, y + 0.8 * size), '...', font=fnt, fill=color, anchor='ls')
                        ended = True
                        break
                    if clip is None or (clip[0] - 1 <= x and x + cell <= clip[2] + 1 and clip[1] - 1 <= y
                                        and y + size <= clip[3] + 1):
                        g, dots = _glyph(ch)
                        d.text((x + cell / 2, y + 0.8 * size), g, font=fnt, fill=color, anchor='ms')
                        if dots:
                            for dx in (-0.15, 0.15):
                                cx = x + cell / 2 + dx * size
                                d.point([(cx, y), (cx, y + 1)], fill=color)
                    x += cell
            y += size

    def draw(i):
        n = tree.nodes[i]
        if not n.get('shown'):
            return
        r = tree.rect(i)
        clip = tree.clip(i)
        clip_s = box(clip) if clip else None
        if r is not None:
            cr = _clipped(tree, i) if clip else r
            if cr is not None and cr[2] - cr[0] >= 1 and cr[3] - cr[1] >= 1:
                b = box(cr)
                kind = n['kind']
                if kind == 'Texture':
                    if n.get('layer') != 'HIGHLIGHT':
                        if n.get('color'):
                            c = n['color'] + [1, 1, 1, 1]
                            a = (c[3] if isinstance(c[3], (int, float)) else 1) * (n.get('alpha') or 1)
                            d.rectangle(b, fill=_rgb(c, (0, 0, 0)) + (int(a * 255),))
                        elif n.get('atlas') or n.get('texture'):
                            name = n.get('atlas') or os.path.basename(str(n.get('texture')).replace('\\', '/'))
                            col = (200, 160, 90, 200) if n.get('atlas') else (120, 120, 140, 160)
                            if n.get('atlas') and ('insideframe' in name or 'background' in name.lower()
                                                   or 'Background' in name):
                                d.rectangle(b, fill=(40, 32, 26, 140) if 'insideframe' not in name else None, outline=col)
                            else:
                                d.rectangle(b, outline=col)
                            if b[2] - b[0] > 40 and b[3] - b[1] > 8:
                                d.text((b[0] + 2, b[1] + 1), name[:int((b[2] - b[0]) / (4 * scale))], font=label_font,
                                       fill=col)
                elif kind == 'FontString':
                    if n.get('text'):
                        draw_text(n, r, clip_s)
                else:
                    style = ROLE_STYLE.get(n.get('role'))
                    if style:
                        fill, line = style
                        if n.get('role') == 'chip' and n.get('on') is False:
                            fill = tuple(int(v * 0.45) for v in fill)
                        d.rectangle(b, fill=(fill + (230,)) if fill else None, outline=line)
                    elif not n.get('tplPart') and kind != 'Frame':
                        d.rectangle(b, outline=(90, 90, 110, 120))
                    if kind == 'EditBox' and n.get('text'):
                        draw_text(dict(n, font=n.get('font') or 'ChatFontNormal', justifyH=n.get('justifyH')), r, clip_s)
        kids = tree.kids.get(i, [])
        regions = [k for k in kids if tree.nodes[k]['kind'] in ('Texture', 'FontString')]
        frames = [k for k in kids if k not in regions]
        regions.sort(key=lambda k: (tree.nodes[k]['kind'] == 'FontString', LAYERS.get(tree.nodes[k].get('layer'), 2)))
        for k in regions:
            draw(k)
        frames.sort(key=lambda k: tree.nodes[k].get('level') or 0)
        for k in frames:
            draw(k)

    draw(root)
    # what the rules found: a red frame round the node
    for i in sorted(shot.get('bad_nodes') or []):
        r = tree.rect(i)
        if r:
            d.rectangle(box(r), outline=(255, 40, 40), width=max(1, scale))
    img.save(path)
    return W, H


def wrap_colored(lines, font, width):
    """Lines broken at spaces to width (estimated), the colour of a broken run carried over."""
    out = []
    for para in lines:
        cur, color = '', ''
        for word in para.split(' '):
            cand = (cur + ' ' + word) if cur else word
            if cur and text_width(cand, font) > width:
                out.append(cur)
                cur = color + word
            else:
                cur = cand
            for m in re.finditer(r'\|c[0-9a-fA-F]{8}|\|r', word):
                color = m.group(0) if m.group(0) != '|r' else ''
        out.append(cur)
    return out


def plain_keep_colors(text):
    """The text with link and texture codes resolved but |c colours kept (for the drawing)."""
    def sub(m):
        if m.group(0).startswith(('|T', '|A')):
            return '|T|t'
        return m.group(0) if m.group(0).startswith(('|c', '|r')) else ''
    return CODE.sub(sub, str(text or ''))


def boxes(shot):
    """The layout boxes of a shot for --compare: sorted (kind, role, l, t, r, b, text, atlas)."""
    tree = Tree(shot['nodes'], shot['marks'])
    out = []
    for i, n in tree.nodes.items():
        if not tree.visible(i):
            continue
        r = tree.rect(i)
        if r is None:
            continue
        out.append([n['kind'], n.get('role') or '', round(r[0], 1), round(r[1], 1), round(r[2], 1), round(r[3], 1),
                    n.get('text') or '', n.get('atlas') or '', n.get('font') or ''])
    out.sort()
    return out


def compare(old_dir, shots):
    """Shots whose boxes differ from those saved in old_dir: [(name, added, removed)]."""
    out = []
    for s in shots:
        key = f'{s["view"]}-{s["name"]}'
        path = os.path.join(old_dir, key + '.boxes.json')
        if not os.path.exists(path):
            out.append((key, 'new', None))
            continue
        with open(path, encoding='utf-8') as fh:
            old = [tuple(x) for x in json.load(fh)]
        new = [tuple(x) for x in boxes(s)]
        if old != new:
            from collections import Counter
            co, cn = Counter(old), Counter(new)
            added = list((cn - co).elements())
            removed = list((co - cn).elements())
            out.append((key, added, removed))
    return out



def snapshots(out_dir, compare_dir=None, scale=1, locale='deDE', mono=False):
    os.makedirs(out_dir, exist_ok=True)
    shots, used, allowed = capture_all(locale)
    factor = LOCALES.get(locale, 1.0)
    cards = []
    for s in shots:
        key = f'{s["view"]}-{s["name"]}'
        found = check_shot(s, factor)
        if s['nodes']:
            render(s, os.path.join(out_dir, key + '.png'), scale, mono)
            with open(os.path.join(out_dir, key + '.boxes.json'), 'w', encoding='utf-8') as fh:
                json.dump(boxes(s), fh, ensure_ascii=False)
        cards.append((s, key, found))
    atlas_bad = check_atlases(used, allowed)
    changed = compare(compare_dir, shots) if compare_dir else None
    write_index(out_dir, cards, atlas_bad, changed, locale)
    return cards, atlas_bad, changed


def write_index(out_dir, cards, atlas_bad, changed, locale):
    parts = ['<!doctype html><meta charset="utf-8"><title>Amisia UI snapshots</title>',
             '<style>body{background:#111;color:#ddd;font:13px sans-serif;margin:16px}h2{color:#e3b857}'
             '.grid{display:flex;flex-wrap:wrap;gap:16px}.card{background:#1b1820;padding:8px;border:1px solid #333}'
             '.card img{display:block;max-width:100%}.bad{color:#f66}.ok{color:#6c6}ul{margin:4px 0;padding-left:18px;'
             'max-width:820px}</style>',
             f'<h1>Amisia UI snapshots ({html.escape(locale)})</h1>']
    total = sum(len(v) for _, _, f in cards for v in f.values())
    parts.append(f'<p>{len(cards)} shots, {total} rule findings' + (f', {len(atlas_bad)} atlas findings' if atlas_bad else '')
                 + '.</p>')
    if atlas_bad:
        parts.append('<ul class="bad">' + ''.join(f'<li>{html.escape(a)}</li>' for a in atlas_bad) + '</ul>')
    if changed is not None:
        if changed:
            parts.append('<h2>Changed against the comparison</h2><ul>' + ''.join(
                f'<li>{html.escape(k)}: ' + ('new' if a == 'new' else f'{len(a)} boxes new, {len(r)} gone') + '</li>'
                for k, a, r in changed) + '</ul>')
        else:
            parts.append('<p class="ok">No layout box changed against the comparison.</p>')
    for view in VIEWS:
        parts.append(f'<h2>{view}</h2><div class="grid">')
        for s, key, found in cards:
            if s['view'] != view:
                continue
            parts.append(f'<div class="card"><b>{html.escape(s["name"])}</b><br>')
            if s['nodes']:
                parts.append(f'<a href="{key}.png"><img src="{key}.png" alt="{html.escape(key)}"></a>')
            if found:
                parts.append('<ul class="bad">' + ''.join(f'<li>{html.escape(r)}: {html.escape(x)}</li>'
                                                          for r, xs in found.items() for x in xs) + '</ul>')
            else:
                parts.append('<div class="ok">rules: ok</div>')
            parts.append('</div>')
        parts.append('</div>')
    with open(os.path.join(out_dir, 'index.html'), 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(parts))


# ---------------------------------------------------------------- main
def main(argv=None):
    ap = argparse.ArgumentParser(prog='ui_layout.py', description=__doc__.split('\n\n')[0])
    sub = ap.add_subparsers(dest='cmd', required=True)
    r = sub.add_parser('rules', help='check the layout rules; exit 1 on a finding')
    r.add_argument('--locale', action='append', help='a locale of LOCALES (default: all)')
    s = sub.add_parser('snapshots', help='draw every page and window into PNGs with an index.html')
    s.add_argument('--out', default=DEFAULT_OUT, help=f'output folder (default {DEFAULT_OUT})')
    s.add_argument('--compare', default=None, help='a folder of an earlier run: report the shots whose boxes changed')
    s.add_argument('--scale', type=int, default=1, help='pixels per UI pixel (default 1)')
    s.add_argument('--locale', default='deDE')
    s.add_argument('--mono', action='store_true', help='draw text in a fixed 0.6 em grid instead of the estimated advances')
    args = ap.parse_args(argv)
    if args.cmd == 'rules':
        found = run_rules(args.locale)
        for line in found:
            print(line)
        print(f'layout rules: {len(found)} finding(s)' if found else 'layout rules: ok')
        return 1 if found else 0
    cards, atlas_bad, changed = snapshots(os.path.abspath(args.out), args.compare, args.scale, args.locale, args.mono)
    n = sum(len(v) for _, _, f in cards for v in f.values())
    print(f'{len(cards)} shots in {os.path.abspath(args.out)} (index.html); {n} rule finding(s)'
          + (f', {len(atlas_bad)} atlas finding(s)' if atlas_bad else ''))
    if changed is not None:
        if changed:
            for k, a, rem in changed:
                print(f'changed: {k}: ' + ('new' if a == 'new' else f'{len(a)} boxes new, {len(rem)} gone'))
        else:
            print('compare: no layout box changed')
    return 0


if __name__ == '__main__':
    sys.exit(main())
