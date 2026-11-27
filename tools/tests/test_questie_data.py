"""tools/questie_data.py: QuestieDB's Forever data (D-157) read in its sandbox from a small cut in the files'
own format (tools/tests/fixtures/questiedb), the download's choice of files and its one request at a time."""
import json
import os
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import questie_data  # noqa: E402

FIXTURE = os.path.join(HERE, 'fixtures', 'questiedb')


def test_the_reader_keeps_weapons_and_armour_with_their_sources():
    db = questie_data.load(FIXTURE)
    assert db['commit'] == '0123456789abcdef0123456789abcdef01234567'
    # no source (25) and no gear (117 Tough Jerky, class 0) are left out
    assert sorted(db['items']) == [5191, 5200, 7000, 7001, 7002, 7003, 7004]
    assert db['items'][5191] == {'name': 'Cruel Barb', 'npcs': [646], 'objects': [], 'vendors': [], 'quests': []}
    assert db['items'][7001]['objects'] == [2039]
    assert db['items'][7002]['quests'] == [4711]
    assert db['items'][7003]['vendors'] == [900]
    # only the NPCs, objects and quests an item names, with names, levels, rank, zone (an AreaTable id)
    assert sorted(db['npcs']) == [6, 299, 646, 900, 901]
    assert db['npcs'][646] == {'name': 'Mr. Smite', 'min': 20, 'max': 20, 'rank': 1, 'zone': 1581, 'title': None,
                               'friendly': None}
    assert db['npcs'][900]['friendly'] == 'A' and db['npcs'][900]['title'] == 'Shoe Merchant'
    assert db['npcs'][901]['rank'] == 4
    assert db['objects'] == {2039: {'name': 'Hidden Strongbox', 'zone': 40}}
    assert db['quests'] == {4711: {'name': 'Die Fackel', 'level': 30, 'min': 25, 'faction': 'A', 'classes': 0,
                                   'zone': 40}}


def test_a_missing_download_is_no_source_with_a_note(tmp_path, capsys):
    assert questie_data.load(str(tmp_path)) is None
    assert 'build.py questie' in capsys.readouterr().err


def test_race_masks_become_a_faction():
    assert questie_data.race_faction(77) == 'A'
    assert questie_data.race_faction(178) == 'H'
    assert questie_data.race_faction(255) is None and questie_data.race_faction(0) is None
    # QuestieDB sets high bits on some masks (8589934770 = 2^33 + 178): only the classic races count
    assert questie_data.race_faction(8589934770) == 'H'


def test_the_sandbox_refuses_bytecode_and_keeps_the_file_in():
    db, err = questie_data.run('\x1bLuaQ\x00', 'x.lua')
    assert db is None and 'binary chunk refused' in err
    # a data string of precompiled code is refused as well
    db, err = questie_data.run('local Q = QuestieLoader:ImportModule("QuestieDB")\n'
                               'Q.itemKeys = {}\nQ.itemData = "\\27LuaQ"\n', 'x.lua')
    assert db is None and 'binary chunk refused' in err
    for src in ('os.execute("true")', 'io.open("/etc/passwd")', 'require("os")', 'python.eval("1")',
                'local s = ("x"):rep(3)', 'loadstring("return 1")()', 'debug.sethook()'):
        db, err = questie_data.run(src, 'x.lua')
        assert db is None and err, src
    db, err = questie_data.run('while true do end', 'x.lua', budget=100000)
    assert db is None and 'runs too long' in err
    # what a file may do: fill the table it is handed, data as a string or a table
    db, err = questie_data.run('local Q = QuestieLoader:ImportModule("QuestieDB")\nQ.a = [[return {[1] = {"A"}}]]\n'
                               'Q.b = {2}\n', 'x.lua')
    assert err is None and db['a'][1][1] == 'A' and db['b'][1] == 2


def test_the_download_keeps_the_forever_tables_and_the_licence_only():
    assert questie_data.kept('data/Forever/foreverItemDB.lua')
    assert questie_data.kept('LICENSE.md') and questie_data.kept('PROVENANCE.md')
    assert not questie_data.kept('data/Era/eraItemDB.lua')
    assert not questie_data.kept('data/Forever/conversion.json')
    assert not questie_data.kept('data/Forever/sub/x.lua')
    assert not questie_data.kept('AGENTS.md') and not questie_data.kept('src/meta/itemMeta.lua')


def test_the_download_asks_one_file_after_the_other(tmp_path, monkeypatch):
    blobs = {'a1': b'-- item', 'b2': b'licence', 'c3': b'nope'}
    tree = {'tree': [{'path': 'data/Forever/foreverItemDB.lua', 'type': 'blob', 'sha': 'a1'},
                     {'path': 'LICENSE.md', 'type': 'blob', 'sha': 'b2'},
                     {'path': 'data/Era/eraItemDB.lua', 'type': 'blob', 'sha': 'c3'},
                     {'path': 'data/Forever', 'type': 'tree', 'sha': 'd4'}]}
    asked, sleeps = [], []

    class Answer:
        def __init__(self, body):
            self.body = body

        def read(self):
            return self.body

        def __enter__(self):
            return self

        def __exit__(self, *a):
            return False

    def urlopen(req, timeout=None):
        url = req.full_url
        asked.append(url)
        assert url.startswith('https://api.github.com/repos/Questie/questiedb/')
        assert req.get_method() == 'GET' and 'Amisia-build-tool' in req.headers['User-agent']
        if url.endswith('/commits/master'):
            return Answer(json.dumps({'sha': 'c0ffee'}).encode())
        if '/git/commits/' in url:
            return Answer(json.dumps({'tree': {'sha': 't1'}}).encode())
        if '/git/trees/' in url:
            return Answer(json.dumps(tree).encode())
        return Answer(blobs[url.rsplit('/', 1)[1]])

    monkeypatch.setattr(questie_data.urllib.request, 'urlopen', urlopen)
    monkeypatch.setattr(questie_data.time, 'sleep', sleeps.append)
    monkeypatch.setattr(questie_data, '_token', lambda: None)
    (tmp_path / 'old.lua').write_text('x')
    assert questie_data.refresh(str(tmp_path)) == 'c0ffee'
    assert len(asked) == 5 and len(sleeps) == 5, 'commit, tree, listing and the two kept files, each after a pause'
    assert not any(u.endswith('/c3') for u in asked)
    assert (tmp_path / 'data' / 'Forever' / 'foreverItemDB.lua').read_bytes() == b'-- item'
    assert (tmp_path / 'LICENSE.md').read_bytes() == b'licence'
    assert not (tmp_path / 'old.lua').exists() and (tmp_path / 'COMMIT').read_text().strip() == 'c0ffee'


def test_areas_become_maps_through_their_parents(tmp_path):
    (tmp_path / 'UiMapAssignment.csv').write_text(
        'ID,UiMapID,OrderIndex,MapID,AreaID\n1,1429,0,0,12\n2,1999,1,0,12\n3,1436,0,0,40\n', encoding='utf-8')
    (tmp_path / 'AreaTable.csv').write_text(
        'ID,ZoneName,AreaName_lang,ContinentID,ParentAreaID\n12,x,Elwynn Forest,0,0\n87,x,Goldshire,0,12\n'
        '40,x,Westfall,0,0\n1583,x,Blackrock Spire,0,0\n', encoding='utf-8')
    assert questie_data.area_zones(str(tmp_path)) == {12: 1429, 87: 1429, 40: 1436}
    names = questie_data.area_names(str(tmp_path))
    assert names[1583] == 'Blackrock Spire' and 87 not in names
    assert names[1585] == 'Blackrock Depths', "QuestieDB's own id of Blackrock Depths"


@pytest.mark.skipif(not os.path.exists(os.path.join(questie_data.QUESTIE_CACHE, 'data', 'Forever', 'foreverItemDB.lua')),
                    reason='no QuestieDB download on this machine')
def test_the_real_download_reads():
    db = questie_data.load()
    assert len(db['items']) > 1000 and len(db['npcs']) > 500 and len(db['quests']) > 300


def test_the_item_names_are_read_as_text(tmp_path):
    """The English names and item levels of the weapons and armour, for the WoWSims gear sets (F-239)."""
    folder = tmp_path / 'data' / 'Forever'
    folder.mkdir(parents=True)
    (folder / 'foreverItemDB.lua').write_text(
        "QuestieDB.itemData = [[return {\n"
        "[15411] = {'Mark of Fordring',nil,nil,nil,nil,{5944},nil,nil,63,0,0,4,0},\n"
        "[38] = {'Recruit\\'s Shirt',nil,nil,nil,nil,nil,nil,nil,1,0,0,4,0},\n"
        "[2589] = {'Linen Cloth',{1,2},nil,nil,nil,nil,nil,nil,5,0,0,7,0},\n"
        "}]]\n", encoding='utf-8')
    assert questie_data.item_names(str(tmp_path)) == {15411: ('Mark of Fordring', 63), 38: ("Recruit's Shirt", 1)}
    assert questie_data.item_names(str(tmp_path / 'none')) == {}
