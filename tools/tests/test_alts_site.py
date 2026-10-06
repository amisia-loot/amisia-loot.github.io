"""Alts on the site (index.html) and their way into the Amisia addon.

tools/tests/site_alts.cjs cuts the alt code out of the page: which raider is whose alt
(raider.main, one level, broken links ignored), attendance and the grid cells added up over the
characters of a player, the awards of a player, unlinking without loss, removing a main, and the
"#AMISIA-ALTS" text. That text goes through the addon's own parser (ns.ParseAlts) and must come
out the same.
"""
import json
import os
import shutil
import subprocess
import sys

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DRIVER = os.path.join(ROOT, 'tools', 'tests', 'site_alts.cjs')
sys.path.insert(0, os.path.join(ROOT, 'addon', 'tests'))


@pytest.fixture(scope='module')
def out():
    node = shutil.which('node') or os.path.expanduser('~/.local/node/bin/node')
    if not os.path.exists(node):
        pytest.skip('node is not installed')
    p = subprocess.run([node, DRIVER], stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=dict(os.environ, TZ='UTC'))
    assert p.returncode == 0, p.stderr.decode('utf-8', 'replace')
    return json.loads(p.stdout.decode('utf-8'))


def test_a_ledger_without_links_works_as_before(out):
    b = out['before']
    assert b['main'] == 'b' and b['group'] == ['a'] and b['mains'] == ['a', 'b', 'z', 'c', 'v']
    assert b['text'] == '', 'no links, no text'


def test_linking_and_its_refusals(out):
    assert out['link'] == [
        None, None,
        'Anna has alts of their own. Unlink those first.',
        'Bob is an alt of Anna. Pick the main.',
        'A raider cannot be their own alt.',
        'A raider cannot be their own alt.',
        'Unknown raider.',
    ], out['link']
    a = out['after']
    assert a['main'] == 'a' and a['mainOfMain'] == 'a'
    assert a['alts'] == ['b', 'z'] and a['altsOfAlt'] == []
    assert a['group'] == ['a', 'b', 'z'], 'the main first, then the alts by name'
    assert a['mains'] == ['a', 'c', 'v']


def test_broken_links_are_ignored(out):
    b = out['broken']
    assert b['chain'] == 'x', 'an alt of an alt counts on its own'
    assert b['dangling'] == 'y', 'a main that is gone'
    assert b['alts'] == ['b', 'z'] and b['mains'] == ['a', 'c', 'v', 'x', 'y']


def test_attendance_adds_up_the_characters(out):
    assert out['attAnnaAlone'] == {'was': 2, 'late': 0, 'bench': 0, 'total': 5, 'rate': 0.4}
    # there as Anna, as Bob (late), Zed on the bench (counts as attended), missed, Anna on time
    # with Bob late (not late)
    assert out['attAnna'] == {'was': 4, 'late': 1, 'bench': 1, 'total': 5, 'rate': 0.8}
    assert out['attBob'] == {'was': 2, 'late': 2, 'bench': 0, 'total': 5, 'rate': 0.4}, 'a character alone as before'
    assert out['missed'] == [False, False, True]


def test_the_grid_cells(out):
    m = out['marks']
    assert m[0]['won'] and m[0]['as'] == 'a' and not m[0]['late']
    assert m[1]['won'] and m[1]['late'] and m[1]['as'] == 'b' and m[1]['when'] == 1759430000, 'won as the alt, late'
    assert not m[2]['here'] and m[2]['bench']['note'] == 'voll' and m[2]['as'] == 'z', 'the alt on the bench'
    assert not m[3]['here'] and m[3]['bench'] is None and m[3]['as'] is None, 'missed'
    assert m[4]['here'] and not m[4]['late'] and m[4]['as'] == 'a', 'one character on time is on time'


def test_the_awards_of_a_player(out):
    assert out['awardsOfGroup'] == ['w2', 'w1'], 'oldest first, both characters'
    assert out['awardsOfGroupZone'] == ['w1']


def test_unlinking_loses_nothing(out):
    u = out['unlinked']
    assert u['main'] == 'b'
    assert u['anna'] == {'was': 3, 'late': 0, 'bench': 1, 'total': 5, 'rate': 0.6}
    assert u['bob'] == {'was': 2, 'late': 2, 'bench': 0, 'total': 5, 'rate': 0.4}


def test_removing_a_main_frees_its_alts(out):
    r = out['removed']
    assert r['raiders'] == ['b', 'z', 'c', 'v'] and r['mainB'] == 'b' and not r['hasMainField']
    assert r['awards'] == ['w1', 'w3'], "the alt keeps its loot, the main's goes with it"
    assert r['text'] == ''


def test_the_text_for_the_addon(out):
    assert out['text'].split('\n') == ['#AMISIA-ALTS 1 forever 2026-10-06', 'A Bob Anna', 'A Zed_Zorn Anna', '#END'], out['text']


def test_the_addon_reads_the_text_back(out):
    run = pytest.importorskip('run', reason='addon/tests/run.py needs lupa')
    lua = run.fresh('--[[preload\nSTUB.toc = 16001\n]]')
    parse = lua.eval('function(t) local res, why = NS.ParseAlts(t); return res, why end')
    res, why = parse(out['text'])
    assert res is not None, why
    assert res['n'] == 2 and res['skipped'] == 0 and res['date'] == '2026-10-06'
    assert [(e['alt'], e['main']) for e in res['list'].values()] == [('Bob', 'Anna'), ('Zed Zorn', 'Anna')]


def test_wishes_and_alts_in_one_paste(out):
    """The wishlist's "Copy for the addon" puts the alt block behind the wishes."""
    run = pytest.importorskip('run', reason='addon/tests/run.py needs lupa')
    lua = run.fresh('--[[preload\nSTUB.toc = 16001\n]]')
    imp = lua.eval('function(t) local text, ok = NS.ImportSiteText(t); return text, ok, NS.AltsInfo() and NS.AltsInfo().n or 0 end')
    text, ok, n = imp('#AMISIA-WL 1 forever 2026-10-06\nW 28830 3 Anna\n#END\n' + out['text'])
    assert ok and n == 2 and '1 Wunsch' in text and '2 Twinks' in text, text
    page = open(os.path.join(ROOT, 'index.html'), encoding='utf-8').read()
    assert "wishAddonText(WISHES) + (a ? '\\n' + a : '')" in page, 'the copy joins both blocks'
