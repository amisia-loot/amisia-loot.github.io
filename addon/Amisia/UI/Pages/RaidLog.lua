-- Raid log: the timeline of one raid (start, late raiders, raiders from the bench, every boss
-- attempt, the end) with the details of an attempt, the bench of the raid and its Discord text.
-- Everyone sees the timeline and the bench; entering bosses, editing the bench and the Discord text
-- are for officers.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local LOG_ROWS, BENCH_ROWS, ROW_H = 12, 10, 22
local MAX_PARTS = 6
local OUTSIDE_FOR = 600   -- seconds: the group outside offered for "Alle eintragen"
local GREY, GREEN, RED, ORANGE, LABEL = T.GREY, T.GREEN, "|cffe05a5a", T.ORANGE, T.LABEL
local SRC_TEXT = { enc = L["Kampf"], kill = L["Kampf (Ende)"], loot = L["Lootfenster"], hand = L["von Hand"] }
local VIEWS = { verlauf = "verlauf", log = "verlauf", bench = "bench", ersatzbank = "bench", ersatz = "bench", discord = "discord",
    ["würfe"] = "rolls", wuerfe = "rolls", rolls = "rolls" }   -- l10n-ok: typed view words
local KIND_ORDER = { start = 1, late = 2, bench = 2, kill = 3, pull = 4, ["end"] = 5 }

local page
local view = "verlauf"   -- kept until logout
local chosenRaid         -- session id, "next" (tonight before the raid), or nil for the default
local chosenKill         -- the attempt in the detail area, or "pull" for the running one
local adding = false     -- the "Boss eintragen" line is open
local addOk = true
local addName, addAt     -- the boss to enter, and the time of its loot window
local addFor             -- the raid the "Boss eintragen" line was opened for
local benchName          -- the name chosen in the bench line
local part = 1           -- the Discord part shown
local discordText = ""   -- what the read-only box holds
local discordFor         -- the raid and the part the box holds
local discordPart
local focusDiscord = false

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function hm(t) return date("%H:%M", t or 0) end

-- "05.10." (English "Oct 5") from "2026-10-05".
local function shortDate(iso)
    local y, m, d = tostring(iso or ""):match("^(%d+)%-(%d+)%-(%d+)$")
    if not d then return tostring(iso or "?") end
    return ns.FmtDay(time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 }))
end

local function byId(id)
    for _, s in ipairs(ns.Sessions()) do
        if s.id == id then return s end
    end
    return nil
end

-- The raids newest first, the running recording in front.
local function ordered()
    local src, out, act = ns.Sessions(), {}, ns.Active()
    if act then out[1] = act end
    for i = #src, 1, -1 do
        if src[i] ~= act then out[#out + 1] = src[i] end
    end
    return out
end

-- Tonight's bench before the raid, without creating it.
local function tonightBench()
    local b = AmisiaDB and AmisiaDB.benchNext
    if type(b) == "table" and b.date == ns.NightOf(time()) and type(b.list) == "table" then return b end
    return nil
end

local function officer() return ns.IsOfficerView() end

-- No raid log to show: tonight before the raid while raids are saved, or no raid at all.
local function noRaidText(s)
    if s == "next" and #ns.Sessions() > 0 then return L["Für heute vor dem Raid gibt es noch keinen Raid-Log."] end
    return L["Noch kein Raid aufgezeichnet."]
end

-- A kill or wipe entered by hand without anyone read for it: who was there is not known.
local function unknownWho(k)
    if k.src ~= "hand" or k.wait then return false end
    if k.ok then return type(k.who) ~= "table" or #k.who == 0 end
    return (tonumber(k.n) or 0) == 0
end

local function shownView()
    if view == "discord" and not officer() then return "verlauf" end
    return view
end

-- The raid the page shows, or "next" for tonight before the raid: the chosen one, else the
-- recording, else (bench view) tonight, else the newest raid.
local function chosen()
    local act = ns.Active()
    if chosenRaid == "next" and not act then return "next" end
    local s = chosenRaid and chosenRaid ~= "next" and byId(chosenRaid)
    if s then return s end
    if act then return act end
    if shownView() == "bench" then return "next" end
    local list = ns.Sessions()
    return list[#list] or "next"
end

local function classColored(name, class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return (c and c.colorStr) and ("|c%s%s|r"):format(c.colorStr, name) or name
end

local function memberColored(s, name)
    local m = s.members and s.members[name]
    return classColored(name, m and m.class)
end

-- The length of an attempt when its start is known from the encounter events.
local function lengthText(k)
    if (k.src == "enc" or k.src == "kill") and k.start and k.t and k.t > k.start then return ns.FightLength(k.t - k.start) end
    return nil
end

local function lift(d)
    -- the dialog strata is below the main window's; lift it so it is not hidden behind
    if d and d.SetFrameStrata then
        d:SetFrameStrata("FULLSCREEN_DIALOG")
        if d.Raise then d:Raise() end
    end
end

local function countsText(s)
    if s == "next" then
        -- the history says it in its middle; the line stays empty there
        if #ns.Sessions() == 0 and shownView() ~= "bench" then
            return shownView() == "verlauf" and "" or L["Noch kein Raid aufgezeichnet."]
        end
        local b = tonightBench()
        local n = b and #ns.BenchList(b) or 0
        return L["Heute, vor dem Raid · %d auf der Ersatzbank"]:format(n)
    end
    local _, wipes, bosses = ns.KillCount(s)
    local parts = {}
    if bosses > 0 then parts[#parts + 1] = bosses == 1 and L["1 Boss"] or L["%d Bosse"]:format(bosses) end
    if wipes > 0 then parts[#parts + 1] = ns.WipeText(wipes) end
    parts[#parts + 1] = L["%s bis %s"]:format(hm(s.firstScan or s.start), hm(s.last or s.start))
    local members = ns.MemberCount(s)
    if members > 0 then parts[#parts + 1] = L["%d Raider"]:format(members) end
    local late = ns.LateCount(s)
    if late > 0 then parts[#parts + 1] = L["%d zu spät"]:format(late) end
    local bench = #ns.BenchList(s)
    if bench > 0 then parts[#parts + 1] = L["%d Ersatzbank"]:format(bench) end
    return table.concat(parts, " · ")
end

---------------------------------------------------------------------------
-- Verlauf
---------------------------------------------------------------------------
local function timeline(s)
    local out = {}
    if type(s) ~= "table" then return out end
    out[#out + 1] = { kind = "start", t = s.start or 0 }
    for name, m in pairs(s.members or {}) do
        if m.late then
            out[#out + 1] = { kind = "late", t = m.first or 0, name = name }
        elseif m.bench then
            out[#out + 1] = { kind = "bench", t = m.first or 0, name = name }
        end
    end
    for _, k in ipairs(ns.Kills(s)) do out[#out + 1] = { kind = "kill", t = k.t or 0, k = k } end
    local live = s == ns.Active()
    if live and type(s.pull) == "table" then out[#out + 1] = { kind = "pull", t = s.pull.start or time(), p = s.pull } end
    if not live then out[#out + 1] = { kind = "end", t = s.last or s.start or 0 } end
    table.sort(out, function(a, b)
        if a.t ~= b.t then return a.t < b.t end
        if KIND_ORDER[a.kind] ~= KIND_ORDER[b.kind] then return KIND_ORDER[a.kind] < KIND_ORDER[b.kind] end
        return tostring(a.name or (a.k and a.k.name) or "") < tostring(b.name or (b.k and b.k.name) or "")
    end)
    return out
end

local function fillLogRow(r, e)
    local when, event, result, dur, who, src = hm(e.t), "", "", "", "", ""
    if e.kind == "start" then
        event = L["Aufnahme gestartet"]
    elseif e.kind == "end" then
        event = L["Aufnahme beendet"]
    elseif e.kind == "late" then
        event, result = L["%s kommt"]:format(e.name), ORANGE .. L["zu spät"] .. "|r"
    elseif e.kind == "bench" then
        event = L["%s kommt von der Ersatzbank"]:format(e.name)
    elseif e.kind == "pull" then
        event = e.p.name or "?"
        result = LABEL .. L["läuft"] .. "|r"
        dur = ns.FightLength(time() - (e.p.start or time()))
        src = L["Kampf"]
    elseif e.kind == "kill" then
        local k = e.k
        if k.src == "loot" then when = GREY .. L["ca. ##Uhrzeit"] .. hm(k.t) .. "|r" end
        event = k.name or "?"
        result = k.ok and (GREEN .. "Kill|r") or (RED .. "Wipe|r")
        dur = lengthText(k) or ""
        if k.wait then
            who = "..."
        elseif not unknownWho(k) then
            who = tostring(k.n or (type(k.who) == "table" and #k.who) or "")
        end
        src = SRC_TEXT[k.src] or ""
    end
    r.time:SetText(when)
    r.event:SetText(event)
    r.result:SetText(result)
    r.dur:SetText(dur)
    r.who:SetText(who)
    r.src:SetText(src)
    local sel = (e.kind == "kill" and e.k == chosenKill) or (e.kind == "pull" and chosenKill == "pull")
    if sel then r.sel:Show() else r.sel:Hide() end
end

-- the timeline's columns (the list is 590 wide, its bar beside it)
local LOG_COLS = { { "time", 6, 44, L["Zeit"] }, { "event", 54, 246, L["Ereignis"] }, { "result", 304, 76, L["Ergebnis"] },
    { "dur", 384, 46, L["Dauer"] }, { "who", 434, 46, L["Dabei"] }, { "src", 484, 102, L["Quelle"] } }

local function buildLog(f)
    local V = W.Page(f, { view = true })
    local headFrame, head = V:Columns(LOG_COLS)
    -- the head frame's Show/Hide stands for the column heads, the cells for the tests
    for k, fs in pairs(head) do headFrame[k] = fs end
    V.head = headFrame
    V.list = V:List(LOG_ROWS, ROW_H, function(r)
        r.sel = W.SelectBar(r)
        W.Cells(r, LOG_COLS)
        r:SetScript("OnClick", function(self)
            local e = self.item
            if not e then return end
            if e.kind == "kill" then
                chosenKill = e.k
            elseif e.kind == "pull" then
                chosenKill = "pull"
            else
                return
            end
            ns.Refresh()
        end)
    end, fillLogRow)
    -- no raid yet: the page says so over the list instead of an empty table
    V.empty = V:Empty(440)

    -- the detail area under the list
    V.title = W.Text(V, T.FONT.title, 490)
    V.title:SetPoint("TOPLEFT", V.list, "BOTTOMLEFT", 6, -6)
    V.del = W.Button(V, L["Löschen##Knopf"], 90, function()
        local s = chosen()
        if not officer() or type(s) ~= "table" or type(chosenKill) ~= "table" then return end
        lift(StaticPopup_Show("AMISIA_RAIDLOG_DELETE", nil, nil, { s = s, k = chosenKill }))
    end)
    V.del:SetPoint("TOPRIGHT", V.list, "BOTTOMRIGHT", 0, -4)
    V.detail = W.ScrollText(V)
    V.detail:SetPoint("TOPLEFT", V.list, "BOTTOMLEFT", T.LAYOUT.TEXT_X, -28)
    -- the text ends with the list; its bar lies under the list's
    V.detail:SetPoint("BOTTOMRIGHT", -T.SCROLL_ROOM, 0)

    -- "Boss eintragen": [Boss v] [Kill] [Wipe] [Eintragen] [Abbrechen]
    local A = CreateFrame("Frame", nil, V)
    A:SetPoint("TOPLEFT", V.list, "BOTTOMLEFT", 0, -4)
    A:SetPoint("TOPRIGHT", V.list, "BOTTOMRIGHT", 0, -4)
    A:SetHeight(22)
    A.pick = W.Picker(A, 220, function(v, free)
        addName = v
        addAt = (not free) and A.times and A.times[v] or nil
    end)
    A.pick:SetPoint("LEFT", 0, 0)
    A.kill = W.Chip(A, "Kill", 50, function()
        addOk = true
        ns.Refresh()
    end)
    A.kill:SetPoint("LEFT", A.pick, "RIGHT", 6, 0)
    A.wipe = W.Chip(A, "Wipe", 50, function()
        addOk = false
        ns.Refresh()
    end)
    A.wipe:SetPoint("LEFT", A.kill, "RIGHT", 4, 0)
    A.ok = W.Button(A, L["Eintragen"], 90, function()
        local s = chosen()
        if not officer() or type(s) ~= "table" then return end
        if s ~= addFor then
            -- another raid is shown now (a recording started): the line was for the one before
            adding, addName, addAt, addFor = false, nil, nil, nil
            A.pick:SetValue(nil)
            ns.msg(L["Der Raid hat gewechselt. Bitte den Boss neu eintragen."])
            ns.Refresh()
            return
        end
        if not addName then
            ns.msg(L["Zuerst einen Boss wählen oder einen Namen eingeben."])
            return
        end
        local live = s == ns.Active()
        local t = addAt or (live and time()) or (s.last or s.start)
        local k, why = ns.AddKill(s, { name = addName, ok = addOk, t = t })
        if not k then
            ns.msg(why)
            return
        end
        ns.msg(L["%s eingetragen: %s (%s)."]:format(k.ok and "Kill" or "Wipe", k.name, hm(k.t)))
        adding, addName, addAt, addFor = false, nil, nil, nil
        A.pick:SetValue(nil)
        chosenKill = k
        ns.Refresh()
    end)
    A.ok:SetPoint("LEFT", A.wipe, "RIGHT", 10, 0)
    A.cancel = W.Button(A, L["Abbrechen"], 90, function()
        adding, addName, addAt, addFor = false, nil, nil, nil
        A.pick:SetValue(nil)
        ns.Refresh()
    end)
    A.cancel:SetPoint("LEFT", A.ok, "RIGHT", 6, 0)
    A:Hide()
    V.add = A
    return V
end

-- The names a raider list shows, of a kill: present, not present, bench, loot.
local function detailLines(s, k)
    local lines = {}
    if unknownWho(k) then
        lines[#lines + 1] = LABEL .. L["Dabei:|r unbekannt (von Hand nachgetragen)"]
        if not k.ok then return lines end
    elseif not k.ok then
        lines[#lines + 1] = L["%sDabei:|r %d Raider"]:format(LABEL, tonumber(k.n) or 0)
        return lines
    end
    local inWho = {}
    if unknownWho(k) then
        -- nobody to list as there or not there
    elseif k.wait then
        lines[#lines + 1] = LABEL .. L["Dabei:|r wird nach dem Kampf gelesen"]
    else
        local who = {}
        for _, name in ipairs(k.who or {}) do
            inWho[name:lower()] = true
            who[#who + 1] = memberColored(s, name)
        end
        lines[#lines + 1] = L["%sDabei (%d):|r %s"]:format(LABEL, #who, #who > 0 and table.concat(who, ", ") or L["niemand"])
        local missing = {}
        for name, m in pairs(s.members or {}) do
            local there = inWho[name:lower()]
            if not there then
                for w in pairs(inWho) do
                    if ns.SameName(w, name) then there = true break end
                end
            end
            if not there then missing[#missing + 1] = { name = name, m = m } end
        end
        table.sort(missing, function(a, b) return a.name < b.name end)
        if #missing > 0 then
            local words = {}
            for i, x in ipairs(missing) do
                local text = memberColored(s, x.name)
                if (x.m.first or 0) > (k.t or 0) then text = text .. L[" (kam %s)"]:format(hm(x.m.first)) end
                words[i] = text
            end
            lines[#lines + 1] = LABEL .. L["Nicht dabei:|r %s"]:format(table.concat(words, ", "))
        end
    end
    local bench = {}
    for _, x in ipairs(ns.BenchList(s)) do
        if not inWho[x.name:lower()] then bench[#bench + 1] = classColored(x.name, x.e.class) end
    end
    if #bench > 0 then lines[#lines + 1] = LABEL .. L["Ersatzbank:|r %s"]:format(table.concat(bench, ", ")) end
    local loot = {}
    for _, a in ipairs(s.awards or {}) do
        if ns.KillFor(s, a.src, a.t) == k then
            if a.to == "bank" or a.to == "de" then
                loot[#loot + 1] = ("%s: %s"):format(ns.ItemName(a.item), a.to == "bank" and "Bank" or L["entzaubert"])
            else
                loot[#loot + 1] = L["%s an %s%s"]:format(ns.ItemName(a.item), a.name or "?", (a.kind and a.kind ~= "-") and (" (" .. a.kind .. ")") or "")
            end
        end
    end
    if #loot > 0 then lines[#lines + 1] = LABEL .. "Loot:|r " .. table.concat(loot, ", ") end
    return lines
end

local function refreshLog(V, s)
    local items = timeline(s)
    -- the chosen attempt: still in this raid, else the newest
    local kills = type(s) == "table" and ns.Kills(s) or {}
    if chosenKill == "pull" then
        if not (type(s) == "table" and s == ns.Active() and s.pull) then chosenKill = nil end
    elseif chosenKill then
        local still = false
        for _, k in ipairs(kills) do if k == chosenKill then still = true break end end
        if not still then chosenKill = nil end
    end
    if not chosenKill then chosenKill = kills[#kills] end
    V.list:SetItems(items)
    if s == "next" and #ns.Sessions() == 0 then
        V.empty:Set(L["Noch kein Raid aufgezeichnet"],
            L["Amisia zeichnet von selbst auf, sobald du einen Schlachtzug betrittst: Anwesenheit, Bosskills und Loot. Hier stehen dann die Bosse des Abends."])
        V.empty:Show()
        V.head:Hide()
    else
        V.empty:Hide()
        V.head:Show()
    end

    local A = V.add
    if adding and s ~= addFor then
        -- the line was opened for another raid: closed and emptied
        adding, addName, addAt, addFor = false, nil, nil, nil
        A.pick:SetValue(nil)
    end
    if adding and officer() and type(s) == "table" then
        -- loot window sources of this raid, sorted by their first opening
        local first, names = {}, {}
        for _, d in pairs(s.drops or {}) do
            if type(d) == "table" and type(d.src) == "string" and d.src ~= "?" and d.src ~= "" and d.t then
                if not first[d.src] then names[#names + 1] = d.src end
                if not first[d.src] or d.t < first[d.src] then first[d.src] = d.t end
            end
        end
        table.sort(names, function(a, b)
            if first[a] ~= first[b] then return first[a] < first[b] end
            return a < b
        end)
        local values = {}
        for i, n in ipairs(names) do values[i] = { value = n, text = L["%s (Lootfenster %s)"]:format(n, hm(first[n])) } end
        A.times = first
        A.pick:SetValues(values, L["Anderer Name"])
        A.kill:SetOn(addOk)
        A.wipe:SetOn(not addOk)
        A:Show()
        V.title:Hide()
        V.del:Hide()
    else
        adding = false
        A:Hide()
        V.title:Show()
    end

    local k = chosenKill
    if type(s) ~= "table" then
        V.title:SetText("")
        V.del:Hide()
        V.detail:SetText("")
        return
    end
    if k == "pull" then
        local p = s.pull
        V.title:SetText(L["%s · %släuft seit %s|r"]:format(p.name or "?", LABEL, hm(p.start)))
        V.del:Hide()
        V.detail:SetText(L["%sDer Kampf läuft seit %s.|r"]:format(GREY, ns.FightLength(time() - (p.start or time()))))
        return
    end
    if not k then
        V.title:SetText("")
        V.del:Hide()
        V.detail:SetText(GREY .. L["Noch kein Bossversuch in diesem Raid. Offiziere tragen Bosse mit \"Boss eintragen\" ein.|r"])
        return
    end
    local len = lengthText(k)
    V.title:SetText(("%s · %s %s%s%s"):format(k.name or "?", k.ok and "Kill" or "Wipe", k.src == "loot" and L["ca. "] or "", hm(k.t),
        len and L[" · Kampf %s"]:format(len) or ""))
    if officer() and not adding then V.del:Show() else V.del:Hide() end
    V.detail:SetText(table.concat(detailLines(s, k), "\n"))
end

---------------------------------------------------------------------------
-- Ersatzbank
---------------------------------------------------------------------------
-- The bench the view works on: a raid, or tonight's (nil while nothing is entered).
local function benchOf(s)
    if s == "next" then return tonightBench() end
    return s
end

-- Names of the group outside the instance seen in the last 10 minutes, without a bench entry.
local function outsideNames(s)
    local out = {}
    if type(s) ~= "table" or s ~= ns.Active() then return out end
    local t = time()
    for name, seen in pairs(s.outside or {}) do
        local m = s.members and s.members[name]
        if type(seen) == "number" and t - seen <= OUTSIDE_FOR and not ns.IsBenched(s, name) and not (m and (m.last or 0) >= seen) then
            out[#out + 1] = name
        end
    end
    table.sort(out)
    return out
end

-- the bench's columns; the note gives 12 px to the list's scroll bar, so "eingewechselt 20:15" keeps its width
local BENCH_COLS = { { "name", 6, 128, "Name" }, { "since", 138, 36, L["Seit"] }, { "how", 178, 110, L["Wie"] },
    { "note", 292, 148, L["Notiz"] }, { "joined", 444, 118, L["Im Raid"] } }

local function buildBench(f)
    local B = W.Page(f, { view = true })
    -- whose bench, then the entry line (officers)
    B:Bands({ "line", "row" })
    B.label = B:Line(1)
    B.pick = W.Picker(B, 200, function(v) benchName = v end)
    -- the suggestions are read when the list opens, not on every refresh (guild rosters can be long)
    local open = B.pick.Open
    function B.pick:Open()
        local s = chosen()
        self:SetValues(ns.BenchSuggestions(benchOf(s) or { list = {} }), L["Anderer Name"])
        return open(self)
    end
    B.note = W.LineEdit(B, 200)
    local function addBench()
        if not officer() then return end
        local s = chosen()
        local name = benchName or B.pick:GetValue()
        if not name then
            ns.msg(L["Zuerst einen Namen wählen."])
            return
        end
        -- tonight before the raid: ns.BenchTarget() (benchNext, or the recording if one started)
        local target = type(s) == "table" and s or nil
        local e, key = ns.BenchAdd(target, name, { note = B.note:GetText() })
        if not e then
            ns.msg(key)
            return
        end
        ns.msg(L["%s steht auf der Ersatzbank%s."]:format(key, e.note and (" (" .. e.note .. ")") or ""))
        benchName = nil
        B.pick:SetValue(nil)
        B.note:SetText("")
        ns.Refresh()
    end
    B.addBtn = W.Button(B, L["Eintragen"], 90, addBench)
    W.FitChip(B.addBtn, 90)
    B:Place(2, { B.pick, B.note, B.addBtn })
    -- Enter in the note enters the name, like the button
    B.note:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        addBench()
    end)
    B:Footer({ "hint" })
    B.hint:SetText(L["Raider tragen sich mit !bench im Flüster-, Raid- oder Gildenchat selbst ein. Es antwortet die Lootleitung."])

    local headFrame, head = B:Columns(BENCH_COLS)
    for k, fs in pairs(head) do headFrame[k] = fs end
    B.head = headFrame
    B.list = B:List(BENCH_ROWS, ROW_H, function(r)
        W.Cells(r, BENCH_COLS)
        r.x = W.ResetButton(r, T.RESET, function(self)
            local x = self:GetParent().item
            local target = benchOf(chosen())
            if not x or not officer() or not target then return end
            local ok, res = ns.BenchRemove(target, x.name)
            ns.msg(ok and L["%s steht nicht mehr auf der Ersatzbank."]:format(res) or res)
            ns.Refresh()
        end)
        r.x:SetPoint("RIGHT", -4, 0)
        W.Tooltip(r.x, L["Austragen"], L["Von der Ersatzbank nehmen."])
    end, function(r, x)
        local e = x.e
        r.name:SetText(classColored(x.name, e.class))
        r.since:SetText(hm(e.t))
        r.how:SetText(e.self and L["selbst, !bench"] or L["von %s"]:format(e.by or "?"))
        r.note:SetText(e.note or "")
        r.joined:SetText(x.joined and L["eingewechselt %s"]:format(hm(x.joined)) or "")
        if officer() then r.x:Show() else r.x:Hide() end
    end)
    B.empty = B:Empty()
    B.empty:Set(L["Niemand auf der Ersatzbank"], L["Offiziere tragen oben ein, Raider sich selbst mit !bench."])

    -- the group outside the instance, with a button that enters them all, under the list
    B.outside = W.Text(B, T.FONT.text, 478)
    B.outside:SetPoint("TOPLEFT", B.list, "BOTTOMLEFT", T.LAYOUT.TEXT_X, -10)
    B.all = W.Button(B, L["Alle eintragen"], 100, function()
        local s = chosen()
        if not officer() or type(s) ~= "table" then return end
        local n = 0
        for _, name in ipairs(outsideNames(s)) do
            if ns.BenchAdd(s, name, {}) then n = n + 1 end
        end
        ns.msg(L["%d auf die Ersatzbank eingetragen."]:format(n))
        ns.Refresh()
    end)
    B.all:SetPoint("TOPRIGHT", B.list, "BOTTOMRIGHT", 0, -6)
    return B
end

local function refreshBench(B, s)
    local off = officer()
    if s == "next" then
        B.label:SetText(L["Für heute, vor dem Raid:"])
    else
        B.label:SetText(L["Ersatzbank: %s"]:format(ns.BenchLabel(s)))
    end
    local target = benchOf(s)
    local benched = target and ns.BenchList(target) or {}
    B.list:SetItems(benched)
    B.empty:SetShown(#benched == 0)
    for _, w in ipairs({ B.pick, B.note, B.addBtn, B.hint }) do
        if off then w:Show() else w:Hide() end
    end
    local outside = off and outsideNames(s) or {}
    if #outside > 0 then
        B.outside:SetText(L["In der Gruppe, nicht in der Instanz: %s"]:format(table.concat(outside, ", ")))
        B.outside:Show()
        B.all:Show()
    else
        B.outside:SetText("")
        B.outside:Hide()
        B.all:Hide()
    end
end

---------------------------------------------------------------------------
-- Discord
---------------------------------------------------------------------------
local function setDiscord(D, text, s)
    discordText = text or ""
    discordFor, discordPart = type(s) == "table" and s.id or nil, part
    D.area.box:SetText(discordText)
    D.area.box:SetCursorPosition(0)
    D.area.box:HighlightText()
end

local function buildDiscord(f)
    local D = W.Page(f, { view = true })
    -- the parts as chips, the text down to the footer
    local top = D:Bands({ "row" })
    D.chips = {}
    for i = 1, MAX_PARTS do
        local c = W.Chip(D, L["Teil %d"]:format(i), 60, function()
            part = i
            discordText = nil
            ns.Refresh()
        end)
        W.FitChip(c, 60)
        c:Hide()
        D.chips[i] = c
    end
    D:Place(1, D.chips)
    D:Footer({ "hint" })
    D.area = W.EditArea(D)
    D.area:SetPoint("TOPLEFT", 0, top)
    D.area:SetPoint("BOTTOMRIGHT", 0, D:Bottom())
    -- read-only like the export box: typing puts the text back and marks it
    D.area.box:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(discordText or "")
            self:HighlightText()
        end
    end)
    -- the text is kept while the box has the focus (a live raid changes it every minute and would
    -- take the selection away); leaving the box brings it up to date
    D.area.box:SetScript("OnEditFocusLost", function()
        if page and page:IsShown() and D:IsShown() then ns.Refresh() end
    end)
    return D
end

local function refreshDiscord(D, s)
    if type(s) ~= "table" then
        for _, c in ipairs(D.chips) do c:Hide() end
        if discordText ~= "" then setDiscord(D, "") end
        D.hint:SetText(noRaidText(s))
        return
    end
    -- focused on the same raid and part: the box keeps its text and selection
    if D.area.box:HasFocus() and discordText ~= nil and discordFor == s.id and discordPart == part and not focusDiscord then
        return
    end
    local parts = ns.RaidSummary(s)
    if part > #parts then part = math.max(1, #parts) end
    for i, c in ipairs(D.chips) do
        if #parts > 1 and i <= #parts then
            c:SetOn(i == part)
            c:Show()
        else
            c:Hide()
        end
    end
    local text = parts[part] or ""
    if text ~= discordText or discordFor ~= s.id or discordPart ~= part then setDiscord(D, text, s) end
    if focusDiscord then
        focusDiscord = false
        D.area.box:SetFocus()
        D.area.box:HighlightText()
    end
    D.hint:SetText(L["Strg+A, Strg+C, in Discord einfügen. %d Zeichen.%s"]:format(ns.TextLength(text),
        #parts > 1 and L[" Teil %d von %d."]:format(part, #parts) or ""))
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------
local function setView(v)
    view = v
    if v == "bench" then ns.RequestGuildRoster() end
    if v == "discord" then
        focusDiscord = true
        discordText = nil
    end
    ns.Refresh()
end

function ns.RaidLogPageFrame() return page end

-- Opens the page with a view ("verlauf", "bench", "rolls", "discord") on a raid (nil: the default).
function ns.ShowRaidLog(v, sessionId)
    view = VIEWS[tostring(v or ""):lower()] or view
    chosenRaid = sessionId
    chosenKill, adding, part = nil, false, 1
    if view == "bench" then ns.RequestGuildRoster() end
    if view == "discord" then
        focusDiscord = true
        discordText = nil
    end
    ns.ShowPage("raidlog")
end

ns.RegisterPanel{ key = "raidlog", label = L["Raid-Log"], icon = "Interface\\Icons\\INV_Misc_Note_01", order = 25, group = "raid",
    create = function(parent)
        local f = W.Page(parent)
        page = f
        -- the head row: the raid, entering a boss and the Discord text (officers); then the counts
        -- and the views
        f:Bands({ "row", "line", "row" })
        f.raid = W.Picker(f, 220, function(v)
            chosenRaid = v
            chosenKill, adding, part = nil, false, 1
            discordText = nil
            ns.Refresh()
        end)
        f.discordBtn = W.Button(f, L["Discord-Text"], 110, function() setView("discord") end)
        f.addBoss = W.Button(f, L["Boss eintragen"], 110, function()
            if not officer() then return end
            local s = chosen()
            if type(s) ~= "table" then
                ns.msg(noRaidText(s))
                return
            end
            view = "verlauf"
            adding, addOk, addName, addAt, addFor = true, true, nil, nil, s
            if f.log then f.log.add.pick:SetValue(nil) end
            ns.Refresh()
        end)
        W.FitChip(f.addBoss, 110)
        W.FitChip(f.discordBtn, 110)
        f:Place(1, { f.raid }, { f.addBoss, f.discordBtn })
        f.counts = f:Line(2)
        f.views = {}
        f.views.verlauf = W.Chip(f, L["Verlauf"], 70, function() setView("verlauf") end)
        f.views.bench = W.Chip(f, L["Ersatzbank"], 110, function() setView("bench") end)
        f.views.rolls = W.Chip(f, L["Würfe"], 90, function() setView("rolls") end)
        f.views.discord = W.Chip(f, "Discord", 70, function() setView("discord") end)
        f.viewRow = { f.views.verlauf, f.views.bench, f.views.rolls, f.views.discord }
        f:Place(3, f.viewRow)
        f.log = buildLog(f)
        f.bench = buildBench(f)
        f.discord = buildDiscord(f)
        f.rolls = ns.RaidLogRolls.Build(f)
        f.log:Hide()
        f.bench:Hide()
        f.discord:Hide()
        return f
    end,
    refresh = function(f)
        local off = officer()
        local s = chosen()
        local v = shownView()
        -- the raid choice: the recording (or tonight before the raid) first, then the saved raids
        local values, act = {}, ns.Active()
        if not act then
            values[1] = { value = "next", text = L["Heute, vor dem Raid (%s)"]:format(shortDate(ns.NightOf(time()))) }
        end
        for _, r in ipairs(ordered()) do
            values[#values + 1] = { value = r.id, text = ("%s%s, %s"):format(r == act and "|TInterface\\AddOns\\Amisia\\Media\\Icons\\dot:12:12:0:0|t " or "",
                r.zone or "?", shortDate(r.date)) }
        end
        f.raid:SetValues(values)
        f.raid:SetValue(s == "next" and "next" or s.id)
        if off then f.addBoss:Show(); f.discordBtn:Show(); f.views.discord:Show()
        else f.addBoss:Hide(); f.discordBtn:Hide(); f.views.discord:Hide() end
        f.counts:SetText(countsText(s))
        local target = benchOf(s)
        f.views.bench.label:SetText(L["Ersatzbank (%d)"]:format(target and #ns.BenchList(target) or 0))
        f.views.verlauf:SetOn(v == "verlauf")
        f.views.bench:SetOn(v == "bench")
        f.views.discord:SetOn(v == "discord")
        f.views.rolls:SetOn(v == "rolls")
        f.views.rolls.label:SetText(L["Würfe (%d)"]:format(ns.RaidLogRolls.Count(s)))
        if v ~= "verlauf" then adding = false end
        for key, frame in pairs({ verlauf = f.log, bench = f.bench, discord = f.discord, rolls = f.rolls }) do
            if key ~= v then frame:Hide() end
        end
        if v == "verlauf" then
            f.log:Show()
            refreshLog(f.log, s)
        elseif v == "bench" then
            f.bench:Show()
            refreshBench(f.bench, s)
        elseif v == "rolls" then
            f.rolls:Show()
            ns.RaidLogRolls.Refresh(f.rolls, s)
        else
            f.discord:Show()
            refreshDiscord(f.discord, s)
        end
    end }

StaticPopupDialogs["AMISIA_RAIDLOG_DELETE"] = {
    text = L["Diesen Eintrag aus dem Raid-Log löschen?"],
    button1 = L["Löschen##Knopf"],
    button2 = L["Abbrechen"],

    OnAccept = function(_, data)
        if type(data) == "table" and data.s and data.k then
            ns.DeleteKill(data.s, data.k)
            if chosenKill == data.k then chosenKill = nil end
        end
        ns.Refresh()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}
