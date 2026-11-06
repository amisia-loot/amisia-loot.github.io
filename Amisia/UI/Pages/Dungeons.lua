-- Dungeons page (tab Ausrüstung, right after the gear page): the dungeon planner. The spec of the
-- gear page in the head row with the order of the list (by level, the ranking, the chain); the next
-- dungeon with its reason; every dungeon's value; the chosen one's image with its boss model, its
-- bosses and upgrades or its quests (one row each: state, level, the quest path's progress "Weg 2/4",
-- start, XP); the waypoints to its entrance and quest givers and "Alle Questgeber auf der Karte". A
-- click on a quest opens its quest path (F-135) in place of the list, image and quests: the steps from
-- the first pre-quest to the quest, each with where it is taken and handed in ("Karte"), what it needs
-- and its objective, the next step highlighted ("Nächsten Schritt auf der Karte"). The values come
-- from Gear/Dungeons.lua; item texts, marks, tooltips, clicks, menus and the cache are the gear page's
-- (ns.GearPageKit). The state stays in settings.bis (dungeon, dsort, dpart); the open quest path only
-- in memory (after /reload the list shows).
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local K = ns.GearPageKit
local GREY, GREEN = T.GREY, "|cff4fd06a"
local ICON = "Interface\\Icons\\INV_Misc_Book_11"
local ROW_H = 24
-- 5 dungeons and 5 rows of the chosen one between its image and the footer
local DUNGEON_ROWS, DETAIL_ROWS = 5, 5
local state, cached, say, col, hideTip = K.state, K.cached, K.say, K.col, K.hideTip
local itemText, marks, gainText = K.itemText, K.marks, K.gainText
local itemTooltip, modifiedClick, menuEntries = K.itemTooltip, K.modifiedClick, K.menuEntries

local page

---------------------------------------------------------------------------
-- The next dungeon, the list, the chosen one's bosses and quests
---------------------------------------------------------------------------

local GOLD_TEXT = "|cffe3b857"
-- the texts of the journal parts (image, XP, marks, dressing room), in one place for the translation
local DTEXT = {
    level = "Level %s · %s",
    mark = L["Alle auf Karte"],
    unmark = L["Karte leeren"],
    markTitle = L["Alle Questgeber auf der Karte"],
    markTip = L["Markiert die Questgeber aller offenen Quests dieses Dungeons auf der Weltkarte (bei einer Questreihe den Geber der ersten offenen Vorquest). Noch einmal klicken: Markierung entfernen."],
    marked = L["%d Questgeber auf der Weltkarte markiert."],
    unmarked = L["Markierung der Questgeber entfernt."],
    itemHint = L["Strg-Klick: Anprobe. Shift-Klick: in den Chat."],
    xpLine = L["EP: %s"],
    xpLog = L["laut Questlog"],
    xpSeen = L["gesehen bei Level %d"],
    xpScaled = L["geschätzt, gesehen bei Level %d"],
    xpOther = L["gesehen bei Level %d, Questlevel unbekannt"],
    xpNone = L["EP: noch nicht gesehen"],
}
local ART_W, ART_H = 590, 48
-- the run planner (F-139)
local RTEXT = {
    row = L["Dein Lauf"],
    rowSub = L["%d offen · %d Halte"],
    info = L["%d offene Quests · %d Halte vor dem Lauf"],
    sum = L["Lauf: %s EP · %d Upgrades"],
    sumNoXP = L["Lauf: %d Upgrades"],
    atLeast = L["mind. %s"],
    tipTitle = L["Dieser Lauf"],
    tipNow = L["Jetzt: Stufe %d, %d %%"],
    tipAfter = L["Nach dem Lauf: Stufe %d, %d %%"],
    tipAfterAbout = L["Nach dem Lauf: etwa Stufe %d, %d %%"],
    tipMissing = L["Quests ohne bekannte EP zählen nicht: %d"],
    tipUps = L["Upgrades: %d (Quest-Belohnungen und Bosse)"],
    tipCap = L["Höchststufe: es zählen nur Upgrades."],
    tipAfterCap = L["Nach dem Lauf: Höchststufe %d"],
    noQuests = L["Keine offenen Quests in diesem Dungeon."],
    pending = L["im Log, Ziel noch offen: %s"],
    before = L["Vor dem Lauf"],
    inside = L["Im Dungeon"],
    after = L["Nach dem Lauf abgeben"],
    accept = L["%d. %s: annehmen %s"],
    turnIn = L["%d. %s: abgeben %s"],
    later = L["ab Stufe %d: %s"],
    unknown = L["Ort unbekannt: %s"],
    nothingBefore = L["Nichts abzuholen: alles Nötige ist im Log."],
    nothingAfter = L["Keine Abgabe mit bekanntem Ort."],
    goals = L["Ziel: %s"],
    starts = L["startet: %s"],
    ups = L["Upgrades für dich: %d"],
    other = L["Sonst im Dungeon: %s"],
    noBosses = L["Für diesen Dungeon kennt Amisia keine Bosse."],
    route = L["Route: Halt %d/%d auf der Karte"],
    noRoute = L["Route: kein Halt"],
    routeTip = L["Setzt den Wegpunkt auf einen Halt vor dem Lauf und öffnet die Weltkarte dort (nicht in Instanzen und im Kampf). Jeder Klick: der nächste Halt."],
    hint = L["Vor dem Lauf: die Halte nach Zonen, deine Zone zuerst. Im Dungeon: die Bosse in der Reihenfolge des Spiels mit den Quests dort. Karte: Weltkarte und Wegpunkt (nicht in Instanzen und im Kampf)."],
    plan = L["Lauf planen"],
    planTip = L["Was dieser Dungeon dir bringt, was du vorher abholst, was bei welchem Boss passiert und wo du danach abgibst."],
    worthTip = L["Lohn: %s"],
    worthPct = L["%d %% einer Stufe"],
    worthUp = L["ein Upgrade"],
    worthNoXP = L["EP unbekannt"],
    worthCost = L["Aufwand: %d offene Schritte, %d Zonen draußen"],
}
local VERDICT = { must = GREEN .. L["Muss"] .. "|r", worth = "|cffa6e28f" .. L["Lohnt"] .. "|r", skip = GREY .. L["Kann weg"] .. "|r",
    later = T.ORANGE .. L["Später"] .. "|r", unknown = GREY .. "?|r" }
local VERDICT_BAR = { must = { 0.31, 0.82, 0.42 }, worth = { 0.65, 0.89, 0.56 }, skip = { 0.5, 0.5, 0.5 }, later = { 0.88, 0.64, 0.27 },
    unknown = { 0.5, 0.5, 0.5 } }

local function signed(x) return ("%+d"):format(math.floor(x + 0.5)) end

-- The dungeon list in the chosen order: "level" as the planner gives it, "value" the ranking first
-- (then the rest by level), "chain" the chain's dungeons in its order (then the rest). Rows of the
-- ranking and the chain carry their place (e.rank) and, for the chain, the chain's value.
local function orderedDungeons(list, sort)
    if sort ~= "value" and sort ~= "chain" then return list, nil end
    local c = cached()
    c.dorder = c.dorder or {}
    local key = sort .. tostring(list)
    if c.dorder[key] then return c.dorder[key][1], c.dorder[key][2] end
    local top, chain, why = {}, nil, nil
    if sort == "value" then
        for i, e in ipairs(ns.DungeonRanking()) do top[#top + 1] = { e = e, rank = i, value = e.value } end
    else
        chain, why = ns.DungeonChain()
        for i, st in ipairs(chain) do top[#top + 1] = { e = st.entry, rank = i, value = st.value } end
    end
    local out, seen = {}, {}
    for _, t in ipairs(top) do
        out[#out + 1] = setmetatable({ rank = t.rank, chainValue = sort == "chain" and t.value or nil }, { __index = t.e })
        seen[t.e] = true
    end
    for _, e in ipairs(list) do
        if not seen[e] then out[#out + 1] = e end
    end
    c.dorder[key] = { out, { chain = chain, why = why } }
    return out, c.dorder[key][2]
end

-- The chosen dungeon: the saved one while the list has it, one out of reach that ns.ShowDungeon
-- asked for, else the recommended, else the first.
local asked
local function chosenDungeon(list, nextE)
    local key = state().dungeon
    for _, e in ipairs(list) do
        if e.key == key then return e end
    end
    if key and key == asked then
        local e = ns.DungeonInfo(key)
        if e then return e end
    end
    return nextE or list[1]
end

local function fillDungeonRow(r, e)
    local raid = e.kind == "raid" and (" (Raid%s)"):format(e.size and (" " .. e.size) or "") or ""
    local dim = e.fit == "high" or e.fit == "easy" or e.fit == "later"
    r.name:SetText((e.rank and (e.rank .. ". ") or "") .. e.name .. raid)
    if dim then r.name:SetTextColor(0.56, 0.53, 0.64) else r.name:SetTextColor(1, 1, 1) end
    r.level:SetText(ns.Dungeons.RangeText(e))
    r.fit:SetText(ns.Dungeons.FitText(e))
    if e.fit == "fit" then r.fit:SetTextColor(0.31, 0.82, 0.42)
    elseif e.fit == "soon" then r.fit:SetTextColor(1, 0.82, 0)
    else r.fit:SetTextColor(0.56, 0.53, 0.64) end
    if e.computed then
        r.upgrades:SetText(tostring(e.upgrades))
        r.run:SetText(e.perRun > 0 and signed(e.perRun) or "0")
        r.quests:SetText(e.once > 0 and signed(e.once) or "0")
        r.value:SetText(tostring(math.floor((e.chainValue or e.value) + 0.5)))
    else
        r.upgrades:SetText(""); r.run:SetText(""); r.quests:SetText(""); r.value:SetText("")
    end
    if r.owner and r.owner.chosen == e.key then r.sel:Show() else r.sel:Hide() end
end

local function dungeonTip(self)
    local e = self.item
    if not e then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(e.name, 1, 0.82, 0)
    local range = ns.Dungeons.RangeText(e)
    if range ~= "" then
        GameTooltip:AddLine(("Level %s%s"):format(range, e.est and L[", geschätzt aus den Items"] or ""), 0.85, 0.85, 0.85)
    end
    if e.kind == "raid" then
        GameTooltip:AddLine(("Raid%s%s"):format(e.size and L[" für %s"]:format(e.size) or "", e.fit == "later" and (", " .. ns.Dungeons.FitText(e)) or ""),
            0.85, 0.85, 0.85)
    end
    if e.computed then
        GameTooltip:AddLine(L["%d Upgrades, je Lauf %s, Quests %s, Wert %d"]:format(e.upgrades, signed(e.perRun), signed(e.once),
            math.floor(e.value + 0.5)), 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

-- The rows of the chosen dungeon: a row per boss with its items below it.
local function detailItems(e)
    local c = cached()
    c.detail = c.detail or {}
    local out = c.detail[e]
    if out then return out end
    out = {}
    for _, b in ipairs(e.bosses or {}) do
        out[#out + 1] = { kind = "boss", text = b.name, b = b }
        for _, it in ipairs(b.items) do
            out[#out + 1] = { kind = "item", id = it.id, it = it, rec = it.rec, wished = it.wished, owned = it.owned }
        end
    end
    c.detail[e] = out
    return out
end

-- The quest rows of a dungeon: one row per quest with its quest path (the pre-quests and rewards
-- show in the quest path). list, status as ns.DungeonQuests gives them.
local function questItems(key)
    local c = cached()
    c.qdetail = c.qdetail or {}
    local list, status = ns.DungeonQuests(key)
    local kept = c.qdetail[key]
    if kept and kept.list == list then return kept.out, status end
    local out = {}
    for _, q in ipairs(list) do
        out[#out + 1] = { kind = "quest", text = q.title .. (q.done and L[" (erledigt)"] or q.gone and L[" (nicht mehr möglich)"] or ""),
            q = q, qid = q.qid, path = ns.Dungeons.QuestPath(q, key) }
    end
    c.qdetail[key] = { list = list, out = out }
    return out, status
end

-- The dungeon mark of the world map in front of a start inside the dungeon (the user's wish: a quest
-- that starts in the dungeon shows the dungeon symbol)
local DUNGEON_MARK = "|A:Dungeon:14:14|a "
local function startText(q)
    local where = ns.Dungeons.QuestStartText(q)
    if q.start == "I" and where ~= "" then return DUNGEON_MARK .. where end
    return where
end

local STATE_TEXT = { done = L["erledigt"], active = L["im Log"], ready = L["im Log, fertig"], gone = L["nicht mehr möglich"],
    locked = L["noch nicht annehmbar"] }
-- the state shown as text in the row (open and locked show only the mark there)
local ROW_STATE = { done = true, active = true, ready = true, gone = true }
local function questState(n) return ns.Dungeons.QuestState(n) end

-- The level text of a quest in the quest log's colours (simplified): red when it cannot be taken yet
-- or is five levels above, orange three above, yellow around the own level, green below, grey far below.
local function questLevelText(q)
    local text = ns.Dungeons.QuestLevelText(q)
    if text == "" then return "" end
    local my = tonumber(UnitLevel("player")) or 1
    local lv = (q.level or 0) > 0 and q.level or (q.minLevel or 0)
    local c
    if (q.minLevel or 0) > my or lv - my >= 5 then c = "|cffff2020"
    elseif lv - my >= 3 then c = "|cffff8040"
    elseif lv - my >= -2 then c = "|cffffff00"
    elseif lv - my >= -5 then c = "|cff40c040"
    else c = GREY end
    return c .. text .. "|r"
end

-- The cells of a detail row: a quest row makes room for the quest path's progress ("Weg 2/4").
local CELLS = {
    quest = { name = { 4, 178 }, slot = { 186, 48 }, way = { 236, 58 }, gain = { 298, 34 }, xp = { 336, 56 }, rate = { 398, 188 } },
    other = { name = { 4, 220 }, slot = { 228, 62 }, way = { 236, 58 }, gain = { 292, 40 }, xp = { 336, 56 }, rate = { 398, 188 } },
}
local function placeCells(r, kind)
    kind = kind == "quest" and "quest" or "other"
    if r.cellKind == kind then return end
    r.cellKind = kind
    for key, c in pairs(CELLS[kind]) do
        r[key]:ClearAllPoints()
        r[key]:SetPoint("LEFT", c[1], 0)
        r[key]:SetWidth(c[2])
    end
end

local function fillDetailRow(r, e)
    placeCells(r, e.kind)
    r.xp:SetText("")
    r.way:SetText("")
    if e.kind == "boss" then
        r.name:SetText(GOLD_TEXT .. e.text .. "|r")
        r.slot:SetText("")
        r.gain:SetText("")
        if e.b.tentative then
            -- an NPC only the guild's records know: listed, counted from its third kill
            local k = e.b.kills or 0
            r.rate:SetText(GREY .. L["%d %s, zählt ab 3"]:format(k, k == 1 and "Kill" or "Kills") .. "|r")
        else
            r.rate:SetText(e.b.perRun > 0 and L["je Lauf %s"]:format(signed(e.b.perRun)) or "")
        end
    elseif e.kind == "item" then
        local it = e.it
        r.name:SetText(marks(it) .. itemText(it.id))
        r.slot:SetText(ns.BIS_SLOT_NAME[it.slotKey] or "")
        r.gain:SetText(gainText(it))
        r.rate:SetText(it.rate or "")
    elseif e.kind == "reward" then
        local it = e.it
        r.name:SetText("      " .. marks(it) .. itemText(it.id))
        r.slot:SetText(ns.BIS_SLOT_NAME[it.slotKey] or "")
        r.gain:SetText(gainText(it))
        r.rate:SetText(it.upgrade and (GREEN .. "Upgrade|r") or "")
    else
        -- a quest: state, title, level, the quest path's progress, where it starts
        local q = e.q
        local st = questState(q)
        local icon = ns.Dungeons.QuestStateIcon(st) .. " "
        local title = GOLD_TEXT .. e.text .. "|r"
        local over = q.done or q.gone
        r.name:SetText(icon .. ((over and (GREY .. e.text .. "|r")) or title))
        r.slot:SetText(questLevelText(q))
        local way = ns.Dungeons.QuestPathShort(e.path)
        r.way:SetText(way ~= "" and L["Weg %s"]:format(way) or "")
        r.gain:SetText(q.best and ((over and GREY or GREEN) .. signed(q.best.gain) .. "|r") or "")
        local where = startText(q)
        r.rate:SetText((ROW_STATE[st] and (GREY .. STATE_TEXT[st] .. "|r" .. (where ~= "" and " · " or "")) or "") .. where)
        local xp = ns.Dungeons.XPText(ns.Dungeons.QuestXP(q))
        r.xp:SetText(over and xp ~= "" and (GREY .. xp .. "|r") or xp)
    end
end

-- The tooltip of a quest row: title, level, state, where it starts, the chain, a hint on the click.
local function questTip(self)
    local e = self.item
    if not e or not e.q then return end
    local q = e.q
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(q.title, 1, 0.82, 0)
    local lv = ns.Dungeons.QuestLevelText(q)
    if lv ~= "" then GameTooltip:AddLine(L["Level %s"]:format(lv), 0.85, 0.85, 0.85) end
    local st = questState(q)
    GameTooltip:AddLine(ns.Dungeons.QuestStateIcon(st) .. " " .. (STATE_TEXT[st] or L["offen"]), 0.85, 0.85, 0.85)
    local where = ns.Dungeons.QuestStartText(q)
    if where ~= "" then GameTooltip:AddLine(L["Start: %s"]:format(where), 0.85, 0.85, 0.85, true) end
    local value, how, seen = ns.Dungeons.QuestXP(q)
    if value then
        local from = how == "log" and DTEXT.xpLog or how == "scaled" and DTEXT.xpScaled:format(seen)
            or how == "other" and DTEXT.xpOther:format(seen) or DTEXT.xpSeen:format(seen or 0)
        GameTooltip:AddDoubleLine(DTEXT.xpLine:format(ns.Dungeons.XPText(value, how, seen)), from, 0.85, 0.85, 0.85, 0.6, 0.6, 0.6)
    else
        GameTooltip:AddLine(DTEXT.xpNone, 0.6, 0.6, 0.6)
    end
    local path = e.path
    if path and path.total > 1 then
        GameTooltip:AddLine(L["Weg: %d von %d Schritten erledigt"]:format(path.done, path.total), 0.85, 0.85, 0.85)
    end
    if path and path.next and not q.done and not q.gone then
        GameTooltip:AddLine(L["Nächster Schritt: %s"]:format(ns.Dungeons.QuestPathNextText(path)), 0.85, 0.85, 0.85, true)
    end
    if #(q.rewards or {}) > 0 then
        local names = {}
        for i, it in ipairs(q.rewards) do
            if i > 4 then break end
            names[#names + 1] = itemText(it.id) .. (it.upgrade and (" " .. GREEN .. signed(it.gain) .. "|r") or "")
        end
        GameTooltip:AddLine(L["Belohnung: %s"]:format(table.concat(names, ", ")), 0.85, 0.85, 0.85, true)
    end
    -- the worth (F-139): what it brings, what it costs
    local w = self.journal and e.worth or nil
    if w then
        local gains = {}
        if w.pct then gains[#gains + 1] = RTEXT.worthPct:format(math.floor(w.pct + 0.5))
        elseif not q.best then gains[#gains + 1] = RTEXT.worthNoXP end
        if q.best then gains[#gains + 1] = RTEXT.worthUp end
        GameTooltip:AddDoubleLine(RTEXT.worthTip:format(table.concat(gains, " + ")), VERDICT[w.verdict] or "", 0.85, 0.85, 0.85, 1, 1, 1)
        GameTooltip:AddLine(RTEXT.worthCost:format(w.steps, w.zones), 0.6, 0.6, 0.6)
    end
    if not self.journal then GameTooltip:AddLine(L["Klick: der Questweg mit allen Schritten"], 0.31, 0.82, 0.42) end
    GameTooltip:Show()
end

-- The boss model of the image: the NPC's creature where the client has a model frame for it.
local function setModelNpc(a, npc)
    local m = a.model
    if not npc or not m or type(m.SetCreature) ~= "function" then
        a.npc = nil
        if m then m:Hide() end
        return
    end
    m:Show()
    if a.npc ~= npc then
        if not pcall(m.SetCreature, m, npc) then
            a.npc = nil
            m:Hide()
            return
        end
        if m.SetPortraitZoom then pcall(m.SetPortraitZoom, m, 0.7) end
        a.npc = npc
    end
end

-- The header image of the chosen dungeon: the middle of the client's loading screen, darkened to the
-- left, the name and level on it, the boss model and the mark button to the right.
local function buildArt(B, top)
    local a = CreateFrame("Frame", nil, B)
    a:SetPoint("TOPLEFT", 0, top)
    a:SetPoint("TOPRIGHT", -12, top)
    a:SetHeight(ART_H)
    a.tex = a:CreateTexture(nil, "BACKGROUND")
    a.tex:SetAllPoints()
    a.shade = a:CreateTexture(nil, "BORDER")
    a.shade:SetAllPoints()
    a.shade:SetColorTexture(0, 0, 0, 1)
    if a.shade.SetGradient and CreateColor then
        a.shade:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0.85), CreateColor(0, 0, 0, 0.1))
    else
        a.shade:SetAlpha(0.45)
    end
    a.edges = W.Border(a, W.GOLD[1], W.GOLD[2], W.GOLD[3], 0.7)
    a.title = W.Text(a, T.FONT.big, 330)
    a.title:SetPoint("TOPLEFT", 10, -7)
    a.info = W.Text(a, T.FONT.text, 330)
    a.info:SetPoint("BOTTOMLEFT", 10, 7)
    a.model = CreateFrame("PlayerModel", nil, a)
    a.model:SetSize(ART_H - 4, ART_H - 4)
    a.model:SetPoint("RIGHT", -2, 0)
    a.model:Hide()
    a.SetModelNpc = setModelNpc
    return a
end

-- The list of the chosen dungeon's or raid's rows on page B (rows high): bosses with their items, or
-- quests; clicks, menus, tooltips, the hovered boss in B.art.
local function buildDetail(B, rows)
    return W.List(B, rows, ROW_H, function(r)
        r.name = col(r, 4, 220, nil, T.FONT.text)
        r.slot = col(r, 228, 62, nil, T.FONT.text)
        r.gain = col(r, 292, 40, nil, T.FONT.text)
        r.gain:SetJustifyH("RIGHT")
        r.xp = col(r, 336, 56, nil, T.FONT.text)
        r.xp:SetJustifyH("RIGHT")
        r.rate = col(r, 398, 188, nil, T.FONT.text)
        r.way = col(r, 236, 58, nil, T.FONT.text)
        r.way:SetJustifyH("RIGHT")
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetScript("OnClick", function(self, button)
            local e = self.item
            if not e then return end
            if e.kind == "quest" and button ~= "RightButton" then
                -- the quest path in place of the list (F-135)
                if B.OpenPath then B:OpenPath(e) end
                return
            end
            if not e.id then return end
            if button == "RightButton" then
                if e.kind == "item" then W.Menu(self, menuEntries(e, ns.BisOpts())) end
                return
            end
            modifiedClick(e.id)
        end)
        r:SetScript("OnEnter", function(self)
            local e = self.item
            if e and e.q then
                questTip(self)
            elseif e and e.id then
                itemTooltip(self, e.id)
                GameTooltip:AddLine(DTEXT.itemHint, 0.6, 0.6, 0.6)
                GameTooltip:Show()
            elseif e and e.kind == "boss" then
                -- the hovered boss in the image
                B.art:SetModelNpc(ns.Dungeons.ModelNpc(B.entry, e.b))
            end
        end)
        r:SetScript("OnLeave", function(self)
            hideTip()
            local e = self.item
            if e and e.kind == "boss" then B.art:SetModelNpc(ns.Dungeons.ModelNpc(B.entry)) end
        end)
    end, fillDetailRow)
end

---------------------------------------------------------------------------
-- The quest path (F-135): a dungeon quest's steps from the first pre-quest to the quest
---------------------------------------------------------------------------

local LABEL = T.LABEL
local PTEXT = {
    back = L["< Zurück zu den Dungeons"],
    map = L["Nächsten Schritt auf der Karte"],
    mapTip = L["Öffnet die Weltkarte beim Ort des nächsten offenen Schritts und setzt den Wegpunkt. In Instanzen und im Kampf setzt Amisia nur ihr eigenes Ziel."],
    card = L["Karte"],
    cardTip = L["Öffnet die Weltkarte dort und setzt den Wegpunkt (nicht in Instanzen und im Kampf)."],
    accept = L["Annehmen:"],
    turnIn = L["Abgeben:"],
    needs = L["Voraussetzung:"],
    goal = L["Ziel:"],
    spots = L["Fundorte:"],
    spotsSource = L["nach Berichten von Spielern, von Amisia nicht selbst gesehen"],
    after = L["danach"],
    stepOf = L["Schritt %d von %d"],
    optional = L["optional"],
    crumb = L["optional: nur Hinweis auf die nächste Quest"],
    alsoOk = L["eine davon reicht · auch möglich: %s"],
    noLonger = L["eine davon reicht · nicht mehr nötig: %s"],
    goneBy = L["nicht mehr möglich, weil %s erledigt ist"],
    gone = L["nicht mehr möglich"],
    level = L["Stufe %s"],
    progress = L["Weg: %d von %d Schritten erledigt"],
    nextStep = L["Nächster Schritt:"],
    rewards = L["Belohnung:"],
    path = L["Questweg:"],
    count = L["Quests: %d, offen: %d"],
    cut = L["(%d frühere Schritte nicht gezeigt)"],
    hint = L["Links die Quests des Dungeons, rechts die gewählte. Karte: Weltkarte und Wegpunkt zu diesem Schritt (nicht in Instanzen und im Kampf). Strg-Klick auf eine Belohnung: Anprobe."],
    best = L["beste Wahl"],
    instead = L["statt %s"],
    empty = L["Platz leer"],
    doneFold = L["Schritte %d-%d erledigt · Klick: zeigen"],
    doneOpen = L["Schritte %d-%d erledigt · Klick: einklappen"],
    lvlRange = L["ab %d · grau ab %d (noch %d)"],
    lvlLow = L["ab Stufe %d, du bist %d"],
    lvlGrey = L["schon grau: wenig EP"],
}
local P = {
    PAD = 8, ICON = 16, TEXT_X = 30, LINE = 12, LINE_GAP = 3, HEAD_H = 26, AFTER_H = 22, BUTTON_H = T.ROW_BUTTON_H,
}
local J = T.DJOURNAL

-- How many lines a wrapped font string takes at width w (the client's height where it knows it).
local function textHeight(fs, w)
    local full = fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth() or 0
    local lines = math.max(1, math.ceil(full / math.max(1, w)))
    return math.max(fs:GetStringHeight() or 0, lines * P.LINE)
end

-- One field of a step card: a gold label over its text (wrapped) and a red button "Karte" at the
-- label's right.
local function cardLine(c, onMap)
    local ln = {}
    ln.label = W.Text(c, T.FONT.text, 100)
    ln.label:SetTextColor(W.GOLD[1], W.GOLD[2], W.GOLD[3])
    ln.value = W.Text(c, T.FONT.text, 100, true)
    ln.value:SetJustifyV("TOP")
    ln.btn = W.Button(c, PTEXT.card, nil, function(self) onMap(self.what, self.qid) end, { height = P.BUTTON_H })
    ln.btn:SetHeight(P.BUTTON_H)
    W.FitChip(ln.btn)
    W.Tooltip(ln.btn, PTEXT.card, PTEXT.cardTip)
    return ln
end

local function newCard(parent, onMap)
    local c = W.Inset(parent)
    c.ground = c.fill(0, 0, 0, 0.25)
    -- the next step: the glow of a chosen recipe
    c.glow = c:CreateTexture(nil, "ARTWORK")
    c.glow:SetAllPoints()
    if W.HasAtlas("Professions_Recipe_Active") then c.glow:SetAtlas("Professions_Recipe_Active") else c.glow:SetColorTexture(W.GOLD[1], W.GOLD[2], W.GOLD[3], 0.15) end
    c.glow:Hide()
    c.icon = c:CreateTexture(nil, "OVERLAY")
    c.icon:SetSize(P.ICON, P.ICON)
    c.icon:SetPoint("TOPLEFT", P.PAD, -6)
    c.title = W.Text(c, T.FONT.title, 300)
    c.title:SetPoint("TOPLEFT", P.TEXT_X, -8)
    c.step = W.Text(c, T.FONT.hint)
    c.step:SetJustifyH("RIGHT")
    c.step:SetPoint("TOPRIGHT", -P.PAD, -9)
    c.lines = {}
    for i = 1, 6 do c.lines[i] = cardLine(c, onMap) end
    -- "danach" under the card: a line down to the next card, the arrow head, the word
    c.link = c:CreateTexture(nil, "BACKGROUND")
    c.link:SetColorTexture(0.55, 0.5, 0.42, 0.8)
    c.link:SetWidth(2)
    c.arrow = c:CreateTexture(nil, "ARTWORK")
    c.arrow:SetSize(12, 12)
    c.after = W.Text(c, T.FONT.hint)
    c.after:SetText(PTEXT.after)
    return c
end

-- Fills field ln of card c at y: the label (none for a line of marks), under it the text, the map
-- button for (what, qid) at the label's right when a place is known. Returns the y under the field.
local function fillLine(c, ln, y, label, value, what, qid, width)
    ln.label:ClearAllPoints()
    ln.value:ClearAllPoints()
    ln.btn:ClearAllPoints()
    local x = P.TEXT_X
    local right = P.PAD + (what and (ln.btn:GetWidth() + 6) or 0)
    local w = width - x - right
    local top = y
    if label then
        ln.label:SetWidth(w)
        ln.label:SetText(label)
        ln.label:SetPoint("TOPLEFT", x, y - 1)
        ln.label:Show()
        top = y - P.LINE - 1
    else
        ln.label:SetText("")
        ln.label:Hide()
    end
    ln.value:SetWidth(w)
    ln.value:SetText(value)
    ln.value:SetPoint("TOPLEFT", x, top - 1)
    ln.value:Show()
    local h = (y - top) + textHeight(ln.value, w)
    if what then
        ln.btn.what, ln.btn.qid = what, qid
        ln.btn:SetPoint("TOPRIGHT", -P.PAD, y + 3)
        ln.btn:Show()
        h = math.max(h, P.BUTTON_H - 4)
    else
        ln.btn:Hide()
    end
    return y - h - P.LINE_GAP
end

local STEP_TEXT = { done = GREY, gone = GREY }

-- Fills card c with step s of path; width: the card's width. Returns the card's height. A done
-- step folds to its head; a step no longer possible keeps only why.
local function fillCard(c, s, path, width, isNext)
    local Dn = ns.Dungeons
    local n = s.node
    local st = s.state
    local tex, shade = Dn.QuestStateArt(st)
    c.icon:SetTexture(tex)
    c.icon:SetVertexColor(shade, shade, shade)
    local over = st == "done" or st == "gone"
    c.step:SetText(s.reqNo and PTEXT.stepOf:format(s.reqNo, path.total) or PTEXT.optional)
    c.title:SetWidth(math.max(60, width - P.TEXT_X - P.PAD - c.step:GetStringWidth() - 10))
    c.title:SetText((STEP_TEXT[st] or "") .. s.no .. ". " .. n.title .. (STEP_TEXT[st] and "|r" or ""))
    c.glow:SetShown(isNext and true or false)
    c:SetAlpha(over and 0.65 or 1)
    local y = -P.HEAD_H
    local used = 0
    local function line(label, value, what)
        used = used + 1
        y = fillLine(c, c.lines[used], y, label, value, what, n.qid, width)
    end
    if not over then
        local a = s.accept
        local acceptText = a.kind == "inside" and (DUNGEON_MARK .. a.text) or a.text
        line(PTEXT.accept, acceptText, a.point and "accept" or nil)
        -- where in the dungeon the start item can lie (hand-kept hints, D-65)
        if s.spots then
            local rows = {}
            for i, t in ipairs(s.spots) do rows[i] = "· " .. t end
            rows[#rows + 1] = GREY .. PTEXT.spotsSource .. "|r"
            line(PTEXT.spots, table.concat(rows, "\n"))
        end
        line(PTEXT.turnIn, s.turnIn.text, s.turnIn.point and "turnin" or nil)
        if s.needs then line(PTEXT.needs, s.needs) end
        if s.objective then line(PTEXT.goal, s.objective) end
    end
    -- the marks: one of several, a breadcrumb, no longer possible
    local flags = {}
    if s.gone then flags[#flags + 1] = s.goneBy and PTEXT.goneBy:format(s.goneBy) or PTEXT.gone end
    if s.one and not over then flags[#flags + 1] = (s.oneDone and PTEXT.noLonger or PTEXT.alsoOk):format(table.concat(s.others, ", ")) end
    if not over then
        if s.breadcrumb then flags[#flags + 1] = PTEXT.crumb elseif s.optional then flags[#flags + 1] = PTEXT.optional end
    end
    if #flags > 0 then line(nil, T.ORANGE .. table.concat(flags, " · ") .. "|r") end
    for i = used + 1, #c.lines do
        local ln = c.lines[i]
        ln.label:Hide(); ln.value:Hide(); ln.btn:Hide()
    end
    local h = -y + P.PAD - P.LINE_GAP
    c:SetHeight(h)
    return h
end

---------------------------------------------------------------------------
-- The quest journal (F-138): the dungeon's quests on the left, the chosen one on the right
---------------------------------------------------------------------------

-- The colour of a state word in the list: in the log yellow, ready green, over grey.
local STATE_COLOR = { active = "|cffffd100", ready = GREEN, done = GREY, gone = GREY }

-- A card of the quest list: the state mark, the title and the state word; under them level, path
-- and the start mark, the upgrade's gain at the right.
local function buildQuestCard(V)
    return function(r)
        r.sel = W.SelectBar(r)
        r.mark = r:CreateTexture(nil, "OVERLAY")
        r.mark:SetSize(J.MARK, J.MARK)
        r.mark:SetPoint("TOPLEFT", J.MARK_X, J.MARK_Y)
        r.title = W.Text(r, T.FONT.title, J.LIST_W - J.TEXT_X - J.RIGHT_PAD)
        r.title:SetPoint("TOPLEFT", J.TEXT_X, J.LINE1_Y)
        r.state = W.Text(r, T.FONT.text)
        r.state:SetJustifyH("RIGHT")
        r.state:SetPoint("TOPRIGHT", -J.RIGHT_PAD, J.LINE1_Y - 1)
        r.sub = W.Text(r, T.FONT.text, J.LIST_W - J.TEXT_X - J.RIGHT_PAD)
        r.sub:SetPoint("TOPLEFT", J.TEXT_X, J.LINE2_Y)
        r.gain = W.Text(r, T.FONT.text)
        r.gain:SetJustifyH("RIGHT")
        r.gain:SetPoint("TOPRIGHT", -J.RIGHT_PAD, J.LINE2_Y)
        -- the worth against the dungeon's best quest (F-139)
        r.worth = r:CreateTexture(nil, "ARTWORK")
        r.worth:SetHeight(J.WORTH_H)
        r.worth:SetPoint("BOTTOMLEFT", J.TEXT_X, J.WORTH_Y)
        r:SetScript("OnClick", function(self)
            if self.item and V.owner then V.owner:OpenPath(self.item) end
        end)
        r.journal = true
        r:SetScript("OnEnter", questTip)
        r:SetScript("OnLeave", hideTip)
    end
end

-- The first card of the list: the run planner (F-139).
local function fillRunCard(r, e)
    if W.HasAtlas("Dungeon") then r.mark:SetAtlas("Dungeon") else r.mark:SetTexture(ICON) end
    r.mark:SetVertexColor(1, 1, 1)
    r.state:SetText("")
    local room = J.LIST_W - J.TEXT_X - J.RIGHT_PAD
    r.title:SetWidth(room)
    r.title:SetText(GOLD_TEXT .. RTEXT.row .. "|r")
    r.sub:SetWidth(room)
    r.sub:SetText(RTEXT.rowSub:format(e.plan.open, #e.plan.route))
    r.gain:SetText("")
    r.worth:Hide()
    local chosen = r.owner and r.owner.chosenQuest
    r.sel:SetShown(chosen == "run")
end

local function fillQuestCard(r, e)
    if e.kind == "run" then return fillRunCard(r, e) end
    local q = e.q
    local st = questState(q)
    local tex, shade = ns.Dungeons.QuestStateArt(st)
    r.mark:SetTexture(tex)
    r.mark:SetTexCoord(0, 1, 0, 1)
    r.mark:SetVertexColor(shade, shade, shade)
    local over = q.done or q.gone
    local word = STATE_COLOR[st] and (STATE_COLOR[st] .. STATE_TEXT[st] .. "|r") or ""
    r.state:SetText(word)
    local room = J.LIST_W - J.TEXT_X - J.RIGHT_PAD
    r.title:SetWidth(room - (word ~= "" and (r.state:GetStringWidth() + 6) or 0))
    r.title:SetText(over and (GREY .. q.title .. "|r") or q.title)
    local parts = {}
    local lv = questLevelText(q)
    if lv ~= "" then parts[#parts + 1] = PTEXT.level:format(lv) end
    local way = ns.Dungeons.QuestPathShort(e.path)
    if way ~= "" then parts[#parts + 1] = L["Weg %s"]:format(way) end
    if q.best and not over then parts[#parts + 1] = GREEN .. signed(q.best.gain) .. "|r" end
    local sub = table.concat(parts, " · ")
    if q.start == "I" then sub = sub .. (sub ~= "" and " " or "") .. "|A:Dungeon:14:14|a" end
    r.sub:SetText(over and (GREY .. sub .. "|r") or sub)
    -- the worth: its word at the right, a thin bar against the dungeon's best quest (F-139)
    local w = e.worth
    r.gain:SetText(w and VERDICT[w.verdict] or "")
    r.sub:SetWidth(room - (r.gain:GetText() ~= "" and (r.gain:GetStringWidth() + 6) or 0))
    if w and (e.worthMax or 0) > 0 and w.score > 0 then
        local c = VERDICT_BAR[w.verdict] or VERDICT_BAR.skip
        r.worth:SetColorTexture(c[1], c[2], c[3], 0.8)
        r.worth:SetWidth(math.max(2, room * math.min(1, w.score / e.worthMax)))
        r.worth:Show()
    else
        r.worth:Hide()
    end
    local chosen = r.owner and r.owner.chosenQuest
    r.sel:SetShown(chosen ~= nil and (e.qid or q.title) == chosen)
end

-- The view: its row ("< Zurück zu den Dungeons", "Nächsten Schritt auf der Karte"), the dungeon's
-- image, the quest list and the chosen quest's inset (its body scrolls).
local function buildPath(B)
    local V = W.Page(B, { view = true, top = -(T.LAYOUT.ROW_H + T.LAYOUT.GAP) })
    V.owner = B
    V:Bands({ "row" })
    V.back = W.Button(V, PTEXT.back, nil, function() B:OpenPath(nil) end)
    W.FitChip(V.back)
    V.map = W.Button(V, PTEXT.map, nil, function()
        if V.plan then
            -- the run planner: the route's stops one after the other (F-139)
            local route = V.plan.route
            if #route == 0 then return end
            local at = math.min(V.routeAt or 1, #route)
            say(ns.DungeonRouteWaypoint(route[at]))
            V.routeAt = at % #route + 1
            V.map:SetText(RTEXT.route:format(V.routeAt, #route))
            W.FitChip(V.map)
        elseif V.path then
            say(ns.DungeonPathWaypoint(V.path))
        end
    end)
    W.FitChip(V.map)
    local hook = (V.map.styled or V.map.arrow) and V.map.HookScript or V.map.SetScript
    hook(V.map, "OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local title = PTEXT.map
        if V.plan then title = #V.plan.route > 0 and RTEXT.route:format(V.routeAt or 1, #V.plan.route) or RTEXT.noRoute end
        GameTooltip:AddLine(title, 1, 0.82, 0)
        GameTooltip:AddLine(V.plan and RTEXT.routeTip or PTEXT.mapTip, 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    hook(V.map, "OnLeave", hideTip)
    V:Place(1, { V.back }, { V.map })
    V.art = buildArt(V, -J.ART_Y)
    V.art.title:SetWidth(320)
    V.art.info:SetWidth(320)
    -- the run's sum in the image (F-139): the text and the XP bar left of the boss model
    local a, runX = V.art, -(ART_H + J.RUN_X)
    a.run = W.Text(a, T.FONT.text, J.RUN_W)
    a.run:SetJustifyH("RIGHT")
    a.run:SetPoint("TOPRIGHT", runX, J.RUN_Y)
    a.bar = CreateFrame("Frame", nil, a)
    a.bar:SetSize(J.RUN_W, J.BAR_H)
    a.bar:SetPoint("BOTTOMRIGHT", runX, J.BAR_Y)
    a.bar.bg = W.Flat(a.bar, J.BAR_BG[1], J.BAR_BG[2], J.BAR_BG[3], J.BAR_BG[4])
    a.bar.cur = a.bar:CreateTexture(nil, "ARTWORK")
    a.bar.cur:SetColorTexture(J.XP_COLOR[1], J.XP_COLOR[2], J.XP_COLOR[3], 1)
    a.bar.cur:SetPoint("TOPLEFT")
    a.bar.cur:SetPoint("BOTTOMLEFT")
    a.bar.gain = a.bar:CreateTexture(nil, "ARTWORK")
    a.bar.gain:SetColorTexture(J.GAIN_COLOR[1], J.GAIN_COLOR[2], J.GAIN_COLOR[3], 1)
    a.bar.gain:SetPoint("TOPLEFT", a.bar.cur, "TOPRIGHT")
    a.bar.gain:SetPoint("BOTTOMLEFT", a.bar.cur, "BOTTOMRIGHT")
    a.bar.edges = W.Border(a.bar, W.GOLD[1], W.GOLD[2], W.GOLD[3], 0.5)
    a.hot = CreateFrame("Frame", nil, a)
    a.hot:SetPoint("TOPRIGHT", runX, 0)
    a.hot:SetSize(J.RUN_W, ART_H)
    a.hot:EnableMouse(true)
    a.hot:SetScript("OnEnter", function(self) if V.runTip then V.runTip(self) end end)
    a.hot:SetScript("OnLeave", hideTip)
    V.list = V:List(J.ROWS, J.ROW_H, buildQuestCard(V), fillQuestCard, { top = -J.CONTENT_Y, width = J.LIST_W })
    for _, r in ipairs(V.list.rows) do r.owner = V end
    -- the chosen quest
    local d = W.Inset(V)
    d:SetPoint("TOPLEFT", J.DETAIL_X, -J.CONTENT_Y)
    d:SetPoint("TOPRIGHT", 0, -J.CONTENT_Y)
    d:SetHeight(J.ROWS * J.ROW_H)
    d.layoutRole = "detail"
    d.fill(0, 0, 0, 0.2)
    V.detail = d
    local inner = T.PAGE_W - J.DETAIL_X - J.TITLE_X - J.PAD
    V.mark = d:CreateTexture(nil, "ARTWORK")
    V.mark:SetSize(J.ICON, J.ICON)
    V.mark:SetPoint("TOPLEFT", J.PAD, -J.PAD)
    V.title = W.Text(d, T.FONT.big, inner)
    V.title:SetPoint("TOPLEFT", J.TITLE_X, J.TITLE_Y)
    V.info = W.Text(d, T.FONT.text, inner)
    V.info:SetPoint("TOPLEFT", J.TITLE_X, J.INFO_Y)
    V.scroll = CreateFrame("ScrollFrame", nil, d)
    V.scroll:SetPoint("TOPLEFT", J.PAD, -J.BODY_Y)
    V.scroll:SetPoint("BOTTOMRIGHT", -(J.PAD + T.SCROLL_ROOM - T.SCROLLBAR_GAP), J.PAD)
    V.bodyW = T.PAGE_W - J.DETAIL_X - 2 * J.PAD - (T.SCROLL_ROOM - T.SCROLLBAR_GAP)
    V.child = CreateFrame("Frame", nil, V.scroll)
    V.child:SetSize(V.bodyW, 10)
    V.scroll:SetScrollChild(V.child)
    W.Scroll(V.scroll, d)
    -- the next step in a box
    V.nextBox = CreateFrame("Frame", nil, V.child)
    V.nextBox.ground = W.Flat(V.nextBox, W.GOLD[1], W.GOLD[2], W.GOLD[3], 0.1, "BACKGROUND")
    V.nextBox.edges = W.Border(V.nextBox, W.GOLD[1], W.GOLD[2], W.GOLD[3], 0.45)
    V.nextLine = W.Text(V.nextBox, T.FONT.text, V.bodyW - 2 * J.BOX_PAD, true)
    V.nextLine:SetJustifyV("TOP")
    V.nextLine:SetPoint("TOPLEFT", J.BOX_PAD, -J.BOX_PAD)
    -- the level window (F-139): a bar from the minimum to the level it turns grey at, the own level marked
    V.lvl = CreateFrame("Frame", nil, V.child)
    V.lvl:SetSize(V.bodyW, J.LVL_ROW)
    V.lvl.segs = {}
    for i, c in ipairs({ J.LVL_LOW, J.LVL_OK, J.LVL_GREY }) do
        local t = V.lvl:CreateTexture(nil, "ARTWORK")
        t:SetColorTexture(c[1], c[2], c[3], c[4])
        t:SetHeight(J.LVL_H)
        V.lvl.segs[i] = t
    end
    V.lvl.me = V.lvl:CreateTexture(nil, "OVERLAY")
    V.lvl.me:SetColorTexture(1, 1, 1, 1)
    V.lvl.me:SetSize(2, J.LVL_H + 6)
    V.lvl.text = W.Text(V.lvl, T.FONT.text, V.bodyW - J.LVL_W - J.LVL_GAP)
    V.lvl.text:SetPoint("LEFT", J.LVL_W + J.LVL_GAP, 0)
    -- the done steps at the path's start as one line (F-139): a click shows or folds them
    V.showDone = {}
    V.doneLine = CreateFrame("Button", nil, V.child)
    V.doneLine:SetSize(V.bodyW, J.DONE_H)
    V.doneLine.ground = W.Flat(V.doneLine, 0, 0, 0, 0.25)
    V.doneLine.icon = V.doneLine:CreateTexture(nil, "ARTWORK")
    V.doneLine.icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    V.doneLine.icon:SetSize(P.ICON - 2, P.ICON - 2)
    V.doneLine.icon:SetPoint("LEFT", P.PAD, 0)
    V.doneLine.text = W.Text(V.doneLine, T.FONT.text, V.bodyW - P.TEXT_X - P.PAD)
    V.doneLine.text:SetPoint("LEFT", P.TEXT_X, 0)
    V.doneLine:SetScript("OnClick", function()
        local k = V.shownQuest
        if k ~= nil then V.showDone[k] = not V.showDone[k] or nil end
        ns.Refresh()
    end)
    V.doneLine:Hide()
    -- the run planner's parts in the body (pools, F-139)
    V.runLabels, V.runLines, V.runNodes = {}, {}, {}
    V.rewardLabel = W.Text(V.child, T.FONT.text)
    V.rewardLabel:SetTextColor(W.GOLD[1], W.GOLD[2], W.GOLD[3])
    V.rewardLabel:SetText(PTEXT.rewards)
    V.rewards = {}
    V.xp = W.Text(V.child, T.FONT.text, V.bodyW)
    V.pathLabel = W.Text(V.child, T.FONT.text, V.bodyW)
    V.cards = {}
    V.onMap = function(what, qid)
        if qid then say(ns.DungeonQuestWaypoint(qid, true, what, B.pathDungeon)) end
    end
    V:Hide()
    return V
end

-- The item's icon and quality (the client's, else the scan's or the gear data's).
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local function itemIcon(id)
    local f = C_Item and C_Item.GetItemIconByID
    local icon = type(f) == "function" and ns.Plain(f(id)) or nil
    return icon or (ns.Gear.ScanIcon and ns.Gear.ScanIcon(id)) or QUESTION
end
local function itemQuality(id)
    local f = C_Item and C_Item.GetItemInfo
    local q = type(f) == "function" and select(3, f(id)) or nil
    if not q and ns.Gear.Item then
        local row = ns.Gear.Item(id)
        q = row and row[5]
    end
    return tonumber(q)
end

-- A reward tile: the icon in its quality's frame, the name with the marks, under it slot and gain;
-- tooltip, Ctrl- and Shift-click as everywhere.
local function rewardButton(V, i)
    local b = V.rewards[i]
    if b then return b end
    b = W.Inset(V.child, "Button")
    b.fill(0, 0, 0, 0.3)
    b:SetHeight(J.TILE_H)
    b.frame = CreateFrame("Frame", nil, b)
    b.frame:SetSize(J.TILE_ICON, J.TILE_ICON)
    b.frame:SetPoint("LEFT", (J.TILE_H - J.TILE_ICON) / 2, 0)
    b.icon = b.frame:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.edges = W.Border(b.frame, 1, 1, 1, 1)
    b.text = W.Text(b, T.FONT.text, 100)
    b.text:SetPoint("TOPLEFT", J.TILE_TEXT_X, -5)
    b.sub = W.Text(b, T.FONT.text, 100)
    b.sub:SetPoint("TOPLEFT", J.TILE_TEXT_X, -19)
    b:SetScript("OnEnter", function(self)
        if not self.id then return end
        itemTooltip(self, self.id)
        GameTooltip:AddLine(DTEXT.itemHint, 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", hideTip)
    b:SetScript("OnClick", function(self) if self.id then modifiedClick(self.id) end end)
    V.rewards[i] = b
    return b
end

-- The item worn in a slot row, as text; false for an empty slot, nil when unknown (F-139).
local INV_OF
local function wornText(slotKey)
    if not INV_OF then
        INV_OF = {}
        for _, sl in ipairs(ns.Gear.SLOTS or {}) do INV_OF[sl.key] = sl.inv end
    end
    local inv = INV_OF[slotKey]
    if not inv or not GetInventoryItemLink then return nil end
    local id = ns.ItemID(ns.Plain(GetInventoryItemLink("player", inv)))
    return id and itemText(id) or false
end

-- The rewards as tiles, two per row (one when a name is too long), from y; returns the y under them.
-- Under the name: "beste Wahl" (the best upgrade of several), the slot, the gain and what it replaces.
local function fillRewards(V, q, y)
    local list = q.rewards or {}
    for _, b in ipairs(V.rewards) do b:Hide() end
    if #list == 0 then
        V.rewardLabel:Hide()
        return y
    end
    V.rewardLabel:ClearAllPoints()
    V.rewardLabel:SetPoint("TOPLEFT", 0, y)
    V.rewardLabel:Show()
    y = y - J.LABEL_H
    local quality = T.GOALS.QUALITY
    -- two tiles per row while every name fits half the width, else one
    local widest = 0
    for i, it in ipairs(list) do
        local b = rewardButton(V, i)
        b.id = it.id
        b.icon:SetTexture(itemIcon(it.id))
        local c = quality[itemQuality(it.id) or 1] or quality[1]
        W.SetBorderColor(b.edges, c[1], c[2], c[3], 1)
        b.text:SetText(marks(it) .. itemText(it.id))
        local parts = {}
        if #list > 1 and it == q.best then parts[#parts + 1] = GREEN .. PTEXT.best .. "|r" end
        local slot = ns.BIS_SLOT_NAME[it.slotKey] or ""
        if slot ~= "" then parts[#parts + 1] = GREY .. slot .. "|r" end
        parts[#parts + 1] = it.upgrade and (GREEN .. signed(it.gain) .. "|r") or (GREY .. signed(it.gain) .. "|r")
        local worn = it.upgrade and wornText(it.slotKey)
        if worn then parts[#parts + 1] = GREY .. PTEXT.instead:format("|r" .. worn .. GREY) .. "|r"
        elseif worn == false then parts[#parts + 1] = GREY .. PTEXT.empty .. "|r" end
        b.sub:SetText(table.concat(parts, " · "))
        local fs = b.text
        widest = math.max(widest, fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth() or 0,
            b.sub.GetUnboundedStringWidth and b.sub:GetUnboundedStringWidth() or b.sub:GetStringWidth() or 0)
    end
    local half = math.floor((V.bodyW - J.TILE_GAP) / 2)
    local cols = widest <= half - J.TILE_TEXT_X - 4 and 2 or 1
    local tileW = cols == 2 and half or V.bodyW
    for i in ipairs(list) do
        local b = V.rewards[i]
        b:SetWidth(tileW)
        b.text:SetWidth(tileW - J.TILE_TEXT_X - 4)
        b.sub:SetWidth(tileW - J.TILE_TEXT_X - 4)
        b:ClearAllPoints()
        local col0, row0 = (i - 1) % cols, math.floor((i - 1) / cols)
        b:SetPoint("TOPLEFT", col0 * (tileW + J.TILE_GAP), y - row0 * (J.TILE_H + J.TILE_GAP))
        b:Show()
    end
    local rows = math.ceil(#list / cols)
    return y - rows * (J.TILE_H + J.TILE_GAP) - J.SECTION_GAP + J.TILE_GAP
end

-- The level window of quest q at y (F-139): the bar (too low, can be taken, grey) with the own level
-- marked and the text beside it; nothing for an unknown level or a quest that is over. Returns the y
-- under it.
local function fillLevel(V, q, y)
    local lw = ns.Dungeons.LevelWindow(q)
    if q.done or q.gone or not lw.level or not lw.grey then
        V.lvl:Hide()
        return y
    end
    local from = (lw.min or 0) > 0 and lw.min or lw.level
    local lo = math.min(from, lw.my) - 1
    local hi = math.max(lw.grey, lw.my) + 1
    local function x(lv) return (lv - lo) / (hi - lo) * J.LVL_W end
    local bounds = { { lo, from }, { from, lw.grey }, { lw.grey, hi } }
    for i, t in ipairs(V.lvl.segs) do
        local a, b = bounds[i][1], bounds[i][2]
        t:ClearAllPoints()
        if b > a then
            t:SetPoint("LEFT", V.lvl, "LEFT", x(a), 0)
            t:SetWidth(math.max(1, x(b) - x(a)))
            t:Show()
        else
            t:Hide()
        end
    end
    V.lvl.me:ClearAllPoints()
    V.lvl.me:SetPoint("CENTER", V.lvl, "LEFT", x(math.min(hi, math.max(lo, lw.my))), 0)
    if lw.my < from then
        V.lvl.text:SetText(T.ORANGE .. PTEXT.lvlLow:format(from, lw.my) .. "|r")
    elseif lw.my >= lw.grey then
        V.lvl.text:SetText(GREY .. PTEXT.lvlGrey .. "|r")
    else
        V.lvl.text:SetText(PTEXT.lvlRange:format(from, lw.grey, lw.grey - lw.my))
    end
    V.lvl:ClearAllPoints()
    V.lvl:SetPoint("TOPLEFT", 0, y)
    V.lvl:Show()
    return y - J.LVL_ROW - J.SECTION_GAP
end

-- "8950" with a grouping for big numbers as the client writes them.
local function bigNumber(v)
    local f = _G.BreakUpLargeNumbers
    return type(f) == "function" and ns.Plain(f(v)) or tostring(v)
end

-- The run's sum in the image (F-139): "Lauf: +8950 EP · 3 Upgrades" and the XP bar (own XP, then the
-- open quests' XP); its tooltip names the level now and after the run. At the cap only the upgrades.
local function fillRunSum(V, plan)
    local a = V.art
    local Dn = ns.Dungeons
    local cur, max, my, capped = Dn.OwnXP()
    local xp = plan.xp
    if capped or xp.total == 0 then
        a.run:SetText(plan.ups > 0 and RTEXT.sumNoXP:format(plan.ups) or "")
        a.bar:Hide()
    else
        local num = "+" .. bigNumber(xp.total)
        if xp.missing > 0 then num = RTEXT.atLeast:format(num) end
        a.run:SetText(RTEXT.sum:format(num, plan.ups))
        local w = J.RUN_W
        local f0 = math.min(1, cur / max)
        local f1 = math.min(1, (cur + xp.total) / max)
        a.bar.cur:SetWidth(math.max(0.1, w * f0))
        a.bar.gain:SetWidth(math.max(0.1, w * (f1 - f0)))
        a.bar:Show()
    end
    V.runTip = function(owner)
        GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(RTEXT.tipTitle, 1, 0.82, 0)
        if capped then
            GameTooltip:AddLine(RTEXT.tipCap, 0.85, 0.85, 0.85, true)
        else
            GameTooltip:AddLine(RTEXT.tipNow:format(my, math.floor(cur / max * 100)), 0.85, 0.85, 0.85)
            local after = cur + xp.total
            local lv, rest = my + math.floor(after / max), after % max
            local cap = ns.Gear.Cap and ns.Gear.Cap() or 60
            local r, g = J.GAIN_COLOR[1] + 0.3, J.GAIN_COLOR[2] + 0.3
            if lv >= cap then
                GameTooltip:AddLine(RTEXT.tipAfterCap:format(cap), r, g, 1)
            else
                -- past the next level the need of this level stands in for the next one's: about
                local fmt = lv > my and RTEXT.tipAfterAbout or RTEXT.tipAfter
                GameTooltip:AddLine(fmt:format(lv, math.floor(rest / max * 100)), r, g, 1)
            end
            if xp.missing > 0 then GameTooltip:AddLine(RTEXT.tipMissing:format(xp.missing), 0.6, 0.6, 0.6) end
        end
        GameTooltip:AddLine(RTEXT.tipUps:format(plan.ups), 0.85, 0.85, 0.85)
        GameTooltip:Show()
    end
end

-- The dungeon's image in the journal: name, level and fit, how many quests and how many are open,
-- the run's sum.
local function fillJournalArt(V, e, rows, plan)
    local a = V.art
    if not e then a:Hide() return end
    a:Show()
    local Dn = ns.Dungeons
    local fid, kind = Dn.Art(e.key)
    if fid then
        a.tex:SetTexture(fid)
        a.tex:SetTexCoord(Dn.ArtCoords(kind, ART_W, ART_H))
        a.tex:Show()
    else
        a.tex:Hide()
    end
    a.title:SetText(e.name)
    local all, open = 0, 0
    for _, row in ipairs(rows) do
        if row.q then
            all = all + 1
            if not row.q.done and not row.q.gone then open = open + 1 end
        end
    end
    local range = Dn.RangeText(e)
    local parts = { range ~= "" and DTEXT.level:format(range, Dn.FitText(e)) or Dn.FitText(e), PTEXT.count:format(all, open) }
    a.info:SetText(table.concat(parts, " · "))
    a:SetModelNpc(Dn.ModelNpc(e))
    fillRunSum(V, plan)
end

-- The head of the journal: the image and the list (the chosen row marked and in view).
local function fillJournal(B, rows, plan, chosen)
    local V = B.pathView
    V.plan = nil
    fillJournalArt(V, B.entry, rows, plan)
    V.chosenQuest = chosen
    local at
    for i, row in ipairs(rows) do
        if (row.kind == "run" and chosen == "run") or (row.q and (row.qid or row.q.title) == chosen) then at = i end
    end
    if at and (at <= V.list.offset or at > V.list.offset + J.ROWS) then V.list.offset = at - 1 end
    V.list:SetItems(rows)
    -- another quest or the run starts at the top
    if V.shownQuest ~= chosen then
        V.shownQuest = chosen
        if V.scroll.SetVerticalScroll then V.scroll:SetVerticalScroll(0) end
    end
end

-- Shows the quest parts of the body (shown) or hides them for the run planner.
local function showQuestParts(V, shown)
    for _, f in ipairs({ V.nextBox, V.xp, V.pathLabel }) do f:SetShown(shown) end
    if not shown then
        V.rewardLabel:Hide()
        V.lvl:Hide()
        V.doneLine:Hide()
        for _, b in ipairs(V.rewards) do b:Hide() end
        for _, c in ipairs(V.cards) do c:Hide() end
    else
        for _, fs in ipairs(V.runLabels) do fs:Hide() end
        for _, ln in ipairs(V.runLines) do ln.fs:Hide(); ln.btn:Hide() end
        for _, nd in ipairs(V.runNodes) do nd.icon:Hide(); nd.link:Hide() end
    end
end

-- Fills the chosen quest's inset.
local function fillPath(B, path)
    local V = B.pathView
    local Dn = ns.Dungeons
    local q = path.quest
    V.path = path
    showQuestParts(V, true)
    V.map:SetText(PTEXT.map)
    W.FitChip(V.map)
    -- the head of the inset
    local st = questState(q)
    local tex, shade = Dn.QuestStateArt(st)
    V.mark:SetTexture(tex)
    V.mark:SetTexCoord(0, 1, 0, 1)
    V.mark:SetVertexColor(shade, shade, shade)
    V.title:SetText(q.title)
    local info = {}
    local lv = Dn.QuestLevelText(q)
    if lv ~= "" then info[#info + 1] = PTEXT.level:format(lv) end
    info[#info + 1] = STATE_TEXT[st] or L["offen"]
    local way = Dn.QuestPathShort(path)
    if way ~= "" then info[#info + 1] = L["Weg %s"]:format(way) end
    V.info:SetText(table.concat(info, " · "))
    -- the body: the level window, the next step, the rewards, the XP, the quest path
    local y = fillLevel(V, q, 0)
    V.nextLine:SetText(LABEL .. PTEXT.nextStep .. "|r " .. Dn.QuestPathNextText(path) ..
        (path.cut > 0 and (" " .. GREY .. PTEXT.cut:format(path.cut) .. "|r") or ""))
    local boxH = textHeight(V.nextLine, V.bodyW - 2 * J.BOX_PAD) + 2 * J.BOX_PAD
    V.nextBox:ClearAllPoints()
    V.nextBox:SetPoint("TOPLEFT", 0, y)
    V.nextBox:SetSize(V.bodyW, boxH)
    y = y - boxH - J.SECTION_GAP
    y = fillRewards(V, q, y)
    local value, how, seen = Dn.QuestXP(q)
    if value then
        local from = how == "log" and DTEXT.xpLog or how == "scaled" and DTEXT.xpScaled:format(seen)
            or how == "other" and DTEXT.xpOther:format(seen) or DTEXT.xpSeen:format(seen or 0)
        V.xp:SetText(LABEL .. DTEXT.xpLine:format("|r" .. Dn.XPText(value, how, seen)) .. " " .. GREY .. "· " .. from .. "|r")
    else
        V.xp:SetText(GREY .. DTEXT.xpNone .. "|r")
    end
    V.xp:ClearAllPoints()
    V.xp:SetPoint("TOPLEFT", 0, y)
    y = y - J.LABEL_H - J.SECTION_GAP
    V.pathLabel:SetText(LABEL .. PTEXT.path .. "|r" .. (path.total > 1 and (" " .. PTEXT.progress:format(path.done, path.total)) or ""))
    V.pathLabel:ClearAllPoints()
    V.pathLabel:SetPoint("TOPLEFT", 0, y)
    y = y - J.LABEL_H
    V.map:SetEnabled(path.next ~= nil and Dn.QuestStepTarget(path.next) ~= nil)
    -- the done steps at the start (two or more, not the quest itself) as one line until clicked (F-139)
    local lead = 0
    for i, s in ipairs(path.steps) do
        if s.state ~= "done" or i == #path.steps then break end
        lead = i
    end
    if lead < 2 then lead = 0 end
    local width = V.bodyW
    local cy = -y
    if lead > 0 then
        local first, last = path.steps[1].no, path.steps[lead].no
        V.doneLine.text:SetText(GREY .. (V.showDone[V.shownQuest] and PTEXT.doneOpen or PTEXT.doneFold):format(first, last) .. "|r")
        V.doneLine:ClearAllPoints()
        V.doneLine:SetPoint("TOPLEFT", 0, -cy)
        V.doneLine:Show()
        cy = cy + J.DONE_H + P.LINE_GAP
        if V.showDone[V.shownQuest] then lead = 0 end
    else
        V.doneLine:Hide()
    end
    -- the step cards, top to bottom, "danach" between them
    for i, s in ipairs(path.steps) do
        local c = V.cards[i]
        if not c then
            c = newCard(V.child, V.onMap)
            V.cards[i] = c
        end
        if i <= lead then
            c:Hide()
        else
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", 0, -cy)
            c:SetWidth(width)
            local h = fillCard(c, s, path, width, s == path.next)
            c:Show()
            cy = cy + h
            local last = i == #path.steps
            c.link:SetShown(not last)
            c.arrow:SetShown(not last)
            c.after:SetShown(not last)
            if not last then
                c.link:ClearAllPoints()
                c.link:SetPoint("TOP", c, "BOTTOMLEFT", P.PAD + P.ICON / 2, 0)
                c.link:SetHeight(P.AFTER_H - 8)
                c.arrow:ClearAllPoints()
                c.arrow:SetPoint("TOP", c, "BOTTOMLEFT", P.PAD + P.ICON / 2, -(P.AFTER_H - 12))
                if W.HasAtlas("talents-arrow-head-gray") then c.arrow:SetAtlas("talents-arrow-head-gray") else c.arrow:Hide() end
                c.after:ClearAllPoints()
                c.after:SetPoint("LEFT", c, "BOTTOMLEFT", P.TEXT_X, -P.AFTER_H / 2)
                cy = cy + P.AFTER_H
            end
        end
    end
    for i = #path.steps + 1, #V.cards do V.cards[i]:Hide() end
    V.child:SetHeight(math.max(10, cy))
    if V.scroll.UpdateScrollChildRect then V.scroll:UpdateScrollChildRect() end
end

-- The run planner in the inset (F-139): before the run (the stops by zone, what cannot be done yet),
-- in the dungeon (the bosses in the game's order with the quests there), after the run (the turn-ins).
local SKULL = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
local START_COLOR = "|cff6fb5ff"
local function fillRun(B, plan)
    local V = B.pathView
    V.path, V.plan = nil, plan
    showQuestParts(V, false)
    if W.HasAtlas("Dungeon") then V.mark:SetAtlas("Dungeon") else V.mark:SetTexture(ICON) end
    V.mark:SetVertexColor(1, 1, 1)
    V.title:SetText(RTEXT.row)
    V.info:SetText(RTEXT.info:format(plan.open, #plan.route))
    -- the route button: the next stop
    if B.routeFor ~= B.pathDungeon then
        B.routeFor = B.pathDungeon
        V.routeAt = 1
    end
    local n = #plan.route
    V.routeAt = math.min(V.routeAt or 1, math.max(1, n))
    V.map:SetText(n > 0 and RTEXT.route:format(V.routeAt, n) or RTEXT.noRoute)
    W.FitChip(V.map)
    V.map:SetEnabled(n > 0)
    local y, nLabel, nLine, nNode = 0, 0, 0, 0
    local function label(text)
        nLabel = nLabel + 1
        local fs = V.runLabels[nLabel]
        if not fs then
            fs = W.Text(V.child, T.FONT.text, V.bodyW)
            V.runLabels[nLabel] = fs
        end
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", 0, y)
        fs:SetText(LABEL .. text .. "|r")
        fs:Show()
        y = y - J.LABEL_H
    end
    local function line(text, x, stop)
        nLine = nLine + 1
        local ln = V.runLines[nLine]
        if not ln then
            ln = { fs = W.Text(V.child, T.FONT.text, 100, true) }
            ln.fs:SetJustifyV("TOP")
            ln.btn = W.Button(V.child, PTEXT.card, nil, function(self) say(ns.DungeonRouteWaypoint(self.stop)) end, { height = P.BUTTON_H })
            ln.btn:SetHeight(P.BUTTON_H)
            W.FitChip(ln.btn)
            W.Tooltip(ln.btn, PTEXT.card, PTEXT.cardTip)
            V.runLines[nLine] = ln
        end
        local w = V.bodyW - x - (stop and (ln.btn:GetWidth() + 6) or 0)
        ln.fs:SetWidth(w)
        ln.fs:SetText(text)
        ln.fs:ClearAllPoints()
        ln.fs:SetPoint("TOPLEFT", x, y - 1)
        ln.fs:Show()
        local h = textHeight(ln.fs, w)
        if stop then
            ln.btn.stop = stop
            ln.btn:ClearAllPoints()
            ln.btn:SetPoint("TOPRIGHT", 0, y + 3)
            ln.btn:Show()
            h = math.max(h, P.BUTTON_H - 4)
        else
            ln.btn:Hide()
        end
        y = y - h - P.LINE_GAP
    end
    local function groups(list)
        for _, g in ipairs(list) do
            line("|cffffffff" .. g.zone .. "|r", 0)
            for _, st in ipairs(g.stops) do
                local fmt = st.what == "accept" and RTEXT.accept or RTEXT.turnIn
                line(fmt:format(st.no, st.title, st.text), J.STOP_X, st)
            end
        end
    end
    -- before the run
    label(RTEXT.before)
    groups(plan.before)
    for _, l in ipairs(plan.later) do line(T.ORANGE .. RTEXT.later:format(l.level, l.title) .. "|r", J.STOP_X) end
    for _, t in ipairs(plan.pending) do line(RTEXT.pending:format(t), J.STOP_X) end
    for _, t in ipairs(plan.unknown) do line(GREY .. RTEXT.unknown:format(t) .. "|r", J.STOP_X) end
    if plan.open == 0 then
        line(GREY .. RTEXT.noQuests .. "|r", 0)
    elseif n == 0 and #plan.later == 0 and #plan.unknown == 0 and #plan.pending == 0 then
        line(GREY .. RTEXT.nothingBefore .. "|r", 0)
    end
    y = y - J.SECTION_GAP
    -- in the dungeon: the bosses as a track
    label(RTEXT.inside)
    if #plan.bosses == 0 then line(GREY .. RTEXT.noBosses .. "|r", 0) end
    local prev
    for _, t in ipairs(plan.bosses) do
        nNode = nNode + 1
        local nd = V.runNodes[nNode]
        if not nd then
            nd = { icon = V.child:CreateTexture(nil, "ARTWORK"), link = V.child:CreateTexture(nil, "BACKGROUND") }
            nd.icon:SetTexture(SKULL)
            nd.icon:SetSize(J.NODE, J.NODE)
            nd.link:SetColorTexture(0.55, 0.5, 0.42, 0.8)
            nd.link:SetWidth(J.LINK_W)
            V.runNodes[nNode] = nd
        end
        local busy = #t.goals + #t.starts + t.ups > 0
        nd.icon:ClearAllPoints()
        nd.icon:SetPoint("TOPLEFT", 0, y)
        nd.icon:SetAlpha(busy and 1 or 0.45)
        nd.icon:Show()
        nd.link:ClearAllPoints()
        if prev then
            nd.link:SetPoint("TOP", prev.icon, "BOTTOM", 0, -1)
            nd.link:SetPoint("BOTTOM", nd.icon, "TOP", 0, 1)
            nd.link:Show()
        else
            nd.link:Hide()
        end
        prev = nd
        line((busy and GOLD_TEXT or GREY) .. t.name .. "|r", J.NODE_TEXT_X)
        if #t.goals > 0 then line(RTEXT.goals:format(table.concat(t.goals, ", ")), J.NODE_TEXT_X) end
        if #t.starts > 0 then line(START_COLOR .. RTEXT.starts:format(table.concat(t.starts, ", ")) .. "|r", J.NODE_TEXT_X) end
        if t.ups > 0 then line(GREEN .. RTEXT.ups:format(t.ups) .. "|r", J.NODE_TEXT_X) end
    end
    if #plan.other > 0 then line(RTEXT.other:format(table.concat(plan.other, ", ")), 0) end
    y = y - J.SECTION_GAP
    -- after the run
    label(RTEXT.after)
    groups(plan.after)
    if #plan.after == 0 then line(GREY .. RTEXT.nothingAfter .. "|r", 0) end
    for i = nLabel + 1, #V.runLabels do V.runLabels[i]:Hide() end
    for i = nLine + 1, #V.runLines do V.runLines[i].fs:Hide(); V.runLines[i].btn:Hide() end
    for i = nNode + 1, #V.runNodes do V.runNodes[i].icon:Hide(); V.runNodes[i].link:Hide() end
    V.child:SetHeight(math.max(10, -y))
    if V.scroll.UpdateScrollChildRect then V.scroll:UpdateScrollChildRect() end
end

local function create(parent)
    -- the head row: the spec (the gear page's) with the order chips; the recommendation, why, the
    -- list, the image, the bosses or quests, the hint in the footer
    local B = W.Page(parent)
    page = B
    B:Bands({ "row", "row", { "line", lines = 2 } })
    B.spec = K.specPicker(B)
    B.next = W.Text(B, T.FONT.title)
    B.why = B:Line(3)
    -- the order of the list: by level, by value (the ranking), the chain
    B.sorts = {}
    local sortDefs = { { "level", "Level", 50, L["Nach Level"], L["Die Dungeons nach ihrem Levelbereich."] },
        { "value", L["Wert"], 46, L["Rangliste"], L["Die lohnendsten Dungeons für dich zuerst: offene Quests plus zwei Läufe."] },
        { "chain", L["Kette"], 50, L["Kette"], L["Der beste Dungeon, seine Upgrades gedanklich angelegt (je Boss das größte, alle Quest-Upgrades), dann der beste danach, bis zu fünf."] } }
    local sortRow = {}
    for i, d in ipairs(sortDefs) do
        local chip = W.Chip(B, d[2], d[3], function()
            state().dsort = d[1]
            ns.Refresh()
        end)
        W.Tooltip(chip, d[4], d[5])
        B.sorts[d[1]] = chip
        sortRow[i] = chip
    end
    -- the spec, the order chips at the right edge (in the order of sortDefs); the recommendation
    -- under them, as wide as the page
    B:Place(1, { B.spec }, sortRow)
    B:Place(2, { { B.next, fill = true } })
    B:Footer({ { "hint", lines = 2 } })
    -- the list is 590 wide (12 px for its scroll bar)
    local cols = { { "name", 4, 170, "Dungeon" }, { "level", 178, 46, "Level" }, { "fit", 228, 56, L["Passung"] },
        { "upgrades", 288, 56, "Upgrades", justify = "RIGHT" }, { "run", 348, 66, L["Je Lauf"], justify = "RIGHT" },
        { "quests", 418, 66, "Quests", justify = "RIGHT" }, { "value", 488, 60, L["Wert"], justify = "RIGHT" } }
    B.headFrame, B.head = B:Columns(cols)
    B.list = B:List(DUNGEON_ROWS, ROW_H, function(r)
        r.owner = B
        r.sel = W.SelectBar(r)
        W.Cells(r, cols)
        r:SetScript("OnClick", function(self)
            if not self.item then return end
            state().dungeon = self.item.key
            ns.Refresh()
        end)
        r:SetScript("OnEnter", dungeonTip)
        r:SetScript("OnLeave", hideTip)
    end, fillDungeonRow)
    -- the image under the list, the bosses' or quests' header under it, then their list
    local G = T.LAYOUT
    local artTop = B.listTop - DUNGEON_ROWS * ROW_H - G.GAP
    B.art = buildArt(B, artTop)
    local headerTop = artTop - ART_H - G.GAP
    B.mark = W.Button(B.art, DTEXT.mark, 110, function()
        if not B.chosen then return end
        if ns.DungeonMarked() == B.chosen then
            ns.DungeonClearMarks()
            ns.msg(DTEXT.unmarked)
        else
            local n, why = ns.DungeonMarkQuests(B.chosen)
            if n then ns.msg(DTEXT.marked:format(n)) else say(nil, why) end
        end
        B.mark:SetText(ns.DungeonMarked() == B.chosen and DTEXT.unmark or DTEXT.mark)
    end)
    B.mark:SetPoint("RIGHT", -(ART_H + 4), 0)
    W.Tooltip(B.mark, DTEXT.markTitle, DTEXT.markTip)
    -- the run planner of the chosen dungeon (F-139)
    B.plan = W.Button(B.art, RTEXT.plan, J.PLAN_W, function()
        if not B.chosen then return end
        B.pathFor = { dungeon = B.chosen, key = "run", part = state().dpart == "quests" and "quests" or "bosses" }
        B.detailKey = nil
        ns.Refresh()
    end)
    B.plan:SetPoint("RIGHT", B.mark, "LEFT", -4, 0)
    W.Tooltip(B.plan, RTEXT.plan, RTEXT.planTip)
    B.art.title:SetWidth(300)
    B.art.info:SetWidth(300)

    B.header = W.SectionHeader(B, "", false)
    B.header:SetPoint("TOPLEFT", 0, headerTop)
    B.header:SetPoint("TOPRIGHT", -244, headerTop)
    -- the lower part: the bosses or the quests of the chosen dungeon
    B.parts = {}
    B.parts.bosses = W.Chip(B, L["Bosse"], 54, function() state().dpart = "bosses"; ns.Refresh() end)
    B.parts.quests = W.Chip(B, "Quests", 54, function() state().dpart = "quests"; ns.Refresh() end)
    W.Tooltip(B.parts.quests, "Quests", L["Die Quests des Dungeons mit Stufe, Weg (erledigte Schritte der Vorquests) und Start. Klick auf eine Quest zeigt ihren Questweg: jeden Schritt mit Annehmen, Abgeben, Voraussetzung und Karte."])
    B.way = W.Button(B, L["Wegpunkt"], 120, function()
        if B.chosen then say(ns.DungeonWaypoint(B.chosen)) end
    end)
    -- the two chips and the waypoint button at the right end of the header's line
    W.Row(B, { B.parts.bosses, B.parts.quests, { B.way, gap = G.ITEM_GAP } }, T.CHIP_GAP, 0, headerTop - 1, { right = true })
    W.Tooltip(B.way, L["Wegpunkt zum Eingang"], L["Setzt das Kartenziel auf den nächsten Eingang des gewählten Dungeons."])
    B.detail = buildDetail(B, DETAIL_ROWS)
    B.detail:SetPoint("TOPLEFT", 0, headerTop - T.HEADER_H - G.GAP)
    B.detail:SetPoint("TOPRIGHT", -T.SCROLL_ROOM, headerTop - T.HEADER_H - G.GAP)
    -- the quest path in place of the list, the image and the quests (F-135); only in memory
    B.pathView = buildPath(B)
    -- the journal remembers the part it was opened from (the planner's quests or bosses)
    local function partNow() return state().dpart == "quests" and "quests" or "bosses" end
    function B:OpenPath(e)
        if e and e.kind == "run" then
            self.pathFor = { dungeon = state().dungeon, key = "run", part = partNow() }
        elseif e and e.q then
            self.pathFor = { dungeon = state().dungeon, key = e.qid or e.q.title, part = partNow() }
        else
            self.pathFor = nil
        end
        self.detailKey = nil
        ns.Refresh()
    end
    -- the parts of the planner the quest path covers
    B.planParts = { B.next, B.why, B.headFrame, B.list, B.art, B.header, B.parts.bosses, B.parts.quests, B.way, B.detail }
    return B
end

-- The image, its texts, the boss model and the mark button of the chosen dungeon e.
local function fillArt(B, e)
    local a = B.art
    if not e then
        a:Hide()
        return
    end
    a:Show()
    local Dn = ns.Dungeons
    local fid, kind = Dn.Art(e.key)
    if fid then
        a.tex:SetTexture(fid)
        a.tex:SetTexCoord(Dn.ArtCoords(kind, ART_W, ART_H))
        a.tex:Show()
    else
        a.tex:Hide()
    end
    a.title:SetText(e.name)
    local range = Dn.RangeText(e)
    a.info:SetText(range ~= "" and DTEXT.level:format(range, Dn.FitText(e)) or Dn.FitText(e))
    a:SetModelNpc(Dn.ModelNpc(e))
    if B.mark then B.mark:SetText(ns.DungeonMarked() == e.key and DTEXT.unmark or DTEXT.mark) end
end

local function refresh(B)
    K.namesFresh()
    K.fillSpec(B.spec, ns.BisOpts())
    local list = ns.DungeonList()
    local nextE, why = ns.DungeonNext()
    local Dn = ns.Dungeons
    local sort = state().dsort
    if sort ~= "value" and sort ~= "chain" then sort = "level" end
    for k, chip in pairs(B.sorts) do chip:SetOn(k == sort) end
    local shown, extra = orderedDungeons(list, sort)
    if sort == "chain" then
        B.next:SetText(Dn.ChainText(extra.chain, extra.why))
        B.why:SetText(#extra.chain > 0 and (L["Annahme: je Boss das größte Upgrade und alle Quest-Upgrades bekommen."] ..
            (extra.why and (" " .. extra.why) or "")) or "")
    elseif nextE then
        B.next:SetText(L["Nächster Dungeon: %s · Level %s"]:format(nextE.name, Dn.RangeText(nextE)))
        B.why:SetText(nextE.why or "")
    else
        B.next:SetText(why or Dn.NO_DATA)
        B.why:SetText("")
    end
    local e = chosenDungeon(list, nextE)
    B.chosen = e and e.key or nil
    B.list:SetItems(shown)
    if e and not e.computed then e = ns.DungeonInfo(e.key) or e end
    B.entry = e
    fillArt(B, e)
    local part = state().dpart == "quests" and "quests" or "bosses"
    for k, chip in pairs(B.parts) do chip:SetOn(k == part) end
    -- another dungeon or part starts at the top
    local detailKey = e and (e.key .. part) or nil
    if detailKey ~= B.detailKey then B.detail.offset = 0 end
    B.detailKey = detailKey
    local status
    -- the quest path of a quest of this dungeon, while it is open (F-135)
    local path
    local pf = B.pathFor
    if pf and (not e or pf.dungeon ~= e.key or (pf.part or "quests") ~= part) then
        B.pathFor, pf = nil, nil
    end
    -- the quest journal: the run planner (F-139) or the chosen quest, else the first (one gone from
    -- the data or the faction)
    local journalRows, plan, run
    if pf then
        local qrows = (questItems(e.key))
        -- each quest's worth and the best one's score for the bars (F-139)
        local best = 0
        for _, row in ipairs(qrows) do
            row.worth = Dn.QuestWorth(row.q, row.path)
            if row.worth and row.worth.score > best then best = row.worth.score end
        end
        for _, row in ipairs(qrows) do row.worthMax = best end
        plan = Dn.RunPlan(e.key, qrows, e)
        journalRows = { { kind = "run", plan = plan } }
        for _, row in ipairs(qrows) do journalRows[#journalRows + 1] = row end
        if pf.key == "run" then
            run = true
        else
            for _, row in ipairs(qrows) do
                if (row.qid or row.q.title) == pf.key then path = row.path end
            end
            if not path and qrows[1] then
                pf.key = qrows[1].qid or qrows[1].q.title
                path = qrows[1].path
            end
            if not path then B.pathFor = nil end
        end
    end
    -- (the image shows by fillArt above, only for a dungeon)
    local journal = path or run
    for _, f in ipairs(B.planParts) do
        if journal then f:Hide() elseif f ~= B.art then f:Show() end
    end
    if journal then
        B.pathDungeon = e.key
        B.pathView:Show()
        fillJournal(B, journalRows, plan, pf.key)
        if run then
            fillRun(B, plan)
            B.hint:SetText(RTEXT.hint)
        else
            fillPath(B, path)
            B.hint:SetText(PTEXT.hint)
        end
        return
    end
    B.pathView:Hide()
    if e and part == "quests" then
        local rows
        rows, status = questItems(e.key)
        B.header:SetHeaderText(e.name .. " · Quests")
        B.detail:SetItems(rows)
        B.way:SetEnabled(ns.DungeonEntrance(e.key) ~= nil)
    elseif e then
        B.header:SetHeaderText(e.name .. " · " .. L["Bosse"])
        B.detail:SetItems(detailItems(e))
        B.way:SetEnabled(ns.DungeonEntrance(e.key) ~= nil)
    else
        B.header:SetHeaderText("")
        B.detail:SetItems({})
        B.way:SetEnabled(false)
    end
    local hint
    if part == "quests" then
        hint = Dn.QuestStatusText(status) or ""
        if e and #B.detail.items == 0 and hint == "" then hint = L["Für diesen Dungeon kennt Amisia keine Quests."] end
        local xp = e and Dn.XPSumText(Dn.XPSum((ns.DungeonQuests(e.key)))) or ""
        local parts = {}
        for _, t in ipairs({ xp, hint, L["Klick auf eine Quest: ihr Questweg mit allen Schritten. Weg: erledigte Schritte von allen. Grün: Upgrade für dich."] }) do
            if t ~= "" then parts[#parts + 1] = t end
        end
        hint = table.concat(parts, " ")
    else
        hint = L["Je Lauf: Zuwachs der Upgrades mal Dropchance, ohne Mitbewerber in der Gruppe. Wert: offene Dungeon-Quests plus zwei Läufe."]
        if e and e.computed and #B.detail.items == 0 then hint = L["In diesem Dungeon gibt es nichts mehr für dich."] .. " " .. hint end
        hint = hint .. " " .. DTEXT.itemHint
    end
    B.hint:SetText(hint)
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------

function ns.DungeonsPageFrame() return page end

-- Opens the page Dungeons with that dungeon or raid chosen (a click on its entrance on the world
-- map). While the world map shows, the window stays under it (F-011). Returns true when the window
-- shows.
function ns.ShowDungeon(key)
    if type(key) ~= "string" then return false end
    -- a raid opens on the page Raids
    if ns.ShowRaid and ns.Dungeons.IsRaid(key) then return ns.ShowRaid(key) end
    state().dungeon = key
    asked = key
    if ns.ShowPage then ns.ShowPage("dungeons") end
    local main, map = _G.AmisiaFrame, _G.WorldMapFrame
    if main and map and map.IsShown and map:IsShown() and ns.MapLowerMain then
        ns.MapLowerMain(map, main)
        if map.Raise then map:Raise() end
    end
    return main ~= nil and main:IsShown() and true or false
end

-- Opens the page Dungeons with the quest path of quest qid of dungeon key (F-135). Returns true when
-- the window shows.
function ns.ShowDungeonQuest(key, qid)
    if type(key) ~= "string" then return false end
    state().dungeon = key
    state().dpart = "quests"
    asked = key
    if ns.ShowPage then ns.ShowPage("dungeons") end
    if page then
        page.pathFor = { dungeon = key, key = qid, part = "quests" }
        page.detailKey = nil
        ns.Refresh()
    end
    local main = _G.AmisiaFrame
    return main ~= nil and main:IsShown() and true or false
end

-- the journal parts the page Raids shares (UI/Pages/RaidJournal.lua)
ns.DungeonJournalKit = { buildArt = buildArt, fillArt = fillArt, buildDetail = buildDetail, detailItems = detailItems,
    ART_H = ART_H, ROW_H = ROW_H, itemHint = DTEXT.itemHint, signed = signed }

ns.RegisterPanel{ key = "dungeons", label = "Dungeons", icon = ICON, order = 51, group = "gear",
    available = function() return ns.Gear.Available() end,
    create = create, refresh = refresh }
