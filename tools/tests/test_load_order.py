"""Every addon file but Locales/Locale.lua puts its body in ns.Load(function() ... end) (D-128).

The client loads Amisia's SavedVariables only after all its files ran, and the chosen language
(ui.language, F-199) must be known before a file translates its texts. Locales/Locale.lua is the
first file of the core's TOCs and runs the bodies once the core and the modules it expects have
loaded (D-130); a file without the wrapper would run before the language is chosen (and before the
files it may need), so these tests stop it.
The generated data (Data/*.lua, written by tools/build_*.py) and Core/LazyData.lua, which they call,
load at once as before: they hold no texts, which the last test checks. So does each module's first
file (Raid/Module.lua, Gear/Module.lua): it points the module's namespace at the core's before any
other file of the module runs (F-202).
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import modules  # noqa: E402

FLAVORS = ('', '_TBC', '_Vanilla')
HEADER = re.compile(r'^local [\w_]+, ns = \.\.\.\s*$')
AT_ONCE = {'Locales/Locale.lua', 'Core/LazyData.lua', 'Raid/Module.lua', 'Gear/Module.lua'}
FIRST = {'core': 'Locales/Locale.lua', 'raid': 'Raid/Module.lua', 'gear': 'Gear/Module.lua'}


def at_once(name):
    return name in AT_ONCE or name.startswith('Data/')


def toc_files(module, flavor=''):
    return [name for name, _, _ in modules.toc_entries(module, flavor) if name.endswith('.lua')]


def all_files():
    return {(name, module) for module in modules.MODULES for flavor in FLAVORS for name in toc_files(module, flavor)}


def test_each_part_starts_with_its_first_file():
    # the core's Locales/Locale.lua (ns.Load, _G.AmisiaCore), a module's Module.lua (the shared namespace);
    # the gear module's classic TOCs list no file (Forever only, D-130)
    for module in modules.MODULES:
        for flavor in FLAVORS:
            files = toc_files(module, flavor)
            if module == 'gear' and flavor:
                assert files == [], modules.toc_name(module, flavor)
                continue
            assert files and files[0] == FIRST[module], modules.toc_name(module, flavor)


def test_every_other_file_waits_for_the_language():
    bad = []
    files = sorted((f, m) for f, m in all_files() if not at_once(f))
    assert len(files) > 100
    for name, module in files:
        with open(os.path.join(modules.folder(module), name), encoding='utf-8') as fh:
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
    files = sorted((f, m) for f, m in all_files() if at_once(f) and f != 'Locales/Locale.lua')
    names = [f for f, _ in files]
    assert 'Core/LazyData.lua' in names and 'Raid/Module.lua' in names and len(files) > 10
    for name, module in files:
        with open(os.path.join(modules.folder(module), name), encoding='utf-8') as fh:
            text = fh.read()
        # texts only in a part that waits (Core/LazyData.lua's memory report)
        now = text.split('\nns.Load(function()\n')[0]
        assert not re.search(r'(?<![\w.])L\[', now) and 'ns.L[' not in now, name


def test_a_module_shares_the_core_namespace():
    # Module.lua: the metatable onto _G.AmisiaCore, the bodies queued as the module's part, the mark
    for module, name in (('raid', 'Raid/Module.lua'), ('gear', 'Gear/Module.lua')):
        with open(os.path.join(modules.folder(module), name), encoding='utf-8') as fh:
            text = fh.read()
        assert 'local core = _G.AmisiaCore' in text, name
        assert 'setmetatable(ns, { __index = core, __newindex = core })' in text, name
        assert 'core.LoadPart("%s", fn)' % module in text, name
        assert 'core.MODULES.%s = true' % module in text, name
    with open(os.path.join(modules.ADDON, 'Locales', 'Locale.lua'), encoding='utf-8') as fh:
        text = fh.read()
    assert '_G.AmisiaCore = ns' in text
