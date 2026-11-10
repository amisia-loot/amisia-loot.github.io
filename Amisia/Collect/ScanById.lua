-- Amisia scans by id (spec 2026-11-10-quest-und-npc-scan, D-104): what the quest scan
-- (ScanQuests.lua), the NPC scan (ScanNpcs.lua) and the data probe (Core/SelfTestData.lua,
-- /amisia selbsttest daten) share: the lines of a hyperlink tooltip read without showing anything
-- (C_TooltipInfo.GetHyperlink, or a hidden tooltip of our own: never GameTooltip), when a scan must
-- wait (combat, an encounter lockdown, an instance), the client's language and build, the probe's
-- verdicts (AmisiaDB.probe), ranges of ids as text, and the generated id lists (Data/ScanLists.lua).
-- Only reads: nothing is sent to chat or other players.
local ADDON, ns = ...
local L = ns.L

local SB = {}
ns.ScanById = SB

SB.MAX_LINES = 12      -- tooltip lines read at most
SB.NPC_LINK = "unit:Creature-0-0-0-0-%d-0000000000"
SB.VERDICTS = { ok = true, retry = true, none = true }

function SB.NpcLink(id) return SB.NPC_LINK:format(id) end
function SB.QuestLink(id) return ("quest:%d"):format(id) end

-- A text of the client as plain text: nil for a secret or empty one; codes, line breaks and tabs out.
local function clean(v)
    v = ns.Plain(v)
    if type(v) ~= "string" then return nil end
    if ns.StripCodes then v = ns.StripCodes(v) end
    v = v:gsub("[\r\n\t]+", " "):match("^%s*(.-)%s*$")
    return v ~= "" and v or nil
end
SB.Clean = clean

---------------------------------------------------------------------------
-- Tooltip lines
---------------------------------------------------------------------------
local TIP_NAME = "AmisiaIdTip"
local tip

-- The own hidden tooltip (made on first use), or nil when the client cannot make one.
function SB.Tip()
    if tip then return tip end
    local ok, t = pcall(CreateFrame, "GameTooltip", TIP_NAME, nil, "GameTooltipTemplate")
    if ok and t then tip = t end
    return tip
end

-- The left texts of the own tooltip after SetHyperlink(link): a list (an unreadable line is ""), nil and
-- the number of secret lines; or nil and why ("missing": no tooltip, "error": the client raised,
-- "secret": every line secret).
function SB.TipLines(link)
    local t = SB.Tip()
    if not t or type(t.SetHyperlink) ~= "function" then return nil, "missing" end
    if t.SetOwner then pcall(t.SetOwner, t, _G.WorldFrame or UIParent, "ANCHOR_NONE") end
    if t.ClearLines then pcall(t.ClearLines, t) end
    if not pcall(t.SetHyperlink, t, link) then return nil, "error" end
    local okN, n = pcall(t.NumLines, t)
    n = okN and tonumber(ns.Plain(n)) or 0
    local out, secret = {}, 0
    for i = 1, math.min(n, SB.MAX_LINES) do
        local fs = _G[TIP_NAME .. "TextLeft" .. i]
        local text
        if fs and fs.GetText then
            local okT, v = pcall(fs.GetText, fs)
            if okT then
                if v ~= nil and ns.Plain(v) == nil then secret = secret + 1 end
                text = clean(v)
            end
        end
        out[#out + 1] = text or ""
    end
    if t.Hide then pcall(t.Hide, t) end
    if n > 0 and secret == n then return nil, "secret" end
    return out, nil, secret
end

-- The left texts of C_TooltipInfo.GetHyperlink(link), as TipLines.
function SB.InfoLines(link)
    local api = _G.C_TooltipInfo
    local f = type(api) == "table" and api.GetHyperlink
    if type(f) ~= "function" then return nil, "missing" end
    local ok, data = pcall(f, link)
    if not ok then return nil, "error" end
    data = ns.Plain(data)
    if type(data) ~= "table" then return {} end
    local lines = ns.Plain(data.lines)
    if type(lines) ~= "table" then return {} end
    local out, secret = {}, 0
    for i = 1, math.min(#lines, SB.MAX_LINES) do
        local line = ns.Plain(lines[i])
        local v = type(line) == "table" and line.leftText or nil
        if v ~= nil and ns.Plain(v) == nil then secret = secret + 1 end
        out[#out + 1] = clean(v) or ""
    end
    if #lines > 0 and secret == #lines then return nil, "secret" end
    return out, nil, secret
end

-- The lines through route ("info" or "tip"; nil: the probe's route, else info where the client has it).
function SB.Lines(link, route)
    route = route or SB.Route()
    if route == "tip" then return SB.TipLines(link) end
    local lines, why, secret = SB.InfoLines(link)
    if lines or route == "info" then return lines, why, secret end
    return SB.TipLines(link)
end

-- The route the probe found to give NPC names, else info where the client has it, else tip.
function SB.Route()
    local p = SB.Probe()
    if p and (p.route == "info" or p.route == "tip") then return p.route end
    local api = _G.C_TooltipInfo
    return (type(api) == "table" and type(api.GetHyperlink) == "function") and "info" or "tip"
end

-- Whether a tooltip line is the unit's level line ("Stufe ?? (Elite)"): it starts as the client's
-- TOOLTIP_UNIT_LEVEL does before its number.
local function levelLine(s)
    if type(s) ~= "string" or s == "" then return false end
    local tpl = rawget(_G, "TOOLTIP_UNIT_LEVEL")
    local head = type(tpl) == "string" and tpl:match("^(.-)%%") or nil
    -- (head may be nil: no ipairs over a list with a hole)
    if type(head) == "string" and head ~= "" and s:sub(1, #head) == head then return true end
    return s:sub(1, 6) == "Stufe " or s:sub(1, 6) == "Level "   -- l10n-ok: the client's own words, compared, never shown
end

-- A field of a saved scan line: no tab, no line break, not endless.
local function field(s)
    if type(s) ~= "string" then return nil end
    s = s:gsub("[%c]", " "):match("^%s*(.-)%s*$")
    if s == "" or #s > 60 then return nil end
    return s
end

-- An NPC from tooltip lines (as the client of 2026-11-10 writes them: name, a title line where the
-- NPC has one, "Stufe ?? (Elite)", the kind of creature): the name, the title (the second line when
-- it is in angle brackets or the level line follows it), the rank in the level line's brackets
-- ("Elite", "Rar", "Boss"; the client's word) and the kind ("Humanoid"). nil for no name or the
-- client's "unknown".
function SB.NpcFrom(lines)
    if type(lines) ~= "table" then return nil end
    local name = lines[1]
    if type(name) ~= "string" or name == "" then return nil end
    local unknown = { rawget(_G, "UNKNOWNOBJECT"), rawget(_G, "UNKNOWN") }
    for _, u in ipairs(unknown) do
        if type(u) == "string" and name == u then return nil end
    end
    local sub, at = nil, nil
    if levelLine(lines[2]) then
        at = 2
    elseif levelLine(lines[3]) then
        sub, at = field(lines[2]), 3
    elseif type(lines[2]) == "string" and lines[2]:match("^<.+>$") then
        sub = field(lines[2])
    end
    local rank, kind
    if at then
        rank = field(lines[at]:match("%(([^()]*)%)%s*$"))
        local k = lines[at + 1]
        -- the kind is one or two plain words; another addon's line ("NpcID") or a number is none
        if type(k) == "string" and not k:find("[%d:]") and #k <= 30 then kind = field(k) end
    end
    return name, sub, rank, kind
end

---------------------------------------------------------------------------
-- When a scan waits, the client
---------------------------------------------------------------------------
-- Why nothing may be asked now, or nil: combat, the encounter lockdown (values may be secret) and,
-- with inInstance, any instance (tooltip data is restricted there).
function SB.Blocked(inInstance)
    if InCombatLockdown() then return L["im Kampf"] end
    if ns.AddOnRestricted and (ns.AddOnRestricted(0) or ns.AddOnRestricted(1)) then return L["Kampfsperre"] end
    if inInstance then
        local ok, _, kind = pcall(GetInstanceInfo)
        kind = ok and ns.Plain(kind) or nil
        if kind and kind ~= "none" then return L["in einer Instanz"] end
    end
    return nil
end

function SB.Locale()
    local ok, loc = pcall(GetLocale)
    loc = ok and ns.Plain(loc) or nil
    return type(loc) == "string" and loc:match("^%a%a%a%a$") and loc or "enUS"
end

function SB.Build()
    local ok, version, number = pcall(GetBuildInfo)
    if not ok then return "?" end
    return ("%s.%s"):format(tostring(ns.Plain(version) or "?"), tostring(ns.Plain(number) or "?"))
end

-- "1 h 05 min", "12 min", "40 s".
function SB.Duration(seconds)
    seconds = math.max(0, math.floor((tonumber(seconds) or 0) + 0.5))
    if seconds < 60 then return L["%d s"]:format(seconds) end
    local m = math.floor(seconds / 60 + 0.5)
    if m < 60 then return L["%d min"]:format(m) end
    return L["%d h %02d min"]:format(math.floor(m / 60), m % 60)
end

---------------------------------------------------------------------------
-- The probe's verdicts: AmisiaDB.probe = { v = 1, build, at, npc, npcNew, route, burst, quest,
-- questTip, model, ... } (Core/SelfTestData.lua writes it; a mini-probe of the NPC scan may write npc)
---------------------------------------------------------------------------
local PROBE_KEYS = { npc = "v", npcNew = "v", quest = "v", questTip = "v", model = "v", vignette = "v", questMap = "v",
                     journal = "v", taxi = "v", route = "r", burst = "n", src = "s" }

-- Called on ADDON_LOADED: AmisiaDB.probe with known fields of known values only, or nil.
function SB.ProbeLoaded(root)
    local p = root.probe
    if type(p) ~= "table" then root.probe = nil return nil end
    local out = { v = 1 }
    if type(p.build) == "string" and #p.build <= 40 then out.build = p.build end
    if ns.Int(p.at, 1, 4102444800) then out.at = p.at end
    for k, kind in pairs(PROBE_KEYS) do
        local v = p[k]
        if kind == "v" and SB.VERDICTS[v] then out[k] = v end
        if kind == "r" and (v == "info" or v == "tip") then out[k] = v end
        if kind == "n" and ns.Int(v, 0, 100) then out[k] = v end
        if kind == "s" and (v == "probe" or v == "mini") then out[k] = v end
    end
    if not out.build or not out.at then root.probe = nil return nil end
    root.probe = out
    return out
end

-- The verdicts of this client build, or nil (none yet, or of another build).
function SB.Probe()
    local p = AmisiaDB and AmisiaDB.probe
    if type(p) ~= "table" or p.build ~= SB.Build() then return nil end
    return p
end

-- One verdict of this build ("ok", "retry", "none") or nil.
function SB.Verdict(key)
    local p = SB.Probe()
    return p and SB.VERDICTS[p[key]] and p[key] or nil
end

-- Writes verdicts (a table of fields) for this build; the other fields of the same build stay.
function SB.SaveProbe(fields, src)
    if not AmisiaDB then return end
    local p = SB.Probe() or {}
    p.v, p.build, p.at, p.src = 1, SB.Build(), math.floor(time()), src or "probe"
    for k, v in pairs(fields) do p[k] = v end
    AmisiaDB.probe = p
    SB.ProbeLoaded(AmisiaDB)
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name == ADDON and AmisiaDB then SB.ProbeLoaded(AmisiaDB) end
end)

---------------------------------------------------------------------------
-- Ids as text: ranges "a-b,c,d-e" (decimal; unsorted pieces allowed, the reader sorts and joins)
---------------------------------------------------------------------------
-- The ranges of a text: { { a, b }, ... } sorted and joined.
function SB.ParseRanges(text)
    local out = {}
    if type(text) ~= "string" then return out end
    for a, b in text:gmatch("(%d+)%-?(%d*)") do
        a = tonumber(a)
        b = tonumber(b) or a
        if a and b and b >= a then out[#out + 1] = { a, b } end
    end
    table.sort(out, function(x, y) return x[1] < y[1] end)
    local joined = {}
    for _, r in ipairs(out) do
        local last = joined[#joined]
        if last and r[1] <= last[2] + 1 then
            if r[2] > last[2] then last[2] = r[2] end
        else
            joined[#joined + 1] = { r[1], r[2] }
        end
    end
    return joined
end

function SB.RangesText(ranges)
    local parts = {}
    for _, r in ipairs(ranges) do parts[#parts + 1] = r[1] == r[2] and tostring(r[1]) or (r[1] .. "-" .. r[2]) end
    return table.concat(parts, ",")
end

-- text with id added: the last piece grows when id follows it, else a new piece goes to the end.
function SB.AddToRanges(text, id)
    text = type(text) == "string" and text or ""
    if text == "" then return tostring(id) end
    local head, a, b = text:match("^(.-)(%d+)%-(%d+)$")
    if not head then
        head, a = text:match("^(.-)(%d+)$")
        b = a
    end
    a, b = tonumber(a), tonumber(b)
    if a and b then
        if id == b + 1 then return head .. a .. "-" .. id end
        if id >= a and id <= b then return text end
    end
    return text .. "," .. id
end

-- Whether id lies in a ranges text.
function SB.InRanges(text, id)
    for _, r in ipairs(SB.ParseRanges(text)) do
        if id >= r[1] and id <= r[2] then return true end
    end
    return false
end

-- The number of ids in a ranges text.
function SB.RangesCount(text)
    local n = 0
    for _, r in ipairs(SB.ParseRanges(text)) do n = n + r[2] - r[1] + 1 end
    return n
end

---------------------------------------------------------------------------
-- The generated lists (Data/ScanLists.lua, tools/build_scan_lists.py)
---------------------------------------------------------------------------
local function b36(s) return tonumber(s, 36) end

-- The ids of a "<step>.<length>" range list (base 36, steps from the end of the previous range).
function SB.ExpandSteppedRanges(text)
    local out, last = {}, 0
    if type(text) ~= "string" then return out end
    for step, len in text:gmatch("(%w+)%.(%w+)") do
        local first = last + (b36(step) or 0)
        last = first + (b36(len) or 1) - 1
        for id = first, last do out[#out + 1] = id end
    end
    return out
end

-- The ids of a "<step>,<step>" list (base 36, steps from the previous id).
function SB.ExpandSteps(text)
    local out, id = {}, 0
    if type(text) ~= "string" then return out end
    for step in text:gmatch("%w+") do
        id = id + (b36(step) or 0)
        out[#out + 1] = id
    end
    return out
end

-- The list of key ("Q" every quest of the client, "NA" the NPCs our data names), as an array; nil
-- without the data.
local lists = {}
function SB.List(key)
    if lists[key] then return lists[key] end
    local d = ns.Data("SCAN_LISTS")
    if type(d) ~= "table" then return nil end
    local out
    if key == "Q" then out = SB.ExpandSteppedRanges(d.Q) elseif key == "NA" then out = SB.ExpandSteps(d.NA) end
    lists[key] = out
    return out
end

-- The ranges of phase B: { { from, to }, ... } and the number of ids, or nil.
function SB.RangesB()
    local d = ns.Data("SCAN_LISTS")
    if type(d) ~= "table" or type(d.NB) ~= "table" then return nil end
    local out, n = {}, 0
    for _, r in ipairs(d.NB) do
        local a, b = tonumber(r[1]), tonumber(r[2])
        if a and b and b >= a then out[#out + 1] = { a, b }; n = n + b - a + 1 end
    end
    return out, n
end

-- Forgets the expanded lists (a test puts other data in place).
function SB.Reset() lists = {} end

---------------------------------------------------------------------------
-- One id scan at a time (quests or NPCs; the item scan has its own)
---------------------------------------------------------------------------
local busy
function SB.Busy() return busy end
function SB.SetBusy(who) busy = who end

-- The scanned names for the client's language (Data/ScanNames.lua): a quest's title or an NPC's
-- name, or nil.
local function names()
    local d = ns.Data("SCAN_NAMES")
    local part = type(d) == "table" and type(d.L) == "table" and d.L[SB.Locale()] or nil
    return type(part) == "table" and part or nil
end

function ns.ScannedQuestTitle(qid)
    local p = names()
    local t = p and type(p.Q) == "table" and p.Q[qid]
    return type(t) == "string" and t ~= "" and t or nil
end

function ns.ScannedNpcName(npc)
    local p = names()
    local t = p and type(p.N) == "table" and p.N[npc]
    return type(t) == "string" and t ~= "" and t or nil
end
