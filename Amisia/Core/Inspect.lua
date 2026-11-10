-- One inspect request at a time for every part of Amisia (F-169, D-99): the duellists' specialisation
-- (Core/Duels.lua, F-114) and the gear score in the player tooltip (UI/UnitInfo.lua) ask through here.
-- A request goes only out of combat, outside the encounter lockdown, never while the client's own
-- inspect window is open, only for a unit the client lets inspect (CanInspect, and in inspect range
-- where the client tells it), at most one at a time and at least In.GAP seconds after the last one.
-- An answer later than In.WAIT seconds is no longer awaited; another inspect request in between (the
-- player's own, another addon's) makes Amisia drop its answer. INSPECT_READY of the asked character
-- runs the asker's onReady(guid, unit, tag); afterwards the inspect is cleared (ClearInspectPlayer,
-- never while the inspect window is open) unless onReady returns true, then the asker clears it
-- with In.Clear when it is done. Reads and sends nothing else; the talent reader of an answer is
-- Gear/Talents.lua (T.InspectTrees).
local ADDON, ns = ...

local In = {}
ns.Inspect = In

In.WAIT = 4    -- seconds an answer is awaited
In.GAP = 1     -- seconds between two requests of Amisia at least

local pending     -- { guid, unit, tag, onReady, at } the request that waits for its answer
local lastAt      -- GetTime() of Amisia's last request
local ownCall, hooked

-- Whether the client's inspect window is open.
function In.FrameShown()
    local f = _G.InspectFrame
    return type(f) == "table" and f.IsShown and f:IsShown() and true or false
end

-- Why no request may go now: "combat", "window", "lockdown"; nil when one may.
function In.Blocked()
    if (type(UnitAffectingCombat) == "function" and ns.Plain(UnitAffectingCombat("player")))
        or (type(InCombatLockdown) == "function" and ns.Plain(InCombatLockdown())) then
        return "combat"
    end
    if In.FrameShown() then return "window" end
    if ns.ChatLocked and ns.ChatLocked() then return "lockdown" end
    return nil
end

-- The request that waits for its answer ({ guid, unit, tag, at }), nil when none (or too late).
function In.Pending()
    if pending and GetTime() - pending.at >= In.WAIT then pending = nil end
    return pending
end

-- Seconds until a request may go (0: now; the answer awaited or the gap since the last one).
function In.Wait()
    local now, p = GetTime(), In.Pending()
    local w = 0
    if p then w = p.at + In.WAIT - now end
    if lastAt then w = math.max(w, lastAt + In.GAP - now) end
    return math.max(0, w)
end

-- Whether unit may be inspected: the client's CanInspect and, where the client tells it, the
-- inspect range (CheckInteractDistance index 1).
function In.CanInspect(unit)
    if type(_G.CanInspect) == "function" then
        local ok, can = pcall(_G.CanInspect, unit)
        if not ok or not ns.Plain(can) then return false end
    end
    local near = _G.CheckInteractDistance
    if type(near) == "function" then
        local ok, inRange = pcall(near, unit, 1)
        if ok and ns.Plain(inRange) == false then return false end
    end
    return true
end

-- Asks the client to inspect unit (of guid); onReady(guid, unit, tag) runs on its answer. true when
-- the request went out; false and why ("api", "combat", "window", "lockdown", "busy", "unit", "error")
-- otherwise.
function In.Request(unit, guid, onReady, tag)
    if type(_G.NotifyInspect) ~= "function" then return false, "api" end
    local why = In.Blocked()
    if why then return false, why end
    if In.Wait() > 0 then return false, "busy" end
    if type(unit) ~= "string" or type(guid) ~= "string" or ns.Plain(UnitGUID(unit)) ~= guid
        or not In.CanInspect(unit) then
        return false, "unit"
    end
    if not hooked and type(hooksecurefunc) == "function" then
        hooked = true
        hooksecurefunc("NotifyInspect", function() if not ownCall then pending = nil end end)
    end
    local now = GetTime()
    lastAt = now
    pending = { guid = guid, unit = unit, tag = tag, onReady = onReady, at = now }
    ownCall = true
    local ok = pcall(_G.NotifyInspect, unit)
    ownCall = nil
    if not ok then
        pending = nil
        return false, "error"
    end
    return true
end

-- Ends the inspect (never while the client's inspect window is open).
function In.Clear()
    if type(_G.ClearInspectPlayer) == "function" and not In.FrameShown() then pcall(_G.ClearInspectPlayer) end
end

ns.OnEvent("INSPECT_READY", function(guid)
    local p = In.Pending()
    if not p or ns.Plain(guid) ~= p.guid then return end
    pending = nil
    local keep = false
    if p.onReady then
        local ok, res = pcall(p.onReady, p.guid, p.unit, p.tag)
        if not ok then geterrorhandler()(res) end
        keep = ok and res == true
    end
    if not keep then In.Clear() end
end)
