-- The big generated data files (Data/GearData, MapData, QuestData, ProfessionData, TalentData) hand
-- their table to ns.LazyData as Lua source in one long string: at login only the string is kept,
-- the table is built the first time something asks for it (ns.Data). That keeps the login short and
-- the memory low for players who never open the gear, map, quest, profession or talent pages.
-- ns.HasData tells whether the data is there without building it, ns.DataSize how many entries the
-- generator counted (availability checks: a file built without data has 0).
-- Assigning ns[key] (a test's fixture, or nil to take the data away) replaces what waits.
local ADDON, ns = ...

local pending = {}   -- key -> source text of a table not built yet
local sizes = {}     -- key -> the number of entries the generator counted
local made = {}      -- key -> the table built from the source (a fixture put in its place is not it)
local built = {}     -- key -> milliseconds and KB the build took (for the self-test and tests)

-- Registers the source of ns[key]: a Lua chunk that returns the table; n: its number of entries.
function ns.LazyData(key, source, n)
    assert(type(key) == "string" and type(source) == "string", "LazyData needs a key and its source")
    rawset(ns, key, nil)
    pending[key], sizes[key], made[key] = source, n, nil
end

local function build(key)
    local src = pending[key]
    pending[key] = nil
    local t0 = debugprofilestop and debugprofilestop()
    local before = collectgarbage("count")
    local fn, err = loadstring(src, "@Amisia/Data/" .. key)
    local ok, value = false, err
    if fn then ok, value = pcall(fn) end
    if not ok or type(value) ~= "table" then
        local handler = geterrorhandler and geterrorhandler()
        if handler then handler("Amisia: data " .. key .. " did not load: " .. tostring(value)) end
        return nil
    end
    rawset(ns, key, value)
    made[key] = value
    built[key] = { ms = t0 and (debugprofilestop() - t0) or nil, kb = collectgarbage("count") - before }
    return value
end

-- The data table of key, built on the first call; nil when the client has no such data.
function ns.Data(key)
    local v = rawget(ns, key)
    if v ~= nil then return v end
    if pending[key] then return build(key) end
    return nil
end

-- Whether key has data (built or waiting), without building it.
function ns.HasData(key)
    return rawget(ns, key) ~= nil or pending[key] ~= nil
end

-- The number of entries of key's data as the generator counted them, while that data waits or is
-- the one built from it; nil otherwise (no count given, or a table put in its place).
function ns.DataSize(key)
    if pending[key] then return sizes[key] end
    local v = rawget(ns, key)
    if v ~= nil and v == made[key] then return sizes[key] end
    return nil
end

-- Lets go of the data of key (built or waiting), so its memory can be collected.
function ns.DropData(key)
    pending[key], sizes[key], made[key] = nil, nil, nil
    rawset(ns, key, nil)
end

-- What was built so far: { key = { ms, kb } } (the self-test and the tests read it).
function ns.DataBuilt() return built end

-- /amisia speicher: what the client counts for Amisia before and after a full garbage collection
-- (the difference is garbage the client had not collected yet), the data tables built so far and
-- the entries of the saved scan that still wait for the trim. Not in combat: a full collection can
-- stutter for a moment.
local function addonKB()
    if not (UpdateAddOnMemoryUsage and GetAddOnMemoryUsage) then return nil end
    UpdateAddOnMemoryUsage()
    return GetAddOnMemoryUsage(ADDON)
end

local function mb(kb) return ("%.1f MB"):format(kb / 1024) end

local function countKeys(t)
    local n = 0
    if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
    return n
end

function ns.MemoryReport()
    local L = ns.L
    if InCombatLockdown and InCombatLockdown() then return { L["Nicht im Kampf: das Messen räumt den Speicher auf."] } end
    local before = addonKB()
    collectgarbage("collect")
    local after = addonKB()
    local out = {}
    if before and after then
        out[#out + 1] = L["Speicher: %s, davon Müll %s, echte Daten %s."]:format(mb(before), mb(math.max(0, before - after)), mb(after))
    else
        out[#out + 1] = L["Der Client nennt den Speicher der Addons nicht."]
    end
    local keys = {}
    for key in pairs(built) do if made[key] ~= nil then keys[#keys + 1] = key end end
    table.sort(keys, function(a, b) return (built[a].kb or 0) > (built[b].kb or 0) end)
    local parts = {}
    for _, key in ipairs(keys) do parts[#parts + 1] = ("%s %s"):format(key, mb(built[key].kb or 0)) end
    out[#out + 1] = L["Geladene Daten: %s."]:format(#parts > 0 and table.concat(parts, ", ") or L["keine"])
    local waiting = {}
    for key in pairs(pending) do waiting[#waiting + 1] = key end
    table.sort(waiting)
    if #waiting > 0 then out[#out + 1] = L["Noch nicht geladen: %s."]:format(table.concat(waiting, ", ")) end
    local scan = AmisiaDB and AmisiaDB.scan
    if type(scan) == "table" then
        out[#out + 1] = L["Gespeicherter Scan: %d Items, %d Quellen (räumt /amisia scan aufräumen auf)."]
            :format(countKeys(scan.items), countKeys(scan.sources))
    end
    return out
end

if ns.RegisterSlash then
    ns.RegisterSlash("speicher", { en = "memory", desc = ns.L["Speicher von Amisia messen (Daten und Müll)"], run = function()
        for _, line in ipairs(ns.MemoryReport()) do ns.msg(line) end
    end })
end

-- ns.KEY reads go through ns.Data too; an assignment to a key that still waits replaces it.
setmetatable(ns, {
    __index = function(t, k)
        if pending[k] then return ns.Data(k) end
        return nil
    end,
    __newindex = function(t, k, v)
        pending[k] = nil
        rawset(t, k, v)
    end,
})
