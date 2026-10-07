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
CORE = os.path.join(ROOT, 'addon', 'Amisia', 'Core', 'Core.lua')
PRIO = os.path.join(ROOT, 'addon', 'Amisia', 'Raid', 'LootPrio.lua')

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

        -- three of a material (the addon tracks none until the guild names some; the test sets one)
        NS.MATS[32897], NS.MAT_ORDER[1] = "Mark of the Illidari", 32897
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
    written = set()
    for path in (CORE, PRIO):
        written |= set(re.findall(r'^\s*lines\[#lines \+ 1\] = \("([A-Z]{1,2})', open(path, encoding='utf-8').read(), re.M))
    assert 'LC' in written, 'the loot prio lines are found in LootPrio.lua'
    read = set(out['letters'])
    assert not (written - read), 'the addon writes lines the site throws away: ' + ', '.join(sorted(written - read))


def test_the_loot_prio_lines_reach_the_site():
    """An export with loot prio edited in game: the LC lines stand outside the raid blocks."""
    run = pytest.importorskip('run', reason='addon/tests/run.py needs lupa')
    lua = run.fresh()
    text = lua.eval('''function()
        STUB.now = 1788100000
        NS.EditLootPrio(32235, "Anna (Tank), Krieger Furor, offen", "erst Tanks")
        NS.ClearLootPrioItem(32837)
        return NS.ExportText({})
    end''')()
    out = read_back(text)
    assert out['sessions'] == [] and out['blocks'] == 1
    rows = out['prio']['rows']
    assert out['prio']['bad'] == 0 and [r['item'] for r in rows] == [32235, 32837], rows
    assert rows[0]['prio'] == [{'k': 'p', 'name': 'Anna', 'label': 'Tank'}, {'k': 'c', 'cls': 'WARRIOR', 'label': 'Furor'}, {'k': 'o'}]
    assert rows[0]['note'] == 'erst Tanks' and rows[0]['at'] == 1788100000 and rows[1]['prio'] == [] and rows[1]['note'] == ''


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


def export_log_from_addon():
    """Records a raid of 1.7 with the real addon: a boss fight (START/END) with who was there, a
    wipe, a bench entry with a note from an officer and one the raider made himself."""
    run = pytest.importorskip('run', reason='addon/tests/run.py needs lupa')
    lua = run.fresh()
    lua.execute(r'''
        STUB.roster = {
            { name = "Vuloo", class = "PRIEST" },
            { name = "Fraktur", class = "SHAMAN" },
            { name = "Vulo Sturmwind", class = "MAGE" },
        }
        STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
        local s = NS.Active()
        STUB.fire("ENCOUNTER_START", 602, "Supremus", 4, 25)
        STUB.tick(121)
        STUB.fire("ENCOUNTER_END", 602, "Supremus", 4, 25, 0)
        STUB.tick(300)
        STUB.fire("ENCOUNTER_START", 601, "Hochkriegsfürst Naj'entus", 4, 25)
        STUB.tick(192)
        STUB.fire("ENCOUNTER_END", 601, "Hochkriegsfürst Naj'entus", 4, 25, 1, {})
        STUB.tick(2)
        assert(not s.kills[2].wait, "names read")
        assert(NS.BenchAdd(s, "Bob", { note = "ab 21 Uhr", class = "MAGE" }))
        assert(NS.BenchAdd(s, "Kim Eisherz", { self = true }))
        KILLS = { wipeStart = s.kills[1].start, wipeEnd = s.kills[1].t, start = s.kills[2].start, t = s.kills[2].t }
        EXPORT = NS.ExportText({ s })
    ''')
    k = lua.eval('KILLS')
    return lua.eval('EXPORT'), {x: k[x] for x in ('wipeStart', 'wipeEnd', 'start', 't')}


@pytest.fixture(scope='module')
def parsed17():
    text, k = export_log_from_addon()
    return text, k, read_back(text)


def test_boss_attempts_reach_the_site(parsed17):
    text, k, out = parsed17
    assert out['blocks'] == 1 and out['rest'] == ''
    s = out['sessions'][0]
    assert s['kills'] == [
        {'enc': 602, 'start': k['wipeStart'], 'end': k['wipeEnd'], 'ok': False, 'size': 25, 'diff': 4, 'src': 'E', 'name': 'Supremus'},
        {'enc': 601, 'start': k['start'], 'end': k['t'], 'ok': True, 'size': 25, 'diff': 4, 'src': 'E',
         'name': "Hochkriegsfürst Naj'entus", 'present': ['Fraktur', 'Vulo Sturmwind', 'Vuloo']},
    ], s['kills']


def test_the_bench_reaches_the_site(parsed17):
    text, k, out = parsed17
    bench = {b['name']: b for b in out['sessions'][0]['bench']}
    assert set(bench) == {'Bob', 'Kim Eisherz'}
    assert bench['Bob']['cls'] == 'Mage' and bench['Bob']['self'] is False and bench['Bob']['by'] == 'Vuloo'
    assert bench['Bob']['note'] == 'ab 21 Uhr' and bench['Bob']['at'] > 0
    assert bench['Kim Eisherz']['self'] is True and bench['Kim Eisherz']['by'] is None
    assert bench['Kim Eisherz']['note'] == '' and bench['Kim Eisherz']['cls'] == ''
    assert '\nBN Kim_Eisherz ' in text


def test_the_old_lines_read_the_same_with_and_without_the_new_ones(parsed17):
    text, k, out = parsed17
    old = '\n'.join(l for l in text.split('\n') if not l.startswith(('EK ', 'EP ', 'BN ')))
    assert old != text
    s16 = read_back(old)['sessions'][0]
    s17 = out['sessions'][0]
    for key in ('sid', 'date', 'instance', 'zone', 'members', 'loot', 'items', 'drops', 'awards', 'away', 'gone', 'names'):
        assert s16[key] == s17[key], key
    assert s16['kills'] == [] and s16['bench'] == []


def test_strange_log_lines_are_ignored():
    text = '\n'.join(['#AMISIA 2 Vuloo', 'S 20260901200000-564 2026-09-01 564 Der Schwarze Tempel',
                      'M Vuloo PRIEST 1 0', 'EP 999 5 Vuloo', 'BN', 'BN Bob', 'EK 601 1 2 K 25 4 E Supremus',
                      'EP 601 3 Vuloo', 'E', '#END', ''])
    s = read_back(text)['sessions'][0]
    assert [x['name'] for x in s['kills']] == ['Supremus'] and 'present' not in s['kills'][0], 'an EP without its EK is dropped'
    assert s['bench'] == [], 'a BN without a name or its fields is dropped'


BIS = os.path.join(ROOT, 'addon', 'Amisia', 'Gear', 'Bis.lua')


def export_wishes_from_addon():
    """Records a raid, exports it, puts three wishes on the list (one with a note that holds spaces
    and a bar) and exports the raid again; returns both raid exports and the wishlist text."""
    run = pytest.importorskip('run', reason='addon/tests/run.py needs lupa')
    lua = run.fresh()
    lua.execute(r'''
        STUB.player = "Vulo Sturmwind"
        STUB.roster = { { name = "Vulo Sturmwind", class = "WARRIOR" }, { name = "Fraktur", class = "SHAMAN" } }
        STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
        local epic = STUB.item(32235, "Cursed Vision of Sargeras", 4)
        STUB.fire("CHAT_MSG_LOOT", ("%s receives loot: %s."):format("Fraktur", epic))
        local s = NS.Active()
        BEFORE, HASH_BEFORE = NS.ExportText({ s }), NS.SessionHash(s)
        for _, id in ipairs({ 28830, 29434, 30000 }) do
            STUB.item(id, "Item " .. id, 4)
            STUB.items[id].equipLoc = "INVTYPE_CHEST"
        end
        assert(NS.WishAdd(28830, 3, "nur MS | bitte"))
        STUB.tick(5)
        assert(NS.WishAdd(29434, 1))
        assert(NS.WishAdd(30000))
        AFTER, HASH_AFTER = NS.ExportText({ s }), NS.SessionHash(s)
        WISHES = NS.WishExportText()
    ''')
    g = lua.globals()
    return g.BEFORE, g.AFTER, g.HASH_BEFORE, g.HASH_AFTER, g.WISHES


@pytest.fixture(scope='module')
def wishes():
    before, after, hb, ha, text = export_wishes_from_addon()
    return before, after, hb, ha, text, read_back(text)


def test_every_wish_line_the_addon_writes_is_read(wishes):
    import re
    written = set(re.findall(r'^\s*lines\[#lines \+ 1\] = \("([A-Z]{1,2})', open(BIS, encoding='utf-8').read(), re.M))
    assert 'WL' in written, 'the wishlist lines are found in Bis.lua'
    read = set(wishes[5]['letters'])
    assert not (written - read), 'the addon writes lines the site throws away: ' + ', '.join(sorted(written - read))


def test_the_wishes_reach_the_site(wishes):
    text, out = wishes[4], wishes[5]
    assert text.startswith('#AMISIA 2 Vulo_Sturmwind\n') and text.endswith('\n#END')
    assert out['blocks'] == 1 and out['rest'] == '' and out['sessions'] == [], 'a wishlist is no raid'
    w = out['wishes']
    assert [(x['item'], x['prio'], x['name']) for x in w] == [
        (28830, 3, 'Vulo Sturmwind'), (30000, 2, 'Vulo Sturmwind'), (29434, 1, 'Vulo Sturmwind')], w
    assert w[0]['note'] == 'nur MS bitte', 'the bar is gone, the spaces stay: ' + w[0]['note']
    assert w[1]['note'] == '' and w[2]['note'] == ''
    assert all(x['at'] > 0 for x in w) and w[2]['at'] - w[0]['at'] == 5, 'the time of each wish'


def test_the_raid_export_is_the_same_with_and_without_wishes(wishes):
    before, after, hb, ha = wishes[:4]
    assert before == after, 'wishes are not part of the raid export'
    assert hb == ha, 'nor of its fingerprint'
    assert '\nWL ' not in after


DROPS = os.path.join(ROOT, 'addon', 'Amisia', 'Collect', 'Drops.lua')
PAGE = os.path.join(ROOT, 'index.html')


def drops_from_addon(record):
    """Records a raid with two boss loot windows (one after a kill event, one with an epic) and a
    dungeon boss; returns the raid export, its fingerprint and the text "Drops fuer die Website"."""
    run = pytest.importorskip('run', reason='addon/tests/run.py needs lupa')
    lua = run.fresh()
    lua.execute(r'''
        NS.Set("drops.record", %s)
        STUB.roster = {
            { name = "Vuloo", class = "PRIEST" },
            { name = "Fraktur", class = "SHAMAN" },
            { name = "Vulo Sturmwind", class = "MAGE" },
        }
        STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
        local s = NS.Active()
        local epic = STUB.item(32235, "Cursed Vision of Sargeras", 4)
        local green = STUB.item(32236, "Green Thing", 2)
        STUB.fire("ENCOUNTER_END", 601, "Hochkriegsfürst Naj'entus", 4, 25, 1)
        STUB.tick(5)
        STUB.target, STUB.targetGUID = "Hochkriegsfürst Naj'entus", "Creature-0-1-564-1-22887-1"
        STUB.loot = { { link = green, name = "Green Thing", src = "Creature-0-1-564-1-22887-1" } }
        STUB.fire("LOOT_OPENED")
        STUB.tick(600)
        STUB.target, STUB.targetGUID = "Illidan Sturmgrimm", "Creature-0-1-564-1-22917-1"
        STUB.loot = { { link = epic, name = "Cursed Vision of Sargeras", src = "Creature-0-1-564-1-22917-1" },
                      { link = green, name = "Green Thing", src = "Creature-0-1-564-1-22917-1", qty = 2 } }
        STUB.fire("LOOT_OPENED")
        RAID, HASH = NS.ExportText({ s }), NS.SessionHash(s)
        DROPS = NS.DropsExportText()
    ''' % ('true' if record else 'false'))
    g = lua.globals()
    return g.RAID, g.HASH, g.DROPS


def parse_drops(text):
    """The format the spec gives, read field by field: DZ <inst> <party|raid> <name>,
    DN <npc> <enc|0> <name>, DK <h> <npc> <inst> <diff> <YYYY-MM-DD> <origin> <G|E> <id>:<n>,...|-."""
    import re
    out = {'zones': {}, 'names': {}, 'kills': [], 'bad': 0}
    for line in text.split('\n'):
        f = line.split(' ')
        if f[0] == 'DZ':
            m = re.match(r'^DZ (\d+) (party|raid) (.+)$', line)
            if not m:
                out['bad'] += 1
                continue
            out['zones'][int(m.group(1))] = (m.group(2), m.group(3))
        elif f[0] == 'DN':
            m = re.match(r'^DN (\d+) (\d+) (.+)$', line)
            if not m:
                out['bad'] += 1
                continue
            out['names'][int(m.group(1))] = (int(m.group(2)), m.group(3))
        elif f[0] == 'DK':
            m = re.match(r'^DK ([0-9a-f]{8}) (\d+) (\d+) (\d+) (\d{4}-\d\d-\d\d) ([0-9a-f]{8}) ([GE]) (\S+)$', line)
            if not m or not re.match(r'^(-|\d+:\d+(,\d+:\d+)*)$', m.group(8)):
                out['bad'] += 1
                continue
            items = {} if m.group(8) == '-' else {int(a): int(b) for a, b in (x.split(':') for x in m.group(8).split(','))}
            out['kills'].append({'h': m.group(1), 'npc': int(m.group(2)), 'inst': int(m.group(3)), 'diff': int(m.group(4)),
                                 'date': m.group(5), 'o': m.group(6), 'src': m.group(7), 'items': items})
    return out


@pytest.fixture(scope='module')
def drops():
    raid_on, hash_on, text = drops_from_addon(True)
    raid_off, hash_off, empty = drops_from_addon(False)
    return raid_on, hash_on, text, raid_off, hash_off, empty


def test_the_drop_text_follows_the_format(drops):
    text = drops[2]
    lines = text.split('\n')
    assert lines[0] == '#AMISIA 2 Vuloo' and lines[-1] == '#END', 'header with who exports, and the end'
    body = lines[1:-1]
    assert body and all(l[:3] in ('DZ ', 'DN ', 'DK ') for l in body), body
    got = parse_drops(text)
    assert got['bad'] == 0
    assert len(got['kills']) == 2
    k = {x['npc']: x for x in got['kills']}
    assert k[22887]['items'] == {32236: 1} and k[22917]['items'] == {32235: 1, 32236: 2}
    assert all(x['inst'] == 564 and x['src'] == 'G' and x['o'] == k[22887]['o'] for x in got['kills'])
    assert got['zones'] == {564: ('raid', 'Black Temple')}
    assert got['names'][22887] == (601, "Hochkriegsfürst Naj'entus") and got['names'][22917] == (0, 'Illidan Sturmgrimm')


def test_no_player_name_in_the_drop_lines(drops):
    text = drops[2]
    for line in text.split('\n')[1:]:
        for name in ('Vuloo', 'Fraktur', 'Vulo', 'Sturmwind'):
            assert name not in line, line


def test_the_raid_export_is_the_same_with_and_without_drop_records(drops):
    raid_on, hash_on, text, raid_off, hash_off, empty = drops
    assert raid_on == raid_off, 'drop records are not part of the raid export'
    assert hash_on == hash_off, 'nor of its fingerprint'
    assert '\nDK ' not in raid_on and '\nDZ ' not in raid_on and '\nDN ' not in raid_on
    assert empty == '#AMISIA 2 Vuloo\n#END', 'recording off: an empty drop text'


def test_the_site_takes_the_drop_text_as_no_raid(drops):
    out = read_back(drops[2])
    assert out['blocks'] == 1 and out['rest'] == '', 'one Amisia block'
    assert out['sessions'] == [] and out['wishes'] == [] and out['bank'] is None, 'the other parsers skip the drop lines'


def test_every_drop_line_the_addon_writes_has_a_reader(drops):
    import re
    written = set(re.findall(r'^\s*lines\[#lines \+ 1\] = \("([A-Z]{1,2})', open(DROPS, encoding='utf-8').read(), re.M))
    assert written == {'DZ', 'DN', 'DK'}, written
    got = parse_drops(drops[2])
    assert got['zones'] and got['names'] and got['kills'], 'the reference reader reads every kind'
    page = open(PAGE, encoding='utf-8').read()
    assert 'function amParseDrops(' in page, 'the site reads the drop lines'
    found = set(re.findall(r"'(D[ZNK])'", page[page.index('function amParseDrops('):][:4000]))
    assert not (written - found), 'the addon writes drop lines the site throws away: ' + ', '.join(sorted(written - found))
    out = read_back(drops[2])
    assert {'DZ', 'DN', 'DK'} <= set(out['letters']), 'the site parser knows every drop line'


def test_the_drop_text_round_trips_to_the_site(drops):
    """The site's own amParseDrops reads what the addon wrote, field by field as the reference reader."""
    import datetime
    ref = parse_drops(drops[2])
    got = read_back(drops[2])['drops']
    assert got['bad'] == 0
    assert got['zones'] == {str(k): list(v) for k, v in ref['zones'].items()}
    assert got['names'] == {str(k): v[1] for k, v in ref['names'].items() if k > 0}
    day0 = datetime.date(2026, 1, 1)
    want = [{'h': k['h'], 'npc': k['npc'], 'inst': k['inst'], 'diff': k['diff'],
             'day': (datetime.date.fromisoformat(k['date']) - day0).days, 'o': k['o'], 'src': k['src'],
             'items': {str(i): n for i, n in k['items'].items()}} for k in ref['kills']]
    assert got['kills'] == want
