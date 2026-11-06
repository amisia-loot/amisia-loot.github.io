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
    GameTooltip:AddLine(L["Klick: der Questweg mit allen Schritten"], 0.31, 0.82, 0.42)
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
    back = L["< Zurück zu den Quests"],
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
    info = L["Dungeon-Quest · %s · Stufe %s"],
    progress = L["Weg: %d von %d Schritten erledigt"],
    nextStep = L["Nächster Schritt:"],
    rewards = L["Belohnung:"],
    cut = L["(%d frühere Schritte nicht gezeigt)"],
    hint = L["Karte: Weltkarte und Wegpunkt zu diesem Schritt (nicht in Instanzen und im Kampf). Grau: erledigt; hervorgehoben: der nächste Schritt."],
}
local P = {
    PAD = 8, ICON = 16, TEXT_X = 30, LABEL_W = 88, LINE = 12, LINE_GAP = 3, HEAD_H = 26, AFTER_H = 22, BUTTON_H = T.ROW_BUTTON_H,
}

-- How many lines a wrapped font string takes at width w (the client's height where it knows it).
local function textHeight(fs, w)
    local full = fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth() or 0
    local lines = math.max(1, math.ceil(full / math.max(1, w)))
    return math.max(fs:GetStringHeight() or 0, lines * P.LINE)
end

-- One line of a step card: a gold label, the text (wrapped) and a red button "Karte".
local function cardLine(c, onMap)
    local ln = {}
    ln.label = W.Text(c, T.FONT.text, P.LABEL_W)
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

-- Fills line ln of card c at y: label, text, the map button for (what, qid) when a place is known.
-- Returns the y under the line.
local function fillLine(c, ln, y, label, value, what, qid, width)
    ln.label:ClearAllPoints()
    ln.value:ClearAllPoints()
    ln.btn:ClearAllPoints()
    ln.label:SetText(label or "")
    ln.label:SetShown(label ~= nil)
    local x = label and (P.TEXT_X + P.LABEL_W + 4) or P.TEXT_X
    local right = P.PAD + (what and (ln.btn:GetWidth() + 6) or 0)
    local w = width - x - right
    ln.value:SetWidth(w)
    ln.value:SetText(value)
    ln.label:SetPoint("TOPLEFT", P.TEXT_X, y - 1)
    ln.value:SetPoint("TOPLEFT", x, y - 1)
    ln.value:Show()
    local h = textHeight(ln.value, w)
    if what then
        ln.btn.what, ln.btn.qid = what, qid
        ln.btn:SetPoint("TOPRIGHT", -P.PAD, y + 4)
        ln.btn:Show()
        h = math.max(h, P.BUTTON_H - 6)
    else
        ln.btn:Hide()
    end
    return y - h - P.LINE_GAP
end

local STEP_TEXT = { done = GREY, gone = GREY }

-- Fills card c with step s of path; width: the card's width. Returns the card's height.
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
    local a = s.accept
    local acceptText = a.kind == "inside" and (DUNGEON_MARK .. a.text) or a.text
    -- a done or closed step needs no way there: no "Karte"
    line(PTEXT.accept, acceptText, not over and a.point and "accept" or nil)
    -- where in the dungeon the start item can lie (hand-kept hints, D-65); not once the step is over
    if s.spots and not over then
        local rows = {}
        for i, t in ipairs(s.spots) do rows[i] = "· " .. t end
        rows[#rows + 1] = GREY .. PTEXT.spotsSource .. "|r"
        line(PTEXT.spots, table.concat(rows, "\n"))
    end
    line(PTEXT.turnIn, s.turnIn.text, not over and s.turnIn.point and "turnin" or nil)
    if s.needs then line(PTEXT.needs, s.needs) end
    if s.objective then line(PTEXT.goal, s.objective) end
    -- the marks: one of several, a breadcrumb, no longer possible
    local flags = {}
    if s.gone then flags[#flags + 1] = s.goneBy and PTEXT.goneBy:format(s.goneBy) or PTEXT.gone end
    if s.one then flags[#flags + 1] = (s.oneDone and PTEXT.noLonger or PTEXT.alsoOk):format(table.concat(s.others, ", ")) end
    if s.breadcrumb then flags[#flags + 1] = PTEXT.crumb elseif s.optional then flags[#flags + 1] = PTEXT.optional end
    if #flags > 0 then line(nil, T.ORANGE .. table.concat(flags, " · ") .. "|r") end
    for i = used + 1, #c.lines do
        local ln = c.lines[i]
        ln.label:Hide(); ln.value:Hide(); ln.btn:Hide()
    end
    local h = -y + P.PAD - P.LINE_GAP
    c:SetHeight(h)
    return h
end

-- The view: "< Zurück zu den Quests" and "Nächsten Schritt auf der Karte" in its head row, the quest's
-- title, its dungeon and level with the progress, the rewards, the next step; the step cards scroll.
local function buildPath(B)
    local V = W.Page(B, { view = true, top = B.top })
    V:Bands({ "row" })
    V.back = W.Button(V, PTEXT.back, nil, function() B:OpenPath(nil) end)
    W.FitChip(V.back)
    V.map = W.Button(V, PTEXT.map, nil, function()
        if V.path then say(ns.DungeonPathWaypoint(V.path)) end
    end)
    W.FitChip(V.map)
    W.Tooltip(V.map, PTEXT.map, PTEXT.mapTip)
    V:Place(1, { V.back }, { V.map })
    local G = T.LAYOUT
    local textW = T.PAGE_W - 2 * G.TEXT_X
    V.title = W.Text(V, T.FONT.title, textW)
    V.info = W.Text(V, T.FONT.text, textW)
    V.rewardLabel = W.Text(V, T.FONT.text)
    V.rewardLabel:SetTextColor(W.GOLD[1], W.GOLD[2], W.GOLD[3])
    V.rewardLabel:SetText(PTEXT.rewards)
    V.rewards = {}
    V.nextLine = W.Text(V, T.FONT.text, textW, true)
    V.nextLine:SetJustifyV("TOP")
    V.scroll = CreateFrame("ScrollFrame", nil, V)
    V.child = CreateFrame("Frame", nil, V.scroll)
    V.child:SetSize(T.PAGE_W - T.SCROLL_ROOM, 10)
    V.scroll:SetScrollChild(V.child)
    W.Scroll(V.scroll, V)
    V.cards = {}
    V.onMap = function(what, qid)
        if qid then say(ns.DungeonQuestWaypoint(qid, true, what, B.pathDungeon)) end
    end
    V:Hide()
    return V
end

-- A reward of the quest in the head: its item text with the marks and the gain; tooltip, Ctrl- and
-- Shift-click as everywhere.
local function rewardButton(V, i)
    local b = V.rewards[i]
    if b then return b end
    b = CreateFrame("Button", nil, V)
    b:SetHeight(14)
    b.text = W.Text(b, T.FONT.text)
    b.text:SetPoint("LEFT", 0, 0)
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

local function fillRewards(V, q, y)
    local G = T.LAYOUT
    local list = q.rewards or {}
    for _, b in ipairs(V.rewards) do b:Hide() end
    if #list == 0 then
        V.rewardLabel:Hide()
        return y
    end
    V.rewardLabel:ClearAllPoints()
    V.rewardLabel:SetPoint("TOPLEFT", G.TEXT_X, y)
    V.rewardLabel:Show()
    local x = G.TEXT_X + V.rewardLabel:GetStringWidth() + 6
    local limit = T.PAGE_W - G.TEXT_X
    for i, it in ipairs(list) do
        local b = rewardButton(V, i)
        b.id = it.id
        b.text:SetText(marks(it) .. itemText(it.id) .. (it.upgrade and (" " .. GREEN .. signed(it.gain) .. "|r") or ""))
        local w = b.text:GetStringWidth() + 2
        if x + w > limit then break end
        b:SetWidth(w)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", x, y + 1)
        b:Show()
        x = x + w + 12
    end
    return y - 14 - 4
end

local function fillPath(B, path)
    local V = B.pathView
    local Dn = ns.Dungeons
    local G = T.LAYOUT
    local q = path.quest
    V.path = path
    local y = V.top - 2
    V.title:ClearAllPoints()
    V.title:SetPoint("TOPLEFT", G.TEXT_X, y)
    V.title:SetText(q.title)
    y = y - 16
    local lv = Dn.QuestLevelText(q)
    local info = PTEXT.info:format(B.entry and B.entry.name or "?", lv ~= "" and lv or "?")
    if path.total > 1 then info = info .. " · " .. PTEXT.progress:format(path.done, path.total) end
    V.info:ClearAllPoints()
    V.info:SetPoint("TOPLEFT", G.TEXT_X, y)
    V.info:SetText(info)
    y = y - 14 - 4
    y = fillRewards(V, q, y)
    V.nextLine:ClearAllPoints()
    V.nextLine:SetPoint("TOPLEFT", G.TEXT_X, y)
    V.nextLine:SetText(LABEL .. PTEXT.nextStep .. "|r " .. Dn.QuestPathNextText(path) ..
        (path.cut > 0 and (" " .. GREY .. PTEXT.cut:format(path.cut) .. "|r") or ""))
    y = y - textHeight(V.nextLine, T.PAGE_W - 2 * G.TEXT_X) - G.GAP - 2
    V.map:SetEnabled(path.next ~= nil and Dn.QuestStepTarget(path.next) ~= nil)
    V.scroll:ClearAllPoints()
    V.scroll:SetPoint("TOPLEFT", 0, y)
    V.scroll:SetPoint("BOTTOMRIGHT", -T.SCROLL_ROOM, B:Bottom())
    -- the cards, top to bottom, "danach" between them
    local width = T.PAGE_W - T.SCROLL_ROOM
    local cy = 0
    for i, s in ipairs(path.steps) do
        local c = V.cards[i]
        if not c then
            c = newCard(V.child, V.onMap)
            V.cards[i] = c
        end
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
    for i = #path.steps + 1, #V.cards do V.cards[i]:Hide() end
    V.child:SetHeight(math.max(10, cy))
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
    function B:OpenPath(e)
        if e and e.q then
            self.pathFor = { dungeon = state().dungeon, key = e.qid or e.q.title }
        else
            self.pathFor = nil
        end
        self.detailKey = nil
        ns.Refresh()
    end
    -- the parts of the planner the quest path covers
    B.planParts = { B.headFrame, B.list, B.art, B.header, B.parts.bosses, B.parts.quests, B.way, B.detail }
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
    if pf and (part ~= "quests" or not e or pf.dungeon ~= e.key) then
        B.pathFor, pf = nil, nil
    end
    if pf then
        for _, row in ipairs((questItems(e.key))) do
            if (row.qid or row.q.title) == pf.key then path = row.path end
        end
        if not path then B.pathFor = nil end
    end
    -- (the image shows by fillArt above, only for a dungeon)
    for _, f in ipairs(B.planParts) do
        if path then f:Hide() elseif f ~= B.art then f:Show() end
    end
    if path then
        B.pathDungeon = e.key
        B.pathView:Show()
        fillPath(B, path)
        B.hint:SetText(PTEXT.hint)
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
        page.pathFor = { dungeon = key, key = qid }
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
