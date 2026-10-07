-- Amisia raid materials: the list of guild materials is learned, not named in the code. A trade
-- good (or reagent) of the quality setting that drops in a loot window, is looted or is handed out
-- while a raid is recorded goes into AmisiaDB.mats = { [itemID] = { name, q, first, manual, hide } }.
-- ns.MATS and ns.MAT_ORDER (Core.lua) are rebuilt from it in place, in the order first seen, so the
-- material loot (L lines), the guild bank count (K/B lines), the pages and the loot announcement
-- read it as before. An officer takes a material out (it stays remembered as hidden, so it is not
-- learned again) or adds one by link.
local ADDON, ns = ...

local CAP = 40            -- materials in the list at most
local HIDDEN_CAP = 100    -- materials taken out that are remembered, oldest go first
ns.MAT_CAP = CAP

-- Item classes of raid materials: trade goods, and reagents (the class some raid drops of the
-- classic item data carry). Trade goods of the enchanting subclass come from disenchanting.
local ItemClass = Enum and Enum.ItemClass
local CLASS_TRADEGOODS = ItemClass and ItemClass.Tradegoods or 7
local CLASS_REAGENT = ItemClass and ItemClass.Reagent or 5
local SUB_ENCHANTING = 12

local DB          -- AmisiaDB, set by MatsLoaded
local fullNoted   -- the "list is full" note was given this session

local function msg(text) if ns.msg then ns.msg(text) end end

local function visible(e) return type(e) == "table" and not e.hide end

-- Item class and subclass, also for items the client has not cached (GetItemInfoInstant).
local function itemClass(id)
    local instant = C_Item and C_Item.GetItemInfoInstant
    if instant then
        local _, _, _, _, _, class, sub = instant(id)
        if class then return class, sub end
    end
    local info = C_Item and C_Item.GetItemInfo
    if info then
        local r = { info(id) }
        return r[12], r[13]
    end
    return nil
end

function ns.IsMatClass(id)
    local class, sub = itemClass(id)
    if class == CLASS_REAGENT then return true end
    return class == CLASS_TRADEGOODS and sub ~= SUB_ENCHANTING
end

local function linkName(link)
    return type(link) == "string" and link:match("|h%[(.-)%]|h") or nil
end

local function nameOf(id, link)
    local known = DB and DB.itemNames and DB.itemNames[id]
    return linkName(link) or (C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(id))
        or (known and known.n) or ("Item " .. id)
end

local function qualityOf(id, link, q)
    q = tonumber(q) or ns.LinkQuality(link)
    if q then return q end
    local known = DB and DB.itemNames and DB.itemNames[id]
    if known and tonumber(known.q) and known.q > 0 then return known.q end
    if C_Item and C_Item.GetItemInfo then
        local _, _, iq = C_Item.GetItemInfo(id)
        return tonumber(iq)
    end
    return nil
end

local function countVisible()
    local n = 0
    for _, e in pairs(DB.mats) do if visible(e) then n = n + 1 end end
    return n
end

-- The visible materials in the order first seen: { id, name, q, first, manual }.
function ns.MatEntries()
    local out = {}
    if not (DB and DB.mats) then return out end
    for id, e in pairs(DB.mats) do
        if visible(e) then out[#out + 1] = { id = id, name = e.name, q = e.q, first = e.first, manual = e.manual } end
    end
    table.sort(out, function(a, b)
        if a.first ~= b.first then return a.first < b.first end
        return a.id < b.id
    end)
    return out
end

-- The saved entry of a material, or nil.
function ns.MatInfo(id)
    return DB and DB.mats and DB.mats[id] or nil
end

function ns.HiddenMatCount()
    local n = 0
    for _, e in pairs(DB and DB.mats or {}) do if type(e) == "table" and e.hide then n = n + 1 end end
    return n
end

-- ns.MATS and ns.MAT_ORDER from AmisiaDB.mats, filled in place (other files hold the tables).
local function rebuild()
    wipe(ns.MATS)
    wipe(ns.MAT_ORDER)
    for i, e in ipairs(ns.MatEntries()) do
        ns.MATS[e.id] = e.name
        ns.MAT_ORDER[i] = e.id
    end
end
ns.RebuildMats = rebuild

local function changed()
    rebuild()
    if ns.Refresh then ns.Refresh() end
end

local function pruneHidden()
    local hidden = {}
    for id, e in pairs(DB.mats) do
        if type(e) == "table" and e.hide then hidden[#hidden + 1] = { id = id, at = tonumber(e.hide) or 0 } end
    end
    if #hidden <= HIDDEN_CAP then return end
    table.sort(hidden, function(a, b) if a.at ~= b.at then return a.at < b.at end return a.id < b.id end)
    for i = 1, #hidden - HIDDEN_CAP do DB.mats[hidden[i].id] = nil end
end

-- Puts an item on the list when it qualifies; first: when it was seen. Returns true when it is new.
local function learn(id, link, q, first)
    if not (DB and DB.mats) or not ns.Get("mats.learn") then return false end
    id = tonumber(id)
    if not id or DB.mats[id] ~= nil or ns.IGNORE[id] then return false end
    q = qualityOf(id, link, q)
    if not q or q < (tonumber(ns.Get("mats.quality")) or 2) then return false end
    if not ns.IsMatClass(id) then return false end
    if countVisible() >= CAP then
        if not fullNoted then
            fullNoted = true
            msg(("Die Materialliste ist voll (%d). /amisia mats weg <Link> macht Platz."):format(CAP))
        end
        return false
    end
    local name = nameOf(id, link)
    DB.mats[id] = { name = name, q = q, first = first or time() }
    if ns.RememberItem and not (DB.itemNames and DB.itemNames[id]) then ns.RememberItem(id, link, q) end
    return true
end

-- An item met in the running raid recording: looted, in a loot window or handed out.
function ns.LearnMat(id, link, q)
    if not (ns.Active and ns.Active()) then return false end
    if not learn(id, link, q) then return false end
    changed()
    if ns.IsOfficerView() then
        msg(("Neues Raidmaterial: %s. /amisia mats weg <Link> nimmt es wieder heraus."):format(ns.MATS[tonumber(id)] or "?"))
    end
    return true
end

-- By hand (an officer): any item. Returns ok and the message for the chat.
function ns.AddMat(item)
    if not (DB and DB.mats) then return false, "Amisia ist noch nicht geladen." end
    local id = tonumber(item) or ns.ItemID(item)
    if not id then return false, "Kein Gegenstand erkannt. Mit Shift-Klick einen Link einfügen." end
    local link = type(item) == "string" and item or nil
    local e = DB.mats[id]
    if visible(e) then return false, ("%s steht schon in der Liste."):format(e.name) end
    if countVisible() >= CAP then
        return false, ("Die Materialliste ist voll (%d). Zuerst eins herausnehmen."):format(CAP)
    end
    if e then
        e.hide = nil
    else
        local q = qualityOf(id, link)
        DB.mats[id] = { name = nameOf(id, link), q = q or 0, first = time(), manual = true }
        if ns.RememberItem and not (DB.itemNames and DB.itemNames[id]) then ns.RememberItem(id, link, q) end
    end
    changed()
    return true, ("%s steht jetzt in der Materialliste."):format(DB.mats[id].name)
end

-- Takes a material out; it stays remembered, so it is not learned again.
function ns.RemoveMat(item)
    if not (DB and DB.mats) then return false, "Amisia ist noch nicht geladen." end
    local id = tonumber(item) or ns.ItemID(item)
    local e = id and DB.mats[id]
    if not visible(e) then return false, "Das steht nicht in der Materialliste." end
    e.hide = time()
    pruneHidden()
    changed()
    return true, ("%s ist aus der Materialliste heraus. /amisia mats add <Link> holt es zurück."):format(e.name)
end

-- Raids recorded before the list was learned teach their materials once.
local function learnFromSessions()
    for _, s in ipairs(DB.sessions or {}) do
        local start = tonumber(s.start) or 0
        for _, l in ipairs(s.loot or {}) do learn(l.item, nil, nil, tonumber(l.t) or start) end
        for _, l in ipairs(s.items or {}) do learn(l.item, nil, nil, tonumber(l.t) or start) end
        for _, d in pairs(s.drops or {}) do
            if type(d) == "table" then
                for id in pairs(d.items or {}) do learn(id, nil, nil, tonumber(d.t) or start) end
            end
        end
        for _, a in ipairs(s.awards or {}) do learn(a.item, nil, nil, tonumber(a.t) or start) end
    end
end

-- On ADDON_LOADED (Core.lua), after the raids are in shape: cleans the saved list, learns from the
-- raids recorded before it once, and builds ns.MATS. Loading twice changes nothing.
function ns.MatsLoaded(root)
    DB = root
    root.mats = type(root.mats) == "table" and root.mats or {}
    for id, e in pairs(root.mats) do
        local ok = type(id) == "number" and id > 0 and id % 1 == 0 and type(e) == "table"
            and type(e.name) == "string" and e.name ~= "" and tonumber(e.first)
        if ok then
            e.first = tonumber(e.first)
            e.q = tonumber(e.q) or 0
            if e.hide ~= nil and not tonumber(e.hide) then e.hide = 0 end
        else
            root.mats[id] = nil
        end
    end
    if root.matsScan ~= 1 then
        learnFromSessions()
        root.matsScan = 1
    end
    rebuild()
end

---------------------------------------------------------------------------
-- Settings and the command
---------------------------------------------------------------------------
ns.RegisterSettings{ key = "mats", label = "Raidmaterialien", order = 41, officer = true, items = {
    { key = "mats.learn", type = "toggle", label = "Materialien im Raid lernen", default = true,
      tip = "Handwerkswaren, die in einer Raidaufnahme droppen, geplündert oder vergeben werden, kommen von selbst in die Materialliste (höchstens 40)." },
    { key = "mats.quality", type = "choice", label = "Lernen ab Qualität", default = 2,
      values = { { 1, "Weiß" }, { 2, "Grün" }, { 3, "Blau" }, { 4, "Episch" } },
      tip = "Schlechtere Handwerkswaren lernt Amisia nicht. Von Hand lässt sich jeder Gegenstand eintragen." },
}}

ns.RegisterSlash("mats", { aliases = { "materialien" }, args = "[add|weg <Link>]",
    desc = "Raidmaterialien zeigen, von Hand eintragen oder herausnehmen", run = function(rest)
        local word, arg = (rest or ""):match("^(%S*)%s*(.-)%s*$")
        word = (word or ""):lower()
        if word == "" then
            local list = ns.MatEntries()
            if #list == 0 then
                msg("Noch keine Raidmaterialien. Amisia lernt sie in Raidaufnahmen von selbst.")
                return
            end
            local names = {}
            for i, e in ipairs(list) do names[i] = e.name end
            msg(("Raidmaterialien (%d von %d): %s."):format(#list, CAP, table.concat(names, ", ")))
            return
        end
        local add = word == "add" or word == "neu" or word == "dazu"
        local remove = word == "weg" or word == "entfernen" or word == "remove"
        if not add and not remove then
            msg("Aufruf: /amisia mats [add|weg <Link>]")
            return
        end
        if not ns.IsOfficerView() then
            msg("Die Materialliste ändern nur Offiziere.")
            return
        end
        local _, text
        if add then _, text = ns.AddMat(arg) else _, text = ns.RemoveMat(arg) end
        msg(text)
    end })
