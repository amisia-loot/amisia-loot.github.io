-- About: the version, who runs which Amisia version in raid and guild, and every command, generated
-- from the registry.
local ADDON, ns = ...
local W = ns.W

local ORANGE, RED, GREY = "|cffff9933", "|cffff4d4d", "|cff8f8f8f"
local ROWS, ROW_H = 8, 20
-- column: field, x, width
local COLS = { { "name", 6, 180, "Name" }, { "ver", 190, 72, "Version" }, { "view", 266, 80, "Ansicht" },
               { "where", 350, 60, "Wo" }, { "last", 414, 126, "Zuletzt" } }

local page            -- the built frame
local refreshAt, refreshPending

local function colored(color, text) return color .. text .. "|r" end

local function classColored(name, class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c and c.colorStr then return "|c" .. c.colorStr .. name .. "|r" end
    return name
end

local function lastText(at)
    if type(at) ~= "number" then return "-" end
    if date("%Y-%m-%d", at) == date("%Y-%m-%d", time()) then return date("%H:%M", at) end
    return date("%d.%m.", at)
end

local function buildRow(row)
    for _, col in ipairs(COLS) do
        local fs = W.Text(row, "GameFontHighlightSmall", col[3])
        fs:SetPoint("LEFT", col[2], 0)
        row[col[1]] = fs
    end
end

local function fillRow(row, r)
    if r.missing then
        row.name:SetText(colored(GREY, r.name))
        row.ver:SetText("-")
        row.view:SetText("-")
        row.where:SetText(colored(GREY, "Raid"))
        row.last:SetText(colored(GREY, "kein Amisia?"))
        return
    end
    row.name:SetText(classColored(r.name, r.class))
    local v = tostring(r.v or "-")
    if r.self and r.tooOld then
        v = colored(RED, v)
    elseif r.outdated or r.tooOld then
        v = colored(ORANGE, v)
    end
    row.ver:SetText(v)
    row.view:SetText(ns.VersionView(r))
    row.where:SetText(r.where == "raid" and "Raid" or "Gilde")
    row.last:SetText(lastText(r.at))
end

local function setButton(b, enabled, tip)
    b:SetEnabled(enabled)
    b.tip = tip
end

local function tipButton(b)
    b:SetScript("OnEnter", function(self)
        if not self.tip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self:GetText(), 1, 0.82, 0)
        GameTooltip:AddLine(self.tip, 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function ask(where)
    local ok, why = ns.VersionAsk(where)
    if not ok and why then ns.msg(why) end
    ns.Refresh()
end

function ns.AboutPageFrame() return page end

ns.RegisterPanel{ key = "about", label = "Über und Befehle", icon = "Interface\\Icons\\INV_Misc_QuestionMark", order = 910, group = "amisia",
    create = function(parent)
        local f = CreateFrame("Frame", nil, parent)
        f.head = W.Text(f, "GameFontNormal", 590)
        f.head:SetPoint("TOPLEFT", 0, 0)
        f.sub = W.Text(f, "GameFontHighlightSmall", 590)
        f.sub:SetPoint("TOPLEFT", 0, -18)
        f.newer = W.Text(f, "GameFontHighlightSmall", 590)
        f.newer:SetPoint("TOPLEFT", 0, -38)
        f.title = W.Text(f, "GameFontNormal", 360)
        f.title:SetPoint("TOPLEFT", 0, -62)
        f.askGuild = W.Button(f, "Gilde fragen", 110, function() ask("guild") end)
        f.askGuild:SetPoint("TOPRIGHT", 0, -58)
        f.askRaid = W.Button(f, "Raid fragen", 110, function() ask("raid") end)
        f.askRaid:SetPoint("TOPRIGHT", -116, -58)
        tipButton(f.askGuild)
        tipButton(f.askRaid)
        f.summary = W.Text(f, "GameFontHighlightSmall", 590)
        f.summary:SetPoint("TOPLEFT", 0, -86)
        f.cols = {}
        for _, col in ipairs(COLS) do
            local fs = W.Text(f, "GameFontDisableSmall", col[3])
            fs:SetPoint("TOPLEFT", col[2], -104)
            fs:SetText(col[4])
            f.cols[#f.cols + 1] = fs
        end
        f.list = W.List(f, ROWS, ROW_H, buildRow, fillRow)
        f.list:SetPoint("TOPLEFT", 0, -122)
        f.list:SetPoint("TOPRIGHT", -24, -122)
        f.empty = W.Text(f, "GameFontDisableSmall", 560)
        f.empty:SetPoint("TOPLEFT", 6, -126)
        f.cmdTitle = W.Text(f, "GameFontNormal", 300)
        f.cmdTitle:SetPoint("TOPLEFT", 0, -290)
        f.cmdTitle:SetText("Befehle")
        f.text = W.ScrollText(f)
        f.text:SetPoint("TOPLEFT", 0, -308)
        f.text:SetPoint("BOTTOMRIGHT", -24, 0)
        page = f
        return f
    end,
    refresh = function(f)
        refreshAt = GetTime()
        f.head:SetText(("Amisia %s · Sync-Protokoll %d"):format(ns.VERSION or "", ns.SYNC_PROTO or 1))
        f.sub:SetText("|cff8f86a3Raid-Aufnahme, Loot, Rolls, Soft-Reserves und Export für die Amisia-Loot-Seite.|r")
        f.title:SetText("Amisia in Raid und Gilde")
        local newer, by = ns.VersionNewer()
        if newer then
            f.newer:SetText(colored(ORANGE, ("Es gibt eine neuere Version: %s (gesehen bei %s). Bitte aktualisieren."):format(newer, by)))
            f.newer:Show()
        else
            f.newer:SetText("")
            f.newer:Hide()
        end
        local available = ns.CommAvailable()
        local on = available and ns.Get("sync.versionCheck") ~= false
        local inRaid = IsInRaid(LE_PARTY_CATEGORY_HOME) and true or false
        local inGuild = IsInGuild() and true or false
        if not available then
            setButton(f.askRaid, false, "Addon-Nachrichten sind nicht verfügbar.")
            setButton(f.askGuild, false, "Addon-Nachrichten sind nicht verfügbar.")
        elseif not on then
            setButton(f.askRaid, false, "Versionsprüfung ist ausgeschaltet.")
            setButton(f.askGuild, false, "Versionsprüfung ist ausgeschaltet.")
        else
            setButton(f.askRaid, inRaid, not inRaid and "Nur in einer Raidgruppe." or nil)
            local wait = ns.VersionGuildWait()
            if not inGuild then
                setButton(f.askGuild, false, "Nur in einer Gilde.")
            elseif wait > 0 then
                setButton(f.askGuild, false, ("Wieder in %s."):format(ns.VersionMinutes(wait)))
            else
                setButton(f.askGuild, true, nil)
            end
        end
        local rows = available and ns.VersionRows() or {}
        local raidRows, withAmisia, outdated, guildRows = 0, 0, 0, 0
        for _, r in ipairs(rows) do
            if r.where == "raid" then
                raidRows = raidRows + 1
                if r.v then withAmisia = withAmisia + 1 end
                if r.outdated or r.tooOld then outdated = outdated + 1 end
            else
                guildRows = guildRows + (r.self and 0 or 1)
            end
        end
        local guildText = ("Gilde: %d gesehen"):format(guildRows)
        -- more clients than rows: the wheel scrolls the list
        if available and #rows > ROWS then
            guildText = guildText .. (" · %d von %d, Mausrad"):format(ROWS, #rows)
        end
        if inRaid then
            f.summary:SetText(("Raid: %d von %d mit Amisia%s · %s"):format(withAmisia, math.max(#ns.GroupRoster(), raidRows),
                outdated > 0 and (" · %d veraltet"):format(outdated) or "", guildText))
        else
            f.summary:SetText(guildText)
        end
        if not available then
            f.list:SetItems({})
            f.empty:SetText("Addon-Nachrichten sind nicht verfügbar.")
            f.empty:Show()
        elseif #rows <= 1 then
            f.list:SetItems({})
            f.empty:SetText("Noch keine anderen Amisia-Clients gesehen.")
            f.empty:Show()
        else
            f.list:SetItems(rows)
            f.empty:Hide()
        end
        f.text:SetText(table.concat(ns.SlashHelpLines(ns.IsOfficerView()), "\n"))
    end }

-- New versions or a new sync state: the page builds again, at most once a second, only while shown.
local function soon()
    if not page or not page:IsShown() or ns.CurrentPage() ~= "about" or refreshPending then return end
    refreshPending = true
    local wait = refreshAt and math.max(0, 1 - (GetTime() - refreshAt)) or 0
    C_Timer.After(wait, function()
        refreshPending = false
        if page and page:IsShown() and ns.CurrentPage() == "about" then ns.Refresh() end
    end)
end
ns.Listen("SYNC_VERSIONS", soon)
ns.Listen("SYNC_STATE", soon)
