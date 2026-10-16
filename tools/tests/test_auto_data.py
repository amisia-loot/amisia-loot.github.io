"""tools/auto_data.py: when an export counts as complete, which build the data has (DECISIONS D-51)."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import auto_data  # noqa: E402


def write(path, text, age):
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write(text)
    t = 1_000_000 - age
    os.utime(path, (t, t))


def test_complete_builds_wants_every_ok_table_and_a_quiet_folder(tmp_path):
    d = str(tmp_path)
    now = 1_000_000
    # complete and settled
    write(os.path.join(d, '_export.1.60.1.70338.txt'), 'Item\tok\tx\nJournalInstance\tleer\tx\n', 900)
    write(os.path.join(d, 'Item.1.60.1.70338.csv'), 'ID\n', 900)
    # a table still missing (Syncthing busy)
    write(os.path.join(d, '_export.1.60.1.70425.txt'), 'Item\tok\tx\nSpell\tok\tx\n', 900)
    write(os.path.join(d, 'Item.1.60.1.70425.csv'), 'ID\n', 900)
    assert auto_data.complete_builds(d, now=now) == ['1.60.1.70338']
    # all there, but one file only a minute old
    write(os.path.join(d, 'Spell.1.60.1.70425.csv'), 'ID\n', 60)
    assert auto_data.complete_builds(d, now=now) == ['1.60.1.70338']
    # settled: the newest comes last, sorted by number, not by text
    write(os.path.join(d, 'Spell.1.60.1.70425.csv'), 'ID\n', 600)
    write(os.path.join(d, '_export.1.60.1.9999.txt'), 'Item\tok\tx\n', 900)
    write(os.path.join(d, 'Item.1.60.1.9999.csv'), 'ID\n', 900)
    assert auto_data.complete_builds(d, now=now) == ['1.60.1.9999', '1.60.1.70338', '1.60.1.70425']
    # a report without any exported table is no export
    write(os.path.join(d, '_export.1.60.1.80000.txt'), 'Item\tleer\tx\n', 900)
    assert '1.60.1.80000' not in auto_data.complete_builds(d, now=now)
    assert auto_data.complete_builds(str(tmp_path / 'none'), now=now) == []


def test_data_build_reads_the_talent_data_line():
    text = '-- header\nns.LazyData("TALENTS", [=[\nreturn {\nbuild="1.60.1.70425",max=51,\n'
    assert auto_data.data_build(text) == '1.60.1.70425'
    assert auto_data.data_build('') is None
    assert auto_data.build_key('1.60.1.9999') < auto_data.build_key('1.60.1.70338')


def test_the_repo_talent_data_has_a_build():
    with open(os.path.join(auto_data.ROOT, 'Amisia', 'Data', 'TalentData.lua'), encoding='utf-8') as fh:
        assert auto_data.data_build(fh.read())
