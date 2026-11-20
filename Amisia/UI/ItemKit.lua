-- The item rows' helpers that the gear page (module Ausrüstung) and the pages of the module
-- Dungeons & Raids share (F-228, D-158): item names in their quality colour, the item tooltip, the
-- modified click (link, dressing room), the marks owned and wished, the gain text, the page state
-- settings.bis, a memo per BiS state, columns and the chat answer of an action. Without the module
-- Ausrüstung there is no BiS state: the memo then lives until the next reload of the data. Item names
-- the client did not have yet fill the shown rows once item data arrives (ns.ItemKit.WatchNames for
-- the pages that show them).
local ADDON, ns = ...
ns.Load(function()
local L = ns.L
local W, T = ns.W, ns.Theme
local Gear = ns.Gear
local GREY, GREEN = T.GREY, "|cff4fd06a"
local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t"
local STAR = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:12:12|t"
local QUALITY = T.QUALITY_HEX
local itemInfo = ns.ItemInfo

local K = {}
ns.ItemKit = K

K.CHECK, K.STAR = CHECK, STAR
K.OWNED_TEXT = { worn = L["angelegt"], bag = L["in der Tasche, nicht angelegt"], bank = L["in der Bank, nicht angelegt"] }

-- The window state of the gear and dungeon pages in settings.bis (view, slot, place, sources).
function K.state()
    local s = AmisiaDB.settings
    s.bis = type(s.bis) == "table" and s.bis or {}
    return s.bis
end

-- The options the item values are for: the module Ausrüstung's (ns.BisOpts: spec, sources, play style,
-- exclusions); without it the own class, level and faction with every source and no spec (F-228).
local ALL_SOURCES = { X = true, Q = true, D = true, C = true, V = true, W = true, A = true, P = true }
function ns.ItemOpts()
    if ns.BisOpts then return ns.BisOpts() end
    local _, class = UnitClass("player")
    return {
        class = class, kind = "Speedrun", faction = ns.OwnFaction(),
        level = math.max(1, math.min(tonumber(ns.Plain(UnitLevel("player"))) or 1, Gear.Cap())),
        sources = ALL_SOURCES, prof = "all", plan = "auto",
    }
end

-- What a refresh keeps until the BiS state changes (the module Ausrüstung's ns.BisStamp): source
-- texts, explanations, places. Without that module until the next DATA_CHANGED (drops, quests), so the
-- dungeon pages' lists keyed by their tables do not pile up.
local memo = { stamp = -1 }
local dataGen = 0
ns.Listen("DATA_CHANGED", function() dataGen = dataGen + 1 end)
function K.cached()
    local st = ns.BisStamp and ns.BisStamp() or ("d" .. dataGen)
    if memo.stamp ~= st then memo = { stamp = st, src = {}, explain = {} } end
    return memo
end

local nameMissing = false   -- a shown row had no item name yet ("Item 12345")
function K.nameMissing() return nameMissing end
-- a refresh starts with no missing item name; GET_ITEM_INFO_RECEIVED fills its rows again
function K.namesFresh() nameMissing = false end

function K.itemText(id)
    local name, _, q = itemInfo(id)
    local row = Gear.Item(id)
    q = q or (row and (row[5] or 0) > 0 and row[5]) or 1
    if not name then nameMissing = true end
    return ("|c%s%s|r"):format(QUALITY[q] or QUALITY[1], name or Gear.ScanName(id) or (row and row.name) or ("Item " .. id))
end

-- A worn item's name in the colour of its link.
function K.linkText(link)
    local color = link:match("^|c(%x%x%x%x%x%x%x%x)")
    local name = link:match("|h%[(.-)%]|h")
    if name then return color and ("|c%s%s|r"):format(color, name) or name end
    local id = ns.ItemID(link)
    return id and K.itemText(id) or "?"
end

function K.linkOf(id)
    local _, link = itemInfo(id)
    return link or ("item:" .. id)
end

-- A gain as percent of what is worn; a tiny worn score (starter items) gives thousands, shown as ">999 %"
-- so the column does not cut it.
function K.pctText(gain, mine)
    local pct = math.floor(gain / mine * 100 + 0.5)
    if pct > 999 then return ">999 %" end
    return ("%+d %%"):format(pct)
end

function K.marks(e)
    return (e.owned and (CHECK .. " ") or "") .. (e.wished and (STAR .. " ") or "")
end

function K.gainText(e)
    if e.worn or e.owned == "worn" then return CHECK end
    if e.switch then return L["Wechsel"] end
    if type(e.gain) ~= "number" then return "" end
    return (e.upgrade and GREEN or GREY) .. ("%+d"):format(math.floor(e.gain + 0.5)) .. "|r"
end

-- Shift or Ctrl on an item: the client's modified click (link into the chat, dressing room, as the
-- player's key bindings say); Ctrl the client does not take opens the dressing room itself.
function K.modifiedClick(id)
    if not id then return false end
    local ctrl = IsControlKeyDown and IsControlKeyDown() or false
    if not ((IsShiftKeyDown and IsShiftKeyDown()) or ctrl) then return false end
    local link = K.linkOf(id)
    local handled = HandleModifiedItemClick and HandleModifiedItemClick(link)
    if not handled and ctrl and type(DressUpLink) == "function" then pcall(DressUpLink, link) end
    return true
end

function K.itemTooltip(owner, id)
    if not id then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local _, link = itemInfo(id)
    if link then
        GameTooltip:SetHyperlink(link)
    elseif GameTooltip.SetItemByID then
        GameTooltip:SetItemByID(id)
        -- an item only the server describes and no longer does: what the scan saw (D-59)
        if Gear.ScanTooltip(GameTooltip, id, owner, function() K.itemTooltip(owner, id) end) then return end
    end
    GameTooltip:Show()
end
function K.hideTip() GameTooltip:Hide() end

function K.say(ok, why)
    if not ok and why then ns.msg(why) end
end

function K.col(parent, x, w, label, template)
    local fs = W.Text(parent, template or T.FONT.head, w)
    fs:SetPoint("LEFT", x, 0)
    if label then fs:SetText(label) end
    return fs
end

-- The menu of an item row when the module Ausrüstung is not there: only the link (its pages add
-- wish, exclude and the map, ns.GearPageKit.menuEntries).
function K.menuEntries(e)
    local id = e and e.id
    if not id then return {} end
    return { { L["Link in den Chat"], function() W.InsertLink(K.linkOf(id)) end } }
end

---------------------------------------------------------------------------
-- Item names that arrive late
---------------------------------------------------------------------------
-- The pages whose rows show item names (their key: true); ITEM_NAMES fires before the refresh, so a
-- page can drop what it built from the names (the gear page's wishlist sorted by name).
local watched = {}
function K.WatchNames(page) watched[page] = true end

local namesDue = false
ns.OnEvent("GET_ITEM_INFO_RECEIVED", function()
    if not nameMissing or namesDue then return end
    namesDue = true
    C_Timer.After(0.3, function()
        namesDue = false
        local cur = ns.CurrentPage and ns.CurrentPage()
        if not nameMissing or not watched[cur] then return end
        ns.Fire("ITEM_NAMES")
        ns.Refresh()
    end)
end)
end)
