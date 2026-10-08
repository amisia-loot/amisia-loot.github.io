"""Loot council priority lists on the site (index.html) and their way to and from the Amisia addon.

tools/tests/site_prio.cjs cuts the loot council code out of the page: the prio token, the order as
an officer types it, the "#AMISIA-LC" text behind the wishes and alts, and the "LC" lines of the
addon's export taken over into the ledger. The texts go through the addon's own parsers both ways:
the site's block through ns.ParseLootPrio, an export the addon wrote through the site's amParsePrio,
and back, so the addon drops its in-game edits once the site has them.
"""
import json
import re
import os
import shutil
import subprocess
import sys

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DRIVER = os.path.join(ROOT, 'tools', 'tests', 'site_prio.cjs')
sys.path.insert(0, os.path.join(ROOT, 'addon', 'tests'))


def node():
    n = shutil.which('node') or os.path.expanduser('~/.local/node/bin/node')
    if not os.path.exists(n):
        pytest.skip('node is not installed')
    return n


def drive(export=None):
    p = subprocess.run([node(), DRIVER], input=json.dumps({'export': export}).encode('utf-8'), stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE, env=dict(os.environ, TZ='UTC'))
    assert p.returncode == 0, p.stderr.decode('utf-8', 'replace')
    return json.loads(p.stdout.decode('utf-8'))


def addon():
    run = pytest.importorskip('run', reason='addon/tests/run.py needs lupa')
    return run.fresh('--[[preload\nSTUB.toc = 16001\n]]')


@pytest.fixture(scope='module')
def out():
    return drive()


def test_the_token(out):
    t = out['token']
    assert t['entries'] == [{'k': 'p', 'name': 'Anna', 'label': 'Tank'}, {'k': 'c', 'cls': 'WARRIOR', 'label': 'Furor'}, {'k': 'o'},
                            {'k': 'p', 'name': 'Vulo Sturmwind'}]
    assert t['back'] == 'p:Anna:Tank,c:WARRIOR:Furor,o,p:Vulo_Sturmwind'
    assert t['text'] == '1. Anna (Tank), 2. Warrior Furor, 3. open, 4. Vulo Sturmwind'
    assert t['empty'] == []
    assert t['bad'] == [None] * 7, 'a digit, an unknown class or kind, nothing, a long label, eleven places, no colon'


def test_the_order_as_typed(out):
    assert out['free'] == [
        {'token': 'p:Anna:Tank,c:WARRIOR:Furor,o'},
        {'token': 'p:Vulo_Sturmwind:Heal,c:WARRIOR,c:DEATHKNIGHT:Frost,o'},
        {'error': 'Not recognised: X1'},
        {'token': '-'},
        {'error': 'Not recognised: Anna (Tank'},
        {'error': 'Not recognised: Anna (' + 'x' * 20 + ')'},
    ], out['free']


def test_the_text_for_the_addon(out):
    assert out['none']['text'] == '' and out['none']['copy'] == '#AMISIA-WL 1 forever 2026-10-07\nW 32235 3 Anna\n#END', 'nothing new without a prio'
    assert out['shown'] == [True, True, False, False], 'a cleared item is not shown'
    assert out['text'].split('\n') == [
        '#AMISIA-LC 1 forever 2026-10-07',
        'C 30001 1788000200 -',
        'C 32235 1788000000 p:Anna:Tank,c:WARRIOR:Furor,o Erst Tanks dann DPS',
        'C 32837 1788000100 p:Vulo_Sturmwind',
        '#END',
    ], out['text']
    assert out['copy'].split('\n#END\n') == ['#AMISIA-WL 1 forever 2026-10-07\nW 32235 3 Anna', '#AMISIA-ALTS 1 forever 2026-10-07\nA Bob Anna',
                                            out['text'][:-len('\n#END')] + '\n#END'], 'one paste: wishes, alts, prio'


def test_the_addon_reads_the_site_text(out):
    lua = addon()
    imp = lua.eval('function(t) local text, ok = NS.ImportSiteText(t); local p = NS.LootPrioOf(32235); '
                   'return text, ok, p and NS.PrioTokenOf(p.prio), p and p.note, NS.LootPrioOf(30001) == nil, NS.LootPrioInfo().n end')
    text, ok, tok, note, cleared, n = imp(out['copy'])
    assert ok and '1 Wunsch' in text and '1 Twink' in text and '3 Items mit Prio' in text, text
    assert tok == 'p:Anna:Tank,c:WARRIOR:Furor,o' and note == 'Erst Tanks dann DPS' and cleared and n == 3


def test_the_edits_made_in_game_reach_the_site_and_come_back():
    lua = addon()
    export = lua.eval('''function()
        NS.SetLootPrio("#AMISIA-LC 1 forever 2026-10-07\\nC 32235 1788000000 p:Anna:Tank,o\\nC 32837 1788000100 p:Bob\\n#END")
        STUB.now = 1788100000
        NS.EditLootPrio(32235, "Chorf (Tank), Krieger Furor, offen", "neu | verteilt")
        NS.ClearLootPrioItem(32837)
        NS.EditLootPrio(40000, "Anna", "")
        return NS.ExportText({})
    end''')()
    assert export.count('\nLC ') == 3, export
    out = drive(export)
    p = out['parsed']
    assert p['bad'] == 0
    assert [(r['item'], r['at'], r['by']) for r in p['rows']] == [(32235, 1788100000, 'Vuloo'), (32837, 1788100000, 'Vuloo'),
                                                                    (40000, 1788100000, 'Vuloo')], p['rows']
    assert p['rows'][0]['note'] == 'neu verteilt' and p['rows'][1]['prio'] == [] and p['rows'][1]['note'] == ''
    # the ledger of the driver holds 32235 and 32837 from before (older): both change, 40000 is new
    assert out['plan'] == [[32235, 'change'], [32837, 'change'], [40000, 'new']]
    assert out['applied'] == 3 and out['again'] == [[32235, 'same'], [32837, 'same'], [40000, 'same']]
    assert out['older'] == ['older']
    lines = out['afterText'].split('\n')
    assert 'C 32235 1788100000 p:Chorf:Tank,c:WARRIOR:Furor,o neu verteilt' in lines and 'C 32837 1788100000 -' in lines, lines
    # pasted back into the addon, the edits are done
    back = lua.eval('function(t) local res, why = NS.SetLootPrio(t); return res ~= nil, why, NS.LootPrioPending(), '
                    'NS.LootPrioOf(32837) == nil, NS.PrioTokenOf(NS.LootPrioOf(40000).prio) end')
    ok, why, pending, cleared, tok = back(out['afterText'])
    assert ok, why
    assert pending == 0 and cleared and tok == 'p:Anna'


def test_broken_export_lines(out):
    b = out['bad']
    assert b['bad'] == 3 and [r['item'] for r in b['rows']] == [6] and b['rows'][0]['note'] == 'fine'


def test_a_time_far_ahead_is_refused(out):
    f = out['future']
    assert f['bad'] == 1 and [r['item'] for r in f['rows']] == [8], 'more than a day ahead: refused; an hour: taken'


def test_a_name_counts_bytes_like_the_addon(out):
    assert out['nameBytes'] == ['Ä' * 24, None], '48 bytes at most (UTF-8), as NAME_MAX in the addon'


def test_the_text_of_a_damaged_list(out):
    assert out['textOfObject'] == '', 'a prio that is no list shows nothing and throws nothing'


def test_the_page_wires_it_up():
    page = open(os.path.join(ROOT, 'index.html'), encoding='utf-8').read()
    assert 'data-view="prio"' in page and 'id="view-prio"' in page
    assert "'dropZones', 'lootPrio', 'points'];" in page, 'kept per game'
    assert "if (ui.view === 'prio') renderPrio();" in page
    assert "amPrio = lc && (lc.rows.length || lc.bad)" in page, 'the import reads the LC lines'


@pytest.fixture(scope='module')
def page():
    """The whole page script against a fake DOM (tools/tests/site_prio_page.cjs)."""
    p = subprocess.run([node(), os.path.join(ROOT, 'tools', 'tests', 'site_prio_page.cjs')], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                       env=dict(os.environ, TZ='UTC'))
    assert p.returncode == 0, p.stderr.decode('utf-8', 'replace')
    return json.loads(p.stdout.decode('utf-8'))


def test_the_tab_sets_and_edits_a_prio(page):
    assert page['empty']
    s = page['saved']
    assert s['prio'] == [{'k': 'p', 'name': 'Anna', 'label': 'Tank'}, {'k': 'c', 'cls': 'WARRIOR', 'label': 'Furor'}, {'k': 'o'}]
    assert s['note'] == 'erst Tanks' and s['at'] > 1788000000
    assert page['toast'] == 'Saved the prio of Item 32235.' and page['count'] == '1 of 1 items'
    assert '1. Anna (Tank)' in page['row'] and '2. Warrior Furor' in page['row'] and '3. open' in page['row'] and 'data-lcedit="32235"' in page['row']
    assert page['refused'] == 'Not recognised: X1', 'a broken order changes nothing'
    assert page['form'] == ['32235', 'Anna (Tank), Warrior Furor, open', 'erst Tanks'], 'Edit fills the form again'
    # the page stamps today's date into the block
    assert re.search(r'#AMISIA-LC 1 forever \d{4}-\d{2}-\d{2}\nC 32235 %d p:Anna:Tank,c:WARRIOR:Furor,o erst Tanks\n#END$' % s['at'], page['text']), page['text']
    assert page['readOnly'] == {'side': True, 'edit': False}, 'viewers only read'


def test_the_import_tab_takes_the_changes_made_in_game(page):
    p = page['importPanel']
    assert not p['hidden'] and not p['disabled']
    assert p['text'].startswith('This text holds 2 items whose loot prio an officer changed in game: 2 to take over. 1 line could not be read.')
    i = page['imported']
    assert i['a']['prio'] == [{'k': 'p', 'name': 'Chorf', 'label': 'Tank'}, {'k': 'o'}] and i['a']['note'] == 'neu' and i['a']['at'] == 1891000000
    assert i['a']['by'] == 'Vulo Sturmwind' and i['b']['prio'] == [{'k': 'p', 'name': 'Bob'}]
    assert i['toast'] == 'Took over the loot prio of 2 items.' and i['panel']
    assert page['again']['disabled'] and '0 to take over, 2 already in the ledger' in page['again']['text']
    assert page['backupHas'], 'a backup carries the prio'
    assert page['damaged'], 'a prio that is no list does not break the tab'
