"""Only the first raid of a night decides who came in late (amLate in index.html).

On a night of Hyjal and then Black Temple, whoever joins Black Temple after its start is not
late, and importing the Black Temple session must neither add marks nor clear Hyjal's.
"""
import json
import os
import shutil
import subprocess

import pytest

DRIVER = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'site_late.cjs')


@pytest.fixture(scope='module')
def nights():
    node = shutil.which('node')
    if not node:
        pytest.skip('node is not installed')
    p = subprocess.run([node, DRIVER], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    assert p.returncode == 0, p.stderr.decode('utf-8', 'replace')
    return json.loads(p.stdout.decode('utf-8'))


def test_the_second_raid_leaves_the_first_raids_marks(nights):
    n = nights['hyjalThenBt']
    assert n['late'] == {'Buxxbaum': 2, 'Ziepel': 3}
    assert n['lateRaid'] == {'instance': 534, 'start': '20260923194932'}


def test_the_first_raid_wins_when_it_is_imported_last(nights):
    assert nights['btThenHyjal'] == nights['hyjalThenBt']


def test_a_second_recording_of_the_first_raid_still_corrects_it(nights):
    n = nights['secondOfficer']
    assert n['late'] == {'Ziepel': 3, 'Corpina': 4}, 'a punctual line clears, a late one adds'
    assert n['lateRaid'] == {'instance': 534, 'start': '20260923194932'}


def test_a_night_with_one_raid_keeps_its_marks(nights):
    assert nights['btAlone']['late'] == {'Chorf': 6}


def test_a_night_imported_before_the_rule_is_set_right(nights):
    assert nights['legacy'] == nights['hyjalThenBt']
