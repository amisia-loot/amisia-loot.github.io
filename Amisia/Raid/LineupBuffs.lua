-- The buffs of the lineup (F-224, D-149, spec docs/specs/2026-11-17-raid-buffs-im-planer.md): what the classes
-- of the planner can bring, per entry of Data/RaidBuffData.lua (the gear module, Forever only, built from the
-- client tables by tools/build_raidbuffs.py). ns.LineupBuffs(night) counts who stands in a group (nobody
-- placed: everyone of the night who is neither absent nor on the bench) and gives each entry its state:
-- "have" (a placed class brings it baseline, with the count), "talent" (only a talent of a placed class with a
-- fitting role could), "missing"; a group-scope entry its groups. Nothing is saved, sent or inspected: the
-- class of an entry is all it knows. On TBC Anniversary and Classic Era the data is not there and the
-- feature is absent (ns.LineupBuffsAvailable). The page Aufstellung shows it (UI/Pages/Lineup.lua).
local ADDON, ns = ...
ns.Load(function()

local KEY = "RAIDBUFFS"
-- the positions of an entry of the data
local E_KEY, E_BLOCK, E_SCOPE, E_SPELL, E_ICON, E_ROLES, E_CLASSES = 1, 2, 3, 4, 5, 6, 7

ns.LINEUP_BUFF_BLOCKS = { "buff", "boss", "util" }

-- Whether the planner shows the buffs: the data is there (Forever, the gear module loaded) and holds entries.
function ns.LineupBuffsAvailable()
    return ns.HasData(KEY) and (ns.DataSize(KEY) or 1) > 0 or false
end

local function clientCall(space, fn, ...)
    local t = space and _G[space]
    local f = t and t[fn]
    if type(f) ~= "function" then return nil end
    local ok, v = pcall(f, ...)
    if ok then return v end
    return nil
end

-- The client's name and icon of a spell (the client's language); nil when the client knows no such spell.
function ns.LineupBuffSpell(spell, icon)
    local name = clientCall("C_Spell", "GetSpellName", spell)
    if name == nil and type(_G.GetSpellInfo) == "function" then
        local ok, v = pcall(_G.GetSpellInfo, spell)
        name = ok and v or nil
    end
    if type(name) ~= "string" or name == "" then return nil end
    local tex = clientCall("C_Spell", "GetSpellTexture", spell)
    if tex == nil and type(_G.GetSpellTexture) == "function" then
        local ok, v = pcall(_G.GetSpellTexture, spell)
        tex = ok and v or nil
    end
    if tex == nil and icon and icon ~= 0 then tex = icon end
    return name, tex
end

local function roleOf(e) return e.r or "R" end

local function counts(e)
    return not e.a and not e.b and not e.v
end

-- The state of every entry for the night (nil: the feature is absent). Returns
--   { all = counted every sign-up (nobody placed), counted = players counted, noClass = of them without a
--     class, entries = { { key, block, scope, spell, name, icon, roles, classes = { { class, talent } },
--     state = "have"/"talent"/"missing", count, groups = { g, ... } (group scope, placed only),
--     who = { { n, c, g, talent } } } } in the data's order, missing = the entries of state "missing" }
-- An entry the client knows no spell of is left out (a new build that took it away).
function ns.LineupBuffs(night)
    if not ns.LineupBuffsAvailable() then return nil end
    local data = ns.Data(KEY)
    if type(data) ~= "table" or type(data.entries) ~= "table" then return nil end
    local n = ns.LineupNight and ns.LineupNight(night, false)
    local list = n and n.list or {}
    local placed, any = {}, false
    for _, e in ipairs(list) do
        if counts(e) and e.g then
            placed[#placed + 1] = e
            any = true
        end
    end
    local all = false
    if not any then
        for _, e in ipairs(list) do
            if counts(e) then placed[#placed + 1] = e end
        end
        all = #placed > 0
    end
    local byClass, noClass = {}, 0
    for _, e in ipairs(placed) do
        local c = type(e.c) == "string" and e.c ~= "" and e.c or nil
        if c then
            byClass[c] = byClass[c] or {}
            table.insert(byClass[c], e)
        else
            noClass = noClass + 1
        end
    end
    local out = { all = all, counted = #placed, noClass = noClass, entries = {}, missing = {} }
    for _, d in ipairs(data.entries) do
        local name, icon = ns.LineupBuffSpell(d[E_SPELL], d[E_ICON])
        if name then
            local roles = d[E_ROLES] or ""
            local classes, cl = {}, d[E_CLASSES] or {}
            for i = 1, #cl, 2 do classes[#classes + 1] = { cl[i], cl[i + 1] == 1 } end
            local r = { key = d[E_KEY], block = d[E_BLOCK], scope = d[E_SCOPE], spell = d[E_SPELL], name = name,
                        icon = icon, roles = roles, classes = classes, who = {}, count = 0, groups = {} }
            local base, tal, groupsOf = 0, 0, { base = {}, tal = {} }
            for _, c in ipairs(classes) do
                for _, e in ipairs(byClass[c[1]] or {}) do
                    if roles == "" or roles:find(roleOf(e), 1, true) then
                        r.who[#r.who + 1] = { n = e.n, c = e.c, g = e.g, talent = c[2] }
                        local bucket = c[2] and "tal" or "base"
                        if c[2] then tal = tal + 1 else base = base + 1 end
                        if e.g and not all then groupsOf[bucket][e.g] = true end
                    end
                end
            end
            local use
            if base > 0 then
                r.state, r.count, use = "have", base, groupsOf.base
            elseif tal > 0 then
                r.state, r.count, use = "talent", tal, groupsOf.tal
            else
                r.state = "missing"
            end
            if use and r.scope == "group" then
                for g = 1, 8 do
                    if use[g] then r.groups[#r.groups + 1] = g end
                end
            end
            out.entries[#out.entries + 1] = r
            if r.state == "missing" then out.missing[#out.missing + 1] = r end
        end
    end
    return out
end

end)
