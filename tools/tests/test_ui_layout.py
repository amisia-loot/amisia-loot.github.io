"""tools/ui_layout.py: the text width estimate, the anchor solver, each layout rule on a made-up
frame tree, the drawing and the comparison. The rules over the real pages run in
`build.py check` (step "layout rules")."""
import json
import os
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import ui_layout as U  # noqa: E402


def node(i, parent, kind='Frame', points=(), **kw):
    n = {'id': i, 'parent': parent, 'kind': kind, 'shown': True, 'points': [list(p) for p in points]}
    n.update(kw)
    return n


def shot(nodes, marks=None, extra=None, name='t', view='officer'):
    return {'name': name, 'view': view, 'nodes': nodes, 'marks': marks or {'window': 1}, 'extra': extra or {}}


def test_text_width():
    assert U.text_width('', 'GameFontNormal') == 0
    plain = U.text_width('Vergeben', 'GameFontNormal')
    assert 48 < plain < 60, plain
    assert U.text_width('|cffe0a344Vergeben|r', 'GameFontNormal') == plain, 'colour codes take no room'
    assert U.text_width('Vergeben', 'GameFontNormalSmall') < plain, 'a smaller font'
    assert U.text_width('Vergeben', 'NumberFontNormalSmall') < plain, 'a narrow face'
    assert U.text_width('Über', 'GameFontNormal') == U.text_width('Uber', 'GameFontNormal'), 'umlauts as their letter'
    icon = U.text_width('|TInterface\\x:12:12|t A', 'GameFontNormal')
    assert icon >= 14 + U.text_width(' A', 'GameFontNormal') - 0.01, 'a texture takes its size'
    assert U.text_width('ab\nabcdef', 'GameFontNormal') == U.text_width('abcdef', 'GameFontNormal'), 'the widest line'
    assert U.wrap_lines('aaa bbb ccc', 'GameFontNormal', U.text_width('aaa bbb', 'GameFontNormal') + 1) == 2
    assert U.text_width('Vergeben', 'GameFontNormal', 1.2) == pytest.approx(plain * 1.2), 'the locale factor'


def test_anchors():
    nodes = [
        node(1, None, w=600, h=400),
        node(2, 1, points=[('TOPLEFT', None, 'TOPLEFT', 10, -20), ('BOTTOMRIGHT', None, 'BOTTOMRIGHT', -10, 20)]),
        node(3, 2, w=50, h=20, points=[('TOPRIGHT', None, 'TOPRIGHT', 0, 0)]),
        node(4, 2, w=30, h=10, points=[('RIGHT', 3, 'LEFT', -4, 0)]),
        node(5, 1, 'FontString', text='abc', font='GameFontNormal', points=[('CENTER', None, 'CENTER', 0, 0)]),
        node(6, 1, kind='ScrollFrame', w=100, h=50, points=[('TOPLEFT', None, 'TOPLEFT', 0, -300)], scrollChild=7),
        node(7, 6, w=100, h=500),
        node(8, 1, 'FontString', text='aaa bbb ccc ddd', font='GameFontNormal', w=40, wordWrap=True,
             points=[('TOPLEFT', None, 'TOPLEFT', 0, 0)]),
    ]
    t = U.Tree(nodes)
    assert t.rect(2) == (10, 20, 590, 380)
    assert t.rect(3) == (540, 20, 590, 40)
    assert t.rect(4) == (506, 25, 536, 35), t.rect(4)
    w = U.text_width('abc', 'GameFontNormal')
    assert t.rect(5) == pytest.approx((300 - w / 2, 194, 300 + w / 2, 206))
    assert t.rect(7) == (0, 300, 100, 800), 'the scroll child sits at the top of its frame'
    assert t.clip(7) == (0, 300, 100, 350) and t.clip(8) is None, 'a scroll frame clips its child'
    lines = U.wrap_lines('aaa bbb ccc ddd', 'GameFontNormal', 40)
    assert lines > 1 and t.rect(8)[3] == lines * 12, 'a wrapping text grows by its lines'


def window(*kids, w=400, h=300):
    return [node(1, None, w=w, h=h)] + list(kids)


def test_rule_bounds():
    s = shot(window(node(2, 1, w=50, h=20, role='button', points=[('TOPRIGHT', None, 'TOPRIGHT', 10, 0)]),
                    node(3, 1, w=50, h=20, tplPart=True, points=[('TOPRIGHT', None, 'TOPRIGHT', 10, 0)]),
                    node(4, 1, w=43, h=50, role='tab', points=[('TOPLEFT', None, 'TOPRIGHT', 0, 0)])))
    found = U.check_shot(s)
    assert len(found['bounds']) == 1 and 'leaves the window' in found['bounds'][0], 'template parts and tabs may hang out'
    assert s['bad_nodes'] == [2]


def test_rule_overlap():
    s = shot(window(node(2, 1, w=50, h=20, role='button', points=[('TOPLEFT', None, 'TOPLEFT', 0, 0)]),
                    node(3, 1, w=50, h=20, role='chip', points=[('TOPLEFT', None, 'TOPLEFT', 49, 0)]),
                    node(4, 1, w=50, h=20, role='chip', points=[('TOPLEFT', None, 'TOPLEFT', 99, 0)]),
                    node(5, 4, w=10, h=10, role='plain', points=[('CENTER', None, 'CENTER', 0, 0)])))
    found = U.check_shot(s)
    assert len(found['overlap']) == 1, 'touching chips and a button inside a chip are fine: ' + str(found)


def test_rule_text_and_minwidth():
    label = 'Vergeben'
    need = U.text_width(label, 'GameFontNormal') + 2 * U.PAD
    s = shot(window(
        node(2, 1, w=need - 2, h=22, role='button', points=[('TOPLEFT', None, 'TOPLEFT', 0, 0)]),
        node(3, 2, 'FontString', text=label, font='GameFontNormal', tplPart=True, points=[('CENTER', None, 'CENTER', 0, 0)]),
        node(4, 1, 'FontString', text='a long label here', font='GameFontNormal', w=30, wordWrap=False,
             points=[('TOPLEFT', None, 'TOPLEFT', 0, -40)]),
        node(5, 1, 'FontString', text='wraps, so it may', font='GameFontNormal', w=30, wordWrap=True,
             points=[('TOPLEFT', None, 'TOPLEFT', 0, -60)]),
        node(6, 1, w=need, h=22, role='chip', points=[('TOPLEFT', None, 'TOPLEFT', 0, -100)]),
        node(7, 6, 'FontString', text=label, font='GameFontNormal', wordWrap=False, points=[('CENTER', None, 'CENTER', 0, 0)]),
    ))
    found = U.check_shot(s)
    assert len(found['minwidth']) == 1 and 'needs' in found['minwidth'][0], found
    assert len(found['text']) == 1 and 'cut off' in found['text'][0], found


def test_rule_text_list_cells_may_end_in_an_ellipsis():
    s = shot(window(
        node(2, 1, w=300, h=100, role='list', points=[('TOPLEFT', None, 'TOPLEFT', 0, 0)]),
        node(3, 2, w=300, h=20, role='plain', points=[('TOPLEFT', None, 'TOPLEFT', 0, 0)]),
        node(4, 3, 'FontString', text='a very long item name in a cell', font='GameFontNormal', w=40, wordWrap=False,
             points=[('LEFT', None, 'LEFT', 4, 0)]),
    ))
    assert 'text' not in U.check_shot(s)


def test_rule_nav():
    extra = {'page': 'gear', 'current': 'overview', 'visible': ['overview', 'gear', 'talents']}
    s = shot(window(node(2, 1, w=150, h=100, points=[('TOPLEFT', None, 'TOPLEFT', 0, 0)]),
                    node(3, 2, w=150, h=22, role='plain', points=[('TOPLEFT', None, 'TOPLEFT', 0, 0)]),
                    node(4, 2, w=150, h=22, role='plain', points=[('TOPLEFT', None, 'TOPLEFT', 0, -90)])),
             marks={'window': 1, 'nav': 2, 'nav:overview': 3, 'nav:gear': 4}, extra=extra)
    found = U.check_shot(s)['nav']
    assert any('did not open' in f for f in found)
    assert any('talents has no row' in f for f in found)
    assert any('gear lies outside the list' in f for f in found)


def test_atlas_allow_list():
    assert U.check_atlases(['a', 'b'], ['a']) == ['atlas b is not in the style allow-list (ns.Theme.ATLASES)']
    assert U.check_atlases(['a'], []) and 'missing' in U.check_atlases(['a'], [])[0]


def test_render_and_compare(tmp_path):
    pytest.importorskip('PIL')
    s = shot(window(node(2, 1, w=80, h=22, role='button', points=[('TOPLEFT', None, 'TOPLEFT', 10, -10)]),
                    node(3, 2, 'FontString', text='Über |cffe0a344Gold|r', font='GameFontNormal',
                         points=[('CENTER', None, 'CENTER', 0, 0)]),
                    node(4, 1, 'Texture', atlas='common-insideframe', points=[('TOPLEFT', None, 'TOPLEFT', 0, -40),
                                                                             ('BOTTOMRIGHT', None, 'BOTTOMRIGHT', 0, 0)])))
    path = tmp_path / 'x.png'
    w, h = U.render(s, str(path))
    assert path.exists() and (w, h) == (400 + 70, 300 + 20)
    with open(tmp_path / 'officer-t.boxes.json', 'w', encoding='utf-8') as fh:
        json.dump(U.boxes(s), fh)
    assert U.compare(str(tmp_path), [s]) == [], 'the same boxes'
    s['nodes'][1]['points'][0][3] = 12
    changed = U.compare(str(tmp_path), [s])
    assert changed and changed[0][0] == 'officer-t' and len(changed[0][1]) >= 1
