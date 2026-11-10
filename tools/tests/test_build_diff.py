"""tools/build_diff.py on small hand-made tables of two builds (D-103): new, removed and changed rows,
floats written differently are no change, a table only one build has, the names in the report."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import build_diff  # noqa: E402

OLD, NEW = '1.60.1.100', '1.60.1.200'

TABLES = {
    'ItemSparse': (
        'ID,Display_lang,OverallQualityID,InventoryType,ItemLevel,RequiredLevel,StatPercentEditor_0,DmgVariance\n'
        '1,Old Sword,2,13,20,15,100,0.4\n'
        '2,Gone Ring,3,11,30,25,0,0\n'
        '3,Same Hat,1,1,10,5,0,0.30000001192\n',
        'ID,Display_lang,OverallQualityID,InventoryType,ItemLevel,RequiredLevel,StatPercentEditor_0,DmgVariance,NewCol\n'
        '1,Old Sword,2,13,22,15,120,0.40000000596,1\n'
        '3,Same Hat,1,1,10,5,0,0.3,1\n'
        '4,New Epic Cloak,4,16,60,58,0,0,1\n'
        '5,New Green Boots,2,8,40,35,0,0,1\n'),
    'QuestV2': ('ID,UniqueBitFlag\n10,0\n11,0\n', 'ID,UniqueBitFlag\n10,0\n12,0\n13,0\n'),
    'Map': ('ID,MapName_lang,InstanceType,MaxPlayers\n0,Eastern Kingdoms,0,0\n',
            'ID,MapName_lang,InstanceType,MaxPlayers\n0,Eastern Kingdoms,0,0\n2970,The Drowned City,1,5\n'),
    'DungeonEncounter': ('Name_lang,ID,MapID\n', 'Name_lang,ID,MapID\nCaptain Dreadrise,3476,2970\n'),
    'SkillLine': ('ID,DisplayName_lang,CategoryID\n171,Alchemy,11\n6,Frost,7\n',) * 2,
    'SkillLineAbility': ('ID,SkillLine,Spell\n1,171,500\n2,6,122\n', 'ID,SkillLine,Spell\n1,171,500\n2,6,122\n3,171,501\n'),
    'TraitDefinition': ('ID,SpellID\n1,600\n',) * 2,
    'SpellName': ('ID,Name_lang\n500,Elixir\n600,Swiftmend\n122,Frost Nova\n',
                  'ID,Name_lang\n500,Elixir\n501,New Flask\n600,Swiftmend\n122,Frost Nova\n'),
    'SpellEffect': ('ID,SpellID,EffectBasePointsF\n1,500,10\n2,600,5\n3,122,3\n',
                    'ID,SpellID,EffectBasePointsF\n1,500,10.0\n2,600,7\n3,122,4\n4,501,1\n'),
}


def folders(tmp_path):
    a, b = tmp_path / 'export', tmp_path / 'fetched'
    a.mkdir()
    b.mkdir()
    for t, (old, *new) in TABLES.items():
        (a / f'{t}.{OLD}.csv').write_text(old, encoding='utf-8')
        (b / f'{t}.{NEW}.csv').write_text(new[0] if new else old, encoding='utf-8')
    # only the new build has the flight points
    (b / f'TaxiNodes.{NEW}.csv').write_text('ID,Name_lang\n3203,"Rog\'mar, Riverglades"\n', encoding='utf-8')
    return [('export', str(a)), ('wago.tools', str(b))]


def test_numbers_are_compared_as_numbers():
    assert build_diff.same('0.4', '0.40000000596') and build_diff.same('1', '1.0') and build_diff.same(' x', 'x')
    assert not build_diff.same('20', '22') and not build_diff.same('a', 'b') and not build_diff.same('0', '0.01')
    assert build_diff.same('16341.209960938', '16341.21')


def test_new_removed_and_changed_rows_without_float_noise(tmp_path):
    srcs = folders(tmp_path)
    assert build_diff.builds_on_disk(srcs) == [OLD, NEW]
    files = build_diff.table_files(NEW, srcs)
    assert set(files) == set(TABLES) | {'TaxiNodes'}
    old = build_diff.Build(OLD, build_diff.table_files(OLD, srcs))
    new = build_diff.Build(NEW, files)
    c = build_diff.compare(old, new, 'ItemSparse')
    assert c['new'] == [4, 5] and c['removed'] == [2]
    assert c['changed'] == {1: ['ItemLevel', 'StatPercentEditor_0']}, 'DmgVariance 0.4 is 0.40000000596; NewCol is named only'
    assert c['cols_added'] == ['NewCol'] and c['cols_removed'] == []
    assert build_diff.compare(old, new, 'TaxiNodes') is None, 'a table only one build has is not compared'


def test_the_report_names_what_is_new(tmp_path):
    short, full = build_diff.report(OLD, NEW, folders(tmp_path), quest_name_map={12: 'The Drowned Path'})
    text = '\n'.join(full)
    assert short[0].startswith(f'New in {NEW} against {OLD}') and len(short) <= build_diff.SHORT
    assert any(s.startswith('Items: 2 new (1 epic, 1 uncommon), 1 removed, 1 changed (ItemLevel 1, StatPercentEditor_0 1)')
               for s in short), short
    assert '4 New Epic Cloak (epic, back, item level 60, level 58)' in text
    assert 'new by slot: back 1, feet 1' in text and 'removed: 2 Gone Ring' in text
    assert '1 Old Sword: ItemLevel 20 -> 22, StatPercentEditor_0 100 -> 120' in text
    assert 'Quests (QuestV2): 2 new, 1 removed' in text and 'new: 12 The Drowned Path, 13' in text and 'removed: 11' in text
    assert '2970 The Drowned City (dungeon, 5 players)' in text and '3476 Captain Dreadrise (The Drowned City)' in text
    assert 'Profession spells (SkillLineAbility): 1 new, 0 removed, 0 changed' in text and '501 New Flask' in text
    assert 'Frost Nova' not in text.split('Profession spells')[1].split('Talent spells')[0], 'a class spell is no profession'
    assert 'Talent spells (TraitDefinition): 0 new, 0 removed, 1 changed' in text and '600 Swiftmend [SpellEffect]' in text
    assert f'Flight points: TaxiNodes not in both builds (only in {NEW}, 1 nodes in {NEW})' in text
    assert f'only in {NEW}: TaxiNodes' in text
    assert any(s.startswith('Dungeons: 1 new dungeons/raids (The Drowned City), 1 new bosses') for s in short), short


def test_a_build_without_tables(tmp_path):
    short, full = build_diff.report(OLD, '1.60.1.999', folders(tmp_path))
    assert short == full and 'no client table of 1.60.1.999 on disk' in short[0]


def test_the_quest_names_of_amisias_quest_data(tmp_path):
    p = tmp_path / 'QuestData.lua'
    p.write_text('return {\nQ={\n[123]="1426;Boar Trouble;5;A;0;0;0;0;;O;;;;",\n[124]="0;;1;;0;0;0;0;;;;;;",\n}}\n',
                 encoding='utf-8')
    assert build_diff.quest_names(str(p)) == {123: 'Boar Trouble', 124: ''}
    assert build_diff.quest_names(str(tmp_path / 'none')) == {}
