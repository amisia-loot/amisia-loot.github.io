-- The run timer window (F-166, D-96; the look of F-180, D-112: AmisiaRunTimer, tokens T.RUNTIMER). The
-- title is the dungeon's name (a wing as "Scharlachrotes Kloster: Friedhof", D-106). Under it three
-- values side by side, a grey word over a large white value: "Zeit" (the running total of
-- Gear/RunTimes.lua, GetTime only for the live display; after the end the final time), "Mob-XP" and
-- "Gold" (Gear/RunGains.lua: the own character's mob experience and looted money of this run; "-" for
-- the XP at the level cap). A grey line with the best time ("Bestzeit 24:12", "Noch keine Bestzeit",
-- "Bestzeit vorher ...", before the first fight "Die Uhr läuft ab dem ersten Kampf."), a thin gold
-- rule, the dungeon's bosses as round portraits in the game's order (the kit of the pages, W.Portrait):
-- in colour while alive, crossed out in red and stepped back once killed in this run; the mouse names
-- the boss, its split and the difference to the best run's split (green faster, red slower) or, for the
-- next boss, the best run's split as the target. Under the heading "Rare" the dungeon's rare mobs
-- (DungeonData.lua rares), stepped back, crossed out once seen dead in this run; a dungeon without rare
-- data has no such row. "Gold" shows numbers with the client's coin icons. At the bottom the result
-- ("Neue Bestzeit! -0:40", "Erste gemessene Zeit", "+1:40 zur Bestzeit", "Nicht beendet") and the link
-- "Alle Zeiten" (the part Zeiten of the page). Many bosses wrap into rows (W.Grid); the window grows.
-- It opens by itself when a clock starts (the settings runtimes.window and, in a raid, runtimes.raids),
-- stays while the clock runs (a ghost outside too), shows the result until the character leaves the
-- instance and closes when a clock ends unfinished. A plain frame, nothing secure: it is built on
-- entering an instance (out of combat), shown in a fight without any protected call. Movable, its
-- place in settings.runTimerWindow; the grip in the lower right corner scales it (its scale there
-- too); Escape leaves it open.
local ADDON, ns = ...
ns.Load(function()
local L = ns.L
local W, T = ns.W, ns.Theme
local S = T.RUNTIMER
local RT = ns.RunTimes

local TW = {}
ns.RunTimer = TW

local F
local shownKey     -- the instance the window shows

local GREEN, RED, GREY = T.GREEN, T.RED, T.GREY

local TEXT = {
    time = L["Zeit"], xp = L["Mob-XP"], gold = L["Gold"], rare = L["Rare##Lauf"],
    split = L["Zwischenzeit %s"], toBest = L["%s zum besten Lauf"], target = L["Ziel: %s (bester Lauf)"],
    bestRun = L["Bester Lauf: %s"], alive = L["Noch nicht getötet"], killed = L["getötet"],
    skipped = L["Übersprungen"],
    rareHint = L["Ein Rarer erscheint nicht in jedem Lauf. Er zählt als getötet, sobald du ihn tot siehst (als Ziel, unter der Maus oder beim Plündern)."],
}

local function windowState()
    if not AmisiaDB then return nil end
    AmisiaDB.settings = AmisiaDB.settings or {}
    if type(AmisiaDB.settings.runTimerWindow) ~= "table" then AmisiaDB.settings.runTimerWindow = {} end
    return AmisiaDB.settings.runTimerWindow
end

local function place()
    if F then W.PlaceWindow(F, windowState(), "RIGHT", UIParent, "RIGHT", -60, 80) end
end

-- The window's scale (the grip): s between SCALE_MIN and SCALE_MAX, kept in the window's state (nil at 1).
local function applyScale(s, keep)
    s = math.max(S.SCALE_MIN, math.min(S.SCALE_MAX, tonumber(s) or 1))
    if F then F:SetScale(s) end
    if keep then
        local st = windowState()
        if st then st.scale = math.abs(s - 1) > 0.005 and math.floor(s * 100 + 0.5) / 100 or nil end
    end
    return s
end
function TW.Scale() return F and F:GetScale() or 1 end
function TW.SetScale(s) return applyScale(s, true) end

function ns.ResetRunTimerPosition()
    local st = windowState()
    if st then st.point, st.x, st.y, st.scale = nil, nil, nil, nil end
    applyScale(1)
    place()
end

---------------------------------------------------------------------------
-- Formats
---------------------------------------------------------------------------
-- copper as numbers with the client's coin icons ("36 [silver] 76 [copper]"), from a gold coin on
-- without the copper so it fits its column. Built here from the money frame's three icons: the client's
-- own GetCoinTextureString is missing on Forever, and the letters of the fallback ("36S 76K") read badly.
function TW.Money(copper)
    local c = math.max(0, math.floor(tonumber(copper) or 0))
    if c == 0 then return "0" end
    if c >= 10000 then c = c - c % 100 end
    local parts = {}
    for _, coin in ipairs(S.COINS) do
        local n = math.floor(c / coin[1])
        c = c - n * coin[1]
        if n > 0 then parts[#parts + 1] = ("%d|T%s:%d:%d:1:0|t"):format(n, coin[2], S.COIN, S.COIN) end
    end
    return table.concat(parts, " ")
end

-- the mob XP: "-" at the level cap without any counted, else the number
function TW.XPText(x)
    x = math.max(0, math.floor(tonumber(x) or 0))
    if x == 0 and ns.RunGains and ns.RunGains.Capped() then return "-" end
    return tostring(x)
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
-- A column of the values: the grey word over the large white value, w wide.
local function buildValue(word, w)
    local c = CreateFrame("Frame", nil, F)
    c:SetSize(w, S.LABEL_H + S.VALUE_H)
    c.label = W.Text(c, T.FONT.hint, w)
    c.label:SetPoint("TOPLEFT", 0, 0)
    c.label:SetText(word)
    c.value = W.Text(c, T.FONT.big, w)
    c.value:SetPoint("TOPLEFT", 0, -S.LABEL_H)
    c.value:SetTextColor(1, 1, 1)
    return c
end

-- The tooltip of a portrait: p.tip = { title, line, ... } (a line may carry its colour codes).
local function showTip(self)
    local tip = self.tip
    if not tip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(tip[1], 1, 0.82, 0)
    for i = 2, #tip do GameTooltip:AddLine(tip[i], 0.85, 0.85, 0.85, true) end
    GameTooltip:Show()
end

local function buildPortrait()
    local p = W.Portrait(F, S.PORT)
    -- the red cross over a boss killed or a rare seen dead
    p.cross = p.top:CreateTexture(nil, "OVERLAY", nil, 2)
    p.cross:SetSize(S.CROSS, S.CROSS)
    p.cross:SetPoint("CENTER")
    p.cross:SetTexture(S.CROSS_TEX)
    p.cross:Hide()
    p:EnableMouse(true)
    p:SetScript("OnEnter", showTip)
    p:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return p
end

-- The grip in the lower right corner (the chat window's size grabber): dragging scales the whole
-- window between SCALE_MIN and SCALE_MAX; its top left corner stays where it is.
local function buildGrip()
    local g = CreateFrame("Button", nil, F)
    g:SetSize(S.GRIP, S.GRIP)
    g:SetPoint("BOTTOMRIGHT", -2, 2)
    g:SetFrameLevel(F:GetFrameLevel() + 20)
    g:SetNormalTexture(S.GRIP_TEX .. "Up")
    g:SetPushedTexture(S.GRIP_TEX .. "Down")
    g:SetHighlightTexture(S.GRIP_TEX .. "Highlight")
    local drag
    local function parentScale()
        local e = UIParent:GetEffectiveScale()
        return e and e > 0 and e or 1
    end
    -- the scale that puts the window's right edge under the cursor (screen x), and the window's top
    -- left corner back at its screen place
    local function follow()
        local x = GetCursorPosition()
        local pe = parentScale()
        local s = applyScale(((x or 0) - drag.grab - drag.left) / (S.W * pe))
        F:ClearAllPoints()
        F:SetPoint("TOPLEFT", UIParent, "TOPLEFT", drag.left / (pe * s), (drag.top - drag.screenTop) / (pe * s))
    end
    follow = ns.Perf.Wrap("OnUpdate RunTimer resize", follow)   -- /amisia leistung (F-184)
    g:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        local left, top, eff = F:GetLeft(), F:GetTop(), F:GetEffectiveScale()
        if not (left and top and eff and eff > 0) then return end
        local x = GetCursorPosition()
        drag = { left = left * eff, top = top * eff, screenTop = (UIParent:GetTop() or 0) * parentScale() }
        drag.grab = (x or 0) - (drag.left + S.W * eff)
        self:SetScript("OnUpdate", follow)
    end)
    local function stop(self)
        if not drag then return end
        self:SetScript("OnUpdate", nil)
        drag = nil
        applyScale(F:GetScale(), true)
        W.SaveWindowPlace(F, windowState())
    end
    g:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then stop(self) end
    end)
    g:SetScript("OnHide", stop)   -- the window closed mid-drag: no mouse up comes
    W.Tooltip(g, L["Größe ändern"], L["Ziehen: das Fenster kleiner oder größer."])
    g:Show()
    return g
end

local function build()
    if F then return F end
    F = W.Window("AmisiaRunTimer", S.W, S.TOP + S.BOTTOM_H, { title = L["Lauf-Zeiten"], strata = "MEDIUM",
        escape = false, onDragStop = function(f) W.SaveWindowPlace(f, windowState()) end })
    F.values = { buildValue(TEXT.time, S.COL_W[1]), buildValue(TEXT.xp, S.COL_W[2]), buildValue(TEXT.gold, S.COL_W[3]) }
    W.Row(F, F.values, 0, S.PAD, -S.TOP)
    F.total, F.xp, F.gold = F.values[1].value, F.values[2].value, F.values[3].value
    F.sub = W.Text(F, T.FONT.hint, S.W - 2 * S.PAD)
    F.sub:SetPoint("TOPLEFT", S.PAD, -(S.TOP + S.LABEL_H + S.VALUE_H + S.GAP))
    F.rule = W.GoldRule(F, 0.6)
    F.rareHead = W.Text(F, T.FONT.head, S.W - 2 * S.PAD)
    F.rareHead:SetText(TEXT.rare)
    F.result = W.Text(F, T.FONT.text, S.RESULT_W)
    F.all = W.Link(F, L["Alle Zeiten##Lauf"], function()
        if shownKey then RT.ShowPart(shownKey) end
    end)
    W.Tooltip(F.all, L["Alle Zeiten##Lauf"], L["Bestzeit, Zeiten je Boss und die letzten Läufe dieser Instanz auf ihrer Seite."])
    F.bosses, F.rares = {}, {}
    local acc = 0
    F:SetScript("OnUpdate", ns.Perf.Wrap("OnUpdate RunTimer", function(_, elapsed)
        acc = acc + (elapsed or 0)
        if acc < S.TICK then return end
        acc = 0
        local l, secs = RT.Live()
        if l and l.k == shownKey then F.total:SetText(RT.Fmt(secs)) end
    end))
    F.grip = buildGrip()
    local st = windowState()
    applyScale(st and st.scale or 1)
    place()
    return F
end
TW.Build = build

---------------------------------------------------------------------------
-- Filling
---------------------------------------------------------------------------
-- What the window shows for key: the live clock, else the run just ended there, else the best run as
-- the targets (waiting for the first fight).
local function stateOf(key)
    local l, secs = RT.Live()
    if l and l.k == key then return "live", l, secs end
    local d = RT.lastDone
    if d and d.k == key then return "done", d.run, d.run.t, d end
    return "wait", nil, 0
end

-- The shown name of NPC npc (the scanned name in the client's language), else name.
local function npcName(npc, name)
    return npc and ns.ScannedNpcName and ns.ScannedNpcName(npc) or name
end

-- The tooltip lines of boss line x (RT.Lines) of key: { title, line, ... }.
function TW.BossTip(key, x)
    local npc = ns.Dungeons and ns.Dungeons.BossNpc and ns.Dungeons.BossNpc(key, x.name) or nil
    local tip = { npcName(npc, x.name) }
    if x.split then
        tip[#tip + 1] = "|cffffffff" .. TEXT.split:format(RT.Fmt(x.split)) .. "|r"
        if x.diff then
            local c = x.diff < 0 and GREEN or x.diff > 0 and RED or GREY
            tip[#tip + 1] = c .. TEXT.toBest:format(RT.Diff(x.diff)) .. "|r"
        end
    else
        tip[#tip + 1] = GREY .. (x.skipped and TEXT.skipped or TEXT.alive) .. "|r"
        if x.best then
            tip[#tip + 1] = GREY .. (x.next and TEXT.target or TEXT.bestRun):format(RT.Fmt(x.best)) .. "|r"
        end
    end
    return tip, npc
end

-- The tooltip lines of rare r ({ npc, English name }), killed or not.
function TW.RareTip(r, killed)
    return { npcName(r[1], r[2]), killed and (GREEN .. TEXT.killed .. "|r") or (GREY .. TEXT.alive .. "|r"), GREY .. TEXT.rareHint .. "|r" }
end

-- Shows list (portraits of pool, made on use) from y down: each item { npc, dim (stepped back), done
-- (crossed out), tip }. Returns the
-- offset below them (y when none).
local function fillPortraits(pool, list, y)
    local shown = {}
    for i, it in ipairs(list) do
        local p = pool[i] or buildPortrait()
        pool[i] = p
        W.SetPortrait(p, it.npc)
        W.DimPortrait(p, it.dim)
        p.cross:SetShown(it.done and true or false)
        p.done = it.done and true or false
        p.tip = it.tip
        p.key, p.creature = it.key, it.npc
        p:Show()
        shown[i] = p
    end
    for i = #list + 1, #pool do pool[i]:Hide() end
    if #shown == 0 then return y end
    return W.Grid(F, shown, S.COLS, S.PORT_GAP, S.PORT_GAP, S.PAD, y)
end

local function resultText(mode, done)
    if mode ~= "done" then return "" end
    if not done.run.d then return GREY .. L["Nicht beendet"] .. "|r" end
    if done.best and done.prev then
        return GREEN .. L["Neue Bestzeit!"] .. " " .. RT.Diff(done.run.t - done.prev) .. "|r"
    elseif done.best then
        return GREEN .. L["Erste gemessene Zeit"] .. "|r"
    end
    return RED .. L["%s zur Bestzeit"]:format(RT.Diff(done.run.t - done.prev)) .. "|r"
end

local function refresh()
    if not F or not shownKey then return end
    local key = shownKey
    local mode, rec, secs, done = stateOf(key)
    local times = RT.Of(key)
    local best = times and times.best
    F:SetTitle((rec and rec.nm) or (done and done.nm) or RT.Name(key))
    -- the three values
    F.total:SetText(RT.Fmt(secs))
    F.xp:SetText(TW.XPText(rec and rec.x))
    F.gold:SetText(TW.Money(rec and rec.g))
    if mode == "wait" then
        F.sub:SetText(L["Die Uhr läuft ab dem ersten Kampf."])
    elseif done and done.best and done.prev then
        F.sub:SetText(L["Bestzeit vorher %s"]:format(RT.Fmt(done.prev)))
    elseif best then
        F.sub:SetText(L["Bestzeit %s"]:format(RT.Fmt(best.t)))
    else
        F.sub:SetText(L["Noch keine Bestzeit"])
    end
    local y = -(S.TOP + S.LABEL_H + S.VALUE_H + S.GAP + S.LINE_H + S.GAP)
    F.rule:ClearAllPoints()
    F.rule:SetPoint("TOPLEFT", S.PAD, y)
    F.rule:SetPoint("TOPRIGHT", -S.PAD, y)
    y = y - 1 - S.RULE_GAP
    -- the bosses in the game's order: in colour while they live, crossed out and stepped back once
    -- killed in this run (the user's picture of 2026-11-11)
    local lines = RT.Lines(key, rec)
    local passed = false   -- a later boss killed: an earlier one without a split was skipped
    for i = #lines, 1, -1 do
        if lines[i].split then passed = true elseif passed then lines[i].skipped = true end
    end
    local bosses = {}
    for i, x in ipairs(lines) do
        local tip, npc = TW.BossTip(key, x)
        bosses[i] = { npc = npc, dim = x.split and true or false, done = x.split and true or false, tip = tip, key = x.enc }
    end
    y = fillPortraits(F.bosses, bosses, y)
    -- the rares: stepped back (a rare is not there in every run), crossed out once seen dead in this run
    local killed = (mode == "live" and rec and rec.rk) or (mode == "done" and done.rk) or {}
    local rares = {}
    for i, r in ipairs(RT.Rares(key)) do
        rares[i] = { npc = r[1], dim = true, done = killed[r[1]] and true or false, tip = TW.RareTip(r, killed[r[1]]), key = r[1] }
    end
    if #rares > 0 then
        y = y - S.SECTION_GAP
        F.rareHead:ClearAllPoints()
        F.rareHead:SetPoint("TOPLEFT", S.PAD, y)
        F.rareHead:Show()
        y = y - S.HEAD_H
    else
        F.rareHead:Hide()
    end
    y = fillPortraits(F.rares, rares, y)
    -- the result and the link
    y = y - S.SECTION_GAP
    F.result:SetText(resultText(mode, done))
    F.result:ClearAllPoints()
    F.result:SetPoint("TOPLEFT", S.PAD, y - S.RESULT_Y)
    F.all:ClearAllPoints()
    F.all:SetPoint("TOPRIGHT", -(S.PAD + S.GRIP_ROOM), y)   -- clear of the grip in the corner
    F:SetHeight(-y + S.BOTTOM_H)
    TW.mode = mode
end
TW.Refresh = function() refresh() end

-- Shows the window for key (the instance's dungeon or raid key).
function TW.Show(key)
    if not key then return end
    build()
    shownKey = key
    refresh()
    F:Show()
end

function TW.Hide()
    if F then F:Hide() end
end

function TW.Shown() return F ~= nil and F:IsShown() and shownKey or nil end

-- A clock started (RunTimes.Fight): the window opens when the settings say so.
function TW.Started(kind)
    if not ns.Get("runtimes.window") then return end
    if kind == "raid" and not ns.Get("runtimes.raids") then return end
    local l = RT.Live()
    if l then TW.Show(l.k) end
end

ns.Listen("RUNTIMES", function(what)
    if not F or not F:IsShown() then return end
    -- a clock that ended unfinished closes the window; a finished one shows its result
    if what == "end" and TW.mode == "live" then
        F:Hide()
        return
    end
    refresh()
end)

-- Entering or leaving a world: built inside an instance before any fight; a running clock shows
-- again after a /reload; out of the instance after the end the window closes.
local function world()
    local inst = RT.InstanceNow()
    local l = RT.Live()
    if inst then build() end
    if l and not (F and F:IsShown()) and inst == l.i then
        TW.Started(select(2, RT.InstanceNow()))
    elseif F and F:IsShown() and not l and inst ~= (shownKey and ns.Runs.Fact(shownKey) or {}).inst then
        F:Hide()
    end
end
ns.OnEvent("PLAYER_ENTERING_WORLD", world)
ns.OnEvent("ZONE_CHANGED_NEW_AREA", world)
end)
