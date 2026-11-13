-- Tools (expert mode): one row per task that gathers data for the N100's builds (F-186, D-118): the
-- item scan ("Ausrüstung"), the quest and NPC scans by id (D-104) and the item collector, each with its
-- state in plain words, a progress bar while the total is known, and only the actions that fit the
-- state; a line "Nächster Schritt" when there is something to do. Above the rows "Alles Fehlende scannen"
-- (F-188, D-120): what is open, or the queue's plan while it runs, and its link. Under it the guild's drop data:
-- kills own and heard, when this client last announced and last received kills, the list per instance and
-- boss with the rates, the sharing switch, "Wer teilt" (F-189, D-121: the members heard this session, in
-- place of the list), "Jetzt abgleichen" and the text "Drops für die Website" (in place of the list).
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local page
-- what stands under the drop controls: "list" (per instance and boss), "who" (Wer teilt, F-189) or
-- "export" (the text Drops für die Website)
local dropView = "list"
local exportText = ""

-- rows of 18 under the drop controls down to the footer (10 x 18 = 180 of 195)
local DROP_ROWS, DROP_ROW_H = 10, 18
local GOLD = { 1, 0.82, 0 }
local GREY = { 0.56, 0.53, 0.64 }
local WHITE = { 1, 1, 1 }
local INDENT = { boss = "   ", item = "      " }

local function setExport(D, text)
    exportText = text or ""
    D.area.box:SetText(exportText)
    D.area.box:SetCursorPosition(0)
end

local function itemTooltip(owner, id)
    if not id then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local _, link = C_Item.GetItemInfo(id)
    if link then
        GameTooltip:SetHyperlink(link)
    elseif GameTooltip.SetItemByID then
        GameTooltip:SetItemByID(id)
    end
    GameTooltip:Show()
end

-- An age as "gerade eben", "vor 3 Min.", "vor 2 Std.".
local function ago(secs)
    secs = math.max(0, secs or 0)
    if secs < 60 then return L["gerade eben"] end
    if secs < 7200 then return L["vor %d Min."]:format(math.floor(secs / 60)) end
    return L["vor %d Std."]:format(math.floor(secs / 3600))
end

-- The comparison with one member (ns.DropSyncMembers) in words.
local function memberState(m)
    local st = m.state
    if st == "pulling" then return L["du holst gerade"] end
    if st == "equal" then return m.got > 0 and L["gleich, %d Kills geholt"]:format(m.got) or L["gleich"] end
    if st == "got" then return L["%d Kills geholt"]:format(m.got) end
    if st == "nothing" then return L["geholt, nichts Neues dabei"] end
    if st == "more" then return L["hat mehr: wartet"] end
    if st == "other" then return L["hat andere: wartet"] end
    if st == "later" then return L["hat andere: beim nächsten Abgleich"] end
    if st == "gave" then return L["hat %d Kills von dir geholt"]:format(m.gave) end
    if st == "less" then return L["hat weniger als du"] end
    return L["fragt bei dir an"]
end

-- The rows of "Wer teilt": the name in its class colour (from the guild roster), when it was heard and
-- the kills it announced, the comparison on the right.
local function memberItems()
    local class = {}
    for _, g in ipairs(ns.GuildRoster() or {}) do
        if type(g.name) == "string" then class[g.name:lower()] = g.class end
    end
    local items = {}
    for _, m in ipairs(ns.DropSyncMembers()) do
        local info = m.heard and L["%s gehört, %d Kills"]:format(ago(m.heard), m.total or 0) or L["%s gefragt"]:format(ago(m.asked))
        items[#items + 1] = { kind = "member", m = m, text = ns.ClassColored(m.name, class[m.name:lower()]) .. "  " .. T.GREY .. info .. "|r",
            rate = memberState(m) }
    end
    return items
end

local function memberTooltip(owner, m)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(m.name)
    if m.heard then
        GameTooltip:AddLine(L["Angekündigt %s: %d Kills der letzten vier Wochen, neuester Tag %s."]:format(ago(m.heard), m.total or 0,
            m.newest and ns.DropsDate(m.newest) or L["keiner"]), 1, 1, 1, true)
    else
        GameTooltip:AddLine(L["Keine Ankündigung gehört; hat dich %s gefragt."]:format(ago(m.asked)), 1, 1, 1, true)
    end
    GameTooltip:AddLine(L["Von dort geholt: %d neue Kills. Von dir geholt: %d Kills."]:format(m.got, m.gave), 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end

local function syncTooltip(b)
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["Jetzt abgleichen"])
    local ok, why, wait = ns.DropSyncCanSync()
    if ok then
        GameTooltip:AddLine(L["Kündigt deine Drop-Daten jetzt der Gilde an: wer etwas anderes hat, holt es, und Amisia holt bei den Mitgliedern, die schon gemeldet haben. Höchstens einmal in der Minute."], 1, 1, 1, true)
    else
        GameTooltip:AddLine(ns.DropSyncWhyText(why, wait) or "", 1, 1, 1, true)
    end
    GameTooltip:Show()
end

local function buildDrops(f)
    -- the guild's drop data under its section header: the state, sharing, "Wer teilt", "Jetzt abgleichen"
    -- and the text for the website, the list (or the members, or the text) down to the footer
    local D = W.Page(f, { view = true })
    local top = D:Bands({ "header", { "line", lines = 2 }, "row" })
    D.head = W.SectionHeader(D, L["Drop-Daten"], false)
    D.head:SetAllPoints(D.bands[1])
    D.state = D:Line(2)

    D.share = W.Toggle(D, function(on) ns.Set("drops.share", on); ns.Refresh() end)
    D.shareLabel = W.Text(D, T.FONT.text, 130)
    D.shareLabel:SetText(L["Mit der Gilde teilen"])
    W.Tooltip(D.share, L["Drop-Daten mit der Gilde teilen"], L["Ohne Namen, nur außerhalb von Instanzen, nur unter geprüften Gildenmitgliedern."])

    D.who = W.Link(D, L["Wer teilt"], function()
        dropView = dropView == "who" and "list" or "who"
        if D.area.box:HasFocus() then D.area.box:ClearFocus() end
        ns.Refresh()
    end)
    W.FitChip(D.who)
    W.Tooltip(D.who, L["Wer teilt"], L["Die Gildenmitglieder, deren Drop-Daten Amisia seit dem Einloggen gehört hat, und wie weit ihr gleich seid. Nur hier zu sehen, nirgends gespeichert oder gesendet."])
    D.sync = W.Link(D, L["Jetzt abgleichen"], function()
        ns.DropSyncNow()
        ns.Refresh()
    end)
    W.FitChip(D.sync)
    D.sync:SetScript("OnEnter", syncTooltip)
    D.sync:SetScript("OnLeave", function() GameTooltip:Hide() end)

    D.web = W.Button(D, L["Drops für die Website"], 160, function()
        dropView = dropView == "export" and "list" or "export"
        if dropView == "export" then
            setExport(D, ns.DropsExportText())
            D.area.box:SetFocus()
            D.area.box:HighlightText()
        else
            D.area.box:ClearFocus()
        end
        ns.Refresh()
    end)
    W.FitChip(D.web, 160)
    D:Footer({ "areaHint" })

    -- rows of 18 under the controls down to the footer; the list is 590 wide, its thin bar beside it
    D.list = D:List(DROP_ROWS, DROP_ROW_H, function(r)
        r.name = W.Text(r, T.FONT.text, 330)
        r.name:SetPoint("LEFT", 6, 0)
        r.rate = W.Text(r, T.FONT.text, 240)
        r.rate:SetPoint("RIGHT", -6, 0)
        r.rate:SetJustifyH("RIGHT")
        r:SetScript("OnEnter", function(self)
            local e = self.item
            if e and e.kind == "item" then itemTooltip(self, e.id) end
            if e and e.kind == "member" then memberTooltip(self, e.m) end
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end, function(r, e)
        -- instances gold, the rates of items grey
        local nameColor = e.kind == "inst" and GOLD or WHITE
        local rateColor = e.kind == "inst" and GOLD or e.kind == "item" and GREY or WHITE
        r.name:SetText((INDENT[e.kind] or "") .. e.text)
        r.name:SetTextColor(nameColor[1], nameColor[2], nameColor[3])
        r.rate:SetText(e.rate)
        r.rate:SetTextColor(rateColor[1], rateColor[2], rateColor[3])
    end)
    D.empty = D:Empty(T.EMPTY.W, D.list)
    D.empty:Hide()
    D.area = W.ReadOnlyArea(D, function() return exportText end)
    D.area:SetPoint("TOPLEFT", 0, top)
    D.area:SetPoint("BOTTOMRIGHT", 0, D:Bottom())
    D.area:Hide()
    D.areaHint:SetText(L["Strg+A, Strg+C, auf der Website im Reiter Import einfügen."])
    D.areaHint:Hide()
    return D
end

-- The exchange in one sentence: sharing off; the manual run ("Abgleich läuft ..." and its result); else
-- when this client last announced itself and last received kills.
local function exchangeText(heardAt)
    if not ns.Get("drops.share") then return L["Teilen ist aus: Amisia tauscht keine Drop-Daten mit der Gilde."] end
    local info = ns.DropSyncInfo()
    if info.manual then return info.manual end
    return (info.announced and L["Angekündigt %s"]:format(ago(info.announced)) or L["Noch nicht angekündigt"])
        .. L[", zuletzt Kills empfangen %s."]:format(heardAt and ns.FmtDayTime(heardAt) or L["noch nie"])
end

-- The parts of the exchange (F-189), also once a second while the page shows and something waits: the
-- state line, the links "Wer teilt (n)" and "Jetzt abgleichen", and the members in place of the list.
-- The counts of the records come from the last full refresh (D.status; DROPS_CHANGED refreshes it).
local function fillExchange(D)
    local s = D.status or ns.DropsStatus()
    if s.kills == 0 then
        -- a manual run's line after the short form, so both fit the two lines
        local run = ns.DropSyncInfo().manual
        D.state:SetText(run and (L["Noch keine Kills."] .. " " .. run) or ns.Get("drops.record")
            and L["Noch keine Kills. Amisia zeichnet geöffnete Lootfenster von Bossen in Dungeons und Raids auf."]
            or L["Noch keine Kills. Amisia zeichnet geöffnete Lootfenster von Bossen in Dungeons und Raids auf (Aufzeichnen ist in den Einstellungen aus)."])
    else
        D.state:SetText(L["%d Kills (%d eigene, %d gehörte), %d Bosse, neuester Tag %s."]:format(
            s.kills, s.own, s.heard, s.bosses, s.newest and ns.DropsDate(s.newest) or L["keiner"]) .. " " .. exchangeText(s.heardAt))
    end
    local whoText = dropView == "who" and L["Zur Liste"] or L["Wer teilt (%d)"]:format(ns.DropSyncInfo().members)
    if D.who:GetText() ~= whoText then D.who:SetText(whoText) end
    local ok = ns.DropSyncCanSync()
    if ok then D.sync:Enable() else D.sync:Disable() end
    if dropView == "who" then
        local items = memberItems()
        D.list:SetItems(items)
        if #items == 0 then
            local why = ns.DropSyncBlocked()
            local text = L["Noch kein Gildenmitglied mit Drop-Daten gehört (seit dem Einloggen)."]
            D.empty:Set(L["Noch niemand gehört"], why and (text .. " " .. ns.DropSyncWhyText(why)) or text)
        end
        D.empty:SetShown(#items == 0)
    else
        D.empty:Hide()
    end
    -- the controls again when a link's width changed
    local sig = D.who:GetText() .. "|" .. D.sync:GetText()
    if sig ~= D.sig then
        D.sig = sig
        D:Place(3, { D.share, D.shareLabel }, { D.who, D.sync, D.web })
    end
end

local function fillDrops(D)
    D.share:SetChecked(ns.Get("drops.share") and true or false)
    D.status = ns.DropsStatus()
    if dropView ~= "who" then D.list:SetItems(ns.DropsBossList()) end
    fillExchange(D)
    if dropView == "export" then
        D.list:Hide()
        D.area:Show()
        D.areaHint:Show()
        D.web:SetText(L["Zur Liste"])
        -- the text follows the records unless the box is in use
        if not D.area.box:HasFocus() then
            local text = ns.DropsExportText()
            if text ~= exportText then setExport(D, text) end
        end
    else
        D.area:Hide()
        D.areaHint:Hide()
        D.list:Show()
        D.web:SetText(L["Drops für die Website"])
    end
end

-- Whether the exchange part changes by itself while the page shows: a manual run waits for answers, the
-- link waits for its minute, or the members are shown (their ages).
local function exchangeTicks()
    if dropView == "who" then return true end
    local info = ns.DropSyncInfo()
    if info.manual then return true end
    local _, why = ns.DropSyncCanSync()
    return why == "wait"
end

---------------------------------------------------------------------------
-- The scan rows (F-186)
---------------------------------------------------------------------------
local SCAN_ROWS = { "gear", "quests", "npcs", "collect" }
local ROW_NAME = { gear = L["Ausrüstung"], quests = L["Quests"], npcs = L["NPCs"], collect = L["Sammler"] }
local ACTIONS = { "resume", "start", "retry", "stop", "toggle" }
local TICK = 1   -- seconds between two updates of the rows while a scan runs and the page shows

local function percent(p) return math.floor(100 * p.done / p.total) end
local function dur(seconds) return ns.ScanById.Duration(seconds) end

-- Which scan runs: "gear", "quests", "npcs" or nil.
local function runningScan()
    if ns.ScanRunning and ns.ScanRunning() then return "gear" end
    if ns.QuestScan and ns.QuestScan.Running() then return "quests" end
    if ns.NpcScan and ns.NpcScan.Running() then return "npcs" end
    return nil
end

local function inInstance()
    local ok, _, kind = pcall(GetInstanceInfo)
    kind = ok and ns.Plain(kind) or nil
    return kind ~= nil and kind ~= "none"
end

-- What a finished or idle scan holds: n lines wait in the file for the N100's build, or (none left)
-- everything was taken over (D-34: the addon trims what the build has); never ran: "Noch nicht gelaufen".
local WAITING = {
    gear = { L["%d neue Items warten auf die Übernahme."], L["Fertig: %d neue Items warten auf die Übernahme."] },
    quests = { L["%d neue Quests warten auf die Übernahme."], L["Fertig: %d neue Quests warten auf die Übernahme."] },
    npcs = { L["%d neue Namen warten auf die Übernahme."], L["Fertig: %d neue Namen warten auf die Übernahme."] },
}
local function waiting(key, n, finished, ran)
    if n > 0 then return WAITING[key][finished and 2 or 1]:format(n) end
    if finished or ran then return L["Fertig: alles übernommen."] end
    return L["Noch nicht gelaufen."]
end

-- A running or paused scan with a known total: the text and the bar's value.
local function progressText(p, runningFmt, pausedFmt)
    if not p.total then return p.running and L["Läuft ..."] or L["Angehalten."], nil end
    local fmt = p.running and runningFmt or pausedFmt
    return fmt:format(percent(p), dur(p.seconds)), p.done / p.total
end

-- Each row's model: { state, bar (0..1 or nil), resume, start, retry (a count), stop, toggle (label) }.
local function gearRow()
    local p = ns.ScanProgress()
    local m = { start = not p.running, retry = not p.running and p.retry > 0 and p.retry or nil, stop = p.running }
    if p.running then
        m.state, m.bar = progressText(p, p.kind == "retry" and L["Wiederholt Offene: %d %%, etwa %s übrig"]
            or L["Läuft: %d %%, etwa %s übrig"], L["Angehalten: %d %%, noch etwa %s"])
    elseif p.resumable then
        m.state, m.bar = progressText(p, L["Läuft: %d %%, etwa %s übrig"], L["Angehalten: %d %%, noch etwa %s"])
        m.resume = true
    else
        local s = AmisiaDB and AmisiaDB.scan or {}
        m.state = waiting("gear", p.items, p.finished, s.next ~= nil or s.trim ~= nil)
    end
    return m
end

local function questRow()
    local QS = ns.QuestScan
    local p = QS.Progress()
    local m = { stop = p.running }
    if p.running or p.started then
        m.state, m.bar = progressText(p, L["Läuft: %d %%, etwa %s übrig"], L["Angehalten: %d %%, noch etwa %s"])
        m.resume = not p.running
    else
        local q = AmisiaDB and AmisiaDB.scan and AmisiaDB.scan.quests
        m.state = waiting("quests", p.n, p.finished, type(q) == "table" and q.at ~= nil)
        m.start = true
    end
    return m
end

local function npcRow()
    local p = ns.NpcScan.Progress()
    local m = { stop = p.running ~= nil }
    if p.running == "mini" then
        m.state = L["Prüft zuerst drei bekannte NPCs ..."]
    elseif p.none and not p.running then
        m.state = L["Der Client nennt keine NPC-Namen."]
    elseif p.running == "B" or (not p.running and p.phase == "B") then
        if p.running or p.started then
            m.state, m.bar = progressText(p, L["Sucht neue NPCs: %d %%, etwa %s übrig"], L["Suche nach neuen NPCs angehalten: %d %%, noch etwa %s"])
        else
            m.state = p.total and L["Bekannte NPCs fertig; die Suche nach neuen dauert etwa %s."]:format(dur(p.seconds))
                or L["Bekannte NPCs fertig; die Suche nach neuen ist offen."]
        end
        m.resume = not p.running
    elseif p.running or p.started then
        m.state, m.bar = progressText(p, L["Läuft: %d %%, etwa %s übrig"], L["Angehalten: %d %%, noch etwa %s"])
        m.resume = not p.running
    else
        m.state = waiting("npcs", p.n, p.finished, p.doneA)
        -- a finished NPC scan has nothing left to ask (a start would only say its state)
        m.start = not p.finished
    end
    return m
end

local function collectRow()
    local on = ns.Get("tools.collect") and true or false
    local n = ns.CollectCount()
    local m = { toggle = on and L["Ausschalten"] or L["Einschalten"] }
    if n > 0 then
        m.state = (on and L["An: %d Items mit Quelle warten auf die Übernahme."] or L["Aus: %d Items mit Quelle warten auf die Übernahme."]):format(n)
    else
        m.state = on and L["An: alles übernommen."] or L["Aus."]
    end
    return m
end

local MODELS = { gear = gearRow, quests = questRow, npcs = npcRow, collect = collectRow }

-- The line "Nächster Schritt" (D-118), the first that fits: a scan stopped by an instance; new entries
-- of this session not yet written (SavedVariables are written at logout and /reload); items without an
-- answer to ask again. Nothing while a scan runs, else nil. While "Alles Fehlende scannen" is on, only
-- what it waits for: it goes on by itself (F-188).
local function nextStep()
    if runningScan() then return nil end
    local SA = ns.ScanAll
    if SA and SA.Active() then return SA.NextStep() end
    local paused = ns.ScanProgress().pausedIn or (ns.QuestScan.Progress().pausedIn) or (ns.NpcScan.Progress().pausedIn)
    if paused then
        return inInstance() and L["Ein Scan hielt in der Instanz an: außerhalb von Instanzen in seiner Zeile fortsetzen."]
            or L["Ein Scan hielt in der Instanz an: in seiner Zeile fortsetzen."]
    end
    local added = ns.ScanAddedCount()
    if added > 0 then
        return L["%d neue Einträge seit dem Einloggen: ausloggen oder /reload, damit sie gespeichert werden."]:format(added)
    end
    local retry = ns.ScanProgress().retry
    if retry > 0 then return L["%d Items ohne Antwort: Offene wiederholen."]:format(retry) end
    return nil
end

local function onAction(key, act)
    if act == "toggle" then
        ns.Set("tools.collect", not ns.Get("tools.collect"))
    elseif act == "stop" then
        ns.ScanCommand("stop")
    elseif key == "gear" then
        ns.ScanCommand(act == "resume" and "" or act == "retry" and "retry" or "gear")
    else
        ns.ScanCommand(key)
    end
    ns.Refresh()
end

local ACTION_LABEL = { resume = L["Fortsetzen"], start = L["Starten"], stop = L["Anhalten"], retry = L["Offene wiederholen"], toggle = L["Einschalten"] }

local function buildScanRow(f, i, key)
    local r = { key = key, band = i, acts = {} }
    r.name = W.Text(f, T.FONT.head, T.TOOLS.NAME_W)
    r.name:SetText(ROW_NAME[key])
    r.state = W.Text(f, T.FONT.text)
    r.bar = W.ProgressBar(f)
    r.bar:Hide()
    for _, act in ipairs(ACTIONS) do
        local b = W.Link(f, ACTION_LABEL[act], function() onAction(key, act) end)
        W.FitChip(b)
        b:Hide()
        r.acts[act] = b
    end
    return r
end

-- Sets one row from its model; places the band again only when its parts come or go.
local function fillScanRow(f, r, busy)
    local m = MODELS[r.key]()
    r.state:SetText(m.state or "")
    local sig = m.bar and "b" or ""
    if m.bar then r.bar:SetValue(m.bar) end
    r.bar:SetShown(m.bar ~= nil)
    for _, act in ipairs(ACTIONS) do
        local b, want = r.acts[act], m[act]
        if act == "retry" and want then b:SetText(L["Offene wiederholen (%d)"]:format(want)) end
        if act == "toggle" and want then b:SetText(want) end
        b:SetShown(want and true or false)
        -- one scan at a time (D-104): while another runs, this row's starts are greyed with the reason
        local blockedNow = busy and busy ~= r.key and act ~= "toggle" and act ~= "stop"
        if blockedNow then b:Disable() else b:Enable() end
        b.blockedBy = blockedNow and busy or nil
        if want then sig = sig .. act end
    end
    if sig ~= r.sig then
        r.sig = sig
        local right = { r.bar }
        for _, act in ipairs(ACTIONS) do right[#right + 1] = r.acts[act] end
        f:Place(r.band, { r.name, { r.state, fill = true } }, right, { shown = true })
    end
end

-- The band of "Alles Fehlende scannen" (F-188): the plan or what is open, and one quiet link: start
-- (greyed while a scan runs by hand), "Anhalten" while the queue is on, none with nothing open.
local function fillAll(f, busy)
    local SA, a = ns.ScanAll, f.all
    if not SA then return end
    local on = SA.Active()
    local open = not on and #SA.State().open > 0
    a.text:SetText(SA.PlanText())
    a.start:SetShown(open)
    a.stop:SetShown(on)
    if busy and open then a.start:Disable() else a.start:Enable() end
    a.start.blockedBy = (busy and open) and busy or nil
    local sig = (open and "s" or "") .. (on and "x" or "")
    if sig ~= a.sig then
        a.sig = sig
        f:Place(1, { { a.text, fill = true } }, { a.start, a.stop }, { shown = true })
    end
end

local function fillScans(f)
    local busy = runningScan()
    fillAll(f, busy)
    for _, r in ipairs(f.rows) do fillScanRow(f, r, busy) end
    local step = nextStep()
    f.next:SetText(step and (T.LABEL .. L["Nächster Schritt:"] .. "|r " .. step) or "")
    f.next:SetShown(step ~= nil)
end

local function blockedTip(b)
    if not b.blockedBy then return end
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["Es läuft schon ein Scan"])
    GameTooltip:AddLine(L["Immer nur ein Scan zur Zeit: erst den laufenden anhalten."], 1, 1, 1, true)
    GameTooltip:Show()
end

local function buildAll(f)
    local a = {}
    a.text = W.Text(f, T.FONT.text)
    a.start = W.Link(f, L["Alles Fehlende scannen"], function()
        local ok, why = ns.ScanAll.Start()
        if not ok and why then ns.msg(why) end
        ns.Refresh()
    end)
    W.FitChip(a.start)
    a.stop = W.Link(f, L["Anhalten"], function()
        ns.ScanCommand("stop")
        ns.Refresh()
    end)
    W.FitChip(a.stop)
    for _, b in ipairs({ a.start, a.stop }) do
        b:Hide()
        b:SetScript("OnEnter", blockedTip)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    f.all = a
end

local function buildScans(f)
    -- "Alles Fehlende scannen", four rows of controls (one per task) and the line "Nächster Schritt"
    f:Bands({ "row", "row", "row", "row", "row", "line" })
    buildAll(f)
    f.rows, f.rowByKey = {}, {}
    for i, key in ipairs(SCAN_ROWS) do
        local r = buildScanRow(f, i + 1, key)
        f.rows[i], f.rowByKey[key] = r, r
        for _, b in pairs(r.acts) do
            b:SetScript("OnEnter", blockedTip)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
    end
    f.next = f:Line(6)
    -- while a scan runs and the page shows: the rows' texts and bars once a second, nothing rebuilt; the
    -- drop exchange's line, links and members likewise while they change by themselves (F-189)
    local since = 0
    f.ticker = CreateFrame("Frame", nil, f)
    f.ticker:SetScript("OnUpdate", ns.Perf.Wrap("OnUpdate Tools scans", function(_, elapsed)
        since = since + (elapsed or 0)
        if since < TICK then return end
        since = 0
        if ns.CurrentPage() ~= "tools" then return end
        if runningScan() then fillScans(f) end
        if f.drops and exchangeTicks() then fillExchange(f.drops) end
    end))
end

ns.RegisterPanel{ key = "tools", label = L["Werkzeuge"], sub = L["Scans für die Daten, Drops der Gilde."], icon = "Interface\\Icons\\INV_Misc_Gear_01", order = 80, group = "guild", expert = true,
    create = function(parent)
        local f = W.Page(parent)
        buildScans(f)
        f.drops = buildDrops(f)
        page = f
        return f
    end,
    refresh = function(f)
        fillScans(f)
        fillDrops(f.drops)
    end }

-- The text "Drops für die Website" (/amisia drops export): the tools page with the text marked.
-- The page is part of expert mode; without it the command says where the text is.
function ns.ShowDropsExport()
    ns.ShowPage("tools")
    if ns.CurrentPage() ~= "tools" or not page then
        ns.msg(L["Der Text \"Drops für die Website\" steht auf der Seite Werkzeuge; sie zeigt Amisia im Expertenmodus (Einstellungen)."])
        return
    end
    dropView = "export"
    ns.Refresh()
    setExport(page.drops, ns.DropsExportText())
    page.drops.area.box:SetFocus()
    page.drops.area.box:HighlightText()
end

-- New or merged records, and the exchange's own changes (a member heard, a pull, a blob, the manual
-- run; F-189): the page shows them, at most once a second and only while shown.
local refreshPending, refreshAt = false, nil
local function refreshSoon()
    if not page or not page:IsShown() or ns.CurrentPage() ~= "tools" or refreshPending then return end
    refreshPending = true
    local wait = refreshAt and math.max(0, 1 - (GetTime() - refreshAt)) or 0
    C_Timer.After(wait, function()
        refreshPending = false
        refreshAt = GetTime()
        if page and page:IsShown() and ns.CurrentPage() == "tools" then ns.Refresh() end
    end)
end
ns.Listen("DROPS_CHANGED", refreshSoon)
ns.Listen("DROPSYNC_CHANGED", refreshSoon)
