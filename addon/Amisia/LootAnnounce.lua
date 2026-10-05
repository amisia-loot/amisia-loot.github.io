-- Amisia loot lead: exactly one client per raid announces loot and answers !sr, without any sync.
-- That is the master looter under master loot, else the raid leader; Amisia must run in the
-- officer view. loot.lead = "me" makes this client the lead when the leader has no Amisia.
-- The lead names the items of every corpse once in the raid chat, with the reservers from the
-- raid: from the loot window (master loot or own looting) and from the group loot roll frames.
-- Every client marks reserved items on the roll frames with "SR".
local ADDON, ns = ...

local LM = Enum and Enum.LootMethod or {}
local MASTER = LM.Masterlooter or 2
local FREE = LM.Freeforall or 0
local PERSONAL = LM.Personal or 5

-- The loot method as a flag for master loot, with the master looter's party and raid index, and
-- a flag for a method that hands out items over group loot rolls (group loot, need before greed,
-- round robin: not master loot, free-for-all or personal loot). Both clients have
-- C_PartyInfo.GetLootMethod; an older one the global with "master".
local function lootMethod()
    local info = _G.C_PartyInfo
    if type(info) == "table" and type(info.GetLootMethod) == "function" then
        local ok, method, partyID, raidID = pcall(info.GetLootMethod)
        if ok then
            local rolls = type(method) == "number" and method ~= MASTER and method ~= FREE and method ~= PERSONAL
            return method == MASTER, partyID, raidID, rolls
        end
        return nil
    end
    local old = _G.GetLootMethod
    if type(old) == "function" then
        local ok, method, partyID, raidID = pcall(old)
        if ok then
            local rolls = type(method) == "string" and method ~= "master" and method ~= "freeforall" and method ~= "personalloot"
            return method == "master", partyID, raidID, rolls
        end
    end
    return nil
end

function ns.IsLootLead()
    if not IsInRaid() or not ns.IsOfficerView() then return false end
    if ns.Get("loot.lead") == "me" then return true end
    local master, partyID, raidID = lootMethod()
    if master then
        if raidID then return UnitIsUnit("raid" .. raidID, "player") and true or false end
        if partyID then return partyID == 0 end
    end
    -- no master loot, or no way to tell who loots: the leader leads
    return UnitIsGroupLeader("player") and true or false
end

---------------------------------------------------------------------------
-- What was announced: s.announced of the running recording (survives a /reload), else memory
---------------------------------------------------------------------------
local KEEP = 12 * 3600       -- keys older than this fall out on the next write
local ITEM_KEY_FOR = 600     -- an item-list key (no usable source) holds this long
local MAX_LINES = 8          -- item lines of one announcement
local BATCH = 1.5            -- group loot rolls starting within this make one announcement
local TTL = 600

-- kept on ns, so a second load of this file (the tests' /reload) shares it
ns.lootAnnounced = ns.lootAnnounced or {}

local function store()
    local s = ns.Active and ns.Active()
    if s then
        s.announced = type(s.announced) == "table" and s.announced or {}
        return s.announced
    end
    return ns.lootAnnounced
end

local function seen(key)
    local t = store()[key]
    if not t then return false end
    local age = time() - t
    if age >= KEEP then return false end
    if key:sub(1, 2) == "i:" then return age < ITEM_KEY_FOR end
    return true
end

local function remember(keys)
    local into, t = store(), time()
    for k, at in pairs(into) do
        if t - (tonumber(at) or 0) >= KEEP then into[k] = nil end
    end
    for _, k in ipairs(keys) do into[k] = t end
end

---------------------------------------------------------------------------
-- The announcement
---------------------------------------------------------------------------
local function raidNames()
    local out = {}
    for i = 1, GetNumGroupMembers() or 0 do
        local n = ns.FullName(ns.Plain((GetRaidRosterInfo(i))))
        if n then out[#out + 1] = n end
    end
    return out
end

-- "SR: Fraktur, Vulo Sturmwind x2 (+1 nicht im Raid)" or "frei"; second value: someone in the
-- raid reserved it.
local function reserversText(id, raid)
    local sr = AmisiaDB and AmisiaDB.softres
    local shown, outside = {}, 0
    for _, name in ipairs(ns.ReservedBy(id)) do
        local here = false
        for _, r in ipairs(raid) do
            if ns.SameName(r, name) then here = true break end
        end
        if here then
            local n = ns.SoftResTimes and ns.SoftResTimes(sr, id, name) or 1
            shown[#shown + 1] = n > 1 and ("%s x%d"):format(name, n) or name
        else
            outside = outside + 1
        end
    end
    local text = #shown > 0 and ("SR: " .. table.concat(shown, ", ")) or "frei"
    if outside > 0 then text = text .. (" (+%d nicht im Raid)"):format(outside) end
    return text, #shown > 0
end

local function items(n) return n == 1 and "1 Item" or ("%d Items"):format(n) end

-- head ("Amisia Loot (Illidan Sturmgrimm)"), then one line per item, at most 8, into the raid chat;
-- with loot.warning a raid warning as well, when this client may give one.
local function announce(head, links)
    local raid = raidNames()
    local lines, reserved = { ("%s: %s"):format(head, items(#links)) }, 0
    for i, e in ipairs(links) do
        local text, here = reserversText(e.id, raid)
        if here then reserved = reserved + 1 end
        if i <= MAX_LINES then lines[#lines + 1] = ("%d. %s %s"):format(i, e.link, text) end
    end
    if #links > MAX_LINES then lines[#lines + 1] = ("und %d weitere"):format(#links - MAX_LINES) end
    for _, line in ipairs(lines) do ns.Say(line, "RAID", nil, { ttl = TTL }) end
    if ns.Get("loot.warning") and (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
        ns.Say(("Loot: %s, %d reserviert. Liste im Schlachtzugschat."):format(items(#links), reserved),
            "RAID_WARNING", nil, { ttl = TTL })
    end
end

-- An item worth announcing: a link at loot.quality or better, no guild material, nothing ignored.
local function worth(link)
    link = ns.Plain(link)
    local id = ns.ItemID(link)
    if not id or ns.MATS[id] or ns.IGNORE[id] then return nil end
    local q = ns.LinkQuality(link)
    if not q or q < (tonumber(ns.Get("loot.quality")) or 4) then return nil end
    return id, link
end

local function plainString(v)
    v = ns.Plain(v)
    return (type(v) == "string" and v ~= "") and v or nil
end

-- The name of a slot's source for the head, or nil ("?" or secret).
local function sourceName(slot)
    if type(ns.LootSourceName) ~= "function" then return nil end
    local ok, name = pcall(ns.LootSourceName, slot)
    name = ok and plainString(name) or nil
    if name == "?" then return nil end
    return name
end

-- The items of the open loot window grouped by source, in slot order: { key, name, links }.
-- A source is the slot's GUID (GetLootSourceInfo), else the target's; without a usable one (secret
-- or missing) the sorted item ids are the key. Containers from the bags are left out.
local function lootGroups()
    local groups, byKey, loose = {}, {}, nil
    local sourceInfo = _G.GetLootSourceInfo
    for slot = 1, (GetNumLootItems and GetNumLootItems() or 0) do
        local id, link = worth(GetLootSlotLink(slot))
        if id then
            local raw, hasApi = nil, type(sourceInfo) == "function"
            if hasApi then
                local ok, v = pcall(sourceInfo, slot)
                raw = ok and v or nil
            end
            local guid = plainString(raw)
            local secret = guid == nil and type(raw) ~= "nil"
            local key, name
            if guid then
                if not guid:find("^Item%-") then key, name = "g:" .. guid, sourceName(slot) end
            elseif not secret then
                local target = plainString(UnitGUID and UnitGUID("target"))
                if target then key, name = "g:" .. target, plainString(UnitName("target")) end
            end
            if not (guid and guid:find("^Item%-")) then
                local g
                if key then
                    g = byKey[key]
                    if not g then
                        g = { key = key, name = name, links = {} }
                        byKey[key] = g
                        groups[#groups + 1] = g
                    end
                else
                    if not loose then
                        loose = { links = {} }
                        groups[#groups + 1] = loose
                    end
                    g = loose
                end
                g.links[#g.links + 1] = { id = id, link = link }
            end
        end
    end
    if loose then
        local ids, set = {}, {}
        for _, e in ipairs(loose.links) do
            if not set[e.id] then set[e.id] = true; ids[#ids + 1] = e.id end
        end
        table.sort(ids)
        loose.key = "i:" .. table.concat(ids, ",")
    end
    return groups
end

local function lootHead(g)
    return g.name and ("Amisia Loot (%s)"):format(g.name) or "Amisia Loot"
end

local lootOpen = false

local function onLootOpened(_, isFromItem)
    lootOpen = true
    -- Forever: loot from an item (a container, a bag) is no corpse
    if isFromItem == true then return end
    if not ns.Get("loot.announce") or not ns.IsLootLead() then return end
    -- under group loot the items are rolled for, and START_LOOT_ROLL announces them already
    if ns.Get("loot.groupLoot") and select(4, lootMethod()) then return end
    for _, g in ipairs(lootGroups()) do
        if not seen(g.key) then
            announce(lootHead(g), g.links)
            remember({ g.key })
        end
    end
end
ns.OnEvent("LOOT_OPENED", onLootOpened)
ns.OnEvent("LOOT_CLOSED", function() lootOpen = false end)

-- /amisia ansage: the open loot window once more, without the key check.
local function announceAgain()
    if not ns.IsOfficerView() then ns.msg("Ansagen nur in der Offiziersansicht.") return end
    if not lootOpen then ns.msg("Kein Lootfenster offen.") return end
    if not IsInRaid() then ns.msg("Ansagen nur im Raid.") return end
    local groups = lootGroups()
    if #groups == 0 then ns.msg("Nichts anzusagen: kein Item ab der Qualitätsgrenze.") return end
    for _, g in ipairs(groups) do
        announce(lootHead(g), g.links)
        remember({ g.key })
    end
end

---------------------------------------------------------------------------
-- Group loot: START_LOOT_ROLL(rollID, rollTime), collected over 1.5 s
---------------------------------------------------------------------------
local batch   -- { list = { { rollID, id, link, minute } } } while collecting

local function rollKey(rollID, minute) return ("r:%s:%d"):format(tostring(rollID), minute) end

-- A roll counts as announced when its id was announced within the last minutes (a roll lasts
-- a few minutes at most; ids come back after a while).
local function rollSeen(rollID)
    local m = math.floor(time() / 60)
    for d = 0, 5 do
        if seen(rollKey(rollID, m - d)) then return true end
    end
    return false
end

local function flush()
    local b = batch
    batch = nil
    if not b or not IsInRaid() then return end
    local links, keys = {}, {}
    for _, e in ipairs(b.list) do
        if not rollSeen(e.rollID) then
            links[#links + 1] = e
            keys[#keys + 1] = rollKey(e.rollID, e.minute)
        end
    end
    if #links == 0 then return end
    announce("Amisia Würfeln", links)
    remember(keys)
end

local function onStartRoll(rollID)
    rollID = ns.Plain(rollID)
    if type(rollID) ~= "number" then return end
    if not ns.Get("loot.announce") or not ns.Get("loot.groupLoot") or not ns.IsLootLead() then return end
    local fn = _G.GetLootRollItemLink
    if type(fn) ~= "function" then return end
    local ok, raw = pcall(fn, rollID)
    if not ok then return end
    local id, link = worth(raw)
    if not id or rollSeen(rollID) then return end
    if batch then
        for _, e in ipairs(batch.list) do
            if e.rollID == rollID then return end
        end
    else
        batch = { list = {} }
        C_Timer.After(BATCH, flush)
    end
    batch.list[#batch.list + 1] = { rollID = rollID, id = id, link = link, minute = math.floor(time() / 60) }
end
ns.OnEvent("START_LOOT_ROLL", onStartRoll)

---------------------------------------------------------------------------
-- SR mark on the group loot roll frames (softres.lootMark, every client)
-- Both clients have GroupLootFrame1-4 with .rollID and .IconFrame; the mark follows each OnShow,
-- so a frame used again for another roll shows the mark of that roll.
---------------------------------------------------------------------------
local GOLD = { 0.89, 0.72, 0.34 }
local marks = setmetatable({}, { __mode = "k" })    -- roll frame -> font string
local hooked = setmetatable({}, { __mode = "k" })

local function markRoll(frame)
    local mark = marks[frame]
    local text
    local fn = _G.GetLootRollItemLink
    if ns.Get("softres.lootMark") and type(fn) == "function" then
        local ok, link = pcall(fn, ns.Plain(frame.rollID))
        local id = ok and ns.ItemID(ns.Plain(link)) or nil
        local names = id and ns.ReservedBy(id) or {}
        if #names > 0 then
            text = "SR"
            local me, roster = ns.UnitFullName("player"), ns.GroupRoster()
            for _, n in ipairs(names) do
                if ns.SameNameIn(n, me, roster) then text = "SR (du)" break end
            end
        end
    end
    if not text then
        if mark then mark:Hide() end
        return
    end
    if not mark then
        local parent = type(frame.IconFrame) == "table" and frame.IconFrame or frame
        mark = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        mark:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -1)
        mark:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        marks[frame] = mark
    end
    mark:SetText(text)
    mark:Show()
end

local function onRollFrameShow(frame)
    local ok, err = pcall(markRoll, frame)
    if not ok then
        local handler = geterrorhandler and geterrorhandler()
        if handler then handler(err) end
    end
end

local function hookRollFrames()
    for i = 1, tonumber(_G.NUM_GROUP_LOOT_FRAMES) or 4 do
        local f = _G["GroupLootFrame" .. i]
        if type(f) == "table" and type(f.HookScript) == "function" and not hooked[f] then
            hooked[f] = true
            f:HookScript("OnShow", onRollFrameShow)
        end
    end
end
hookRollFrames()
ns.OnEvent("PLAYER_ENTERING_WORLD", hookRollFrames)

-- For tests and the window: the mark a roll frame shows, or nil.
function ns.RollMarkText(frame)
    local m = marks[frame]
    return (m and m:IsShown()) and m:GetText() or nil
end

---------------------------------------------------------------------------
-- Settings and command
---------------------------------------------------------------------------
ns.RegisterSettings{ key = "loot", label = "Loot-Ansage", order = 22, officer = true, items = {
    { key = "loot.announce", type = "toggle", label = "Loot im Schlachtzugschat ansagen", default = true,
      tip = "Einmal pro Leiche, nur als Lootleitung. Gildenmaterialien nie." },
    { key = "loot.quality", type = "choice", label = "Ansagen ab Qualität", default = 4,
      values = { { 3, "Selten" }, { 4, "Episch" }, { 5, "Legendär" } } },
    { key = "loot.groupLoot", type = "toggle", label = "Auch bei Gruppenplündern ansagen", default = true,
      tip = "Aus den Würfelfenstern: Würfe, die zusammen beginnen, stehen in einer Ansage." },
    { key = "loot.warning", type = "toggle", label = "Zusätzlich eine Schlachtzugswarnung", default = false,
      tip = "Nur als Leiter oder Assistent." },
    { key = "loot.lead", type = "choice", label = "Ansage und !sr-Antworten", default = "auto",
      values = { { "auto", "Plündermeister, sonst Leiter" }, { "me", "Immer ich" } },
      tip = "Antwortet nur ein Amisia im Raid, posten zwei Offiziere nicht doppelt. \"Immer ich\", wenn der Leiter Amisia nicht hat." },
}}

ns.RegisterSlash("ansage", { aliases = { "announce" }, officer = true, desc = "offenes Lootfenster erneut ansagen",
    run = function() announceAgain() end })
