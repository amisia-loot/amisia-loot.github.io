-- Amisia loot rules: the master looter's small loot goes out by fixed rules (spec
-- docs/specs/2026-10-08-loot-abend.md, part 2; DECISIONS D-37). An officer keeps an ordered list of
-- rules in the settings ("Lootregeln"); the first rule that matches an item wins:
--   q  quality up to uncommon or rare  -> bank or disenchanter
--   m  the learned raid materials       -> bank or disenchanter
--   i  a list of named items            -> bank or disenchanter
--   p  one named item                   -> one player
-- When the master looter (officer rank and officer view, master loot, a running recording) opens a
-- corpse, the rules hand the items out by GiveMasterLoot one second later ("automatisch", the
-- default) or on a click on the bar beside the loot window ("Ein Klick"). Every hand-out becomes a
-- normal award through Awards.lua with the note "Regel: <rule>", and the loot lead says in one raid
-- chat line what the rules gave. Nothing happens without rules (a fresh install has none), while
-- paused, in combat or the encounter lockdown (the run waits for ADDON_RESTRICTION_STATE_CHANGED),
-- or for an item that is soft-reserved by someone in the raid, has a loot prio, is on a raider's
-- guild wishlist, got an upgrade or wish answer, has a roll or points round, or is legendary.
-- "/amisia regeln probe" tells what the rules would do and gives nothing.
--
-- Sharing between officers (Comm.lua checks the fields):
--   MR <rev> <part> <parts> <set by> <id:kind:value:target,...|->  a rule set in at most 4 parts
--   MQ <rev>   "who has a newer set?" once after the login; an officer whose sent set is newer
--              answers with MR by whisper
-- A received set is only an offer: it counts once an officer takes it over ("Übernehmen").
-- Stored in AmisiaDB.lootRules = { v = 1, rev, by, at, sent, seen, list = { rule... },
-- offer = { from, rev, at, list } }.
local ADDON, ns = ...
local L = ns.L
local W, T = ns.W, ns.Theme

local MAX_RULES = 30
local MAX_ITEMS = 50
local MAX_PARTS = 4
local PER_PART = 6            -- rule entries in one MR message
local IDS_PER_ENTRY = 16      -- item ids of a list rule in one entry (a longer list takes more entries)
local PART_BYTES = 236        -- an MR message stays below Comm.lua's 250 bytes
local PART_WAIT = 30          -- seconds a set waits for its missing parts
local OFFER_GAP = 30          -- a new set from one officer at most this often
local FUTURE = 86400          -- a received revision may run this far ahead of the own clock
local ASK_AFTER, ASK_SPREAD = 35, 20
local AUTO_DELAY = 1          -- seconds after the loot window opens ("automatisch")
local NEED_WAIT, NEED_TRIES = 3, 2   -- an open "Wer braucht das?" question holds the run this long
local CORPSE_KEEP = 12 * 3600
local NOTE_MARK = "Regel: "   -- l10n-ok: the fixed marker of a rule's award note (data, read on the site)
local MASTER = (Enum and Enum.LootMethod and Enum.LootMethod.Masterlooter) or 2
local KINDS = { q = true, m = true, i = true, p = true }
local SPECIAL = { bank = true, de = true }

local DB                      -- AmisiaDB
local lootOpen, fromItem, serial = false, false, 0
local given, failed = {}, {}  -- loot slot -> link: handed out / left lying in this loot window
local givenList = {}          -- the plan entries the rules gave in this loot window (the bar in automatic mode)
local waiting                 -- { serial, manual }: a run held by combat or the lockdown
local waitTold                -- serial of the window whose waiting was told
local told = {}               -- raid id -> true: "Lootregeln aktiv" was said
local incoming = {}           -- sender (lower case) -> { rev, n, parts, got, by, at }
local offerAt = {}            -- sender (lower case) -> GetTime() of its last finished set
local counter = 0
-- kept on ns, so a second load of this file (the tests' /reload) shares it
ns.lootRulesDone = ns.lootRulesDone or {}   -- corpse key -> time(): the rules ran on it

local function msg(text) if ns.msg then ns.msg(text) end end
local function now() return math.floor(time()) end
local function me() return ns.UnitFullName("player") or "?" end
local function changed()
    ns.Fire("LOOT_RULES")
    if ns.Refresh then ns.Refresh() end
end

---------------------------------------------------------------------------
-- The saved rules, checked field by field
---------------------------------------------------------------------------
local function itemId(v)
    v = tonumber(v)
    if not v or v < 1 or v > 9999999 or v % 1 ~= 0 then return nil end
    return v
end

-- A player's name for a rule: a full name without digits, bars or separators, at most one space;
-- never the words bank and de.
local function playerName(v)
    local name = ns.FullName(type(v) == "string" and v:gsub("_", " ") or nil)
    if not name or #name > 48 or name:find("[%d%c|,:+]") or select(2, name:gsub(" ", "")) > 1 then return nil end
    if SPECIAL[name:lower()] then return nil end
    return name
end

local function cleanBy(v)
    if type(v) ~= "string" or v == "" or #v > 60 or v:find("[%c|]") then return nil end
    return v
end

local function cleanItems(list, max)
    local out, set = {}, {}
    if type(list) ~= "table" then return out end
    for _, x in ipairs(list) do
        local id = itemId(x)
        if id and not set[id] and #out < max then
            set[id] = true
            out[#out + 1] = id
        end
    end
    return out
end

-- A rule in shape, or nil: { id = 4 hex, k, q (2 or 3, kind q), items (kinds i and p), to, by }.
local function cleanRule(r)
    if type(r) ~= "table" or not KINDS[r.k] then return nil end
    local id = type(r.id) == "string" and r.id:match("^%x%x%x%x$") and r.id:lower()
    if not id then return nil end
    local out = { id = id, k = r.k, by = cleanBy(r.by) }
    if r.k == "p" then
        out.items = cleanItems(r.items, 2)
        out.to = playerName(r.to)
        if #out.items ~= 1 or not out.to then return nil end
        return out
    end
    if not SPECIAL[r.to] then return nil end
    out.to = r.to
    if r.k == "q" then
        out.q = tonumber(r.q)
        if out.q ~= 2 and out.q ~= 3 then return nil end
    elseif r.k == "i" then
        out.items = cleanItems(r.items, MAX_ITEMS)
        if #out.items == 0 then return nil end
    end
    return out
end

local function cleanList(list)
    local out, ids = {}, {}
    if type(list) ~= "table" then return out end
    for _, r in ipairs(list) do
        local c = cleanRule(r)
        if c and not ids[c.id] and #out < MAX_RULES then
            ids[c.id] = true
            out[#out + 1] = c
        end
    end
    return out
end

local function epoch(v, ahead)
    v = tonumber(v)
    if not v or v < 0 or v % 1 ~= 0 or v > now() + (ahead or FUTURE) then return nil end
    return v
end

-- On ADDON_LOADED (and in tests): the saved rules in shape.
function ns.LootRulesLoaded(root)
    DB = root
    local r = type(root.lootRules) == "table" and root.lootRules or {}
    local out = { v = 1, rev = epoch(r.rev) or 0, by = cleanBy(r.by), at = epoch(r.at), sent = epoch(r.sent),
                  seen = epoch(r.seen), list = cleanList(r.list) }
    local o = r.offer
    if type(o) == "table" and cleanBy(o.from) and epoch(o.rev) then
        out.offer = { from = o.from, rev = o.rev, at = epoch(o.at) or now(), list = cleanList(o.list) }
    end
    root.lootRules = out
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name == ADDON and AmisiaDB then ns.LootRulesLoaded(AmisiaDB) end
end)

-- The saved rules: { v, rev, by, at, sent, seen, list, offer }.
function ns.LootRules()
    if not DB then return { v = 1, rev = 0, list = {} } end
    return DB.lootRules
end

---------------------------------------------------------------------------
-- Words for a rule
---------------------------------------------------------------------------
local QUALITY_WORD = { [2] = L["Ungewöhnlich"], [3] = L["Selten"] }

local function targetWord(to)
    if to == "bank" then return L["Bank##Ziel"] end
    if to == "de" then return L["Entzaubern"] end
    return to
end

-- What a rule takes, without its target: "Qualität bis Selten", "Raidmaterialien", "3 Items".
local function whatText(r)
    if r.k == "q" then return L["Qualität bis %s"]:format(QUALITY_WORD[r.q] or "?") end
    if r.k == "m" then return L["Raidmaterialien"] end
    if #r.items == 1 then return ns.ItemName(r.items[1]) end
    return L["%d Items"]:format(#r.items)
end

-- "Qualität bis Selten -> Entzaubern"
function ns.LootRuleLabel(r)
    return ("%s -> %s"):format(whatText(r), targetWord(r.to))
end

-- The name a rule gives to now, or nil and why not (the bank or disenchanter name is missing).
local function targetName(r)
    if r.to == "bank" or r.to == "de" then
        local name = ns.Get(r.to == "bank" and "awards.bankName" or "awards.deName")
        if type(name) ~= "string" or name == "" then
            return nil, r.to == "bank" and L["Bank-Charakter fehlt (Einstellungen, Vergaben)"]
                or L["Entzauberer fehlt (Einstellungen, Vergaben)"]
        end
        return name
    end
    return r.to
end

-- What keeps a rule from working: the missing bank or disenchanter name; nil when nothing.
function ns.LootRuleProblem(r)
    local _, why = targetName(r)
    return why
end

---------------------------------------------------------------------------
-- Editing (officers)
---------------------------------------------------------------------------
local function touch()
    local lr = ns.LootRules()
    lr.rev = math.max(now(), (lr.rev or 0) + 1)
    lr.by, lr.at = me(), now()
    changed()
end

local function newRuleId(lr)
    local used = {}
    for _, r in ipairs(lr.list) do used[r.id] = true end
    if lr.offer then for _, r in ipairs(lr.offer.list) do used[r.id] = true end end
    for _ = 1, 100 do
        counter = counter + 1
        local id = ns.Checksum(me() .. ":" .. now() .. ":" .. counter .. ":" .. GetTime()):sub(1, 4)
        if not used[id] then return id end
    end
    return nil
end

-- The item ids in a text: links and bare numbers, in order, each once.
function ns.LootRuleItems(text)
    local out = {}
    if type(text) ~= "string" then return out end
    -- a link stands for its item id; colour codes and the link's name are left out
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|Hitem:(%d+)[^|]*|h.-|h", " %1 ")
    for id in text:gmatch("(%d+)") do out[#out + 1] = id end
    return cleanItems(out, MAX_ITEMS + 1)
end

-- Adds a rule at the end: { k, q, items, to }. Returns the rule, or nil and why.
function ns.AddLootRule(spec)
    if not DB then return nil, L["Amisia ist noch nicht geladen."] end
    if not ns.IsOfficerView() then return nil, L["Lootregeln setzen nur Offiziere."] end
    spec = type(spec) == "table" and spec or {}
    local lr = ns.LootRules()
    if #lr.list >= MAX_RULES then return nil, L["Höchstens %d Regeln."]:format(MAX_RULES) end
    if not KINDS[spec.k] then return nil, L["Unbekannte Regelart."] end
    local items = spec.items
    if type(items) == "string" then items = ns.LootRuleItems(items) end
    if spec.k == "i" or spec.k == "p" then
        items = cleanItems(items, MAX_ITEMS + 1)
        if #items == 0 then return nil, L["Kein Item erkannt: Link einfügen oder Item-ID angeben."] end
        if #items > MAX_ITEMS then return nil, L["Höchstens %d Items pro Liste."]:format(MAX_ITEMS) end
        if spec.k == "p" and #items > 1 then return nil, L["Eine Spieler-Regel gilt für genau ein Item."] end
    end
    if spec.k == "p" and not playerName(spec.to) then return nil, L["Name fehlt oder ist ungültig."] end
    local id = newRuleId(lr)
    if not id then return nil, L["Ungültiger Wert."] end
    local r = cleanRule({ id = id, k = spec.k, q = spec.q, items = items, to = spec.to, by = me() })
    if not r then return nil, L["Ungültiger Wert."] end
    lr.list[#lr.list + 1] = r
    touch()
    return r
end

local function findRule(id)
    for i, r in ipairs(ns.LootRules().list) do
        if r.id == id then return r, i end
    end
end

function ns.RemoveLootRule(id)
    local _, i = findRule(id)
    if not i or not ns.IsOfficerView() then return false end
    table.remove(ns.LootRules().list, i)
    touch()
    return true
end

-- Moves a rule one place up (dir -1) or down (dir 1).
function ns.MoveLootRule(id, dir)
    local list = ns.LootRules().list
    local _, i = findRule(id)
    local j = i and i + (dir or -1)
    if not i or not ns.IsOfficerView() or j < 1 or j > #list then return false end
    list[i], list[j] = list[j], list[i]
    touch()
    return true
end

---------------------------------------------------------------------------
-- Who may apply rules, and when
---------------------------------------------------------------------------
-- master loot, and whether this client is the master looter
local function masterLoot()
    local info = _G.C_PartyInfo
    if type(info) ~= "table" or type(info.GetLootMethod) ~= "function" then return false, false end
    local ok, method, partyID, raidID = pcall(info.GetLootMethod)
    if not ok then return false, false end
    method, partyID, raidID = ns.Plain(method), ns.Plain(partyID), ns.Plain(raidID)
    if method ~= MASTER then return false, false end
    if raidID then return true, UnitIsUnit("raid" .. raidID, "player") and true or false end
    return true, partyID == 0
end

-- Why the rules do nothing here, or nil when this client applies them.
local function whyNot()
    local lr = ns.LootRules()
    if ns.Get("lootrules.paused") then return L["Lootregeln pausiert."] end
    if #lr.list == 0 then return L["Keine Lootregeln angelegt."] end
    if not IsInRaid() then return L["Lootregeln nur im Raid."] end
    local master, mine = masterLoot()
    if not master then return L["Kein Master Loot: Lootregeln wirken nur unter Master Loot."] end
    if not mine then return L["Du bist nicht der Plündermeister."] end
    if not ns.IsOfficerView() then return L["Lootregeln nur in der Offiziersansicht."] end
    if not ns.SelfIsOfficer() then return L["Lootregeln nur mit Offiziersrang."] end
    if not ns.Active() then return L["Keine Aufnahme: Vergaben werden nur in einer Raidinstanz mit Raidgruppe gespeichert."] end
    if type(GiveMasterLoot) ~= "function" or type(GetMasterLootCandidate) ~= "function" then
        return L["Master Loot ist auf diesem Client nicht verfügbar."]
    end
    return nil
end
ns.LootRulesWhyNot = whyNot

local function restrictionOn(kind)
    local api = _G.C_RestrictedActions
    local fn = type(api) == "table" and api.IsAddOnRestrictionActive
    if type(fn) ~= "function" then return false end
    local ok, on = pcall(fn, kind)
    return ok and ns.Plain(on) == true
end

-- Combat or the addon restriction of combat or an encounter: GiveMasterLoot waits.
local function blocked()
    if InCombatLockdown() then return true end
    local R = _G.Enum and Enum.AddOnRestrictionType or {}
    return restrictionOn(R.Combat or 0) or restrictionOn(R.Encounter or 1)
end

---------------------------------------------------------------------------
-- What the rules do with an item
---------------------------------------------------------------------------
local function matches(r, id, q)
    if r.k == "q" then return q ~= nil and q <= r.q end
    if r.k == "m" then return ns.MATS[id] ~= nil end
    for _, x in ipairs(r.items) do
        if x == id then return true end
    end
    return false
end

local function pointsRaid()
    local p = ns.PointsSession and ns.PointsSession(ns.Active())
    return p ~= nil and (p.sys == "dkp" or p.sys == "epgp")
end

-- Why no rule may touch an item (the normal way takes it), or nil: legendary, reserved by someone
-- in the raid, a loot prio, a raider's guild wish, an upgrade or wish answer, a roll round.
function ns.LootRuleGuard(id, q)
    if q and q >= 5 then return L["legendär"] end
    for _, name in ipairs(ns.ReservedBy and ns.ReservedBy(id) or {}) do
        if ns.InMyGroup(name) then return L["reserviert"] end
    end
    if ns.LootPrioOf and ns.LootPrioOf(id) then return L["Loot-Prio"] end
    if ns.WishersOf and #ns.WishersOf(id, true) > 0 then return L["Gildenwunsch"] end
    local need = ns.NeedOf and ns.NeedOf(id)
    if need and (#need.up > 0 or #need.wish > 0) then return L["Upgrade oder Wunsch gemeldet"] end
    if ns.RoundsOf and #ns.RoundsOf(id) > 0 then return L["Roll-Runde"] end
    return nil
end

-- One item through the rules: { rule, index, name } when a rule gives it, else { why }.
local function decide(id, q)
    if q and q >= 5 then return { why = L["legendär"] } end
    local list = ns.LootRules().list
    local rule, index
    for i, r in ipairs(list) do
        if matches(r, id, q) then rule, index = r, i break end
    end
    if not rule then return { why = L["keine Regel"] } end
    local guard = ns.LootRuleGuard(id, q)
    if guard then return { why = guard, rule = rule, index = index, blocked = true } end
    if rule.k == "p" and pointsRaid() then return { why = L["Punkte-Raid: Spieler-Regeln ruhen"], rule = rule, index = index, blocked = true } end
    local name, missing = targetName(rule)
    if not name then return { why = missing, rule = rule, index = index, blocked = true } end
    return { rule = rule, index = index, name = name }
end

local function slotQuality(slot, link)
    local q = select(5, GetLootSlotInfo(slot))
    q = ns.Plain(q)
    if type(q) ~= "number" then q = ns.LinkQuality(link) end
    return q
end

local function lootThreshold()
    local fn = _G.GetLootThreshold
    if type(fn) ~= "function" then return 0 end
    local ok, v = pcall(fn)
    v = ok and ns.Plain(v) or nil
    return type(v) == "number" and v or 0
end

-- The items of the open loot window through the rules: { slot, link, id, q, rule, index, name, why }
-- in slot order; money, currency, quest items and items below the loot threshold (anyone loots
-- those) are left out.
function ns.LootRulesPlan()
    local out = {}
    local threshold = lootThreshold()
    for slot = 1, (GetNumLootItems and GetNumLootItems() or 0) do
        local link = ns.Plain(GetLootSlotLink(slot))
        local id = ns.ItemID(link)
        local _, _, _, currency, _, _, quest = GetLootSlotInfo(slot)
        if id and not ns.Plain(currency) and ns.Plain(quest) ~= true then
            local q = slotQuality(slot, link)
            if not q or q >= threshold then
                local e = decide(id, q)
                e.slot, e.link, e.id, e.q = slot, link, id, q
                if given[slot] then e.why, e.done = L["schon verteilt"], true end
                if failed[slot] and not e.done then e.why, e.blocked = failed[slot], true end
                out[#out + 1] = e
            end
        end
    end
    return out
end

-- The entries a run would hand out.
local function actionable(plan)
    local out = {}
    for _, e in ipairs(plan) do
        if e.name and not e.blocked and not e.done then out[#out + 1] = e end
    end
    return out
end

-- The key of the corpse: its source GUID, else the sorted item ids.
local function corpseKey(plan)
    local sourceInfo = _G.GetLootSourceInfo
    for _, e in ipairs(plan) do
        if type(sourceInfo) == "function" then
            local ok, guid = pcall(sourceInfo, e.slot)
            guid = ok and ns.Plain(guid) or nil
            if type(guid) == "string" and guid ~= "" and not guid:find("^Item%-") then return "g:" .. guid end
        end
    end
    local ids = {}
    for _, e in ipairs(plan) do ids[#ids + 1] = e.id end
    table.sort(ids)
    return #ids > 0 and ("i:" .. table.concat(ids, ",")) or nil
end

local function doneRecently(key)
    local t = key and ns.lootRulesDone[key]
    return t ~= nil and time() - t < CORPSE_KEEP
end

local function markDone(key)
    if not key then return end
    local t = time()
    for k, at in pairs(ns.lootRulesDone) do
        if t - at >= CORPSE_KEEP then ns.lootRulesDone[k] = nil end
    end
    ns.lootRulesDone[key] = t
end

---------------------------------------------------------------------------
-- Handing out
---------------------------------------------------------------------------
local function candidateIndex(slot, name)
    for i = 1, 40 do
        local c = ns.Plain(GetMasterLootCandidate(slot, i))
        if c and ns.SameName(c, name) then return i end
    end
    return nil
end

-- "[Item] an die Bank (Name)", "[Item] zum Entzaubern (Name)", "[Item] an Name"
local function givenText(e)
    if e.rule.to == "bank" then return ("%s %s"):format(e.link, L["an die Bank (%s)"]:format(e.name)) end
    if e.rule.to == "de" then return ("%s %s"):format(e.link, L["zum Entzaubern (%s)"]:format(e.name)) end
    return L["%s an %s##Regel"]:format(e.link, e.name)
end

local refreshBar

-- Hands out what the rules give in the open loot window. manual: a click or a command (a corpse the
-- rules already ran on is done again; the reason is told). Returns the number given and, when
-- nothing could run, why.
local function run(manual)
    local why = whyNot()
    if why then
        if manual then msg(why) end
        return 0, why
    end
    if not lootOpen or fromItem then
        if manual then msg(L["Kein Lootfenster offen."]) end
        return 0, L["Kein Lootfenster offen."]
    end
    local plan = ns.LootRulesPlan()
    local todo = actionable(plan)
    local key = corpseKey(plan)
    if #todo == 0 then
        if manual then msg(L["Die Regeln haben hier nichts zu verteilen."]) end
        return 0
    end
    if not manual and doneRecently(key) then return 0 end
    if blocked() then
        waiting = { serial = serial, manual = manual }
        if waitTold ~= serial then
            waitTold = serial
            msg(L["Lootregeln warten bis nach dem Kampf (Kampfsperre)."])
        end
        return 0, "blocked"
    end
    waiting = nil
    local parts, n = {}, 0
    for _, e in ipairs(todo) do
        if not (ns.PendingAward and ns.PendingAward(e.slot)) and ns.ItemID(ns.Plain(GetLootSlotLink(e.slot))) == e.id then
            local idx = candidateIndex(e.slot, e.name)
            if not idx then
                failed[e.slot] = L["kein Kandidat"]
                msg(L["%s ist kein Kandidat für %s. Das Item bleibt liegen."]:format(e.name, e.link))
            else
                local ok = pcall(GiveMasterLoot, e.slot, idx)
                if ok then
                    given[e.slot] = e.link
                    givenList[#givenList + 1] = e
                    if ns.TagPendingAward then
                        ns.TagPendingAward(e.slot, NOTE_MARK .. ns.LootRuleLabel(e.rule), "-")
                    end
                    parts[#parts + 1] = givenText(e)
                    n = n + 1
                else
                    failed[e.slot] = L["nicht gegeben"]
                end
            end
        end
    end
    markDone(key)
    -- one line in the raid chat, only from the loot lead (D-27)
    if n > 0 and ns.Get("lootrules.chat") and ns.IsLootLead and ns.IsLootLead() then
        local lines = ns.ChatLines(L["Amisia-Regeln: "], parts)
        lines[#lines] = lines[#lines] .. "."
        for _, line in ipairs(lines) do ns.Say(line, "RAID", nil, { ttl = 600 }) end
    end
    if refreshBar then refreshBar() end
    return n
end

function ns.LootRulesRun(manual) return run(manual) end

-- An open "Wer braucht das?" question of an item to give: its answers may still come.
local function needPending(todo)
    for _, e in ipairs(todo) do
        local need = ns.NeedOf and ns.NeedOf(e.id)
        if need and need.missing > 0 and time() - (need.at or 0) < NEED_WAIT then return true end
    end
    return false
end

local function autoRun(at, tries)
    if not lootOpen or at ~= serial or ns.Get("lootrules.mode") ~= "auto" then return end
    if tries < NEED_TRIES and needPending(actionable(ns.LootRulesPlan())) then
        C_Timer.After(1, function() autoRun(at, tries + 1) end)
        return
    end
    run(false)
end

-- After the lockdown: the held run once more, while its loot window is still open.
local function retry()
    C_Timer.After(0, function()
        local w = waiting
        if not w or not lootOpen or w.serial ~= serial or blocked() then return end
        waiting = nil
        run(w.manual)
    end)
end
ns.OnEvent("ADDON_RESTRICTION_STATE_CHANGED", retry)
ns.OnEvent("PLAYER_REGEN_ENABLED", retry)

---------------------------------------------------------------------------
-- The bar beside the loot window
---------------------------------------------------------------------------
local bar

local function countText(todo)
    local bank, de, players = 0, 0, {}
    for _, e in ipairs(todo) do
        if e.rule.to == "bank" then bank = bank + 1
        elseif e.rule.to == "de" then de = de + 1
        else players[#players + 1] = e.name end
    end
    local out = {}
    if bank > 0 then out[#out + 1] = L["%d an die Bank"]:format(bank) end
    if de > 0 then out[#out + 1] = L["%d zum Entzaubern"]:format(de) end
    for _, name in ipairs(players) do out[#out + 1] = L["1 an %s"]:format(name) end
    return table.concat(out, ", ")
end

local function makeBar()
    local f = W.Window("AmisiaLootRulesBar", 300, 78, { title = L["Lootregeln"], escape = false, strata = "HIGH" })
    f.text = W.Text(f, T.FONT.text, 276)
    f.text:SetPoint("TOPLEFT", 12, -32)
    f.give = W.Button(f, L["Verteilen"], nil, function() run(true) end, { height = T.ROW_BUTTON_H })
    W.FitChip(f.give, 90)
    f.give:SetPoint("BOTTOMRIGHT", -10, 8)
    f.mode = W.Text(f, T.FONT.hint, 170)
    f.mode:SetPoint("BOTTOMLEFT", 12, 12)
    -- the tooltip names every item and its rule
    f.hit = CreateFrame("Frame", nil, f)
    f.hit:SetPoint("TOPLEFT", f.text, "TOPLEFT")
    f.hit:SetSize(276, 16)
    f.hit:EnableMouse(true)
    f.hit:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["Lootregeln"], 1, 0.82, 0)
        for _, e in ipairs(givenList) do
            GameTooltip:AddLine(L["%s: verteilt (Regel %d)"]:format(e.link, e.index), 0.85, 0.85, 0.85, true)
        end
        if ns.Get("lootrules.mode") == "click" then
            for _, e in ipairs(ns.LootRulesPlan()) do
                if e.name and not e.blocked and not e.done then
                    GameTooltip:AddLine(L["%s: Regel %d (%s)"]:format(e.link, e.index, ns.LootRuleLabel(e.rule)), 0.85, 0.85, 0.85, true)
                elseif e.why and not e.done then
                    GameTooltip:AddLine(("%s: %s"):format(e.link, e.why), 0.6, 0.6, 0.6, true)
                end
            end
        end
        GameTooltip:Show()
    end)
    f.hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local lf = _G.LootFrame
    f:ClearAllPoints()
    if type(lf) == "table" and type(lf.GetObjectType) == "function" then
        f:SetPoint("TOPLEFT", lf, "TOPRIGHT", 4, 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 240, 120)
    end
    return f
end

-- One-click mode: the bar shows how many items the rules would hand out, with the button.
-- Automatic mode: it shows only what the rules gave in this loot window (no button), else nothing.
refreshBar = function()
    local active = lootOpen and not fromItem and not whyNot()
    local click = ns.Get("lootrules.mode") == "click"
    local list = {}
    if active and click then
        list = actionable(ns.LootRulesPlan())
    elseif active then
        for _, e in ipairs(givenList) do list[#list + 1] = e end
    end
    if #list == 0 then
        if bar then bar:Hide() end
        return
    end
    bar = bar or makeBar()
    if click then
        bar.text:SetText(#list == 1 and L["1 Item nach Regeln verteilen"] or L["%d Items nach Regeln verteilen"]:format(#list))
        bar.give:Show()
    else
        bar.text:SetText(L["Verteilt: %s"]:format(countText(list)))
        bar.give:Hide()
    end
    bar.mode:SetText(click and countText(list) or L["automatisch"])
    bar:Show()
end

-- For the snapshots and tests: the bar (made when missing) after a refresh.
function ns.LootRulesBar()
    refreshBar()
    return bar
end

---------------------------------------------------------------------------
-- The loot window
---------------------------------------------------------------------------
local function tellOnce()
    local s = ns.Active()
    if not s or told[s.id or s] then return end
    told[s.id or s] = true
    msg(L["Lootregeln aktiv: %d (Pause: /amisia regeln pause)"]:format(#ns.LootRules().list))
end

ns.OnEvent("LOOT_OPENED", function(_, isFromItem)
    lootOpen = true
    serial = serial + 1
    wipe(given)
    wipe(failed)
    wipe(givenList)
    waiting = nil
    fromItem = isFromItem == true
    if fromItem or whyNot() then
        if bar then bar:Hide() end
        return
    end
    tellOnce()
    refreshBar()
    if ns.Get("lootrules.mode") == "auto" then
        local at = serial
        C_Timer.After(AUTO_DELAY, function() autoRun(at, 0) end)
    end
end)

ns.OnEvent("LOOT_SLOT_CLEARED", function()
    if lootOpen and refreshBar then refreshBar() end
end)

ns.OnEvent("LOOT_CLOSED", function()
    lootOpen = false
    waiting = nil
    wipe(given)
    wipe(failed)
    wipe(givenList)
    if bar then bar:Hide() end
end)

---------------------------------------------------------------------------
-- Dry run: /amisia regeln probe [item]
---------------------------------------------------------------------------
local function probeLine(e)
    if e.name and not e.blocked and not e.done then
        return L["%s: Regel %d (%s) gibt es %s."]:format(e.link, e.index, ns.LootRuleLabel(e.rule),
            e.rule.to == "bank" and L["an die Bank (%s)"]:format(e.name)
            or e.rule.to == "de" and L["zum Entzaubern (%s)"]:format(e.name)
            or L["an %s##Regel"]:format(e.name))
    end
    if e.rule then
        return L["%s: bleibt liegen, %s (Regel %d)."]:format(e.link, e.why, e.index)
    end
    return L["%s: bleibt liegen, %s."]:format(e.link, e.why)
end

-- Says in the own chat what the rules would do with the open loot or the given item; gives nothing.
function ns.LootRulesProbe(rest)
    local lines = {}
    local lr = ns.LootRules()
    if #lr.list == 0 then
        msg(L["Keine Lootregeln angelegt."])
        return lines
    end
    local text = (rest or ""):match("^%s*(.-)%s*$")
    local plan
    if text ~= "" then
        local id = ns.LootRuleItems(text)[1]
        if not id then
            msg(L["Kein Item erkannt: Link einfügen oder Item-ID angeben."])
            return lines
        end
        local link = text:match("|c%x+|Hitem:.-|h|r") or select(2, C_Item.GetItemInfo(id)) or ("Item " .. id)
        local q = ns.LinkQuality(link) or select(3, C_Item.GetItemInfo(id))
        local e = decide(id, q)
        e.link, e.id, e.q = link, id, q
        plan = { e }
    elseif lootOpen and not fromItem then
        plan = ns.LootRulesPlan()
    else
        msg(L["Kein Lootfenster offen. /amisia regeln probe <Item> prüft ein Item."])
        return lines
    end
    lines[1] = L["Probe der Lootregeln (nichts wird verteilt):"]
    if #plan == 0 then lines[#lines + 1] = L["Keine Items, die die Regeln betreffen."] end
    for _, e in ipairs(plan) do lines[#lines + 1] = probeLine(e) end
    local why = whyNot()
    if why then
        lines[#lines + 1] = L["Jetzt würde nichts verteilt: %s"]:format(why)
    elseif ns.Get("lootrules.mode") ~= "auto" then
        lines[#lines + 1] = L["Verteilt wird mit dem Knopf am Lootfenster."]
    end
    for _, line in ipairs(lines) do msg(line) end
    return lines
end

---------------------------------------------------------------------------
-- Sharing between officers: MR / MQ
---------------------------------------------------------------------------
local function inGuild() return type(_G.IsInGuild) == "function" and ns.Plain(IsInGuild()) == true end

-- The rules as MR entries "id:kind:value:target"; a long item list takes several entries.
local function entries(list)
    local out = {}
    for _, r in ipairs(list) do
        local to = SPECIAL[r.to] and r.to or ns.ExportName(r.to)
        if r.k == "q" then
            out[#out + 1] = ("%s:q:%d:%s"):format(r.id, r.q, to)
        elseif r.k == "m" then
            out[#out + 1] = ("%s:m:-:%s"):format(r.id, to)
        elseif r.k == "p" then
            out[#out + 1] = ("%s:p:%d:%s"):format(r.id, r.items[1], to)
        else
            for i = 1, #r.items, IDS_PER_ENTRY do
                local chunk = {}
                for j = i, math.min(#r.items, i + IDS_PER_ENTRY - 1) do chunk[#chunk + 1] = tostring(r.items[j]) end
                out[#out + 1] = ("%s:i:%s:%s"):format(r.id, table.concat(chunk, "+"), to)
            end
        end
    end
    return out
end

-- The MR messages of the own set: a list of field lists, or nil when it needs more than 4.
local function messages()
    local lr = ns.LootRules()
    local by = ns.ExportName(lr.by or me()):gsub("[%s%c,:|]", "")
    if by == "" then by = "?" end
    local groups, cur, size = {}, {}, 0
    local head = #tostring(lr.rev) + #by + 16
    for _, e in ipairs(entries(lr.list)) do
        if #cur >= PER_PART or (#cur > 0 and head + size + #e + 1 > PART_BYTES) then
            groups[#groups + 1] = cur
            cur, size = {}, 0
        end
        cur[#cur + 1] = e
        size = size + #e + 1
    end
    groups[#groups + 1] = cur
    if #groups > MAX_PARTS then return nil end
    local out = {}
    for p, g in ipairs(groups) do
        out[p] = { tostring(lr.rev), tostring(p), tostring(#groups), by, #g > 0 and table.concat(g, ",") or "-" }
    end
    return out
end

local function sendRules(chan, target)
    if not (ns.CommReady and ns.CommReady()) then return false, L["Addon-Nachrichten sind aus."] end
    local list = messages()
    if not list then return false, L["Zu viele Regeln für eine Nachricht (höchstens %d Teile)."]:format(MAX_PARTS) end
    for p, fields in ipairs(list) do
        local ok, why = ns.CommSend("MR", fields, chan, target,
            { key = "MR:" .. chan .. ":" .. tostring(target or "") .. ":" .. p, ttl = 120, low = chan == "WHISPER" or nil })
        if not ok then return false, why end
    end
    return true
end

-- "An Offiziere senden": the own set goes to the guild as an offer to the other officers.
function ns.SendLootRules()
    if not DB then return false, L["Amisia ist noch nicht geladen."] end
    if not ns.IsOfficerView() or not ns.SelfIsOfficer() then return false, L["Lootregeln senden nur Offiziere."] end
    if not inGuild() then return false, L["Nicht in einer Gilde."] end
    local lr = ns.LootRules()
    if lr.rev == 0 then touch() end
    local ok, why = sendRules("GUILD")
    if not ok then return false, why end
    lr.sent = lr.rev
    changed()
    return true
end

-- The offer against the own rules: counts of new, changed and removed rules.
function ns.LootRulesDiff(offer)
    offer = offer or ns.LootRules().offer
    local d = { new = 0, changed = 0, removed = 0 }
    if not offer then return d end
    local own = {}
    for _, r in ipairs(ns.LootRules().list) do own[r.id] = r end
    local function same(a, b)
        if a.k ~= b.k or a.q ~= b.q or a.to ~= b.to then return false end
        local ai, bi = a.items or {}, b.items or {}
        if #ai ~= #bi then return false end
        for i = 1, #ai do if ai[i] ~= bi[i] then return false end end
        return true
    end
    local seen = {}
    for _, r in ipairs(offer.list) do
        seen[r.id] = true
        if not own[r.id] then d.new = d.new + 1 elseif not same(own[r.id], r) then d.changed = d.changed + 1 end
    end
    for id in pairs(own) do if not seen[id] then d.removed = d.removed + 1 end end
    return d
end

-- "Übernehmen": the offer becomes the own rule set.
function ns.AcceptLootRules()
    local lr = ns.LootRules()
    local o = lr.offer
    if not o or not ns.IsOfficerView() then return false end
    lr.list = cleanList(o.list)
    lr.rev, lr.by, lr.at = o.rev, o.from, now()
    lr.seen = math.max(lr.seen or 0, o.rev)
    lr.sent, lr.offer = nil, nil
    changed()
    msg(L["Lootregeln von %s übernommen (%d Regeln)."]:format(o.from, #lr.list))
    return true
end

-- "Ablehnen": the offer goes; the same set is not offered again.
function ns.DeclineLootRules()
    local lr = ns.LootRules()
    local o = lr.offer
    if not o then return false end
    lr.seen = math.max(lr.seen or 0, o.rev)
    lr.offer = nil
    changed()
    return true
end

-- The newest set this client knows of: its own, the offer, or one it declined.
local function knownRev()
    local lr = ns.LootRules()
    return math.max(lr.rev or 0, lr.seen or 0, lr.offer and lr.offer.rev or 0)
end

-- The rules of an MR set, or nil when an entry does not fit together.
local function parseSet(set, from)
    local byId, order = {}, {}
    for i = 1, set.n do
        local text = set.parts[i]
        if text ~= "-" then
            for e in (text .. ","):gmatch("([^,]*),") do
                local id, k, value, to = e:match("^(%x%x%x%x):([qmip]):([^:]+):([^:]+)$")
                if not id then return nil end
                id = id:lower()
                local r = byId[id]
                if r and (r.k ~= k or k ~= "i") then return nil end
                if not r then
                    r = { id = id, k = k, to = to, by = from, items = {} }
                    byId[id] = r
                    order[#order + 1] = r
                end
                if k == "q" then r.q = tonumber(value)
                elseif k ~= "m" then
                    for x in (value .. "+"):gmatch("([^+]*)%+") do r.items[#r.items + 1] = x end
                end
            end
        end
    end
    local list = {}
    for _, r in ipairs(order) do
        if r.k == "p" then r.to = (r.to:gsub("_", " ")) end
        local c = cleanRule(r)
        if not c then return nil end
        list[#list + 1] = c
    end
    if #list > MAX_RULES then return nil end
    return list
end

ns.CommOn("MR", function(sender, f)
    if not DB then return end
    local name = ns.TrustName(sender)
    if not name then return end
    local rev, part, parts = tonumber(f[1]), tonumber(f[2]), tonumber(f[3])
    if rev > now() + FUTURE or rev <= knownRev() then return end
    ns.TrustWait(name, "officer", function(ok)
        if not ok or rev <= knownRev() then return end
        local key, t = name:lower(), GetTime()
        local set = incoming[key]
        if not set or set.rev ~= rev or set.n ~= parts or t - set.at > PART_WAIT then
            -- one new set per officer every 30 s
            if offerAt[key] and t - offerAt[key] < OFFER_GAP then return end
            set = { rev = rev, n = parts, parts = {}, got = 0, at = t }
            incoming[key] = set
        end
        if not set.parts[part] then
            set.parts[part] = f[5]
            set.got = set.got + 1
        end
        if set.got < set.n then return end
        incoming[key] = nil
        offerAt[key] = t
        local list = parseSet(set, name)
        if not list then return end
        local lr = ns.LootRules()
        lr.offer = { from = name, rev = rev, at = now(), list = list }
        changed()
        if ns.IsOfficerView() then
            msg(L["Neue Lootregeln von %s (%d Regeln): Übernehmen oder Ablehnen unter Einstellungen, Lootregeln (/amisia regeln)."]:format(name, #list))
        end
    end)
end)

-- The question after the login (officers only): who has a newer sent set?
function ns.AskLootRules()
    if not DB or not inGuild() or not ns.SelfIsOfficer() or not (ns.CommReady and ns.CommReady()) then return false end
    return ns.CommSend("MQ", { tostring(knownRev()) }, "GUILD", nil, { key = "MQ", ttl = 120, low = true }) and true or false
end

local function spread(n)
    local h = tonumber(ns.Checksum(me()):sub(1, 6), 16) or 0
    return (h % (n * 10)) / 10
end

ns.CommOn("MQ", function(sender, f)
    if not DB then return end
    local name = ns.TrustName(sender)
    if not name then return end
    local asked = tonumber(f[1]) or 0
    ns.TrustWait(name, "officer", function(ok)
        if not ok then return end
        local lr = ns.LootRules()
        -- only a set this officer sent, and only when it is newer than what the asker knows
        if lr.sent and lr.sent == lr.rev and lr.rev > asked and ns.SelfIsOfficer() then
            C_Timer.After(1 + spread(3), function() sendRules("WHISPER", sender) end)
        end
    end)
end)

local asked = false
ns.OnEvent("PLAYER_LOGIN", function()
    if asked then return end
    asked = true
    C_Timer.After(ASK_AFTER + spread(ASK_SPREAD), function() ns.AskLootRules() end)
end)

---------------------------------------------------------------------------
-- The editor in the settings (section "Lootregeln")
---------------------------------------------------------------------------
local ED_W, ED_ROW = 560, 22
local KIND_VALUES = { { "q", L["Qualität"] }, { "m", L["Raidmaterialien"] }, { "i", L["Itemliste"] }, { "p", L["Item an Spieler"] } }
local QUALITY_VALUES = { { 2, L["bis Ungewöhnlich"] }, { 3, L["bis Selten"] } }
local TARGET_VALUES = { { "bank", L["Bank##Ziel"] }, { "de", L["Entzaubern"] } }

local editor   -- the frame of the custom settings item

local function ruleRow(parent)
    local r = CreateFrame("Frame", nil, parent)
    r:SetSize(ED_W, ED_ROW)
    r.text = W.Text(r, T.FONT.text, 330)
    r.text:SetPoint("LEFT", 12, 0)
    r.note = W.Text(r, T.FONT.hint, 120)
    r.note:SetPoint("LEFT", 346, 0)
    r.up = W.Chip(r, L["Hoch"], nil, function(self) ns.MoveLootRule(self:GetParent().id, -1) end)
    W.FitChip(r.up, 46)
    r.up:SetPoint("LEFT", 470, 0)
    r.del = W.ResetButton(r, T.RESET, function(self) ns.RemoveLootRule(self:GetParent().id) end)
    r.del:SetPoint("LEFT", 470 + r.up:GetWidth() + T.CHIP_GAP + 4, 0)
    W.Tooltip(r.del, L["Regel entfernen"], nil)
    r:EnableMouse(true)
    r:SetScript("OnEnter", function(self)
        local rule = findRule(self.id)
        if not rule then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(ns.LootRuleLabel(rule), 1, 0.82, 0)
        if rule.items and #rule.items > 1 then
            for _, id in ipairs(rule.items) do GameTooltip:AddLine(ns.ItemName(id), 0.85, 0.85, 0.85) end
        end
        local problem = ns.LootRuleProblem(rule)
        if problem then GameTooltip:AddLine(problem, 0.88, 0.34, 0.29, true) end
        if rule.by then GameTooltip:AddLine(L["Angelegt von %s"]:format(rule.by), 0.6, 0.6, 0.6) end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
end

local function addRule()
    local e = editor
    local k = e.kind.current
    local spec = { k = k, q = e.quality.current, to = e.target.current }
    if k == "i" or k == "p" then spec.items = e.items:GetText() end
    if k == "p" then spec.to = e.name:GetText() end
    local r, why = ns.AddLootRule(spec)
    if not r then
        msg(why)
        return
    end
    e.items:SetText("")
    e.name:SetText("")
    msg(L["Regel angelegt: %s"]:format(ns.LootRuleLabel(r)))
end

local function buildEditor(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(ED_W, 100)
    f.rows = {}
    f.empty = W.Text(f, T.FONT.hint, 540, true)
    f.empty:SetText(L["Noch keine Regeln. Ohne Regeln verteilt Amisia nichts von selbst."])
    -- the add row: kind, its value, the target, "Hinzufügen"
    f.addRow = CreateFrame("Frame", nil, f)
    f.addRow:SetSize(ED_W, T.LAYOUT.ROW_H)
    f.kind = W.Choice(f.addRow, 120, function() ns.Refresh() end)
    f.kind:SetValues(KIND_VALUES)
    f.kind:SetValue("q")
    f.quality = W.Choice(f.addRow, 130)
    f.quality:SetValues(QUALITY_VALUES)
    f.quality:SetValue(3)
    f.items = W.LineEdit(f.addRow, 150)
    W.Tooltip(f.items, L["Items"], L["Item-Link (Shift-Klick) oder Item-ID; bei einer Liste mehrere."])
    f.target = W.Choice(f.addRow, 100)
    f.target:SetValues(TARGET_VALUES)
    f.target:SetValue("de")
    f.name = W.LineEdit(f.addRow, 110)
    W.Tooltip(f.name, L["Spieler"], L["Der Name des Spielers, der das Item bekommt."])
    f.add = W.Button(f.addRow, L["Hinzufügen"], nil, addRule, { height = T.ROW_BUTTON_H })
    W.FitChip(f.add, 80)
    -- sending and the offer
    f.sendRow = CreateFrame("Frame", nil, f)
    f.sendRow:SetSize(ED_W, T.LAYOUT.ROW_H)
    f.send = W.Button(f.sendRow, L["An Offiziere senden"], nil, function()
        local ok, why = ns.SendLootRules()
        msg(ok and L["Lootregeln an die Offiziere gesendet."] or why)
    end, { height = T.ROW_BUTTON_H })
    W.FitChip(f.send, 120)
    f.sent = W.Text(f.sendRow, T.FONT.hint, 380)
    f.offerRow = CreateFrame("Frame", nil, f)
    f.offerRow:SetSize(ED_W, T.LAYOUT.ROW_H)
    f.offer = W.Text(f.offerRow, T.FONT.text, 330)
    f.accept = W.Button(f.offerRow, L["Übernehmen"], nil, function() ns.AcceptLootRules() end, { height = T.ROW_BUTTON_H })
    W.FitChip(f.accept, 80)
    f.decline = W.Button(f.offerRow, L["Ablehnen"], nil, function() ns.DeclineLootRules() end, { height = T.ROW_BUTTON_H })
    W.FitChip(f.decline, 70)
    editor = f
    return f
end

local function fillEditor(f)
    local lr = ns.LootRules()
    local column = {}
    for i, rule in ipairs(lr.list) do
        local r = f.rows[i] or ruleRow(f)
        f.rows[i] = r
        r.id = rule.id
        r.text:SetText(("%d. %s"):format(i, ns.LootRuleLabel(rule)))
        local problem = ns.LootRuleProblem(rule)
        r.note:SetText(problem and (T.RED .. L["Name fehlt"] .. "|r") or (rule.k ~= "p" and targetName(rule) or ""))
        r.up:SetEnabled(i > 1)
        r:Show()
        column[#column + 1] = r
    end
    for i = #lr.list + 1, #f.rows do f.rows[i]:Hide() end
    if #lr.list == 0 then
        f.empty:Show()
        column[#column + 1] = { f.empty, right = 20 }
        f.empty:SetHeight(T.LAYOUT.LINE_H)
    else
        f.empty:Hide()
    end
    -- the add row shows the fields of the chosen kind
    local k = f.kind.current
    f.kind:Show()
    f.add:Show()
    f.quality:SetShown(k == "q")
    f.items:SetShown(k == "i" or k == "p")
    f.target:SetShown(k ~= "p")
    f.name:SetShown(k == "p")
    W.Row(f.addRow, { f.kind, f.quality, f.items, f.target, f.name, f.add }, T.LAYOUT.ITEM_GAP, 12, 0, { shown = true, point = "LEFT" })
    column[#column + 1] = { f.addRow, gap = T.LAYOUT.GAP + 2 }
    f.sent:SetText(lr.sent and lr.sent == lr.rev and L["Gesendet: %s"]:format(ns.FmtDayTime(lr.sent))
        or (lr.by and L["Stand: %s von %s"]:format(ns.FmtDayTime(lr.at or lr.rev), lr.by) or ""))
    W.Row(f.sendRow, { f.send, f.sent }, T.LAYOUT.ITEM_GAP, 12, 0, { point = "LEFT" })
    column[#column + 1] = { f.sendRow, gap = T.LAYOUT.GAP }
    local o = lr.offer
    if o then
        local d = ns.LootRulesDiff(o)
        f.offer:SetText(L["Neue Lootregeln von %s: %d neu, %d geändert, %d entfernt"]:format(o.from, d.new, d.changed, d.removed))
        W.Row(f.offerRow, { f.offer, f.accept, f.decline }, T.LAYOUT.ITEM_GAP, 12, 0, { point = "LEFT" })
        f.offerRow:Show()
        column[#column + 1] = { f.offerRow, gap = T.LAYOUT.GAP }
    else
        f.offerRow:Hide()
    end
    local bottom = W.Column(f, column, 0, 0, 0)
    f:SetHeight(math.max(ED_ROW, -bottom))
end

-- A link shift-clicked while one of the editor's boxes has the focus lands in it (a list collects).
local function onInsertLink(link)
    if not editor or not ns.ItemID(link) then return end
    if editor.items:HasFocus() then
        local text = editor.items:GetText() or ""
        if editor.kind.current == "i" and text ~= "" then editor.items:SetText(text .. " " .. link) else editor.items:SetText(link) end
    end
end
if type(ChatFrameUtil) == "table" and type(ChatFrameUtil.InsertLink) == "function" then
    hooksecurefunc(ChatFrameUtil, "InsertLink", onInsertLink)
end
if type(ChatEdit_InsertLink) == "function" then
    hooksecurefunc("ChatEdit_InsertLink", onInsertLink)
end

---------------------------------------------------------------------------
-- Settings and command
---------------------------------------------------------------------------
local function setPaused(on)
    ns.Set("lootrules.paused", on and true or false)
    if refreshBar then refreshBar() end
end

ns.RegisterSettings{ key = "lootrules", label = L["Lootregeln"], order = 23, officer = true, items = {
    { key = "lootrules.paused", type = "toggle", label = L["Pause"], default = false,
      tip = L["Solange an, verteilen die Regeln nichts; alle Items gehen den normalen Weg."],
      onChange = function() if refreshBar then refreshBar() end end },
    { key = "lootrules.mode", type = "choice", label = L["Modus"], default = "auto",
      values = { { "auto", L["Automatisch"] }, { "click", L["Ein Klick"] } },
      tip = L["Automatisch: eine Sekunde nach dem Öffnen der Leiche, nur außerhalb von Kampf und Kampfsperre. Ein Klick: eine Leiste am Lootfenster mit dem Knopf \"Verteilen\"."] },
    { key = "lootrules.chat", type = "toggle", label = L["Eine Zeile im Raidchat"], default = true,
      tip = L["Nennt, was die Regeln verteilt haben. Nur die Lootleitung schreibt sie."] },
    { key = "lootrules.list", type = "custom", label = L["Regeln (die erste passende gilt)"],
      tip = L["Reservierte Items, Items mit Loot-Prio, Gildenwunsch oder Upgrade-Antwort fasst keine Regel an."],
      build = buildEditor, fill = fillEditor },
}}

ns.Listen("LOOT_RULES", function() if refreshBar then refreshBar() end end)

ns.RegisterSlash("regeln", { en = "rules", officer = true, args = L["[pause|weiter|probe [Item]]"],
    desc = L["Lootregeln: Einstellungen öffnen, pausieren, fortsetzen, Probe ohne Verteilen"], run = function(rest)
        local word, tail = (rest or ""):match("^%s*(%S*)%s*(.-)%s*$")
        word = (word or ""):lower()
        if word == "pause" then -- l10n-ok: typed sub-word
            setPaused(true)
            msg(L["Lootregeln pausiert. /amisia regeln weiter schaltet sie wieder ein."])
        elseif word == "weiter" or word == "resume" then -- l10n-ok: typed sub-words
            setPaused(false)
            msg(L["Lootregeln laufen wieder (%d Regeln)."]:format(#ns.LootRules().list))
        elseif word == "probe" or word == "dryrun" then -- l10n-ok: typed sub-words
            ns.LootRulesProbe(tail)
        elseif ns.ShowSettings then
            ns.ShowSettings(L["Lootregeln"])
        end
    end })
