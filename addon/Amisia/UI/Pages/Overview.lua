-- Overview: one card per registered feature, each with its state and at most one button.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
-- two insets side by side fill the 602 px of the content exactly: 2 x 295 + 12
local GAP, SLOTS = 12, 6
local CARD_W, CARD_H = (T.PAGE_W - GAP) / 2, 112

local page
-- For tests: the page frame once built.
function ns.OverviewPageFrame() return page end

ns.RegisterPanel{ key = "overview", label = L["Übersicht"], icon = "Interface\\Icons\\INV_Misc_Book_09", order = 10, group = "raid",
    create = function(parent)
        -- the cards fill the page from its top; no head row (each card has its own button)
        local f = W.Page(parent)
        page = f
        f.cards = {}
        for i = 1, SLOTS do
            local c = W.Card(f, CARD_W, CARD_H)
            c:Hide()
            f.cards[i] = c
        end
        W.Grid(f, f.cards, 2, GAP, GAP, 0, 0)
        f.empty = f:Empty()
        f.empty:Set(L["Noch nichts zu zeigen"], L["Hier stehen Karten zu Raid, Vergaben und Ausrüstung, sobald es etwas gibt."])
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
                    c.line1:SetText(L["Fehler"])
                    c.line2:SetText(tostring(err):match("^[^\n]*"))
                end
                c:Show()
            end
        end
        for i = n + 1, SLOTS do f.cards[i]:Hide() end
        f.empty:SetShown(n == 0)
    end }
