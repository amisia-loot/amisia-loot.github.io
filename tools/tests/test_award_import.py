"""The site takes award ids, edits, deletions and bank or disenchant hand-outs from the addon.

tools/tests/site_awards.cjs runs the import functions cut out of index.html against small ledgers;
this test holds what they did against the design: a second import of the same award is a
duplicate, a change made in game moves the award, an older export never undoes a change made on
the site, a deletion in game removes the award for good, an award imported from 1.4 gets its id
filled in, and an item to the bank or the disenchanter creates no raider.
"""
import json
import os
import shutil
import subprocess

import pytest

DRIVER = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'site_awards.cjs')
DATE = '2026-09-09'


@pytest.fixture(scope='module')
def out():
    node = shutil.which('node')
    if not node:
        pytest.skip('node is not installed')
    p = subprocess.run([node, DRIVER], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    assert p.returncode == 0, p.stderr.decode('utf-8', 'replace')
    return json.loads(p.stdout.decode('utf-8'))


def test_the_parser_reads_ids_history_bank_and_tombstones(out):
    p = out['parsed']
    a1, a2 = p['awards']
    assert a1['uid'] == 'id1' and a1['edited'] == 0 and 'orig' not in a1 and 'note' not in a1
    assert a1['name'] == 'Fraktur' and a1['kind'] == 'MS', 'the A line reads as before'
    assert a2['uid'] == 'id2' and a2['edited'] == 1757448000 and a2['orig'] == 'Fraktur' and a2['note'] == 'Tausch mit Fraktur'
    assert p['away'] == [
        {'uid': 'id3', 'item': 32524, 'at': 1757444520, 'to': 'bank', 'receiver': 'Vulo Bank', 'source': 'Mutter Shahraz', 'edited': 0},
        {'uid': 'id4', 'item': 32837, 'at': 1757444580, 'to': 'de', 'receiver': None, 'source': 'Illidan Sturmgrimm', 'edited': 0, 'note': 'zweites Schwert'}]
    assert p['gone'] == [{'uid': 'id5', 'item': 32235, 'at': 1757444640, 'deleted': 1757448100}]


def test_award_rows_carry_the_id_and_join_the_note(out):
    rows = out['rows']
    plain = next(r for r in rows if r['item'] == 32235)
    assert plain['amKey'] == 'id1' and plain['amEdited'] == 0 and 'orig' not in plain and plain['note'] == ''
    noted = next(r for r in rows if r['item'] == 32837 and not r.get('away'))
    assert noted['amKey'] == 'id2' and noted['amEdited'] == 1757448000 and noted['orig'] == 'Fraktur'
    assert noted['os'] is True and noted['note'] == 'Tausch mit Fraktur'
    away = [r for r in rows if r.get('away')]
    assert [(r['away'], r['item'], r['name'], r['amKey']) for r in away] == [('bank', 32524, 'Vulo Bank', 'id3'), ('de', 32837, '', 'id4')]


def test_the_same_export_again_is_a_duplicate(out):
    assert out['dup']['status'] == 'dup' and out['dup']['awardId'] == 'a1'


def test_a_newer_winner_moves_the_award(out):
    c = out['change']
    assert c['row']['status'] == 'change' and c['row']['awardId'] == 'a1'
    assert c['row']['change'] == {'raider': 'Vuloo', 'note': 'Tausch'}
    assert c['result'] == {'changed': 1, 'gone': 0}
    a = c['award']
    assert a['raider'] == 'r2' and a['note'] == 'Tausch' and a['am'] == 'id1' and a['amEdited'] == 1757448000
    assert a['src'] == DATE + '|32235|vuloo', 'the signature follows the winner'
    assert DATE + '|32235|fraktur' in c['dropped'] and not any(d.startswith('m') for d in c['dropped']), 'the old signature is dropped, the id is not'
    assert c['raiders'] == 2, 'no raider invented'
    # the second officer's export of the same hand-out, with its own id or none at all
    old_own, old_plain, new_own = c['secondRecorder']
    assert old_own['status'] == 'dup' and old_own['removed'] is True, 'the old winner shows as Removed'
    assert old_plain['status'] == 'dup' and old_plain['removed'] is True
    assert new_own['status'] == 'dup' and new_own['removed'] is False, 'the new winner is simply there'


def test_an_older_export_does_not_undo_a_change_on_the_site(out):
    o = out['older']
    assert o['row']['status'] == 'dup' and o['result'] == {'changed': 0, 'gone': 0}
    assert o['award']['raider'] == 'r2' and o['award']['note'] == 'OS' and o['award']['amEdited'] == 1757450000


def test_a_note_or_a_new_winner_from_the_roster_or_outside_it(out):
    n = out['noteChange']
    first, second = n['rows']
    assert first['status'] == 'change' and first['change'] == {'note': 'OS · SR'}
    assert second['status'] == 'change' and second['change'] == {'raider': 'Neuling'}
    assert n['result'] == {'changed': 2, 'gone': 0}
    assert n['awards'][0]['note'] == 'OS · SR' and n['awards'][0]['raider'] == 'r1' and n['awards'][0]['amEdited'] == 5
    assert 'Neuling' in n['raiders'] and n['awards'][1]['raider'] not in ('r1', 'r2') and n['awards'][1]['amEdited'] == 7


def test_a_deletion_in_game_removes_the_award_for_good(out):
    g = out['gone']
    assert len(g['rows']) == 1, 'a tombstone the ledger never had is not shown'
    r = g['rows'][0]
    assert r['status'] == 'gone' and r['gone'] is True and r['awardId'] == 'a1' and r['item'] == 32235 and r['name'] == 'Fraktur'
    assert g['result'] == {'changed': 0, 'gone': 1}
    assert g['awards'] == ['a2']
    assert 'mid1' in g['dropped'] and DATE + '|32235|fraktur' in g['dropped']
    assert all(b['status'] == 'dup' and b['removed'] is True for b in g['back']), 'neither the id nor the signature brings it back'
    assert g['passThrough'] == ['gone'], 'resolving again keeps a gone row'


def test_an_award_from_1_4_gets_its_id_filled_in(out):
    f = out['fill']
    plain, renamed, bossed = f['rows']
    assert plain['status'] == 'fill' and plain['awardId'] == 'a1' and plain['fill'] == {'am': 'id1'}
    assert renamed['status'] == 'change' and renamed['awardId'] == 'a2' and renamed['change'] == {'raider': 'Fraktur'}, 'orig names the winner the ledger knows'
    assert bossed['status'] == 'fill' and bossed['fill'] == {'am': 'id3', 'boss': 'Illidan Stormrage'}, 'the id joins what the fill knew already'
    assert f['result'] == {'changed': 1, 'gone': 0}
    a2 = next(a for a in f['awards'] if a['id'] == 'a2')
    assert a2['raider'] == 'r1' and a2['am'] == 'id2' and a2['amEdited'] == 9
    assert {'id': 'a1', 'am': 'id1', 'amEdited': 0} in f['afterFill']
    assert f['again'] == ['dup'], 'after the fill the id is known'


def test_bank_and_disenchant_create_no_raider_and_count_as_handed_out(out):
    w = out['away']
    assert [(r['status'], r['why'], r['away']) for r in w['rows']] == [('skip', 'to the guild bank', 'bank'), ('skip', 'disenchanted', 'de')]
    assert [l['item'] for l in w['before']] == [32524], 'before the import the cloak lies unclaimed'
    assert w['firstStatus'] == 'ok', 'a session with new bank or disenchant entries is new'
    assert w['lootAway'] == [
        {'key': 'id3', 'date': DATE, 'instance': 564, 'item': 32524, 'to': 'bank'},
        {'key': 'id4', 'date': DATE, 'instance': 564, 'item': 32837, 'to': 'de'}]
    assert 'Vulo Bank' not in w['raiders'], 'the bank character is no raider'
    assert w['after'] == [], 'the cloak counts as handed out'
    assert w['secondStatus'] == 'dup' and w['lootAwayAfterTwice'] == 2


def test_a_marker_inside_a_note_does_not_cut_the_block(out):
    want = [['2026-09-09', [['Fraktur', 'aaaaaaaaaaaa', 'bis #END fertig #AMISIA 2 x'], ['Vuloo', 'bbbbbbbbbbbb', '#END']]], ['2026-09-10', []]]
    for k in ('lf', 'crlf'):
        m = out['marker'][k]
        assert m['blocks'] == 1 and m['rest'] == '', (k, m['rest'])
        assert m['sessions'] == want, k
    assert out['marker']['twice']['blocks'] == 2 and out['marker']['twice']['rest'] == ''


def test_two_officers_exports_of_one_raid_import_one_award(out):
    o = out['officers']
    assert o['both'] == ['ok', 'dup'], 'the second recorder\'s id names the same hand-out'
    assert o['twoCopies'] == ['ok', 'ok'], 'two copies in one recording stay two'
    assert o['twoCopiesBoth'] == ['ok', 'ok', 'dup', 'dup']


def test_a_rename_by_the_other_officer_changes_the_award_in_the_ledger(out):
    r = out['renamedByOther']
    assert r['row']['status'] == 'change' and r['row']['awardId'] == 'a1' and r['row']['change'] == {'raider': 'Vuloo'}
    assert r['result'] == {'changed': 1, 'gone': 0}
    assert r['awards'] == [{'id': 'a1', 'raider': 'r2', 'am': 'aaaaaaaaaaaa', 'amEdited': 1757448000}], 'no second award, the id stays'
    assert r['again'] == ['dup', 'dup']
    assert r['older']['row']['status'] == 'dup' and r['older']['result'] == {'changed': 0, 'gone': 0}
    assert r['older']['awards'] == [{'id': 'a1', 'raider': 'r1', 'am': 'aaaaaaaaaaaa'}]


def test_a_player_award_moves_to_the_bank_and_back(out):
    t = out['toAway']
    sig = DATE + '|32235|fraktur'
    first = t['first']['rows']
    assert len(first) == 1 and first[0]['status'] == 'change' and first[0]['awardId'] == 'a1' and first[0]['change'] == {'away': 'bank'}
    assert t['first']['result'] == {'changed': 1, 'gone': 0}
    s = t['firstState']
    assert s['awards'] == []
    assert s['lootAway'] == [{'key': 'cccccccccccc', 'date': DATE, 'instance': 564, 'item': 32235, 'to': 'bank', 'amEdited': 1757450000}]
    assert sig in s['dropped'] and 'mcccccccccccc' not in s['dropped']
    # the same export again changes nothing
    assert [r['status'] for r in t['again']['rows']] == ['skip'] and t['again']['result'] == {'changed': 0, 'gone': 0}
    assert t['again']['session'] == ['dup'] and t['againState'] == s
    # bank to disenchant
    assert t['de']['session'] == ['ok']
    assert t['deState']['lootAway'] == [{'key': 'cccccccccccc', 'date': DATE, 'instance': 564, 'item': 32235, 'to': 'de', 'amEdited': 1757451000}]
    # an export from before the move does not undo it
    assert [r['status'] for r in t['old']['rows']] == ['skip'] and t['old']['session'] == ['dup']
    assert t['oldState']['awards'] == [] and len(t['oldState']['lootAway']) == 1
    # back to Fraktur in game
    b = t['back']['rows']
    assert b[0]['status'] == 'change' and b[0]['change'] == {'back': 'de', 'raider': 'Fraktur'}
    assert t['back']['result'] == {'changed': 1, 'gone': 0}
    bs = t['backState']
    assert [(x['raider'], x['am'], x['amEdited'], x['item']) for x in bs['awards']] == [('r1', 'cccccccccccc', 1757452000, 32235)]
    assert bs['lootAway'] == [] and sig not in bs['dropped'] and 'mcccccccccccc' not in bs['dropped']
    assert [r['status'] for r in t['backAgain']['rows']] == ['dup'] and t['backAgain']['result'] == {'changed': 0, 'gone': 0}
    assert t['backAgainState'] == bs
    # a newer state on the site stays over an older bank export
    assert [r['status'] for r in t['olderBank']['rows']] == ['dup']
    assert len(t['olderBankState']['awards']) == 1 and t['olderBankState']['lootAway'] == []


def test_a_bank_entry_deleted_in_game_leaves_the_ledger(out):
    t = out['toAway']
    g = t['gone']['rows']
    assert len(g) == 1 and g[0]['status'] == 'gone' and g[0]['amKey'] == 'dddddddddddd' and g[0]['away'] == 'de'
    assert t['gone']['result'] == {'changed': 0, 'gone': 1}
    assert t['goneState']['lootAway'] == [] and 'mdddddddddddd' in t['goneState']['dropped']
    assert t['goneAgain']['rows'] == [] and t['goneAgain']['result'] == {'changed': 0, 'gone': 0}
    assert t['goneOldState']['lootAway'] == [], 'an older export does not bring it back'


def test_a_bank_copy_looted_by_the_bank_character_counts_once(out):
    b = out['bankLoot']
    assert [(x['raider'], x['item'], x['count']) for x in b['without']['other']] == [('rb', 32235, 1)]
    one = b['oneLeft']
    assert one['other'] == [] and one['clash'] == [], 'the bank character\'s copy is the bank entry'
    assert one['left'] == [{'item': 32235, 'count': 1, 'sources': ['Illidan Stormrage']}], 'two dropped, one to the bank, one left'
    assert b['allOut'] == {'other': [], 'left': [], 'clash': []}
