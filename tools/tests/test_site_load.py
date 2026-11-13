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


def test_forever_loads_the_kills_of_the_data_build_once(out):
    """F-187: data/drops-forever.js, with BUILD_ID, only for Forever; the page is drawn again when it arrives."""
    assert 'data/drops-forever.js?v=x' in out['dropsScripts']
    assert out['dropsOk']['DROPS'] == {'v': 1, 'k': [], 'names': {}, 'zones': {}} and out['dropsOk']['state'] == 'ok'
    assert out['dropsOk']['renders'] >= 1
    assert out['dropsArchive'] == {'DROPS': None, 'scripts': 1}, 'the archive has no drops file'
    assert out['dropsBack']['DROPS'] == {'v': 1, 'k': [], 'names': {}, 'zones': {}} and out['dropsBack']['scripts'] == 1, 'loaded once'


def test_a_missing_drops_file_leaves_the_page_working(out):
    assert out['dropsMissing']['DROPS'] is None and out['dropsMissing']['state'] == 'error'


def test_a_late_drops_file_waits_for_its_game(out):
    assert out['dropsLate'] is None, 'the archive on show: the file of Forever is not applied'
    assert out['dropsLateBack'] == {'v': 1, 'k': []}
