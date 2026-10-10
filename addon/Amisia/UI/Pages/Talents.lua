-- The page "Talente": WoW Forever's talent trees of every class in the look of the game's classic
-- three-tree talent window: three dark panels side by side, each with its name and points centred
-- at the top (right-click there or its red X on hover resets the tree), a 4 x 7 grid of square
-- icons with a thin square frame and a rank plate, straight gold lines for the prerequisites.
-- Left click +1, right click -1, shift for all ranks; the tooltip names what a talent still needs.
-- Level and the Talented perk set the free points; the plan of each class is kept as its share
-- code. The own class can load its talents from the game. The rules live in Talents.lua, the sizes
-- and colours in ns.Theme.TALENT.
local ADDON, ns = ...
local W, T, Theme = ns.W, ns.Talents, ns.Theme
local L = ns.L
local F = T.F
local TT = Theme.TALENT

local ICON = "Interface\\Icons\\INV_Misc_Book_09"
-- the trees start under the head row (ROW_H + GAP of ns.Theme.LAYOUT)
local TREE_W, TREE_GAP, TREE_TOP, TREE_H = TT.TREE_W, TT.TREE_GAP, Theme.LAYOUT.ROW_H + Theme.LAYOUT.GAP, TT.TREE_H
-- a button: the icon with its frame around it; the grid of 4 columns centred in the tree
local BTN = TT.ICON + 2 * TT.FRAME
local GRID = { left = math.floor((TREE_W - (3 * TT.PITCH + BTN)) / 2), top = TT.GRID_TOP, pitch = TT.PITCH }
local GOLD = TT.FRAME_COLOR.maxed
local RED = { 1, 0.1, 0.1 }
local TURN = { down = 0, right = math.pi / 2, left = -math.pi / 2, up = math.pi }
local HINT = L["Linksklick: +1 · Rechtsklick: -1 · Shift: alle Ränge"]

local page

function ns.TalentsPageFrame() return page end

local hasAtlas = W.HasAtlas

local function playerClass()
    local _, cls = UnitClass("player")
    return cls
end

local function points()
    local s = T.State()
    return T.PointsAt(s.level or 60, s.talented or 0)
end

local function say(text, isError)
    if not page then return end
    page.msg:SetText(text or "")
    if isError then page.msg:SetTextColor(RED[1], 0.35, 0.35) else page.msg:SetTextColor(0.85, 0.85, 0.85) end
end

local function save()
    T.SavePlan(page.plan)
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
    if page.plan then save() end
    T.State().class = cls
    page.plan = openPlan(cls)
    say("")
    ns.Refresh()
end

---------------------------------------------------------------------------
-- The tooltip of a talent
---------------------------------------------------------------------------
local function tooltip(btn)
    local n, plan = btn.node, page.plan
    if not n then return end
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
    local live = page.livePlan
    if live and live.class == plan.class then
        local lr = T.Rank(live, n[F.NODE])
        if lr ~= r then GameTooltip:AddLine((L["Im Spiel: Rang %d"]):format(lr), 0.56, 0.53, 0.64) end
    end
    GameTooltip:AddLine(HINT, 0.56, 0.53, 0.64, true)
    GameTooltip:Show()
end

local function click(btn, button)
    local n = btn.node
    if not n then return end
    local id, plan = n[F.NODE], page.plan
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
    ns.Refresh()
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

-- A talent button as in the classic talent window: the square icon, a thin square frame around it
-- tinted by the state, a soft gold glow outside the frame when the talent is full, the rank on a
-- dark plate over the icon's lower right edge.
local function talentButton(tree)
    local b = CreateFrame("Button", nil, tree)
    b:SetSize(BTN, BTN)
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
    b.plate:SetSize(TT.PLATE_W, TT.PLATE_H)
    b.plate:SetPoint("BOTTOMRIGHT", TT.PLATE_X, TT.PLATE_Y)
    b.plate:SetColorTexture(0, 0, 0, TT.PLATE_ALPHA)
    b.rank = W.Text(b, TT.RANK_FONT, TT.PLATE_W)
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

local function cellOffset(n)
    return GRID.left + n[F.COL] * GRID.pitch, -(GRID.top + n[F.ROW] * GRID.pitch)
end

-- A line from the prerequisite src to node dst (both on one tree, one column or one row: the
-- client's data has no other), drawn behind the buttons, with an arrow head in the gap before dst;
-- its textures come from the tree's pool (a class switch reuses them, nothing is made again).
local function arrow(tree, srcBtn, dstBtn, src, dst)
    tree.arrowPool = tree.arrowPool or {}
    tree.arrowsUsed = (tree.arrowsUsed or 0) + 1
    local a = tree.arrowPool[tree.arrowsUsed]
    if not a then
        a = { line = tree:CreateTexture(nil, "ARTWORK"), head = tree:CreateTexture(nil, "OVERLAY") }
        a.head:SetSize(TT.ARROW, TT.ARROW)
        tree.arrowPool[tree.arrowsUsed] = a
    end
    a.line:ClearAllPoints()
    a.head:ClearAllPoints()
    a.line:Show()
    a.head:Show()
    -- the head sits in the gap, its tip on dst's frame; the line runs under the head's back half
    local tip, back = TT.ARROW / 2, TT.ARROW - 2
    if src[F.COL] == dst[F.COL] then
        a.dir = src[F.ROW] < dst[F.ROW] and "down" or "up"
        a.line:SetWidth(TT.LINE)
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
        a.line:SetHeight(TT.LINE)
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

-- Throws away the buttons and arrows of the class shown before and builds the ones of cls.
local function buildClass(cls)
    for _, b in pairs(page.buttons) do b:Hide() end
    for _, a in pairs(page.arrows) do a.line:Hide() a.head:Hide() end
    page.buttons, page.arrows = {}, {}
    for t = 1, 3 do page.trees[t].arrowsUsed = 0 end
    page.pool = page.pool or { {}, {}, {} }
    local used = { 0, 0, 0 }
    local c = T.Class(cls)
    for t = 1, 3 do
        local tree = page.trees[t]
        for _, n in ipairs(c.order[t]) do
            used[t] = used[t] + 1
            local b = page.pool[t][used[t]]
            if not b then
                b = talentButton(tree)
                page.pool[t][used[t]] = b
            end
            b.node = n
            b:ClearAllPoints()
            local x, y = cellOffset(n)
            b:SetPoint("TOPLEFT", tree, "TOPLEFT", x, y)
            local icon = T.NodeIcon(n)
            b.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            b:Show()
            page.buttons[n[F.NODE]] = b
        end
    end
    -- the client's class background, once behind all three trees (it shows the whole talent window)
    local bg = "talent-background-" .. cls:lower()
    if hasAtlas(bg) and page.bg:SetAtlas(bg) then
        page.bg:SetAlpha(0.5)
    else
        page.bg:SetColorTexture(0.05, 0.04, 0.06, 0.85)
        page.bg.atlas = nil
    end
    for id, b in pairs(page.buttons) do
        local n = b.node
        if type(n[F.PRE]) == "table" then
            for _, sid in ipairs(n[F.PRE]) do
                local src = c.byId[math.abs(sid)]
                local srcBtn = src and page.buttons[src[F.NODE]]
                if srcBtn and src[F.TREE] == n[F.TREE] then
                    page.arrows[src[F.NODE] .. ">" .. id] = arrow(page.trees[n[F.TREE]], srcBtn, b, src, n)
                end
            end
        end
    end
    page.builtClass = cls
end

local function resetTree(t)
    T.ResetTree(page.plan, t)
    save()
    say("")
    ns.Refresh()
end

-- A tree: a dark panel, its head centred at the top (the name large and gold, "N Punkte" small
-- under it). The head takes the mouse: a right click resets the tree, hovering shows its red X.
local function makeTree(f, t)
    local tree = W.Inset(f)
    tree:SetSize(TREE_W, TREE_H)
    tree:SetPoint("TOPLEFT", f, "TOPLEFT", (t - 1) * (TREE_W + TREE_GAP), -TREE_TOP)
    local head = CreateFrame("Frame", nil, tree)
    tree.head = head
    head:SetPoint("TOPLEFT", 0, 0)
    head:SetPoint("TOPRIGHT", 0, 0)
    head:SetHeight(TT.HEAD_H)
    head:EnableMouse(true)
    -- the name keeps the X's room free on both sides, so it stays centred
    local nameW = TREE_W - 2 * (TT.RESET + TT.RESET_X + 2)
    tree.name = W.Text(head, TT.NAME_FONT, nameW)
    tree.name:SetJustifyH("CENTER")
    tree.name:SetPoint("TOP", head, "TOP", 0, -TT.NAME_Y)
    tree.pts = W.Text(head, TT.PTS_FONT, nameW)
    tree.pts:SetJustifyH("CENTER")
    tree.pts:SetPoint("TOP", tree.name, "BOTTOM", 0, -TT.PTS_GAP)
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

local function onCode(text)
    if not page or text == T.Encode(page.plan) then return end
    local plan, err = T.Decode(text)
    if not plan then
        say(err, true)
        page.code:SetText(T.Encode(page.plan))
        return
    end
    if page.plan then save() end
    T.State().class = plan.class
    page.plan = plan
    save()
    local s = T.State()
    local spent = T.Spent(plan)
    if spent > points() then s.level = T.LevelFor(spent, s.talented or 0) or 60 end
    say((L["Code übernommen: %s, %d Punkte."]):format(T.ClassName(plan.class), spent))
    ns.Refresh()
end

local function create(parent)
    local f = W.Page(parent)
    page = f
    f.buttons, f.arrows = {}, {}
    f.layoutInfo = GRID
    -- the head row: class, level and Talented, the points at the right; the trees under it
    f:Bands({ "row" })

    f.class = W.Picker(f, 130, function(v) chooseClass(v) end)
    f.levelLabel = W.Text(f, Theme.FONT.text, 34)
    f.levelLabel:SetText(L["Stufe"])
    f.level = W.Stepper(f, 76, function(v)
        T.State().level = v
        ns.Refresh()
    end)
    f.level:Configure(1, 60, 1)
    f.talentedLabel = W.Text(f, Theme.FONT.text, 58)
    f.talentedLabel:SetText(L["Talentiert"])
    f.talented = W.Stepper(f, 64, function(v)
        T.State().talented = v
        ns.Refresh()
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
    f.bg:SetPoint("BOTTOMRIGHT", f, "TOPLEFT", 3 * TREE_W + 2 * TREE_GAP - 3, -(TREE_TOP + TREE_H - 3))
    f.trees = {}
    for t = 1, 3 do f.trees[t] = makeTree(f, t) end

    f.msg = W.Text(f, Theme.FONT.text, 320)
    f.msg:SetPoint("TOPLEFT", Theme.LAYOUT.TEXT_X, -(TREE_TOP + TREE_H + 4))
    f.liveText = W.Text(f, Theme.FONT.text, 262)
    f.liveText:SetJustifyH("RIGHT")
    f.liveText:SetPoint("TOPRIGHT", -Theme.LAYOUT.TEXT_X, -(TREE_TOP + TREE_H + 4))

    f.live = W.Button(f, L["Eigene laden"], 104, function()
        local plan, info = T.Live()
        if not plan then
            say(info, true)
            return
        end
        page.plan = plan
        T.State().class = plan.class
        save()
        say((L["Talente aus dem Spiel geladen (%d Punkte)."]):format(T.Spent(plan)))
        ns.Refresh()
    end)
    W.Tooltip(f.live, L["Eigene Talente laden"], L["Übernimmt die Talente, die dein Charakter gerade hat."])
    f.resetAll = W.Button(f, L["Alles zurücksetzen"], 128, function()
        T.Reset(page.plan)
        save()
        say("")
        ns.Refresh()
    end)
    W.FitChip(f.live, 104)
    W.FitChip(f.resetAll, 128)
    f.codeLabel = W.Text(f, Theme.FONT.text, 34)
    f.codeLabel:SetText("Code")
    f.code = W.LineEdit(f, 300, onCode)
    -- the bottom row: load, reset, the share code taking the rest
    f:BottomRow({ f.live, f.resetAll, { f.codeLabel, gap = 10 }, { f.code, gap = 4, fill = true } })
    -- a click into the box marks the code, ready to copy
    f.code:HookScript("OnEditFocusGained", function(self) self:HighlightText() end)
    W.Tooltip(f.code, L["Build-Code"], L["Zum Teilen kopieren (Strg+C). Einen Code einfügen und Enter drücken übernimmt ihn."])
    return f
end

local function refresh(f)
    local s = T.State()
    local cls = f.plan and f.plan.class or s.class
    if not T.Class(cls or "") then cls = T.Classes()[1] end
    if not cls then return end
    if not f.plan or f.plan.class ~= cls then f.plan = openPlan(cls) end
    s.class = cls
    if f.builtClass ~= cls then buildClass(cls) end

    local values = {}
    for _, c in ipairs(T.Classes()) do values[#values + 1] = { value = c, text = T.ClassName(c) } end
    f.class:SetValues(values)
    f.class:SetValue(cls)
    f.level:SetValue(s.level or 60)
    f.talented:SetValue(s.talented or 0)

    local plan, pts = f.plan, points()
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
    f.livePlan = nil
    local own = cls == playerClass()
    local live, info
    if own then live, info = T.Live() end
    if live then
        f.livePlan = live
        f.liveText:SetText((L["Im Spiel: %d/%d/%d · %d von %d Punkten"]):format(T.Spent(live, 1), T.Spent(live, 2), T.Spent(live, 3),
            info.spent or T.Spent(live), info.total or T.PointsAt(UnitLevel("player") or 60, s.talented or 0)))
    else
        f.liveText:SetText(own and ("|cff8f86a3" .. tostring(info or "") .. "|r") or "")
    end
    f.live:SetEnabled(live ~= nil)
    if not f.code:HasFocus() then f.code:SetText(T.Encode(plan)) end
end

ns.RegisterPanel{ key = "talents", label = L["Talente"], icon = ICON, order = 58, group = "gear",
    available = function() return T.Available() end,
    create = create, refresh = refresh }

-- Opens the page; code: a share code to take over.
function ns.ShowTalents(code)
    if ns.ShowPage then ns.ShowPage("talents") end
    if code and code:find("%S") and page then onCode(code) end
end

ns.RegisterSlash("talente", { en = "talents", aliases = { "talent" }, args = L["[Code]"],
    desc = L["Talentrechner öffnen (mit Code: Build übernehmen)"],
    run = function(rest) ns.ShowTalents(rest) end })

-- the own talents changed in the game: show them while the page is open
local function changed()
    if page and page:IsShown() and ns.CurrentPage and ns.CurrentPage() == "talents" then ns.Refresh() end
end
ns.OnEvent("PLAYER_TALENT_UPDATE", changed)
ns.OnEvent("TRAIT_CONFIG_UPDATED", changed)
