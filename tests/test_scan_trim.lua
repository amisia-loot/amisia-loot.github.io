-- The scan trim (Collect/ScanTrim.lua): only what the marker covers leaves AmisiaDB.scan; in steps at
-- login, at once by command; the setting turns the login run off.
local function b36(n)
    local digits, out = "0123456789abcdefghijklmnopqrstuvwxyz", ""
    if n == 0 then return "0" end
    while n > 0 do
        local r = n % 36
        out = digits:sub(r + 1, r + 1) .. out
        n = (n - r) / 36
    end
    return out
end
local H = NS.ScanTrimHash

-- the hash is the build's (tools/build_scan_archive.py lua_hash): fixed values
assert(H("") == 0 and H("a") == 97 and H("ab") == 97 * 31 + 98, "h = h * 31 + byte")
assert(H("Rekrutenhemd\t1\t1\t0\t4\t0\tINVTYPE_BODY\t135009\t0") == 216741158, H("Rekrutenhemd\t1\t1\t0\t4\t0\tINVTYPE_BODY\t135009\t0"))
assert(H("Händler: Wuark [3881] @Brachland") == 40464479, H("Händler: Wuark [3881] @Brachland"))

-- A marker over these lines and notes: I and S in the build's form, C the client's ids as ranges.
local function marker(lines, notes, ranges, cmax)
    local I, prev = {}, 0
    local ids = {}
    for id in pairs(lines) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do I[#I + 1] = b36(id - prev) .. "." .. b36(H(lines[id])); prev = id end
    local S = {}
    ids, prev = {}, 0
    for id in pairs(notes) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local e = b36(id - prev)
        for _, n in ipairs(notes[id]) do e = e .. "." .. b36(H(n)) end
        S[#S + 1] = e
        prev = id
    end
    local C, last = {}, 0
    for _, r in ipairs(ranges or {}) do C[#C + 1] = b36(r[1] - last) .. "." .. b36(r[2] - r[1] + 1); last = r[2] end
    return { built = "2026-10-08:test", items = #I, sources = #S, client = "1.60.1.70235", cmax = cmax or last,
             I = table.concat(I, ","), S = table.concat(S, ","), C = table.concat(C, ",") }
end

local function fill()
    AmisiaDB.scan = {
        next = 25001, from = 1, to = 25000, rate = 100, at = 1791316479,
        items = { [10] = "Zehn\t1", [11] = "Elf neu\t2", [12] = "Zwölf\t3", [500] = "Fünfhundert\t4" },
        sources = { [10] = { "Auktionshaus", "Haendler: Wuark [3881] @Brachland" }, [12] = { "Auktionshaus" }, [13] = { "Quest: X [5] L3" } },
        retry = { 3, 7, 7, 10, 40, 99999, 300 },
        suffix = { [10] = { [5] = "STRENGTH=3" } },
        count = 4, sourceCount = 3,
    }
end

-- what the archive had: 10 and 12 as they are, 11 with an older line; notes of 10 (one of two) and 12;
-- the client knows 1-5, 10-12, 40 and 300-400, up to 500
local LINES = { [10] = "Zehn\t1", [11] = "Elf alt\t2", [12] = "Zwölf\t3", [20] = "Zwanzig\t1" }
local NOTES = { [10] = { "Auktionshaus" }, [12] = { "Auktionshaus" }, [14] = { "Auktionshaus" } }
local RANGES = { { 1, 5 }, { 10, 12 }, { 40, 40 }, { 300, 400 } }

fill()
NS.SCAN_DONE = marker(LINES, NOTES, RANGES, 500)
STUB.messages = {}
local res = NS.ScanTrimNow()
local s = AmisiaDB.scan
assert(res and res.items == 2 and res.notes == 2 and res.sources == 1, STUB.dump(res))
assert(s.items[10] == nil and s.items[12] == nil, "covered lines go")
assert(s.items[11] == "Elf neu\t2", "a line that changed since the build stays")
assert(s.items[500] == "Fünfhundert\t4", "a line the archive does not have stays")
assert(#s.sources[10] == 1 and s.sources[10][1] == "Haendler: Wuark [3881] @Brachland", "only the covered note goes")
assert(s.sources[12] == nil, "an item whose notes all went goes")
assert(s.sources[13][1] == "Quest: X [5] L3", "notes of an item the marker does not list stay")
-- retry: 7 (twice) is not in the client, 10 the archive holds; 3, 40 and 300 the client knows; 99999 is above cmax
assert(STUB.dump(s.retry) == STUB.dump({ 3, 40, 99999, 300 }), STUB.dump(s.retry))
assert(res.retry == 3, res.retry)
assert(s.next == 25001 and s.from == 1 and s.to == 25000 and s.rate == 100, "the scan's progress stays")
assert(s.suffix[10][5] == "STRENGTH=3", "suffixes stay (Gear.lua reads them)")
assert(s.count == 2 and s.sourceCount == 2, "counts follow what is left")
assert(s.trim.built == "2026-10-08:test" and s.trim.items == 2 and s.trim.total == 2)
assert(STUB.messages[#STUB.messages]:find("2 Items, 2 Quellen und 3 offene IDs entfernt", 1, true), STUB.messages[#STUB.messages])
assert(not NS.HasData("SCAN_DONE"), "the marker is let go after its run")
-- a second run in the session: nothing left to compare against
STUB.messages = {}
assert(NS.ScanTrimNow() == nil)
assert(STUB.messages[1]:find("Schon aufgeräumt", 1, true), STUB.messages[1])
-- twice is the same as once
NS.SCAN_DONE = marker(LINES, NOTES, RANGES, 500)
local before = STUB.dump(s.items) .. STUB.dump(s.sources) .. STUB.dump(s.retry)
res = NS.ScanTrimNow()
assert(res.items == 0 and res.notes == 0 and res.retry == 0 and STUB.dump(s.items) .. STUB.dump(s.sources) .. STUB.dump(s.retry) == before)
assert(s.trim.total == 2)

-- without a client table in the marker (C empty) no retry id goes but the archived ones
fill()
NS.SCAN_DONE = marker(LINES, NOTES, nil, 0)
NS.ScanTrimNow()
assert(STUB.dump(AmisiaDB.scan.retry) == STUB.dump({ 3, 7, 7, 40, 99999, 300 }), STUB.dump(AmisiaDB.scan.retry))

-- the command words, German and English
for _, word in ipairs({ "aufräumen", "cleanup" }) do
    fill()
    NS.SCAN_DONE = marker(LINES, NOTES, RANGES, 500)
    NS.ScanCommand(word)
    assert(AmisiaDB.scan.items[10] == nil and AmisiaDB.scan.items[11], word)
end

-- not while the scan runs
fill()
NS.SCAN_DONE = marker(LINES, NOTES, RANGES, 500)
STUB.instance = { name = "Shattrath", type = "none", id = 0 }
assert(NS.ScanStart(1, 1000))
STUB.messages = {}
assert(NS.ScanTrimNow() == nil and AmisiaDB.scan.items[10], "refused while scanning")
assert(STUB.messages[1]:find("Scan anhalten", 1, true), STUB.messages[1])
NS.ScanStop()

-- in steps: a small budget leaves work for later ticks
local many, lines, notes = {}, {}, {}
for id = 1000, 1999 do many[id] = "Item " .. id .. "\t2\t10"; lines[id] = many[id] end
for id = 1000, 1199 do notes[id] = { "Auktionshaus" } end
local function fillMany()
    local items, sources = {}, {}
    for id, l in pairs(many) do items[id] = l end
    for id = 1000, 1199 do sources[id] = { "Auktionshaus" } end
    AmisiaDB.scan = { items = items, sources = sources, retry = {}, next = 2000, from = 1000, to = 1999, count = 1000 }
end
fillMany()
NS.SCAN_DONE = marker(lines, notes, { { 1, 3000 } }, 3000)
NS.SCAN_TRIM.budget = 50
local finished
assert(NS.ScanTrimStart(function(r) finished = r end))
assert(NS.ScanTrimRunning() and not finished, "the first step does not do it all")
assert(NS.ScanTrimNow() == nil, "a second run waits for the first")
local function left()
    local n = 0
    for _ in pairs(AmisiaDB.scan.items) do n = n + 1 end
    return n
end
for _ = 1, 3 do STUB.tick(NS.SCAN_TRIM.step) end
assert(NS.ScanTrimRunning() and left() > 0 and left() < 1000, "a few steps did some, not all: " .. left())
STUB.tick(30)
assert(finished and finished.items == 1000 and finished.notes == 200 and not NS.ScanTrimRunning(), STUB.dump(finished))
assert(next(AmisiaDB.scan.items) == nil and next(AmisiaDB.scan.sources) == nil)
assert(AmisiaDB.scan.next == 2000 and AmisiaDB.scan.from == 1000, "progress kept")
-- something new while it ran stays
fillMany()
NS.SCAN_DONE = marker(lines, notes, { { 1, 3000 } }, 3000)
finished = nil
NS.ScanTrimStart(function(r) finished = r end)
AmisiaDB.scan.items[5000] = "Neu\t1"
AmisiaDB.scan.items[1999] = "Item 1999 anders\t2\t10"
STUB.tick(30)
assert(finished and AmisiaDB.scan.items[5000] == "Neu\t1" and AmisiaDB.scan.items[1999] == "Item 1999 anders\t2\t10",
    "new and changed lines of the session stay")
NS.SCAN_TRIM.budget = 3000

-- at login: a few seconds late, in steps; quiet unless the marker is new to the file
fillMany()
AmisiaDB.scan.trim = { built = "2026-10-08:test" }
NS.SCAN_DONE = marker(lines, notes, { { 1, 3000 } }, 3000)
STUB.messages = {}
STUB.fire("PLAYER_LOGIN")
STUB.tick(NS.SCAN_TRIM.delay - 1)
assert(AmisiaDB.scan.items[1000], "nothing before the delay")
STUB.tick(5)
assert(next(AmisiaDB.scan.items) == nil, "trimmed after the delay")
assert(#STUB.messages == 0, "the same marker again says nothing")
-- a new marker says what it did
fillMany()
AmisiaDB.scan.trim = { built = "older" }
NS.SCAN_DONE = marker(lines, notes, { { 1, 3000 } }, 3000)
STUB.messages = {}
STUB.fire("PLAYER_LOGIN")
STUB.tick(NS.SCAN_TRIM.delay + 5)
assert(next(AmisiaDB.scan.items) == nil and STUB.messages[1] and STUB.messages[1]:find("1000 Items", 1, true), STUB.dump(STUB.messages))

-- the setting off: the login leaves the file alone, the command still works
assert(NS.Get("tools.scanAutotrim") == true, "on by default")
NS.Set("tools.scanAutotrim", false)
fillMany()
NS.SCAN_DONE = marker(lines, notes, { { 1, 3000 } }, 3000)
STUB.fire("PLAYER_LOGIN")
STUB.tick(NS.SCAN_TRIM.delay + 30)
assert(AmisiaDB.scan.items[1000], "no trim at login with the setting off")
NS.ScanCommand("aufräumen")
assert(next(AmisiaDB.scan.items) == nil, "the command trims anyway")
NS.Set("tools.scanAutotrim", true)

-- no marker in this version
fillMany()
NS.SCAN_DONE = nil
STUB.messages = {}
assert(NS.ScanTrimNow() == nil and AmisiaDB.scan.items[1000])
