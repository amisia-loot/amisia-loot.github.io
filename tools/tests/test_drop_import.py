"""The guild's drop records on the site (index.html): the addon's text "Drops für die Website" goes
into the Import tab, its kills into the ledger field dropObs (per game), and the Loot Tables tab
shows per dungeon and raid the bosses with "Kills seen by the guild" and per item "9 of 41 (22 %)".

tools/tests/site_drops.cjs cuts the drop code out of the page: amParseDrops reads DZ/DN/DK,
dropPlan and dropImport merge kills by id (items at their largest count, the smaller origin, names
only where none is known; importing twice changes nothing), dropTables counts the observations of
data/forever.js up to its day (obsThrough) and the imported kills after it, so nothing counts twice;
a raid without a zone in data/forever.js appears from its first imported kill.
"""
import json
import os
import re
import shutil
import subprocess
import sys

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DRIVER = os.path.join(ROOT, 'tools', 'tests', 'site_drops.cjs')


def page():
    with open(os.path.join(ROOT, 'index.html'), encoding='utf-8') as fh:
        return fh.read()


@pytest.fixture(scope='module')
def out():
    node = shutil.which('node')
    if not node:
        pytest.skip('node is not installed')
    p = subprocess.run([node, DRIVER], stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=dict(os.environ, TZ='UTC'))
    assert p.returncode == 0, p.stderr.decode('utf-8', 'replace')
    return json.loads(p.stdout.decode('utf-8'))


def test_days_count_from_the_first_of_january_2026(out):
    d = out['days']
    assert (d['first'], d['oct5'], d['next']) == (0, 277, 365)
    assert d['bad'] == [None, None, None]
    assert d['back'] == '2026-10-05'


def test_the_drop_lines_are_read(out):
    p = out['parsed']
    assert p['zones'] == {'2834': ['party', 'Halle der Thane'], '409': ['raid', 'Geschmolzener Kern']}
    assert p['names'] == {'213450': 'Faldrim Ambossmahl', '213470': 'Kurgor der Wächter'}
    kills = {k['h']: k for k in p['kills']}
    assert [k['h'] for k in p['kills']] == ['a0000001', 'a0000002', 'a0000003', 'a0000004']
    assert kills['a0000001'] == {'h': 'a0000001', 'npc': 213450, 'inst': 2834, 'diff': 1, 'day': 277, 'o': '00000001',
                                 'src': 'G', 'items': {'219004': 3, '219006': 2}}, 'the same kill twice in one text is one'
    assert kills['a0000002']['items'] == {} and kills['a0000002']['day'] == 276
    assert kills['a0000003']['diff'] == 9 and kills['a0000003']['inst'] == 409 and kills['a0000003']['day'] == 278
    assert kills['a0000004']['npc'] == 0 and kills['a0000004']['src'] == 'E'
    assert p['bad'] == 7, 'a zone of a battleground and six broken kill lines are counted and skipped'
    assert out['parsedNone'] == {'kills': [], 'names': {}, 'zones': {}, 'bad': 0}, 'other lines are not drop lines'


def test_the_plan_and_the_import(out):
    assert out['plan1'] == {'n': 4, 'fresh': 4, 'changed': 0, 'names': 4, 'bad': 7}
    assert out['import1'] == {'added': 4, 'merged': 0, 'names': 4}
    s = out['state1']
    assert s['dropObs'] == [
        ['a0000001', 213450, 2834, 1, 277, '00000001', 'G', [219004, 3, 219006, 2]],
        ['a0000002', 213450, 2834, 1, 276, '11111111', 'G', []],
        ['a0000003', 213470, 409, 9, 278, '3fa9c2e1', 'G', [219005, 1]],
        ['a0000004', 0, 2834, 1, 277, '3fa9c2e1', 'E', [219006, 1]],
    ], 'compact: id, NPC, instance, difficulty, day, origin, source, item and count pairs'
    assert s['dropNames'] == {'213450': 'Faldrim Ambossmahl', '213470': 'Kurgor der Wächter'}
    assert s['dropZones'] == {'2834': ['party', 'Halle der Thane'], '409': ['raid', 'Geschmolzener Kern']}


def test_importing_twice_changes_nothing(out):
    assert out['plan2'] == {'n': 4, 'fresh': 0, 'changed': 0, 'names': 0, 'bad': 7}
    assert out['import2'] == {'added': 0, 'merged': 0, 'names': 0}
    assert out['state2'] == out['state1']


def test_the_same_kill_from_someone_else_is_merged(out):
    assert out['plan3'] == {'n': 2, 'fresh': 1, 'changed': 1, 'names': 1, 'bad': 0}
    assert out['import3'] == {'added': 1, 'merged': 1, 'names': 1}
    s = out['state3']
    recs = {r[0]: r for r in s['dropObs']}
    assert recs['a0000001'] == ['a0000001', 213450, 2834, 1, 277, '00000001', 'G', [219004, 3, 219006, 2, 219007, 1]], \
        'items at their largest count, the smaller origin stays'
    assert recs['b0000001'] == ['b0000001', 213480, 2834, 1, 278, '00000002', 'G', [219008, 1]]
    assert s['dropNames']['213450'] == 'Faldrim Ambossmahl', 'a known name is not overwritten'
    assert s['dropNames']['213480'] == 'Neuer Boss'
    assert s['dropZones']['2834'] == ['party', 'Halle der Thane']
    assert out['orderFree'], 'the order of two imports does not matter'


def test_no_player_names_in_the_ledger(out):
    s = out['state3']
    for r in s['dropObs']:
        strings = [x for x in r if isinstance(x, str)]
        assert len(strings) == 3 and re.fullmatch(r'[0-9a-f]{8}', strings[0]) and re.fullmatch(r'[0-9a-f]{8}', strings[1])
        assert strings[2] in ('G', 'E')
    text = json.dumps(s)
    for name in ('Vulo', 'Sturmwind', 'Fraktur'):
        assert name not in text, name


def test_broken_records_from_a_backup_are_dropped(out):
    assert out['import4'] == {'added': 4, 'merged': 0, 'names': 4}
    s = out['state4']
    assert [r[0] for r in s['dropObs']] == ['a0000001', 'a0000002', 'a0000003', 'a0000004']
    assert isinstance(s['dropNames'], dict) and isinstance(s['dropZones'], dict)


def test_the_loot_tables_count_each_kill_once(out):
    t = out['tables']
    assert [z['key'] for z in t] == ['thanes', 'i409'], 'the zones of data/forever.js first, then the new ones'
    thanes, raid = t
    assert thanes['name'] == 'Halle der Thane' and thanes['kind'] == 'party' and thanes['known'] is True
    assert [b['name'] for b in thanes['bosses']] == ['Faldrim Ambossmahl', 'Neuer Boss']
    faldrim, neu = thanes['bosses']
    # 40 kills in data/forever.js up to day 277; the imported kills of day 277 and before are in them
    assert faldrim['kills'] == 40 and faldrim['npc'] == 213450
    assert [(i['id'], i['n']) for i in faldrim['items']] == [(219004, 8), (219006, 3), (219009, 0)], \
        'observed items by count, then the items of the boss table in data/forever.js'
    assert faldrim['items'][0]['name'] == 'Ring der Thane' and faldrim['items'][0]['rate'] == '8 of 40 (20 %)'
    assert faldrim['items'][2]['rate'] == '0 of 40 (0 %)'
    assert neu['kills'] == 1 and neu['items'] == [{'id': 219008, 'name': 'Item 219008', 'n': 1, 'rate': '1 of 1'}]
    assert thanes['kills'] == 41
    # the raid nobody listed: from its first imported kill, named by the addon's DZ line
    assert raid['name'] == 'Geschmolzener Kern' and raid['kind'] == 'raid' and raid['known'] is False and raid['inst'] == 409
    assert raid['bosses'][0]['name'] == 'Kurgor der Wächter' and raid['bosses'][0]['kills'] == 1
    assert raid['bosses'][0]['items'][0]['name'] == 'Umhang der Thane', 'named from the observed items of data/forever.js'


def test_without_a_base_every_imported_kill_counts(out):
    t = out['tablesNoBase']
    assert [z['name'] for z in t] == ['Geschmolzener Kern', 'Halle der Thane']
    thanes = t[1]
    faldrim = [b for b in thanes['bosses'] if b['npc'] == 213450][0]
    assert faldrim['kills'] == 2, 'two kills, the fallback record (no NPC) counts nowhere'
    assert {i['id']: i['n'] for i in faldrim['items']} == {219004: 1, 219006: 1, 219007: 1}, 'kills with the item, not pieces'
    assert out['tablesEmpty'] == []


def test_the_rate_text(out):
    assert out['rates'] == ['9 of 41 (22 %)', '2 of 3', '0 of 40 (0 %)', '5 of 5 (100 %)']


def test_the_download_for_build_scan(out):
    d = out['download']
    assert d['v'] == 1 and len(d['k']) == 5 and d['names']['213480'] == 'Neuer Boss' and d['zones']['409'] == ['raid', 'Geschmolzener Kern']


def test_hostile_names_are_just_names(out):
    h = out['hostile']
    for name in ('constructor', 'toString', '__proto__', 'hasOwnProperty', 'valueOf'):
        assert h[name] == [[name, [[name, 2]]]], (name, h[name])


def test_a_kill_on_both_sides_of_midnight_counts_once(out):
    assert out['midnight'] == [['Faldrim', 1, '1 of 1']], 'the id of the base\'s last day is not counted again'
    assert out['midnightDay'] == [276] and out['midnightParse'] == [276], 'the earlier day'


def test_a_kill_after_tomorrow_is_not_read(out):
    assert out['future']['kills'] == [] and out['future']['bad'] == 1


def test_the_tab_escapes_names_and_draws_items_without_a_link(out):
    p = out['page']
    assert '<img' not in p['body'] and '&lt;img src=x onerror=alert(1)&gt;' in p['body'], 'a boss name from the addon is escaped'
    assert 'Zone &quot;&lt;b&gt;&quot;' in p['body'] and '&lt;i&gt;Item&lt;/i&gt;' in p['body']
    assert '<b>' not in p['zones'] and '&lt;b&gt;' in p['zones']
    assert 'link="false"' in p['body'] and 'link="undefined"' not in p['body']
    assert 'Kills seen by the guild: 1' in p['body'] and '1 of 1' in p['body']
    assert 'Drop rates are counted from loot windows guild members opened; they are observations, not official chances.' in p['body']
    assert p['count'] == '1 boss · 1 kill'
    assert p['download'] is False and p['downloadViewer'] is True, 'the download is for editors'
    assert 'No boss kills yet' in p['empty']


def test_the_page_wires_it_up():
    src = page()
    assert '<button class="tab" role="tab" data-view="drops">Loot Tables</button>' in src
    assert 'id="view-drops"' in src
    m = re.search(r"const PER_GAME = \[([^\]]*)\]", src)
    assert all("'%s'" % k in m.group(1) for k in ('dropObs', 'dropNames', 'dropZones')), 'kept per game'
    assert "'drops'" not in src[src.index('const ARCHIVE_TABS'):src.index('\n', src.index('const ARCHIVE_TABS'))], \
        'the TBC archive has no drop tables'
    # a backup restore checks the types of the new fields
    restore = src[src.index("$('#importBtn').addEventListener"):]
    restore = restore[:restore.index('\n});')]
    assert 'dropObs:Array.isArray(d.dropObs)?d.dropObs:[]' in restore
    assert "dropNames:d.dropNames&&typeof d.dropNames==='object'&&!Array.isArray(d.dropNames)?d.dropNames:{}" in restore
    assert "dropZones:d.dropZones&&typeof d.dropZones==='object'&&!Array.isArray(d.dropZones)?d.dropZones:{}" in restore
    for text in ('This text holds ', ' boss kill', 'seen by the guild', 'Add the kills', 'Download observations',
                 'Drop rates are counted from loot windows guild members opened; they are observations, not official chances.',
                 'Kills seen by the guild: '):
        assert text in src, text


def test_the_tables_escape_what_they_show():
    src = page()
    i = src.index('function renderDrops(')
    body = src[i:src.index('\n}', i)]
    # every name from the data or the ledger goes through esc(); items without a link
    for part in ('esc(z.name)', 'esc(b.name)', 'esc(i.name)', 'esc(i.rate)'):
        assert part in body, part
    assert 'icoHTML(' in body and ",0,false)" in body.replace(' ', ''), 'observation rows draw items without a link'
    assert 'wowhead' not in body.lower()


def test_the_twin_still_builds(tmp_path):
    out_file, data = tmp_path / 'twin.html', tmp_path / 'data.json'
    data.write_text('{}', encoding='utf-8')
    p = subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'build_twin.py'), str(out_file), str(data)],
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    assert p.returncode == 0, p.stderr.decode('utf-8', 'replace')
    twin = out_file.read_text(encoding='utf-8')
    assert 'function dropTables(' in twin and 'id="view-drops"' in twin, 'the loot tables stay in the twin'
