"""tests/run.py: the files it loads from the TOC. XML lines (the pin template) are the client's
business; the Lua runner must skip them, and the TOC must still list them."""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, 'tests'))
import run  # noqa: E402


def test_toc_files_skip_xml():
    files = run.toc_files()
    assert files, 'the TOCs list files'
    assert not [f for _, f in files if f.lower().endswith('.xml')], files
    assert all(f.endswith('.lua') for _, f in files), files
    # the core's files first, then the raid module's, then the gear module's (F-202)
    parts = [p for p, _ in files]
    assert parts == sorted(parts, key=['core', 'raid', 'gear'].index)
    assert [p for p, _ in run.toc_files('tbc')] and 'gear' not in {p for p, _ in run.toc_files('tbc')}


def test_toc_loads_the_map_pins_without_a_template():
    with open(os.path.join(ROOT, 'Amisia_Gear', 'Amisia_Gear.toc'), encoding='utf-8') as fh:
        # the load condition ([AllowLoadGameType camelot], D-57) stays out of the name
        lines = [re.sub(r'\s*\[[^\]]*\]', '', ln.strip()) for ln in fh if ln.strip() and not ln.startswith('#')]
    # the pins are Amisia's own buttons on its own layer of the world map: no XML template
    assert not [ln for ln in lines if ln.lower().endswith('.xml')], lines
    assert lines.index('Gear\\GuildWishes.lua') < lines.index('Gear\\MapPins.lua') < lines.index('Gear\\MapPlaces.lua')
