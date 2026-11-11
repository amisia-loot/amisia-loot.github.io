--[[preload
STUB.missingTemplates.SecureActionButtonTemplate = true
]]
-- F-181 (D-113): a client without SecureActionButtonTemplate. The window of an item that starts a quest
-- still shows, but only informs: no button, the line names the bag and the slot (counted from 1), the X
-- closes it; nothing raises.
local QS = NS.QuestStart
STUB.class, STUB.level, STUB.faction = "WARRIOR", 30, "Alliance"
STUB.item(8101, "Einfache Zeichnung", 1)
STUB.items[8101].classID, STUB.items[8101].equipLoc = 12, ""
STUB.bags = { [0] = { false, false }, [1] = { false, false, 8101 } }
C_Container.GetContainerItemQuestInfo = function(bag, slot)
    if C_Container.GetContainerItemID(bag, slot) == 8101 then return { isQuestItem = true, questID = 990950 } end
    return { isQuestItem = false }
end
STUB.fire("PLAYER_ENTERING_WORLD")
STUB.fire("QUEST_LOG_UPDATE")
STUB.tick(QS.LOGIN_DELAY + 1)
local f = _G.AmisiaQuestStart
assert(f and f:IsShown(), "the window shows without the template")
assert(_G.AmisiaQuestStartButton == nil and f.button == nil, "no secure button")
local text = f.hint:GetText()
assert(text == "Rechtsklick auf den Gegenstand in der Tasche startet die Quest (Tasche 2, Platz 3).", text)
assert(f:GetHeight() > NS.Theme.QUESTSTART.TOP + NS.Theme.QUESTSTART.ICON, "room for the line")
-- in combat nothing is protected here either; the X still waits (the same path as with the button)
STUB.combat = true
f.CloseButton:Click()
assert(f:IsShown() and #STUB.blocked == 0)
STUB.combat = false
STUB.fire("PLAYER_REGEN_ENABLED")
STUB.tick(1)
assert(not f:IsShown(), "closed after combat")
print("test_quest_start_nosecure: ok")
