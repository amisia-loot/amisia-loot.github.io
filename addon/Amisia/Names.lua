-- Character names. Forever names are "First Surname" (one space, the surname may hold a dash);
-- Anniversary names may carry "-Realm". Everything that compares names goes through FullName and
-- SameName, and the export writes "_" for the space (no WoW name holds an underscore), so its
-- fields stay space-separated.
local ADDON, ns = ...

function ns.IsForever()
    local toc = GetBuildInfo and select(4, GetBuildInfo()) or 0
    return toc >= 16000 and toc < 17000
end

-- One spelling of a name: trimmed, single spaces, no realm on Anniversary, and on Forever the
-- surname added when it comes separately (UnitName's second value there).
function ns.FullName(name, surname)
    if type(name) ~= "string" then return nil end
    name = name:match("^%s*(.-)%s*$"):gsub("%s+", " ")
    if ns.IsForever() then
        if type(surname) == "string" and surname ~= "" and not name:find(" ", 1, true) then
            name = name .. " " .. surname
        end
    else
        name = name:match("^([^%-]+)") or name
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
