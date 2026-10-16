-- Dungeons page (tab Ausrüstung, right after the gear page): the dungeon planner. The spec of the
-- gear page in the head row with the order of the list (by level, the ranking, the chain); the next
-- dungeon with its reason; every dungeon's value; the chosen one's image with its boss model, its
-- bosses and upgrades or its quests with pre-quests, start, XP and rewards; the waypoints to its
-- entrance and quest givers and "Alle Questgeber auf der Karte". The values come from Gear/Dungeons.lua;
-- item texts, marks, tooltips, clicks, menus and the cache are the gear page's (ns.GearPageKit).
-- The state stays in settings.bis (dungeon, dsort, dpart).
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

-- The chosen dungeon: the saved one while the list has it, a raid below the level cap that
-- ns.ShowDungeon asked for (the list holds raids from the cap on), else the recommended, else the
-- first.
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

-- The quest rows of a dungeon: per quest a row, its pre-quests and its gear rewards below it.
-- list, status as ns.DungeonQuests gives them.
local function questItems(key)
    local c = cached()
    c.qdetail = c.qdetail or {}
    local list, status = ns.DungeonQuests(key)
    local kept = c.qdetail[key]
    if kept and kept.list == list then return kept.out, status end
    local out = {}
    for _, q in ipairs(list) do
        out[#out + 1] = { kind = "quest", text = q.title .. (q.done and L[" (erledigt)"] or q.gone and L[" (nicht mehr möglich)"] or ""),
            q = q, qid = q.qid }
        for _, n in ipairs(q.chain) do
            out[#out + 1] = { kind = "pre", q = n, qid = n.qid }
        end
        for _, r in ipairs(q.rewards) do
            out[#out + 1] = { kind = "reward", id = r.id, it = r, owned = r.owned }
        end
    end
    c.qdetail[key] = { list = list, out = out }
    return out, status
end

local STATE_TEXT = { done = L["erledigt"], active = L["im Log"], gone = L["nicht mehr möglich"] }
local function questState(n) return n.done and "done" or n.active and "active" or n.gone and "gone" or nil end

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

local function fillDetailRow(r, e)
    r.xp:SetText("")
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
        -- a quest or one of its pre-quests: state, title, level, where it starts
        local q, pre = e.q, e.kind == "pre"
        local st = questState(q)
        local title = pre and ("   " .. L["Vorquest: %s"]:format(q.title) .. (q.one and L[" (oder eine andere)"] or "")) or (GOLD_TEXT .. e.text .. "|r")
        local over = q.done or q.gone
        r.name:SetText((over and (GREY .. title .. "|r")) or title)
        r.slot:SetText(questLevelText(q))
        r.gain:SetText(not pre and q.best and ((over and GREY or GREEN) .. signed(q.best.gain) .. "|r") or "")
        local where = ns.Dungeons.QuestStartText(q)
        r.rate:SetText((st and (GREY .. STATE_TEXT[st] .. "|r" .. (where ~= "" and " · " or "")) or "") .. where)
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
    GameTooltip:AddLine(st and STATE_TEXT[st] or L["offen"], 0.85, 0.85, 0.85)
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
    for _, n in ipairs(q.chain or {}) do
        GameTooltip:AddLine(L["Vorquest: %s"]:format(n.title) .. (n.done and L[" (erledigt)"] or ""), 0.6, 0.6, 0.6, true)
    end
    if q.start ~= "X" then GameTooltip:AddLine(L["Klick: Wegpunkt zum Start"], 0.31, 0.82, 0.42) end
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

    B.header = W.SectionHeader(B, "", false)
    B.header:SetPoint("TOPLEFT", 0, headerTop)
    B.header:SetPoint("TOPRIGHT", -244, headerTop)
    -- the lower part: the bosses or the quests of the chosen dungeon
    B.parts = {}
    B.parts.bosses = W.Chip(B, L["Bosse"], 54, function() state().dpart = "bosses"; ns.Refresh() end)
    B.parts.quests = W.Chip(B, "Quests", 54, function() state().dpart = "quests"; ns.Refresh() end)
    W.Tooltip(B.parts.quests, "Quests", L["Die Quests des Dungeons mit Vorquests, Start und Belohnungen. Klick auf eine Quest setzt den Wegpunkt zum Questgeber."])
    B.way = W.Button(B, L["Wegpunkt"], 120, function()
        if B.chosen then say(ns.DungeonWaypoint(B.chosen)) end
    end)
    -- the two chips and the waypoint button at the right end of the header's line
    W.Row(B, { B.parts.bosses, B.parts.quests, { B.way, gap = G.ITEM_GAP } }, T.CHIP_GAP, 0, headerTop - 1, { right = true })
    W.Tooltip(B.way, L["Wegpunkt zum Eingang"], L["Setzt das Kartenziel auf den nächsten Eingang des gewählten Dungeons."])
    B.detail = W.List(B, DETAIL_ROWS, ROW_H, function(r)
        r.name = col(r, 4, 220, nil, T.FONT.text)
        r.slot = col(r, 228, 62, nil, T.FONT.text)
        r.gain = col(r, 292, 40, nil, T.FONT.text)
        r.gain:SetJustifyH("RIGHT")
        r.xp = col(r, 336, 56, nil, T.FONT.text)
        r.xp:SetJustifyH("RIGHT")
        r.rate = col(r, 398, 188, nil, T.FONT.text)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetScript("OnClick", function(self, button)
            local e = self.item
            if not e then return end
            if (e.kind == "quest" or e.kind == "pre") and e.qid and button ~= "RightButton" then
                say(ns.DungeonQuestWaypoint(e.qid))
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
    B.detail:SetPoint("TOPLEFT", 0, headerTop - T.HEADER_H - G.GAP)
    B.detail:SetPoint("TOPRIGHT", -T.SCROLL_ROOM, headerTop - T.HEADER_H - G.GAP)
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
    B.mark:SetText(ns.DungeonMarked() == e.key and DTEXT.unmark or DTEXT.mark)
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
        for _, t in ipairs({ xp, hint, L["Klick auf eine Quest: Wegpunkt zum Questgeber. Grün: Upgrade für dich."], DTEXT.itemHint }) do
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

ns.RegisterPanel{ key = "dungeons", label = "Dungeons", icon = ICON, order = 51, group = "gear",
    available = function() return ns.Gear.Available() end,
    create = create, refresh = refresh }
