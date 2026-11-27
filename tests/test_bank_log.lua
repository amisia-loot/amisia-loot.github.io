--[[preload
-- a guild bank with three tabs (tab 3 hidden from this character) and the transaction logs of the
-- client: per tab { type, name, link, count, tab1, tab2, years, months, days, hours } (time ago,
-- as GetGuildBankTransaction answers), the money log { type, name, copper, years, months, days, hours }
STUB.gbTabs = { { "Mats", true }, { "Rüstung", true }, { "Offiziere", false } }
STUB.gblog = { {}, {}, {} }
STUB.gbmoney = {}
STUB.logQueries = {}
GetNumGuildBankTabs = function() return #STUB.gbTabs end
GetGuildBankTabInfo = function(tab) local t = STUB.gbTabs[tab]; return t and t[1], 134, t and t[2] end
QueryGuildBankTab = function() end
GetCurrentGuildBankTab = function() return 1 end
GetGuildBankItemLink = function() return nil end
GetGuildBankItemInfo = function() return 134, 0 end
MAX_GUILDBANK_TABS = 8
QueryGuildBankLog = function(tab) STUB.logQueries[#STUB.logQueries + 1] = tab end
GetNumGuildBankTransactions = function(tab) return STUB.gblog[tab] and #STUB.gblog[tab] or 0 end
GetGuildBankTransaction = function(tab, i)
    local e = STUB.gblog[tab] and STUB.gblog[tab][i]
    if not e then return nil end
    return unpack(e, 1, 10)
end
GetNumGuildBankMoneyTransactions = function() return #STUB.gbmoney end
GetGuildBankMoneyTransaction = function(i)
    local e = STUB.gbmoney[i]
    if not e then return nil end
    return unpack(e, 1, 7)
end
]]
-- The guild bank log: reading every visible tab's log and the money log when the bank opens,
-- merging the reads without duplicates (the client gives times relative to now, in hours), pruning
-- by age and size, the filters of the page and the BT lines of the export.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local ore = STUB.item(61001, "Feuerkern", 3)
local cloth = STUB.item(61002, "Runenstoff", 1)

local function openBank()
    STUB.logQueries = {}
    STUB.fire("GUILDBANKFRAME_OPENED")
    -- each tab's log answers a moment after its query; the reader goes on with the next one
    for _ = 1, 6 do
        STUB.tick(0.3)
        STUB.fire("GUILDBANKLOG_UPDATE")
    end
    STUB.tick(5)
    STUB.fire("GUILDBANKFRAME_CLOSED")
end

---------------------------------------------------------------------------
-- settings
---------------------------------------------------------------------------
local logOn, days = NS.SettingItem("bank.log"), NS.SettingItem("bank.logDays")
assert(logOn and logOn.type == "toggle" and logOn.default == true, "bank.log")
assert(days and days.type == "slider" and days.default == 90, "bank.logDays: 90 days by default")

---------------------------------------------------------------------------
-- the merge rule on its own
---------------------------------------------------------------------------
local T0 = STUB.now
local function row(n, item, count, ago, kind, tab) return { k = tab or 1, y = kind or "deposit", n = n, i = item, c = count, ago = ago } end
assert(NS.MergeBankLog({ row("Fraktur", 61001, 20, 0), row("Fraktur", 61001, 20, 0), row("Vuloo", 61002, 5, 3) }, T0) == 3,
    "two identical deposits in the same hour stay two")
local list = NS.BankLog().list
assert(#list == 3, #list)
-- the same log read 40 minutes later: the newest two are now "1 hour ago" or still "0", nothing new
assert(NS.MergeBankLog({ row("Fraktur", 61001, 20, 0), row("Fraktur", 61001, 20, 0), row("Vuloo", 61002, 5, 3) }, T0 + 2400) == 0,
    "a later read of the same log adds nothing")
assert(NS.MergeBankLog({ row("Fraktur", 61001, 20, 1), row("Fraktur", 61001, 20, 1), row("Vuloo", 61002, 5, 4) }, T0 + 4000) == 0,
    "nor when the hours have moved on")
assert(#NS.BankLog().list == 3)
-- the reads narrow the time of an entry: real time lies in (read - (ago+1) h, read - ago h]
local f
for _, e in ipairs(NS.BankLog().list) do if e.n == "Fraktur" then f = e end end
assert(f.hi == T0 and f.lo == T0 + 2400 - 3600, ("lo %d hi %d"):format(f.lo - T0, f.hi - T0))
-- a third identical deposit in that hour is new; one of the same kind three hours earlier too
assert(NS.MergeBankLog({ row("Fraktur", 61001, 20, 1), row("Fraktur", 61001, 20, 1), row("Fraktur", 61001, 20, 1) }, T0 + 4000) == 1,
    "a third one in the same read is new")
assert(NS.MergeBankLog({ row("Fraktur", 61001, 20, 5) }, T0 + 4000) == 1, "another hour, another entry")
-- other count, other kind, other tab: new
assert(NS.MergeBankLog({ row("Fraktur", 61001, 19, 1), row("Fraktur", 61001, 20, 1, "withdraw"), row("Fraktur", 61001, 20, 1, nil, 2) }, T0 + 4000) == 3)
-- an entry older than a month: the months make the time fuzzy (three days either way)
assert(NS.MergeBankLog({ { k = 0, y = "repair", n = "Chorf", i = 0, c = 12345, ago = 24 * 35, fuzzy = true } }, T0) == 1)
assert(NS.MergeBankLog({ { k = 0, y = "repair", n = "Chorf", i = 0, c = 12345, ago = 24 * 33, fuzzy = true } }, T0 + 86400) == 0,
    "a fuzzy entry matches within its days")
-- a row older than bank.logDays is no new entry, on any read
assert(NS.Set("bank.logDays", 14))
local stale = { { k = 1, y = "deposit", n = "Anna", i = 61001, c = 5, ago = 20 * 24 } }
local kept = #NS.BankLog().list
assert(NS.MergeBankLog(stale, math.floor(time())) == 0 and NS.MergeBankLog(stale, math.floor(time()) + 3600) == 0,
    "older than the days kept: not counted")
assert(#NS.BankLog().list <= kept)
NS.Reset("bank.logDays")

---------------------------------------------------------------------------
-- reading the bank: every visible tab and the money log, one after another
---------------------------------------------------------------------------
AmisiaDB.bankLog = nil
NS.BankLogLoaded(AmisiaDB)
STUB.gblog[1] = {
    { "deposit", "Fraktur", ore, 20, nil, nil, 0, 0, 0, 2 },
    { "withdraw", "Vuloo", cloth, 5, nil, nil, 0, 0, 1, 3 },
    { "move", "Vuloo", ore, 3, 1, 2, 0, 0, 0, 0 },
}
STUB.gblog[2] = { { "deposit", "Anna Bergmann", cloth, 40, nil, nil, 0, 0, 0, 1 } }
STUB.gblog[3] = { { "withdraw", "Geheim", ore, 1, nil, nil, 0, 0, 0, 1 } }
STUB.gbmoney = { { "deposit", "Fraktur", 1234567, 0, 0, 0, 4 }, { "repair", "Chorf", 50000, 0, 0, 2, 0 } }
openBank()
local q = table.concat(STUB.logQueries, ",")
assert(q == "1,2,9", "the visible tabs and the money log (MAX_GUILDBANK_TABS + 1), never the hidden tab: " .. q)
local log = NS.BankLog()
assert(#log.list == 6, "four item entries and two of money: " .. #log.list)
assert(log.tabs[1] == "Mats" and log.tabs[2] == "Rüstung", "tab names are kept")
assert(log.at and log.at > 0 and log.by == "Vuloo", "when and by whom it was read")
local byName = {}
for _, e in ipairs(log.list) do byName[e.n .. ":" .. e.y] = e end
local mv = byName["Vuloo:move"]
assert(mv and mv.i == 61001 and mv.c == 3 and mv.a == 1 and mv.b == 2 and mv.k == 1, "a move keeps both tabs")
local money = byName["Fraktur:deposit"]
assert(byName["Chorf:repair"].k == 0 and byName["Chorf:repair"].c == 50000, "money entries live on tab 0")
assert(has(table.concat(STUB.messages, "\n"), "Gildenbank-Protokoll: 6 neue Einträge"), table.concat(STUB.messages, "\n"))
assert(money)

-- open again half an hour later: the log has moved on by an hour for some, one entry is new
STUB.now = STUB.now + 1800
STUB.gblog[1][1][10] = 3
STUB.gblog[1][2][10] = 4
STUB.gblog[1][3][10] = 1
STUB.gblog[1][4] = { "deposit", "Kimtaro", ore, 7, nil, nil, 0, 0, 0, 0 }
STUB.gbmoney[1][7] = 5
openBank()
assert(#NS.BankLog().list == 7, "only the new deposit is added: " .. #NS.BankLog().list)

-- off: nothing is read
NS.Set("bank.log", false)
openBank()
assert(#STUB.logQueries == 0, "switched off, no query")
NS.Reset("bank.log")

---------------------------------------------------------------------------
-- the page's filters: tab, kind, name or item
---------------------------------------------------------------------------
local all = NS.BankLogEntries({})
assert(#all == 7 and all[1].hi >= all[#all].hi, "newest first")
assert(#NS.BankLogEntries({ tab = 2 }) == 1 and #NS.BankLogEntries({ tab = 0 }) == 2, "by tab, 0 the money log")
assert(#NS.BankLogEntries({ kind = "withdraw" }) == 1 and #NS.BankLogEntries({ kind = "deposit" }) == 3, "by kind (items)")
assert(#NS.BankLogEntries({ kind = "money" }) == 2, "the money kinds together")
assert(#NS.BankLogEntries({ q = "fraktur" }) == 2, "by name")
assert(#NS.BankLogEntries({ q = "runenst" }) == 2, "by item name")
assert(#NS.BankLogEntries({ tab = 1, kind = "deposit", q = "kim" }) == 1)
local text = NS.BankLogText(NS.BankLogEntries({ q = "Anna" })[1])
assert(has(text, "Anna Bergmann") and has(text, "Runenstoff") and has(text, "40"), text)
assert(has(NS.BankLogText(byName["Chorf:repair"]), "5g"), NS.BankLogText(byName["Chorf:repair"]))

---------------------------------------------------------------------------
-- export: the entries not exported yet, once
---------------------------------------------------------------------------
local ex = NS.ExportText({})
local n = 0
for line in ex:gmatch("[^\n]+") do if line:match("^BT ") then n = n + 1 end end
assert(n == 7, "every entry once: " .. n .. "\n" .. ex)
assert(has(ex, "\nBT ") and has(ex, " 1 move 61001 3 1 2 Vuloo\n"), ex)
assert(has(ex, " 2 deposit 61002 40 0 0 Anna_Bergmann\n"), "the name with _ for the space: " .. ex)
assert(has(ex, " 0 repair 0 50000 0 0 Chorf\n"), ex)
assert(has(ex, "\nN 61001 3 Feuerkern\n") and has(ex, "\nN 61002 1 Runenstoff\n"), "the items are named: " .. ex)
assert(NS.BankPending(), "new log entries wait for the export")
NS.MarkExported({})
assert(not NS.BankPending(), "exported")
assert(not has(NS.ExportText({}), "\nBT "), "exported entries do not come again")
STUB.now = STUB.now + 60
STUB.gblog[2][2] = { "withdraw", "Chorf", cloth, 2, nil, nil, 0, 0, 0, 0 }
openBank()
ex = NS.ExportText({})
assert(has(ex, " 2 withdraw 61002 2 0 0 Chorf\n") and not has(ex, "Anna_Bergmann"), "only the new one: " .. ex)

---------------------------------------------------------------------------
-- pruning: by age and by size, on load too
---------------------------------------------------------------------------
NS.Set("bank.logDays", 30)
local old = { k = 1, y = "deposit", n = "Alt", i = 61001, c = 1, lo = STUB.now - 40 * 86400, hi = STUB.now - 40 * 86400 + 3600, s = STUB.now - 40 * 86400 }
table.insert(AmisiaDB.bankLog.list, old)
-- broken entries fall away on load
table.insert(AmisiaDB.bankLog.list, { k = "x" })
table.insert(AmisiaDB.bankLog.list, "kaputt")
NS.BankLogLoaded(AmisiaDB)
for _, e in ipairs(NS.BankLog().list) do assert(e.n ~= "Alt", "older than 30 days is gone") end
assert(#NS.BankLog().list == 8, #NS.BankLog().list)
local many = {}
for i = 1, 1100 do many[i] = row("Masse" .. i, 61001, 1, 0) end
NS.MergeBankLog(many, STUB.now)
assert(#NS.BankLog().list == 1000, "capped: " .. #NS.BankLog().list)
NS.Reset("bank.logDays")

---------------------------------------------------------------------------
-- names the client does not have yet: the tab is asked once more, rows still without a name wait
---------------------------------------------------------------------------
AmisiaDB.bankLog = nil
NS.BankLogLoaded(AmisiaDB)
STUB.gbTabs = { { "Mats", true } }
STUB.gblog = { {
    { "deposit", nil, ore, 20, nil, nil, 0, 0, 0, 2 },
    { "deposit", "Fraktur", cloth, 3, nil, nil, 0, 0, 0, 4 },
} }
-- the client's word for a name it does not know (GlobalStrings) counts as none
UNKNOWNOBJECT = UNKNOWNOBJECT or "Unbekannt"
STUB.gbmoney = { { "deposit", "", 50000, 0, 0, 1, 15 }, { "deposit", UNKNOWNOBJECT, 2, 0, 0, 10, 0 } }
local function step(s) STUB.tick(s) end
STUB.logQueries = {}
STUB.fire("GUILDBANKFRAME_OPENED")
step(0.6)
assert(table.concat(STUB.logQueries, ",") == "1", table.concat(STUB.logQueries, ","))
STUB.fire("GUILDBANKLOG_UPDATE")
step(0.2)
assert(#NS.BankLog().list == 0, "a tab with a nameless row waits for a second query")
-- the client's answers to the first query still coming in change nothing while it waits
STUB.fire("GUILDBANKLOG_UPDATE")
step(0.3)
assert(#NS.BankLog().list == 0 and #STUB.logQueries == 1)
-- the names arrive; the tab is asked once more
STUB.gblog[1][1][2] = "Abunazir Jr"
step(1.3)
assert(table.concat(STUB.logQueries, ",") == "1,1", "asked once more: " .. table.concat(STUB.logQueries, ","))
STUB.fire("GUILDBANKLOG_UPDATE")
step(0.2)
assert(#NS.BankLog().list == 2, "both item rows, with names: " .. #NS.BankLog().list)
-- the money log: its names stay missing after the second query, those rows are kept as "?" (as the game shows
-- UNKNOWN for them: a deleted character)
assert(table.concat(STUB.logQueries, ",") == "1,1,9", table.concat(STUB.logQueries, ","))
STUB.fire("GUILDBANKLOG_UPDATE")
step(0.2)
step(1.5)
assert(table.concat(STUB.logQueries, ",") == "1,1,9,9", "the money log once more: " .. table.concat(STUB.logQueries, ","))
STUB.fire("GUILDBANKLOG_UPDATE")
step(0.2)
step(5)
STUB.fire("GUILDBANKFRAME_CLOSED")
assert(#STUB.logQueries == 4, "once more only, never a third time: " .. #STUB.logQueries)
local unnamed = 0
for _, e in ipairs(NS.BankLog().list) do
    assert(e.n ~= UNKNOWNOBJECT and e.n ~= "", "the client's word is no name: " .. e.n)
    if e.n == "?" then unnamed = unnamed + 1; assert(e.k == 0, "only the money rows") end
end
assert(#NS.BankLog().list == 4 and unnamed == 2, "after the second query, the nameless rows as \"?\": " .. #NS.BankLog().list)
-- the next visit (an hour later) has the names: the "?" entries take them; nothing doubled
STUB.now = STUB.now + 3600
STUB.gblog[1][1][10], STUB.gblog[1][2][10] = 3, 5
STUB.gbmoney = { { "deposit", "Abunazir Jr", 50000, 0, 0, 1, 16 }, { "deposit", "Fraktur Winterkirsch", 2, 0, 0, 10, 1 } }
openBank()
assert(#NS.BankLog().list == 4, "still four entries: " .. #NS.BankLog().list)
local money2 = {}
for _, e in ipairs(NS.BankLog().list) do if e.k == 0 then money2[#money2 + 1] = e.n end end
table.sort(money2)
assert(table.concat(money2, ",") == "Abunazir Jr,Fraktur Winterkirsch", "renamed: " .. table.concat(money2, ","))
-- and a visit where the name is missing again even after the second query: the "?" row is the named entry
STUB.now = STUB.now + 60
STUB.gbmoney[1][2] = nil
openBank()
assert(table.concat(STUB.logQueries, ",") == "1,9,9", "the money log asked twice: " .. table.concat(STUB.logQueries, ","))
assert(#NS.BankLog().list == 4, "a \"?\" row matches the named entry: " .. #NS.BankLog().list)
for _, e in ipairs(NS.BankLog().list) do assert(e.n ~= "?", "the named entry keeps its name") end
-- the bank closed while a tab waits for its second query: the named rows are kept, the nameless left out (the
-- names were loading), no second query
AmisiaDB.bankLog = nil
NS.BankLogLoaded(AmisiaDB)
STUB.gblog = { { { "deposit", nil, ore, 1, nil, nil, 0, 0, 0, 0 }, { "deposit", "Kimtaro", ore, 2, nil, nil, 0, 0, 0, 0 } } }
STUB.gbmoney = {}
STUB.logQueries = {}
STUB.fire("GUILDBANKFRAME_OPENED")
step(0.6)
STUB.fire("GUILDBANKLOG_UPDATE")
step(0.2)
STUB.fire("GUILDBANKFRAME_CLOSED")
step(5)
assert(#STUB.logQueries == 1 and #NS.BankLog().list == 1 and NS.BankLog().list[1].n == "Kimtaro",
    "closed while waiting: the named row kept, no second query: " .. #STUB.logQueries .. " " .. #NS.BankLog().list)

---------------------------------------------------------------------------
-- "?" entries of older versions: a named read gives them the name; on load their named twins replace them
---------------------------------------------------------------------------
AmisiaDB.bankLog = nil
NS.BankLogLoaded(AmisiaDB)
local R = math.floor(STUB.now)
table.insert(NS.BankLog().list, { k = 0, y = "deposit", n = "?", i = 0, c = 50000, lo = R - 40 * 3600, hi = R - 39 * 3600, s = R - 86400 })
assert(NS.MergeBankLog({ { k = 0, y = "deposit", n = "Abunazir Jr", i = 0, c = 50000, ago = 39 } }, R + 1800) == 0,
    "a named read matches the \"?\" entry")
local only = NS.BankLog().list
assert(#only == 1 and only[1].n == "Abunazir Jr", "it takes the name: " .. only[1].n)
assert(only[1].lo == R + 1800 - 40 * 3600 and only[1].hi == R - 39 * 3600, ("and the window narrows to the overlap: %d %d"):format(only[1].lo - R, only[1].hi - R))
-- a named entry of the same name still comes first; a second "?" row stays matched one to one
table.insert(NS.BankLog().list, { k = 0, y = "deposit", n = "?", i = 0, c = 50000, lo = R - 40 * 3600, hi = R - 39 * 3600, s = R })
assert(NS.MergeBankLog({ { k = 0, y = "deposit", n = "Abunazir Jr", i = 0, c = 50000, ago = 39 },
                         { k = 0, y = "deposit", n = "Chorf", i = 0, c = 50000, ago = 39 } }, R) == 0, "two rows, two entries")
local names = {}
for _, e in ipairs(NS.BankLog().list) do names[#names + 1] = e.n end
table.sort(names)
assert(table.concat(names, ",") == "Abunazir Jr,Chorf", table.concat(names, ","))

-- the screenshot of 2026-11-27 (read at 13:28): the money log with seven entries, Amisia had nine
AmisiaDB.bankLog = nil
NS.BankLogLoaded(AmisiaDB)
local H = 3600
local function ent(n, c, hi, w, y) return { k = 0, y = y or "deposit", n = n, i = 0, c = c, lo = hi - (w or H), hi = hi, s = R } end
local saved = {
    ent("Vuloo", 30000, R - 14 * H - 46 * 60),        -- "vor 14 Stunden": 26.11. 22:42
    ent("Abunazir Jr", 50000, R - 39 * H),             -- "vor 1 Tag": 25.11. 22:28
    ent("?", 50000, R - 38 * H - 60),                  -- its twin from the nameless read: 25.11. 23:27
    ent("Chorf", 50000, R - 41 * H - 46 * 60),         -- "vor 1 Tag": 25.11. 19:42
    ent("Anna", 7, R - 145 * H - 46 * 60),             -- "vor 6 Tagen": 21.11. 11:42
    ent("Anna", 8, R - 161 * H - 1 * 60),              -- 20.11. 20:27
    ent("Kimtaro", 9, R - 205 * H - 9 * 60),           -- "vor 8 Tagen": 19.11. 00:19
    ent("Fraktur Winterkirsch", 2, R - 258 * H - 9 * 60), -- "vor 10 Tagen": 16.11. 19:19
    ent("?", 2, R - 258 * H - 3 * 60),                 -- its twin: 16.11. 19:25
    -- a month old on both sides: the six-day windows overlap
    ent("Lia", 4, R - 40 * 24 * H, 6 * 24 * H + H, "repair"),
    ent("?", 4, R - 38 * 24 * H, 6 * 24 * H + H, "repair"),
    -- no named twin (another amount, or another tab): stays
    ent("?", 10000, R - 30 * H, H, "withdraw"),
    { k = 1, y = "deposit", n = "?", i = 61001, c = 2, lo = R - 260 * H, hi = R - 258 * H, s = R },
    -- two "?" of one amount and one named entry: one goes, one stays (one to one)
    ent("Vuloo", 77, R - 50 * H),
    ent("?", 77, R - 50 * H + 600),
    ent("?", 77, R - 50 * H + 1200),
}
AmisiaDB.bankLog = { list = saved, tabs = {} }
NS.BankLogLoaded(AmisiaDB)
local left = {}
for _, e in ipairs(NS.BankLog().list) do left[#left + 1] = e.n .. ":" .. e.c end
table.sort(left)
assert(#NS.BankLog().list == 12, "the twins are gone: " .. table.concat(left, ","))
local q2 = 0
for _, e in ipairs(NS.BankLog().list) do
    if e.n == "?" then q2 = q2 + 1; assert(e.c == 10000 or e.c == 2 or e.c == 77, "kept: " .. e.c) end
    if e.n == "Abunazir Jr" then assert(e.hi == R - 39 * H and e.lo == R - 39 * H - 60, "the overlap: " .. (e.hi - e.lo)) end
end
assert(q2 == 3, "the \"?\" without a named twin stay: " .. q2)
-- once per saved log: Vuloo's 77 took one twin, the next load does not take the other
assert(AmisiaDB.bankLog.named == true)
NS.BankLogLoaded(AmisiaDB)
assert(#NS.BankLog().list == 12, "loading again changes nothing: " .. #NS.BankLog().list)
