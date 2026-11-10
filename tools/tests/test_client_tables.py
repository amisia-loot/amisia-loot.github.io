"""tools/client_tables.py (D-101): per table the highest version, at the same version more rows, an empty
file only when nothing else has rows; the folder of links the builders read; an explicit --wago folder
wins; TABLES is the one list (tools/export_db2.ps1) and holds every table a builder reads."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
sys.path.insert(0, TOOLS)
import client_tables as ct  # noqa: E402


def write(folder, name, rows, header='ID,Name'):
    os.makedirs(folder, exist_ok=True)
    with open(os.path.join(folder, name), 'w', encoding='utf-8') as fh:
        fh.write(header + '\n' + ''.join(f'{i},"n{i}"\n' for i in range(rows)))


def three(tmp_path):
    srcs = [('export', str(tmp_path / 'export')), ('wago.tools', str(tmp_path / 'fetched')), ('att', str(tmp_path / 'att'))]
    for _, d in srcs:
        os.makedirs(d, exist_ok=True)
    return srcs


def test_the_highest_version_wins_then_more_rows(tmp_path):
    srcs = three(tmp_path)
    ex, fe, at = (d for _, d in srcs)
    write(ex, 'Map.1.60.1.70862.csv', 73)
    write(ex, 'Map.1.60.1.9999.csv', 500)           # by number, not by text
    write(fe, 'Map.1.60.1.70888.csv', 78)
    c = ct.choose('Map', srcs)
    assert (c['source'], c['version'], c['rows']) == ('wago.tools', '1.60.1.70888', 78)
    assert c['others'] == [{'source': 'export', 'version': '1.60.1.70862', 'rows': 73,
                            'path': os.path.join(ex, 'Map.1.60.1.70862.csv')}]
    # same version: more rows (the export lacks the encrypted rows)
    write(ex, 'AreaTable.1.60.1.70862.csv', 1375)
    write(at, 'AreaTable.1.60.1.70862.csv', 1404)
    c = ct.choose('AreaTable', srcs)
    assert (c['source'], c['rows']) == ('att', 1404) and not c['fewer']
    # same version, same rows: the export first
    write(ex, 'ContentTuning.1.60.1.70862.csv', 100)
    write(at, 'ContentTuning.1.60.1.70862.csv', 100)
    assert ct.choose('ContentTuning', srcs)['source'] == 'export'
    assert ct.choose('Nothing', srcs) is None


def test_an_empty_newer_file_loses_and_a_smaller_newer_one_is_flagged(tmp_path):
    srcs = three(tmp_path)
    ex, fe, _ = (d for _, d in srcs)
    write(ex, 'TraitNodeXTraitCond.1.60.1.70755.csv', 1)
    write(fe, 'TraitNodeXTraitCond.1.60.1.70888.csv', 0)
    c = ct.choose('TraitNodeXTraitCond', srcs)
    assert (c['version'], c['rows']) == ('1.60.1.70755', 1)
    # nothing but empty files: the newest of them
    write(ex, 'Empty.1.60.1.1.csv', 0)
    write(fe, 'Empty.1.60.1.2.csv', 0)
    assert ct.choose('Empty', srcs)['version'] == '1.60.1.2'
    # newer with fewer rows than the export: chosen, but the report warns
    write(ex, 'Item.1.60.1.70862.csv', 10)
    write(fe, 'Item.1.60.1.70888.csv', 8)
    c = ct.choose('Item', srcs)
    assert c['version'] == '1.60.1.70888' and [o['rows'] for o in c['fewer']] == [10]
    lines = ct.report_lines({'Item': c})
    assert any('WARNING Item' in ln for ln in lines)


def test_rows_count_quoted_newlines_and_a_file_without_version_is_the_oldest(tmp_path):
    srcs = three(tmp_path)
    ex, fe, _ = (d for _, d in srcs)
    with open(os.path.join(ex, 'Spell.1.60.1.1.csv'), 'w', encoding='utf-8') as fh:
        fh.write('ID,Description_lang\n1,"two\nlines"\n2,x\n')
    assert ct.count_rows(os.path.join(ex, 'Spell.1.60.1.1.csv')) == 2
    write(fe, 'Spell.csv', 50)
    assert ct.choose('Spell', srcs)['version'] == '1.60.1.1'
    # a localised file is another table, not a version
    write(fe, 'Spell.1.60.1.2.deDE.csv', 50)
    assert ct.choose('Spell', srcs)['version'] == '1.60.1.1'


def test_the_folder_of_links_holds_one_file_per_table(tmp_path):
    srcs = three(tmp_path)
    ex, fe, at = (d for _, d in srcs)
    write(ex, 'Map.1.60.1.70862.csv', 73)
    write(fe, 'Map.1.60.1.70888.csv', 78)
    write(ex, 'ItemSparse.1.60.1.70862.csv', 5)
    write(at, 'SkillLineAbility.1.60.1.70862.csv', 3)
    dest = str(tmp_path / 'chosen')
    os.makedirs(dest)
    write(dest, 'Old.1.60.1.1.csv', 1)               # a table no source has any more
    seen = []
    assert ct.chosen_dir(dest, srcs, log=seen.append) == dest
    csvs = sorted(n for n in os.listdir(dest) if n.endswith('.csv'))
    assert csvs == ['ItemSparse.1.60.1.70862.csv', 'Map.1.60.1.70888.csv', 'SkillLineAbility.1.60.1.70862.csv']
    assert os.path.realpath(os.path.join(dest, 'Map.1.60.1.70888.csv')) == os.path.realpath(os.path.join(fe, 'Map.1.60.1.70888.csv'))
    with open(os.path.join(dest, ct.REPORT), encoding='utf-8') as fh:
        report = fh.read()
    assert 'Map' in report and 'wago.tools' in report and '78 rows' in report
    assert any(line.startswith('Map ') for line in seen)
    # the builders read it like any folder
    import att_data
    assert att_data.wago_csv(dest, 'Map').endswith('Map.1.60.1.70888.csv')
    assert len(list(att_data.wago_rows('Map', dest))) == 78
    # again: the same (and a newer export takes over)
    write(ex, 'Map.1.60.1.70900.csv', 80)
    ct.chosen_dir(dest, srcs)
    assert att_data.wago_csv(dest, 'Map').endswith('Map.1.60.1.70900.csv')
    assert not os.path.exists(os.path.join(dest, 'Map.1.60.1.70888.csv'))


def test_an_explicit_folder_wins(tmp_path, monkeypatch):
    """A builder given --wago reads that folder and never lays out the choice; without one it reads the
    folder of links (client_tables.default_dir())."""
    import build_raidcheck
    called = []
    monkeypatch.setattr(ct, 'default_dir', lambda: called.append(1) or str(tmp_path / 'chosen'))
    got = []
    data = {'slotsFrom': 'client', 'flask': {}, 'elixir': {}, 'food': {}, 'buffs': {}}
    monkeypatch.setattr(build_raidcheck, 'build', lambda dirs: got.append(dirs) or data)
    monkeypatch.setattr(build_raidcheck, 'render_lua', lambda d: '')
    out = str(tmp_path / 'out.lua')
    build_raidcheck.main(['--wago', str(tmp_path / 'mine'), '--out', out])
    assert got == [[str(tmp_path / 'mine')]] and called == []
    build_raidcheck.main(['--out', out])
    assert got[1] == [str(tmp_path / 'chosen')] and called == [1]


def test_tables_is_the_export_list_and_holds_every_builders_table():
    assert ct.TABLES == ct.read_tables(ct.EXPORT_SCRIPT) and len(ct.TABLES) == len(set(ct.TABLES)) >= 50
    import build_bis
    import build_enchants
    import build_magescrolls
    import build_raidcheck
    import build_talents
    import build
    wanted = set(build_bis.TABLES) | set(build_bis.DMG_TABLES.values())
    for mod in (build_enchants, build_magescrolls, build_raidcheck, build_talents):
        wanted |= set(mod.REQUIRED) | set(getattr(mod, 'OPTIONAL', []))
    wanted |= set(build.MAGESCROLL_TABLES) | set(build.RAIDCHECK_TABLES) | set(build.ENCHANT_TABLES)
    wanted |= {'LFGDungeons', 'ContentTuning', 'AreaTable', 'DungeonEncounter', 'UiMapAssignment', 'Map',
               'LoadingScreens', 'SkillLineAbility', 'SpellReagents', 'SkillLine', 'SpellCooldowns', 'SpellCategories'}
    assert not wanted - set(ct.TABLES), sorted(wanted - set(ct.TABLES))


def test_the_three_places():
    labels = [lab for lab, _ in ct.sources()]
    assert labels == ['export', 'wago.tools', 'att']
    assert ct.sources()[0][1].endswith('_wago') and ct.sources()[1][1] == ct.FETCHED
    assert ct.att_dir().endswith(os.path.join('.config', '.wago'))
