"""What loading the addon costs in the test stub: per data file the time and memory to load it, and
the whole login (every file of the TOC, ADDON_LOADED, PLAYER_LOGIN, PLAYER_ENTERING_WORLD and ten
seconds of timers), then the first use of each lazy data table.

    python3 tools/load_cost.py [--eager]

--eager loads the data files with their tables built at once (as before Core/LazyData.lua), for the
comparison. The numbers are Lua 5.1 under lupa: the client's own differ, the ratio is what counts.
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


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--eager', action='store_true', help='also measure with the tables built at load (before)')
    args = ap.parse_args(argv)
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
