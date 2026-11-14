-- Dungeons page (tab Dungeons & Raids): the dungeon planner in two views (F-143). The start: the spec
-- of the gear page in the head row with the order of the rows (by level, the ranking, the chain); the
-- next dungeon with its reason; every dungeon as a row of a table by level range (F-148, D-74:
-- picture, name, level, territory, zone, keys, quests, waypoint). A click on a row opens the detail: a
-- link back to the table, the chosen one's image with its boss model, its bosses and upgrades or its quests (one row
-- each: state, level, the quest path's progress "Weg 2/4", start, XP); the waypoints to its entrance
-- and quest givers and "Alle Questgeber auf der Karte". A click on a quest opens its quest path
-- (F-135) in place of the list, image and quests: the steps from the first pre-quest to the quest,
-- each with where it is taken and handed in ("Karte"), what it needs and its objective, the next step
-- highlighted ("Nächsten Schritt auf der Karte"). The values come from Gear/Dungeons.lua; item texts,
-- marks, tooltips, clicks, menus and the cache are the gear page's (ns.GearPageKit). The state stays
-- in settings.bis (dungeon, dsort, dpart); the view and the open quest path only in memory (the first
-- open of a session shows the table, a /reload starts there again).
local ADDON, ns = ...
ns.Load(function()
local L = ns.L
local W, T = ns.W, ns.Theme
local K = ns.GearPageKit
local GREY, GREEN = T.GREY, "|cff4fd06a"
local ICON = "Interface\\Icons\\INV_Misc_Book_11"
-- the quest log's plus and minus before a boss that folds (F-144), as in the main window's side bar
local ROW_H = 24
-- at least 5 rows of the chosen one under its image (they fill the page down to its bottom)
local DETAIL_ROWS = 5
local state, cached, say, col, hideTip = K.state, K.cached, K.say, K.col, K.hideTip
local itemText, marks, gainText = K.itemText, K.marks, K.gainText
local itemTooltip, modifiedClick, menuEntries = K.itemTooltip, K.modifiedClick, K.menuEntries
local JP = ns.JournalParts   -- the detail's tabs, run, map and keys (D-72)

local page

---------------------------------------------------------------------------
-- The next dungeon, the list, the chosen one's bosses and quests
---------------------------------------------------------------------------

local GOLD_TEXT = "|cffe3b857"
local KILLED = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t "
-- the hints of the parts Wunschliste, Karte and Zugang (D-72)
local WISH_HINT = L["Gewünscht und empfohlen, nach Boss. Wünsche setzt und streichst du mit Rechtsklick auf ein Item, auch hier."]
local MAP_HINT = L["Die Karte kommt aus dem Spiel; fehlt sie dort, kann Amisia keine zeigen. Mausrad: zoomen, Ziehen: verschieben, Pfeile: Ebenen."]
local ACCESS_HINT = L["Grün: du hast den Schlüssel. Klick auf einen Schritt: Wegpunkt zum Annehmen der Quest."]
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
    bossHint = L["Klick auf einen Boss: seine Beute rechts. Stern: Wunschliste."],
    xpLine = L["EP: %s"],
    xpLog = L["laut Questlog"],
    xpSeen = L["gesehen bei Level %d"],
    xpScaled = L["geschätzt, gesehen bei Level %d"],
    xpOther = L["gesehen bei Level %d, Questlevel unbekannt"],
    xpScan = L["aus dem Quest-Scan, geschätzt"],
    scanned = L["Nur aus dem Quest-Scan: Questgeber und Ort noch unbekannt"],
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

-- The rows of the chosen dungeon: a row per boss with its items below it (the boss row keeps its
-- item rows in .items, in the same order, for the folded strip). Every boss of the game's order, in
-- that order (F-170): those without loot for the character without item rows (ns.Dungeons.JournalBosses);
-- npc: the boss's NPC for the portrait.
local function detailItems(e)
    local c = cached()
    c.detail = c.detail or {}
    local out = c.detail[e]
    if out then return out end
    out = {}
    for _, jb in ipairs(ns.Dungeons.JournalBosses(e.key, e.bosses)) do
        local b = jb.b
        -- shown: the name in the client's language where the NPC scan found it (D-104); text stays the key
        local head = { kind = "boss", text = b.name, shown = ns.ScannedNpcName and jb.npc and ns.ScannedNpcName(jb.npc) or nil,
                       b = b, npc = jb.npc, items = {} }
        out[#out + 1] = head
        for _, it in ipairs(b.items) do
            local row = { kind = "item", id = it.id, it = it, rec = it.rec, wished = it.wished, owned = it.owned }
            out[#out + 1] = row
            head.items[#head.items + 1] = row
        end
    end
    c.detail[e] = out
    return out
end

-- The part Übersicht (F-154, D-85): the bosses on the left, the chosen boss's loot on the right. The
-- chosen boss per page and dungeon (raid) key, only in memory; a dungeon shown the first time starts
-- with the first boss that has an upgrade for the player (an item marked "Upgrade" in its row), else
-- the first with loot, else the first.
local function bossUpgrade(b)
    -- the item's own mark (the gear data's threshold, an own pick of D-55), as its row shows it
    for _, it in ipairs(b.items or {}) do
        if it.upgrade then return true end
    end
    return false
end

-- The boss rows of e on page B (n: the place in the game's order, on: the chosen one) and the chosen one.
-- An item asked for from elsewhere (F-157, the source symbol of the gear planner): { key, id, scroll };
-- a boss asked for (F-168, the dungeon bar): { key, boss = its place in the game's order }.
-- The next showing of that instance chooses the boss that drops it, scrolls its loot row into view
-- and marks it; choosing another boss or instance ends it.
local focus

local function bossHeads(B, e)
    local heads = {}
    for _, row in ipairs(detailItems(e)) do
        if row.kind == "boss" then
            heads[#heads + 1] = { kind = "boss", text = row.text, shown = row.shown, b = row.b, npc = row.npc, items = row.items, n = #heads + 1,
                killed = JP.BossKilled(e.key, row.text) }
        end
    end
    B.bossSel = B.bossSel or {}
    if focus and focus.key == e.key and not focus.chosen then
        focus.chosen = true
        for _, h in ipairs(heads) do
            -- a boss asked for by its place in the game's order (F-168, the dungeon bar)
            if focus.boss and JP.BossIndex(e.key, h.text) == focus.boss then B.bossSel[e.key] = h.text end
            for _, row in ipairs(h.items) do
                if row.id == focus.id then B.bossSel[e.key] = h.text end
            end
        end
    end
    local name, sel = B.bossSel[e.key], nil
    for _, h in ipairs(heads) do
        if h.text == name then sel = h end
    end
    if not sel then
        for _, h in ipairs(heads) do
            if not sel and bossUpgrade(h.b) then sel = h end
        end
        for _, h in ipairs(heads) do
            if not sel and #h.items > 0 then sel = h end
        end
        sel = sel or heads[1]
        B.bossSel[e.key] = sel and sel.text or nil
    end
    if sel then sel.on = true end
    return heads, sel
end

-- The part Wunschliste of e (D-72): each boss with an item the character wishes or the plan
-- recommends, with only those items.
local function wishItems(e)
    local out, head = {}, nil
    for _, row in ipairs(detailItems(e)) do
        if row.kind == "boss" then
            head = { kind = "boss", text = row.text, shown = row.shown, b = row.b, items = {}, killed = JP.BossKilled(e.key, row.text) }
        elseif (row.wished or row.rec) and head then
            if #head.items == 0 then out[#out + 1] = head end
            out[#out + 1] = row
            head.items[#head.items + 1] = row
        end
    end
    return out
end

-- The bosses of e on page B (the part Übersicht; ns.Refresh and a click on a boss); nil clears the view.
local fillBossView
local function showBosses(B, e)
    local V = B.bossView
    V.entry = e
    if not e then
        V.list:SetItems({})
        V.loot:SetItems({})
        fillBossView(B, nil, 0)
        return
    end
    if focus and focus.key ~= e.key then focus = nil end
    local heads, sel = bossHeads(B, e)
    -- another instance starts at the top
    if V.shownKey ~= e.key then V.list.offset = 0 end
    V.shownKey = e.key
    if V.shownBoss ~= (sel and (e.key .. "\0" .. sel.text)) then V.loot.offset = 0 end
    V.shownBoss = sel and (e.key .. "\0" .. sel.text) or nil
    local loot = sel and sel.items or {}
    if focus and focus.scroll then
        focus.scroll = nil
        for i, row in ipairs(loot) do
            if row.id == focus.id then V.loot.offset = math.max(0, i - math.max(1, V.loot.rowCount or 1)) end
        end
    end
    V.list:SetItems(heads)
    V.loot:SetItems(loot)
    fillBossView(B, sel, #heads)
end

-- Chooses boss name of the shown instance on B.
local function chooseBoss(B, name)
    local e = B.bossView.entry
    if not (e and name) then return end
    focus = nil
    B.bossSel = B.bossSel or {}
    B.bossSel[e.key] = name
    showBosses(B, e)
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
            q = q, qid = q.qid, dkey = key, path = ns.Dungeons.QuestPath(q, key) }
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
-- a quest row in a party (F-178): the start shorter, the members' marks at the right end
CELLS.questg = { name = { 4, 178 }, slot = { 186, 48 }, way = { 236, 58 }, gain = { 298, 34 }, xp = { 336, 56 }, rate = { 398, 92 },
    grp = { 492, 94 } }
-- a boss of the Wunschliste: its name, its gain per run after it
CELLS.boss = { name = { 4, 220 }, slot = { 228, 62 }, way = { 236, 58 }, gain = { 292, 40 }, xp = { 336, 56 }, rate = { 228, 200 } }
local function placeCells(r, kind)
    kind = CELLS[kind] and kind or "other"
    if r.cellKind == kind then return end
    r.cellKind = kind
    for key, c in pairs(CELLS[kind]) do
        r[key]:ClearAllPoints()
        r[key]:SetPoint("LEFT", c[1], 0)
        r[key]:SetWidth(c[2])
    end
end

-- A boss's gain per run ("je Lauf +12"), or for an NPC only the guild's records know its kills
-- (listed, counted from its third kill); "" without either.
local function bossRate(b)
    if b.tentative then
        local k = b.kills or 0
        return GREY .. L["%d %s, zählt ab 3"]:format(k, k == 1 and "Kill" or "Kills") .. "|r"
    end
    return (b.perRun or 0) > 0 and L["je Lauf %s"]:format(signed(b.perRun)) or ""
end

local function fillDetailRow(r, e)
    placeCells(r, e.kind)
    r.grp:SetText("")
    if r.share then r.share:Hide() end
    r.xp:SetText("")
    r.way:SetText("")
    if e.kind == "boss" then
        -- killed in the run (D-72): the ready check's tick, the name grey
        local shown = e.shown or e.text
        r.name:SetText(e.killed and (KILLED .. GREY .. shown .. "|r") or (GOLD_TEXT .. shown .. "|r"))
        r.slot:SetText("")
        r.gain:SetText("")
        r.rate:SetText(bossRate(e.b))
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
        -- a quest: state, title, level, the quest path's progress, where it starts; in a party the
        -- members' marks (F-178)
        local q = e.q
        local GQ = ns.GroupQuests
        local grpMarks = GQ and e.dkey and GQ.Marks(e.dkey, q.qid) or ""
        if grpMarks ~= "" then
            placeCells(r, "questg")
            r.grp:SetText(grpMarks)
        end
        if r.share then r.share:SetShown(GQ ~= nil and e.dkey ~= nil and GQ.CanShare(e.dkey, q.qid) and GQ.ShareAvailable()) end
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

-- Where a quest's XP comes from (Dungeons.QuestXP's how and seen), for the tooltip and the detail.
local function xpSource(how, seen)
    return how == "log" and DTEXT.xpLog or how == "scaled" and DTEXT.xpScaled:format(seen)
        or how == "other" and DTEXT.xpOther:format(seen) or how == "scan" and DTEXT.xpScan or DTEXT.xpSeen:format(seen or 0)
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
    -- a quest only the quest scan's text placed here (D-109): no giver, no place yet
    if q.scanned then GameTooltip:AddLine(DTEXT.scanned, 0.6, 0.6, 0.6, true) end
    local value, how, seen = ns.Dungeons.QuestXP(q)
    if value then
        local from = xpSource(how, seen)
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
    -- the party's state of it (F-178)
    if ns.GroupQuests and e.dkey then
        for i, line in ipairs(ns.GroupQuests.TipLines(e.dkey, q.qid)) do
            if i == 1 then GameTooltip:AddLine(line, 1, 0.82, 0) else GameTooltip:AddLine(line, 0.85, 0.85, 0.85, true) end
        end
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
-- top: where the list starts on B (a SetPoint offset); the list takes the rows that fit down to B's
-- lower end, at least rows (the footer's room went to it when the hint moved behind the "i", D-67), and
-- follows the main window's height (W.FillTo, D-68).
-- What a click on an item row does (also a click on its icon in a folded boss's strip): the right
-- button the item's menu, Shift or Ctrl the client's modified click.
local function itemClick(owner, e, button)
    if not (e and e.id) then return end
    if button == "RightButton" then
        if e.kind == "item" then W.Menu(owner, menuEntries(e, ns.BisOpts())) end
        return
    end
    modifiedClick(e.id)
end

local function itemTip(owner, id)
    itemTooltip(owner, id)
    GameTooltip:AddLine(DTEXT.itemHint, 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

-- "Teilen" on a quest row (F-178): the client's quest share of the own quest, only on the click.
local function addShare(r)
    r.share = W.Link(r, L["Teilen"], function(self)
        local e = self:GetParent().item
        if not (e and e.qid and ns.GroupQuests) then return end
        local ok, why = ns.GroupQuests.Share(e.qid)
        if ok then
            ns.msg(L["Quest \"%s\" mit der Gruppe geteilt."]:format(e.q and e.q.title or "?"))
        elseif why then
            ns.msg(why)
        end
    end)
    W.FitChip(r.share)
    r.share:SetPoint("RIGHT", -4, 0)
    W.Tooltip(r.share, L["Teilen"], L["Teilt die Quest aus deinem Questlog mit der Gruppe (wem sie fehlt, steht im Tooltip der Zeile)."])
    W.RowAction(r, r.share)
    r.share:Hide()
end

local function buildDetail(B, rows, top)
    local list = W.List(B, rows, ROW_H, function(r)
        r.name = col(r, 4, 220, nil, T.FONT.text)
        r.slot = col(r, 228, 62, nil, T.FONT.text)
        r.gain = col(r, 292, 40, nil, T.FONT.text)
        r.gain:SetJustifyH("RIGHT")
        r.xp = col(r, 336, 56, nil, T.FONT.text)
        r.xp:SetJustifyH("RIGHT")
        r.rate = col(r, 398, 188, nil, T.FONT.text)
        r.way = col(r, 236, 58, nil, T.FONT.text)
        r.way:SetJustifyH("RIGHT")
        -- the party's marks of a quest (F-178) and "Teilen" while the mouse is on the row (D-67)
        r.grp = col(r, 492, 94, nil, T.FONT.text)
        addShare(r)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetScript("OnClick", function(self, button)
            local e = self.item
            if not e then return end
            if e.kind == "quest" and button ~= "RightButton" then
                -- the quest path in place of the list (F-135)
                if B.OpenPath then B:OpenPath(e) end
                return
            end
            if e.kind == "boss" then
                -- the right button: killed or not (D-72)
                if button == "RightButton" then JP.BossMenu(B, self, e) end
                return
            end
            itemClick(self, e, button)
        end)
        r:SetScript("OnEnter", function(self)
            local e = self.item
            if e and e.q then
                questTip(self)
            elseif e and e.id then
                itemTip(self, e.id)
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
    if top then W.FillTo(list, B, top, rows, ROW_H) end
    return list
end

---------------------------------------------------------------------------
-- The part Übersicht (F-154, D-85): the bosses with their portraits, the chosen boss's loot with icons
---------------------------------------------------------------------------

local BV = T.DBOSS
local BTEXT = {
    items = L["%d Items"], oneItem = L["1 Item"], noLoot = L["keine Beute bekannt"],
    ups = L["%d Upgrades"], oneUp = L["1 Upgrade"],
    of = L["Boss %d von %d"], killed = L["getötet"],
    none = L["Für diesen Boss kennt Amisia keine Beute."],
    noneForYou = L["Von diesem Boss kennt Amisia keine Beute für dich."],
    nothingForYou = L["nichts für dich"],
    noBosses = L["Für diese Instanz kennt Amisia keine Bosse."],
    bossTip = L["Klick: seine Beute rechts. Rechtsklick: als getötet markieren oder nicht."],
    wishOn = L["Von der Wunschliste nehmen"], wishOff = L["Auf die Wunschliste"],
}

-- A boss's portrait and its NPC: the shared kit (UI/Widgets.lua, W.Portrait, F-180)
local buildPortrait, setPortrait = W.Portrait, W.SetPortrait

-- The grey line of a boss row: its items and upgrades ("4 Items · 1 Upgrade"), "keine Beute bekannt",
-- or the kills of an NPC only the guild's records know.
local function bossLine(h)
    if h.b.tentative then return bossRate(h.b) end
    local n = #(h.items or {})
    -- a boss of the game's order without loot for the character (F-170): what the item data knows of it
    local known = h.b.known or 0
    if n == 0 and known > 0 then
        return GREY .. (known == 1 and BTEXT.oneItem or BTEXT.items:format(known)) .. " · " .. BTEXT.nothingForYou .. "|r"
    end
    if n == 0 then return GREY .. BTEXT.noLoot .. "|r" end
    local text = GREY .. (n == 1 and BTEXT.oneItem or BTEXT.items:format(n)) .. "|r"
    local ups = 0
    for _, row in ipairs(h.items) do
        if row.it and row.it.upgrade then ups = ups + 1 end
    end
    if ups > 0 then text = text .. GREY .. " · |r" .. GREEN .. (ups == 1 and BTEXT.oneUp or BTEXT.ups:format(ups)) .. "|r" end
    return text
end

local function fillBossRow(r, h)
    r.sel:SetShown(h.on and true or false)
    setPortrait(r.port, h.b.npc or h.npc)
    r.port:SetAlpha(h.killed and 0.5 or 1)
    local shown = h.shown or h.text
    local name = h.killed and (KILLED .. GREY .. shown .. "|r") or ((h.on and GOLD_TEXT or "|cffffffff") .. shown .. "|r")
    r.name:SetText(GREY .. h.n .. ".|r " .. name)
    r.sub:SetText(bossLine(h))
end

-- The chosen boss h of n in the head over its loot (nil: none, the instance's or the boss's empty text).
fillBossView = function(B, h, n)
    local V = B.bossView
    local head = V.head
    if not h then
        setPortrait(head.port, nil)
        head.port:SetAlpha(1)
        head.name:SetText("")
        head.sub:SetText(V.entry and (GREY .. BTEXT.noBosses .. "|r") or "")
        V.none:Hide()
        return
    end
    setPortrait(head.port, h.b.npc or h.npc)
    head.port:SetAlpha(h.killed and 0.5 or 1)
    head.name:SetText(GOLD_TEXT .. (h.shown or h.text) .. "|r")
    local parts = { BTEXT.of:format(h.n, n) }
    local rate = bossRate(h.b)
    if rate ~= "" then parts[#parts + 1] = rate end
    if h.killed then parts[#parts + 1] = KILLED .. BTEXT.killed end
    head.sub:SetText(table.concat(parts, GREY .. " · |r"))
    V.none:SetText((h.b.known or 0) > 0 and BTEXT.noneForYou or BTEXT.none)
    V.none:SetShown(#(h.items or {}) == 0)
end

local setWishStar = W.WishStar

local function fillLootRow(r, e)
    local it = e.it
    r.icon:SetTexture(itemIcon(e.id))
    local q = itemQuality(e.id) or 1
    local c = T.QUALITY_RGB[q] or T.QUALITY_RGB[1]
    if ns.GoalsKit and r.frame.ring then ns.GoalsKit.setRing(r.frame, c[1], c[2], c[3]) end
    -- the owned mark only: the star at the row's end shows the wish
    r.name:SetText(marks({ owned = it.owned }) .. itemText(it.id))
    local parts = {}
    local slot = ns.BIS_SLOT_NAME[it.slotKey]
    if slot then parts[#parts + 1] = GREY .. slot .. "|r" end
    local gain = gainText(it)
    if gain and gain ~= "" then parts[#parts + 1] = gain end
    r.sub:SetText(table.concat(parts, GREY .. " · |r"))
    r.rate:SetText(it.rate or "")
    setWishStar(r.star, e.wished and true or false)
    r.sel:SetShown(focus ~= nil and focus.id ~= nil and focus.id == e.id)
end

-- The view of the part Übersicht on page B at top (a SetPoint offset) down to the page's bottom:
-- B.bossView with .list (the bosses), .head (the chosen one), .loot (its items), .none (no loot).
local function buildBossView(B, top)
    local V = CreateFrame("Frame", nil, B)
    V:SetPoint("TOPLEFT", 0, top)
    V:SetPoint("BOTTOMRIGHT", 0, B:Bottom())
    B.bossView = V
    -- the bosses: a click chooses, the right button marks killed (D-72), the mouse shows it in the image
    V.list = W.List(V, BV.MIN_ROWS, BV.ROW_H, function(r)
        r.sel = W.SelectBar(r)
        r.port = buildPortrait(r, BV.PORTRAIT)
        r.port:SetPoint("LEFT", BV.PORT_X, 0)
        r.name = W.Text(r, T.FONT.body)
        r.name:SetPoint("TOPLEFT", BV.TEXT_X, BV.NAME_Y)
        r.name:SetPoint("TOPRIGHT", -4, BV.NAME_Y)
        r.sub = W.Text(r, T.FONT.text)
        r.sub:SetPoint("TOPLEFT", BV.TEXT_X, BV.SUB_Y)
        r.sub:SetPoint("TOPRIGHT", -4, BV.SUB_Y)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetScript("OnClick", function(self, button)
            local h = self.item
            if not h then return end
            if button == "RightButton" then
                JP.BossMenu(B, self, h)
            else
                chooseBoss(B, h.text)
            end
        end)
        r:SetScript("OnEnter", function(self)
            local h = self.item
            if not h then return end
            B.art:SetModelNpc(ns.Dungeons.ModelNpc(B.entry, h.b.npc and h.b or h))
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(h.shown or h.text, 1, 0.82, 0)
            GameTooltip:AddLine(BTEXT.bossTip, 0.6, 0.6, 0.6, true)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function()
            hideTip()
            B.art:SetModelNpc(ns.Dungeons.ModelNpc(B.entry))
        end)
    end, fillBossRow)
    V.list:SetPoint("TOPLEFT", 0, 0)
    V.list:SetWidth(BV.LIST_W - T.SCROLL_ROOM)
    W.FillTo(V.list, B, top, BV.MIN_ROWS, BV.ROW_H)
    -- the chosen boss: its portrait, name and line on a dark ground with a gold edge
    local x = BV.LIST_W + BV.GAP
    local head = CreateFrame("Frame", nil, V)
    head:SetPoint("TOPLEFT", x, 0)
    head:SetPoint("TOPRIGHT", -T.SCROLL_ROOM, 0)
    head:SetHeight(BV.HEAD_H)
    W.Flat(head, BV.HEAD_BG[1], BV.HEAD_BG[2], BV.HEAD_BG[3], BV.HEAD_BG[4])
    head.edges = W.Border(head, W.GOLD[1], W.GOLD[2], W.GOLD[3], 0.5)
    head.port = buildPortrait(head, BV.HEAD_PORT)
    head.port:SetPoint("LEFT", BV.HEAD_PORT_X, 0)
    head.name = W.Text(head, T.FONT.big)
    head.name:SetPoint("TOPLEFT", BV.HEAD_TEXT_X, BV.HEAD_NAME_Y)
    head.name:SetPoint("TOPRIGHT", -BV.END, BV.HEAD_NAME_Y)
    head.sub = W.Text(head, T.FONT.text)
    head.sub:SetPoint("TOPLEFT", BV.HEAD_TEXT_X, BV.HEAD_SUB_Y)
    head.sub:SetPoint("TOPRIGHT", -BV.END, BV.HEAD_SUB_Y)
    V.head = head
    -- its loot: the item's icon in its quality's ring, name, slot and gain, drop rate, wish star; clicks
    -- and the menu as on the item rows of the lists
    local lootTop = -(BV.HEAD_H + BV.GAP)
    V.loot = W.List(V, BV.MIN_ROWS, BV.LOOT_H, function(r)
        r.sel = W.SelectBar(r)   -- the item asked for from the gear planner (F-157)
        r.frame = CreateFrame("Frame", nil, r)
        r.frame:SetSize(BV.ICON, BV.ICON)
        r.frame:SetPoint("LEFT", BV.ICON_X, 0)
        r.icon = r.frame:CreateTexture(nil, "ARTWORK")
        r.icon:SetPoint("TOPLEFT", 1, -1)
        r.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        -- the thin rounded ring of the planner's slots (D-81 Nachtrag)
        if ns.GoalsKit then ns.GoalsKit.roundIcon(r.frame, T.PLANNER.DOLL, r.icon) end
        local starX = BV.END
        local rateX = starX + BV.STAR + BV.END
        local textR = rateX + BV.RATE_W + BV.END
        r.name = W.Text(r, T.FONT.text)
        r.name:SetPoint("TOPLEFT", BV.LOOT_TEXT_X, BV.LOOT_NAME_Y)
        r.name:SetPoint("TOPRIGHT", -textR, BV.LOOT_NAME_Y)
        r.sub = W.Text(r, T.FONT.text)
        r.sub:SetPoint("TOPLEFT", BV.LOOT_TEXT_X, BV.LOOT_SUB_Y)
        r.sub:SetPoint("TOPRIGHT", -textR, BV.LOOT_SUB_Y)
        r.rate = W.Text(r, T.FONT.text, BV.RATE_W)
        r.rate:SetPoint("RIGHT", -rateX, 0)
        r.rate:SetJustifyH("RIGHT")
        r.star = CreateFrame("Button", nil, r)
        r.star:SetSize(BV.STAR, BV.STAR)
        r.star:SetPoint("RIGHT", -starX, 0)
        r.star.tex = r.star:CreateTexture(nil, "ARTWORK")
        r.star.tex:SetAllPoints()
        r.star:SetScript("OnClick", function(self)
            local e = self:GetParent().item
            if not (e and e.id) then return end
            if self.on then ns.WishRemove(e.id) else say(ns.WishAdd(e.id)) end
        end)
        r.star:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.on and BTEXT.wishOn or BTEXT.wishOff)
            GameTooltip:Show()
        end)
        r.star:SetScript("OnLeave", hideTip)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetScript("OnClick", function(self, button) itemClick(self, self.item, button) end)
        r:SetScript("OnEnter", function(self) if self.item then itemTip(self, self.item.id) end end)
        r:SetScript("OnLeave", hideTip)
    end, fillLootRow)
    V.loot:SetPoint("TOPLEFT", x, lootTop)
    V.loot:SetPoint("TOPRIGHT", -T.SCROLL_ROOM, lootTop)
    W.FillTo(V.loot, B, top + lootTop, BV.MIN_ROWS, BV.LOOT_H)
    V.none = W.Text(V, T.FONT.dim)
    V.none:SetPoint("TOPLEFT", V.loot, "TOPLEFT", BV.ICON_X, -BV.ICON_X)
    V.none:SetPoint("TOPRIGHT", V.loot, "TOPRIGHT", -BV.END, -BV.ICON_X)
    V.none:SetText(BTEXT.none)
    V.none:Hide()
    return V
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
    scanned = L["nur aus dem Quest-Scan"],
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
-- label's right, shown while the mouse is on the card (D-67) and always on the next step's card.
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
    W.RowAction(c, ln.btn)
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
    W.PinRowActions(c, isNext)
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
        -- placed by the quest scan's text alone (D-109)
        if s.scanned then flags[#flags + 1] = PTEXT.scanned end
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
    V.back = W.Link(V, PTEXT.back, function() B:OpenPath(nil) end)
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
    local quality = T.QUALITY_RGB
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
        -- what it replaces only for an upgrade: for any other reward "upgrade" is false, which
        -- must not read as an empty slot
        local worn
        if it.upgrade then worn = wornText(it.slotKey) end
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

-- The image a of the dungeon e shown, with its name (the journal's and the detail's).
local function showArt(a, e)
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
end

-- The dungeon's image in the journal: name, level and fit, how many quests and how many are open,
-- the run's sum.
local function fillJournalArt(V, e, rows, plan)
    local a = V.art
    if not e then a:Hide() return end
    showArt(a, e)
    local Dn = ns.Dungeons
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
        local from = xpSource(how, seen)
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
            -- the line's area: its "Karte" shows while the mouse is on it (D-67)
            ln.hit = CreateFrame("Frame", nil, V.child)
            ln.btn = W.Button(V.child, PTEXT.card, nil, function(self) say(ns.DungeonRouteWaypoint(self.stop)) end, { height = P.BUTTON_H })
            ln.btn:SetHeight(P.BUTTON_H)
            W.FitChip(ln.btn)
            W.Tooltip(ln.btn, PTEXT.card, PTEXT.cardTip)
            W.RowAction(ln.hit, ln.btn)
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
        -- the button reaches 3 px above its line: the line's area too, so the mouse is on the line
        -- whenever it is on the button (it may overlap the line above by those 3 px)
        ln.hit:ClearAllPoints()
        ln.hit:SetPoint("TOPLEFT", 0, y + 3)
        ln.hit:SetSize(V.bodyW, h + P.LINE_GAP + 3)
        ln.hit:Show()
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
    for i = nLine + 1, #V.runLines do V.runLines[i].fs:Hide(); V.runLines[i].btn:Hide(); V.runLines[i].hit:Hide() end
    for i = nNode + 1, #V.runNodes do V.runNodes[i].icon:Hide(); V.runNodes[i].link:Hide() end
    V.child:SetHeight(math.max(10, -y))
    if V.scroll.UpdateScrollChildRect then V.scroll:UpdateScrollChildRect() end
end

---------------------------------------------------------------------------
-- The start view (F-148, D-74): every dungeon (or raid) as a row of a table, by level range
---------------------------------------------------------------------------

local DT = T.DTABLE
local CARD_TEXT = {
    tag = L["Empfohlen"],
    here = L["Hier bist du"],
    values = L["%d Upgrades · %s je Lauf · Wert %d"],
    soon = "|cffffd100",
    group = L["Stufe %d - %d"],
    count = L["%d Dungeons"], countRaid = L["%d Raids"], one = L["1 Dungeon"], oneRaid = L["1 Raid"],
    name = "Dungeon", level = L["Stufe"], side = L["Gebiet"], zone = "Zone", keys = L["Schlüssel"],
    quests = "Quests", act = L["Aktionen"], size = L["Größe"],
    way = L["Wegpunkt zum Eingang"], wayTip = L["Setzt das Kartenziel auf den nächsten Eingang."],
}

-- The territory of the zones (uiMapID) the factions hold; every other zone is contested. The client
-- tells only the zone one stands in (C_PvP), so the starting zones and capitals are listed here.
local ZONE_SIDE = {
    [1429] = "A", [1426] = "A", [1438] = "A", [1436] = "A", [1432] = "A", [1439] = "A",
    [1453] = "A", [1455] = "A", [1457] = "A",
    [1411] = "H", [1412] = "H", [1420] = "H", [1413] = "H", [1421] = "H",
    [1454] = "H", [1456] = "H", [1458] = "H",
}
-- the crests of the client's target frame (the faction's part of the 64 px texture) and the crossed
-- swords of its world state frame for a contested zone
local SIDE_ART = {
    A = { file = "Interface\\TargetingFrame\\UI-PVP-Alliance", coords = { 0, 0.62, 0, 0.62 } },
    H = { file = "Interface\\TargetingFrame\\UI-PVP-Horde", coords = { 0, 0.62, 0, 0.62 } },
    C = { file = "Interface\\WorldStateFrame\\CombatSwords", coords = { 0, 0.5, 0, 0.5 } },
}
local MAP_ART = "Interface\\WorldMap\\UI-World-Icon"
-- the sorted column's arrow after its name
local SORT_UP, SORT_DOWN = " |TInterface\\Buttons\\Arrow-Up-Up:10:10:0:-2|t", " |TInterface\\Buttons\\Arrow-Down-Up:10:10:0:2|t"
local function hasFile(path) return not (GetFileIDFromPath and GetFileIDFromPath(path) == nil) end

-- The zone of an instance's entrance (uiMapID and name) as the map data knows it; kept per key once known.
local zoneOf = {}
local function instanceZone(key)
    local z = zoneOf[key]
    if z then return z.map, z.name end
    local point = ns.DungeonEntrance and ns.DungeonEntrance(key)
    if not point or not point.map then return nil, nil end
    z = { map = point.map, name = ns.Gear.ZoneName(point.map) or "" }
    zoneOf[key] = z
    return z.map, z.name
end
-- "A", "H" or "C" (contested); nil without a known entrance.
local function instanceSide(key)
    local map = instanceZone(key)
    if not map then return nil end
    return ZONE_SIDE[map] or "C"
end

-- The level text in the quest log's colours: red too high, orange soon, yellow fitting, green easy,
-- grey not yet open.
local FIT_COLOR = { high = "|cffff2020", soon = "|cffff8040", fit = "|cffffff00", easy = "|cff40c040", later = GREY, unknown = GREY }
local function levelText(e)
    local range = ns.Dungeons.RangeText(e)
    if range == "" then return GREY .. "-|r" end
    return (FIT_COLOR[e.fit] or GREY) .. range .. "|r"
end

-- The key icons of an instance (up to two, grey while the character lacks one), or "".
local function keyIcons(key)
    local keys = JP.Keys(key)
    local parts = {}
    for i = 1, math.min(2, keys and #keys or 0) do
        local k = keys[i]
        local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(k.item)
        if icon then
            parts[#parts + 1] = JP.HasItem(k.item) and ("|T%s:%d:%d|t"):format(icon, DT.KEY, DT.KEY)
                or ("|T%s:%d:%d:0:0:64:64:4:60:4:60:110:110:110|t"):format(icon, DT.KEY, DT.KEY)
        end
    end
    return table.concat(parts, " ")
end

-- The column defs of a table (ctx.cols: { key, label, kind = "text"|"side"|"keys"|"act" }) placed at
-- width w: each at its x and width from the right end, the name between the picture and them.
local function placeCols(cols, w)
    local x = w
    for i = #cols, 1, -1 do
        local c = cols[i]
        c.w = DT.WIDTH[c.key] or 50
        x = x - c.w
        c.x = x
        x = x - DT.GAP
    end
    return math.max(40, x - DT.NAME_X)
end

-- A row of the table: an instance (its picture, name and line, the columns' cells) or a level
-- range's group row (sign, name, count). ctx.pick(e) on a click, ctx.tip(row) on the mouse.
local function buildTableRow(r, ctx)
    r.art = r:CreateTexture(nil, "ARTWORK")
    r.art:SetSize(DT.ART_W, DT.ART_H)
    r.art:SetPoint("LEFT", DT.ART_X, 0)
    r.artFrame = CreateFrame("Frame", nil, r)
    r.artFrame:SetAllPoints(r.art)
    r.artFrame.edges = W.Border(r.artFrame, W.GOLD[1], W.GOLD[2], W.GOLD[3], DT.EDGE)
    r.name = W.Text(r, T.FONT.title)
    r.name:SetPoint("LEFT", DT.NAME_X, DT.NAME_Y)
    r.sub = W.Text(r, T.FONT.hint)
    r.sub:SetPoint("LEFT", DT.NAME_X, DT.SUB_Y)
    r.cells = {}
    for _, c in ipairs(ctx.cols) do
        local cell
        if c.kind == "side" then
            cell = r:CreateTexture(nil, "ARTWORK")
            cell:SetSize(DT.SIDE, DT.SIDE)
        elseif c.kind == "act" then
            cell = W.IconButton(r, DT.ACT, hasFile(MAP_ART) and { file = MAP_ART } or {}, function(self)
                if self:GetParent().item then ctx.action(self:GetParent().item) end
            end, "»")
            W.Tooltip(cell, CARD_TEXT.way, CARD_TEXT.wayTip)
        else
            cell = W.Text(r, c.kind == "keys" and T.FONT.text or T.FONT.body)
            cell:SetJustifyH(c.justify or "CENTER")
        end
        r.cells[c.key] = cell
    end
    -- the group row's parts
    r.groupBg = W.Flat(r, DT.GROUP_BG[1], DT.GROUP_BG[2], DT.GROUP_BG[3], DT.GROUP_BG[4], "BACKGROUND")
    r.groupEdges = W.Border(r, W.GOLD[1], W.GOLD[2], W.GOLD[3], DT.EDGE)
    r.sign = r:CreateTexture(nil, "ARTWORK")
    r.sign:SetSize(DT.SIGN, DT.SIGN)
    r.sign:SetPoint("LEFT", DT.SIGN_X, 0)
    r.groupName = W.Text(r, T.FONT.title)
    r.groupName:SetPoint("LEFT", DT.GROUP_X, 0)
    r.groupCount = W.Text(r, T.FONT.text)
    r.groupCount:SetPoint("RIGHT", -DT.GAP - 4, 0)
    r.groupCount:SetJustifyH("RIGHT")
    function r:Place(cols, nameW)
        self.name:SetWidth(nameW)
        self.sub:SetWidth(nameW)
        for _, c in ipairs(cols) do
            local cell = self.cells[c.key]
            cell:ClearAllPoints()
            if c.kind == "side" or c.kind == "act" then
                cell:SetPoint("CENTER", self, "LEFT", c.x + c.w / 2, 0)
            else
                cell:SetWidth(c.w)
                cell:SetPoint("LEFT", c.x, 0)
            end
        end
    end
    r:SetScript("OnClick", function(self)
        local it = self.item
        if not it then return end
        if it.group then ctx.toggle(it.group) else ctx.pick(it) end
    end)
    r:SetScript("OnEnter", function(self) if self.item and not self.item.group then ctx.tip(self) end end)
    r:SetScript("OnLeave", hideTip)
end

local function setSide(tex, side)
    local art = side and SIDE_ART[side]
    if art and hasFile(art.file) then
        tex:SetTexture(art.file)
        tex:SetTexCoord(unpack(art.coords))
        tex:Show()
    else
        tex:Hide()
    end
end

-- Fills row r with item it: a group row, or an instance with ctx.cell(e, key) the text of a text cell
-- and ctx.texts(e) its name, its line and whether it is dim (a desaturated picture, a grey name).
local function fillTableRow(r, it, ctx)
    local group = it.group ~= nil
    for _, f in ipairs({ r.groupBg, r.sign, r.groupName, r.groupCount }) do f:SetShown(group) end
    for _, e in ipairs(r.groupEdges) do e:SetShown(group) end
    r.bg:SetShown(not group)
    r.art:SetShown(false)
    r.artFrame:SetShown(not group)
    for _, f in ipairs({ r.name, r.sub }) do f:SetShown(not group) end
    for _, cell in pairs(r.cells) do cell:SetShown(not group) end
    if group then
        r.sign:SetTexture(it.open and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
        r.groupName:SetText(it.label)
        r.groupCount:SetText(it.countText)
        return
    end
    local e = it
    local Dn = ns.Dungeons
    local fid, kind = Dn.Art(e.key)
    if fid then
        r.art:SetTexture(fid)
        r.art:SetTexCoord(Dn.ArtCoords(kind, DT.ART_W, DT.ART_H))
        r.art:Show()
    end
    local name, sub, dim = ctx.texts(e)
    r.name:SetText(name)
    r.sub:SetText(sub or "")
    r.art:SetDesaturated(dim and true or false)
    if dim then r.name:SetTextColor(0.56, 0.53, 0.64) else r.name:SetTextColor(W.GOLD[1], W.GOLD[2], W.GOLD[3]) end
    -- the instance the character stands in and the chosen one: the brighter frame (D-72)
    local here = ctx.here ~= nil and (ctx.here == e.key or (ctx.hereSet ~= nil and ctx.hereSet[e.key] == true))
    local a = here and 1 or ctx.chosen == e.key and 0.95 or DT.EDGE
    W.SetBorderColor(r.artFrame.edges, W.GOLD[1], W.GOLD[2], W.GOLD[3], a)
    for _, c in ipairs(ctx.cols) do
        local cell = r.cells[c.key]
        if c.kind == "side" then
            setSide(cell, instanceSide(e.key))
        elseif c.kind == "act" then
            cell:SetEnabled(ns.DungeonEntrance(e.key) ~= nil)
        elseif c.kind == "keys" then
            local t = keyIcons(e.key)
            cell:SetText(t ~= "" and t or (GREY .. "-|r"))
        else
            cell:SetText(ctx.cell(e, c.key) or "")
        end
    end
end

-- The table on page B from top down to the page's bottom (it follows the window's height, W.FillTo,
-- and its width, W.FollowWidth): the sortable column heads, then a W.List of the group rows and the
-- instances. ctx: cols, texts, cell, tip, pick, action, group(e) -> key, label, order; sortField (the
-- settings.bis key of the column, its direction in sortField .. "Desc"), sorts[key](e) -> value,
-- grouped() whether the rows go by group (else flat in the given order).
-- tbl:SetEntries(list, chosen, recommended) shows them, tbl:RowOf(key) scrolls that instance into
-- view and returns its row, tbl:JumpTo(group) shows that group at the top, tbl.groups the groups
-- shown ({ key, label, count }), tbl:Rows() the instance rows shown.
local function buildTable(B, top, ctx)
    ctx.shut = ctx.shut or {}
    local tbl
    local heads = { { "name", 0, 100, ctx.nameLabel or CARD_TEXT.name } }
    for _, c in ipairs(ctx.cols) do heads[#heads + 1] = { c.key, 0, 50, c.label, justify = c.kind ~= "keys" and "CENTER" or nil } end
    local function sortBy(key)
        if not ctx.sorts[key] then return end
        local st = state()
        if ctx.onSort then ctx.onSort() end
        if st[ctx.sortField] == key then
            st[ctx.sortField .. "Desc"] = not st[ctx.sortField .. "Desc"] or nil
        else
            st[ctx.sortField], st[ctx.sortField .. "Desc"] = key, nil
        end
        ns.Refresh()
    end
    local headFrame, headCells = B:Columns(heads, { top = top, sort = sortBy })
    tbl = B:List(DT.MIN_ROWS, DT.ROW_H, function(r) buildTableRow(r, ctx) end, function(r, it)
        fillTableRow(r, it, ctx)
        r:Place(ctx.cols, tbl.nameW)
    end, { fill = true })
    tbl.head, tbl.heads, tbl.ctx = headFrame, headCells, ctx
    tbl.entries, tbl.groups = {}, {}
    -- the columns at the list's width now
    local function layout()
        local w = (T.PAGE_W_NOW or T.PAGE_W) - T.SCROLL_ROOM
        tbl.nameW = placeCols(ctx.cols, w)
        local h = headCells.name
        h:SetWidth(DT.NAME_X + tbl.nameW)
        if h.label then h.label:SetWidth(DT.NAME_X + tbl.nameW) end
        for _, c in ipairs(ctx.cols) do
            local b = headCells[c.key]
            b:ClearAllPoints()
            b:SetPoint("LEFT", c.x, 0)
            b:SetWidth(c.w)
            if b.label then b.label:SetWidth(c.w) end
        end
        for i = 1, #tbl.rows do tbl.rows[i]:Place(ctx.cols, tbl.nameW) end
    end
    layout()
    W.FollowWidth(tbl, function() layout() end)
    -- the sorted column's head white with its arrow (none while the rows keep another order)
    local function markHeads(key, desc)
        for k, b in pairs(headCells) do
            local label = k == "name" and (ctx.nameLabel or CARD_TEXT.name) or nil
            for _, c in ipairs(heads) do if c[1] == k then label = c[4] end end
            b.label:SetText(label .. (k == key and (desc and SORT_DOWN or SORT_UP) or ""))
        end
        W.MarkSortHead(headCells, key)
    end
    function ctx.toggle(g)
        ctx.shut[g] = not ctx.shut[g] or nil
        tbl:SetEntries(tbl.entries, ctx.chosen, ctx.recommended)
    end
    function tbl:SetEntries(list, chosen, recommended)
        ctx.chosen, ctx.recommended = chosen, recommended
        self.entries = list or {}
        local st = state()
        local key = ctx.grouped() and st[ctx.sortField] or nil
        if key and not ctx.sorts[key] then key = nil end
        local desc = st[ctx.sortField .. "Desc"] and true or false
        markHeads(key, desc)
        local items, groups = {}, {}
        if not ctx.grouped() then
            for _, e in ipairs(self.entries) do items[#items + 1] = e end
        else
            local byKey, order = {}, {}
            for i, e in ipairs(self.entries) do
                local gk, label, rank = ctx.group(e)
                local g = byKey[gk]
                if not g then
                    g = { key = gk, label = label, rank = rank or 0, list = {} }
                    byKey[gk] = g
                    order[#order + 1] = g
                end
                g.list[#g.list + 1] = { e = e, i = i }
            end
            table.sort(order, function(a, b) return a.rank < b.rank end)
            local f = key and ctx.sorts[key]
            for _, g in ipairs(order) do
                if f then
                    table.sort(g.list, function(a, b)
                        local x, y = f(a.e), f(b.e)
                        if x ~= y then
                            if desc then return x > y end
                            return x < y
                        end
                        return a.i < b.i
                    end)
                end
                local n = #g.list
                local open = not ctx.shut[g.key]
                items[#items + 1] = { group = g.key, label = g.label, open = open, count = n,
                    countText = ctx.countText(n) }
                groups[#groups + 1] = { key = g.key, label = g.label, count = n }
                if open then for _, x in ipairs(g.list) do items[#items + 1] = x.e end end
            end
        end
        self.groups = groups
        self:SetItems(items)
    end
    function tbl:RowOf(key)
        for i, it in ipairs(self.items) do
            if not it.group and it.key == key then
                if i <= self.offset or i > self.offset + self.rowCount then
                    self.offset = math.max(0, math.min(i - 1, #self.items - self.rowCount))
                    self:SetItems(self.items)
                end
                return self.rows[i - self.offset]
            end
        end
        return nil
    end
    function tbl:JumpTo(g)
        if ctx.shut[g] then
            ctx.shut[g] = nil
            self:SetEntries(self.entries, ctx.chosen, ctx.recommended)
        end
        for i, it in ipairs(self.items) do
            if it.group == g then
                self.offset = math.max(0, math.min(i - 1, #self.items - self.rowCount))
                self:SetItems(self.items)
                return true
            end
        end
        return false
    end
    function tbl:Rows()
        local out = {}
        for i, r in ipairs(self.rows) do
            if i <= self.rowCount and r.item and not r.item.group then out[#out + 1] = r end
        end
        return out
    end
    return tbl
end

---------------------------------------------------------------------------
-- The start's filter row and the cards' run (F-146, D-72): shared with the page Raids
---------------------------------------------------------------------------
local FTEXT = {
    search = L["Instanz, Boss, Beute, Quest"],
    all = L["Alle"], fit = L["Passend"], quests = "Quests",
    allTip = L["Alle Instanzen."], fitTip = L["Nur, was zu deinem Level passt."],
    questsTip = L["Nur Dungeons mit offenen, angenommenen oder abgabebereiten Quests."],
    here = L["Wo bin ich"], hereTip = L["Öffnet die Instanz, in der du gerade stehst."],
    nowhere = L["Du bist gerade in keiner Instanz, die Amisia kennt."],
    emptyTitle = L["Nichts gefunden"], empty = L["Keine Instanz passt zu Suche und Auswahl."],
}
local SKULL_MARK = "|T" .. SKULL .. ":12:12|t"
local QMARK = "|TInterface\\GossipFrame\\AvailableQuestIcon:12:12|t"

-- The open quests of a dungeon: those to take, in the log or ready to hand in.
local function openQuests(dkey)
    local n = 0
    for _, q in ipairs((ns.DungeonQuests(dkey))) do
        local st = ns.Dungeons.QuestState(q)
        if st == "open" or st == "active" or st == "ready" then n = n + 1 end
    end
    return n
end

-- The run's kills ("1/4" after the skull), the open quests (withQuests) and, unless noKeys, the keys.
local function runBadge(e, withQuests, noKeys)
    local parts = {}
    local _, n, m = ns.Runs.Of(e.key)
    if n then parts[#parts + 1] = ("%s %d/%d"):format(SKULL_MARK, n, m) end
    if withQuests then
        local q = openQuests(e.key)
        if q > 0 then parts[#parts + 1] = ("%s %d"):format(QMARK, q) end
    end
    -- up to two keys (D-72): their icons, grey while the character lacks them
    local keys = not noKeys and JP.Keys(e.key)
    for i = 1, math.min(2, keys and #keys or 0) do
        local k = keys[i]
        local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(k.item)
        if icon then
            parts[#parts + 1] = JP.HasItem(k.item) and ("|T%s:12:12|t"):format(icon)
                or ("|T%s:12:12:0:0:64:64:4:60:4:60:110:110:110|t"):format(icon)
        end
    end
    return table.concat(parts, "  ")
end

-- Whether entry e matches the search text q (lower case): its name, other names, its bosses, their
-- loot (names the client has cached) and its quests' titles.
local function lowerHas(text, q) return type(text) == "string" and text:lower():find(q, 1, true) ~= nil end
local function matches(e, q, withQuests)
    if lowerHas(e.name, q) then return true end
    local f = ns.Runs.Fact(e.key)
    for _, a in ipairs(f and type(f.aliases) == "table" and f.aliases or {}) do
        if lowerHas(a, q) then return true end
    end
    for _, b in ipairs(f and type(f.order) == "table" and f.order or {}) do
        if lowerHas(b, q) then return true end
    end
    local info = e.computed and e or ns.DungeonInfo(e.key) or e
    for _, b in ipairs(info.bosses or {}) do
        if lowerHas(b.name, q) then return true end
        for _, it in ipairs(b.items or {}) do
            local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(it.id)
            if lowerHas(name, q) then return true end
        end
    end
    if withQuests then
        for _, qn in ipairs((ns.DungeonQuests(e.key))) do
            if lowerHas(qn.title, q) then return true end
        end
    end
    return false
end

-- The entries the filter leaves (B.filter: mode "all"|"fit"|"quests", query from 2 characters).
local function filterEntries(list, flt, withQuests)
    local q = flt.query or ""
    if flt.mode == "all" and #q < 2 then return list end
    local out = {}
    for _, e in ipairs(list) do
        local ok = flt.mode ~= "fit" or e.fit == "fit"
        if ok and flt.mode == "quests" then ok = openQuests(e.key) > 0 end
        if ok and #q >= 2 then ok = matches(e, q, withQuests) end
        if ok then out[#out + 1] = e end
    end
    return out
end

-- The filter row in band i of page B: the search box filling the band's left, the choice tabs and
-- "Wo bin ich" at its right. opts.quests: the choice Quests too; opts.here(key): opens that key.
-- B.filter (only in memory), B.search, B.filterTabs, B.hereLink, B.filterParts; B.emptyGrid the
-- empty state under the grid.
local function buildFilter(B, i, opts)
    B.filter = { mode = "all", query = "" }
    local function setQuery(text)
        local q = (tostring(text or ""):match("^%s*(.-)%s*$") or ""):lower()
        if q ~= B.filter.query then
            B.filter.query = q
            ns.Refresh()
        end
    end
    B.search = W.SearchBox(B, nil, setQuery, FTEXT.search)
    B.search:HookScript("OnTextChanged", function(self, user) if user then setQuery(self:GetText()) end end)
    if B.search.clearButton then B.search.clearButton:HookScript("OnClick", function() setQuery("") end) end
    local modes = { { "all", FTEXT.all, FTEXT.allTip }, { "fit", FTEXT.fit, FTEXT.fitTip } }
    if opts.quests then modes[#modes + 1] = { "quests", FTEXT.quests, FTEXT.questsTip } end
    B.filterTabs = {}
    local right = {}
    for _, m in ipairs(modes) do
        local tab = W.Tab(B, m[2], function()
            B.filter.mode = m[1]
            ns.Refresh()
        end)
        W.Tooltip(tab, m[2], m[3])
        B.filterTabs[m[1]] = tab
        right[#right + 1] = tab
    end
    B.hereLink = W.Link(B, FTEXT.here, function()
        local key = ns.Runs.Here()
        if key then opts.here(key) else ns.msg(FTEXT.nowhere) end
    end)
    W.Tooltip(B.hereLink, FTEXT.here, FTEXT.hereTip)
    right[#right + 1] = { B.hereLink, gap = T.LAYOUT.ITEM_GAP }
    B:Place(i, { { B.search, fill = true } }, right)
    B.filterParts = { B.search, B.hereLink }
    for _, m in ipairs(modes) do B.filterParts[#B.filterParts + 1] = B.filterTabs[m[1]] end
end

-- The filter row's state on the screen and the entries it leaves (the page shows its empty state).
local function applyFilter(B, list, withQuests)
    for k, tab in pairs(B.filterTabs) do tab:SetOn(k == B.filter.mode) end
    local out = filterEntries(list, B.filter, withQuests)
    if B.emptyGrid then B.emptyGrid:Set(FTEXT.emptyTitle, FTEXT.empty) end
    return out
end

-- The instance the character stands in, once per entry (D-72, ns.Runs.entry): its key the first
-- time the page refreshes after the entry, else nil. The page opens its detail then: on its first
-- show inside, and when the character enters while it is open.
local held = {}   -- [isRaid] = the entry a ShowDungeon/ShowRaid used up (it chose another instance)

-- The key stood in for the list (ns.Runs.Here) and, while a map of several dungeons does not tell
-- which one the character is in (no kill since entering, D-106), the set of all of them: each says
-- "Hier bist du".
local function hereCtx(ctx)
    local k, sure, keys = ns.Runs.Here()
    ctx.here, ctx.hereSet = k, nil
    if k and not sure and keys and #keys > 1 then
        ctx.hereSet = {}
        for _, x in ipairs(keys) do ctx.hereSet[x] = true end
    end
end
local function holdHere(isRaid) held[isRaid] = ns.Runs.entry end
local function newHere(B, isRaid)
    if held[isRaid] == ns.Runs.entry then B.lastEntry = ns.Runs.entry end
    local here = ns.Runs.Here()
    if not here or ns.Dungeons.IsRaid(here) ~= isRaid or B.lastEntry == ns.Runs.entry then return nil end
    B.lastEntry = ns.Runs.entry
    return here
end

-- A dungeon's row (F-148): its name with its place in the order ("1. "), the line under it (the run,
-- "Hier bist du", "Empfohlen", the upgrades and gain per run); dim when too high, too easy or later.
local function dungeonTexts(e, ctx)
    local raid = e.kind == "raid" and (" (Raid%s)"):format(e.size and (" " .. e.size) or "") or ""
    local name = (e.rank and (e.rank .. ". ") or "") .. e.name .. raid
    local parts = {}
    if ctx.here == e.key or (ctx.hereSet and ctx.hereSet[e.key]) then parts[#parts + 1] = GREEN .. CARD_TEXT.here .. "|r" end
    local badge = runBadge(e, false, true)
    if badge ~= "" then parts[#parts + 1] = badge end
    if ctx.recommended == e.key then parts[#parts + 1] = GREEN .. CARD_TEXT.tag .. "|r" end
    if e.computed then
        parts[#parts + 1] = CARD_TEXT.values:format(e.upgrades, e.perRun > 0 and signed(e.perRun) or "0",
            math.floor((e.chainValue or e.value) + 0.5))
    end
    return name, table.concat(parts, " · "), e.fit == "high" or e.fit == "easy" or e.fit == "later"
end

-- The level range of a dungeon in tens ("Stufe 20 - 29"), for the table's groups and the side bar.
local function levelGroup(e)
    local lo = math.floor((e.min or 0) / 10) * 10
    return "L" .. lo, CARD_TEXT.group:format(math.max(1, lo), lo + 9), lo
end

-- The view of the page: "start" (the cards) until a card is clicked or a dungeon is asked for, then
-- "detail" (the image, the bosses or quests); only in memory, the first open of a session starts.
local view = "start"

-- The head row by the view: the start's order tabs on the right, the detail's back link on the left.
-- The head row by view: the order tabs at the start, the link back before the spec in the detail, the
-- spec alone in the journal (the link is hidden there and would leave its room empty).
local function placeHead(B, mode)
    if B.headView == mode then return end
    B.headView = mode
    if mode == "detail" then
        B:Place(1, { B.back, B.spec }, {})
    elseif mode == "journal" then
        B:Place(1, { B.spec }, {})
    else
        B:Place(1, { B.spec }, B.sortRow)
    end
end

-- The tabs and links at the right end of the bosses' header line (B.partRow, the hidden ones passed
-- over) and the header up to them; a tab or link whose word changes places them again.
local function placeParts(B, headerTop)
    local reach = W.Row(B, B.partRow, T.CHIP_GAP, 0, headerTop - 1, { right = true, shown = true })
    for _, x in ipairs(B.partRow) do
        local f = type(x) == "table" and x[1] or x
        if f.isTab then f.replace = function() placeParts(B, headerTop) end end
    end
    B.header:SetPoint("TOPRIGHT", -(reach + T.LAYOUT.GAP), headerTop)
end

local function create(parent)
    -- the head row: the spec (the gear page's) with the order chips (start) or the link back to the
    -- cards (detail); the recommendation, why and the cards (start); the image, the bosses or quests
    -- (detail); the hint behind the "i"
    local B = W.Page(parent)
    page = B
    -- the head row, the filter row (D-72), the recommendation, why
    B:Bands({ "row", "row", "row", { "line", lines = 2 } })
    B.back = W.Link(B, L["< Alle Dungeons"], function()
        view = "start"
        ns.Refresh()
    end)
    W.Tooltip(B.back, L["Alle Dungeons"], L["Zurück zur Liste aller Dungeons."])
    B.spec = K.specPicker(B)
    B.next = W.Text(B, T.FONT.title)
    B.why = B:Line(4)
    -- the order of the list: by level, by value (the ranking), the chain
    B.sorts = {}
    local sortDefs = { { "level", "Level", L["Nach Level"], L["Die Dungeons nach ihrem Levelbereich."] },
        { "value", L["Wert"], L["Rangliste"], L["Die lohnendsten Dungeons für dich zuerst: offene Quests plus zwei Läufe."] },
        { "chain", L["Kette"], L["Kette"], L["Der beste Dungeon, seine Upgrades gedanklich angelegt (je Boss das größte, alle Quest-Upgrades), dann der beste danach, bis zu fünf."] } }
    local sortRow = {}
    for i, d in ipairs(sortDefs) do
        local chip = W.Tab(B, d[2], function()
            state().dsort = d[1]
            ns.Refresh()
        end)
        W.Tooltip(chip, d[3], d[4])
        B.sorts[d[1]] = chip
        sortRow[i] = chip
    end
    -- the spec, the order chips at the right edge (in the order of sortDefs); the recommendation
    -- under them, as wide as the page
    B.sortRow = sortRow
    placeHead(B, "start")
    -- the search, the choice and "Wo bin ich" over the recommendation (D-72)
    buildFilter(B, 2, { quests = true, here = function(key) ns.ShowDungeon(key) end })
    B:Place(3, { { B.next, fill = true } })
    B:Footer({ { "hint", lines = 2, help = true } })
    -- the start: the table under the recommendation, down to the page's bottom (F-148); a click
    -- chooses the dungeon and opens its detail view
    local sideRank = { A = 1, C = 2, H = 3 }
    local tctx
    tctx = { cols = {
            { key = "level", label = CARD_TEXT.level },
            { key = "side", label = CARD_TEXT.side, kind = "side" },
            { key = "zone", label = CARD_TEXT.zone, justify = "LEFT" },
            { key = "keys", label = CARD_TEXT.keys, kind = "keys" },
            { key = "quests", label = CARD_TEXT.quests },
            { key = "act", label = CARD_TEXT.act, kind = "act" } },
        texts = function(e) return dungeonTexts(e, tctx) end,
        cell = function(e, key)
            if key == "level" then return levelText(e) end
            if key == "zone" then return select(2, instanceZone(e.key)) or (GREY .. "-|r") end
            if key == "quests" then
                local n = openQuests(e.key)
                return n > 0 and tostring(n) or (GREY .. "-|r")
            end
        end,
        tip = dungeonTip,
        pick = function(e)
            state().dungeon = e.key
            view = "detail"
            ns.Refresh()
        end,
        action = function(e) say(ns.DungeonWaypoint(e.key)) end,
        group = levelGroup,
        countText = function(n) return n == 1 and CARD_TEXT.one or CARD_TEXT.count:format(n) end,
        grouped = function() return (state().dsort or "level") == "level" end,
        -- a click on a column head sorts by it inside the level ranges
        onSort = function() state().dsort = "level" end,
        sortField = "dcol",
        sorts = {
            name = function(e) return e.name end,
            level = function(e) return (e.min or 0) * 100 + (e.max or 0) end,
            side = function(e) return sideRank[instanceSide(e.key) or "C"] end,
            zone = function(e) return select(2, instanceZone(e.key)) or "~" end,
            quests = function(e) return openQuests(e.key) end,
        } }
    B.table = buildTable(B, B.top, tctx)
    B.emptyGrid = B:Empty(nil, B.table)
    -- the detail: the image right under the head row, the bosses' or quests' header under it, then
    -- their list down to the page's bottom
    local G = T.LAYOUT
    local artTop = -(G.ROW_H + G.GAP)
    B.art = buildArt(B, artTop)
    -- the tabs under the image (D-72), the part's header under them
    local tabTop = artTop - ART_H - G.GAP
    local headerTop = tabTop - G.ROW_H - G.GAP
    B.mark = W.Link(B.art, DTEXT.mark, function()
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
        B.pathFor = { dungeon = B.chosen, key = "run", part = JP.PartOf(B, B.entry) }
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
    -- the parts of the detail as tabs under the image (D-72): Übersicht (the bosses and their loot),
    -- Karte, Quests, Wunschliste, Zugang (only with a key); the last one stays in settings.bis.dpart
    JP.BuildTabs(B, tabTop, { "bosses", "map", "quests", "wish", "access", "times" }, "dpart")
    B.way = W.Link(B, L["Wegpunkt"], function()
        if B.chosen then say(ns.DungeonWaypoint(B.chosen)) end
    end)
    W.Tooltip(B.way, L["Wegpunkt zum Eingang"], L["Setzt das Kartenziel auf den nächsten Eingang des gewählten Dungeons."])
    -- the run (D-72): "1/4" with its bar and "Lauf zurücksetzen", only in the part Übersicht, at the
    -- right end of the header's line; the waypoint at the tabs' right end
    JP.BuildRun(B)
    -- the times (F-166): the list where the others are, "Zeiten löschen" in the header's line
    JP.BuildTimes(B, headerTop - T.HEADER_H - G.GAP)
    B.partRow = { B.runBar, { B.resetRun, gap = G.ITEM_GAP }, { B.clearTimes, gap = G.ITEM_GAP } }
    function B:PlaceParts() placeParts(self, headerTop) end
    W.Row(B, { B.way }, 0, 0, tabTop - 1, { right = true })
    B:PlaceParts()
    B.detail = buildDetail(B, DETAIL_ROWS, headerTop - T.HEADER_H - G.GAP)
    B.detail:SetPoint("TOPLEFT", 0, headerTop - T.HEADER_H - G.GAP)
    B.detail:SetPoint("TOPRIGHT", -T.SCROLL_ROOM, headerTop - T.HEADER_H - G.GAP)
    -- the bosses and the chosen one's loot (F-154), the instance map and the keys (D-72), where the list is
    buildBossView(B, headerTop - T.HEADER_H - G.GAP)
    JP.BuildMap(B, headerTop - T.HEADER_H - G.GAP)
    JP.BuildAccess(B, headerTop - T.HEADER_H - G.GAP)
    -- the quest path in place of the list, the image and the quests (F-135); only in memory
    B.pathView = buildPath(B)
    -- the journal remembers the part it was opened from (the planner's quests or bosses)
    local function partNow() return JP.PartOf(B, B.entry) end
    function B:OpenPath(e)
        if e and e.kind == "run" then
            self.pathFor = { dungeon = state().dungeon, key = "run", part = partNow() }
        elseif e and e.q then
            self.pathFor = { dungeon = state().dungeon, key = e.qid or e.q.title, part = partNow() }
        else
            self.pathFor = nil
        end
        self.detailKey = nil
        -- the journal opens from the detail view and goes back to it
        view = "detail"
        ns.Refresh()
    end
    -- the parts of the start and of the detail view; the quest journal covers them all (planParts)
    B.startParts = { B.next, B.why, B.table, B.table.head }
    for _, f in ipairs(B.filterParts) do B.startParts[#B.startParts + 1] = f end
    B.detailParts = { B.back, B.art, B.header, B.way, B.detail }
    for _, k in ipairs(B.partKeys) do B.detailParts[#B.detailParts + 1] = B.parts[k] end
    -- shown by the part (refresh): the run's parts, the bosses, the map and the keys
    B.planParts = { B.emptyGrid, B.runBar, B.resetRun, B.bossView, B.mapView, B.accessView, B.timesView, B.clearTimes }
    for _, f in ipairs(B.startParts) do B.planParts[#B.planParts + 1] = f end
    for _, f in ipairs(B.detailParts) do B.planParts[#B.planParts + 1] = f end
    for _, chip in ipairs(sortRow) do B.planParts[#B.planParts + 1] = chip end
    return B
end

-- The image, its texts, the boss model and the mark button of the chosen dungeon e.
local function fillArt(B, e)
    local a = B.art
    if not e then
        a:Hide()
        return
    end
    showArt(a, e)
    local Dn = ns.Dungeons
    local range = Dn.RangeText(e)
    a.info:SetText(range ~= "" and DTEXT.level:format(range, Dn.FitText(e)) or Dn.FitText(e))
    a:SetModelNpc(Dn.ModelNpc(e))
    if B.mark then B.mark:SetText(ns.DungeonMarked() == e.key and DTEXT.unmark or DTEXT.mark) end
end

local function refresh(B)
    K.namesFresh()
    K.fillSpec(B.spec, ns.BisOpts())
    -- in a dungeon (its first show there, or entered while open): its detail (D-72)
    local here = newHere(B, false)
    if here then
        state().dungeon = here
        asked = here
        view = "detail"
        B.pathFor = nil
    end
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
    hereCtx(B.table.ctx)
    local filtered = applyFilter(B, shown, true)
    B.table:SetEntries(filtered, B.chosen, nextE and nextE.key or nil)
    if e and not e.computed then e = ns.DungeonInfo(e.key) or e end
    B.entry = e
    local detail = view == "detail" and e ~= nil
    -- back on the start: the chosen row in view
    if not detail and B.wasDetail and B.chosen then B.table:RowOf(B.chosen) end
    B.wasDetail = detail
    if detail then fillArt(B, e) else B.art:Hide() end
    local part = JP.PartOf(B, e)
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
    -- the parts of the view (the image shows by fillArt above, only for a dungeon); the journal
    -- covers both views
    local journal = path or run
    for _, f in ipairs(B.planParts) do
        if f ~= B.art then f:Hide() end
    end
    if not journal then
        for _, f in ipairs(detail and B.detailParts or B.startParts) do
            if f ~= B.art then f:Show() end
        end
        if not detail then
            for _, chip in ipairs(B.sortRow) do chip:Show() end
            B.emptyGrid:SetShown(#filtered == 0 and #shown > 0)
        end
        -- the part's view (D-72): the list, the map or the keys; the tabs (Zugang only with a key)
        if detail then
            B.parts.access:SetShown(JP.Keys(e.key) ~= nil)
            B.parts.times:SetShown(ns.Runs.Encounters(e.key) ~= nil)
            JP.PlaceTabs(B)
            B.detail:SetShown(part == "quests" or part == "wish")
            B.bossView:SetShown(part == "bosses")
            B.mapView:SetShown(part == "map")
            B.accessView:SetShown(part == "access")
            B.timesView:SetShown(part == "times")
        end
        JP.FillRun(B, detail and e or nil, part == "bosses")
        JP.FillTimes(B, detail and e or nil, detail and part == "times")
        B:PlaceParts()
    else
        B.art:Hide()
    end
    placeHead(B, journal and "journal" or detail and "detail" or "start")
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
        -- the party's state of these quests: asked for while a member's is missing (F-178)
        if ns.GroupQuests then ns.GroupQuests.Look(e.key) end
        rows, status = questItems(e.key)
        B.header:SetHeaderText("Quests")
        B.detail:SetItems(rows)
        B.way:SetEnabled(ns.DungeonEntrance(e.key) ~= nil)
    elseif e and part == "wish" then
        B.header:SetHeaderText(L["Wunschliste"])
        B.detail:SetItems(wishItems(e))
        B.way:SetEnabled(ns.DungeonEntrance(e.key) ~= nil)
    elseif e and part == "map" then
        B.header:SetHeaderText(L["Karte"])
        JP.FillMap(B, e)
        B.way:SetEnabled(ns.DungeonEntrance(e.key) ~= nil)
    elseif e and part == "access" then
        B.header:SetHeaderText(L["Zugang"])
        JP.FillAccess(B, e)
        B.way:SetEnabled(ns.DungeonEntrance(e.key) ~= nil)
    elseif e and part == "times" then
        B.header:SetHeaderText(L["Zeiten"])
        B.way:SetEnabled(ns.DungeonEntrance(e.key) ~= nil)
    elseif e then
        B.header:SetHeaderText(L["Bosse"])
        showBosses(B, e)
        B.way:SetEnabled(ns.DungeonEntrance(e.key) ~= nil)
    else
        B.header:SetHeaderText("")
        showBosses(B, nil)
        B.way:SetEnabled(false)
    end
    local hint
    if part == "quests" then
        hint = Dn.QuestStatusText(status) or ""
        if e and #B.detail.items == 0 and hint == "" then hint = L["Für diesen Dungeon kennt Amisia keine Quests."] end
        local xp = e and Dn.XPSumText(Dn.XPSum((ns.DungeonQuests(e.key)))) or ""
        local parts = {}
        local grp = ns.GroupQuests and #ns.GroupQuests.Members() > 0
            and L["Rechts je Mitglied ein Zeichen (Maus auf die Zeile: wer was hat; grau mit \"?\": unbekannt)."] or ""
        for _, t in ipairs({ xp, hint, L["Klick auf eine Quest: ihr Questweg mit allen Schritten. Weg: erledigte Schritte von allen. Grün: Upgrade für dich."], grp }) do
            if t ~= "" then parts[#parts + 1] = t end
        end
        hint = table.concat(parts, " ")
    elseif part == "wish" then
        hint = (#B.detail.items == 0 and (L["Aus dieser Instanz wünschst du dir nichts."] .. " ") or "") .. WISH_HINT
    elseif part == "map" or part == "access" then
        hint = part == "map" and MAP_HINT or ACCESS_HINT
    elseif part == "times" then
        hint = JP.TIMES_HINT
    else
        hint = L["Je Lauf: Zuwachs der Upgrades mal Dropchance, ohne Mitbewerber in der Gruppe. Wert: offene Dungeon-Quests plus zwei Läufe."]
        if e and e.computed and #B.bossView.list.items == 0 then hint = L["In diesem Dungeon gibt es nichts mehr für dich."] .. " " .. hint end
        hint = hint .. " " .. DTEXT.bossHint .. " " .. DTEXT.itemHint
    end
    if not detail then
        hint = L["Klick auf eine Zeile: Bild, Bosse, Beute und Quests des Dungeons. Klick auf einen Spaltenkopf: sortieren, auf einen Stufenbereich: auf- und zuklappen."] .. " " ..
            L["Je Lauf: Zuwachs der Upgrades mal Dropchance, ohne Mitbewerber in der Gruppe. Wert: offene Dungeon-Quests plus zwei Läufe."]
    end
    B.hint:SetText(hint)
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------

-- Opens the page Dungeons with that dungeon or raid chosen (a click on its entrance on the world
-- map). While the world map shows, the window stays under it (F-011). Returns true when the window
-- shows.
-- part: the part to show ("times" for /amisia zeiten, F-166), else the last one.
function ns.ShowDungeon(key, part)
    if type(key) ~= "string" then return false end
    -- a raid opens on the page Raids
    if ns.ShowRaid and ns.Dungeons.IsRaid(key) then return ns.ShowRaid(key, part) end
    holdHere(false)   -- asked for: no jump to the instance stood in (D-72)
    state().dungeon = key
    if part then state().dpart = part end
    asked = key
    view = "detail"
    if ns.ShowPage then ns.ShowPage("dungeons") end
    local main, map = _G.AmisiaFrame, _G.WorldMapFrame
    if main and map and map.IsShown and map:IsShown() and ns.MapLowerMain then
        ns.MapLowerMain(map, main)
        if map.Raise then map:Raise() end
    end
    return main ~= nil and main:IsShown() and true or false
end

-- Opens the dungeon or raid key at the boss that drops item id, its loot row marked (F-157: a click
-- on the source symbol of the gear planner). Returns true when the window shows.
function ns.ShowDungeonItem(key, id)
    if type(key) ~= "string" then return false end
    focus = type(id) == "number" and { key = key, id = id, scroll = true } or nil
    if ns.Dungeons.IsRaid(key) then return ns.ShowRaid ~= nil and ns.ShowRaid(key, "bosses") or false end
    state().dpart = "bosses"
    return ns.ShowDungeon(key)
end

-- Opens the dungeon or raid key on the part Übersicht with its i-th boss of the game's order chosen
-- (F-168: a click on a boss in the dungeon bar). Returns true when the window shows.
function ns.ShowDungeonBoss(key, i)
    if type(key) ~= "string" then return false end
    focus = type(i) == "number" and { key = key, boss = i } or nil
    if ns.Dungeons.IsRaid(key) then return ns.ShowRaid ~= nil and ns.ShowRaid(key, "bosses") or false end
    state().dpart = "bosses"
    return ns.ShowDungeon(key)
end

-- Opens the page Dungeons with the quest path of quest qid of dungeon key (F-135). Returns true when
-- the window shows.
function ns.ShowDungeonQuest(key, qid)
    if type(key) ~= "string" then return false end
    holdHere(false)
    state().dungeon = key
    state().dpart = "quests"
    asked = key
    view = "detail"
    if ns.ShowPage then ns.ShowPage("dungeons") end
    if page then
        page.pathFor = { dungeon = key, key = qid, part = "quests" }
        page.detailKey = nil
        ns.Refresh()
    end
    -- from a pin of the world map (F-179): the window stays under the map, as ns.ShowDungeon keeps it
    local main, map = _G.AmisiaFrame, _G.WorldMapFrame
    if main and map and map.IsShown and map:IsShown() and ns.MapLowerMain then
        ns.MapLowerMain(map, main)
        if map.Raise then map:Raise() end
    end
    return main ~= nil and main:IsShown() and true or false
end

-- the own run changed (a kill, an entry, a reset; Gear/Runs.lua): the cards and the bosses (D-72)
ns.Listen("RUN", function() if ns.RefreshSoon then ns.RefreshSoon() end end)
-- a member's quest state came or went (F-178)
ns.Listen("GROUP_QUESTS", function() if ns.RefreshSoon then ns.RefreshSoon() end end)

-- the journal parts the page Raids shares (UI/Pages/RaidJournal.lua)
ns.DungeonJournalKit = { buildArt = buildArt, fillArt = fillArt, buildDetail = buildDetail,
    buildTable = buildTable, levelText = levelText, instanceZone = instanceZone, instanceSide = instanceSide, wishItems = wishItems, WISH_HINT = WISH_HINT, MAP_HINT = MAP_HINT, ACCESS_HINT = ACCESS_HINT,
    buildFilter = buildFilter, holdHere = holdHere, hereCtx = hereCtx, applyFilter = applyFilter, runBadge = runBadge, newHere = newHere, ART_H = ART_H, itemHint = DTEXT.itemHint, bossHint = DTEXT.bossHint, signed = signed,
    -- the bosses and the chosen one's loot (F-154)
    buildBossView = buildBossView, showBosses = showBosses, placeParts = placeParts }

ns.RegisterPanel{ key = "dungeons", label = "Dungeons", sub = L["Was dir jeder Dungeon bringt: Bosse, Beute und Quests."], icon = ICON, order = 51, group = "dungeons",
    available = function() return ns.Gear.Available() end,
    create = create, refresh = refresh,
    -- the level ranges of the table in the side bar while the start shows (D-74)
    jumps = function(B) return B.table and B.table:IsShown() and B.table.groups or {} end,
    jump = function(B, key) if B.table then B.table:JumpTo(key) end end }
end)
