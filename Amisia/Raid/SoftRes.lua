-- Amisia soft-reserves: a pasted list (softres.it CSV or "Name [item]" lines), shown in item
-- tooltips and on the loot window, and ranked first in roll rounds.
local ADDON, ns = ...
local L = ns.L

local GetItemInfo = C_Item.GetItemInfo

local marks = {}   -- loot element -> "SR" font string

local function shortName(name)
    name = ns.FullName(name)
    if not name then return nil end
    return name:sub(1, 1):upper() .. name:sub(2)
end

-- Splits one CSV line on delim, honouring double quotes.
local function splitCsv(line, delim)
    local out, cur, q, i = {}, "", false, 1
    while i <= #line do
        local ch = line:sub(i, i)
        if q then
            if ch == '"' then
                if line:sub(i + 1, i + 1) == '"' then cur = cur .. '"'; i = i + 1 else q = false end
            else
                cur = cur .. ch
            end
        elseif ch == '"' then
            q = true
        elseif ch == delim then
            out[#out + 1] = cur; cur = ""
        else
            cur = cur .. ch
        end
        i = i + 1
    end
    out[#out + 1] = cur
    return out
end

local function splitLines(text)
    local out = {}
    for line in (text or ""):gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" then out[#out + 1] = line end
    end
    return out
end

-- A cleaned-up list name after the remembered fixes (AmisiaDB.srAliases, keys in lower case).
-- renamed collects fixed name -> name as written in the list.
local function aliased(name, renamed)
    if not name then return nil end
    local aliases = AmisiaDB and AmisiaDB.srAliases
    local to = type(aliases) == "table" and aliases[name:lower()]
    if type(to) == "string" and to ~= "" and to ~= name then
        if renamed then renamed[to] = renamed[to] or name end
        return to
    end
    return name
end

---------------------------------------------------------------------------
-- The softres.it code (its "Gargul" export, spec docs/specs/2026-10-11-softres-gargul.md, A2):
-- Base64 of zlib-packed JSON, unpacked only with the client's C_EncodingUtil. The text is untrusted
-- (D-26): every step under pcall, every field checked and capped, unknown fields passed over.
---------------------------------------------------------------------------
-- DecompressString has no output limit: zlib packs at most 1032:1, so the code's length is the only
-- bound before the client allocates. 24 KB of Base64 are 18 KB packed, at most about 19 MB unpacked
-- (a raid of 40 with notes is under 7 KB); MAX_JSON is checked only after unpacking.
local MAX_CODE = 24576        -- characters of a pasted code
local MAX_JSON = 262144       -- bytes unpacked
local MAX_DEPTH = 20          -- nesting of the JSON (the code has 5); the client's reader is not asked deeper
local MAX_RESERVES = 2000
local MAX_NAME, MAX_NOTE = 48, 60
local ZLIB = 1                -- Enum.CompressionMethod.Zlib (in game 2026-10-11)

-- s without the spaces around it, in linear time ("^%s*(.-)%s*$" is quadratic on a long run of
-- spaces inside s, and a code can unpack to 256 KB of them).
local function trim(s)
    local first = s:find("%S")
    if not first then return "" end
    return s:match(".*%S", first)
end

-- s without colour codes, bars and control characters, trimmed, at most max characters (UTF-8 kept
-- whole); nil when nothing is left.
local function cleanText(s, max)
    if type(s) ~= "string" then return nil end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", ""):gsub("%c", " ")
    s = trim(s)
    local out, n = {}, 0
    for ch in s:gmatch("[%z\1-\127\192-\253][\128-\191]*") do
        n = n + 1
        if n > max then break end
        out[n] = ch
    end
    s = trim(table.concat(out))
    return s ~= "" and s or nil
end

-- Whether json nests deeper than max (strings left out): checked before the client's reader.
local function tooDeep(json, max)
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

-- A name of the code without its "-Realm". A Forever surname may hold a dash ("Anna Stein-Herz"):
-- with a surname only the own realm or a second dash in the surname is taken for the realm.
local function dropRealm(s)
    local base, tail = s:match("^(.-)%-([^%-]*)$")
    if not base then return s end
    -- one word before the first dash: no surname, all after it is the realm ("Bob-Die Aldor")
    if not s:match("^([^%-]*)"):find(" ", 1, true) then return (s:gsub("%-.*$", "")) end
    local sur = s:match("^%S+ (.+)$")
    local realm = type(GetNormalizedRealmName) == "function" and ns.Plain(GetNormalizedRealmName())
    local function flat(x) return (x:gsub("[%s']", ""):lower()) end
    if type(realm) == "string" and realm ~= "" and flat(tail) == flat(realm) then return base end
    if select(2, sur:gsub("%-", "")) >= 2 then return base end
    return s
end

-- A name of the code: cleaned, "-Realm" dropped, no digits or separators.
local function codeName(s)
    s = cleanText(s, MAX_NAME)
    s = s and dropRealm(s)
    if not s or s == "" or s:find("[%d,;:]") then return nil end
    return shortName(s)
end

local function codeItem(v)
    if type(v) == "table" then v = v.id end
    v = tonumber(v)
    if not v or v % 1 ~= 0 or v < 1 or v > 999999 then return nil end
    return v
end

-- A class as a list writes it ("Priest", "Death Knight", "PRIEST") as the client's token, or nil.
local CLASS_TOKENS = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true, SHAMAN = true,
                       MAGE = true, WARLOCK = true, DRUID = true, DEATHKNIGHT = true, MONK = true, DEMONHUNTER = true,
                       EVOKER = true }
function ns.SoftResClassToken(s)
    if type(s) ~= "string" then return nil end
    local t = s:gsub("[^%a]", ""):upper()
    return CLASS_TOKENS[t] and t or nil
end

-- A class token as the client names it ("Priester"), else the token.
function ns.SoftResClassName(token)
    local names = _G.LOCALIZED_CLASS_NAMES_MALE
    return type(names) == "table" and names[token] or token
end

-- "Klasse passt nicht: softres Magier, im Raid Priester" for a finding of check.class; short (the
-- import preview's row): "Klasse: softres Magier, im Raid Priester".
function ns.SoftResClassText(f, short)
    return (short and L["Klasse: softres %s, im Raid %s"] or L["Klasse passt nicht: softres %s, im Raid %s"])
        :format(ns.SoftResClassName(f.want), ns.SoftResClassName(f.have))
end

ns.SoftResClean = function(s, max) return cleanText(s, max) end

-- A list's class as written, kept only when it names a class ("Priest", "Death Knight").
local function listClass(s)
    s = cleanText(s, 20)
    return s and ns.SoftResClassToken(s) and s or nil
end

-- The pasted text as a code, or nil: one word of Base64 characters (line breaks around and inside it
-- dropped), at least 24 long. "Anna 18814" or a CSV never is one.
function ns.SoftResCode(text)
    if type(text) ~= "string" then return nil end
    local code = trim(text):gsub("[\r\n]+", "")
    if #code < 24 or not code:match("^[%w+/]+=?=?$") then return nil end
    return code
end

-- Unpacks a code: the JSON as a table, or nil and why ("api" the client lacks a function, "big",
-- "broken").
function ns.DecodeSoftResCode(code)
    local E = _G.C_EncodingUtil
    if type(E) ~= "table" or type(E.DecodeBase64) ~= "function" or type(E.DecompressString) ~= "function"
        or type(E.DeserializeJSON) ~= "function" then
        return nil, "api"
    end
    if type(code) ~= "string" or #code > MAX_CODE then return nil, "big" end
    local method = (Enum and Enum.CompressionMethod and Enum.CompressionMethod.Zlib) or ZLIB
    local ok, raw = pcall(E.DecodeBase64, code)
    if not ok or type(raw) ~= "string" or raw == "" then return nil, "broken" end
    local ok2, json = pcall(E.DecompressString, raw, method)
    if not ok2 or type(json) ~= "string" or json == "" then return nil, "broken" end
    if #json > MAX_JSON then return nil, "big" end
    if tooDeep(json, MAX_DEPTH) then return nil, "broken" end
    local ok3, data = pcall(E.DeserializeJSON, json)
    if not ok3 or type(data) ~= "table" then return nil, "broken" end
    return data
end

local CODE_ERRORS = {
    api = L["Dieser Client kann den Code nicht entpacken. Bitte den CSV-Export nehmen."],
    big = L["Code zu groß."],
    broken = L["Der Code ist unvollständig oder verändert. Auf softres.it 'Gargul' öffnen, 'Copy to Clipboard', hier ohne weitere Zeichen einfügen."],
    empty = L["Code gelesen, aber keine Reservierungen darin."],
}
function ns.SoftResCodeError(why) return why and CODE_ERRORS[why] or nil end

-- The reservations of a code through add(item, name); fills extra (notes, classes, the softres +1,
-- hard reserves, bonus rolls counted, the softres id and its last change) or sets extra.err.
local function readCode(code, add, extra, count)
    local data, why = ns.DecodeSoftResCode(code)
    if not data then extra.err = why return end
    local function list(v) return type(v) == "table" and v or {} end
    for _, sr in ipairs(list(data.softreserves)) do
        local name = type(sr) == "table" and codeName(sr.name)
        if name then
            local key = aliased(name)
            for _, it in ipairs(list(sr.items)) do
                if count() >= MAX_RESERVES then break end
                local id = codeItem(it)
                if id then add(id, name) end
            end
            extra.notes[key] = cleanText(sr.note, MAX_NOTE)
            extra.classes[key] = listClass(sr.class)
            local plus = tonumber(sr.plusOnes)
            extra.plus[key] = (plus and plus >= 1 and plus % 1 == 0 and plus <= 99) and plus or nil
        end
    end
    for _, h in ipairs(list(data.hardreserves)) do
        local id = type(h) == "table" and codeItem(h.id)
        if id and not extra.hard[id] and extra.hardCount < MAX_RESERVES then
            extra.hard[id] = { to = cleanText(h["for"], MAX_NAME) or "", note = cleanText(h.note, MAX_NOTE) or "" }
            extra.hardCount = extra.hardCount + 1
        end
    end
    extra.bonus = math.min(#list(data.bonusrolls), 999)
    local meta = list(data.metadata)
    local sid = cleanText(meta.id, 40)
    extra.sid = sid and sid:match("^[%w%-_]+$") or nil
    local updated = tonumber(meta.updatedAt)
    extra.updated = (updated and updated >= 0 and updated < 4e9) and math.floor(updated) or nil
    if count() == 0 and extra.hardCount == 0 then extra.err = "empty" end
end

-- Returns byItem { [itemID] = { names } }, the number of distinct reservations (name and item),
-- the unrecognised lines, times { [itemID] = { [name] = n } } for names that reserved an item more
-- than once, the number of all reservations (doubles included), renamed { [fixed] = listName }
-- for names a remembered fix changed and extra { src = "csv"|"lines"|"code" }; a code adds notes,
-- classes, plus (softres +1, a hint only, D-22), hard { [itemID] = { to, note } }, hardCount, bonus,
-- sid, updated, or err ("api", "big", "broken", "empty") and nothing else.
function ns.ParseSoftRes(text)
    local byItem, sets, bad, count, times, total, renamed = {}, {}, {}, 0, {}, 0, {}
    local extra = { src = "lines" }
    local function add(item, name)
        if not item or not name then return false end
        -- what the raid can be sent (F-107): item ids 1-9999999, names without digits or separators
        if item < 1 or item > 9999999 or item % 1 ~= 0 or #name > MAX_NAME or name:find("[%d,;:|]") then return false end
        name = aliased(name, renamed)
        sets[item] = sets[item] or {}
        total = total + 1
        if not sets[item][name] then
            sets[item][name] = 1
            byItem[item] = byItem[item] or {}
            byItem[item][#byItem[item] + 1] = name
            count = count + 1
        else
            sets[item][name] = sets[item][name] + 1
            times[item] = times[item] or {}
            times[item][name] = sets[item][name]
        end
        return true
    end
    local code = ns.SoftResCode(text)
    if code then
        extra = { src = "code", notes = {}, classes = {}, plus = {}, hard = {}, hardCount = 0, bonus = 0 }
        readCode(code, add, extra, function() return total end)
        if extra.err and extra.err ~= "empty" then byItem, count, times, total, renamed = {}, 0, {}, 0, {} end
        for _, names in pairs(byItem) do table.sort(names) end
        return byItem, count, bad, times, total, renamed, extra
    end
    local all = splitLines(text)
    if #all > 0 and all[1]:lower():gsub("%s", ""):find("itemid", 1, true) then
        extra.src = "csv"
        local head = all[1]
        local delim = (select(2, head:gsub(";", "")) > select(2, head:gsub(",", ""))) and ";" or ","
        local cols = {}
        for i, h in ipairs(splitCsv(head, delim)) do cols[(h:lower():gsub("%s", ""))] = i end
        local cItem = cols["itemid"]
        -- softres.it heads its CSV "Item Name,Item ID,From,Raider Name,Raider Class,..." (2026); older
        -- exports and other tools used "Name" or "Character"
        local cName = cols["raidername"] or cols["name"] or cols["character"] or cols["charactername"]
            or cols["player"] or cols["playername"]
        local cClass = cols["raiderclass"] or cols["class"]
        extra.classes = {}
        for i = 2, #all do
            local f = splitCsv(all[i], delim)
            local item = cItem and tonumber((f[cItem] or ""):match("(%d+)"))
            local name = cName and shortName(f[cName])
            if add(item, name) then
                local class = cClass and listClass(f[cClass])
                if class then extra.classes[aliased(name)] = class end
            else
                bad[#bad + 1] = all[i]
            end
        end
    else
        for _, line in ipairs(all) do
            -- "Name [Item-Link]" or "Name 32235"; the name may hold a space (Forever surnames)
            local item = ns.ItemID(line)
            local name
            if item then
                name = line:match("^(.-)%s*|c") or line:match("^(.-)%s*|H")
            else
                local n, num = line:match("^(.-)[%s,;:\t]+(%d+)%s*$")
                name, item = n, tonumber(num)
            end
            name = name and name:gsub("[%s,;:\t]+$", "")
            -- "Amy 32235 32236" or "Bob: 1, 2" is no name with one item: names hold no digits or separators
            if name and name:find("[%d,;:\t]") then name = nil end
            if not add(item, shortName(name)) then bad[#bad + 1] = line end
        end
    end
    for _, names in pairs(byItem) do table.sort(names) end
    return byItem, count, bad, times, total, renamed, extra
end

-- Stores a pasted list. Returns the number of reservations (doubles included), the bad lines, and
-- for a code that cannot be read the reason as text (then nothing is stored), and extra
-- (ns.ParseSoftRes).
function ns.SetSoftRes(text)
    local byItem, _, bad, times, total, renamed, extra = ns.ParseSoftRes(text)
    if extra.err then return 0, {}, ns.SoftResCodeError(extra.err), extra end
    AmisiaDB.softres = { version = 3, date = date("%Y-%m-%d"), byItem = byItem, raw = text or "", count = total,
                         times = times, renamed = renamed, reminded = {}, src = extra.src, sid = extra.sid,
                         updated = extra.updated, notes = extra.notes or {}, classes = extra.classes or {},
                         plus = extra.plus or {}, hard = extra.hard or {}, at = ns.ServerTime() }
    ns.MarkSoftResLoot()
    if ns.Refresh then ns.Refresh() end
    return total, bad, nil, extra
end

local function nameMap(t, ok)
    local out = {}
    for k, v in pairs(type(t) == "table" and t or {}) do
        if type(k) == "string" and ok(v) then out[k] = v end
    end
    return out
end

-- The list of 1.5 gets the fields of data model 2, a list of 2.25 those of data model 3 (the code's
-- notes, classes, softres +1 and hard reserves, empty); called by Core on ADDON_LOADED. The doubles
-- of 1.5 were merged already and count once. Running it again changes nothing.
function ns.MigrateSoftRes(DB)
    if type(DB) ~= "table" then return end
    DB.srAliases = type(DB.srAliases) == "table" and DB.srAliases or {}
    local sr = DB.softres
    if type(sr) ~= "table" then return end
    sr.byItem = type(sr.byItem) == "table" and sr.byItem or {}
    if not sr.version then
        sr.times, sr.renamed, sr.reminded = {}, {}, {}
        sr.version = 2
    end
    sr.times = type(sr.times) == "table" and sr.times or {}
    sr.renamed = type(sr.renamed) == "table" and sr.renamed or {}
    sr.reminded = type(sr.reminded) == "table" and sr.reminded or {}
    if sr.version < 3 then sr.version = 3 end
    local function str(v) return type(v) == "string" end
    sr.notes = nameMap(sr.notes, str)
    sr.classes = nameMap(sr.classes, str)
    sr.plus = nameMap(sr.plus, function(v) return type(v) == "number" and v >= 1 end)
    local hard = {}
    for id, h in pairs(type(sr.hard) == "table" and sr.hard or {}) do
        if type(id) == "number" and type(h) == "table" then
            hard[id] = { to = str(h.to) and h.to or "", note = str(h.note) and h.note or "" }
        end
    end
    sr.hard = hard
    -- since 2.41 (F-107): the import time and, for a list another officer shared, his name
    if type(sr.at) ~= "number" or sr.at < 0 or sr.at ~= math.floor(sr.at) then sr.at = nil end
    if type(sr.from) ~= "string" or sr.from == "" then sr.from = nil end
    if type(sr.hash) ~= "string" or not sr.hash:match("^%x+$") or #sr.hash ~= 16 then sr.hash = nil end
end

-- The hard reserve of an item from the loaded code ({ to, note }), or nil.
function ns.HardReserveOf(item)
    local sr = AmisiaDB and AmisiaDB.softres
    local h = sr and type(sr.hard) == "table" and sr.hard[tonumber(item) or 0]
    return type(h) == "table" and h or nil
end

-- "HR: Gilde (Bank)" for an item with a hard reserve, else nil.
function ns.HardReserveText(item)
    local h = ns.HardReserveOf(item)
    if not h then return nil end
    local text = L["HR: %s"]:format(h.to ~= "" and h.to or L["unbekannt"])
    if h.note ~= "" then text = text .. " (" .. h.note .. ")" end
    return text
end

-- How often name (as in the list) reserved item.
local function timesOf(sr, item, name)
    local t = sr and sr.times and sr.times[item]
    return (t and tonumber(t[name])) or 1
end
ns.SoftResTimes = timesOf

---------------------------------------------------------------------------
-- Check against the raid
---------------------------------------------------------------------------
local function sortedKeys(set)
    local out = {}
    for k in pairs(set) do out[#out + 1] = k end
    table.sort(out)
    return out
end

-- Who to check against: the raid, else the running recording or the newest raid. Returns the
-- names, a label ("Raid (25)", "letzter Raid, 02.10.") and their classes ({ [lower name] = token },
-- as far as known), or {}, nil and {}.
function ns.SoftResRoster()
    if IsInRaid() then
        local set, classes, n = {}, {}, GetNumGroupMembers() or 0
        for i = 1, n do
            local raw, _, _, _, _, class = GetRaidRosterInfo(i)
            local name = ns.FullName(ns.Plain(raw))
            if name then
                set[name] = true
                class = ns.Plain(class)
                if type(class) == "string" and class ~= "" then classes[name:lower()] = class end
            end
        end
        return sortedKeys(set), ("Raid (%d)"):format(n), classes
    end
    local s = ns.Active and ns.Active()
    if not s then
        for _, o in ipairs(ns.Sessions and ns.Sessions() or {}) do
            if not s or (o.start or 0) > (s.start or 0) then s = o end
        end
    end
    if not s then return {}, nil, {} end
    local classes = {}
    for name, m in pairs(s.members or {}) do
        if type(m) == "table" and type(m.class) == "string" and m.class ~= "" then classes[name:lower()] = m.class end
    end
    return sortedKeys(s.members or {}), L["letzter Raid, %s"]:format(ns.FmtDay(s.start or time())), classes
end

-- Edit distance of two strings (bytes).
local function distance(a, b)
    if a == b then return 0 end
    local la, lb = #a, #b
    local prev = {}
    for j = 0, lb do prev[j] = j end
    for i = 1, la do
        local cur = { [0] = i }
        local ca = a:byte(i)
        for j = 1, lb do
            local cost = (ca == b:byte(j)) and 0 or 1
            cur[j] = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
        end
        prev = cur
    end
    return prev[lb]
end

local function firstName(name) return (name:match("^(%S+)") or name):lower() end

-- The loaded list (or sr, e.g. a preview from ns.ParseSoftRes) against roster and its classes
-- (both default ns.SoftResRoster()). Pure: no frames, no chat. nil without a list.
-- match: list name -> the raider it was matched to (exact or one by ns.SameName); class: { name,
-- raider, want, have } for a match whose class on the list is another than in the raid (tokens).
function ns.SoftResCheck(sr, roster, classes)
    sr = sr or (AmisiaDB and AmisiaDB.softres)
    if type(sr) ~= "table" then return nil end
    if not roster then
        local _
        roster, _, classes = ns.SoftResRoster()
    end
    classes = classes or {}
    local listClasses = type(sr.classes) == "table" and sr.classes or {}
    local function wants(name) return ns.SoftResClassToken(listClasses[name]) end
    local out = { roster = #roster, reservers = 0, ok = {}, missing = {}, absent = {}, unclear = {}, over = {}, multi = {},
                  match = {}, class = {} }
    -- every list name with its sum of reservations
    local sums, multi = {}, {}
    for item, names in pairs(sr.byItem or {}) do
        for _, name in ipairs(names) do
            local n = timesOf(sr, item, name)
            sums[name] = (sums[name] or 0) + n
            if n > 1 then multi[#multi + 1] = { name = name, item = item, n = n } end
        end
    end
    local listNames = sortedKeys(sums)
    out.reservers = #listNames
    local exact = {}
    for _, r in ipairs(roster) do exact[r:lower()] = r end
    local found, lost = {}, {}   -- roster name -> true; list names not in the raid
    for _, name in ipairs(listNames) do
        local hit = exact[name:lower()]
        if hit then
            found[hit] = true
            out.match[name] = hit
        else
            local cands = {}
            for _, r in ipairs(roster) do
                if ns.SameName(name, r) then cands[#cands + 1] = r end
            end
            table.sort(cands)
            if #cands == 1 then
                found[cands[1]] = true
                out.match[name] = cands[1]
                if not name:find(" ", 1, true) and cands[1]:find(" ", 1, true) then
                    out.unclear[#out.unclear + 1] = { name = name, kind = "surname", suggest = cands }
                end
            elseif #cands > 1 then
                -- several raiders share this first name: no guess, the officer picks
                lost[#lost + 1] = name
                out.unclear[#out.unclear + 1] = { name = name, kind = "surname", suggest = { cands[1], cands[2], cands[3] } }
            else
                lost[#lost + 1] = name
            end
        end
    end
    for _, r in ipairs(roster) do
        if found[r] then out.ok[#out.ok + 1] = r else out.missing[#out.missing + 1] = r end
    end
    table.sort(out.ok); table.sort(out.missing)
    -- a matched name whose class on the list is another than the raider's
    for _, name in ipairs(listNames) do
        local r = out.match[name]
        local want, have = wants(name), r and classes[r:lower()]
        if want and have and want ~= have then
            out.class[#out.class + 1] = { name = name, raider = r, want = want, have = have }
        end
    end
    -- names not in the raid: suggestions among the raiders without a reservation; the same class
    -- allows one letter more and comes first
    local done = {}
    for _, u in ipairs(out.unclear) do done[u.name] = true end
    for _, name in ipairs(lost) do
        out.absent[#out.absent + 1] = name
        if not done[name] then
            local low, sug, want = name:lower(), {}, wants(name)
            for _, r in ipairs(out.missing) do
                local d = (#name >= 4 and #r >= 4) and distance(low, r:lower()) or 99
                local same = want ~= nil and classes[r:lower()] == want
                if d <= (same and 3 or 2) or firstName(name) == firstName(r) then
                    sug[#sug + 1] = { r = r, d = d, s = same and 0 or 1 }
                end
            end
            if #sug > 0 then
                table.sort(sug, function(a, b)
                    if a.s ~= b.s then return a.s < b.s end
                    if a.d ~= b.d then return a.d < b.d end
                    return a.r < b.r
                end)
                local list = {}
                for i = 1, math.min(3, #sug) do list[i] = sug[i].r end
                out.unclear[#out.unclear + 1] = { name = name, kind = "typo", suggest = list }
            end
        end
    end
    table.sort(out.absent)
    table.sort(out.unclear, function(a, b) return a.name < b.name end)
    local limit = tonumber(ns.Get("softres.limit")) or 0
    if limit > 0 then
        for _, name in ipairs(listNames) do
            if sums[name] > limit then out.over[#out.over + 1] = { name = name, n = sums[name] } end
        end
    end
    table.sort(multi, function(a, b) if a.name ~= b.name then return a.name < b.name end return a.item < b.item end)
    out.multi = multi
    return out
end

-- The reservations of a name (over ns.SameNameIn with roster, default the group): { { item, n } },
-- by item name. A bare first name on the list counts only while one raider carries it.
function ns.ReservesOf(name, roster)
    local sr = AmisiaDB and AmisiaDB.softres
    roster = roster or ns.GroupRoster()
    local out, at = {}, {}
    for item, names in pairs(sr and sr.byItem or {}) do
        for _, n in ipairs(names) do
            if ns.SameNameIn(n, name, roster) then
                if at[item] then
                    at[item].n = at[item].n + timesOf(sr, item, n)
                else
                    at[item] = { item = item, n = timesOf(sr, item, n) }
                    out[#out + 1] = at[item]
                end
            end
        end
    end
    for _, e in ipairs(out) do e.sort = ns.ItemName(e.item) end
    table.sort(out, function(a, b) if a.sort ~= b.sort then return a.sort < b.sort end return a.item < b.item end)
    for _, e in ipairs(out) do e.sort = nil end
    return out
end

-- Renames a name of the loaded list everywhere (a typo, a missing surname). remember: the fix also
-- holds for every later list. Returns the number of items changed; 0 when from is not in the list.
function ns.RenameReserve(from, to, remember)
    local sr = AmisiaDB and AmisiaDB.softres
    to = ns.FullName(to)
    if not sr or type(from) ~= "string" or not to or from == to then return 0 end
    local lowFrom, lowTo = from:lower(), to:lower()
    local n, listName = 0, nil
    for item, names in pairs(sr.byItem or {}) do
        local at, has
        for i, name in ipairs(names) do
            local low = name:lower()
            if not at and low == lowFrom then at = i elseif low == lowTo then has = name end
        end
        if at then
            n = n + 1
            -- the spellings as the list holds them; "vulo" finds "Vulo"
            local old = names[at]
            listName = listName or old
            local count = timesOf(sr, item, old)
            table.remove(names, at)
            if has then
                count = count + timesOf(sr, item, has)
                if has ~= to then
                    for i, name in ipairs(names) do
                        if name == has then names[i] = to end
                    end
                    table.sort(names)
                end
            else
                names[#names + 1] = to
                table.sort(names)
            end
            sr.times = sr.times or {}
            local t = sr.times[item]
            if t then
                t[old] = nil
                if has then t[has] = nil end
            end
            if count > 1 then
                sr.times[item] = t or {}
                sr.times[item][to] = count
            elseif t and next(t) == nil then
                sr.times[item] = nil
            end
        end
    end
    if n == 0 then return 0 end
    sr.renamed = sr.renamed or {}
    for k, v in pairs(sr.renamed) do
        if k:lower() == lowFrom and k ~= to then
            sr.renamed[to] = sr.renamed[to] or v
            sr.renamed[k] = nil
        end
    end
    if listName ~= to then sr.renamed[to] = sr.renamed[to] or listName end
    -- the code's note, class and softres +1 of the name go with it (what the new name has stays)
    for _, field in ipairs({ "notes", "classes", "plus" }) do
        local t = sr[field]
        if type(t) == "table" then
            local moved = {}
            for k in pairs(t) do
                if type(k) == "string" and k:lower() == lowFrom and k ~= to then moved[#moved + 1] = k end
            end
            for _, k in ipairs(moved) do
                if t[to] == nil then t[to] = t[k] end
                t[k] = nil
            end
        end
    end
    if remember and AmisiaDB then
        AmisiaDB.srAliases = AmisiaDB.srAliases or {}
        AmisiaDB.srAliases[from:lower()] = to
    end
    ns.MarkSoftResLoot()
    if ns.Refresh then ns.Refresh() end
    return n
end

-- A suggestion clicked in the import preview: the loaded list is renamed when it holds the name,
-- and the fix is remembered for the pasted text and coming lists either way (AmisiaDB.srAliases).
function ns.RememberSoftResName(from, to)
    if type(from) ~= "string" or type(to) ~= "string" or from == to or not AmisiaDB then return end
    if ns.RenameReserve(from, to, true) == 0 then
        AmisiaDB.srAliases = AmisiaDB.srAliases or {}
        AmisiaDB.srAliases[from:lower()] = to
    end
    if ns.SoftResImportChanged then ns.SoftResImportChanged() end
    if ns.Refresh then ns.Refresh() end
end

-- After an import by the window or "/amisia sr <code>": the list goes to the group (part A, F-107)
-- and, in a raid with softres.announce, into the raid chat (F-108). Returns whether it was shared.
function ns.SoftResAfterImport()
    local shared = ns.SoftResShareNow and ns.SoftResShareNow() or false
    if IsInRaid() and ns.IsOfficerView() and ns.Get("softres.announce") then ns.AnnounceSoftRes() end
    return shared
end

function ns.ClearSoftRes()
    local sr = AmisiaDB.softres
    AmisiaDB.softres = nil
    if sr and ns.SoftResShareCleared then ns.SoftResShareCleared(sr) end
    ns.MarkSoftResLoot()
    if ns.Refresh then ns.Refresh() end
end

function ns.ReservedBy(item)
    local sr = AmisiaDB and AmisiaDB.softres
    local names = sr and sr.byItem and sr.byItem[tonumber(item) or 0]
    return names or {}
end

-- "05.10." from the list's "2026-10-05".
function ns.SoftResShortDate(iso)
    local y, m, d = tostring(iso or ""):match("^(%d+)%-(%d+)%-(%d+)$")
    if not d then return tostring(iso or "?") end
    return ns.FmtDay(time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 }))
end

-- Whole days since the list was loaded, or nil without a list or date.
function ns.SoftResAge(sr)
    sr = sr or (AmisiaDB and AmisiaDB.softres)
    local y, m, d = tostring(sr and sr.date or ""):match("^(%d+)-(%d+)-(%d+)$")
    if not y then return nil end
    local t = time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
    return t and math.max(0, math.floor((time() - t) / 86400)) or nil
end

function ns.SoftResInfo()
    local sr = AmisiaDB and AmisiaDB.softres
    if not sr then return nil end
    return sr.date, sr.count or 0
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------
-- The group as plain names (secret ones left out), or nil when alone.
local function groupNames()
    if not IsInGroup() then return nil end
    local out = {}
    for i = 1, GetNumGroupMembers() or 0 do
        local n = ns.FullName(ns.Plain((GetRaidRosterInfo(i))))
        if n then out[#out + 1] = n end
    end
    return out
end

-- "Reserviert: Fraktur, du x2 (+1 außerhalb)": in a group (softres.tooltipGroup) only reservers
-- from it, the others counted.
function ns.SoftResTooltipText(id)
    local sr = AmisiaDB and AmisiaDB.softres
    local names = ns.ReservedBy(id)
    if #names == 0 then return nil end
    local group = ns.Get("softres.tooltipGroup") and groupNames() or nil
    local me = ns.UnitFullName("player")
    -- "du" for a bare first name only while no one else in the group carries it
    local roster = group or groupNames() or {}
    local shown, outside = {}, 0
    for _, name in ipairs(names) do
        local inGroup = not group
        if group then
            for _, g in ipairs(group) do
                if ns.SameName(g, name) then inGroup = true break end
            end
        end
        if inGroup then
            local label = ns.SameNameIn(name, me, roster) and L["du"] or name
            local n = timesOf(sr, id, name)
            label = n > 1 and ("%s x%d"):format(label, n) or label
            -- a code's note and its softres +1 (a hint only: Amisia's plus-one stays its own, D-22)
            local extra = {}
            local note = sr and type(sr.notes) == "table" and sr.notes[name]
            if type(note) == "string" and note ~= "" then extra[#extra + 1] = note end
            local plus = sr and type(sr.plus) == "table" and tonumber(sr.plus[name])
            if plus and plus > 0 then extra[#extra + 1] = L["softres +1: %d"]:format(plus) end
            shown[#shown + 1] = #extra > 0 and (label .. " (" .. table.concat(extra, ", ") .. ")") or label
        else
            outside = outside + 1
        end
    end
    local text = L["Reserviert: %s"]:format(#shown > 0 and table.concat(shown, ", ") or L["niemand aus der Gruppe"])
    if outside > 0 then text = text .. L[" (+%d außerhalb)"]:format(outside) end
    return text
end

-- Through the shared item tooltip hook (Core.lua): protected, one line per tooltip build.
ns.OnItemTooltip("softres", function(tip, _, id)
    if not ns.Get("softres.tooltip") then return false end
    local text = ns.SoftResTooltipText(id)
    local hard = ns.HardReserveText(id)
    if not text and not hard then return false end
    if hard then tip:AddLine(hard, 0.89, 0.72, 0.34) end
    if text then tip:AddLine(text, 0.89, 0.72, 0.34) end
    return true
end)

---------------------------------------------------------------------------
-- Loot window marks
---------------------------------------------------------------------------
-- btn: an element of the scrolling loot window; the mark sits on its icon button, btn.Item.
local function markButton(btn, slot)
    if not ns.Get("softres.lootMark") then
        if marks[btn] then marks[btn]:Hide() end
        return
    end
    local icon = btn.Item
    if type(icon) ~= "table" or type(icon.CreateFontString) ~= "function" then return end
    -- a secret link (the loot window in a boss fight on Forever) is never read: no mark then
    local link = slot and GetLootSlotLink and ns.Plain(GetLootSlotLink(slot))
    local id = link and ns.ItemID(link)
    -- a hard reserve (from a softres.it code) is "HR", before a soft reserve
    local hard = id and ns.HardReserveOf(id) ~= nil
    local reserved = hard or (id and #ns.ReservedBy(id) > 0)
    local mark = marks[btn]
    if reserved and not mark then
        -- on the item icon, top left (the quality text sits at the element's top right)
        mark = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        mark:SetPoint("TOPLEFT", icon, "TOPLEFT", 1, -1)
        mark:SetTextColor(0.89, 0.72, 0.34)
        marks[btn] = mark
    end
    if mark then
        mark:SetText(hard and "HR" or "SR")
        if reserved then mark:Show() else mark:Hide() end
    end
end

-- For tests and the window: the SR of a loot element, and whether it is visible.
function ns.SoftResMark(btn) return marks[btn] end
function ns.SoftResMarkShown(btn)
    local m = marks[btn]
    return (m and m:IsShown()) and true or false
end

-- Marks every element the loot window shows now.
function ns.MarkSoftResLoot()
    local box = LootFrame and LootFrame.ScrollBox
    if box and box.ForEachFrame then
        box:ForEachFrame(function(frame)
            if frame.GetSlotIndex then markButton(frame, frame:GetSlotIndex()) end
        end)
    end
end

-- The loot window is a scroll box that hands its element frames to other slots while it scrolls:
-- every element it sets up is marked again (the client's initialised-frame callback).
local scrollHooked
local function onLootElement(_, frame)
    if type(frame) ~= "table" or type(frame.GetSlotIndex) ~= "function" then return end
    local ok, err = pcall(function() markButton(frame, frame:GetSlotIndex()) end)
    if not ok then
        local handler = geterrorhandler and geterrorhandler()
        if handler then handler(err) end
    end
end
local function hookLootScroll()
    if scrollHooked then return end
    local box = LootFrame and LootFrame.ScrollBox
    local util = _G.ScrollUtil
    if type(box) ~= "table" or type(util) ~= "table" or type(util.AddInitializedFrameCallback) ~= "function" then return end
    scrollHooked = true
    util.AddInitializedFrameCallback(box, onLootElement, marks)
end
hookLootScroll()

ns.OnEvent("LOOT_OPENED", function()
    hookLootScroll()
    C_Timer.After(0, ns.MarkSoftResLoot)
end)
ns.OnEvent("LOOT_SLOT_CLEARED", function() C_Timer.After(0, ns.MarkSoftResLoot) end)

---------------------------------------------------------------------------
-- Chat: reminders, the raid summary and !sr for raiders without the addon
---------------------------------------------------------------------------
local REPLY_LINES = 3     -- lines of one answer
local SUMMARY_LINES = 2
local REMIND_TEXT = L["Amisia: Du hast für heute noch nichts reserviert."]

-- Lines of head and parts (ns.ChatLines) within maxLines: the parts that do not fit become
-- "und n weitere" at the end of the last part kept. suffix goes after the last part.
local function cappedLines(head, parts, maxLines, sep, suffix, moreText)
    suffix = suffix or ""
    moreText = moreText or L["und %d weitere"]
    local function build(list)
        if #list == 0 then return ns.ChatLines(head .. suffix, {}, sep) end
        local copy = {}
        for i, p in ipairs(list) do copy[i] = p end
        copy[#copy] = copy[#copy] .. suffix
        return ns.ChatLines(head, copy, sep)
    end
    local lines = build(parts)
    if #lines <= maxLines then return lines end
    for k = #parts - 1, 0, -1 do
        local cut = {}
        for i = 1, k do cut[i] = parts[i] end
        local more = moreText:format(#parts - k)
        if k > 0 then cut[k] = cut[k] .. " " .. more else cut[1] = more end
        lines = build(cut)
        if #lines <= maxLines then return lines end
    end
    return { lines[1] }
end

-- The raw name of a raid member as the roster gives it, for whispers.
local function rawRosterName(name)
    for i = 1, GetNumGroupMembers() or 0 do
        local raw = ns.Plain((GetRaidRosterInfo(i)))
        if type(raw) == "string" and ns.FullName(raw) == name then return raw end
    end
    return name
end

-- Raid members without a reservation who were not reminded for this list yet; never oneself.
-- check: a ns.SoftResCheck of the list against the raid, when the caller has one already.
function ns.SoftResReminders(check)
    local sr = AmisiaDB and AmisiaDB.softres
    if not sr or not IsInRaid() then return {} end
    local c = check or ns.SoftResCheck(sr)
    local me = ns.UnitFullName("player")
    local out = {}
    for _, name in ipairs(c and c.missing or {}) do
        if not (sr.reminded and sr.reminded[name]) and not ns.SameName(name, me) then out[#out + 1] = name end
    end
    return out
end

local LOCKED = L["Chat ist gerade gesperrt (Bosskampf). Nach dem Kampf erneut."]

-- Whispers everyone of ns.SoftResReminders() once (ttl 120) and marks them. Returns the number,
-- and the reason when nothing could be sent. Never in the chat lockdown: a whisper queued there
-- may run out unsent, and the raider would count as reminded.
function ns.SendSoftResReminders()
    local sr = AmisiaDB and AmisiaDB.softres
    if not sr then return 0 end
    if ns.ChatLocked and ns.ChatLocked() then return 0, LOCKED end
    local extra = ns.Get("softres.remindText")
    local text = REMIND_TEXT .. ((type(extra) == "string" and extra ~= "") and (" " .. extra) or "")
    local n = 0
    sr.reminded = sr.reminded or {}
    for _, name in ipairs(ns.SoftResReminders()) do
        if ns.Say(text, "WHISPER", rawRosterName(name), { ttl = 120 }) then
            sr.reminded[name] = time()
            n = n + 1
        end
    end
    if ns.Refresh then ns.Refresh() end
    return n
end

-- Asks before whispering (officers, in a raid). The dialog is lifted above the main window.
function ns.ConfirmSoftResReminders()
    if not ns.IsOfficerView() then ns.msg(L["Erinnern nur in der Offiziersansicht."]) return end
    if not (AmisiaDB and AmisiaDB.softres) then ns.msg(L["Keine Soft-Reserves geladen."]) return end
    if not IsInRaid() then ns.msg(L["Erinnern geht nur im Raid."]) return end
    if ns.ChatLocked and ns.ChatLocked() then ns.msg(LOCKED) return end
    local n = #ns.SoftResReminders()
    if n == 0 then ns.msg(L["Alle ohne Reserve wurden schon erinnert."]) return end
    local d = StaticPopup_Show("AMISIA_SR_REMIND", n)
    if d and d.SetFrameStrata then d:SetFrameStrata("FULLSCREEN_DIALOG"); if d.Raise then d:Raise() end end
end

StaticPopupDialogs["AMISIA_SR_REMIND"] = {
    text = L["%d Raidern ohne Reserve flüstern?"],
    button1 = L["Flüstern"],
    button2 = L["Abbrechen"],
    OnAccept = function()
        local n, why = ns.SendSoftResReminders()
        ns.msg(why or L["%d Raider erinnert."]:format(n))
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- "Soft-Reserves: 22 von 25 haben reserviert. Ohne Reserve: ..." in the raid chat, two lines at
-- most. Returns the number of lines, or nil and the reason.
function ns.PostSoftResSummary()
    local sr = AmisiaDB and AmisiaDB.softres
    if not sr then return nil, L["Keine Soft-Reserves geladen."] end
    if not IsInRaid() then return nil, L["Posten geht nur im Raid."] end
    local c = ns.SoftResCheck(sr)
    local lines
    if #c.missing == 0 then
        lines = { L["Soft-Reserves: alle %d haben reserviert."]:format(c.roster) }
    else
        lines = cappedLines(L["Soft-Reserves: %d von %d haben reserviert. Ohne Reserve: "]:format(#c.ok, c.roster),
            c.missing, SUMMARY_LINES, ", ", ".")
    end
    for _, line in ipairs(lines) do ns.Say(line, "RAID") end
    return #lines
end

-- The check as lines for one's own chat (/amisia sr pruefen).
function ns.SoftResCheckLines()
    local sr = AmisiaDB and AmisiaDB.softres
    if not sr then return { L["Keine Soft-Reserves geladen."] } end
    local roster, label, classes = ns.SoftResRoster()
    if not label then return { L["Kein Raid zum Abgleichen."] } end
    local c = ns.SoftResCheck(sr, roster, classes)
    local out = { L["Abgleich mit %s: %d reserviert, %d ohne Reserve, %d nicht im Raid, %d unklar%s."]:format(
        (label:gsub("^letzter ", "letztem ")), #c.ok, #c.missing, #c.absent, #c.unclear,   -- l10n-ok: German case of the label (English has no match)
        (#c.over > 0 and L[", %d zu viel"]:format(#c.over) or "") .. (#c.class > 0 and L[", %d Klasse falsch"]:format(#c.class) or "")) }
    if #c.missing > 0 then out[#out + 1] = L["Ohne Reserve: %s"]:format(table.concat(c.missing, ", ")) end
    if #c.absent > 0 then out[#out + 1] = L["Nicht im Raid: %s"]:format(table.concat(c.absent, ", ")) end
    for _, u in ipairs(c.unclear) do
        out[#out + 1] = L["Unklar: %s (%s?)"]:format(u.name, table.concat(u.suggest, ", "))
    end
    for _, o in ipairs(c.over) do out[#out + 1] = L["Zu viele: %s (%d)"]:format(o.name, o.n) end
    for _, f in ipairs(c.class) do out[#out + 1] = ("%s: %s"):format(f.name, ns.SoftResClassText(f)) end
    for _, m in ipairs(c.multi) do out[#out + 1] = L["Mehrfach: %s, %s x%d"]:format(m.name, ns.ItemName(m.item), m.n) end
    return out
end

-- !sr answers ------------------------------------------------------------
-- A link to put into the chat: the client's link when it knows the item, else the name in brackets.
local function chatLink(id)
    local _, link = GetItemInfo(id)
    if type(link) == "string" and link:find("|Hitem:", 1, true) then return link end
    return "[" .. ns.ItemName(id) .. "]"
end

local NOBODY = L["niemand"]

local function reserversText(sr, item)
    local names = ns.ReservedBy(item)
    if #names == 0 then return NOBODY end
    local parts = {}
    for _, name in ipairs(names) do
        local n = timesOf(sr, item, name)
        parts[#parts + 1] = n > 1 and ("%s x%d"):format(name, n) or name
    end
    return table.concat(parts, ", ")
end

-- The answer to "!sr" (rest empty) or "!sr <link or part of a name>" as chat lines.
local function answer(sr, sender, rest)
    local age = ns.SoftResAge(sr) or 0
    local suffix = age > (tonumber(ns.Get("softres.warnDays")) or 7) and L[" (Liste ist %d Tage alt)"]:format(age) or ""
    local when = ns.SoftResShortDate(sr.date)
    if rest == "" then
        local mine = ns.ReservesOf(sender)
        if #mine == 0 then
            return { L["Amisia: Du hast nichts reserviert (Liste vom %s).%s"]:format(when, suffix) }
        end
        local parts = {}
        for _, e in ipairs(mine) do
            parts[#parts + 1] = chatLink(e.item) .. (e.n > 1 and (" x" .. e.n) or "")
        end
        return cappedLines(L["Amisia: Deine Reservierungen (Liste vom %s): "]:format(when), parts, REPLY_LINES, ", ", suffix)
    end
    local id = ns.ItemID(rest)
    if id then
        local link = rest:match("(|c%x+|Hitem:.-|h|r)") or chatLink(id)
        local who = reserversText(sr, id)
        return { L["Amisia: %s reserviert von %s%s%s"]:format(link, who, who == NOBODY and "." or "", suffix) }
    end
    local q = rest:gsub("|", ""):lower():sub(1, 40)
    local hits = {}
    for item in pairs(sr.byItem or {}) do
        local name = ns.ItemName(item)
        if name:lower():find(q, 1, true) then hits[#hits + 1] = { item = item, sort = name } end
    end
    if #hits == 0 then
        return { L["Amisia: Kein reserviertes Item passt zu \"%s\".%s"]:format(q, suffix) }
    end
    table.sort(hits, function(a, b) if a.sort ~= b.sort then return a.sort < b.sort end return a.item < b.item end)
    local parts = {}
    for i = 1, math.min(3, #hits) do
        parts[i] = L["%s reserviert von %s"]:format(chatLink(hits[i].item), reserversText(sr, hits[i].item))
    end
    if #hits > 3 then suffix = L[" (%d weitere Treffer)"]:format(#hits - 3) .. suffix end
    return cappedLines("Amisia: ", parts, REPLY_LINES, "; ", suffix)
end

-- The raid chat lines after an import (F-108): how many reserved and how to ask, then the hard
-- reserves with their links ("[Name]" while the client does not know an item). english: the fixed
-- English text for raiders with another addon or client (rolls.announceEnglish, as the roll
-- announcement), else the client's language. At most 1 + 3 lines.
function ns.SoftResAnnounceLines(sr, english)
    sr = sr or (AmisiaDB and AmisiaDB.softres)
    if not sr then return {} end
    local raiders = {}
    for _, names in pairs(sr.byItem or {}) do
        for _, name in ipairs(names) do raiders[name] = true end
    end
    local n = 0
    for _ in pairs(raiders) do n = n + 1 end
    local ask = ns.Get("softres.chat") and (ns.IsLootLead() and ns.UnitFullName("player") or "") or nil
    local lines = {}
    if english then
        local line = ("Soft reserves loaded: %d reserves from %d raiders."):format(sr.count or 0, n)
        if ask then line = line .. (" Whisper '!sr' to %s to see yours."):format(ask ~= "" and ask or "the loot lead") end
        lines[1] = line
    else
        local line = L["Soft-Reserves geladen: %d Reservierungen von %d Raidern."]:format(sr.count or 0, n)
        if ask then
            line = line .. " " .. (ask ~= "" and L["'!sr' an %s flüstern zeigt deine."]:format(ask)
                or L["'!sr' an die Lootleitung flüstern zeigt deine."])
        end
        lines[1] = line
    end
    local hard = {}
    for id, h in pairs(type(sr.hard) == "table" and sr.hard or {}) do
        hard[#hard + 1] = { id = id, to = h.to or "", note = h.note or "", sort = ns.ItemName(id) }
    end
    if #hard == 0 then return lines end
    table.sort(hard, function(a, b) if a.sort ~= b.sort then return a.sort < b.sort end return a.id < b.id end)
    local parts = {}
    for _, h in ipairs(hard) do
        local part = chatLink(h.id)
        if h.to ~= "" then part = part .. (english and (" for %s"):format(h.to) or L[" für %s"]:format(h.to)) end
        if h.note ~= "" and h.note ~= h.to then part = part .. " (" .. h.note .. ")" end
        parts[#parts + 1] = part
    end
    for _, line in ipairs(cappedLines(english and "Hard reserves: " or L["Hard-Reserves: "], parts, 3, ", ", ".",
        english and "and %d more" or nil)) do
        lines[#lines + 1] = line
    end
    return lines
end

local announceGen = 0   -- the newest announcement waiting for its item links

-- Says the lines of ns.SoftResAnnounceLines in the raid (officers, in a raid): waits up to 5 s for
-- the links of the hard reserves, then the lines go through the chat queue (held in the lockdown,
-- dropped after 120 s). Returns true, or nil and the reason.
function ns.AnnounceSoftRes()
    local sr = AmisiaDB and AmisiaDB.softres
    if not ns.IsOfficerView() then return nil, L["Ansagen nur in der Offiziersansicht."] end
    if not sr then return nil, L["Keine Soft-Reserves geladen."] end
    if not IsInRaid() then return nil, L["Ansagen geht nur im Raid."] end
    announceGen = announceGen + 1
    local gen, waited = announceGen, 0
    local function known()
        for id in pairs(type(sr.hard) == "table" and sr.hard or {}) do
            local _, link = GetItemInfo(id)
            if not link then
                if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
                return false
            end
        end
        return true
    end
    local function say()
        if gen ~= announceGen or AmisiaDB.softres ~= sr then return end
        if not known() and waited < 5 then
            waited = waited + 0.5
            C_Timer.After(0.5, say)
            return
        end
        for _, line in ipairs(ns.SoftResAnnounceLines(sr)) do ns.Say(line, "RAID", nil, { ttl = 120 }) end
        if ns.GERMAN and ns.Get("rolls.announceEnglish") then
            for _, line in ipairs(ns.SoftResAnnounceLines(sr, true)) do ns.Say(line, "RAID", nil, { ttl = 120 }) end
        end
    end
    say()
    return true
end

local function inGroup(name)
    for i = 1, GetNumGroupMembers() or 0 do
        local member = ns.FullName(ns.Plain((GetRaidRosterInfo(i))))
        if member and ns.SameName(member, name) then return true end
    end
    return false
end

-- sender is the raw text the client gave (already plain); the answer goes back to it by whisper.
local function onSoftResCommand(sender, rest)
    local sr = AmisiaDB and AmisiaDB.softres
    if not sr or not ns.Get("softres.chat") or not ns.IsLootLead() then return end
    local name = ns.FullName(sender)
    if not name or not inGroup(name) then return end
    -- one answer per sender every 15 s, 20 a minute (Chat.lua)
    if not ns.ReplyGate("sr", name:lower()) then return end
    for _, line in ipairs(answer(sr, name, rest or "")) do
        ns.Say(line, "WHISPER", sender, { ttl = 120 })
    end
end

ns.RegisterChatCommand("sr", onSoftResCommand)
ns.RegisterChatCommand("softres", onSoftResCommand)

---------------------------------------------------------------------------
-- The import preview (the window is UI/SoftResImport.lua)
---------------------------------------------------------------------------
local function plural(n, one, many) return n == 1 and one or many end

-- The preview line for a pasted text: parsed with the remembered fixes and checked against
-- ns.SoftResRoster(); nothing is stored. "" for an empty text.
function ns.SoftResPreviewText(text)
    if not (text or ""):find("%S") then return "" end
    local byItem, _, bad, times, total, _, extra = ns.ParseSoftRes(text)
    if extra.err then return ns.SoftResCodeError(extra.err) end
    local roster, label, classes = ns.SoftResRoster()
    local c = ns.SoftResCheck({ byItem = byItem, times = times, classes = extra.classes }, roster, classes)
    local head = L["%d Raider, %d %s"]:format(c.reservers, total, plural(total, L["Reservierung"], L["Reservierungen"]))
    local parts = {}
    if extra.src == "code" then
        -- the code: what it holds, then the check against the raid as for a CSV
        head = L["Gargul-Code erkannt: %d %s, %d %s"]:format(total, plural(total, L["Reservierung"], L["Reservierungen"]),
            extra.hardCount, plural(extra.hardCount, L["Hard-Reserve"], L["Hard-Reserves"]))
        local loaded = AmisiaDB and AmisiaDB.softres
        if extra.sid and loaded and loaded.sid == extra.sid then parts[#parts + 1] = L["gleicher Raid wie die geladene Liste"] end
        if extra.bonus > 0 then parts[#parts + 1] = L["%d Bonus-Würfe nicht übernommen"]:format(extra.bonus) end
        if label then
            if #c.missing > 0 then parts[#parts + 1] = L["%d ohne Reserve"]:format(#c.missing) end
            if #c.absent > 0 then parts[#parts + 1] = L["%d nicht im Raid"]:format(#c.absent) end
            if #c.unclear > 0 then parts[#parts + 1] = L["%d %s unklar"]:format(#c.unclear, plural(#c.unclear, L["Name##Anzahl"], L["Namen##Anzahl"])) end
            if #c.class > 0 then parts[#parts + 1] = L["%d Klasse falsch"]:format(#c.class) end
            if #c.over > 0 then parts[#parts + 1] = L["%d zu viel"]:format(#c.over) end
        else
            parts[#parts + 1] = L["kein Raid zum Abgleichen"]
        end
    elseif label then
        head = L["Vorschau gegen %s: %s"]:format((label:gsub("^letzter ", "letzten ")), head)   -- l10n-ok: German case of the label (English has no match)
        if #c.missing > 0 then parts[#parts + 1] = L["%d ohne Reserve"]:format(#c.missing) end
        if #c.absent > 0 then parts[#parts + 1] = L["%d nicht im Raid"]:format(#c.absent) end
        if #c.unclear > 0 then parts[#parts + 1] = L["%d %s unklar"]:format(#c.unclear, plural(#c.unclear, L["Name##Anzahl"], L["Namen##Anzahl"])) end
        if #c.class > 0 then parts[#parts + 1] = L["%d Klasse falsch"]:format(#c.class) end
        if #c.over > 0 then parts[#parts + 1] = L["%d zu viel"]:format(#c.over) end
    elseif extra.src ~= "code" then
        head = L["Vorschau: %s"]:format(head)
        parts[#parts + 1] = L["kein Raid zum Abgleichen"]
    end
    if #bad > 0 then parts[#parts + 1] = L["%d %s nicht erkannt"]:format(#bad, plural(#bad, L["Zeile"], L["Zeilen"])) end
    if #parts == 0 then return head end
    return head .. " · " .. table.concat(parts, " · ")
end

-- The preview of the import window (F-108): the pasted text, or the loaded list when text is nil.
-- Pure apart from reading the raid; nothing is stored. Returns nil for an empty text, else
-- { err, head (ns.SoftResPreviewText), label (the roster's), raid (IsInRaid), same (the text is the
--   loaded list), missing = { { name, class } }, hard = { { item, to, note } }, reservers,
--   rows = { { name, class, items = { { item, n } }, n, status, tone, suggest, sort } } }:
-- tone "unclear"/"class" (orange), "over" (red), "renamed" (gold), "absent" (grey) or nil; rows with
-- a finding first, then those in the raid, then those not in it, each by name.
function ns.SoftResPreview(text)
    local loaded = AmisiaDB and AmisiaDB.softres
    local list, head
    if text == nil then
        if not loaded then return nil end
        list, head = loaded, ""
    else
        if not text:find("%S") then return nil end
        local byItem, _, _, times, _, renamed, extra = ns.ParseSoftRes(text)
        head = ns.SoftResPreviewText(text)
        if extra.err then return { err = head, head = head, rows = {}, missing = {}, hard = {}, reservers = 0 } end
        list = { byItem = byItem, times = times, renamed = renamed, classes = extra.classes or {}, hard = extra.hard or {} }
    end
    local roster, label, classes = ns.SoftResRoster()
    local c = ns.SoftResCheck(list, roster, classes)
    local raw = loaded and loaded.raw or ""
    local out = { head = head, label = label, raid = IsInRaid() and true or false, missing = {}, hard = {}, rows = {},
                  reservers = c.reservers,
                  same = loaded ~= nil and (text == nil or text:match("^%s*(.-)%s*$") == raw:match("^%s*(.-)%s*$")) }
    for _, name in ipairs(c.missing) do out.missing[#out.missing + 1] = { name = name, class = classes[name:lower()] } end
    for id, h in pairs(type(list.hard) == "table" and list.hard or {}) do
        out.hard[#out.hard + 1] = { item = id, to = h.to or "", note = h.note or "", sort = ns.ItemName(id) }
    end
    table.sort(out.hard, function(a, b) if a.sort ~= b.sort then return a.sort < b.sort end return a.item < b.item end)
    -- the findings per name, the strongest kept
    local found = {}
    local function note(name, status, tone, rank, suggest)
        local f = found[name]
        if not f or rank < f.rank then found[name] = { status = status, tone = tone, rank = rank, suggest = suggest } end
    end
    for _, u in ipairs(c.unclear) do
        note(u.name, u.kind == "surname" and L["ohne Nachnamen, gemeint:"] or L["Name unklar, gemeint:"], "unclear", 1, u.suggest)
    end
    for _, f in ipairs(c.class) do note(f.name, ns.SoftResClassText(f, true), "class", 2) end
    local limit = tonumber(ns.Get("softres.limit")) or 0
    for _, o in ipairs(c.over) do note(o.name, L["zu viel: %d von %d"]:format(o.n, limit), "over", 3) end
    local renamed = type(list.renamed) == "table" and list.renamed or {}
    for name, was in pairs(renamed) do note(name, L["korrigiert aus %s"]:format(was), "renamed", 4) end
    local absent = {}
    for _, name in ipairs(c.absent) do
        absent[name] = true
        if label then note(name, L["nicht im Raid"], "absent", 5) end
    end
    -- the rows: every list name with its items
    local rows = {}
    for item, names in pairs(list.byItem or {}) do
        for _, name in ipairs(names) do
            local r = rows[name]
            if not r then
                local f = found[name]
                local raider = c.match[name]
                r = { name = name, items = {}, n = 0, class = (raider and classes[raider:lower()]) or ns.SoftResClassToken((list.classes or {})[name]),
                      status = f and f.status or nil, tone = f and f.tone or nil, suggest = f and f.suggest or nil,
                      group = (f and f.rank <= 3) and 1 or (absent[name] and 3 or 2) }
                rows[name] = r
                out.rows[#out.rows + 1] = r
            end
            local n = timesOf(list, item, name)
            r.items[#r.items + 1] = { item = item, n = n, sort = ns.ItemName(item) }
            r.n = r.n + n
        end
    end
    for _, r in ipairs(out.rows) do
        table.sort(r.items, function(a, b) if a.sort ~= b.sort then return a.sort < b.sort end return a.item < b.item end)
    end
    table.sort(out.rows, function(a, b)
        if a.group ~= b.group then return a.group < b.group end
        local la, lb = a.name:lower(), b.name:lower()
        if la ~= lb then return la < lb end
        return a.name < b.name
    end)
    return out
end


-- softres.remindText: no escape codes or line breaks, at most 120 characters (UTF-8 kept whole).
local function cleanRemindText(v)
    v = tostring(v or ""):gsub("|", ""):gsub("[\r\n]+", " ")
    v = v:match("^%s*(.-)%s*$")
    local out, n = {}, 0
    for ch in v:gmatch("[%z\1-\127\192-\253][\128-\191]*") do
        n = n + 1
        if n > 120 then break end
        out[n] = ch
    end
    return table.concat(out)
end

ns.RegisterSettings{ key = "softres", label = L["Soft-Reserves"], order = 27, group = "raid", pages = { "softres" }, items = {
    { key = "softres.tooltip", type = "toggle", label = L["Tooltip-Zeile \"Reserviert: ...\""], default = true, tip = L["Der Item-Tooltip nennt, wer das Item reserviert hat."] },
    { key = "softres.lootMark", type = "toggle", label = L["SR-Markierung im Lootfenster und an den Würfelfenstern"], default = true,
      onChange = function() ns.MarkSoftResLoot() end, tip = L["Reservierte Items tragen im Lootfenster und an den Würfelfenstern ein \"SR\"."] },
    { key = "softres.warnDays", type = "slider", label = L["Warnen, wenn die Liste älter ist als (Tage)"], default = 7, min = 1, max = 30, step = 1, tip = L["Ist die eingefügte Liste älter, steht bei ihrer Anzeige, wie alt sie ist."] },
    { key = "softres.tooltipGroup", type = "toggle", label = L["Im Tooltip nur Reservierungen aus der Gruppe"], default = true, tip = L["In einer Gruppe nennt der Tooltip nur die Reservierungen von Spielern, die dabei sind."] },
    { key = "softres.limit", type = "slider", label = L["Reservierungen pro Raider (0 = keine Prüfung)"], default = 0, min = 0, max = 6, step = 1,
      officer = true, tip = L["Die Prüfung der Liste nennt Raider, die mehr Items reserviert haben. 0 schaltet das aus."] },
    { key = "softres.chat", type = "toggle", label = L["Auf !sr antworten"], default = true, officer = true,
      tip = L["Nur als Lootleitung, per Flüsterung."] },
    { key = "softres.share", type = "toggle", label = L["Liste mit dem Raid teilen"], default = true, officer = true,
      tip = L["Deine übernommene Liste geht an alle Amisia-Nutzer im Raid, auch an später Kommende. Angenommen wird sie nur von Offizieren der eigenen Gilde."] },
    { key = "softres.announce", type = "toggle", label = L["Beim Übernehmen im Raid ansagen"], default = true, officer = true,
      tip = L["Nach dem Übernehmen sagt eine Zeile im Raidchat, wie viele reserviert haben und wie man mit '!sr' fragt; die Hard-Reserves folgen mit ihren Items."] },
    { key = "softres.remindText", type = "text", label = L["Zusatz in der Erinnerung"], default = "", officer = true,
      tip = L["Z. B. Link zur Liste."], validate = cleanRemindText },
}}
-- Forgets the remembered name fixes (AmisiaDB.srAliases): all of them, or the ones of name (as
-- written in a list or as fixed). The loaded list stays as it is. Returns the number forgotten.
function ns.ForgetSoftResAliases(name)
    local aliases = AmisiaDB and AmisiaDB.srAliases
    if type(aliases) ~= "table" then return 0 end
    local low = type(name) == "string" and name:match("^%s*(.-)%s*$"):lower() or ""
    local n = 0
    for from, to in pairs(aliases) do
        if low == "" or from:lower() == low or (type(to) == "string" and to:lower() == low) then
            aliases[from] = nil
            n = n + 1
        end
    end
    if n > 0 and ns.Refresh then ns.Refresh() end
    return n
end

-- The remembered fix for a list name, or nil.
function ns.SoftResAlias(listName)
    local aliases = AmisiaDB and AmisiaDB.srAliases
    local to = type(aliases) == "table" and type(listName) == "string" and aliases[listName:lower()]
    return type(to) == "string" and to or nil
end

local function forgetCommand(name)
    name = (name or ""):match("^%s*(.-)%s*$")
    local n = ns.ForgetSoftResAliases(name)
    if name == "" then
        ns.msg(n > 0 and L["%d gemerkte Namenskorrekturen vergessen. Die geladene Liste bleibt, wie sie ist."]:format(n)
            or L["Keine gemerkten Namenskorrekturen."])
    else
        ns.msg(n > 0 and L["Gemerkte Namenskorrektur für %s vergessen. Die geladene Liste bleibt, wie sie ist."]:format(name)
            or L["Keine gemerkte Namenskorrektur für %s."]:format(name))
    end
end

local SUBWORDS = { pruefen = "check", ["prüfen"] = "check", check = "check", erinnern = "remind", remind = "remind",   -- l10n-ok: typed sub-words, both languages work
                   posten = "post", post = "post", vergessen = "forget", forget = "forget" }
local SR_ARGS = L["[pruefen|erinnern|posten|vergessen [Name]]"]
-- "/amisia sr <code>": a softres.it code straight from the chat line (officers; the chat line takes
-- 255 characters, a longer code goes into the import window).
local function codeCommand(code)
    if not ns.IsOfficerView() then ns.msg(L["Importieren nur in der Offiziersansicht."]) return end
    local count, _, err, extra = ns.SetSoftRes(code)
    if err then ns.msg(err) return end
    local shared = ns.SoftResAfterImport()
    ns.msg(L["%d Reservierungen übernommen, Hard-Reserves: %d."]:format(count, extra.hardCount)
        .. (shared and (" " .. L["Mit der Gruppe geteilt."]) or ""))
end

ns.RegisterSlash("sr", { args = SR_ARGS, desc = L["Soft-Reserves anzeigen"], run = function(rest)
    local code = ns.SoftResCode(ns.Plain(rest))
    if code then codeCommand(code) return end
    local word, tail = (rest or ""):match("^(%S+)%s*(.-)$")
    local sub = word and SUBWORDS[word:lower()]
    if word and not sub then
        ns.msg(L["Aufruf: /amisia sr %s"]:format(SR_ARGS))
        return
    end
    if sub == "forget" then
        forgetCommand(tail)
    elseif sub == "check" then
        for _, line in ipairs(ns.SoftResCheckLines()) do ns.msg(line) end
    elseif sub == "remind" then
        ns.ConfirmSoftResReminders()
    elseif sub == "post" then
        if not ns.IsOfficerView() then ns.msg(L["Posten nur in der Offiziersansicht."]) return end

        local n, why = ns.PostSoftResSummary()
        if not n then ns.msg(why) end
    elseif ns.ShowPage then
        ns.ShowPage("softres")
    else
        ns.ToggleSoftResFrame()
    end
end })
