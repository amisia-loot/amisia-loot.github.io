-- /amisia leistung (en performance): Amisia measures its own CPU time and keeps the result for the
-- N100 (F-184, D-116, spec docs/specs/2026-11-12-leistung-messen.md). The timing itself is Core/Perf.lua;
-- this file is the command, the report and the saved runs. It is the last file of the TOC: its end
-- stamps the time all of Amisia's files took to load.
--
-- AmisiaDB.perf = { v = 1, arm = true or nil (measure the next login), runs = { newest first } }; a run:
-- { at = server epoch of the start, v = Amisia's version, b = client build, g = ns.GAME, kind = hand/login,
--   stop = hand/time/cap/logout, dur = seconds, fr = frames, cb = seconds in combat, where = the instance
--   types met ("none", "party", ... joined by ","), ms = Amisia's measured time (ms), n = calls,
--   sp = calls over the spike limit, kb = garbage of the measured calls (KB),
--   mem = { a0, a1 = Amisia's memory at start and end (KB, nil without the client's function),
--           l0, l1 = the Lua memory of all addons (KB) },
--   load = { files, al, pl, pew, ev = ms: the files, the login's ADDON_LOADED, PLAYER_LOGIN,
--            PLAYER_ENTERING_WORLD and other events until the first PLAYER_ENTERING_WORLD },
--   data = { { k = key, ms, kb, run = true when built during the run } },
--   rows = { { l = label, n = calls, ms = own time, inc = with the measured calls inside, max = the
--              longest own time of one call, sp = calls over the spike limit, kb = own garbage } } }
-- No names of players, characters or realms: labels are fixed words, event names, page keys and
-- "File:line" of Amisia's own code.
local ADDON, ns = ...
local L = ns.L
local P = ns.Perf

local R = {
    RUNS = 5,            -- runs kept
    ROWS = 60,           -- rows per run
    DATA = 20,           -- built data tables per run
    LABEL = 60,          -- bytes of a label
    CAP = 60,            -- minutes a measurement runs at most
    LOGIN = 60,          -- seconds "login" measures
    TOP = 10,            -- rows in the chat report
    BUDGET = 1000 / 60,  -- ms of one frame at 60 fps
}
ns.PerfReport = R

local cur     -- the running measurement: { kind, at, t0, mem0, lua0, where, built0 }
local token = 0

local function round(x, d)
    local m = 10 ^ (d or 2)
    return math.floor((tonumber(x) or 0) * m + 0.5) / m
end

-- Amisia's memory in KB (the client's own count, refreshed: only at start and stop), or nil.
local function addonKB()
    local update = _G.UpdateAddOnMemoryUsage or (C_AddOns and C_AddOns.UpdateAddOnMemoryUsage)
    local get = _G.GetAddOnMemoryUsage or (C_AddOns and C_AddOns.GetAddOnMemoryUsage)
    if type(update) ~= "function" or type(get) ~= "function" then return nil end
    local ok = pcall(update)
    if not ok then return nil end
    local ok2, kb = pcall(get, ADDON)
    kb = ok2 and tonumber(ns.Plain and ns.Plain(kb) or kb) or nil
    return kb and round(kb, 0) or nil
end

local function build()
    local ok, version, number = pcall(GetBuildInfo)
    if not ok then return "?" end
    return ("%s.%s"):format(tostring(version or "?"), tostring(number or "?"))
end

-- The saved table (shaped by ns.PerfLoaded), or nil before ADDON_LOADED.
local function store()
    return AmisiaDB and type(AmisiaDB.perf) == "table" and AmisiaDB.perf or nil
end

local function noteWhere()
    if not cur then return end
    local kind = "none"
    if IsInInstance then
        local ok, inside, t = pcall(IsInInstance)
        t = ok and ns.Plain and ns.Plain(t) or t
        if ok and type(t) == "string" and t:match("^%a+$") then kind = t elseif ok and inside then kind = "instance" end
    end
    cur.where[kind] = true
end

---------------------------------------------------------------------------
-- Start and stop
---------------------------------------------------------------------------
-- Starts a measurement of kind ("hand" or "login") that stops itself after seconds with reason ("time"
-- or "cap"). Returns true, or false and "running"/"noclock".
function R.Start(kind, seconds, reason)
    local ok, why = P.Start()
    if not ok then return false, why end
    token = token + 1
    local mine = token
    local built0 = {}
    for k in pairs(ns.DataBuilt and ns.DataBuilt() or {}) do built0[k] = true end
    cur = { kind = kind, at = time(), t0 = GetTime(), mem0 = addonKB(), lua0 = collectgarbage("count"), where = {}, built0 = built0 }
    noteWhere()
    C_Timer.After(seconds, function()
        if mine == token and P.Running() then R.Finish(reason or "time") end
    end)
    return true
end

-- The login's steps: inclusive ms per event of the bus until the first PLAYER_ENTERING_WORLD.
local function loadInfo()
    local ev = {}
    for label, r in pairs(P.BootRows()) do
        local name = label:match("^Event (%S+) ") or label:match("^Core (%S+)$")
        if name then ev[name] = (ev[name] or 0) + r.inc end
    end
    local other = 0
    for name, ms in pairs(ev) do
        if name ~= "ADDON_LOADED" and name ~= "PLAYER_LOGIN" and name ~= "PLAYER_ENTERING_WORLD" then other = other + ms end
    end
    return { files = P.loadMs and round(P.loadMs, 1) or nil, al = round(ev.ADDON_LOADED or 0, 1), pl = round(ev.PLAYER_LOGIN or 0, 1),
             pew = round(ev.PLAYER_ENTERING_WORLD or 0, 1), ev = round(other, 1) }
end

local function dataInfo(built0)
    local out = {}
    for k, b in pairs(ns.DataBuilt and ns.DataBuilt() or {}) do
        out[#out + 1] = { k = tostring(k), ms = b.ms and round(b.ms, 1) or nil, kb = round(b.kb or 0, 0), run = not built0[k] or nil }
    end
    table.sort(out, function(a, b)
        if (a.ms or 0) ~= (b.ms or 0) then return (a.ms or 0) > (b.ms or 0) end
        return a.k < b.k
    end)
    for i = #out, R.DATA + 1, -1 do out[i] = nil end
    return out
end

-- Ends the running measurement with reason, saves it (newest first, R.RUNS kept) and returns the
-- run; nil when none runs.
function R.Stop(reason)
    if not cur or not P.Running() then return nil end
    noteWhere()
    local res = P.Stop()
    local c = cur
    cur = nil
    token = token + 1
    local rows, ms, n, sp, kb = {}, 0, 0, 0, 0
    for label, r in pairs(res.rows or {}) do
        ms, n, sp, kb = ms + r.ms, n + r.n, sp + r.sp, kb + r.kb
        rows[#rows + 1] = { l = label:sub(1, R.LABEL), n = r.n, ms = round(r.ms, 2), inc = round(r.inc, 2), max = round(r.max, 2),
                            sp = r.sp, kb = round(r.kb, 1) }
    end
    table.sort(rows, function(a, b)
        if a.ms ~= b.ms then return a.ms > b.ms end
        if a.n ~= b.n then return a.n > b.n end
        return a.l < b.l
    end)
    for i = #rows, R.ROWS + 1, -1 do rows[i] = nil end
    local where = {}
    for w in pairs(c.where) do where[#where + 1] = w end
    table.sort(where)
    local run = {
        at = c.at, v = tostring(ns.VERSION), b = build(), g = tostring(ns.GAME), kind = c.kind, stop = reason,
        dur = round(GetTime() - c.t0, 1), fr = res.frames, cb = round(res.combat, 1), where = table.concat(where, ","),
        ms = round(ms, 1), n = n, sp = sp, kb = round(kb, 0),
        mem = { a0 = c.mem0, a1 = addonKB(), l0 = round(c.lua0, 0), l1 = round(collectgarbage("count"), 0) },
        load = loadInfo(), data = dataInfo(c.built0), rows = rows,
    }
    local s = store()
    if s then
        table.insert(s.runs, 1, run)
        for i = #s.runs, R.RUNS + 1, -1 do s.runs[i] = nil end
    end
    return run
end

-- Stops and prints the report.
function R.Finish(reason)
    local run = R.Stop(reason)
    if run then
        for _, line in ipairs(R.Lines(run)) do ns.msg(line) end
    end
    return run
end

function R.Last()
    local s = store()
    return s and s.runs[1] or nil
end

---------------------------------------------------------------------------
-- The report
---------------------------------------------------------------------------
local function duration(s)
    s = math.floor((tonumber(s) or 0) + 0.5)
    if s < 60 then return L["%d s"]:format(s) end
    return L["%d min %02d s"]:format(math.floor(s / 60), s % 60)
end

local function mb(kb)
    if type(kb) ~= "number" then return "?" end
    return ns.Num(kb / 1024, 1) .. " MB"
end

local function ms(x)
    if type(x) ~= "number" then return "?" end
    return ns.Num(x, x < 10 and 2 or 0)
end

local KINDS = { hand = L["von Hand"], login = L["Login"] }
local STOPS = { hand = L["von Hand beendet"], time = L["nach der gewählten Zeit beendet"], cap = L["nach der Obergrenze beendet"],
                logout = L["beim Ausloggen beendet"] }

local function whereText(where)
    where = tostring(where or "")
    if where == "" or where == "none" then return L["außerhalb von Instanzen"] end
    if where:find("none", 1, true) then return L["teils in einer Instanz"] end
    return L["in einer Instanz"]
end

-- The chat lines of a run (a saved one too: every field read as it may be).
local function num(v) return tonumber(v) or 0 end

function R.Lines(run)
    local out = {}
    local dur = math.max(num(run.dur), 0.001)
    local fr = math.floor(num(run.fr))
    local at = tonumber(run.at)
    out[#out + 1] = L["Leistung (%s, %s): %s gemessen, %d Frames, %s fps, %s im Kampf, %s; %s."]:format(
        KINDS[run.kind] or tostring(run.kind), at and ns.FmtDayTime(at) or "?", duration(run.dur), fr, ns.Num(fr / dur, 0),
        duration(run.cb), whereText(run.where), STOPS[run.stop] or tostring(run.stop))
    local perFrame = fr > 0 and num(run.ms) / fr or 0
    out[#out + 1] = L["Amisia: %s ms je Sekunde, %s ms je Frame (%s %% von 16,7 ms, einem Frame bei 60 fps); %d Aufrufe, %d über %d ms."]:format(
        ns.Num(num(run.ms) / dur, 2), ns.Num(perFrame, 3), ns.Num(perFrame / R.BUDGET * 100, 1), math.floor(num(run.n)), math.floor(num(run.sp)), P.SPIKE)
    local mem = type(run.mem) == "table" and run.mem or {}
    out[#out + 1] = L["Speicher: Amisia %s -> %s, alle Addons %s -> %s; Müll von Amisia %s KB je Sekunde."]:format(
        mb(mem.a0), mb(mem.a1), mb(mem.l0), mb(mem.l1), ns.Num(num(run.kb) / dur, 1))
    local ld = type(run.load) == "table" and run.load or {}
    out[#out + 1] = L["Laden: Dateien %s ms, ADDON_LOADED %s ms, PLAYER_LOGIN %s ms, PLAYER_ENTERING_WORLD %s ms, andere Ereignisse %s ms."]:format(
        ms(ld.files), ms(ld.al), ms(ld.pl), ms(ld.pew), ms(ld.ev))
    local parts, during = {}, {}
    for _, d in ipairs(type(run.data) == "table" and run.data or {}) do
        if type(d) == "table" then
            parts[#parts + 1] = ("%s %s ms"):format(tostring(d.k), ms(tonumber(d.ms)))
            if d.run then during[#during + 1] = tostring(d.k) end
        end
    end
    if #parts == 0 then
        out[#out + 1] = L["Gebaute Daten: keine."]
    elseif #during == 0 then
        out[#out + 1] = L["Gebaute Daten: %s."]:format(table.concat(parts, ", "))
    else
        out[#out + 1] = L["Gebaute Daten: %s; davon in der Messung: %s."]:format(table.concat(parts, ", "), table.concat(during, ", "))
    end
    local rows = {}
    for _, r in ipairs(type(run.rows) == "table" and run.rows or {}) do
        if type(r) == "table" then rows[#rows + 1] = r end
    end
    if #rows == 0 then
        out[#out + 1] = L["Keine Aufrufe gemessen."]
        return out
    end
    local top = math.min(#rows, R.TOP)
    out[#out + 1] = L["Die %d teuersten Stellen, eigene Zeit (Aufrufe · ms gesamt · ms je Aufruf · längster Aufruf in ms · über %d ms):"]:format(top, P.SPIKE)
    for i = 1, top do
        local r = rows[i]
        local n = math.floor(num(r.n))
        out[#out + 1] = ("%d. %s · %d · %s · %s · %s · %d"):format(i, tostring(r.l), n, ms(num(r.ms)), ns.Num(num(r.ms) / math.max(n, 1), 3),
            ms(num(r.max)), math.floor(num(r.sp)))
    end
    return out
end

---------------------------------------------------------------------------
-- Saved data and the command
---------------------------------------------------------------------------
-- AmisiaDB.perf shaped on ADDON_LOADED (Core.lua calls it first thing, so a measurement of the login
-- starts before the other handlers of ADDON_LOADED): runs kept as they are, cut to R.RUNS and R.ROWS.
function ns.PerfLoaded(sv)
    local old = sv.perf
    local runs = {}
    if type(old) == "table" and old.v == 1 and type(old.runs) == "table" then
        for _, r in ipairs(old.runs) do
            if type(r) == "table" and type(r.at) == "number" and #runs < R.RUNS then
                if type(r.rows) ~= "table" then r.rows = {} end
                for i = #r.rows, R.ROWS + 1, -1 do r.rows[i] = nil end
                runs[#runs + 1] = r
            end
        end
    end
    local arm = type(old) == "table" and old.arm == true
    sv.perf = { v = 1, runs = runs }
    if arm and R.Start("login", R.LOGIN, "time") then
        ns.msg(L["Leistung: Der Login wird %d s lang gemessen; der Bericht kommt danach."]:format(R.LOGIN))
    end
end

local function startHand(minutes)
    if P.Running() then
        ns.msg(L["Die Messung läuft schon. /amisia leistung beendet sie."])
        return
    end
    local ok, why = R.Start("hand", (minutes or R.CAP) * 60, minutes and "time" or "cap")
    if not ok then
        if why == "noclock" then ns.msg(L["Dieser Client hat keine genaue Uhr (debugprofilestop): Amisia kann hier nicht messen."]) end
        return
    end
    if minutes then
        ns.msg(L["Leistung: Messung läuft %d min. Spiel einfach weiter; /amisia leistung beendet sie früher."]:format(minutes))
    else
        ns.msg(L["Leistung: Messung läuft (höchstens %d min). /amisia leistung beendet sie und zeigt den Bericht."]:format(R.CAP))
    end
end

function R.Slash(rest)
    local w = tostring(rest or ""):lower():match("^%s*(%S*)")
    local n = tonumber(w)
    if w == "" then
        if P.Running() then R.Finish("hand") else startHand(nil) end
    elseif w == "an" or w == "on" then   -- l10n-ok: typed words
        startHand(nil)
    elseif w == "aus" or w == "off" then   -- l10n-ok: typed words
        if P.Running() then R.Finish("hand") else ns.msg(L["Es läuft keine Messung."]) end
    elseif w == "bericht" or w == "report" then   -- l10n-ok: typed words
        local run = R.Last()
        if not run then
            ns.msg(L["Noch keine Messung gespeichert. /amisia leistung startet eine."])
        else
            for _, line in ipairs(R.Lines(run)) do ns.msg(line) end
        end
    elseif w == "login" then
        local s = store()
        if not P.Clock then
            ns.msg(L["Dieser Client hat keine genaue Uhr (debugprofilestop): Amisia kann hier nicht messen."])
        elseif s then
            s.arm = true
            ns.msg(L["Leistung: Die nächste Anmeldung oder /reload wird %d s lang gemessen."]:format(R.LOGIN))
        end
    elseif n then
        startHand(math.max(1, math.min(R.CAP, math.floor(n))))
    else
        ns.msg(L["Aufruf: /amisia leistung [an|aus|bericht|login|<Minuten>]"])
    end
end

ns.RegisterSlash("leistung", { en = "performance", args = L["[an|aus|bericht|login|<Minuten>]"],
    desc = L["Amisias Rechenzeit messen, Bericht im Chat"], run = function(rest) R.Slash(rest) end })

-- the result is saved before the file is written; where the measurement went along
ns.OnEvent("PLAYER_LOGOUT", function() if P.Running() then R.Stop("logout") end end)
ns.OnEvent("PLAYER_ENTERING_WORLD", noteWhere)
ns.OnEvent("ZONE_CHANGED_NEW_AREA", noteWhere)

-- the last file of the TOC: every file of Amisia has loaded
P.loadMs = P.Since()
