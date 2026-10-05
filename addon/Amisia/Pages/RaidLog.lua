-- Raid log: the timeline of one raid (start, late raiders, raiders from the bench, every boss
-- attempt, the end) with the details of an attempt, the bench of the raid and its Discord text.
-- Everyone sees the timeline and the bench; entering bosses, editing the bench and the Discord text
-- are for officers.
local ADDON, ns = ...
local W = ns.W
local GOLD = W.GOLD
local LOG_ROWS, BENCH_ROWS, ROW_H = 12, 10, 22
local MAX_PARTS = 6
local OUTSIDE_FOR = 600   -- seconds: the group outside offered for "Alle eintragen"
local GREY, GREEN, RED, ORANGE, LABEL = "|cff8f86a3", "|cff4fbf7a", "|cffe05a5a", "|cffe0a344", "|cffe2b857"
local SRC_TEXT = { enc = "Kampf", kill = "Kampf (Ende)", loot = "Lootfenster", hand = "von Hand" }
local VIEWS = { verlauf = "verlauf", log = "verlauf", bench = "bench", ersatzbank = "bench", ersatz = "bench", discord = "discord" }
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

-- "05.10." from "2026-10-05".
local function shortDate(iso)
    local m, d = tostring(iso or ""):match("^%d+%-(%d+)%-(%d+)$")
    return d and (d .. "." .. m .. ".") or tostring(iso or "?")
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
    if s == "next" and #ns.Sessions() > 0 then return "Für heute vor dem Raid gibt es noch keinen Raid-Log." end
    return "Noch kein Raid aufgezeichnet."
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

local function col(parent, x, w, label, template)
    local fs = W.Text(parent, template or "GameFontNormalSmall", w)
    fs:SetPoint("LEFT", x, 0)
    if label then fs:SetText(label) end
    return fs
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
        if #ns.Sessions() == 0 and shownView() ~= "bench" then return "Noch kein Raid aufgezeichnet." end
        local b = tonightBench()
        local n = b and #ns.BenchList(b) or 0
        return ("Heute, vor dem Raid · %d auf der Ersatzbank"):format(n)
    end
    local _, wipes, bosses = ns.KillCount(s)
    local parts = {}
    if bosses > 0 then parts[#parts + 1] = bosses == 1 and "1 Boss" or (bosses .. " Bosse") end
    if wipes > 0 then parts[#parts + 1] = ns.WipeText(wipes) end
    parts[#parts + 1] = ("%s bis %s"):format(hm(s.firstScan or s.start), hm(s.last or s.start))
    local members = ns.MemberCount(s)
    if members > 0 then parts[#parts + 1] = members .. " Raider" end
    local late = ns.LateCount(s)
    if late > 0 then parts[#parts + 1] = late .. " zu spät" end
    local bench = #ns.BenchList(s)
    if bench > 0 then parts[#parts + 1] = bench .. " Ersatzbank" end
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
        event = "Aufnahme gestartet"
    elseif e.kind == "end" then
        event = "Aufnahme beendet"
    elseif e.kind == "late" then
        event, result = e.name .. " kommt", ORANGE .. "zu spät|r"
    elseif e.kind == "bench" then
        event = e.name .. " kommt von der Ersatzbank"
    elseif e.kind == "pull" then
        event = e.p.name or "?"
        result = LABEL .. "läuft|r"
        dur = ns.FightLength(time() - (e.p.start or time()))
        src = "Kampf"
    elseif e.kind == "kill" then
        local k = e.k
        if k.src == "loot" then when = GREY .. "ca. " .. hm(k.t) .. "|r" end
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

local function buildLog(f)
    local V = CreateFrame("Frame", nil, f)
    V:SetPoint("TOPLEFT", 0, -72)
    V:SetPoint("BOTTOMRIGHT", 0, 0)
    local head = CreateFrame("Frame", nil, V)
    head:SetHeight(18)
    head:SetPoint("TOPLEFT", 0, 0)
    head:SetPoint("TOPRIGHT", 0, 0)
    head.time = col(head, 2, 48, "Zeit")
    head.event = col(head, 54, 246, "Ereignis")
    head.result = col(head, 304, 76, "Ergebnis")
    head.dur = col(head, 384, 46, "Dauer")
    head.who = col(head, 434, 46, "Dabei")
    head.src = col(head, 484, 118, "Quelle")
    V.head = head
    V.list = W.List(V, LOG_ROWS, ROW_H, function(r)
        r.sel = W.Flat(r, GOLD[1], GOLD[2], GOLD[3], 0.18, "BORDER")
        r.time = col(r, 2, 48, nil, "GameFontHighlightSmall")
        r.event = col(r, 54, 246, nil, "GameFontHighlightSmall")
        r.result = col(r, 304, 76, nil, "GameFontHighlightSmall")
        r.dur = col(r, 384, 46, nil, "GameFontHighlightSmall")
        r.who = col(r, 434, 46, nil, "GameFontHighlightSmall")
        r.src = col(r, 484, 118, nil, "GameFontHighlightSmall")
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
    V.list:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, 0)
    V.list:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", 0, 0)

    -- the detail area under the list
    V.title = W.Text(V, "GameFontNormal", 490)
    V.title:SetPoint("TOPLEFT", V.list, "BOTTOMLEFT", 6, -6)
    V.del = W.Button(V, "Löschen", 90, function()
        local s = chosen()
        if not officer() or type(s) ~= "table" or type(chosenKill) ~= "table" then return end
        lift(StaticPopup_Show("AMISIA_RAIDLOG_DELETE", nil, nil, { s = s, k = chosenKill }))
    end)
    V.del:SetPoint("TOPRIGHT", V.list, "BOTTOMRIGHT", 0, -4)
    V.detail = W.ScrollText(V)
    V.detail:SetPoint("TOPLEFT", V.list, "BOTTOMLEFT", 0, -28)
    V.detail:SetPoint("BOTTOMRIGHT", -24, 0)

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
    A.ok = W.Button(A, "Eintragen", 90, function()
        local s = chosen()
        if not officer() or type(s) ~= "table" then return end
        if s ~= addFor then
            -- another raid is shown now (a recording started): the line was for the one before
            adding, addName, addAt, addFor = false, nil, nil, nil
            A.pick:SetValue(nil)
            ns.msg("Der Raid hat gewechselt. Bitte den Boss neu eintragen.")
            ns.Refresh()
            return
        end
        if not addName then
            ns.msg("Zuerst einen Boss wählen oder einen Namen eingeben.")
            return
        end
        local live = s == ns.Active()
        local t = addAt or (live and time()) or (s.last or s.start)
        local k, why = ns.AddKill(s, { name = addName, ok = addOk, t = t })
        if not k then
            ns.msg(why)
            return
        end
        ns.msg(("%s eingetragen: %s (%s)."):format(k.ok and "Kill" or "Wipe", k.name, hm(k.t)))
        adding, addName, addAt, addFor = false, nil, nil, nil
        A.pick:SetValue(nil)
        chosenKill = k
        ns.Refresh()
    end)
    A.ok:SetPoint("LEFT", A.wipe, "RIGHT", 10, 0)
    A.cancel = W.Button(A, "Abbrechen", 90, function()
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
        lines[#lines + 1] = LABEL .. "Dabei:|r unbekannt (von Hand nachgetragen)"
        if not k.ok then return lines end
    elseif not k.ok then
        lines[#lines + 1] = ("%sDabei:|r %d Raider"):format(LABEL, tonumber(k.n) or 0)
        return lines
    end
    local inWho = {}
    if unknownWho(k) then
        -- nobody to list as there or not there
    elseif k.wait then
        lines[#lines + 1] = LABEL .. "Dabei:|r wird nach dem Kampf gelesen"
    else
        local who = {}
        for _, name in ipairs(k.who or {}) do
            inWho[name:lower()] = true
            who[#who + 1] = memberColored(s, name)
        end
        lines[#lines + 1] = ("%sDabei (%d):|r %s"):format(LABEL, #who, #who > 0 and table.concat(who, ", ") or "niemand")
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
                if (x.m.first or 0) > (k.t or 0) then text = text .. (" (kam %s)"):format(hm(x.m.first)) end
                words[i] = text
            end
            lines[#lines + 1] = LABEL .. "Nicht dabei:|r " .. table.concat(words, ", ")
        end
    end
    local bench = {}
    for _, x in ipairs(ns.BenchList(s)) do
        if not inWho[x.name:lower()] then bench[#bench + 1] = classColored(x.name, x.e.class) end
    end
    if #bench > 0 then lines[#lines + 1] = LABEL .. "Ersatzbank:|r " .. table.concat(bench, ", ") end
    local loot = {}
    for _, a in ipairs(s.awards or {}) do
        if ns.KillFor(s, a.src, a.t) == k then
            if a.to == "bank" or a.to == "de" then
                loot[#loot + 1] = ("%s: %s"):format(ns.ItemName(a.item), a.to == "bank" and "Bank" or "entzaubert")
            else
                loot[#loot + 1] = ("%s an %s%s"):format(ns.ItemName(a.item), a.name or "?", (a.kind and a.kind ~= "-") and (" (" .. a.kind .. ")") or "")
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
        for i, n in ipairs(names) do values[i] = { value = n, text = ("%s (Lootfenster %s)"):format(n, hm(first[n])) } end
        A.times = first
        A.pick:SetValues(values, "Anderer Name")
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
        V.title:SetText(("%s · %släuft seit %s|r"):format(p.name or "?", LABEL, hm(p.start)))
        V.del:Hide()
        V.detail:SetText(("%sDer Kampf läuft seit %s.|r"):format(GREY, ns.FightLength(time() - (p.start or time()))))
        return
    end
    if not k then
        V.title:SetText("")
        V.del:Hide()
        V.detail:SetText(GREY .. "Noch kein Bossversuch in diesem Raid. Offiziere tragen Bosse mit \"Boss eintragen\" ein.|r")
        return
    end
    local len = lengthText(k)
    V.title:SetText(("%s · %s %s%s%s"):format(k.name or "?", k.ok and "Kill" or "Wipe", k.src == "loot" and "ca. " or "", hm(k.t),
        len and (" · Kampf " .. len) or ""))
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

local function buildBench(f)
    local B = CreateFrame("Frame", nil, f)
    B:SetPoint("TOPLEFT", 0, -72)
    B:SetPoint("BOTTOMRIGHT", 0, 0)
    B.label = W.Text(B, "GameFontHighlightSmall", 590)
    B.label:SetPoint("TOPLEFT", 6, 0)
    B.pick = W.Picker(B, 200, function(v) benchName = v end)
    B.pick:SetPoint("TOPLEFT", 0, -18)
    -- the suggestions are read when the list opens, not on every refresh (guild rosters can be long)
    local open = B.pick.Open
    function B.pick:Open()
        local s = chosen()
        self:SetValues(ns.BenchSuggestions(benchOf(s) or { list = {} }), "Anderer Name")
        return open(self)
    end
    B.note = W.LineEdit(B, 200)
    B.note:SetPoint("LEFT", B.pick, "RIGHT", 6, 0)
    local function addBench()
        if not officer() then return end
        local s = chosen()
        local name = benchName or B.pick:GetValue()
        if not name then
            ns.msg("Zuerst einen Namen wählen.")
            return
        end
        -- tonight before the raid: ns.BenchTarget() (benchNext, or the recording if one started)
        local target = type(s) == "table" and s or nil
        local e, key = ns.BenchAdd(target, name, { note = B.note:GetText() })
        if not e then
            ns.msg(key)
            return
        end
        ns.msg(("%s steht auf der Ersatzbank%s."):format(key, e.note and (" (" .. e.note .. ")") or ""))
        benchName = nil
        B.pick:SetValue(nil)
        B.note:SetText("")
        ns.Refresh()
    end
    B.addBtn = W.Button(B, "Eintragen", 90, addBench)
    B.addBtn:SetPoint("LEFT", B.note, "RIGHT", 6, 0)
    -- Enter in the note enters the name, like the button
    B.note:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        addBench()
    end)

    local head = CreateFrame("Frame", nil, B)
    head:SetHeight(18)
    head:SetPoint("TOPLEFT", 0, -44)
    head:SetPoint("TOPRIGHT", 0, -44)
    head.name = col(head, 4, 130, "Name")
    head.since = col(head, 138, 36, "Seit")
    head.how = col(head, 178, 110, "Wie")
    head.note = col(head, 292, 160, "Notiz")
    head.joined = col(head, 456, 118, "Im Raid")
    B.head = head
    B.list = W.List(B, BENCH_ROWS, ROW_H, function(r)
        r.name = col(r, 4, 130, nil, "GameFontHighlightSmall")
        r.since = col(r, 138, 36, nil, "GameFontHighlightSmall")
        r.how = col(r, 178, 110, nil, "GameFontHighlightSmall")
        r.note = col(r, 292, 160, nil, "GameFontHighlightSmall")
        r.joined = col(r, 456, 118, nil, "GameFontHighlightSmall")
        r.x = W.Chip(r, "x", 20, function(self)
            local x = self:GetParent().item
            local target = benchOf(chosen())
            if not x or not officer() or not target then return end
            local ok, res = ns.BenchRemove(target, x.name)
            ns.msg(ok and ("%s steht nicht mehr auf der Ersatzbank."):format(res) or res)
            ns.Refresh()
        end)
        r.x:SetPoint("RIGHT", -4, 0)
        r.x:SetOn(false)
        W.Tooltip(r.x, "Austragen", "Von der Ersatzbank nehmen.")
    end, function(r, x)
        local e = x.e
        r.name:SetText(classColored(x.name, e.class))
        r.since:SetText(hm(e.t))
        r.how:SetText(e.self and "selbst, !bench" or ("von " .. (e.by or "?")))
        r.note:SetText(e.note or "")
        r.joined:SetText(x.joined and ("eingewechselt " .. hm(x.joined)) or "")
        if officer() then r.x:Show() else r.x:Hide() end
    end)
    B.list:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, 0)
    B.list:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", 0, 0)

    B.outside = W.Text(B, "GameFontHighlightSmall", 490)
    B.outside:SetPoint("TOPLEFT", B.list, "BOTTOMLEFT", 6, -10)
    B.all = W.Button(B, "Alle eintragen", 100, function()
        local s = chosen()
        if not officer() or type(s) ~= "table" then return end
        local n = 0
        for _, name in ipairs(outsideNames(s)) do
            if ns.BenchAdd(s, name, {}) then n = n + 1 end
        end
        ns.msg(("%d auf die Ersatzbank eingetragen."):format(n))
        ns.Refresh()
    end)
    B.all:SetPoint("TOPRIGHT", B.list, "BOTTOMRIGHT", 0, -6)
    B.hint = W.Text(B, "GameFontDisableSmall", 590, true)
    B.hint:SetPoint("TOPLEFT", B.list, "BOTTOMLEFT", 6, -40)
    B.hint:SetText("Raider tragen sich mit !bench im Flüster-, Raid- oder Gildenchat selbst ein. Es antwortet die Lootleitung.")
    return B
end

local function refreshBench(B, s)
    local off = officer()
    if s == "next" then
        B.label:SetText("Für heute, vor dem Raid:")
    else
        B.label:SetText("Ersatzbank: " .. ns.BenchLabel(s))
    end
    local target = benchOf(s)
    B.list:SetItems(target and ns.BenchList(target) or {})
    for _, w in ipairs({ B.pick, B.note, B.addBtn, B.hint }) do
        if off then w:Show() else w:Hide() end
    end
    local outside = off and outsideNames(s) or {}
    if #outside > 0 then
        B.outside:SetText("In der Gruppe, nicht in der Instanz: " .. table.concat(outside, ", "))
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
    local D = CreateFrame("Frame", nil, f)
    D:SetPoint("TOPLEFT", 0, -72)
    D:SetPoint("BOTTOMRIGHT", 0, 0)
    D.chips = {}
    for i = 1, MAX_PARTS do
        local c = W.Chip(D, "Teil " .. i, 60, function()
            part = i
            discordText = nil
            ns.Refresh()
        end)
        c:SetPoint("TOPLEFT", (i - 1) * 64, 0)
        c:Hide()
        D.chips[i] = c
    end
    D.area = W.EditArea(D)
    D.area:SetPoint("TOPLEFT", 0, -24)
    D.area:SetPoint("TOPRIGHT", 0, -24)
    D.area:SetHeight(340)
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
    D.hint = W.Text(D, "GameFontDisableSmall", 590)
    D.hint:SetPoint("TOPLEFT", D.area, "BOTTOMLEFT", 0, -6)
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
    D.hint:SetText(("Strg+A, Strg+C, in Discord einfügen. %d Zeichen.%s"):format(ns.TextLength(text),
        #parts > 1 and (" Teil %d von %d."):format(part, #parts) or ""))
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

-- Opens the page with a view ("verlauf", "bench", "discord") on a raid (nil: the default).
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

ns.RegisterPanel{ key = "raidlog", label = "Raid-Log", icon = "Interface\\Icons\\INV_Misc_Note_01", order = 25,
    create = function(parent)
        local f = CreateFrame("Frame", nil, parent)
        page = f
        f.raid = W.Picker(f, 220, function(v)
            chosenRaid = v
            chosenKill, adding, part = nil, false, 1
            discordText = nil
            ns.Refresh()
        end)
        f.raid:SetPoint("TOPLEFT", 0, -2)
        f.discordBtn = W.Button(f, "Discord-Text", 110, function() setView("discord") end)
        f.discordBtn:SetPoint("TOPRIGHT", 0, -1)
        f.addBoss = W.Button(f, "Boss eintragen", 110, function()
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
        f.addBoss:SetPoint("RIGHT", f.discordBtn, "LEFT", -6, 0)
        f.counts = W.Text(f, "GameFontDisableSmall", 590)
        f.counts:SetPoint("TOPLEFT", 6, -28)
        f.views = {}
        f.views.verlauf = W.Chip(f, "Verlauf", 70, function() setView("verlauf") end)
        f.views.verlauf:SetPoint("TOPLEFT", 0, -48)
        f.views.bench = W.Chip(f, "Ersatzbank", 110, function() setView("bench") end)
        f.views.bench:SetPoint("LEFT", f.views.verlauf, "RIGHT", 4, 0)
        f.views.discord = W.Chip(f, "Discord", 70, function() setView("discord") end)
        f.views.discord:SetPoint("LEFT", f.views.bench, "RIGHT", 4, 0)
        f.log = buildLog(f)
        f.bench = buildBench(f)
        f.discord = buildDiscord(f)
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
            values[1] = { value = "next", text = ("Heute, vor dem Raid (%s)"):format(shortDate(ns.NightOf(time()))) }
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
        f.views.bench.label:SetText(("Ersatzbank (%d)"):format(target and #ns.BenchList(target) or 0))
        f.views.verlauf:SetOn(v == "verlauf")
        f.views.bench:SetOn(v == "bench")
        f.views.discord:SetOn(v == "discord")
        if v ~= "verlauf" then adding = false end
        if v == "verlauf" then
            f.bench:Hide(); f.discord:Hide(); f.log:Show()
            refreshLog(f.log, s)
        elseif v == "bench" then
            f.log:Hide(); f.discord:Hide(); f.bench:Show()
            refreshBench(f.bench, s)
        else
            f.log:Hide(); f.bench:Hide(); f.discord:Show()
            refreshDiscord(f.discord, s)
        end
    end }

StaticPopupDialogs["AMISIA_RAIDLOG_DELETE"] = {
    text = "Diesen Eintrag aus dem Raid-Log löschen?",
    button1 = "Löschen",
    button2 = "Abbrechen",
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
