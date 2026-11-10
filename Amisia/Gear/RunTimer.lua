-- The run timer window (F-166, D-96, AmisiaRunTimer, tokens T.RUNTIMER): the instance's name as the
-- title, the running total (Gear/RunTimes.lua; GetTime only for the live display), a grey line with
-- the best time, one row per boss in the game's order: its name, the split when killed and beside it
-- the difference to the best run's split (green faster "-0:12", red slower "+0:07"); the next boss
-- shows the best run's split in grey as its target. At the end "Neue Bestzeit!" or the difference, and
-- the link "Alle Zeiten" (the part Zeiten of the page). It opens by itself when a clock starts (the
-- settings runtimes.window and, in a raid, runtimes.raids), stays while the clock runs (a ghost
-- outside too), shows the result until the character leaves the instance and closes when a clock
-- ends unfinished. A plain frame, nothing secure: it is built on entering an instance (out of
-- combat), shown in a fight without any protected call. Movable, its place in
-- settings.runTimerWindow; Escape leaves it open.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme
local S = T.RUNTIMER
local RT = ns.RunTimes

local TW = {}
ns.RunTimer = TW

local F
local shownKey     -- the instance the window shows
local rows = {}

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

local function rowY(i)
    return -(S.TOP + S.TOTAL_H + S.LINE_H + S.GAP + (i - 1) * S.ROW_H)
end

local function buildRow(i)
    local r = {}
    r.name = W.Text(F, T.FONT.text, S.NAME_W)
    r.name:SetPoint("TOPLEFT", S.PAD, rowY(i))
    r.diff = W.Text(F, T.FONT.text, S.DIFF_W)
    r.diff:SetPoint("TOPRIGHT", -S.PAD, rowY(i))
    r.diff:SetJustifyH("RIGHT")
    r.split = W.Text(F, T.FONT.text, S.SPLIT_W)
    r.split:SetPoint("TOPRIGHT", -(S.PAD + S.DIFF_W + S.GAP), rowY(i))
    r.split:SetJustifyH("RIGHT")
    return r
end

local function build()
    if F then return F end
    F = W.Window("AmisiaRunTimer", S.W, S.TOP + S.TOTAL_H + S.LINE_H + S.BOTTOM_H, { title = L["Lauf-Zeiten"], strata = "MEDIUM",
        escape = false, onDragStop = function(f) W.SaveWindowPlace(f, windowState()) end })
    F.total = W.Text(F, T.FONT.big, S.W - 2 * S.PAD)
    F.total:SetPoint("TOPLEFT", S.PAD, -S.TOP)
    F.sub = W.Text(F, T.FONT.hint, S.W - 2 * S.PAD)
    F.sub:SetPoint("TOPLEFT", S.PAD, -(S.TOP + S.TOTAL_H))
    F.result = W.Text(F, T.FONT.body, S.W - 2 * S.PAD)
    F.all = W.Link(F, L["Alle Zeiten##Lauf"], function()
        if shownKey then RT.ShowPart(shownKey) end
    end)
    W.Tooltip(F.all, L["Alle Zeiten##Lauf"], L["Bestzeit, Zeiten je Boss und die letzten Läufe dieser Instanz auf ihrer Seite."])
    F.rows = rows
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

local GREEN, RED, GREY = T.GREEN, T.RED, T.GREY

-- What the window shows for key: the live clock, else the run just ended there, else the best run as
-- the targets (waiting for the first fight).
local function stateOf(key)
    local l, secs = RT.Live()
    if l and l.k == key then return "live", l, secs end
    local d = RT.lastDone
    if d and d.k == key then return "done", d.run, d.run.t, d end
    return "wait", nil, 0
end

local function refresh()
    if not F or not shownKey then return end
    local key = shownKey
    local mode, rec, secs, done = stateOf(key)
    local times = RT.Of(key)
    local best = times and times.best
    F:SetTitle((rec and rec.nm) or (done and done.nm) or RT.Name(key))
    F.total:SetText(RT.Fmt(secs))
    if mode == "wait" then
        F.sub:SetText(L["Die Uhr läuft ab dem ersten Kampf."])
    elseif done and done.best and done.prev then
        F.sub:SetText(L["Bestzeit vorher %s"]:format(RT.Fmt(done.prev)))
    elseif best then
        F.sub:SetText(L["Bestzeit %s"]:format(RT.Fmt(best.t)))
    else
        F.sub:SetText(L["Noch keine Bestzeit"])
    end
    local lines = RT.Lines(key, rec)
    local n = math.min(#lines, S.MAX_ROWS)
    for i = 1, n do
        rows[i] = rows[i] or buildRow(i)
        local r, x = rows[i], lines[i]
        r.name:SetText(x.split and x.name or (GREY .. x.name .. "|r"))
        if x.split then
            r.split:SetText(RT.Fmt(x.split))
            if x.diff then
                r.diff:SetText((x.diff < 0 and GREEN or x.diff > 0 and RED or GREY) .. RT.Diff(x.diff) .. "|r")
            else
                r.diff:SetText("")
            end
        elseif (x.next or mode == "wait") and x.best then
            -- the target: the best run's split
            r.split:SetText(GREY .. RT.Fmt(x.best) .. "|r")
            r.diff:SetText("")
        else
            r.split:SetText(GREY .. "-|r")
            r.diff:SetText("")
        end
        r.name:Show(); r.split:Show(); r.diff:Show()
    end
    for i = n + 1, #rows do
        rows[i].name:Hide(); rows[i].split:Hide(); rows[i].diff:Hide()
    end
    -- the result line
    local result = ""
    if mode == "done" then
        if done.run.d then
            if done.best and done.prev then
                result = GREEN .. L["Neue Bestzeit!"] .. " " .. RT.Diff(done.run.t - done.prev) .. "|r"
            elseif done.best then
                result = GREEN .. L["Erste gemessene Zeit"] .. "|r"
            else
                result = RED .. L["%s zur Bestzeit"]:format(RT.Diff(done.run.t - done.prev)) .. "|r"
            end
        else
            result = GREY .. L["Nicht beendet"] .. "|r"
        end
    end
    F.result:SetText(result)
    local bottom = rowY(n + 1) - S.GAP
    F.result:ClearAllPoints()
    F.result:SetPoint("TOPLEFT", S.PAD, bottom)
    F.all:ClearAllPoints()
    F.all:SetPoint("TOPRIGHT", -S.PAD, bottom - S.LINE_H)
    F:SetHeight(-bottom + S.BOTTOM_H)
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
