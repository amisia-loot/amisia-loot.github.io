-- Guild bank: the last count of the tracked materials.
local ADDON, ns = ...
local W = ns.W

ns.RegisterPanel{ key = "bank", label = "Gildenbank", icon = "Interface\\Icons\\INV_Misc_Coin_02", order = 70, officer = true,
    create = function(parent)
        local f = CreateFrame("Frame", nil, parent)
        f.state = W.Text(f, "GameFontHighlight", 590, true)
        f.state:SetPoint("TOPLEFT", 0, -2)
        f.list = W.List(f, math.max(#ns.MAT_ORDER, 1), 22, function(r)
            r.name = W.Text(r, "GameFontHighlightSmall", 300)
            r.name:SetPoint("LEFT", 6, 0)
            r.count = W.Text(r, "GameFontHighlightSmall", 80)
            r.count:SetPoint("RIGHT", -6, 0)
            r.count:SetJustifyH("RIGHT")
        end, function(r, e)
            r.name:SetText(ns.ItemName(e.id))
            r.count:SetText(e.count)
        end)
        f.list:SetPoint("TOPLEFT", 0, -40)
        f.list:SetPoint("TOPRIGHT", 0, -40)
        return f
    end,
    refresh = function(f)
        if not ns.HasMats() then
            f.state:SetText("|cff8f86a3Keine Materialien festgelegt.|r Solange die Gilde keine Materialien benennt, zählt Amisia nichts in der Gildenbank.")
            f.list:SetItems({})
            return
        end
        local bank = ns.Bank()
        if not (bank and bank.counts) then
            f.state:SetText("|cff8f86a3Noch nicht gezählt.|r Öffne die Gildenbank einmal, dann zählt Amisia die Materialien.")
            f.list:SetItems({})
            return
        end
        local hidden = (bank.total or 0) - (bank.tabs or 0)
        f.state:SetText(("Gezählt am %s von %s · %d von %d sichtbaren Tabs mit Gegenständen%s"):format(
            date("%d.%m.%Y %H:%M", bank.at), bank.by or "?", bank.filled or 0, bank.tabs or 0,
            hidden > 0 and (" · |cffe0a344" .. hidden .. " Tabs nicht sichtbar|r") or ""))
        local items = {}
        for _, id in ipairs(ns.MAT_ORDER) do items[#items + 1] = { id = id, count = bank.counts[id] or 0 } end
        f.list:SetItems(items)
    end }

-- The card appears only while materials are tracked (ns.MAT_ORDER).
ns.RegisterCard{ key = "bank", order = 50, officer = true, available = ns.HasMats, fill = function(c)
    local bank = ns.Bank()
    c.title:SetText("Gildenbank")
    if not (bank and bank.counts) then
        c.line1:SetText("Noch nicht gezählt")
        return
    end
    local b = bank.counts
    c.line1:SetText(("Gezählt am %s"):format(date("%d.%m. %H:%M", bank.at)))
    c.line2:SetText(ns.MatLine(b))
    c:SetAction("Ansehen", function() ns.ShowPage("bank") end)
end }
