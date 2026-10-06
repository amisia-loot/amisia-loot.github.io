import json
import os
import sys
import textwrap

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
import build_scan as b  # noqa: E402

SV = textwrap.dedent(r'''
AmisiaDB = {
  ["scan"] = { ["items"] = {
    [32235] = "Cursed Vision of Sargeras\t4\t141\t70\t4\t1\tINVTYPE_HEAD\t134\t1",
    [32837] = "Warglaive\t5\t156\t70\t2\t7\tINVTYPE_WEAPONMAINHAND\t135\t1",
    [30000] = "Pattern: Thing\t3\t70\t70\t9\t2\t\t136\t0",
    [31000] = "World Drop Cloak\t4\t120\t70\t4\t1\tINVTYPE_CLOAK\t137\t2",
  },
  ["sources"] = {
    [31000] = { "Drop: Fel Reaver", "Haendler: Thrallmar Quartermaster" },
    [32235] = { "Quest: The Fall of the Betrayer" },
    [39999] = { "Auktionshaus" },
  } },
  ["itemNames"] = { [40000] = { ["n"] = "Only Seen", ["q"] = 4 } },
  ["sessions"] = {
    { ["zone"] = "Black Temple", ["instanceID"] = 564, ["date"] = "2026-09-19",
      ["drops"] = {
        ["Creature-1"] = { ["src"] = "Illidan Stormrage", ["items"] = { [32235] = 1, [32837] = 1 } },
        ["Creature-2"] = { ["src"] = "Ashtongue Guard", ["items"] = { [32235] = 1, [30000] = 2 } },
        ["Creature-3"] = { ["src"] = "?", ["items"] = { [40000] = 1 } },
      } },
    { ["zone"] = "New Raid", ["instanceID"] = 999, ["date"] = "2026-09-20",
      ["drops"] = { ["Creature-9"] = { ["src"] = "Old Name", ["items"] = { [32837] = 1 } } } },
  },
}
''')


def test_pipeline(tmp_path):
    p = tmp_path / 'Amisia.lua'
    p.write_text(SV, encoding='utf-8')
    db = b.load_sv(str(p))
    items, sessions, collected = b.collect([db])
    assert items[32235]['name'] == 'Cursed Vision of Sargeras' and items[32235]['q'] == 4
    assert collected[31000] == ['Drop: Fel Reaver', 'Haendler: Thrallmar Quartermaster']
    assert items[40000]['name'] == 'Only Seen', 'names from the export fallback'
    assert len(sessions) == 2 and len(sessions[0]['drops']) == 5
    zones_cfg = {'Black Temple': {'key': 'bt', 'short': 'BT', 'color': ['#c26a4a', '#a6482a']}}
    bosses_cfg = {'Ashtongue Guard': 'trash', 'Old Name': 'New Name'}
    zones, bosses, warn = b.zones_and_bosses(sessions, zones_cfg, bosses_cfg)
    assert [z['key'] for z in zones] == ['bt', 'newraid']
    assert [x['name'] for x in bosses] == ['Illidan Stormrage', 'New Name', 'Trash (Black Temple)']
    assert any('unknown zone "New Raid"' in w for w in warn)
    assert any('"Illidan Stormrage"' in w for w in warn), 'unlisted sources are reported'
    out = b.build_items(items, sessions, bosses, zones, bosses_cfg)
    byid = {i['id']: i for i in out}
    assert byid[32235]['slot'] == 'head' and byid[32235]['sources'] == ['Illidan Stormrage', 'Trash (Black Temple)']
    assert byid[32837]['slot'] == 'weapon' and byid[32837]['sources'] == ['Illidan Stormrage', 'New Name']
    assert byid[30000]['slot'] == 'recipe' and byid[30000]['sources'] == ['Trash (Black Temple)']
    assert byid[40000]['name'] == 'Only Seen' and byid[40000]['slot'] == 'other'
    assert byid[32235]['sub'] == 'Cloth' and byid[32235]['bind'] == 'BoP' and byid[32235]['lvl'] == 70
    assert byid[32837]['sub'] == 'Sword' and 'sub' not in byid[30000], 'a recipe has no armour or weapon type'
    assert b.add_field_sources(out, items, collected, zones, bosses) == 1
    field = {i['id']: i for i in out}[31000]
    assert field['sources'] == ['Fel Reaver'] and field['bind'] == 'BoE'
    assert zones[-1]['key'] == 'field' and bosses[-1] == {'name': 'Fel Reaver', 'zone': 'field'}
    b.add_via(out, collected)
    assert field['via'] == ['Haendler: Thrallmar Quartermaster'], 'the drop became a boss, the rest stays a note'
    assert byid[32235]['via'] == ['Quest: The Fall of the Betrayer']
    assert 'via' not in byid[32837]
    js = tmp_path / 'forever.js'
    b.write_js(str(js), zones, bosses, out, None)
    txt = js.read_text(encoding='utf-8')
    assert txt.startswith('window.__LOOT=window.__LOOT||{};window.__LOOT["forever"]=')
    data = json.loads(txt.split('=', 2)[2].rstrip(';\n'))
    assert data['zones'][0]['name'] == 'Black Temple' and len(data['items']) == 5 and 'sprite' not in data


def test_icon_names_keeps_names_and_caches(tmp_path, monkeypatch):
    cache = tmp_path / 'cache.json'
    calls = []

    def fake_fetch(url):
        calls.append(url)
        return b'<item><icon displayId="1">INV_Helmet_01</icon></item>'
    monkeypatch.setattr(b, 'fetch', fake_fetch)
    items = [{'id': 1, 'icon': '134'}, {'id': 2, 'icon': 'inv_sword_01'}, {'id': 1, 'icon': ''}]
    b.icon_names(items, str(cache), log=lambda *_: None)
    assert items[0]['icon'] == 'inv_helmet_01' and items[1]['icon'] == 'inv_sword_01' and items[2]['icon'] == 'inv_helmet_01'
    assert len(calls) == 1, 'second lookup of the same id comes from the cache'
    assert json.loads(cache.read_text())['1'] == 'inv_helmet_01'


def test_catalog_adds_awardable_items_without_drops(tmp_path):
    items = {
        1: {'name': 'Epic Helm', 'q': 4, 'ilvl': 30, 'min': 0, 'classID': 4, 'subclassID': 1, 'equipLoc': 'INVTYPE_HEAD', 'icon': '133076', 'bind': 1},
        2: {'name': 'Low Rare Ring', 'q': 3, 'ilvl': 40, 'min': 0, 'classID': 4, 'subclassID': 0, 'equipLoc': 'INVTYPE_FINGER', 'icon': '1', 'bind': 1},
        3: {'name': 'High Rare Ring', 'q': 3, 'ilvl': 63, 'min': 0, 'classID': 4, 'subclassID': 0, 'equipLoc': 'INVTYPE_FINGER', 'icon': '2', 'bind': 1},
        4: {'name': "Tigole's Boomstick (TEST)", 'q': 6, 'ilvl': 100, 'min': 0, 'classID': 2, 'subclassID': 3, 'equipLoc': 'INVTYPE_RANGED', 'icon': '3', 'bind': 1},
        5: {'name': 'Epic Gem', 'q': 4, 'ilvl': 70, 'min': 0, 'classID': 3, 'subclassID': 0, 'equipLoc': '', 'icon': '4', 'bind': 0},
        6: {'name': 'Already Dropped', 'q': 4, 'ilvl': 70, 'min': 0, 'classID': 4, 'subclassID': 1, 'equipLoc': 'INVTYPE_HEAD', 'icon': '5', 'bind': 1},
    }
    out = [{'id': 6, 'name': 'Already Dropped', 'slot': 'head', 'icon': '5', 'sources': ['Boss'], 'q': 4, 'ilvl': 70}]
    zones, bosses = [], [{'name': 'Boss', 'zone': 'z'}]
    n = b.add_catalog(out, items, zones, bosses, 60)
    assert n == 2 and sorted(i['id'] for i in out) == [1, 3, 6]
    assert all(i['sources'] == ['Unknown source'] for i in out if i['id'] != 6)
    assert zones[-1]['key'] == 'unknown' and bosses[-1] == {'name': 'Unknown source', 'zone': 'unknown'}
    assert b.add_catalog(out, items, [], [], 60) == 0, 'a second run adds nothing twice'


def test_fileid_names_from_listfile_and_cache(tmp_path):
    lf = tmp_path / 'listfile.csv'
    lf.write_text('133076;interface/icons/INV_Helmet_08.blp\n9;world/other.m2\n2;Interface/Icons/inv_ring_02.blp\n', encoding='utf-8')
    cache = tmp_path / 'fileids.json'
    items = [{'id': 1, 'icon': '133076'}, {'id': 2, 'icon': '2'}, {'id': 3, 'icon': '9'}, {'id': 4, 'icon': 'named'}]
    m = b.fileid_names(items, str(lf), str(cache))
    assert m == {'133076': 'inv_helmet_08', '2': 'inv_ring_02'}
    assert b.fileid_names(items, None, str(cache)) == m, 'works from the cache without the listfile'
    b.icon_names(items, cache_path=str(tmp_path / 'icons.json'), fileids=m, wowhead=False)
    assert [i['icon'] for i in items] == ['inv_helmet_08', 'inv_ring_02', '', 'named']


# ---------------------------------------------------------------- the guild's drop records
DROP_TEXT = '\n'.join([
    '#AMISIA 2 Vulo_Sturmwind',
    'DZ 2834 party Halle der Thane',
    'DZ 409 raid Geschmolzener Kern',
    'DN 213450 0 Faldrim Ambossmahl',
    'DN 213470 3012 Kurgor der Wächter',
    'DN 0 3020 Geheimer Boss',
    'DK a0000001 213450 2834 1 2026-10-05 3fa9c2e1 G 219004:1,219006:2',
    'DK a0000002 213450 2834 1 2026-10-04 11111111 G -',
    'DK a0000003 213470 409 9 2026-10-05 3fa9c2e1 G 219005:1',
    'DK a0000004 0 2834 1 2026-10-05 3fa9c2e1 E 219006:1',
    'DK a0000005 213450 2834 1 2026-13-05 3fa9c2e1 G -',
    'DK broken',
    '#END', ''])

SV_DROPS = textwrap.dedent(r'''
AmisiaDB = {
  ["scan"] = { ["items"] = {
    [219004] = "Ring der Thane\t3\t20\t15\t4\t0\tINVTYPE_FINGER\t133345\t1",
    [32235] = "Cursed Vision of Sargeras\t4\t141\t70\t4\t1\tINVTYPE_HEAD\t134\t1",
  } },
  ["sessions"] = {
    { ["zone"] = "Black Temple", ["instanceID"] = 564, ["date"] = "2026-09-19",
      ["drops"] = { ["Creature-1"] = { ["src"] = "Illidan Stormrage", ["items"] = { [32235] = 1 } } } },
  },
  ["drops"] = { ["v"] = 1, ["me"] = "00000001",
    ["k"] = {
      ["a0000001"] = { ["npc"] = 213450, ["inst"] = 2834, ["diff"] = 1, ["day"] = 277, ["o"] = "00000001",
                       ["it"] = { [219004] = 1, [219007] = 1 }, ["src"] = "G", ["mine"] = true },
      ["c0000001"] = { ["npc"] = 213450, ["inst"] = 2834, ["diff"] = 1, ["day"] = 270, ["o"] = "00000001",
                       ["it"] = {}, ["src"] = "G", ["mine"] = true },
      ["d0000001"] = { ["npc"] = 0, ["inst"] = 2834, ["diff"] = 1, ["day"] = 270, ["o"] = "00000001",
                       ["it"] = { [219006] = 1 }, ["src"] = "E", ["enc"] = 3020 },
      ["kaputt"] = { ["npc"] = 1 },
    },
    ["npc"] = { [213450] = "Faldrim" },
    ["inst"] = { [2834] = { "party", "Halle der Thane" } },
    ["enc"] = { [3020] = "Geheimer Boss" },
    ["peers"] = {},
  },
}
''')

SITE_OBS = {'v': 1, 'k': [['b0000001', 213480, 2834, 1, 278, '00000002', 'G', [219008, 1]],
                          ['a0000001', 213450, 2834, 1, 277, '00000002', 'G', [219004, 3]],
                          ['bad'], None],
            'names': {'213480': 'Neuer Boss', '213450': 'Faldrim Anvilmeal'}, 'zones': {'2834': ['party', 'Hall of Thanes']}}


def test_drop_days():
    assert b.drop_day('2026-01-01') == 0 and b.drop_day('2026-10-05') == 277 and b.drop_day('2027-01-01') == 365
    assert b.drop_day('2026-02-30') is None and b.drop_day('x') is None
    assert b.drop_date(277) == '2026-10-05'


def test_drop_records_from_the_text():
    got = b.obs_from_text(DROP_TEXT)
    assert sorted(got['k']) == ['a0000001', 'a0000002', 'a0000003', 'a0000004']
    assert got['k']['a0000001'] == {'npc': 213450, 'inst': 2834, 'diff': 1, 'day': 277, 'o': '3fa9c2e1', 'src': 'G',
                                    'it': {219004: 1, 219006: 2}}
    assert got['k']['a0000004']['npc'] == 0 and got['k']['a0000004']['src'] == 'E'
    assert got['npc'] == {213450: 'Faldrim Ambossmahl', 213470: 'Kurgor der Wächter'}
    assert got['inst'] == {2834: ['party', 'Halle der Thane'], 409: ['raid', 'Geschmolzener Kern']}
    assert got['bad'] == 2, 'a wrong date and a broken line'


def test_drop_records_from_the_saved_variables_and_the_site(tmp_path):
    p = tmp_path / 'Amisia.lua'
    p.write_text(SV_DROPS, encoding='utf-8')
    sv = b.obs_from_sv(b.load_sv(str(p)))
    assert sorted(sv['k']) == ['a0000001', 'c0000001', 'd0000001'], 'a broken record stays out'
    assert sv['k']['a0000001']['it'] == {219004: 1, 219007: 1} and 'mine' not in sv['k']['a0000001'], 'no own marker'
    assert sv['k']['d0000001']['enc'] == 3020
    assert sv['npc'] == {213450: 'Faldrim'} and sv['inst'] == {2834: ['party', 'Halle der Thane']}
    site = b.obs_from_site(SITE_OBS)
    assert sorted(site['k']) == ['a0000001', 'b0000001'] and site['bad'] == 2
    assert site['k']['b0000001'] == {'npc': 213480, 'inst': 2834, 'diff': 1, 'day': 278, 'o': '00000002', 'src': 'G', 'it': {219008: 1}}
    assert site['npc'] == {213480: 'Neuer Boss', 213450: 'Faldrim Anvilmeal'}


def test_the_archive_merges_every_source_once(tmp_path):
    p = tmp_path / 'Amisia.lua'
    p.write_text(SV_DROPS, encoding='utf-8')
    arch = b.load_archive(str(tmp_path / 'none.json'))
    assert arch == {'v': 1, 'k': {}, 'npc': {}, 'inst': {}, 'enc': {}}
    parts = [b.obs_from_text(DROP_TEXT), b.obs_from_sv(b.load_sv(str(p))), b.obs_from_site(SITE_OBS)]
    stats = [b.merge_obs(arch, part) for part in parts]
    assert stats[0] == {'new': 4, 'merged': 0} and stats[1] == {'new': 2, 'merged': 1} and stats[2] == {'new': 1, 'merged': 1}
    a1 = arch['k']['a0000001']
    assert a1['it'] == {219004: 3, 219006: 2, 219007: 1} and a1['o'] == '00000001', 'items at their largest count, the smaller origin'
    assert arch['npc'][213450] == 'Faldrim Ambossmahl', 'the first name stays'
    assert arch['npc'][213480] == 'Neuer Boss' and arch['inst'][2834] == ['party', 'Halle der Thane']
    assert arch['enc'][3020] == 'Geheimer Boss'
    # merging everything again changes nothing, in any order
    again = [b.merge_obs(arch, part) for part in reversed(parts)]
    assert all(s == {'new': 0, 'merged': 0} for s in again)
    path = tmp_path / 'drop_obs.json'
    b.save_archive(str(path), arch)
    assert b.load_archive(str(path)) == arch, 'the archive reads back the same'
    first = path.read_bytes()
    b.save_archive(str(path), b.load_archive(str(path)))
    assert path.read_bytes() == first, 'stable on disk'
    text = path.read_text(encoding='utf-8')
    for name in ('Vulo', 'Sturmwind', 'Fraktur'):
        assert name not in text, 'no player names in the archive'


def test_the_boss_tables_from_the_archive():
    arch = b.load_archive('/nonexistent')
    b.merge_obs(arch, b.obs_from_text(DROP_TEXT))
    b.merge_obs(arch, b.obs_from_site(SITE_OBS))
    cfg = {'Halle der Thane': {'key': 'thanes', 'short': 'Thane', 'color': ['#111111', '#222222']},
           "Onyxia's Lair": {'key': 'ony', 'short': 'Ony', 'color': ['#333333', '#444444'], 'raid': True, 'instance': 249}}
    zones, bosses, through, warnings = b.obs_tables(arch, cfg)
    assert through == 278, 'the newest day in the archive'
    assert zones == [
        {'key': 'geschmolzene', 'name': 'Geschmolzener Kern', 'short': 'Geschmol', 'color': b.DEFAULT_COLOR, 'inst': 409, 'kind': 'raid'},
        {'key': 'thanes', 'name': 'Halle der Thane', 'short': 'Thane', 'color': ['#111111', '#222222'], 'inst': 2834, 'kind': 'party'},
    ], zones
    assert any('Geschmolzener Kern' in w for w in warnings), 'a zone without a key is reported'
    by = {x['npc']: x for x in bosses}
    assert sorted(by) == [213450, 213470, 213480], 'the fallback record (no NPC) has no table'
    assert by[213450] == {'npc': 213450, 'name': 'Faldrim Ambossmahl', 'zone': 'thanes', 'kills': 2,
                          'obs': {'219004': 1, '219006': 1}}, 'kills with the item, not pieces'
    assert by[213470]['zone'] == 'geschmolzene' and by[213470]['kills'] == 1
    assert by[213480]['name'] == 'Neuer Boss'
    # a zone named only by its instance id in the config
    arch2 = b.load_archive('/nonexistent')
    b.merge_obs(arch2, b.obs_from_text('DZ 249 raid Onyxias Hort\nDN 10184 0 Onyxia\nDK e0000001 10184 249 1 2026-10-05 3fa9c2e1 G 17078:1\n'))
    zones2, bosses2, _, _ = b.obs_tables(arch2, cfg)
    assert zones2[0]['key'] == 'ony' and zones2[0]['name'] == 'Onyxias Hort' and bosses2[0]['zone'] == 'ony'


def _js(path):
    txt = path.read_text(encoding='utf-8')
    return json.loads(txt.split('=', 2)[2].rstrip(';\n'))


def test_without_saved_variables_only_the_observations_change(tmp_path, monkeypatch):
    monkeypatch.setattr(b, 'DEFAULT_SV', str(tmp_path / 'missing' / 'Amisia.lua'))
    js = tmp_path / 'forever.js'
    zones = [{'key': 'thanes', 'name': 'Halle der Thane', 'short': 'Thane', 'color': ['#111111', '#222222']}]
    bosses = [{'name': 'Faldrim Ambossmahl', 'zone': 'thanes'}]
    items = [{'id': 219004, 'name': 'Ring der Thane', 'slot': 'finger', 'icon': 'x', 'sources': ['Faldrim Ambossmahl'], 'q': 3, 'ilvl': 20}]
    b.write_js(str(js), zones, bosses, items, {'file': 'data/forever.abc.jpg', 'cols': 24, 'rows': 1, 'n': 1})
    before = js.read_bytes()
    arch = tmp_path / 'drop_obs.json'
    # nothing observed yet: the data file stays as it is, the archive is made
    assert b.main(['--out', str(js), '--archive', str(arch)]) == 0
    assert js.read_bytes() == before and arch.exists()
    obs = tmp_path / 'obs.json'
    obs.write_text(json.dumps(SITE_OBS), encoding='utf-8')
    text = tmp_path / 'drops.txt'
    text.write_text(DROP_TEXT, encoding='utf-8')
    assert b.main(['--out', str(js), '--archive', str(arch), '--obs', str(obs), '--drops', str(text)]) == 0
    data = _js(js)
    assert data['zones'] == zones and data['bosses'] == bosses and data['items'] == items and data['sprite']['n'] == 1, \
        'the catalog of the last full build stays'
    assert data['obsThrough'] == 278
    assert [z['key'] for z in data['obsZones']] == ['geschmolzene', 'thanes']
    assert {x['npc'] for x in data['obsBosses']} == {213450, 213470, 213480}
    after = js.read_bytes()
    assert b.main(['--out', str(js), '--archive', str(arch)]) == 0
    assert js.read_bytes() == after, 'the archive alone builds the same file again'
    assert len(b.load_archive(str(arch))['k']) == 5


def test_the_saved_variables_on_the_n100_feed_the_archive(tmp_path, monkeypatch):
    sv = tmp_path / 'Amisia.lua'
    sv.write_text(SV_DROPS, encoding='utf-8')
    monkeypatch.setattr(b, 'DEFAULT_SV', str(sv))
    js = tmp_path / 'forever.js'
    b.write_js(str(js), [], [], [{'id': 1, 'name': 'Kept', 'slot': 'head', 'icon': '', 'sources': ['Unknown source'], 'q': 4, 'ilvl': 1}], None)
    arch = tmp_path / 'drop_obs.json'
    assert b.main(['--out', str(js), '--archive', str(arch)]) == 0
    data = _js(js)
    assert data['items'][0]['name'] == 'Kept', 'only the drop records are read, the catalog is not rebuilt'
    assert sorted(b.load_archive(str(arch))['k']) == ['a0000001', 'c0000001', 'd0000001']
    assert data['obsBosses'][0]['npc'] == 213450 and data['obsBosses'][0]['kills'] == 2


def test_a_full_build_names_the_observed_items(tmp_path, monkeypatch):
    monkeypatch.setattr(b, 'DEFAULT_SV', str(tmp_path / 'missing.lua'))
    sv = tmp_path / 'Amisia.lua'
    sv.write_text(SV_DROPS, encoding='utf-8')
    js = tmp_path / 'forever.js'
    arch = tmp_path / 'drop_obs.json'
    assert b.main([str(sv), '--out', str(js), '--archive', str(arch), '--no-icons']) == 0
    data = _js(js)
    assert [i['id'] for i in data['items']] == [32235], 'the raid drop of the session'
    assert data['obsBosses'][0]['obs'] == {'219004': 1, '219007': 1}
    named = {i['id']: i for i in data['obsItems']}
    assert named[219004]['name'] == 'Ring der Thane' and named[219004]['slot'] == 'finger', 'a scanned item gets its name'
    assert 219007 not in named, 'an item the scan never saw has no row'
    assert data['obsThrough'] == 277
