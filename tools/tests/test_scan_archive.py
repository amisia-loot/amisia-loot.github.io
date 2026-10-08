"""tools/build_scan_archive.py: the scan archive (merge without loss, newer wins), the marker the addon
trims by (Data/ScanDone.lua), the builds reading archive and SavedVariables together, and the round
trip with the real files: a build after the addon trimmed its file gives the same data as before."""
import json
import os
import shutil
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
sys.path.insert(0, os.path.join(ROOT, 'addon', 'tests'))
import build_scan_archive as sa  # noqa: E402
import build_scan  # noqa: E402

REAL_ARCHIVE = os.path.join(ROOT, 'tools', 'scan_archive.json')
REAL_MARKER = os.path.join(ROOT, 'addon', 'Amisia', 'Data', 'ScanDone.lua')


def sv(items=None, sources=None, suffix=None, **rest):
    return dict({'scan': {'items': items or {}, 'sources': sources or {}, 'suffix': suffix or {}, 'next': 9}}, **rest)


def test_absorb_loses_nothing_and_the_file_wins():
    arch = sa.empty()
    s = sa.absorb(arch, sv({1: 'Eins\t1', 2: 'Zwei\t2'}, {1: ['Auktionshaus'], 2: ['Quest: A [3] L2']}, {1: {7: 'STRENGTH=1'}}))
    assert s == {'items': 2, 'changed': 0, 'sources': 2, 'suffix': 1}
    # a later file: item 1 changed, item 3 new, item 2 trimmed away (absent), one more note for 1
    s = sa.absorb(arch, sv({1: 'Eins neu\t1', 3: 'Drei\t3'}, {1: ['Haendler: B [4] @Z', 'Auktionshaus']}, {1: {7: 'STRENGTH=2', 8: 'AGILITY=1'}}))
    assert s == {'items': 1, 'changed': 1, 'sources': 1, 'suffix': 2}
    assert arch['items'] == {1: 'Eins neu\t1', 2: 'Zwei\t2', 3: 'Drei\t3'}, 'newer wins, nothing absent is dropped'
    assert arch['sources'] == {1: ['Auktionshaus', 'Haendler: B [4] @Z'], 2: ['Quest: A [3] L2']}, 'notes joined in order'
    assert arch['suffix'] == {1: {7: 'STRENGTH=2', 8: 'AGILITY=1'}}
    # lists from lupa (keys 1..n), junk and empty values
    sa.absorb(arch, {'scan': {'items': ['Item eins'], 'sources': {'x': ['?'], 5: [''], 6: 'Auktionshaus'}}})
    assert arch['items'][1] == 'Item eins' and 5 not in arch['sources'] and arch['sources'][6] == ['Auktionshaus']
    assert sa.absorb(arch, {}) == {'items': 0, 'changed': 0, 'sources': 0, 'suffix': 0}


def test_the_file_round_trips_and_is_written_only_on_change(tmp_path):
    arch = sa.empty()
    sa.absorb(arch, sv({25: 'Kurzschwert\t1', 3: 'Ä\t2'}, {3: ['Auktionshaus']}, {25: {9: 'STAMINA=2'}}))
    arch['client'] = {'build': '1.60.1.70235', 'ids': sa.ranges([1, 2, 3, 7, 8, 25])}
    assert arch['client']['ids'] == [[1, 3], [7, 8], [25, 25]]
    path = tmp_path / 'a.json'
    assert sa.save(str(path), arch) is True
    assert sa.save(str(path), arch) is False, 'unchanged: not written again'
    back = sa.load(str(path))
    assert back['items'] == arch['items'] and back['sources'] == arch['sources'] and back['suffix'] == arch['suffix']
    assert back['client'] == arch['client']
    text = path.read_text(encoding='utf-8')
    assert json.loads(text)['items']['3'] == 'Ä\t2' and text.index('"3":') < text.index('"25":'), 'ids in order, one per line'
    assert sa.load(str(tmp_path / 'none.json')) == sa.empty()


def test_builds_read_the_archive_under_the_files(tmp_path):
    arch = sa.empty()
    sa.absorb(arch, sv({1: 'Alt\t2\t10', 2: 'Archiv\t3\t20'}, {2: ['Auktionshaus']}, {2: {5: 'STRENGTH=4'}}))
    path = tmp_path / 'a.json'
    sa.save(str(path), arch)
    trimmed = sv({1: 'Neu\t2\t10', 4: 'Frisch\t2\t5'}, {4: ['Quest: Q [8] L4']})
    items, _, collected = build_scan.collect(sa.with_archive([trimmed], str(path)))
    assert items[1]['name'] == 'Neu' and items[2]['name'] == 'Archiv' and items[4]['name'] == 'Frisch'
    assert list(items) == [1, 2, 4] and list(collected) == [2, 4], 'in id order whatever the files hold'
    assert sa.with_archive([trimmed], str(tmp_path / 'none.json')) == [trimmed]
    over = sa.overlay(trimmed, str(path))
    assert over['scan']['items'][2] == 'Archiv\t3\t20' and over['scan']['items'][1] == 'Neu\t2\t10'
    assert over['scan']['suffix'] == {2: {5: 'STRENGTH=4'}} and over['scan']['next'] == 9
    assert sa.overlay(None, str(path))['scan']['items'][2] == 'Archiv\t3\t20'
    assert sa.overlay(trimmed, '') is trimmed


def test_the_hash_and_base36_are_the_addons():
    assert sa.lua_hash('') == 0 and sa.lua_hash('a') == 97 and sa.lua_hash('ab') == 97 * 31 + 98
    assert sa.lua_hash('Händler: Wuark [3881] @Brachland') == 40464479, 'over the UTF-8 bytes'
    assert [sa.b36(n) for n in (0, 35, 36, 1000000006)] == ['0', 'z', '10', int_to_36(1000000006)]
    pytest.importorskip('lupa')
    import run
    lua = run.fresh()
    h = lua.eval('NS.ScanTrimHash')
    for text in ('Rekrutenhemd\t1\t1\t0\t4\t0\tINVTYPE_BODY\t135009\t0', 'Händler: Wuark [3881] @Brachland', 'x' * 500):
        assert h(text) == sa.lua_hash(text)


def int_to_36(n):
    out = ''
    while n:
        n, r = divmod(n, 36)
        out = '0123456789abcdefghijklmnopqrstuvwxyz'[r] + out
    return out


def decode(marker):
    """The marker's parts read back: ({id: hash}, {id: [hashes]}, [[first, last]])."""
    items, prev = {}, 0
    for e in marker['I'].split(','):
        step, h = e.split('.')
        prev += int(step, 36)
        items[prev] = int(h, 36)
    srcs, prev = {}, 0
    for e in marker['S'].split(','):
        step, *hs = e.split('.')
        prev += int(step, 36)
        srcs[prev] = [int(h, 36) for h in hs]
    ranges, last = [], 0
    for e in (marker['C'].split(',') if marker['C'] else []):
        step, n = e.split('.')
        first = last + int(step, 36)
        last = first + int(n, 36) - 1
        ranges.append([first, last])
    return items, srcs, ranges


def test_the_marker_holds_what_the_archive_holds():
    pytest.importorskip('lupa')
    import lua_data
    arch = sa.empty()
    sa.absorb(arch, sv({5: 'Fünf\t1', 7: 'Sieben\t2', 1000: 'Tausend\t3'}, {7: ['Auktionshaus', 'Quest: Q [2] L1']}))
    arch['client'] = {'build': '1.60.1.70235', 'ids': sa.ranges([1, 2, 3, 5, 7, 1000])}
    arch['updated'] = '2026-10-08'
    text = sa.marker_text(arch)
    assert text.startswith('-- GENERATED by tools/build_scan_archive.py') and 'ns.LazyData("SCAN_DONE", [' in text
    assert text.rstrip().endswith(', 3)'), 'the count is the number of item lines'
    m = lua_data.load(text, 'ScanDone.lua').SCAN_DONE
    assert m.built.startswith('2026-10-08:') and m['items'] == 3 and m['sources'] == 1 and m.cmax == 1000 and m.client == '1.60.1.70235'
    items, srcs, ranges = decode({'I': m.I, 'S': m.S, 'C': m.C})
    assert items == {k: sa.lua_hash(v) for k, v in arch['items'].items()}
    assert srcs == {7: [sa.lua_hash('Auktionshaus'), sa.lua_hash('Quest: Q [2] L1')]}
    assert ranges == [[1, 3], [5, 5], [7, 7], [1000, 1000]]
    assert sa.marker_text(arch) == text, 'the same archive, the same file'
    arch['items'][5] = 'Fünf anders\t1'
    assert sa.marker_text(arch) != text, 'the stamp follows the content'


def test_update_merges_the_files_and_writes_both(tmp_path):
    pytest.importorskip('lupa')
    f = tmp_path / 'Amisia.lua'
    f.write_text('AmisiaDB = { ["scan"] = { ["items"] = { [12] = "Zwölf\\t1", [30] = "Dreißig\\t2" }, '
                 '["sources"] = { [12] = { "Auktionshaus" } }, ["next"] = 31 } }\n', encoding='utf-8')
    wago = tmp_path / 'wago'
    wago.mkdir()
    (wago / 'ItemSparse.1.60.1.70235.csv').write_text('ID,Display_lang\n12,a\n13,b\n30,c\n', encoding='utf-8')
    archive, marker = tmp_path / 'a.json', tmp_path / 'ScanDone.lua'
    import datetime
    arch = sa.update(str(archive), [str(f)], str(wago), str(marker), today=datetime.date(2026, 10, 8), log=lambda *_: None)
    assert arch['items'] == {12: 'Zwölf\t1', 30: 'Dreißig\t2'} and arch['client'] == {'build': '1.60.1.70235', 'ids': [[12, 13], [30, 30]]}
    assert arch['updated'] == '2026-10-08' and archive.exists() and marker.exists()
    first = archive.read_text(encoding='utf-8')
    # the file trimmed in game: an update loses nothing and does not touch the date
    f.write_text('AmisiaDB = { ["scan"] = { ["items"] = {}, ["next"] = 31 } }\n', encoding='utf-8')
    arch = sa.update(str(archive), [str(f)], str(wago), str(marker), today=datetime.date(2026, 10, 9), log=lambda *_: None)
    assert archive.read_text(encoding='utf-8') == first and arch['updated'] == '2026-10-08'


def test_the_committed_marker_is_current():
    """Data/ScanDone.lua is what tools/scan_archive.json says (python3 tools/build.py data writes both)."""
    assert os.path.exists(REAL_ARCHIVE) and os.path.exists(REAL_MARKER)
    with open(REAL_MARKER, encoding='utf-8') as fh:
        assert fh.read() == sa.marker_text(sa.load(REAL_ARCHIVE)), 'rebuild: python3 tools/build_scan_archive.py marker'


def test_the_marker_is_in_the_toc_after_the_other_data():
    with open(os.path.join(ROOT, 'addon', 'Amisia', 'Amisia.toc'), encoding='utf-8') as fh:
        toc = [ln.strip() for ln in fh if ln.strip() and not ln.startswith('#')]
    assert 'Data\\ScanDone.lua [AllowLoadGameType camelot]' in toc and 'Collect\\ScanTrim.lua' in toc


# ---------------------------------------------------------------- the round trip with the real files
REAL_SV = sa.DEFAULT_SV


def trimmed_sv(text, out):
    """The SavedVariables after the addon's trim at login: the real file in the test stub, the
    committed marker, the login run; the file with the scan the stub left (the rest as it was, so only
    the trim differs)."""
    import run
    lua = run.fresh('', setup=lambda l: l.execute(text))
    lua.execute('STUB.fire("PLAYER_LOGIN"); STUB.tick(NS.SCAN_TRIM.delay + 120)')
    assert not lua.eval('NS.ScanTrimRunning()')
    out.write_text(text + '\nAmisiaDB.scan = ' + lua.eval('STUB.dump(AmisiaDB.scan)') + '\n', encoding='utf-8')
    return lua


@pytest.mark.skipif(not os.path.exists(REAL_SV), reason='needs ~/addons/_SavedVariables/Amisia.lua')
def test_a_build_after_the_trim_gives_the_same_data(tmp_path):
    pytest.importorskip('lupa')
    import att_data
    import build_bis
    import build_gear
    with open(REAL_SV, encoding='utf-8') as fh:
        text = fh.read()
    full = build_scan.load_sv(REAL_SV)
    trimmed_path = tmp_path / 'Amisia.lua'
    trimmed_sv(text, trimmed_path)
    trimmed = build_scan.load_sv(str(trimmed_path))
    n_full = len(full['scan']['items'])
    n_left = len(trimmed['scan'].get('items') or {})
    assert n_left < n_full / 2 or n_full < 100, f'the trim took most of the scan ({n_left} of {n_full} left)'
    assert trimmed['scan']['next'] == full['scan']['next'], 'the scan progress stays'
    # the archive as build.py data leaves it: the committed one with this file joined
    archive = tmp_path / 'scan_archive.json'
    shutil.copy(REAL_ARCHIVE, archive)
    arch = sa.load(str(archive))
    sa.absorb(arch, full)
    sa.save(str(archive), arch)

    # what the builds read: the same before (whole file) and after (trimmed file) the trim
    def scan_of(db):
        items, _, collected = build_scan.collect(sa.with_archive([db], str(archive)))
        return items, collected
    assert scan_of(trimmed) == scan_of(full)
    over_full, over_trim = sa.overlay(full, str(archive)), sa.overlay(trimmed, str(archive))
    assert build_bis.scan_stats(over_trim) == build_bis.scan_stats(over_full)
    assert build_bis.observed_suffixes(over_trim) == build_bis.observed_suffixes(over_full)

    # GearData.lua, built by build_gear.py from each
    if os.path.isdir(os.path.join(att_data.ATT_CACHE, 'dungeons & raids')):
        outs = []
        for name, path in (('before', REAL_SV), ('after', str(trimmed_path))):
            out = tmp_path / f'GearData.{name}.lua'
            build_gear.main(['--sv', path, '--scan-archive', str(archive), '--out', str(out), '--no-wowsrc'])
            outs.append(out.read_text(encoding='utf-8'))
        assert outs[0] == outs[1], 'GearData.lua differs after the trim'

    # data/forever.js, built by build_scan.py from each (no icons; the drop archive a copy)
    outs = []
    for name, path in (('before', REAL_SV), ('after', str(trimmed_path))):
        drops = tmp_path / f'drop_obs.{name}.json'
        shutil.copy(os.path.join(ROOT, 'tools', 'drop_obs.json'), drops)
        out = tmp_path / f'forever.{name}.js'
        assert build_scan.main([path, '--out', str(out), '--archive', str(drops), '--scan-archive', str(archive), '--no-icons']) == 0
        outs.append(out.read_text(encoding='utf-8'))
    assert outs[0] == outs[1], 'forever.js differs after the trim'
