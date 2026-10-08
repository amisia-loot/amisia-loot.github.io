"""DKP/EPGP on the site after the review (index.html): a raid is one raid by its key date:instance, so two
officers' exports of it count once; an export older than the one the ledger took over is left out; the
backup restore keeps the points; a viewer's text for the addon holds only the standings the Points tab
shows them. tools/tests/site_points_review.cjs drives the page.
"""
import json
import os
import shutil
import subprocess

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DRIVER = os.path.join(ROOT, 'tools', 'tests', 'site_points_review.cjs')


@pytest.fixture(scope='module')
def out():
    node = shutil.which('node') or os.path.expanduser('~/.local/node/bin/node')
    if not os.path.exists(node):
        pytest.skip('node is not installed')
    p = subprocess.run([node, DRIVER], capture_output=True, text=True, timeout=120)
    assert p.returncode == 0, p.stderr
    return json.loads(p.stdout)


def test_two_officers_exports_of_one_raid_count_once(out):
    first, second = out['officers']
    assert first['status'] == ['new'] and first['fraktur'] == 15
    assert second['status'] == ['update'] and second['other'] == [True], second
    assert second['fraktur'] == 15, 'the second export replaces the first, it does not add to it'


def test_exports_of_an_older_addon_name_the_raid_by_the_s_line(out):
    first, second = out['officersOld']
    assert second['status'] == ['update'] and second['fraktur'] == 15, second


def test_an_older_export_of_a_raid_is_left_out(out):
    assert out['full']['fraktur'] == 20
    assert out['mid'] == {'status': ['older'], 'other': [False], 'applied': 0, 'fraktur': 20}
    assert out['midOther']['status'] == ['older'] and out['midOther']['applied'] == 0
    assert out['oldFull']['fraktur'] == 20 and out['oldMid']['status'] == ['older'] and out['oldMid']['fraktur'] == 20, 'an older addon: by its earnings'
    assert out['stored'] == {'date': '2026-10-07', 'sys': 'dkp', 'on': True, 'key': '2026-10-07:533', 'at': 1791402000}


def test_the_text_for_the_addon_names_the_raid_by_its_key(out):
    lines = out['text'].split('\n')
    assert 'R 20261007200000-533' in lines and 'K 2026-10-07:533' in lines


def test_the_backup_restore_keeps_the_points(out):
    r = out['restore']
    assert r['has'] and r['sys'] == 'dkp'
    assert r['log'] == 4, 'three earnings and a correction, the broken entries left out'
    assert r['raids'] == ['20261007200000-533'] and r['junk'] is False
    assert out['restoreNone'] is False, 'a backup without points adds none'


def test_a_viewer_gets_only_what_the_points_tab_shows(out):
    assert out['viewerHidden'] == [], 'pub=0 and not signed in: no standings'
    assert out['viewerOwn'] == ['P Chorf 7'], 'pub=0: the own main'
    assert out['viewerPub'] == ['P Fraktur 20', 'P Chorf 7']
    assert out['editor'] == ['P Fraktur 20', 'P Chorf 7']


def test_no_dead_points_code():
    html = open(os.path.join(ROOT, 'index.html'), encoding='utf-8').read()
    assert 'ptItemCost' not in html and 'ptSlot' not in html
