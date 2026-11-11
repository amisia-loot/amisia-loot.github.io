-- The run timer window (F-166, D-96; the look of F-180, D-112: AmisiaRunTimer, tokens T.RUNTIMER). The
-- title is the dungeon's name (a wing as "Scharlachrotes Kloster: Friedhof", D-106). Under it three
-- values side by side, a grey word over a large white value: "Zeit" (the running total of
-- Gear/RunTimes.lua, GetTime only for the live display; after the end the final time), "Mob-XP" and
-- "Gold" (Gear/RunGains.lua: the own character's mob experience and looted money of this run; "-" for
-- the XP at the level cap). A grey line with the best time ("Bestzeit 24:12", "Noch keine Bestzeit",
-- "Bestzeit vorher ...", before the first fight "Die Uhr läuft ab dem ersten Kampf."), a thin gold
-- rule, the dungeon's bosses as round portraits in the game's order (the kit of the pages, W.Portrait):
-- grey while alive, in colour once killed in this run; the mouse names the boss, its split and the
-- difference to the best run's split (green faster, red slower) or, for the next boss, the best run's
-- split as the target. Under the heading "Rare" the dungeon's rare mobs (DungeonData.lua rares), grey
-- until seen dead in this run; a dungeon without rare data has no such row. At the bottom the result
-- ("Neue Bestzeit! -0:40", "Erste gemessene Zeit", "+1:40 zur Bestzeit", "Nicht beendet") and the link
-- "Alle Zeiten" (the part Zeiten of the page). Many bosses wrap into rows (W.Grid); the window grows.
-- It opens by itself when a clock starts (the settings runtimes.window and, in a raid, runtimes.raids),
-- stays while the clock runs (a ghost outside too), shows the result until the character leaves the
-- instance and closes when a clock ends unfinished. A plain frame, nothing secure: it is built on
-- entering an instance (out of combat), shown in a fight without any protected call. Movable, its
-- place in settings.runTimerWindow; Escape leaves it open.
local ADDON, ns = ...
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

function ns.ResetRunTimerPosition()
    local st = windowState()
    if st then st.point, st.x, st.y = nil, nil, nil end
    place()
end

---------------------------------------------------------------------------
-- Formats
---------------------------------------------------------------------------
-- copper as the client's coins (GetCoinTextureString, looked up defensively), from a gold coin on
-- without the copper; without the client's function "1g 46s" (its coin symbols, else g, s, c)
function TW.Money(copper)
    local c = math.max(0, math.floor(tonumber(copper) or 0))
    if c == 0 then return "0" end
    if c >= 10000 then c = c - c % 100 end
    local fn = _G.GetCoinTextureString
    if type(fn) == "function" then
        local ok, s = pcall(fn, c)
        s = ok and ns.Plain(s) or nil
        if type(s) == "string" and s ~= "" then return s end
    end
    local function sym(name, fallback)
        local v = _G[name]
        return type(v) == "string" and v ~= "" and v or fallback
    end
    local parts = {}
    local g, sv, cp = math.floor(c / 10000), math.floor(c % 10000 / 100), c % 100
    if g > 0 then parts[#parts + 1] = g .. sym("GOLD_AMOUNT_SYMBOL", "g") end
    if sv > 0 then parts[#parts + 1] = sv .. sym("SILVER_AMOUNT_SYMBOL", "s") end
    if cp > 0 then parts[#parts + 1] = cp .. sym("COPPER_AMOUNT_SYMBOL", "c") end
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
    p:EnableMouse(true)
    p:SetScript("OnEnter", showTip)
    p:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return p
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
    F:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + (elapsed or 0)
        if acc < S.TICK then return end
        acc = 0
        local l, secs = RT.Live()
        if l and l.k == shownKey then F.total:SetText(RT.Fmt(secs)) end
    end)
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

-- Shows list (portraits of pool, made on use) from y down: each item { npc, dim, tip }. Returns the
-- offset below them (y when none).
local function fillPortraits(pool, list, y)
    local shown = {}
    for i, it in ipairs(list) do
        local p = pool[i] or buildPortrait()
        pool[i] = p
        W.SetPortrait(p, it.npc)
        W.DimPortrait(p, it.dim)
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
    -- the bosses in the game's order: grey until killed in this run
    local lines = RT.Lines(key, rec)
    local passed = false   -- a later boss killed: an earlier one without a split was skipped
    for i = #lines, 1, -1 do
        if lines[i].split then passed = true elseif passed then lines[i].skipped = true end
    end
    local bosses = {}
    for i, x in ipairs(lines) do
        local tip, npc = TW.BossTip(key, x)
        bosses[i] = { npc = npc, dim = not x.split, tip = tip, key = x.enc }
    end
    y = fillPortraits(F.bosses, bosses, y)
    -- the rares: grey until seen dead in this run
    local killed = (mode == "live" and rec and rec.rk) or (mode == "done" and done.rk) or {}
    local rares = {}
    for i, r in ipairs(RT.Rares(key)) do
        rares[i] = { npc = r[1], dim = not killed[r[1]], tip = TW.RareTip(r, killed[r[1]]), key = r[1] }
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
    F.all:SetPoint("TOPRIGHT", -S.PAD, y)
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
