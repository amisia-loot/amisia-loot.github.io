-- The fixes of the 2026-10-13 audit (2.30.1): the alt-click round only in the officer view, the
-- award's kind from a roll under the chat's short name, a lineup from a calendar event without an id,
-- unexported raids kept, an item stored once per session, the softres code keeping a dashed surname,
-- the settings search folding umlauts.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function roll(name, v) STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format(name, v, 1, 100)) end

STUB.roster = { { name = "Leiter Eins", class = "PRIEST" }, { name = "Vulo Sturmwind", class = "WARRIOR" },
                { name = "Fraktur Stein", class = "SHAMAN" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)

---------------------------------------------------------------------------
-- 1. alt-click in the loot window: a raider starts no round
---------------------------------------------------------------------------
STUB.loot = { { link = link, name = "Cursed Vision of Sargeras" } }
STUB.fire("LOOT_OPENED")
NS.Set("ui.view", "raider")
STUB.chat = {}
STUB.alt = true; HandleModifiedItemClick(link); STUB.alt = false
assert(NS.CurrentRoll() == nil, "the raider view starts no round")
assert(#STUB.chat == 0, "and announces nothing")
NS.Set("ui.view", "officer")
STUB.alt = true; HandleModifiedItemClick(link); STUB.alt = false
assert(NS.CurrentRoll() and NS.CurrentRoll().item == 32235, "the officer view still does")

---------------------------------------------------------------------------
-- 2. the chat's "Vulo" is the candidate "Vulo Sturmwind": the award's kind is MS
---------------------------------------------------------------------------
roll("Vulo", 70); roll("Fraktur", 20)
STUB.tick(25)
assert(NS.RollKind(32235, "Vulo Sturmwind") == "MS", tostring(NS.RollKind(32235, "Vulo Sturmwind")))
assert(NS.RollKind(32235, "Fraktur Stein") == "MS")
assert(NS.RollKind(32235, "Niemand Nirgends") == "-")
STUB.fire("LOOT_CLOSED"); STUB.loot = {}

---------------------------------------------------------------------------
-- 3. a lineup from a calendar event without an id stays with its event on a re-read
---------------------------------------------------------------------------
STUB.guild = { { name = STUB.player, rank = 1, class = "PRIEST" }, { name = "Anna Bergmann", rank = 3, class = "PRIEST" } }
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(1)
STUB.calendar({ events = { { title = "Molten Core", days = 2, eventType = 0, noId = true } } })
local list = NS.Cal.Events()
assert(#list == 1 and list[1].id == nil, "the event has no id")
local night = NS.LineupCalendar(list[1], { { name = "Anna Bergmann", classFilename = "PRIEST", level = 60, inviteStatus = 1 } }, true)
local n = NS.LineupNight(night)
assert(n and n.cal and n.cal.id == nil, "the night keeps the event without an id")
assert(NS.LineupCalendarAgain(night), "the officer may read again")
STUB.tick(2)
assert(not n.cal.lost, "found again by time and title, not lost")
-- another event of the same night is still another one
NS.LineupCalendar({ at = list[1].at, night = night, title = "Onyxia" }, {}, true)
assert(n.cal.title == "Onyxia", n.cal.title)

---------------------------------------------------------------------------
-- 4. the oldest raids go, but in the officer view not before the site has them
---------------------------------------------------------------------------
local function stop()
    NS.Set("record.enabled", false); STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(1)
    NS.Set("record.enabled", true)
end
stop()
local DB = AmisiaDB
DB.sessions = {}
local old = time() - 40 * 86400
for i = 1, 12 do
    DB.sessions[i] = { id = ("2026090%02d-1"):format(i), start = old + i, last = old + i, date = "2026-09-01", zone = "Alt " .. i,
        instanceID = 1, members = {}, loot = {}, items = {}, drops = {}, awards = {}, gone = {}, kills = {}, bench = {}, outside = {} }
end
NS.MarkExported({ DB.sessions[3], DB.sessions[4], DB.sessions[5] })
NS.Set("record.keepSessions", 10)
STUB.instance = { name = "Geschmolzener Kern", type = "raid", id = 409, diff = 9 }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
assert(NS.Active() and NS.Active().instanceID == 409, "a new raid runs")
local ids = {}
for _, s in ipairs(DB.sessions) do ids[s.id] = true end
assert(#DB.sessions == 10, "the exported ones made room: " .. #DB.sessions)
assert(ids["202609001-1"] and ids["202609002-1"], "unexported raids stay")
assert(not ids["202609003-1"] and not ids["202609004-1"] and not ids["202609005-1"], "exported raids went first")
-- the raider view keeps the old rule: the oldest go
stop()
NS.Set("ui.view", "raider")
NS.Set("record.keepSessions", 10)
DB.sessions[#DB.sessions + 1] = { id = "20260930-9", start = old, last = old, date = "2026-09-30", zone = "X", instanceID = 9,
    members = {}, loot = {}, items = {}, drops = {}, awards = {}, gone = {}, kills = {}, bench = {}, outside = {} }
local first = DB.sessions[1].id
STUB.instance = { name = "Onyxias Hort", type = "raid", id = 249, diff = 9 }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
assert(#DB.sessions == 10 and DB.sessions[1].id ~= first, "raider view: the oldest went")
NS.Set("ui.view", "officer")

---------------------------------------------------------------------------
-- 5. an item is stored once per session, not on every bag update
---------------------------------------------------------------------------
NS.Set("tools.collect", true)
local stores, store = 0, NS.StoreItem
NS.StoreItem = function(id) stores = stores + 1; return store(id) end
local potion = STUB.item(13444, "Major Mana Potion", 1)
STUB.items[13444].classID = 0   -- a consumable: complete without stats
assert(NS.NoteItem(potion) == true)
assert(NS.NoteItem(potion) == true and NS.NoteItem(13444) == true)
assert(stores == 1, "stored once: " .. stores)
NS.StoreItem = store

---------------------------------------------------------------------------
-- 6. the softres code: a dashed surname stays, a realm goes
---------------------------------------------------------------------------
local fh = assert(io.open(ADDON_DIR .. "/../tests/fixtures/softres_dash.txt", "rb"))
local code = fh:read("*a"):gsub("%s+$", "")
fh:close()
local byItem, count, bad = NS.ParseSoftRes(code)
assert(count == 3 and #bad == 0, "three names")
assert(byItem[18814][1] == "Anna Stein-Herz", tostring(byItem[18814][1]))
assert(byItem[17076][1] == "Bob", tostring(byItem[17076][1]))
assert(byItem[17204][1] == "Kim Sturmwind", tostring(byItem[17204][1]))

---------------------------------------------------------------------------
-- 7. the settings search folds umlauts
---------------------------------------------------------------------------
local it = { key = "x.y", label = "Übergabe im Handel", tip = "" }
assert(NS.SettingHits(it, NS.Fold("über")) and NS.SettingHits(it, NS.Fold("ÜBER")), "Ü and ü are one letter")
assert(not NS.SettingHits(it, NS.Fold("unter")))
