-- The version of the saved data as a whole (AmisiaDB.schema) and the ordered steps that bring an
-- older file up to it (D-48). Core runs ns.Migrate on ADDON_LOADED before the settings are checked
-- (ns.ApplySettings), so a step can move a setting to its new place before an unknown one is dropped.
-- Each step runs once, in order; a step that fails stops the chain (the next login tries again from
-- there) and is reported like any Lua error. A file saved by a newer Amisia is left as it is.
-- The parts' own marks (settings.version, awardsVersion, softres.version, the v fields) stay theirs:
-- a step here is for what crosses parts, a setting moved to another section first of all.
local ADDON, ns = ...
local L = ns.L

-- Moves a stored setting from one path to another ("sync.shareUpgrades" -> "need.share"), when the
-- new place holds nothing yet; the old value goes either way. For the steps below.
function ns.MigrateMoveSetting(db, from, to)
    local s = type(db.settings) == "table" and db.settings
    if not s then return end
    local fs, fk = from:match("^(%w+)%.(%w+)$")
    local ts, tk = to:match("^(%w+)%.(%w+)$")
    if type(s[fs]) ~= "table" or s[fs][fk] == nil then return end
    local old = s[fs][fk]
    s[fs][fk] = nil
    if type(s[ts]) ~= "table" then s[ts] = {} end
    if s[ts][tk] == nil then s[ts][tk] = old end
end

-- The steps; step n brings the file from schema n - 1 to n. Never reorder, never remove one: a
-- step that is no longer needed becomes an empty function.
ns.MIGRATIONS = {
    -- 1 (2.32.0): the count starts; nothing to move
    function(db) end,
}

local newer   -- the schema of a file a newer Amisia saved, for the one chat line

-- Runs the steps the file has not had. Returns the schema the file has now.
function ns.Migrate(db)
    local from = tonumber(db.schema) or 0
    if from > #ns.MIGRATIONS then
        newer = from
        return from
    end
    for v = from + 1, #ns.MIGRATIONS do
        local ok, err = pcall(ns.MIGRATIONS[v], db)
        if not ok then
            local report = geterrorhandler and geterrorhandler()
            if report then report(err) end
            return db.schema or 0
        end
        db.schema = v
    end
    return db.schema
end

ns.OnEvent("PLAYER_LOGIN", function()
    if newer then
        ns.msg(L["Die gespeicherten Daten stammen von einer neueren Amisia-Version (Stand %d, diese kennt %d). Bitte Amisia aktualisieren."]:format(newer, #ns.MIGRATIONS))
    end
end)
