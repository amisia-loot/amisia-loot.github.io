"""tools/game_errors.py and `build.py errors`: the error catcher's file with an Amisia error, with
another addon's error only, empty, malformed (no crash), missing (silent)."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
sys.path.insert(0, TOOLS)
import build  # noqa: E402
import game_errors as ge  # noqa: E402

FIX = os.path.join(HERE, 'fixtures', 'buggrabber')


def fix(name):
    return os.path.join(FIX, name)


def test_amisia_errors_are_found_with_where_count_session_and_time():
    session, errors = ge.amisia_errors(fix('amisia.lua'))
    assert session == 31
    assert len(errors) == 2, 'the Talents error and the client error with Amisia in its stack'
    talents, widgets = errors
    assert (talents['counter'], talents['session'], talents['time']) == (3, 31, '2026/10/08 20:14:03')
    assert ge.where(talents) == 'Amisia/UI/Pages/Talents.lua:212'
    assert ge.where(widgets) == 'Amisia/UI/Widgets.lua:88', 'Amisia\'s own frame first, backslashes made forward'
    lines = ge.lines(errors, session)
    assert lines[0] == ("  3x  Amisia/UI/Pages/Talents.lua:212  Amisia/UI/Pages/Talents.lua:212: attempt to index local "
                        "'node' (a nil value)  (Sitzung 31, diese Sitzung, 2026/10/08 20:14:03)")
    assert '(Sitzung 30, 2026/10/07 18:01:00)' in lines[1]


def test_report_lists_amisia_or_every_addon():
    text, rc = ge.report(fix('amisia.lua'))
    assert rc == 0
    assert text.splitlines()[0] == 'Fehler aus dem Spiel von Amisia: 2 (von 3 in der Datei, aktuelle Sitzung 31)'
    assert 'OtherAddon' not in text
    text, rc = ge.report(fix('amisia.lua'), all_=True)
    assert rc == 0 and 'aller Addons: 3' in text and 'OtherAddon/Core.lua:7' in text
    assert 'Blizzard_UI/Frame.lua:40' in text, 'with --all the first frame of the error, not Amisia\'s'


def test_another_addons_error_is_not_amisias():
    session, errors = ge.amisia_errors(fix('other.lua'))
    assert (session, errors) == (12, [])
    assert build.game_errors_note(fix('other.lua')) == []
    text, _ = ge.report(fix('other.lua'), all_=True)
    assert 'OtherAddon/Core.lua:7' in text


def test_an_empty_file_has_no_errors():
    assert ge.amisia_errors(fix('empty.lua')) == (29, [])
    assert build.game_errors_note(fix('empty.lua')) == []
    text, rc = ge.report(fix('empty.lua'))
    assert rc == 0 and ': 0 (von 0' in text


def test_a_malformed_file_never_crashes():
    text, rc = ge.report(fix('malformed.lua'))
    assert rc == 1 and text.startswith('Fehlerdatei nicht lesbar')
    note = build.game_errors_note(fix('malformed.lua'))
    assert len(note) == 1 and 'nicht lesbar' in note[0]


def test_a_missing_file_is_silent(tmp_path):
    missing = str(tmp_path / 'nope.lua')
    assert ge.amisia_errors(missing) is None
    assert build.game_errors_note(missing) == []


def test_the_note_of_check_and_release_counts_amisias_errors():
    note = build.game_errors_note(fix('amisia.lua'))
    assert note[0] == 'note  Fehler aus dem Spiel: 2 (python3 tools/build.py errors)'
    assert len(note) == 3


def test_fields_are_read_defensively(tmp_path):
    p = tmp_path / 'odd.lua'
    p.write_text('BugGrabberDB = { session = "x", errors = { "a string", { message = 5, counter = "many" },'
                 ' { stack = "Interface/AddOns/Amisia/Core/Core.lua:9: in main chunk" } } }\n', encoding='utf-8')
    session, errors = ge.load(str(p))
    assert session == 0 and len(errors) == 2
    assert errors[0]['message'] == '5' and errors[0]['counter'] == 1
    assert ge.is_amisia(errors[1]) and ge.where(errors[1]) == 'Amisia/Core/Core.lua:9'
    p.write_text('os.exit(1)\n', encoding='utf-8')
    text, rc = ge.report(str(p))
    assert rc == 1 and 'nicht lesbar' in text, 'no BugGrabberDB, and the sandbox has no os'
