-- The version of the saved data as a whole (AmisiaDB.schema) and the ordered steps that bring an
-- older file up to it (D-48). Core runs ns.Migrate on ADDON_LOADED before the settings are checked
-- (ns.ApplySettings), so a step can move a setting to its new place before it is checked there. Only
-- these steps remove a stored key: the settings check keeps every key it does not know (a switched-off
-- module's, F-202, D-130).
-- Each step runs once, in order; a step that fails stops the chain (the next login tries again from
-- there) and is reported like any Lua error. A file saved by a newer Amisia is left as it is.
-- The parts' own marks (settings.version, awardsVersion, softres.version, the v fields) stay theirs:
-- a step here is for what crosses parts, a setting moved to another section first of all.
local ADDON, ns = ...
ns.Load(function()
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

-- The keys of the dungeons of part (the facts' part: the client's name of a map of several dungeons) in
-- the facts' order and their encounters (encounter id -> key); empty without the facts (not Forever).
local function partKeys(part)
    local keys, byEnc = {}, {}
    local F = ns.DUNGEON_FACTS
    for _, e in ipairs(type(F) == "table" and type(F.list) == "table" and F.list or {}) do
        if type(e) == "table" and e.part == part and type(e.key) == "string" then
            keys[#keys + 1] = e.key
            for _, id in ipairs(type(e.enc) == "table" and e.enc or {}) do byEnc[id] = e.key end
        end
    end
    return keys, byEnc
end

-- The dungeon of part a saved run of the old key belongs to: the one of its last kill (its latest split).
local function runWing(run, byEnc)
    local key, at
    for enc, secs in pairs(type(run) == "table" and type(run.s) == "table" and run.s or {}) do
        local k = byEnc[enc]
        if k and type(secs) == "number" and (not at or secs > at) then key, at = k, secs end
    end
    return key
end

-- A copy of a saved run with only the splits of dungeon key; finished only when key's last boss is among
-- them (a run of the whole old dungeon ended at the last boss of the order).
local function runOf(run, key, byEnc)
    local s, last = {}, nil
    local F = ns.DUNGEON_FACTS
    for _, e in ipairs(type(F) == "table" and type(F.list) == "table" and F.list or {}) do
        if e.key == key and type(e.enc) == "table" then last = e.enc[#e.enc] end
    end
    for enc, secs in pairs(run.s) do
        if byEnc[enc] == key then s[enc] = secs end
    end
    return { at = run.at, t = run.t, s = s, n = run.n, c = run.c, d = (run.d and last ~= nil and s[last] ~= nil) or nil }
end

-- What the file saved under the old key of a dungeon that is now several (D-106: "sm", the Scarlet
-- Monastery, is four wings): the run times go to the wings (a run and the best to the wing of their last
-- kill with only that wing's splits, a best only if that wing's last boss is among them; the best time
-- per boss to the wing of the boss; a run without a kill goes), a running clock to the wing of its last
-- kill (else the first), the page's chosen dungeon and the marked quest givers to the first wing. Without
-- the facts nothing changes (an unknown key is dropped by its owner or ignored).
function ns.MigrateSplitDungeon(db, old, part)
    local keys, byEnc = partKeys(part)
    local first = keys[1]
    if not first then return end
    local rt = type(db.runTimes) == "table" and db.runTimes or nil
    local rec = rt and type(rt.inst) == "table" and rt.inst[old] or nil
    if type(rec) == "table" then
        rt.inst[old] = nil
        local function into(k)
            local x = rt.inst[k]
            if type(x) ~= "table" then x = {}; rt.inst[k] = x end
            if type(x.seg) ~= "table" then x.seg = {} end
            if type(x.runs) ~= "table" then x.runs = {} end
            return x
        end
        for _, run in ipairs(type(rec.runs) == "table" and rec.runs or {}) do
            local k = runWing(run, byEnc)
            if k then table.insert(into(k).runs, runOf(run, k, byEnc)) end
        end
        local k = runWing(rec.best, byEnc)
        local best = k and runOf(rec.best, k, byEnc)
        if best and best.d then
            local x = into(k)
            local had = type(x.best) == "table" and tonumber(x.best.t)
            if not had or (tonumber(best.t) or had) < had then x.best = best end
        end
        for enc, v in pairs(type(rec.seg) == "table" and rec.seg or {}) do
            local sk = byEnc[enc]
            if sk then into(sk).seg[enc] = v end
        end
    end
    for _, l in pairs(rt and type(rt.live) == "table" and rt.live or {}) do
        if type(l) == "table" and l.k == old then l.k, l.nm = runWing(l, byEnc) or first, nil end
    end
    local s = type(db.settings) == "table" and db.settings or nil
    if s and type(s.bis) == "table" and s.bis.dungeon == old then s.bis.dungeon = first end
    if type(db.map) == "table" and db.map.quests == old then db.map.quests = first end
end

-- The steps; step n brings the file from schema n - 1 to n. Never reorder, never remove one: a
-- step that is no longer needed becomes an empty function.
ns.MIGRATIONS = {
    -- 1 (2.32.0): the count starts; nothing to move
    function(db) end,
    -- 2 (2.32.0): the settings in their sections (spec 2026-10-13-einstellungen-abschnitte): "Wer braucht
    -- das?", the plus-one rules to the roll rounds, the gear table's two into gear and wishes, the guild
    -- wishes, the bench and the Discord text into sections of their own
    function(db)
        for _, m in ipairs({
        { "sync.shareUpgrades", "need.share" },
        { "sync.askUpgrades", "need.ask" },
        { "sync.needTooltip", "need.tooltip" },
        { "awards.plusScope", "rolls.plusScope" },
        { "awards.plusOrder", "rolls.plusOrder" },
        { "gear.kind", "bis.kind" },   -- l10n-ok: setting key
        { "gear.upgradeDot", "bis.upgradeDot" },   -- l10n-ok: setting key
        { "bis.guildTooltip", "wishes.tooltip" },   -- l10n-ok: setting key
        { "bis.guildLootMark", "wishes.lootMark" },   -- l10n-ok: setting key
        { "bis.guildAward", "wishes.award" },   -- l10n-ok: setting key
        { "raidlog.benchChat", "bench.chat" },
        { "raidlog.benchGuildOnly", "bench.guildOnly" },
        { "raidlog.benchNotify", "bench.notify" },
        { "raidlog.discordWipes", "discord.wipes" },
        { "raidlog.discordLoot", "discord.loot" },
        { "raidlog.discordNames", "discord.names" },
        { "raidlog.discordHead", "discord.head" },
        }) do
            ns.MigrateMoveSetting(db, m[1], m[2])
        end
    end,
    -- 3 (2.65.0): the window "Ausrüstungsziele" is the page Ausrüstungsplaner (D-80): its place, its
    -- choices and its scale go
    function(db)
        local s = type(db.settings) == "table" and db.settings
        if not s then return end
        s.goalWindow = nil
        if type(s.ui) == "table" then s.ui.goalScale = nil end
    end,
    -- 4 (2.67.0): flight masters, zeppelins and ships leave the world map by default (D-83): a stored
    -- choice goes, so the new default holds; the player can switch them on again
    function(db)
        local m = type(db.settings) == "table" and db.settings.map
        if type(m) ~= "table" then return end
        m.flights, m.transports = nil, nil
    end,
    -- 5 (2.71.0): the item display ("+Item") has its own section "Item-Anzeige" (D-89)
    function(db)
        for _, m in ipairs({
            { "ui.lootToast", "toast.show" },
            { "ui.lootToastMoney", "toast.money" },
            { "ui.lootToastSize", "toast.size" },
            { "ui.lootToastQuality", "toast.quality" },
        }) do
            ns.MigrateMoveSetting(db, m[1], m[2])
        end
    end,
    -- 6 (2.75.0): the Scarlet Monastery is four dungeons, one per wing (F-174, D-106): what was saved
    -- under its old key "sm" goes to the wings
    function(db) ns.MigrateSplitDungeon(db, "sm", "Scarlet Monastery") end,
    -- 7 (2.85.1): the target window shows for the client's map pin too (F-203): the old "auto",
    -- the default before, goes so the new default "Immer" holds; "Aus" stays
    function(db)
        local m = type(db.settings) == "table" and db.settings.map
        if type(m) == "table" and m.arrow == "auto" then m.arrow = nil end
    end,
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
            ns.ReportError(err)
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
end)
