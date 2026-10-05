"""Boss kills and the bench from the Amisia addon on the site (index.html).

tools/tests/site_raidlog.cjs cuts the import and attendance code out of the page and runs one
raid night through it: a first export, a second officer's recording of the same night, the first
raid exported again after a kill was deleted and a raider left the bench, and an export of 1.6.
"""
import json
import os
import shutil
import subprocess
from datetime import datetime, timezone

import pytest

DRIVER = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'site_raidlog.cjs')
SID_A, SID_B = '20261001195500-564', '20261001195800-564'


@pytest.fixture(scope='module')
def out():
    node = shutil.which('node')
    if not node:
        pytest.skip('node is not installed')
    p = subprocess.run([node, DRIVER], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                       env=dict(os.environ, TZ='UTC'))
    assert p.returncode == 0, p.stderr.decode('utf-8', 'replace')
    return json.loads(p.stdout.decode('utf-8'))


def hm(t):
    return datetime.fromtimestamp(t, timezone.utc).strftime('%H:%M')


def line(text, head):
    hits = [l for l in text.split('\n') if l.startswith(head)]
    assert len(hits) == 1, (head, text)
    return hits[0]


def test_the_parser_reads_kills_and_bench(out):
    s = out['parsed']
    assert [(k['enc'], k['ok'], k['src'], k['name']) for k in s['kills']] == [
        (601, True, 'E', "Hochkriegsfürst Naj'entus"), (602, False, 'E', 'Supremus'), (602, True, 'E', 'Supremus'),
        (0, True, 'L', 'Mutter Shahraz')]
    assert s['kills'][0]['present'] == ['Chorf', 'Fraktur', 'Vuloo', 'Fremder']
    assert 'present' not in s['kills'][1], 'a wipe has no names'
    assert [b['name'] for b in s['bench']] == ['Bob', 'Chorf', 'Kim Eisherz']


def test_the_preview_names_new_bench_raiders(out):
    p = out['previewA'][0]
    assert p['status'] == 'ok'
    assert {'Bob', 'Kim Eisherz'} <= set(p['newNames'])
    assert p['people'] == 3, 'the bench is not counted among the people of the raid'


def test_import_puts_kills_and_bench_on_the_night(out):
    T = out['T']
    n = out['afterA']['night']
    assert n['present'] == ['Chorf', 'Fraktur', 'Vuloo'], 'the bench does not mark anyone present'
    assert [(k['sid'], k['enc'], k['ok'], k['src'], k['end'], k['present']) for k in n['kills']] == [
        (SID_A, 601, True, 'E', T + 792, ['Chorf', 'Fraktur', 'Vuloo']),
        (SID_A, 602, False, 'E', T + 1321, []),
        (SID_A, 602, True, 'E', T + 1740, ['Fraktur', 'Vuloo']),
        (SID_A, 0, True, 'L', T + 5400, ['Vuloo']),
    ], 'a name without a raider (Fremder) drops out of present'
    k = n['kills'][0]
    assert k['name'] == "Hochkriegsfürst Naj'entus" and k['start'] == T + 600 and k['size'] == 25
    assert set(n['bench']) == {'Bob', 'Chorf', 'Kim Eisherz'}
    assert n['bench']['Bob'] == {'sid': SID_A, 'at': T - 600, 'self': True, 'note': 'ab 21 Uhr'}
    assert n['bench']['Kim Eisherz'] == {'sid': SID_A, 'at': T - 400, 'self': False, 'note': ''}
    raiders = out['afterA']['raiders']
    assert 'Bob:Mage' in raiders and 'Kim Eisherz:Unknown' in raiders, 'bench names join the roster'
    assert not any(r.startswith('Fremder') for r in raiders), 'names at a kill do not'
    assert out['importA']['res']['created'] == 5


def test_present_beats_the_bench(out):
    assert out['afterA']['bench'] == ['Bob', 'Kim Eisherz'], 'Chorf was there, so he is not on the bench'


def test_the_same_export_again_is_nothing_new(out):
    assert out['againA'] == ['dup']
    assert out['againAafterB'] == ['dup'], 'a bench entry another recorder now holds is not new'
    assert out['againA2'] == ['dup']


def test_a_second_recorder_gives_one_kill_per_boss(out):
    T = out['T']
    ks = out['afterB']['kills']
    assert [(k['name'], k['ok'], k['wipes']) for k in ks] == [
        ("High Warlord Naj'entus", True, 0), ('Supremus', True, 1), ('Mother Shahraz', True, 0), ('Illidan Sturmgrimm', False, 1)]
    assert ks[0]['present'] == ['Anna', 'Chorf', 'Fraktur', 'Vuloo'], 'the kill with more raiders is kept'
    assert ks[1]['present'] == ['Fraktur', 'Vuloo'] and ks[1]['end'] == T + 1740
    assert ks[2]['src'] == 'H' and ks[2]['present'] == ['Fraktur', 'Vuloo'], 'merged over the translated name'
    n = out['afterB']['night']
    assert len(n['kills']) == 9 and {k['sid'] for k in n['kills']} == {SID_A, SID_B}
    assert n['bench']['Bob']['sid'] == SID_B and n['bench']['Bob']['note'] == 'spaeter'
    assert out['importB']['status'] == ['ok']


def test_a_reimport_drops_a_deleted_kill_and_a_bench_entry(out):
    assert out['previewA2'] == ['ok'], 'a session with fewer kills or bench entries counts as new'
    n = out['afterA2']['night']
    mine = [k for k in n['kills'] if k['sid'] == SID_A]
    assert [(k['enc'], k['ok']) for k in mine] == [(601, True), (602, False), (0, True)], 'the deleted Supremus kill is gone'
    assert len([k for k in n['kills'] if k['sid'] == SID_B]) == 5, 'the other recorder keeps his'
    assert set(n['bench']) == {'Bob', 'Chorf'}, 'Kim left the bench'
    assert n['bench']['Bob']['sid'] == SID_A
    assert out['afterA2']['bench'] == ['Bob']
    ks = out['afterA2']['kills']
    assert [(k['name'], k['wipes']) for k in ks][:2] == [("High Warlord Naj'entus", 0), ('Supremus', 1)]
    assert ks[1]['present'] == ['Fraktur'], "now only the second recorder's Supremus kill"


def test_night_text_names_bosses_and_bench(out):
    T = out['T']
    a = out['afterA']['text']
    assert line(a, 'Bosses: ') == "Bosses: High Warlord Naj'entus %s, Supremus %s (1 wipe), Mother Shahraz ~%s" % (
        hm(T + 792), hm(T + 1740), hm(T + 5400))
    assert line(a, 'Bench: ') == 'Bench: Bob, Kim Eisherz'
    assert line(a, 'Missing: ') == 'Missing: Zed', 'the bench is not missing'
    b = out['afterB']['text']
    assert line(b, 'Bosses: ').endswith('Illidan Stormrage %s (1 wipe, no kill)' % hm(T + 7300))
    c = out['afterA2']['text']
    assert line(c, 'Bench: ') == 'Bench: Bob'
    assert line(c, 'Missing: ') == 'Missing: Kim Eisherz, Zed'


def test_an_export_of_1_6_imports_as_before(out):
    assert out['importOld']['status'] == ['ok']
    n = out['oldNight']
    assert n['present'] == ['Vuloo'] and 'kills' not in n and 'bench' not in n


def att(out, mode, rid):
    a = out['att'][mode][rid]
    return a['was'], a['total'], a['bench'], round(a['rate'], 3)


def test_attendance_bench_counts_as_attended_by_default(out):
    for mode in ('undefined', 'present', 'bogus'):
        assert att(out, mode, 'b') == (2, 3, 1, 0.667), mode
        assert att(out, mode, 'a') == (3, 3, 0, 1.0), 'present beats the bench, a night off stays out'
        assert att(out, mode, 'c') == (0, 3, 0, 0.0)


def test_attendance_bench_excused(out):
    assert att(out, 'excused', 'b') == (1, 2, 1, 0.5), 'the bench night leaves the rate'
    assert att(out, 'excused', 'a') == (3, 3, 0, 1.0)


def test_attendance_bench_missed(out):
    assert att(out, 'missed', 'b') == (1, 3, 1, 0.333), 'counted as missed, still marked'


def test_bench_on_leaves_out_who_was_there(out):
    for mode in out['att']:
        assert out['att'][mode]['benchD4'] == []


def test_missed_the_last_raid_lists_the_bench_only_when_it_counts_as_missed(out):
    m = out['missed']
    for mode in ('undefined', 'present', 'excused'):
        assert m[mode] == {'a': False, 'b': False, 'c': True}, (mode, m[mode])
    assert m['missed'] == {'a': False, 'b': True, 'c': True}


def test_attempts_of_one_recording_are_never_merged(out):
    T = out['T']
    k = out['sameRecording']
    # two wipes of recording A 120 s apart stay two; B's copy of the first adds nothing
    assert [(x['ok'], x['wipes']) for x in k] == [(True, 2), (True, 0)], k
    # B's kill (more raiders) stands for A's kill 5 s earlier; A's second kill 60 s later stays its own
    assert k[0]['end'] == T + 1745 and k[0]['sid'] == SID_B
    assert k[1]['end'] == T + 1800 and k[1]['sid'] == SID_A
