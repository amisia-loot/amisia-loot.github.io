-- The page "Talente": WoW Forever's talent trees of every class in the look of the classic talent
-- window: three trees side by side, each with its name, its points and a reset button, a 4 x 7
-- grid of the talents with their rank, the points a row needs at its left, arrows for the
-- prerequisites. Left click +1, right click -1, shift for all ranks. Level and the Talented perk
-- set the free points; the plan of each class is kept as its share code. The own class can load
-- its talents from the game. The rules live in Talents.lua.
local ADDON, ns = ...
local W, T = ns.W, ns.Talents
local F = T.F

local ICON = "Interface\\Icons\\INV_Misc_Book_09"
local TREE_W, TREE_GAP, TREE_TOP, TREE_H = 196, 7, 28, 398
local HEAD_H = 24
-- the grid inside a tree: a column for the row locks, then 4 columns and 7 rows
local GRID = { left = 18, top = HEAD_H + 8, pitchX = 44, pitchY = 50, pad = 5 }
local BTN = 34
local ROWS = 7
local GOLD = { 1, 0.82, 0 }
local GREEN = { 0.25, 1, 0.25 }
local GREY = { 0.5, 0.5, 0.5 }
local RED = { 1, 0.1, 0.1 }
local BORDER = { maxed = "talents-node-square-yellow", partial = "talents-node-square-green",
                 free = "talents-node-square-green", locked = "talents-node-square-gray" }
local BORDER_COLOR = { maxed = GOLD, partial = GREEN, free = GREEN, locked = GREY }
local TURN = { down = 0, right = math.pi / 2, left = -math.pi / 2, up = math.pi }
local HINT = "Linksklick: +1 · Rechtsklick: -1 · Shift: alle Ränge"

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
    GameTooltip:AddLine(("Rang %d/%d"):format(r, max), 1, 1, 1)
    if r < max then
        for _, line in ipairs(T.Missing(plan, n[F.NODE])) do GameTooltip:AddLine(line, RED[1], RED[2], RED[3], true) end
    end
    GameTooltip:AddLine(T.NodeText(n, math.max(1, r)), GOLD[1], GOLD[2], GOLD[3], true)
    if r > 0 and r < max then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Nächster Rang:", 1, 1, 1)
        GameTooltip:AddLine(T.NodeText(n, r + 1), GOLD[1], GOLD[2], GOLD[3], true)
    end
    local live = page.livePlan
    if live and live.class == plan.class then
        local lr = T.Rank(live, n[F.NODE])
        if lr ~= r then GameTooltip:AddLine(("Im Spiel: Rang %d"):format(lr), 0.56, 0.53, 0.64) end
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
local function talentButton(tree)
    local b = CreateFrame("Button", nil, tree)
    b:SetSize(BTN, BTN)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.border = b:CreateTexture(nil, "OVERLAY")
    b.border:SetPoint("CENTER")
    b.border:SetSize(BTN + 10, BTN + 10)
    b.edges = W.Border(b, GREY[1], GREY[2], GREY[3], 0)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b.icon)
    hl:SetColorTexture(1, 1, 1, 0.15)
    b.rankBg = b:CreateTexture(nil, "OVERLAY", nil, 1)
    b.rankBg:SetSize(26, 12)
    b.rankBg:SetPoint("BOTTOMRIGHT", 6, -5)
    b.rankBg:SetColorTexture(0, 0, 0, 0.8)
    b.rank = W.Text(b, "NumberFontNormalSmall", 30)
    b.rank:SetDrawLayer("OVERLAY", 2)
    b.rank:SetJustifyH("CENTER")
    b.rank:SetPoint("CENTER", b.rankBg, "CENTER", 0, 0)
    b:SetScript("OnClick", click)
    b:SetScript("OnEnter", tooltip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function setState(b, state)
    b.state = state
    local atlas = BORDER[state]
    if hasAtlas(atlas) and b.border:SetAtlas(atlas) then
        b.border:Show()
        W.SetBorderColor(b.edges, 0, 0, 0, 0)
    else
        b.border:SetColorTexture(0, 0, 0, 0)
        b.border.atlas = nil
        b.border.color = BORDER_COLOR[state]
        local c = BORDER_COLOR[state]
        W.SetBorderColor(b.edges, c[1], c[2], c[3], 1)
    end
    local locked = state == "locked"
    b.icon:SetDesaturated(locked)
    b.icon.desaturated = locked
    b.icon:SetVertexColor(locked and 0.6 or 1, locked and 0.6 or 1, locked and 0.6 or 1)
    local c = state == "maxed" and GOLD or (locked and GREY or GREEN)
    b.rank:SetTextColor(c[1], c[2], c[3])
end

local function cellOffset(n)
    return GRID.left + n[F.COL] * GRID.pitchX + GRID.pad, -(GRID.top + n[F.ROW] * GRID.pitchY)
end

-- An arrow from the prerequisite src to node dst (both on one tree, one column or one row).
local function arrow(tree, srcBtn, dstBtn, src, dst)
    local a = { line = tree:CreateTexture(nil, "ARTWORK"), head = tree:CreateTexture(nil, "OVERLAY") }
    a.head:SetSize(14, 14)
    if src[F.COL] == dst[F.COL] then
        a.dir = src[F.ROW] < dst[F.ROW] and "down" or "up"
        a.line:SetWidth(4)
        if a.dir == "down" then
            a.line:SetPoint("TOP", srcBtn, "BOTTOM", 0, 0)
            a.line:SetPoint("BOTTOM", dstBtn, "TOP", 0, 4)
            a.head:SetPoint("CENTER", dstBtn, "TOP", 0, 3)
        else
            a.line:SetPoint("BOTTOM", srcBtn, "TOP", 0, 0)
            a.line:SetPoint("TOP", dstBtn, "BOTTOM", 0, -4)
            a.head:SetPoint("CENTER", dstBtn, "BOTTOM", 0, -3)
        end
    else
        a.dir = src[F.COL] < dst[F.COL] and "right" or "left"
        a.line:SetHeight(4)
        if a.dir == "right" then
            a.line:SetPoint("LEFT", srcBtn, "RIGHT", 0, 0)
            a.line:SetPoint("RIGHT", dstBtn, "LEFT", -4, 0)
            a.head:SetPoint("CENTER", dstBtn, "LEFT", -3, 0)
        else
            a.line:SetPoint("RIGHT", srcBtn, "LEFT", 0, 0)
            a.line:SetPoint("LEFT", dstBtn, "RIGHT", 4, 0)
            a.head:SetPoint("CENTER", dstBtn, "RIGHT", 3, 0)
        end
    end
    if a.head.SetRotation then a.head:SetRotation(TURN[a.dir]) end
    a.src, a.dst = src[F.NODE], dst[F.NODE]
    return a
end

local function paintArrow(a, plan)
    local met = T.Rank(plan, a.src) >= T.Node(plan.class, a.src)[F.MAX]
    local atlas = met and "talents-arrow-head-yellow" or "talents-arrow-head-gray"
    local c = met and GOLD or GREY
    a.line:SetColorTexture(c[1], c[2], c[3], 0.9)
    if hasAtlas(atlas) and a.head:SetAtlas(atlas) then a.head:Show() else a.head:Hide() end
end

-- Throws away the buttons and arrows of the class shown before and builds the ones of cls.
local function buildClass(cls)
    for _, b in pairs(page.buttons) do b:Hide() end
    for _, a in pairs(page.arrows) do a.line:Hide() a.head:Hide() end
    page.buttons, page.arrows = {}, {}
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
        -- the row locks: the highest a row's talents need
        for row = 1, ROWS do
            local req = 0
            for _, n in ipairs(c.order[t]) do
                if n[F.ROW] == row - 1 then req = math.max(req, T.GateReq(n)) end
            end
            local label = tree.rowLabels[row]
            label:SetText(req > 0 and tostring(req) or "")
            label:SetShown(req > 0)
        end
        tree.icon:SetTexture(T.TreeIcon(cls, t) or ICON)
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

local function makeTree(f, t)
    local tree = W.Inset(f)
    tree:SetSize(TREE_W, TREE_H)
    tree:SetPoint("TOPLEFT", f, "TOPLEFT", (t - 1) * (TREE_W + TREE_GAP), -TREE_TOP)
    tree.head = CreateFrame("Frame", nil, tree)
    tree.head:SetPoint("TOPLEFT", 4, -4)
    tree.head:SetPoint("TOPRIGHT", -4, -4)
    tree.head:SetHeight(HEAD_H - 4)
    W.Flat(tree.head, 0, 0, 0, 0.55)
    tree.icon = tree.head:CreateTexture(nil, "ARTWORK")
    tree.icon:SetSize(16, 16)
    tree.icon:SetPoint("LEFT", 3, 0)
    tree.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    tree.name = W.Text(tree.head, "GameFontNormal", 120)
    tree.name:SetPoint("LEFT", 24, 0)
    tree.pts = W.Text(tree.head, "GameFontHighlight", 26)
    tree.pts:SetJustifyH("RIGHT")
    tree.pts:SetPoint("RIGHT", -24, 0)
    tree.reset = W.ResetButton(tree.head, 16, function()
        T.ResetTree(page.plan, t)
        save()
        say("")
        ns.Refresh()
    end)
    tree.reset:SetPoint("RIGHT", -3, 0)
    W.Tooltip(tree.reset, "Baum zurücksetzen", "Nimmt alle Punkte aus diesem Baum.")
    tree.rowLabels = {}
    for row = 1, ROWS do
        local l = W.Text(tree, "GameFontDisableSmall", 16)
        l:SetJustifyH("CENTER")
        l:SetPoint("TOPLEFT", 1, -(GRID.top + (row - 1) * GRID.pitchY + BTN / 2 - 6))
        tree.rowLabels[row] = l
    end
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
    say(("Code übernommen: %s, %d Punkte."):format(T.ClassName(plan.class), spent))
    ns.Refresh()
end

local function create(parent)
    local f = CreateFrame("Frame", nil, parent)
    page = f
    f.buttons, f.arrows = {}, {}
    f.layoutInfo = GRID

    f.class = W.Picker(f, 130, function(v) chooseClass(v) end)
    f.class:SetPoint("TOPLEFT", 0, -1)
    f.levelLabel = W.Text(f, "GameFontHighlightSmall", 34)
    f.levelLabel:SetPoint("TOPLEFT", 140, -5)
    f.levelLabel:SetText("Stufe")
    f.level = W.Stepper(f, 76, function(v)
        T.State().level = v
        ns.Refresh()
    end)
    f.level:Configure(1, 60, 1)
    f.level:SetPoint("TOPLEFT", 176, -1)
    f.talentedLabel = W.Text(f, "GameFontHighlightSmall", 58)
    f.talentedLabel:SetPoint("TOPLEFT", 262, -5)
    f.talentedLabel:SetText("Talentiert")
    f.talented = W.Stepper(f, 64, function(v)
        T.State().talented = v
        ns.Refresh()
    end)
    f.talented:Configure(0, 5, 1)
    f.talented:SetPoint("TOPLEFT", 322, -1)
    f.talented:EnableMouse(true)
    W.Tooltip(f.talented, "Talentiert (Vermächtnis)",
        "Jeder Rang gibt die Talentpunkte eine Stufe früher (ab Stufe 9 bis 5); mehr als 51 Punkte gibt es nie.")
    f.total = W.Text(f, "GameFontHighlight", 206)
    f.total:SetJustifyH("RIGHT")
    f.total:SetPoint("TOPRIGHT", 0, -5)

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -(TREE_TOP + 3))
    f.bg:SetPoint("BOTTOMRIGHT", f, "TOPLEFT", 3 * TREE_W + 2 * TREE_GAP - 3, -(TREE_TOP + TREE_H - 3))
    f.trees = {}
    for t = 1, 3 do f.trees[t] = makeTree(f, t) end

    f.msg = W.Text(f, "GameFontHighlightSmall", 330)
    f.msg:SetPoint("TOPLEFT", 2, -(TREE_TOP + TREE_H + 4))
    f.liveText = W.Text(f, "GameFontHighlightSmall", 262)
    f.liveText:SetJustifyH("RIGHT")
    f.liveText:SetPoint("TOPRIGHT", 0, -(TREE_TOP + TREE_H + 4))

    f.live = W.Button(f, "Eigene laden", 104, function()
        local plan, info = T.Live()
        if not plan then
            say(info, true)
            return
        end
        page.plan = plan
        T.State().class = plan.class
        save()
        say(("Talente aus dem Spiel geladen (%d Punkte)."):format(T.Spent(plan)))
        ns.Refresh()
    end)
    f.live:SetPoint("BOTTOMLEFT", 0, 2)
    W.Tooltip(f.live, "Eigene Talente laden", "Übernimmt die Talente, die dein Charakter gerade hat.")
    f.resetAll = W.Button(f, "Alles zurücksetzen", 128, function()
        T.Reset(page.plan)
        save()
        say("")
        ns.Refresh()
    end)
    f.resetAll:SetPoint("LEFT", f.live, "RIGHT", 6, 0)
    f.codeLabel = W.Text(f, "GameFontHighlightSmall", 34)
    f.codeLabel:SetPoint("LEFT", f.resetAll, "RIGHT", 10, 0)
    f.codeLabel:SetText("Code")
    f.code = W.LineEdit(f, 600 - 104 - 6 - 128 - 10 - 34 - 4, onCode)
    f.code:SetPoint("LEFT", f.codeLabel, "RIGHT", 4, 0)
    -- a click into the box marks the code, ready to copy
    f.code:HookScript("OnEditFocusGained", function(self) self:HighlightText() end)
    W.Tooltip(f.code, "Build-Code", "Zum Teilen kopieren (Strg+C). Einen Code einfügen und Enter drücken übernimmt ihn.")
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
    f.total:SetText(("%s%d / %d|r Punkte%s"):format(over and "|cffff4040" or "|cffffffff", spent, pts,
        spent > 0 and need and (" · ab Stufe " .. need) or ""))

    for t = 1, 3 do
        local tree = f.trees[t]
        tree.name:SetText(T.TreeName(cls, t))
        tree.pts:SetText(tostring(T.Spent(plan, t)))
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
        f.liveText:SetText(("Im Spiel: %d/%d/%d · %d von %d Punkten"):format(T.Spent(live, 1), T.Spent(live, 2), T.Spent(live, 3),
            info.spent or T.Spent(live), info.total or T.PointsAt(UnitLevel("player") or 60, s.talented or 0)))
    else
        f.liveText:SetText(own and ("|cff8f86a3" .. tostring(info or "") .. "|r") or "")
    end
    f.live:SetEnabled(live ~= nil)
    if not f.code:HasFocus() then f.code:SetText(T.Encode(plan)) end
end

ns.RegisterPanel{ key = "talents", label = "Talente", icon = ICON, order = 56, group = "gear",
    available = function() return T.Available() end,
    create = create, refresh = refresh }

-- Opens the page; code: a share code to take over.
function ns.ShowTalents(code)
    if ns.ShowPage then ns.ShowPage("talents") end
    if code and code:find("%S") and page then onCode(code) end
end

ns.RegisterSlash("talente", { aliases = { "talents", "talent" }, args = "[Code]",
    desc = "Talentrechner öffnen (mit Code: Build übernehmen)",
    run = function(rest) ns.ShowTalents(rest) end })

-- the own talents changed in the game: show them while the page is open
local function changed()
    if page and page:IsShown() and ns.CurrentPage and ns.CurrentPage() == "talents" then ns.Refresh() end
end
ns.OnEvent("PLAYER_TALENT_UPDATE", changed)
ns.OnEvent("TRAIT_CONFIG_UPDATED", changed)
