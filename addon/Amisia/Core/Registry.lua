-- Amisia registry: every feature announces its page, its overview card, its settings and its
-- slash commands here; the main window, the settings page and the command help are built from
-- what is registered. Loaded first, so every other file can register while it loads.
local ADDON, ns = ...

ns.panels, ns.cards, ns.schema, ns.slash = {}, {}, {}, {}
local items = {}        -- setting path -> item of the schema
local slashWords = {}   -- command word or alias -> definition
local listeners = {}    -- message name -> handlers
local SETTINGS_VERSION = 2

local function byOrder(a, b)
    local oa, ob = a.order or 99, b.order or 99
    if oa ~= ob then return oa < ob end
    return tostring(a.key or a.word) < tostring(b.key or b.word)
end

-- Adds spec to list, replacing an entry with the same id, and keeps the list in order.
local function upsert(list, spec, field)
    for i, s in ipairs(list) do
        if s[field] == spec[field] then table.remove(list, i) break end
    end
    list[#list + 1] = spec
    table.sort(list, byOrder)
end

---------------------------------------------------------------------------
-- Internal messages
---------------------------------------------------------------------------
function ns.Listen(name, fn)
    listeners[name] = listeners[name] or {}
    table.insert(listeners[name], fn)
end

-- Handlers run protected, so one broken handler cannot stop the others; its error still goes to
-- the client's error handler and shows up like any other Lua error.
function ns.Fire(name, ...)
    for _, fn in ipairs(listeners[name] or {}) do
        local ok, err = pcall(fn, ...)
        if not ok then
            local handler = geterrorhandler and geterrorhandler()
            if handler then handler(err) end
        end
    end
end

---------------------------------------------------------------------------
-- Pages and overview cards
---------------------------------------------------------------------------
-- Page: { key, label, icon, order, group, officer, expert, available = fn, create = fn(parent) -> frame,
--         refresh = fn(frame) }. Built the first time it is opened, refreshed only while shown.
-- group names the section of the page list (ns.PANEL_GROUPS); bottom (the old sidebar) is still
-- allowed but no longer read.
function ns.RegisterPanel(spec)
    assert(type(spec.key) == "string" and type(spec.create) == "function", "RegisterPanel needs key and create")
    upsert(ns.panels, spec, "key")
end

-- The sections of the page list, top to bottom.
ns.PANEL_GROUPS = {
    { key = "raid", label = "Raid" },
    { key = "gear", label = "Ausrüstung" },
    { key = "guild", label = "Gilde" },
    { key = "amisia", label = "Amisia" },
}

-- The section of a page: its group, else by its order (a page without one or with an unknown one,
-- a test page).
function ns.PanelGroup(p)
    for _, g in ipairs(ns.PANEL_GROUPS) do
        if g.key == p.group then return p.group end
    end
    local o = p.order or 99
    if o < 50 then return "raid" elseif o < 60 then return "gear" elseif o < 900 then return "guild" end
    return "amisia"
end

function ns.Panel(key)
    for _, p in ipairs(ns.panels) do
        if p.key == key then return p end
    end
    return nil
end

-- Card on the overview: { key, order, officer, expert, available = fn, fill = fn(card) }.
function ns.RegisterCard(spec)
    assert(type(spec.key) == "string" and type(spec.fill) == "function", "RegisterCard needs key and fill")
    upsert(ns.cards, spec, "key")
end

local function guildOfficer()
    local can = C_GuildInfo and C_GuildInfo.CanEditOfficerNote
    return type(can) == "function" and can() and true or false
end

-- Whether the officer parts are shown: whoever may edit officer notes, unless the view is forced.
function ns.IsOfficerView()
    local view = ns.Get("ui.view")
    if view == "officer" then return true end
    if view == "raider" then return false end
    return guildOfficer()
end

-- Whether a page, card, settings section or item is shown right now.
function ns.Visible(spec)
    if not spec then return false end
    if spec.available and not spec.available() then return false end
    if spec.officer and not ns.IsOfficerView() then return false end
    if spec.expert and not ns.Get("ui.expert") then return false end
    return true
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
local function split(path)
    return tostring(path):match("^([%w_]+)%.([%w_]+)$")
end

local function put(s, path, value)
    local sec, key = split(path)
    s[sec] = type(s[sec]) == "table" and s[sec] or {}
    s[sec][key] = value
end

-- Minutes after midnight from "20:00", "20.30" or "20"; false for "aus"/"off" when allowOff.
function ns.ParseTime(text, allowOff)
    text = tostring(text or ""):lower():match("^%s*(.-)%s*$")
    if allowOff and (text == "aus" or text == "off") then return false end
    local h, m = text:match("^(%d%d?)[:.](%d%d)$")
    if not h then h, m = text:match("^(%d%d?)$"), "0" end
    h, m = tonumber(h), tonumber(m)
    if not h or not m or h > 23 or m > 59 then return nil end
    return h * 60 + m
end

function ns.FormatTime(mins)
    if not mins then return "aus" end
    return ("%02d:%02d"):format(math.floor(mins / 60), mins % 60)
end

-- A value checked against its item: ok, and the value to store.
local function normalize(it, v)
    local t = it.type
    if t == "toggle" then
        return type(v) == "boolean", v
    elseif t == "slider" then
        local n = tonumber(v)
        if not n or n ~= n or n < it.min or n > it.max then return false end
        local step = it.step or 1
        return true, it.min + math.floor((n - it.min) / step + 0.5) * step
    elseif t == "time" then
        local mins = v
        if type(v) == "string" then mins = ns.ParseTime(v, it.allowOff) end
        if mins == false then return it.allowOff and true or false, false end
        if type(mins) ~= "number" or mins < 0 or mins > 1439 or mins % 1 ~= 0 then return false end
        return true, mins
    elseif t == "choice" then
        for _, c in ipairs(it.values) do
            if c[1] == v then return true, v end
        end
        return false
    elseif t == "text" then
        return type(v) == "string", v
    end
    return false
end

-- validate (non-boolean types only) may adjust a value or refuse it with nil.
local function check(it, v)
    local ok, value = normalize(it, v)
    if ok and it.validate then
        value = it.validate(value)
        ok = value ~= nil
    end
    return ok, value
end

-- Section: { key, label, order, officer, expert, available, items = { item... } }
-- Item: { key = "section.name", type = toggle|slider|time|choice|text|button|desc, label, tip,
--         default, min, max, step, allowOff, values = { { value, text } }, officer, expert,
--         available, validate = fn, onChange = fn(value), run = fn (buttons), invalid = "reason" }
function ns.RegisterSettings(section)
    assert(type(section.key) == "string" and type(section.items) == "table", "RegisterSettings needs key and items")
    for _, it in ipairs(section.items) do
        it.section = section
        if it.key then
            assert(split(it.key), "setting path must be section.name: " .. tostring(it.key))
            items[it.key] = it
        end
    end
    upsert(ns.schema, section, "key")
end

function ns.SettingItem(path) return items[path] end

local function stored()
    return AmisiaDB and AmisiaDB.settings
end

function ns.Get(path)
    local sec, key = split(path)
    local s = stored()
    if s and sec and type(s[sec]) == "table" and s[sec][key] ~= nil then return s[sec][key] end
    local it = items[path]
    if it then return it.default end
    return nil
end

function ns.IsDefault(path)
    local it = items[path]
    return not it or ns.Get(path) == it.default
end

function ns.Set(path, value)
    local it = items[path]
    if not it or it.type == "button" or it.type == "desc" then return false, "Unbekannte Einstellung: " .. tostring(path) end
    local s = stored()
    if not s then return false, "Amisia ist noch nicht geladen." end
    local ok, v = check(it, value)
    if not ok then return false, it.invalid or "Ungültiger Wert." end
    put(s, path, v)
    if it.onChange then it.onChange(v) end
    ns.Fire("SETTING", path, v)
    return true, v
end

function ns.Reset(path)
    local it = items[path]
    local s = stored()
    if not it or not s then return end
    local sec, key = split(path)
    if type(s[sec]) == "table" then s[sec][key] = nil end
    if it.onChange then it.onChange(it.default) end
    ns.Fire("SETTING", path, it.default)
end

-- Called by Core on ADDON_LOADED: moves the flat settings of 1.3 into their sections once and drops
-- stored values that no longer pass (a changed range, a hand-edited file).
function ns.ApplySettings(root)
    root.settings = root.settings or {}
    local s = root.settings
    if (tonumber(s.version) or 1) < SETTINGS_VERSION then
        local function move(path, v)
            if v ~= nil then put(s, path, v) end
        end
        move("record.enabled", s.enabled); s.enabled = nil
        move("record.lateAt", s.lateAt); s.lateAt = nil
        move("rolls.seconds", tonumber(s.rollSeconds)); s.rollSeconds = nil
        move("tools.collect", s.collect); s.collect = nil
        if type(s.minimap) == "table" and s.minimap.hide ~= nil then
            move("ui.minimap", not s.minimap.hide)
            s.minimap.hide = nil
        end
        if type(root.scan) == "table" then move("tools.scanRate", tonumber(root.scan.rate)) end
        s.version = SETTINGS_VERSION
    end
    for path, it in pairs(items) do
        local sec, key = split(path)
        if type(s[sec]) == "table" and s[sec][key] ~= nil and not check(it, s[sec][key]) then
            s[sec][key] = nil
        end
    end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
-- def: { en = "word", aliases = { ... }, args = "<x>", desc, officer, run = fn(rest, word) }
-- word is the German command, en the English one (the help of an English client shows it); both and
-- every alias work in every language. A word another command already holds is an error.
local function claim(w, def)
    local had = slashWords[w]
    if had and had.word ~= def.word then
        error(("slash word %q of /amisia %s is taken by /amisia %s"):format(w, def.word, had.word), 3)
    end
    slashWords[w] = def
end

function ns.RegisterSlash(word, def)
    def.word = word
    upsert(ns.slash, def, "word")
    claim(word, def)
    if def.en then claim(def.en, def) end
    for _, a in ipairs(def.aliases or {}) do claim(a, def) end
end

-- The word of a command in the client's language.
function ns.SlashWord(def)
    return (not ns.GERMAN and def.en) or def.word
end

function ns.SlashHelpLines(officer)
    local out = {}
    for _, def in ipairs(ns.slash) do
        if officer or not def.officer then
            out[#out + 1] = ("/amisia %s%s - %s"):format(ns.SlashWord(def), def.args and (" " .. def.args) or "", def.desc or "")
        end
    end
    return out
end

function ns.ShowHelp()
    local chat = DEFAULT_CHAT_FRAME
    ns.msg("Befehle (das Fenster öffnet /amisia):")
    for _, line in ipairs(ns.SlashHelpLines(ns.IsOfficerView())) do chat:AddMessage("  " .. line) end
end

function ns.Dispatch(input)
    local raw = (input or ""):match("^%s*(.-)%s*$") or ""
    local word, rest = raw:match("^(%S+)%s*(.*)$")
    if not word then
        if ns.ToggleMain then ns.ToggleMain() end
        return
    end
    local def = slashWords[word:lower()]
    if not def then
        ns.msg(("Unbekannter Befehl \"%s\"."):format(word))
        ns.ShowHelp()
        return
    end
    def.run(rest or "", word:lower())
end

SLASH_AMISIA1 = "/amisia"
SlashCmdList.AMISIA = ns.Dispatch

ns.RegisterSlash("hilfe", { en = "help", aliases = { "?" }, desc = "alle Befehle", run = function() ns.ShowHelp() end })

---------------------------------------------------------------------------
-- Interface settings that belong to no single feature
---------------------------------------------------------------------------
ns.RegisterSettings{ key = "ui", label = "Oberfläche", order = 90, items = {
    { key = "ui.minimap", type = "toggle", label = "Minimap-Button", default = true,
      tip = "Der runde Amisia-Button am Rand der Minimap.",
      onChange = function(v) if ns.ShowMinimapButton then ns.ShowMinimapButton(v) end end },
    { key = "ui.scale", type = "slider", label = "Fenstergröße (%)", default = 100, min = 70, max = 130, step = 5,
      onChange = function(v) if ns.ApplyScale then ns.ApplyScale(v) end end },
    { key = "ui.resetPosition", type = "button", label = "Fensterposition zurücksetzen",
      run = function() if ns.ResetPositions then ns.ResetPositions() end end },
    { key = "ui.view", type = "choice", label = "Ansicht", default = "auto",
      values = { { "auto", "Automatisch" }, { "officer", "Offizier" }, { "raider", "Raider" } },
      tip = "Automatisch: wer Offiziersnotizen bearbeiten darf, sieht den Offiziersbereich." },
    { key = "ui.expert", type = "toggle", label = "Expertenmodus", default = false,
      tip = "Zeigt die Werkzeuge und seltene Einstellungen." },
}}
