-- Amisia calendar: an event of the sign-up bot in Discord, pasted (F-223, D-148, spec
-- docs/specs/2026-11-16-kalender-termin-aus-discord.md). An addon has no network: the player copies the
-- event's JSON (the bot hands every event out under a public address, its dashboard has a button for
-- it) and pastes it. Read from it, and nothing else: title, description, startTime (a Unix time) and
-- the sign-ups (signUps: name, className, specName, roleName, status).
--   CB.Form(text)   the values for the form of "Termin anlegen ..." (Raid/CalendarCreate.lua): day and
--                   time in the game calendar's clock, title (31 characters), description (255), and
--                   the instance of the game's list the title names. Nothing is made by the paste:
--                   the player sees the form and clicks "Anlegen" himself.
--   CB.Read(text)   the JSON as a table for ns.ParseLineup (Raid/Lineup.lua reads the sign-ups).
-- Pasted text is untrusted (D-12, D-26): the size and the nesting are capped before the client's reader
-- sees it, every field is checked and cut, codes, links, mentions and Discord's decorations go. No
-- connection to the bot, no key, nothing sent back (D-148).
local ADDON, ns = ...
ns.Load(function()
local L, N_ = ns.L, ns.N_

local CB = {}
ns.CalBot = CB

CB.MAX_JSON = 262144    -- characters of a pasted event (the soft-reserve code's bound)
CB.MAX_DEPTH = 20       -- nesting of the JSON; the client's reader is not asked deeper
CB.MIN_START, CB.MAX_START = 1500000000, 4102444800   -- a start between 2017 and 2100
CB.TITLE_READ = 120     -- characters of the bot's title read before it is cut to the game's 31

local CC = function() return ns.CalCreate end

-- Whether the client can read JSON.
function CB.Available()
    local E = _G.C_EncodingUtil
    return type(E) == "table" and type(E.DeserializeJSON) == "function"
end

-- Whether text looks like the bot's event: a JSON object that names a start.
function CB.Looks(text)
    if type(text) ~= "string" then return false end
    local head = text:sub(1, 64):gsub("^\239\187\191", "")
    return head:find("^%s*{") ~= nil and text:find('"startTime"', 1, true) ~= nil
end

-- The nesting of a JSON text is deeper than max (strings left out), counted before the client reads it.
local function tooDeep(json, max)
    if ns.JsonTooDeep then return ns.JsonTooDeep(json, max) end
    local bare = json:gsub("\\.", ""):gsub('"[^"]*"', "")
    local depth = 0
    for c in bare:gmatch("[%[{%]}]") do
        if c == "[" or c == "{" then
            depth = depth + 1
            if depth > max then return true end
        else
            depth = depth - 1
        end
    end
    return false
end

-- The start of an event as a Unix time in seconds (a time in milliseconds is taken too); nil when it
-- is no sensible moment.
function CB.Start(data)
    local n = type(data) == "table" and tonumber(data.startTime)
    if not n or n ~= n then return nil end
    if n > 100000000000 then n = n / 1000 end
    n = math.floor(n)
    if n < CB.MIN_START or n > CB.MAX_START then return nil end
    return n
end

-- The pasted event as a table, or nil and why: "not" (no event of the bot), "big", "api" (the client
-- cannot read JSON).
function CB.Read(text)
    if type(text) ~= "string" then return nil, "not" end
    if #text > CB.MAX_JSON then return nil, "big" end
    if not CB.Looks(text) then return nil, "not" end
    if not CB.Available() then return nil, "api" end
    text = text:gsub("^\239\187\191", "")
    if tooDeep(text, CB.MAX_DEPTH) then return nil, "not" end
    local ok, data = pcall(C_EncodingUtil.DeserializeJSON, text)
    if not ok or type(data) ~= "table" then return nil, "not" end
    if not CB.Start(data) then return nil, "not" end
    return data
end

-- A text of the bot without Discord's decorations: timestamps, custom emoji, mentions, links, emoji
-- codes, emoji and Markdown marks away, line breaks as spaces; cut to max characters (CC.Clean).
function CB.Plain(text, max)
    if type(text) ~= "string" then return nil end
    local s = text:sub(1, 4000)
    s = s:gsub("<t:%-?%d+:?%a?>", " "):gsub("<a?:[%w_]+:%d+>", " "):gsub("<[@#][!&]?%d+>", " ")
    s = s:gsub("%[([^%]]*)%]%(%s*https?://[^%)]*%)", "%1")
    s = s:gsub("https?://%S+", " ")
    s = s:gsub(":[%a_][%w_]*:", " ")
    s = s:gsub("[\240-\244][\128-\191][\128-\191][\128-\191]", " ")
    s = s:gsub("[%*~`]", ""):gsub("__", "")
    s = s:gsub("[\r\n]+%s*[>#%-]+%s+", " "):gsub("^%s*[>#]+%s+", "")
    return CC().Clean(s, max)
end

local WHY = {
    ["not"] = N_("Das ist kein Termin des Anmelde-Bots (JSON)."),
    big = N_("Zu groß."),
    api = N_("Dieser Client kann das JSON nicht lesen."),
    past = N_("Der Termin liegt in der Vergangenheit."),
}
function CB.Why(why)
    if WHY[why] then return L[WHY[why]] end
    return CC().Why(why)
end

-- The values of the pasted event for the form: { kind = "signup", day (noon of its calendar day), at,
-- time (minutes), title, desc, type, tex, texTitle (the instance the title names, else nil: the player
-- picks), signups (their count) }, or nil and why ("not", "big", "api", "past", "late").
function CB.Form(text)
    local data, why = CB.Read(text)
    if not data then return nil, why end
    local C = CC()
    local start = CB.Start(data)
    -- a fixed moment: in the calendar's clock (the realm's) it reads this much later than on the PC
    local at = start + C.Skew()
    if start <= time() then return nil, "past" end
    local t = date("*t", at)
    local day = time({ year = t.year, month = t.month, day = t.day, hour = 12 })
    local max = C.MaxDay()
    if max and day > max + 3600 then return nil, "late" end
    local full = CB.Plain(data.title, CB.TITLE_READ)
    local title = full and C.Clean(full, C.TITLE_CHARS) or nil
    local desc = CB.Plain(data.description, C.DESC_CHARS)
    -- a title the game cuts: whole at the start of the description, as far as it fits
    if full and title and full ~= title then desc = C.Clean(full .. (desc and (". " .. desc) or ""), C.DESC_CHARS) end
    local form = { kind = "signup", day = day, at = at, time = t.hour * 60 + t.min, title = title or "", desc = desc or "",
                   signups = type(data.signUps) == "table" and #data.signUps or 0 }
    -- the instance: the longest name of the game's lists that stands in the title
    local low = ns.Fold(full or "")
    local best, bestLen
    for _, typ in ipairs({ 0, 1 }) do
        for _, x in ipairs(C.Textures(typ)) do
            local name = ns.Fold(x.title)
            if #name >= 4 and low:find(name, 1, true) and (not bestLen or #name > bestLen) then
                best, bestLen = { type = typ, tex = x.index, texTitle = x.title }, #name
            end
        end
    end
    if best then form.type, form.tex, form.texTitle = best.type, best.tex, best.texTitle end
    return form
end
end)
