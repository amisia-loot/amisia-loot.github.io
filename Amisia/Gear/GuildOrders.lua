-- Amisia guild orders (F-231, D-164, spec docs/specs/2026-11-23-gildenauftraege.md): a member asks the guild to
-- craft a recipe ("Gildenauftrag", never "Handwerksauftrag": that is the game's Merchant's Favor), a member whose
-- character knows it accepts, says it is done, and the requester closes it once received. Amisia only passes the
-- word: no gold, no trade, no mail.
--
-- The requester's client is the one source of an order: it keeps its own orders (AmisiaDB.orders.own, at most 5
-- open) and tells the guild every change as OA (GUILD, a new revision; keyed per order id, at most every 2 s),
-- once 20-60 s after the login (low) and by whisper as the answer to OQ. A crafter's step goes to the requester
-- only (OT by whisper: T accept, R give back, D done); the requester's client takes the first T of an open order
-- (the sender is the crafter), a later one gets the order's state back. The crafter needs the requester online
-- (the button is grey else). OQ: every client asks the guild once 30-60 s after the login (low); requesters with
-- orders answer by whisper (0-10 s).
--
-- Trust: only members of the own guild by the roster; the requester is the server's sender, never a field; an OA
-- changes only orders of its sender; an OT only an own order of the receiver. Caps: 5 open orders per requester,
-- 100 heard in all (the oldest heard falls), note 60 bytes without bar or control characters, count 1-20; an
-- order of a recipe the profession data lacks is dropped once that data is built (never built for it, D-28).
-- An order unchanged for 14 days closes itself; one heard that was not heard again for 14 days falls out.
--
-- Like the recipe exchange (D-12, F-035): nothing goes in the chat lockdown or a battleground; inside an instance
-- it waits until 5-15 s after the way out. Combat holds nothing back.
--
-- AmisiaDB.orders = { v = 1, own = { [id] = { rev, spell, item, n, mats, state, by, at, changed, note } },
--                     heard = { [sender] = { [id] = { rev, spell, item, n, mats, state, by, at, changed, note, seen } } } }
local ADDON, ns = ...
ns.Load(function()
local L = ns.L

local GO = {}
ns.GuildOrders = GO

-- the caps and times; a table so a test can lower one
local LIM = {
    ownMax = 5,                          -- open own orders
    perSender = 5,                       -- open orders kept per requester
    heardMax = 100,                      -- heard orders in all
    nMax = 20,                           -- the count of one order
    noteBytes = 60,
    days = 14,                           -- an order unchanged this long closes; a heard one not heard again falls
    closedKeep = 3 * 86400,              -- seconds a closed own order is still told (OQ, the login)
    revMax = 999999,
    ageMax = 99999999,
    chatHour = 6,                        -- crafter chat lines an hour
    gapOA = 2.1, gapOT = 3.1,            -- seconds between two own OA / OT of one order (the receivers' keyed gaps)
    announceMin = 20, announceSpread = 40,   -- the own orders after the login
    askMin = 30, askSpread = 30,         -- OQ after the login
    answerJitter = 10,                   -- the whisper answer to OQ
    answersMax = 20,                     -- names waiting for an answer
    backGap = 30,                        -- seconds between two state whispers of one order to one crafter
    closedMax = 5,                       -- closed own orders still told, per character (the newest)
    askedFor = 120,                      -- seconds an own step shows "Angefragt" without an answer
    outWait = 5, outSpread = 10,         -- seconds after leaving an instance before anything goes
    loginLine = 90,                      -- seconds after entering the world: the login line (after the answers)
    tick = 1,
    sweep = 60,                          -- seconds between two expiry checks
}
GO.LIM = LIM

GO.MATS = { "B", "H", "A" }
GO.MAT_NAMES = { B = L["bringe ich mit"], H = L["vom Hersteller"], A = L["nach Absprache"] }
local VALID_MAT = { B = true, H = true, A = true }
local VALID_STATE = { O = true, T = true, D = true, X = true }

local function now() return math.floor(time()) end
local function whole(v, lo, hi) return ns.Int(v, lo or 0, hi or 1e10) end
local function validName(v) return type(v) == "string" and v ~= "" and #v <= 48 and not v:find("[%c,:|%d]") end
local function validNote(v) return type(v) == "string" and v ~= "" and #v <= LIM.noteBytes and not v:find("[%c|]") end
local function validId(v) return type(v) == "string" and #v == 4 and v:match("^%x+$") ~= nil end

local rev = 0
function GO.Rev() return rev end
local function changed()
    rev = rev + 1
    ns.FireSoon("GUILD_ORDERS")
end

local function on() return ns.Get("orders.on") ~= false end

---------------------------------------------------------------------------
-- The saved table
---------------------------------------------------------------------------
local function store(create)
    if type(AmisiaDB) ~= "table" then return nil end
    local o = AmisiaDB.orders
    if type(o) ~= "table" then
        if not create then return nil end
        o = { v = 1, own = {}, heard = {} }
        AmisiaDB.orders = o
    end
    if type(o.own) ~= "table" then o.own = {} end
    if type(o.heard) ~= "table" then o.heard = {} end
    return o
end
GO._store = store

local function myName() return ns.UnitFullName and ns.UnitFullName("player") or nil end

---------------------------------------------------------------------------
-- Texts
---------------------------------------------------------------------------
-- A note as the player typed it: no codes, bars or control characters, single spaces, at most 60 bytes (never
-- inside a character); nil when nothing is left.
function GO.CleanNote(text)
    if type(text) ~= "string" then return nil end
    text = ns.StripCodes(text):gsub("[%c]", " "):gsub("%s+", " ")
    return ns.CleanNote(text, LIM.noteBytes)
end

-- The made item of an order (the data's when built, else the message's), 0 for none.
local function itemOf(o)
    local Pr = ns.Prof
    if Pr and ns.DataLoaded("PROFESSIONS") then
        local r = Pr.Recipe(o.spell)
        if r and (r.item or 0) > 0 then return r.item end
    end
    return tonumber(o.item) or 0
end
GO.ItemOf = itemOf

-- "[Mondstoff-Robe]" as a link when the client has it, else the recipe's name.
function GO.ItemText(o)
    local item = itemOf(o)
    if item > 0 and C_Item and C_Item.GetItemInfo then
        local ok, name, link = pcall(C_Item.GetItemInfo, item)
        link = ok and ns.Plain(link) or nil
        if type(link) == "string" and link ~= "" then return link end
        name = ok and ns.Plain(name) or nil
        if type(name) == "string" and name ~= "" then return "[" .. name .. "]" end
    end
    local Pr = ns.Prof
    local name = Pr and Pr.SpellName and Pr.SpellName(o.spell)
    return "[" .. (name or L["Rezept %s"]:format(tostring(o.spell))) .. "]"
end

-- "4x [Mondstoff-Robe]".
function GO.What(o) return ("%dx %s"):format(o.n or 1, GO.ItemText(o)) end

-- "vor 2 Std.", "vor 5 Min.", "vor 3 Tagen".
function GO.AgeText(at)
    local s = math.max(0, now() - (tonumber(at) or now()))
    if s < 3600 then return L["vor %d Min."]:format(math.max(1, math.floor(s / 60))) end
    if s < 86400 then return L["vor %d Std."]:format(math.floor(s / 3600)) end
    return L["vor %d Tagen"]:format(math.floor(s / 86400))
end

---------------------------------------------------------------------------
-- Who of the own characters knows a recipe
---------------------------------------------------------------------------
-- The own characters of this guild (the current one first), from the account's list.
local function ownNames()
    local me = myName()
    local out, seen = {}, {}
    if me then
        out[1] = me
        seen[me] = true
    end
    local list = ns.GuildCharsOwn and ns.GuildCharsOwn() or {}
    for _, c in ipairs(list) do
        if not seen[c.name] then
            out[#out + 1] = c.name
            seen[c.name] = true
        end
    end
    return out
end

-- The own character of this guild that knows a recipe (from its profession window), the current one first; nil.
function GO.Crafter(spell)
    local p = type(AmisiaDB) == "table" and AmisiaDB.prof
    local chars = type(p) == "table" and type(p.chars) == "table" and p.chars or nil
    if not chars then return nil end
    for _, name in ipairs(ownNames()) do
        local c = chars[name]
        if type(c) == "table" then
            for _, s in pairs(c) do
                if type(s) == "table" and type(s.known) == "table" and s.known[spell] == true then return name end
            end
        end
    end
    return nil
end

local function isOwn(name)
    for _, n in ipairs(ownNames()) do
        if ns.SameName(n, name) then return true end
    end
    return false
end

-- A guild member as the roster has it: { name, class, online }; nil when not in the roster. While the roster
-- cannot be read, the name counts as online.
local function member(name)
    local m, why = ns.GuildMember(name)
    if m then return { name = m.name, class = m.class ~= "" and m.class or nil, online = m.online ~= false } end
    if why == "unknown" then return { name = name, online = true } end
    return nil
end
GO.Member = member

---------------------------------------------------------------------------
-- When anything may go: the feature on, messages, a guild, no lockdown; never in a battleground or inside an
-- instance, and 5 to 15 s after leaving one (as the recipe exchange, D-12)
---------------------------------------------------------------------------
-- A fraction 0 to 1 from the own name and the clock: the spreads after the login and the way out without
-- math.random (the other timers keep the random numbers they had before this file, as GuildCalls.lua)
local function spread(salt)
    local n = math.floor((GetTime() or 0) * 1000) + (salt or 0)
    local me = myName() or ""
    for i = 1, #me do n = n + me:byte(i) * i end
    return (n % 1000) / 1000
end

local function inside()
    if type(IsInInstance) == "function" and ns.Plain((IsInInstance())) == true then return true end
    local _, kind = GetInstanceInfo()
    kind = ns.Plain(kind)
    if kind ~= nil and kind ~= "none" then return true end
    return ns.InBattlefield and ns.InBattlefield() or false
end
local wasInside, outAt = false, nil
local function away()
    if inside() then
        wasInside, outAt = true, nil
        return true
    end
    if wasInside then
        wasInside = false
        outAt = GetTime() + LIM.outWait + spread(7) * LIM.outSpread
    end
    if outAt and GetTime() >= outAt then outAt = nil end
    return outAt ~= nil
end
ns.OnEvent("PLAYER_ENTERING_WORLD", function() away() end)
ns.OnEvent("ZONE_CHANGED_NEW_AREA", function() away() end)

function GO.CanTalk()
    local out = away()
    if not AmisiaDB or not on() then return false end
    if not ns.CommAvailable() or not ns.InGuild() then return false end
    if ns.CommHeld() then return false end
    return not out
end
local canTalk = function() return GO.CanTalk() end

---------------------------------------------------------------------------
-- The own orders
---------------------------------------------------------------------------
local due = {}            -- [id] = true: the own order goes to the guild (OA) once it may
local sentAt = {}         -- [id] = GetTime() of the last own OA to the guild
local answers = {}        -- [lower name] = name: an OQ waits for its whisper answer
local backs = {}          -- ["lower name:id"] = { to, id }: a refused step gets that order's state back
local backAt = {}         -- ["lower name:id"] = GetTime() of the last such answer
local askedAt = {}        -- ["lower requester:id"] = GetTime() of the own last step
local owedOT = {}         -- ["lower requester:id"] = { to, id, act }: an own step waits
local otAt = {}           -- ["lower requester:id"] = GetTime() of the last OT
local asked = {}          -- ["lower requester:id"] = "T"/"R"/"D": the own last step of another's order

-- The own orders of the logged-in character (AmisiaDB is per account: each order names its owner, so a twink
-- never sends, steps on or receives the orders of another own character).
local function ownList()
    local o = store(false)
    local me = myName()
    local out = {}
    if not o or not me then return out end
    for id, e in pairs(o.own) do
        if type(e) == "table" and e.owner == me then out[id] = e end
    end
    return out
end

local function openCount()
    local n = 0
    for _, e in pairs(ownList()) do
        if type(e) == "table" and e.state ~= "X" then n = n + 1 end
    end
    return n
end
GO.OpenCount = openCount

-- The fields of an own order's OA.
function GO.Fields(id, e)
    local age = math.max(0, math.min(LIM.ageMax, now() - (e.at or now())))
    return { id, tostring(e.rev), tostring(e.spell), tostring(e.n), e.mats, e.state, e.by or "-", tostring(age),
        e.note or "-", tostring(tonumber(e.item) or 0) }
end

local function newId(list)
    for _ = 1, 50 do
        local id = ("%04x"):format(math.random(0, 65535))
        if not list[id] then return id end
    end
    return nil
end

-- An own order changed: a new revision, to the guild once it may.
local function bump(id, e)
    e.rev = e.rev % LIM.revMax + 1
    e.changed = now()
    due[id] = true
    changed()
end

-- Puts up an own order. spell: a recipe of the profession data; n 1-20; mats "B"/"H"/"A"; note (cleaned, 60
-- bytes). announce: also a line in the guild chat ("Suche Hersteller: 4x [Item]", only from the player's click).
-- The id, or nil and the reason.
function GO.Create(spell, n, mats, note, announce)
    if type(AmisiaDB) ~= "table" then return nil, L["Noch nicht geladen."] end
    if not on() then return nil, L["Gildenaufträge sind aus (Einstellungen, Gilde)."] end
    if not ns.InGuild() then return nil, L["Du bist in keiner Gilde."] end
    if not ns.CommAvailable() then return nil, L["Addon-Nachrichten sind nicht verfügbar."] end
    spell = tonumber(spell)
    local Pr = ns.Prof
    local r = spell and Pr and Pr.Recipe(spell)
    if not r then return nil, L["Kein Rezept."] end
    n = tonumber(n)
    if not ns.Int(n, 1, LIM.nMax) then return nil, L["Anzahl 1 bis %d."]:format(LIM.nMax) end
    if not VALID_MAT[mats] then return nil, L["Wähle, wer das Material bringt."] end
    if openCount() >= LIM.ownMax then
        return nil, L["Du hast schon %d offene Gildenaufträge; schließe erst einen."]:format(LIM.ownMax)
    end
    local me = myName()
    if not me then return nil, L["Noch nicht geladen."] end
    local o = store(true)
    local id = newId(o.own)
    if not id then return nil, L["Noch nicht geladen."] end
    local t = now()
    o.own[id] = { owner = me, rev = 1, spell = spell, item = (r.item or 0) > 0 and r.item or nil, n = n, mats = mats, state = "O",
        at = t, changed = t, note = GO.CleanNote(note) }
    due[id] = true
    changed()
    if announce then
        ns.Say(L["Suche Hersteller: %s"]:format(GO.What(o.own[id])), "GUILD")
    end
    if not GO.CanTalk() then ns.msg(L["Dein Gildenauftrag geht an die Gilde, sobald es wieder geht."]) end
    return id
end

-- Keeps the newest closed own orders of the character (5); older ones are forgotten once told.
local function pruneClosed()
    local o = store(false)
    if not o then return end
    local closed = {}
    for id, e in pairs(ownList()) do
        if e.state == "X" and not due[id] then closed[#closed + 1] = id end
    end
    if #closed <= LIM.closedMax then return end
    table.sort(closed, function(a, b)
        local ca, cb = o.own[a].changed or 0, o.own[b].changed or 0
        if ca ~= cb then return ca > cb end
        return a < b
    end)
    for i = LIM.closedMax + 1, #closed do o.own[closed[i]] = nil end
end
GO.PruneClosed = pruneClosed

local function closeOwn(id)
    local e = ownList()[id]
    if type(e) ~= "table" or e.state == "X" then return nil end
    e.state = "X"
    bump(id, e)
    pruneClosed()
    return true
end

-- "Zurückziehen": the own order closes (OA with X).
function GO.Withdraw(id) return closeOwn(id) end
-- "Erhalten": the done order closes (OA with X).
function GO.Received(id) return closeOwn(id) end

-- The own orders that are not closed: { { id, spell, item, n, mats, state, by, at, note } } oldest first.
function GO.Mine()
    local out = {}
    for id, e in pairs(ownList()) do
        if type(e) == "table" and e.state ~= "X" then
            out[#out + 1] = { id = id, spell = e.spell, item = e.item, n = e.n, mats = e.mats, state = e.state, by = e.by,
                at = e.at, note = e.note, own = true }
        end
    end
    table.sort(out, function(a, b)
        if a.at ~= b.at then return a.at < b.at end
        return a.id < b.id
    end)
    return out
end

-- "offen", "angenommen von Ben", "fertig: Ben".
function GO.StateText(o)
    if o.state == "T" then return L["angenommen von %s"]:format(o.by or "?") end
    if o.state == "D" then return L["fertig: %s"]:format(o.by or "?") end
    return L["offen"]
end

---------------------------------------------------------------------------
-- A crafter's step: OT to the requester (accept, give back, done)
---------------------------------------------------------------------------
local function heardList()
    local o = store(false)
    return o and o.heard or {}
end

local function heardOrder(sender, id)
    local list = heardList()
    for name, orders in pairs(list) do
        if ns.SameName(name, sender) and type(orders) == "table" and type(orders[id]) == "table" then
            return orders[id], name
        end
    end
    return nil
end
GO.Heard = heardOrder

local function mine(by) return by ~= nil and myName() ~= nil and ns.SameName(by, myName()) end
GO.IsMine = mine

-- Why a step on another's order cannot go now (a text), or nil.
function GO.StepBlocked(sender)
    if not on() then return L["Gildenaufträge sind aus (Einstellungen, Gilde)."] end
    local m = member(sender)
    if not m then return L["%s ist nicht mehr in der Gilde."]:format(sender) end
    if not m.online then return L["%s ist offline."]:format(m.name) end
    return nil
end

local function step(sender, id, act)
    local e, name = heardOrder(sender, id)
    if not e then return nil, L["Der Auftrag ist nicht mehr da."] end
    local why = GO.StepBlocked(name)
    if why then return nil, why end
    if act == "T" then
        if e.state ~= "O" then return nil, L["Schon angenommen von %s."]:format(e.by or "?") end
        if not GO.Crafter(e.spell) then return nil, L["Keiner deiner Charaktere kann das Rezept."] end
    elseif not mine(e.by) or (act == "D" and e.state ~= "T") or (act == "R" and e.state ~= "T" and e.state ~= "D") then
        return nil, L["Der Auftrag ist nicht bei dir."]
    end
    local key = name:lower() .. ":" .. id
    owedOT[key] = { to = name, id = id, act = act }
    asked[key], askedAt[key] = act, GetTime()
    if not GO.CanTalk() then ns.msg(L["Geht an %s, sobald es wieder geht."]:format(name)) end
    changed()
    return true
end

-- "Annehmen", "Fertig", "Abgeben": true, or nil and the reason.
function GO.Accept(sender, id) return step(sender, id, "T") end
function GO.Done(sender, id) return step(sender, id, "D") end
function GO.GiveBack(sender, id) return step(sender, id, "R") end

-- The own last step on another's order ("T", "R", "D"), nil.
function GO.Asked(sender, id)
    local key = tostring(sender):lower() .. ":" .. tostring(id)
    if asked[key] and askedAt[key] and GetTime() - askedAt[key] > LIM.askedFor then
        asked[key], askedAt[key] = nil, nil
    end
    return asked[key]
end

---------------------------------------------------------------------------
-- Others' orders
---------------------------------------------------------------------------
-- The guild's orders (heard, not closed, of members of the roster, never an own character): { { sender, class,
-- online, id, spell, item, n, mats, state, by, at, note, seen, crafter } }; crafter: the own character that knows
-- the recipe. Split in "für mich" (an own character knows it and it is open, or it is at the own character) and
-- the others; both oldest first.
function GO.Others()
    local forMe, rest = {}, {}
    local Pr = ns.Prof
    local built = ns.DataLoaded("PROFESSIONS")
    for name, orders in pairs(heardList()) do
        local m = type(orders) == "table" and member(name)
        if m and not isOwn(name) then
            for id, e in pairs(orders) do
                if type(e) == "table" and e.state ~= "X" and (not built or not Pr or Pr.Recipe(e.spell)) then
                    local x = { sender = m.name, class = m.class, online = m.online, id = id, spell = e.spell, item = e.item,
                        n = e.n, mats = e.mats, state = e.state, by = e.by, at = e.at, note = e.note, seen = e.seen,
                        crafter = GO.Crafter(e.spell) }
                    local atMe = mine(e.by)
                    if (x.crafter and e.state == "O") or atMe then forMe[#forMe + 1] = x else rest[#rest + 1] = x end
                end
            end
        end
    end
    local function order(a, b)
        if a.at ~= b.at then return a.at < b.at end
        return a.sender .. a.id < b.sender .. b.id
    end
    table.sort(forMe, order)
    table.sort(rest, order)
    return forMe, rest
end

-- How many open orders of the guild an own character can craft (the minimap tooltip, the login line).
function GO.ForMeCount()
    local n = 0
    for name, orders in pairs(heardList()) do
        if type(orders) == "table" and member(name) and not isOwn(name) then
            for _, e in pairs(orders) do
                if type(e) == "table" and e.state == "O" and GO.Crafter(e.spell) then n = n + 1 end
            end
        end
    end
    return n
end

-- The minimap button's line: "Gildenaufträge für dich: 2", nil without any.
function GO.TooltipLine()
    if not on() then return nil end
    local n = GO.ForMeCount()
    if n <= 0 then return nil end
    return L["Gildenaufträge für dich: %d"]:format(n)
end

-- The login line: "2 Gildenaufträge kannst du herstellen.", nil without any.
function GO.LoginLine()
    local n = GO.ForMeCount()
    if n <= 0 then return nil end
    if n == 1 then return L["1 Gildenauftrag kannst du herstellen."] end
    return L["%d Gildenaufträge kannst du herstellen."]:format(n)
end

-- The crafter's chat line of a new order: once per order, at most 6 an hour.
local told, chatTimes = {}, {}
local function crafterLine(sender, id, e)
    if not ns.Get("orders.chat") then return end
    local key = sender:lower() .. ":" .. id
    if told[key] then return end
    local t = GetTime()
    local keep = {}
    for _, x in ipairs(chatTimes) do
        if t - x < 3600 then keep[#keep + 1] = x end
    end
    chatTimes = keep
    if #chatTimes >= LIM.chatHour then return end
    told[key] = true
    chatTimes[#chatTimes + 1] = t
    local m = member(sender)
    ns.msg(L["Gildenauftrag von %s: %s. Seite Berufe > Aufträge."]:format(ns.ClassColored(sender, m and m.class), GO.What(e)))
end

local function countOpen(orders)
    local n = 0
    for _, e in pairs(orders) do
        if type(e) == "table" and e.state ~= "X" then n = n + 1 end
    end
    return n
end

local function dropOldest()
    local list = heardList()
    local total, oldest, oldName, oldId = 0, nil, nil, nil
    for name, orders in pairs(list) do
        for id, e in pairs(type(orders) == "table" and orders or {}) do
            total = total + 1
            local s = type(e) == "table" and e.seen or 0
            if not oldest or s < oldest or (s == oldest and name .. id < oldName .. oldId) then
                oldest, oldName, oldId = s, name, id
            end
        end
    end
    if total >= LIM.heardMax and oldName then
        list[oldName][oldId] = nil
        if next(list[oldName]) == nil then list[oldName] = nil end
        -- room for one more: below the cap (a lowered cap drops several)
        if total - 1 >= LIM.heardMax then return dropOldest() end
        return true
    end
    return false
end

-- A member's OA (fields checked by Comm): only orders of the sender; a revision not newer is only "seen"; X
-- drops it; 5 open per sender, 100 in all (the oldest heard falls); a recipe the built profession data lacks is
-- dropped. Returns what happened: "new", "update", "seen", "closed" or nil.
function GO.Take(sender, f)
    if not on() or type(f) ~= "table" or not validName(sender) then return nil end
    local id, r, spell, n = f[1], tonumber(f[2]), tonumber(f[3]), tonumber(f[4])
    local mats, st, by, age = f[5], f[6], f[7] ~= "-" and f[7] or nil, tonumber(f[8])
    if not validId(id) or not ns.Int(r, 1, LIM.revMax) or not ns.Int(spell, 1) or not ns.Int(n, 1, LIM.nMax)
        or not VALID_MAT[mats] or not VALID_STATE[st] or not ns.Int(age, 0, LIM.ageMax) then return nil end
    if (st == "T" or st == "D") and not validName(by) then return nil end
    local note = f[9] ~= "-" and f[9] or nil
    if note ~= nil and not validNote(note) then return nil end
    local item = tonumber(f[10]) or 0
    if not ns.Int(item, 0, 99999999) then item = 0 end
    local o = store(st ~= "X")
    if not o then return nil end
    local orders = o.heard[sender]
    local e = type(orders) == "table" and orders[id] or nil
    local t = now()
    if st == "X" then
        if not e then return nil end
        orders[id] = nil
        if next(orders) == nil then o.heard[sender] = nil end
        changed()
        return "closed"
    end
    if e and r <= e.rev then
        e.seen = t
        return "seen"
    end
    local Pr = ns.Prof
    if ns.DataLoaded("PROFESSIONS") and Pr and not Pr.Recipe(spell) then return nil end
    if not e then
        if type(orders) == "table" and countOpen(orders) >= LIM.perSender then return nil end
        dropOldest()
        orders = o.heard[sender]
        if type(orders) ~= "table" then
            orders = {}
            o.heard[sender] = orders
        end
    end
    local fresh = e == nil
    e = e or {}
    e.rev, e.spell, e.item, e.n, e.mats, e.state, e.by = r, spell, item > 0 and item or nil, n, mats, st, by
    e.at, e.changed, e.seen, e.note = t - age, t, t, note
    orders[id] = e
    if fresh and st == "O" and GO.Crafter(spell) then crafterLine(sender, id, e) end
    -- the own step answered: the order at the own character or at another
    local key = sender:lower() .. ":" .. id
    if asked[key] == "T" and st ~= "O" and not mine(by) then
        ns.msg(L["Schon angenommen von %s: %s."]:format(by or "?", GO.What(e)))
        asked[key] = nil
    end
    changed()
    return fresh and "new" or "update"
end

ns.CommOn("OA", function(sender, f, chan)
    if chan ~= "GUILD" and chan ~= "WHISPER" then return end
    local name = ns.TrustName(sender)
    if not name then return end
    ns.TrustWait(name, "member", function(ok)
        if ok and not isOwn(name) then GO.Take(name, f) end
    end)
end)

-- A crafter's step on an own order: only by whisper, only from a member, only an own open order; the first T
-- wins (the crafter is the sender); R and D only from that crafter. A step that does not fit gets the order's
-- state back by whisper. Returns whether the order changed.
function GO.TakeStep(sender, f)
    if not on() or type(f) ~= "table" then return false end
    local id, act = f[1], f[2]
    local e = ownList()[id]
    if type(e) ~= "table" then return false end
    local function back()
        local key = sender:lower() .. ":" .. id
        local t = GetTime()
        if (not backAt[key] or t - backAt[key] >= LIM.backGap) and ns.Count(backs) < LIM.answersMax then
            backs[key], backAt[key] = { to = sender, id = id }, t
        end
        return false
    end
    if e.state == "X" then return back() end
    if act == "T" then
        if e.state ~= "O" then return back() end
        e.state, e.by = "T", sender
        bump(id, e)
        ns.msg(L["%s hat deinen Gildenauftrag angenommen: %s."]:format(sender, GO.What(e)))
        return true
    end
    if not (e.by and e.by:lower() == sender:lower()) then return back() end
    if act == "D" then
        if e.state ~= "T" then return back() end
        e.state = "D"
        bump(id, e)
        ns.msg(L["%s: %s ist fertig."]:format(sender, GO.What(e)))
        return true
    end
    -- R: given back, open again
    e.state, e.by = "O", nil
    bump(id, e)
    return true
end

ns.CommOn("OT", function(sender, f, chan)
    if chan ~= "WHISPER" then return end
    local name = ns.TrustName(sender)
    if not name then return end
    ns.TrustWait(name, "member", function(ok)
        if ok then GO.TakeStep(name, f) end
    end)
end)

-- The question after a login: answered by whisper with the own orders (open, or closed within 3 days).
local function hasOwn()
    local t = now()
    for _, e in pairs(ownList()) do
        if type(e) == "table" and (e.state ~= "X" or t - (e.changed or 0) <= LIM.closedKeep) then return true end
    end
    return false
end

ns.CommOn("OQ", function(sender, f, chan)
    if chan ~= "GUILD" then return end
    local name = ns.TrustName(sender)
    if not name then return end
    ns.TrustWait(name, "member", function(ok)
        if not ok or not on() or not hasOwn() then return end
        if ns.Count(answers) >= LIM.answersMax then return end
        answers[name:lower()] = name
    end)
end)

---------------------------------------------------------------------------
-- The clock: what waits goes, the expiry
---------------------------------------------------------------------------
local lastSweep = -1e9
local askAt              -- GetTime() when the own OQ goes (once after the login, when it may)

-- Closes own orders unchanged for 14 days, forgets closed ones after 3 days and heard ones not heard for 14.
function GO.Sweep()
    local o = store(false)
    if not o then return end
    local t, limit, any = now(), LIM.days * 86400, false
    for id, e in pairs(o.own) do
        if type(e) ~= "table" then
            o.own[id] = nil
        elseif e.state ~= "X" and t - (e.changed or 0) > limit then
            e.state = "X"
            bump(id, e)
            any = true
        elseif e.state == "X" and t - (e.changed or 0) > LIM.closedKeep and not due[id] then
            o.own[id] = nil
            any = true
        end
    end
    for name, orders in pairs(o.heard) do
        if type(orders) == "table" then
            for id, e in pairs(orders) do
                if type(e) ~= "table" or t - (e.seen or 0) > limit then
                    orders[id] = nil
                    any = true
                end
            end
        end
        if type(orders) ~= "table" or next(orders) == nil then o.heard[name] = nil end
    end
    pruneClosed()
    if any then changed() end
end

local function tick()
    local t = GetTime()
    if t - lastSweep >= LIM.sweep then
        lastSweep = t
        GO.Sweep()
    end
    if not next(due) and not next(answers) and not next(backs) and not next(owedOT) and not askAt then return end
    if not canTalk() then return end
    if askAt and t >= askAt then
        askAt = nil
        ns.CommSend("OQ", { ("%04x"):format(math.floor(t * 1000) % 65536) }, "GUILD", nil, { key = "OQ", ttl = 60, low = true })
    end
    local own = ownList()
    for id in pairs(due) do
        local e = own[id]
        if type(e) ~= "table" then
            due[id] = nil
        elseif not sentAt[id] or t - sentAt[id] >= LIM.gapOA then
            if ns.CommSend("OA", GO.Fields(id, e), "GUILD", nil, { key = "OA:" .. id, ttl = 60, low = due[id] == "low" or nil }) then
                sentAt[id] = t
                due[id] = nil
            end
        end
    end
    for low, name in pairs(answers) do
        answers[low] = nil
        local m = member(name)
        if m and m.online then
            local tt = now()
            for id, e in pairs(own) do
                if type(e) == "table" and (e.state ~= "X" or tt - (e.changed or 0) <= LIM.closedKeep) then
                    ns.CommSend("OA", GO.Fields(id, e), "WHISPER", m.name, { key = "OA:W:" .. low .. ":" .. id,
                        jitter = LIM.answerJitter, ttl = 60, low = true, when = canTalk })
                end
            end
        end
    end
    for key, b in pairs(backs) do
        backs[key] = nil
        local m, e = member(b.to), own[b.id]
        if m and m.online and type(e) == "table" then
            ns.CommSend("OA", GO.Fields(b.id, e), "WHISPER", m.name, { key = "OA:W:" .. key, ttl = 60, when = canTalk })
        end
    end
    for key, s in pairs(owedOT) do
        local m = member(s.to)
        if not m or not m.online then
            owedOT[key] = nil
            asked[key] = nil
            ns.msg(L["%s ist offline."]:format(s.to))
            changed()
        elseif not otAt[key] or t - otAt[key] >= LIM.gapOT then
            if ns.CommSend("OT", { s.id, s.act }, "WHISPER", m.name, { key = "OT:" .. key, ttl = 60 }) then
                otAt[key] = t
                owedOT[key] = nil
            end
        end
    end
end
GO.Tick = tick
C_Timer.NewTicker(LIM.tick, ns.Perf.Wrap("Ticker GuildOrders", tick))

-- After the login (and a /reload): the own orders once to the guild (20-60 s, low), the question (30-60 s,
-- low, from the ticker once it may); the login line once per session (not after a /reload).
ns.OnEvent("PLAYER_LOGIN", function()
    askAt = GetTime() + LIM.askMin + spread(3) * LIM.askSpread
    C_Timer.After(LIM.announceMin + spread(11) * LIM.announceSpread, function()
        for id, e in pairs(ownList()) do
            if type(e) == "table" and not due[id] and (e.state ~= "X" or now() - (e.changed or 0) <= LIM.closedKeep) then
                due[id] = "low"
            end
        end
    end)
end)
local entered = false
ns.OnEvent("PLAYER_ENTERING_WORLD", function(_, isReload)
    if entered then return end
    entered = true
    if ns.Plain(isReload) == true then return end
    C_Timer.After(LIM.loginLine, function()
        if not on() or not ns.Get("orders.login") then return end
        local line = GO.LoginLine()
        if line then ns.msg(line) end
    end)
end)

-- The profession data was built (the page): orders of recipes it lacks go.
function GO.Check()
    if not ns.DataLoaded("PROFESSIONS") or not ns.Prof then return end
    local any = false
    for name, orders in pairs(heardList()) do
        for id, e in pairs(type(orders) == "table" and orders or {}) do
            if type(e) == "table" and not ns.Prof.Recipe(e.spell) then
                orders[id] = nil
                any = true
            end
        end
        if type(orders) == "table" and next(orders) == nil then heardList()[name] = nil end
    end
    if any then changed() end
end

---------------------------------------------------------------------------
-- /amisia auftraege
---------------------------------------------------------------------------
function GO.PrintOwn()
    local list = GO.Mine()
    if #list == 0 then
        ns.msg(L["Keine eigenen Gildenaufträge."])
    else
        for _, o in ipairs(list) do ns.msg(("%s: %s"):format(GO.What(o), GO.StateText(o))) end
    end
    local line = GO.LoginLine()
    if line then ns.msg(line) end
end

-- l10n-ok: the German command words
ns.RegisterSlash("auftraege", { en = "orders", aliases = { "aufträge", "auftrag" }, desc = L["Gildenaufträge: Herstellwünsche an die Gilde"],   -- l10n-ok: command words
    forever = true, run = function()
        if ns.ShowProfessions and ns.Prof and ns.Prof.Available() then
            ns.ShowProfessions("auftraege")
        else
            GO.PrintOwn()
        end
    end })

---------------------------------------------------------------------------
-- On load: AmisiaDB.orders checked
---------------------------------------------------------------------------
local function cleanEntry(e, heard)
    if type(e) ~= "table" then return nil end
    if not ns.Int(e.rev, 1, LIM.revMax) or not ns.Int(e.spell, 1) or not ns.Int(e.n, 1, LIM.nMax) then return nil end
    if not VALID_MAT[e.mats] or not VALID_STATE[e.state] or not whole(e.at) or not whole(e.changed) then return nil end
    if heard and (e.state == "X" or not whole(e.seen)) then return nil end
    if e.state == "T" or e.state == "D" then
        if not validName(e.by) then return nil end
    elseif e.state == "O" then
        e.by = nil
    elseif e.by ~= nil and not validName(e.by) then
        e.by = nil
    end
    if e.note ~= nil and not validNote(e.note) then e.note = nil end
    if e.item ~= nil and not (ns.Int(e.item, 1, 99999999)) then e.item = nil end
    if not heard and not validName(e.owner) then return nil end
    local keep = { owner = not heard or nil, rev = true, spell = true, item = true, n = true, mats = true, state = true, by = true, at = true,
        changed = true, note = true, seen = heard or nil }
    for k in pairs(e) do
        if not keep[k] then e[k] = nil end
    end
    return e
end

function ns.GuildOrdersLoaded(root)
    local o = type(root) == "table" and root.orders
    if o == nil then return end
    if type(o) ~= "table" then
        root.orders = nil
        return
    end
    local t, limit = now(), LIM.days * 86400
    local own, open, closed = {}, {}, {}
    for id, e in pairs(type(o.own) == "table" and o.own or {}) do
        e = validId(id) and cleanEntry(e, false)
        if e and (e.state ~= "X" or t - e.changed <= LIM.closedKeep) then
            own[id] = e
            local list = e.state ~= "X" and open or closed
            list[e.owner] = list[e.owner] or {}
            table.insert(list[e.owner], id)
        end
    end
    -- per character more than 5 open (or closed): the newest stay
    local function newest(lists, key)
        for _, ids in pairs(lists) do
            if #ids > LIM.ownMax then
                table.sort(ids, function(a, b)
                    if own[a][key] ~= own[b][key] then return own[a][key] > own[b][key] end
                    return a < b
                end)
                for i = LIM.ownMax + 1, #ids do own[ids[i]] = nil end
            end
        end
    end
    newest(open, "at")
    newest(closed, "changed")
    local heard, all = {}, {}
    for name, orders in pairs(type(o.heard) == "table" and o.heard or {}) do
        if validName(name) and type(orders) == "table" then
            local list, n = {}, {}
            for id, e in pairs(orders) do
                e = validId(id) and cleanEntry(e, true)
                if e and t - e.seen <= limit then n[#n + 1] = { id = id, e = e } end
            end
            table.sort(n, function(a, b)
                if a.e.seen ~= b.e.seen then return a.e.seen > b.e.seen end
                return a.id < b.id
            end)
            for i = 1, math.min(#n, LIM.perSender) do
                list[n[i].id] = n[i].e
                all[#all + 1] = { name = name, id = n[i].id, seen = n[i].e.seen }
            end
            if next(list) then heard[name] = list end
        end
    end
    if #all > LIM.heardMax then
        table.sort(all, function(a, b)
            if a.seen ~= b.seen then return a.seen > b.seen end
            return a.name .. a.id < b.name .. b.id
        end)
        for i = LIM.heardMax + 1, #all do
            local x = all[i]
            heard[x.name][x.id] = nil
            if next(heard[x.name]) == nil then heard[x.name] = nil end
        end
    end
    root.orders = { v = 1, own = own, heard = heard }
    rev = rev + 1
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name == ns.ADDON and AmisiaDB then ns.GuildOrdersLoaded(AmisiaDB) end
end)

---------------------------------------------------------------------------
-- Settings: the section Gildenaufträge (tab Gilde)
---------------------------------------------------------------------------
ns.RegisterSettings{ key = "orders", label = L["Gildenaufträge"], order = 57, group = "prof", pages = { "professions" }, forever = true, items = {
    { key = "orders.on", type = "toggle", label = L["Gildenaufträge"], default = true,
      tip = L["Aufträge an die Gilde stellen und annehmen (Seite Berufe, Reiter Aufträge). Aus: Amisia sendet und nimmt keine."] },
    { key = "orders.chat", type = "toggle", label = L["Chatzeile bei neuen Aufträgen"], default = true,
      tip = L["Eine Zeile im Chat, wenn jemand aus der Gilde einen Auftrag stellt, den einer deiner Charaktere herstellen kann; einmal je Auftrag, höchstens 6 je Stunde."] },
    { key = "orders.login", type = "toggle", label = L["Aufträge beim Einloggen"], default = true,
      tip = L["Sagt beim Einloggen einmal im Chat, wie viele Aufträge der Gilde deine Charaktere herstellen können."] },
    { key = "orders.announce", type = "toggle", label = L["Im Gildenchat ankündigen"], default = false,
      tip = L["Die Vorgabe im Fenster \"Auftrag stellen\": eine Zeile \"Suche Hersteller\" im Gildenchat für Mitglieder ohne Amisia, nur mit deinem Klick."] },
} }
end)
