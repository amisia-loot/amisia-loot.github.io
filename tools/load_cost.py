"""What loading the addon costs in the test stub: per data file the time and memory to load it, and
the whole login (every file of the TOC, ADDON_LOADED, PLAYER_LOGIN, PLAYER_ENTERING_WORLD and ten
seconds of timers), then the first use of each lazy data table, and what each file of the TOC holds
after it loaded (grouped: code, English texts, lazy data texts, data tables).

    python3 tools/load_cost.py [--eager] [--files N] [--locale enUS] [--sv FILE]

--eager loads the data files with their tables built at once (as before Core/LazyData.lua), for the
comparison. --files N lists the N biggest files (default 25, 0 for none). --locale loads as another
client language (default deDE). --sv loads a SavedVariables file first, as the client does, and shows
what it costs and what the scan trim (Collect/ScanTrim.lua) gives back. The numbers are Lua 5.1 under
lupa: the client's own differ, the ratio is what counts.
"""
import argparse
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, 'addon', 'tests'))
sys.path.insert(0, HERE)
import lua_data  # noqa: E402
import run as addon_run  # noqa: E402

LAZY = ('GEAR', 'MAP', 'QUEST_DATA', 'PROFESSIONS', 'TALENTS', 'MAGESCROLLS')
FILES = {'GEAR': 'GearData', 'MAP': 'MapData', 'QUEST_DATA': 'QuestData', 'PROFESSIONS': 'ProfessionData',
         'TALENTS': 'TalentData', 'MAGESCROLLS': 'MageScrollData'}

MEASURE = r'''
return function(src, name, eager)
    collectgarbage("collect"); collectgarbage("collect")
    local m0, t0 = collectgarbage("count"), os.clock()
    local ns = {}
    ns.LazyData = function(key, text)
        if eager then ns[key] = assert(loadstring(text))() else ns[key .. "_src"] = text end
    end
    assert(loadstring(src, "@" .. name))("Amisia", ns)
    local t1 = os.clock()
    collectgarbage("collect"); collectgarbage("collect")
    return (t1 - t0) * 1000, collectgarbage("count") - m0, ns
end
'''

LOGIN = r'''
local t0 = os.clock()
STUB.fire("PLAYER_LOGIN"); STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(10)
local t1 = os.clock()
collectgarbage("collect"); collectgarbage("collect")
local built = {}
for k in pairs(NS.DataBuilt and NS.DataBuilt() or {}) do built[#built + 1] = k end
table.sort(built)
return (t1 - t0) * 1000, collectgarbage("count"), table.concat(built, ",")
'''

FIRST = r'''
return function(key)
    collectgarbage("collect"); collectgarbage("collect")
    local m0, t0 = collectgarbage("count"), os.clock()
    local d = NS.Data and NS.Data(key) or NS[key]
    local t1 = os.clock()
    collectgarbage("collect"); collectgarbage("collect")
    return (t1 - t0) * 1000, collectgarbage("count") - m0, d ~= nil
end
'''


def per_file(eager):
    from lupa.lua51 import LuaRuntime
    out = []
    for key in LAZY:
        lua = LuaRuntime(unpack_returned_tuples=True)
        with open(os.path.join(ROOT, 'addon', 'Amisia', 'Data', FILES[key] + '.lua'), encoding='utf-8') as fh:
            src = fh.read()
        ms, kb, _ = lua.execute(MEASURE)(src, FILES[key] + '.lua', eager)
        out.append((FILES[key], len(src.encode('utf-8')) // 1024, ms, kb))
    return out


def login(eager):
    """Loads the whole addon like run.py does; with eager the data files' tables are built while they
    load (their text written out again by lua_data.eager)."""
    if eager:
        real_open = open

        def patched(path, *a, **kw):
            fh = real_open(path, *a, **kw)
            base = os.path.basename(str(path))
            if base.endswith('.lua') and base[:-4] in FILES.values() and 'Data' in str(path):
                text = lua_data.eager(fh.read())
                fh.close()
                import io
                return io.StringIO(text)
            return fh
        addon_run.open = patched
    t0 = time.perf_counter()
    lua = addon_run.fresh('')
    load_ms = (time.perf_counter() - t0) * 1000
    if eager:
        del addon_run.open
    lua.execute('collectgarbage("collect"); collectgarbage("collect")')
    load_kb = lua.eval('collectgarbage("count")')
    login_ms, login_kb, built = lua.execute(LOGIN)
    first = []
    if not eager:
        for key in LAZY:
            ms, kb, ok = lua.execute(FIRST)(key)
            first.append((key, ms, kb, ok))
    return load_ms, load_kb, login_ms, login_kb, built, first


GC = 'function() collectgarbage("collect"); collectgarbage("collect"); return collectgarbage("count") end'


def group_of(name, src):
    """The kind of a TOC file for the breakdown."""
    if name.startswith('Locales'):
        return 'English texts' if 'enUS_' in name else 'locale code'
    if name.startswith('Data'):
        return 'lazy data texts' if 'ns.LazyData(' in src else 'data tables'
    return 'code'


def per_toc(locale='deDE'):
    """[(KB held, file, KB of source, group)] for every TOC file in load order, then ADDON_LOADED;
    and the KB the stub itself holds."""
    from lupa.lua51 import LuaRuntime
    lua = LuaRuntime(unpack_returned_tuples=True)
    gc = lua.eval(GC)
    m0 = gc()
    with open(os.path.join(ROOT, 'addon', 'tests', 'wow_stub.lua'), encoding='utf-8') as fh:
        lua.execute(fh.read())
    lua.globals().STUB.locale = locale
    lua.globals().STUB.measure = addon_run.measure
    meta = lua.globals().STUB.tocMeta
    for k, v in addon_run.toc_meta().items():
        meta[k] = v
    stub = gc() - m0
    ns = lua.eval('{}')
    loader = lua.eval('function(src, name) return assert(loadstring(src, "@" .. name)) end')
    rows, prev = [], gc()
    for name in addon_run.toc_files():
        with open(os.path.join(addon_run.ADDON, name), encoding='utf-8') as fh:
            src = fh.read()
        loader(src, name)('Amisia', ns)
        now = gc()
        rows.append((now - prev, name.replace(os.sep, '/'), len(src.encode('utf-8')) / 1024, group_of(name, src)))
        prev = now
    lua.eval('function(ns) NS = ns; STUB.fire("ADDON_LOADED", "Amisia") end')(ns)
    now = gc()
    rows.append((now - prev, 'ADDON_LOADED', 0, 'saved data'))
    return rows, stub


def print_files(rows, stub, top):
    total = sum(r[0] for r in rows)
    print(f'  per file after it loaded ({total / 1024:.2f} MB the addon, {stub / 1024:.2f} MB the stub):')
    groups = {}
    for kb, _, _, g in rows:
        groups[g] = groups.get(g, 0) + kb
    for g, kb in sorted(groups.items(), key=lambda x: -x[1]):
        print(f'    {g:16} {kb:7.0f} KB')
    for kb, name, size, g in sorted(rows, reverse=True)[:top]:
        print(f'    {kb:7.0f} KB  {name:34} {size:6.0f} KB source  ({g})')


def with_saved_variables(path):
    """The addon load with a SavedVariables file, then the scan trim at login."""
    with open(path, encoding='utf-8') as fh:
        text = fh.read()
    lua = addon_run.fresh('', setup=lambda l: l.execute(text))
    gc = lua.eval(GC)
    loaded = gc()
    lua.execute('STUB.fire("PLAYER_LOGIN"); STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick((NS.SCAN_TRIM and NS.SCAN_TRIM.delay or 0) + 60)')
    trimmed = gc()
    return loaded, trimmed, os.path.getsize(path)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--eager', action='store_true', help='also measure with the tables built at load (before)')
    ap.add_argument('--files', type=int, default=25, help='list the N biggest files (0: none)')
    ap.add_argument('--locale', default='deDE', help='the client language to load as (default deDE)')
    ap.add_argument('--sv', help='a SavedVariables file to load first (its cost and the scan trim)')
    args = ap.parse_args(argv)
    if args.files:
        print(f'== what each file holds ({args.locale})')
        print_files(*per_toc(args.locale), args.files)
    if args.sv:
        loaded, trimmed, size = with_saved_variables(args.sv)
        print(f'== with {args.sv} ({size / 1024 / 1024:.2f} MB)')
        print(f'  addon load with it: {loaded / 1024:6.1f} MB; after the login and the scan trim: {trimmed / 1024:6.1f} MB')
    for eager in ([True, False] if args.eager else [False]):
        label = 'eager (tables at load)' if eager else 'lazy (text at load, tables on first use)'
        print(f'== {label}')
        for name, size, ms, kb in per_file(eager):
            print(f'  {name:15} {size:5d} KB file   load {ms:6.1f} ms   {kb:7.0f} KB held')
        load_ms, load_kb, login_ms, login_kb, built, first = login(eager)
        print(f'  addon load (all TOC files, ADDON_LOADED): {load_ms:6.0f} ms, {load_kb / 1024:6.1f} MB Lua memory')
        print(f'  login (PLAYER_LOGIN, ENTERING_WORLD, 10 s of timers): {login_ms:5.0f} ms, '
              f'{login_kb / 1024:6.1f} MB after; built at login: {built or "nothing"}')
        for key, ms, kb, ok in first:
            print(f'  first use of {key:12} {ms:6.1f} ms  +{kb:7.0f} KB' + ('' if ok else '  (no data)'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
