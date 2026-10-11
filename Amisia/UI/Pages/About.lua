-- About: the version, who runs which Amisia version in raid and guild, and every command, generated
-- from the registry.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme

local ORANGE, RED, GREY = "|cffff9933", "|cffff4d4d", "|cff8f8f8f"
local ROWS, ROW_H = 8, 20
-- column: field, x, width
local COLS = { { "name", 6, 180, "Name" }, { "ver", 190, 72, "Version" }, { "view", 266, 80, L["Ansicht"] },
               { "where", 350, 60, L["Wo"] }, { "last", 414, 126, L["Zuletzt"] } }

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
    return ns.FmtDay(at)
end

local function buildRow(row)
    for _, col in ipairs(COLS) do
        local fs = W.Text(row, T.FONT.text, col[3])
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
        row.last:SetText(colored(GREY, L["kein Amisia?"]))
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
    row.where:SetText(r.where == "raid" and "Raid" or L["Gilde"])
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

ns.RegisterPanel{ key = "about", label = L["Über und Befehle"], icon = "Interface\\Icons\\INV_Misc_QuestionMark", order = 910, group = "amisia",
    create = function(parent)
        local f = W.Page(parent)
        -- the head row: the version and the self-test; the line under it, a newer version; then who
        -- runs Amisia in raid and guild with the buttons that ask, and the summary
        f:Bands({ "row", "line", "line", "row", "line" })
        f.head = W.Text(f, T.FONT.title)
        -- the in-game self-test: a report of the client to copy into a chat with the developers
        f.selfTest = W.Button(f, L["Selbsttest"], 110, function() if ns.ShowSelfTest then ns.ShowSelfTest() end end)
        W.FitChip(f.selfTest, 110)
        f.selfTest.tip = L["Prüft Namen, Sperren, Gildenränge, Atlanten, Vorlagen und Client-Funktionen und zeigt einen Bericht zum Kopieren. Sendet nichts."]
        tipButton(f.selfTest)
        f:Place(1, { { f.head, fill = true } }, { f.selfTest })
        f.sub = f:Line(2)
        f.newer = f:Line(3)
        f.title = W.Text(f, T.FONT.title, 360)
        f.askGuild = W.Button(f, L["Gilde fragen"], 110, function() ask("guild") end)
        f.askRaid = W.Button(f, L["Raid fragen"], 110, function() ask("raid") end)
        W.FitChip(f.askGuild, 110)
        W.FitChip(f.askRaid, 110)
        tipButton(f.askGuild)
        tipButton(f.askRaid)
        f:Place(4, { f.title }, { f.askRaid, f.askGuild })
        f.summary = f:Line(5)
        local _, heads = f:Columns(COLS)
        f.cols = {}
        for i, col in ipairs(COLS) do f.cols[i] = heads[col[1]] end
        f.list = f:List(ROWS, ROW_H, buildRow, fillRow)
        f.empty = f:Empty()
        f.empty:Set(L["Niemand gesehen"], "")
        -- the commands under the list, down to the page's end
        f.cmdTitle = W.Text(f, T.FONT.title, 300)
        f.cmdTitle:SetPoint("TOPLEFT", f.list, "BOTTOMLEFT", T.LAYOUT.TEXT_X, -6)
        f.cmdTitle:SetText(L["Befehle"])
        f.text = W.ScrollText(f)
        f.text:SetPoint("TOPLEFT", f.list, "BOTTOMLEFT", T.LAYOUT.TEXT_X, -24)
        -- the text ends with the list; its bar lies under the list's
        f.text:SetPoint("BOTTOMRIGHT", -T.SCROLL_ROOM, 0)
        page = f
        return f
    end,
    refresh = function(f)
        refreshAt = GetTime()
        f.head:SetText(L["Amisia %s · Sync-Protokoll %d"]:format(ns.VERSION or "", ns.SYNC_PROTO or 1))
        f.sub:SetText("|cff8f86a3" .. L["Raid-Aufnahme, Loot, Rolls, Soft-Reserves und Export für die Amisia-Loot-Seite."] .. "|r")
        f.title:SetText(L["Amisia in Raid und Gilde"])
        local newer, by = ns.VersionNewer()
        if newer then
            f.newer:SetText(colored(ORANGE, L["Es gibt eine neuere Version: %s (gesehen bei %s). Bitte aktualisieren."]:format(newer, by)))
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
            setButton(f.askRaid, false, L["Addon-Nachrichten sind nicht verfügbar."])
            setButton(f.askGuild, false, L["Addon-Nachrichten sind nicht verfügbar."])
        elseif not on then
            setButton(f.askRaid, false, L["Versionsprüfung ist ausgeschaltet."])
            setButton(f.askGuild, false, L["Versionsprüfung ist ausgeschaltet."])
        else
            setButton(f.askRaid, inRaid, not inRaid and L["Nur in einer Raidgruppe."] or nil)
            local wait = ns.VersionGuildWait()
            if not inGuild then
                setButton(f.askGuild, false, L["Nur in einer Gilde."])
            elseif wait > 0 then
                setButton(f.askGuild, false, L["Wieder in %s."]:format(ns.VersionMinutes(wait)))
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
        local guildText = L["Gilde: %d gesehen"]:format(guildRows)
        -- more clients than rows: the wheel scrolls the list
        if available and #rows > ROWS then
            guildText = guildText .. L[" · %d von %d, Mausrad"]:format(ROWS, #rows)
        end
        if inRaid then
            f.summary:SetText(L["Raid: %d von %d mit Amisia%s · %s"]:format(withAmisia, math.max(#ns.GroupRoster(), raidRows),
                outdated > 0 and L[" · %d veraltet"]:format(outdated) or "", guildText))
        else
            f.summary:SetText(guildText)
        end
        if not available then
            f.list:SetItems({})
            f.empty:SetText(L["Addon-Nachrichten sind nicht verfügbar."])
            f.empty:Show()
        elseif #rows <= 1 then
            f.list:SetItems({})
            f.empty:SetText(L["Noch keine anderen Amisia-Clients gesehen."])
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
