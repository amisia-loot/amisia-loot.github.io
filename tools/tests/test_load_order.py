"""Every addon file but Locales/Locale.lua puts its body in ns.Load(function() ... end) (D-128).

The client loads Amisia's SavedVariables only after all its files ran, and the chosen language
(ui.language, F-199) must be known before a file translates its texts. Locales/Locale.lua is the
first file of every TOC and runs the bodies on ADDON_LOADED; a file without the wrapper would run
before the language is chosen (and before the files it may need), so these tests stop it.
The generated data (Data/*.lua, written by tools/build_*.py) and Core/LazyData.lua, which they call,
load at once as before: they hold no texts, which the last test checks.
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ADDON = os.path.join(ROOT, 'Amisia')
TOCS = ('Amisia.toc', 'Amisia_TBC.toc', 'Amisia_Vanilla.toc')
HEADER = re.compile(r'^local [\w_]+, ns = \.\.\.\s*$')
AT_ONCE = {'Locales/Locale.lua', 'Core/LazyData.lua'}


def at_once(name):
    return name in AT_ONCE or name.startswith('Data/')


def toc_files(toc):
    out = []
    with open(os.path.join(ADDON, toc), encoding='utf-8') as fh:
        for line in fh:
            line = line.strip()
            if line and not line.startswith('#') and line.split(' [')[0].endswith('.lua'):
                out.append(line.split(' [')[0].replace('\\', '/'))
    return out


def test_locale_comes_first():
    for toc in TOCS:
        assert toc_files(toc)[0] == 'Locales/Locale.lua', toc


def test_every_other_file_waits_for_the_language():
    bad = []
    files = sorted(f for f in {f for toc in TOCS for f in toc_files(toc)} if not at_once(f))
    assert len(files) > 100
    for name in files:
        with open(os.path.join(ADDON, name), encoding='utf-8') as fh:
            lines = fh.read().rstrip('\n').split('\n')
        heads = [i for i, line in enumerate(lines) if HEADER.match(line)]
        if not heads or heads[0] + 1 >= len(lines) or lines[heads[0] + 1] != 'ns.Load(function()' \
                or lines[-1] != 'end)':
            bad.append(name)
            continue
        # nothing but comments before the header
        if any(line.strip() and not line.lstrip().startswith('--') for line in lines[:heads[0]]):
            bad.append(name)
    assert not bad, 'without ns.Load(function() ... end) right after "local ADDON, ns = ...": ' + ', '.join(bad)


def test_what_loads_at_once_has_no_texts():
    files = sorted(f for f in {f for toc in TOCS for f in toc_files(toc)} if at_once(f) and f != 'Locales/Locale.lua')
    assert 'Core/LazyData.lua' in files and len(files) > 10
    for name in files:
        with open(os.path.join(ADDON, name), encoding='utf-8') as fh:
            text = fh.read()
        # texts only in a part that waits (Core/LazyData.lua's memory report)
        now = text.split('\nns.Load(function()\n')[0]
        assert not re.search(r'(?<![\w.])L\[', now) and 'ns.L[' not in now, name
