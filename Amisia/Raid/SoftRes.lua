-- Amisia soft-reserves: a pasted list (softres.it CSV or "Name [item]" lines), shown in item
-- tooltips and on the loot window, and ranked first in roll rounds.
local ADDON, ns = ...
local L = ns.L

local GetItemInfo = C_Item.GetItemInfo

local F, editBox, resultText, dateText, previewText
local previewGen = 0   -- the newest pending preview; older timers do nothing
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
    local sur = s:match("^%S+ (.+)$")
    if not sur then return (s:gsub("%-.*$", "")) end
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
            local class = cleanText(sr.class, 20)
            extra.classes[key] = class and class:match("^%a+$") and class or nil
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
        for i = 2, #all do
            local f = splitCsv(all[i], delim)
            local item = cItem and tonumber((f[cItem] or ""):match("(%d+)"))
            local name = cName and shortName(f[cName])
            if not add(item, name) then bad[#bad + 1] = all[i] end
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
                         plus = extra.plus or {}, hard = extra.hard or {} }
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
-- names and a label ("Raid (25)", "letzter Raid, 02.10."), or {} and nil.
function ns.SoftResRoster()
    if IsInRaid() then
        local set, n = {}, GetNumGroupMembers() or 0
        for i = 1, n do
            local name = ns.FullName(ns.Plain((GetRaidRosterInfo(i))))
            if name then set[name] = true end
        end
        return sortedKeys(set), ("Raid (%d)"):format(n)
    end
    local s = ns.Active and ns.Active()
    if not s then
        for _, o in ipairs(ns.Sessions and ns.Sessions() or {}) do
            if not s or (o.start or 0) > (s.start or 0) then s = o end
        end
    end
    if not s then return {}, nil end
    return sortedKeys(s.members or {}), L["letzter Raid, %s"]:format(ns.FmtDay(s.start or time()))
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

-- The loaded list (or sr, e.g. a preview from ns.ParseSoftRes) against roster (default
-- ns.SoftResRoster()). Pure: no frames, no chat. nil without a list.
function ns.SoftResCheck(sr, roster)
    sr = sr or (AmisiaDB and AmisiaDB.softres)
    if type(sr) ~= "table" then return nil end
    roster = roster or ns.SoftResRoster()
    local out = { roster = #roster, reservers = 0, ok = {}, missing = {}, absent = {}, unclear = {}, over = {}, multi = {} }
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
        else
            local cands = {}
            for _, r in ipairs(roster) do
                if ns.SameName(name, r) then cands[#cands + 1] = r end
            end
            table.sort(cands)
            if #cands == 1 then
                found[cands[1]] = true
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
    -- names not in the raid: suggestions among the raiders without a reservation
    local done = {}
    for _, u in ipairs(out.unclear) do done[u.name] = true end
    for _, name in ipairs(lost) do
        out.absent[#out.absent + 1] = name
        if not done[name] then
            local low, sug = name:lower(), {}
            for _, r in ipairs(out.missing) do
                local d = (#name >= 4 and #r >= 4) and distance(low, r:lower()) or 99
                if d <= 2 or firstName(name) == firstName(r) then
                    sug[#sug + 1] = { r = r, d = d }
                end
            end
            if #sug > 0 then
                table.sort(sug, function(a, b) if a.d ~= b.d then return a.d < b.d end return a.r < b.r end)
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

function ns.ClearSoftRes()
    AmisiaDB.softres = nil
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
local function cappedLines(head, parts, maxLines, sep, suffix)
    suffix = suffix or ""
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
        local more = L["und %d weitere"]:format(#parts - k)
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
    local roster, label = ns.SoftResRoster()
    if not label then return { L["Kein Raid zum Abgleichen."] } end
    local c = ns.SoftResCheck(sr, roster)
    local out = { L["Abgleich mit %s: %d reserviert, %d ohne Reserve, %d nicht im Raid, %d unklar%s."]:format(
        (label:gsub("^letzter ", "letztem ")), #c.ok, #c.missing, #c.absent, #c.unclear,   -- l10n-ok: German case of the label (English has no match)
        #c.over > 0 and L[", %d zu viel"]:format(#c.over) or "") }
    if #c.missing > 0 then out[#out + 1] = L["Ohne Reserve: %s"]:format(table.concat(c.missing, ", ")) end
    if #c.absent > 0 then out[#out + 1] = L["Nicht im Raid: %s"]:format(table.concat(c.absent, ", ")) end
    for _, u in ipairs(c.unclear) do
        out[#out + 1] = L["Unklar: %s (%s?)"]:format(u.name, table.concat(u.suggest, ", "))
    end
    for _, o in ipairs(c.over) do out[#out + 1] = L["Zu viele: %s (%d)"]:format(o.name, o.n) end
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
-- Import window
---------------------------------------------------------------------------
local function plural(n, one, many) return n == 1 and one or many end

-- The preview line for a pasted text: parsed with the remembered fixes and checked against
-- ns.SoftResRoster(); nothing is stored. "" for an empty text.
function ns.SoftResPreviewText(text)
    if not (text or ""):find("%S") then return "" end
    local byItem, _, bad, times, total, _, extra = ns.ParseSoftRes(text)
    if extra.err then return ns.SoftResCodeError(extra.err) end
    local roster, label = ns.SoftResRoster()
    local c = ns.SoftResCheck({ byItem = byItem, times = times }, roster)
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
            if #c.over > 0 then parts[#parts + 1] = L["%d zu viel"]:format(#c.over) end
        else
            parts[#parts + 1] = L["kein Raid zum Abgleichen"]
        end
    elseif label then
        head = L["Vorschau gegen %s: %s"]:format((label:gsub("^letzter ", "letzten ")), head)   -- l10n-ok: German case of the label (English has no match)
        if #c.missing > 0 then parts[#parts + 1] = L["%d ohne Reserve"]:format(#c.missing) end
        if #c.absent > 0 then parts[#parts + 1] = L["%d nicht im Raid"]:format(#c.absent) end
        if #c.unclear > 0 then parts[#parts + 1] = L["%d %s unklar"]:format(#c.unclear, plural(#c.unclear, L["Name##Anzahl"], L["Namen##Anzahl"])) end
        if #c.over > 0 then parts[#parts + 1] = L["%d zu viel"]:format(#c.over) end
    elseif extra.src ~= "code" then
        head = L["Vorschau: %s"]:format(head)
        parts[#parts + 1] = L["kein Raid zum Abgleichen"]
    end
    if #bad > 0 then parts[#parts + 1] = L["%d %s nicht erkannt"]:format(#bad, plural(#bad, L["Zeile"], L["Zeilen"])) end
    if #parts == 0 then return head end
    return head .. " · " .. table.concat(parts, " · ")
end

local function updatePreview()
    if not F or not previewText then return end
    local ok, text = pcall(ns.SoftResPreviewText, editBox:GetText())
    previewText:SetText(ok and text or "")
    if not ok then
        local handler = geterrorhandler and geterrorhandler()
        if handler then handler(text) end
    end
end

-- Recomputes the preview 0.3 s after the last change of the text.
local function schedulePreview()
    previewGen = previewGen + 1
    local gen = previewGen
    C_Timer.After(0.3, function()
        if gen == previewGen then updatePreview() end
    end)
end

local function refresh()
    if not F or not F:IsShown() then return end
    local sr = AmisiaDB.softres
    if sr then
        local today = date("%Y-%m-%d")
        dateText:SetText(sr.date == today
            and L["|cff4fbf7aListe von heute:|r %d Reservierungen"]:format(sr.count or 0)
            or L["|cffe0a344Liste vom %s:|r %d Reservierungen. Für einen neuen Raid neu einfügen."]:format(ns.SoftResShortDate(sr.date), sr.count or 0))
        if editBox:GetText() == "" then editBox:SetText(sr.raw or "") end
    else
        dateText:SetText(L["|cff8f86a3Keine Soft-Reserves.|r softres.it-CSV, Gargul-Code oder Zeilen wie 'Name [Item-Link]' einfügen."])
    end
end

-- The bottom of the import window, from below: buttons (10-32), result, preview, the text box.
local TEXT_H = 26                       -- two lines of GameFontHighlightSmall
local RESULT_Y = 38
local PREVIEW_Y = RESULT_Y + TEXT_H + 4
local BOX_BOTTOM = PREVIEW_Y + TEXT_H + 4

local function build()
    -- a dialog in the client's frame without a portrait, the title in its bar; the side tab of the
    -- main window follows it
    local W = ns.W
    F = W.Window("AmisiaSoftResFrame", 440, 380, { title = L["Soft-Reserves"], strata = "FULLSCREEN_DIALOG",
        onShow = refresh,
        onVisibility = function() if ns.UpdateSideTabs then ns.UpdateSideTabs() end end })
    F:SetPoint("CENTER", 0, 40)

    dateText = F:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dateText:SetPoint("TOPLEFT", 12, -32)
    dateText:SetWidth(410)
    dateText:SetJustifyH("LEFT")

    -- the pasted text: the shared edit area (an inset, the thin bar inside its right edge; a click
    -- anywhere in it focuses the text)
    local boxBg = W.EditArea(F)
    boxBg:SetPoint("TOPLEFT", 12, -50)
    boxBg:SetPoint("BOTTOMRIGHT", -12, BOX_BOTTOM)
    editBox = boxBg.box
    editBox:SetScript("OnTextChanged", schedulePreview)

    -- the preview sits above the result of the last import; each has a fixed room of two lines,
    -- so a long text is cut instead of growing into the other
    previewText = F:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    previewText:SetPoint("BOTTOMLEFT", 12, PREVIEW_Y)
    previewText:SetSize(416, TEXT_H)
    previewText:SetJustifyH("LEFT")
    previewText:SetJustifyV("TOP")
    previewText:SetWordWrap(true)
    previewText:SetMaxLines(2)
    previewText:SetTextColor(0.89, 0.72, 0.34)
    previewText:SetText("")

    resultText = F:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    resultText:SetPoint("BOTTOMLEFT", 12, RESULT_Y)
    resultText:SetSize(416, TEXT_H)
    resultText:SetJustifyH("LEFT")
    resultText:SetJustifyV("TOP")
    resultText:SetWordWrap(true)
    resultText:SetMaxLines(2)

    local apply = W.Button(F, L["Übernehmen"], 110, function()
        local count, bad, err, extra = ns.SetSoftRes(editBox:GetText())
        if err then
            resultText:SetText(err)
        elseif extra and extra.src == "code" then
            resultText:SetText(L["%d Reservierungen übernommen, Hard-Reserves: %d."]:format(count, extra.hardCount))
        else
            resultText:SetText(L["%d Reservierungen übernommen, %d Zeilen nicht erkannt."]:format(count, #bad)
                .. (#bad > 0 and L[" Erste: %s"]:format(bad[1]:sub(1, 40)) or ""))
        end
        refresh()
    end)
    apply:SetPoint("BOTTOMLEFT", 12, 10)

    local clear = W.Button(F, L["Leeren"], 90, function()
        ns.ClearSoftRes()
        editBox:SetText("")
        previewText:SetText("")
        resultText:SetText(L["Liste geleert."])
        refresh()
    end)
    clear:SetPoint("LEFT", apply, "RIGHT", 6, 0)
    F.editBox, F.resultText, F.dateText, F.applyBtn, F.clearBtn, F.previewText, F.box = editBox, resultText, dateText, apply, clear, previewText, boxBg
    ns.SoftResFrame = F
end

function ns.ToggleSoftResFrame()
    if not F then build() end
    if F:IsShown() then F:Hide() else F:Show() end
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
    ns.msg(err or L["%d Reservierungen übernommen, Hard-Reserves: %d."]:format(count, extra.hardCount))
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
