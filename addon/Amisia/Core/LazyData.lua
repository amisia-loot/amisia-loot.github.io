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
