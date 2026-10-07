-- Guild bank: the learned raid materials with their last count, and a small editor (take a
-- material out per row, add one by link).
local ADDON, ns = ...
local W = ns.W

local box   -- the link box of the editor, for the shift-click hook below
local page
local BANK_ROWS = 18

function ns.BankPageFrame() return page end

ns.RegisterPanel{ key = "bank", label = "Gildenbank", icon = "Interface\\Icons\\INV_Misc_Coin_02", order = 70, group = "guild", officer = true,
    create = function(parent)
        local f = CreateFrame("Frame", nil, parent)
        f.state = W.Text(f, "GameFontHighlight", 590, true)
        f.state:SetPoint("TOPLEFT", 0, -2)
        -- add by link: shift-click an item while the box has the focus, or type an item id
        f.add = {}
        f.add.box = W.LineEdit(f, 260)
        f.add.box:SetPoint("TOPLEFT", 0, -40)
        box = f.add.box
        local function add()
            local ok, text = ns.AddMat(f.add.box:GetText() or "")
            ns.msg(text)
            if ok then f.add.box:SetText("") end
            ns.Refresh()
        end
        f.add.box:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            add()
        end)
        f.add.button = W.Button(f, "Hinzufügen", 110, add)
        f.add.button:SetPoint("LEFT", f.add.box, "RIGHT", 6, 0)
        -- ends at 594, inside the page (220 reached 2 px past it)
        f.add.hint = W.Text(f, "GameFontDisableSmall", 210)
        f.add.hint:SetPoint("LEFT", f.add.button, "RIGHT", 8, 0)
        f.add.hint:SetText("Link mit Shift-Klick einfügen")
        -- 18 rows fit the page under the editor (70 + 18 * 22 = 466 of 478 px); the wheel scrolls the rest
        f.list = W.List(f, BANK_ROWS, 22, function(r)
            r.name = W.Text(r, "GameFontHighlightSmall", 300)
            r.name:SetPoint("LEFT", 6, 0)
            r.count = W.Text(r, "GameFontHighlightSmall", 80)
            r.count:SetPoint("RIGHT", -60, 0)
            r.count:SetJustifyH("RIGHT")
            r.remove = W.Button(r, "Weg", 46, function(self)
                local row = self:GetParent()
                if not (row and row.item) then return end
                local _, text = ns.RemoveMat(row.item.id)
                ns.msg(text)
                ns.Refresh()
            end)
            r.remove:SetPoint("RIGHT", -4, 0)
            W.Tooltip(r.remove, "Herausnehmen", "Nimmt das Material aus der Liste. Amisia lernt es dann nicht wieder; /amisia mats add <Link> holt es zurück.")
        end, function(r, e)
            r.name:SetText(ns.ItemName(e.id) .. (e.manual and " |cff8f86a3(von Hand)|r" or ""))
            r.count:SetText(e.count and tostring(e.count) or "-")
        end)
        -- 12 px short of the right edge: room for the list's scroll bar; the count and the button
        -- hang on the row's right and move with it
        f.list:SetPoint("TOPLEFT", 0, -70)
        f.list:SetPoint("TOPRIGHT", -12, -70)
        page = f
        return f
    end,
    refresh = function(f)
        local hidden = ns.HiddenMatCount()
        local n = #ns.MAT_ORDER
        local head = ("%d von %d Raidmaterialien%s%s. "):format(n, ns.MAT_CAP,
            hidden > 0 and (" · " .. hidden .. " herausgenommen") or "",
            n > BANK_ROWS and (" · %d von %d sichtbar, Mausrad"):format(BANK_ROWS, n) or "")
        local bank = ns.Bank()
        if not ns.HasMats() then
            f.state:SetText("|cff8f86a3Noch keine Raidmaterialien.|r Amisia lernt sie in Raidaufnahmen von selbst: Handwerkswaren, die droppen, geplündert oder vergeben werden. Von Hand: Link unten einfügen.")
        elseif not (bank and bank.counts) then
            f.state:SetText(head .. "|cff8f86a3Noch nicht gezählt.|r Öffne die Gildenbank einmal, dann zählt Amisia die Materialien.")
        else
            local hiddenTabs = (bank.total or 0) - (bank.tabs or 0)
            f.state:SetText(head .. ("Gezählt am %s von %s · %d von %d sichtbaren Tabs mit Gegenständen%s"):format(
                date("%d.%m.%Y %H:%M", bank.at), bank.by or "?", bank.filled or 0, bank.tabs or 0,
                hiddenTabs > 0 and (" · |cffe0a344" .. hiddenTabs .. " Tabs nicht sichtbar|r") or ""))
        end
        local counts = bank and bank.counts or {}
        local items = {}
        for _, id in ipairs(ns.MAT_ORDER) do
            local e = ns.MatInfo(id)
            items[#items + 1] = { id = id, count = counts[id], manual = e and e.manual }
        end
        f.list:SetItems(items)
    end }

-- A link shift-clicked into the chat lands in the box while it has the focus. The client calls
-- ChatFrameUtil.InsertLink; ChatEdit_InsertLink is its deprecated alias with a hook of its own.
local function onInsertLink(link)
    if box and box:HasFocus() and ns.ItemID(link) then box:SetText(link) end
end
if type(ChatFrameUtil) == "table" and type(ChatFrameUtil.InsertLink) == "function" then
    hooksecurefunc(ChatFrameUtil, "InsertLink", onInsertLink)
end
if type(ChatEdit_InsertLink) == "function" then
    hooksecurefunc("ChatEdit_InsertLink", onInsertLink)
end

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
