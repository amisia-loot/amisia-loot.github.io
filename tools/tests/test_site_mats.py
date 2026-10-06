"""The Mats tab of the ledger (index.html) for WoW Forever has no fixed list of materials.

The Amisia addon learns its raid materials on its own, so the page takes the list from the
imported data: every item of the looted materials and of the last guild bank count, named from
the loot tables or from the names the addon sent. The TBC archive keeps its fixed list.
tools/tests/site_mats.cjs cuts the material code out of the page.
"""
import json
import os
import shutil
import subprocess
import sys

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DRIVER = os.path.join(ROOT, 'tools', 'tests', 'site_mats.cjs')


def page():
    with open(os.path.join(ROOT, 'index.html'), encoding='utf-8') as fh:
        return fh.read()


@pytest.fixture(scope='module')
def out():
    node = shutil.which('node')
    if not node:
        pytest.skip('node is not installed')
    p = subprocess.run([node, DRIVER], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    assert p.returncode == 0, p.stderr.decode('utf-8', 'replace')
    return json.loads(p.stdout.decode('utf-8'))


def test_forever_without_imports_has_no_materials(out):
    assert out['empty'] == []


def test_forever_takes_its_materials_from_the_imported_data(out):
    assert out['forever'] == [
        {'id': 61001, 'name': 'Fiery Core'},
        {'id': 61011, 'name': 'Late Cloth'},
        {'id': 61005, 'name': 'Lava Core'},
        {'id': 5001, 'name': 'Table Ore'},
    ], 'looted and counted items, each once, by name'
    assert out['names'] == {'61005': 'Lava Core', '5001': 'Table Ore', '99': 'Item 99'}
    assert out['bankOnly'] == [{'id': 61011, 'name': 'Item 61011'}], 'a bank count alone names its items'


def test_the_tbc_archive_keeps_its_fixed_list(out):
    assert out['tbc'] == [32428, 32897, 32227, 32228, 32229, 32230, 32231, 32249]
    assert out['tbcName'] == 'Mark of the Illidari'


def test_the_page_explains_the_learned_list():
    src = page()
    for text in ('No tracked materials for World of Warcraft Forever yet. The TBC counts are in the TBC archive.',
                 'The Amisia addon learns them on its own',
                 'who looted a tracked material',
                 '(only when materials are tracked)'):
        assert text in src, text
    # the bank count in the import preview shows every counted item, not only a fixed list
    i = src.index('function amBankRender(){')
    body = src[i:src.index('\n}', i)]
    assert 'Object.keys(amBank.items)' in body and 'matsHere()' not in body

