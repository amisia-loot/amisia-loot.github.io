"""The Stats tab of the site (index.html).

tools/tests/site_stats.cjs cuts the statistics code out of the page and runs it on a small
ledger: one row per player with the characters of its alts added up, items won with the MS/OS/SR
split from the award note, attendance over the nights since the player was first seen (the bench
rule of the Attendance tab, nights taken out do not count), bosses seen, the longest streak, items
per week, the ranges (4 weeks, the phase since the newest raid first showed up, all), the class and
role filters, sorting and the hall of fame.
"""
import json
import os
import shutil
import subprocess

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DRIVER = os.path.join(ROOT, 'tools', 'tests', 'site_stats.cjs')


@pytest.fixture(scope='module')
def out():
    node = shutil.which('node') or os.path.expanduser('~/.local/node/bin/node')
    if not os.path.exists(node):
        pytest.skip('node is not installed')
    p = subprocess.run([node, DRIVER], stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=dict(os.environ, TZ='UTC'))
    assert p.returncode == 0, p.stderr.decode('utf-8', 'replace')
    return json.loads(p.stdout.decode('utf-8'))


def by_name(run):
    return {p['name']: p for p in run['players']}


def test_one_row_per_player_with_the_alts_added(out):
    p = by_name(out['all'])
    assert out['all']['nights'] == 4, 'the night taken out does not count'
    assert sorted(p) == ['Anna', 'Bob', 'Chorf', 'Dora'], 'Bobalt counts for Bob'
    bob = p['Bob']
    assert (bob['items'], bob['ms'], bob['os'], bob['sr']) == (3, 1, 1, 1)
    assert bob['chars'] == [{'name': 'Bob', 'items': 1, 'raids': 2}, {'name': 'Bobalt', 'items': 2, 'raids': 1}]


def test_attendance_since_first_seen(out):
    p = by_name(out['all'])
    a, b, c, d = p['Anna'], p['Bob'], p['Chorf'], p['Dora']
    assert (a['raids'], a['total'], a['late'], a['streak']) == (4, 4, 1, 4)
    assert a['rate'] == 1 and a['perRaid'] == 0.25 and a['last'] == '2026-08-27'
    assert (b['raids'], b['total'], b['late'], b['streak']) == (3, 4, 1, 3)
    assert (c['raids'], c['total'], c['streak']) == (2, 3, 1), 'Chorf from his first night on'
    assert (d['raids'], d['total'], d['bench']) == (2, 3, 1), 'the bench counts as attended by default'
    assert d['items'] == 0 and d['last'] is None and d['perRaid'] == 0


def test_the_bench_rule_of_the_attendance_tab(out):
    d = by_name(out['excused'])['Dora']
    assert (d['raids'], d['total'], d['bench']) == (1, 2, 1), 'excused: left out of the rate'
    d = by_name(out['missed'])['Dora']
    assert (d['raids'], d['total'], d['bench'], d['streak']) == (1, 3, 1, 1), 'missed: counted as missed'


def test_bosses_and_weeks(out):
    p = by_name(out['all'])
    assert p['Anna']['bosses'] == 3, 'a wipe is no boss seen'
    assert p['Bob']['bosses'] == 2, 'as Bob and as Bobalt'
    assert p['Dora']['bosses'] == 0
    assert len(p['Bob']['weeks']) == 8
    assert p['Bob']['weeks'][:3] == [0, 2, 1], 'newest week first'


def test_ranges(out):
    w4 = by_name(out['w4'])
    assert out['w4']['nights'] == 3
    assert (w4['Anna']['items'], w4['Anna']['raids'], w4['Anna']['total']) == (0, 3, 3)
    assert (w4['Bob']['items'], w4['Bob']['raids'], w4['Bob']['total']) == (3, 2, 3)
    assert out['phase']['phase'] == {'zone': 'hyjal', 'name': 'Mount Hyjal', 'from': '2026-09-26'}
    ph = by_name(out['phase'])
    assert out['phase']['nights'] == 2
    assert sorted(ph) == ['Anna', 'Bob', 'Chorf', 'Dora']
    assert (ph['Bob']['items'], ph['Bob']['raids'], ph['Bob']['total']) == (2, 1, 2)


def test_filters(out):
    assert [p['name'] for p in out['mage']['players']] == ['Bob']
    assert sorted(p['name'] for p in out['dps']['players']) == ['Bob', 'Dora']
    assert sorted(p['name'] for p in out['unknown']['players']) == ['Anna', 'Chorf']
    assert out['kinds'] == ['os', 'sr', 'ms', 'ms']


def test_sorting(out):
    s = out['sorted']
    assert s['items'] == 'Bob,Chorf,Anna,Dora'
    assert s['rate'] == 'Anna,Bob,Chorf,Dora', 'ties by name'
    assert s['name'] == 'Anna,Bob,Chorf,Dora' and s['nameDesc'] == 'Dora,Chorf,Bob,Anna'
    assert s['last'].startswith('Chorf') and s['last'].endswith('Dora'), 'no item sorts last'


def test_hall_of_fame(out):
    fame = {e['key']: e for e in out['fame']}
    assert fame['items']['name'] == 'Bob' and fame['items']['n'] == 3
    assert fame['rate']['name'] == 'Anna' and fame['rate']['n'] == 1
    assert fame['bosses']['name'] == 'Anna' and fame['bosses']['n'] == 3
    assert fame['streak']['name'] == 'Anna' and fame['streak']['n'] == 4
    w = fame['wanted']
    assert w['name'] == 'Chorf' and w['item'] == 1003 and w['n'] == 3, 'a fulfilled wish that three raiders had'
    assert 'Dragonspine Trophy' in w['text']
    assert 'upgrade' not in fame
    assert all(e['title'] and e['text'] for e in out['fame'])


def test_the_tab_renders(out):
    page = out['page']
    assert page['count'] == '4 players · 2 nights'
    assert 'Mount Hyjal first showed up' in page['hint']
    assert 'data-stsort="name"' in page['head'] and 'Player ▲' in page['head'], 'sorted by name, A to Z'
    body = page['body']
    assert body.index('>Anna<') < body.index('>Bob<') < body.index('>Chorf<'), 'rows by name'
    assert 'class="stdetail"' in body and body.count('class="stwk"') == 8, "Bob's weeks are open"
    assert 'Bobalt: 2 items, 1 night' in body, 'the split per character'
    assert 'Most items' in page['fame'] and 'Longest streak' in page['fame']
    assert '<option>Mage</option>' in page['classes'] and '<option>Warrior</option>' in page['classes']
    assert '>Chorf<' in out['pageWarrior'] and '>Bob<' not in out['pageWarrior'], 'the class filter'


def test_an_empty_ledger(out):
    assert out['empty'] == {'nights': 0, 'phase': None, 'players': []}
    assert out['emptyFame'] == []


def test_the_tab_is_on_the_page():
    with open(os.path.join(ROOT, 'index.html'), encoding='utf-8') as fh:
        page = fh.read()
    assert 'data-view="stats"' in page and 'id="view-stats"' in page
    assert "if (ui.view === 'stats') renderStats();" in page
