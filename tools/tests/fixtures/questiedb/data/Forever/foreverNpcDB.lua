-- AUTO GENERATED FILE! DO NOT EDIT!
-- A small cut of QuestieDB's data/Forever/foreverNpcDB.lua (its format of 2026-11-20).

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB");

QuestieDB.npcKeys = {
    ['name'] = 1, -- string
    ['minLevelHealth'] = 2, -- int
    ['maxLevelHealth'] = 3, -- int
    ['minLevel'] = 4, -- int
    ['maxLevel'] = 5, -- int
    ['rank'] = 6, -- int
    ['spawns'] = 7, -- table {[zoneID(int)] = {coordPair(floatVector2D),...},...}
    ['waypoints'] = 8, -- table
    ['zoneID'] = 9, -- guess as to where this NPC is most common
    ['questStarts'] = 10, -- table {questID(int),...}
    ['questEnds'] = 11, -- table {questID(int),...}
    ['factionID'] = 12, -- int
    ['friendlyToFaction'] = 13, -- string, "A" and/or "H"
    ['subName'] = 14, -- string
    ['npcFlags'] = 15, -- int
}

QuestieDB.npcData = [[return {
[6] = {'Kobold Vermin',42,55,1,2,0,{[12]={{48.89,36.44},{49.55,36.06}}},nil,12,nil,nil,25,nil,nil,0},
[299] = {'Young Wolf',42,55,1,2,0,{[12]={{40.0,50.0}}},nil,12,nil,nil,32,nil,nil,0},
[646] = {'Mr. Smite',2000,2000,20,20,1,{[1581]={{1.0,2.0}}},nil,1581,nil,nil,17,nil,nil,0},
[900] = {'Griselda',500,500,30,30,0,{[12]={{41.0,51.0}}},nil,12,nil,nil,12,"A","Shoe Merchant",128},
[901] = {'Mother Fang',300,300,10,10,4,{[40]={{30.0,40.0}}},nil,40,nil,nil,32,nil,nil,0},
}]]
