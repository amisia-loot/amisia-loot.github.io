-- The award history (Raid/AwardHistory.lua): the item tooltip "Vergeben: ..." (newest first, at
-- most three, "+N weitere", bank and disenchant, an alt with its main, deleted and undone awards
-- left out, the setting awards.tooltip), the index dropped on every change of the book, and the
-- roll window's row tooltip with what the roller got in the last four weeks.
local DAY = 86400
local now = STUB.now
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
for _, k in ipairs({ "bis.tooltip", "drops.tooltip", "prio.tooltip", "softres.tooltip" }) do
    if NS.SettingItem(k) then NS.Set(k, false) end
end

local function raid(id, ago)
    local start = now - ago * DAY
    local s = { id = id, date = date("%Y-%m-%d", start), zone = "Der Schwarze Tempel", instanceID = 564, start = start, last = start + 3600,
                members = { Fraktur = { class = "SHAMAN", first = start, last = start + 3000 } }, loot = {}, items = {}, drops = {},
                awards = {}, gone = {}, kills = {}, bench = {}, outside = {} }
    AmisiaDB.sessions[#AmisiaDB.sessions + 1] = s
    return s
end
local function award(s, name, item, kind, hour, to)
    return NS.AddAwardTo(s, { name = name, item = item, kind = kind, src = "?", t = s.start + (hour or 0) * 3600, to = to })
end

local old = raid("old", 40)
local mid = raid("mid", 20)
local new = raid("new", 3)
assert(NS.SetAlts("#AMISIA-ALTS 1 forever 2026-10-01\nA Kleinfrak Fraktur\n#END"))

-- the tooltip of the shared hook, as the client builds it
local lines = {}
GameTooltip.AddLine = function(_, t) lines[#lines + 1] = t end
local shown
GameTooltip.GetItem = function() return "x", shown end
local function hover(id)
    shown = STUB.item(id, "Item " .. id, 4)
    for k in pairs(lines) do lines[k] = nil end
    if GameTooltip.scripts.OnTooltipCleared then GameTooltip.scripts.OnTooltipCleared(GameTooltip) end
    STUB.showTooltip(GameTooltip)
    return lines
end

---------------------------------------------------------------------------
-- one award: the name, the kind and the day
---------------------------------------------------------------------------
award(new, "Fraktur", 5001, "MS", 1)
hover(5001)
assert(#lines == 1 and lines[1] == "Vergeben: Fraktur (MS), " .. date("%d.%m.", new.start + 3600), table.concat(lines, " / "))
assert(#hover(5002) == 0, "an item never given out has no line")

---------------------------------------------------------------------------
-- newest first, at most three, "+N weitere"; bank, disenchant and an alt
---------------------------------------------------------------------------
award(old, "Anna", 5003, "OS", 1)
award(mid, "-", 5003, "-", 1, "bank")
award(mid, "Kleinfrak", 5003, "MS", 2)
award(new, "-", 5003, "-", 1, "de")
award(new, "Bob", 5003, "-", 2)
hover(5003)
assert(#lines == 4, table.concat(lines, " / "))
assert(lines[1] == "Vergeben: Bob, " .. date("%d.%m.", new.start + 7200), lines[1])
assert(lines[2] == "Vergeben: Entzaubern, " .. date("%d.%m.", new.start + 3600), lines[2])
assert(lines[3] == "Vergeben: Kleinfrak (Twink von Fraktur, MS), " .. date("%d.%m.", mid.start + 7200), lines[3])
assert(lines[4] == "+2 weitere", lines[4])
-- the bank shows as such further down the list
local all = NS.AwardsOfItem(5003)
assert(#all == 5 and all[4].to == "bank" and all[5].name == "Anna")

---------------------------------------------------------------------------
-- a deleted award and an undone one are left out; the index follows every change
---------------------------------------------------------------------------
local gone = award(new, "Chorf", 5004, "MS", 3)
hover(5004)
assert(#lines == 1 and has(lines[1], "Chorf"))
assert(NS.AwardHistoryBuilt(), "the tooltip built the index")
NS.DeleteAward(new, gone.id)
assert(not NS.AwardHistoryBuilt(), "a deleted award drops the index")
assert(#hover(5004) == 0, "a deleted award is not shown")
assert(NS.UndoAward(), "undo brings it back")
assert(#hover(5004) == 1, "the undone delete shows the award again")
award(new, "Dora", 5004, "OS", 4)
assert(not NS.AwardHistoryBuilt(), "a new award drops the index")
hover(5004)
assert(#lines == 2 and has(lines[1], "Dora (OS)") and has(lines[2], "Chorf (MS)"), table.concat(lines, " / "))
assert(NS.UndoAward(), "undo of the new award")
hover(5004)
assert(#lines == 1 and has(lines[1], "Chorf"), "the undone award is gone: " .. table.concat(lines, " / "))
-- an edit (another winner) shows at once
NS.EditAward(new, gone.id, { name = "Anna" })
hover(5004)
assert(#lines == 1 and has(lines[1], "Anna (MS)"), table.concat(lines, " / "))

-- a tooltip reads the index, it does not walk the raids: a change past the book (no event) is not seen
new.awards[#new.awards + 1] = { id = "aaaaaaaaaaaa", name = "Ghost", item = 5005, kind = "MS", t = new.start, to = "player" }
assert(#hover(5005) == 0, "the index is kept between tooltips")
NS.Fire("DATA_CHANGED")
assert(#hover(5005) == 1, "and built again after a change")
table.remove(new.awards)
NS.Fire("DATA_CHANGED")

-- a deleted raid gives a new raid list: the index follows it
local extra = raid("extra", 1)
award(extra, "Fraktur", 5006, "MS", 1)
assert(#hover(5006) == 1)
NS.DeleteSessions({ extra = true })
assert(#hover(5006) == 0, "the deleted raid's award is gone")

---------------------------------------------------------------------------
-- the setting
---------------------------------------------------------------------------
assert(NS.Get("awards.tooltip") == true, "on by default")
assert(NS.Set("awards.tooltip", false))
assert(#hover(5001) == 0, "switched off")
NS.Reset("awards.tooltip")
assert(#hover(5001) == 1)
-- the line is everyone's: a raider sees it too, and the setting
assert(NS.Set("ui.view", "raider"))
assert(#hover(5001) == 1, "a raider sees who got the item")
assert(NS.Visible(NS.SettingItem("awards.tooltip")) and NS.Visible(NS.SettingItem("awards.tooltip").section), "a raider finds the setting")
assert(not NS.Visible(NS.SettingItem("awards.plusScope")), "the officers' award settings stay theirs")
NS.Reset("ui.view")

---------------------------------------------------------------------------
-- what a player got: the last four weeks (every character), the split, the newest item
---------------------------------------------------------------------------
-- Fraktur: 5001 MS (3 days ago), Kleinfrak 5003 MS (20 days ago); Anna: 5003 OS (40 days), 5004 MS
local h = NS.AwardHistoryOf("Fraktur")
assert(h.n == 2 and h.ms == 2 and h.os == 0 and h.last.item == 5001, ("%d %d"):format(h.n, h.ms))
assert(NS.AwardHistoryOf("Kleinfrak").n == 2, "an alt counts with its main")
local a = NS.AwardHistoryOf("Anna")
assert(a.n == 1 and a.ms == 1 and a.last.item == 5004, "the award older than four weeks does not count")
assert(NS.AwardHistoryOf("Niemand").n == 0 and NS.AwardHistoryOf("Niemand").last == nil)
local hl = NS.AwardHistoryLines("Fraktur")
assert(hl[1] == "Letzte 4 Wochen: 2 Items (2 MS)" and hl[2] == "Zuletzt: Item 5001, " .. date("%d.%m.", new.start + 3600), table.concat(hl, " / "))
assert(NS.AwardHistoryLines("Niemand")[1] == "Letzte 4 Wochen: nichts bekommen" and #NS.AwardHistoryLines("Niemand") == 1)

---------------------------------------------------------------------------
-- the roll window: a roller's row names what the player got
---------------------------------------------------------------------------
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" }, { name = "Bob", class = "MAGE" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
STUB.loot = { { link = link, name = "Cursed Vision of Sargeras" } }
STUB.fire("LOOT_OPENED")
assert(NS.StartRoll(link, 30))
NS.ShowRollFrame()
STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format("Fraktur", 77, 1, 100))
STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format("Vuloo", 12, 1, 100))
local row = NS.RollFrame.rows[1]
assert(row.who == "Fraktur" and row.scripts.OnEnter, "the row has a tooltip")
for k in pairs(lines) do lines[k] = nil end
row.scripts.OnEnter(row)
assert(lines[1] == "Fraktur" and lines[2] == "Letzte 4 Wochen: 2 Items (2 MS)" and has(lines[3], "Zuletzt: Item 5001"), table.concat(lines, " / "))
for k in pairs(lines) do lines[k] = nil end
NS.RollFrame.rows[2].scripts.OnEnter(NS.RollFrame.rows[2])
assert(lines[1] == "Vuloo" and lines[2] == "Letzte 4 Wochen: nichts bekommen" and #lines == 2, table.concat(lines, " / "))
-- the numbers of other players stay with the officers
assert(NS.Set("ui.view", "raider"))
for k in pairs(lines) do lines[k] = nil end
row.scripts.OnEnter(row)
assert(#lines == 0, "no history for a raider")
NS.Reset("ui.view")
NS.StopRoll()
STUB.fire("LOOT_CLOSED")
