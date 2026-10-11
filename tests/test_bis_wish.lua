-- The wishlist (Bis.lua): add, change, remove, the limit of 50, items the class cannot wear; the
-- self clean-up from the bags and from the own loot line; the toast from the loot window, a group
-- loot roll, the loot lead's announcement in the raid chat and a raid warning, secret text skipped,
-- once per item in two minutes, one at a time with at most three waiting, never in battlegrounds,
-- upgrades only with their switch, sound only for wishes; the separate WL export; the move on load;
-- /amisia wunsch.
local Gear = NS.Gear
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
STUB.class, STUB.level = "WARRIOR", 60
STUB.instance = { name = "Geschmolzener Kern", type = "raid", id = 409 }

-- a small Forever data set; the client describes every item
local LINKS = {}
local function gear(id, name, loc, strength, sources, sub)
    LINKS[id] = STUB.item(id, name, 4)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID = "INVTYPE_" .. loc, 4, sub or 4
    it.stats, it.minLevel = { ITEM_MOD_STRENGTH_SHORT = strength }, 60
    if sources then
        NS.GEAR.I[id] = { loc, 4, sub or 4, 60, 4, 1, 70, 0, 0, 0 }
        for _, n in ipairs(sources) do NS.GEAR.I[id][#NS.GEAR.I[id] + 1] = n end
    end
    return LINKS[id]
end
NS.GEAR = { game = "forever", cap = 60, built = "test-wish", I = {}, Z = {},
    S = { { "X", "Geschmolzener Kern", "Ragnaros", 409, 2717, 0, 0 }, { "X", "Pechschwingenhort", "Nefarian", 469, 2677, 0, 0 } } }
Gear._reset()
gear(201, "Krone", "HEAD", 40, { 1 })
gear(202, "Gürtel der Hoffnung", "WAIST", 30, { 2 })
gear(203, "Brust", "CHEST", 50, { 1 })
gear(204, "Upgrade", "LEGS", 45, { 2 })
gear(205, "Stoffhose", "LEGS", 0, { 2 }, 1)
STUB.items[206] = { name = "Erz", quality = 1, link = STUB.link(206, "Erz", 1), equipLoc = "", classID = 7 }
LINKS[206] = STUB.items[206].link
local me = NS.BisChar()

---------------------------------------------------------------------------
-- add, change, remove
---------------------------------------------------------------------------
local e, why = NS.WishAdd(LINKS[201])
assert(e and e.prio == 2 and e.note == "" and e.t == STUB.now and me.wish[201] == e, "added with medium priority")
local e2 = NS.WishAdd(201, 3, "nur MS |x\nbitte")
assert(e2 == e and e.prio == 3 and e.note == "nur MS x bitte", "updated: " .. tostring(e.note))
assert(NS.WishAdd(201, nil, ("y"):rep(60)).note == ("y"):rep(40), "a note holds 40 bytes")
NS.WishAdd(201, 3, "nur MS")
e, why = NS.WishAdd("kein Link")
assert(e == nil and why == "Kein Item.", tostring(why))
e, why = NS.WishAdd(LINKS[206])
assert(e == nil and why == "Das kann dein Charakter nicht tragen.", "no gear: " .. tostring(why))
STUB.class = "PRIEST"
e, why = NS.WishAdd(202)
assert(e == nil and why == "Das kann dein Charakter nicht tragen.", "plate for a priest")
STUB.class = "WARRIOR"
assert(NS.WishAdd(202, 1))
assert(NS.WishSetPrio(202, 2) and me.wish[202].prio == 2)
assert(NS.WishRemove(202) == true and not me.wish[202])
assert(NS.WishRemove(202) == nil, "only once")

-- at most 50
for id = 3001, 3049 do STUB.item(id, "Kappe " .. id, 3) end
for id = 3001, 3049 do assert(NS.WishAdd(id), "wish " .. id) end
e, why = NS.WishAdd(202)
assert(e == nil and why == "Die Wunschliste ist voll (50).", tostring(why))
assert(NS.WishAdd(201, 2), "a wish already there still changes")
for id = 3001, 3049 do NS.WishRemove(id) end
NS.WishAdd(201, 3)

-- the list: priority, then name; owned and slot
NS.WishAdd(202, 1)
NS.WishAdd(203, 3)
local list = NS.Wishes()
assert(#list == 3 and list[1].id == 203 and list[2].id == 201 and list[3].id == 202, "by priority, then name")
assert(list[1].slot == "Brust" and has(list[1].src, "Geschmolzener Kern"), tostring(list[1].src))

---------------------------------------------------------------------------
-- the export for the website
---------------------------------------------------------------------------
NS.WishAdd(202, 1, "Notiz mit Leerzeichen")
me.wish[202].note = "Hand|bearbeitet"
local text = NS.WishExportText()
local lines = {}
for l in text:gmatch("[^\n]+") do lines[#lines + 1] = l end
assert(lines[1] == "#AMISIA 2 Vuloo" and lines[#lines] == "#END", text)
assert(lines[2] == ("WL 201 3 %d Vuloo nur MS"):format(me.wish[201].t), lines[2])
assert(lines[3] == ("WL 203 3 %d Vuloo"):format(me.wish[203].t), "priority, then item id: " .. lines[3])
assert(lines[4] == ("WL 202 1 %d Vuloo Handbearbeitet"):format(me.wish[202].t), "the bar goes: " .. lines[4])
assert(#lines == 5 and not has(text, "\nS ") and not has(text, "\nN "), "no raid blocks, no names")
me.wish[202].note = "Notiz mit Leerzeichen"
assert(has(NS.WishExportText(), "Vuloo Notiz mit Leerzeichen\n"), "a note with spaces is the last field")
-- the raid export does not change
local before = NS.ExportText({})
assert(not has(before, "WL "), "no wishes in the raid export")

---------------------------------------------------------------------------
-- self clean-up
---------------------------------------------------------------------------
STUB.messages = {}
STUB.bags[0] = { 202 }
STUB.fire("BAG_UPDATE_DELAYED"); STUB.tick(1.1)
assert(not me.wish[202], "a wish in the bags goes")
assert(has(STUB.messages[#STUB.messages], "Gürtel der Hoffnung von deiner Wunschliste genommen"), tostring(STUB.messages[#STUB.messages]))
-- switched off: it stays, marked
assert(NS.Set("bis.wishAutoRemove", false))
NS.WishAdd(202, 1)
STUB.bags[0] = {}
STUB.fire("BAG_UPDATE_DELAYED"); STUB.tick(1.1)
STUB.bags[0] = { 202 }
STUB.fire("BAG_UPDATE_DELAYED"); STUB.tick(1.1)
assert(me.wish[202], "kept")
for _, w in ipairs(NS.Wishes()) do if w.id == 202 then assert(w.owned == "bag", "marked as owned") end end
NS.Reset("bis.wishAutoRemove")
NS.WishRemove(202)
STUB.bags[0] = {}
STUB.fire("BAG_UPDATE_DELAYED"); STUB.tick(1.1)
-- the own loot line takes it off at once; another's does not
NS.WishAdd(203, 3)
STUB.fire("CHAT_MSG_LOOT", "Fraktur receives loot: " .. LINKS[203] .. ".")
assert(me.wish[203], "someone else's loot")
local secretLine = "You receive loot: " .. LINKS[203] .. "."
STUB.secret[secretLine] = true
STUB.fire("CHAT_MSG_LOOT", secretLine)
assert(me.wish[203], "a secret line is skipped")
STUB.secret = {}
STUB.fire("CHAT_MSG_LOOT", "You receive loot: " .. LINKS[203] .. ".")
assert(not me.wish[203], "own loot")

---------------------------------------------------------------------------
-- toasts
---------------------------------------------------------------------------
local toasts = {}
local real = NS.BisToast
NS.BisToast = function(id, why, link, src) toasts[#toasts + 1] = { id = id, why = why, src = src }; return real(id, why, link, src) end
local function clear() toasts = {}; STUB.tick(200) end
-- the loot window
STUB.target, STUB.targetGUID = "Prinz Malchezaar", "Creature-0-1-1-1-22917-1"
STUB.loot = { { link = LINKS[201] }, { link = LINKS[206] } }
local sounds = #STUB.sounds
STUB.fire("LOOT_OPENED")
assert(#toasts == 1 and toasts[1].id == 201 and toasts[1].why == "wish" and toasts[1].src == "Prinz Malchezaar", "a wish in the loot window")
assert(#STUB.sounds == sounds + 1 and STUB.sounds[#STUB.sounds] == SOUNDKIT.RAID_WARNING, "with the raid warning sound")
local f = AmisiaBisToast
assert(f and f:IsShown() and f.strata == "FULLSCREEN_DIALOG" and f._w == 320 and f._h == 58, "the toast frame")
assert(f.inherits and f.inherits.TooltipBackdropTemplate and f.NineSlice, "the client's tooltip ground and border")
assert(f.title:GetText() == "Wunsch droppt!" and has(f.item:GetText(), "Krone") and f.source:GetText() == "Prinz Malchezaar")
assert(not f.keyboard, "no keyboard input taken")
-- the same item again within two minutes: nothing
STUB.fire("LOOT_OPENED")
assert(#toasts == 1, "once per item in two minutes")
-- it goes after 8 seconds, unless the mouse is on it
f.scripts.OnEnter(f)
STUB.tick(9)
assert(f:IsShown(), "the mouse holds it")
f.scripts.OnLeave(f)
STUB.tick(1.1)
assert(not f:IsShown(), "gone after the mouse left")
clear()
-- a group loot roll
STUB.rolls[7] = LINKS[201]
STUB.fire("START_LOOT_ROLL", 7, 60)
assert(#toasts == 1 and toasts[1].src == "Würfeln", "a roll")
clear()
-- the loot lead's announcement and a raid warning
STUB.fire("CHAT_MSG_RAID", "Hallo " .. LINKS[201], "Vulo")
assert(#toasts == 0, "only lines that look like an announced item")
STUB.fire("CHAT_MSG_RAID_LEADER", "1. " .. LINKS[201] .. " SR: Fraktur", "Vulo")
assert(#toasts == 1 and toasts[1].src == "Ansage", "the announcement")
clear()
STUB.fire("CHAT_MSG_RAID_WARNING", "Roll auf " .. LINKS[201] .. ": /roll für Mainspec", "Vulo")
assert(#toasts == 1, "the raid warning of a roll start")
clear()
local secret = "2. " .. LINKS[201] .. " frei"
STUB.secret[secret] = true
STUB.fire("CHAT_MSG_RAID", secret, "Vulo")
assert(#toasts == 0, "secret chat is skipped")
STUB.secret = {}
STUB.chatLock = true
STUB.fire("CHAT_MSG_RAID", "2. " .. LINKS[201] .. " frei", "Vulo")
assert(#toasts == 0, "nothing during the chat lockdown")
STUB.chatLock = false
clear()
-- an upgrade that is no wish: no sound; only with its switch
sounds = #STUB.sounds
STUB.fire("CHAT_MSG_RAID", "1. " .. LINKS[204] .. " frei", "Vulo")
assert(#toasts == 1 and toasts[1].why == "upgrade" and #STUB.sounds == sounds, "an upgrade, silent")
assert(f.title:GetText() == "Upgrade für dich" and has(f.item:GetText(), "+90 (Beine)"), tostring(f.item:GetText()))
clear()
assert(NS.Set("bis.toastUpgrade", false))
STUB.fire("CHAT_MSG_RAID", "1. " .. LINKS[204] .. " frei", "Vulo")
assert(#toasts == 0, "upgrades switched off")
NS.Reset("bis.toastUpgrade")
STUB.fire("CHAT_MSG_RAID", "1. " .. LINKS[205] .. " frei", "Vulo")
assert(#toasts == 0, "no upgrade, no wish: nothing")
-- no sound without its switch
assert(NS.Set("bis.toastSound", false))
sounds = #STUB.sounds
STUB.fire("CHAT_MSG_RAID", "1. " .. LINKS[201] .. " frei", "Vulo")
assert(#toasts == 1 and #STUB.sounds == sounds, "silent wish")
NS.Reset("bis.toastSound")
clear()
-- owned items, battlegrounds, the main switch
STUB.bags[0] = { 204 }
STUB.fire("BAG_UPDATE_DELAYED"); STUB.tick(1.1)
STUB.fire("CHAT_MSG_RAID", "1. " .. LINKS[204] .. " frei", "Vulo")
assert(#toasts == 0, "nothing for what you have")
STUB.bags[0] = {}
STUB.fire("BAG_UPDATE_DELAYED"); STUB.tick(1.1)
STUB.instance = { name = "Arathibecken", type = "pvp", id = 529 }
STUB.fire("CHAT_MSG_RAID", "1. " .. LINKS[201] .. " frei", "Vulo")
assert(#toasts == 0, "not in a battleground")
STUB.instance = { name = "Geschmolzener Kern", type = "raid", id = 409 }
assert(NS.Set("bis.toast", false))
STUB.fire("CHAT_MSG_RAID", "1. " .. LINKS[201] .. " frei", "Vulo")
assert(#toasts == 0, "toasts switched off")
NS.Reset("bis.toast")
clear()

-- one at a time, at most three: the oldest waiting one goes
NS.WishAdd(202, 2)
NS.WishAdd(203, 2)
gear(207, "Hals", "NECK", 10, { 1 }, 0)
gear(208, "Rücken", "CLOAK", 10, { 1 }, 0)
NS.WishAdd(207, 2)
NS.WishAdd(208, 2)
STUB.fire("CHAT_MSG_RAID_WARNING", LINKS[201] .. " " .. LINKS[202] .. " " .. LINKS[203] .. " " .. LINKS[207] .. " " .. LINKS[208], "Vulo")
assert(#toasts == 5, "five toasts asked for")
local st = NS.BisToastState()
assert(st.shown == 201 and #st.queue == 2 and st.queue[1] == 207 and st.queue[2] == 208, "one shown, two waiting, the oldest waiting went")
STUB.tick(8.1)
st = NS.BisToastState()
assert(st.shown == 207 and #st.queue == 1, "the next one follows")
-- clicks: shift posts the link, right closes, left opens the page at the slot
STUB.shift = true
f.scripts.OnClick(f, "LeftButton")
assert(STUB.inserted == LINKS[207] and f:IsShown(), "shift-click posts the link")
STUB.shift = false
f.scripts.OnClick(f, "RightButton")
st = NS.BisToastState()
assert(st.shown == 208 and #st.queue == 0, "right click closes, the next shows")
f.scripts.OnClick(f, "LeftButton")
assert(AmisiaDB.settings.bis.view == "goals" and AmisiaDB.settings.bis.slot == "BACK" and not f:IsShown(), "click opens the targets at the slot")
assert(NS.BisToastState().shown == nil)

---------------------------------------------------------------------------
-- /amisia wunsch
---------------------------------------------------------------------------
NS.WishRemove(201)
NS.Dispatch("wunsch " .. LINKS[201] .. " hoch für Tank Set")
assert(me.wish[201] and me.wish[201].prio == 3 and me.wish[201].note == "für Tank Set", "added by command")
NS.Dispatch("wunsch 201 niedrig")
assert(me.wish[201].prio == 1, "by item id")
NS.Dispatch("wunsch weg " .. LINKS[201])
assert(not me.wish[201], "removed by command")
STUB.messages = {}
NS.Dispatch("wunsch " .. LINKS[206])
assert(has(STUB.messages[#STUB.messages], "nicht tragen"), "the reason shows")
NS.Dispatch("wunsch")
assert(AmisiaDB.settings.bis.view == "wish", "/amisia wunsch opens the list")

---------------------------------------------------------------------------
-- the move on load: twice changes nothing, broken entries go, the oldest of too many wishes go
---------------------------------------------------------------------------
local many = {}
for i = 1, 55 do many[4000 + i] = { t = 1000 + i, prio = 2, note = "" } end
many["4100"] = { t = 5000, prio = 9, note = ("n|"):rep(30) }
many.bad = { t = 1 }
many[4200] = "kaputt"
AmisiaDB.bis = { v = 1, chars = {
    ["Anna"] = { class = "PRIEST", wish = many, ex = { item = { ["17"] = true, x = true }, boss = { [5] = true, Gruul = true } },
                 bag = { [1] = 5, [2] = "x" } },
    [7] = { class = "MAGE" },
    ["Kaputt"] = "nein",
}, guild = { game = "forever", list = { [28830] = { { name = "Anna", prio = 3 } }, abc = {} } } }
NS.BisMigrate(AmisiaDB)
local anna = AmisiaDB.bis.chars.Anna
local n = 0
for id, w in pairs(anna.wish) do
    n = n + 1
    assert(type(id) == "number" and w.prio >= 1 and w.prio <= 3 and #w.note <= 40 and not has(w.note, "|"), "wish " .. tostring(id))
end
assert(n == 50 and anna.wish[4100] and anna.wish[4100].prio == 3 and not anna.wish[4001] and not anna.wish[4006] and anna.wish[4007], "the oldest went: " .. n)
assert(anna.ex.item[17] and not anna.ex.item.x and anna.ex.boss.Gruul and not anna.ex.boss[5] and anna.ex.place, "exclusions checked")
assert(anna.bag[1] == 5 and not anna.bag[2] and anna.bank, "seen items checked")
assert(not AmisiaDB.bis.chars[7] and not AmisiaDB.bis.chars.Kaputt, "broken characters go")
assert(AmisiaDB.bis.guild.list[28830] and not AmisiaDB.bis.guild.list.abc, "guild wishes without a number key go")
local function dump(t, seen)
    if type(t) ~= "table" then return tostring(t) end
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local out = {}
    for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "=" .. dump(t[k]) end
    return "{" .. table.concat(out, ",") .. "}"
end
local once = dump(AmisiaDB.bis)
NS.BisMigrate(AmisiaDB)
assert(dump(AmisiaDB.bis) == once, "twice changes nothing")
-- a missing table gets its shape on first use
AmisiaDB.bis = nil
assert(NS.BisChar() and AmisiaDB.bis.v == 1 and type(AmisiaDB.bis.chars) == "table")

-- wishes need no data set
NS.GEAR = nil
assert(NS.WishAdd(201, 2), "a wish needs only the item id")
assert(has(NS.WishExportText(), "WL 201 2 "))
