-- Pull and break timer (F-164, D-94): `/amisia pull [Sekunden]` (3 to 60, default pull.seconds; "stop"
-- or 0 cancels) and `/amisia raidpause [Minuten]` (en `break`; 1 to 30, default pull.minutes; "stop"
-- cancels; `/amisia pause <Minuten>` too). In a raid the leader or an assistant, in a party the leader
-- starts it for the group; alone it runs only here. The pull timer never starts in combat.
-- The group sees the pull through the client's own countdown when the client has it
-- (C_PartyInfo.DoCountdown, looked up when used; the big numbers for everyone, no addon needed) and
-- one line "Pull in 10 Sekunden" in the group chat (raid warning when allowed, else raid or party
-- chat, ns.Say); without the client's countdown the chat also counts 5 4 3 2 1 and "Pull!". The break
-- says "Pause: 5 Minuten (bis HH:MM)", "Pause: noch 1 Minute" and "Pause vorbei". The chat lockdown of
-- a boss fight (Forever) stops it quietly with one line in the own chat, like a line the client
-- refuses. The running timer shows in the main window's status line (ns.PullTimerStatus, event
-- PULLTIMER) and its menu offers start and cancel. Nothing is saved; a /reload ends it here (the
-- client's countdown runs on).
local ADDON, ns = ...
ns.Load(function()
local L = ns.L

local PULL_MIN, PULL_MAX = 3, 60       -- seconds of a pull timer
local BREAK_MIN, BREAK_MAX = 1, 30     -- minutes of a break
local COUNT_FROM = 5                   -- the chat counts the last seconds from here (no client countdown)
local PULL_TTL = 1.5                   -- a countdown line is worthless a moment later
local BREAK_TTL = 30

local PT = {}
ns.PullTimer = PT
PT.PULL_MIN, PT.PULL_MAX, PT.BREAK_MIN, PT.BREAK_MAX = PULL_MIN, PULL_MAX, BREAK_MIN, BREAK_MAX

local cur          -- the running timer: { kind = "pull"/"break", ends (GetTime), total, group, client, said = {} }
local ticker

local function changed() ns.Fire("PULLTIMER") end

-- The client's countdown function, or nil.
local function countdownFn()
    local api = _G.C_PartyInfo
    local fn = type(api) == "table" and api.DoCountdown
    return type(fn) == "function" and fn or nil
end

-- Whether the chat may carry the lines now: not in the lockdown of a boss fight (chat or encounter).
local function chatClosed()
    return ns.ChatLocked() or ns.AddOnRestricted(1) or ns.AddOnRestricted(5)
end

-- Who starts it: "group" (raid leader or assistant, party leader), "local" (alone), or nil and the
-- reason (in a group without the lead).
function PT.Mode()
    if not IsInGroup() then return "local" end
    if UnitIsGroupLeader("player") then return "group" end
    if ns.HomeRaid() and UnitIsGroupAssistant("player") then return "group" end
    return nil, ns.HomeRaid() and L["Nur als Leiter oder Assistent"] or L["Nur als Gruppenleiter"]
end

local function stopTicker()
    if ticker then ticker:Cancel() end
    ticker = nil
end

local function finish()
    cur = nil
    stopTicker()
    changed()
end

-- A line to the group; false (and the timer ended with one own line) when it cannot go out.
local function say(text, ttl)
    if not cur or not cur.group then return true end
    if chatClosed() then
        finish()
        ns.msg(L["Timer angehalten: der Chat ist im Bosskampf gesperrt."])
        return false
    end
    local ok = ns.Say(text, "RAID_WARNING", nil, { ttl = ttl, key = "pulltimer" })
    if not ok then
        finish()
        ns.msg(L["Timer angehalten: die Zeile ging nicht in den Gruppenchat."])
        return false
    end
    return true
end

local function left()
    return cur and math.max(0, math.ceil(cur.ends - GetTime() - 0.001)) or 0
end

local function minutesText(m)
    if m == 1 then return L["1 Minute"] end
    return L["%d Minuten"]:format(m)
end

local function tick()
    if not cur then return stopTicker() end
    local s = left()
    if cur.kind == "pull" then
        if s <= 0 then
            if cur.group and not cur.client then say(L["Pull!"], PULL_TTL) end
            if not cur.group then ns.msg(L["Pull!"]) end
            return finish()
        end
        if cur.group and not cur.client and s <= COUNT_FROM and not cur.said[s] then
            cur.said[s] = true
            if not say(tostring(s), PULL_TTL) then return end
        end
    else
        if s <= 0 then
            if cur.group then say(L["Pause vorbei"], BREAK_TTL) else ns.msg(L["Pause vorbei"]) end
            return finish()
        end
        -- one minute left: once, when the break was longer than that
        if s <= 60 and cur.total > 60 and not cur.said.minute then
            cur.said.minute = true
            local line = L["Pause: noch %s"]:format(minutesText(1))
            if cur.group then
                if not say(line, BREAK_TTL) then return end
            else
                ns.msg(line)
            end
        end
    end
    changed()
end

local function start(kind, seconds, mode)
    stopTicker()
    cur = { kind = kind, ends = GetTime() + seconds, total = seconds, group = mode == "group", said = {} }
    ticker = C_Timer.NewTicker(0.25, ns.Perf.Wrap("Ticker PullTimer", tick))
end

-- Starts a pull timer of seconds (nil: the setting). Returns true, or nil and the reason (said by the caller).
function PT.Pull(seconds)
    seconds = tonumber(seconds) or ns.Get("pull.seconds")
    seconds = math.floor(seconds + 0.5)
    if seconds < PULL_MIN or seconds > PULL_MAX then
        return nil, L["Pull-Timer: %d bis %d Sekunden."]:format(PULL_MIN, PULL_MAX)
    end
    if InCombatLockdown() then return nil, L["Nicht im Kampf"] end
    local mode, why = PT.Mode()
    if not mode then return nil, why end
    if mode == "group" and chatClosed() then return nil, L["Der Chat ist im Bosskampf gesperrt."] end
    start("pull", seconds, mode)
    if mode == "group" then
        local fn = countdownFn()
        cur.client = fn ~= nil and pcall(fn, seconds) or false
        -- a line that cannot go out ended the timer and said why
        if not say(L["Pull in %d Sekunden"]:format(seconds), PULL_TTL + 1) then return nil end
    else
        ns.msg(L["Pull in %d Sekunden"]:format(seconds) .. " " .. L["(nur bei dir: du bist in keiner Gruppe)"])
    end
    changed()
    return true
end

-- Starts a break of minutes (nil: the setting). Returns true, or nil and the reason.
function PT.Break(minutes)
    minutes = tonumber(minutes) or ns.Get("pull.minutes")
    minutes = math.floor(minutes + 0.5)
    if minutes < BREAK_MIN or minutes > BREAK_MAX then
        return nil, L["Pause: %d bis %d Minuten."]:format(BREAK_MIN, BREAK_MAX)
    end
    local mode, why = PT.Mode()
    if not mode then return nil, why end
    if mode == "group" and chatClosed() then return nil, L["Der Chat ist im Bosskampf gesperrt."] end
    -- a pull timer that runs gives way (its countdown on the client's screen ends with it)
    if cur and cur.kind == "pull" then PT.Stop() end
    start("break", minutes * 60, mode)
    local line = L["Pause: %s (bis %s)"]:format(minutesText(minutes), date("%H:%M", time() + minutes * 60))
    if mode == "group" then
        if not say(line, BREAK_TTL) then return nil end
    else
        ns.msg(line .. " " .. L["(nur bei dir: du bist in keiner Gruppe)"])
    end
    changed()
    return true
end

-- Cancels the running timer (kind: only that one). Returns true when one ran.
function PT.Stop(kind)
    if not cur or (kind and cur.kind ~= kind) then return false end
    local was = cur
    if was.group and was.kind == "pull" and was.client then
        -- the client's countdown ends with 0
        local fn = countdownFn()
        if fn then pcall(fn, 0) end
    end
    local line = was.kind == "pull" and L["Pull abgebrochen!"] or L["Pause abgebrochen"]
    if was.group then say(line, BREAK_TTL) else ns.msg(line) end
    finish()
    return true
end

-- The running timer: kind, seconds left, whether the group sees it; nil when none runs.
function PT.Running()
    if not cur then return nil end
    return cur.kind, left(), cur.group
end

-- The status line's text of the running timer, or nil.
function ns.PullTimerStatus()
    if not cur then return nil end
    local s = left()
    if cur.kind == "pull" then return L["Pull in %d s"]:format(s) end
    return L["Pause: noch %d:%02d"]:format(math.floor(s / 60), s % 60)
end

-- The two entries of the status line's menu (MainFrame): start, or cancel while one runs.
function ns.PullTimerMenu()
    local mode, why = PT.Mode()
    local function entry(kind, label, stopLabel, startFn, tip)
        if cur and cur.kind == kind then
            return { stopLabel, function() PT.Stop(kind) end, tip = tip }
        end
        return { label, mode and function()
            local ok, err = startFn()
            if not ok and err then ns.msg(err) end
        end or nil, tip = mode and tip or why }
    end
    return {
        entry("pull", L["Pull-Timer (%d s)"]:format(ns.Get("pull.seconds")), L["Pull-Timer abbrechen"], function() return PT.Pull() end,
            L["Zählt bis zum Pull herunter: der Countdown des Spiels für alle (wenn es ihn hat) und eine Zeile im Raid. Als Leiter oder Assistent; allein nur bei dir. /amisia pull [Sekunden]"]),
        entry("break", L["Pause (%d min)"]:format(ns.Get("pull.minutes")), L["Pause abbrechen"], function() return PT.Break() end,
            L["Sagt die Pause im Raid an, mit Uhrzeit des Endes; eine Minute vorher und am Ende noch einmal. /amisia raidpause [Minuten]"]),
    }
end

-- A fight starts during a pull timer: the pull happened (or someone pulled early); the timer ends here.
ns.OnEvent("PLAYER_REGEN_DISABLED", function()
    if cur and cur.kind == "pull" then finish() end
end)

-- The typed words: a number, "stop"/"0" (or "aus", "abbrechen"); "" the default.
local STOP_WORDS = { stop = true, aus = true, abbrechen = true, cancel = true, off = true } -- l10n-ok: typed words
local function slash(kind, rest)
    local word = (type(rest) == "string" and rest:match("^%s*(%S*)") or ""):lower()
    if STOP_WORDS[word] or word == "0" then
        if not PT.Stop(kind) then ns.msg(kind == "pull" and L["Es läuft kein Pull-Timer."] or L["Es läuft keine Pause."]) end
        return
    end
    if word ~= "" and not tonumber(word) then
        ns.msg(kind == "pull" and L["Aufruf: /amisia pull [Sekunden | stop]"] or L["Aufruf: /amisia raidpause [Minuten | stop]"])
        return
    end
    local ok, why
    if kind == "pull" then ok, why = PT.Pull(tonumber(word)) else ok, why = PT.Break(tonumber(word)) end
    if not ok and why then ns.msg(why) end
end
PT.Slash = slash

ns.RegisterSlash("pull", { en = "pull", args = L["[Sekunden | stop]"], desc = L["Pull-Timer für die Gruppe (Leiter oder Assistent)"],
    run = function(rest) slash("pull", rest) end })
ns.RegisterSlash("raidpause", { en = "break", args = L["[Minuten | stop]"], desc = L["Pause für die Gruppe ansagen (Leiter oder Assistent)"],
    run = function(rest) slash("break", rest) end })

ns.RegisterSettings{ key = "pull", label = L["Pull- und Pausen-Timer"], order = 14, group = "raid", items = {
    { key = "pull.seconds", type = "slider", label = L["Pull-Timer: Sekunden"], default = 10, min = PULL_MIN, max = PULL_MAX,
      tip = L["So lange zählt der Pull-Timer, wenn du keine Zahl angibst (Menü der Statuszeile, /amisia pull)."] },
    { key = "pull.minutes", type = "slider", label = L["Pause: Minuten"], default = 5, min = BREAK_MIN, max = BREAK_MAX,
      tip = L["So lange dauert die Pause, wenn du keine Zahl angibst (Menü der Statuszeile, /amisia raidpause)."] },
}}

-- for the tests
PT._reset = function()
    cur = nil
    stopTicker()
end
end)
