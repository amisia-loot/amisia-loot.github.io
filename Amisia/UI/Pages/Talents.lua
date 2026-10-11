-- The page "Talente" and the window "Talentrechner" (AmisiaTalentFrame): WoW Forever's talent
-- trees of every class in the look of the game's classic three-tree talent window: three dark
-- panels side by side, each with its name and points centred at the top (right-click there or its
-- red X on hover resets the tree), a 4 x 7 grid of square icons with a thin square frame and a rank
-- plate, straight gold lines for the prerequisites. Left click +1, right click -1, shift for all
-- ranks; the tooltip names what a talent still needs. Level and the Talented perk set the free
-- points; the plan of each class is kept as its share code. The own class can load its talents from
-- the game. The rules live in Talents.lua, the sizes and colours in ns.Theme.TALENT.
-- One builder (buildView) draws the view for a parent in a size profile: TALENT.PAGE on the page in
-- the main window, TALENT.BIG in the window. Both views show the one plan (S below): a click in
-- one changes the other on its refresh. The window is moved and scaled on its own (settings
-- talentWindow and ui.talentScale, Ctrl + mouse wheel over it).
local ADDON, ns = ...
local W, T, Theme = ns.W, ns.Talents, ns.Theme
local L = ns.L
local F = T.F
local TT = Theme.TALENT
local LAY = Theme.LAYOUT

local ICON = "Interface\\Icons\\INV_Misc_Book_09"
-- the trees start under the head row (ROW_H + GAP of ns.Theme.LAYOUT)
local TREE_TOP = LAY.ROW_H + LAY.GAP
local GOLD = TT.FRAME_COLOR.maxed
local RED = { 1, 0.1, 0.1 }
local TURN = { down = 0, right = math.pi / 2, left = -math.pi / 2, up = math.pi }
local HINT = L["Linksklick: +1 · Rechtsklick: -1 · Shift: alle Ränge"]

-- what both views show: the plan of the shown class, the talents in the game (own class)
local S = { plan = nil, live = nil }
local page, big, win
local refreshView

function ns.TalentsPageFrame() return page end
-- the plan both views show (tests and the snapshot scene); nil opens the class's saved plan again
function ns.TalentsPlan() return S.plan end
function ns.TalentsSetPlan(plan) S.plan = plan end

local hasAtlas = W.HasAtlas

local function playerClass()
    local _, cls = UnitClass("player")
    return cls
end

local function points()
    local s = T.State()
    return T.PointsAt(s.level or 60, s.talented or 0)
end

-- the views built so far (the page, the window's)
local function eachView(fn)
    if page then fn(page) end
    if big then fn(big) end
end

-- Refreshes both views: the page through the main window (only while it shows the page), the
-- window's while it is open.
local function refreshAll()
    ns.Refresh()
    if big and win and win:IsShown() then refreshView(big) end
end

-- the message under the trees, in both views
local function say(text, isError)
    eachView(function(v)
        v.msg:SetText(text or "")
        if isError then v.msg:SetTextColor(RED[1], 0.35, 0.35) else v.msg:SetTextColor(0.85, 0.85, 0.85) end
    end)
end

local function save()
    T.SavePlan(S.plan)
end

-- The plan a class opens with: its saved one, else (the own class) the talents in the game.
local function openPlan(cls)
    local plan, saved = T.LoadPlan(cls)
    if not saved and cls == playerClass() then
        local live = T.Live()
        if live and T.Spent(live) > 0 then plan = live end
    end
    return plan
end

local function chooseClass(cls)
    if not T.Class(cls) then return end
    if S.plan then save() end
    T.State().class = cls
    S.plan = openPlan(cls)
    say("")
    refreshAll()
end

---------------------------------------------------------------------------
-- The tooltip of a talent
---------------------------------------------------------------------------
local function tooltip(btn)
    local n, plan = btn.node, S.plan
    if not n or not plan then return end
    local r, max = T.Rank(plan, n[F.NODE]), n[F.MAX]
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:AddLine(T.NodeName(n), 1, 1, 1)
    GameTooltip:AddLine((L["Rang %d/%d"]):format(r, max), 1, 1, 1)
    if r < max then
        for _, line in ipairs(T.Missing(plan, n[F.NODE])) do GameTooltip:AddLine(line, RED[1], RED[2], RED[3], true) end
    end
    GameTooltip:AddLine(T.NodeText(n, math.max(1, r)), GOLD[1], GOLD[2], GOLD[3], true)
    if r > 0 and r < max then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Nächster Rang:"], 1, 1, 1)
        GameTooltip:AddLine(T.NodeText(n, r + 1), GOLD[1], GOLD[2], GOLD[3], true)
    end
    local live = S.live
    if live and live.class == plan.class then
        local lr = T.Rank(live, n[F.NODE])
        if lr ~= r then GameTooltip:AddLine((L["Im Spiel: Rang %d"]):format(lr), 0.56, 0.53, 0.64) end
    end
    GameTooltip:AddLine(HINT, 0.56, 0.53, 0.64, true)
    GameTooltip:Show()
end

local function click(btn, button)
    local n = btn.node
    if not n or not S.plan then return end
    local id, plan = n[F.NODE], S.plan
    local shift = IsShiftKeyDown and IsShiftKeyDown()
    local ok, why
    if button == "RightButton" then
        ok, why = T.CanRemove(plan, id)
        if ok then
            if shift then T.RemoveAll(plan, id) else T.Remove(plan, id) end
        end
    else
        ok, why = T.CanAdd(plan, id, points())
        if ok then
            if shift then T.AddAll(plan, id, points()) else T.Add(plan, id, points()) end
        end
    end
    say(ok and "" or why, not ok)
    if ok then save() end
    refreshAll()
    if GameTooltip.IsOwned and GameTooltip:IsOwned(btn) then tooltip(btn) end
end

---------------------------------------------------------------------------
-- Building: the trees, the buttons and arrows of the shown class
---------------------------------------------------------------------------
-- A square ring of four colour textures around frame b: its outer edge out px outside b (negative:
-- inside), size px thick. Returns the four textures.
local function ring(b, out, size, layer, r, g, bl, a)
    local function edge(p1, x1, y1, p2, x2, y2, w, h)
        local t = b:CreateTexture(nil, layer)
        t:SetColorTexture(r, g, bl, a)
        t:SetPoint(p1, b, p1, x1, y1)
        t:SetPoint(p2, b, p2, x2, y2)
        if w then t:SetWidth(w) end
        if h then t:SetHeight(h) end
        return t
    end
    return { edge("TOPLEFT", -out, out, "TOPRIGHT", out, out, nil, size),
             edge("BOTTOMLEFT", -out, -out, "BOTTOMRIGHT", out, -out, nil, size),
             edge("TOPLEFT", -out, out - size, "BOTTOMLEFT", -out, -out + size, size, nil),
             edge("TOPRIGHT", out, out - size, "BOTTOMRIGHT", out, -out + size, size, nil) }
end

-- A talent button as in the classic talent window, in the sizes of profile P: the square icon, a
-- thin square frame around it tinted by the state, a soft gold glow outside the frame when the
-- talent is full, the rank on a dark plate over the icon's lower right edge.
local function talentButton(tree, P)
    local size = P.ICON + 2 * TT.FRAME
    local b = CreateFrame("Button", nil, tree)
    b:SetSize(size, size)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", TT.FRAME, -TT.FRAME)
    b.icon:SetPoint("BOTTOMRIGHT", -TT.FRAME, TT.FRAME)
    b.icon:SetTexCoord(TT.CROP, 1 - TT.CROP, TT.CROP, 1 - TT.CROP)
    b.frame = ring(b, 0, TT.FRAME, "BORDER", 0, 0, 0, 1)
    b.glow = {}
    for i, a in ipairs(TT.GLOW) do
        for _, t in ipairs(ring(b, i, 1, "BACKGROUND", GOLD[1], GOLD[2], GOLD[3], a)) do b.glow[#b.glow + 1] = t end
    end
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b.icon)
    hl:SetColorTexture(1, 1, 1, 0.15)
    b.plate = b:CreateTexture(nil, "OVERLAY", nil, 1)
    b.plate:SetSize(P.PLATE_W, P.PLATE_H)
    b.plate:SetPoint("BOTTOMRIGHT", P.PLATE_X, P.PLATE_Y)
    b.plate:SetColorTexture(0, 0, 0, TT.PLATE_ALPHA)
    b.rank = W.Text(b, P.RANK_FONT, P.PLATE_W)
    b.rank:SetDrawLayer("OVERLAY", 2)
    b.rank:SetJustifyH("CENTER")
    b.rank:SetPoint("CENTER", b.plate, "CENTER", 0, 0)
    b:SetScript("OnClick", click)
    b:SetScript("OnEnter", tooltip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

-- state: locked (a tier or prerequisite missing), free (reachable, no point), partial, maxed
local function setState(b, state)
    b.state = state
    local c = TT.FRAME_COLOR[state] or TT.FRAME_COLOR.locked
    W.SetBorderColor(b.frame, c[1], c[2], c[3], 1)
    b.frameColor = c
    local maxed = state == "maxed"
    for _, t in ipairs(b.glow) do t:SetShown(maxed) end
    b.glowShown = maxed
    local locked = state == "locked"
    b.icon:SetDesaturated(locked)
    b.icon.desaturated = locked
    local v = locked and TT.DIM or 1
    b.icon:SetVertexColor(v, v, v)
    local rc = TT.RANK_COLOR[state] or TT.RANK_COLOR.locked
    b.rank:SetTextColor(rc[1], rc[2], rc[3])
end

-- A line from the prerequisite src to node dst (both on one tree, one column or one row: the
-- client's data has no other), drawn behind the buttons, with an arrow head in the gap before dst;
-- its textures come from the tree's pool (a class switch reuses them, nothing is made again).
local function arrow(tree, P, srcBtn, dstBtn, src, dst)
    tree.arrowPool = tree.arrowPool or {}
    tree.arrowsUsed = (tree.arrowsUsed or 0) + 1
    local a = tree.arrowPool[tree.arrowsUsed]
    if not a then
        a = { line = tree:CreateTexture(nil, "ARTWORK"), head = tree:CreateTexture(nil, "OVERLAY") }
        a.head:SetSize(P.ARROW, P.ARROW)
        tree.arrowPool[tree.arrowsUsed] = a
    end
    a.line:ClearAllPoints()
    a.head:ClearAllPoints()
    a.line:Show()
    a.head:Show()
    -- the head sits in the gap, its tip on dst's frame; the line runs under the head's back half
    local tip, back = P.ARROW / 2, P.ARROW - 2
    if src[F.COL] == dst[F.COL] then
        a.dir = src[F.ROW] < dst[F.ROW] and "down" or "up"
        a.line:SetWidth(P.LINE)
        if a.dir == "down" then
            a.line:SetPoint("TOP", srcBtn, "BOTTOM", 0, 0)
            a.line:SetPoint("BOTTOM", dstBtn, "TOP", 0, back)
            a.head:SetPoint("CENTER", dstBtn, "TOP", 0, tip)
        else
            a.line:SetPoint("BOTTOM", srcBtn, "TOP", 0, 0)
            a.line:SetPoint("TOP", dstBtn, "BOTTOM", 0, -back)
            a.head:SetPoint("CENTER", dstBtn, "BOTTOM", 0, -tip)
        end
    else
        a.dir = src[F.COL] < dst[F.COL] and "right" or "left"
        a.line:SetHeight(P.LINE)
        if a.dir == "right" then
            a.line:SetPoint("LEFT", srcBtn, "RIGHT", 0, 0)
            a.line:SetPoint("RIGHT", dstBtn, "LEFT", -back, 0)
            a.head:SetPoint("CENTER", dstBtn, "LEFT", -tip, 0)
        else
            a.line:SetPoint("RIGHT", srcBtn, "LEFT", 0, 0)
            a.line:SetPoint("LEFT", dstBtn, "RIGHT", back, 0)
            a.head:SetPoint("CENTER", dstBtn, "RIGHT", tip, 0)
        end
    end
    if a.head.SetRotation then a.head:SetRotation(TURN[a.dir]) end
    a.src, a.dst = src[F.NODE], dst[F.NODE]
    return a
end

-- gold when the prerequisite is full, dark grey while it is not
local function paintArrow(a, plan)
    local met = T.Rank(plan, a.src) >= T.Node(plan.class, a.src)[F.MAX]
    local atlas = met and "talents-arrow-head-yellow" or "talents-arrow-head-gray"
    local c = met and TT.LINE_COLOR.met or TT.LINE_COLOR.unmet
    a.line:SetColorTexture(c[1], c[2], c[3], c[4])
    a.met = met
    if hasAtlas(atlas) and a.head:SetAtlas(atlas) then a.head:Show() else a.head:Hide() end
end

-- Throws away the buttons and arrows of the class view v showed before and builds the ones of cls.
local function buildClass(v, cls)
    for _, b in pairs(v.buttons) do b:Hide() end
    for _, a in pairs(v.arrows) do a.line:Hide() a.head:Hide() end
    v.buttons, v.arrows = {}, {}
    for t = 1, 3 do v.trees[t].arrowsUsed = 0 end
    v.pool = v.pool or { {}, {}, {} }
    local used = { 0, 0, 0 }
    local c = T.Class(cls)
    local G = v.layoutInfo
    for t = 1, 3 do
        local tree = v.trees[t]
        for _, n in ipairs(c.order[t]) do
            used[t] = used[t] + 1
            local b = v.pool[t][used[t]]
            if not b then
                b = talentButton(tree, v.P)
                v.pool[t][used[t]] = b
            end
            b.node = n
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", tree, "TOPLEFT", G.left + n[F.COL] * G.pitch, -(G.top + n[F.ROW] * G.pitch))
            local icon = T.NodeIcon(n)
            b.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            b:Show()
            v.buttons[n[F.NODE]] = b
        end
    end
    -- the client's class background, once behind all three trees (it shows the whole talent window)
    local bg = "talent-background-" .. cls:lower()
    if hasAtlas(bg) and v.bg:SetAtlas(bg) then
        v.bg:SetAlpha(0.5)
    else
        v.bg:SetColorTexture(0.05, 0.04, 0.06, 0.85)
        v.bg.atlas = nil
    end
    for id, b in pairs(v.buttons) do
        local n = b.node
        if type(n[F.PRE]) == "table" then
            for _, sid in ipairs(n[F.PRE]) do
                local src = c.byId[math.abs(sid)]
                local srcBtn = src and v.buttons[src[F.NODE]]
                if srcBtn and src[F.TREE] == n[F.TREE] then
                    v.arrows[src[F.NODE] .. ">" .. id] = arrow(v.trees[n[F.TREE]], v.P, srcBtn, b, src, n)
                end
            end
        end
    end
    v.builtClass = cls
end

local function resetTree(t)
    if not S.plan then return end
    T.ResetTree(S.plan, t)
    save()
    say("")
    refreshAll()
end

-- A tree in profile P: a dark panel, its head centred at the top (the name large and gold,
-- "N Punkte" small under it). The head takes the mouse: a right click resets the tree, hovering
-- shows its red X.
local function makeTree(f, P, t)
    local tree = W.Inset(f)
    tree:SetSize(P.TREE_W, P.TREE_H)
    tree:SetPoint("TOPLEFT", f, "TOPLEFT", (t - 1) * (P.TREE_W + P.TREE_GAP), -TREE_TOP)
    local head = CreateFrame("Frame", nil, tree)
    tree.head = head
    head:SetPoint("TOPLEFT", 0, 0)
    head:SetPoint("TOPRIGHT", 0, 0)
    head:SetHeight(P.HEAD_H)
    head:EnableMouse(true)
    -- the name keeps the X's room free on both sides, so it stays centred
    local nameW = P.TREE_W - 2 * (TT.RESET + TT.RESET_X + 2)
    tree.name = W.Text(head, P.NAME_FONT, nameW)
    tree.name:SetJustifyH("CENTER")
    tree.name:SetPoint("TOP", head, "TOP", 0, -P.NAME_Y)
    tree.pts = W.Text(head, P.PTS_FONT, nameW)
    tree.pts:SetJustifyH("CENTER")
    tree.pts:SetPoint("TOP", tree.name, "BOTTOM", 0, -P.PTS_GAP)
    tree.reset = W.ResetButton(head, TT.RESET, function() resetTree(t) end)
    tree.reset:SetPoint("TOPRIGHT", head, "TOPRIGHT", -TT.RESET_X, -TT.RESET_X)
    W.Tooltip(tree.reset, L["Baum zurücksetzen"], L["Nimmt alle Punkte aus diesem Baum."])
    tree.reset:Hide()
    local function away()
        if not head:IsMouseOver() then tree.reset:Hide() end
    end
    head:SetScript("OnEnter", function(self)
        tree.reset:Show()
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(tree.name:GetText() or "", GOLD[1], GOLD[2], GOLD[3])
        GameTooltip:AddLine(L["Rechtsklick: Baum zurücksetzen"], 0.56, 0.53, 0.64)
        GameTooltip:Show()
    end)
    head:SetScript("OnLeave", function()
        GameTooltip:Hide()
        away()
    end)
    head:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then resetTree(t) end
    end)
    tree.reset:HookScript("OnLeave", away)
    return tree
end

-- A code typed or pasted into the box of view v.
local function onCode(v, text)
    if not v or (S.plan and text == T.Encode(S.plan)) then return end
    local plan, err = T.Decode(text)
    if not plan then
        say(err, true)
        if S.plan then v.code:SetText(T.Encode(S.plan)) end
        return
    end
    if S.plan then save() end
    T.State().class = plan.class
    S.plan = plan
    save()
    local s = T.State()
    local spent = T.Spent(plan)
    if spent > points() then s.level = T.LevelFor(spent, s.talented or 0) or 60 end
    say((L["Code übernommen: %s, %d Punkte."]):format(T.ClassName(plan.class), spent))
    refreshAll()
end

-- The width of a view in profile P: three trees and the two gaps between them.
local function viewWidth(P) return 3 * P.TREE_W + 2 * P.TREE_GAP end

-- The one builder of the talent view: a W.Page on parent in the sizes of profile P (TALENT.PAGE or
-- TALENT.BIG). opts.bigButton: the red button that opens the window (on the page); opts.hint: the
-- click hint as the footer (in the window).
local function buildView(parent, P, opts)
    opts = opts or {}
    local VW = viewWidth(P)
    local f = W.Page(parent, { width = VW })
    f.P = P
    f.buttons, f.arrows = {}, {}
    -- the grid of 4 columns centred in the tree: the button is the icon with its frame around it
    local btn = P.ICON + 2 * TT.FRAME
    f.layoutInfo = { left = math.floor((P.TREE_W - (3 * P.PITCH + btn)) / 2), top = P.GRID_TOP, pitch = P.PITCH, button = btn }
    -- the head row: class, level and Talented, the points at the right; the trees under it
    f:Bands({ "row" })

    f.class = W.Picker(f, 130, function(v) chooseClass(v) end)
    f.levelLabel = W.Text(f, Theme.FONT.text, 34)
    f.levelLabel:SetText(L["Stufe"])
    f.level = W.Stepper(f, 76, function(v)
        T.State().level = v
        refreshAll()
    end)
    f.level:Configure(1, 60, 1)
    f.talentedLabel = W.Text(f, Theme.FONT.text, 58)
    f.talentedLabel:SetText(L["Talentiert"])
    f.talented = W.Stepper(f, 64, function(v)
        T.State().talented = v
        refreshAll()
    end)
    f.talented:Configure(0, 5, 1)
    f.talented:EnableMouse(true)
    W.Tooltip(f.talented, L["Talentiert (Vermächtnis)"],
        L["Jeder Rang gibt die Talentpunkte eine Stufe früher (ab Stufe 9 bis 5); mehr als 51 Punkte gibt es nie."])
    f.total = W.Text(f, Theme.FONT.body, 206)
    f.total:SetJustifyH("RIGHT")
    -- the class, then each stepper with its label in front
    f:Place(1, { f.class, { f.levelLabel, gap = 10 }, { f.level, gap = 2 }, { f.talentedLabel, gap = 10 }, { f.talented, gap = 2 } },
        { f.total })

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -(TREE_TOP + 3))
    f.bg:SetPoint("BOTTOMRIGHT", f, "TOPLEFT", VW - 3, -(TREE_TOP + P.TREE_H - 3))
    f.trees = {}
    for t = 1, 3 do f.trees[t] = makeTree(f, P, t) end

    -- under the trees: the last message at the left, the talents in the game at the right
    local lineY = -(TREE_TOP + P.TREE_H + LAY.GAP)
    f.msg = W.Text(f, Theme.FONT.text, VW - P.LIVE_W - 2 * LAY.TEXT_X - 8)
    f.msg:SetPoint("TOPLEFT", LAY.TEXT_X, lineY)
    f.liveText = W.Text(f, Theme.FONT.text, P.LIVE_W)
    f.liveText:SetJustifyH("RIGHT")
    f.liveText:SetPoint("TOPRIGHT", -LAY.TEXT_X, lineY)

    f.live = W.Button(f, L["Eigene laden"], 104, function()
        local plan, info = T.Live()
        if not plan then
            say(info, true)
            return
        end
        S.plan = plan
        T.State().class = plan.class
        save()
        say((L["Talente aus dem Spiel geladen (%d Punkte)."]):format(T.Spent(plan)))
        refreshAll()
    end)
    W.Tooltip(f.live, L["Eigene Talente laden"], L["Übernimmt die Talente, die dein Charakter gerade hat."])
    f.resetAll = W.Button(f, L["Alles zurücksetzen"], 128, function()
        if not S.plan then return end
        T.Reset(S.plan)
        save()
        say("")
        refreshAll()
    end)
    W.FitChip(f.live, 104)
    W.FitChip(f.resetAll, 128)
    f.codeLabel = W.Text(f, Theme.FONT.text, 34)
    f.codeLabel:SetText("Code")
    f.code = W.LineEdit(f, 200, function(text) onCode(f, text) end)
    local right
    if opts.bigButton then
        -- the window with the bigger trees (the side tab and /amisia talente gross open it too)
        f.bigBtn = W.Button(f, L["Großes Fenster"], 110, function() ns.ToggleTalentFrame() end)
        W.FitChip(f.bigBtn, 110)
        W.Tooltip(f.bigBtn, L["Talentrechner"],
            L["Öffnet die Talente in einem eigenen, größeren Fenster (auch /amisia talente gross). Strg + Mausrad über dem Fenster ändert seine Größe."])
        right = { f.bigBtn }
    end
    if opts.hint then
        f:Footer({ "hint" })
        f.hint:SetText(HINT)
    end
    -- the bottom row: load, reset, the share code taking the rest (and the window's button)
    f:BottomRow({ f.live, f.resetAll, { f.codeLabel, gap = 10 }, { f.code, gap = 4, fill = true } }, right)
    -- a click into the box marks the code, ready to copy
    f.code:HookScript("OnEditFocusGained", function(self) self:HighlightText() end)
    W.Tooltip(f.code, L["Build-Code"], L["Zum Teilen kopieren (Strg+C). Einen Code einfügen und Enter drücken übernimmt ihn."])
    return f
end

refreshView = function(f)
    if not f then return end
    local s = T.State()
    local cls = S.plan and S.plan.class or s.class
    if not T.Class(cls or "") then cls = T.Classes()[1] end
    if not cls then return end
    if not S.plan or S.plan.class ~= cls then S.plan = openPlan(cls) end
    s.class = cls
    if f.builtClass ~= cls then buildClass(f, cls) end

    local values = {}
    for _, c in ipairs(T.Classes()) do values[#values + 1] = { value = c, text = T.ClassName(c) } end
    f.class:SetValues(values)
    f.class:SetValue(cls)
    f.level:SetValue(s.level or 60)
    f.talented:SetValue(s.talented or 0)

    local plan, pts = S.plan, points()
    local spent = T.Spent(plan)
    local need = T.LevelFor(spent, s.talented or 0)
    local over = spent > pts
    f.total:SetText((L["%s%d / %d|r Punkte%s"]):format(over and "|cffff4040" or "|cffffffff", spent, pts,
        spent > 0 and need and L[" · ab Stufe %d"]:format(need) or ""))

    for t = 1, 3 do
        local tree = f.trees[t]
        tree.name:SetText(T.TreeName(cls, t))
        local inTree = T.Spent(plan, t)
        tree.pts:SetText((inTree == 1 and L["%d Punkt"] or L["%d Punkte"]):format(inTree))
    end
    for id, b in pairs(f.buttons) do
        local n = b.node
        local r = T.Rank(plan, id)
        b.rank:SetText(("%d/%d"):format(r, n[F.MAX]))
        local state
        if r >= n[F.MAX] then
            state = "maxed"
        elseif r > 0 then
            state = "partial"
        elseif T.CanAdd(plan, id, pts) then
            state = "free"
        else
            state = "locked"
        end
        setState(b, state)
    end
    for _, a in pairs(f.arrows) do
        a.line:Show()
        paintArrow(a, plan)
    end

    -- the own class: the talents in the game
    S.live = nil
    local own = cls == playerClass()
    local live, info
    if own then live, info = T.Live() end
    if live then
        S.live = live
        f.liveText:SetText((L["Im Spiel: %d/%d/%d · %d von %d Punkten"]):format(T.Spent(live, 1), T.Spent(live, 2), T.Spent(live, 3),
            info.spent or T.Spent(live), info.total or T.PointsAt(UnitLevel("player") or 60, s.talented or 0)))
    else
        f.liveText:SetText(own and ("|cff8f86a3" .. tostring(info or "") .. "|r") or "")
    end
    f.live:SetEnabled(live ~= nil)
    if not f.code:HasFocus() then f.code:SetText(T.Encode(plan)) end
end

local function create(parent)
    page = buildView(parent, TT.PAGE, { bigButton = true })
    return page
end

ns.RegisterPanel{ key = "talents", label = L["Talente"], icon = ICON, order = 58, group = "gear",
    available = function() return T.Available() end,
    create = create, refresh = refreshView }

---------------------------------------------------------------------------
-- The window "Talentrechner": the view in the BIG profile, moved and scaled on its own
---------------------------------------------------------------------------
local function winState()
    local st = type(AmisiaDB) == "table" and AmisiaDB.settings
    if type(st) ~= "table" then return nil end
    if type(st.talentWindow) ~= "table" then st.talentWindow = {} end
    return st.talentWindow
end

local function place()
    if not win then return end
    win:ClearAllPoints()
    local st = winState()
    if st and type(st.point) == "string" and tonumber(st.x) and tonumber(st.y) then
        win:SetPoint(st.point, UIParent, st.point, tonumber(st.x), tonumber(st.y))
    else
        win:SetPoint("CENTER")
    end
end

local function savePlace(f)
    local st = winState()
    if not st then return end
    local point, _, _, x, y = f:GetPoint(1)
    if type(point) == "string" and tonumber(x) and tonumber(y) then
        st.point, st.x, st.y = point, math.floor(x + 0.5), math.floor(y + 0.5)
    end
end

function ns.ResetTalentWindowPosition()
    local st = winState()
    if st then st.point, st.x, st.y = nil, nil, nil end
    place()
end

function ns.ApplyTalentScale(v)
    if win then win:SetScale((tonumber(v) or tonumber(ns.Get("ui.talentScale")) or 100) / 100) end
end

-- Ctrl + mouse wheel over the window: SCALE_STEP percent bigger or smaller, within the setting's
-- bounds, saved as the setting.
local function wheel(_, delta)
    if not (IsControlKeyDown and IsControlKeyDown()) or not tonumber(delta) or delta == 0 then return end
    local it = ns.SettingItem("ui.talentScale")
    if not it then return end
    local cur = tonumber(ns.Get("ui.talentScale")) or it.default
    local v = math.max(it.min, math.min(it.max, cur + (delta > 0 and 1 or -1) * TT.WINDOW.SCALE_STEP))
    if v ~= cur then ns.Set("ui.talentScale", v) end
end

local function buildWindow()
    local P, WT = TT.BIG, TT.WINDOW
    local VW = viewWidth(P)
    -- head row, trees, the message line, the bottom row, the hint (the gaps of ns.Theme.LAYOUT)
    local VH = TREE_TOP + P.TREE_H + LAY.GAP + LAY.LINE_H + LAY.GAP + LAY.ROW_H + LAY.GAP + LAY.LINE_H
    -- the main window's strata (FULLSCREEN): it stays open with the world map as the main window does
    win = W.Window("AmisiaTalentFrame", VW + 2 * Theme.WINDOW_PAD, WT.TOP + VH + WT.BOTTOM, { title = L["Talentrechner"],
        strata = "FULLSCREEN", background = "Profession-Background-Overview",
        onShow = function(self)
            if self.Raise then self:Raise() end
            refreshView(big)
        end,
        onVisibility = function() if ns.UpdateSideTabs then ns.UpdateSideTabs() end end,
        onDragStop = savePlace })
    local body = CreateFrame("Frame", nil, win)
    body:SetPoint("TOPLEFT", Theme.WINDOW_PAD, -WT.TOP)
    body:SetSize(VW, VH)
    big = buildView(body, P, { hint = true })
    big:SetAllPoints(body)
    win.body, win.view = body, big
    win:EnableMouseWheel(true)
    win:SetScript("OnMouseWheel", wheel)
    place()
    ns.ApplyTalentScale()
end

local function available()
    if T.Available() then return true end
    ns.msg(L["Der Talentrechner ist nicht verfügbar."])
    return false
end

function ns.ShowTalentFrame()
    if not available() then return end
    if not win then buildWindow() end
    if win:IsShown() then refreshView(big) else win:Show() end
    return win
end

function ns.ToggleTalentFrame()
    if win and win:IsShown() then
        win:Hide()
        return
    end
    return ns.ShowTalentFrame()
end

-- Opens the page; code: a share code to take over.
function ns.ShowTalents(code)
    if ns.ShowPage then ns.ShowPage("talents") end
    if code and code:find("%S") and page then onCode(page, code) end
end

-- /amisia talente [Code|gross]: the page, a build, or the window
local BIG_WORDS = { gross = true, ["gro\195\159"] = true, big = true }   -- l10n-ok: typed words
ns.RegisterSlash("talente", { en = "talents", aliases = { "talent" }, args = L["[Code|gross]"],
    desc = L["Talentrechner öffnen (mit Code: Build übernehmen, gross: großes Fenster)"],
    run = function(rest)
        local word = type(rest) == "string" and rest:match("^%s*(%S+)%s*$")
        if word and BIG_WORDS[word:lower()] then
            ns.ShowTalentFrame()
            return
        end
        ns.ShowTalents(rest)
    end })

-- the own talents changed in the game: show them in the open views
local function changed()
    if page and page:IsShown() and ns.CurrentPage and ns.CurrentPage() == "talents" then ns.Refresh() end
    if big and win and win:IsShown() then refreshView(big) end
end
ns.OnEvent("PLAYER_TALENT_UPDATE", changed)
ns.OnEvent("TRAIT_CONFIG_UPDATED", changed)
