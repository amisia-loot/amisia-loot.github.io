-- Enchant suggestions per slot (F-128, spec docs/specs/2026-10-31-verzauberungen.md): what is on a
-- worn item, which permanent enchantments fit it (Data/EnchantData.lua from the client tables) and
-- what each brings the own spec against the one on it (ns.BisStatsChange: the same model as the
-- upgrades), with their sources (a recipe of Enchanting or Engineering, an item such as an armour kit
-- or a scroll), reagents and the guild's crafters (ns.Prof, ns.Crafters). Only the worn item, no
-- temporary enchantments, nothing is sent or saved. The goals window and the slot card show it.
local ADDON, ns = ...
local L = ns.L
local Gear = ns.Gear

local E = {}
ns.Enchants = E

local parsed     -- { data = the table it came from, ench = { [id] = { stats, fx, ilvl, name } }, src = { [id] = { sources } } }

local function num(v) return tonumber(v) or 0 end

local function split(text, sep)
    local out = {}
    if text == nil or text == "" then return out end
    for part in (text .. sep):gmatch("(.-)" .. sep) do out[#out + 1] = part end
    return out
end

local function data()
    local d = ns.Data("ENCHANT")
    if type(d) ~= "table" then return nil end
    if parsed and parsed.data == d then return parsed end
    parsed = { data = d, ench = {}, src = {} }
    for id, line in pairs(d.E or {}) do
        local f = split(line, "|")
        local stats = {}
        for k, v in (f[1] or ""):gmatch("([%w_]+)=([^;]+)") do stats[k] = tonumber(v) end
        parsed.ench[id] = { stats = stats, fx = f[2] == "1", ilvl = num(f[3]), name = f[4] or "" }
    end
    for _, line in ipairs(d.S or {}) do
        local f = split(line, ":")
        local ench = num(f[3])
        if parsed.ench[ench] then
            local inv, sub = {}, {}
            for _, x in ipairs(split(f[7] or "", ",")) do inv["INVTYPE_" .. x] = true end
            for _, x in ipairs(split(f[8] or "", ",")) do sub[num(x)] = true end
            local list = parsed.src[ench] or {}
            parsed.src[ench] = list
            list[#list + 1] = { kind = f[1], id = num(f[2]), enchant = ench, skill = num(f[4]), level = num(f[5]),
                class = num(f[6]), inv = next(inv) and inv or nil, sub = next(sub) and sub or nil }
        end
    end
    return parsed
end

function E.Available() return ns.HasData("ENCHANT") end

-- The enchantment id of an item link ("item:id:enchant:..."), nil without one.
function E.OfLink(link)
    link = ns.Plain(link)
    local id = type(link) == "string" and tonumber(link:match("item:%-?%d+:(%d*)"))
    return id and id > 0 and id or nil
end

local function itemName(id)
    local f = C_Item and C_Item.GetItemInfo
    local name = f and ns.Plain((f(id)))
    if type(name) == "string" and name ~= "" then return name end
    local g = C_Item and C_Item.GetItemNameByID
    name = g and ns.Plain(g(id))
    return type(name) == "string" and name ~= "" and name or nil
end

local function sourceName(s)
    if s.kind == "r" then return ns.Prof and ns.Prof.SpellName(s.id) or nil end
    return itemName(s.id)
end

-- The name of an enchantment: its recipe's or item's name from the client, else the English name
-- of the data, else "Verzauberung <id>".
function E.Name(id)
    local d = data()
    local list = d and d.src[id] or {}
    for _, kind in ipairs({ "r", "i" }) do
        for _, s in ipairs(list) do
            if s.kind == kind then
                local name = sourceName(s)
                if name then return name end
            end
        end
    end
    local e = d and d.ench[id]
    if e and e.name ~= "" and not e.name:find("%$") then return e.name end
    return L["Verzauberung %d"]:format(id)
end

-- The icon of an enchantment (the planner's enchant square, F-149): its recipe's spell icon or its
-- item's icon from the client, recipes first; nil when the client has none.
function E.Icon(id)
    local d = data()
    local list = d and d.src[id] or {}
    for _, kind in ipairs({ "r", "i" }) do
        for _, s in ipairs(list) do
            if s.kind == kind then
                local f
                if kind == "r" then
                    f = (C_Spell and C_Spell.GetSpellTexture) or _G.GetSpellTexture
                else
                    f = C_Item and C_Item.GetItemIconByID
                end
                local tex = type(f) == "function" and ns.Plain(f(s.id)) or nil
                if tex then return tex end
            end
        end
    end
    return nil
end

-- The scoring stats of an enchantment ({ AGI = 3, ... }); weapon damage becomes damage per second
-- with the weapon's speed.
function E.Stats(id, speed)
    local d = data()
    local e = d and d.ench[id]
    local out = {}
    if not e then return out end
    for k, v in pairs(e.stats) do
        if k == "WDMG" then
            if speed and speed > 0 then out.DPS = (out.DPS or 0) + v / speed end
        else
            local key = Gear.StatKey(k)
            if key then out[key] = (out[key] or 0) + v end
        end
    end
    return out
end

-- "+3 Beweglichkeit, +2 Ausdauer" (weapon damage as it stands on the item: "+3 Waffenschaden").
function E.Text(id)
    local d = data()
    local e = d and d.ench[id]
    if not e then return "" end
    local parts = {}
    for k, v in pairs(e.stats) do
        local label
        if k == "WDMG" then label = L["Waffenschaden"]
        else
            local key = Gear.StatKey(k)
            label = key and Gear.STAT_LABELS[key]
        end
        if label then parts[#parts + 1] = ("%+d %s"):format(v, label) end
    end
    table.sort(parts)
    return table.concat(parts, ", ")
end

local function fits(s, classID, subID, loc)
    if s.class ~= classID then return false end
    if s.inv and not s.inv[loc] then return false end
    if s.sub and not s.sub[subID] then return false end
    return true
end

local function placeOf(slotKey, loc)
    if loc == "INVTYPE_2HWEAPON" then return "2H" end
    if slotKey == "MAINHAND" then return "MH" end
    if slotKey == "OFFHAND" and loc ~= "INVTYPE_SHIELD" and loc ~= "INVTYPE_HOLDABLE" then return "OH" end
    if slotKey == "RANGED" then return "RANGED" end
    return nil
end

local function itemLevelOf(link)
    local f = C_Item and C_Item.GetDetailedItemLevelInfo
    local lvl = f and tonumber(ns.Plain((f(link))))
    if lvl then return lvl end
    local g = C_Item and C_Item.GetItemInfo
    if not g then return nil end
    local _, _, _, ilvl = g(link)
    return tonumber(ns.Plain(ilvl))
end

local function playerLevel() return tonumber(ns.Plain(UnitLevel("player"))) or 60 end

-- The suggestions for the worn item of a slot (a key of Gear.SLOTS): { slotKey, link, current =
-- { id, name, text } or nil, list = { { id, name, text, total, score, fx, later, sources } },
-- better (one scored row brings more) }; nil when the slot is empty or nothing fits its item.
-- The list: what brings more for the own spec first (by the model's percent, else the weighted
-- score), then what does more than the scoring counts (procs, resistances, skills) without a number.
function E.ForSlot(slotKey, opts)
    local d = data()
    if not d then return nil end
    local inv
    for _, sl in ipairs(Gear.SLOTS) do if sl.key == slotKey then inv = sl.inv end end
    local link = inv and ns.Plain(GetInventoryItemLink("player", inv))
    if type(link) ~= "string" then return nil end
    local info = C_Item and C_Item.GetItemInfoInstant
    if not info then return nil end
    local _, _, _, loc, _, classID, subID = info(link)
    loc, classID, subID = ns.Plain(loc), tonumber(ns.Plain(classID)), tonumber(ns.Plain(subID))
    if not classID then return nil end
    local ilvl = itemLevelOf(link)
    local speed
    if classID == 2 then
        local s = Gear.ReadStats(link)
        speed = s and s.SPEED
    end
    local place = placeOf(slotKey, loc)
    local curId = E.OfLink(link)
    local cur = curId and E.Stats(curId, speed) or {}
    local level = playerLevel()
    local out = { slotKey = slotKey, link = link, list = {}, better = false }
    if curId then out.current = { id = curId, name = E.Name(curId), text = E.Text(curId) } end
    local any = false
    for id, list in pairs(d.src) do
        local ok = {}
        for _, s in ipairs(list) do
            if fits(s, classID, subID, loc) then ok[#ok + 1] = s end
        end
        local e = d.ench[id]
        if #ok > 0 and (e.ilvl == 0 or not ilvl or ilvl >= e.ilvl) then
            any = true
            if id ~= curId then
                table.sort(ok, function(a, b)
                    if a.kind ~= b.kind then return a.kind == "r" end
                    return a.id < b.id
                end)
                local total, score = ns.BisStatsChange(cur, E.Stats(id, speed), place, opts)
                local later
                if ok[1].kind == "i" then
                    local lo
                    for _, s in ipairs(ok) do lo = math.min(lo or s.level, s.level) end
                    if lo and lo > level then later = lo end
                end
                local gain = total or score
                local row = { id = id, name = E.Name(id), text = E.Text(id), total = total, score = score, fx = e.fx,
                    later = later, sources = ok }
                if gain and gain > 0.0001 then
                    row.scored = true
                    out.list[#out.list + 1] = row
                    if not later then out.better = true end
                elseif e.fx then
                    out.list[#out.list + 1] = row
                end
            end
        end
    end
    if not any then return nil end
    table.sort(out.list, function(a, b)
        if (a.scored or false) ~= (b.scored or false) then return a.scored == true end
        if a.scored then
            if (a.later ~= nil) ~= (b.later ~= nil) then return a.later == nil end
            local x, y = a.total or a.score or 0, b.total or b.score or 0
            if x ~= y then return x > y end
        end
        return a.id < b.id
    end)
    return out
end

-- The short gain text of a row: "+1,8 %" (the model), "+12" (the weighted score) or "".
function E.GainText(row)
    if not row.scored then return "" end
    if type(row.total) == "number" then return ns.UpgradePct(row.total) end
    if type(row.score) == "number" then return ("%+d"):format(math.floor(row.score + 0.5)) end
    return ""
end

-- The source line of a row: "Verzauberkunst 245", "Lederverarbeitung: Mittleres Rüstungsset",
-- "Gegenstand: ..."; with "ab Stufe N" when the item needs a higher level.
function E.SourceText(row)
    local s = row.sources[1]
    local text
    if s.kind == "r" then
        text = ("%s %d"):format(ns.Prof and ns.Prof.Name(s.skill) or "?", s.level)
    else
        text = L["Gegenstand"]
    end
    if row.later then text = text .. " · " .. L["ab Stufe %d"]:format(row.later) end
    return text
end

-- The tooltip of a row: name, stats, every source with its reagents (count in the bags) and who of
-- the guild can make it.
function E.Tooltip(owner, row)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:AddLine(row.name, 1, 0.82, 0)
    GameTooltip:AddLine(E.SourceText(row), 0.85, 0.85, 0.85)
    if row.text ~= "" then GameTooltip:AddLine(row.text, 1, 1, 1, true) end
    if row.fx then GameTooltip:AddLine(L["Hat einen Effekt, den die Wertung nicht zählt."], 0.6, 0.6, 0.6, true) end
    local Pr, Cr = ns.Prof, ns.Crafters
    for _, s in ipairs(row.sources) do
        GameTooltip:AddLine(" ")
        if s.kind == "r" then
            GameTooltip:AddLine(L["Rezept: %s %d"]:format(Pr and Pr.Name(s.skill) or "?", s.level), 1, 0.82, 0)
            local r = Pr and Pr.Recipe(s.id)
            for _, src in ipairs(r and Pr.Sources(r) or {}) do
                GameTooltip:AddLine("  " .. src.text, 0.85, 0.85, 0.85, true)
            end
            for _, g in ipairs(Pr and Pr.Reagents(s.id) or {}) do
                local name = itemName(g[1]) or ("#" .. g[1])
                GameTooltip:AddDoubleLine("  " .. ("%dx %s"):format(g[2], name),
                    L["in der Tasche: %d"]:format(Pr.Count(g[1])), 0.85, 0.85, 0.85, 0.6, 0.6, 0.6)
            end
            local who = Cr and Cr.ForSpell(s.id) or {}
            if #who > 0 then GameTooltip:AddLine(L["Können: %s"]:format(Cr.Text(who, 6, true)), 0.85, 0.85, 0.85, true) end
        else
            GameTooltip:AddLine(L["Gegenstand: %s"]:format(itemName(s.id) or ("#" .. s.id)), 1, 0.82, 0)
            if s.level > 1 then GameTooltip:AddLine("  " .. L["Mindeststufe %d"]:format(s.level), 0.85, 0.85, 0.85) end
            if Pr then GameTooltip:AddLine("  " .. L["in der Tasche: %d"]:format(Pr.Count(s.id)), 0.85, 0.85, 0.85) end
            local who = Cr and Cr.ForItem(s.id) or {}
            if #who > 0 then GameTooltip:AddLine(L["Können: %s"]:format(Cr.Text(who, 6, true)), 0.85, 0.85, 0.85, true) end
        end
    end
    GameTooltip:Show()
end

-- A click on a row: Shift puts the recipe's or item's link into the chat; else the map target on
-- the first source with a place (a trainer, a vendor of the recipe), or on the item's sources.
function E.Click(row)
    local s = row.sources[1]
    if IsShiftKeyDown and IsShiftKeyDown() then
        local link
        if s.kind == "r" then
            local f = C_Spell and C_Spell.GetSpellLink
            link = f and ns.Plain(f(s.id))
        else
            local _, l = C_Item.GetItemInfo(s.id)
            link = ns.Plain(l)
        end
        local CU = _G.ChatFrameUtil
        if link and CU and CU.InsertLink and not CU.InsertLink(link) and CU.OpenChat then CU.OpenChat(link) end
        return
    end
    local Pr = ns.Prof
    for _, src in ipairs(row.sources) do
        if src.kind == "r" and Pr then
            local r = Pr.Recipe(src.id)
            for _, p in ipairs(r and Pr.Sources(r) or {}) do
                if p.point and ns.MapSetPoint then
                    local ok, why = ns.MapSetPoint(p.point, p.text)
                    if not ok and why then ns.msg(why) end
                    return
                end
            end
        elseif src.kind == "i" and ns.MapSetTarget then
            local ok = ns.MapSetTarget(src.id)
            if ok then return end
        end
    end
    ns.msg(L["Für diese Verzauberung kennt Amisia keinen Ort."])
end

-- The slot card's line: "Verzauberung: <jetzt> · besser: <Name> (+x,x %)", nil without a section.
function E.CardLine(slotKey)
    local ok, res = pcall(E.ForSlot, slotKey)
    if not ok or not res then return nil end
    local now = res.current and res.current.name or (ns.Theme.RED .. L["Keine"] .. "|r")
    local best = res.list[1]
    if best and best.scored and not best.later then
        return L["Verzauberung: %s · besser: %s (%s)"]:format(now, best.name, E.GainText(best))
    end
    return L["Verzauberung: %s"]:format(now)
end
