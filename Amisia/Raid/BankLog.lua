-- Amisia guild bank log: when the guild bank opens, the transaction log of every tab the character
-- may view and the money log are read one after another (QueryGuildBankLog, then
-- GUILDBANKLOG_UPDATE or a short wait) and merged into AmisiaDB.bankLog; the Bank page shows it with
-- filters, the export carries the new entries as BT lines.
--
-- The client gives every entry's time only relative to now: years, months, days and hours ago (the
-- money log the same). An entry read at time R with h hours ago lies in (R - (h+1) h, R - h h];
-- months count as 30 days and years as 365, and an entry older than a month gets three days of
-- slack either way. Each saved entry keeps that window as lo..hi.
--
-- The dedupe rule: an entry of a new read is one already saved when tab, kind, name, item, count
-- (copper for money) and the tabs of a move are the same and the time windows overlap (a minute of
-- slack for the clock). Matching is one to one within a read: two equal deposits in the same hour
-- stay two entries, because both are in every read. A match narrows the saved window to the
-- overlap. Limits: an entry that left the client's short log (the server keeps the newest few per
-- tab) while an identical one came in within the same hour is taken for the old one; a changed
-- character name counts as another name; month-old entries read for the first time match with
-- three days of slack.
--
-- Names: on an early read the client may not have the players' names yet (nil or "", the name its
-- own log shows as UNKNOWN; a deleted character's entries come the same way, the game cannot tell
-- them apart). A tab with such a row is left out at first and asked once more after a short wait
-- (RETRY); rows still without a name after that second query are saved as "?" (the game shows
-- UNKNOWN for them too). When the bank closes before the second query, they are left out (the names
-- were most likely still loading). A "?" entry and a named one of the same tab, kind, item, count and
-- move tabs match regardless of the name, both ways (a named row gives a saved "?" its name; a "?"
-- row matches a saved named entry), so a later read with the name brings no twin. On load a "?"
-- entry with such a named twin is dropped (the twins older versions saved; one to one, the slack of a
-- guild read; once per saved log, bankLog.named); a "?" without one stays. "?" entries never go to
-- the guild (BankShare.lua).
--
-- Kept: entries younger than bank.logDays (90 by default), at most 1000 (the oldest go first).
local ADDON, ns = ...
ns.Load(function()
local L = ns.L

local CAP = 1000
local HOUR, DAY = 3600, 86400
local SLACK = 60              -- seconds of clock slack when two windows are compared
local FUZZ = 3 * DAY          -- either way, for entries older than a month
local WAIT = 3                -- seconds a tab's log may take to answer
local RETRY = 1.5             -- seconds before a tab with rows lacking a name is asked once more
local NONAME = "?"            -- the name older versions saved for a row the client gave without one
local TWIN_SLACK = 120        -- seconds two windows may miss each other when a "?" entry meets its named twin
local MONEY = 0               -- the money log's tab in the saved entries

local DB
-- { queue = { tabs }, cur, readAt, added, new = { the new entries }, retried = { [tab] = true } (to be asked once
-- more for rows without a name), pause (the tab waiting for that second query), again = { [tab] = true } (the
-- second query went: rows still without a name are kept as "?") }
local reading
local openNow = false
local token = 0

local function msg(text) if ns.msg then ns.msg(text) end end
local function now() return math.floor(time()) end
local function api(name) return type(_G[name]) == "function" and _G[name] or nil end
local function moneyTab() return (tonumber(_G.MAX_GUILDBANK_TABS) or 8) + 1 end

local function log()
    if not DB then return { list = {}, tabs = {} } end
    return DB.bankLog
end

-- { list = { entry }, tabs = { [tab] = name }, at = last read, by = who read, got = { by, at } the last
-- entries heard from the guild (BankShare.lua), named = true once the "?" twins of older versions are
-- dropped }. An entry: { k = tab (0 money), y = kind, n = name,
-- i = itemID (0 money), c = count or copper, a, b = the tabs of a move, lo, hi = the time window,
-- s = when it was first saved, r = who reported it when it came from the guild (nil: an own read) }.
function ns.BankLog() return log() end

-- The fields an entry is matched by; loose: without the name (a "?" entry meets its named twin).
local function sig(e, loose)
    return table.concat({ e.k, e.y, loose and "" or (e.n or NONAME):lower(), e.i or 0, e.c or 0, e.a or 0, e.b or 0 }, "\a")
end

local function valid(e)
    return type(e) == "table" and type(e.k) == "number" and type(e.y) == "string" and e.y ~= "" and type(e.n) == "string"
        and type(e.i) == "number" and type(e.c) == "number" and type(e.lo) == "number" and type(e.hi) == "number" and e.lo <= e.hi
end

-- The oldest end of a window kept (bank.logDays).
local function keepFrom() return now() - (tonumber(ns.Get("bank.logDays")) or 90) * DAY end

-- What this client keeps (BankShare.lua asks only for that): the oldest end of a window kept (own clock)
-- and the most entries kept.
ns.BANK_LOG_CAP = CAP
function ns.BankLogKeepFrom() return keepFrom() end

-- By age (bank.logDays) and size (the newest 1000).
local function prune()
    if not DB then return end
    local limit = keepFrom()
    local keep = {}
    for _, e in ipairs(DB.bankLog.list) do
        if valid(e) and e.hi >= limit then
            e.s = tonumber(e.s) or e.hi
            keep[#keep + 1] = e
        end
    end
    if #keep > CAP then
        table.sort(keep, function(a, b) return a.hi > b.hi end)
        for i = #keep, CAP + 1, -1 do keep[i] = nil end
    end
    DB.bankLog.list = keep
end

-- A "?" entry (saved by an older version from a row read before the client had the name) whose named
-- twin is saved too: the same tab, kind, item, count and move tabs, the windows overlapping (TWIN_SLACK).
-- One "?" per named entry; the named one keeps the overlap. A "?" without a twin stays. Run once per saved
-- log (bankLog.named).
local function dropNamelessTwins()
    local named, loose = {}, false
    for _, e in ipairs(DB.bankLog.list) do
        if e.n == NONAME then
            loose = true
        else
            local k = sig(e, true)
            named[k] = named[k] or {}
            table.insert(named[k], e)
        end
    end
    if not loose then return end
    local used, keep = {}, {}
    for _, e in ipairs(DB.bankLog.list) do
        local twin
        if e.n == NONAME then
            local bestOver
            for _, o in ipairs(named[sig(e, true)] or {}) do
                if not used[o] then
                    local over = math.min(o.hi, e.hi) - math.max(o.lo, e.lo)
                    if over >= -TWIN_SLACK and (not twin or over > bestOver) then twin, bestOver = o, over end
                end
            end
        end
        if twin then
            used[twin] = true
            local nlo, nhi = math.max(twin.lo, e.lo), math.min(twin.hi, e.hi)
            if nlo <= nhi then twin.lo, twin.hi = nlo, nhi end
        else
            keep[#keep + 1] = e
        end
    end
    DB.bankLog.list = keep
end

function ns.BankLogLoaded(root)
    DB = root
    local b = type(root.bankLog) == "table" and root.bankLog or {}
    local got = type(b.got) == "table" and type(b.got.by) == "string" and tonumber(b.got.at)
        and { by = b.got.by, at = tonumber(b.got.at) } or nil
    root.bankLog = { list = type(b.list) == "table" and b.list or {}, tabs = type(b.tabs) == "table" and b.tabs or {},
                     at = tonumber(b.at), by = type(b.by) == "string" and b.by or nil, got = got,
                     named = b.named == true or nil }
    prune()
    -- once: since this version a "?" entry and its named twin match in the merge (no new twins), and a named
    -- entry that took one twin must not take another on the next load
    if not root.bankLog.named then
        dropNamelessTwins()
        root.bankLog.named = true
    end
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name == ns.ADDON and AmisiaDB then ns.BankLogLoaded(AmisiaDB) end
end)

-- One read into the saved log: rows with their time windows lo..hi (local clock). Matching is one to
-- one within the read (two equal entries of the read stay two); a match narrows the saved window to
-- the overlap; slack: seconds two windows may miss each other (SLACK for the own reads). by: who
-- reported the read (nil for an own read, a name for one heard from the guild, BankShare.lua), kept
-- on the new entries as r. Returns the new entries that are still kept after prune() (bank.logDays and
-- the cap of 1000): an entry pruned at once is no new entry (BankShare.lua's rounds stop on none).
local function mergeWindows(rows, at, slack, by)
    -- bySig: the saved entries by their fields; nameless: the "?" entries by their fields without the name;
    -- loose: all entries by their fields without the name (for a "?" row)
    local bySig, nameless, loose = {}, {}, {}
    for _, e in ipairs(DB.bankLog.list) do
        local k = sig(e)
        bySig[k] = bySig[k] or {}
        table.insert(bySig[k], e)
        k = sig(e, true)
        loose[k] = loose[k] or {}
        table.insert(loose[k], e)
        if e.n == NONAME then
            nameless[k] = nameless[k] or {}
            table.insert(nameless[k], e)
        end
    end
    local function closest(list, lo, hi, used)
        local best, bestOver
        for _, old in ipairs(list or {}) do
            if not used[old] then
                local over = math.min(old.hi, hi) - math.max(old.lo, lo)
                if over >= -slack and (not best or over > bestOver) then best, bestOver = old, over end
            end
        end
        return best
    end
    local used, added, limit = {}, {}, keepFrom()
    for _, r in ipairs(rows) do
        local lo, hi = r.lo, r.hi
        -- older than bank.logDays: prune would drop it at once (and it would count as new every time)
        if hi >= limit then
            local e = { k = r.k, y = r.y, n = r.n, i = r.i or 0, c = r.c or 0, a = r.a, b = r.b }
            local best = closest(bySig[sig(e)], lo, hi, used)
            if not best and e.n ~= NONAME then
                -- a saved "?" entry: the named row gives it its name
                best = closest(nameless[sig(e, true)], lo, hi, used)
                if best then best.n = e.n end
            elseif not best then
                -- a "?" row (no name even after the second query): a saved named entry is the same one
                best = closest(loose[sig(e, true)], lo, hi, used)
            end
            if best then
                used[best] = true
                local nlo, nhi = math.max(best.lo, lo), math.min(best.hi, hi)
                if nlo <= nhi then best.lo, best.hi = nlo, nhi end
            else
                e.lo, e.hi, e.s, e.r = lo, hi, at, by
                DB.bankLog.list[#DB.bankLog.list + 1] = e
                used[e] = true
                added[#added + 1] = e
            end
        end
    end
    if #added > 0 then
        prune()
        local kept, out = {}, {}
        for _, e in ipairs(DB.bankLog.list) do kept[e] = true end
        for _, e in ipairs(added) do if kept[e] then out[#out + 1] = e end end
        added = out
    end
    return added
end

-- The rows of one read made at readAt (k, y, n, i, c, a, b, ago = hours ago, fuzzy = older than a
-- month) as windows.
local function windows(rows, readAt)
    local out = {}
    for _, r in ipairs(rows) do
        local ago = math.max(0, tonumber(r.ago) or 0)
        local hi = readAt - ago * HOUR
        local lo = hi - HOUR
        if r.fuzzy then lo, hi = lo - FUZZ, math.min(readAt, hi + FUZZ) end
        out[#out + 1] = { k = r.k, y = r.y, n = r.n, i = r.i, c = r.c, a = r.a, b = r.b, lo = lo, hi = hi }
    end
    return out
end

-- Merges the rows of one read made at readAt: { k, y, n, i, c, a, b, ago = hours ago, fuzzy = older
-- than a month }. Returns how many entries are new (and the new entries).
function ns.MergeBankLog(rows, readAt)
    if not DB then return 0, {} end
    readAt = math.floor(tonumber(readAt) or now())
    local added = mergeWindows(windows(rows, readAt), readAt, SLACK)
    return #added, added
end

-- Merges the entries of a read another client reported (BankShare.lua): rows with lo..hi on the own
-- clock, checked by the caller; slack in seconds; by the reporting name. Returns the new entries.
function ns.MergeBankLogRead(rows, slack, by)
    if not DB then return {} end
    return mergeWindows(rows, now(), tonumber(slack) or SLACK, by)
end

---------------------------------------------------------------------------
-- Reading the client's logs
---------------------------------------------------------------------------
local function plain(v) return ns.Plain and ns.Plain(v) or v end
-- At most max bytes of s, never inside a character of several bytes (UTF-8): a lead byte whose
-- character the cut would split goes with its continuation bytes.
local function cutUtf8(s, max)
    if #s <= max then return s end
    s = s:sub(1, max)
    local i = #s
    while i > 0 and s:byte(i) >= 0x80 and s:byte(i) < 0xC0 do i = i - 1 end
    if i > 0 and s:byte(i) >= 0xC0 then
        local lead = s:byte(i)
        local need = lead >= 0xF0 and 4 or lead >= 0xE0 and 3 or 2
        if #s - i + 1 < need then s = s:sub(1, i - 1) end
    end
    return s
end

-- A name as the client gives it, or nil when it gives none yet (nil, "", secret, its UNKNOWNOBJECT or
-- UNKNOWN: the names arrive a moment after the log; a deleted character's entries look the same).
local function cleanName(n)
    n = plain(n)
    if type(n) ~= "string" then return nil end
    n = cutUtf8((n:gsub("[%c|]", "")), 48)
    if n == "" or n == NONAME or n == _G.UNKNOWNOBJECT or n == _G.UNKNOWN then return nil end
    return n
end
local function cleanKind(y)
    y = plain(y)
    if type(y) ~= "string" or not y:match("^%a+$") or #y > 20 then return nil end
    return y
end

local function agoHours(y, m, d, h)
    y, m, d, h = tonumber(plain(y)) or 0, tonumber(plain(m)) or 0, tonumber(plain(d)) or 0, tonumber(plain(h)) or 0
    return ((y * 365 + m * 30 + d) * 24 + h), (y > 0 or m > 0)
end

-- The rows of one tab's log (or the money log) as the client has them now, and how many rows came
-- without a name: left out, or kept as "?" with keepNameless (after the second query).
local function readTab(tab, keepNameless)
    local rows, nameless = {}, 0
    if tab == moneyTab() then
        local num, get = api("GetNumGuildBankMoneyTransactions"), api("GetGuildBankMoneyTransaction")
        if not num or not get then return rows, 0 end
        local ok, n = pcall(num)
        n = ok and tonumber(plain(n)) or 0
        for i = 1, math.min(n, 100) do
            local okRow, kind, name, amount, y, m, d, h = pcall(get, i)
            kind = okRow and cleanKind(kind)
            name = kind and (cleanName(name) or (keepNameless and NONAME))
            if kind and name == NONAME then nameless = nameless + 1 end
            if kind and not name then
                nameless = nameless + 1
            elseif kind then
                local ago, fuzzy = agoHours(y, m, d, h)
                rows[#rows + 1] = { k = MONEY, y = kind, n = name, i = 0, c = math.max(0, math.floor(tonumber(plain(amount)) or 0)),
                                    ago = ago, fuzzy = fuzzy }
            end
        end
        return rows, nameless
    end
    local num, get = api("GetNumGuildBankTransactions"), api("GetGuildBankTransaction")
    if not num or not get then return rows, 0 end
    local ok, n = pcall(num, tab)
    n = ok and tonumber(plain(n)) or 0
    for i = 1, math.min(n, 100) do
        local okRow, kind, name, link, cnt, t1, t2, y, m, d, h = pcall(get, tab, i)
        kind = okRow and cleanKind(kind)
        link = plain(link)
        local id = type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
        name = kind and id and (cleanName(name) or (keepNameless and NONAME))
        if kind and id and name == NONAME then nameless = nameless + 1 end
        if kind and id and not name then
            nameless = nameless + 1
        elseif kind and id then
            if ns.RememberItem then ns.RememberItem(id, link, ns.LinkQuality and ns.LinkQuality(link)) end
            local ago, fuzzy = agoHours(y, m, d, h)
            local e = { k = tab, y = kind, n = name, i = id, c = math.max(1, math.floor(tonumber(plain(cnt)) or 1)),
                        ago = ago, fuzzy = fuzzy }
            if kind == "move" then e.a, e.b = tonumber(plain(t1)), tonumber(plain(t2)) end
            rows[#rows + 1] = e
        end
    end
    return rows, nameless
end

local function finish()
    local r = reading
    reading = nil
    if not r or not DB then return end
    DB.bankLog.at, DB.bankLog.by = r.readAt, ns.UnitFullName("player") or "?"
    if r.added > 0 then
        msg(L["Gildenbank-Protokoll: %d neue Einträge (%d gespeichert)."]:format(r.added, #DB.bankLog.list))
        -- the new entries of this read go to the guild (BankShare.lua: officers, bank.share), only those still kept
        -- (a later tab's merge may have pruned an earlier tab's new entry: the cap of 1000)
        local kept, new = {}, {}
        for _, e in ipairs(DB.bankLog.list) do kept[e] = true end
        for _, e in ipairs(r.new) do if kept[e] then new[#new + 1] = e end end
        if ns.BankShareRead then ns.BankShareRead(new) end
    end
    if ns.Refresh then ns.Refresh() end
end

local nextTab, query

-- The current tab answered (or the wait is over): read it, then ask for the next one. Rows without a
-- name: the tab is asked once more after RETRY (the bank still open); after that second query they are
-- kept as "?"; when the bank closed before it, they are left out.
local function readCurrent()
    local r = reading
    if not r or not r.cur or r.pause then return end
    local ok, rows, nameless = pcall(readTab, r.cur, r.again[r.cur])
    if ok and nameless and nameless > 0 and openNow and not r.retried[r.cur] then
        local tab = r.cur
        r.retried[tab], r.pause = true, tab
        token = token + 1
        local mine = token
        C_Timer.After(RETRY, function()
            if reading == r and r.cur == tab and r.pause == tab and token == mine then
                r.pause, r.again[tab] = nil, true
                query(r, tab)
            end
        end)
        return
    end
    if ok then
        local n, new = ns.MergeBankLog(rows, now())
        r.added = r.added + n
        for _, e in ipairs(new) do r.new[#r.new + 1] = e end
    else
        ns.ReportError(rows)
    end
    r.cur = nil
    nextTab()
end

-- Asks for one tab's log; its answer (GUILDBANKLOG_UPDATE) or the end of WAIT reads it.
query = function(r, tab)
    token = token + 1
    local mine = token
    pcall(QueryGuildBankLog, tab)
    C_Timer.After(WAIT, function()
        if reading == r and r.cur == tab and token == mine then readCurrent() end
    end)
end

nextTab = function()
    local r = reading
    if not r then return end
    if not openNow then return finish() end
    local tab = table.remove(r.queue, 1)
    if not tab then return finish() end
    r.cur = tab
    query(r, tab)
end

local function start()
    if reading or not openNow or not DB or not ns.Get("bank.log") then return end
    if not (api("QueryGuildBankLog") and api("GetNumGuildBankTabs") and api("GetGuildBankTabInfo")) then return end
    local okN, tabs = pcall(GetNumGuildBankTabs)
    tabs = okN and tonumber(plain(tabs)) or 0
    local queue = {}
    for tab = 1, tabs do
        local ok, name, _, viewable = pcall(GetGuildBankTabInfo, tab)
        if ok and plain(viewable) then
            queue[#queue + 1] = tab
            name = plain(name)
            if type(name) == "string" and name ~= "" then DB.bankLog.tabs[tab] = cleanName(name) end
        end
    end
    -- the money log needs no tab of its own
    queue[#queue + 1] = moneyTab()
    reading = { queue = queue, readAt = now(), added = 0, new = {}, retried = {}, again = {} }
    nextTab()
end

local function opened()
    if openNow then return end
    openNow = true
    -- the tab list arrives with the bank; a moment later it is there
    C_Timer.After(0.5, start)
end

local function closed()
    openNow = false
    if reading then
        -- what came in so far is kept; the rest waits for the next visit
        reading.queue = {}
        reading.pause = nil
        if reading.cur then readCurrent() else finish() end
    end
end

ns.OnEvent("GUILDBANKFRAME_OPENED", opened)
ns.OnEvent("GUILDBANKFRAME_CLOSED", closed)
ns.OnEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(kind)
    if Enum and Enum.PlayerInteractionType and kind == Enum.PlayerInteractionType.GuildBanker then opened() end
end)
ns.OnEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(kind)
    if Enum and Enum.PlayerInteractionType and kind == Enum.PlayerInteractionType.GuildBanker then closed() end
end)
ns.OnEvent("PLAYER_ENTERING_WORLD", function() if openNow then closed() end end)
ns.OnEvent("GUILDBANKLOG_UPDATE", function()
    if reading and reading.cur then
        -- the answer is here; read it in the next frame (several events may come at once)
        local r, tab = reading, reading.cur
        C_Timer.After(0.1, function()
            if reading == r and r.cur == tab then readCurrent() end
        end)
    end
end)

---------------------------------------------------------------------------
-- The page and the export
---------------------------------------------------------------------------
-- The saved entries, newest first. filter: tab (a number, 0 the money log), kind ("deposit",
-- "withdraw", "move" for items, "money" for the money log), q (part of a name or an item name).
function ns.BankLogEntries(filter)
    filter = filter or {}
    local q = type(filter.q) == "string" and filter.q:lower():match("^%s*(.-)%s*$") or ""
    local out = {}
    for _, e in ipairs(log().list) do
        local ok = filter.tab == nil or e.k == filter.tab
        if ok and filter.kind then
            if filter.kind == "money" then ok = e.k == MONEY
            else ok = e.k ~= MONEY and e.y == filter.kind end
        end
        if ok and q ~= "" then
            local hay = e.n:lower()
            if e.i and e.i > 0 then hay = hay .. "\a" .. ns.ItemName(e.i):lower() end
            ok = hay:find(q, 1, true) ~= nil
        end
        if ok then out[#out + 1] = e end
    end
    table.sort(out, function(a, b)
        if a.hi ~= b.hi then return a.hi > b.hi end
        return (a.s or 0) > (b.s or 0)
    end)
    return out
end

-- "12g 3s 4c" from copper.
function ns.FmtCopper(c)
    c = math.floor(tonumber(c) or 0)
    local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if s > 0 then parts[#parts + 1] = s .. "s" end
    if k > 0 or #parts == 0 then parts[#parts + 1] = k .. "c" end
    return table.concat(parts, " ")
end

function ns.BankTabName(tab)
    if tab == MONEY then return L["Gold"] end
    local n = log().tabs[tab]
    return n or L["Tab %d"]:format(tab or 0)
end

local KIND_TEXT = {
    deposit = L["legt ein"], withdraw = L["nimmt"], move = L["verschiebt"], repair = L["repariert für"],
    withdrawForTab = L["nimmt für ein Tab"], buyTab = L["kauft ein Tab für"], depositSummary = L["Gewinn aus Beute"],
    buyRename = L["benennt die Gilde um für"], refundRename = L["bekommt zurück"],
}
function ns.BankLogKindText(kind) return KIND_TEXT[kind] or kind end

-- One entry as a line: "Name legt ein: Item x20 (Tab)".
function ns.BankLogText(e)
    local what
    if e.k == MONEY then
        what = ns.FmtCopper(e.c)
    else
        what = ("%s x%d"):format(ns.ItemName(e.i), e.c)
        if e.y == "move" then
            what = what .. " (" .. ns.BankTabName(e.a) .. " > " .. ns.BankTabName(e.b) .. ")"
        end
    end
    return ("%s %s: %s"):format(e.n, ns.BankLogKindText(e.y), what)
end

-- The entries no export carried yet (x marks the exported ones), oldest first.
function ns.BankLogPending()
    local out = {}
    for _, e in ipairs(log().list) do
        if not e.x then out[#out + 1] = e end
    end
    table.sort(out, function(a, b)
        if a.hi ~= b.hi then return a.hi < b.hi end
        return sig(a) < sig(b)
    end)
    return out
end

function ns.MarkBankLogExported()
    for _, e in ipairs(log().list) do e.x = 1 end
end
end)
