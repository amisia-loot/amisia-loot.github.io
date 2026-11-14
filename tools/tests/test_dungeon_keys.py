"""tools/forever_dungeon_keys.json and the fields build_dungeons.py adds from it and the client tables:
keys (the key and attunement items, every item id the client's own, every quest one the repo's quest data
has with that title), enc (one encounter id per boss of order) and maps (the uiMap ids of the floors)."""
import json
import os
import re
import shutil
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
ROOT = os.path.dirname(TOOLS)
ADDON = os.path.join(ROOT, 'Amisia_Gear')   # the gear module holds the data (F-202)
sys.path.insert(0, TOOLS)
import att_data  # noqa: E402
import build_dungeons  # noqa: E402

KEYS = os.path.join(TOOLS, 'forever_dungeon_keys.json')
OUT = os.path.join(ADDON, 'Data', 'DungeonData.lua')
WAGO = os.path.join(HERE, 'fixtures', 'wago')
USER_WAGO = os.path.expanduser('~/addons/_wago')


def doc():
    with open(KEYS, encoding='utf-8') as fh:
        return json.load(fh)


def facts():
    with open(build_dungeons.FACTS, encoding='utf-8') as fh:
        return json.load(fh)


def quest_titles():
    """{quest id: {titles}} of the repo's quest data (QuestData.lua and DungeonQuestData.lua)."""
    out = {}
    with open(os.path.join(ADDON, 'Data', 'QuestData.lua'), encoding='utf-8') as fh:
        for m in re.finditer(r'^\[(\d+)\]="\d+;((?:[^;\\]|\\.)*);', fh.read(), re.M):
            out.setdefault(int(m.group(1)), set()).add(m.group(2))
    with open(os.path.join(ADDON, 'Data', 'DungeonQuestData.lua'), encoding='utf-8') as fh:
        for m in re.finditer(r'\[(\d+)\] = \{ "((?:[^"\\]|\\.)*)"', fh.read()):
            out.setdefault(int(m.group(1)), set()).add(m.group(2).replace("\\'", "'"))
    return out


def test_every_key_is_well_formed_and_names_its_source():
    d = doc()
    assert re.match(r'^\d{4}-\d{2}-\d{2}$', d['checked'])
    known = {e['key'] for e in facts()['dungeons']}
    assert d['dungeons'] and set(d['dungeons']) <= known, set(d['dungeons']) - known
    for key, items in d['dungeons'].items():
        assert items, key
        ids = [i['item'] for i in items]
        assert len(ids) == len(set(ids)), key
        for i in items:
            assert set(i) <= {'item', 'name', 'need', 'why', 'quests', 'questsA', 'questsH', 'src', 'note'}, i
            assert isinstance(i['item'], int) and i['item'] > 0 and i['name'], i
            assert i['need'] in build_dungeons.KEY_NEED and i['why'] in build_dungeons.KEY_WHY, i
            assert i['src'] in d['sources'] and d['sources'][i['src']] and i.get('note'), i
            for f in ('quests', 'questsA', 'questsH'):
                assert all(isinstance(q, int) and q > 0 for q in i.get(f, [])), i
            assert not (i.get('quests') and (i.get('questsA') or i.get('questsH'))), 'one chain for both or one per faction'
    text = open(KEYS, encoding='utf-8').read()
    assert 'http' not in text and 'www.' not in text
    text.encode('latin-1')


def test_every_key_item_is_in_the_client_item_table():
    path = att_data.wago_csv(USER_WAGO, 'ItemSparse')
    if not path:
        pytest.skip('no ItemSparse CSV in ~/addons/_wago')
    want = {i['item']: i['name'] for items in doc()['dungeons'].values() for i in items}
    names = {}
    for row in att_data.wago_rows('ItemSparse', USER_WAGO):
        iid = build_dungeons._int(row.get('ID'))
        if iid in want:
            names[iid] = row.get('Display_lang')
    for iid, name in want.items():
        assert names.get(iid) == name, (iid, name, names.get(iid))


def test_every_quest_of_a_key_is_in_the_repo_quest_data():
    titles = quest_titles()
    for items in doc()['dungeons'].values():
        for i in items:
            for f in ('quests', 'questsA', 'questsH'):
                for q in i.get(f, []):
                    assert q in titles, (i['name'], q)


def test_enc_lines_up_with_order_and_maps_are_numbers():
    with open(build_dungeons.CLIENT, encoding='utf-8') as fh:
        client = json.load(fh)
    with_order = 0
    for k, v in client['dungeons'].items():
        if v.get('order'):
            with_order += 1
            assert len(v.get('enc') or []) == len(v['order']), k
            assert all(isinstance(x, int) and x > 0 for x in v['enc']), k
            assert len(set(v['enc'])) == len(v['enc']), k
        assert all(isinstance(x, int) and x > 0 for x in v.get('maps', [])), k
    assert with_order >= 20
    assert client['dungeons']['onyxia']['enc'] == [1084]
    bad = dict(client)
    bad['dungeons'] = {'rfc': {'order': ['A', 'B'], 'enc': [1]}}
    with pytest.raises(ValueError):
        build_dungeons.merge({'dungeons': [{'key': 'rfc', 'name': 'Ragefire Chasm', 'kind': 'party'}]}, bad)


def test_the_floors_of_an_instance(tmp_path):
    for name in os.listdir(WAGO):
        shutil.copy(os.path.join(WAGO, name), tmp_path / name)
    (tmp_path / 'UiMapAssignment.1.60.1.10.csv').write_text(
        'ID,UiMapID,OrderIndex,MapID,AreaID\n'
        '5,1411,0,1,14\n'
        '7,302,1,4777,0\n'
        '6,301,0,4777,0\n'
        '8,301,2,4777,0\n'
        '9,303,1,4777,0\n', encoding='utf-8')
    assert build_dungeons.uimap_floors(str(tmp_path)) == {1: [1411], 4777: [301, 302, 303]}, \
        'every uiMap once, by its first OrderIndex, then the row ID'
    c = build_dungeons.client_facts({'dungeons': [{'key': 'halls', 'name': 'Test Halls', 'kind': 'party'},
                                                  {'key': 'wing', 'name': 'Test Wing', 'kind': 'party'}]}, [str(tmp_path)])
    assert c['tables']['UiMapAssignment'] == 'UiMapAssignment.1.60.1.10.csv'
    assert c['dungeons']['halls']['maps'] == [301, 302, 303] and 'maps' not in c['dungeons']['wing'], 'none without floors'
    text = build_dungeons.render({'checked': 'x', 'dungeons': [{'key': 'halls', 'name': 'Test Halls', 'kind': 'party'}]}, c,
                                 {'halls': [{'item': 7, 'name': 'Test Key', 'need': 'required', 'why': 'door', 'quests': [],
                                             'src': 's', 'note': 'n'},
                                            {'item': 8, 'name': 'Test Seal', 'need': 'optional', 'why': 'attune',
                                             'questsA': [1, 2], 'questsH': [3], 'src': 's', 'note': 'n'}]})
    assert ('enc = { 10, 11, 12 }, maps = { 301, 302, 303 }, keys = { { item = 7, need = "required", why = "door" }, '
            '{ item = 8, need = "optional", why = "attune", questsA = { 1, 2 }, questsH = { 3 } } } },') in text
    assert 'Test Key' not in text and 'note' not in text and 'src' not in text, 'names and notes stay in the JSON'


def test_the_generated_file_carries_the_keys():
    lupa = pytest.importorskip('lupa.lua51')
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    ns = lua.eval('{}')
    with open(OUT, encoding='utf-8') as fh:
        lua.eval('function(s) return assert(loadstring(s)) end')(fh.read())('Amisia', ns)
    lst = ns.DUNGEON_FACTS.list
    by = {lst[i].key: lst[i] for i in range(1, len(lst) + 1)}
    keys = doc()['dungeons']
    for k, e in by.items():
        if e.order is not None:
            assert e.enc is not None and len(e.enc) == len(e.order), k
        if e.maps is not None:
            assert all(isinstance(e.maps[i], int) for i in range(1, len(e.maps) + 1)), k
        if k in keys:
            assert len(e['keys']) == len(keys[k]) and e['keys'][1].item == keys[k][0]['item'], k
        else:
            assert e['keys'] is None, k
    ony = by['onyxia']['keys'][1]
    assert ony.item == 16309 and ony.need == 'required' and ony.why == 'attune'
    assert ony.questsA[len(ony.questsA)] == 6502 and ony.questsH[len(ony.questsH)] == 6602
