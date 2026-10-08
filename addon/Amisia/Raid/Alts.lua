-- Amisia alts: which character is the alt of which main, pasted in from the website ("Copy for
-- the addon" on the Wishlist tab, or "Alts for the addon" on the Roster tab). Counting per player
-- goes through ns.MainOf and ns.SameMain: the plus-one of an alt is the plus-one of its main.
-- Soft-reserves, guild wishes, the bench and late marks stay per character. Stored in
-- AmisiaDB.alts = { date, at, by, n, list = { { alt = name, main = name } } }.
--
-- The pasted text is untrusted: escape codes and bars are stripped, every name is checked.
local ADDON, ns = ...
local L = ns.L

local HEAD_FAIL = L["Das ist keine Twink-Liste der Amisia-Seite."]
local MAX_LINES = 2000      -- lines read, the head included
local MAX_LINE = 200        -- bytes of one line that are looked at
local NAME_MAX = 48
local OWN_GAME = "forever"
local GAME_NAMES = { forever = "WoW Forever", tbc = "TBC Anniversary" }

local function stripCodes(s)
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")
    s = s:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|", "")
    return s
end

-- A name of the text: "_" is the space; no digits, no control characters, not too long.
local function cleanName(raw)
    local name = ns.FullName((raw:gsub("_", " ")))
    if not name or #name > NAME_MAX or name:find("[%d%c]") then return nil end
    return name
end

---------------------------------------------------------------------------
-- Parser
---------------------------------------------------------------------------

-- Reads the website's text:
--   #AMISIA-ALTS 1 <game> <yyyy-mm-dd>
--   A <alt with _> <main with _>
--   #END
-- Returns { game, date, list = { { alt, main } }, n, skipped } or nil and the reason (in the client's language).
-- Skipped: unknown or broken lines, an alt of itself, an alt named twice (the first line stays),
-- and chains (one level only: an alt that is the main of an earlier line, a main that is an alt).
function ns.ParseAlts(text)
    if type(text) ~= "string" then return nil, HEAD_FAIL end
    local res = { list = {}, n = 0, skipped = 0 }
    local read, head = 0, false
    local rows = {}
    for raw in text:gmatch("[^\r\n]+") do
        local line = stripCodes(raw:sub(1, MAX_LINE)):match("^%s*(.-)%s*$")
        if line ~= "" then
            if not head then
                line = line:gsub("^\239\187\191", "")
                local ver, game, day = line:match("^#AMISIA%-ALTS%s+(%d+)%s+(%S+)%s+(%S+)")
                if ver ~= "1" or not day or not day:match("^%d%d%d%d%-%d%d%-%d%d$") then return nil, HEAD_FAIL end
                game = game:lower()
                if game ~= OWN_GAME then
                    return nil, L["Diese Twink-Liste ist für %s, du bist in %s."]:format(GAME_NAMES[game] or game:sub(1, 24),
                        GAME_NAMES[OWN_GAME])
                end
                res.game, res.date, head, read = game, day, true, 1
            elseif line == "#END" then
                break
            elseif read >= MAX_LINES then
                res.skipped = res.skipped + 1
            else
                read = read + 1
                local a, m = line:match("^A%s+(%S+)%s+(%S+)%s*$")
                a, m = a and cleanName(a), m and cleanName(m)
                if not a or not m or a:lower() == m:lower() then
                    res.skipped = res.skipped + 1
                else
                    rows[#rows + 1] = { alt = a, main = m }
                end
            end
        end
    end
    if not head then return nil, HEAD_FAIL end
    -- line by line: an alt already taken, an alt that is a main of an earlier line, or a main
    -- that is an alt of an earlier line is skipped (the website never writes them)
    local mains, alts = {}, {}
    for _, r in ipairs(rows) do
        local low, mlow = r.alt:lower(), r.main:lower()
        if mains[low] or alts[low] or alts[mlow] then
            res.skipped = res.skipped + 1
        else
            alts[low], mains[mlow] = true, true
            res.list[#res.list + 1] = r
            res.n = res.n + 1
        end
    end
    if res.n == 0 then return nil, L["Die Twink-Liste ist leer."] end
    return res
end

---------------------------------------------------------------------------
-- Storage and lookups
---------------------------------------------------------------------------

local index, indexOf   -- lower alt name -> entry, built from the stored list
-- memos of the lookups, valid for the list indexOf: lower name -> entry (false: no alt), lower
-- main -> its alts. SameName depends on the two names only, so only a new list clears them.
local entryMemo, altsMemo = {}, {}
local function stored()
    local a = AmisiaDB and AmisiaDB.alts
    if type(a) ~= "table" or type(a.list) ~= "table" then return nil end
    return a
end

local function byAlt()
    local a = stored()
    local list = a and a.list or nil
    if indexOf ~= list or not index then
        index, indexOf, entryMemo, altsMemo = {}, list, {}, {}
        for _, e in ipairs(list or {}) do
            if type(e) == "table" and type(e.alt) == "string" and type(e.main) == "string" then index[e.alt:lower()] = e end
        end
    end
    return index
end

-- Stores a pasted list (the old one stays when the text is refused). Returns the parse result or
-- nil and the reason.
function ns.SetAlts(text)
    local res, why = ns.ParseAlts(text)
    if not res then return nil, why end
    if not AmisiaDB then return nil, L["Amisia ist noch nicht geladen."] end
    AmisiaDB.alts = { game = res.game, date = res.date, at = time(), by = ns.UnitFullName("player"), n = res.n, list = res.list }
    ns.Fire("ALTS")
    return res
end

function ns.ClearAlts()
    if AmisiaDB then AmisiaDB.alts = nil end
    ns.Fire("ALTS")
end

-- { date, n, age } or nil without a list.
function ns.AltsInfo()
    local a = stored()
    if not a then return nil end
    return { date = a.date, n = tonumber(a.n) or #a.list, age = ns.SoftResAge and ns.SoftResAge({ date = a.date }) or nil }
end

-- The entry of an alt: by the exact name first, then by ns.SameName (a spelling without surname)
-- when exactly one entry fits.
local function entryOf(name)
    name = ns.FullName(name)
    if not name then return nil end
    local idx = byAlt()
    local low = name:lower()
    local memo = entryMemo[low]
    if memo ~= nil then return memo or nil end
    local hit = idx[low]
    if not hit then
        for _, x in pairs(idx) do
            if ns.SameName(x.alt, name) then
                if hit then hit = nil break end
                hit = x
            end
        end
    end
    entryMemo[low] = hit or false
    return hit
end

-- The main of a character, or the name itself when it is no known alt (nil for no name).
function ns.MainOf(name)
    local e = entryOf(name)
    if e then return e.main end
    return ns.FullName(name)
end

-- Whether name is a known alt: its main, else nil.
function ns.AltMain(name)
    local e = entryOf(name)
    return e and e.main or nil
end

-- The alts of a main, sorted by name.
function ns.AltsOf(main)
    main = ns.FullName(main)
    if not main then return {} end
    local idx = byAlt()
    local low = main:lower()
    local list = altsMemo[low]
    if not list then
        list = {}
        for _, e in pairs(idx) do
            if ns.SameName(e.main, main) then list[#list + 1] = e.alt end
        end
        table.sort(list)
        altsMemo[low] = list
    end
    local out = {}
    for i, alt in ipairs(list) do out[i] = alt end
    return out
end

-- Whether two names belong to one player: the same character, or the same main.
function ns.SameMain(a, b)
    if ns.SameName(a, b) then return true end
    local ma, mb = ns.MainOf(a), ns.MainOf(b)
    return ma ~= nil and mb ~= nil and ns.SameName(ma, mb)
end

---------------------------------------------------------------------------
-- The website's text: wishes, alts and the loot prio (LootPrio.lua) in one paste
---------------------------------------------------------------------------

-- Splits a pasted text into its blocks: { wl = text, alts = text, lc = text, pts = text } (any may be missing).
function ns.SiteBlocks(text)
    local out, cur, buf = {}, nil, nil
    if type(text) ~= "string" then return out end
    for raw in text:gmatch("[^\r\n]+") do
        local line = raw:gsub("^\239\187\191", ""):match("^%s*(.-)%s*$")
        local kind = line:match("^#AMISIA%-WL%s") and "wl" or line:match("^#AMISIA%-ALTS%s") and "alts"
            or line:match("^#AMISIA%-LC%s") and "lc" or line:match("^#AMISIA%-PTS%s") and "pts" or nil
        if kind then
            cur, buf = kind, { line }
        elseif cur then
            buf[#buf + 1] = line
            if line == "#END" then
                if not out[cur] then out[cur] = table.concat(buf, "\n") end
                cur, buf = nil, nil
            end
        end
    end
    -- a block without its end (cut off in the copy) is read as far as it goes
    if cur and not out[cur] then out[cur] = table.concat(buf, "\n") end
    return out
end

-- Imports what the text holds: the guild wishes, the alts, the loot prio, the points, or several. Returns the result
-- line and whether anything was taken. A text with neither block goes to the wishes' parser, so
-- its refusal reads as before.
function ns.ImportSiteText(text)
    local blocks = ns.SiteBlocks(text)
    if not blocks.wl and not blocks.alts and not blocks.lc and not blocks.pts then
        local _, why = ns.SetGuildWishes(text)
        return why, false
    end
    local parts, ok = {}, false
    if blocks.wl then
        local res, why = ns.SetGuildWishes(blocks.wl)
        if res then
            ok = true
            parts[#parts + 1] = L["%d %s übernommen, %d %s nicht erkannt."]:format(res.n, res.n == 1 and L["Wunsch"] or L["Wünsche"],
                res.skipped, res.skipped == 1 and L["Zeile"] or L["Zeilen"])
        else
            parts[#parts + 1] = why
        end
    end
    if blocks.alts then
        local res, why = ns.SetAlts(blocks.alts)
        if res then
            ok = true
            local skipped = res.skipped > 0 and L[", %d übersprungen"]:format(res.skipped) or ""
            parts[#parts + 1] = L["%d %s übernommen%s."]:format(res.n, res.n == 1 and L["Twink"] or L["Twinks"], skipped)
        else
            parts[#parts + 1] = why
        end
    end
    if blocks.lc then
        local res, why = ns.SetLootPrio(blocks.lc)
        if res then
            ok = true
            parts[#parts + 1] = L["%d %s mit Prio übernommen, %d %s nicht erkannt."]:format(res.n, res.n == 1 and L["Item"] or L["Items"],
                res.skipped, res.skipped == 1 and L["Zeile"] or L["Zeilen"])
        else
            parts[#parts + 1] = why
        end
    end
    if blocks.pts and ns.SetPointsSite then
        local res, why = ns.SetPointsSite(blocks.pts)
        if res then
            ok = true
            parts[#parts + 1] = L["%d %s übernommen (%s)."]:format(res.n, res.n == 1 and L["Punktestand"] or L["Punktestände"],
                ns.PointsSystemName(res.sys))
        else
            parts[#parts + 1] = why
        end
    end
    return table.concat(parts, " "), ok
end

ns.RegisterSlash("twinks", { en = "alts", args = L["[Name|löschen]"], desc = L["Twinks und ihre Mains von der Website"],
    run = function(rest)
        local word = type(rest) == "string" and rest:lower():match("^%s*(.-)%s*$") or ""
        if word == "löschen" or word == "loeschen" or word == "clear" or word == "delete" then -- l10n-ok: sub-words
            if not ns.IsOfficerView() then
                ns.msg(L["Die Twink-Liste löschen nur Offiziere."])
                return
            end
            ns.ClearAlts()
            ns.msg(L["Twink-Liste gelöscht."])
            return
        end
        local name = ns.FullName(rest)
        if name then
            local main = ns.AltMain(name)
            if main then
                ns.msg(L["%s ist ein Twink von %s."]:format(name, main))
            else
                local alts = ns.AltsOf(name)
                ns.msg(#alts > 0 and L["Twinks von %s: %s."]:format(name, table.concat(alts, ", "))
                    or L["%s hat keine Twinks in der Liste."]:format(name))
            end
            return
        end
        local info = ns.AltsInfo()
        if not info then
            ns.msg(L["Keine Twink-Liste geladen. Auf der Website: Wishlist, Copy for the addon; im Spiel: /amisia wuensche."])
            return
        end
        ns.msg(L["Twink-Liste vom %s: %d %s."]:format(info.date, info.n, info.n == 1 and L["Twink"] or L["Twinks"]))
    end })
