"""The ledger is kept for WoW Forever only; TBC Anniversary is a read-only archive (index.html).

tools/tests/site_archive.cjs cuts the shelf and archive code out of the page: fitShelf puts Forever
on top without losing anything, archiveView copies shelf.tbc for the archive, removeRaider leaves the
archive alone and keeps the raider in retired, and nothing done in the archive is saved.
"""
import json
import os
import shutil
import subprocess

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DRIVER = os.path.join(ROOT, 'tools', 'tests', 'site_archive.cjs')


@pytest.fixture(scope='module')
def out():
    node = shutil.which('node')
    if not node:
        pytest.skip('node is not installed')
    p = subprocess.run([node, DRIVER], stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=dict(os.environ, TZ='UTC'))
    assert p.returncode == 0, p.stderr.decode('utf-8', 'replace')
    return json.loads(p.stdout.decode('utf-8'))


def test_the_live_ledger_stays_as_it_is(out):
    assert out['live'] == {'unchanged': True, 'twice': True, 'has': True}


def test_a_ledger_with_tbc_on_top_moves_to_the_shelf(out):
    o = out['old']
    assert o['game'] == 'forever' and o['shelfGame'] == 'forever', 'a missing shelfGame still means tbc'
    assert o['top'] == 0 and not o['topNights'], 'Forever on top starts empty'
    assert o['shelfTbc'], 'the TBC data lies unchanged in shelf.tbc'
    assert o['withGameSame'], 'game "tbc" or no game at all: the same move'
    assert o['twice'], 'moving twice changes nothing'
    assert o['countBefore'] == o['countAfter'] == {'awards': 2, 'nights': 2}
    assert o['has'] and o['shelfKeys'] == ['tbc']


def test_a_backup_with_another_game_on_top(out):
    assert out['mop'] == {'game': 'forever', 'shelfGame': 'forever', 'top': 0, 'shelfMop': True, 'shelfTbc': True, 'has': True}


def test_a_ledger_without_tbc_data_has_no_archive(out):
    assert out['none'] == {'has': False, 'hasOld': False, 'game': 'forever', 'shelfGame': 'forever'}


def test_a_shelf_entry_is_never_overwritten(out):
    assert out['clash'] == {'keys': ['tbc', 'tbc~2'], 'kept': 1, 'top': True}


def test_the_archive_view_is_a_copy(out):
    v = out['view']
    assert v['game'] == 'tbc' and v['shelfGame'] == 'tbc' and v['shelf'] == {}
    assert v['awards'] == 2 and v['nights'] == 2 and v['guild'] == 'Amisia'
    assert v['liveUntouched'], 'changing the view does not reach the ledger'
    assert v['oldAwards'] == 2 and v['oldNights'] == 2 and v['bank'], 'a ledger that has not moved yet: read from the top'
    assert v['noRetiredKey']


def test_removing_a_raider_leaves_the_archive_alone(out):
    r = out['remove']
    assert out['allBuckets'] == 2, 'the top and the MoP shelf, not shelf.tbc'
    assert r['tbcSame'], 'shelf.tbc is the same as before, apart from retired'
    assert r['retired'] == [{'id': 'a', 'name': 'Anna', 'cls': 'Priest'}]
    assert r['retiredAfterCid'] == ['a'], 'a raider without loot in the archive is not kept, nobody twice'
    assert r['raiders'] == ['b'] and r['top'] == 0 and r['mop'] == 0, 'the other game versions lose the raider as before'
    assert r['viewRaiders'] == ['a', 'b'], 'the archive still knows Anna'
    assert r['annaInArchive'] and not r['cidInArchive']
    assert r['bench'] and r['kill']


def test_the_archive_never_saves(out):
    assert out['enterDirty'] is False, 'no archive with unsaved changes'
    e = out['enter']
    assert e['archiveOn'] and e['readOnly'] and e['game'] == 'tbc' and e['live'] and e['gameKey'] == 'tbc' and e['awards'] == 2
    assert e['view'] == 'armory', 'the Wishlist tab is not part of the archive'
    assert out['markDirty'] == {'dirty': False, 'savedAt': True}
    assert out['roleInArchive'] is True, 'an editor is read-only in the archive too'


def test_a_new_ledger_goes_behind_the_archive(out):
    assert out['takeInArchive'] == {'live': True, 'archiveOn': True, 'awards': 3, 'viewIsNotLive': True}
    assert out['leave'] == {'archiveOn': False, 'live': True, 'readOnly': False, 'gameKey': 'forever', 'shelfTbc': 3}
    assert out['takeEmpty'] is False, 'a ledger without archive data leaves the archive'


def test_the_hint_for_editors_follows_the_loaded_ledger(out):
    assert out['takeOld'] == {'moved': 'tbc', 'gameKey': 'forever'}
    assert out['takeLive'] == {'moved': None}


def test_the_start_ledger_keeps_every_award(out):
    s = out['start']
    assert s['game'] == 'tbc'
    assert s['before'] == s['after'] == {'awards': 65, 'nights': 0}
    assert s['view'] == {'awards': 65, 'nights': 0} and s['top'] == 0


def page():
    with open(os.path.join(ROOT, 'index.html'), encoding='utf-8') as fh:
        return fh.read()


def test_the_page_offers_forever_only():
    src = page()
    games = src[src.index('const GAMES = ['):src.index('];', src.index('const GAMES = ['))]
    assert "key:'forever'" in games and games.count("key:'") == 1
    assert "const PLAY = 'forever';" in src
    assert "tbc: {key:'tbc', name:'TBC Anniversary'" in src and 'archive:true' in src
    assert "s.shelfGame || 'tbc'" in src, 'the old meaning of a missing shelfGame stays'
    for gone in ("state.game||'tbc'", "state.game || 'tbc'", 'GAME.tbc', 'data/classic.js', 'data/sod.js', 'data/mop.js',
                 '_anniversary_', 'Mark of the Illidari, Heart of Darkness', 'nine Burning Crusade raids',
                 'Materials are tracked for TBC Anniversary so far', "' in every game version'"):
        assert gone not in src, gone


def test_the_page_texts():
    src = page()
    for text in ('<div class="eyebrow" id="eyebrow">World of Warcraft Forever</div>',
                 '>TBC archive</button>',
                 'You are looking at the <b>TBC Anniversary archive</b>. It is read-only.',
                 '>Back to Forever</button>',
                 'This ledger still had TBC Anniversary on top. Its loot and raid nights are now in the TBC archive.',
                 '>Save the move to Forever</button>',
                 'Save or discard your changes first.',
                 'No tracked materials for World of Warcraft Forever yet. The TBC counts are in the TBC archive.',
                 'folder of your WoW Forever install',
                 'who looted a tracked material',
                 '(only when materials are tracked)',
                 'Disenchanted items and items that are not in the Forever loot tables are ignored.',
                 ' Their loot in the TBC archive stays.',
                 '<select class="inp" id="gGame" disabled'):
        assert text in src, text
