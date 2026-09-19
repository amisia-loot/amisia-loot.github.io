"""Runs every addon/tests/test_*.lua under Lua 5.1 with the small client stub.

Each test file gets a fresh runtime: the stub, then every addon file in TOC order,
then ADDON_LOADED. Inside a test `NS` is the addon namespace and `AmisiaDB` the saved table.
"""
import glob
import os
import sys

from lupa.lua51 import LuaRuntime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON = os.path.join(ROOT, 'Amisia')


def toc_files():
    out = []
    with open(os.path.join(ADDON, 'Amisia.toc'), encoding='utf-8') as fh:
        for line in fh:
            line = line.strip()
            if line and not line.startswith('#'):
                out.append(line)
    return out


def fresh():
    lua = LuaRuntime(unpack_returned_tuples=True)
    with open(os.path.join(ROOT, 'tests', 'wow_stub.lua'), encoding='utf-8') as fh:
        lua.execute(fh.read())
    ns = lua.eval('{}')
    loader = lua.eval('function(src, name) return assert(loadstring(src, "@" .. name)) end')
    for name in toc_files():
        path = os.path.join(ADDON, name)
        if not os.path.exists(path):
            continue
        with open(path, encoding='utf-8') as fh:
            chunk = loader(fh.read(), name)
        chunk('Amisia', ns)
    lua.eval('function(ns) NS = ns; STUB.fire("ADDON_LOADED", "Amisia") end')(ns)
    return lua


def main(argv):
    only = argv[1] if len(argv) > 1 else None
    failed = 0
    for path in sorted(glob.glob(os.path.join(ROOT, 'tests', 'test_*.lua'))):
        base = os.path.basename(path)
        if only and only not in base:
            continue
        lua = fresh()
        try:
            with open(path, encoding='utf-8') as fh:
                lua.execute(fh.read())
            print('ok   ', base)
        except Exception as exc:  # noqa: BLE001 - report every failure the same way
            failed += 1
            print('FAIL ', base)
            print('      ' + str(exc).strip().splitlines()[0][:500])
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
