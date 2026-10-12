-- Raid-Check (officers only, F-098/F-099, D-46): three views of the raid before the pull and of the
-- guild before the evening. "Buffs & Verbrauch": per raider the flask, elixirs, food, the missing
-- class buffs and the Amisia version (read from the auras out of combat; out of sight the raider's
-- own report); "Ausrüstung": what each raider's Amisia says (item level, lowest durability, empty and
-- unenchanted slots, free talent points, when); "Raid-IDs": per instance who of the guild is free,
-- locked or unknown, grouped by main, filters "nur frei" and "nur Stufe 60". "Prüfen" asks the raid
-- (XQ), "Im Raid-Chat sagen" (raidcheck.chat) says what is missing, "Raid-IDs abfragen" asks the
-- guild (IQ). The logic lives in Raid/RaidCheck.lua and Raid/RaidIDs.lua; this page only shows it.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local GREY, ORANGE, RED, GREEN = T.GREY, T.ORANGE, T.RED, T.GREEN

local ROWS, ROW_H = 17, 20
local ID_ROWS = 15
local POLL = 10            -- the buffs are read again this often while the page is open
-- the columns { key, x, width } of the three lists (590 wide: the page less the bar's room)
local BUFF_COLS = { { "g", 6, 14 }, { "name", 24, 140 }, { "flask", 168, 70 }, { "elixir", 242, 50 }, { "food", 296, 54 },
                    { "buffs", 354, 150 }, { "ver", 508, 76 } }
local GEAR_COLS = { { "g", 6, 14 }, { "name", 24, 140 }, { "ilvl", 168, 46 }, { "dur", 218, 70 }, { "empty", 292, 86 },
                    { "unench", 382, 86 }, { "free", 472, 44 }, { "at", 520, 64 } }
local ID_COLS = { { "name", 6, 170 }, { "level", 180, 34 }, { "state", 222, 228 }, { "by", 454, 130 } }
local ALT_X = 18           -- an alt's name, indented under its main

local page
local view = "buffs"       -- "buffs", "gear" or "ids"
local onlyFree, onlyTop = false, false

function ns.RaidCheckPageFrame() return page end

local function show(frame, on) if on then frame:Show() else frame:Hide() end end
local function color(c, text) return c .. text .. "|r" end

local function classColored(name, class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return c and c.colorStr and ("|c%s%s|r"):format(c.colorStr, name) or name
end

local function ago(at)
    local s = math.max(0, time() - (at or time()))
    if s < 60 then return L["gerade eben"] end
    return L["vor %d Min."]:format(math.floor(s / 60))
end

local function left(info)
    if not info or not info.left then return "" end
    return L[", noch %d Min."]:format(math.max(1, math.floor(info.left / 60 + 0.5)))
end

local STATE_WORD = { offline = L["offline"], dead = L["tot"], far = L["außer Sicht"] }

-- Opens the page, in a view when given ("buffs", "gear", "ids").
function ns.ShowRaidCheck(which)
    if which == "buffs" or which == "gear" or which == "ids" then view = which end
    ns.ShowPage("raidcheck")
end

---------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------
local function buffTooltip(owner, r)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(r.name, 1, 0.82, 0)
    if r.state ~= "ok" and not r.cons then
        GameTooltip:AddLine(STATE_WORD[r.state] or "", 0.85, 0.85, 0.85)
    end
    local c = r.cons
    if c then
        if r.src == "self" then
            GameTooltip:AddLine(L["Laut Amisia des Spielers (%s), außer Sicht."]:format(ago(r.rep and r.rep.at)), 0.85, 0.85, 0.85, true)
        end
        local function line(label, info)
            if info then
                GameTooltip:AddLine(("%s: %s%s"):format(label, info.name or (info.self and L["ja"]) or tostring(info.id or ""), left(info)), 0.4, 0.85, 0.5, true)
            end
        end
        line(L["Fläschchen"], c.flask)
        for _, e in ipairs(c.elixirs) do line(L["Elixier"], e) end
        line(L["Essen"], c.food)
        if not ns.RaidCheck.Supplied(c) then GameTooltip:AddLine(L["Kein Fläschchen und kein Elixier."], 0.88, 0.34, 0.29, true) end
        if not c.food then GameTooltip:AddLine(L["Kein Essen (Satt)."], 0.88, 0.34, 0.29, true) end
        for _, key in ipairs(ns.RaidCheck.GROUP_ORDER) do
            if c.have[key] then line(ns.RaidCheck.GROUP_NAME[key], c.have[key]) end
        end
        for _, key in ipairs(r.missing or {}) do
            GameTooltip:AddLine(L["Fehlt: %s"]:format(ns.RaidCheck.GROUP_NAME[key]), 0.88, 0.34, 0.29, true)
        end
    end
    GameTooltip:AddLine(r.ver and L["Amisia %s"]:format(r.ver) or L["Ohne Amisia: nur Buffs."], 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

local function fillBuff(row, r)
    row.g:SetText(color(GREY, tostring(r.g or "")))
    row.name:SetText(classColored(r.name, r.c) .. (r.src == "self" and color(GREY, " *") or ""))
    local c = r.cons
    if not c then
        row.flask:SetText(color(GREY, STATE_WORD[r.state] or "-"))
        row.elixir:SetText("")
        row.food:SetText("")
        row.buffs:SetText("")
    else
        local supplied = ns.RaidCheck.Supplied(c)
        row.flask:SetText(c.flask and color(GREEN, L["ja"]) or (supplied and color(GREY, "-") or color(RED, L["fehlt"])))
        local n = #c.elixirs
        row.elixir:SetText(n > 0 and color(GREEN, tostring(n)) or (supplied and color(GREY, "0") or color(RED, "0")))
        row.food:SetText(c.food and color(GREEN, L["ja"]) or color(RED, L["fehlt"]))
        if r.src ~= "read" then
            row.buffs:SetText(color(GREY, L["laut Amisia"]))
        elseif #r.missing > 0 then
            local parts = {}
            for i, key in ipairs(r.missing) do parts[i] = ns.RaidCheck.GROUP_SHORT[key] end
            row.buffs:SetText(color(RED, table.concat(parts, ", ")))
        else
            row.buffs:SetText(color(GREEN, L["alle"]))
        end
    end
    row.ver:SetText(r.ver and r.ver or color(GREY, "-"))
end

local function gearTooltip(owner, r)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(r.name, 1, 0.82, 0)
    local rep = r.rep
    if not rep then
        GameTooltip:AddLine(L["Ohne Amisia: nur Buffs."], 0.85, 0.85, 0.85, true)
    else
        GameTooltip:AddLine(L["Laut Amisia des Spielers, %s."]:format(ago(rep.at)), 0.85, 0.85, 0.85, true)
        local names = ns.RaidCheck.SlotNames
        GameTooltip:AddLine(L["Leere Plätze: %s"]:format(names(rep.empty)), 1, 1, 1, true)
        GameTooltip:AddLine(L["Unverzaubert: %s"]:format(names(rep.unench)), 1, 1, 1, true)
        if rep.below and rep.below > 0 then
            GameTooltip:AddLine(L["%d Items unter %d %% Haltbarkeit"]:format(rep.below, ns.Get("raidcheck.durability") or 30), 0.88, 0.34, 0.29, true)
        end
    end
    GameTooltip:Show()
end

local function fillGear(row, r)
    row.g:SetText(color(GREY, tostring(r.g or "")))
    row.name:SetText(classColored(r.name, r.c))
    local rep = r.rep
    if not rep then
        for _, k in ipairs({ "ilvl", "dur", "empty", "unench", "free", "at" }) do row[k]:SetText(k == "ilvl" and color(GREY, "-") or "") end
        return
    end
    row.ilvl:SetText(rep.ilvl and ("%.1f"):format(rep.ilvl) or color(GREY, "-"))
    if rep.dur then
        local c = ns.RaidCheck.DurColor(rep.dur)
        local text = ("%d %%"):format(rep.dur) .. ((rep.below or 0) > 0 and (" (%d)"):format(rep.below) or "")
        row.dur:SetText(c == "red" and color(RED, text) or c == "orange" and color(ORANGE, text) or color(GREEN, text))
    else
        row.dur:SetText(color(GREY, "-"))
    end
    local function count(list)
        local n = #(list or {})
        return n > 0 and color(RED, tostring(n)) or color(GREEN, "0")
    end
    row.empty:SetText(count(rep.empty))
    row.unench:SetText(count(rep.unench))
    if rep.free then
        local top = type(GetMaxPlayerLevel) == "function" and tonumber(GetMaxPlayerLevel()) or 60
        local level = r.l or rep.level
        local text = tostring(rep.free)
        -- below the highest level free points are normal: grey
        row.free:SetText((level and level < top) and color(GREY, text) or (rep.free > 0 and color(RED, text) or color(GREEN, text)))
    else
        row.free:SetText(color(GREY, "-"))
    end
    row.at:SetText(color(GREY, ago(rep.at)))
end

local function idTooltip(owner, p)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(p.n, 1, 0.82, 0)
    local m = ns.RaidIDsChosen()
    if p.state == "locked" and p.id then
        GameTooltip:AddLine(L["Gesperrt: %s"]:format(ns.RaidIDText(p.id)), 0.88, 0.34, 0.29, true)
    elseif p.state == "free" then
        GameTooltip:AddLine(L["Frei"], 0.4, 0.85, 0.5)
    else
        GameTooltip:AddLine(L["Unbekannt: ohne Amisia oder nicht gemeldet."], 0.6, 0.6, 0.6, true)
    end
    if p.by then GameTooltip:AddLine(L["Laut %s (nicht vom Charakter selbst)."]:format(p.by), 0.6, 0.6, 0.6, true) end
    if m then
        local alts = ns.RaidIDFreeAlts(p.n, m)
        if #alts > 0 then GameTooltip:AddLine(L["Freie Twinks: %s"]:format(table.concat(alts, ", ")), 1, 1, 1, true) end
    end
    GameTooltip:Show()
end

local function fillId(row, p)
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", p.alt and ALT_X or ID_COLS[1][2], 0)
    row.name:SetWidth(ID_COLS[1][3] - (p.alt and (ALT_X - ID_COLS[1][2]) or 0))
    row.name:SetText(classColored(p.n, p.c))
    row.level:SetText(p.l and tostring(p.l) or "")
    if p.state == "locked" then
        row.state:SetText(color(RED, L["gesperrt (%s)"]:format(ns.RaidIDText(p.id))))
    elseif p.state == "free" then
        row.state:SetText(color(GREEN, L["frei##ID"]))
    else
        row.state:SetText(color(GREY, L["unbekannt"]))
    end
    row.by:SetText(p.by and color(GREY, L["laut %s"]:format(p.by)) or "")
end

local function wireRow(row, tip)
    row:SetScript("OnEnter", function(self) if self.item then tip(self, self.item) end end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------
local function build(parent)
    local f = W.Page(parent)
    page = f
    local top = f:Bands({ "row", "line" })
    f.views = {
        buffs = W.Chip(f, L["Buffs & Verbrauch"], 120, function() view = "buffs" ns.Refresh() end),
        gear = W.Chip(f, L["Ausrüstung"], 90, function() view = "gear" ns.Refresh() end),
        ids = W.Chip(f, L["Raid-IDs"], 80, function() view = "ids" ns.Refresh() end),
    }
    W.FitChip(f.views.buffs, 120)
    W.FitChip(f.views.gear, 90)
    W.FitChip(f.views.ids, 80)
    f.check = W.Button(f, L["Prüfen"], 80, function()
        local _, line = ns.RaidCheck.Ask()
        if line then ns.msg(line) end
        ns.Refresh()
    end)
    W.FitChip(f.check, 80)
    W.Tooltip(f.check, L["Prüfen"], L["Liest die Buffs aller Raider in Sichtweite neu und fragt die Amisia-Clients des Raids nach Haltbarkeit, Itemstufe, Verzauberungen und freien Talentpunkten. Nicht im Kampf."])
    f.say = W.Button(f, L["Im Raid-Chat sagen"], 140, function()
        local n, why = ns.RaidCheck.Say()
        if not n and why then ns.msg(why) end
        ns.Refresh()
    end)
    W.FitChip(f.say, 140)
    W.Tooltip(f.say, L["Im Raid-Chat sagen"], L["Schreibt in den Raid-Chat, wem Fläschchen, Essen oder Haltbarkeit fehlt (höchstens zwei Zeilen, nur Namen aus der Raidliste). Nie im Bosskampf."])
    f.ask = W.Button(f, L["Raid-IDs abfragen"], 140, function()
        local ok, why = ns.RaidIDsAsk()
        if ok then ns.msg(L["Raid-IDs: die Gilde ist gefragt, die Antworten kommen in bis zu 30 Sekunden."]) elseif why then ns.msg(why) end
        ns.Refresh()
    end)
    W.FitChip(f.ask, 140)
    W.Tooltip(f.ask, L["Raid-IDs abfragen"], L["Fragt die Amisia-Clients der Gilde nach den Raid-IDs ihrer Charaktere (höchstens alle 5 Minuten). Wer online ist, antwortet per Flüstern."])
    f:Place(1, { f.views.buffs, f.views.gear, f.views.ids }, { f.say, f.check, f.ask }, { shown = true })
    f.line = f:Line(2)
    f:Footer({ { "hint", lines = 2 } })
    -- buffs
    f.buffView = W.Page(f, { view = true, top = top })
    local _, bh = f.buffView:Columns(BUFF_COLS)
    bh.g:SetText(L["Gr.##Gruppe"])
    bh.name:SetText(L["Name##Spalte"])
    bh.flask:SetText(L["Fläschchen"])
    bh.elixir:SetText(L["Elixiere"])
    bh.food:SetText(L["Essen"])
    bh.buffs:SetText(L["Fehlende Buffs"])
    bh.ver:SetText(L["Amisia"])
    f.buffList = f.buffView:List(ROWS, ROW_H, function(row)
        W.Cells(row, BUFF_COLS)
        wireRow(row, buffTooltip)
    end, fillBuff)
    -- gear
    f.gearView = W.Page(f, { view = true, top = top })
    local _, gh = f.gearView:Columns(GEAR_COLS)
    gh.g:SetText(L["Gr.##Gruppe"])
    gh.name:SetText(L["Name##Spalte"])
    gh.ilvl:SetText(L["Stufe##Item"])
    gh.dur:SetText(L["Haltbarkeit"])
    gh.empty:SetText(L["Leer##Platz"])
    gh.unench:SetText(L["Unverzaubert"])
    gh.free:SetText(L["Punkte"])
    gh.at:SetText(L["Stand"])
    f.gearList = f.gearView:List(ROWS, ROW_H, function(row)
        W.Cells(row, GEAR_COLS)
        wireRow(row, gearTooltip)
    end, fillGear)
    -- raid IDs: the instance and the filters in a band of their own
    f.idView = W.Page(f, { view = true, top = top })
    local idTop = f.idView:Bands({ "row" })
    f.inst = W.Picker(f.idView, 190, function(v)
        ns.RaidIDsChoose(v)
        ns.Refresh()
    end)
    f.onlyFree = W.Chip(f.idView, L["nur frei"], 70, function()
        onlyFree = not onlyFree
        ns.Refresh()
    end)
    f.onlyTop = W.Chip(f.idView, L["nur Stufe 60"], 90, function()
        onlyTop = not onlyTop
        ns.Refresh()
    end)
    W.FitChip(f.onlyFree, 70)
    W.FitChip(f.onlyTop, 90)
    f.idView:Place(1, { f.inst, f.onlyFree, f.onlyTop })
    local _, ih = f.idView:Columns(ID_COLS, { top = idTop })
    ih.name:SetText(L["Name##Spalte"])
    ih.level:SetText(L["Stufe"])
    ih.level:SetJustifyH("RIGHT")
    ih.state:SetText(L["Raid-ID"])
    ih.by:SetText(L["Quelle"])
    f.idList = f.idView:List(ID_ROWS, ROW_H, function(row)
        W.Cells(row, ID_COLS)
        row.level:SetJustifyH("RIGHT")
        wireRow(row, idTooltip)
    end, fillId)
    f.empty = f:Empty()
    -- the buffs are read again now and then while the page is open (never in combat)
    C_Timer.NewTicker(POLL, function()
        if page and page:IsVisible() and ns.CurrentPage and ns.CurrentPage() == "raidcheck" and view ~= "ids"
            and not ns.RaidCheck.Locked() then
            ns.Refresh()
        end
    end)
    return f
end

local function refresh(f)
    for k, c in pairs(f.views) do c:SetOn(k == view) end
    local ids = view == "ids"
    show(f.check, not ids)
    show(f.say, not ids and ns.Get("raidcheck.chat") == true)
    show(f.ask, ids)
    f.say:SetEnabled(ns.RaidCheck.CanSay())
    f:Place(1, { f.views.buffs, f.views.gear, f.views.ids }, { f.say, f.check, f.ask }, { shown = true })
    show(f.buffView, view == "buffs")
    show(f.gearView, view == "gear")
    show(f.idView, ids)
    f.empty:Hide()
    if ids then
        local wait = ns.RaidIDsAskWait()
        f.ask:SetEnabled(wait == 0)
        local list = ns.RaidIDsInstances()
        local values = {}
        for _, x in ipairs(list) do values[#values + 1] = { value = x.m, text = x.name } end
        f.inst:SetValues(values)
        local m = ns.RaidIDsChosen()
        f.inst:SetValue(m)
        f.onlyFree:SetOn(onlyFree)
        f.onlyTop:SetOn(onlyTop)
        f.onlyTop.label:SetText(L["nur Stufe %d"]:format(type(GetMaxPlayerLevel) == "function" and tonumber(GetMaxPlayerLevel()) or 60))
        W.FitChip(f.onlyTop, 90)
        f.idView:Place(1, { f.inst, f.onlyFree, f.onlyTop })
        if not m then
            f.line:SetText("")
            f.idList:SetItems({})
            f.empty:Set(L["Noch keine Raid-IDs"], L["Amisia liest die Raid-IDs nach dem Login und nach einem Boss-Kill; \"Raid-IDs abfragen\" fragt die Gilde."])
            f.empty:Show()
        else
            local rows = ns.RaidIDsRows(m, { free = onlyFree, top = onlyTop })
            local n = { free = 0, locked = 0, unknown = 0 }
            for _, p in ipairs(ns.RaidIDsRows(m)) do n[p.state] = n[p.state] + 1 end
            f.line:SetText(L["%s: %d frei · %d gesperrt · %d unbekannt"]:format(ns.RaidIDsName(m), n.free, n.locked, n.unknown))
            f.idList:SetItems(rows)
        end
        f.hint:SetText(L["Grün frei, rot gesperrt, grau unbekannt (ohne Amisia). Twinks stehen eingerückt unter ihrem Main (Twink-Liste der Website). \"laut ...\": nicht vom Charakter selbst gemeldet."])
        return
    end
    local rows = ns.RaidCheck.Rows()
    f.check:SetEnabled(not rows.combat)
    if rows.combat then
        f.line:SetText(color(ORANGE, L["Im Kampf: Werte von %s"]:format(date("%H:%M", rows.at))))
    elseif view == "buffs" then
        f.line:SetText(ns.RaidCheck.MissingText(rows))
    else
        local with = 0
        for _, r in ipairs(rows.list) do if r.rep then with = with + 1 end end
        f.line:SetText(L["Laut Amisia der Raider: %d von %d mit Amisia."]:format(with, #rows.list))
    end
    if view == "buffs" then
        f.buffList:SetItems(rows.list)
        f.hint:SetText(L["Gelesen aus den Buffs (außerhalb des Kampfes); * laut Amisia des Spielers, wenn er außer Sicht ist. Versorgt: ein Fläschchen oder ein Elixier. Klassen-Buffs zählen nur, wenn die Klasse im Raid ist."])
    else
        f.gearList:SetItems(rows.list)
        f.hint:SetText(L["Was die Amisia jedes Raiders meldet (\"Prüfen\" oder Bereitschaftscheck). Haltbarkeit rot unter %d %%, orange unter 50 %%. Ohne Amisia: nur Buffs."]:format(ns.Get("raidcheck.durability") or 30))
    end
    if #rows.list == 0 then
        f.empty:Set(L["Im Kampf"], L["Die Werte kommen nach dem Kampf."])
        f.empty:Show()
    end
end

ns.RegisterPanel{ key = "raidcheck", label = L["Raid-Check"], icon = "Interface\\Icons\\INV_Potion_97", order = 23, group = "raid",
    officer = true, available = function() return ns.RaidCheckAllowed() end,
    create = build, refresh = refresh }

local function again()
    if ns.CurrentPage and ns.CurrentPage() == "raidcheck" and ns.Refresh then ns.Refresh() end
end
ns.Listen("RAIDCHECK", again)
ns.Listen("RAIDIDS", again)
ns.OnEvent("GROUP_ROSTER_UPDATE", again)
