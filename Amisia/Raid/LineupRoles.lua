-- Amisia lineup, the view "Rollen" (F-165, D-95): three lists of names the raid leader keeps, each
-- with its switch: main tanks (in order), assistants, master looters (the first of the list in the
-- raid gets it) with the loot threshold. "Rollen jetzt setzen" (ns.LineupRolesSet) promotes the
-- listed assistants, marks the listed main tanks and sets master loot, for those in the raid. It only
-- adds: nobody is demoted, no mark or loot master is taken away. Only as raid leader, in a raid of
-- one's own, out of combat and the lockdown. The automatic run (roles.auto, off) does the same
-- quietly QUIET seconds after the roster changed, once per name and raid (like the automatic
-- assistant of Raid/LineupSort.lua), and says a line only when it did something.
-- Whether the client lets an addon do this is not certain (SetPartyAssignment may be protected): a
-- refused call raises no error but fires ADDON_ACTION_FORBIDDEN / ADDON_ACTION_BLOCKED with the addon
-- and the function. Such an event for Amisia that names a function of a block (or comes during a
-- block's call, or up to LATE seconds after the main tank call) marks the block refused for the
-- session: it is not tried again, the chat says it once, the view shows a grey line. Nothing is sent
-- to other clients.
local ADDON, ns = ...
local L = ns.L

local RO = {}
ns.LineupRoles = RO

local MAX = 10             -- names per list
local QUIET = 2            -- the automatic run: seconds without a roster change before it starts
local LATE = 2             -- a refusal without a function name this many seconds after the main tank call counts for it
RO.MAX, RO.QUIET = MAX, QUIET
RO.BLOCKS = { "assist", "tanks", "ml" }
-- the loot thresholds of the picker: uncommon, rare, epic
RO.QUALITIES = { 2, 3, 4 }
local DEFAULT_Q = 4
local MASTER = (_G.Enum and Enum.LootMethod and Enum.LootMethod.Masterlooter) or 2

local function IV() return ns.LineupInv end
local function SO() return ns.LineupSortState end

-- The texts said once when the client refuses a block.
local REFUSED = {
    tanks = L["Haupttanks: Das Spiel lässt Addons das nicht setzen. Setze sie im Raidfenster von Hand."],
    assist = L["Assistenten: Das Spiel lässt Addons das nicht setzen. Befördere sie im Raidfenster von Hand."],
    ml = L["Plündermeister: Das Spiel lässt Addons das nicht setzen. Stelle die Plündermethode von Hand ein."],
}
RO.REFUSED = REFUSED
-- the client functions of each block, as a refusal event names them
local FN_BLOCK = { SetPartyAssignment = "tanks", PromoteToAssistant = "assist", SetLootMethod = "ml", SetLootThreshold = "ml" }

---------------------------------------------------------------------------
-- The saved lists: AmisiaDB.lineup.roles = { assist = { on, list }, tanks = { on, list },
-- ml = { on, list }, q = 2/3/4, auto }
---------------------------------------------------------------------------
-- A text of names with commas: the cleaned names (one per spelling, MAX at most) and how many were
-- dropped (not a name, a double, over MAX).
function RO.Parse(text)
    local out, seen, dropped = {}, {}, 0
    for part in tostring(text or ""):gmatch("[^,;\n]+") do
        local raw = part:match("^%s*(.-)%s*$")
        if raw ~= "" then
            local name = ns.LineupCleanName(raw)
            if name and not seen[name:lower()] and #out < MAX then
                seen[name:lower()] = true
                out[#out + 1] = name
            else
                dropped = dropped + 1
            end
        end
    end
    return out, dropped
end

local function cleanList(v)
    local out, seen = {}, {}
    for _, n in ipairs(type(v) == "table" and v or {}) do
        local name = type(n) == "string" and ns.LineupCleanName(n)
        if name and not seen[name:lower()] and #out < MAX then
            seen[name:lower()] = true
            out[#out + 1] = name
        end
    end
    return out
end

-- Core, ADDON_LOADED (through ns.LineupLoaded): every field checked; nil when nothing is left.
function RO.Clean(r)
    if type(r) ~= "table" then return nil end
    local out = {}
    for _, b in ipairs(RO.BLOCKS) do
        local x = type(r[b]) == "table" and r[b] or {}
        out[b] = { on = x.on ~= false, list = cleanList(x.list) }
    end
    local q = tonumber(r.q)
    out.q = (q == 2 or q == 3 or q == 4) and q or DEFAULT_Q
    out.auto = r.auto == true
    return out
end

-- The lists as they are (create: made in AmisiaDB when missing); nil without a saved table.
local function store(create)
    local d = ns.LineupStore(create)
    if not d then return nil end
    if type(d.roles) ~= "table" then
        if not create then return nil end
        d.roles = RO.Clean({})
    end
    return d.roles
end

local EMPTY = RO.Clean({})
-- The lists to read (the defaults while nothing is saved): never changed by the caller.
function RO.Get() return store(false) or EMPTY end

-- Sets a list from the text of its field: the count and the names dropped.
function RO.SetList(block, text)
    local list, dropped = RO.Parse(text)
    store(true)[block].list = list
    ns.Fire("LINEUP_INVITE")
    return #list, dropped
end
function RO.SetOn(block, on)
    store(true)[block].on = on and true or false
    ns.Fire("LINEUP_INVITE")
end
function RO.SetQuality(q)
    if q == 2 or q == 3 or q == 4 then store(true).q = q end
    ns.Fire("LINEUP_INVITE")
end
function RO.SetAuto(on)
    store(true).auto = on and true or false
    ns.Fire("LINEUP_INVITE")
end
function RO.ListText(block) return table.concat(RO.Get()[block].list, ", ") end

-- "Aus dem Planer": the night's tanks (role T) in a group, in group order (then list order).
function RO.FromPlanner(night)
    local n = ns.LineupNight(night or ns.LineupTonight(), false)
    local items = {}
    for i, e in ipairs(n and n.list or {}) do
        if e.r == "T" and e.g and not e.a and not e.b and not e.v then items[#items + 1] = { i = i, e = e } end
    end
    table.sort(items, function(a, b)
        if a.e.g ~= b.e.g then return a.e.g < b.e.g end
        return a.i < b.i
    end)
    local names = {}
    for _, it in ipairs(items) do names[#names + 1] = it.e.n end
    if #names == 0 then return nil, L["Im Planer steht kein Tank in einer Gruppe."] end
    local count = RO.SetList("tanks", table.concat(names, ","))
    return count
end

---------------------------------------------------------------------------
-- Who may, and the raid
---------------------------------------------------------------------------
-- Why the roles cannot be set now: a code and its text, or nil. Officers only (the page), out of
-- combat and the lockdown, in a raid of one's own, its leader (an assistant cannot promote or set
-- the loot).
function RO.Blocked()
    local REASON = IV().REASON
    if not ns.LineupAllowed() then return "officer", REASON.officer end
    local fight = IV().Fight()
    if fight then return fight, REASON[fight] end
    if not ns.HomeRaid() then return "raid", REASON.raid end
    if not UnitIsGroupLeader("player") then return "leader", L["Nur als Raidleiter"] end
    return nil
end

local refused = {}         -- [block] = true: the client refused it in this session
local handled = {}         -- [lower name] = true: the automatic run looked at him in this raid
local cur                  -- the running run: { refused = {} }
local during               -- the block whose client call runs right now
local tankAt               -- when the main tank call was made last

function RO.Refused(block) return refused[block] == true end

-- Whether a block has something to do: on, names, not refused.
local function active(cfg, b) return cfg[b].on and #cfg[b].list > 0 and not refused[b] end
function RO.HasWork()
    local cfg = RO.Get()
    for _, b in ipairs(RO.BLOCKS) do if active(cfg, b) then return true end end
    return false
end

-- The raid: rows { i, name, sub, rank } and their names.
local function raidRows()
    local rows = SO().Rows()
    local names = {}
    for _, r in ipairs(rows) do names[#names + 1] = r.name end
    return rows, names
end

local function find(rows, names, want)
    for _, r in ipairs(rows) do
        if ns.SameNameIn(want, r.name, names) then return r end
    end
    return nil
end

-- Whether a raider is a main tank already: GetPartyAssignment, else the roster's role.
local function isTank(r)
    local get = _G.GetPartyAssignment
    if type(get) == "function" then
        local ok, v = pcall(get, "MAINTANK", "raid" .. r.i)
        if ok and ns.Plain(v) ~= nil then return ns.Plain(v) and true or false end
    end
    local role = select(10, GetRaidRosterInfo(r.i))
    return ns.Plain(role) == "MAINTANK"
end

-- The loot method now: master (true/false) and the master looter's name (nil: unknown). The method
-- is an enum on new clients and the word "master" on old ones.
local function masterNow(rows)
    local known, method, partyID, raidID = ns.LootMethod()
    if not known and type(_G.GetLootMethod) == "function" then
        local ok, m, p, x = pcall(_G.GetLootMethod)
        if ok then method, partyID, raidID = ns.Plain(m), ns.Plain(p), ns.Plain(x) end
    end
    if method ~= MASTER and method ~= "master" then return false, nil end
    if raidID then
        for _, r in ipairs(rows) do if r.i == raidID then return true, r.name end end
    end
    for _, r in ipairs(rows) do
        if ns.Plain(select(11, GetRaidRosterInfo(r.i))) == true then return true, r.name end
    end
    if partyID == 0 then return true, ns.UnitFullName("player") end
    return true, nil
end

local function thresholdNow()
    local api = _G.C_PartyInfo
    local get = (type(api) == "table" and api.GetLootThreshold) or _G.GetLootThreshold
    if type(get) ~= "function" then return nil end
    local ok, q = pcall(get)
    return ok and tonumber(ns.Plain(q)) or nil
end

---------------------------------------------------------------------------
-- The client calls: each returns true (called), false (an error) or nil (no such function)
---------------------------------------------------------------------------
local function step(block, f, ...)
    if block == "tanks" then tankAt = GetTime() end
    if type(f) ~= "function" then return nil end
    during = block
    local ok = pcall(f, ...)
    during = nil
    return ok
end

local function setTank(r) return step("tanks", _G.SetPartyAssignment, "MAINTANK", "raid" .. r.i) end

-- The promotion of Raid/LineupSort.lua (C_PartyInfo.PromoteToAssistant, else the global).
local function promote(name)
    local api = _G.C_PartyInfo
    if not (type(api) == "table" and type(api.PromoteToAssistant) == "function") and type(_G.PromoteToAssistant) ~= "function" then
        return nil
    end
    during = "assist"
    local ok = SO().Promote(name)
    during = nil
    return ok and true or false
end

local function setMaster(name)
    local api = _G.C_PartyInfo
    if type(api) == "table" and type(api.SetLootMethod) == "function" then return step("ml", api.SetLootMethod, MASTER, name) end
    return step("ml", _G.SetLootMethod, "master", name)
end

local function setThreshold(q)
    local api = _G.C_PartyInfo
    if type(api) == "table" and type(api.SetLootThreshold) == "function" then return step("ml", api.SetLootThreshold, q) end
    return step("ml", _G.SetLootThreshold, q)
end

-- The client refused a call of Amisia's: the block it names; without a name the block whose call
-- runs now, else the main tanks when their call was a moment ago (the one call not known to work).
local function onRefused(who, what)
    if ns.Plain(who) ~= ADDON then return end
    what = ns.Plain(what)
    local block
    if type(what) == "string" then
        for fn, b in pairs(FN_BLOCK) do
            if what:find(fn, 1, true) then block = b break end
        end
    end
    if not block then block = during end
    if not block and tankAt and GetTime() - tankAt <= LATE then block = "tanks" end
    if not block or refused[block] then return end
    refused[block] = true
    if cur then
        cur.refused[block] = true
    else
        ns.msg(REFUSED[block])
        ns.Fire("LINEUP_INVITE")
    end
end
ns.OnEvent("ADDON_ACTION_FORBIDDEN", onRefused)
ns.OnEvent("ADDON_ACTION_BLOCKED", onRefused)

---------------------------------------------------------------------------
-- The run
---------------------------------------------------------------------------
-- the names of the loot toast's quality picker (the German client's: Selten green, Rar blue)
local QUALITY_NAME = { [2] = L["Selten (grün)"], [3] = L["Rar (blau)"], [4] = L["Episch (lila)"] }
RO.QUALITY_NAME = QUALITY_NAME

-- A block's counts as text: "2 befördert, 1 nicht im Raid".
local function countText(c, done)
    local parts = {}
    if c.done > 0 then parts[#parts + 1] = done:format(c.done) end
    if c.already > 0 then parts[#parts + 1] = c.alreadyText:format(c.already) end
    if c.absent > 0 then parts[#parts + 1] = L["%d nicht im Raid"]:format(c.absent) end
    if c.failed > 0 then parts[#parts + 1] = L["%d vom Spiel abgelehnt"]:format(c.failed) end
    if c.missing then parts[#parts + 1] = L["das Spiel hat die Funktion nicht"] end
    return table.concat(parts, ", ")
end

-- Assistants and main tanks: the listed names in the raid who lack the role get it. fresh: only
-- these lower names (the automatic run); nil: every name.
local function listStep(cfg, block, rows, names, fresh)
    local c = { done = 0, already = 0, absent = 0, failed = 0,
                alreadyText = block == "assist" and L["%d schon Assistent"] or L["%d schon Haupttank"] }
    if not active(cfg, block) then return nil end
    for _, want in ipairs(cfg[block].list) do
        local r = find(rows, names, want)
        if not r then
            if not fresh then c.absent = c.absent + 1 end
        elseif not fresh or fresh[r.name:lower()] then
            local has
            if block == "assist" then has = r.rank >= 1 else has = isTank(r) end
            if has then
                c.already = c.already + 1
            elseif not c.missing and not refused[block] then
                local ok
                if block == "assist" then ok = promote(r.name) else ok = setTank(r) end
                if ok == nil then
                    c.missing = true
                elseif ok and not refused[block] then
                    c.done = c.done + 1
                elseif not refused[block] then
                    c.failed = c.failed + 1
                end
            end
        end
    end
    return c
end

-- Master loot: the first listed name in the raid; not set again when he has it.
local function mlStep(cfg, rows, names, fresh)
    if not active(cfg, "ml") then return nil end
    local want
    for _, n in ipairs(cfg.ml.list) do
        want = find(rows, names, n)
        if want then break end
    end
    local q = cfg.q
    local res = { q = q }
    if not want then
        if fresh then return nil end
        res.none = true
        return res
    end
    res.name = want.name
    local master, who = masterNow(rows)
    if master and who and ns.SameName(who, want.name) then
        res.already = true
    elseif fresh and not fresh[want.name:lower()] then
        -- the automatic run sets master loot only for the one who just came (or on the first run)
        return nil
    else
        local ok = setMaster(want.name)
        if ok == nil then res.missing = true elseif not ok then res.failed = true end
        if not ok or refused.ml then return res end
        res.done = true
    end
    if refused.ml then return res end
    local now = thresholdNow()
    if now ~= q then
        local ok = setThreshold(q)
        if ok == nil then res.qMissing = true elseif not ok then res.qFailed = true else res.qDone = true end
    end
    return res
end

local function mlText(res)
    if res.none then return L["Plündermeister: niemand der Liste im Raid"] end
    local q = QUALITY_NAME[res.q] or tostring(res.q)
    if res.missing then return L["Plündermeister: das Spiel hat die Funktion nicht"] end
    if res.failed then return L["Plündermeister: das Spiel hat %s nicht gesetzt"]:format(res.name) end
    local line = res.already and L["Plündermeister: %s ist es schon, ab %s"]:format(res.name, q)
        or L["Plündermeister: %s, ab %s"]:format(res.name, q)
    if res.qMissing or res.qFailed then line = line .. ", " .. L["Plündergrenze nicht gesetzt"] end
    return line
end

-- One run. quiet: the automatic one (fresh names only, a line only when it did something).
-- Returns the chat line (nil when nothing was said) and the results per block.
local function run(quiet)
    local cfg = RO.Get()
    local rows, names = raidRows()
    local fresh
    if quiet then
        fresh = {}
        for _, r in ipairs(rows) do
            if not handled[r.name:lower()] then fresh[r.name:lower()] = true end
        end
        if not next(fresh) then return nil end
    end
    cur = { refused = {} }
    local res = {}
    local ok, err = pcall(function()
        res.assist = listStep(cfg, "assist", rows, names, fresh)
        res.tanks = listStep(cfg, "tanks", rows, names, fresh)
        res.ml = mlStep(cfg, rows, names, fresh)
    end)
    local got = cur.refused
    cur = nil
    for _, r in ipairs(rows) do handled[r.name:lower()] = true end
    if not ok then ns.ReportError(err) end
    -- the line
    local parts, did = {}, false
    for _, b in ipairs({ "assist", "tanks" }) do
        local c = res[b]
        if got[b] then
            ns.msg(REFUSED[b])
        elseif c and (c.done > 0 or not quiet) then
            -- the automatic run says only what it did
            local text = quiet and (b == "assist" and L["%d befördert"] or L["%d gesetzt"]):format(c.done)
                or countText(c, b == "assist" and L["%d befördert"] or L["%d gesetzt"])
            if c.done > 0 then did = true end
            if text ~= "" then
                parts[#parts + 1] = (b == "assist" and L["Assistenten: %s"] or L["Haupttanks: %s"]):format(text)
            end
        end
    end
    if got.ml then
        ns.msg(REFUSED.ml)
    elseif res.ml and (res.ml.done or res.ml.qDone or not quiet) then
        if res.ml.done or res.ml.qDone then did = true end
        parts[#parts + 1] = mlText(res.ml)
    end
    if quiet and not did then
        ns.Fire("LINEUP_INVITE")
        return nil, res
    end
    local line
    if #parts > 0 then
        line = L["Rollen: %s."]:format(table.concat(parts, " · "))
        ns.msg(line)
    elseif not quiet and not next(got) then
        line = L["Rollen: nichts zu setzen."]
        ns.msg(line)
    end
    ns.Fire("LINEUP_INVITE")
    return line, res
end

-- "Rollen jetzt setzen": true, or nil and the reason.
function ns.LineupRolesSet()
    local _, why = RO.Blocked()
    if why then return nil, why end
    if not RO.HasWork() then return nil, L["Keine Namen in den eingeschalteten Listen."] end
    run(false)
    return true
end

-- The automatic run: only with the switch, as raid leader, out of combat; once per name and raid.
function RO.Auto()
    if not ns.HomeRaid() then
        handled = {}
        return
    end
    local cfg = RO.Get()
    if not cfg.auto or not RO.HasWork() then return end
    if RO.Blocked() then return end
    run(true)
end

local autoToken = 0
local function autoLater()
    autoToken = autoToken + 1
    local token = autoToken
    C_Timer.After(QUIET, function()
        if token == autoToken then RO.Auto() end
    end)
end
ns.OnEvent("GROUP_ROSTER_UPDATE", autoLater)
-- after a fight or the lockdown the newly joined get their turn
ns.OnEvent("PLAYER_REGEN_ENABLED", autoLater)
ns.OnEvent("ADDON_RESTRICTION_STATE_CHANGED", autoLater)

---------------------------------------------------------------------------
-- The view's grey line per block
---------------------------------------------------------------------------
function RO.Status(block)
    if refused[block] then return REFUSED[block] end
    local cfg = RO.Get()
    local x = cfg[block]
    if not x.on then return L["Aus: wird nicht gesetzt."] end
    if #x.list == 0 then return L["Keine Namen."] end
    if not ns.HomeRaid() then return L["%d Namen; im Raid setzt Amisia sie."]:format(#x.list) end
    local rows, names = raidRows()
    if block == "ml" then
        for _, n in ipairs(x.list) do
            local r = find(rows, names, n)
            if r then
                local master, who = masterNow(rows)
                if master and who and ns.SameName(who, r.name) then
                    return L["%s ist Plündermeister, ab %s."]:format(r.name, QUALITY_NAME[cfg.q])
                end
                return L["Bekommt es: %s, ab %s."]:format(r.name, QUALITY_NAME[cfg.q])
            end
        end
        return L["Niemand der Liste im Raid."]
    end
    local inRaid, has = 0, 0
    for _, n in ipairs(x.list) do
        local r = find(rows, names, n)
        if r then
            inRaid = inRaid + 1
            if (block == "assist" and r.rank >= 1) or (block == "tanks" and isTank(r)) then has = has + 1 end
        end
    end
    return L["%d Namen, %d im Raid, %d haben es schon."]:format(#x.list, inRaid, has)
end

RO._reset = function()
    refused, handled, cur, during, tankAt = {}, {}, nil, nil, nil
end
