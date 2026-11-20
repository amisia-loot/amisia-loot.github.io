-- AUTO GENERATED FILE! DO NOT EDIT!
-- A small cut of QuestieDB's data/Forever/foreverItemDB.lua (its format of 2026-11-20) for tools/tests/test_questie_data.py.

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB");

QuestieDB.itemKeys = {
    ['name'] = 1, -- string
    ['npcDrops'] = 2, -- table or nil, NPC IDs
    ['objectDrops'] = 3, -- table or nil, object IDs
    ['itemDrops'] = 4, -- table or nil, item IDs
    ['startQuest'] = 5, -- int or nil, ID of the quest started by this item
    ['questRewards'] = 6, -- table or nil, quest IDs
    ['flags'] = 7, -- int or nil
    ['foodType'] = 8, -- int or nil
    ['itemLevel'] = 9, -- int, the level of this item
    ['requiredLevel'] = 10, -- int, the level required to equip/use this item
    ['ammoType'] = 11, -- int,
    ['class'] = 12, -- int,
    ['subClass'] = 13, -- int,
    ['vendors'] = 14, -- table or nil, NPC IDs
    ['relatedQuests'] = 15, -- table or nil, IDs of quests that are related to this item
}

QuestieDB.itemData = [[return {
[25] = {'Worn Shortsword',nil,nil,nil,nil,nil,nil,nil,2,1,0,2,7},
[117] = {'Tough Jerky',{38,6},nil,nil,nil,nil,nil,nil,5,1,0,0,0},
[5191] = {'Cruel Barb',{646},nil,nil,nil,nil,nil,nil,24,19,0,2,7},
[5200] = {'Impaling Harpoon',{6},nil,nil,nil,nil,nil,nil,24,19,0,2,6},
[7000] = {'Wolf Hat',{299},nil,nil,nil,nil,nil,nil,20,15,0,4,2},
[7001] = {'Chest Ring',nil,{2039},nil,nil,nil,nil,nil,20,15,0,4,0},
[7002] = {'Quest Cloak',nil,nil,nil,nil,{4711},nil,nil,30,25,0,4,1},
[7003] = {'Vendor Boots',nil,nil,nil,nil,nil,nil,nil,30,25,0,4,2,{900}},
[7004] = {'Rare Gloves',{901},nil,nil,nil,nil,nil,nil,30,25,0,4,2},
}]]
