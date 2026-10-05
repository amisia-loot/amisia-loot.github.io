"""The data files of the site since 2.0: WoW Forever, plus the TBC Anniversary archive.

data/ holds the Forever loot tables and, for the read-only archive only, the TBC loot and crafting
tables and the TBC boss names. Every file index.html loads must exist, and the TBC boss name table
must stay exactly what it was before the other games were filtered out.
"""
import hashlib
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = os.path.join(ROOT, 'data')
# sha256 of the line window.__BOSSNAMES["tbc"]=...; as it was before classic, sod and mop went
TBC_BOSSNAMES_SHA256 = 'd189170c86d1ab92355f39d226f93eaa2d98292d50c05bf9cf4d748c5e67d605'


def page():
    with open(os.path.join(ROOT, 'index.html'), encoding='utf-8') as fh:
        return fh.read()


def test_data_holds_forever_and_the_tbc_archive_only():
    names = sorted(os.listdir(DATA))
    allowed = re.compile(r'^(forever|tbc|craft-tbc)(\.[0-9a-f]{8}\.jpg|\.js)$|^bossnames\.js$')
    assert [n for n in names if not allowed.match(n)] == [], names
    for need in ('forever.js', 'tbc.js', 'craft-tbc.js', 'bossnames.js'):
        assert need in names
    for prefix in ('forever.', 'tbc.', 'craft-tbc.'):
        assert len([n for n in names if n.startswith(prefix) and n.endswith('.jpg')]) == 1, prefix


def test_bossnames_holds_the_tbc_table_unchanged():
    with open(os.path.join(DATA, 'bossnames.js'), 'rb') as fh:
        lines = fh.read().split(b'\n')
    tables = [l for l in lines if l.startswith(b'window.__BOSSNAMES[')]
    assert [re.match(rb'window\.__BOSSNAMES\["([a-z]+)"\]', l).group(1) for l in tables] == [b'tbc']
    assert hashlib.sha256(tables[0]).hexdigest() == TBC_BOSSNAMES_SHA256
    json.loads(tables[0][len(b'window.__BOSSNAMES["tbc"]='):].rstrip(b';').decode('utf-8'))


def test_the_tbc_files_are_marked_archive_only():
    for name in ('tbc.js', 'craft-tbc.js'):
        with open(os.path.join(DATA, name), encoding='utf-8') as fh:
            head = fh.readline()
        assert head.startswith('// Archive only since Amisia 2.0'), name


def sprite_of(name):
    with open(os.path.join(DATA, name), encoding='utf-8') as fh:
        m = re.search(r'"sprite":\{"file":"([^"]+)"', fh.read())
    return m and m.group(1)


def test_every_file_the_page_loads_exists():
    src = page()
    files = set(re.findall(r"file:'(data/[^']+)'", src))
    files |= {'data/craft-%s.js' % k for k in re.findall(r"craft:'([a-z]+)'", src)}
    files.add('data/bossnames.js')
    assert files == {'data/forever.js', 'data/tbc.js', 'data/craft-tbc.js', 'data/bossnames.js'}, files
    for f in sorted(files):
        assert os.path.isfile(os.path.join(ROOT, f)), f
        sp = sprite_of(os.path.basename(f))
        if sp:
            assert os.path.isfile(os.path.join(ROOT, sp)), sp


def test_build_id_is_new_since_1_9():
    m = re.search(r"const BUILD_ID = '(\d+)';", page())
    assert m and m.group(1) != '1790101610', 'a data file changed: browsers must not keep the cached copy'
