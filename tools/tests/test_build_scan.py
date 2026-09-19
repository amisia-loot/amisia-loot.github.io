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
    items, sessions = b.collect([db])
    assert items[32235]['name'] == 'Cursed Vision of Sargeras' and items[32235]['q'] == 4
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
    js = tmp_path / 'forever.js'
    b.write_js(str(js), zones, bosses, out, None)
    txt = js.read_text(encoding='utf-8')
    assert txt.startswith('window.__LOOT=window.__LOOT||{};window.__LOOT["forever"]=')
    data = json.loads(txt.split('=', 2)[2].rstrip(';\n'))
    assert data['zones'][0]['name'] == 'Black Temple' and len(data['items']) == 4 and 'sprite' not in data


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
