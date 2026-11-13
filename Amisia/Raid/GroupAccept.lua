-- Accept group invites from the guild and from friends (F-163, D-93; every player, off by default):
-- on the client's PARTY_INVITE_REQUEST Amisia accepts (AcceptGroup) when the sender is a member of
-- the own guild by the roster (the same spelling; a name of another realm is nobody of ours) or on
-- the own friend list (ns.BenchFriendRows), closes the client's invite window (StaticPopup
-- "PARTY_INVITE") and says one line in the own chat. Anyone else's invite stays the client's own
-- question; a secret or unreadable sender does nothing. While the roster is not read yet the answer
-- waits for it (ns.TrustWait, 60 s at most). Sends nothing.
local ADDON, ns = ...
local L = ns.L

local SAME_GAP = 2         -- one invite event of a sender within this many seconds counts once

local GA = {}
ns.GroupAccept = GA

local lastName, lastAt     -- the last invite answered (the client may fire the event twice)

-- The name the guild and the friend list would write: the own realm's ending dropped, one spelling.
local function nameOf(raw)
    raw = ns.Plain(raw)
    if type(raw) ~= "string" or raw == "" then return nil end
    return ns.StripOwnRealm(raw) or ns.FullName(raw)
end

-- A member of the own guild under exactly this name (no first name alone, D-41 rules of the whisper invite).
local function guildMember(name)
    local m = ns.GuildMember(name)
    return m ~= nil and type(m.name) == "string" and m.name:lower() == name:lower()
end

local function friend(name)
    local low = name:lower()
    for _, f in ipairs(ns.BenchFriendRows and ns.BenchFriendRows() or {}) do
        if f.name:lower() == low then return true end
    end
    return false
end

local function hidePopup()
    local hide = rawget(_G, "StaticPopup_Hide")
    if type(hide) == "function" then pcall(hide, "PARTY_INVITE") end
end

-- Accepts the invite now; why = "guild" or "friend". Returns true when the client took it.
local function accept(name, why)
    if not ns.Get("invites.accept") then return false end
    if IsInGroup() then return false end
    local fn = rawget(_G, "AcceptGroup")
    if type(fn) ~= "function" then return false end
    if not pcall(fn) then return false end
    -- the client shows its window on the same event, maybe after this handler: hide it now and next frame
    hidePopup()
    C_Timer.After(0, hidePopup)
    ns.msg((why == "guild" and L["Einladung von %s angenommen (Gilde)."] or L["Einladung von %s angenommen (Freund)."]):format(name))
    return true
end

-- The invite of raw (the event's first value): accepted from a guild member or a friend.
function GA.Request(raw)
    if not ns.Get("invites.accept") then return end
    local name = nameOf(raw)
    if not name then return end
    local t = GetTime()
    if lastName == name:lower() and lastAt and t - lastAt < SAME_GAP then return end
    lastName, lastAt = name:lower(), t
    if friend(name) then
        if guildMember(name) then return accept(name, "guild") end
        return accept(name, "friend")
    end
    if not ns.InGuild() then return end
    ns.TrustWait(name, "member", function(member)
        if member and guildMember(name) then accept(name, "guild") end
    end)
end

ns.OnEvent("PARTY_INVITE_REQUEST", function(name) GA.Request(name) end)

ns.RegisterSettings{ key = "invites", label = L["Gruppeneinladungen"], order = 15, group = "raid", items = {
    { key = "invites.accept", type = "toggle", label = L["Einladungen von Gilde und Freunden annehmen"], default = false,
      tip = L["Lädt dich ein Mitglied deiner Gilde oder jemand von deiner Freundesliste in eine Gruppe ein, nimmt Amisia sofort an und sagt es in deinem Chat. Einladungen von anderen fragt das Spiel wie immer."] },
    -- F-197: the link behind "ist jetzt online" (Raid/OnlineInvite.lua)
    { key = "invites.onlineLink", type = "toggle", label = L["[Einladen] bei \"ist jetzt online\""], default = true,
      tip = L["Kommt jemand aus Gilde oder Freundesliste online, steht hinter der Zeile im Chat ein [Einladen]; ein Klick lädt ihn ein. Nicht, wenn er schon in deiner Gruppe ist oder du in der Gruppe nicht einladen darfst."] },
}}

-- for the tests
GA._reset = function() lastName, lastAt = nil, nil end
