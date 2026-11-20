-- AUTO GENERATED FILE! DO NOT EDIT!
-- A small cut of QuestieDB's data/Forever/foreverQuestDB.lua (its format of 2026-11-20, the first 17 keys).

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB");

QuestieDB.questKeys = {
    ['name'] = 1, -- string
    ['startedBy'] = 2, -- table
    ['finishedBy'] = 3, -- table
    ['requiredLevel'] = 4, -- int
    ['questLevel'] = 5, -- int
    ['requiredRaces'] = 6, -- bitmask
    ['requiredClasses'] = 7, -- bitmask
    ['objectivesText'] = 8, -- table: {string,...}
    ['triggerEnd'] = 9, -- table
    ['objectives'] = 10, -- table
    ['sourceItemId'] = 11, -- int
    ['preQuestGroup'] = 12, -- table
    ['preQuestSingle'] = 13, -- table
    ['childQuests'] = 14, -- table
    ['inGroupWith'] = 15, -- table
    ['exclusiveTo'] = 16, -- table
    ['zoneOrSort'] = 17, -- int, >0: AreaTable.dbc ID; <0: QuestSort.dbc ID
}

QuestieDB.questData = [[return {
[4711] = {"Die Fackel",{{900}},{{900}},25,30,77,nil,{"Bring the torch."},nil,nil,nil,nil,nil,nil,nil,nil,40},
}]]
