"""The addon writes the export, the site reads it: this test holds the two against each other.

The addon runs under the Lua stub of addon/tests and writes a real export; the ledger's own
parser is cut out of index.html and reads it back (tools/tests/site_parser.cjs). A line the addon
starts writing differently, or a field it moves, fails here instead of quietly disappearing from
the site.
"""
import json
import os
import subprocess
import sys

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ADDON_TESTS = os.path.join(ROOT, 'addon', 'tests')
DRIVER = os.path.join(ROOT, 'tools', 'tests', 'site_parser.cjs')
CORE = os.path.join(ROOT, 'addon', 'Amisia', 'Core.lua')

sys.path.insert(0, ADDON_TESTS)


def export_from_addon():
    """Records a raid with the real addon code and returns its export text."""
    run = pytest.importorskip('run', reason='addon/tests/run.py needs lupa')
    lua = run.fresh()
    lua.execute(r'''
        -- ten minutes before the raid start of that night, so the first roster is punctual
        local start = NS.LateCutoff(STUB.now)
        STUB.now = start - 600
        STUB.roster = {
            { name = "Vuloo", class = "PRIEST" },
            { name = "Fraktur", class = "SHAMAN" },
        }
        STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)

        -- somebody who only turns up half an hour after the raid start
        STUB.now = start + 1800
        STUB.roster[3] = { name = "Spaetling", class = "MAGE" }
        STUB.fire("GROUP_ROSTER_UPDATE"); STUB.tick(2)

        -- three of a material
        local mark = STUB.item(32897, "Mark of the Illidari", 4)
        STUB.fire("CHAT_MSG_LOOT", ("%s receives loot: %sx3."):format("Fraktur", mark))

        -- a loot window on a boss whose name the client shows in its own language,
        -- the epic out of it, and the master looter's hand-out of that epic
        local epic = STUB.item(32235, "Cursed Vision of Sargeras", 4)
        STUB.loot = { { link = epic, name = "Cursed Vision of Sargeras", src = "Creature-0-1-564-1-22917-1" } }
        STUB.target, STUB.targetGUID = "Illidan Sturmgrimm", "Creature-0-1-564-1-22917-1"
        STUB.fire("LOOT_OPENED")
        STUB.fire("CHAT_MSG_LOOT", ("%s receives loot: %s."):format("Fraktur", epic))
        NS.AwardCommand("Fraktur 32235 sr")

        EXPORT = NS.ExportText({ NS.Active() })
    ''')
    return lua.eval('EXPORT')


def read_back(text):
    if not shutil_which('node'):
        pytest.skip('node is not installed')
    p = subprocess.run([shutil_which('node'), DRIVER], input=text.encode('utf-8'),
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    assert p.returncode == 0, p.stderr.decode('utf-8', 'replace')
    return json.loads(p.stdout.decode('utf-8'))


def shutil_which(name):
    import shutil
    return shutil.which(name)


@pytest.fixture(scope='module')
def parsed():
    text = export_from_addon()
    return text, read_back(text)


def test_every_line_the_addon_writes_is_read(parsed):
    text, out = parsed
    import re
    written = set(re.findall(r'^\s*lines\[#lines \+ 1\] = \("([A-Z])', open(CORE, encoding='utf-8').read(), re.M))
    read = set(out['letters'])
    assert not (written - read), 'the addon writes lines the site throws away: ' + ', '.join(sorted(written - read))


def test_the_session_comes_across(parsed):
    text, out = parsed
    assert out['blocks'] == 1 and out['rest'] == '', 'the whole export is one Amisia block'
    assert len(out['sessions']) == 1
    s = out['sessions'][0]
    assert s['instance'] == 564 and s['zone'] == 'Black Temple'
    assert s['date'] == '2026-09-09'


def test_the_roster_keeps_class_and_delay(parsed):
    text, out = parsed
    m = {x['name']: x for x in out['sessions'][0]['members']}
    assert set(m) == {'Vuloo', 'Fraktur', 'Spaetling'}
    assert m['Fraktur']['cls'] == 'Shaman', 'the class of the export reaches the ledger'
    assert m['Spaetling']['late'] is True and m['Spaetling']['first'] > 0
    assert m['Fraktur']['late'] is False


def test_loot_items_drops_and_awards(parsed):
    text, out = parsed
    s = out['sessions'][0]
    assert {'name': 'Fraktur', 'item': 32897, 'count': 3} in s['loot'], 'materials'
    assert {'name': 'Fraktur', 'item': 32235, 'count': 1} in s['items'], 'blue and better loot'
    assert any(d['item'] == 32235 and d['source'] == 'Illidan Sturmgrimm' for d in s['drops']), 'loot windows'
    a = s['awards'][0]
    assert a['name'] == 'Fraktur' and a['item'] == 32235 and a['kind'] == 'SR' and a['at'] > 0
    assert s['names']['32235']['n'] == 'Cursed Vision of Sargeras' and s['names']['32235']['q'] == 4


def test_a_hand_out_becomes_an_award_row(parsed):
    text, out = parsed
    rows = out['awardRows']
    assert len(rows) == 1
    assert rows[0]['name'] == 'Fraktur' and rows[0]['item'] == 32235
    assert rows[0]['note'] == 'SR' and rows[0]['boss'] == 'Illidan Sturmgrimm'
    assert rows[0]['cls'] == 'Shaman', 'the class comes out of the session'


def test_the_guild_bank_count(parsed):
    text, out = parsed
    assert out['bank'] is None, 'this export carries no count'
    block = '\n'.join(['#AMISIA 1 Vuloo', 'K 1789400000 2026-09-20 21:30 6 6 6 Vuloo',
                       'B 32897 120', 'B 32428 44', '#END'])
    bank = read_back(block)['bank']
    assert bank['at'] == 1789400000 and bank['by'] == 'Vuloo' and bank['time'] == '21:30'
    assert bank['filled'] == 6 and bank['tabs'] == 6 and bank['total'] == 6
    assert bank['items'] == {'32897': 120, '32428': 44}
