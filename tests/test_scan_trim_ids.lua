-- The trim of the scans by id (Collect/ScanTrim.lua, D-104): lines of the scan's language whose hash
-- the marker lists go, changed lines and lines of another language stay; the ids without an answer
-- the archive holds go from the ranges; the progress fields stay.
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

local function stepped(lines)
    local ids, out, prev = {}, {}, 0
    for id in pairs(lines) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do out[#out + 1] = b36(id - prev) .. "." .. b36(H(lines[id])); prev = id end
    return table.concat(out, ",")
end

-- the ranges helper: what is left of a ranges text without another
local R = NS.ScanTrimRanges
assert(R("1-10", "3-4") == "1-2,5-10")
assert(select(2, R("1-10", "3-4")) == 2)
assert(R("1-10,20,30-35", "1-10,31") == "20,30,32-35", R("1-10,20,30-35", "1-10,31"))
assert(R("5,7,9", "") == "5,7,9")
assert(R("", "1-100") == "")
assert(R("1-3", "0-50") == "")

-- what the archive had (deDE): quest 1 as it is, quest 2 older; NPC 10 as it is; empties 100-110 and 7
local ARCH_Q = { [1] = "Eins\t5", [2] = "Zwei alt\t6" }
local ARCH_N = { [10] = "Hogger\t<Gnoll>" }
AmisiaDB.scan = {
    items = {}, sources = {}, retry = {}, count = 0, sourceCount = 0,
    quests = { loc = "deDE", next = 40, n = 3, list = { [1] = "Eins\t5", [2] = "Zwei neu\t6", [3] = "Drei\t7" }, none = "7,8,9" },
    npcs = { loc = "deDE", a = 5, b = 1200, n = 2, list = { [10] = "Hogger\t<Gnoll>", [11] = "Neu" }, empty = "100-120,130" },
}
rawset(NS, "SCAN_DONE", { built = "2026-11-10:ids", items = 0, sources = 0, client = "", cmax = 0, I = "", S = "", C = "",
    QL = { deDE = stepped(ARCH_Q), enUS = stepped({ [3] = "Drei\t7" }) }, QE = { deDE = "7" },
    NL = { deDE = stepped(ARCH_N) }, NE = { deDE = "100-110" } })

local res = NS.ScanTrimNow()
assert(res and res.quests == 1 and res.npcs == 1, res and (res.quests .. " " .. res.npcs))
local q, n = AmisiaDB.scan.quests, AmisiaDB.scan.npcs
assert(not q.list[1] and q.list[2] == "Zwei neu\t6" and q.list[3] == "Drei\t7", "a changed line and one of another language stay")
assert(q.none == "8-9", q.none)
assert(q.next == 40 and q.loc == "deDE" and q.n == 2, "progress stays")
assert(not n.list[10] and n.list[11] == "Neu" and n.n == 1)
assert(n.empty == "111-120,130", n.empty)
assert(n.a == 5 and n.b == 1200)
assert(AmisiaDB.scan.trim.quests == 1 and AmisiaDB.scan.trim.npcs == 1)
assert(STUB.messages[#STUB.messages]:find("Dazu 1 Quests und 1 NPC-Namen", 1, true), STUB.messages[#STUB.messages])

-- a marker without the new parts (an older build) leaves them alone
AmisiaDB.scan.quests.list[1] = "Eins\t5"
rawset(NS, "SCAN_DONE", { built = "2026-11-09:old", items = 0, sources = 0, client = "", cmax = 0, I = "", S = "", C = "" })
res = NS.ScanTrimNow()
assert(res and res.quests == 0 and AmisiaDB.scan.quests.list[1] == "Eins\t5")

-- the trim waits while a scan by id runs
rawset(NS, "SCAN_DONE", { built = "2026-11-10:ids", items = 0, sources = 0, client = "", cmax = 0, I = "", S = "", C = "" })
NS.ScanById.SetBusy("npcs")
local ok, why = NS.ScanTrimNow()
assert(not ok and why:find("Erst den Scan anhalten", 1, true), why)
NS.ScanById.SetBusy(nil)
print("scan trim of the scans by id: lines per language, ranges, progress kept")
