-- Amisia awards: the book of what the master looter hands out, and how a hand-out gets in.
--
-- The book: every award has a fixed id (12 hex characters, unique in its raid) so the ledger
-- recognises the same award on a second import. A deleted award moves to s.gone as a tombstone
-- with deleted = epoch, so s.awards only ever holds living awards and the export can tell the
-- site what vanished. Every change fires DATA_CHANGED and lands on an undo stack of 20 steps that
-- lives until logout.
--
-- The hand-out: remembered when GiveMasterLoot runs and written as an award once the client
-- confirms it: the loot chat line for that player and item, or the loot slot being emptied.
-- Without confirmation it is dropped after a few seconds. Every loot slot keeps its own open
-- hand-out, so a second one before the first is confirmed does not push the first out. A hand-out
-- to the bank or disenchant character of the settings is written with to = "bank" or "de".
local ADDON, ns = ...

local GetItemInfo = C_Item.GetItemInfo

local VALID_KIND = { MS = true, OS = true, SR = true, ["-"] = true }
local VALID_TO = { player = true, bank = true, de = true }
local NOTE_MAX = 60
local UNDO_MAX = 20
local GONE = "Vergabe nicht mehr vorhanden."

local undo = {}   -- { op = "add"|"edit"|"delete"|"restore"|"rename", s, id, before = copy, item, name, ... }

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function copy(a)
    local c = {}
    for k, v in pairs(a) do c[k] = v end
    return c
end

-- Puts the fields of src into a, dropping what src does not have.
local function assign(a, src)
    for k in pairs(a) do a[k] = nil end
    for k, v in pairs(src) do a[k] = v end
end

-- A note without bars and line breaks, trimmed and cut to max bytes (default NOTE_MAX) without
-- splitting a character; nil when nothing is left.
local function cleanNote(text, max)
    if type(text) ~= "string" then return nil end
    max = tonumber(max) or NOTE_MAX
    text = text:gsub("[\r\n]+", " "):gsub("|", ""):match("^%s*(.-)%s*$")
    if #text > max then
        local cut = max
        -- a byte 10xxxxxx continues a character: step back to the character's start
        while cut > 0 do
            local b = text:byte(cut + 1)
            if not b or b < 0x80 or b >= 0xC0 then break end
            cut = cut - 1
        end
        text = text:sub(1, cut):match("^(.-)%s*$")
    end
    if text == "" then return nil end
    return text
end
ns.CleanNote = cleanNote

local function idUsed(s, id)
    for _, a in ipairs(s.awards or {}) do if a.id == id then return true end end
    for _, a in ipairs(s.gone or {}) do if a.id == id then return true end end
    return false
end

-- A new id: the time and a random part, rolled again while the raid already has it.
local function newId(s, t)
    local id
    repeat
        id = ("%08x%04x"):format(t % 4294967296, math.random(0, 65535))
    until not idUsed(s, id)
    return id
end

-- The id of an award from 1.4: the same raid, name, item and time give the same id on every load.
local function legacyId(s, a)
    local key = table.concat({ tostring(s.id), tostring(a.name), tostring(a.item), tostring(a.t) }, "\t")
    local id, n = ns.Checksum(key):sub(1, 12), 0
    while idUsed(s, id) do
        n = n + 1
        id = ns.Checksum(key .. "\t" .. n):sub(1, 12)
    end
    return id
end

local function alive(s)
    for _, o in ipairs(ns.Sessions()) do
        if o == s then return true end
    end
    return false
end

-- Attendance for an award: a name already in the raid's members, or (in the running recording)
-- in the group, is noted; any other name is left alone, so a typo does not invent a raider.
local function noteWinner(s, name, t)
    if s.members[name] or (s == ns.Active() and ns.InGroup(name)) then
        ns.NoteMember(s, name, nil, t)
        return true
    end
    return false
end

---------------------------------------------------------------------------
-- Quiet changes and the sync report
---------------------------------------------------------------------------
local quiet = 0   -- > 0 inside ns.AwardsQuiet

-- Runs fn(...) for a change applied on behalf of someone else (the sync): no undo step, no note in
-- the chat, no report to the sync. Returns what fn returns; an error is raised after the count is
-- set back.
function ns.AwardsQuiet(fn, ...)
    quiet = quiet + 1
    local res = { pcall(fn, ...) }
    quiet = quiet - 1
    if not res[1] then error(res[2], 0) end
    return unpack(res, 2, table.maxn(res))
end

function ns.AwardsIsQuiet() return quiet > 0 end

-- Reports a change to the sync (Sync.lua decides what it means).
local function report(op, s, info)
    if quiet == 0 and ns.SyncNote then ns.SyncNote(op, s, info) end
end

local function push(entry)
    if quiet > 0 then return end
    undo[#undo + 1] = entry
    while #undo > UNDO_MAX do table.remove(undo, 1) end
end

local function changed()
    ns.Fire("DATA_CHANGED")
end

---------------------------------------------------------------------------
-- The book
---------------------------------------------------------------------------
-- The award with this id: the award, its index and whether it lies among the tombstones.
function ns.FindAward(s, id)
    if not s or not id then return nil end
    for i, a in ipairs(s.awards or {}) do
        if a.id == id then return a, i, false end
    end
    for i, a in ipairs(s.gone or {}) do
        if a.id == id then return a, i, true end
    end
    return nil
end

-- A new award in raid s: { name, item, kind, src, t, to, note, manual }. A bank or disenchant
-- award has kind "-" and, without a receiver, the name "-".
function ns.AddAwardTo(s, f)
    if type(s) ~= "table" or type(s.awards) ~= "table" then
        return nil, "Keine Aufnahme: Vergaben werden nur in einer Raidinstanz mit Raidgruppe gespeichert."
    end
    f = f or {}
    local item = tonumber(f.item)
    local to = VALID_TO[f.to] and f.to or "player"
    local name = f.name
    if to ~= "player" and (type(name) ~= "string" or name == "") then name = "-" end
    if type(name) ~= "string" or name == "" or not item then return nil, "Name oder Item fehlt." end
    local t = tonumber(f.t) or time()
    local a = {
        id = newId(s, t), name = name, item = item, t = t,
        kind = (to == "player" and VALID_KIND[f.kind]) and f.kind or "-",
        src = (type(f.src) == "string" and f.src ~= "") and f.src or "?",
        to = to, note = cleanNote(f.note), manual = f.manual and true or nil,
    }
    s.gone = s.gone or {}
    s.awards[#s.awards + 1] = a
    if to == "player" and not noteWinner(s, name, t) and s == ns.Active() and quiet == 0 then
        ns.msg(("Hinweis: %s ist nicht in der Gruppe. Die Vergabe ist gespeichert, aber ohne Anwesenheit."):format(name))
    end
    if not ns.KnownItem(item) then
        local _, ilink, q = GetItemInfo(item)
        ns.RememberItem(item, ilink, q)
    end
    -- only the running recording moves on; an old raid must not become resumable
    if s == ns.Active() then
        s.last = t
        -- a trade good handed out in the raid joins the material list
        if ns.LearnMat then
            local _, ilink, q = GetItemInfo(item)
            ns.LearnMat(item, ilink, q)
        end
    end
    push({ op = "add", s = s, id = a.id })
    changed()
    report("add", s, { a = a })
    return a
end

-- Changes { name, kind, note, to } of a living award. A new name keeps the first one in orig;
-- bank or disenchant means kind "-".
function ns.EditAward(s, id, f)
    local a, _, inGone = ns.FindAward(s, id)
    if not a or inGone then return nil, GONE end
    f = f or {}
    local before = copy(a)
    if f.to ~= nil and VALID_TO[f.to] then a.to = f.to end
    if a.to ~= "player" then
        a.kind = "-"
    elseif f.kind ~= nil and VALID_KIND[f.kind] then
        a.kind = f.kind
    end
    if f.name ~= nil then
        local name = ns.FullName(f.name)
        -- the bank or the disenchanter may go without a receiver, written as "-"
        if not name and a.to ~= "player" then name = "-" end
        if not name then
            assign(a, before)
            return nil, "Name oder Item fehlt."
        end
        if name ~= a.name then
            a.orig = a.orig or a.name
            a.name = name
            if a.to == "player" then noteWinner(s, name, a.t) end
        end
    end
    -- a player needs a name: back from the bank without a receiver is refused
    if a.to == "player" and a.name == "-" then
        assign(a, before)
        return nil, "Name oder Item fehlt."
    end
    if f.note ~= nil then a.note = cleanNote(f.note) end
    local same = true
    for k, v in pairs(a) do if before[k] ~= v then same = false end end
    for k, v in pairs(before) do if a[k] ~= v then same = false end end
    if same then return a end
    a.edited = time()
    push({ op = "edit", s = s, id = id, before = before })
    changed()
    local fields = {}
    for _, k in ipairs({ "name", "kind", "note", "to" }) do
        if a[k] ~= before[k] then fields[k] = a[k] == nil and false or a[k] end
    end
    report("edit", s, { id = id, fields = fields })
    return a
end

-- Takes a living award out of the raid; it stays as a tombstone in s.gone.
local function remove(s, id)
    local a, i, inGone = ns.FindAward(s, id)
    if not a or inGone then return nil end
    table.remove(s.awards, i)
    a.deleted = time()
    s.gone = s.gone or {}
    s.gone[#s.gone + 1] = a
    return a
end

-- Brings a tombstone back into s.awards, in order of its time.
local function revive(s, id)
    local a, i, inGone = ns.FindAward(s, id)
    if not a or not inGone then return nil end
    table.remove(s.gone, i)
    a.deleted = nil
    local pos = #s.awards + 1
    for j, o in ipairs(s.awards) do
        if (o.t or 0) > (a.t or 0) then pos = j break end
    end
    table.insert(s.awards, pos, a)
    return a
end

function ns.DeleteAward(s, id)
    local a = remove(s, id)
    if not a then return nil, GONE end
    push({ op = "delete", s = s, id = id })
    changed()
    report("delete", s, { id = id })
    return a
end

function ns.RestoreAward(s, id)
    local a = revive(s, id)
    if not a then return nil, GONE end
    push({ op = "restore", s = s, id = id })
    changed()
    report("restore", s, { id = id })
    return a
end

-- Renames every living award of raid s from one name to another, as one undo step.
function ns.RenameAwards(s, from, to)
    to = ns.FullName(to)
    if not s or not to or type(from) ~= "string" or from == to then return 0 end
    local before, t = {}, time()
    for _, a in ipairs(s.awards or {}) do
        if a.name == from then
            before[#before + 1] = copy(a)
            a.orig = a.orig or a.name
            a.name = to
            a.edited = t
        end
    end
    if #before == 0 then return 0 end
    noteWinner(s, to, t)
    push({ op = "rename", s = s, before = before, from = from, to = to })
    changed()
    local ids = {}
    for i, b in ipairs(before) do ids[i] = b.id end
    report("rename", s, { from = from, to = to, ids = ids })
    return #before
end

-- Members of raid s that may be meant by a name not among them: the same character by
-- ns.SameName or the same first name, sorted. A name that is a member needs no suggestion.
function ns.NameSuggestions(s, name)
    local out = {}
    name = ns.FullName(name)
    if not s or not name then return out end
    local lower = name:lower()
    for m in pairs(s.members or {}) do
        if m:lower() == lower then return {} end
    end
    local first = name:match("^(%S+)"):lower()
    for m in pairs(s.members or {}) do
        if ns.SameName(m, name) or m:match("^(%S+)"):lower() == first then out[#out + 1] = m end
    end
    table.sort(out)
    return out
end

-- "bank" or "de" when the name is the bank or disenchant character of the settings.
function ns.IsSpecialName(name)
    if type(name) ~= "string" or name == "" then return nil end
    local bank, de = ns.Get("awards.bankName"), ns.Get("awards.deName")
    if type(bank) == "string" and bank ~= "" and ns.SameName(name, bank) then return "bank" end
    if type(de) == "string" and de ~= "" and ns.SameName(name, de) then return "de" end
    return nil
end

---------------------------------------------------------------------------
-- Undo
---------------------------------------------------------------------------
local VERB = { add = "Hinzufügen", edit = "Ändern", delete = "Löschen", restore = "Wiederherstellen" }

local function label(e)
    if e.op == "rename" then
        return ("Umbenennen von %s in %s (%d)"):format(e.from, e.to, #e.before)
    end
    local a = ns.FindAward(e.s, e.id)
    local b = a or (e.before) or {}
    return ("%s von %s an %s"):format(VERB[e.op] or e.op, ns.ItemName(b.item), tostring(b.name or "?"))
end

-- Whether step e can still be taken back: its raid exists and its award is where the step left it.
local function doable(e)
    if not alive(e.s) then return false end
    if e.op == "rename" then
        for _, b in ipairs(e.before) do
            local a, _, inGone = ns.FindAward(e.s, b.id)
            if a and not inGone then return true end
        end
        return false
    end
    local a, _, inGone = ns.FindAward(e.s, e.id)
    if not a then return false end
    if e.op == "delete" then return inGone end
    return not inGone
end

-- What the next undo would take back, or nil. Steps undo would skip are skipped here as well.
function ns.UndoLabel()
    for i = #undo, 1, -1 do
        if doable(undo[i]) then return label(undo[i]) end
    end
    return nil
end

-- Takes back the last change. A step whose raid or award no longer exists is skipped.
function ns.UndoAward()
    while #undo > 0 do
        local e = table.remove(undo)
        if doable(e) then
            local text = label(e)
            local done
            -- every step goes to the sync as the change it makes
            local reports = {}
            local function all(a) return { name = a.name, kind = a.kind, note = a.note == nil and false or a.note, to = a.to } end
            if e.op == "add" or e.op == "restore" then
                done = remove(e.s, e.id)
                if done then reports[1] = { "delete", { id = e.id } } end
            elseif e.op == "delete" then
                done = revive(e.s, e.id)
                if done then reports[1] = { "restore", { id = e.id } } end
            elseif e.op == "edit" then
                local a, _, inGone = ns.FindAward(e.s, e.id)
                if a and not inGone then
                    -- the revision of the sync is no part of the step taken back
                    local v = a.v
                    assign(a, e.before)
                    a.v = v
                    -- stamped anew, so the site takes the reverted award as the newer state
                    a.edited = time()
                    done = a
                    reports[1] = { "edit", { id = e.id, fields = all(a) } }
                end
            elseif e.op == "rename" then
                for _, b in ipairs(e.before) do
                    local a, _, inGone = ns.FindAward(e.s, b.id)
                    if a and not inGone then
                        local v = a.v
                        assign(a, b)
                        a.v = v
                        a.edited = time()
                        done = a
                        reports[#reports + 1] = { "edit", { id = b.id, fields = all(a) } }
                    end
                end
            end
            if done then
                changed()
                for _, r in ipairs(reports) do report(r[1], e.s, r[2]) end
                return text
            end
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- The move of 1.4 data: ids and to for every award, tombstone lists, and the export marks
-- carried over so an exported raid stays "done" instead of turning "changed".
---------------------------------------------------------------------------
function ns.MigrateAwards(DB)
    if (tonumber(DB.awardsVersion) or 0) >= 1 then return end
    DB.sessions = DB.sessions or {}
    DB.exported = DB.exported or {}
    -- 1. which raids were exported as they are, by the old form of the fingerprint
    local matched = {}
    for _, s in ipairs(DB.sessions) do
        local e = DB.exported[s.id]
        if e and e.h == ns.SessionHash(s, true) then matched[#matched + 1] = s end
    end
    -- 2. ids and targets
    for _, s in ipairs(DB.sessions) do
        s.gone = s.gone or {}
        for _, a in ipairs(s.awards or {}) do
            if type(a.id) ~= "string" then a.id = legacyId(s, a) end
            if not VALID_TO[a.to] then a.to = "player" end
        end
    end
    -- 3. the new fingerprint for what was exported
    for _, s in ipairs(matched) do
        DB.exported[s.id].h = ns.SessionHash(s)
    end
    -- 4.
    DB.awardsVersion = 1
end

---------------------------------------------------------------------------
-- Plus-one: mainspec wins of a player in this raid or this ID week. Only living awards to a
-- player with kind MS count; SR, OS, bank and disenchant do not.
---------------------------------------------------------------------------
-- The raid with the latest start, the running recording included.
local function newestSession()
    local best
    for _, s in ipairs(ns.Sessions()) do
        if not best or (s.start or 0) > (best.start or 0) then best = s end
    end
    return best
end

-- Start of the ID week: a week before the next weekly reset, or nil when the client cannot say.
local function weekStart()
    local api = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
    if type(api) ~= "function" then return nil end
    local left = api()
    if type(left) ~= "number" then return nil end
    return time() + left - 7 * 86400
end

-- The raids a scope covers and the scope that applied: "week" falls back to "raid" when the
-- client does not know the weekly reset.
local function plusSessions(scope)
    scope = scope or ns.Get("awards.plusScope")
    if scope == "week" then
        local from = weekStart()
        if from then
            local out = {}
            for _, s in ipairs(ns.Sessions()) do
                if (s.start or 0) >= from then out[#out + 1] = s end
            end
            return out, "week"
        end
    end
    local s = ns.Active() or newestSession()
    return { s }, "raid"
end

-- The scope the plus-one counts in right now: "raid" or "week".
function ns.PlusScope()
    local _, scope = plusSessions()
    return scope
end

local function plusAward(a)
    return a.kind == "MS" and (a.to == nil or a.to == "player")
end

function ns.PlusCount(name, scope)
    if not ns.FullName(name) then return 0 end
    local n = 0
    for _, s in ipairs((plusSessions(scope))) do
        for _, a in ipairs(s and s.awards or {}) do
            if plusAward(a) and ns.SameName(a.name, name) then n = n + 1 end
        end
    end
    return n
end

-- Everyone with a plus-one in the scope: { { name, n } }, most first, then by name. Spellings of
-- one character (with and without surname) are counted together under the first one seen.
function ns.PlusList(scope)
    local out, sessions = {}, plusSessions(scope)
    for _, s in ipairs(sessions) do
        for _, a in ipairs(s and s.awards or {}) do
            if plusAward(a) then
                local hit
                for _, e in ipairs(out) do
                    if ns.SameName(e.name, a.name) then hit = e break end
                end
                if hit then hit.n = hit.n + 1 else out[#out + 1] = { name = a.name, n = 1 } end
            end
        end
    end
    table.sort(out, function(x, y)
        if x.n ~= y.n then return x.n > y.n end
        return x.name < y.name
    end)
    return out
end

local SCOPE_TEXT = { raid = "dieser Raid", week = "diese ID-Woche" }

-- "/amisia plus [Name]": the plus-one of everyone in the scope, or of one name.
local function plusCommand(rest)
    local name = ns.FullName(rest)
    local _, scope = plusSessions()
    if name then
        ns.msg(("Plus-Eins von %s (%s): %d."):format(name, SCOPE_TEXT[scope], ns.PlusCount(name)))
        return
    end
    local list, parts = ns.PlusList(), {}
    for _, e in ipairs(list) do parts[#parts + 1] = ("%s %d"):format(e.name, e.n) end
    if #parts == 0 then
        ns.msg(("Plus-Eins (%s): noch niemand."):format(SCOPE_TEXT[scope]))
    else
        ns.msg(("Plus-Eins (%s): %s."):format(SCOPE_TEXT[scope], table.concat(parts, ", ")))
    end
end

ns.RegisterSlash("plus", { officer = true, args = "[Name]", desc = "Plus-Eins der Gewinner im Chat", run = plusCommand })

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
-- A character name: no digits, at most one space (a Forever surname); empty switches it off.
local function validName(v)
    local name = ns.FullName(v)
    if not name then return "" end
    if name:find("%d") then return nil end
    if select(2, name:gsub(" ", "")) > 1 then return nil end
    return name
end

ns.RegisterSettings{ key = "awards", label = "Vergaben", order = 25, officer = true, items = {
    { key = "awards.plusScope", type = "choice", label = "Plus-Eins zählt", default = "raid",
      values = { { "raid", "Dieser Raid" }, { "week", "Diese ID-Woche" } },
      tip = "Wie weit die Mainspec-Gewinne eines Spielers zurückgezählt werden. Kennt der Client die Zeit bis zum wöchentlichen Reset nicht, zählt nur dieser Raid." },
    { key = "awards.plusOrder", type = "toggle", label = "Plus-Eins in der Roll-Reihenfolge", default = false,
      tip = "Weniger Plus-Eins gewinnt vor dem höheren Wurf, nur bei Mainspec." },
    { key = "awards.modClick", type = "toggle", label = "Alt+Shift-Klick auf ein Item öffnet die Vergabe", default = true },
    { key = "awards.bankName", type = "text", label = "Bank-Charakter", default = "", validate = validName,
      tip = "Master Loot an diesen Namen zählt als Bank.", invalid = "Name ohne Ziffern, höchstens ein Leerzeichen." },
    { key = "awards.deName", type = "text", label = "Entzauberer", default = "", validate = validName,
      tip = "Master Loot an diesen Namen zählt als Entzaubern.", invalid = "Name ohne Ziffern, höchstens ein Leerzeichen." },
}}

---------------------------------------------------------------------------
-- Hand-outs through master loot
---------------------------------------------------------------------------
local PENDING_TTL = 5
local pending = {}   -- loot slot -> { slot, name, item, link, src, t, token, kind, note }
local lastSlot       -- slot of the latest hand-out

-- The open hand-out of a loot slot, or of the latest hand-out when no slot is given.
function ns.PendingAward(slot) return pending[slot or lastSlot or 0] end

-- Short name without the realm part.
local function shortName(name)
    return ns.FullName(name)
end

-- Name of what a loot slot came from: the drop recorded for its source, else the current target.
function ns.LootSourceName(slot)
    local s = ns.Active()
    local guid = (slot and slot > 0 and GetLootSourceInfo) and GetLootSourceInfo(slot) or nil
    if s and guid and s.drops[guid] and s.drops[guid].src ~= "?" then return s.drops[guid].src end
    local target = UnitName("target")
    if target and (not guid or guid == (UnitGUID and UnitGUID("target"))) then return target end
    return "?"
end

local TO_TEXT = { bank = "an die Bank (%s)", de = "zum Entzaubern (%s)" }

local function commit(a)
    local to = ns.IsSpecialName(a.name) or "player"
    local kind = "-"
    if to == "player" then
        kind = a.kind or (ns.RollKind and ns.RollKind(a.item, a.name)) or "-"
    end
    local ok, why = ns.AddAwardTo(ns.Active(), { name = a.name, item = a.item, kind = kind, src = a.src, t = time(), to = to, note = a.note })
    if ok then
        local item = a.link or ("Item " .. a.item)
        if to == "player" then
            ns.msg(("Vergabe gespeichert: %s an %s (%s)."):format(item, a.name, kind))
        else
            ns.msg(("Vergabe gespeichert: %s %s."):format(item, TO_TEXT[to]:format(a.name)))
        end
    elseif why then
        ns.msg(why)
    end
end

local function onGive(slot, candidate)
    local link = GetLootSlotLink and GetLootSlotLink(slot)
    local id = ns.ItemID(link)
    local name = shortName(GetMasterLootCandidate and GetMasterLootCandidate(slot, candidate))
    if not id or not name then return end
    local token = {}
    -- a new hand-out of the same slot replaces the old one: that one never arrived
    pending[slot] = { slot = slot, name = name, item = id, link = link, src = ns.LootSourceName(slot), t = time(), token = token }
    lastSlot = slot
    C_Timer.After(PENDING_TTL, function()
        if pending[slot] and pending[slot].token == token then pending[slot] = nil end
    end)
end

if type(GiveMasterLoot) == "function" then
    hooksecurefunc("GiveMasterLoot", onGive)
end

ns.OnEvent("CHAT_MSG_LOOT", function(text)
    if not next(pending) then return end
    local who, id = ns.ParseLoot(text)
    who = shortName(who)
    if not who then return end
    -- the oldest open hand-out of that item to that player: two copies of one token leave in order
    local found
    for _, a in pairs(pending) do
        if a.name == who and a.item == id and (not found or a.t < found.t or (a.t == found.t and a.slot < found.slot)) then
            found = a
        end
    end
    if found then
        pending[found.slot] = nil
        commit(found)
    end
end)

ns.OnEvent("LOOT_SLOT_CLEARED", function(slot)
    local a = slot and pending[slot]
    if a then
        pending[slot] = nil
        commit(a)
    end
end)

ns.OnEvent("LOOT_CLOSED", function() wipe(pending) end)

---------------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------------
-- "/amisia award <Name|bank|de> <Item-Link oder ID> [ms|os|sr]" and "/amisia unaward"; without
-- anything the award dialog opens.
local SPECIAL_TO = { bank = "bank", de = "de" }
local SPECIAL_TEXT = { bank = "an die Bank", de = "zum Entzaubern" }

function ns.AwardCommand(rest)
    rest = (rest or ""):match("^%s*(.-)%s*$")
    if rest:lower() == "unaward" then
        local a = ns.RemoveLastAward()
        ns.msg(a and ("Vergabe entfernt: Item %d an %s. /amisia undo holt sie zurück."):format(a.item, a.name) or "Keine Vergabe in der laufenden Aufnahme.")
        return
    end
    if rest == "" and ns.ShowAwardDialog then
        ns.ShowAwardDialog(nil, ns.Active())
        return
    end
    -- the name runs up to the item link or the item id, so a Forever surname fits
    local name, tail = rest:match("^(.-)%s*(|c.*)$")
    if not name then name, tail = rest:match("^(%D-)%s+(%d.*)$") end
    if not name then name, tail = rest:match("^(%S+)%s*(.*)$") end
    if not name or name == "" then
        ns.msg("Aufruf: /amisia award <Name> <Item-Link oder ID> [ms|os|sr]")
        return
    end
    local id = ns.ItemID(tail) or tonumber(tail:match("^(%d+)"))
    if not id then
        ns.msg("Item fehlt: Link einfügen oder Item-ID angeben.")
        return
    end
    local kind = (tail:match("%s(%a%a)%s*$") or ""):upper()
    if kind ~= "MS" and kind ~= "OS" and kind ~= "SR" then kind = "-" end
    local to = SPECIAL_TO[name:lower()]
    local ok, why = ns.AddAwardTo(ns.Active(), { name = to and "-" or shortName(name), item = id, kind = to and "-" or kind,
        src = ns.LootSourceName(0), t = time(), to = to, manual = true })
    if not ok then
        ns.msg(why)
    elseif to then
        ns.msg(("Vergabe gespeichert: Item %d %s."):format(id, SPECIAL_TEXT[to]))
    else
        ns.msg(("Vergabe gespeichert: Item %d an %s (%s)."):format(id, shortName(name), kind))
    end
end

ns.RegisterSlash("award", { officer = true, args = "<Name|bank|de> <Item-Link|ID> [ms|os|sr]", desc = "Vergabe von Hand eintragen, ohne Angaben öffnet der Dialog",
    run = function(rest) ns.AwardCommand(rest) end })
ns.RegisterSlash("unaward", { officer = true, desc = "letzte Vergabe zurücknehmen", run = function() ns.AwardCommand("unaward") end })
ns.RegisterSlash("rueckgaengig", { aliases = { "undo" }, officer = true, desc = "letzte Änderung an Vergaben zurücknehmen", run = function()
    local text = ns.UndoAward()
    ns.msg(text and ("Rückgängig: %s."):format(text) or "Nichts rückgängig zu machen.")
end })
