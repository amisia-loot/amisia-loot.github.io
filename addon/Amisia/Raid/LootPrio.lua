-- Amisia loot council: per item an officers' note and an ordered priority list (players with a
-- role, classes with a spec, "offen"), e.g. "1. Anna (Tank), 2. Krieger Furor, 3. offen". The
-- website is the source: officers edit it there and copy it into the addon as an "#AMISIA-LC"
-- block (with the wishes and alts in one paste, Alts.lua ns.ImportSiteText). Officers can edit an
-- item in game too (a small dialog from the roll window or /amisia prio <item>); those edits stay
-- local and go back to the site as "LC" lines of the export until a pasted site list carries them.
-- The newest entry of an item wins (site, own edit, the keeper's shared list).
--
-- Shown in the roll window (a line under the item and "P1", "P2" in the rows), the award dialog
-- (prio players first), the loot announcement (loot.prio), the item tooltip (prio.tooltip) and on
-- the group loot roll frames ("P", "P1" when the own name stands first).
--
-- Shared in the raid by the sync keeper (Sync.lua): "LV <raid key> <hash> <n>" into the raid, a
-- client with another state asks by whisper "LQ <raid key> <hash>", the keeper answers with the
-- whole list as blob "LC". Only a verified officer of the own guild in the own group is listened
-- to, and a list is checked whole before it replaces the shared one. Raiders see only that list.
--
-- Stored in AmisiaDB.prio = { site = { date, at, by, n, list }, edits = { [id] = entry },
-- shared = { from, at, hash, list } }; entry = { at, by, note, prio = { { k = "p"|"c"|"o", name,
-- class, label } } }. Every pasted or received text is untrusted: codes stripped, fields checked.
local ADDON, ns = ...
local L = ns.L
local N_ = ns.N_
local W, T = ns.W, ns.Theme

local HEAD_FAIL = L["Das ist keine Prioliste der Amisia-Seite."]
local MAX_LINES = 2000
local MAX_LINE = 1000
local NAME_MAX = 48
local LABEL_MAX = 16
local NOTE_MAX = 80
local MAX_ENTRIES = 10
local MAX_ID = 9999999
local MAX_SHARE = 120          -- items in one shared list (the newest)
local OWN_GAME = "forever"
local GAME_NAMES = { forever = "WoW Forever", tbc = "TBC Anniversary" }
local LV_EVERY = 240           -- the keeper repeats its state this often
local LV_GAP = 10              -- and not more often than this after a change
local ANSWER_AFTER = 2         -- requests within this go out together
local ANSWER_RAID = 3          -- this many requesters: one send into the raid
local LINE_MAX = 80            -- characters of the prio in a loot announcement line
local ZERO = "0000000000000000"
local TOO_BIG = N_("Daten zu groß.")   -- Comm's reason for a blob over its parts (compared, not shown)
local GOLD = { 1, 0.82, 0 }

-- class tokens and their names (German in the code, English through L)
local CLASS_NAME = { WARRIOR = N_("Krieger"), PALADIN = N_("Paladin"), HUNTER = N_("Jäger"), ROGUE = N_("Schurke"),
    PRIEST = N_("Priester"), SHAMAN = N_("Schamane"), MAGE = N_("Magier"), WARLOCK = N_("Hexenmeister"), DRUID = N_("Druide"),
    DEATHKNIGHT = N_("Todesritter"), MONK = N_("Mönch") }
local CLASS_EN = { WARRIOR = "warrior", PALADIN = "paladin", HUNTER = "hunter", ROGUE = "rogue", PRIEST = "priest",   -- l10n-ok: words read in the free text
    SHAMAN = "shaman", MAGE = "mage", WARLOCK = "warlock", DRUID = "druid", DEATHKNIGHT = "death knight", MONK = "monk" }   -- l10n-ok: words read in the free text
local OPEN_WORDS = { offen = true, open = true, frei = true, free = true }   -- l10n-ok: words read in the free text

local function report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

local function now() return GetTime() end

---------------------------------------------------------------------------
-- The prio token: "p:Anna:Tank,c:WARRIOR:Furor,o" ("_" is the space, "-" an empty list)
---------------------------------------------------------------------------

local function stripCodes(s)
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")
    s = s:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|", "")
    return s
end

local function cleanName(raw)
    local name = ns.FullName((tostring(raw):gsub("_", " ")))
    if not name or #name > NAME_MAX or name:find("[%d%c,:;()|]") then return nil end
    return name
end

-- A label ("Tank", "Furor"): no separators or codes, at most 16 bytes; nil when not valid.
local function cleanLabel(raw)
    if type(raw) ~= "string" then return nil end
    local s = raw:gsub("_", " "):match("^%s*(.-)%s*$"):gsub("%s+", " ")
    if s == "" or #s > LABEL_MAX or s:find("[%c,:;()|]") then return nil end
    return s
end

local function className(cls)
    local names = _G.LOCALIZED_CLASS_NAMES_MALE
    local n = type(names) == "table" and ns.Plain(names[cls])
    if type(n) == "string" and n ~= "" then return n end
    return CLASS_NAME[cls] and L[CLASS_NAME[cls]] or cls
end

-- The entries of a token, or nil when any part is not valid.
function ns.ParsePrioToken(tok)
    if type(tok) ~= "string" or tok == "" then return nil end
    local out = {}
    if tok == "-" then return out end
    for part in (tok .. ","):gmatch("([^,]*),") do
        if #out >= MAX_ENTRIES then return nil end
        local k, a, b
        if part == "o" then
            k = "o"
        else
            k, a, b = part:match("^([pc]):([^:]+):?(.*)$")
        end
        local e
        if k == "o" then
            e = { k = "o" }
        elseif k == "p" then
            local name = cleanName(a)
            if not name then return nil end
            e = { k = "p", name = name }
        elseif k == "c" then
            if not CLASS_NAME[a] then return nil end
            e = { k = "c", class = a }
        else
            return nil
        end
        if k ~= "o" and b ~= "" then
            e.label = cleanLabel(b)
            if not e.label then return nil end
        end
        out[#out + 1] = e
    end
    return out
end

local function under(s) return (s:gsub(" ", "_")) end

function ns.PrioTokenOf(list)
    if type(list) ~= "table" or #list == 0 then return "-" end
    local parts = {}
    for i, e in ipairs(list) do
        if e.k == "o" then
            parts[i] = "o"
        else
            parts[i] = e.k .. ":" .. under(e.k == "p" and e.name or e.class) .. (e.label and (":" .. under(e.label)) or "")
        end
    end
    return table.concat(parts, ",")
end

local function entryText(e)
    if e.k == "o" then return L["offen"] end
    if e.k == "c" then return className(e.class) .. (e.label and (" " .. e.label) or "") end
    return e.name .. (e.label and (" (" .. e.label .. ")") or "")
end

-- "1. Anna (Tank), 2. Krieger Furor, 3. offen"; numbered false leaves the numbers out.
function ns.LootPrioText(list, numbered)
    local parts = {}
    for i, e in ipairs(list or {}) do
        parts[i] = (numbered == false and "" or (i .. ". ")) .. entryText(e)
    end
    return table.concat(parts, ", ")
end

---------------------------------------------------------------------------
-- The website's block
---------------------------------------------------------------------------

local function gameName(key) return GAME_NAMES[key] or stripCodes(tostring(key)):sub(1, 24) end

-- Reads:
--   #AMISIA-LC 1 <game> <yyyy-mm-dd>
--   C <itemID> <edited epoch> <token|-> [<note>]
--   #END
-- Returns { game, date, list = { [id] = entry }, n, skipped } or nil and the reason. An item with
-- neither prio nor note stays as a cleared item (it overrides an older edit).
function ns.ParseLootPrio(text)
    if type(text) ~= "string" then return nil, HEAD_FAIL end
    local res = { list = {}, n = 0, skipped = 0 }
    local read, head = 0, false
    for raw in text:gmatch("[^\r\n]+") do
        local line = stripCodes(raw:sub(1, MAX_LINE)):match("^%s*(.-)%s*$")
        if line ~= "" then
            if not head then
                line = line:gsub("^\239\187\191", "")
                local ver, game, day = line:match("^#AMISIA%-LC%s+(%d+)%s+(%S+)%s+(%S+)")
                if ver ~= "1" or not day or not day:match("^%d%d%d%d%-%d%d%-%d%d$") then return nil, HEAD_FAIL end
                game = game:lower()
                if game ~= OWN_GAME then
                    return nil, L["Diese Prioliste ist für %s, du bist in %s."]:format(gameName(game), gameName(OWN_GAME))
                end
                res.game, res.date, head, read = game, day, true, 1
            elseif line == "#END" then
                break
            elseif read >= MAX_LINES then
                res.skipped = res.skipped + 1
            else
                read = read + 1
                local id, at, tok, note = line:match("^C%s+(%d+)%s+(%d+)%s+(%S+)%s*(.-)$")
                id, at = tonumber(id), tonumber(at)
                local prio = tok and ns.ParsePrioToken(tok)
                if not id or id < 1 or id > MAX_ID or not at or not prio then
                    res.skipped = res.skipped + 1
                else
                    local old = res.list[id]
                    if not old then res.n = res.n + 1 end
                    if not old or at >= old.at then
                        res.list[id] = { at = at, note = ns.CleanNote(note, NOTE_MAX) or "", prio = prio }
                    end
                end
            end
        end
    end
    if not head then return nil, HEAD_FAIL end
    if res.n == 0 then return nil, L["Die Prioliste ist leer."] end
    return res
end

---------------------------------------------------------------------------
-- Storage and lookups
---------------------------------------------------------------------------

local function store(make)
    if not AmisiaDB then return nil end
    local p = AmisiaDB.prio
    if type(p) ~= "table" then
        if not make then return nil end
        p = {}
        AmisiaDB.prio = p
    end
    if type(p.edits) ~= "table" then p.edits = {} end
    return p
end

local function empty(e) return #e.prio == 0 and (e.note or "") == "" end

-- The officers' view: site list, own edits and the shared list; raiders: only the shared list.
local function officer() return ns.IsOfficerView() end

local SOURCES = { "site", "shared", "edit" }   -- on the same time the later one wins
local function sourceList(p, src)
    if src == "edit" then return p.edits end
    local t = p[src]
    return type(t) == "table" and type(t.list) == "table" and t.list or nil
end

-- The newest entry of an item (a cleared one included) and its source.
local function newest(id, all)
    local p = store()
    if not p or not id then return nil end
    local best, from
    for _, src in ipairs(SOURCES) do
        if all or src == "shared" then
            local list = sourceList(p, src)
            local e = list and list[id]
            if type(e) == "table" and (not best or (tonumber(e.at) or 0) >= (tonumber(best.at) or 0)) then best, from = e, src end
        end
    end
    return best, from
end

local function itemId(item) return tonumber(item) or ns.ItemID(ns.Plain(item)) end

-- The prio of an item as this client shows it: { prio, note, at, by, src } or nil.
function ns.LootPrioOf(item, everything)
    local e, src = newest(itemId(item), everything or officer())
    if not e or empty(e) then return nil end
    return { prio = e.prio, note = e.note or "", at = e.at, by = e.by, src = src }
end

-- Every item's newest entry, cleared ones included (what the keeper shares): id -> entry.
local function merged()
    local p, out = store(), {}
    if not p then return out end
    for _, src in ipairs(SOURCES) do
        local list = sourceList(p, src)
        for id, e in pairs(list or {}) do
            local o = out[id]
            if type(e) == "table" and (not o or (tonumber(e.at) or 0) >= (tonumber(o.at) or 0)) then out[id] = e end
        end
    end
    return out
end

-- The place of a roller in the item's list: rank and "name" (a player entry) or "class"; nil.
function ns.LootPrioRank(item, name, class)
    local p = ns.LootPrioOf(item)
    if not p or not name then return nil end
    local roster = ns.GroupRoster()
    for i, e in ipairs(p.prio) do
        if e.k == "p" and ns.SameNameIn(e.name, name, roster) then return i, "name" end
    end
    if class then
        for i, e in ipairs(p.prio) do
            if e.k == "c" and e.class == class then return i, "class" end
        end
    end
    return nil
end

local function fire()
    ns.Fire("LOOT_PRIO")
end

-- Stores a pasted site list (the old one stays when the text is refused); own edits the list
-- already carries (same or newer time) are dropped.
function ns.SetLootPrio(text)
    local res, why = ns.ParseLootPrio(text)
    if not res then return nil, why end
    local p = store(true)
    if not p then return nil, L["Amisia ist noch nicht geladen."] end
    p.site = { game = res.game, date = res.date, at = time(), by = ns.UnitFullName("player"), n = res.n, list = res.list }
    for id, e in pairs(p.edits) do
        local s = res.list[id]
        if s and s.at >= (tonumber(e.at) or 0) then p.edits[id] = nil end
    end
    fire()
    return res
end

function ns.ClearLootPrio()
    if AmisiaDB then AmisiaDB.prio = nil end
    fire()
end

-- { date, n, edits, shared } or nil without anything.
function ns.LootPrioInfo()
    local p = store()
    if not p then return nil end
    local edits = 0
    for _ in pairs(p.edits) do edits = edits + 1 end
    local site, shared = type(p.site) == "table" and p.site or nil, type(p.shared) == "table" and p.shared or nil
    if not site and not shared and edits == 0 then return nil end
    local sn = 0
    for _ in pairs(shared and shared.list or {}) do sn = sn + 1 end
    return { date = site and site.date, n = site and tonumber(site.n) or 0, edits = edits, shared = sn, from = shared and shared.from }
end

-- Own edits waiting for the site (exported as LC lines).
function ns.LootPrioPending()
    local p = store()
    local n = 0
    for _ in pairs(p and p.edits or {}) do n = n + 1 end
    return n
end

---------------------------------------------------------------------------
-- Editing in game
---------------------------------------------------------------------------

local function classOf(word)
    local f = ns.Fold(word)
    for cls, de in pairs(CLASS_NAME) do
        if ns.Fold(de) == f or CLASS_EN[cls] == f or ns.Fold(L[de]) == f then return cls end
    end
    for _, map in ipairs({ _G.LOCALIZED_CLASS_NAMES_MALE, _G.LOCALIZED_CLASS_NAMES_FEMALE }) do
        if type(map) == "table" then
            for cls, text in pairs(map) do
                if CLASS_NAME[cls] and type(text) == "string" and ns.Fold(text) == f then return cls end
            end
        end
    end
    return nil
end

-- The order as typed: "Anna (Tank), Krieger Furor, offen" (comma or semicolon). Returns the entries
-- or nil and "Nicht erkannt: <part>".
function ns.ParsePrioFree(text)
    local out = {}
    text = stripCodes(tostring(text or ""))
    for part in (text .. ","):gmatch("([^,;]*)[,;]") do
        part = part:match("^%s*(.-)%s*$")
        if part ~= "" then
            if #out >= MAX_ENTRIES then return nil, L["Höchstens %d Einträge."]:format(MAX_ENTRIES) end
            local body, label = part:match("^(.-)%s*%((.-)%)$")
            body = body or part
            local e
            if OPEN_WORDS[ns.Fold(body)] and not label then
                e = { k = "o" }
            else
                -- a class: its name, the two words of "death knight", or the client's name, then the spec
                local cls, rest
                for n = 2, 1, -1 do
                    local words = {}
                    for w in body:gmatch("%S+") do words[#words + 1] = w end
                    if #words >= n then
                        local c = classOf(table.concat(words, " ", 1, n))
                        if c then cls, rest = c, table.concat(words, " ", n + 1) break end
                    end
                end
                if cls then
                    e = { k = "c", class = cls }
                    label = label or (rest ~= "" and rest or nil)
                else
                    local name = cleanName(body)
                    if not name then return nil, L["Nicht erkannt: %s"]:format(part) end
                    e = { k = "p", name = name }
                end
                if label then
                    e.label = cleanLabel(label)
                    if not e.label then return nil, L["Nicht erkannt: %s"]:format(part) end
                end
            end
            out[#out + 1] = e
        end
    end
    return out
end

-- The order as the box shows it again: "Anna (Tank), Krieger Furor, offen".
function ns.LootPrioFreeText(list)
    return ns.LootPrioText(list, false)
end

local function putEdit(id, prio, note)
    local p = store(true)
    if not p then return nil, L["Amisia ist noch nicht geladen."] end
    local e = { at = math.floor(time()), by = ns.UnitFullName("player"), note = note or "", prio = prio }
    p.edits[id] = e
    fire()
    return e
end

-- An officer's edit of one item: the order as typed and a note. Returns the entry or nil and why.
function ns.EditLootPrio(item, orderText, note)
    local id = itemId(item)
    if not id then return nil, L["Kein Item."] end
    local prio, why = ns.ParsePrioFree(orderText)
    if not prio then return nil, why end
    return putEdit(id, prio, ns.CleanNote(stripCodes(tostring(note or "")), NOTE_MAX))
end

-- Clears an item (an empty edit, so it also clears the site's and the shared entry).
function ns.ClearLootPrioItem(item)
    local id = itemId(item)
    if not id then return nil end
    return putEdit(id, {}, "")
end

local function oneLine(text) return (tostring(text or ""):gsub("[%c|]", " ")) end

-- LC <itemID> <edited epoch> <officer> <token|-> [<note>]: own edits for the site, item by item.
function ns.LootPrioExportLines()
    local p = store()
    local ids, lines = {}, {}
    for id in pairs(p and p.edits or {}) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local e = p.edits[id]
        local note = (e.note or "") ~= "" and (" " .. oneLine(e.note)) or ""
        lines[#lines + 1] = ("LC %d %d %s %s%s"):format(id, tonumber(e.at) or 0, ns.ExportName(e.by or "?"), ns.PrioTokenOf(e.prio), note)
    end
    return lines
end

---------------------------------------------------------------------------
-- The short forms the other parts show
---------------------------------------------------------------------------

-- "Prio: 1. Anna (Tank), 2. Krieger · Notiz" for the roll window; nil without prio.
function ns.LootPrioLine(item)
    local p = ns.LootPrioOf(item)
    if not p then return nil end
    local text = #p.prio > 0 and L["Prio: %s"]:format(ns.LootPrioText(p.prio)) or nil
    if p.note ~= "" then text = text and (text .. " · " .. p.note) or L["Notiz: %s"]:format(p.note) end
    return text
end

-- "Anna (Tank), Krieger, offen" for the loot announcement, cut to 80 characters; nil without prio.
function ns.LootPrioShort(item)
    local p = ns.LootPrioOf(item)
    if not p or #p.prio == 0 then return nil end
    local text = ns.LootPrioText(p.prio, false)
    if #text > LINE_MAX then text = ns.CleanNote(text, LINE_MAX - 3) .. "..." end
    return text
end

-- The award dialog's names with the players of the list first, in their order ("Anna (Prio 1)").
function ns.LootPrioAwardValues(item, values)
    if not item or not officer() then return values end
    local p = ns.LootPrioOf(item)
    if not p then return values end
    local names = {}
    for i, v in ipairs(values) do names[i] = v.value end
    local first, taken = {}, {}
    for rank, e in ipairs(p.prio) do
        if e.k == "p" then
            for i, v in ipairs(values) do
                if not taken[i] and ns.SameNameIn(e.name, v.value, names) then
                    taken[i] = true
                    first[#first + 1] = { value = v.value, text = L["%s (Prio %d)"]:format(v.value, rank) }
                    break
                end
            end
        end
    end
    if #first == 0 then return values end
    for i, v in ipairs(values) do
        if not taken[i] then first[#first + 1] = v end
    end
    return first
end

---------------------------------------------------------------------------
-- Tooltip and the group loot roll frames
---------------------------------------------------------------------------

ns.OnItemTooltip("lootprio", function(tip, _, id)
    if not ns.Get("prio.tooltip") then return false end
    local p = ns.LootPrioOf(id)
    if not p then return false end
    if #p.prio > 0 then tip:AddLine(L["Prio: %s"]:format(ns.LootPrioText(p.prio)), GOLD[1], 0.7, 0.28, true) end
    if p.note ~= "" then tip:AddLine(L["Notiz: %s"]:format(p.note), 0.85, 0.85, 0.85, true) end
    return true
end)

local rollMarks = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })

local function markRoll(frame)
    local text
    local fn = _G.GetLootRollItemLink
    if ns.Get("prio.lootMark") and type(fn) == "function" then
        local ok, link = pcall(fn, ns.Plain(frame.rollID))
        local id = ok and ns.ItemID(ns.Plain(link)) or nil
        local p = id and ns.LootPrioOf(id)
        if p and #p.prio > 0 then
            text = "P"
            local rank, how = ns.LootPrioRank(id, ns.UnitFullName("player"))
            if rank and how == "name" then text = "P" .. rank end
        end
    end
    local mark = rollMarks[frame]
    if not text then
        if mark then mark:Hide() end
        return
    end
    if not mark then
        local parent = type(frame.IconFrame) == "table" and frame.IconFrame or frame
        mark = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        mark:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 1, 1)
        mark:SetTextColor(GOLD[1], 0.7, 0.28)
        rollMarks[frame] = mark
    end
    mark:SetText(text)
    mark:Show()
end

local function onRollFrameShow(frame)
    local ok, err = pcall(markRoll, frame)
    if not ok then report(err) end
end

local function hookRollFrames()
    for i = 1, tonumber(_G.NUM_GROUP_LOOT_FRAMES) or 4 do
        local f = _G["GroupLootFrame" .. i]
        if type(f) == "table" and type(f.HookScript) == "function" and not hooked[f] then
            hooked[f] = true
            f:HookScript("OnShow", onRollFrameShow)
        end
    end
end
hookRollFrames()
ns.OnEvent("PLAYER_ENTERING_WORLD", hookRollFrames)

function ns.LootPrioRollMarkText(frame)
    local m = rollMarks[frame]
    return (m and m:IsShown()) and m:GetText() or nil
end

---------------------------------------------------------------------------
-- The edit dialog
---------------------------------------------------------------------------
local D
local DW, DH = 380, 196

local function dialogSave()
    local e, why = ns.EditLootPrio(D.item, D.order:GetText(), D.note:GetText())
    if not e then
        D.hint:SetText("|cffe05050" .. tostring(why) .. "|r")
        return
    end
    D:Hide()
end

local function buildDialog()
    D = W.Window("AmisiaPrioDialog", DW, DH, { title = L["Loot-Prio"], strata = "FULLSCREEN_DIALOG" })
    D:SetPoint("CENTER", 0, 160)
    D.itemText = W.Text(D, T.FONT.body, DW - 24)
    D.itemText:SetPoint("TOPLEFT", 12, -32)
    local lab = W.Text(D, T.FONT.text, 80)
    lab:SetPoint("TOPLEFT", 12, -60)
    lab:SetText(L["Reihenfolge"])
    D.order = W.LineEdit(D, DW - 24 - 84, function() end)
    D.order:SetPoint("LEFT", lab, "RIGHT", 4, 0)
    D.order:SetMaxLetters(MAX_LINE)   -- ten full names with roles reach about 700 characters
    local noteLab = W.Text(D, T.FONT.text, 80)
    noteLab:SetPoint("TOPLEFT", 12, -88)
    noteLab:SetText(L["Notiz"])
    D.note = W.LineEdit(D, DW - 24 - 84, function() end)
    D.note:SetPoint("LEFT", noteLab, "RIGHT", 4, 0)
    D.note:SetMaxLetters(NOTE_MAX)
    D.hint = W.Text(D, T.FONT.hint, DW - 24, true)
    D.hint:SetPoint("TOPLEFT", 12, -112)
    D.hint:SetHeight(36)
    D.hint:SetJustifyV("TOP")
    D.save = W.Button(D, L["Speichern"], 90, dialogSave)
    W.FitChip(D.save, 90)
    D.save:SetPoint("BOTTOMLEFT", 12, 12)
    D.clear = W.Button(D, L["Leeren"], 80, function()
        D.order:SetText("")
        D.note:SetText("")
    end)
    W.FitChip(D.clear, 80)
    D.clear:SetPoint("LEFT", D.save, "RIGHT", 6, 0)
    D.cancel = W.Button(D, L["Abbrechen"], 86, function() D:Hide() end)
    W.FitChip(D.cancel, 86)
    D.cancel:SetPoint("BOTTOMRIGHT", -12, 12)
    ns.PrioDialog = D
end

-- Opens the dialog for an item (officers only).
function ns.ShowPrioDialog(item)
    if not ns.IsOfficerView() then
        ns.msg(L["Loot-Prio bearbeiten nur Offiziere."])
        return nil
    end
    local id = itemId(item)
    if not id then
        ns.msg(L["Kein Item."])
        return nil
    end
    if not D then buildDialog() end
    D.item = id
    local link = type(item) == "string" and item:find("|H", 1, true) and item or nil
    if not link and C_Item and C_Item.GetItemInfo then
        local _, l = C_Item.GetItemInfo(id)
        link = l
    end
    D.itemText:SetText(link or ("Item " .. id))
    local p = ns.LootPrioOf(id, true)
    D.order:SetText(p and ns.LootPrioFreeText(p.prio) or "")
    D.note:SetText(p and p.note or "")
    D.hint:SetText(L["Spieler mit Rolle in Klammern, Klassen mit Spezialisierung, \"offen\"; durch Kommas getrennt. Leer und gespeichert löscht die Prio."])
    D:Show()
    return D
end

---------------------------------------------------------------------------
-- Sharing in the raid: LV / LQ / LC
---------------------------------------------------------------------------
local lastLV            -- { h, key, at }
local asks, askTimer = {}, false   -- sender -> true: requests waiting for the answer
local wanted = {}                   -- raid key -> the announced state this client asked for
local stats = { sent = 0, taken = 0, refused = 0 }

local function shareOn() return ns.Get("prio.share") ~= false and ns.CommReady and ns.CommReady() and ns.CommPacking() end

local function running()
    local s = ns.Active and ns.Active()
    if not s or not ns.RaidKey then return nil end
    return s, ns.RaidKey(s)
end

-- The rows of a list in a fixed order: { id, at, by, token, note }, at most MAX_SHARE (the newest).
local function rowsOf(list)
    local rows = {}
    for id, e in pairs(list) do
        rows[#rows + 1] = { id, tonumber(e.at) or 0, e.by or "", ns.PrioTokenOf(e.prio), e.note or "" }
    end
    table.sort(rows, function(a, b)
        if a[2] ~= b[2] then return a[2] > b[2] end
        return a[1] < b[1]
    end)
    for i = #rows, MAX_SHARE + 1, -1 do rows[i] = nil end
    table.sort(rows, function(a, b) return a[1] < b[1] end)
    return rows
end

local function hashOf(rows)
    local parts = {}
    for i, r in ipairs(rows) do parts[i] = ("%d %d %s %s"):format(r[1], r[2], r[4], r[5]) end
    return ns.Checksum(table.concat(parts, "\n"))
end

-- The hash and size of what this client holds (all sources).
local function ownState()
    local rows = rowsOf(merged())
    return hashOf(rows), #rows, rows
end

local function sendLV()
    if not shareOn() then return end
    local _, key = running()
    if not key or not (ns.SyncIsKeeper and ns.SyncIsKeeper()) then
        lastLV = nil
        return
    end
    local h, n = ownState()
    if n == 0 then return end
    local t = now()
    if lastLV and lastLV.key == key then
        if lastLV.h == h and t - lastLV.at < LV_EVERY then return end
        if t - lastLV.at < LV_GAP then return end
    end
    if ns.CommSend("LV", { key, h, tostring(n) }, "RAID", nil, { ttl = 60, key = "LV" }) then
        lastLV = { h = h, key = key, at = t }
    end
end

local function sendList()
    askTimer = false
    local _, key = running()
    if not key or not (ns.SyncIsKeeper and ns.SyncIsKeeper()) then asks = {} return end
    local _, n, rows = ownState()
    if n == 0 then asks = {} return end
    local who = {}
    for s in pairs(asks) do who[#who + 1] = s end
    asks = {}
    -- too big for one blob: the newest half, until it fits (the rest waits for the site's paste)
    local function send(chan, target, opts)
        local list = rows
        while true do
            local ok, why = ns.CommSendBlob("LC", key, { v = 1, l = list }, chan, target, opts)
            if ok then stats.sent = stats.sent + 1 return end
            if why ~= TOO_BIG or #list <= 10 then return end
            table.sort(list, function(a, b) return a[2] > b[2] end)
            local half = {}
            for i = 1, math.floor(#list / 2) do half[i] = list[i] end
            table.sort(half, function(a, b) return a[1] < b[1] end)
            list = half
        end
    end
    if #who >= ANSWER_RAID then
        send("RAID", nil, { ttl = 600 })
        return
    end
    for _, s in ipairs(who) do send("WHISPER", s, { ttl = 600, key = "LC:" .. s }) end
end

ns.CommOn("LV", function(sender, f, chan)
    if chan ~= "RAID" or not shareOn() then return end
    local name = ns.TrustName(sender)
    if not name then return end
    local key, h = f[1], f[2]
    ns.TrustWait(name, "officer", function(ok)
        if not ok or not shareOn() or not ns.InMyGroup(name) then return end
        local _, own = running()
        if own ~= key then return end
        local p = store()
        -- the list of that state is here already (a list cut to fit one blob has another hash)
        if (p and type(p.shared) == "table" and (p.shared.hash == h or p.shared.lv == h)) or ownState() == h then return end
        wanted[key] = h
        ns.CommSend("LQ", { key, (p and type(p.shared) == "table" and p.shared.hash) or ZERO }, "WHISPER", sender,
            { jitter = 2.75, ttl = 60, key = "LQ:" .. key })
    end)
end)

ns.CommOn("LQ", function(sender, f, chan)
    if chan ~= "WHISPER" or not shareOn() then return end
    local name = ns.TrustName(sender)
    if not name then return end
    ns.TrustWait(name, "member", function(ok)
        if not ok or not ns.InMyGroup(name) then return end
        local _, key = running()
        if key ~= f[1] or not (ns.SyncIsKeeper and ns.SyncIsKeeper()) then return end
        asks[sender] = true
        if not askTimer then
            askTimer = true
            C_Timer.After(ANSWER_AFTER, function()
                local okSend, err = pcall(sendList)
                if not okSend then askTimer = false; report(err) end
            end)
        end
    end)
end)

-- A received list, checked whole: id -> entry, or nil.
local function checkList(tbl)
    if type(tbl) ~= "table" or tbl.v ~= 1 or type(tbl.l) ~= "table" then return nil end
    local list, n, limit = {}, 0, time() + 86400
    for _, r in ipairs(tbl.l) do
        n = n + 1
        if n > MAX_SHARE or type(r) ~= "table" then return nil end
        local id, at, by, tok, note = r[1], r[2], r[3], r[4], r[5]
        if type(id) ~= "number" or id ~= math.floor(id) or id < 1 or id > MAX_ID or list[id] then return nil end
        if type(at) ~= "number" or at ~= math.floor(at) or at < 0 or at > limit then return nil end
        if type(by) ~= "string" or (by ~= "" and cleanName(by) ~= by) then return nil end
        if type(tok) ~= "string" or #tok > MAX_LINE then return nil end
        local prio = ns.ParsePrioToken(tok)
        if not prio then return nil end
        if type(note) ~= "string" or (note ~= "" and ns.CleanNote(note, NOTE_MAX) ~= note) or note:find("|", 1, true) then return nil end
        list[id] = { at = at, by = by ~= "" and by or nil, note = note, prio = prio }
    end
    if n ~= #tbl.l then return nil end
    return list
end

ns.CommOnBlob("LC", function(sender, tbl, chan, key)
    if not shareOn() then return end
    local name = ns.TrustName(sender)
    if not name then return end
    ns.TrustWait(name, "officer", function(ok)
        if not ok or not ns.InMyGroup(name) then
            stats.refused = stats.refused + 1
            return
        end
        local _, own = running()
        if own ~= key then return end
        local list = checkList(tbl)
        if not list then
            stats.refused = stats.refused + 1
            return
        end
        local p = store(true)
        if not p then return end
        p.shared = { from = name, at = time(), hash = hashOf(rowsOf(list)), lv = wanted[key], list = list }
        stats.taken = stats.taken + 1
        fire()
    end)
end)

function ns.LootPrioStats() return stats end

C_Timer.NewTicker(5, function()
    local ok, err = pcall(sendLV)
    if not ok then report(err) end
end)
ns.Listen("LOOT_PRIO", function()
    -- a change goes out with the next tick (at most every 10 s)
    if lastLV then lastLV.h = nil end
end)

---------------------------------------------------------------------------
-- Settings and the command
---------------------------------------------------------------------------
ns.RegisterSettings{ key = "prio", label = L["Loot-Prio"], order = 23, items = {
    { key = "prio.tooltip", type = "toggle", label = L["Loot-Prio im Item-Tooltip"], default = true,
      tip = L["Offiziere sehen ihre Liste, Raider die der Offiziere im Raid."] },
    { key = "prio.lootMark", type = "toggle", label = L["\"P\" auf den Würfelfenstern"], default = true,
      tip = L["P1, P2 ...: an dieser Stelle stehst du selbst."] },
    { key = "prio.share", type = "toggle", label = L["Loot-Prio im Raid teilen"], default = true,
      tip = L["Die Lootleitung schickt ihre Liste an alle Amisia-Clients im Raid. Angenommen wird sie nur von Offizieren der eigenen Gilde."] },
}}

ns.RegisterSlash("prio", { officer = true, args = L["[Item-Link|löschen]"], desc = L["Loot-Prio eines Items bearbeiten"],
    run = function(rest)
        rest = type(rest) == "string" and rest:match("^%s*(.-)%s*$") or ""
        local word = rest:lower()
        if word == "löschen" or word == "loeschen" or word == "clear" then -- l10n-ok: sub-words
            if not ns.IsOfficerView() then
                ns.msg(L["Loot-Prio bearbeiten nur Offiziere."])
                return
            end
            ns.ClearLootPrio()
            ns.msg(L["Prioliste gelöscht."])
            return
        end
        if ns.ItemID(rest) or tonumber(rest) then
            ns.ShowPrioDialog(rest)
            return
        end
        local info = ns.LootPrioInfo()
        if not info then
            ns.msg(L["Keine Prioliste geladen. Auf der Website: Loot Council, Copy for the addon; im Spiel: /amisia wuensche."])
            return
        end
        ns.msg(L["Prioliste vom %s: %d Items, %d eigene Änderungen, %d vom Raid."]:format(info.date or "-", info.n, info.edits, info.shared))
    end })
