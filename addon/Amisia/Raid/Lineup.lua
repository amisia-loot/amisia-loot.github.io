-- Amisia lineup (Raid-Aufstellung, D-41): an officer pastes the sign-up list of a raid night (the
-- block #AMISIA-RAID, plain "Name Rolle" lines, or the text of a sign-up bot), Amisia matches every
-- name against the guild roster (then the group and the friend list), guesses missing roles,
-- divides the sign-ups into groups by simple rules, keeps what the officer holds in place, and puts
-- the bench on the evening's bench (ns.BenchAdd). Saved per raid night in AmisiaDB.lineup.
-- Inviting (part C) and sorting the groups in the game (part D) wait for the in-game checks of the
-- spec (docs/specs/2026-10-10-raid-aufstellung.md); nothing here invites, sorts or sends.
-- Parts G and H (D-42): the invite list of a guild event of the game calendar (Raid/Calendar.lua,
-- read only) and the sign-ups raiders send from Amisia (Raid/Signup.lua) join the same night. One
-- row per name with the marks of its sources (L list, K calendar, A Amisia); the status is the
-- player's newest statement (Amisia's click time, the time Amisia saw the calendar status change; a
-- pasted list is older than both; Amisia wins within 2 minutes of the calendar); what the officer
-- did by hand (group, hold, bench, role) stays.
--
-- The pasted text is untrusted: colour codes and bars stripped, each line cut to 200 bytes, at most
-- 2000 lines read and 80 sign-ups taken, names without digits or control characters, 48 at most.
local ADDON, ns = ...
local L = ns.L

local MAX_LINES = 2000      -- lines read
local MAX_LINE = 200        -- bytes of one line that are looked at
local NAME_MAX = 48
local MAX_SIGNUPS = 80      -- sign-ups per night (the absent included)
local MAX_NIGHTS = 8        -- nights kept, the newest
local MAX_OPTIONS = 5       -- names offered for an unclear sign-up
local ALIAS_MAX = 300       -- remembered name fixes (shared with the soft-reserves)
local OWN_GAME = "forever"
local GROUP_SIZE = 5
local SIZES = { [10] = true, [20] = true, [40] = true }
local SAME_CLICK = 120      -- Amisia and the calendar within this many seconds: one click, Amisia counts
local MAX_GONE = 80         -- names removed by the officer, remembered per night
local DAYS_AHEAD = 14       -- sign-ups from Amisia: tonight up to this many days ahead
-- statuses (st, d, ks): A signed up, B confirmed, V tentative, E standby, X declined or absent,
-- I invited, O no answer, G no longer in the calendar; Amisia's own: A, V, X
local CODES = { A = true, B = true, V = true, E = true, X = true, I = true, O = true, G = true }
local OWN = { A = true, V = true, X = true }
-- these are not placed (shown grey at the bottom), unless the officer holds the player
local OUT = { X = true, I = true, O = true, G = true }
local SOURCES = { "L", "K", "A" }

ns.LINEUP_ROLES = { "T", "H", "M", "R" }
ns.LINEUP_CODES = CODES
local IS_ROLE = { T = true, H = true, M = true, R = true }
local CLASSES = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true, SHAMAN = true, MAGE = true,
                  WARLOCK = true, DRUID = true }
-- a role from the class when the list names none (the spec, part A step 4); shown grey with "?"
local GUESS = { WARRIOR = "M", ROGUE = "M", HUNTER = "R", MAGE = "R", WARLOCK = "R", PRIEST = "H", PALADIN = "H",
                SHAMAN = "H", DRUID = "H" }
ns.LINEUP_GUESS = GUESS
ns.LINEUP_CLASSES = CLASSES
-- "DPS" in a list: melee or ranged by the class
local DPS_ROLE = { WARRIOR = "M", ROGUE = "M", PALADIN = "M", SHAMAN = "M", DRUID = "M", HUNTER = "R", MAGE = "R",
                   WARLOCK = "R", PRIEST = "R" }

---------------------------------------------------------------------------
-- Words of a sign-up list (German and English, lower case, umlauts folded by norm)
---------------------------------------------------------------------------
-- the spelling Amisia compares: lower case, umlauts and their two-letter forms as the plain vowel
local function norm(s)
    s = ns.Fold(s)
    s = s:gsub("\195\164", "a"):gsub("\195\182", "o"):gsub("\195\188", "u"):gsub("\195\159", "ss")
    s = s:gsub("ae", "a"):gsub("oe", "o"):gsub("ue", "u")
    return s
end

local WORDS = {}
local function words(kind, value, list)
    for w in list:gmatch("%S+") do WORDS[norm(w)] = { kind = kind, v = value } end
end
-- roles, specs that name a role, and their plurals
words("role", "T", "tank tanks maintank offtank mt ot schutz prot protection")
words("role", "H", "heiler heilerin heal heals healer healers heilung holy heilig resto restoration disc disziplin wiederherstellung") -- l10n-ok: list words the parser reads
words("role", "M", "nahkampf nahkämpfer nahkaempfer melee melees mdps furor fury arms waffen enh enhancement verstärkung vergelter retri retribution feral wildheit") -- l10n-ok: list words the parser reads
words("role", "R", "fernkampf fernkämpfer fernkaempfer ranged range rdps caster casters schatten shadow ele elemental elementar balance gleichgewicht eule boomkin") -- l10n-ok: list words the parser reads
words("dps", true, "dps dd schaden damage")
words("bench", true, "ersatz ersatzbank ersatzspieler bench reserve standby backup")
words("absent", true, "abgemeldet abwesend abmeldung abmeldungen absent declined decline absage absagen abgesagt")
words("maybe", true, "vielleicht tentative maybe unsicher eventuell evtl")
words("late", true, "spät später late")   -- l10n-ok: list words the parser reads
-- classes: a class word right after a first name may be its surname ("Vulo Pala"); see parseWords
words("class", "WARRIOR", "krieger warrior warriors warri")
words("class", "PALADIN", "paladin paladine paladins pala pally")
words("class", "HUNTER", "jäger jaeger hunter hunters hunt") -- l10n-ok: list words the parser reads
words("class", "ROGUE", "schurke schurken rogue rogues")
words("class", "PRIEST", "priester priest priests")
words("class", "SHAMAN", "schamane schamanen shaman shamans schami")
words("class", "MAGE", "magier mage mages")
words("class", "WARLOCK", "hexenmeister warlock warlocks hexer")
words("class", "DRUID", "druide druiden druid druids dudu")
-- a line whose first word is one of these is a heading or a note of the bot, never a name
local STOP = {}
for w in ("datum date zeit time uhrzeit uhr leader leitung raidleiter raidleader raidlead raid total gesamt anmeldungen "
    .. "anmeldung signups signup sign teilnehmer info notiz note start beginn treffpunkt ort instanz event termin tag day "
    .. "erstellt created und and"):gmatch("%S+") do STOP[norm(w)] = true end -- l10n-ok: list words the parser reads

local function stripCodes(s)
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")
    s = s:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|", " ")
    return s
end

-- A name of the block: "_" is the space; no digits, no control characters, not too long.
local function cleanName(raw)
    local name = ns.FullName((tostring(raw or ""):gsub("_", " ")))
    if not name or #name > NAME_MAX or name:find("[%d%c|]") then return nil end
    return name
end

-- A word of a name: letters (the bytes of umlauts and accents too), a dash or an apostrophe inside.
local function nameWord(w)
    return #w <= NAME_MAX and w:find("^[%a\195-\197][%a\128-\197%-']*$") ~= nil and not w:find("%-%-")
end

local function keyword(w) return WORDS[norm(w)] end

-- What a heading or a keyword sets on a section or an entry.
local function applyWord(e, kw)
    if kw.kind == "role" then e.r = e.r or kw.v
    elseif kw.kind == "class" then e.c = e.c or kw.v
    elseif kw.kind == "dps" then e.d = true
    elseif kw.kind == "bench" then e.b = true
    elseif kw.kind == "absent" then e.a = true
    elseif kw.kind == "maybe" then e.m = true
    end
end

-- One line of text as a list of words: the bot's decorations gone (emoji, markdown, numbering,
-- times, mentions), parentheses kept only when they hold keywords ("Vulo (Tank)").
local function lineWords(s)
    s = s:gsub("%b()", function(x)
        local inner, all = x:sub(2, -2), true
        local n = 0
        for w in inner:gmatch("[^%s,;/]+") do
            n = n + 1
            if not keyword(w) then all = false end
        end
        return (all and n > 0) and (" " .. inner .. " ") or " "
    end)
    s = s:gsub("%b[]", " "):gsub("%b{}", " ")
    -- a separator ends a name ("Kim - Schurke", "Bob, Nahkampf"): it stays as the word ","
    s = s:gsub("[%(%)%[%]{}\"<>@]", " "):gsub("[,;/+=:!?]", " , "):gsub("%s%-+%s", " , ")
    local out = {}
    for w in s:gmatch("%S+") do
        if w == "," then
            if #out > 0 and out[#out] ~= "," then out[#out + 1] = w end
        else
            w = w:gsub("^[%-%.'´`]+", ""):gsub("[%-%.'´`]+$", "")
            if w ~= "" and not w:find("%d") then out[#out + 1] = w end
        end
    end
    if out[#out] == "," then out[#out] = nil end
    return out
end

-- Text decorations a sign-up bot or Discord adds, away; emoji codes become their word.
local function cleanLine(raw)
    local s = stripCodes(raw:sub(1, MAX_LINE))
    s = s:gsub("<t:%-?%d+:?%a?>", " ")              -- timestamps
    s = s:gsub("<a?:([%w_]+):%d+>", " %1 ")         -- custom emoji <:Warrior:123>
    s = s:gsub("<[@#][!&]?%d+>", " ")               -- mentions
    s = s:gsub(":([%a_]+):", " %1 ")                -- :Warrior:
    s = s:gsub("[\240-\244][\128-\191][\128-\191][\128-\191]", " ")   -- emoji
    s = s:gsub("[\226\239][\128-\191][\128-\191]", " ")               -- symbols, dashes, bullets, variation marks
    s = s:gsub("\194[\128-\191]", " ")                                -- Latin-1 punctuation, the no-break space
    s = s:gsub("[%*_~`>#]", " "):gsub("%c", " ")
    return s
end

-- The words of one sign-up: leading keywords (an emoji class), then the name (one or two words),
-- then keywords. A class word as the second word is kept twice: as the surname (n) and as the
-- class of the first name alone (n1, c1); the match decides. nil when it is no sign-up.
local function parseWords(ws)
    local e = {}
    local i = 1
    while ws[i] and (ws[i] == "," or keyword(ws[i])) do
        if ws[i] ~= "," then applyWord(e, keyword(ws[i])) end
        i = i + 1
    end
    local first = ws[i]
    if not first or STOP[norm(first)] or not nameWord(first) then return nil end
    local nameWords, extra = { first }, 0
    i = i + 1
    local second = ws[i]
    if second then
        local kw = keyword(second)
        if not kw and nameWord(second) then
            nameWords[2] = second
            i = i + 1
        elseif kw and kw.kind == "class" and nameWord(second) then
            e.n1, e.c1 = first, kw.v
            nameWords[2] = second
            i = i + 1
        end
    end
    for k = i, #ws do
        local kw = ws[k] ~= "," and keyword(ws[k])
        if kw then applyWord(e, kw) elseif ws[k] ~= "," then extra = extra + 1 end
    end
    -- three or more words that are no keywords: a sentence or a heading, not a sign-up
    if #nameWords + extra >= 3 then return nil end
    local name = table.concat(nameWords, " ")
    if #name > NAME_MAX then return nil end
    e.n = name
    if not e.n1 then e.c1 = nil end
    return e
end

-- The section a heading opens: { r, c, d, b, a, m }; nil when the words are no heading.
local function headingOf(ws)
    if #ws == 0 then return nil end
    local sec, any = {}, false
    for _, w in ipairs(ws) do
        if w ~= "," then
            local kw = keyword(w)
            if not kw then return nil end
            if kw.kind ~= "late" then any = true end
            applyWord(sec, kw)
        end
    end
    return any and sec or nil
end

local function blankEntry(e, sec)
    -- the section's defaults where the line says nothing
    if sec then
        e.r = e.r or sec.r
        e.c = e.c or sec.c
        e.d = e.d or sec.d
        e.b = e.b or sec.b
        e.a = e.a or sec.a
        e.m = e.m or sec.m
    end
    if e.d and not e.r and e.c then e.r = DPS_ROLE[e.c] end
    return e
end

-- Reads the block of the website or one written by hand:
--   #AMISIA-RAID 1 forever <yyyy-mm-dd> [<title ...>]
--   S <name with _> <T/H/M/R/-> [<class token or ->] [<B bench / ? maybe / ->]
--   #END
local function parseBlock(text)
    local res = { list = {}, skipped = 0, block = true }
    local head, read = false, 0
    for raw in text:gmatch("[^\r\n]+") do
        local line = stripCodes(raw:sub(1, MAX_LINE)):gsub("^\239\187\191", ""):match("^%s*(.-)%s*$")
        if line ~= "" then
            if not head then
                local ver, game, day, title = line:match("^#AMISIA%-RAID%s+(%d+)%s+(%S+)%s+(%S+)%s*(.-)$")
                if ver then
                    if ver ~= "1" or not day:match("^%d%d%d%d%-%d%d%-%d%d$") then return nil, L["Das ist kein Aufstellungsblock (#AMISIA-RAID 1)."] end
                    if game:lower() ~= OWN_GAME then
                        return nil, L["Dieser Aufstellungsblock ist für %s, du bist in WoW Forever."]:format(game:sub(1, 24))
                    end
                    res.date, res.title, head = day, ns.CleanNote(title, 40), true
                end
            elseif line == "#END" then
                break
            elseif read >= MAX_LINES then
                res.skipped = res.skipped + 1
            else
                read = read + 1
                local name, role, class, flag = line:match("^S%s+(%S+)%s+(%S+)%s*(%S*)%s*(%S*)%s*$")
                name = name and cleanName(name)
                if not name or not (IS_ROLE[role] or role == "-") or (class ~= "" and class ~= "-" and not CLASSES[class])
                    or (flag ~= "" and flag ~= "-" and flag ~= "B" and flag ~= "?") then
                    res.skipped = res.skipped + 1
                else
                    res.list[#res.list + 1] = { n = name, r = IS_ROLE[role] and role or nil,
                        c = CLASSES[class] and class or nil, b = flag == "B" or nil, m = flag == "?" or nil }
                end
            end
        end
    end
    if not head then return nil, L["Das ist kein Aufstellungsblock (#AMISIA-RAID 1)."] end
    return res
end

-- Reads a pasted list: the block, else plain lines and a bot's text. Returns { list = { entry },
-- date (block), title (block), skipped, over (sign-ups past 80), block } or nil and the reason.
-- An entry: { n = name, r, c, b, a (absent), m (maybe), n1/c1 (the name without a surname that is a
-- class word) }. A name written twice counts once (the first line).
function ns.ParseLineup(text)
    if type(text) ~= "string" then return nil, L["Kein Name erkannt."] end
    local res, why
    if text:find("#AMISIA%-RAID") then
        local blocks = ns.SiteBlocks and ns.SiteBlocks(text) or {}
        res, why = parseBlock(blocks.raid or text)
        if not res then return nil, why end
    else
        res = { list = {}, skipped = 0 }
        local sec, read = nil, 0
        local function take(piece)
            local ws = lineWords(piece)
            if #ws == 0 then return end
            local e = parseWords(ws)
            if e then res.list[#res.list + 1] = blankEntry(e, sec) else res.skipped = res.skipped + 1 end
        end
        for raw in text:gmatch("[^\r\n]+") do
            read = read + 1
            if read > MAX_LINES then
                res.skipped = res.skipped + 1
            else
                local s = cleanLine(raw)
                local ws = lineWords(s)
                local h = headingOf(ws)
                if h then
                    sec = h
                elseif #ws > 0 then
                    -- "Tanks: Vulo, Anna": a heading with its names on one line
                    local left, rest = s:match("^%s*([^:]-)%s*:%s*(.-)%s*$")
                    local lh = left and headingOf(lineWords(left))
                    if lh then
                        sec = lh
                        for piece in rest:gmatch("[^,;]+") do take(piece) end
                    elseif left and left ~= "" and not left:find("%s") and STOP[norm(left)] then
                        res.skipped = res.skipped + 1
                    else
                        take(s)
                    end
                end
            end
        end
    end
    -- doubles: the first line counts; at most 80 sign-ups
    local out, seen = {}, {}
    res.over = 0
    for _, e in ipairs(res.list) do
        local low = e.n:lower()
        if not seen[low] then
            seen[low] = true
            if #out >= MAX_SIGNUPS then
                res.over = res.over + 1
            else
                e.d = nil
                out[#out + 1] = e
            end
        end
    end
    res.list = out
    if #out == 0 then return nil, L["Kein Name erkannt."] end
    return res
end

---------------------------------------------------------------------------
-- Matching against the guild, the group and the friend list
---------------------------------------------------------------------------
-- Whether a and b (both normed) differ in one letter: one missing, one too many, one other, or two
-- neighbours swapped.
local function oneOff(a, b)
    local la, lb = #a, #b
    if a == b or math.abs(la - lb) > 1 then return false end
    if la == lb then
        local diff = {}
        for i = 1, la do
            if a:byte(i) ~= b:byte(i) then
                diff[#diff + 1] = i
                if #diff > 2 then return false end
            end
        end
        if #diff == 1 then return true end
        local i, j = diff[1], diff[2]
        return j == i + 1 and a:byte(i) == b:byte(j) and a:byte(j) == b:byte(i)
    end
    if la < lb then a, b, lb = b, a, la end
    -- a is one longer: some byte of a left out gives b
    local i = 1
    while i <= lb and a:byte(i) == b:byte(i) do i = i + 1 end
    return a:sub(i + 1) == b:sub(i)
end

local function firstOf(name) return name:match("^(%S+)") or name end

-- Everyone Amisia can tell apart: { people = { { name, class, online, level, guild } }, full = {},
-- first = {}, guild = bool (the guild roster was readable) }.
local function knownPeople()
    local k = { people = {}, full = {}, first = {}, lower = {}, guild = false }
    local function add(name, class, online, level, guild)
        name = ns.FullName(name)
        if not name then return end
        local low = name:lower()
        local p = k.lower[low]
        if p then
            if online then p.online = true end
            if (not p.class or p.class == "") and class and class ~= "" then p.class = class end
            return
        end
        p = { name = name, class = (class ~= "" and class) or nil, online = online and true or false, level = level, guild = guild }
        k.lower[low] = p
        k.people[#k.people + 1] = p
        local key, fk = norm(name), norm(firstOf(name))
        k.full[key] = k.full[key] or {}
        table.insert(k.full[key], p)
        k.first[fk] = k.first[fk] or {}
        table.insert(k.first[fk], p)
    end
    local g = ns.GuildRoster and ns.GuildRoster()
    if g then
        k.guild = true
        for _, m in ipairs(g) do add(m.name, m.class, m.online, m.level, true) end
    end
    -- oneself: online, also without a guild (the bench check of a single officer)
    local _, myClass = UnitClass("player")
    add(ns.UnitFullName("player"), ns.Plain(myClass) or "", true, tonumber(ns.Plain(UnitLevel("player"))), not k.guild)
    for _, r in ipairs(ns.BenchGroupRows and (ns.BenchGroupRows()) or {}) do add(r.name, r.class, r.online, nil, false) end
    for _, f in ipairs(ns.BenchFriendRows and ns.BenchFriendRows() or {}) do add(f.name, f.class, f.online, nil, false) end
    return k
end
ns.LineupKnown = knownPeople

local function names(list)
    local out = {}
    for i, p in ipairs(list) do
        if i > MAX_OPTIONS then break end
        out[#out + 1] = p.name
    end
    table.sort(out)
    return out
end

-- The match of one list name: status (nil found, "l" likely, "a" ambiguous, "u" unknown, "g"
-- guest), the person (found, likely), the options (ambiguous).
local function matchName(k, name, oneWordOnly)
    local key = norm(name)
    local hit = k.full[key]
    if hit and #hit == 1 then
        local p = hit[1]
        return (k.guild and not p.guild) and "g" or nil, p
    elseif hit and #hit > 1 then
        return "a", nil, names(hit)
    end
    if not name:find(" ", 1, true) or oneWordOnly then
        local firsts = k.first[norm(firstOf(name))]
        if firsts and #firsts == 1 then return "l", firsts[1] end
        if firsts and #firsts > 1 then return "a", nil, names(firsts) end
    end
    -- one letter off: the whole name, or the first name for a list name without surname
    local found = {}
    local single = not name:find(" ", 1, true)
    for _, p in ipairs(k.people) do
        local other = single and norm(firstOf(p.name)) or norm(p.name)
        if oneOff(key, other) then found[#found + 1] = p end
    end
    if #found == 1 then return "l", found[1] end
    if #found > 1 then return "a", nil, names(found) end
    return "u"
end

-- Matches entry e in place: n (the name Amisia takes), s (the list's spelling when another), x, o, c.
local function matchEntry(k, e)
    local listName = e.s or e.n
    local fix = ns.SoftResAlias and ns.SoftResAlias(listName)
    local x, p, opts = matchName(k, fix or listName)
    -- "Vulo Pala": not a known name, but "Vulo" alone with the class Paladin may be
    if x == "u" and e.n1 then
        local x1, p1, o1 = matchName(k, e.n1, true)
        if x1 ~= "u" then
            x, p, opts = x1, p1, o1
            e.c = e.c or e.c1
        end
    end
    e.n1, e.c1 = nil, nil
    e.x, e.o = x, nil
    if p then
        -- the list's spelling is kept only when it is more than another case
        if p.name:lower() ~= listName:lower() then e.n, e.s = p.name, listName else e.n, e.s = p.name, nil end
        if p.class then e.c = p.class end
    else
        e.n, e.s = fix or listName, fix and listName or nil
        if x == "a" then e.o = opts end
    end
    -- a fix remembered earlier counts as confirmed
    if fix and x == "l" then e.x = nil end
end

---------------------------------------------------------------------------
-- Storage: AmisiaDB.lineup = { v = 1, nights = { [yyyy-mm-dd] = { at, by, title, size, list } } }
---------------------------------------------------------------------------
local function db(create)
    local DB = AmisiaDB
    if type(DB) ~= "table" then return nil end
    if type(DB.lineup) ~= "table" then
        if not create then return nil end
        DB.lineup = { v = 1, nights = {} }
    end
    if type(DB.lineup.nights) ~= "table" then DB.lineup.nights = {} end
    return DB.lineup
end

local function tonight() return ns.NightOf(time()) end
ns.LineupTonight = tonight

-- The nights, newest first.
function ns.LineupNights()
    local d = db(false)
    local out = {}
    for night in pairs(d and d.nights or {}) do out[#out + 1] = night end
    table.sort(out, function(a, b) return a > b end)
    return out
end

local function trim(d)
    local all = ns.LineupNights()
    for i = MAX_NIGHTS + 1, #all do d.nights[all[i]] = nil end
end

function ns.LineupNight(night, create)
    night = night or tonight()
    local d = db(create)
    if not d then return nil end
    local n = d.nights[night]
    if not n and create then
        n = { at = time(), by = ns.UnitFullName("player"), size = ns.Get("lineup.size") or 40, list = {} }
        d.nights[night] = n
        trim(d)
    end
    return n
end

---------------------------------------------------------------------------
-- Sources and the valid statement (parts G and H)
---------------------------------------------------------------------------
-- The source marks of an entry in the order L, K, A; an entry without marks came from a list.
local function sourcesOf(e) return e.f or "L" end
local function hasSrc(e, src) return sourcesOf(e):find(src, 1, true) ~= nil end
local function withSrc(f, src, on)
    local out = ""
    for _, x in ipairs(SOURCES) do
        local has = (x == src and on) or (x ~= src and (f or ""):find(x, 1, true) ~= nil)
        if has then out = out .. x end
    end
    return out
end
ns.LineupHasSource = hasSrc

-- The player's valid statement: status, time (nil: none known), source. The pasted list counts as
-- older than every statement of the calendar or Amisia; a calendar status seen first (kt 0, no
-- change seen) is older than any Amisia click; within SAME_CLICK of each other Amisia counts.
local function statementOf(e)
    local st, t, src
    if e.d then st, t, src = e.d, -1, "L" end
    if e.ks then
        local kt = e.kt or 0
        if not src or kt > t then st, t, src = e.ks, kt, "K" end
    end
    if e.as then
        local ag = e.ag or 0
        if not src or ag > t or (src == "K" and math.abs(ag - t) < SAME_CLICK) then st, t, src = e.as, ag, "A" end
    end
    return st, t, src
end

-- Applies the valid statement to e: st and t, maybe (V), not placed (X, I, O, G: out of the group,
-- unless held), standby (E: on the bench when not in a group). notify: a placed player who signs
-- off gets the officer one chat line.
local function settle(e, notify)
    local st, t = statementOf(e)
    if not st then return end
    local was = e.st
    e.st, e.t = st, (t and t > 0) and t or nil
    e.m = st == "V" or nil
    if OUT[st] then
        local group = e.g
        if notify and st == "X" and was ~= "X" and group then
            if e.k then
                ns.msg(L["Aufstellung: %s hat sich abgemeldet (Gruppe %d, festgehalten)."]:format(e.n, group))
            else
                ns.msg(L["Aufstellung: %s hat sich abgemeldet (war Gruppe %d)."]:format(e.n, group))
            end
        end
        if e.k then
            e.a = nil
        else
            e.a = true
            e.g, e.b, e.v = nil, nil, nil
        end
    else
        e.a = nil
        if st == "E" and not e.g then e.b = true end
    end
end

local function posNum(v)
    v = tonumber(v)
    if v and v > 0 and v < 4294967296 then return math.floor(v) end
    return nil
end

local function cleanEntry(e)
    if type(e) ~= "table" then return nil end
    local n = type(e.n) == "string" and cleanName(e.n)
    if not n then return nil end
    local out = { n = n }
    if IS_ROLE[e.r] then out.r = e.r end
    if CLASSES[e.c] then out.c = e.c end
    local g = tonumber(e.g)
    if g and g >= 1 and g <= 8 and g % 1 == 0 then out.g = g end
    for _, f in ipairs({ "b", "k", "q", "m", "a", "v" }) do
        if e[f] == true then out[f] = true end
    end
    if type(e.s) == "string" then out.s = cleanName(e.s) end
    if e.x == "l" or e.x == "a" or e.x == "u" or e.x == "g" then out.x = e.x end
    if out.x == "a" and type(e.o) == "table" then
        local o = {}
        for _, v in ipairs(e.o) do
            local c = type(v) == "string" and cleanName(v)
            if c and #o < MAX_OPTIONS then o[#o + 1] = c end
        end
        if #o > 0 then out.o = o end
    end
    -- the sources and statements of parts G and H
    if type(e.f) == "string" then
        local f = withSrc(e.f, "", false)
        if f ~= "" then out.f = f end
    end
    if CODES[e.st] then out.st, out.t = e.st, posNum(e.t) end
    if type(e.w) == "string" then out.w = ns.CleanNote(stripCodes(e.w), 40) end
    if e.h == true and out.r then out.h = true end
    if CODES[e.d] then out.d = e.d end
    if CODES[e.ks] then out.ks, out.kt = e.ks, posNum(e.kt) or 0 end
    if OWN[e.as] then out.as, out.ag, out.au = e.as, posNum(e.ag) or 0, posNum(e.au) end
    if IS_ROLE[e.ar] then out.ar = e.ar end
    if IS_ROLE[e.lr] then out.lr = e.lr end
    -- placed and benched exclude each other; the absent are neither
    if out.a then out.g, out.b, out.v, out.k = nil, nil, nil, nil end
    if out.b or out.v then out.g = nil end
    return out
end

-- The calendar event of a night: { id (digits), at (epoch), title (40), read (epoch), lost }.
local function cleanCal(c)
    if type(c) ~= "table" or not posNum(c.at) then return nil end
    local id = type(c.id) == "string" and #c.id <= 20 and c.id:match("^%d+$") and c.id or nil
    return { id = id, at = posNum(c.at), title = ns.CleanNote(stripCodes(type(c.title) == "string" and c.title or ""), 40),
             read = posNum(c.read), lost = c.lost == true or nil }
end

-- The names the officer removed: { [lower name] = { t = when, k = the calendar status then, u = the
-- sender's clock time of the last Amisia click then } }.
local function cleanGone(g)
    if type(g) ~= "table" then return nil end
    local list = {}
    for low, v in pairs(g) do
        if type(low) == "string" and #low <= NAME_MAX and type(v) == "table" and posNum(v.t) then
            list[#list + 1] = { low = low, t = posNum(v.t), k = CODES[v.k] and v.k or nil, u = posNum(v.u) }
        end
    end
    table.sort(list, function(a, b) return a.t > b.t end)
    local out = {}
    for i = 1, math.min(#list, MAX_GONE) do out[list[i].low] = { t = list[i].t, k = list[i].k, u = list[i].u } end
    return next(out) and out or nil
end

-- Core, ADDON_LOADED: every field checked, 8 nights (the newest), 80 names per night.
function ns.LineupLoaded(root)
    if type(root) ~= "table" or root.lineup == nil then return end
    local d = root.lineup
    if type(d) ~= "table" or type(d.nights) ~= "table" then
        root.lineup = nil
        return
    end
    local nights = {}
    for night, n in pairs(d.nights) do
        if type(night) == "string" and night:match("^%d%d%d%d%-%d%d%-%d%d$") and type(n) == "table" and type(n.list) == "table" then
            local list, seen = {}, {}
            for _, e in ipairs(n.list) do
                local c = cleanEntry(e)
                if c and not seen[c.n:lower()] and #list < MAX_SIGNUPS then
                    seen[c.n:lower()] = true
                    list[#list + 1] = c
                end
            end
            local size = tonumber(n.size)
            nights[night] = { at = tonumber(n.at) or 0, by = type(n.by) == "string" and cleanName(n.by) or nil,
                              title = ns.CleanNote(n.title, 40), size = SIZES[size] and size or 40, list = list,
                              cal = cleanCal(n.cal), gone = cleanGone(n.gone) }
        end
    end
    root.lineup = { v = 1, nights = nights }
    local all = {}
    for night in pairs(nights) do all[#all + 1] = night end
    table.sort(all, function(a, b) return a > b end)
    for i = MAX_NIGHTS + 1, #all do nights[all[i]] = nil end
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name == ADDON and AmisiaDB then ns.LineupLoaded(AmisiaDB) end
end)

-- every edit is saved at once; the page refreshes on LINEUP
local function changed()
    ns.Fire("LINEUP")
end

-- The role this player had in the newest other night where the list or an officer gave it.
local function lastRole(name, except)
    local d = db(false)
    if not d then return nil end
    local low = name:lower()
    for _, night in ipairs(ns.LineupNights()) do
        local n = d.nights[night]
        if night ~= except then
            for _, e in ipairs(n and n.list or {}) do
                if e.n:lower() == low and e.r and not e.q then return e.r end
            end
        end
    end
    return nil
end

-- The role (part H, rule 5): set by the officer, else the Amisia sign-up's, else the list's, else
-- the last lineup's, else from the class (guessed, "?"). The calendar names none.
local function settleRole(e, except)
    if e.h and e.r then e.q = nil return end
    e.h = nil
    if e.ar then e.r, e.q = e.ar, nil return end
    if e.lr then e.r, e.q = e.lr, nil return end
    if e.r and not e.q then return end
    e.r, e.q = nil, nil
    local r = lastRole(e.n, except)
    if r then
        e.r, e.q = r, nil
    elseif e.c and GUESS[e.c] then
        e.r, e.q = GUESS[e.c], true
    end
end

-- The words of the summary line for the chat.
local function summary(list, over, guildOk)
    local c = { found = 0, l = 0, a = 0, u = 0, g = 0, absent = 0 }
    for _, e in ipairs(list) do
        if e.a then
            c.absent = c.absent + 1
        else
            local key = e.x or "found"
            c[key] = c[key] + 1
        end
    end
    -- the absent are matched too (shown grey), but not counted as sign-ups
    local parts = { L["Aufstellung: %d Anmeldungen, %d gefunden"]:format(#list - c.absent, c.found) }
    if c.l > 0 then parts[#parts + 1] = L["%d vermutlich"]:format(c.l) end
    if c.a > 0 then parts[#parts + 1] = L["%d nicht eindeutig"]:format(c.a) end
    if c.u > 0 then parts[#parts + 1] = L["%d unbekannt"]:format(c.u) end
    if c.g > 0 then parts[#parts + 1] = L["%d Gäste"]:format(c.g) end
    if c.absent > 0 then parts[#parts + 1] = L["%d abgemeldet"]:format(c.absent) end
    local text = table.concat(parts, ", ") .. "."
    if over > 0 then text = text .. " " .. L["%d weitere übersprungen (höchstens %d)."]:format(over, MAX_SIGNUPS) end
    if not guildOk then text = text .. " " .. L["Gildenliste noch nicht geladen, gleich nochmal."] end
    return text, c
end

-- Takes a pasted list into a night (the block's date, else night, else tonight): parse, match,
-- roles. A night that had a list keeps the groups, holds and the bench of the names that stay.
-- Returns the night key and the chat line, or nil and the reason (nothing is changed then).
function ns.SetLineupText(text, night)
    local res, why = ns.ParseLineup(text)
    if not res then return nil, why end
    if not AmisiaDB then return nil, L["Amisia ist noch nicht geladen."] end
    if ns.RequestGuildRoster then ns.RequestGuildRoster() end
    local k = knownPeople()
    night = res.date or night or tonight()
    local old = ns.LineupNight(night, false)
    local before = {}
    for _, e in ipairs(old and old.list or {}) do before[e.n:lower()] = e end
    local list, kept = {}, {}
    for _, e in ipairs(res.list) do
        matchEntry(k, e)
        local low = e.n:lower()
        -- the list's statement: absent, maybe or signed up; its role
        e.f, e.lr = "L", e.r
        e.d = e.a and "X" or (e.m and "V") or "A"
        local was = before[low]
        if was then
            kept[low] = true
            -- what the calendar and Amisia said, the note and the officer's role stay
            for _, fld in ipairs({ "ks", "kt", "as", "ag", "au", "ar", "w", "h" }) do e[fld] = was[fld] end
            if was.h then e.r = was.r end
            e.f = withSrc(sourcesOf(was), "L", true)
            if not e.b then e.g, e.k, e.v = was.g, was.k, was.v end
            if not e.r and was.r and not was.q then e.r = was.r end
            if was.b and not e.b and not e.g then e.b = was.b end
        end
        settle(e)
        settleRole(e, night)
        if e.a then e.g, e.b, e.v, e.k = nil, nil, nil, nil end
        list[#list + 1] = cleanEntry(e)
    end
    local pasted = #list
    -- rows of the calendar or Amisia the new list does not name stay, without the list's mark
    for _, was in ipairs(old and old.list or {}) do
        local low = was.n:lower()
        if not kept[low] and (hasSrc(was, "K") or hasSrc(was, "A")) and #list < MAX_SIGNUPS then
            was.f, was.d, was.lr = withSrc(sourcesOf(was), "L", false), nil, nil
            settle(was)
            settleRole(was, night)
            list[#list + 1] = cleanEntry(was)
        end
    end
    local n = ns.LineupNight(night, true)
    n.list, n.at, n.by = list, time(), ns.UnitFullName("player")
    if res.title then n.title = res.title end
    local line = summary({ unpack(list, 1, pasted) }, res.over or 0, k.guild)
    changed()
    return night, line
end

-- The block of the site in the shared paste (ns.ImportSiteText): the officers only.
function ns.LineupImport(blockText)
    if not ns.LineupAllowed() then return nil, L["Die Aufstellung ist nur für Offiziere."] end
    return ns.SetLineupText(blockText)
end

-- Rematches the names that are not found yet (the guild roster came, a fix was remembered).
function ns.LineupRematch(night)
    local n = ns.LineupNight(night, false)
    if not n then return nil end
    if ns.RequestGuildRoster then ns.RequestGuildRoster() end
    local k = knownPeople()
    for i, e in ipairs(n.list) do
        if e.x and e.x ~= "l" then
            local copy = { n = e.n, s = e.s, c = e.c }
            matchEntry(k, copy)
            e.n, e.s, e.x, e.o = copy.n, copy.s, copy.x, copy.o
            if copy.c then e.c = copy.c end
            if e.q then e.r = nil end
            settleRole(e, night)
            n.list[i] = cleanEntry(e)
        end
    end
    local line = summary(n.list, 0, k.guild)
    changed()
    return line
end

---------------------------------------------------------------------------
-- Who may: officer view and officer rank by the guild roster (rank flag 22, D-18)
---------------------------------------------------------------------------
function ns.LineupAllowed()
    return ns.IsOfficerView() and ns.SelfIsOfficer ~= nil and ns.SelfIsOfficer(true) or false
end

---------------------------------------------------------------------------
-- What the page shows of an entry (not saved): class, level, online, alt online, placeable
---------------------------------------------------------------------------
-- { [lower name] = { class, level, online, guild } } of the guild, the group and friends.
function ns.LineupPeople()
    local k = knownPeople()
    return k.lower, k.guild
end

-- Whether an entry can go into a group: not absent, a guest (not in the guild) only with
-- lineup.guests. Unclear and unknown names are placed (the planner works without a guild roster);
-- the page shows their state in colour until the officer clears them up.
function ns.LineupPlaceable(e)
    if e.a then return false end
    if e.x == "g" then return ns.Get("lineup.guests") == true end
    return true
end

-- The one alt of this player that is online while e is offline (alt list of the site), else nil.
function ns.LineupAltOnline(e, people, list)
    people = people or (ns.LineupPeople())
    local me = people[e.n:lower()]
    if not me or me.online or not ns.AltsOf then return nil end
    local main = ns.MainOf(e.n) or e.n
    local cands = ns.AltsOf(main)
    cands[#cands + 1] = main
    local taken = {}
    for _, x in ipairs(list or {}) do taken[x.n:lower()] = true end
    local hit
    for _, alt in ipairs(cands) do
        local p = people[alt:lower()]
        if p and p.online and p.guild and alt:lower() ~= e.n:lower() and not taken[alt:lower()] then
            if hit then return nil end
            hit = p.name
        end
    end
    return hit
end

---------------------------------------------------------------------------
-- Edits of a night (every one saved at once)
---------------------------------------------------------------------------
local function entry(night, i)
    local n = ns.LineupNight(night, false)
    local e = n and n.list[i]
    return e, n
end

local function inGroup(n, g)
    local c = 0
    for _, e in ipairs(n.list) do if e.g == g then c = c + 1 end end
    return c
end

local function groups(n)
    local size = SIZES[tonumber(n.size)] and tonumber(n.size) or 40
    return size / GROUP_SIZE
end
ns.LineupGroups = groups

-- Swaps the places of two entries (group, bench, not placed).
function ns.LineupSwap(night, i, j)
    local a, n = entry(night, i)
    local b = n and n.list[j]
    if not a or not b or i == j or a.a or b.a then return false end
    a.g, b.g = b.g, a.g
    a.b, b.b = b.b, a.b
    a.v, b.v = b.v, a.v
    changed()
    return true
end

-- Moves an entry into group g (1-8), onto the bench ("bench") or out of both (nil). A full group
-- refuses (nil and the reason).
function ns.LineupMove(night, i, g)
    local e, n = entry(night, i)
    if not e or e.a then return nil end
    if g == "bench" then
        e.g, e.b, e.v = nil, true, nil
    elseif g == nil then
        e.g, e.b, e.v = nil, nil, nil
    else
        g = tonumber(g)
        if not g or g < 1 or g > groups(n) then return nil end
        if e.g ~= g and inGroup(n, g) >= GROUP_SIZE then return nil, L["Gruppe %d ist voll."]:format(g) end
        if not ns.LineupPlaceable(e) then return nil, L["Gäste nur mit der Einstellung \"Gäste einladen\"."] end
        e.g, e.b, e.v = g, nil, nil
    end
    changed()
    return true
end

function ns.LineupSetRole(night, i, r)
    local e = entry(night, i)
    if not e or not IS_ROLE[r] then return false end
    -- a role by hand stays over the sign-up's and the list's (part H, rule 5)
    e.r, e.q, e.h = r, nil, true
    changed()
    return true
end

function ns.LineupHold(night, i, on)
    local e = entry(night, i)
    if not e or e.a then return false end
    e.k = on and true or nil
    changed()
    return true
end

function ns.LineupRemove(night, i)
    local e, n = entry(night, i)
    if not e then return false end
    table.remove(n.list, i)
    -- remembered: a statement of the calendar or Amisia from before brings the name back only when
    -- it is new (a new click, another calendar status)
    n.gone = n.gone or {}
    n.gone[e.n:lower()] = { t = math.floor(time()), k = e.ks, u = e.au }
    n.gone = cleanGone(n.gone)
    changed()
    return true
end

-- Remembers "list name -> real name" for the next lists (shared with the soft-reserves).
local function remember(from, to)
    if type(from) ~= "string" or type(to) ~= "string" or from:lower() == to:lower() or not AmisiaDB then return end
    AmisiaDB.srAliases = type(AmisiaDB.srAliases) == "table" and AmisiaDB.srAliases or {}
    local n = 0
    for _ in pairs(AmisiaDB.srAliases) do n = n + 1 end
    if n >= ALIAS_MAX and not AmisiaDB.srAliases[from:lower()] then return end
    AmisiaDB.srAliases[from:lower()] = to
end

-- An unclear entry becomes name: a likely one confirmed, an ambiguous one chosen, an unknown one
-- typed. The list's spelling is remembered for the next lists (not for a choice between two
-- members of one first name: that may be the other one next week).
function ns.LineupConfirm(night, i, name)
    local e, n = entry(night, i)
    if not e then return nil end
    local listName = e.s or e.n
    local was = e.x
    name = cleanName(name or e.n)
    if not name then return nil, L["Name fehlt."] end
    for j, o in ipairs(n.list) do
        if j ~= i and o.n:lower() == name:lower() then return nil, L["%s steht schon in der Liste."]:format(o.n) end
    end
    local k = knownPeople()
    local p = k.lower[name:lower()]
    if was == "u" and not p then
        -- a typed name nobody knows: taken as written, still unknown
        e.n, e.s = name, listName ~= name and listName or nil
        if listName ~= name then remember(listName, name) end
        changed()
        return true
    end
    e.n = p and p.name or name
    e.s = e.n:lower() ~= listName:lower() and listName or nil
    e.x = (p and k.guild and not p.guild) and "g" or nil
    e.o = nil
    if p and p.class then e.c = p.class end
    if e.q then e.r = nil end
    settleRole(e, night)
    if was ~= "a" and e.s then remember(listName, e.n) end
    changed()
    return true
end

-- Puts the online alt in the place of the offline character (a suggestion only, by a click).
function ns.LineupSwapAlt(night, i, alt)
    local e, n = entry(night, i)
    alt = cleanName(alt)
    if not e or not alt then return false end
    for j, o in ipairs(n.list) do
        if j ~= i and o.n:lower() == alt:lower() then return false end
    end
    local people = ns.LineupPeople()
    local p = people[alt:lower()]
    e.s = e.s or e.n
    e.n = p and p.name or alt
    if p and p.class and p.class ~= e.c then
        e.c = p.class
        if e.q then e.r = nil settleRole(e, night) end
    end
    e.x = nil
    changed()
    return true
end

-- Copies the lineup of an older night as the start of night (only into an empty night).
function ns.LineupCopy(from, night)
    local src = ns.LineupNight(from, false)
    night = night or tonight()
    if not src or from == night then return nil end
    local dst = ns.LineupNight(night, false)
    if dst and #dst.list > 0 then return nil, L["Diese Nacht hat schon eine Aufstellung."] end
    dst = ns.LineupNight(night, true)
    dst.list = {}
    for _, e in ipairs(src.list) do
        local c = cleanEntry(e)
        if c and not c.a then
            c.v, c.m = nil, nil
            -- the copy is a start of its own: no sources, statements or notes of the old night
            for _, fld in ipairs({ "f", "st", "t", "w", "d", "ks", "kt", "as", "ag", "au", "ar", "lr" }) do c[fld] = nil end
            dst.list[#dst.list + 1] = c
        end
    end
    dst.size, dst.title = src.size, src.title
    changed()
    return #dst.list
end

---------------------------------------------------------------------------
-- Automatisch einteilen (the spec, part B): simple rules one can follow
---------------------------------------------------------------------------
local function roleOf(e) return e.r or "R" end

-- Divides the night's sign-ups into groups. Held entries stay; the bench chosen by the list or an
-- officer stays; the rest is placed anew. Returns the number placed and the number benched as
-- overflow.
function ns.LineupAutoAssign(night)
    local n = ns.LineupNight(night, false)
    if not n then return 0, 0 end
    local size = tonumber(ns.Get("lineup.size")) or 40
    n.size = SIZES[size] and size or 40
    local G = groups(n)
    local box = {}
    for g = 1, G do box[g] = { n = 0, T = 0, H = 0, M = 0, R = 0, totem = false } end
    local function put(e, g)
        local b = box[g]
        e.g, e.b, e.v = g, nil, nil
        b.n = b.n + 1
        local r = roleOf(e)
        b[r] = b[r] + 1
        if e.c == "SHAMAN" or e.c == "WARRIOR" then b.totem = true end
    end
    local function free(g) return box[g].n < GROUP_SIZE end
    -- held entries first, where they are (a held entry outside the raid size loses its group)
    local pool = {}
    for _, e in ipairs(n.list) do
        if e.a then
            e.g = nil
        elseif e.k and e.g and e.g <= G and free(e.g) and ns.LineupPlaceable(e) then
            put(e, e.g)
        elseif e.b or (e.k and e.v) then
            e.g = nil
        else
            e.g, e.v = nil, nil
            if ns.LineupPlaceable(e) then pool[#pool + 1] = e end
        end
    end
    -- more sign-ups than places: tanks, then healers until every group has one, then the list's order
    local places = 0
    for g = 1, G do places = places + GROUP_SIZE - box[g].n end
    local chosen, rest = {}, {}
    if #pool > places then
        local pick, taken = {}, 0
        local tanksNeeded, healersNeeded = 0, 0
        for g = 1, G do
            if box[g].T == 0 then tanksNeeded = tanksNeeded + 1 end
            if box[g].H == 0 then healersNeeded = healersNeeded + 1 end
        end
        for _, e in ipairs(pool) do
            if roleOf(e) == "T" and tanksNeeded > 0 and taken < places then
                pick[e], tanksNeeded, taken = true, tanksNeeded - 1, taken + 1
            end
        end
        for _, e in ipairs(pool) do
            if roleOf(e) == "H" and healersNeeded > 0 and taken < places then
                pick[e], healersNeeded, taken = true, healersNeeded - 1, taken + 1
            end
        end
        for _, e in ipairs(pool) do
            if not pick[e] and taken < places then pick[e], taken = true, taken + 1 end
        end
        for _, e in ipairs(pool) do
            if pick[e] then chosen[#chosen + 1] = e else rest[#rest + 1] = e end
        end
    else
        chosen = pool
    end
    local by = { T = {}, H = {}, M = {}, R = {} }
    for _, e in ipairs(chosen) do table.insert(by[roleOf(e)], e) end
    -- 1. tanks: one per group from group 1; more tanks count with the melee
    local tankGroups = {}
    for g = 1, G do if box[g].T > 0 then tankGroups[g] = true end end
    local extraTanks = {}
    for _, e in ipairs(by.T) do
        local placed = false
        for g = 1, G do
            if box[g].T == 0 and free(g) then
                put(e, g)
                tankGroups[g], placed = true, true
                break
            end
        end
        if not placed then extraTanks[#extraTanks + 1] = e end
    end
    -- the melee groups: the tank groups, then the next ones, as many as the melee fill (4 per group)
    local meleeCount = #by.M + #extraTanks
    local meleeGroups, mg = {}, 0
    for g = 1, G do
        if tankGroups[g] then meleeGroups[g], mg = true, mg + 1 end
    end
    local want = math.min(G, math.ceil(meleeCount / (GROUP_SIZE - 1)))
    for g = 1, G do
        if mg >= want then break end
        if not meleeGroups[g] then meleeGroups[g], mg = true, mg + 1 end
    end
    -- 2. healers: one per group, shamans (then paladins) to melee groups, priests and druids to the others
    local PREF_MELEE = { SHAMAN = 1, PALADIN = 2, DRUID = 3, PRIEST = 4 }
    local PREF_RANGED = { PRIEST = 1, DRUID = 2, PALADIN = 3, SHAMAN = 4 }
    local healers = by.H
    for g = 1, G do
        if box[g].H == 0 and free(g) and #healers > 0 then
            local pref = meleeGroups[g] and PREF_MELEE or PREF_RANGED
            local best, bi = nil, nil
            for idx, e in ipairs(healers) do
                local rank = pref[e.c or ""] or 5
                if not best or rank < best then best, bi = rank, idx end
            end
            put(table.remove(healers, bi), g)
        end
    end
    -- the healers left go to the tank groups, then wherever there is room
    local function fill(list, order)
        local left = {}
        for _, e in ipairs(list) do
            local placed = false
            for _, g in ipairs(order) do
                if free(g) then
                    put(e, g)
                    placed = true
                    break
                end
            end
            if not placed then left[#left + 1] = e end
        end
        return left
    end
    local tankOrder, meleeOrder, rangedOrder, allOrder = {}, {}, {}, {}
    for g = 1, G do
        allOrder[#allOrder + 1] = g
        if tankGroups[g] then tankOrder[#tankOrder + 1] = g end
        if meleeGroups[g] then meleeOrder[#meleeOrder + 1] = g else rangedOrder[#rangedOrder + 1] = g end
    end
    local spill = {}
    for _, e in ipairs(fill(healers, tankOrder)) do spill[#spill + 1] = e end
    -- 3. melee: a warrior or a shaman in every melee group first (when there are enough), then the rest
    local melee = {}
    for _, e in ipairs(extraTanks) do melee[#melee + 1] = e end
    for _, e in ipairs(by.M) do melee[#melee + 1] = e end
    for _, g in ipairs(meleeOrder) do
        if not box[g].totem and free(g) then
            for idx, e in ipairs(melee) do
                if e.c == "WARRIOR" or e.c == "SHAMAN" then
                    put(table.remove(melee, idx), g)
                    break
                end
            end
        end
    end
    for _, e in ipairs(fill(melee, meleeOrder)) do spill[#spill + 1] = e end
    -- 4. ranged together in the other groups
    for _, e in ipairs(fill(by.R, rangedOrder)) do spill[#spill + 1] = e end
    -- 5. what is left fills the next free place
    local over = 0
    for _, e in ipairs(fill(spill, allOrder)) do
        e.v = true
        over = over + 1
    end
    for _, e in ipairs(rest) do
        e.g, e.v = nil, true
        over = over + 1
    end
    local placed = 0
    for _, e in ipairs(n.list) do if e.g then placed = placed + 1 end end
    changed()
    return placed, over
end

-- Counts of a night: T, H, M, R (sign-ups not on the bench, not absent), bench, absent, placed,
-- open (not placed, not on the bench), groups without a healer (with someone in them).
function ns.LineupCounts(night)
    local n = ns.LineupNight(night, false)
    local c = { T = 0, H = 0, M = 0, R = 0, bench = 0, absent = 0, placed = 0, open = 0, noHealer = {} }
    if not n then return c end
    local heal, filled = {}, {}
    for _, e in ipairs(n.list) do
        if e.a then
            c.absent = c.absent + 1
        elseif e.b or e.v then
            c.bench = c.bench + 1
        else
            local r = roleOf(e)
            c[r] = c[r] + 1
            if e.g then
                c.placed = c.placed + 1
                filled[e.g] = true
                if r == "H" then heal[e.g] = true end
            else
                c.open = c.open + 1
            end
        end
    end
    for g = 1, groups(n) do
        if filled[g] and not heal[g] then c.noHealer[#c.noHealer + 1] = g end
    end
    return c
end

---------------------------------------------------------------------------
-- Parts G and H: the calendar's invite list and the sign-ups from Amisia
---------------------------------------------------------------------------
local function findEntry(n, low)
    for i, e in ipairs(n.list) do
        if e.n:lower() == low then return e, i end
    end
    return nil
end

-- The nights a sign-up from Amisia may be for: tonight up to DAYS_AHEAD days ahead.
local function signupNight(night)
    if type(night) ~= "string" or not night:match("^%d%d%d%d%-%d%d%-%d%d$") then return false end
    local now = time()
    return night >= tonight() and night <= ns.NightOf(now + DAYS_AHEAD * 86400)
end
ns.LineupSignupNight = signupNight

-- One sign-up from Amisia (part H): name (the sender, never a field of the message) for night with
-- rec = { s = "A"/"V"/"X", r = role or nil, c = class token or nil, t = epoch of the click, w = note }.
-- A newer click replaces the older one; one older than the last removal by the officer is ignored.
-- A night without a lineup is made. notify: the officer's chat line when a placed player signs
-- off. Returns whether the lineup changed.
function ns.LineupSignup(night, name, rec, notify)
    name = cleanName(name)
    if not name or type(rec) ~= "table" or not OWN[rec.s] or not signupNight(night) then return false end
    -- raw: the click's time by the sender's clock, which orders the sender's own clicks (a re-send
    -- carries the first click's time); t: the same, never later than now, for the comparison with
    -- the calendar (a clock ahead counts as now)
    local raw = posNum(rec.t)
    if not raw then return false end
    local t = math.min(raw, math.floor(time()))
    local low = name:lower()
    local n = ns.LineupNight(night, false)
    local e = n and findEntry(n, low)
    if not e then
        local gone = n and n.gone and n.gone[low]
        if gone and (t <= gone.t or (gone.u and raw <= gone.u)) then return false end
        if n and #n.list >= MAX_SIGNUPS then return false end
        if not n then
            -- a sign-up never pushes tonight's or a coming night's lineup out of the 8 kept: it
            -- makes a night only while there is room or the oldest kept night is over
            local all = ns.LineupNights()
            if #all >= MAX_NIGHTS and all[#all] >= tonight() then return false end
            n = ns.LineupNight(night, true)
        end
        e = { n = name, f = "A" }
        n.list[#n.list + 1] = e
    elseif (e.au or e.ag) and raw <= (e.au or e.ag) then
        return false
    end
    e.f = withSrc(sourcesOf(e), "A", true)
    e.as, e.ag, e.au, e.ar = rec.s, t, raw, IS_ROLE[rec.r] and rec.r or nil
    e.w = type(rec.w) == "string" and ns.CleanNote(stripCodes(rec.w), 40) or nil
    if CLASSES[rec.c] and not e.c then e.c = rec.c end
    -- the sender is a guild member by the roster: the name is no longer unknown
    if e.x == "u" then e.x = nil end
    settle(e, notify)
    settleRole(e, night)
    changed()
    return true
end

-- Every night (tonight on) in which name signed up through Amisia.
function ns.LineupSignupNights(name)
    local out, low = {}, type(name) == "string" and name:lower() or ""
    local d = db(false)
    for night, n in pairs(d and d.nights or {}) do
        if night >= tonight() then
            local e = findEntry(n, low)
            if e and e.as then out[#out + 1] = night end
        end
    end
    return out
end

-- The invite list of a calendar event (part G, Raid/Calendar.lua) into the night of the event: ev
-- of ns.Cal.Events(), invites of ns.Cal.ReadOpen(). Each name through the same match as a list; a
-- name already there gets the calendar's mark; the status follows the newest statement. Another
-- event of the same night replaces the calendar's rows; who left the calendar and came only from it
-- stays grey "nicht mehr im Kalender". quiet: no chat summary (a re-read). Returns the night and the
-- chat line.
function ns.LineupCalendar(ev, invites, quiet)
    local night = ev.night or ns.NightOf(ev.at)
    local n = ns.LineupNight(night, true)
    local now = math.floor(time())
    if n.cal and n.cal.id ~= ev.id then
        local keep = {}
        for _, e in ipairs(n.list) do
            if hasSrc(e, "K") then
                e.f, e.ks, e.kt = withSrc(sourcesOf(e), "K", false), nil, nil
                if e.f ~= "" then
                    settle(e)
                    keep[#keep + 1] = e
                end
            else
                keep[#keep + 1] = e
            end
        end
        n.list = keep
    end
    n.cal = { id = ev.id, at = ev.at, title = ns.CleanNote(stripCodes(ev.title or ""), 40), read = now }
    local k = knownPeople()
    local seen = {}
    local c = { all = 0, A = 0, V = 0, X = 0, E = 0, I = 0, O = 0 }
    for _, inv in ipairs(invites or {}) do
        local name = cleanName(inv.name)
        if name and not seen[name:lower()] then
            seen[name:lower()] = true
            local code = CODES[inv.code] and inv.code or "O"
            c.all = c.all + 1
            local key = (code == "B") and "A" or code
            if c[key] then c[key] = c[key] + 1 end
            local e = findEntry(n, name:lower())
            if not e then
                local gone = n.gone and n.gone[name:lower()]
                if not (gone and gone.k == code) and #n.list < MAX_SIGNUPS then
                    e = { n = name, c = CLASSES[inv.class] and inv.class or nil, f = "K" }
                    matchEntry(k, e)
                    -- the calendar's spelling is the game's: a name the roster lacks is a guest
                    -- (no roster yet: taken as it is)
                    if e.x == "u" then e.x = k.guild and "g" or nil end
                    local other = findEntry(n, e.n:lower())
                    if other then
                        e = other
                    else
                        n.list[#n.list + 1] = e
                    end
                end
            end
            if e then
                seen[e.n:lower()] = true
                e.f = withSrc(sourcesOf(e), "K", true)
                if e.ks ~= code then
                    -- first seen: older than any Amisia click; a change: the time Amisia saw it
                    e.kt = e.ks and now or 0
                    e.ks = code
                end
                if CLASSES[inv.class] and not e.c then e.c = inv.class end
                settle(e, true)
                settleRole(e, night)
            end
        end
    end
    -- the calendar's rows that are not in it any more
    for _, e in ipairs(n.list) do
        if hasSrc(e, "K") and not seen[e.n:lower()] then
            if sourcesOf(e) == "K" then
                if e.ks ~= "G" then e.ks, e.kt = "G", now end
            else
                e.f, e.ks, e.kt = withSrc(sourcesOf(e), "K", false), nil, nil
            end
            settle(e, true)
        end
    end
    changed()
    local line = L["Aufstellung: Kalender %s, %s: %d Einträge, %d angemeldet, %d vorläufig, %d abgesagt."]:format(
        n.cal.title or "?", ns.Cal.When(ev.at), c.all, c.A, c.V, c.X)
    if c.E > 0 then line = line .. " " .. L["%d auf Ersatz."]:format(c.E) end
    if c.I + c.O > 0 then line = line .. " " .. L["%d ohne Antwort."]:format(c.I + c.O) end
    if quiet then line = nil end
    return night, line
end

-- "Übernehmen" of an event (the page): reads its invite list into its night. fn(night, line) or
-- fn(nil, the reason's text).
function ns.LineupReadCalendar(ev, fn)
    if not ns.LineupAllowed() then return fn(nil, L["Die Aufstellung ist nur für Offiziere."]) end
    ns.Cal.Read(ev, function(invites, why)
        if not invites then return fn(nil, ns.Cal.Why(why)) end
        fn(ns.LineupCalendar(ev, invites))
    end)
end

-- Reads the calendar event of night again (the page is open and the calendar changed): the event by
-- its id; one that is gone or moved to another night is marked lost (the rows stay, the mark turns
-- grey). fn(ok, why) when given. Returns false when the night has no event.
function ns.LineupCalendarAgain(night, fn)
    local n = ns.LineupNight(night, false)
    if not n or not n.cal or not ns.LineupAllowed() then return false end
    -- the client's list as it is (no OpenCalendar: its answer would count as the next change);
    -- loaded first only when it is empty
    -- fresh: the list was just loaded (an empty one is real, not "not loaded yet")
    local function go(list, fresh)
        local ev
        for _, e in ipairs(list or {}) do
            if n.cal.id and e.id == n.cal.id then ev = e break end
        end
        if not ev or ev.night ~= night then
            if list and (#list > 0 or fresh) and not n.cal.lost then
                n.cal.lost = true
                changed()
            end
            if fn then fn(false, "gone") end
            return
        end
        if n.cal.lost then n.cal.lost = nil end
        ns.Cal.Read(ev, function(invites, why)
            if invites then ns.LineupCalendar(ev, invites, true) end
            if fn then fn(invites ~= nil, why) end
        end)
    end
    local list = ns.Cal.Events()
    if #list > 0 then go(list) else ns.Cal.Load(function(l) go(l, true) end) end
    return true
end

-- How many rows of a night carry each source mark: { L, K, A }.
function ns.LineupSources(night)
    local n = ns.LineupNight(night, false)
    local c = { L = 0, K = 0, A = 0 }
    for _, e in ipairs(n and n.list or {}) do
        for _, x in ipairs(SOURCES) do
            if hasSrc(e, x) then c[x] = c[x] + 1 end
        end
    end
    return c
end

---------------------------------------------------------------------------
-- Teil E: the bench of the evening through ns.BenchAdd
---------------------------------------------------------------------------
-- Puts "Ersatz" and the overflow that are online on tonight's bench, with the note "Aufstellung".
-- Not: the absent, the offline, unclear names, guests without lineup.guests. Returns the names
-- added and the number left out, or nil and the reason.
function ns.LineupBench(night)
    night = night or tonight()
    if night ~= tonight() then return nil, L["Die Ersatzbank gilt nur für heute."] end
    local n = ns.LineupNight(night, false)
    if not n or not ns.BenchAdd then return nil, L["Niemand auf Ersatz."] end
    local people = ns.LineupPeople()
    local added, left, any = {}, 0, false
    for _, e in ipairs(n.list) do
        if (e.b or e.v) and not e.a then
            any = true
            local p = people[e.n:lower()]
            if ns.LineupPlaceable(e) and (e.x == nil or e.x == "l" or e.x == "g") and p and p.online then
                local ok, key = ns.BenchAdd(nil, e.n, { note = L["Aufstellung##Notiz"], class = e.c })
                if ok then added[#added + 1] = key else left = left + 1 end
            else
                left = left + 1
            end
        end
    end
    if not any then return nil, L["Niemand auf Ersatz."] end
    return added, left
end

local function benchMessage(added, left)
    if not added then return left end
    local text = #added > 0 and L["Ersatzbank: %s (Notiz \"Aufstellung\")."]:format(table.concat(added, ", "))
        or L["Niemand auf die Ersatzbank eingetragen."]
    if left > 0 then text = text .. " " .. L["%d nicht eingetragen (offline, unklar oder schon im Raid)."]:format(left) end
    return text
end
ns.LineupBenchMessage = benchMessage

-- "Ersatz automatisch eintragen, sobald die Aufnahme läuft" (off by default).
ns.Listen("RECORDING", function(s)
    if not s or not ns.Get("lineup.autoBench") or not ns.LineupAllowed() then return end
    local n = ns.LineupNight(tonight(), false)
    if not n then return end
    local added, left = ns.LineupBench(tonight())
    if added and #added > 0 then ns.msg(benchMessage(added, left)) end
end)

---------------------------------------------------------------------------
-- Settings and /amisia aufstellung
---------------------------------------------------------------------------
ns.RegisterSettings{ key = "lineup", label = L["Raid-Aufstellung"], order = 24, officer = true,
    available = function() return ns.LineupAllowed() end, items = {
    { key = "lineup.size", type = "choice", label = L["Raidgröße"], default = 40,
      values = { { 10, "10" }, { 20, "20" }, { 40, "40" } },
      tip = L["So viele Plätze teilt \"Automatisch einteilen\" ein (40: acht Gruppen, 20: vier, 10: zwei)."] },
    { key = "lineup.guests", type = "toggle", label = L["Gäste einladen"], default = false,
      tip = L["Gäste (nicht in der Gilde) werden nur damit eingeteilt und auf die Ersatzbank gesetzt."] },
    { key = "lineup.autoBench", type = "toggle", label = L["Ersatz automatisch eintragen, sobald die Aufnahme läuft"], default = false,
      tip = L["Trägt \"Ersatz\" und Überzählige von heute, die online sind, auf die Ersatzbank ein."] },
    { key = "lineup.signups", type = "toggle", label = L["Anmeldungen aus Amisia annehmen"], default = true,
      tip = L["Raider mit Amisia melden sich im Spiel an (Rolle und Notiz); ihre Anmeldungen stehen in der Aufstellung der Nacht mit der Quelle \"Amisia\"."] },
}}

ns.RegisterSlash("aufstellung", { en = "lineup", officer = true, desc = L["Raid-Aufstellung: Anmeldeliste einfügen und Gruppen planen"],
    run = function()
        if not ns.LineupAllowed() then
            ns.msg(L["Die Aufstellung ist nur für Offiziere."])
            return
        end
        if ns.ShowLineup then ns.ShowLineup() end
    end })

-- for the tests
ns._lineup = { oneOff = oneOff, norm = norm, cleanLine = cleanLine, lineWords = lineWords, MAX_SIGNUPS = MAX_SIGNUPS,
               MAX_NIGHTS = MAX_NIGHTS, statementOf = statementOf, SAME_CLICK = SAME_CLICK }
