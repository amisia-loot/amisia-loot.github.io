"""addon/tests/run.py: the files it loads from the TOC. XML lines (the pin template) are the client's
business; the Lua runner must skip them, and the TOC must still list them."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, 'addon', 'tests'))
import run  # noqa: E402


def test_toc_files_skip_xml():
    files = run.toc_files()
    assert files, 'the TOC lists files'
    assert not [f for f in files if f.lower().endswith('.xml')], files
    assert all(f.endswith('.lua') for f in files), files


def test_toc_lists_the_pin_template_after_its_mixin():
    with open(os.path.join(ROOT, 'addon', 'Amisia', 'Amisia.toc'), encoding='utf-8') as fh:
        lines = [ln.strip() for ln in fh if ln.strip() and not ln.startswith('#')]
    assert 'MapPin.xml' in lines
    assert lines.index('GuildWishes.lua') < lines.index('MapPins.lua') < lines.index('MapPin.xml')
