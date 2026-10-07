"""tools/export_db2.ps1 (runs on the PC, no PowerShell here): its table lists read as text. Every
table is asked for once (SkillLine serves the professions and the talents), and each table stands
under the comment of the build that reads it."""
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(os.path.dirname(HERE), 'export_db2.ps1')


def source():
    with open(SCRIPT, encoding='utf-8') as fh:
        return fh.read()


def array(text, name):
    m = re.search(r'^\$' + name + r' = @\((.*?)^\)', text, re.S | re.M)
    assert m, name
    return m.group(1)


def names(block):
    out = []
    for line in block.split('\n'):
        line = line.split('#')[0]
        out += re.findall(r"'([A-Za-z0-9_]+)'", line)
    return out


def test_the_final_list_has_every_table_once():
    text = source()
    req, opt, tal = (names(array(text, n)) for n in ('RequiredTables', 'OptionalTables', 'TalentTables'))
    # the script joins the talent tables into the optional ones without repeats and without the
    # required ones
    assert re.search(r'^\$OptionalTables = @\(@\(\$OptionalTables\) \+ @\(\$TalentTables\) \| '
                     r'Where-Object \{ \$RequiredTables -notcontains \$_ \} \| Select-Object -Unique\)$', text, re.M)
    final = req + list(dict.fromkeys(t for t in opt + tal if t not in req))
    assert len(final) == len(set(final))
    assert final.count('SkillLine') == 1 and 'SkillLine' in tal


def test_each_table_under_its_build():
    block = array(source(), 'OptionalTables')
    parts = re.split(r'^\s*#', block, flags=re.M)
    prof = next(p for p in parts if 'build_professions.py' in p)
    art = next((p for p in parts if 'build_dungeonart.py' in p), '')
    assert 'LoadingScreens' not in prof, 'LoadingScreens is no professions table'
    assert 'LoadingScreens' in art, 'LoadingScreens under the comment of build_dungeonart.py'
