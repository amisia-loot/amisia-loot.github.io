-- What Amisia knows about a duellist, outside the duels page (F-116, F-117, F-118): the lines of a
-- player (class and specialisation, record, you against him, streak, nemesis and favourite foe) for
-- the page's tooltips; a card under the client's duel request (duels.request) with these lines for
-- the challenger; a line in the tooltip of a player of the duels (duels.tooltip). Reads only what
-- Core/Duels.lua recorded, sends nothing.
local ADDON, ns = ...
local L = ns.L
local T = ns.Theme
local S = T.DUELS

local I = {}
ns.DuelInfo = I

local function className(c)
    local names = ns.Gear and ns.Gear.CLASS_NAMES
    return c and names and names[c] or c
end

local function colored(text, c)
    local col = c and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c]
    return col and col.colorStr and ("|c%s%s|r"):format(col.colorStr, text) or text
end

local function pct(w, g) return g > 0 and (ns.Num(w / g * 100, 1) .. " %") or "-" end

-- "Jäger · Treffsicherheit", "Jäger" or "unbekannt"
function I.ClassLine(c, tree)
    if not c then return L["unbekannt"] end
    local spec = ns.Duels.TreeName(c, tree)
    return spec and (className(c) .. " · " .. spec) or className(c)
end

-- "3 Siege in Folge", "2 Niederlagen in Folge"; nil below two.
function I.StreakText(e)
    if not e or math.abs(e.streak or 0) < 2 then return nil end
    if e.streak > 0 then return L["%d Siege in Folge"]:format(e.streak) end
    return L["%d Niederlagen in Folge"]:format(-e.streak)
end

-- The own character's wins and losses against e (nil when they never met or e is the own one).
local function againstMe(e)
    local me = ns.UnitFullName("player")
    if not e or not me or ns.SameName(e.name, me) then return nil end
    local mine = ns.Duels.PlayerStats(me)
    local f = mine and e.foes[mine.name:lower()]
    if not f then return nil end
    return f.l, f.w
end

-- The lines about a player: { text, r, g, b } each. opts.class: the class when the duels know none
-- (from a unit).
function I.Lines(name, opts)
    opts = opts or {}
    local lines = {}
    local function add(text, r, g, b) lines[#lines + 1] = { text, r or 0.85, g or 0.85, b or 0.85 } end
    local e = ns.Duels.PlayerStats(name)
    local c = e and e.c or opts.class
    add(colored(e and e.name or name, c), 1, 0.82, 0)
    add(c and I.ClassLine(c, e and e.s) or L["Klasse unbekannt"])
    if not e then
        add(L["Noch kein Duell von ihm aufgezeichnet."], 0.6, 0.6, 0.6)
        return lines
    end
    if c and not e.s then
        add(L["Spezialisierung unbekannt: Amisia liest sie, sobald er in deiner Nähe steht."], 0.6, 0.6, 0.6)
    end
    add(L["%d Duelle, %d - %d (%s)"]:format(e.g, e.w, e.l, pct(e.w, e.g)))
    local w, l = againstMe(e)
    if w then add(L["Du gegen ihn: %d - %d"]:format(w, l), 1, 0.82, 0) end
    local streak = I.StreakText(e)
    if streak then add(L["Serie: %s"]:format(streak), e.streak > 0 and 0.4 or 1, e.streak > 0 and 1 or 0.5, 0.4) end
    if e.best >= 3 then add(L["Beste Serie: %d Siege"]:format(e.best)) end
    local nemesis, favourite = ns.Duels.Rivals(e)
    if nemesis then add(L["Erzfeind: %s (%d - %d)"]:format(nemesis.name, nemesis.w, nemesis.l)) end
    if favourite then add(L["Lieblingsgegner: %s (%d - %d)"]:format(favourite.name, favourite.w, favourite.l)) end
    return lines
end

-- A tooltip gets the lines of a player.
function I.AddLines(tip, name, opts)
    for _, ln in ipairs(I.Lines(name, opts)) do tip:AddLine(ln[1], ln[2], ln[3], ln[4], true) end
end

---------------------------------------------------------------------------
-- The card under a duel request
---------------------------------------------------------------------------
local card

-- The class of a player in sight (target, mouseover, a name plate), for a challenger of no duel.
local function classInSight(name)
    local units = { "target", "mouseover" }
    local np = _G.C_NamePlate
    if type(np) == "table" and type(np.GetNamePlates) == "function" then
        for _, plate in ipairs(np.GetNamePlates() or {}) do
            local u = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
            if type(u) == "string" then units[#units + 1] = u end
        end
    end
    for _, u in ipairs(units) do
        if (type(UnitExists) ~= "function" or ns.Plain(UnitExists(u)))
            and (type(UnitIsPlayer) ~= "function" or ns.Plain(UnitIsPlayer(u))) then
            local n, s = UnitName(u)
            if ns.SameName(ns.FullName(ns.Plain(n), ns.Plain(s)), name) then
                local _, token = UnitClass(u)
                token = ns.Plain(token)
                if ns.Duels.CLASSES[token] then return token end
            end
        end
    end
    return nil
end

-- The client's duel request window while it is shown.
local function requestPopup()
    if type(_G.StaticPopup_FindVisible) == "function" then
        local ok, f = pcall(_G.StaticPopup_FindVisible, "DUEL_REQUESTED")
        if ok and type(f) == "table" then return f end
    end
    for i = 1, 4 do
        local f = _G["StaticPopup" .. i]
        if type(f) == "table" and f.IsShown and f:IsShown() and f.which == "DUEL_REQUESTED" then return f end
    end
    return nil
end

local function cardTick(self, elapsed)
    self.wait = (self.wait or 0) + elapsed
    if self.wait < 0.2 then return end
    self.wait = 0
    if (self.anchor and not self.anchor:IsShown()) or GetTime() - self.at > S.CARD_TIME then self:Hide() end
end

-- Shows the card for a challenger; returns the card (nil when off or without a name).
function I.ShowCard(name)
    name = ns.FullName(ns.Plain(name))
    if not name or not ns.Get("duels.request") then return nil end
    if not card then
        card = CreateFrame("GameTooltip", "AmisiaDuelCard", UIParent, "GameTooltipTemplate")
        card:SetScript("OnUpdate", cardTick)
    end
    local anchor = requestPopup()
    card:SetOwner(UIParent, "ANCHOR_NONE")
    card:ClearAllPoints()
    if anchor then
        card:SetPoint("TOP", anchor, "BOTTOM", 0, -S.CARD_GAP)
    else
        card:SetPoint("TOP", UIParent, "TOP", 0, S.CARD_Y)
    end
    card:AddLine(L["Amisia · Duell-Anfrage"], 0.6, 0.6, 0.6)
    I.AddLines(card, name, { class = classInSight(name) })
    card.anchor, card.at, card.name = anchor, GetTime(), name
    card:Show()
    return card
end

function I.HideCard()
    if card then card:Hide() end
end

-- a frame later: the client's own handler shows the request window first
ns.OnEvent("DUEL_REQUESTED", function(name) C_Timer.After(0, function() I.ShowCard(name) end) end)
ns.OnEvent("DUEL_FINISHED", function() I.HideCard() end)

---------------------------------------------------------------------------
-- The line in a player's tooltip
---------------------------------------------------------------------------
-- "Duelle: 8 - 4 (66,7 %) · du 1 - 2" for a player of the duels, nil otherwise.
function I.TooltipText(name)
    local e = ns.Duels.PlayerStats(name)
    if not e then return nil end
    local text = L["Duelle: %d - %d (%s)"]:format(e.w, e.l, pct(e.w, e.g))
    local w, l = againstMe(e)
    if w then text = text .. " · " .. L["du %d - %d"]:format(w, l) end
    local streak = I.StreakText(e)
    if streak then text = text .. " · " .. streak end
    return text
end

local function onUnitTooltip(tip)
    if tip ~= GameTooltip or not ns.Get("duels.tooltip") or type(tip.GetUnit) ~= "function" then return end
    local _, unit = tip:GetUnit()
    unit = ns.Plain(unit)
    if type(unit) ~= "string" or (type(UnitIsPlayer) == "function" and not ns.Plain(UnitIsPlayer(unit)))
        or (type(UnitIsUnit) == "function" and ns.Plain(UnitIsUnit(unit, "player"))) then return end
    local n, s = UnitName(unit)
    local text = I.TooltipText(ns.FullName(ns.Plain(n), ns.Plain(s)))
    if text then tip:AddLine(text, 0.85, 0.85, 0.85) end
end
I.OnUnitTooltip = onUnitTooltip

if type(TooltipDataProcessor) == "table" and type(TooltipDataProcessor.AddTooltipPostCall) == "function"
    and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tip)
        local ok, err = pcall(onUnitTooltip, tip)
        if not ok then geterrorhandler()(err) end
    end)
end
