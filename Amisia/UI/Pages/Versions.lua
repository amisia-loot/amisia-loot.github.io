-- Amisia-Versionen (tab Gilde, F-237, spec docs/specs/2026-11-25-amisia-versionen.md, D-170): who runs which
-- Amisia version in raid and guild, over the page's whole height. The rows of the version check
-- (Core/Version.lua, ns.VersionRows: the own client, every hello seen in 30 days, the raid members without an
-- answer after "Raid fragen") and, greyed, every guild member of ns.GuildRoster without a hello ("nichts gehört";
-- "kein Amisia?" only once a guild question of this session had its answers and the member is online). Columns
-- Name (class colour, the online mark of the guild roster), Version, Module, Sprache, Ansicht, Wo, Zuletzt; a click
-- on a head sorts, a second turns it round. The filters Alle, Online, Veraltet, Ohne Amisia and the sort are the
-- session's. The head: the summary, the newer version, "Raid fragen" and "Gilde fragen". Every client: the guild
-- tab is there on TBC and Era too (the page Mitglieder), and without a guild the page shows the raid.
local ADDON, ns = ...
ns.Load(function()
local L = ns.L
local W, T = ns.W, ns.Theme
local V = T.VERSIONS

local page
local filter = "all"            -- all, online, old, none
local sortKey, sortDesc         -- nil: the raid, the guild, then the members without Amisia
local built = {}                -- the rows of the last build and what they were built from

local FILTERS = { "all", "online", "old", "none" }
local SORTS = { name = true, ver = true, mods = true, lang = true, view = true, where = true, last = true }

local function colored(color, text) return color .. text .. "|r" end

---------------------------------------------------------------------------
-- The rows
---------------------------------------------------------------------------
-- The guild roster by lower-case name and by first name (with the count of members of that first name).
local function rosterIndex(roster)
    local low, first = {}, {}
    for _, m in ipairs(roster or {}) do
        local l = m.name:lower()
        low[l] = m
        local f = l:match("^(%S+)")
        local e = first[f]
        if e then e.n = e.n + 1 else first[f] = { m = m, n = 1 } end
    end
    return { low = low, first = first }
end

-- The member of a name: the same spelling, else the one member with its first name when one side has no
-- surname (as ns.SameName).
local function memberOf(idx, name)
    local l = name:lower()
    local m = idx.low[l]
    if m then return m end
    local e = idx.first[l:match("^(%S+)") or l]
    if e and e.n == 1 and (not l:find(" ", 1, true) or not e.m.name:find(" ", 1, true)) then return e.m end
    return nil
end

local function langWord(lc)
    local UI = ns.UnitInfo
    return UI and UI.LangWord and UI.LangWord(lc) or nil
end

-- What the rows are built from: the same seen list, roster, group, questions and view give the same rows.
local function buildKey(roster)
    local keeper = ns.SyncKeeperName and ns.SyncKeeperName() or ""
    return table.concat({ tostring(ns.VersionSeenRev()), tostring(roster), tostring(#ns.GroupRoster()),
        tostring(ns.HomeRaid()), tostring(ns.VersionAnswered("raid")), tostring(ns.VersionAnswered("guild")),
        tostring(ns.IsOfficerView()), tostring(keeper), tostring(ns.Get("sync.versionCheck")) }, "|")
end

-- Every row: the version rows (ns.VersionRows) with online (from the roster; in the raid and the own: true),
-- class, mods (ns.VersionModuleKeys), word (the language), fold, order; then the members without a hello
-- ({ none = true, verdict = "kein Amisia?" may be said }), the online ones first.
local function build()
    local roster = ns.GuildRoster and ns.GuildRoster() or nil
    local key = buildKey(roster)
    if built.rows and built.key == key and built.db == AmisiaDB then return built.rows end
    local rows = ns.VersionRows()
    local idx = rosterIndex(roster)
    local matched = {}
    for _, r in ipairs(rows) do
        local m = memberOf(idx, r.name)
        if m then
            matched[m] = true
            r.online = m.online and true or false
            if not r.class and m.class and m.class ~= "" then r.class = m.class end
        else
            r.online = r.self or r.where == "raid"
        end
        if r.self and not r.class and type(UnitClass) == "function" then
            local _, c = UnitClass("player")
            r.class = ns.Plain(c)
        end
        if r.v then
            r.mods = ns.VersionModuleKeys(r)
            r.word = langWord(r.lc)
            r.viewText = ns.VersionView(r)
        end
    end
    local answered = ns.VersionAnswered("guild")
    local none = {}
    for _, m in ipairs(roster or {}) do
        if not matched[m] and not m.self then
            none[#none + 1] = { name = m.name, class = m.class ~= "" and m.class or nil, online = m.online and true or false,
                                where = "guild", none = true, verdict = (answered and m.online) and true or nil }
        end
    end
    for _, r in ipairs(none) do r.fold = ns.Fold(r.name) end
    table.sort(none, function(a, b)
        if a.online ~= b.online then return a.online end
        return a.fold < b.fold
    end)
    for _, r in ipairs(none) do rows[#rows + 1] = r end
    for i, r in ipairs(rows) do
        r.order = i
        r.fold = r.fold or ns.Fold(r.name)
    end
    built = { rows = rows, key = key, db = AmisiaDB }
    return rows
end
ns.VersionsPageRows = build

local function passes(r, f)
    if f == "online" then return r.online == true end
    if f == "old" then return (r.outdated or r.tooOld) and true or false end
    if f == "none" then return (r.none or r.missing) and true or false end
    return true
end

-- The value a row sorts by; nil (no version, never seen) stands last either way.
local function valueOf(r, key)
    if key == "name" then return r.fold end
    if key == "where" then return r.where == "raid" and 0 or 1 end
    if not r.v then return nil end
    if key == "ver" then return r.v end
    if key == "mods" then return #(r.mods or {}) end
    if key == "lang" then return r.word and ns.Fold(r.word) or nil end
    if key == "view" then return ns.Fold(r.viewText or "") end
    if key == "last" then return r.at end
    return nil
end

local function compare(a, b)
    local x, y = valueOf(a, sortKey), valueOf(b, sortKey)
    if x == nil or y == nil then
        if (x == nil) ~= (y == nil) then return y == nil end
        return a.order < b.order
    end
    if sortKey == "ver" then
        local c = ns.CompareVersion(x, y)
        if c ~= 0 then
            if sortDesc then return c > 0 end
            return c < 0
        end
    elseif x ~= y then
        if sortDesc then return x > y end
        return x < y
    end
    return a.order < b.order
end

-- The rows the filter leaves, sorted, and the counts { all, amisia, online, old, none, noRaid, versions =
-- { { v, n } } most common first }.
local function shownRows(rows)
    local out = {}
    local n = { all = #rows, amisia = 0, online = 0, old = 0, none = 0, noRaid = 0 }
    local byV = {}
    for _, r in ipairs(rows) do
        if passes(r, filter) then out[#out + 1] = r end
        if r.v then
            n.amisia = n.amisia + 1
            byV[r.v] = (byV[r.v] or 0) + 1
        end
        if r.online then n.online = n.online + 1 end
        if r.outdated or r.tooOld then n.old = n.old + 1 end
        if r.none or r.missing then n.none = n.none + 1 end
        if r.noRaid then n.noRaid = n.noRaid + 1 end
    end
    local vs = {}
    for v, c in pairs(byV) do vs[#vs + 1] = { v = v, n = c } end
    table.sort(vs, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return ns.CompareVersion(a.v, b.v) > 0
    end)
    n.versions = vs
    if sortKey then table.sort(out, compare) end
    return out, n
end

-- "14 mit Amisia · 9× 2.110.0 · 3× 2.109.0 · 1 weitere · 2 veraltet"
local function summaryText(n)
    local parts = { L["%d mit Amisia"]:format(n.amisia) }
    for i = 1, math.min(V.VERSIONS, #n.versions) do
        parts[#parts + 1] = L["%d× %s"]:format(n.versions[i].n, n.versions[i].v)
    end
    if #n.versions > V.VERSIONS then parts[#parts + 1] = L["%d weitere"]:format(#n.versions - V.VERSIONS) end
    if n.old > 0 then parts[#parts + 1] = L["%d veraltet"]:format(n.old) end
    if n.noRaid > 0 then parts[#parts + 1] = L["%d ohne Raid"]:format(n.noRaid) end
    return table.concat(parts, " · ")
end
ns.VersionsSummaryText = summaryText

---------------------------------------------------------------------------
-- What a row shows
---------------------------------------------------------------------------
local MOD_NAMES = { gear = L["Ausrüstung"], dungeons = L["Dungeons & Raids"], talents = L["Talente"] }

local function lastText(at)
    if type(at) ~= "number" then return "-" end
    if date("%Y-%m-%d", at) == date("%Y-%m-%d", time()) then return date("%H:%M", at) end
    return ns.FmtDay(at)
end

-- The word of a row without Amisia: "kein Amisia?" after an unanswered question, else "nichts gehört".
local function silentText(r)
    if r.missing or r.verdict then return L["kein Amisia?"] end
    return L["nichts gehört"]
end

local function versionText(r)
    local v = tostring(r.v)
    if r.noRaid then return colored(T.GREY, v) end
    if r.self and r.tooOld then return colored(T.RED, v) end
    if r.outdated or r.tooOld then return colored(T.ORANGE, v) end
    return v
end

-- The lines of a row's tooltip (also for the tests): { text, r, g, b }
function ns.VersionsTooltipLines(r)
    local out = {}
    local function add(text, cr, cg, cb) out[#out + 1] = { text, cr or 0.85, cg or 0.85, cb or 0.85 } end
    local grey = 0.6
    if not r.v then
        add(silentText(r))
        if r.missing then
            add(L["Hat auf \"Raid fragen\" nicht geantwortet."], grey, grey, grey)
        elseif r.verdict then
            add(L["Online und ohne Antwort auf \"Gilde fragen\": wohl kein Amisia."], grey, grey, grey)
        else
            add(L["Amisia meldet sich einmal nach dem Login; von diesem Mitglied kam in 30 Tagen kein Hallo. \"Gilde fragen\" klärt es für alle, die online sind."], grey, grey, grey)
        end
        if r.none then add(r.online and L["online"] or L["offline"], grey, grey, grey) end
        return out
    end
    add(L["Version %s"]:format(tostring(r.v)))
    if r.noRaid then
        add(L["Amisia ohne den Raid-Teil."], grey, grey, grey)
    elseif r.tooOld then
        add(L["Zu alt für den Abgleich mit dem Hüter."], 1, 0.3, 0.3)
    elseif r.outdated then
        add(L["Älter als die neueste gesehene Version."], 0.88, 0.64, 0.27)
    end
    if ns.FOREVER then
        local names = {}
        for _, k in ipairs(r.mods or {}) do names[#names + 1] = MOD_NAMES[k] end
        add(#names > 0 and L["Module: %s"]:format(table.concat(names, ", ")) or L["Module: keine"])
    end
    add(r.word and L["Spielsprache: %s"]:format(r.word) or L["Spielsprache: unbekannt"])
    add(L["Ansicht: %s"]:format(r.viewText or ns.VersionView(r)))
    if r.self then
        add(L["Das bist du."], grey, grey, grey)
    else
        add(r.where == "raid" and L["Gesehen im Raid"] or L["Gesehen in der Gilde"], grey, grey, grey)
        if type(r.at) == "number" then add(L["Zuletzt gesehen: %s"]:format(ns.FmtDayTime(r.at)), grey, grey, grey) end
    end
    return out
end

local function rowTooltip(self)
    local r = self.item
    if not r then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(ns.ClassColored(r.name, r.class), 1, 0.82, 0)
    for _, l in ipairs(ns.VersionsTooltipLines(r)) do GameTooltip:AddLine(l[1], l[2], l[3], l[4], true) end
    GameTooltip:Show()
end

local function colOf(key)
    for _, c in ipairs(V.COLS) do
        if c[1] == key then return c end
    end
end

local function buildRow(row)
    row.dot = row:CreateTexture(nil, "ARTWORK")
    row.dot:SetSize(V.DOT, V.DOT)
    row.dot:SetPoint("LEFT", V.DOT_X, 0)
    row.dot:SetTexture(V.ONLINE_ICON)
    local cells = {}
    for _, c in ipairs(V.COLS) do
        cells[#cells + 1] = { c[1], c[2], c[3], cell = c[1] ~= "mods" }
    end
    W.Cells(row, cells)
    -- the modules: the symbols of their tabs, side by side
    local mx = colOf("mods")[2]
    row.mods = {}
    for i = 1, 3 do
        local t = row:CreateTexture(nil, "ARTWORK")
        t:SetSize(V.MOD_ICON, V.MOD_ICON)
        t:SetPoint("LEFT", mx + (i - 1) * (V.MOD_ICON + V.MOD_GAP), 0)
        t:Hide()
        row.mods[i] = t
    end
    row:SetScript("OnEnter", rowTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function fillRow(row, r)
    row.dot:SetShown(r.online == true)
    for _, t in ipairs(row.mods) do t:Hide() end
    if not r.v then
        row.name:SetText(colored(T.GREY, r.name))
        row.ver:SetText(colored(T.GREY, "-"))
        row.lang:SetText("")
        row.view:SetText(colored(T.GREY, "-"))
        row.where:SetText(colored(T.GREY, r.where == "raid" and "Raid" or L["Gilde"]))
        row.last:SetText(colored(T.GREY, silentText(r)))
        return
    end
    row.name:SetText(ns.ClassColored(r.name, r.class))
    row.ver:SetText(versionText(r))
    if ns.FOREVER then
        for i, k in ipairs(r.mods or {}) do
            local art = T.TAB_ICONS[k]
            local t = row.mods[i]
            if t and art and art.file then
                t:SetTexture(art.file)
                t:Show()
            end
        end
    end
    row.lang:SetText(r.word or colored(T.GREY, "-"))
    row.view:SetText(r.viewText or ns.VersionView(r))
    row.where:SetText(r.where == "raid" and "Raid" or L["Gilde"])
    row.last:SetText(lastText(r.at))
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------
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

local function buildPage(parent)
    local f = W.Page(parent)
    page = f
    -- the head row: the filters, the questions; the summary; a newer version
    f:Bands({ "row", "line", "line" })
    local names = { all = L["Alle"], online = L["Online"], old = L["Veraltet"], none = L["Ohne Amisia"] }
    local tips = { all = L["Jeder mit Amisia und die Mitglieder, von denen nichts kam."],
        online = L["Nur wer gerade online ist (Gildenliste, Raid)."],
        old = L["Nur ältere Versionen als die neueste gesehene, und zu alte für den Hüter."],
        none = L["Mitglieder ohne Hallo von Amisia und Raidmitglieder ohne Antwort."] }
    f.tabs = {}
    for _, k in ipairs(FILTERS) do
        f.tabs[k] = W.Tab(f, names[k], function()
            filter = k
            ns.Refresh()
        end)
        W.Tooltip(f.tabs[k], names[k], tips[k])
    end
    f.askGuild = W.Link(f, L["Gilde fragen"], function() ask("guild") end)
    f.askRaid = W.Link(f, L["Raid fragen"], function() ask("raid") end)
    W.FitChip(f.askGuild)
    W.FitChip(f.askRaid)
    tipButton(f.askGuild)
    tipButton(f.askRaid)
    f:Place(1, { f.tabs.all, f.tabs.online, f.tabs.old, f.tabs.none }, { f.askRaid, f.askGuild })
    f.summary = f:Line(2)
    f.newer = f:Line(3)
    f:Footer({ "data" })

    local heads = { name = L["Name"], ver = "Version", mods = ns.FOREVER and L["Module"] or "", lang = L["Sprache"],
        view = L["Ansicht"], where = L["Wo"], last = L["Zuletzt"] }
    local cols = {}
    for _, c in ipairs(V.COLS) do cols[#cols + 1] = { c[1], c[2], c[3], heads[c[1]] } end
    f.headFrame, f.heads = f:Columns(cols, { sort = function(key)
        if not SORTS[key] then return end
        if sortKey == key then
            sortDesc = (not sortDesc) or nil
        else
            sortKey, sortDesc = key, (key == "ver" or key == "last" or key == "mods") or nil
        end
        ns.Refresh()
    end })
    for _, c in ipairs(cols) do
        if c[4] ~= "" then W.Tooltip(f.heads[c[1]], c[4], L["Klicken sortiert, ein zweiter Klick dreht die Reihenfolge um."]) end
    end
    f.list = f:List(V.ROWS, V.ROW_H, buildRow, fillRow, { fill = true })
    f.empty = f:Empty()
    return f
end

local function refreshLinks(f)
    local available = ns.CommAvailable()
    local on = available and ns.Get("sync.versionCheck") ~= false
    if not available then
        setButton(f.askRaid, false, L["Addon-Nachrichten sind nicht verfügbar."])
        setButton(f.askGuild, false, L["Addon-Nachrichten sind nicht verfügbar."])
    elseif not on then
        setButton(f.askRaid, false, L["Versionsprüfung ist ausgeschaltet."])
        setButton(f.askGuild, false, L["Versionsprüfung ist ausgeschaltet."])
    else
        local inRaid = ns.HomeRaid()
        setButton(f.askRaid, inRaid, not inRaid and L["Nur in einer Raidgruppe."] or nil)
        local wait = ns.VersionGuildWait()
        if not ns.InGuild() then
            setButton(f.askGuild, false, L["Nur in einer Gilde."])
        elseif wait > 0 then
            setButton(f.askGuild, false, L["Wieder in %s."]:format(ns.VersionMinutes(wait)))
        else
            setButton(f.askGuild, true, nil)
        end
    end
end

local rosterAskedAt           -- when the page last asked the client for the guild roster

local function refresh(f)
    refreshLinks(f)
    if ns.InGuild() and not (ns.ChatLocked and ns.ChatLocked()) and (not rosterAskedAt or GetTime() - rosterAskedAt > 60) then
        rosterAskedAt = GetTime()
        if ns.RequestGuildRoster then ns.RequestGuildRoster() end
    end
    local rows = build()
    local shown, n = shownRows(rows)
    for k, tab in pairs(f.tabs) do
        tab.dim = (k == "old" and n.old == 0) or (k == "none" and n.none == 0) or nil
        tab:SetOn(k == filter)
    end
    W.MarkSortHead(f.heads, sortKey)
    f.summary:SetText(summaryText(n))
    local newer, by = ns.VersionNewer()
    if newer then
        f.newer:SetText(colored(T.ORANGE, L["Es gibt eine neuere Version: %s (gesehen bei %s). Bitte aktualisieren."]:format(newer, by)))
        f.newer:Show()
    else
        f.newer:SetText("")
        f.newer:Hide()
    end
    f.list:SetItems(shown)
    if #shown == 0 then
        f.empty:Set(L["Nichts gefunden"], L["Kein Eintrag passt zu diesem Filter."])
        f.empty:Show()
    else
        f.empty:Hide()
    end
    local hint = L["Amisia meldet sich einmal nach dem Login bei der Gilde; die Liste vergisst ein Hallo nach 30 Tagen."]
    if not ns.CommAvailable() then hint = L["Addon-Nachrichten sind nicht verfügbar."] end
    if ns.ChatLocked and ns.ChatLocked() then hint = hint .. " · " .. L["Stand vor der Kampfsperre"] end
    f.data:SetText(hint)
end

ns.RegisterPanel{ key = "versions", label = L["Amisia-Versionen"], sub = L["Wer in Gilde und Raid Amisia hat, welche Version, Module und Sprache."],
    icon = "Interface\\Icons\\INV_Misc_Note_01", order = 78, group = "guild", create = buildPage, refresh = refresh }

-- for the tests and the snapshots: the filter and the sort ("all", "online", "old", "none"; a column key or nil)
function ns.VersionsPageState(f, key, desc)
    if f then filter = f end
    if key ~= nil then
        if key == false then sortKey, sortDesc = nil, nil else sortKey, sortDesc = key, desc or nil end
    end
    return filter, sortKey, sortDesc
end

---------------------------------------------------------------------------
-- Following versions, roster and group, only while the page is shown (at most once a second)
---------------------------------------------------------------------------
local function shown() return page ~= nil and page:IsVisible() and ns.CurrentPage and ns.CurrentPage() == "versions" end
local follow = W.RefreshWhileShown(shown, 1)
ns.Listen("SYNC_VERSIONS", follow)
ns.Listen("SYNC_STATE", follow)
for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "ADDON_RESTRICTION_STATE_CHANGED" }) do ns.OnEvent(event, follow) end
-- the roster is built again at most every 10 s (Core/Trust.lua): a change right after a build shows after that
-- gap, so one more refresh follows then
local again = false
local function onRoster()
    if not shown() then return end
    follow()
    if again then return end
    again = true
    C_Timer.After(11, function()
        again = false
        follow()
    end)
end
for _, event in ipairs({ "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE", "CLUB_MEMBER_ADDED", "CLUB_MEMBER_REMOVED",
                         "CLUB_MEMBER_UPDATED", "CLUB_MEMBERS_UPDATED" }) do
    ns.OnEvent(event, onRoster)
end
end)
