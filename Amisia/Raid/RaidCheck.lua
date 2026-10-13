-- The raid check (F-098, spec docs/specs/2026-10-12-raid-check.md, parts A and B, D-46): before the
-- pull an officer sees per raider the flask, the elixirs, the food ("Well Fed") and the class buffs
-- (read by the client itself from the raiders' auras, out of combat) and what each raider's Amisia
-- says about itself: the lowest durability, the item level, empty and unenchanted slots, free talent
-- points. The lists of flasks, elixirs, food and class buffs are Data/RaidCheckData.lua (built from
-- the client tables, spell ids only).
--
-- Messages (Core/Comm.lua):
--   XQ <question id>   an officer -> RAID on "Prüfen": every Amisia of the raid answers once
--   XA <question id|-> <lowest durability|-> <items under the threshold> <item level x10|-> <empty
--      slots|-> <unenchanted slots|-> <free points|-> <consumables F/E<n>/W|->
--      a raider -> RAID 0-3 s after an XQ, or once by itself on a ready check (question id "-")
-- Trust: XQ only from a verified officer (rank flag 22) in the own raid; XA from a guild member in the
-- own raid, kept only in the officer view with the officer rank and only in memory (30 minutes, until
-- the raid ends). Nothing in combat or the lockdown: an answer that does not go out within 10 s
-- falls; a second question within 10 s is not answered again. A ready check in a boss fight is
-- secret: no answer. The chat line "Amisia Raid-Check: Es fehlt: ..." goes only on the officer's
-- click, with raidcheck.chat on, never in the lockdown, two lines at most, names of the raid only.
local ADDON, ns = ...
local L = ns.L
local RR = ns.RaidRead

local RC = {}
ns.RaidCheck = RC

local ANSWER_SPREAD = 3     -- an XA waits 0 to 3 s (not every raider at once)
local ANSWER_TTL = 10       -- and falls when it has not gone 10 s after it was queued
local ANSWER_GAP = 10       -- a second question within this many seconds is not answered again
local ASK_GAP = 10          -- "Prüfen" sends XQ at most this often
local SELF_FRESH = 600      -- a raider out of sight: the own report counts when at most this old
local KEEP = 1800           -- answers kept in memory (seconds)
local ORANGE = 50           -- durability below this: orange (below raidcheck.durability: red)
local CHAT_TTL = 10         -- a chat line that waits (lockdown, throttle) falls after this
local CHAT_LINES = 2
-- the off hand counts as empty only without a two-hand weapon; the ranged slot not for the classes
-- with relics (librams, totems, idols)
local NO_RANGED = { PALADIN = true, SHAMAN = true, DRUID = true }
local SHIELD = 17

-- the buff groups: their word in the cells and the "Es fehlt" line (the data names their class)
RC.GROUP_SHORT = { int = L["Int##Buff"], sta = L["Ausd##Buff"], wild = L["Mal##Buff"], spirit = L["Wille##Buff"], bless = L["Segen##Buff"] }
RC.GROUP_NAME = { int = L["Intelligenz"], sta = L["Ausdauer"], wild = L["Mal der Wildnis"], spirit = L["Willenskraft"], bless = L["Segen"] }
RC.GROUP_ORDER = { "int", "sta", "wild", "spirit", "bless" }

local answers = {}          -- [lower name] = the own report of a raider (XA), in memory only
local lastAnswer = -1e9     -- GetTime() of the own last XA
local lastAsk = -1e9        -- GetTime() of the own last XQ
local lastRows              -- the rows of the last read (shown in combat): { at, list }

local function me() return ns.UnitFullName("player") end
-- RAIDCHECK once for a burst of answers (40 raiders answer within 3 s): the page reads the auras of
-- the raid once, not once per answer
local firePending = false
local function fireSoon()
    if firePending then return end
    firePending = true
    C_Timer.After(0.5, function()
        firePending = false
        ns.Fire("RAIDCHECK")
    end)
end

-- Who may see and ask: the officer view with the officer rank (D-41, as the lineup).
function ns.RaidCheckAllowed()
    return ns.IsOfficerView() and ns.SelfIsOfficer ~= nil and ns.SelfIsOfficer(true) or false
end

-- Why nothing is read or sent now: "combat", "lock" (the chat lockdown of a boss fight) or nil.
function RC.Locked()
    if InCombatLockdown() then return "combat" end
    if ns.ChatLocked() then return "lock" end
    local api = _G.C_RestrictedActions
    if type(api) == "table" and type(api.IsAddOnRestrictionActive) == "function" then
        local ok, on = pcall(api.IsAddOnRestrictionActive, 1)
        if ok and ns.Plain(on) == true then return "lock" end
    end
    return nil
end

local function homeRaid()
    if _G.LE_PARTY_CATEGORY_HOME then return IsInRaid(LE_PARTY_CATEGORY_HOME) and true or false end
    return IsInRaid() and true or false
end

---------------------------------------------------------------------------
-- The lists (Data/RaidCheckData.lua)
---------------------------------------------------------------------------
local data, buffKey, groups
local function lists()
    if data then return data end
    local d = ns.Data("RAIDCHECK")
    if type(d) ~= "table" then return nil end
    data, buffKey, groups = d, {}, {}
    for _, b in ipairs(d.buffs or {}) do
        local key, class, talent, spells = b[1], b[2], b[3] == 1, b[4] or {}
        groups[#groups + 1] = { key = key, class = class, talent = talent }
        for _, id in ipairs(spells) do buffKey[id] = key end
    end
    return d
end
-- for the tests: forget the lists read (a fixture put in their place)
function RC.Reload() data, buffKey, groups = nil, nil, nil end

-- What auras (RR.Auras(...).all) hold: { flask = info, elixirs = { info }, food = info, have = { [group]
-- = info } }; info = { id, left, name }. Secret auras are skipped.
function RC.Classify(all)
    local d = lists()
    local out = { elixirs = {}, have = {} }
    if not d then return out end
    for _, a in ipairs(all or {}) do
        local id, _, left, name = RR.AuraInfo(a)
        if id then
            local info = { id = id, left = left, name = name }
            if d.flask[id] then
                out.flask = out.flask or info
            elseif d.elixir[id] then
                out.elixirs[#out.elixirs + 1] = info
            elseif d.food[id] then
                out.food = out.food or info
            elseif buffKey[id] and not out.have[buffKey[id]] then
                out.have[buffKey[id]] = info
            end
        end
    end
    return out
end

-- Whether a classification counts as supplied: a flask or at least one elixir (the spec's choice).
function RC.Supplied(c) return c ~= nil and (c.flask ~= nil or #c.elixirs > 0) end

---------------------------------------------------------------------------
-- The own report: durability, item level, empty and unenchanted slots, free points, consumables
---------------------------------------------------------------------------
local function equipLoc(link)
    local item = _G.C_Item
    if type(link) ~= "string" or type(item) ~= "table" or type(item.GetItemInfoInstant) ~= "function" then return nil end
    local ok, _, _, _, loc = pcall(item.GetItemInfoInstant, link)
    return ok and ns.Plain(loc) or nil
end

local function slotsOf()
    local d = lists()
    return d and d.slots or { 15, 5, 9, 10, 8, 16, 17 }, d and d.shield or SHIELD
end

-- The own report now: { at, dur (lowest %), below (items under the threshold), ilvl, empty = { inv },
-- unench = { inv }, free, level, cons = classification, auras = readable or not }.
function RC.Own()
    local o = { at = math.floor(time()), empty = {}, unench = {}, below = 0 }
    local ok, a = pcall(RR.Auras, "player")
    if ok then
        o.cons = RC.Classify(a.all)
        o.secret = a.secret
    end
    local threshold = ns.Get("raidcheck.durability") or 30
    local worn = {}
    local _, class = UnitClass("player")
    for _, s in ipairs(RR.Slots()) do
        local okL, link = pcall(GetInventoryItemLink, "player", s.inv)
        link = okL and ns.Plain(link) or nil
        worn[s.inv] = link
        if link then
            local okD, cur, _, pct = pcall(RR.Durability, s.inv)
            if okD and type(cur) == "number" then
                if not o.dur or pct < o.dur then o.dur = pct end
                if pct < threshold then o.below = o.below + 1 end
            end
        end
    end
    for _, s in ipairs(RR.Slots()) do
        local inv = s.inv
        if not worn[inv] then
            local skip = (inv == SHIELD and equipLoc(worn[16]) == "INVTYPE_2HWEAPON") or (inv == 18 and NO_RANGED[ns.Plain(class) or ""])
            if not skip then o.empty[#o.empty + 1] = inv end
        end
    end
    local enchanted, shield = slotsOf()
    for _, inv in ipairs(enchanted) do
        local link = worn[inv]
        if link and not (inv == shield and equipLoc(link) ~= "INVTYPE_SHIELD") then
            local e = RR.Enchant(inv, link, false)
            local has = e.id ~= 0
            if not has then
                local okT, t = pcall(RR.Enchant, inv, link)
                has = okT and t.lines > 0
            end
            if not has then o.unench[#o.unench + 1] = inv end
        end
    end
    local okI, _, equipped = pcall(RR.ItemLevel)
    if okI and type(equipped) == "number" and not RR.isSecret(equipped) then o.ilvl = equipped end
    local okF, free = pcall(RR.FreePoints)
    if okF and type(free) == "number" then o.free = free end
    o.level = tonumber(ns.Plain(UnitLevel("player")))
    return o
end

-- "F", "E2", "W" joined ("FE2W"), "-" for none.
local function consText(c)
    if not c then return "-" end
    local s = (c.flask and "F" or "") .. (#c.elixirs > 0 and ("E" .. math.min(#c.elixirs, 9)) or "") .. (c.food and "W" or "")
    return s ~= "" and s or "-"
end

local function slotList(list)
    if #list == 0 then return "-" end
    local out = {}
    for i, inv in ipairs(list) do out[i] = tostring(inv) end
    return table.concat(out, ",")
end

-- The XA fields of an own report.
function RC.AnswerFields(q, o)
    return { q or "-", o.dur and tostring(o.dur) or "-", tostring(math.min(o.below or 0, 19)),
             o.ilvl and tostring(math.floor(o.ilvl * 10 + 0.5)) or "-", slotList(o.empty), slotList(o.unench),
             o.free and tostring(math.min(o.free, 99)) or "-", consText(o.cons) }
end

-- An XA as a report (the fields are checked by Comm.lua).
local function parseList(v)
    local out = {}
    if v == "-" then return out end
    for x in v:gmatch("%d+") do out[#out + 1] = tonumber(x) end
    return out
end

function RC.ParseAnswer(f)
    local cons = f[8]
    local c = { elixirs = {}, have = {} }
    if cons:find("F", 1, true) then c.flask = { self = true } end
    if cons:find("W", 1, true) then c.food = { self = true } end
    for _ = 1, tonumber(cons:match("E(%d)") or "0") do c.elixirs[#c.elixirs + 1] = { self = true } end
    return { at = math.floor(time()), q = f[1], dur = tonumber(f[2]), below = tonumber(f[3]) or 0,
             ilvl = tonumber(f[4]) and tonumber(f[4]) / 10 or nil, empty = parseList(f[5]), unench = parseList(f[6]),
             free = tonumber(f[7]), cons = c, heard = true }
end

---------------------------------------------------------------------------
-- Answering: XQ from an officer, the ready check by itself
---------------------------------------------------------------------------
-- Sends the own report to the raid (question id q, "-" on a ready check). Returns whether it went
-- into the queue.
function RC.Answer(q)
    if ns.Get("raidcheck.answer") == false or not homeRaid() then return false end
    if RC.Locked() then return false end
    if GetTime() - lastAnswer < ANSWER_GAP then return false end
    if not (ns.CommReady and ns.CommReady()) then return false end
    lastAnswer = GetTime()
    local o = RC.Own()
    return ns.CommSend("XA", RC.AnswerFields(q, o), "RAID", nil, { jitter = ANSWER_SPREAD, ttl = ANSWER_TTL, key = "XA" }) and true or false
end

ns.CommOn("XQ", function(sender, f, chan)
    if chan ~= "RAID" or ns.Get("raidcheck.answer") == false then return end
    local name = ns.TrustName(sender)
    if not name or not ns.InMyGroup(name) then return end
    ns.TrustWait(name, "officer", function(ok)
        if ok and ns.InMyGroup(name) then RC.Answer(f[1]) end
    end)
end)

ns.CommOn("XA", function(sender, f, chan)
    if chan ~= "RAID" or not ns.RaidCheckAllowed() then return end
    local name = ns.TrustName(sender)
    if not name or not ns.InMyGroup(name) then return end
    local rep = RC.ParseAnswer(f)
    ns.TrustWait(name, "member", function(ok)
        if not ok or not ns.InMyGroup(name) then return end
        rep.name = name
        answers[name:lower()] = rep
        fireSoon()
    end)
end)

-- The ready check: every Amisia answers once by itself, outside the lockdown, when a member of the
-- own guild started it (no answer in a raid of strangers); in a boss fight the event is secret and
-- nobody answers. The officer's page reads the buffs again.
ns.OnEvent("READY_CHECK", function(initiator)
    initiator = ns.Plain(initiator)
    if type(initiator) ~= "string" then return end
    if RC.Locked() then return end
    local who = ns.TrustName(initiator)
    if who and ns.IsVerifiedMember(who) == true then RC.Answer("-") end
    if ns.RaidCheckAllowed() then
        lastRows = nil
        ns.Fire("RAIDCHECK")
    end
end)

-- The raid ended: the answers go.
ns.OnEvent("GROUP_ROSTER_UPDATE", function()
    if (GetNumGroupMembers() or 0) == 0 then
        answers, lastRows = {}, nil
    end
end)

-- The own report of a raider (the own one read now), nil when none or older than 30 minutes.
function RC.AnswerOf(name)
    if not name then return nil end
    if ns.SameName(name, me()) then
        local o = RC.Own()
        o.name = me()
        return o
    end
    local a = answers[name:lower()]
    if a and time() - a.at <= KEEP then return a end
    return nil
end

---------------------------------------------------------------------------
-- Asking: "Prüfen"
---------------------------------------------------------------------------
-- Reads every buff again and asks the Amisia clients of the raid (XQ). Returns true and the chat
-- line, or nil and the reason ("Nicht im Kampf." in combat or the lockdown: nothing sent).
function RC.Ask()
    if not ns.RaidCheckAllowed() then return nil, L["Der Raid-Check ist nur für Offiziere."] end
    if RC.Locked() then return nil, L["Nicht im Kampf."] end
    lastRows = nil
    if not homeRaid() then
        ns.Fire("RAIDCHECK")
        return true, L["Raid-Check: Buffs neu gelesen (keine Raidgruppe, niemand gefragt)."]
    end
    if GetTime() - lastAsk < ASK_GAP then return true, L["Raid-Check: gerade gefragt, die Antworten kommen."] end
    lastAsk = GetTime()
    local q = ("%04x"):format(math.random(0, 65535))
    local sent = ns.CommReady and ns.CommReady() and ns.CommSend("XQ", { q }, "RAID", nil, { ttl = ANSWER_TTL, key = "XQ" })
    ns.Fire("RAIDCHECK")
    if not sent then return true, L["Raid-Check: Buffs neu gelesen; Addon-Nachrichten sind aus."] end
    return true, L["Raid-Check: gefragt, die Antworten kommen in wenigen Sekunden."]
end

---------------------------------------------------------------------------
-- The rows of the page: one per raider
---------------------------------------------------------------------------
-- The group: { { name, unit, g, c, l, online, dead } }; alone only the player.
local function roster()
    local out = {}
    local n = GetNumGroupMembers() or 0
    if IsInRaid() and n > 0 then
        for i = 1, n do
            local name, _, subgroup, level, _, file, _, online, dead = GetRaidRosterInfo(i)
            name = ns.FullName(ns.Plain(name))
            if name then
                out[#out + 1] = { name = name, unit = "raid" .. i, g = tonumber(subgroup) or 1, c = ns.Plain(file), l = tonumber(level),
                                  online = online ~= false, dead = dead == true }
            end
        end
        return out
    end
    local units = { "player" }
    if n > 0 then for i = 1, 4 do units[#units + 1] = "party" .. i end end
    for _, unit in ipairs(units) do
        local name = unit == "player" and me() or ns.UnitFullName(unit)
        if name then
            local _, file = UnitClass(unit)
            out[#out + 1] = { name = name, unit = unit, g = 1, c = ns.Plain(file), l = tonumber(ns.Plain(UnitLevel(unit))), online = true }
        end
    end
    return out
end

local function call(name, ...)
    local f = _G[name]
    if type(f) ~= "function" then return nil end
    local ok, v = pcall(f, ...)
    if not ok then return nil end
    return ns.Plain(v)
end

-- One row: { name, unit, g, c, l, me, state = "ok"/"offline"/"dead"/"far", src = "read"/"self"/nil,
-- cons = classification, missing = { group keys }, ver, rep = the own report (XA) }.
local function readRow(m, versions)
    local r = { name = m.name, unit = m.unit, g = m.g, c = m.c, l = m.l, me = ns.SameName(m.name, me()), state = "ok" }
    r.ver = r.me and ns.VERSION or (versions[m.name:lower()] or nil)
    r.rep = RC.AnswerOf(m.name)
    if not m.online then
        r.state = "offline"
    elseif m.dead or call("UnitIsDeadOrGhost", m.unit) == true then
        r.state = "dead"
    elseif not r.me and call("UnitIsVisible", m.unit) == false then
        r.state = "far"
    end
    if r.state == "ok" then
        local ok, a = pcall(RR.Auras, r.me and "player" or m.unit)
        if ok then
            r.cons, r.src = RC.Classify(a.all), "read"
        end
    end
    if not r.cons and r.rep and r.rep.heard and time() - r.rep.at <= SELF_FRESH then
        r.cons, r.src = r.rep.cons, "self"
    end
    return r
end

-- Which buff groups count in this raid: the class is in it (a talent buff only when someone carries it).
local function needed(rows)
    lists()
    local classes, carried = {}, {}
    for _, r in ipairs(rows) do
        if r.c then classes[r.c] = true end
        for key in pairs(r.cons and r.cons.have or {}) do carried[key] = true end
    end
    local out = {}
    for _, g in ipairs(groups or {}) do
        if classes[g.class] and (not g.talent or carried[g.key]) then out[#out + 1] = g.key end
    end
    return out
end

-- The rows of the raid: { at, combat = "combat"/"lock"/nil, list = rows, need = group keys }. In
-- combat or the lockdown the rows of the last read, nothing read again.
function RC.Rows()
    local locked = RC.Locked()
    if locked and lastRows then
        return { at = lastRows.at, combat = locked, list = lastRows.list, need = lastRows.need }
    end
    local versions = {}
    for _, e in ipairs(ns.VersionSeen and ns.VersionSeen() or {}) do versions[e.name:lower()] = e.v end
    local list = {}
    if not locked then
        for _, m in ipairs(roster()) do list[#list + 1] = readRow(m, versions) end
    end
    local need = needed(list)
    for _, r in ipairs(list) do
        r.missing = {}
        -- the class buffs only from the auras read (an own report names no class buffs)
        if r.cons and r.src == "read" then
            for _, key in ipairs(need) do
                if not r.cons.have[key] then r.missing[#r.missing + 1] = key end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.g ~= b.g then return a.g < b.g end
        return a.name:lower() < b.name:lower()
    end)
    local out = { at = math.floor(time()), combat = locked, list = list, need = need }
    if not locked then lastRows = out end
    return out
end

-- The counts of the line "Es fehlt": { supplied = n, food = n, [group] = n }, of the rows with buffs.
function RC.Missing(rows)
    local out = { supplied = 0, food = 0 }
    for _, r in ipairs(rows.list) do
        if r.cons then
            if not RC.Supplied(r.cons) then out.supplied = out.supplied + 1 end
            if not r.cons.food then out.food = out.food + 1 end
            for _, key in ipairs(r.missing or {}) do out[key] = (out[key] or 0) + 1 end
        end
    end
    return out
end

-- "Es fehlt: 3 Fläschchen, 2 Essen, 1 Segen" or "Es fehlt nichts."
function RC.MissingText(rows)
    local m = RC.Missing(rows)
    local parts = {}
    if m.supplied > 0 then parts[#parts + 1] = L["%d Fläschchen"]:format(m.supplied) end
    if m.food > 0 then parts[#parts + 1] = L["%d Essen"]:format(m.food) end
    for _, key in ipairs(RC.GROUP_ORDER) do
        if (m[key] or 0) > 0 then parts[#parts + 1] = ("%d %s"):format(m[key], RC.GROUP_NAME[key]) end
    end
    if #parts == 0 then return L["Es fehlt nichts."] end
    return L["Es fehlt: %s"]:format(table.concat(parts, ", "))
end

-- The colour of a durability: red under the threshold, orange under 50, else nil.
function RC.DurColor(pct)
    if type(pct) ~= "number" then return nil end
    if pct < (ns.Get("raidcheck.durability") or 30) then return "red" end
    if pct < ORANGE then return "orange" end
    return nil
end

---------------------------------------------------------------------------
-- The chat line (optional, officers, click only)
---------------------------------------------------------------------------
-- The parts of the line: "Fläschchen: Anna, Bert", "Essen: Carl", "Haltbarkeit unter 30 %: Dora".
-- Only names of the raid list and fixed words.
function RC.ChatParts(rows)
    local flask, food, dur = {}, {}, {}
    for _, r in ipairs(rows.list) do
        if r.cons and not RC.Supplied(r.cons) then flask[#flask + 1] = r.name end
        if r.cons and not r.cons.food then food[#food + 1] = r.name end
        if r.rep and RC.DurColor(r.rep.dur) == "red" then dur[#dur + 1] = r.name end
    end
    local parts = {}
    if #flask > 0 then parts[#parts + 1] = L["Fläschchen: %s"]:format(table.concat(flask, ", ")) end
    if #food > 0 then parts[#parts + 1] = L["Essen: %s"]:format(table.concat(food, ", ")) end
    if #dur > 0 then parts[#parts + 1] = L["Haltbarkeit unter %d %%: %s"]:format(ns.Get("raidcheck.durability") or 30, table.concat(dur, ", ")) end
    return parts
end

-- Whether the button may be used now (the setting, the officer, not in the lockdown, in a raid).
function RC.CanSay()
    return ns.Get("raidcheck.chat") == true and ns.RaidCheckAllowed() and not RC.Locked() and homeRaid()
end

-- Says what is missing in the raid chat (two lines at most). Returns the number of lines, or nil and
-- the reason.
function RC.Say()
    if ns.Get("raidcheck.chat") ~= true then return nil, L["Die Chatzeile ist in den Einstellungen aus."] end
    if not ns.RaidCheckAllowed() then return nil, L["Der Raid-Check ist nur für Offiziere."] end
    if RC.Locked() then return nil, L["Nicht im Kampf."] end
    if not homeRaid() then return nil, L["Keine eigene Raidgruppe."] end
    local parts = RC.ChatParts(RC.Rows())
    if #parts == 0 then return nil, L["Es fehlt nichts."] end
    local lines = ns.ChatLines(L["Amisia Raid-Check: Es fehlt: "], parts, " · ")
    local n = 0
    for i = 1, math.min(#lines, CHAT_LINES) do
        if ns.Say(lines[i], "RAID", nil, { ttl = CHAT_TTL, key = "raidcheck" .. i }) then n = n + 1 end
    end
    return n
end

---------------------------------------------------------------------------
-- Settings and /amisia raidcheck
---------------------------------------------------------------------------
ns.RegisterSettings{ key = "raidcheck", label = L["Raid-Check"], order = 25, items = {
    { key = "raidcheck.answer", type = "toggle", label = L["Auf Raid-Check antworten"], default = true,
      tip = L["Fragt ein Offizier deines Raids (\"Prüfen\" oder ein Bereitschaftscheck), schickt Amisia ihm Haltbarkeit, Itemstufe, leere und unverzauberte Plätze, freie Talentpunkte und deine Fläschchen, Elixiere und Essen."] },
    { key = "raidcheck.lockouts", type = "toggle", label = L["Raid-IDs der Gilde mitteilen"], default = true,
      tip = L["Amisia merkt sich die Raid-IDs aller Charaktere dieses Kontos und nennt sie den Offizieren der Gilde (nach dem Login, nach einer neuen ID, auf Frage)."] },
    { key = "raidcheck.chat", type = "toggle", label = L["Chatzeile \"Es fehlt\" anbieten"], default = false, officer = true,
      tip = L["Ein Knopf auf der Seite Raid-Check schreibt, wem Fläschchen, Essen oder Haltbarkeit fehlt, in den Raid-Chat. Nur auf Klick, nie im Bosskampf."] },
    { key = "raidcheck.durability", type = "slider", label = L["Haltbarkeit rot unter (%)"], default = 30, min = 10, max = 90, step = 5,
      officer = true, tip = L["Darunter ist die Haltbarkeit rot (unter 50 % orange)."] },
}}

local function slotNames(list)
    local names = {}
    for _, inv in ipairs(list or {}) do names[#names + 1] = RC.SlotName(inv) end
    return #names > 0 and table.concat(names, ", ") or L["keine"]
end

-- The name of an inventory slot (the gear planner's).
function RC.SlotName(inv)
    for _, s in ipairs(RR.Slots()) do
        if s.inv == inv then return s.name end
    end
    return L["Platz %d"]:format(inv)
end
RC.SlotNames = slotNames

-- The own line for the chat (raiders: what the officer sees of them).
function RC.OwnLine()
    local o = RC.Own()
    local c = o.cons
    local parts = {}
    if c then
        parts[#parts + 1] = c.flask and L["Fläschchen ja"] or L["Fläschchen fehlt"]
        parts[#parts + 1] = L["Elixiere %d"]:format(#c.elixirs)
        parts[#parts + 1] = c.food and L["Essen ja"] or L["Essen fehlt"]
    else
        parts[#parts + 1] = L["Buffs nicht lesbar"]
    end
    parts[#parts + 1] = L["Haltbarkeit %s"]:format(o.dur and ("%d %%"):format(o.dur) or "-")
    parts[#parts + 1] = L["Itemstufe %s"]:format(o.ilvl and ("%.1f"):format(o.ilvl) or "-")
    parts[#parts + 1] = L["leer: %s"]:format(slotNames(o.empty))
    parts[#parts + 1] = L["unverzaubert: %s"]:format(slotNames(o.unench))
    parts[#parts + 1] = L["freie Talentpunkte %s"]:format(o.free and tostring(o.free) or "-")
    return L["Raid-Check: %s"]:format(table.concat(parts, " · "))
end

ns.RegisterSlash("raidcheck", { desc = L["Raid-Check: Buffs, Verbrauch, Ausrüstung und Raid-IDs"], run = function()
    if ns.RaidCheckAllowed() then
        if ns.ShowRaidCheck then ns.ShowRaidCheck() end
        return
    end
    ns.msg(RC.OwnLine())
    if ns.RaidIDsOwnLines then
        for _, line in ipairs(ns.RaidIDsOwnLines()) do ns.msg(line) end
    end
end })

-- for the tests
ns._raidcheck = { answers = function() return answers end,
                  reset = function() answers, lastAnswer, lastAsk, lastRows = {}, -1e9, -1e9, nil end }
