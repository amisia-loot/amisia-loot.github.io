-- Amisia guild bank needs: officers set a minimum stock per material (and an optional target), the
-- list goes to the guild by addon message and only a list from a verified officer counts; members
-- pledge donations ("Spenden zusagen"), the pledges reach every Amisia client of the guild and
-- expire after some days. The shortfalls (the last guild bank count against the needs) feed the
-- Bank page, a text for the chat or Discord and the BQ and BP lines of the export.
--
-- Why addon messages and not a pasted text block: the needs change often and members have to see
-- them without anybody pasting anything; the trust rules of the sync (Trust.lua: the sender as the
-- server names it, its rank from the guild roster) already decide who is an officer.
--
-- Messages (Comm.lua checks their fields):
--   GN <rev> <part> <parts> <set by> <id:min:target,...|->  the list of an officer, in parts of 8
--   GQ <rev>                     "who has a newer list?" (after the login); officers answer GN by
--                                whisper, members answer an asking officer with their own pledges
--   GP <itemID> <count> <epoch>  a pledge (count 0 takes it back), first-hand only
-- Stored in AmisiaDB.bankNeeds = { rev, by, list = { [id] = { min, target } } } and
-- AmisiaDB.bankPledges = { { name, item, count, t } }.
local ADDON, ns = ...
local L = ns.L

local MAX_NEEDS = 40          -- materials with a need at most (the size of the material list)
local PER_PART = 8            -- needs in one GN message (8 * 19 bytes + the head stay below 250; 40 / 8 = 5 parts, as Comm.lua allows)
local MAX_COUNT = 99999
local MAX_PLEDGES = 200
local SEND_AFTER = 2          -- seconds a change waits, so several changes go out as one list
local ASK_AFTER, ASK_SPREAD = 25, 20   -- the question after the login
local PART_WAIT = 30          -- seconds a list waits for its missing parts

local DB
local sendPending = false
local incoming = {}           -- sender (lower case) -> { rev, n, parts, at }

local function msg(text) if ns.msg then ns.msg(text) end end
local function now() return math.floor(time()) end
local function me() return ns.UnitFullName("player") or "?" end
local function count(v)
    v = tonumber(v)
    if not v or v ~= v or v < 0 or v > MAX_COUNT or v % 1 ~= 0 then return nil end
    return v
end
local function itemId(v)
    v = tonumber(v)
    if not v or v < 1 or v > 9999999 or v % 1 ~= 0 then return nil end
    return v
end
local function inGuild() return type(_G.IsInGuild) == "function" and ns.Plain(IsInGuild()) == true end
local function pledgeDays() return tonumber(ns.Get("bank.pledgeDays")) or 7 end

local function changed()
    ns.Fire("BANK_NEEDS_CHANGED")
    if ns.Refresh then ns.Refresh() end
end

---------------------------------------------------------------------------
-- The saved list
---------------------------------------------------------------------------
local function needs()
    if not DB then return { rev = 0, list = {} } end
    return DB.bankNeeds
end

-- { rev, by, list = { [itemID] = { min, target } } }; an empty list before anything was set.
function ns.BankNeeds() return needs() end

local function cleanList(list)
    local out, n = {}, 0
    if type(list) ~= "table" then return out end
    for id, e in pairs(list) do
        id = itemId(id)
        local min = type(e) == "table" and count(e.min)
        local target = type(e) == "table" and (e.target == nil and 0 or count(e.target))
        if id and min and target and (min > 0 or target > 0) and (target == 0 or target >= min) and n < MAX_NEEDS then
            out[id] = { min = min, target = target > 0 and target or nil }
            n = n + 1
        end
    end
    return out
end

-- Drops pledges that ran out (pledgeDays) or are broken; keeps the newest 200.
local function prunePledges()
    if not DB then return end
    local keep, limit = {}, now() - pledgeDays() * 86400
    for _, p in ipairs(DB.bankPledges) do
        if type(p) == "table" and type(p.name) == "string" and p.name ~= "" and itemId(p.item) and count(p.count)
            and p.count > 0 and tonumber(p.t) and p.t >= limit then
            keep[#keep + 1] = p
        end
    end
    if #keep > MAX_PLEDGES then
        table.sort(keep, function(a, b) return a.t > b.t end)
        for i = #keep, MAX_PLEDGES + 1, -1 do keep[i] = nil end
    end
    DB.bankPledges = keep
end

-- On ADDON_LOADED (and in tests): the saved needs and pledges in shape.
function ns.BankNeedsLoaded(root)
    DB = root
    local n = type(root.bankNeeds) == "table" and root.bankNeeds or {}
    root.bankNeeds = { rev = tonumber(n.rev) or 0, by = type(n.by) == "string" and n.by or nil, list = cleanList(n.list) }
    root.bankPledges = type(root.bankPledges) == "table" and root.bankPledges or {}
    prunePledges()
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name == ADDON and AmisiaDB then ns.BankNeedsLoaded(AmisiaDB) end
end)

---------------------------------------------------------------------------
-- Sending the list
---------------------------------------------------------------------------
local function entries()
    local ids = {}
    for id in pairs(needs().list) do ids[#ids + 1] = id end
    table.sort(ids)
    local out = {}
    for i, id in ipairs(ids) do
        local e = needs().list[id]
        out[i] = ("%d:%d:%d"):format(id, e.min, e.target or 0)
    end
    return out
end

local function sendNeeds(chan, target)
    if not (ns.CommReady and ns.CommReady()) then return false end
    local all, n = entries(), needs()
    local parts = math.max(1, math.ceil(#all / PER_PART))
    local by = ns.ExportName(n.by or me())
    for p = 1, parts do
        local chunk = {}
        for i = (p - 1) * PER_PART + 1, math.min(#all, p * PER_PART) do chunk[#chunk + 1] = all[i] end
        local fields = { tostring(n.rev), tostring(p), tostring(parts), by, #chunk > 0 and table.concat(chunk, ",") or "-" }
        local ok = ns.CommSend("GN", fields, chan, target,
            { key = "GN:" .. chan .. ":" .. tostring(target or "") .. ":" .. p, ttl = 120, low = chan == "WHISPER" or nil })
        if not ok then return false end
    end
    return true
end

local function scheduleSend()
    if sendPending then return end
    sendPending = true
    C_Timer.After(SEND_AFTER, function()
        sendPending = false
        if inGuild() then sendNeeds("GUILD") end
    end)
end

-- Sets the need of a material (an officer): min and target as counts, target 0 or nil for none;
-- 0 and 0 take the need away. Returns ok and the reason.
function ns.SetBankNeed(id, min, target)
    if not DB then return false, L["Amisia ist noch nicht geladen."] end
    if not ns.IsOfficerView() then return false, L["Den Bedarf der Gildenbank setzen nur Offiziere."] end
    id = itemId(id)
    min = count(min or 0)
    target = count(target or 0)
    if not id then return false, L["Kein Gegenstand erkannt."] end
    if not min or not target then return false, L["Ungültige Anzahl (0 bis 99999)."] end
    if target > 0 and target < min then return false, L["Das Ziel liegt unter dem Minimum."] end
    local list = needs().list
    if min == 0 and target == 0 then
        if not list[id] then return true end
        list[id] = nil
    else
        if not list[id] then
            local n = 0
            for _ in pairs(list) do n = n + 1 end
            if n >= MAX_NEEDS then return false, L["Höchstens %d Materialien mit Bedarf."]:format(MAX_NEEDS) end
        end
        list[id] = { min = min, target = target > 0 and target or nil }
    end
    local n = needs()
    n.rev = math.max(now(), (n.rev or 0) + 1)
    n.by = me()
    scheduleSend()
    changed()
    return true
end

---------------------------------------------------------------------------
-- Receiving a list
---------------------------------------------------------------------------
local function parseEntries(text, into)
    if text == "-" then return true end
    for e in (text .. ","):gmatch("([^,]*),") do
        local id, min, target = e:match("^(%d+):(%d+):(%d+)$")
        id, min, target = itemId(id), count(min), count(target)
        if not id or not min or not target then return false end
        into[id] = { min = min, target = target }
    end
    return true
end

local function applyList(name, set)
    local list = {}
    for i = 1, set.n do
        if not parseEntries(set.parts[i], list) then return end
    end
    local n = needs()
    if set.rev <= (n.rev or 0) then return end
    DB.bankNeeds = { rev = set.rev, by = set.by, list = cleanList(list) }
    changed()
    if ns.IsOfficerView() then
        local c = 0
        for _ in pairs(DB.bankNeeds.list) do c = c + 1 end
        msg(L["Bedarf der Gildenbank von %s übernommen (%d Materialien)."]:format(set.by, c))
    end
end

ns.CommOn("GN", function(sender, f)
    if not DB then return end
    local name = ns.TrustName(sender)
    if not name then return end
    local rev, part, parts = tonumber(f[1]), tonumber(f[2]), tonumber(f[3])
    ns.TrustWait(name, "officer", function(ok)
        if not ok or rev <= (needs().rev or 0) then return end
        local key, t = name:lower(), GetTime()
        local set = incoming[key]
        if not set or set.rev ~= rev or set.n ~= parts or t - set.at > PART_WAIT then
            set = { rev = rev, n = parts, parts = {}, got = 0, by = (f[4]:gsub("_", " ")) }
            incoming[key] = set
        end
        set.at = t
        if not set.parts[part] then
            set.parts[part] = f[5]
            set.got = set.got + 1
        end
        if set.got < set.n then return end
        incoming[key] = nil
        applyList(name, set)
    end)
end)

---------------------------------------------------------------------------
-- Pledges
---------------------------------------------------------------------------
local function findPledge(name, id)
    for i, p in ipairs(DB.bankPledges) do
        if p.item == id and ns.SameName(p.name, name) then return p, i end
    end
end

-- Stores a pledge (count 0 removes it); t decides between two of the same name and item. Returns
-- true when something changed.
local function storePledge(name, id, n, t)
    local p, i = findPledge(name, id)
    if p and t < (p.t or 0) then return false end
    if n == 0 then
        if not p then return false end
        table.remove(DB.bankPledges, i)
        return true
    end
    if p then
        if p.count == n and p.t == t then return false end
        p.count, p.t = n, t
    else
        DB.bankPledges[#DB.bankPledges + 1] = { name = name, item = id, count = n, t = t }
    end
    prunePledges()
    return true
end

-- The active pledges: { name, item, count, t, expires }, by material, then oldest first.
function ns.BankPledgeList()
    if not DB then return {} end
    prunePledges()
    local out, days = {}, pledgeDays()
    for _, p in ipairs(DB.bankPledges) do
        out[#out + 1] = { name = p.name, item = p.item, count = p.count, t = p.t, expires = p.t + days * 86400 }
    end
    table.sort(out, function(a, b)
        if a.item ~= b.item then return a.item < b.item end
        if a.t ~= b.t then return a.t < b.t end
        return a.name < b.name
    end)
    return out
end

local function sendPledge(p, chan, target)
    return ns.CommSend("GP", { tostring(p.item), tostring(p.count), tostring(p.t) }, chan, target,
        { key = "GP:" .. p.item .. ":" .. tostring(target or ""), ttl = 300, low = chan == "WHISPER" or nil })
end

-- The own pledge for a needed material: n pieces, 0 takes it back. Returns ok and the reason.
function ns.PledgeBankNeed(id, n)
    if not DB then return false, L["Amisia ist noch nicht geladen."] end
    id, n = itemId(id), count(n)
    if not id or not n then return false, L["Ungültige Anzahl (0 bis 99999)."] end
    if n > 0 and not needs().list[id] then return false, L["Für dieses Material gibt es keinen Bedarf."] end
    local t = now()
    if not storePledge(me(), id, n, t) and n > 0 then return true end
    if inGuild() and ns.CommReady and ns.CommReady() then sendPledge({ item = id, count = n, t = t }, "GUILD") end
    changed()
    return true
end

-- An officer ticks a pledge off (the donation came in, or it will not): on this client only.
function ns.RemovePledge(name, id)
    if not DB then return false end
    local p, i = findPledge(name, tonumber(id))
    if not p then return false end
    table.remove(DB.bankPledges, i)
    if ns.SameName(name, me()) and inGuild() and ns.CommReady and ns.CommReady() then
        sendPledge({ item = p.item, count = 0, t = now() }, "GUILD")
    end
    changed()
    return true
end

ns.CommOn("GP", function(sender, f)
    if not DB then return end
    local name = ns.TrustName(sender)
    if not name then return end
    local id, n, t = itemId(f[1]), count(f[2]), tonumber(f[3])
    if not id or not n or not t then return end
    t = math.min(t, now())
    if n > 0 and t < now() - pledgeDays() * 86400 then return end
    ns.TrustWait(name, "member", function(ok)
        if not ok then return end
        local before = findPledge(name, id)
        local had = before and before.count
        if not storePledge(name, id, n, t) then return end
        changed()
        if n > 0 and had ~= n and ns.IsOfficerView() then
            msg(L["%s sagt %d %s für die Gildenbank zu."]:format(name, n, ns.ItemName(id)))
        end
    end)
end)

---------------------------------------------------------------------------
-- The question after the login
---------------------------------------------------------------------------
function ns.AskBankNeeds()
    if not DB or not inGuild() or not (ns.CommReady and ns.CommReady()) then return false end
    return ns.CommSend("GQ", { tostring(needs().rev or 0) }, "GUILD", nil, { key = "GQ", ttl = 120, low = true }) and true or false
end

-- A delay of 0 to n seconds that differs per character (from its name), so the clients of a guild
-- do not all ask or answer at once; no random numbers (the other parts' jitter keeps its sequence).
local function spread(n)
    local h = ns.Checksum and tonumber(ns.Checksum(me()):sub(1, 6), 16) or 0
    return (h % (n * 10)) / 10
end

ns.CommOn("GQ", function(sender, f)
    if not DB then return end
    local name = ns.TrustName(sender)
    if not name then return end
    local asked = tonumber(f[1]) or 0
    ns.TrustWait(name, "member", function(ok)
        if not ok then return end
        -- an officer with a newer list answers with it
        local n = needs()
        if (n.rev or 0) > asked and next(n.list) ~= nil and ns.SelfIsOfficer(true) then
            C_Timer.After(1 + spread(3), function() sendNeeds("WHISPER", sender) end)
        end
        -- an asking officer gets the own pledges again (one may have been offline)
        if ns.IsVerifiedOfficer(name) == true then
            prunePledges()
            local mine = me()
            for _, p in ipairs(DB.bankPledges) do
                if ns.SameName(p.name, mine) then sendPledge(p, "WHISPER", sender) end
            end
        end
    end)
end)

local asked = false
ns.OnEvent("PLAYER_LOGIN", function()
    if asked then return end
    asked = true
    C_Timer.After(ASK_AFTER + spread(ASK_SPREAD), function() ns.AskBankNeeds() end)
end)

---------------------------------------------------------------------------
-- Shortfalls and the copy text
---------------------------------------------------------------------------
-- The needed materials against the last guild bank count: { id, min, target, have (nil: not
-- counted), short (missing to the minimum, else to the target), level ("low" below the minimum,
-- "target" below the target, "ok", "unknown" without a count), pledged }; in the order of the
-- material list, then by name.
function ns.BankNeedList()
    local out = {}
    if not DB then return out end
    local counts = DB.bank and DB.bank.counts
    local pledged = {}
    for _, p in ipairs(ns.BankPledgeList()) do pledged[p.item] = (pledged[p.item] or 0) + p.count end
    local order = {}
    for i, id in ipairs(ns.MAT_ORDER) do order[id] = i end
    for id, e in pairs(needs().list) do
        local have = counts and tonumber(counts[id]) or nil
        local short, level = 0, "ok"
        if not have then
            short, level = nil, "unknown"
        elseif have < e.min then
            short, level = e.min - have, "low"
        elseif e.target and have < e.target then
            short, level = e.target - have, "target"
        end
        out[#out + 1] = { id = id, min = e.min, target = e.target, have = have, short = short, level = level,
                          pledged = pledged[id] or 0, name = ns.ItemName(id) }
    end
    table.sort(out, function(a, b)
        local oa, ob = order[a.id] or 999, order[b.id] or 999
        if oa ~= ob then return oa < ob end
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    return out
end

-- The shortfalls as plain text for the guild chat or Discord, one material per line.
function ns.BankNeedText()
    local lines = {}
    local bank = DB and DB.bank
    lines[1] = bank and bank.at and L["Gildenbank: Bedarf (Zählung vom %s)"]:format(ns.FmtDayTime(bank.at))
        or L["Gildenbank: Bedarf (noch nicht gezählt)"]
    local any = false
    for _, r in ipairs(ns.BankNeedList()) do
        if r.level == "low" or r.level == "target" then
            any = true
            local need = r.level == "low" and r.min or r.target
            local line = L["%s: %d von %d (fehlen %d)"]:format(r.name, r.have, need, r.short)
            if r.level == "target" then line = L["%s: %d von %d (bis zum Ziel fehlen %d)"]:format(r.name, r.have, need, r.short) end
            if r.pledged > 0 then line = line .. L[", zugesagt %d"]:format(r.pledged) end
            lines[#lines + 1] = "- " .. line
        elseif r.level == "unknown" then
            any = true
            lines[#lines + 1] = "- " .. L["%s: Bedarf %d, Bestand unbekannt"]:format(r.name, r.min > 0 and r.min or r.target)
        end
    end
    if not any then lines[#lines + 1] = L["Es fehlt nichts."] end
    lines[#lines + 1] = L["Spenden bitte in die Gildenbank. Zusagen im Addon: /amisia > Gildenbank > Bedarf."]
    return table.concat(lines, "\n")
end

-- Whether the needs or pledges changed since the last export that carried them.
function ns.BankNeedsPending()
    if not DB then return false end
    local mark = DB.exportedNeeds or 0
    if (needs().rev or 0) > mark and (next(needs().list) ~= nil or mark > 0) then return true end
    for _, p in ipairs(DB.bankPledges) do if (p.t or 0) > mark then return true end end
    return false
end

function ns.MarkBankNeedsExported()
    if DB then DB.exportedNeeds = now() end
end
-- The setting bank.pledgeDays (how long a pledge counts, on this client) is in the "bank" section
-- of Core.lua.
