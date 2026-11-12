"""tools/perf_report.py and `build.py perf` (F-184, D-116): the runs of /amisia leistung from a made-up
SavedVariables text, newest first, with their heads and rows; no perf key, a broken run, a malformed
file (no crash), a missing file."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
sys.path.insert(0, TOOLS)
import build  # noqa: E402
import perf_report as pr  # noqa: E402

SV = '''
AmisiaDB = {
    ["sessions"] = {},
    ["perf"] = {
        ["v"] = 1,
        ["runs"] = {
            {
                ["at"] = 1789000000, ["v"] = "2.79.0", ["b"] = "1.60.1.70862", ["g"] = "forever", ["kind"] = "hand",
                ["stop"] = "hand", ["dur"] = 300, ["fr"] = 18000, ["cb"] = 40.5, ["where"] = "none,party",
                ["ms"] = 960, ["n"] = 12345, ["sp"] = 3, ["kb"] = 1500,
                ["mem"] = { ["a0"] = 12000, ["a1"] = 12800, ["l0"] = 80000, ["l1"] = 82000 },
                ["load"] = { ["files"] = 120.5, ["al"] = 45.2, ["pl"] = 3.1, ["pew"] = 12, ["ev"] = 4 },
                ["data"] = { { ["k"] = "GEAR", ["ms"] = 230.4, ["kb"] = 5000, ["run"] = true }, { ["k"] = "MAP", ["ms"] = 80, ["kb"] = 900 } },
                ["rows"] = {
                    { ["l"] = "Event BAG_UPDATE Gear/Bis:120", ["n"] = 300, ["ms"] = 150.25, ["inc"] = 160, ["max"] = 6.5, ["sp"] = 2, ["kb"] = 300 },
                    { ["l"] = "OnUpdate MapPins", ["n"] = 18000, ["ms"] = 600, ["inc"] = 610, ["max"] = 1.2, ["sp"] = 0, ["kb"] = 20 },
                    "not a row",
                },
            },
            {
                ["at"] = 1788990000, ["kind"] = "login", ["stop"] = "time", ["dur"] = 60, ["fr"] = 0,
            },
            "not a run",
        },
    },
}
'''


def write(tmp_path, text, name='Amisia.lua'):
    p = tmp_path / name
    p.write_text(text, encoding='utf-8')
    return str(p)


def test_the_runs_newest_first_with_head_and_rows(tmp_path):
    path = write(tmp_path, SV)
    runs = pr.load(path)
    assert [r['kind'] for r in runs] == ['hand', 'login'], 'a run that is no table is left out'
    text, rc = pr.report(path)
    assert rc == 0
    lines = text.splitlines()
    assert lines[0].startswith('Messungen von Amisia: 2 (neueste zuerst')
    head = next(l for l in lines if l.startswith('Lauf 1:'))
    assert '· von Hand · 5 min 00 s · beendet von Hand · Amisia 2.79.0 · Client 1.60.1.70862 · forever · wo none,party' in head
    assert '  Frames 18000 (60,0 fps), im Kampf 40 s; Amisia 3,20 ms/s, 0,053 ms/Frame (0,3 % von 16,7 ms); 12345 Aufrufe, 3 über 5 ms; Müll 5,0 KB/s' in lines
    assert '  Speicher: Amisia 11,7 MB -> 12,5 MB, alle Addons 78,1 MB -> 80,1 MB' in lines
    assert '  Laden: Dateien 120 ms, ADDON_LOADED 45, PLAYER_LOGIN 3,10, PLAYER_ENTERING_WORLD 12, andere Ereignisse 4,00' in lines
    assert '  Daten: GEAR 230 ms (in der Messung), MAP 80 ms' in lines
    rows = [l for l in lines if l.endswith('OnUpdate MapPins') or l.endswith('Gear/Bis:120')]
    assert rows[0].endswith('OnUpdate MapPins'), 'the costliest row first'
    assert rows[0].split()[:6] == ['600.00', '18000', '0.033', '1.20', '0', '20.0']
    assert 'Lauf 2:' in text and 'keine Aufrufe gemessen' in text, 'a run without rows'


def test_rows_are_cut(tmp_path):
    text, _ = pr.report(write(tmp_path, SV), rows=1)
    assert '  ... und 1 weitere Zeilen (--rows 2)' in text.splitlines()


def test_no_perf_key_and_no_file(tmp_path):
    text, rc = pr.report(write(tmp_path, 'AmisiaDB = { ["sessions"] = {} }\n'))
    assert rc == 0 and text.startswith('Noch keine Messung gespeichert')
    text, rc = pr.report(str(tmp_path / 'nope.lua'))
    assert rc == 0 and text.startswith('Keine Datei')


def test_a_malformed_file_never_crashes(tmp_path):
    text, rc = pr.report(write(tmp_path, 'AmisiaDB = { perf = '))
    assert rc == 1 and text.startswith('Datei nicht lesbar')
    text, rc = pr.report(write(tmp_path, 'Other = 1\n', 'other.lua'))
    assert rc == 1 and 'no AmisiaDB table' in text
    odd = 'AmisiaDB = { perf = { v = 1, runs = { { at = "x", dur = "y", fr = {}, mem = 5, rows = { { l = 7, n = "z" } } } } } }\n'
    text, rc = pr.report(write(tmp_path, odd, 'odd.lua'))
    assert rc == 0 and 'Lauf 1: ?' in text, 'odd fields are read defensively'


def test_build_perf_prints_the_report(tmp_path, capsys):
    path = write(tmp_path, SV)
    assert build.main(['perf', '--sv', path, '--rows', '5']) == 0
    assert 'Lauf 1:' in capsys.readouterr().out
