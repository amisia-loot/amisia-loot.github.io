"""A data file that arrives after the game changed must not put its tables on the page (index.html).

tools/tests/site_load.cjs cuts loadGame and loadCraft out of the page, fakes the script loader and
finishes the scripts in the wrong order.
"""
import json
import os
import shutil
import subprocess

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DRIVER = os.path.join(ROOT, 'tools', 'tests', 'site_load.cjs')


@pytest.fixture(scope='module')
def out():
    node = shutil.which('node')
    if not node:
        pytest.skip('node is not installed')
    p = subprocess.run([node, DRIVER], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    assert p.returncode == 0, p.stderr.decode('utf-8', 'replace')
    return json.loads(p.stdout.decode('utf-8'))


def test_opening_the_archive_directly_ends_on_the_archive(out):
    o = out['directArchive']
    assert o['gameKey'] == 'tbc' and o['DATA'] == {'tag': 'TBC'} and o['dataState'] == 'ok'


def test_a_late_archive_script_does_not_replace_forever(out):
    assert out['afterLate']['gameKey'] == 'forever'
    assert out['afterLate']['DATA'] is None, 'tbc.js arriving while Forever is on show applies nothing'
    o = out['leaveEarly']
    assert o['DATA'] == {'tag': 'FOREVER'} and o['dataState'] == 'ok', 'Forever applies when its own script ends'


def test_late_crafting_tables_are_not_applied(out):
    assert out['lateCraft']['CRAFT'] is None and out['lateCraft']['craftState'] != 'ok'


def test_the_crafting_tables_of_the_game_on_show_apply(out):
    assert out['ownCraft'] == {'CRAFT': {'tag': 'CRAFT'}, 'craftState': 'ok'}
