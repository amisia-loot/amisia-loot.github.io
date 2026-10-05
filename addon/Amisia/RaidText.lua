-- Amisia raid text: a summary of one raid as Discord Markdown (date, raid, bosses with their times,
-- attendance, late, bench, loot per boss with winner and MS/OS/SR, bank and disenchant), German,
-- cut into parts Discord accepts. Pure computation: no frames, no chat.
local ADDON, ns = ...

local LIMIT = 1900   -- characters per part; Discord takes 2000
local WEEKDAYS = { "Sonntag", "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag" }

-- Characters of a UTF-8 text (continuation bytes do not count).
local function chars(text)
    local n = 0
    for _ in tostring(text or ""):gmatch("[^\128-\191]") do n = n + 1 end
    return n
end
ns.TextLength = chars

-- The first n characters of a UTF-8 text.
local function cutChars(text, n)
    local count, i = 0, 1
    while i <= #text do
        local b = text:byte(i)
        if b < 0x80 or b >= 0xC0 then
            count = count + 1
            if count > n then return text:sub(1, i - 1) end
        end
        i = i + 1
    end
    return text
end

-- A zero-width space (UTF-8): after an "@" it keeps Discord from reading a mention.
local ZWSP = "\226\128\139"

-- Markdown characters of Discord get a backslash, so a name or an item shows as it is; "<" too
-- and every "@" a zero-width space, so text raiders typed never mentions anyone (@everyone, @here,
-- <@id>, <@&role>, <#channel>).
function ns.DiscordEscape(text)
    local out = tostring(text or ""):gsub("[\\%*_~`|<>#%[%]]", "\\%0")
    return (out:gsub("@", "@" .. ZWSP))
end
local esc = ns.DiscordEscape

local function hm(t) return date("%H:%M", t or 0) end

-- "3:12" from seconds.
local function fightLength(sec)
    sec = math.max(0, math.floor(sec or 0))
    return ("%d:%02d"):format(math.floor(sec / 60), sec % 60)
end
ns.FightLength = fightLength

-- The length of a fight, only when the encounter events gave its start.
local function lengthOf(k)
    if k and k.src == "enc" and k.start and k.t and k.t > k.start then return k.t - k.start end
    return nil
end
ns.KillLength = lengthOf

local function itemName(id)
    local name = ns.ItemName(id)
    if name == ("Item " .. tostring(id)) then
        local known = AmisiaDB and AmisiaDB.itemNames and AmisiaDB.itemNames[id]
        if known and known.n then name = known.n end
    end
    return name
end

-- The bosses of a raid in order: one entry per kill with the wipes of that boss before it, and with
-- withWipes one entry per boss that was only wiped on (at its last wipe).
-- { t, name, kill = k|nil, wipes = n }
function ns.BossRuns(s, withWipes)
    local out, pending = {}, {}
    for _, k in ipairs(ns.Kills(s)) do
        local key = ns.BossKey(k)
        if k.ok then
            local p = pending[key]
            if p then
                pending[key] = nil
            else
                -- a kill without an encounter id (loot window, by hand) takes the wipes of its name
                local low = tostring(k.name or ""):lower()
                for pk, x in pairs(pending) do
                    if tostring(x.name or ""):lower() == low then
                        p = x
                        pending[pk] = nil
                        break
                    end
                end
            end
            out[#out + 1] = { t = k.t, name = k.name or "?", kill = k, wipes = (withWipes and p) and p.n or 0 }
        else
            local p = pending[key] or { n = 0 }
            p.n, p.t, p.name = p.n + 1, k.t, k.name
            pending[key] = p
        end
    end
    if withWipes then
        for _, p in pairs(pending) do out[#out + 1] = { t = p.t, name = p.name or "?", wipes = p.n } end
    end
    table.sort(out, function(a, b)
        if a.t ~= b.t then return a.t < b.t end
        return tostring(a.name) < tostring(b.name)
    end)
    return out
end

local function wipeText(n) return n == 1 and "1 Wipe" or (n .. " Wipes") end
ns.WipeText = wipeText

---------------------------------------------------------------------------
-- The sections
---------------------------------------------------------------------------
-- "2026-10-02" -> weekday, "02.10.2026", "02.10."
local function nightWords(s)
    local y, m, d = tostring(s.date or ""):match("^(%d+)-(%d+)-(%d+)$")
    local t = y and time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12, min = 0, sec = 0 })
    if not t then t = s.start or time() end
    local wd = WEEKDAYS[tonumber(date("%w", t)) + 1] or "?"
    return wd, date("%d.%m.%Y", t), date("%d.%m.", t)
end

local function headSection(s, bosses, wipes)
    local out = {}
    local head = ns.Get("raidlog.discordHead")
    -- the officer's own line stays as typed: a mention or Markdown of their own must work
    if type(head) == "string" and head ~= "" then out[#out + 1] = head end
    local wd, full = nightWords(s)
    out[#out + 1] = ("**%s** · %s, %s · %s bis %s"):format(esc(s.zone or "?"), wd, full, hm(s.firstScan or s.start),
        hm(s.last or s.start))
    local parts = { ("Bosse: %d"):format(bosses) }
    if ns.Get("raidlog.discordWipes") and wipes > 0 then parts[#parts + 1] = ("Wipes: %d"):format(wipes) end
    parts[#parts + 1] = ("Raider: %d"):format(ns.MemberCount(s))
    local late = ns.LateCount(s)
    if late > 0 then parts[#parts + 1] = ("zu spät: %d"):format(late) end
    local bench = #ns.BenchList(s)
    if bench > 0 then parts[#parts + 1] = ("Ersatzbank: %d"):format(bench) end
    out[#out + 1] = table.concat(parts, " · ")
    return out
end

local function bossSection(s)
    local out = {}
    for _, r in ipairs(ns.BossRuns(s, ns.Get("raidlog.discordWipes"))) do
        local extra = {}
        if r.wipes > 0 then extra[#extra + 1] = wipeText(r.wipes) end
        local k = r.kill
        local prefix = ""
        if not k then
            extra[#extra + 1] = "kein Kill"
        else
            local len = lengthOf(k)
            if len then extra[#extra + 1] = "Kampf " .. fightLength(len) end
            if k.src == "loot" then
                prefix = "ca. "
                extra[#extra + 1] = "aus dem Lootfenster"
            end
        end
        out[#out + 1] = ("%s%s %s%s"):format(prefix, hm(r.t), esc(r.name),
            #extra > 0 and (" (" .. table.concat(extra, ", ") .. ")") or "")
    end
    if #out == 0 then return nil end
    table.insert(out, 1, { text = "**Bosse**", heading = true })
    return out
end

local function lootSection(s)
    if not ns.Get("raidlog.discordLoot") then return nil end
    local groups, byKey, bank, de = {}, {}, {}, {}
    local list = {}
    for i, a in ipairs(s.awards or {}) do list[i] = a end
    table.sort(list, function(a, b) return (a.t or 0) < (b.t or 0) end)
    for _, a in ipairs(list) do
        if a.to == "bank" then
            bank[#bank + 1] = esc(itemName(a.item))
        elseif a.to == "de" then
            de[#de + 1] = esc(itemName(a.item))
        else
            local k = ns.KillFor(s, a.src, a.t)
            local key, g
            if k then
                key = k
                g = byKey[key] or { rank = 1, t = k.t, title = ("__%s__ %s%s"):format(esc(k.name or "?"), k.src == "loot" and "ca. " or "", hm(k.t)) }
            elseif type(a.src) == "string" and a.src ~= "" and a.src ~= "?" then
                key = "src:" .. a.src
                g = byKey[key] or { rank = 2, t = 0, name = a.src:lower(), title = ("__%s__"):format(esc(a.src)) }
            else
                key = "?"
                g = byKey[key] or { rank = 3, t = 0, title = "__Ohne Boss__" }
            end
            if not byKey[key] then
                byKey[key] = g
                g.lines = {}
                groups[#groups + 1] = g
            end
            g.lines[#g.lines + 1] = ("- %s: %s%s%s"):format(esc(itemName(a.item)), esc(a.name or "?"),
                (a.kind and a.kind ~= "-") and (" (" .. a.kind .. ")") or "", a.note and (" · " .. esc(a.note)) or "")
        end
    end
    table.sort(groups, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.t ~= b.t then return a.t < b.t end
        return tostring(a.name) < tostring(b.name)
    end)
    local out = {}
    if #groups > 0 or #bank > 0 or #de > 0 then
        out[1] = { text = "**Loot**", heading = true }
        for _, g in ipairs(groups) do
            out[#out + 1] = { text = g.title, heading = true }
            for _, l in ipairs(g.lines) do out[#out + 1] = l end
        end
        if #bank > 0 then out[#out + 1] = { head = "Bank: ", items = bank } end
        if #de > 0 then out[#out + 1] = { head = "Entzaubert: ", items = de } end
        return out
    end
    -- group loot: no hand-outs, what the raiders looted
    local items = {}
    for i, l in ipairs(s.items or {}) do items[i] = l end
    if #items == 0 then return nil end
    table.sort(items, function(a, b) return (a.t or 0) < (b.t or 0) end)
    out[1] = { text = "**Geplündert**", heading = true }
    for _, l in ipairs(items) do
        out[#out + 1] = ("- %s: %s%s"):format(esc(itemName(l.item)), esc(l.name or "?"), (l.count or 1) > 1 and (" x" .. l.count) or "")
    end
    return out
end

local function peopleSection(s)
    local out = {}
    local late = {}
    for name, m in pairs(s.members or {}) do
        if m.late then late[#late + 1] = { name = name, t = m.first or 0 } end
    end
    table.sort(late, function(a, b)
        if a.t ~= b.t then return a.t < b.t end
        return a.name < b.name
    end)
    if #late > 0 then
        local words = {}
        for i, x in ipairs(late) do words[i] = ("%s (%s)"):format(esc(x.name), hm(x.t)) end
        out[#out + 1] = { head = "**Zu spät:** ", items = words }
    end
    local bench = ns.BenchList(s)
    if #bench > 0 then
        local words = {}
        for i, x in ipairs(bench) do
            local extra = {}
            if x.e.note then extra[#extra + 1] = esc(x.e.note) end
            if x.joined then extra[#extra + 1] = "eingewechselt " .. hm(x.joined) end
            words[i] = esc(x.name) .. (#extra > 0 and (" (" .. table.concat(extra, ", ") .. ")") or "")
        end
        out[#out + 1] = { head = "**Ersatzbank:** ", items = words }
    end
    if ns.Get("raidlog.discordNames") then
        local names = {}
        for name in pairs(s.members or {}) do names[#names + 1] = name end
        table.sort(names)
        if #names > 0 then
            for i, n in ipairs(names) do names[i] = esc(n) end
            out[#out + 1] = { head = "**Dabei:** ", items = names }
        end
    end
    return #out > 0 and out or nil
end

---------------------------------------------------------------------------
-- Parts
---------------------------------------------------------------------------
-- A line of a section: a string, a heading { text, heading = true } that stays with what follows
-- it, or a list { head, items } that is wrapped at its items when it does not fit.
local function lineText(l)
    if type(l) == "string" then return l end
    if l.items then return l.head .. table.concat(l.items, ", ") end
    return l.text
end

-- Sections (lists of lines, a blank line between two) into parts of at most LIMIT characters: a
-- section that does not fit the current part any more starts the next one; a list line that does
-- not fit is wrapped at its items (each piece with its head); headings at the end of a part move
-- along into the next, so no part holds headings only. Every part from the second starts with
-- headFor(n). Only a single line longer than a whole part (never seen in practice) is cut.
local function split(sections, headFor)
    local parts, cur, len = {}, {}, 0   -- cur: { { text, heading } }
    local function push(text, heading)
        len = len + (#cur > 0 and 1 or 0) + chars(text)
        cur[#cur + 1] = { text = text, heading = heading }
    end
    local function hasBody()
        for _, c in ipairs(cur) do
            if not c.heading and c.text ~= "" then return true end
        end
        return false
    end
    -- the room for one more line, with the line break and the blank line before it
    local function room(blank)
        return LIMIT - len - (#cur > 0 and 1 or 0) - (blank and 1 or 0)
    end
    -- only called with a body in cur
    local function newPart()
        local carry = {}
        while #cur > 0 and (cur[#cur].heading or cur[#cur].text == "") do table.insert(carry, 1, table.remove(cur)) end
        while carry[1] and carry[1].text == "" do table.remove(carry, 1) end
        local texts = {}
        for i, c in ipairs(cur) do texts[i] = c.text end
        parts[#parts + 1] = table.concat(texts, "\n")
        cur, len = {}, 0
        push(headFor(#parts + 1), true)
        for _, c in ipairs(carry) do push(c.text, c.heading) end
    end
    for _, sec in ipairs(sections) do
        if hasBody() then
            local whole = 1
            for _, l in ipairs(sec) do whole = whole + 1 + chars(lineText(l)) end
            if len + whole > LIMIT then newPart() end
        end
        local blank = #cur > 0 and not (#cur == 1 and #parts > 0)
        for _, l in ipairs(sec) do
            if type(l) == "table" and l.items then
                local idx = 1
                while idx <= #l.items do
                    local text = l.head .. l.items[idx]
                    if chars(text) > room(blank) and hasBody() then
                        newPart()
                        blank = false
                    else
                        if chars(text) > room(blank) then text = cutChars(text, math.max(0, room(blank))) end
                        local j = idx
                        while j < #l.items and chars(text) + 2 + chars(l.items[j + 1]) <= room(blank) do
                            j = j + 1
                            text = text .. ", " .. l.items[j]
                        end
                        if blank then push("") end
                        blank = false
                        push(text)
                        idx = j + 1
                    end
                end
            else
                local text, heading = lineText(l), type(l) == "table" and l.heading or nil
                if chars(text) > room(blank) and hasBody() then
                    newPart()
                    blank = false
                end
                if chars(text) > room(blank) then text = cutChars(text, math.max(0, room(blank))) end
                if blank then push("") end
                blank = false
                push(text, heading)
            end
        end
    end
    if #cur > 0 then
        local texts = {}
        for i, c in ipairs(cur) do texts[i] = c.text end
        parts[#parts + 1] = table.concat(texts, "\n")
    end
    return parts
end

-- The Discord text of raid s: a list of parts of at most 1900 characters, and the characters of the
-- whole text.
function ns.RaidSummary(s)
    if type(s) ~= "table" then return {}, 0 end
    local _, wipes, bosses = ns.KillCount(s)
    local sections = { headSection(s, bosses, wipes) }
    local bossLines, lootLines = bossSection(s), lootSection(s)
    if bossLines then sections[#sections + 1] = bossLines end
    if lootLines then sections[#sections + 1] = lootLines end
    if not bossLines and not lootLines then sections[#sections + 1] = { "Keine Bosse, kein Loot." } end
    local people = peopleSection(s)
    if people then sections[#sections + 1] = people end
    local whole = {}
    for i, sec in ipairs(sections) do
        local texts = {}
        for j, l in ipairs(sec) do texts[j] = lineText(l) end
        whole[i] = table.concat(texts, "\n")
    end
    local total = chars(table.concat(whole, "\n\n"))
    local _, _, short = nightWords(s)
    local zone = esc(s.zone or "?")
    return split(sections, function(n) return ("**%s, %s (Teil %d)**"):format(zone, short, n) end), total
end

---------------------------------------------------------------------------
-- Settings and /amisia discord
---------------------------------------------------------------------------
if ns.RaidLogSettings then
    for _, it in ipairs({
        { key = "raidlog.discordWipes", type = "toggle", label = "Wipes im Discord-Text", default = true, officer = true },
        { key = "raidlog.discordLoot", type = "toggle", label = "Loot im Discord-Text", default = true, officer = true },
        { key = "raidlog.discordNames", type = "toggle", label = "Alle Anwesenden im Discord-Text nennen", default = false, officer = true },
        { key = "raidlog.discordHead", type = "text", label = "Erste Zeile im Discord-Text", default = "", officer = true,
          tip = "Zum Beispiel der Gildenname oder eine Erwähnung.",
          validate = function(v) return ns.CleanNote(v, 80) or "" end },
    }) do
        table.insert(ns.RaidLogSettings.items, it)
    end
    ns.RegisterSettings(ns.RaidLogSettings)
end

ns.RegisterSlash("discord", { officer = true, desc = "Discord-Text des Raids zum Kopieren", run = function()
    if not ns.IsOfficerView() then
        ns.msg("Discord-Text nur in der Offiziersansicht.")
        return
    end
    local s = ns.NewestRaid and ns.NewestRaid()
    if not s then
        ns.msg("Noch kein Raid aufgezeichnet.")
        return
    end
    if ns.ShowRaidLog then
        ns.ShowRaidLog("discord", s.id)
        return
    end
    local parts, total = ns.RaidSummary(s)
    ns.msg(("Discord-Text für %s (%s): %d Zeichen in %d Teil(en)."):format(s.zone or "?", s.date or "?", total, #parts))
end })
