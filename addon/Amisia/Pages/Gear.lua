-- Gear (WoW Forever): what the player can get at their level that beats what they wear.
local ADDON, ns = ...
local W = ns.W
local QUALITY = { [0] = "ff9d9d9d", "ffffffff", "ff1eff00", "ff0070dd", "ffa335ee", "ffff8000", "ffe6cc80" }

local function available() return ns.Gear and ns.Gear.Available() end

local function itemName(id)
    local getInfo = C_Item and C_Item.GetItemInfo or _G.GetItemInfo
    local name, _, q = getInfo(id)
    local row = ns.Gear.Item(id)
    q = q or (row and row[5]) or 1
    return ("|c%s%s|r"):format(QUALITY[q] or QUALITY[1], name or ("Item " .. id))
end

local function sourceText(id, o)
    local rec = ns.Gear.Sources(id, o)[1]
    return rec and ns.Gear.SourceText(rec, true) or ""
end

ns.RegisterPanel{ key = "gear", label = "Ausrüstung", icon = "Interface\\Icons\\INV_Chest_Chain_05", order = 50, available = available,
    create = function(parent)
        local f = CreateFrame("Frame", nil, parent)
        f.state = W.Text(f, "GameFontHighlight", 440, true)
        f.state:SetPoint("TOPLEFT", 0, -2)
        local open = W.Button(f, "Tabelle öffnen", 130, function() ns.ToggleGearFrame() end)
        open:SetPoint("TOPRIGHT", 0, 0)
        f.list = W.List(f, 17, 24, function(r)
            r.slot = W.Text(r, "GameFontNormalSmall", 80)
            r.slot:SetPoint("LEFT", 6, 0)
            r.name = W.Text(r, "GameFontHighlightSmall", 210)
            r.name:SetPoint("LEFT", 90, 0)
            r.src = W.Text(r, "GameFontHighlightSmall", 230)
            r.src:SetPoint("LEFT", 304, 0)
            r.gain = W.Text(r, "GameFontHighlightSmall", 50)
            r.gain:SetPoint("RIGHT", -6, 0)
            r.gain:SetJustifyH("RIGHT")
        end, function(r, e)
            r.slot:SetText(e.slot.name)
            r.name:SetText(itemName(e.id))
            r.src:SetText(sourceText(e.id, r:GetParent().opts))
            r.gain:SetText(("|cff4fd06a+%d|r"):format(math.floor(e.gain + 0.5)))
        end)
        f.list:SetPoint("TOPLEFT", 0, -30)
        f.list:SetPoint("TOPRIGHT", 0, -30)
        return f
    end,
    refresh = function(f)
        local list, _, o = ns.GearMyUpgrades()
        f.list.opts = o
        local loading = ns.Gear.Loading()
        f.state:SetText(("Level %d · %d Upgrades%s"):format(UnitLevel("player") or 1, #list,
            loading > 0 and (" · |cffe0a344lädt noch " .. loading .. " Items|r") or ""))
        f.list:SetItems(list)
    end }

ns.RegisterCard{ key = "gear", order = 30, available = available, fill = function(c)
    local list = ns.GearMyUpgrades()
    c.title:SetText("Deine Ausrüstung")
    c.line1:SetText(("Level %d · %d Upgrades"):format(UnitLevel("player") or 1, #list))
    if list[1] then c.line2:SetText(("Bestes: %s (+%d)"):format(itemName(list[1].id), math.floor(list[1].gain + 0.5))) end
    c:SetAction("Ansehen", function() ns.ShowPage("gear") end)
end }
