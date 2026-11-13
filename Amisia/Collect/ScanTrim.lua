-- Amisia scan trim: AmisiaDB.scan (the item scan's lines, the collector's notes, the ids to ask again,
-- the quest and NPC scans by id: their lines per language and the ids without an answer, D-104)
-- exists only to reach the N100, where tools/build_scan_archive.py keeps all of it for good in
-- tools/scan_archive.json. The marker Data/ScanDone.lua (ns.Data("SCAN_DONE")) says what that archive
-- held when this version was built: per item id a hash of its line, per item the hashes of its notes,
-- and the ids the client's own item table knows. What it covers is taken out of the saved table, so
-- the file and the login keep only what is new since the build. Nothing the marker does not cover is
-- ever removed: a line that changed since (another hash) stays, and so do the scan's progress fields
-- (next, from, to, rate) and the random suffixes (Gear.lua reads those in game).
--
-- At login (tools.scanAutotrim, default on) the work starts a few seconds late and runs in small
-- steps on timers, so the login has no hitch; /amisia scan aufräumen does it at once.
local ADDON, ns = ...
local L = ns.L

local MOD = 1000000007   -- the hash of tools/build_scan_archive.py: h = (h * 31 + byte) % MOD
-- delay: seconds after the login; step: seconds between two steps; budget: work per step (one per
-- marker entry or id, one per 16 bytes hashed)
ns.SCAN_TRIM = { delay = 8, step = 0.02, budget = 3000 }

local byte = string.byte

local function hash(s)
    local h = 0
    for i = 1, #s do h = (h * 31 + byte(s, i)) % MOD end
    return h
end
ns.ScanTrimHash = hash

local running = false
local lastRun   -- the counts of this session's last finished run

local function sortedIDs(t)
    local ids = {}
    if type(t) ~= "table" then return ids end
    for k in pairs(t) do
        if type(k) == "number" then ids[#ids + 1] = k end
    end
    table.sort(ids)
    return ids
end

local count = ns.Count

-- The parts of the scans by id (Collect/ScanQuests.lua, ScanNpcs.lua) and their marker fields: lines per
-- language "<step>.<hash>" (QL, NL) and the ids without an answer as ranges (QE, NE).
local ID_PARTS = {
    { key = "quests", lines = "QL", empty = "QE", field = "none" },
    { key = "npcs", lines = "NL", empty = "NE", field = "empty" },
}

-- Removes from list (id -> line) every line whose hash the marker text "<step>.<hash>,..." lists for
-- its id. Returns the count and the bytes.
local function trimLines(list, text, spend)
    local ids = sortedIDs(list)
    local i, id, n, bytes = 1, 0, 0, 0
    if not ids[1] then return 0, 0 end
    for step, h in text:gmatch("(%w+)%.(%w+)") do
        id = id + (tonumber(step, 36) or 0)
        while ids[i] and ids[i] < id do i = i + 1 end
        if not ids[i] then break end
        if ids[i] == id then
            local line = list[id]
            if type(line) == "string" then
                spend(#line / 16)
                if hash(line) == tonumber(h, 36) then
                    list[id] = nil
                    n = n + 1
                    bytes = bytes + #line + 10
                end
            end
            i = i + 1
        end
        spend(1)
    end
    return n, bytes
end

-- The ranges text have without the ids of gone (both "a-b,c,..."): the rest and how many went.
function ns.ScanTrimRanges(have, gone)
    local SB = ns.ScanById
    local a, b = SB.ParseRanges(have), SB.ParseRanges(gone)
    local out, removed, j = {}, 0, 1
    for _, r in ipairs(a) do
        local from, to = r[1], r[2]
        while b[j] and b[j][2] < from do j = j + 1 end
        local k = j
        while from <= to do
            local g = b[k]
            if not g or g[1] > to then
                out[#out + 1] = { from, to }
                break
            end
            if g[1] > from then out[#out + 1] = { from, g[1] - 1 } end
            removed = removed + math.min(to, g[2]) - math.max(from, g[1]) + 1
            from = g[2] + 1
            k = k + 1
        end
    end
    return SB.RangesText(out), removed
end

-- The work, as a function that calls pause() whenever its budget for one step is used up. Returns
-- the counts: items, sources (items whose notes all went), notes, retry, bytes.
local function trim(m, s, pause)
    local res = { items = 0, sources = 0, notes = 0, retry = 0, bytes = 0, quests = 0, npcs = 0 }
    local budget = ns.SCAN_TRIM.budget
    local used = 0
    local function spend(n)
        used = used + n
        if used >= budget then used = 0; pause() end
    end

    -- the retry ids, unique and in order; drop[id] = true for the ones to let go
    local retry = {}
    do
        local seen = {}
        for _, id in ipairs(type(s.retry) == "table" and s.retry or {}) do
            if type(id) == "number" and not seen[id] then seen[id] = true; retry[#retry + 1] = id end
        end
        table.sort(retry)
    end
    local drop = {}

    -- item lines: removed where the hash matches; a retry id the archive holds a line of goes too
    local items = type(s.items) == "table" and s.items or {}
    local ids = sortedIDs(items)
    spend(#ids / 20)
    local i, r, id = 1, 1, 0
    if (ids[1] or retry[1]) and type(m.I) == "string" then
        for step, h in m.I:gmatch("(%w+)%.(%w+)") do
            id = id + (tonumber(step, 36) or 0)
            while ids[i] and ids[i] < id do i = i + 1 end
            while retry[r] and retry[r] < id do r = r + 1 end
            if ids[i] == id then
                local line = items[id]
                if type(line) == "string" then
                    spend(#line / 16)
                    if hash(line) == tonumber(h, 36) then
                        items[id] = nil
                        res.items = res.items + 1
                        res.bytes = res.bytes + #line + 10
                    end
                end
                i = i + 1
            end
            if retry[r] == id then drop[id] = true; r = r + 1 end
            if not ids[i] and not retry[r] then break end
            spend(1)
        end
    end

    -- collector notes: each note whose hash the marker lists for its item goes; an item without notes
    -- left goes as a whole
    local sources = type(s.sources) == "table" and s.sources or {}
    local sids = sortedIDs(sources)
    local j, sid = 1, 0
    if sids[1] and type(m.S) == "string" then
        for entry in m.S:gmatch("[^,]+") do
            local step, rest = entry:match("^(%w+)(.*)$")
            sid = sid + (tonumber(step or "", 36) or 0)
            while sids[j] and sids[j] < sid do j = j + 1 end
            if sids[j] == sid then
                local list = sources[sid]
                if type(list) == "table" then
                    local known = {}
                    for h in rest:gmatch("%.(%w+)") do known[tonumber(h, 36)] = true end
                    local keep = {}
                    for _, note in ipairs(list) do
                        if type(note) == "string" and known[hash(note)] then
                            res.notes = res.notes + 1
                            res.bytes = res.bytes + #note + 4
                        else
                            keep[#keep + 1] = note
                        end
                    end
                    if #keep == 0 then
                        sources[sid] = nil
                        res.sources = res.sources + 1
                    elseif #keep < #list then
                        sources[sid] = keep
                    end
                    spend(#list)
                end
                j = j + 1
            end
            if not sids[j] then break end
            spend(1)
        end
    end

    -- retry ids the client's own item table does not know (up to cmax; a higher id may be newer than
    -- the table and stays)
    local cmax = tonumber(m.cmax) or 0
    if retry[1] and cmax > 0 and type(m.C) == "string" and m.C ~= "" then
        local k, last = 1, 0
        for step, len in m.C:gmatch("(%w+)%.(%w+)") do
            local first = last + (tonumber(step, 36) or 0)
            last = first + (tonumber(len, 36) or 1) - 1
            while retry[k] and retry[k] < first do
                drop[retry[k]] = true
                k = k + 1
            end
            while retry[k] and retry[k] <= last do k = k + 1 end
            if not retry[k] then break end
            spend(1)
        end
        while retry[k] and retry[k] <= cmax do
            drop[retry[k]] = true
            k = k + 1
        end
    end
    if next(drop) then
        -- in one step: the list as it is now (a retry run may have taken it meanwhile)
        local keep = {}
        for _, rid in ipairs(type(s.retry) == "table" and s.retry or {}) do
            if drop[rid] then
                res.retry = res.retry + 1
                res.bytes = res.bytes + 8
            else
                keep[#keep + 1] = rid
            end
        end
        s.retry = keep
    end

    -- the scans by id (quests, NPCs; D-104): lines of the scan's language whose hash the marker lists,
    -- and the ids without an answer the archive holds too
    for _, part in ipairs(ID_PARTS) do
        local p = type(s[part.key]) == "table" and s[part.key] or nil
        local loc = p and p.loc
        if p and type(loc) == "string" then
            local lines = type(m[part.lines]) == "table" and m[part.lines][loc]
            if type(p.list) == "table" and type(lines) == "string" and lines ~= "" then
                local n, bytes = trimLines(p.list, lines, spend)
                res[part.key] = res[part.key] + n
                res.bytes = res.bytes + bytes
                local fresh = {}
                for k, v in pairs(p.list) do fresh[k] = v end
                p.list = fresh
                p.n = count(p.list)
            end
            local gone = type(m[part.empty]) == "table" and m[part.empty][loc]
            if type(p[part.field]) == "string" and type(gone) == "string" and gone ~= "" then
                local kept, n = ns.ScanTrimRanges(p[part.field], gone)
                p[part.field] = kept
                res.bytes = res.bytes + n * 2
            end
        end
    end

    -- a Lua table keeps its size when its keys go: new tables with what is left give the memory back now
    -- (in one step: anything added meanwhile is copied too)
    for _, key in ipairs({ "items", "sources" }) do
        if type(s[key]) == "table" then
            local fresh = {}
            for k, v in pairs(s[key]) do fresh[k] = v end
            s[key] = fresh
        end
    end
    s.count = count(s.items)
    s.sourceCount = count(s.sources)
    return res
end

local function report(res, m)
    local text = L["Scan aufgeräumt (Stand %s): %d Items, %d Quellen und %d offene IDs entfernt, etwa %d KB. Es bleiben %d Items und %d Quellen, die noch nicht ausgewertet sind."]
        :format(tostring(m.built or "?"), res.items, res.notes, res.retry, math.floor(res.bytes / 1024 + 0.5),
            AmisiaDB.scan.count or 0, AmisiaDB.scan.sourceCount or 0)
    if res.quests + res.npcs > 0 then
        text = text .. " " .. L["Dazu %d Quests und %d NPC-Namen der Scans per Nummer."]:format(res.quests, res.npcs)
    end
    return text
end

local function finish(res, m, loud)
    local s = AmisiaDB.scan
    local before = type(s.trim) == "table" and s.trim or {}
    s.trim = { built = m.built, at = time(), items = res.items, notes = res.notes, retry = res.retry,
               quests = res.quests, npcs = res.npcs, total = (tonumber(before.total) or 0) + res.items }
    lastRun = res
    running = false
    -- the marker is spent for this session (what comes later is new anyway)
    ns.DropData("SCAN_DONE")
    if loud or (before.built ~= m.built and res.items + res.notes + res.retry + res.quests + res.npcs > 0) then ns.msg(report(res, m)) end
    if ns.Refresh then ns.Refresh() end
end

local function ready()
    if running then return nil, L["Das Aufräumen läuft schon."] end
    if (ns.ScanRunning and ns.ScanRunning()) or (ns.ScanById and ns.ScanById.Busy()) then return nil, L["Erst den Scan anhalten (/amisia scan stop), dann aufräumen."] end
    local s = AmisiaDB and AmisiaDB.scan
    if type(s) ~= "table" then return nil, L["Kein Scan gespeichert, nichts aufzuräumen."] end
    local m = ns.Data("SCAN_DONE")
    if type(m) ~= "table" then
        if lastRun then return nil, L["Schon aufgeräumt: was jetzt im Scan steht, ist neu seit dem letzten Build."] end
        return nil, L["Diese Version kennt keine ausgewerteten Scan-Daten."]
    end
    return m, s
end

-- Trims at once and reports. Returns the counts, or nil and why not.
function ns.ScanTrimNow()
    local m, s = ready()
    if not m then
        ns.msg(s)
        return nil, s
    end
    running = true
    local ok, res = pcall(trim, m, s, function() end)
    if not ok then
        running = false
        ns.ReportError(res)
        return nil
    end
    finish(res, m, true)
    return res
end

-- Trims in steps on timers (the login's way); done(res) when finished.
function ns.ScanTrimStart(done)
    local m, s = ready()
    if not m then return nil, s end
    running = true
    local co = coroutine.create(function()
        return trim(m, s, coroutine.yield)
    end)
    local function step()
        local ok, res = coroutine.resume(co)
        if not ok then
            running = false
            ns.ReportError(res)
            return
        end
        if coroutine.status(co) == "dead" then
            finish(res, m, false)
            if done then done(res) end
        else
            C_Timer.After(ns.SCAN_TRIM.step, step)
        end
    end
    step = ns.Perf.Wrap("Timer ScanTrim", step)   -- re-arms itself: /amisia leistung (F-184)
    step()
    return true
end

function ns.ScanTrimRunning() return running end

ns.OnEvent("PLAYER_LOGIN", function()
    if not ns.Get("tools.scanAutotrim") then return end
    C_Timer.After(ns.SCAN_TRIM.delay, function()
        if ns.Get("tools.scanAutotrim") and not running and not (ns.ScanRunning and ns.ScanRunning())
            and not (ns.ScanById and ns.ScanById.Busy()) and ns.HasData("SCAN_DONE") then
            ns.ScanTrimStart()
        end
    end)
end)
