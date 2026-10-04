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
            { name = "Vulo Sturmwind", class = "MAGE" },
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
    written = set(re.findall(r'^\s*lines\[#lines \+ 1\] = \("([A-Z]{1,2})', open(CORE, encoding='utf-8').read(), re.M))
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
    assert set(m) == {'Vuloo', 'Fraktur', 'Spaetling', 'Vulo Sturmwind'}
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


def test_a_surname_survives_the_round_trip(parsed):
    text, out = parsed
    assert '\nM Vulo_Sturmwind MAGE ' in text, 'the export writes the space as an underscore'
    assert text.startswith('#AMISIA 2 ')
    names = {m['name'] for m in out['sessions'][0]['members']}
    assert 'Vulo Sturmwind' in names, names


def export_awards_from_addon():
    """Records a raid whose awards carry the history of 1.5: a renamed award with a note, one to the
    guild bank, one disenchanted and one deleted."""
    run = pytest.importorskip('run', reason='addon/tests/run.py needs lupa')
    lua = run.fresh()
    lua.execute(r'''
        STUB.roster = {
            { name = "Vuloo", class = "PRIEST" },
            { name = "Fraktur", class = "SHAMAN" },
            { name = "Vulo Sturmwind", class = "MAGE" },
        }
        STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
        STUB.item(32235, "Cursed Vision of Sargeras", 4)
        STUB.item(32837, "Warglaive of Azzinoth", 5)
        STUB.item(32838, "Warglaive of Azzinoth", 5)
        STUB.item(32524, "Shroud of the Highborne", 4)
        local s = NS.Active()
        local a = NS.AddAwardTo(s, { name = "Fraktur", item = 32235, kind = "MS", src = "Illidan Sturmgrimm", t = 1757444400 })
        STUB.tick(60)
        NS.EditAward(s, a.id, { name = "Vulo Sturmwind", note = "Tausch mit Fraktur" })
        local b = NS.AddAwardTo(s, { name = "Vulo Bank", item = 32837, kind = "MS", src = "Illidan Sturmgrimm", t = 1757444460, to = "bank" })
        local d = NS.AddAwardTo(s, { item = 32838, src = "Illidan Sturmgrimm", t = 1757444520, to = "de" })
        local g = NS.AddAwardTo(s, { name = "Vuloo", item = 32524, kind = "OS", src = "Mutter Shahraz", t = 1757444580 })
        STUB.tick(60)
        NS.DeleteAward(s, g.id)
        IDS = { a = a.id, b = b.id, d = d.id, g = g.id, edited = a.edited, deleted = g.deleted }
        EXPORT = NS.ExportText({ s })
    ''')
    ids = lua.eval('IDS')
    return lua.eval('EXPORT'), {k: ids[k] for k in ('a', 'b', 'd', 'g', 'edited', 'deleted')}


@pytest.fixture(scope='module')
def parsed15():
    text, ids = export_awards_from_addon()
    return text, ids, read_back(text)


def test_the_history_lines_reach_the_site(parsed15):
    text, ids, out = parsed15
    s = out['sessions'][0]
    assert 'A Vulo_Sturmwind 32235 1757444400 MS Illidan Sturmgrimm\nAX %s %d Fraktur Tausch mit Fraktur\n' % (ids['a'], ids['edited']) in text
    a = s['awards'][0]
    assert a['name'] == 'Vulo Sturmwind' and a['uid'] == ids['a'] and a['edited'] == ids['edited']
    assert a['orig'] == 'Fraktur' and a['note'] == 'Tausch mit Fraktur'
    assert [(x['uid'], x['item'], x['to'], x['receiver'], x['source']) for x in s['away']] == [
        (ids['b'], 32837, 'bank', 'Vulo Bank', 'Illidan Sturmgrimm'), (ids['d'], 32838, 'de', None, 'Illidan Sturmgrimm')]
    assert s['gone'] == [{'uid': ids['g'], 'item': 32524, 'at': 1757444580, 'deleted': ids['deleted']}]
    assert set(s['names']) >= {'32235', '32837', '32838', '32524'}, 'bank, disenchant and tombstone items are named'
    rows = out['awardRows']
    assert [(r['item'], r['name'], r.get('amKey'), r.get('away')) for r in rows] == [
        (32235, 'Vulo Sturmwind', ids['a'], None), (32837, 'Vulo Bank', ids['b'], 'bank'), (32838, '', ids['d'], 'de')]
    assert rows[0]['orig'] == 'Fraktur' and rows[0]['amEdited'] == ids['edited'] and rows[0]['note'] == 'Tausch mit Fraktur'
    assert rows[0]['cls'] == 'Mage', 'the class of the new winner'


def test_an_export_of_1_4_reads_as_before(parsed):
    text, out = parsed
    old = '\n'.join(l for l in text.split('\n') if not l.startswith(('AX ', 'AS ', 'AD ')))
    assert old != text and 'AX ' not in old
    out14 = read_back(old)
    s = out14['sessions'][0]
    assert s['awards'] == [{'name': 'Fraktur', 'item': 32235, 'at': s['awards'][0]['at'], 'kind': 'SR', 'source': 'Illidan Sturmgrimm'}], 'no uid, edited, orig or note'
    assert s['away'] == [] and s['gone'] == []
    rows = out14['awardRows']
    assert len(rows) == 1 and not any(k in rows[0] for k in ('amKey', 'amEdited', 'orig', 'away'))
    assert rows[0]['note'] == 'SR'
    # the same export with the history lines reads the same award, now with its id
    with_id = out['sessions'][0]['awards'][0]
    assert {k: v for k, v in with_id.items() if k not in ('uid', 'edited')} == s['awards'][0]


def test_version_one_exports_still_read():
    text = '\n'.join(['#AMISIA 1 Vuloo', 'S 20260901200000-564 2026-09-01 564 Der Schwarze Tempel',
                      'M Vuloo PRIEST 1 0', 'E', '#END', ''])
    out = read_back(text)
    assert [m['name'] for m in out['sessions'][0]['members']] == ['Vuloo']


def test_a_marker_in_a_note_survives_the_round_trip():
    """A note is free text on the AX line: "#END" or "#AMISIA" inside it must not end the block."""
    run = pytest.importorskip('run', reason='addon/tests/run.py needs lupa')
    lua = run.fresh()
    lua.execute(r'''
        STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
        STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
        STUB.item(32235, "Cursed Vision of Sargeras", 4)
        STUB.item(32837, "Warglaive of Azzinoth", 5)
        local s = NS.Active()
        NS.AddAwardTo(s, { name = "Fraktur", item = 32235, kind = "MS", src = "Illidan Sturmgrimm", note = "bis #END fertig" })
        NS.AddAwardTo(s, { name = "Vuloo", item = 32837, kind = "OS", src = "Illidan Sturmgrimm", note = "#AMISIA 2 #END" })
        EXPORT = NS.ExportText({ s })
    ''')
    text = lua.eval('EXPORT')
    out = read_back(text)
    assert out['blocks'] == 1 and out['rest'] == '', out['rest']
    awards = out['sessions'][0]['awards']
    assert [(a['name'], a['note']) for a in awards] == [('Fraktur', 'bis #END fertig'), ('Vuloo', '#AMISIA 2 #END')]
    assert '32837' in out['sessions'][0]['names'], 'the item names after the awards are read too'
