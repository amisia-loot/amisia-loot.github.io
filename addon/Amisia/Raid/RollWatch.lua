-- Amisia and rounds started with Gargul (spec docs/specs/2026-10-11-softres-gargul.md, B1; DECISIONS
-- D-05 exception, D-44). A guild may use both addons: when the loot lead starts a round with Gargul,
-- Gargul writes "You have 20 seconds to roll on [Item]" (German "Du hast 20 Sekunden um auf [Item] zu
-- würfeln", maybe " - note" behind) into the raid, and at the end "Stop your rolls!" ("Stopp deine
-- Würfe!"). Amisia reads only these chat lines, never Gargul's addon messages, and sends nothing:
--   * every raider client with Amisia opens its roll window for the round, marked "(Gargul)"
--     (RollWindow.lua, rollwin.foreign); Mainspec 1-100, Offspec 1-99 like Gargul's defaults;
--   * the loot lead's Amisia watches the round silently (Rolls.lua, rolls.foreignWatch): it reads the
--     rolls as always, never announces and never decides (whoever starts decides).
-- A line counts only from the master looter, or without master loot the raid leader, in the own group
-- with the officer rank (as D-38), one start per second and sender; a start that waited longer than
-- 5 s for the roster check falls. A secret line (the chat lockdown of a boss fight) cannot be read:
-- no window then. Both languages are read whatever the own client's language.
local ADDON, ns = ...

local GAP = 1                  -- one start per sender and second
local START_TTL = 5            -- a start held by the roster check falls after this
local MAX_LINE = 400
local NOTE_MAX = 60

-- The start as Gargul writes it; what follows the number is the item link.
local START = {
    "You have (%d+) seconds to roll on ",
    "Du hast (%d+) Sekunden,? um auf ",     -- l10n-ok: Gargul's German line, read on every client
}
-- The end, compared in lower case.
local STOP = { "stop your rolls", "stopp deine würfe" }   -- l10n-ok: Gargul's German line

local lastStart = {}           -- lower name -> GetTime() of its last start

local function inPvP()
    local _, kind = GetInstanceInfo()
    kind = ns.Plain(kind)
    return kind == "pvp" or kind == "arena"
end

-- A note: no codes or bars, at most 60 characters (UTF-8 kept whole); nil when empty.
local function cleanNote(s)
    if type(s) ~= "string" then return nil end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", ""):gsub("%c", " "):match("^%s*(.-)%s*$")
    local out, n = {}, 0
    for ch in s:gmatch("[%z\1-\127\192-\253][\128-\191]*") do
        n = n + 1
        if n > NOTE_MAX then break end
        out[n] = ch
    end
    s = table.concat(out):match("^%s*(.-)%s*$")
    return s ~= "" and s or nil
end

-- The start line of a Gargul round: { link, item, secs (5-120), note }, or nil.
function ns.ParseForeignRollStart(text)
    if type(text) ~= "string" or #text > MAX_LINE then return nil end
    local secs, rest
    for _, p in ipairs(START) do
        local _, e, n = text:find(p)
        if e then
            secs, rest = tonumber(n), text:sub(e + 1)
            break
        end
    end
    if not secs then return nil end
    local link = rest:match("^(|c%x+|Hitem:[^|]+|h.-|h|r)") or rest:match("^(|Hitem:[^|]+|h.-|h)")
    local item = link and ns.ItemID(link)
    if not item then return nil end
    local after = rest:sub(#link + 1):gsub("^%s*zu würfeln", "")   -- l10n-ok: the end of Gargul's German line
    local note = after:match("^%s*%-%s*(.-)%s*$")
    return { link = link, item = item, secs = math.max(5, math.min(120, secs)), note = cleanNote(note) }
end

-- Whether text is the end line of a Gargul round.
function ns.IsForeignRollStop(text)
    if type(text) ~= "string" or #text > MAX_LINE then return false end
    local low = text:lower()
    for _, p in ipairs(STOP) do
        if low:find(p, 1, true) then return true end
    end
    return false
end

local function started(s, name, sender, arrived)
    -- the loot lead's Amisia (officer view, the elected lead) watches the round
    if ns.Get("rolls.foreignWatch") and ns.IsOfficerView() and ns.IsLootLead and ns.IsLootLead() and ns.WatchForeignRoll then
        ns.WatchForeignRoll(s.link, s.secs, name)
    end
    -- the starter has Gargul's own window; everyone else gets Amisia's
    local me = ns.UnitFullName("player")
    if me and ns.SameName(name, me) then return end
    if ns.RollWindowForeign then ns.RollWindowForeign(s, name, sender, arrived) end
end

local function stopped(name)
    if ns.StopForeignRoll then ns.StopForeignRoll(name) end
    if ns.RollWindowForeignEnd then ns.RollWindowForeignEnd(name) end
end

-- A raid (or party) chat line or raid warning: a start or an end of a Gargul round from the trusted
-- loot lead. sender is the server's sender, never a part of the text.
local function onChat(text, sender)
    text, sender = ns.Plain(text), ns.Plain(sender)
    if type(text) ~= "string" or type(sender) ~= "string" or sender == "" then return end
    local start = ns.ParseForeignRollStart(text)
    local stop = not start and ns.IsForeignRollStop(text)
    if not start and not stop then return end
    if not IsInGroup() or inPvP() then return end
    if not (ns.Get("rolls.foreignWatch") or (ns.Get("rollwin.enabled") and ns.Get("rollwin.foreign"))) then return end
    local name = ns.TrustName(sender)
    if not name then return end
    -- the group roles first (no roster needed): a raider's lines never take a place in the queue of
    -- senders waiting for the guild roster (ns.TrustWait, shared with WS and the other messages)
    if not ns.InMyGroup(name) or not (ns.IsLootBossName and ns.IsLootBossName(name)) then return end
    local arrived = GetTime()
    if start then
        local key = name:lower()
        if lastStart[key] and arrived - lastStart[key] < GAP then return end
        lastStart[key] = arrived
    end
    ns.TrustWait(name, "officer", function(ok)
        if not ok or not ns.InMyGroup(name) or not (ns.IsLootBossName and ns.IsLootBossName(name)) then return end
        if start then
            if GetTime() - arrived > START_TTL then return end
            started(start, name, sender, arrived)
        else
            stopped(name)
        end
    end)
end

for _, event in ipairs({ "CHAT_MSG_RAID_WARNING", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_PARTY",
                         "CHAT_MSG_PARTY_LEADER" }) do
    ns.OnEvent(event, function(text, sender)
        local ok, err = pcall(onChat, text, sender)
        if not ok then
            local handler = geterrorhandler and geterrorhandler()
            if handler then handler(err) end
        end
    end)
end
