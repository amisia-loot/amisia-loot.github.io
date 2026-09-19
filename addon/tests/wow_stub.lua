-- Just enough of the WoW client API for the Amisia modules to run under plain Lua 5.1.
-- Everything a test may poke at hangs on STUB.
STUB = {
    chat = {}, messages = {}, roster = {}, items = {}, loot = {}, timers = {}, frames = {}, requested = {},
    now = 1789000000, clock = 0, player = "Vuloo", leader = true, alt = false,
    instance = { name = "Black Temple", type = "raid", id = 564 },
}

_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.tinsert = table.insert
_G.strmatch = string.match
_G.time = function() return STUB.now end
_G.date = function(fmt, t) return os.date(fmt, t or STUB.now) end
_G.GetServerTime = function() return STUB.now end
_G.GetTime = function() return STUB.clock end
_G.UnitName = function(u) if u == "target" then return STUB.target end return STUB.player end
_G.UnitGUID = function(u) if u == "target" then return STUB.targetGUID end return "Player-1-1" end
_G.IsInRaid = function() return #STUB.roster > 0 end
_G.IsInGroup = function() return #STUB.roster > 0 end
_G.GetNumGroupMembers = function() return #STUB.roster end
_G.GetRaidRosterInfo = function(i)
    local m = STUB.roster[i]
    if not m then return nil end
    return m.name, m.rank or 0, 1, 70, m.class, m.class, m.zone or "Black Temple", m.online ~= false
end
_G.UnitIsGroupLeader = function() return STUB.leader end
_G.UnitIsGroupAssistant = function() return false end
_G.GetInstanceInfo = function() local i = STUB.instance; return i.name, i.type, 0, "", 0, 0, false, i.id end
_G.InCombatLockdown = function() return STUB.combat and true or false end
_G.IsAltKeyDown = function() return STUB.alt end
_G.GetGuildInfo = function() return "Amisia" end

local function itemId(x) return tonumber(x) or tonumber(tostring(x):match("item:(%d+)")) end
_G.GetItemInfo = function(x)
    local it = STUB.items[itemId(x)]
    if not it then return nil end
    return it.name, it.link, it.quality, it.ilvl or 141, it.minLevel or 70, "Armor", "Cloth", 1, it.equipLoc or "INVTYPE_HEAD", it.icon or 134, 0, it.classID or 4, it.subclassID or 1, it.bind or 1
end
_G.GetItemInfoInstant = function(x)
    local id = itemId(x)
    local it = STUB.items[id]
    return id, "Armor", "Cloth", it and it.equipLoc or "INVTYPE_HEAD", it and it.icon or 134, it and it.classID or 4, it and it.subclassID or 1
end
_G.C_Item = {
    GetItemInfo = _G.GetItemInfo,
    GetItemInfoInstant = _G.GetItemInfoInstant,
    RequestLoadItemDataByID = function(id) STUB.requested[#STUB.requested + 1] = id end,
}
_G.GetNumLootItems = function() return #STUB.loot end
_G.GetLootSlotLink = function(s) return STUB.loot[s] and STUB.loot[s].link end
_G.GetLootSlotInfo = function(s) local l = STUB.loot[s]; return "icon", l and l.name, l and l.qty or 1 end
_G.GetLootSourceInfo = function(s) local l = STUB.loot[s]; return l and l.src or "Creature-0-1-1-1-22917-1", l and l.qty or 1 end
_G.GetMasterLootCandidate = function(slot, i) return STUB.roster[i] and STUB.roster[i].name end
_G.GiveMasterLoot = function(slot, i) STUB.given = { slot = slot, i = i } end
_G.HandleModifiedItemClick = function(link) STUB.modifiedClick = link end
_G.SendChatMessage = function(text, chan) STUB.chat[#STUB.chat + 1] = { text = text, chan = chan } end

_G.hooksecurefunc = function(a, b, c)
    if type(a) == "string" then
        local orig = _G[a]
        _G[a] = function(...) local r = { orig(...) }; b(...); return unpack(r) end
    else
        local orig = a[b]
        a[b] = function(...) local r = { orig(...) }; c(...); return unpack(r) end
    end
end

_G.C_Timer = {
    After = function(s, fn) STUB.timers[#STUB.timers + 1] = { at = STUB.clock + s, fn = fn } end,
    NewTicker = function(s, fn)
        local t = { at = STUB.clock + s, fn = fn, every = s }
        t.Cancel = function() t.dead = true end
        STUB.timers[#STUB.timers + 1] = t
        return t
    end,
}
-- Advances the fake clock, firing timers in order. time() moves along with it.
function STUB.tick(seconds)
    local target = STUB.clock + seconds
    while true do
        local nextT
        for _, t in ipairs(STUB.timers) do
            if not t.dead and t.at <= target + 1e-9 and (not nextT or t.at < nextT.at) then nextT = t end
        end
        if not nextT then break end
        STUB.now = STUB.now + (nextT.at - STUB.clock)
        STUB.clock = nextT.at
        if nextT.every then nextT.at = nextT.at + nextT.every else nextT.dead = true end
        nextT.fn()
    end
    STUB.now = STUB.now + (target - STUB.clock)
    STUB.clock = target
end

local NOOP = function() end
local function region()
    local f = { text = "", shown = true }
    for _, m in ipairs({ "SetPoint", "SetWidth", "SetHeight", "SetSize", "SetJustifyH", "SetWordWrap", "SetTextColor", "SetFontObject",
                          "SetAllPoints", "SetColorTexture", "SetTexture", "SetTexCoord", "SetAlpha", "SetDrawLayer", "SetFont", "SetShadowOffset" }) do
        f[m] = NOOP
    end
    f.SetText = function(self, t) self.text = t end
    f.GetText = function(self) return self.text end
    f.Show = function(self) self.shown = true end
    f.Hide = function(self) self.shown = false end
    f.IsShown = function(self) return self.shown end
    return f
end
local frameMethods = { "SetPoint", "SetSize", "SetWidth", "SetHeight", "SetFrameStrata", "SetClampedToScreen", "SetMovable", "EnableMouse",
    "RegisterForDrag", "SetAllPoints", "SetScrollChild", "SetVerticalScroll", "SetMultiLine", "SetMaxLetters", "SetAutoFocus", "SetFontObject",
    "SetCursorPosition", "HighlightText", "SetFocus", "ClearFocus", "EnableMouseWheel", "SetFrameLevel", "SetToplevel", "StartMoving",
    "StopMovingOrSizing", "SetBackdrop", "SetBackdropColor", "SetNormalTexture", "SetHighlightTexture", "SetPushedTexture", "SetScale", "SetID",
    "SetEnabled", "Disable", "Enable", "SetTextColor", "ClearAllPoints", "SetResizable", "SetHitRectInsets", "RegisterForClicks" }
function _G.CreateFrame(kind, name, parent, template)
    local f = { kind = kind, name = name, shown = false, scripts = {}, events = {}, text = "", parent = parent }
    for _, m in ipairs(frameMethods) do f[m] = NOOP end
    f.SetScript = function(self, k, fn) self.scripts[k] = fn end
    f.GetScript = function(self, k) return self.scripts[k] end
    f.HookScript = function(self, k, fn)
        local o = self.scripts[k]
        self.scripts[k] = function(...) if o then o(...) end fn(...) end
    end
    f.RegisterEvent = function(self, e) self.events[e] = true; STUB.frames[self] = true end
    f.UnregisterEvent = function(self, e) self.events[e] = nil end
    f.Show = function(self) self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    f.Hide = function(self) self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
    f.IsShown = function(self) return self.shown end
    f.IsVisible = f.IsShown
    f.SetText = function(self, t) self.text = t end
    f.GetText = function(self) return self.text end
    f.CreateFontString = function() return region() end
    f.CreateTexture = function() return region() end
    f.GetParent = function() return parent end
    f.GetName = function() return name end
    f.GetFrameLevel = function() return 1 end
    f.SetOwner = NOOP
    f.AddLine = NOOP
    f.AddDoubleLine = NOOP
    f.NumLines = function() return 0 end
    f.GetItem = function() return nil end
    f.Click = function(self) if self.scripts.OnClick then self.scripts.OnClick(self) end end
    if name then _G[name] = f end
    return f
end
function STUB.fire(event, ...)
    for f in pairs(STUB.frames) do
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end

_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) STUB.messages[#STUB.messages + 1] = t end }
_G.UIParent = CreateFrame("Frame", "UIParent")
_G.GameTooltip = CreateFrame("GameTooltip", "GameTooltip")
_G.ItemRefTooltip = CreateFrame("GameTooltip", "ItemRefTooltip")
_G.UISpecialFrames = {}
_G.StaticPopupDialogs = {}
_G.StaticPopup_Show = NOOP
_G.SlashCmdList = {}
_G.ChatFontNormal = {}
_G.GameFontNormal = {}
_G.RAID_CLASS_COLORS = {
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43, colorStr = "ffc79c6e" },
    SHAMAN = { r = 0, g = 0.44, b = 0.87, colorStr = "ff0070de" },
    PRIEST = { r = 1, g = 1, b = 1, colorStr = "ffffffff" },
}
_G.LOOT_ITEM = "%s receives loot: %s."
_G.LOOT_ITEM_MULTIPLE = "%s receives loot: %sx%d."
_G.LOOT_ITEM_SELF = "You receive loot: %s."
_G.LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
_G.LOOT_ITEM_PUSHED = "%s receives item: %s."
_G.LOOT_ITEM_PUSHED_MULTIPLE = "%s receives item: %sx%d."
_G.LOOT_ITEM_PUSHED_SELF = "You receive item: %s."
_G.LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d."
_G.RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)"
_G.Enum = { TooltipDataType = { Item = 0 } }

local QCOLOR = { [2] = "ff1eff00", [3] = "ff0070dd", [4] = "ffa335ee", [5] = "ffff8000" }
function STUB.link(id, name, q)
    return ("|c%s|Hitem:%d::::::::70:::::|h[%s]|h|r"):format(QCOLOR[q or 4] or "ffffffff", id, name)
end
-- Registers an item the fake client "knows" and returns its link.
function STUB.item(id, name, q)
    STUB.items[id] = { name = name, quality = q or 4, link = STUB.link(id, name, q) }
    return STUB.items[id].link
end
