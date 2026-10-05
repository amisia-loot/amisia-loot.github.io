"""Runs every addon/tests/test_*.lua under Lua 5.1 with the small client stub.

Each test file gets a fresh runtime: the stub, then the test's preload block, then every addon
file in TOC order, then ADDON_LOADED. A preload block is a comment at the very top of a test file,
"--[[preload" up to "]]", run before the addon loads (to take away globals a client lacks).
Inside a test `NS` is the addon namespace and `AmisiaDB` the saved table.

Multi-client tests: a file that starts with "--[[clients Vulo_Sturmwind Fraktur]]" ("_" stands for
the space) gets one runtime per name (stub, the shared preload block, STUB.player set to the name,
the addon, ADDON_LOADED). The test text itself runs in a director runtime of its own, with:

  C(name, code)        runs Lua code in the runtime of name and returns its values (numbers,
                       strings, booleans and tables, copied through STUB.dump); "return" may be
                       left out for a single expression
  CLIENTS              the client names
  BUS.raid, BUS.guild  lists of names: RAID goes to everyone in BUS.raid (the sender too, as the
                       client echoes it), GUILD to everyone in BUS.guild, WHISPER to the runtime of
                       that player (a "-Realm" ending is dropped)
  BUS.realm            text appended to the sender of every delivered message (default "")
  BUS.setRaid(names)   BUS.raid and STUB.roster of every client (those not listed get none)
  BUS.setGuild(list)   BUS.guild and STUB.guild of every client; list of { name, rank, online }
  BUS.deliver()        hands every sent message to its receivers (CHAT_MSG_ADDON)
  BUS.tick(s)          runs all clocks in steps of 0.1 s and delivers after each step
  BUS.lock(on)         sets the chat lockdown everywhere and fires ADDON_RESTRICTION_STATE_CHANGED
  BUS.drop(fn)         drops sent messages for which fn(msg) is true (nil: drop none)
  BUS.sent             every sent message: { sender, prefix, text, chan, target, t, proto, kind,
                       dropped }
  BUS.count(filter)    sent messages matching filter (prefix, kind, chan, sender, target, from, to
                       (stub clock), or a function)
"""
import glob
import os
import re
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
                # load conditions like "[AllowLoadGameType camelot]" stay out of the file name;
                # the tests load every file
                name = re.sub(r'\s*\[[^\]]*\]', '', line).replace('\\', os.sep)
                # XML files (templates) are for the client; a test reads them itself
                if name.lower().endswith('.xml'):
                    continue
                out.append(name)
    return out


PRELOAD = re.compile(r'\A--\[\[preload\n(.*?)\n\]\]', re.S)
CLIENTS = re.compile(r'\A--\[\[clients ([^\]\n]*)\]\]\n?')


def fresh(source='', player=None, setup=None):
    lua = LuaRuntime(unpack_returned_tuples=True)
    with open(os.path.join(ROOT, 'tests', 'wow_stub.lua'), encoding='utf-8') as fh:
        lua.execute(fh.read())
    pre = PRELOAD.match(source)
    if pre:
        lua.execute(pre.group(1))
    if player is not None:
        lua.globals().STUB.player = player
    # a client without C_EncodingUtil (STUB.noEncoding set in the preload)
    lua.execute('if STUB.noEncoding then C_EncodingUtil = nil end')
    if setup:
        setup(lua)
    # the addon folder, for a test that loads one file again (a /reload of it)
    lua.globals().ADDON_DIR = ADDON
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


# Strings cross between runtimes as hex, so no byte is ever decoded on the Python side.
CLIENT_PRELUDE = r'''
local function tohex(s) return (tostring(s or ""):gsub(".", function(c) return ("%02x"):format(c:byte()) end)) end
local function fromhex(h) return (h:gsub("%x%x", function(x) return string.char(tonumber(x, 16)) end)) end
function BUS_SEND(sender, prefix, text, chan, target)
    BUS_PY(tohex(prefix), tohex(text), tohex(chan), tohex(target or ""), STUB.clock)
end
function BUS_RECV(prefix, text, chan, sender, target)
    STUB.fire("CHAT_MSG_ADDON", fromhex(prefix), fromhex(text), fromhex(chan), fromhex(sender), fromhex(target), 0, 0, "", 0)
end
function BUS_RUN(code)
    local fn = loadstring("return " .. code, "=C")
    if not fn then fn = assert(loadstring(code, "=C")) end
    local out = { n = 0 }
    local function pack(...) out.n = select("#", ...); for i = 1, out.n do out[i] = select(i, ...) end end
    pack(fn())
    local parts = {}
    for i = 1, out.n do parts[i] = STUB.dump(out[i]) end
    return tohex("return " .. (out.n > 0 and table.concat(parts, ",") or "nil"))
end
function BUS_SET(field, src)
    STUB[field] = assert(loadstring(src))()
end
'''

DIRECTOR_PRELUDE = r'''
local function fromhex(h) return (h:gsub("%x%x", function(x) return string.char(tonumber(x, 16)) end)) end
BUS = { raid = {}, guild = {}, sent = {}, realm = "" }
function BUS_ADD(sender, prefix, text, chan, target, t)
    prefix, text, chan, target = fromhex(prefix), fromhex(text), fromhex(chan), fromhex(target)
    local m = { sender = sender, prefix = prefix, text = text, chan = chan, target = target ~= "" and target or nil, t = t,
                proto = tonumber(text:sub(1, 1)), kind = text:match("^%d(%u%u)") }
    BUS.sent[#BUS.sent + 1] = m
    if BUS._drop and BUS._drop(m) then m.dropped = true end
    return not m.dropped
end
function BUS_LOAD(hex) return assert(loadstring(fromhex(hex)))() end
function BUS.drop(fn) BUS._drop = fn end
function BUS.count(f)
    local n = 0
    for _, m in ipairs(BUS.sent) do
        local ok
        if type(f) == "function" then
            ok = f(m)
        else
            f = f or {}
            ok = (not f.prefix or m.prefix == f.prefix) and (not f.kind or m.kind == f.kind) and (not f.chan or m.chan == f.chan)
                and (not f.sender or m.sender == f.sender) and (not f.target or m.target == f.target)
                and (not f.from or m.t >= f.from) and (not f.to or m.t <= f.to)
        end
        if ok then n = n + 1 end
    end
    return n
end
'''


class Bus:
    def __init__(self, names, source):
        self.order = names
        self.pending = []
        self.director = LuaRuntime(unpack_returned_tuples=True)
        self.director.execute(DIRECTOR_PRELUDE)
        self.clients = {}
        for name in names:
            def setup(lua, name=name):
                lua.execute(CLIENT_PRELUDE)
                lua.globals().BUS_PY = lambda p, t, c, tg, clock, name=name: self.sent(name, p, t, c, tg, clock)
            self.clients[name] = fresh(source, player=name, setup=setup)
        g = self.director.globals()
        bus = g.BUS
        g.C = self.run
        g.CLIENTS = self.director.table_from(names)
        bus.deliver = self.deliver
        bus.tick = self.tick
        bus.lock = self.lock
        bus.setRaid = self.set_raid
        bus.setGuild = self.set_guild

    def client(self, name):
        name = str(name).replace('_', ' ')
        if name not in self.clients:
            raise KeyError('no client ' + name)
        return self.clients[name]

    def run(self, name, code):
        hexsrc = self.client(name).globals().BUS_RUN(code)
        return self.director.globals().BUS_LOAD(hexsrc)

    def sent(self, sender, prefix, text, chan, target, clock):
        if self.director.globals().BUS_ADD(sender, prefix, text, chan, target, clock):
            self.pending.append((sender, prefix, text, chan, target))

    def _names(self, field):
        tbl = self.director.globals().BUS[field]
        return [str(v) for v in tbl.values()] if tbl else []

    def _whisper_target(self, target_hex):
        target = bytes.fromhex(target_hex).decode('utf-8', 'replace')
        if target in self.clients:
            return target
        base = target.rsplit('-', 1)[0] if '-' in target else None
        return base if base in self.clients else None

    def deliver(self):
        rounds = 0
        while self.pending:
            rounds += 1
            if rounds > 10000:
                raise RuntimeError('the bus does not settle')
            sender, prefix, text, chan, target = self.pending.pop(0)
            kind = bytes.fromhex(chan).decode('ascii', 'replace')
            if kind == 'RAID':
                to = [n for n in self._names('raid') if n in self.clients]
                if sender not in self._names('raid'):
                    to = []
            elif kind == 'GUILD':
                to = [n for n in self._names('guild') if n in self.clients]
                if sender not in self._names('guild'):
                    to = []
            elif kind == 'WHISPER':
                t = self._whisper_target(target)
                to = [t] if t else []
            else:
                to = []
            shown = (sender + str(self.director.globals().BUS.realm or '')).encode('utf-8').hex()
            for name in to:
                self.clients[name].globals().BUS_RECV(prefix, text, chan, shown, target)

    def tick(self, seconds):
        steps = int(round(float(seconds) / 0.1))
        for _ in range(steps):
            for name in self.order:
                self.clients[name].globals().STUB.tick(0.1)
            self.deliver()
        self.deliver()

    def lock(self, on):
        on = bool(on)
        for name in self.order:
            lua = self.clients[name]
            lua.globals().STUB.chatLock = on
            lua.globals().STUB.fire('ADDON_RESTRICTION_STATE_CHANGED', 5, 2 if on else 0)
        self.deliver()

    def set_raid(self, names):
        names = [str(v).replace('_', ' ') for v in names.values()] if names else []
        self.director.globals().BUS.raid = self.director.table_from(names)
        roster = 'return {' + ','.join('{name=%s,class="PRIEST"}' % lua_str(n) for n in names) + '}'
        for name in self.order:
            self.clients[name].globals().BUS_SET('roster', roster if name in names else 'return {}')

    def set_guild(self, members):
        rows = []
        for m in (members.values() if members else []):
            name = str(m['name'] if m['name'] is not None else m[1]).replace('_', ' ')
            rank = m['rank'] if m['rank'] is not None else (m[2] if m[2] is not None else 3)
            online = m['online'] if m['online'] is not None else (m[3] if m[3] is not None else True)
            rows.append((name, int(rank), bool(online)))
        self.director.globals().BUS.guild = self.director.table_from([r[0] for r in rows])
        src = 'return {' + ','.join('{name=%s,rank=%d,online=%s,class="PRIEST"}' % (lua_str(n), r, 'true' if o else 'false')
                                     for n, r, o in rows) + '}'
        for name in self.order:
            self.clients[name].globals().BUS_SET('guild', src)


def lua_str(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'


def run_file(source):
    head = CLIENTS.match(source)
    if not head:
        lua = fresh(source)
        lua.execute(source)
        return
    names = [n.replace('_', ' ') for n in head.group(1).split()]
    rest = source[head.end():]
    bus = Bus(names, rest)
    bus.director.execute(rest)


def main(argv):
    only = argv[1] if len(argv) > 1 else None
    failed = 0
    for path in sorted(glob.glob(os.path.join(ROOT, 'tests', 'test_*.lua'))):
        base = os.path.basename(path)
        if only and only not in base:
            continue
        with open(path, encoding='utf-8') as fh:
            source = fh.read()
        try:
            run_file(source)
            print('ok   ', base)
        except Exception as exc:  # noqa: BLE001 - report every failure the same way
            failed += 1
            print('FAIL ', base)
            print('      ' + str(exc).strip().splitlines()[0][:500])
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
