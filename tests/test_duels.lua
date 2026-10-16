-- Duels (F-106, Core/Duels.lua, UI/Pages/Duels.lua): the system message of a duel (knockout and
-- flight, the templates' order of names), own and nearby duels, the same message twice, a secret
-- message; the classes from the own character, target, mouseover, name plates, guild, friends and
-- /who on a click (zone first, then one name; the gap; the answer); the saved data's checks, caps
-- and age; the tournament; the leaderboard, the class table and the coverage; the page with its
-- three views, the class picker, the search, a click on a name.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local D = NS.Duels

_G.DUEL_WINNER_KNOCKOUT = "%1$s hat %2$s in einem Duell besiegt."
_G.DUEL_WINNER_RETREAT = "%2$s ist vor %1$s aus einem Duell geflohen."
STUB.zone, STUB.subzone = "Durotar", "Tor von Orgrimmar"
_G.GetRealZoneText = function() return STUB.zone end
_G.GetSubZoneText = function() return STUB.subzone end
STUB.units = {}
local name0, class0 = _G.UnitName, _G.UnitClass
_G.UnitName = function(u)
    local e = STUB.units[u]
    if e then return e[1], e[3] end
    return name0(u)
end
_G.UnitClass = function(u)
    local e = STUB.units[u]
    if e then return e[2], e[2] end
    return class0(u)
end
_G.UnitIsPlayer = function(u) return u == "player" or (STUB.units[u] ~= nil and STUB.units[u][2] ~= nil) end

STUB.player = "Vuloo"
STUB.class = "PRIEST"
local function say(text) STUB.fire("CHAT_MSG_SYSTEM", text) end

---------------------------------------------------------------------------
-- reading the messages
---------------------------------------------------------------------------
local w, l, k = D.Parse("Tuoppi Foreverpvp hat Beasty Foreverpvp in einem Duell besiegt.")
assert(w == "Tuoppi Foreverpvp" and l == "Beasty Foreverpvp" and k == "K", tostring(w))
w, l, k = D.Parse("Beasty Foreverpvp ist vor Tuoppi Foreverpvp aus einem Duell geflohen.")
assert(w == "Tuoppi Foreverpvp" and l == "Beasty Foreverpvp" and k == "F", "the flight: the second name of the template wins")
assert(D.Parse("Tuoppi hat sich der Gruppe angeschlossen.") == nil, "any other message")
w = D.Parse("|cffffffff|Hplayer:Anna|h[Anna]|h|r hat Bob in einem Duell besiegt.")
assert(w == "Anna", "a player link is cleaned")
assert(D.Parse("Anna hat Anna in einem Duell besiegt.") == nil, "the same name twice")

assert(AmisiaDB.duels and AmisiaDB.duels.v == 1 and #AmisiaDB.duels.list == 0, "the key is shaped at login")
say("Tuoppi Foreverpvp hat Beasty Foreverpvp in einem Duell besiegt.")
assert(D.Count() == 1, D.Count())
say("Tuoppi Foreverpvp hat Beasty Foreverpvp in einem Duell besiegt.")
assert(D.Count() == 1, "the same message within 3 s counts once")
STUB.tick(4)
say("Tuoppi Foreverpvp hat Beasty Foreverpvp in einem Duell besiegt.")
assert(D.Count() == 2, "a rematch counts")
local r = D.All()[1]
assert(r.w == "Tuoppi Foreverpvp" and r.l == "Beasty Foreverpvp" and r.k == "K" and r.z == "Durotar · Tor von Orgrimmar", r.z)
assert(AmisiaDB.duels.zones[1] == "Durotar · Tor von Orgrimmar" and #AmisiaDB.duels.zones == 1, "one zone entry")
-- a secret message is skipped
local secret = "Anna hat Bob in einem Duell besiegt."
STUB.secret[secret] = true
say(secret)
assert(D.Count() == 2, "a secret message is never read")
STUB.secret[secret] = nil

-- duels.nearby off: only the own duels
NS.Set("duels.nearby", false)
STUB.tick(4)
say("Anna hat Bob in einem Duell besiegt.")
assert(D.Count() == 2, "nearby off: a stranger's duel is not kept")
say("Kovu Foreverpvp hat Vuloo in einem Duell besiegt.")
assert(D.Count() == 3, "nearby off: the own duel is kept")
NS.Set("duels.nearby", true)
NS.Set("duels.record", false)
STUB.tick(4)
say("Anna hat Bob in einem Duell besiegt.")
assert(D.Count() == 3, "record off: nothing")
NS.Set("duels.record", true)

---------------------------------------------------------------------------
-- classes
---------------------------------------------------------------------------
assert(D.ClassOf("Vuloo") == "PRIEST", "the own class at once")
assert(D.UnknownCount() == 3, D.UnknownCount())   -- Tuoppi, Beasty, Kovu
STUB.units.target = { "Tuoppi", "WARLOCK", "Foreverpvp" }
STUB.fire("PLAYER_TARGET_CHANGED")
assert(D.ClassOf("Tuoppi Foreverpvp") == "WARLOCK", "from the target (first name + surname)")
STUB.units.mouseover = { "Somebody", "MAGE", "Else" }
STUB.fire("UPDATE_MOUSEOVER_UNIT")
assert(D.ClassOf("Somebody Else") == nil and D.UnknownCount() == 2, "a name of no duel is not kept")
STUB.units.nameplate3 = { "Beasty", "ROGUE", "Foreverpvp" }
NS.Set("duels.plates", false)
STUB.fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
assert(D.ClassOf("Beasty Foreverpvp") == nil, "plates off")
NS.Set("duels.plates", true)
STUB.fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
assert(D.ClassOf("Beasty Foreverpvp") == "ROGUE", "from a name plate")
STUB.units.target = { "Kovu", "BADCLASS", "Foreverpvp" }
STUB.fire("PLAYER_TARGET_CHANGED")
assert(D.ClassOf("Kovu Foreverpvp") == nil, "a token that is no class")
-- the guild roster
STUB.guild = { { name = "Vuloo", class = "PRIEST", rank = 2 }, { name = "Kovu Foreverpvp", class = "DRUID", rank = 3 } }
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)
assert(D.FillKnown(true) == 1 and D.ClassOf("Kovu Foreverpvp") == "DRUID", "from the guild roster")
-- friends (localized class name)
STUB.tick(4)
say("Anna Amboss hat Bob Eisherz in einem Duell besiegt.")
STUB.friends = { { name = "Anna Amboss", className = "Krieger" } }
D.FillKnown(true)
assert(D.ClassOf("Anna Amboss") == "WARRIOR", "from the friend list")

-- a message with the first name only learns from a full name
STUB.tick(4)
say("Solo hat Vuloo in einem Duell besiegt.")
STUB.units.target = { "Solo", "HUNTER", "Weit" }
STUB.fire("PLAYER_TARGET_CHANGED")
assert(D.ClassOf("Solo") == "HUNTER", "first name of a full name")

---------------------------------------------------------------------------
-- /who on a click
---------------------------------------------------------------------------
local sent, toUi = {}, {}
STUB.who = {}
_G.C_FriendList.SendWho = function(q) sent[#sent + 1] = q end
_G.C_FriendList.SetWhoToUi = function(on) toUi[#toUi + 1] = on end
_G.C_FriendList.GetNumWhoResults = function() return #STUB.who, #STUB.who end
_G.C_FriendList.GetWhoInfo = function(i) return STUB.who[i] end
assert(D.UnknownCount() == 1, D.UnknownCount())   -- Bob
-- the client's who list opens itself on an answer (Forever: LFGParentFrame); closed before, it is closed again
local hidden = 0
_G.LFGParentFrame = { shown = false, IsShown = function(self) return self.shown end }
_G.HideUIPanel = function(fr) fr.shown = false hidden = hidden + 1 end
local ok = D.WhoAsk()
assert(ok and sent[1] == 'z-"Durotar"', tostring(sent[1]))
assert(toUi[1] == true, "the answer goes to the list, not the chat")
local ok2, why = D.WhoAsk()
assert(not ok2 and has(why, "warten"), tostring(why))
STUB.who = { { fullName = "Bob Eisherz", filename = "PALADIN" }, { fullName = "Zed", filename = "MAGE" } }
STUB.messages = {}
LFGParentFrame.shown = true      -- the client's handler opened it
STUB.fire("WHO_LIST_UPDATE")
STUB.tick(0.1)
assert(hidden == 1 and not LFGParentFrame.shown, "the who list Amisia's question opened is closed again")
assert(D.ClassOf("Bob Eisherz") == "PALADIN" and D.UnknownCount() == 0, "the answer teaches the class")
assert(toUi[2] == false, "SetWhoToUi back")
assert(has(STUB.messages[#STUB.messages], "brachte 1 Klassen"), tostring(STUB.messages[#STUB.messages]))
local ok3, why3 = D.WhoAsk()
assert(not ok3 and has(why3, "bekannt"), "nothing to ask")
-- the next one asks a name (first name only), the zone was asked
STUB.tick(6)
say("Neu Mann hat Vuloo in einem Duell besiegt.")
STUB.tick(6)
assert(D.WhoAsk() and sent[2] == 'n-"Neu"', tostring(sent[2]))
STUB.tick(7)
assert(D.WhoWait() == 0, "a lost answer stops waiting")
local ok4, why4 = D.WhoAsk()
assert(not ok4 and has(why4, "gefragt"), tostring(why4))

---------------------------------------------------------------------------
-- tournament, leaderboard, classes
---------------------------------------------------------------------------
assert(D.TourStart() and D.Tour().n == 1 and D.Tour().on, "tournament 1 runs")
STUB.tick(4)
say("Tuoppi Foreverpvp hat Kovu Foreverpvp in einem Duell besiegt.")
assert(D.TourStop() and not D.Tour().on, "stopped")
assert(D.All()[1].n == 1 and D.All()[2].n == nil, "only the duel inside is marked")
assert(#D.Filter({ tour = true }) == 1, "only the tournament")

local board = D.Board(D.Filter({}))
assert(board[1].name == "Tuoppi Foreverpvp" and board[1].g == 3 and board[1].w == 3 and board[1].r == 1, board[1].name)
for _, e in ipairs(board) do
    if e.g < D.MIN_GAMES then assert(e.rank > 1, "under three duels after the ranked ones") end
end
assert(#D.Board(D.Filter({}), { class = "ROGUE" }) == 1, "players of a class")
local byName = D.Board(D.Filter({}), { sort = "name" })
assert(byName[1].name == "Anna Amboss", byName[1].name)

local rows = D.Filter({})
local cls, known, sides = D.ClassTable(rows)
assert(sides == #rows * 2 and known == sides - 1, ("%d %d"):format(known, sides))   -- Neu Mann unknown
assert(cls[1].c == "WARLOCK" and cls[1].g == 3 and cls[1].w == 3 and cls[1].p == 1, cls[1].c)
local rogue
for _, e in ipairs(cls) do if e.c == "ROGUE" then rogue = e end end
assert(rogue.g == 2 and rogue.l == 2 and rogue.r == 0, "Beasty lost twice")
local vs = D.ClassTable(rows, "WARLOCK")
assert(#vs == 2, #vs)   -- against ROGUE (2) and DRUID (1)
assert(vs[1].w + vs[2].w == 3, "the warlock's wins by opponent")

---------------------------------------------------------------------------
-- saved data: checks, age, cap
---------------------------------------------------------------------------
local now = STUB.now
local root = { duels = { list = {
    ("%d\tA\tB\t1\tK"):format(now - 10), ("%d\tA\tB\t9\tF\t2"):format(now - 5), "bad", ("%d\tA|cff\tB\t1\tK"):format(now),
    ("%d\tOld\tB\t1\tK"):format(now - 91 * 86400), ("%d\tA\tA\t1\tK"):format(now),
}, zones = { "Durotar", "Unused" }, cls = { A = "MAGE", B = "NOPE", C = "ROGUE" }, tour = { n = 2, on = "x" }, junk = 1 } }
local d = NS.DuelsLoaded(root, now)
assert(#d.list == 2, #d.list)
assert(d.list[1] == ("%d\tA\tB\t1\tK"):format(now - 10) and d.list[2] == ("%d\tA\tB\t0\tF\t2"):format(now - 5), d.list[2])
assert(#d.zones == 1 and d.zones[1] == "Durotar", "unused zones go")
assert(d.cls.A == "MAGE" and d.cls.B == nil and d.cls.C == nil, "classes checked and only for names of the list")
assert(d.tour.n == 2 and d.tour.on == nil and d.junk == nil, "tour checked, other keys dropped")
local big = { duels = { list = { ("%d\tA\tB\t0\tK\t99999999999999999999"):format(now - 1) } } }
NS.DuelsLoaded(big, now)
assert(big.duels.list[1] == ("%d\tA\tB\t0\tK"):format(now - 1), "a tournament number out of bounds goes, the duel stays")
local again = STUB.dump(d)
NS.DuelsLoaded(root, now)
assert(STUB.dump(root.duels) == again, "twice changes nothing")
local many = { duels = { list = {}, zones = { "Z" } } }
for i = 1, D.MAX + 30 do many.duels.list[i] = ("%d\tA%d\tB\t1\tK"):format(now - 100000 + i, i) end
NS.DuelsLoaded(many, now)
assert(#many.duels.list == D.MAX and many.duels.list[1]:find("\tA31\t", 1, true), "the newest D.MAX")

---------------------------------------------------------------------------
-- the page
---------------------------------------------------------------------------
local panel = assert(NS.Panel("duels"))
assert(panel.group == "pvp" and not panel.officer and not panel.expert, "tab PvP, everyone")
NS.Set("ui.view", "raider")
assert(NS.Visible(panel), "raiders see it")
NS.ShowPage("duels")
local f = assert(NS.DuelsPageFrame())
assert(f.histView:IsShown() and not f.boardView:IsShown(), "the history first")
local items = f.histList.items
assert(#items == D.Count() and items[1].w == "Tuoppi Foreverpvp", "newest first")
local row = f.histList.rows[1]
assert(has(row.w.top:GetText(), "Tuoppi Foreverpvp"), row.w.top:GetText())
RAID_CLASS_COLORS.WARLOCK = { r = 0.53, g = 0.53, b = 0.93, colorStr = "ff8787ed" }
assert(has(row.w.sub:GetText(), "Hexenmeister") and has(row.k:GetText(), "Sieg") and has(row.z:GetText(), "Durotar")
    and not has(row.z:GetText(), "Tor"), row.z:GetText())
assert(has(f.data:GetText(), D.Count() .. " Duelle aufgezeichnet"), f.data:GetText())
assert(has(f.who:GetText(), "Klassen suchen (1)"), f.who:GetText())
-- a click on a name: only his duels
row.w.scripts.OnClick(row.w, "LeftButton")
assert(f.search:GetText() == "Tuoppi Foreverpvp", f.search:GetText())
assert(#f.histList.items == 3 and has(f.data:GetText(), "Tuoppi Foreverpvp: 3 Duelle, 3 - 0"), f.data:GetText())
-- "Tuoppi Foreverpvp" is no part of another name here; a part search still finds more
f.search:SetText("")
f.search.scripts.OnTextChanged(f.search, true)
assert(#f.histList.items == 3, "the clear button lifts the filter only through a commit")
assert(f.search.lastCommit == "Tuoppi Foreverpvp", "the click's name counts as committed")
f.search.clearButton.scripts.OnClick(f.search.clearButton)
assert(#f.histList.items == D.Count(), "the clear button shows every duel again")
-- the leaderboard
f.views.board.scripts.OnClick(f.views.board)
assert(f.boardView:IsShown() and f.boardList.items[1].name == "Tuoppi Foreverpvp", "the leaderboard")
assert(has(f.boardList.rows[1].rate:GetText(), "100"), f.boardList.rows[1].rate:GetText())
-- the classes, then one class against the others
f.views.classes.scripts.OnClick(f.views.classes)
assert(f.classView:IsShown() and has(f.data:GetText(), "Klassen bekannt"), f.data:GetText())
assert(has(f.classList.rows[1].class:GetText(), "1. Hexenmeister"), f.classList.rows[1].class:GetText())
f.classList.rows[1].scripts.OnClick(f.classList.rows[1])
assert(AmisiaDB.settings.window.duels.class == "WARLOCK" and #f.classList.items == 2, "a click chooses the class")
assert(has(f.classHeads.class:GetText(), "Hexenmeister gegen"), f.classHeads.class:GetText())
-- the tournament chip
f.tourChip.scripts.OnClick(f.tourChip)
assert(AmisiaDB.settings.window.duels.tour == true and has(f.data:GetText(), "Turnier 1"), f.data:GetText())

-- the command
NS.ShowPage("overview")
SlashCmdList.AMISIA("duelle")
assert(NS.CurrentPage() == "duels", "/amisia duelle")
print("duels ok")
