"""Wishes between the Amisia addon and the site's Wishlist tab (index.html).

tools/tests/site_wishes.cjs cuts the wishlist code out of the page: amParseWishes reads the WL
lines of the addon's "Für die Website" text, wishImportPlan decides what "Paste from the addon"
adds, and wishAddonText writes the text for the addon. That text goes through the addon's own
parser (ns.ParseGuildWishes, under the Lua stub of addon/tests) and must come out the same.
"""
import json
import os
import shutil
import subprocess
import sys

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DRIVER = os.path.join(ROOT, 'tools', 'tests', 'site_wishes.cjs')
sys.path.insert(0, os.path.join(ROOT, 'addon', 'tests'))


@pytest.fixture(scope='module')
def out():
    node = shutil.which('node')
    if not node:
        pytest.skip('node is not installed')
    p = subprocess.run([node, DRIVER], stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=dict(os.environ, TZ='UTC'))
    assert p.returncode == 0, p.stderr.decode('utf-8', 'replace')
    return json.loads(p.stdout.decode('utf-8'))


def test_the_wish_lines_are_read(out):
    w = out['wishes']
    assert [(x['item'], x['prio'], x['at'], x['name']) for x in w] == [
        (28830, 3, 1759601000, 'Vulo Sturmwind'), (29434, 1, 1759601100, 'Vulo Sturmwind'),
        (30000, 2, 1759601200, 'Vulo Sturmwind'), (33000, 2, 1759601500, 'Vulo Sturmwind')], w
    assert w[0]['note'] == 'nur MS, bitte' and w[1]['note'] == ''
    assert len(w[3]['note']) == 80, 'a note is cut to 80 characters'


def test_broken_wish_lines_are_ignored(out):
    items = [x['item'] for x in out['wishes']]
    assert 31000 not in items, 'no name'
    assert 32000 not in items, 'no time'
    assert out['wishes'][2]['prio'] == 2, 'a priority out of range is medium'


def test_the_raid_import_ignores_wishes_and_the_wish_import_raids(out):
    assert out['blocks'] == 2 and out['rest'] == '', 'both blocks are cut out of the paste'
    assert len(out['raid']) == 1 and out['raid'][0]['zone'] == 'Karazhan'
    assert out['raid'][0]['loot'] == [{'name': 'Vuloo', 'item': 22450, 'count': 2}]
    assert out['raidOfWishes'] == [], 'a wishlist holds no raid'
    assert out['wishesOfRaid'] == [], 'a raid export holds no wishes'


def test_the_import_plan(out):
    plan = [(p['item'], p['name'], p['status'], p['raider']) for p in out['plan']]
    assert plan == [
        (28830, 'Anna', 'dup', 'a'),
        (29434, 'Bob', 'new', 'b'),
        (30000, 'Bob', 'got', 'b'),
        (99999, 'Anna', 'noitem', 'a'),
        (30001, 'Zed', 'noraider', None),
        (30001, 'anna', 'new', 'a'),
        (30001, 'Anna', 'dup', 'a'),
        (28830, 'Full', 'new', 'f'),
        (29434, 'Full', 'limit', 'f'),
    ], plan
    new = [p for p in out['plan'] if p['status'] == 'new']
    assert [p['boss'] for p in new] == ['Gruul', 'Netherspite', 'Prince Malchezaar'], 'the first source of the item'
    assert new[0]['note'] == 'only MS' and new[0]['prio'] == 2


def test_forever_full_names_find_a_raider_by_first_name(out):
    assert out['planNames'] == [
        ['Bob Baumann', 'b', 'new'],
        ['Vulo Sturmwind', 'v', 'new'],
        ['Kim Eisherz', 'k2', 'new'],
        ['Kim Feuerherz', 'k', 'new'],
        ['Zed Zorn', None, 'noraider'],
    ], out['planNames']


def test_the_text_for_the_addon(out):
    assert out['text'].split('\n') == [
        '#AMISIA-WL 1 tbc 2026-10-05',
        'W 28830 3 Bob nur MS',
        'W 28830 2 Anna',
        'W 29434 2 Alt_Name',
        'W 30001 1 Vulo_Sturmwind nach dem Boss',
        '#END',
    ], out['text']
    assert out['textForever'].split('\n') == ['#AMISIA-WL 1 forever 2026-10-05', 'W 18832 3 Anna', '#END']
    assert out['empty'].split('\n') == ['#AMISIA-WL 1 tbc 2026-10-05', '#END']


def as_game(text, game):
    """The site's text with the game of its head line set (the addon reads only WoW Forever lists)."""
    head, sep, rest = text.partition('\n')
    parts = head.split(' ')
    assert parts[:2] == ['#AMISIA-WL', '1'] and len(parts) == 4, head
    parts[2] = game
    return ' '.join(parts) + sep + rest


def parse_in_addon(text):
    run = pytest.importorskip('run', reason='addon/tests/run.py needs lupa')
    lua = run.fresh('')
    parse = lua.eval('function(t) local res, why = NS.ParseGuildWishes(t); return res, why end')
    res, why = parse(text)
    if res is None:
        return None, why
    out = {}
    for item_id, entries in res['list'].items():
        out[int(item_id)] = [(e['name'], e['prio'], e['note']) for e in entries.values()]
    return {'game': res['game'], 'date': res['date'], 'n': res['n'], 'skipped': res['skipped'], 'list': out}, None


def test_the_addon_reads_the_text_back(out):
    res, why = parse_in_addon(as_game(out['text'], 'forever'))
    assert res, why
    assert res['game'] == 'forever' and res['date'] == '2026-10-05' and res['n'] == 4 and res['skipped'] == 0
    assert res['list'] == {
        28830: [('Bob', 3, 'nur MS'), ('Anna', 2, '')],
        29434: [('Alt Name', 2, '')],
        30001: [('Vulo Sturmwind', 1, 'nach dem Boss')],
    }, res['list']


def test_the_addon_refuses_the_other_game(out):
    # the addon is WoW Forever only: a TBC list is refused in words, a Forever list is read
    res, why = parse_in_addon(as_game(out['textForever'], 'tbc'))
    assert res is None and why == 'Diese Wunschliste ist für TBC Anniversary, du bist in WoW Forever.', why
    res, why = parse_in_addon(out['textForever'])
    assert res and res['list'] == {18832: [('Anna', 3, '')]}
    res, why = parse_in_addon(as_game(out['empty'], 'forever'))
    assert res is None and why == 'Die Liste ist leer.'
