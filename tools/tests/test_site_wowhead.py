"""Forever items link to Wowhead's Forever database, the TBC archive stays on TBC (index.html).

tools/tests/site_wowhead.cjs runs the link builders and the icon lookup out of the page. Wowhead's
tooltip script names the data environments: TBC is 5, Forever ("forever") is 16.
"""
import json
import os
import shutil
import subprocess

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DRIVER = os.path.join(ROOT, 'tools', 'tests', 'site_wowhead.cjs')


@pytest.fixture(scope='module')
def out():
    node = shutil.which('node')
    if not node:
        pytest.skip('node is not installed')
    p = subprocess.run([node, DRIVER], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    assert p.returncode == 0, p.stderr.decode('utf-8', 'replace')
    return json.loads(p.stdout.decode('utf-8'))


def test_forever_links_to_the_forever_database(out):
    o = out['forever']
    assert o['db'] == 'forever'
    assert 'href="https://www.wowhead.com/forever/item=12345"' in o['link'], o['link']
    assert 'href="https://www.wowhead.com/forever/item=12345"' in o['html'], o['html']
    assert '/classic/' not in o['link'] + o['html']


def test_forever_icons_come_from_data_environment_16(out):
    assert out['forever']['env'] == 16
    assert out['forever']['asked'] == ['https://nether.wowhead.com/tooltip/item/12345?dataEnv=16']


def test_the_tbc_archive_stays_on_tbc(out):
    o = out['tbc']
    assert o['db'] == 'tbc' and o['env'] == 5
    assert 'href="https://www.wowhead.com/tbc/item=12345"' in o['link'], o['link']
    assert o['asked'] == ['https://nether.wowhead.com/tooltip/item/12345?dataEnv=5']


def test_the_icon_lookup_runs_in_the_browser():
    # the page asks Wowhead itself (fetch in the visitor's browser); no tool fetches for the site
    with open(os.path.join(ROOT, 'index.html'), encoding='utf-8') as fh:
        page = fh.read()
    assert "fetch('https://nether.wowhead.com/tooltip/item/'" in page
    assert 'WOWHEAD_ENV = {tbc: 5, forever: 16}' in page
