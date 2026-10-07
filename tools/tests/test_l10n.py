"""The localisation checks (tools/l10n.py): the parser on made-up sources, then the addon itself:
no German text outside L[...], every key with its English entry, no entry without its key."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
import l10n  # noqa: E402


def write(tmp_path, name, text):
    p = tmp_path / name
    p.write_text(text, encoding='utf-8')
    return str(p)


def test_strings_skip_comments_and_read_escapes():
    src = 'local a = "x\\"y" -- "im Kommentar"\n--[[ "auch nicht" ]] local b = [[lang\n]] c = \'ä\''
    vals = [t for _, _, t, _ in l10n.lua_strings(src)]
    assert vals == ['x"y', 'lang\n', 'ä']


def test_scan_finds_unrouted_german_and_skips_routed_and_marked(tmp_path):
    f = write(tmp_path, 'a.lua', '\n'.join([
        'x:SetText("Noch nichts zu zeigen.")',          # German words
        'x:SetText(L["Noch nichts zu zeigen."])',       # routed
        'y = ns.L["Übersicht"]',                        # routed through ns.L
        'if word == "aus" then end -- l10n-ok: the German chat word',
        'z = "TOPLEFT"',                                 # not text
        'w = "Größe"',                                   # umlaut
    ]))
    found = [(line, text) for _, line, text in l10n.scan([f])]
    assert found == [(1, 'Noch nichts zu zeigen.'), (6, 'Größe')]


def test_used_keys_and_entries(tmp_path):
    f = write(tmp_path, 'a.lua', 'a = L["Hallo %s"]:format(n)\nb = L["Raid"]\nc = { N_("Kopf"), ns.N_("Hals") }\n')
    assert set(l10n.used_keys([f])) == {'Hallo %s', 'Raid', 'Kopf', 'Hals'}
    assert l10n.scan([f]) == []
    loc = write(tmp_path, 'enUS_x.lua', 'local L = ns.NewLocale("enUS")\nL["Hallo %s"] = "Hello %s"\nL["Raid"] = true\n'
                                       'L["Raid"] = "Raid"\n')
    dups = []
    assert l10n.enus_entries([loc], dups) == {'Hallo %s': 'Hello %s', 'Raid': 'Raid'}
    assert [k for k, _ in dups] == ['Raid']


def test_format_specifiers():
    assert l10n.specs('%d von %s (%.1f %%)') == ['d', 's', 'f']


def test_the_addon_is_translated():
    problems = l10n.check()
    assert not problems, '\n'.join(problems[:40]) + (f'\n... {len(problems)} in all' if len(problems) > 40 else '')
