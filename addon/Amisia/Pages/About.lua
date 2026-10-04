-- About: the version and every command, generated from the registry.
local ADDON, ns = ...
local W = ns.W

ns.RegisterPanel{ key = "about", label = "Über und Befehle", icon = "Interface\\Icons\\INV_Misc_QuestionMark", order = 910, bottom = true,
    create = function(parent)
        local f = CreateFrame("Frame", nil, parent)
        f.head = W.Text(f, "GameFontNormal", 590, true)
        f.head:SetPoint("TOPLEFT", 0, -2)
        f.text = W.ScrollText(f)
        f.text:SetPoint("TOPLEFT", 0, -50)
        f.text:SetPoint("BOTTOMRIGHT", -24, 0)
        return f
    end,
    refresh = function(f)
        f.head:SetText(("Amisia %s\n|cff8f86a3Raid-Aufnahme, Loot, Rolls, Soft-Reserves und Export für die Amisia-Loot-Seite.|r"):format(ns.VERSION or ""))
        f.text:SetText(table.concat(ns.SlashHelpLines(ns.IsOfficerView()), "\n"))
    end }
