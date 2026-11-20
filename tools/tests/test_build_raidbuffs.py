"""tools/build_raidbuffs.py: the buffs of the lineup (F-224, D-149) from the client tables: the class from
SkillLineAbility -> SkillRaceClassInfo -> ChrClasses, "talent" from the talent trees, one spell id per entry
(small hand-made tables, not real data), the generated Amisia_Gear/Data/RaidBuffData.lua (valid Lua, lazy,
in the TOC), and every listed name still a class's in the tables on disk."""
import os
import re
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
ROOT = os.path.dirname(TOOLS)
ADDON = os.path.join(ROOT, 'Amisia_Gear')   # the gear module holds the data (F-202)
sys.path.insert(0, TOOLS)
import build_raidbuffs  # noqa: E402
import lua_data  # noqa: E402
import modules  # noqa: E402

OUT = modules.data_file('RaidBuffData.lua')
B = '1.60.1.99999'

# skill lines: 6 mage, 7 druid, 8 hunter, 9 warlock pet (several classes), 10 shaman, 11 priest
TABLES = {
    'ChrClasses': 'Name_lang,Filename,ID\nWarrior,WARRIOR,1\nHunter,HUNTER,3\nPriest,PRIEST,5\nShaman,SHAMAN,7\n'
                  'Mage,MAGE,8\nWarlock,WARLOCK,9\nDruid,DRUID,11\n',
    'SkillRaceClassInfo': 'ID,SkillID,ClassMask\n1,6,128\n2,7,1024\n3,8,4\n4,9,1535\n5,10,64\n6,11,16\n7,12,-1\n',
    'SpellName': 'ID,Name_lang\n'
                 '100,Arcane Intellect\n101,Arcane Intellect\n102,Arcane Brilliance\n103,Arcane Intellect\n'
                 '200,Trueshot Aura\n300,Leader of the Pack\n301,Moonkin Aura\n400,Blood Pact\n'
                 '500,Remove Curse\n501,Remove Lesser Curse\n600,Cure Poison\n601,Cure Poison\n'
                 '700,Divine Spirit\n',
    # 103 is an NPC copy of Arcane Intellect in no class line: never the entry's spell
    'SkillLineAbility': 'ID,SkillLine,Spell\n1,6,100\n2,6,101\n3,6,102\n4,8,200\n5,7,300\n6,7,301\n7,9,400\n'
                        '8,7,500\n9,6,501\n10,10,600\n11,7,601\n12,11,700\n13,12,103\n',
    'SpellMisc': 'ID,SpellIconFileDataID,SpellID\n1,9001,101\n2,9002,200\n',
}
TALENT_LUA = '''ns.LazyData("TALENTS", [=[
return {
classes={
HUNTER={id=3,tree=1,
nodes={
{1,2,200,5,2,3,1,1,{12722,15},0,"Trueshot Aura","Increases ..."},
}},
DRUID={id=11,tree=2,
nodes={
{3,4,24858,6,1,6,1,1,{1,30},{-5,6},"Moonkin Form","Shapeshift ..."},
{7,8,300,9,2,4,1,1,{2,20},0,"Leader of the Pack","While in \\"Cat Form\\" ..."},
}},
PRIEST={id=5,tree=3,
nodes={
{9,10,99,9,2,4,1,1,0,0,"Spirit Tap","..."},
}},
},
}
]=], 3)
'''


@pytest.fixture
def tables(tmp_path):
    for name, text in TABLES.items():
        (tmp_path / f'{name}.{B}.csv').write_text(text, encoding='utf-8')
    talents = tmp_path / 'TalentData.lua'
    talents.write_text(TALENT_LUA, encoding='utf-8')
    return str(tmp_path), str(talents)


@pytest.fixture
def small(monkeypatch):
    monkeypatch.setattr(build_raidbuffs, 'ENTRIES', [
        ('int', 'buff', 'raid', ['Arcane Intellect', 'Arcane Brilliance'], {}),
        ('spirit', 'buff', 'raid', ['Divine Spirit'], {}),
        ('trueshot', 'buff', 'group', ['Trueshot Aura'], {}),
        ('lotp', 'buff', 'group', ['Leader of the Pack'], {'roles': 'TM'}),
        ('moonkin', 'buff', 'group', ['Moonkin Aura'], {'roles': 'R', 'via': 'Moonkin Form'}),
        ('bloodpact', 'buff', 'group', ['Blood Pact'], {'cls': 'WARLOCK'}),
        ('curse', 'util', 'raid', ['Remove Curse', 'Remove Lesser Curse'], {}),
        ('poison', 'util', 'raid', ['Cure Poison'], {}),
        ('gone', 'boss', 'raid', ['Curse of Shadow'], {}),
    ])


def by_key(data):
    return {e['key']: e for e in data['entries']}


def test_class_from_the_skill_line_one_spell_with_its_icon(tables, small):
    d = build_raidbuffs.build([tables[0]], tables[1])
    e = by_key(d)['int']
    assert d['build'] == B
    assert e['classes'] == [('MAGE', False)] and e['block'] == 'buff' and e['scope'] == 'raid'
    # the highest id of the first name in the class's line (103 is in no class line); its icon
    assert e['spell'] == 101 and e['icon'] == 9001


def test_talent_from_the_trees_never_from_the_list(tables, small):
    by = by_key(build_raidbuffs.build([tables[0]], tables[1]))
    assert by['trueshot']['classes'] == [('HUNTER', True)]
    assert by['lotp']['classes'] == [('DRUID', True)] and by['lotp']['roles'] == 'TM'
    # the aura's own name is no node: the talent that gives it is
    assert by['moonkin']['classes'] == [('DRUID', True)] and by['moonkin']['roles'] == 'R'
    # a priest spell that is no node of the priest's tree is baseline
    assert by['spirit']['classes'] == [('PRIEST', False)]


def test_one_row_several_classes(tables, small):
    by = by_key(build_raidbuffs.build([tables[0]], tables[1]))
    assert by['curse']['classes'] == [('DRUID', False), ('MAGE', False)] and by['curse']['spell'] == 500
    assert by['poison']['classes'] == [('DRUID', False), ('SHAMAN', False)]


def test_fixed_class_for_the_pet_spell(tables, small):
    # skill line 9 belongs to many classes (the pet's): no class from the tables, the list names it
    assert by_key(build_raidbuffs.build([tables[0]], tables[1]))['bloodpact']['classes'] == [('WARLOCK', False)]


def test_a_name_without_class_is_dropped_and_reported(tables, small):
    d = build_raidbuffs.build([tables[0]], tables[1])
    assert 'gone' not in by_key(d)
    assert d['dropped'] == ['gone: "Curse of Shadow" belongs to no class', 'gone: no class left, dropped']


def test_without_talent_data_nothing_is_a_talent(tables, small):
    by = by_key(build_raidbuffs.build([tables[0]], None))
    assert by['trueshot']['classes'] == [('HUNTER', False)]


def test_lua_output_lazy_and_valid(tables, small):
    lua = build_raidbuffs.render_lua(build_raidbuffs.build([tables[0]], tables[1]), built='2026-11-17')
    assert lua.startswith('-- Generated by tools/build_raidbuffs.py from the WoW Forever client tables')
    assert 'ns.LazyData("RAIDBUFFS", [=[\nreturn {\n' in lua and lua.rstrip().endswith(']=], 8)')
    lupa = pytest.importorskip('lupa.lua51')
    t = lua_data.load(lua, 'RaidBuffData.lua', lupa.LuaRuntime(unpack_returned_tuples=True)).RAIDBUFFS
    first = t.entries[1]
    assert first[1] == 'int' and first[2] == 'buff' and first[3] == 'raid' and first[4] == 101 and first[5] == 9001
    assert first[6] == '' and first[7][1] == 'MAGE' and first[7][2] == 0
    lotp = t.entries[4]
    assert lotp[1] == 'lotp' and lotp[6] == 'TM' and lotp[7][2] == 1


def test_missing_table_fails_clearly(tmp_path):
    with pytest.raises(SystemExit) as e:
        build_raidbuffs.build([str(tmp_path)])
    assert 'SpellName' in str(e.value)


def test_the_list_is_well_formed():
    keys = [e[0] for e in build_raidbuffs.ENTRIES]
    assert len(keys) == len(set(keys))
    for key, block, scope, names, opts in build_raidbuffs.ENTRIES:
        assert block in build_raidbuffs.BLOCKS and scope in build_raidbuffs.SCOPES and names, key
        assert set(opts.get('roles', '')) <= build_raidbuffs.ROLES, key
        assert set(opts) <= {'roles', 'cls', 'via'}, key


def test_shipped_data_file_in_toc_and_valid():
    # the data stands in the TOC of its part (F-228: the core's, where the raid part reads it through ns.Data)
    assert 'Data/RaidBuffData.lua' in [n for n, _, _ in modules.toc_entries()]
    assert modules.module_of('Raid/LineupBuffs.lua') == 'core'
    with open(OUT, encoding='utf-8') as fh:
        src = fh.read()
    lupa = pytest.importorskip('lupa.lua51')
    t = lua_data.load(src, 'RaidBuffData.lua', lupa.LuaRuntime(unpack_returned_tuples=True)).RAIDBUFFS
    n = int(src.rsplit(', ', 1)[1].rstrip(')\n'))
    assert n == len(list(t.entries.keys())) > 40


def chosen_dirs():
    import client_tables  # the newest copy of each table, as build.py data reads them (D-101)
    dirs = [client_tables.default_dir()]
    if any(build_raidbuffs.find_table(dirs, t) is None for t in build_raidbuffs.REQUIRED):
        pytest.skip('no client tables')
    return dirs


@pytest.mark.skipif(not os.path.isdir(build_raidbuffs.WAGO), reason='needs the client tables')
def test_every_listed_name_belongs_to_a_class():
    """A new client build that takes a spell from its class (or renames it) turns this red: the row would
    silently drop out of the planner."""
    d = build_raidbuffs.build(chosen_dirs())
    assert d['dropped'] == []
    assert len(d['entries']) == len(build_raidbuffs.ENTRIES)
    by = by_key(d)
    # what the spec names: talents of the trees and their role gates
    assert by['trueshot']['classes'] == [('HUNTER', True)]
    assert by['lotp']['classes'] == [('DRUID', True)] and by['moonkin']['classes'] == [('DRUID', True)]
    assert by['manatide']['classes'] == [('SHAMAN', True)] and by['manatide']['roles'] == 'H'
    assert by['spirit']['classes'] == [('PRIEST', False)], 'Divine Spirit is baseline on Forever'
    assert by['bloodpact']['classes'] == [('WARLOCK', False)]
    assert all(e['spell'] > 0 for e in d['entries'])


@pytest.mark.skipif(not os.path.isdir(build_raidbuffs.WAGO), reason='needs the client tables')
def test_shipped_file_is_current():
    dirs = chosen_dirs()
    with open(OUT, encoding='utf-8') as fh:
        shipped = fh.read()
    built = re.search(r'built\s*=\s*"([^"]*)"', shipped).group(1)
    assert build_raidbuffs.render_lua(build_raidbuffs.build(dirs), built=built) == shipped, \
        'rebuild: python3 tools/build_raidbuffs.py'
