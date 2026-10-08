-- Amisia mage scrolls: WoW Forever's Comprehension ("Arkanes Verständnis"), the mage's skill line
-- for deciphering untranslated scrolls, read for the scrolls page. MageScrollData.lua
-- (tools/build_magescrolls.py, client tables and AllTheThings) gives the scrolls with the rank they
-- need and their tier, the skill-up steps of each tier, the scrolls deciphering can give, the
-- Comprehension Charm and its spell, Study and Research, the library books and their librarians.
-- The client tells the own rank (C_SkillInfo, else the profession list), what is in the bags, which
-- book quests are turned in (C_QuestLog) and which spells are known (IsPlayerSpell); names and
-- texts come from the client in its language, the data's English is the fallback.
local ADDON, ns = ...
local L = ns.L

local MS = {}
ns.MageScrolls = MS

-- the indices of the data's rows
local T_RANK, T_YELLOW, T_GREY, T_SPELL = 1, 2, 3, 4
local S_ITEM, S_RANK, S_TIER, S_ILVL, S_WORLD, S_NAME = 1, 2, 3, 4, 5, 6
local R_ITEM, R_LEVEL, R_ILVL, R_SPELL, R_NAME, R_TEXT = 1, 2, 3, 4, 5, 6
local B_QUEST, B_ITEM, B_FACTION, B_MAPS, B_NAME, B_CHARM = 1, 2, 3, 4, 5, 6
local F_QUEST, F_NEED, F_LEVEL, F_NAME, F_REWARDS = 1, 2, 3, 4, 5
local N_NPC, N_FACTION, N_MAP, N_X, N_Y, N_NAME = 1, 2, 3, 4, 5, 6

MS.opened = false   -- opened with /amisia schriftrollen: the page shows for any class until logout

local function data() return ns.Data("MAGESCROLLS") end

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c
end

function MS.Available()
    local n = ns.DataSize("MAGESCROLLS")
    if n then return n > 0 end
    local d = data()
    return type(d) == "table" and type(d.scrolls) == "table" and d.scrolls[1] ~= nil
end

function MS.IsMage()
    local _, cls = UnitClass("player")
    return ns.Plain(cls) == "MAGE"
end

-- Whether the page shows: for mages, for others once opened by command.
function MS.Shown() return MS.Available() and (MS.IsMage() or MS.opened) end

function MS.Data() return data() end

---------------------------------------------------------------------------
-- The own rank
---------------------------------------------------------------------------
-- The Comprehension rank and its maximum, or nil when the client does not tell it (not learnt).
function MS.Rank()
    local d = data()
    local skill = d and d.skill
    if not skill or skill == 0 then return nil end
    local info = _G.C_SkillInfo
    if type(info) == "table" and type(info.GetNumSkillLines) == "function" and type(info.GetSkillLineInfo) == "function" then
        local n = tonumber(ns.Plain(call(info.GetNumSkillLines))) or 0
        for i = 1, n do
            local s = call(info.GetSkillLineInfo, i)
            if type(s) == "table" and not s.isHeader and tonumber(ns.Plain(s.skillID)) == skill then
                return tonumber(ns.Plain(s.rank)) or 0, tonumber(ns.Plain(s.maxRank)) or 0
            end
        end
    end
    if ns.Prof and ns.Prof.Rank then
        local rank, max = ns.Prof.Rank(skill)
        if rank then return rank, max end
    end
    return nil
end

---------------------------------------------------------------------------
-- Scrolls, tiers, results
---------------------------------------------------------------------------
function MS.Tiers()
    local out = {}
    for i, t in ipairs(data() and data().tiers or {}) do
        out[i] = { index = i, rank = t[T_RANK], yellow = t[T_YELLOW], grey = t[T_GREY], spell = t[T_SPELL] }
    end
    return out
end

function MS.Tier(i)
    local t = data() and data().tiers and data().tiers[i]
    if not t then return nil end
    return { index = i, rank = t[T_RANK], yellow = t[T_YELLOW], grey = t[T_GREY], spell = t[T_SPELL] }
end

function MS.Scrolls()
    local out = {}
    for i, s in ipairs(data() and data().scrolls or {}) do
        out[i] = { item = s[S_ITEM], rank = s[S_RANK], tier = s[S_TIER], ilvl = s[S_ILVL], world = s[S_WORLD] == 1, name = s[S_NAME] }
    end
    return out
end

function MS.Results()
    local out = {}
    for i, r in ipairs(data() and data().results or {}) do
        out[i] = { item = r[R_ITEM], level = r[R_LEVEL], ilvl = r[R_ILVL], spell = r[R_SPELL], name = r[R_NAME], text = r[R_TEXT] }
    end
    return out
end

function MS.Abilities()
    local out = {}
    for i, a in ipairs(data() and data().abilities or {}) do out[i] = { spell = a[1], name = a[2], text = a[3] } end
    return out
end

-- The colour of a scroll for a rank, as the client's recipe list: red (rank too low), orange,
-- yellow (from the tier's yellow step), green (half way to grey), grey; "none" without a rank.
function MS.Color(scroll, rank)
    if not rank then return "none" end
    if rank < (scroll.rank or 0) then return "red" end
    local t = MS.Tier(scroll.tier)
    if not t or (t.grey or 0) == 0 then return "none" end
    local green = math.floor((t.yellow + t.grey) / 2)
    if rank >= t.grey then return "grey" end
    if rank >= green then return "green" end
    if rank >= t.yellow then return "yellow" end
    return "orange"
end

function MS.Count(item)
    local f = C_Item and C_Item.GetItemCount
    return tonumber(ns.Plain(call(f, item, true))) or 0
end

-- Whether the character knows a spell: true/false from the client, nil without a way to ask.
function MS.Known(spell)
    if not spell or spell == 0 then return nil end
    if type(_G.IsPlayerSpell) == "function" then return ns.Plain(call(_G.IsPlayerSpell, spell)) == true end
    local book = _G.C_SpellBook
    if type(book) == "table" and type(book.IsSpellKnown) == "function" then return ns.Plain(call(book.IsSpellKnown, spell)) == true end
    if type(_G.IsSpellKnown) == "function" then return ns.Plain(call(_G.IsSpellKnown, spell)) == true end
    return nil
end

-- Name of an item from the client (and its quality), else fallback; asks the client to load it.
local asked = {}
function MS.ItemName(id, fallback)
    local f = C_Item and C_Item.GetItemInfo
    local name, _, q = call(f, id)
    name, q = ns.Plain(name), ns.Plain(q)
    if type(name) == "string" and name ~= "" then return name, q, true end
    if not asked[id] and C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
        asked[id] = true
        call(C_Item.RequestLoadItemDataByID, id)
    end
    return fallback or ("Item " .. tostring(id)), nil, false
end

---------------------------------------------------------------------------
-- The library: books, the Friend quests, the librarian
---------------------------------------------------------------------------
local function myFaction()
    local f = UnitFactionGroup and ns.Plain((UnitFactionGroup("player"))) or nil
    return f == "Alliance" and "A" or f == "Horde" and "H" or nil
end

local doneMemo = {}
function MS._resetQuests() doneMemo = {} end

-- Whether a quest is turned in: true/false, nil when the client cannot tell.
function MS.QuestDone(q)
    local v = doneMemo[q]
    if v ~= nil then return v end
    local Ql = _G.C_QuestLog
    local f = type(Ql) == "table" and Ql.IsQuestFlaggedCompleted
    if type(f) ~= "function" then return nil end
    v = ns.Plain(call(f, q)) == true
    doneMemo[q] = v
    return v
end
ns.OnEvent("QUEST_TURNED_IN", function() doneMemo = {} end)

function MS.QuestName(q, fallback)
    local Ql = _G.C_QuestLog
    local name = type(Ql) == "table" and ns.Plain(call(Ql.GetTitleForQuestID, q)) or nil
    if type(name) == "string" and name ~= "" then return name end
    return fallback or ("Quest " .. tostring(q))
end

-- The books for the own faction (and both factions'): { quest, item, faction, maps, name, charm, done }.
function MS.Books()
    local fac, out = myFaction(), {}
    for _, b in ipairs(data() and data().books or {}) do
        local f = b[B_FACTION]
        if f == "" or not fac or f == fac then
            out[#out + 1] = { quest = b[B_QUEST], item = b[B_ITEM], faction = f, maps = b[B_MAPS] or {}, name = b[B_NAME],
                charm = b[B_CHARM] == 1, done = MS.QuestDone(b[B_QUEST]) }
        end
    end
    return out
end

-- The "Friend of the Library" quests: { quest, need, level, name, rewards, have = books turned in, done }.
function MS.Friends()
    local books, have = MS.Books(), 0
    for _, b in ipairs(books) do if b.done then have = have + 1 end end
    local out = {}
    for _, f in ipairs(data() and data().friends or {}) do
        out[#out + 1] = { quest = f[F_QUEST], need = f[F_NEED], level = f[F_LEVEL], name = f[F_NAME], rewards = f[F_REWARDS] or {},
            have = have, done = MS.QuestDone(f[F_QUEST]) }
    end
    return out
end

-- The librarian of the own faction: { npc, name, faction, point = { map, x, y } (0-1) }.
function MS.Librarian()
    local fac = myFaction()
    local first
    for _, n in ipairs(data() and data().librarians or {}) do
        local e = { npc = n[N_NPC], name = n[N_NAME], faction = n[N_FACTION],
            point = { map = n[N_MAP], x = n[N_X] / 10000, y = n[N_Y] / 10000 } }
        if e.faction == fac then return e end
        first = first or e
    end
    return first
end

---------------------------------------------------------------------------
-- Sources of a scroll
---------------------------------------------------------------------------
local function zoneName(map)
    if ns.Prof and ns.Prof.ZoneName then return ns.Prof.ZoneName(map) end
    return nil
end

-- Lines { kind = "W"|"S"|"D"|"?", text, point } for a scroll: the data's world drop, Study (a library
-- makes a bundle of scrolls), and what the source collector saw (a place this client saw itself is
-- a waypoint, a place heard from the guild only text).
function MS.Sources(scroll)
    local out = {}
    if scroll.world then out[#out + 1] = { kind = "W", text = L["Weltdrop (nur Magier finden sie)"] } end
    local d = data()
    if d and (d.bundle or 0) > 0 then
        out[#out + 1] = { kind = "S", text = L["Studieren in einer Bibliothek: ein Bündel Schriftrollen"] }
    end
    local obs = ns.Prof and ns.Prof.Observed and ns.Prof.Observed(scroll.item)
    for _, v in ipairs(obs and obs.drops or {}) do
        local m, x, y = tostring(v.pos or ""):match("^(%d+):(%d+):(%d+)$")
        local where, point
        if m then
            m, x, y = tonumber(m), tonumber(x), tonumber(y)
            where = ("%s %d, %d"):format(zoneName(m) or "?", math.floor(x / 100 + 0.5), math.floor(y / 100 + 0.5))
            if v.ownPos then point = { map = m, x = x / 10000, y = y / 10000 } end
        else
            where = zoneName(tonumber(v.pos))
        end
        out[#out + 1] = { kind = "D", point = point, text = ("Drop: %s%s%s"):format(v.name ~= "" and v.name or ("NPC " .. tostring(v.npc)),
            where and (", " .. where) or "", v.own and L[" (selbst gesehen)"] or L[" (von der Gilde)"]) }
    end
    if #out == 0 then out[1] = { kind = "?", text = L["Quelle noch unbekannt"] } end
    return out
end

-- The zones a book lies in, by name.
function MS.BookZones(b)
    local names = {}
    for _, m in ipairs(b.maps or {}) do names[#names + 1] = zoneName(m) or ("Zone " .. tostring(m)) end
    return names
end
