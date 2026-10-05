"""A raid material the addon learned on its own reaches the site with its name.

The addon runs under the Lua stub of addon/tests: a trade good drops in a raid recording, is looted
and counted in the guild bank. The export carries it as an L line and a B line, both named in an N
line, and the ledger's own parser (tools/tests/site_parser.cjs) reads loot, count and name back.
"""
import json
import os
import shutil
import subprocess
import sys

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ADDON_TESTS = os.path.join(ROOT, 'addon', 'tests')
DRIVER = os.path.join(ROOT, 'tools', 'tests', 'site_parser.cjs')

sys.path.insert(0, ADDON_TESTS)

PRELOAD = r'''--[[preload
STUB.gbank = { { [1] = { 61001, 9 } } }
GetNumGuildBankTabs = function() return #STUB.gbank end
GetGuildBankTabInfo = function(tab) return "Tab " .. tab, 0, true end
QueryGuildBankTab = function() end
GetCurrentGuildBankTab = function() return 1 end
GetGuildBankItemLink = function(tab, slot)
    local e = STUB.gbank[tab] and STUB.gbank[tab][slot]
    return e and ("|cffffffff|Hitem:%d::::::::60:::::|h[x]|h|r"):format(e[1])
end
GetGuildBankItemInfo = function(tab, slot)
    local e = STUB.gbank[tab] and STUB.gbank[tab][slot]
    return 134, e and e[2] or 0
end
]]
'''


@pytest.fixture(scope='module')
def parsed():
    run = pytest.importorskip('run', reason='addon/tests/run.py needs lupa')
    node = shutil.which('node')
    if not node:
        pytest.skip('node is not installed')
    lua = run.fresh(PRELOAD)
    lua.execute(r'''
        STUB.instance = { name = "Geschmolzener Kern", type = "raid", id = 409 }
        STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
        STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
        local core = STUB.item(61001, "Fiery Core", 3)
        STUB.items[61001].classID, STUB.items[61001].subclassID = 7, 10
        STUB.loot = { { link = core, name = "x", src = "Creature-0-1-409-1-11982-1" } }
        STUB.fire("LOOT_OPENED")
        STUB.fire("CHAT_MSG_LOOT", ("%s receives loot: %sx2."):format("Fraktur", core))
        STUB.fire("GUILDBANKFRAME_OPENED"); STUB.tick(1)
        STUB.fire("GUILDBANKFRAME_CLOSED")
        EXPORT = NS.ExportText({ NS.Active() })
    ''')
    text = lua.eval('EXPORT')
    p = subprocess.run([node, DRIVER], input=text.encode('utf-8'), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    assert p.returncode == 0, p.stderr.decode('utf-8', 'replace')
    return text, json.loads(p.stdout.decode('utf-8'))


def test_the_export_carries_the_learned_material(parsed):
    text, _ = parsed
    lines = text.split('\n')
    assert 'L Fraktur 61001 2' in lines
    assert 'B 61001 9' in lines
    assert 'N 61001 3 Fiery Core' in lines
    assert not any(line.startswith('D ') or line.startswith('I ') for line in lines), 'a material is no drop and no item'


def test_the_site_reads_loot_count_and_name(parsed):
    _, out = parsed
    s = out['sessions'][0]
    assert s['loot'] == [{'name': 'Fraktur', 'item': 61001, 'count': 2}]
    assert s['names']['61001'] == {'n': 'Fiery Core', 'q': 3}
    assert out['bank']['items'] == {'61001': 9}
    assert out['bank']['names']['61001'] == {'n': 'Fiery Core', 'q': 3}
