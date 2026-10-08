"""The guild bank needs, pledges and log on the ledger (index.html), from the addon's BQ, BP and BT lines.

tools/tests/site_bank.cjs cuts the code out of the page: the log merge follows the addon's dedupe
rule (same tab, kind, name, item, count and move tabs, overlapping time windows, one to one), an
import takes only a newer needs list, and each needed material gets a line against the last count.
"""
import json
import os
import shutil
import subprocess

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DRIVER = os.path.join(ROOT, 'tools', 'tests', 'site_bank.cjs')


@pytest.fixture(scope='module')
def out():
    node = shutil.which('node')
    if not node:
        pytest.skip('node is not installed')
    p = subprocess.run([node, DRIVER], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    assert p.returncode == 0, p.stderr.decode('utf-8', 'replace')
    return json.loads(p.stdout.decode('utf-8'))


def test_the_log_merges_without_duplicates(out):
    assert out['narrow'] == {'n': 1, 'added': 0, 'lo': 3000, 'hi': 4600}, 'one entry, the window narrowed'
    assert out['twins'] == 2, 'two equal deposits in one export stay two'
    assert out['third'] == 1, 'a third one in a later export is new'
    assert out['others'] == 3, 'another hour, name or count is another entry'
    assert out['cap']['n'] == 1000 and out['cap']['first'] == 1099 * 4000 + 3600, 'the newest 1000, newest first'


def test_an_import_takes_only_newer_needs(out):
    assert out['fresh']['needs']['at'] == 100 and out['fresh']['logNew'] == 1
    assert out['older'] is None, 'an older list never rolls a newer one back'
    assert out['samePledges'] is None, 'nothing new: nothing to import'
    assert out['newPledges']['needs']['pledges'] == [], 'the same list with other pledges replaces them'
    assert out['empty']['parsed'] == {'at': 200, 'by': 'Vulo Sturmwind', 'items': {}, 'pledges': []}, out['empty']
    assert out['empty']['resolved']['needs']['items'] == {}, 'an emptied list replaces the old one'


def test_the_need_line_of_a_material(out):
    low, tgt, ok, unknown, none = out['need']
    assert low['level'] == 'low' and low['short'] == 28 and low['pledged'] == 12, low
    assert tgt['level'] == 'tgt' and tgt['short'] == 40
    assert ok['level'] == 'ok' and ok['short'] == 0
    assert unknown['level'] == 'unknown' and unknown['have'] is None, 'needed but not counted'
    assert none is None, 'no need, no line'
    assert out['mats'] == [61001, 61002, 61003, 61004], 'a needed material is listed even without a count'


def test_the_page_wires_the_import_and_the_mats_tab():
    src = open(os.path.join(ROOT, 'index.html'), encoding='utf-8').read()
    assert "'bankNeeds', 'bankLog'" in src, 'kept per game'
    assert 'bankNeeds:d.bankNeeds' in src and 'bankLog:Array.isArray(d.bankLog)' in src, 'kept on load'
    assert "+bankLine(m.id)+needLine(m.id)+" in src, 'the need line on each material'
    assert 'id="matLogPanel"' in src and 'function renderBankLog()' in src, 'the log on the Mats tab'
    assert "parts.push('the guild bank needs')" in src, 'the import says what it brings'
