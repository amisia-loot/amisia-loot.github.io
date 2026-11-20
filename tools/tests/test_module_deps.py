"""The modules of Amisia (F-202, D-130; F-228, D-158): the core (Amisia, with the raid part) never needs a
module, the modules (Amisia_Gear "Ausrüstung", Amisia_Dungeons "Dungeons & Raids", Amisia_Talents "Talente")
need each other only behind a check, and nothing that runs while the files load names a part that loads
later.

tools/modules.py holds the membership (which file belongs to which part) and the check. In short:
a use (a call, an index, a field: ns.X(), ns.X.f(), ns.X[k], or the same through a local alias) of a
symbol of another part than the core must be guarded: inside "if R then", after "R and" or "not R or" in
the same expression, or after "if not R then ... return end"; R is the symbol itself, an alias of it or
ns.HasModule("gear"/"dungeons"/"talents"). A bare read (if ns.X then, local A = ns.X) uses nothing. The full rule is
in modules.check()'s docstring; the tests below show each form.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
import modules  # noqa: E402

HEAD = 'local ADDON, ns = ...\nns.Load(function()\n'
FOOT = '\nend)\n'

# a small world: one file per part that defines the symbols the cases use
GEAR = HEAD + '''
ns.Bis = {}
function ns.Bis.Score(x) return x end
function ns.BisChar() return {} end
local W = ns.W
function W.GearThing() end
''' + FOOT
DUNGEONS = HEAD + '''
function ns.DungeonKey(s) return s end
ns.Runs = {}
''' + FOOT
CORE = HEAD + '''
function ns.Load(f) f() end
ns.W = {}
function ns.HasModule(k) return false end
''' + FOOT


def world(path, module, body):
    files = []
    for name, mod, src in (('Core/Base.lua', 'core', CORE), ('Dungeons/Base.lua', 'dungeons', DUNGEONS),
                           ('Gear/Base.lua', 'gear', GEAR), (path, module, HEAD + body + FOOT)):
        toks = modules.tokenize(src)
        files.append((name, mod, toks, modules.aliases_of(toks)))
    return [b for b in modules.check(files) if b[0] == path]


def bad(body, path='Core/Test.lua', module='core'):
    return world(path, module, body)


def test_every_file_has_a_part():
    by = modules.files_by_module()
    assert sum(len(v) for v in by.values()) == sum(1 for n, _, _ in modules.toc_entries() if n.endswith('.lua'))
    assert len(by['core']) > 80 and len(by['gear']) > 15 and len(by['dungeons']) > 25 and len(by['talents']) >= 4
    # a path stands in one folder only (module_of and the tests' ADDON_FILE find a file by it)
    seen = {}
    for name, _, module in modules.toc_entries():
        assert name not in seen, '%s in %s and %s' % (name, seen[name], module)
        seen[name] = module
        assert modules.module_of(name) == module, name


def test_the_membership():
    # the modules are Forever parts: folders of their own whose TOCs target Forever only, so their files
    # carry no camelot mark; the core marks its Forever-only files (D-57), the raid part's two among them
    entries = modules.toc_entries()
    camelot = sorted(name for name, mark, _ in entries if mark)
    assert {'Raid/Handover.lua', 'UI/Pages/Export.lua'} <= set(camelot), camelot
    assert all(module == 'core' for name, mark, module in entries if mark)
    # the raid part is the core's (F-228)
    for name in ('Raid/Handover.lua', 'UI/Pages/Export.lua', 'Raid/Alts.lua', 'Raid/Record.lua', 'UI/Setup.lua',
                 'Core/SelfTestCalendar.lua', 'Locales/enUS_raid.lua', 'UI/Pages/Raids.lua'):
        assert modules.module_of(name) == 'core', name
    assert modules.module_of('Gear/Module.lua') == 'gear' and modules.module_of('UI/Pages/Planner.lua') == 'gear'
    for name in ('Core/Registry.lua', 'Core/Comm.lua', 'Core/SelfTest.lua', 'UI/MainFrame.lua', 'UI/Pages/Overview.lua',
                 'UI/Pages/Settings.lua', 'UI/LootToast.lua', 'Locales/Locale.lua', 'Core/Core.lua'):
        assert modules.module_of(name) == 'core', name


def test_each_module_marks_itself_first():
    # a module's Module.lua (the shared namespace, ns.HasModule) is the first file of its TOC, the core's
    # Locales/Locale.lua (_G.AmisiaCore) the first of the core's
    by = modules.files_by_module()
    for module in modules.MODULES:
        assert by[module][0] == modules.FIRST_FILE[module], module


def test_no_forbidden_reference():
    found = modules.check()
    assert not found, 'module boundary (D-130, tools/modules.py):\n' + '\n'.join(
        '%s:%d  %s -> %s  %s' % b for b in found)


def test_a_new_direct_use_fails():
    # the core may not call a module, nor one module another, unguarded
    assert bad('local function f() return ns.Bis.Score(1) end')
    assert bad('local function f() return ns.BisChar() end')
    assert bad('local function f() return ns.DungeonKey(1) end')
    assert bad('local function f() return ns.Bis.Score(1) end', 'Dungeons/Test.lua', 'dungeons')
    assert bad('local function f() return ns.DungeonKey(1) end', 'Gear/Test.lua', 'gear')
    # through a local alias, and a function added to a core table by a module
    assert bad('local B = ns.Bis\nlocal function f() return B.Score(1) end')
    assert bad('local function f() ns.W.GearThing() end')
    # a symbol nobody defines (a typo, or gone)
    assert bad('local function f() return ns.NoSuchThing(1) end', 'Dungeons/Test.lua', 'dungeons')
    # a guard of another symbol does not count
    assert bad('local function f() if ns.Runs then return ns.Bis.Score(1) end end')
    assert bad('local function f() if ns.Bis or x then return ns.Bis.Score(1) end end')
    assert bad('local function f() local a = ns.Bis and 1, ns.Bis.Score(1) end')
    assert bad('local function f() return ns.Bis and ns.Bis.x or ns.Bis.Score(1) end')
    assert bad('local function f() if not ns.Bis then print(1) end return ns.Bis.Score(1) end')


def test_the_guards():
    assert not bad('local function f() if ns.Bis then return ns.Bis.Score(1) end end')
    assert not bad('local function f() if x and ns.Bis ~= nil then return ns.Bis.Score(1) end end')
    assert not bad('local function f() return ns.Bis and ns.Bis.Score(1) or 0 end')
    assert not bad('local function f() if not ns.Bis then return end return ns.Bis.Score(1) end')
    assert not bad('local function f() if not ns.Bis or y then print(1) return end return ns.Bis.Score(1) end')
    assert not bad('local function f() if not ns.Bis or not ns.Bis.Score(1) then return end end')
    assert not bad('local function f() local B = ns.Bis if type(B) == "table" and B.Score then return B.Score(1) end end')
    assert not bad('local function f() if not ns.Bis then return 0 elseif x then return ns.Bis.Score(1) end end')
    assert not bad('local function f() if ns.HasModule("gear") then return ns.Bis.Score(1) end end')
    assert not bad('local function f() local g = ns.HasModule("gear") if g then ns.BisChar() end end')
    assert not bad('local function f() if not ns.HasModule("dungeons") then return end ns.DungeonKey(1) end')
    # a bare read is no use; the core and a module itself are free
    assert not bad('local function f() return ns.Bis ~= nil end')
    assert not bad('local function f() return ns.Bis.Score(1) end', 'Gear/Test.lua', 'gear')
    assert not bad('local function f() return ns.HasModule("x") end', 'Dungeons/Test.lua', 'dungeons')


def test_nothing_of_a_later_part_while_the_files_load():
    # the bodies run core, gear, dungeons, talents (F-202, F-228): a body reads no symbol of a later part,
    # even guarded; inside a function it may
    assert bad('local Bis = ns.Bis')
    assert bad('local c = ns.DungeonKey and ns.DungeonKey()', 'Gear/Test.lua', 'gear')
    assert bad('if ns.Runs then x = 1 end')
    assert not bad('local function f() local Bis = ns.Bis return Bis and Bis.Score(1) end')
    assert not bad('local B = ns.BisChar', 'Dungeons/Test.lua', 'dungeons')


def test_each_text_stands_where_its_users_load():
    # an English text the core uses, or two modules, stands in a core locale file (enUS_core.lua,
    # enUS_selftest.lua); a module's locale file holds only texts of that module (python3 tools/l10n.py
    # check keeps the texts themselves right)
    import l10n
    used, data = l10n.used_keys(), l10n.data_keys()
    wrong = []
    for path in l10n.enus_files():
        part = modules.module_of(os.path.relpath(path, l10n.ROOT))
        if part == 'core':
            continue
        for key, _ in l10n.file_entries(path):
            users = {modules.module_of(f) for f, _ in used.get(key, [])}
            if key in data:
                users.add('gear')
            if not users <= {part}:
                wrong.append('%s: %r (%s)' % (os.path.basename(path), key, ', '.join(sorted(users))))
    assert not wrong, 'texts in the locale file of another part:\n' + '\n'.join(wrong[:20])


def test_the_checker_reads_every_file():
    # the tokenizer reads every addon file (strings, long strings and comments included)
    for name, mod, toks, aliases in modules.read_files():
        assert toks, name
