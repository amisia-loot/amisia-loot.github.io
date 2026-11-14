-- The page "Talente" and the window "Talentrechner" (AmisiaTalentFrame): WoW Forever's talent
-- trees of every class in the look of the game's classic three-tree talent window: three panels
-- side by side in a thin gold-brown frame, each on its part of the client's class art, its name and
-- points centred at the top (right-click there or its red X on hover resets the tree), a 4 x 7 grid
-- of square icons with a thin square frame and a rank plate, straight gold lines for the
-- prerequisites; over them the line "Stufe · Verfügbar · Verteilt · Übrig". Left click +1, right
-- click -1, shift for all ranks; the tooltip names what a talent still needs. Level and the Talented
-- perk set the free points; each class keeps two plans as share codes, "Primär" and "Sekundär". The
-- own class can load its talents from the game. The rules live in Talents.lua, the sizes and colours
-- in ns.Theme.TALENT.
-- D-76: on the page the classes (with their crests), the two plans and the actions (Eigene laden,
-- Plan leeren, Build importieren, Build exportieren) are marks of the side bar (jumps/jump);
-- the window has no side bar and keeps its own controls (class picker, plan tabs, buttons).
-- One builder (buildView) draws the view for a parent in a size profile: TALENT.PAGE on the page in
-- the main window (it grows with the window, T.PAGE_W_NOW and T.PAGE_H), TALENT.BIG in the window.
-- Both views show the one plan (S below): a click in one changes the other on its refresh. The
-- window is moved and scaled on its own (settings talentWindow and ui.talentScale, Ctrl + mouse
-- wheel over it).
local ADDON, ns = ...
ns.Load(function()
local W, T, Theme = ns.W, ns.Talents, ns.Theme
local L = ns.L
local F = T.F
local TT = Theme.TALENT
local LAY = Theme.LAYOUT

local ICON = "Interface\\Icons\\INV_Misc_Book_09"
-- the page area at the main window's own size: the page grows by what the window adds (D-71)
local PAGE_H0 = Theme.PAGE_H
local GOLD = TT.FRAME_COLOR.maxed
local RED = { 1, 0.1, 0.1 }
local TURN = { down = 0, right = math.pi / 2, left = -math.pi / 2, up = math.pi }
local HINT = L["Linksklick: +1 · Rechtsklick: -1 · Shift: alle Ränge"]
local SHORT_HINT = L["Linksklick + · Rechtsklick -"]

-- what both views show: the plan of the shown class, the talents in the game (own class)
local S = { plan = nil, live = nil }
local page, big, win
local refreshView

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

-- The plan a class opens with: its saved one in the shown slot, else (the own class, slot 1) the
-- talents in the game.
local function openPlan(cls)
    local plan, saved = T.LoadPlan(cls)
    if not saved and T.Slot() == 1 and cls == playerClass() then
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

-- The other plan slot of the shown class: the current plan saved, the slot's plan opened.
local SLOTS = { { 1, L["Primär"] }, { 2, L["Sekundär"] } }
local function chooseSlot(slot)
    if slot == T.Slot() then return end
    local cls = S.plan and S.plan.class or T.State().class
    if S.plan then save() end
    T.SetSlot(slot)
    if cls and T.Class(cls) then S.plan = openPlan(cls) else S.plan = nil end
    say((L["Plan %s"]):format(SLOTS[slot][2]))
    refreshAll()
end

-- The talents in the game as the plan (the own class).
local function loadLive()
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
end

-- Every point out of the shown plan.
local function resetPlan()
    if not S.plan then return end
    T.Reset(S.plan)
    save()
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
    v.bgClass = nil
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
    local tree = CreateFrame("Frame", nil, f)
    tree:SetSize(P.TREE_W, P.TREE_H)
    local g = TT.TREE_GROUND
    tree.ground = W.Flat(tree, g[1], g[2], g[3], g[4])
    -- the tree's part of the client's class art (paintArt), over the dark ground
    tree.bg = tree:CreateTexture(nil, "BACKGROUND", nil, 1)
    tree.bg:SetPoint("TOPLEFT", 1, -1)
    tree.bg:SetPoint("BOTTOMRIGHT", -1, 1)
    local e = TT.TREE_EDGE
    tree.edges = W.Border(tree, e[1], e[2], e[3], e[4])
    local head = CreateFrame("Frame", nil, tree)
    tree.head = head
    head:SetPoint("TOPLEFT", 0, 0)
    head:SetPoint("TOPRIGHT", 0, 0)
    head:SetHeight(P.HEAD_H)
    head:EnableMouse(true)
    -- the name keeps the X's room free on both sides, so it stays centred
    local nameW = P.TREE_W - 2 * (TT.RESET + TT.RESET_X + 2)
    tree.nameRoom = 2 * (TT.RESET + TT.RESET_X + 2)
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
    -- an empty box (the import mark emptied it, nothing pasted): the plan's code again, no error
    if not (type(text) == "string" and text:find("%S")) then
        if S.plan then v.code:SetText(T.Encode(S.plan)) end
        return
    end
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

-- The tree's part of the client's class art: the third of talent-background-<class> under tree t,
-- cut to the tree's shape (as wide as the tree's height allows, centred in the third); without the
-- atlas only the dark ground.
local function paintArt(f, cls)
    local name = "talent-background-" .. cls:lower()
    local info = hasAtlas(name) and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name)
    for t, tree in ipairs(f.trees) do
        local bg = tree.bg
        if hasAtlas(name) and bg:SetAtlas(name) then
            bg:SetAlpha(TT.BG_ALPHA)
            if info and (info.width or 0) > 0 and (info.height or 0) > 0 and f.treeH > 0 then
                local aw, ah = info.width, info.height
                local third = aw / 3
                local x0, x1, y0, y1
                local want = ah * f.treeW / f.treeH
                if want <= third then
                    local c = (t - 0.5) * third
                    x0, x1, y0, y1 = c - want / 2, c + want / 2, 0, ah
                else
                    local hh = third * f.treeH / f.treeW
                    x0, x1, y0, y1 = (t - 1) * third, t * third, (ah - hh) / 2, (ah + hh) / 2
                end
                local l, r = info.leftTexCoord or 0, info.rightTexCoord or 1
                local tp, bt = info.topTexCoord or 0, info.bottomTexCoord or 1
                bg:SetTexCoord(l + (r - l) * x0 / aw, l + (r - l) * x1 / aw, tp + (bt - tp) * y0 / ah, tp + (bt - tp) * y1 / ah)
            end
            bg:Show()
        else
            bg.atlas = nil
            bg:Hide()
        end
    end
    f.bgClass = cls
end

-- A talent's button at its row and column of the grid.
local function placeButton(f, b)
    local G, n = f.layoutInfo, b.node
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", f.trees[n[F.TREE]], "TOPLEFT", G.left + n[F.COL] * G.pitch, -(G.top + n[F.ROW] * G.pitch))
end

-- The view's size: the window's view keeps its profile's; the page takes the width and the height
-- the main window gives (T.PAGE_W_NOW, T.PAGE_H; never less than the profile's). The trees share the
-- width and grow down by the extra height; the grid stays centred in each tree. Places the trees, the
-- line over them, the line under them and the buttons again when the size changed.
local function layoutView(f)
    local P = f.P
    local VW, extraH = viewWidth(P), 0
    if f.grows then
        VW = math.max(VW, math.floor(Theme.PAGE_W_NOW or Theme.PAGE_W))
        extraH = math.max(0, math.floor((Theme.PAGE_H or PAGE_H0) - PAGE_H0))
    end
    if f.laidW == VW and f.laidH == extraH then return end
    f.laidW, f.laidH = VW, extraH
    local tw = math.floor((VW - 2 * P.TREE_GAP) / 3)
    local th = P.TREE_H + extraH
    f.treeW, f.treeH = tw, th
    for t, tree in ipairs(f.trees) do
        tree:SetSize(tw, th)
        tree:ClearAllPoints()
        tree:SetPoint("TOPLEFT", f, "TOPLEFT", (t - 1) * (tw + P.TREE_GAP), -f.treeTop)
        tree.name:SetWidth(tw - tree.nameRoom)
        tree.pts:SetWidth(tw - tree.nameRoom)
    end
    -- the grid of 4 columns centred in the tree: the button is the icon with its frame around it
    local G = f.layoutInfo
    G.left = math.floor((tw - (3 * G.pitch + G.button)) / 2)
    for _, b in pairs(f.buttons) do placeButton(f, b) end
    -- the four parts of the line over the trees, each a quarter of the width, centred
    local band = f.statBand
    for i, fs in ipairs(f.stats) do
        fs:ClearAllPoints()
        fs:SetWidth(math.floor(VW / 4))
        fs:SetPoint("LEFT", band, "LEFT", math.floor((i - 1) * VW / 4), 0)
    end
    -- under the trees: the last message at the left, the talents in the game at the right
    local lineY = -(f.treeTop + th + LAY.GAP)
    f.msg:ClearAllPoints()
    f.msg:SetWidth(VW - P.LIVE_W - 2 * LAY.TEXT_X - 8)
    f.msg:SetPoint("TOPLEFT", LAY.TEXT_X, lineY)
    f.liveText:ClearAllPoints()
    f.liveText:SetPoint("TOPLEFT", VW - LAY.TEXT_X - P.LIVE_W, lineY)
    if f.bgClass then paintArt(f, f.bgClass) end
end

-- The one builder of the talent view: a W.Page on parent in the sizes of profile P (TALENT.PAGE or
-- TALENT.BIG). opts.controls (the window): the class picker and the plan tabs in the head row,
-- "Eigene laden" and "Alles zurücksetzen" in the bottom row, the click hint as the footer; without
-- (the page) those are the side bar's marks (D-76), the page grows with the main window and the
-- short click hint stands at the bottom row's right end.
local function buildView(parent, P, opts)
    opts = opts or {}
    local VW = viewWidth(P)
    local f = W.Page(parent, opts.controls and { width = VW } or nil)
    f.P = P
    f.grows = not opts.controls
    f.buttons, f.arrows = {}, {}
    local btn = P.ICON + 2 * TT.FRAME
    f.layoutInfo = { left = 0, top = P.GRID_TOP, pitch = P.PITCH, button = btn }

    -- the window's head row: class, steppers, plan tabs; the line "Stufe · Verfügbar · Verteilt ·
    -- Übrig" under it (on the page it is the first band)
    if opts.controls then
        f:Bands({ "row", "line" })
        f.statBand = f.bands[2]
    else
        f:Bands({ "row" })
        f.statBand = f.bands[1]
    end
    f.treeTop = -f.top
    f.stats = {}
    for i = 1, 4 do
        local fs = W.Text(f, TT.STAT_FONT, math.floor(VW / 4))
        fs:SetJustifyH("CENTER")
        f.stats[i] = fs
    end
    f.statLevel, f.statFree, f.statSpent, f.statLeft = f.stats[1], f.stats[2], f.stats[3], f.stats[4]

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

    f.trees = {}
    for t = 1, 3 do f.trees[t] = makeTree(f, P, t) end
    f.msg = W.Text(f, Theme.FONT.text, VW - P.LIVE_W - 2 * LAY.TEXT_X - 8)
    f.liveText = W.Text(f, Theme.FONT.text, P.LIVE_W)
    f.liveText:SetJustifyH("RIGHT")

    f.codeLabel = W.Text(f, Theme.FONT.text, 34)
    f.codeLabel:SetText("Code")
    f.code = W.LineEdit(f, 200, function(text) onCode(f, text) end)
    -- a click into the box marks the code, ready to copy
    f.code:HookScript("OnEditFocusGained", function(self) self:HighlightText() end)
    W.Tooltip(f.code, L["Build-Code"], L["Zum Teilen kopieren (Strg+C). Einen Code oder einen Build-Link von talentsforever.com oder wowforevertalents.com einfügen und Enter drücken übernimmt ihn."])
    local steppers = { { f.levelLabel }, { f.level, gap = 2 }, { f.talentedLabel, gap = 10 }, { f.talented, gap = 2 } }

    if opts.controls then
        f.class = W.Picker(f, 130, function(v) chooseClass(v) end)
        -- the plan slot: Primär | Sekundär as two text tabs (D-67), a click switches
        f.slots = {}
        for i, s in ipairs(SLOTS) do
            f.slots[i] = W.Tab(f, s[2], function() chooseSlot(s[1]) end)
            W.Tooltip(f.slots[i], L["Zwei Pläne je Klasse"],
                L["Jede Klasse hat zwei gespeicherte Pläne, Primär und Sekundär. Ein Klick wechselt; der gezeigte Plan wird vorher gespeichert."])
        end
        steppers[1].gap = 10
        table.insert(steppers, 1, f.class)
        f:Place(1, steppers, { f.slots[1], f.slots[2] })
        f.live = W.Button(f, L["Eigene laden"], 104, loadLive)
        W.Tooltip(f.live, L["Eigene Talente laden"], L["Übernimmt die Talente, die dein Charakter gerade hat."])
        f.resetAll = W.Link(f, L["Alles zurücksetzen"], resetPlan)
        W.FitChip(f.live, 104)
        W.FitChip(f.resetAll)
        f:Footer({ { "hint", help = true } })
        f.hint:SetText(HINT)
        f:BottomRow({ f.live, f.resetAll, { f.codeLabel, gap = 10 }, { f.code, gap = 4, fill = true } })
    else
        f.hint = W.Text(f, Theme.FONT.hint, P.HINT_W)
        f.hint:SetJustifyH("RIGHT")
        f.hint:SetText(SHORT_HINT)
        steppers[#steppers + 1] = { f.codeLabel, gap = 10 }
        steppers[#steppers + 1] = { f.code, gap = 4, fill = true }
        f:BottomRow(steppers, { f.hint })
        W.FollowWidth(f, function() layoutView(f) end)
    end
    layoutView(f)
    return f
end

-- The line over the trees: the level (red with the level the plan needs when it gives too few
-- points), the points the level gives, the points spent and what is left (red when too many).
local function statLine(f, s, spent, pts, need)
    local W1, R = "|cffffffff", "|cffff4040"
    local level = s.level or 60
    local lv = W1 .. level .. "|r"
    if spent > pts and need then lv = R .. level .. "|r " .. (L["(ab %d)"]):format(need) end
    local c = spent > pts and R or W1
    f.statLevel:SetText(L["Stufe:"] .. " " .. lv)
    f.statFree:SetText(L["Verfügbar:"] .. " " .. W1 .. pts .. "|r")
    f.statSpent:SetText(L["Verteilt:"] .. " " .. c .. spent .. "|r")
    f.statLeft:SetText(L["Übrig:"] .. " " .. c .. (pts - spent) .. "|r")
end

refreshView = function(f)
    if not f then return end
    local s = T.State()
    local cls = S.plan and S.plan.class or s.class
    if not T.Class(cls or "") then cls = T.Classes()[1] end
    if not cls then return end
    if not S.plan or S.plan.class ~= cls then S.plan = openPlan(cls) end
    s.class = cls
    layoutView(f)
    if f.builtClass ~= cls then buildClass(f, cls) end
    if f.bgClass ~= cls then paintArt(f, cls) end

    if f.class then
        local values = {}
        for _, c in ipairs(T.Classes()) do values[#values + 1] = { value = c, text = T.ClassName(c) } end
        f.class:SetValues(values)
        f.class:SetValue(cls)
    end
    f.level:SetValue(s.level or 60)
    f.talented:SetValue(s.talented or 0)
    if f.slots then
        for i, tab in ipairs(f.slots) do tab:SetOn(SLOTS[i][1] == T.Slot()) end
    end

    local plan, pts = S.plan, points()
    local spent = T.Spent(plan)
    statLine(f, s, spent, pts, T.LevelFor(spent, s.talented or 0))

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
    if f.live then f.live:SetEnabled(live ~= nil) end
    if not f.code:HasFocus() then f.code:SetText(T.Encode(plan)) end
end

local function create(parent)
    page = buildView(parent, TT.PAGE)
    return page
end

---------------------------------------------------------------------------
-- The page's marks in the side bar (D-75, D-76): the classes with their crests (the shown one
-- chosen), the two plans, the actions
---------------------------------------------------------------------------
local function crest(cls)
    local CI = Theme.CLASS_ICON
    local tc = type(_G.CLASS_ICON_TCOORDS) == "table" and _G.CLASS_ICON_TCOORDS[cls] or CI.COORDS[cls]
    if type(tc) ~= "table" then return nil end
    return { file = CI.TEXTURE, coords = { tc[1], tc[2], tc[3], tc[4] } }
end

-- The import mark: the box emptied and focused for a code or a build link (Enter takes it).
local function importBox(v)
    v.code:SetText("")
    v.code:SetFocus()
    say(L["Code oder Build-Link einfügen und Enter drücken."])
end

-- The export mark: the box with the plan's code, focused and marked for Ctrl+C (the game gives an
-- addon no clipboard).
local function exportBox(v)
    if not S.plan then return end
    v.code:SetText(T.Encode(S.plan))
    v.code:SetFocus()
    v.code:HighlightText()
    say(L["Der Code ist markiert: Strg+C kopiert ihn."])
end

local function marks()
    local out = {}
    local shown = S.plan and S.plan.class or T.State().class
    for _, c in ipairs(T.Classes()) do
        out[#out + 1] = { key = "class:" .. c, label = T.ClassName(c), icon = crest(c), on = c == shown }
    end
    local tip = L["Jede Klasse hat zwei gespeicherte Pläne, Primär und Sekundär. Ein Klick wechselt; der gezeigte Plan wird vorher gespeichert."]
    for i, s in ipairs(SLOTS) do
        out[#out + 1] = { key = "slot:" .. s[1], label = (L["Plan %d: %s"]):format(i, s[2]), on = s[1] == T.Slot(),
            rule = i == 1, tip = tip }
    end
    local M = TT.MARKS
    local acts = {}
    if shown and shown == playerClass() then
        acts[#acts + 1] = { key = "live", label = L["Eigene laden"], icon = M.live, tip = L["Übernimmt die Talente, die dein Charakter gerade hat."] }
    end
    acts[#acts + 1] = { key = "reset", label = L["Plan leeren"], icon = M.reset, tip = L["Nimmt alle Punkte aus dem gezeigten Plan."] }
    acts[#acts + 1] = { key = "import", label = L["Build importieren"], icon = M.import,
        tip = L["Einen Code oder einen Build-Link von talentsforever.com oder wowforevertalents.com ins Feld Code einfügen und Enter drücken."] }
    acts[#acts + 1] = { key = "export", label = L["Build exportieren"], icon = M.export,
        tip = L["Markiert den Code des Plans im Feld Code: Strg+C kopiert ihn zum Teilen."] }
    acts[1].rule = true
    for _, a in ipairs(acts) do out[#out + 1] = a end
    return out
end

local function jump(v, key)
    local cls = key:match("^class:(.+)$")
    local slot = tonumber(key:match("^slot:(%d)$") or "")
    if cls then
        chooseClass(cls)
    elseif slot then
        chooseSlot(slot)
    elseif key == "live" then
        loadLive()
    elseif key == "reset" then
        resetPlan()
    elseif key == "import" then
        importBox(v)
    elseif key == "export" then
        exportBox(v)
    end
end

ns.RegisterPanel{ key = "talents", label = L["Talente"], sub = L["Talente planen und mit deinen vergleichen."], icon = ICON, order = 53, group = "talents",
    available = function() return T.Available() end,
    create = create, refresh = refreshView,
    jumps = function() return T.Available() and marks() or {} end, jump = jump }

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
    if win then W.PlaceWindow(win, winState(), "CENTER") end
end

local function savePlace(f) W.SaveWindowPlace(f, winState()) end

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
    if v ~= cur then ns.Set("ui.talentScale", v); ns.Refresh() end
end

local function buildWindow()
    local P, WT = TT.BIG, TT.WINDOW
    local VW = viewWidth(P)
    -- head row, the line of points, trees, the message line, the bottom row, the hint (the gaps of
    -- ns.Theme.LAYOUT)
    local VH = LAY.ROW_H + LAY.GAP + LAY.LINE_H + LAY.GAP + P.TREE_H + LAY.GAP + LAY.LINE_H + LAY.GAP + LAY.ROW_H + LAY.GAP + LAY.LINE_H
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
    big = buildView(body, P, { controls = true })
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
    desc = L["Talentrechner öffnen (mit Code oder Build-Link: Build übernehmen, gross: großes Fenster)"],
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
end)
