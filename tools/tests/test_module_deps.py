"""The modules of Amisia (F-202, D-130): the core (Amisia) never needs a module, the raid module
(Amisia_Raid) and the gear module (Amisia_Gear, "Ausrüstung & Dungeons") need each other only behind a
check, and nothing that runs while the files load names a part that loads later.

tools/modules.py holds the membership (which file belongs to which part) and the check. In short:
a use (a call, an index, a field: ns.X(), ns.X.f(), ns.X[k], or the same through a local alias) of a
symbol of another part than the core must be guarded: inside "if R then", after "R and" or "not R or" in
the same expression, or after "if not R then ... return end"; R is the symbol itself, an alias of it or
ns.HasModule("raid"/"gear"). A bare read (if ns.X then, local A = ns.X) uses nothing. The full rule is
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
RAID = HEAD + '''
function ns.RaidKey(s) return s end
ns.Cal = {}
''' + FOOT
CORE = HEAD + '''
function ns.Load(f) f() end
ns.W = {}
function ns.HasModule(k) return false end
''' + FOOT


def world(path, module, body):
    files = []
    for name, mod, src in (('Core/Base.lua', 'core', CORE), ('Raid/Base.lua', 'raid', RAID),
                           ('Gear/Base.lua', 'gear', GEAR), (path, module, HEAD + body + FOOT)):
        toks = modules.tokenize(src)
        files.append((name, mod, toks, modules.aliases_of(toks)))
    return [b for b in modules.check(files) if b[0] == path]


def bad(body, path='Core/Test.lua', module='core'):
    return world(path, module, body)


def test_every_file_has_a_part():
    by = modules.files_by_module()
    assert sum(len(v) for v in by.values()) == sum(1 for n, _ in modules.toc_entries() if n.endswith('.lua'))
    assert len(by['core']) > 25 and len(by['raid']) > 50 and len(by['gear']) > 80


def test_the_membership():
    toc = dict(modules.toc_entries())
    # the gear module is the Forever part: its files carry the camelot mark, and every camelot file is
    # the gear module's but the two raid features Forever has alone
    for name, camelot in toc.items():
        part = modules.module_of(name)
        if camelot and name not in ('Raid/Handover.lua', 'UI/Pages/Export.lua'):
            assert part == 'gear', name
        if part == 'gear' and name.endswith('.lua') and not name.startswith('Locales/'):
            assert camelot, 'a gear file without the camelot mark: ' + name
    assert modules.module_of('Raid/Handover.lua') == 'raid' and modules.module_of('UI/Pages/Export.lua') == 'raid'
    assert modules.module_of('Raid/Alts.lua') == 'core'
    assert modules.module_of('Raid/Record.lua') == 'raid' and modules.module_of('Core/Core.lua') == 'core'
    assert modules.module_of('Raid/Module.lua') == 'raid' and modules.module_of('Gear/Module.lua') == 'gear'
    for name in ('Core/Registry.lua', 'Core/Comm.lua', 'Core/SelfTest.lua', 'UI/MainFrame.lua', 'UI/Pages/Overview.lua',
                 'UI/Pages/Settings.lua', 'UI/LootToast.lua', 'Locales/Locale.lua'):
        assert modules.module_of(name) == 'core', name


def test_each_module_marks_itself_first():
    # Raid/Module.lua and Gear/Module.lua (ns.HasModule) come before every other file of their part
    by = modules.files_by_module()
    assert [n for n in by['raid'] if not n.startswith('Locales/')][0] == 'Raid/Module.lua'
    assert [n for n in by['gear'] if not n.startswith('Locales/')][0] == 'Gear/Module.lua'


def test_no_forbidden_reference():
    found = modules.check()
    assert not found, 'module boundary (D-130, tools/modules.py):\n' + '\n'.join(
        '%s:%d  %s -> %s  %s' % b for b in found)


def test_a_new_direct_use_fails():
    # the core may not call the gear module, nor the raid module the gear module, unguarded
    assert bad('local function f() return ns.Bis.Score(1) end')
    assert bad('local function f() return ns.BisChar() end')
    assert bad('local function f() return ns.RaidKey(1) end')
    assert bad('local function f() return ns.Bis.Score(1) end', 'Raid/Test.lua', 'raid')
    assert bad('local function f() return ns.RaidKey(1) end', 'Gear/Test.lua', 'gear')
    # through a local alias, and a function added to a core table by a module
    assert bad('local B = ns.Bis\nlocal function f() return B.Score(1) end')
    assert bad('local function f() ns.W.GearThing() end')
    # a symbol nobody defines (a typo, or gone)
    assert bad('local function f() return ns.NoSuchThing(1) end', 'Raid/Test.lua', 'raid')
    # a guard of another symbol does not count
    assert bad('local function f() if ns.Cal then return ns.Bis.Score(1) end end')
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
    assert not bad('local function f() if not ns.HasModule("raid") then return end ns.RaidKey(1) end')
    # a bare read is no use; the core and a module itself are free
    assert not bad('local function f() return ns.Bis ~= nil end')
    assert not bad('local function f() return ns.Bis.Score(1) end', 'Gear/Test.lua', 'gear')
    assert not bad('local function f() return ns.HasModule("x") end', 'Raid/Test.lua', 'raid')


def test_nothing_of_a_later_part_while_the_files_load():
    # the bodies run core, raid, gear (step 2 of F-202): a body reads no symbol of a later part, even
    # guarded; inside a function it may
    assert bad('local Bis = ns.Bis')
    assert bad('local c = ns.BisChar and ns.BisChar()', 'Raid/Test.lua', 'raid')
    assert bad('if ns.Cal then x = 1 end')
    assert not bad('local function f() local Bis = ns.Bis return Bis and Bis.Score(1) end')
    assert not bad('local R = ns.RaidKey', 'Gear/Test.lua', 'gear')


def test_each_text_stands_where_its_users_load():
    # an English text the core uses, or both modules, stands in a core locale file (enUS_core.lua,
    # enUS_selftest.lua); a module's locale file holds only texts of that module (python3 tools/l10n.py
    # check keeps the texts themselves right)
    import l10n
    used, data = l10n.used_keys(), l10n.data_keys()
    wrong = []
    for path in l10n.enus_files():
        part = modules.module_of('Locales/' + os.path.basename(path))
        if part == 'core':
            continue
        for key, _ in l10n.file_entries(path):
            users = {modules.module_of(os.path.relpath(os.path.join(l10n.ROOT, f), l10n.ADDON).replace(os.sep, '/'))
                     for f, _ in used.get(key, [])}
            if key in data:
                users.add('gear')
            if not users <= {part}:
                wrong.append('%s: %r (%s)' % (os.path.basename(path), key, ', '.join(sorted(users))))
    assert not wrong, 'texts in the locale file of another part:\n' + '\n'.join(wrong[:20])


def test_the_checker_reads_every_file():
    # the tokenizer reads every addon file (strings, long strings and comments included)
    for name, mod, toks, aliases in modules.read_files():
        assert toks, name
