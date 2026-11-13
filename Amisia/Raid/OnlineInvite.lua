-- "[Einladen]" behind "<Name> ist jetzt online." (F-197, D-127; every player, on by default with
-- invites.onlineLink): a chat filter on CHAT_MSG_SYSTEM finds the client's own line ERR_FRIEND_ONLINE_SS
-- (a friend or a guild member coming online) and adds an addon link "|Haddon:Amisia:inv:<name>|h". A
-- click (the client's SetItemRef event of addon links, EventRegistry "SetItemRef") invites that player
-- (C_PartyInfo.InviteUnit, else InviteUnit). No link for the player himself, someone already in the
-- group or while this client is in a group it may not invite to; a secret line (the chat lockdown) stays
-- as it is. Sends nothing; nothing is saved.
local ADDON, ns = ...
local L = ns.L

local OI = {}
ns.OnlineInvite = OI

local PREFIX = "addon:Amisia:inv:"
local COLOUR = "|cff4fb8ff"

local function enabled() return ns.Get("invites.onlineLink") and true or false end

-- The client's line as a pattern: its "%s" (the name in the link, the name shown) captured, the
-- rest literal; nil without the global.
local linePattern, lineFrom
local function pattern()
    local fmt = _G.ERR_FRIEND_ONLINE_SS
    if type(fmt) ~= "string" or fmt == "" then return nil end
    if lineFrom ~= fmt then
        -- literal first; then "%s" and a positional "%1$s" become captures
        local p = fmt:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
        p = p:gsub("%%%%%d%%%$s", "(.-)")
        p = p:gsub("%%%%s", "(.-)")
        linePattern, lineFrom = "^" .. p .. "$", fmt
    end
    return linePattern
end

-- The name a line of the client names as coming online, or nil.
function OI.NameOf(text)
    text = ns.Plain(text)
    local p = type(text) == "string" and pattern()
    if not p then return nil end
    local linked, shown = text:match(p)
    local name = linked or shown
    if type(name) ~= "string" then return nil end
    -- a player link may carry more fields after the name ("Name-Realm:lineID")
    name = name:match("^([^:|%[%]]+)")
    if not name or name == "" then return nil end
    return name
end

-- Whether this client may invite now: outside a group, or as the leader, or as an assistant of a raid.
function OI.CanInvite()
    if not IsInGroup() then return true end
    if UnitIsGroupLeader("player") then return true end
    return IsInRaid() and UnitIsGroupAssistant("player") and true or false
end

local function linkFor(name)
    return ("%s|H%s%s|h[%s]|h|r"):format(COLOUR, PREFIX, name, L["Einladen##online"])
end

-- The chat filter: the line with the link, or it as it is.
function OI.Filter(_, _, text, ...)
    if not enabled() then return false, text, ... end
    local name = OI.NameOf(text)
    if not name or not OI.CanInvite() then return false, text, ... end
    local me = ns.UnitFullName("player")
    if (me and ns.SameName(name, me)) or ns.InMyGroup(name) then return false, text, ... end
    return false, text .. " " .. linkFor(name), ...
end

-- A click on the link: invites name. true, or false and the reason (said in the chat).
function OI.Invite(name)
    name = ns.Plain(name)
    if type(name) ~= "string" or name == "" then return false end
    if not OI.CanInvite() then
        ns.msg(L["Einladen kann nur der Gruppenleiter (im Raid auch Assistenten)."])
        return false
    end
    if ns.InMyGroup(name) then
        ns.msg(L["%s ist schon in deiner Gruppe."]:format(name))
        return false
    end
    local api = _G.C_PartyInfo
    local fn = type(api) == "table" and api.InviteUnit or rawget(_G, "InviteUnit")
    if type(fn) ~= "function" then return false end
    local ok = pcall(fn, name)
    if ok then ns.msg(L["Eingeladen: %s"]:format(name)) end
    return ok
end

-- the client's event for addon links (all three clients: LinkTypes.AddOn -> EventRegistry "SetItemRef")
function OI.OnLink(_, link)
    if type(link) ~= "string" or link:sub(1, #PREFIX) ~= PREFIX then return end
    OI.Invite(link:sub(#PREFIX + 1))
end

do
    local reg = _G.EventRegistry
    if type(reg) == "table" and type(reg.RegisterCallback) == "function" then
        pcall(reg.RegisterCallback, reg, "SetItemRef", OI.OnLink, OI)
    end
    local add = _G.ChatFrame_AddMessageEventFilter
    local util = _G.ChatFrameUtil
    if type(add) ~= "function" and type(util) == "table" then add = util.AddMessageEventFilter end
    if type(add) == "function" then
        local function pass(ok, ...)
            if ok then return ... end
            ns.ReportError((...))
            return false
        end
        pcall(add, "CHAT_MSG_SYSTEM", function(...) return pass(pcall(OI.Filter, ...)) end)
    end
end
