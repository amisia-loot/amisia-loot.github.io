-- Aufrufe (tab Gilde, F-211, D-136, spec docs/specs/2026-11-15-gilde-aufrufe.md): the guild's calls of
-- Raid/GuildCalls.lua. Three views under one head row: the calls of the others (a row each: title and time,
-- art, creator in class colour and the level from, the roles "Tank 1/1 · Heiler 0/1 · Schaden 2/3" with the
-- sign-ups and the time left, the note; "Anmelden" with a role or "Abmelden"), filtered by art with text tabs;
-- the form "Aufruf erstellen" (art, dungeon from Amisia's data with the gear module, title, level from, time,
-- the roles, the note); the creator's view of the own call (the sign-ups with name, level, role, item level
-- and status, "Einladen" and "Ablehnen" under the mouse, "Alle einladen" as the red button with the reason
-- when inviting is off, "Beenden"). A click on [Anmelden] in the chat opens the page at that call.
local ADDON, ns = ...
ns.Load(function()
local L = ns.L
local W, T = ns.W, ns.Theme
local C = T.CALLS

local page
local mode = "list"          -- "list", "form" or "mine"
local filter = "all"
local form = {}              -- the form's values while it is open
local formError

local function GC() return ns.GuildCalls end

local FILTERS = { "all", "D", "Q", "H", "S" }

local function label(parent, text)
    local fs = W.Text(parent, T.FONT.text)
    fs:SetText(text)
    fs:SetWidth(fs:GetStringWidth() + 2)
    return fs
end

---------------------------------------------------------------------------
-- The calls of the others
---------------------------------------------------------------------------
local function roleMenu(owner, c)
    local need, _, inGroup = GC().Counts(c)
    local entries = { { L["Anmelden als"], head = true } }
    for _, r in ipairs(GC().ROLES) do
        local left = (need[r] or 0) - (inGroup[r] or 0)
        local text = GC().ROLE_NAMES[r] .. (left > 0 and (" " .. T.GREY .. L["(%d gesucht)"]:format(left) .. "|r") or "")
        entries[#entries + 1] = { text, function()
            local ok, why = GC().SignUp(c.low, r)
            if not ok and why then ns.msg(why) end
            ns.Refresh()
        end }
    end
    W.Menu(owner, entries)
end

local function buildRow(r)
    r.title = W.Text(r, T.FONT.title, C.TITLE_W)
    r.title:SetPoint("TOPLEFT", C.PAD, C.LINE1_Y)
    r.when = W.Text(r, T.FONT.body, C.WHEN_W)
    r.when:SetPoint("TOPRIGHT", -C.PAD, C.LINE1_Y)
    r.when:SetJustifyH("RIGHT")
    r.info = W.Text(r, T.FONT.text, C.INFO_W)
    r.info:SetPoint("TOPLEFT", C.PAD, C.LINE2_Y)
    r.roles = W.Text(r, T.FONT.text, C.INFO_W)
    r.roles:SetPoint("TOPLEFT", C.PAD, C.LINE3_Y)
    r.note = W.Text(r, T.FONT.hint, C.NOTE_W)
    r.note:SetPoint("TOPLEFT", C.PAD, C.LINE4_Y)
    r.sel = W.SelectBar(r)
    r.action = W.Link(r, L["Anmelden##Aufruf"], function(self)
        local c = self:GetParent().call
        if not c then return end
        if GC().MySignup(c.low) then
            local ok, why = GC().Withdraw(c.low)
            if not ok and why then ns.msg(why) end
            ns.Refresh()
        else
            roleMenu(self, c)
        end
    end)
    r.action:SetPoint("RIGHT", r, "TOPRIGHT", -C.PAD + T.TAB_PAD, C.ACTION_Y)
end

local function fillRow(r, c)
    r.call = c
    r.title:SetText(GC().Title(c))
    local _, _, _, isFull = GC().Counts(c)
    r.when:SetText(isFull and (C.FULL .. L["voll"] .. "|r") or GC().WhenText(c))
    r.info:SetText(T.GREY .. GC().ART_NAMES[c.art] .. " · " .. L["von %s"]:format("|r" .. ns.ClassColored(c.by, c.class) .. T.GREY)
        .. " · " .. L["ab Stufe %d##Aufruf"]:format(c.min) .. "|r")
    local signed = GC().SignedCount(c)
    local role = GC().MySignup(c.low)
    local text = GC().RolesText(c) .. T.GREY .. " · " .. L["%d angemeldet"]:format(signed) .. " · " .. GC().LeftText(c) .. "|r"
    r.roles:SetText(text)
    r.note:SetText(c.note or "")
    r.sel:SetShown(GC().Focus() == c.low)
    if role then
        r.action:SetText(L["Abmelden##Aufruf"])
    else
        r.action:SetText(L["Anmelden##Aufruf"])
    end
    W.FitChip(r.action)
    W.Tooltip(r.action, role and L["Abmelden##Aufruf"] or L["Anmelden##Aufruf"], function()
        if role then return L["Angemeldet als %s. Ein Klick meldet dich wieder ab."]:format(GC().ROLE_NAMES[role]) end
        return L["Wähle deine Rolle; der Ersteller sieht dich dann unter den Anmeldungen und lädt dich ein."]
    end)
end

---------------------------------------------------------------------------
-- The creator's view
---------------------------------------------------------------------------
local function statusText(s)
    if ns.InMyGroup(s.n) then return T.GREEN .. L["in der Gruppe"] .. "|r" end
    if GC().Invited(s.n) then return L["eingeladen"] end
    if not GC().Online(s.n) then return T.GREY .. L["offline"] .. "|r" end
    return T.GREY .. "-|r"
end

local function itemLevel(name)
    local view = ns.GuildCharsView and ns.GuildCharsView()
    local v = view and view[name:lower()]
    return v and v.il or nil
end

local function buildMineRow(r)
    W.Cells(r, C.COLS)
    r.invite = W.Link(r, L["Einladen"], function(self)
        local s = self:GetParent().signup
        if not s then return end
        local ok, why = GC().Invite(s.n)
        if not ok and why then ns.msg(why) end
        ns.Refresh()
    end)
    r.decline = W.Link(r, L["Ablehnen"], function(self)
        local s = self:GetParent().signup
        if s then GC().Decline(s.n) end
        ns.Refresh()
    end)
    r.decline:SetPoint("RIGHT", -C.PAD + T.TAB_PAD, 0)
    r.invite:SetPoint("RIGHT", r.decline, "LEFT", -C.ACTION_GAP, 0)
    W.RowAction(r, r.invite)
    W.RowAction(r, r.decline)
    W.Tooltip(r.invite, L["Einladen"], function()
        local s = r.signup
        local _, why = GC().InviteBlocked()
        if why then return why end
        if s and not GC().Online(s.n) then return L["%s ist offline."]:format(s.n) end
        return L["Lädt diesen Spieler in deine Gruppe ein."]
    end)
    W.Tooltip(r.decline, L["Ablehnen"], L["Nimmt die Anmeldung heraus; für diesen Aufruf kann sich der Spieler nicht wieder anmelden."])
end

local function fillMineRow(r, s)
    r.signup = s
    local off = not GC().Online(s.n)
    r.name:SetText(off and (T.GREY .. s.n .. "|r") or ns.ClassColored(s.n, s.c))
    r.level:SetText(s.l and tostring(s.l) or "-")
    r.role:SetText(GC().ROLE_NAMES[s.r])
    local il = itemLevel(s.n)
    r.il:SetText(il and tostring(il) or "-")
    r.status:SetText(statusText(s))
    W.FitChip(r.invite)
    W.FitChip(r.decline)
    local blocked = GC().InviteBlocked()
    r.invite:SetEnabled(not blocked and not off and not ns.InMyGroup(s.n))
end

---------------------------------------------------------------------------
-- The form
---------------------------------------------------------------------------
local function resetForm()
    form = { art = "D", min = math.max(1, math.min(99, tonumber(ns.Plain(UnitLevel("player"))) or 1)), time = "now",
             need = { T = 1, H = 1, S = 3 } }
    formError = nil
end

local function artValues()
    local out = {}
    for _, a in ipairs(GC().ARTS) do out[#out + 1] = { value = a, text = GC().ART_NAMES[a] } end
    return out
end

local function dungeonValues()
    local list = GC().DungeonChoices()
    if not list then return nil end
    local out = {}
    for _, d in ipairs(list) do
        out[#out + 1] = { value = d.key, text = d.min and ("%s (%d)"):format(d.name, d.min) or d.name, min = d.min, name = d.name }
    end
    return out
end

local function submit(f)
    form.title = f.titleBox:GetText()
    form.note = f.noteBox:GetText()
    form.clock = f.timeBox:GetText()
    local at = 0
    if form.time == "clock" then
        at = GC().ParseTime(form.clock)
        if not at then
            formError = L["Die Uhrzeit fehlt oder ist falsch (z. B. 20:30)."]
            ns.Refresh()
            return
        end
    end
    local ok, why = GC().Create({ art = form.art, key = form.art == "D" and form.key or nil, title = form.title, min = form.min,
        at = at, need = form.need, note = form.note })
    if not ok then
        formError = why
        ns.Refresh()
        return
    end
    resetForm()
    f.titleBox:SetText("")
    f.noteBox:SetText("")
    f.timeBox:SetText("")
    mode = "mine"
    ns.Refresh()
end

local function buildForm(f)
    local V = W.Page(f, { view = true })
    f.formView = V
    V:Bands({ "row", "row", "row", "row", "row", "line" })
    f.artLabel = label(V, L["Art"])
    f.art = W.Picker(V, C.ART_W, function(v)
        form.art = v or "D"
        ns.Refresh()
    end)
    f.dungeonLabel = label(V, L["Dungeon"])
    f.dungeon = W.Picker(V, C.DUNGEON_W, function(v)
        local prev = form.key
        form.key = v
        for _, d in ipairs(f.dungeon.values or {}) do
            if d.value == v then
                local text = f.titleBox:GetText()
                local prevName
                for _, o in ipairs(f.dungeon.values) do if o.value == prev then prevName = o.name end end
                if text == "" or text == prevName then f.titleBox:SetText(GC().Clean(d.name, GC().TITLE_CHARS) or "") end
                if d.min then
                    form.min = d.min
                end
            end
        end
        ns.Refresh()
    end)
    f.titleLabel = label(V, L["Titel"])
    f.titleBox = W.LineEdit(V, C.DUNGEON_W)
    if f.titleBox.SetMaxLetters then f.titleBox:SetMaxLetters(GC().TITLE_CHARS) end
    f.levelLabel = label(V, L["Stufe ab"])
    f.level = W.NumberStepper(V, C.LEVEL_W, function(v) form.min = v end)
    f.level:Configure(1, 99, 1)
    f.timeLabel = label(V, L["Zeit"])
    f.timeMode = W.Picker(V, C.TIME_MODE_W, function(v)
        form.time = v or "now"
        ns.Refresh()
    end)
    f.timeMode:SetValues({ { value = "now", text = L["jetzt"] }, { value = "clock", text = L["Uhrzeit"] } })
    f.timeBox = W.TimeBox(V, C.TIME_W)
    if f.timeBox.SetMaxLetters then f.timeBox:SetMaxLetters(5) end
    f.roleLabels, f.roleSteppers = {}, {}
    for _, r in ipairs(GC().ROLES) do
        f.roleLabels[r] = label(V, GC().ROLE_NAMES[r])
        f.roleSteppers[r] = W.NumberStepper(V, C.ROLE_W, function(v) form.need[r] = v end)
        f.roleSteppers[r]:Configure(0, 40, 1)
    end
    f.noteLabel = label(V, L["Notiz"])
    f.noteBox = W.LineEdit(V, C.DUNGEON_W)
    if f.noteBox.SetMaxLetters then f.noteBox:SetMaxLetters(GC().NOTE_CHARS) end
    f.formHint = V:Line(6)
    -- the labels share one width, so the fields stand in a column
    local w = 0
    for _, fs in ipairs({ f.artLabel, f.titleLabel, f.levelLabel, f.roleLabels.T, f.noteLabel }) do w = math.max(w, fs:GetWidth()) end
    for _, fs in ipairs({ f.artLabel, f.titleLabel, f.levelLabel, f.roleLabels.T, f.noteLabel }) do fs:SetWidth(w) end
    V:Place(2, { f.titleLabel, { f.titleBox, fill = true } })
    V:Place(4, { f.roleLabels.T, f.roleSteppers.T, f.roleLabels.H, f.roleSteppers.H, f.roleLabels.S, f.roleSteppers.S })
    V:Place(5, { f.noteLabel, { f.noteBox, fill = true } })
end

local function refreshForm(f)
    -- every item of a band placed with opts.shown says whether it shows
    f.art:Show()
    f.level:Show()
    f.timeMode:Show()
    f.art:SetValues(artValues())
    f.art:SetValue(form.art)
    local dungeons = form.art == "D" and dungeonValues() or nil
    f.dungeonLabel:SetShown(dungeons ~= nil)
    f.dungeon:SetShown(dungeons ~= nil)
    if dungeons then
        f.dungeon:SetValues(dungeons)
        f.dungeon:SetValue(form.key)
        if not form.key then f.dungeon.label:SetText(T.GREY .. L["Dungeon wählen"] .. "|r") end
    end
    f.formView:Place(1, { f.artLabel, f.art, f.dungeonLabel, f.dungeon }, nil, { shown = true })
    f.level:SetValue(form.min)
    f.timeMode:SetValue(form.time)
    f.timeBox:SetShown(form.time == "clock")
    f.formView:Place(3, { f.levelLabel, f.level, f.timeLabel, f.timeMode, f.timeBox }, nil, { shown = true })
    for _, r in ipairs(GC().ROLES) do f.roleSteppers[r]:SetValue(form.need[r] or 0) end
    local sum = (form.need.T or 0) + (form.need.H or 0) + (form.need.S or 0)
    if formError then
        f.formHint:SetText(T.RED .. formError .. "|r")
    else
        f.formHint:SetText(L["Gesucht: %d Spieler (zusammen 1 bis 40). Der Aufruf gilt bis 2 Stunden nach seiner Zeit."]:format(sum))
    end
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------
local function build(parent)
    local f = W.Page(parent)
    page = f
    resetForm()
    f:Bands({ "row" })
    f.tabs = {}
    local names = { all = L["Alle"], D = L["Dungeon"], Q = L["Quest"], H = L["Hilfe"], S = L["Sonstiges"] }
    for _, k in ipairs(FILTERS) do
        f.tabs[k] = W.Tab(f, names[k], function()
            filter = k
            ns.Refresh()
        end)
    end
    f.back = W.Link(f, L["Zurück"], function()
        mode = "list"
        formError = nil
        ns.Refresh()
    end)
    f.endLink = W.Link(f, L["Beenden##Aufruf"], function()
        W.Confirm(L["Aufruf beenden"], L["Der Aufruf verschwindet bei allen; die Anmeldungen gehen verloren."], L["Beenden##Aufruf"], function()
            GC().End()
            mode = "list"
            ns.Refresh()
        end)
    end)
    f.main = W.Button(f, L["Aufruf erstellen"], nil, function()
        if mode == "form" then
            submit(f)
        elseif mode == "mine" then
            local ok, why = GC().InviteAll()
            if not ok and why then ns.msg(why) end
            ns.Refresh()
        elseif GC().Own() then
            mode = "mine"
            ns.Refresh()
        else
            mode = "form"
            ns.Refresh()
        end
    end)
    W.Tooltip(f.main, L["Aufrufe"], function()
        if mode == "form" then return L["Schickt den Aufruf an die Gildenmitglieder mit Amisia."] end
        if mode == "mine" then
            local _, why = GC().InviteBlocked()
            return why or L["Lädt die Angemeldeten in Anmeldereihenfolge ein, so viele, wie die Rollen brauchen; ab 6 wird die Gruppe ein Schlachtzug."]
        end
        return GC().Own() and L["Deine Anmeldungen und Einladen."] or L["Ein Aufruf für einen Dungeon, eine Quest oder Hilfe."]
    end)
    f:Footer({ "data" })

    -- the calls
    local LV = W.Page(f, { view = true })
    f.listView = LV
    f.list = LV:List(C.ROWS, C.ROW_H, buildRow, fillRow)
    f.empty = LV:Empty()
    -- the form
    buildForm(f)
    -- the own call
    local MV = W.Page(f, { view = true })
    f.mineView = MV
    MV:Bands({ "line", "line" })
    f.summary = MV:Line(1)
    f.summary2 = MV:Line(2)
    local cols = {}
    local heads = { name = L["Name"], level = L["Stufe"], role = L["Rolle"], il = L["iLvl"], status = L["Status"] }
    for _, c in ipairs(C.COLS) do cols[#cols + 1] = { c[1], c[2], c[3], heads[c[1]] } end
    MV:Columns(cols)
    f.mineList = MV:List(C.MINE_ROWS, C.MINE_ROW_H, buildMineRow, fillMineRow)
    f.mineEmpty = MV:Empty()
    return f
end

local function refresh(f)
    local own = GC().Own()
    if mode == "mine" and not own then mode = "list" end
    if mode == "form" and own then mode = "mine" end
    -- a click on [Anmelden] in the chat: the list at that call
    local focus = GC().Focus()
    if focus and mode ~= "list" and not f.focusSeen then mode = "list" end
    f.focusSeen = focus
    f.listView:SetShown(mode == "list")
    f.formView:SetShown(mode == "form")
    f.mineView:SetShown(mode == "mine")
    for k, tab in pairs(f.tabs) do
        tab:SetShown(mode == "list")
        tab:SetOn(k == filter)
    end
    f.back:SetShown(mode ~= "list")
    f.endLink:SetShown(mode == "mine")
    local blocked, why
    if mode == "form" then
        f.main:SetText(L["Aufruf senden"])
        f.main:Enable()
    elseif mode == "mine" then
        blocked, why = GC().InviteBlocked()
        if GC().Running() then
            f.main:SetText(L["Lädt ein ..."])
            f.main:Disable()
        elseif blocked then
            f.main:SetText(why)
            f.main:Disable()
        else
            f.main:SetText(L["Alle einladen"])
            f.main:SetEnabled(#GC().InviteList() > 0)
        end
    else
        f.main:SetText(own and L["Mein Aufruf"] or L["Aufruf erstellen"])
        f.main:SetEnabled(own ~= nil or ns.InGuild())
    end
    f.main:Show()
    W.FitChip(f.main, nil, C.DUNGEON_W)
    local left = mode == "list" and { f.tabs.all, f.tabs.D, f.tabs.Q, f.tabs.H, f.tabs.S } or { f.back }
    f:Place(1, left, mode == "mine" and { f.endLink, f.main } or { f.main }, { shown = true })

    if mode == "form" then
        refreshForm(f)
        f.data:SetText(L["Höchstens ein eigener Aufruf zur Zeit."])
        return
    end

    if mode == "mine" then
        local c = own
        local title = GC().Title(c)
        f.summary:SetText(("%s · %s · %s · %s"):format(title, GC().ART_NAMES[c.art], L["ab Stufe %d##Aufruf"]:format(c.min), GC().WhenText(c)))
        local _, _, _, isFull = GC().Counts(c)
        f.summary2:SetText(GC().RolesText(c) .. " · " .. L["%d angemeldet"]:format(#c.signups) .. " · " .. GC().LeftText(c)
            .. (isFull and (" · " .. C.FULL .. L["voll"] .. "|r") or ""))
        f.mineList:SetItems(c.signups)
        if #c.signups == 0 then
            f.mineEmpty:Set(L["Noch keine Anmeldungen"], L["Wer sich anmeldet, steht hier mit Rolle, Stufe und Itemlevel."])
            f.mineEmpty:Show()
        else
            f.mineEmpty:Hide()
        end
        f.data:SetText(L["Wer in deiner Gruppe ist, zählt als dabei."] .. (c.note and (" · " .. c.note) or ""))
        return
    end

    -- the list: the chosen call first
    local list = GC().List(filter)
    if focus then
        for i, c in ipairs(list) do
            if c.low == focus then
                table.remove(list, i)
                table.insert(list, 1, c)
                break
            end
        end
    end
    f.list:SetItems(list)
    if #list > 0 then
        f.empty:Hide()
    elseif not ns.InGuild() then
        f.empty:Set(L["Keine Gilde"], L["Du bist in keiner Gilde."])
        f.empty:Show()
    elseif GC().Count() > 0 then
        f.empty:Set(L["Nichts gefunden"], L["Kein Aufruf dieser Art."])
        f.empty:Show()
    else
        f.empty:Set(L["Keine Aufrufe"], L["Gerade sucht niemand aus der Gilde Leute. Stell selbst einen Aufruf ein."])
        f.empty:Show()
    end
    local n = GC().Count()
    f.data:SetText((n == 1 and L["1 Aufruf der Gilde"] or L["%d Aufrufe der Gilde"]:format(n))
        .. (own and (" · " .. L["dein Aufruf läuft"]) or ""))
end

ns.RegisterPanel{ key = "calls", label = L["Aufrufe"], sub = L["Gruppe suchen in der Gilde: Aufrufe mit Anmeldung."],
    icon = "Interface\\Icons\\Ability_Warrior_BattleShout", order = 65.5, group = "guild", create = build, refresh = refresh }

-- the page follows the calls while it shows
local function shown() return page ~= nil and page:IsVisible() and ns.CurrentPage and ns.CurrentPage() == "calls" end
local follow = W.RefreshWhileShown(shown, 1)
ns.Listen("GUILD_CALLS", follow)
for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ADDON_RESTRICTION_STATE_CHANGED" }) do
    ns.OnEvent(event, follow)
end

-- for the tests and the snapshots: the view
function ns.GuildCalls.PageMode(m)
    if m then mode = m end
    return mode
end
end)
