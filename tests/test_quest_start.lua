-- F-181 (D-113): the window of an item that starts a quest (Gear/QuestStart.lua). With a stubbed bag: the
-- login (only after the delay and the client's answer of the quest log, at most three), a start item of an
-- open quest, one whose quest is in the log, one whose quest is done, a normal quest item, two at once, the
-- click on the secure button (the template's use of "item:<id>"), the quest accepted, the X and a later bag
-- update, the item on the cursor and then gone, combat when the item arrives, combat starting while the
-- window is open (nothing protected touched: the stub raises on it), the chat lockdown and an encounter,
-- the client's quest mark missing so that the data decides (QuestItemData S, DungeonQuestData's start
-- items, not D), the old global form never asked, the setting off and on, the client's refusal, the place, Escape.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return m end end
    return nil
end
local QS = NS.QuestStart
assert(QS, "the module loads")

STUB.class, STUB.level, STUB.faction = "WARRIOR", 30, "Alliance"

local function questItem(id, name, class)
    STUB.item(id, name, 1)
    STUB.items[id].classID = class or 12
    STUB.items[id].equipLoc = ""
end
questItem(8001, "Einfache Zeichnung")    -- starts 990901 (open)
questItem(8002, "Zerrissene Seite")      -- starts 990902 (in the log: the client's isActive)
questItem(8003, "Alter Brief")           -- starts 990903 (done)
questItem(8004, "Wolfspelz")             -- a normal quest item: the mark without a quest
questItem(8005, "Versiegelte Order")     -- starts 990905 (open)
questItem(8006, "Blutige Notiz")         -- starts 990906 (open)
questItem(8009, "Fundstück A")           -- starts 990909 (open): over the login's three
questItem(8010, "Fundstück B")           -- starts 990910 (open): over the login's three
questItem(8011, "Gekritzel")             -- starts 990911, arrives later
questItem(8012, "Kampfbeute")            -- starts 990912, arrives in combat
questItem(8013, "Zweite Kampfbeute")     -- starts 990913, arrives while the window is open in combat
questItem(8014, "Sperrfund")             -- starts 990914, arrives in the chat lockdown
questItem(8018, "Bossfund")              -- starts 990918, arrives in an encounter
questItem(8007, "Datenkarte")            -- the data's S 990907 (no client mark)
questItem(8008, "Dungeonschrift")        -- the dungeon data's start item of 99908 (no client mark)
questItem(8015, "Nur ein Ziel")          -- the data's D 990915: not a start item
questItem(8016, "Alte Form")             -- only the old global form would name 990916: never asked
questItem(8017, "Nach dem Schalter")     -- starts 990917, arrives while the setting is off
questItem(8019, "Verweigert")            -- starts 990919, the refusal

local MARK = {
    [8001] = { isQuestItem = true, questID = 990901 }, [8002] = { isQuestItem = true, questID = 990902, isActive = true },
    [8003] = { isQuestItem = true, questID = 990903 }, [8004] = { isQuestItem = true },
    [8005] = { isQuestItem = false, questID = 990905 }, [8006] = { isQuestItem = true, questID = 990906 },
    [8009] = { questID = 990909 }, [8010] = { questID = 990910 }, [8011] = { questID = 990911 }, [8012] = { questID = 990912 },
    [8013] = { questID = 990913 }, [8014] = { questID = 990914 }, [8018] = { questID = 990918 }, [8017] = { questID = 990917 },
    [8019] = { questID = 990919 },
}
local function markFn(bag, slot)
    local id = C_Container.GetContainerItemID(bag, slot)
    return id and MARK[id] or { isQuestItem = false }
end
C_Container.GetContainerItemQuestInfo = markFn
STUB.questsDone = { [990903] = true }
STUB.questsActive = {}
local TITLES = { [990901] = "Die einfache Zeichnung" }
C_QuestLog.GetTitleForQuestID = function(q) return TITLES[q] end
NS.QUEST_ITEMS = { built = "2026-11-11", count = 2, I = { [8007] = "S990907", [8015] = "D990915" } }
NS.DUNGEON_QUESTS.Q[99908] = { "Dungeon Script", 1, 1, "", 0, "X", nil, nil, nil, nil, nil, nil, nil, nil, { { 8008, nil, 1426, nil } } }

local function bagAdd(id)
    for _, b in ipairs({ 1, 2, 3 }) do
        STUB.bags[b] = STUB.bags[b] or {}
        local list = STUB.bags[b]
        for i = 1, #list do
            if list[i] == false then list[i] = id return b, i end
        end
        if #list < 16 then list[#list + 1] = id return b, #list end
    end
end
local function bagRemove(id)
    for _, list in pairs(STUB.bags) do
        for i = 1, #list do if list[i] == id then list[i] = false end end
    end
end
local function bagUpdate()
    STUB.fire("BAG_UPDATE_DELAYED")
    STUB.tick(1)
end
local function win() return _G.AmisiaQuestStart end
local function shown() return win() ~= nil and win():IsShown() end
local function title() return win().TitleContainer.TitleText:GetText() end
local function current() local e = QS.Current() return e and e.id end

---------------------------------------------------------------------------
-- the login: the start items already in the bags, after the delay and the client's answer, at most three
---------------------------------------------------------------------------
STUB.bags = { [0] = { 8001, 8002, 8003, 8004, 8005, 8006, 8009, 8010 } }
STUB.fire("PLAYER_ENTERING_WORLD")
STUB.fire("BAG_UPDATE_DELAYED")
STUB.tick(2)
assert(not shown(), "nothing before the login's delay")
STUB.tick(4)
assert(not shown(), "nothing before the client answered the quest log (completed quests unknown)")
STUB.fire("QUEST_LOG_UPDATE")
STUB.tick(1)
assert(shown(), "the login's start items show")
assert(#QS.queue == 3, "at most three at login: " .. #QS.queue)
assert(current() == 8001, "the first in bag order: " .. tostring(current()))
assert(title() == "Einfache Zeichnung (1 von 3)", title())
assert(win().hint:GetText() == "Klick auf das Symbol startet die Quest.", win().hint:GetText())
local B = _G.AmisiaQuestStartButton
assert(B and B.secure and B:GetAttribute("type") == "item", "the secure item button")
assert(B:GetAttribute("item") == "item:8001", "the item by id, never a bag slot: " .. tostring(B:GetAttribute("item")))
assert(B.points.TOPLEFT.rel == win().slot, "the button lies over the icon")
assert(win().mark.texture == "Interface\\GossipFrame\\AvailableQuestIcon", "the quest giver's \"!\" at the icon: " .. tostring(win().mark.texture))
assert(win().slot.icon.texture == 134, "the item's icon")
for _, q in ipairs(QS.queue) do
    assert(q.id ~= 8002 and q.id ~= 8003 and q.id ~= 8004, "in the log, done or a normal quest item never: " .. q.id)
end
assert(QS.seen[8009] and QS.seen[8010], "the ones over the limit count as seen: no window for them this session")
local found = {}
for _, e in ipairs(QS.BagStarts()) do found[e.id] = e end
assert(found[8001] and found[8001].src == "client" and found[8001].q == 990901)
assert(found[8005] and found[8005].q == 990905, "the client's quest id counts without isQuestItem")
assert(not found[8004], "a quest item without a quest id starts nothing")
assert(not has(table.concat(UISpecialFrames, ","), "AmisiaQuestStart"), "Escape does not close it (a protected frame)")

-- the click goes to the template's own handler: it uses the item
B:Click("LeftButton")
assert(#STUB.secureUses == 1 and STUB.secureUses[1].type == "item" and STUB.secureUses[1].item == "item:8001",
    "the secure click uses the item")

---------------------------------------------------------------------------
-- the quest accepted: the next one; the X: the next; a later bag update does not bring it back
---------------------------------------------------------------------------
STUB.questsActive[990901] = true
STUB.fire("QUEST_ACCEPTED", 4, 990901)
assert(current() == 8005, "accepted: the next item: " .. tostring(current()))
assert(title() == "Versiegelte Order (1 von 2)", title())
assert(B:GetAttribute("item") == "item:8005")
win().CloseButton:Click()
assert(current() == 8006 and title() == "Blutige Notiz", tostring(current()) .. " " .. title())
bagUpdate()
assert(current() == 8006 and #QS.queue == 1, "a dismissed item does not come back after a bag update")
assert(QS.seen[8001] and QS.seen[8005], "the accepted and the closed one stay seen")

-- on the cursor (being moved) it stays; out of the bags the window closes
local b, s = nil, nil
for bag, list in pairs(STUB.bags) do for i = 1, #list do if list[i] == 8006 then b, s = bag, i end end end
STUB.bags[b][s] = false
_G.GetCursorInfo = function() return "item", 8006 end
bagUpdate()
assert(shown() and current() == 8006, "on the cursor it is still the player's")
_G.GetCursorInfo = function() return nil end
bagUpdate()
assert(not shown(), "the item left the bags: the window closes")
STUB.bags[b][s] = 8006
bagUpdate()
assert(not shown(), "seen this session: not again when it comes back")

---------------------------------------------------------------------------
-- a new arrival; two at once
---------------------------------------------------------------------------
bagAdd(8011)
bagUpdate()
assert(shown() and current() == 8011 and title() == "Gekritzel", "a looted start item shows")
win().CloseButton:Click()
assert(not shown(), "closed")
TITLES[990911] = "Gekritzel lesen"

---------------------------------------------------------------------------
-- combat when the item arrives: nothing until the end
---------------------------------------------------------------------------
STUB.combat = true
STUB.fire("PLAYER_REGEN_DISABLED")
bagAdd(8012)
bagUpdate()
assert(not shown(), "not in combat")
assert(#STUB.blocked == 0, "nothing protected touched")
STUB.combat = false
STUB.fire("PLAYER_REGEN_ENABLED")
STUB.tick(1)
assert(shown() and current() == 8012, "after combat it shows")

---------------------------------------------------------------------------
-- combat starts while the window is open: it stays as it is; the X, the quest accepted and a new item only
-- change its line; at the end the next shows
---------------------------------------------------------------------------
STUB.combat = true
STUB.fire("PLAYER_REGEN_DISABLED")
assert(not pcall(win().Hide, win()), "the stub's window is protected now (it holds the secure button)")
STUB.blocked = {}
bagAdd(8013)
bagUpdate()
assert(shown() and current() == 8012, "no change in combat")
B:Click("LeftButton")
assert(STUB.secureUses[#STUB.secureUses].item == "item:8012", "the click works in combat")
local ok, err = pcall(function() win().CloseButton:Click() end)
assert(ok, "the X in combat raises nothing: " .. tostring(err))
assert(shown(), "the X in combat does not hide the protected window")
assert(win().hint:GetText() == "Schließt nach dem Kampf.", win().hint:GetText())
STUB.questsActive[990912] = true
ok, err = pcall(STUB.fire, "QUEST_ACCEPTED", 5, 990912)
assert(ok, tostring(err))
assert(#STUB.blocked == 0, "nothing protected touched in combat: " .. #STUB.blocked)
STUB.combat = false
STUB.fire("PLAYER_REGEN_ENABLED")
STUB.tick(1)
assert(shown() and current() == 8013, "after combat the next: " .. tostring(current()))
assert(B:GetAttribute("item") == "item:8013")
assert(win().hint:GetText() == "Klick auf das Symbol startet die Quest.")
STUB.questsActive[990913] = true
STUB.fire("QUEST_LOG_UPDATE")
STUB.tick(1)
assert(not shown(), "its quest in the log (the bag pass): closed")

---------------------------------------------------------------------------
-- the chat lockdown and a boss encounter: it waits
---------------------------------------------------------------------------
STUB.chatLock = true
bagAdd(8014)
bagUpdate()
assert(not shown(), "not in the chat lockdown")
STUB.chatLock = false
STUB.fire("ADDON_RESTRICTION_STATE_CHANGED", 5, 0)
STUB.tick(1)
assert(shown() and current() == 8014, "after the lockdown")
win().CloseButton:Click()
STUB.fire("ENCOUNTER_START", 1, "Boss", 1, 5)
bagAdd(8018)
bagUpdate()
assert(not shown(), "not in an encounter")
STUB.fire("ENCOUNTER_END", 1, "Boss", 1, 5, 1)
STUB.tick(1)
assert(shown() and current() == 8018, "after the encounter")
win().CloseButton:Click()

---------------------------------------------------------------------------
-- the client gives nothing: the data decides (S and the dungeon data's start items, not D)
---------------------------------------------------------------------------
C_Container.GetContainerItemQuestInfo = nil
bagAdd(8007); bagAdd(8008); bagAdd(8015)
bagUpdate()
assert(shown() and current() == 8007, "the data's S: " .. tostring(current()))
assert(title() == "Datenkarte (1 von 2)", title())
found = {}
for _, e in ipairs(QS.BagStarts()) do found[e.id] = e end
assert(found[8007].src == "data" and found[8007].q == 990907)
assert(found[8008] and found[8008].q == 99908, "the dungeon data's start item")
assert(not found[8015], "the data's D is no start item")
win().CloseButton:Click()
assert(current() == 8008)
win().CloseButton:Click()
-- the old global form is never asked (Forever has only C_Container's)
_G.GetContainerItemQuestInfo = function() error("the global GetContainerItemQuestInfo asked") end
bagAdd(8016)
bagUpdate()
assert(not shown(), "no client mark, no data: nothing")
_G.GetContainerItemQuestInfo = nil
C_Container.GetContainerItemQuestInfo = markFn

---------------------------------------------------------------------------
-- the setting off and on
---------------------------------------------------------------------------
assert(NS.Get("quests.startPopup") == true, "on by default")
bagAdd(8017)
assert(NS.Set("quests.startPopup", false))
bagUpdate()
assert(not shown(), "off: no window")
assert(not QS.seen[8017], "off: nothing read")
assert(NS.Set("quests.startPopup", true))
STUB.tick(1)
assert(shown() and current() == 8017, "on again: the bags as after a login")
NS.Set("quests.startPopup", false)
assert(not shown() and #QS.queue == 0, "off closes the window")
NS.Set("quests.startPopup", true)
STUB.tick(1)

---------------------------------------------------------------------------
-- the client refuses the use: the window only informs
---------------------------------------------------------------------------
bagAdd(8019)
bagUpdate()
assert(current() == 8019)
-- in combat: the line comes, the window changes only after combat
STUB.combat = true
STUB.fire("PLAYER_REGEN_DISABLED")
B:Click("LeftButton")
STUB.fire("ADDON_ACTION_FORBIDDEN", "Amisia", "UNKNOWN()")
assert(QS.Refused(), "refused for the session (just after a click)")
assert(said("lässt Amisia den Gegenstand nicht benutzen"), "one line")
assert(B:IsShown() and #STUB.blocked == 0, "nothing protected touched in combat")
STUB.combat = false
STUB.fire("PLAYER_REGEN_ENABLED")
STUB.tick(1)
assert(not B:IsShown(), "no button any more")
assert(has(win().hint:GetText(), "Rechtsklick auf den Gegenstand in der Tasche"), win().hint:GetText())
assert(has(win().hint:GetText(), "Tasche "), "names the bag")
STUB.fire("ADDON_ACTION_FORBIDDEN", "OtherAddon", "UseItemByName()")
win().CloseButton:Click()

---------------------------------------------------------------------------
-- the place
---------------------------------------------------------------------------
local f = win()
f._point, f._x, f._y = "TOPLEFT", 120, -200
f.scripts.OnDragStop(f)
assert(AmisiaDB.settings.questStartWindow.point == "TOPLEFT" and AmisiaDB.settings.questStartWindow.x == 120, "the place kept")
NS.ResetPositions()
assert(AmisiaDB.settings.questStartWindow.point == nil, "reset with the other windows")

print("test_quest_start: ok")
