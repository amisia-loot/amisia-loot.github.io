-- Character names. WoW Forever names are "First Surname" (one space, the surname may hold a
-- dash). Everything that compares names goes through FullName and SameName, and the export writes
-- "_" for the space (no WoW name holds an underscore), so its fields stay space-separated.
local ADDON, ns = ...

-- One spelling of a name: trimmed, single spaces, and the surname added when it comes separately
-- (UnitName's second value). A dash stays: it belongs to the surname.
function ns.FullName(name, surname)
    if type(name) ~= "string" then return nil end
    name = name:match("^%s*(.-)%s*$"):gsub("%s+", " ")
    if type(surname) == "string" and surname ~= "" and not name:find(" ", 1, true) then
        name = name .. " " .. surname
    end
    if name == "" then return nil end
    return name
end

function ns.UnitFullName(unit)
    local name, second = UnitName(unit)
    return ns.FullName(name, second)
end

-- Whether two spellings mean the same character. A side without surname (a client that leaves it
-- out in one place) matches on the first name.
function ns.SameName(a, b)
    a, b = ns.FullName(a), ns.FullName(b)
    if not a or not b then return false end
    if a:lower() == b:lower() then return true end
    if not a:find(" ", 1, true) or not b:find(" ", 1, true) then
        return a:match("^(%S+)"):lower() == b:match("^(%S+)"):lower()
    end
    return false
end

-- The plain names of the group (secret ones left out); {} when alone.
function ns.GroupRoster()
    local out = {}
    for i = 1, GetNumGroupMembers() or 0 do
        local n = ns.FullName(ns.Plain((GetRaidRosterInfo(i))))
        if n then out[#out + 1] = n end
    end
    return out
end

-- How many names of roster carry the first name of name.
local function firstNameCount(name, roster)
    local first = name:match("^(%S+)"):lower()
    local n = 0
    for _, r in ipairs(roster or {}) do
        r = ns.FullName(r)
        if r and r:match("^(%S+)"):lower() == first then n = n + 1 end
    end
    return n
end

-- ns.SameName within a group: a match on the first name alone (one side without surname) holds
-- only when no more than one name of roster carries that first name. "Vulo" on a list is no one
-- when "Vulo Sturmwind" and "Vulo Eisherz" are both in the raid.
function ns.SameNameIn(a, b, roster)
    a, b = ns.FullName(a), ns.FullName(b)
    if not a or not b then return false end
    if a:lower() == b:lower() then return true end
    if not ns.SameName(a, b) then return false end
    return firstNameCount(a, roster) <= 1
end

-- A value as it is, or nil when the client marks it secret (chat and unit names in a boss fight
-- on the Forever client). A secret value is never compared, only skipped.
function ns.Plain(v)
    local secret = _G.issecretvalue
    if type(secret) == "function" and secret(v) then return nil end
    return v
end

-- A text for a search: lower case, the German capitals folded too (lower() leaves the bytes of
-- Ä, Ö and Ü as they are). nil and other values give "".
local FOLD = { ["Ä"] = "ä", ["Ö"] = "ö", ["Ü"] = "ü" }
function ns.Fold(s)
    if type(s) ~= "string" then return "" end
    return (s:gsub("\195[\132\150\156]", FOLD):lower())
end

function ns.ExportName(name)
    return (tostring(name or "?"):gsub(" ", "_"))
end

-- /amisia namen: how Amisia reads names on this client, to check Forever's surnames.
ns.RegisterSlash("namen", { aliases = { "names" }, desc = "zeigt, wie Amisia Namen liest", run = function()
    local n, second = UnitName("player")
    ns.msg(("Du: UnitName = \"%s\", \"%s\" -> %s"):format(tostring(n), tostring(second), tostring(ns.UnitFullName("player"))))
    for i = 1, math.min(GetNumGroupMembers() or 0, 5) do
        local rn = GetRaidRosterInfo(i)
        ns.msg(("Gruppe %d: Raidliste = \"%s\" -> %s"):format(i, tostring(rn), tostring(ns.FullName(rn))))
    end
end })
