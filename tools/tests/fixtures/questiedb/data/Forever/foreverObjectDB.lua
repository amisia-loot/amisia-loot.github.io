-- AUTO GENERATED FILE! DO NOT EDIT!
-- A small cut of QuestieDB's data/Forever/foreverObjectDB.lua (its format of 2026-11-20).

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB");

QuestieDB.objectKeys = {
    ['name'] = 1, -- string
    ['questStarts'] = 2, -- table {questID(int),...}
    ['questEnds'] = 3, -- table {questID(int),...}
    ['spawns'] = 4, -- table {[zoneID(int)] = {coordPair(floatVector2D),...},...}
    ['zoneID'] = 5, -- guess as to where this object is most common
    ['factionID'] = 6, -- faction restriction mask
    ['waypoints'] = 7, -- waypoints for objects on ships/zeppelins/etc
}

QuestieDB.objectData = [[return {
[2039] = {"Hidden Strongbox",nil,nil,{[40]={{25.97,16.91}}},40},
}]]
