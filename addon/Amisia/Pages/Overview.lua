-- Overview: one card per registered feature, each with its state and at most one button.
local ADDON, ns = ...
local W = ns.W
local CARD_W, CARD_H, GAP, SLOTS = 296, 112, 12, 6

ns.RegisterPanel{ key = "overview", label = "Übersicht", icon = "Interface\\Icons\\INV_Misc_Book_09", order = 10,
    create = function(parent)
        local f = CreateFrame("Frame", nil, parent)
        f.cards = {}
        for i = 1, SLOTS do
            local c = W.Card(f, CARD_W, CARD_H)
            c:SetPoint("TOPLEFT", ((i - 1) % 2) * (CARD_W + GAP), -math.floor((i - 1) / 2) * (CARD_H + GAP))
            c:Hide()
            f.cards[i] = c
        end
        f.empty = W.Text(f, "GameFontDisable", 500)
        f.empty:SetPoint("TOPLEFT", 4, -4)
        return f
    end,
    refresh = function(f)
        local n = 0
        for _, spec in ipairs(ns.cards) do
            if n < SLOTS and ns.Visible(spec) then
                n = n + 1
                local c = f.cards[n]
                c.title:SetText("")
                c.line1:SetText("")
                c.line2:SetText("")
                c:SetAction(nil)
                local ok, err = pcall(spec.fill, c)
                if not ok then
                    c.title:SetText(spec.key)
                    c.line1:SetText("Fehler")
                    c.line2:SetText(tostring(err):match("^[^\n]*"))
                end
                c:Show()
            end
        end
        for i = n + 1, SLOTS do f.cards[i]:Hide() end
        f.empty:SetText(n == 0 and "Noch nichts zu zeigen." or "")
    end }
