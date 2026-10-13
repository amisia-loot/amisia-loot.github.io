-- Amisia registry: every feature announces its page, its overview card, its settings and its
-- slash commands here; the main window, the settings page and the command help are built from
-- what is registered. Loaded first, so every other file can register while it loads.
local ADDON, ns = ...
local L = ns.L

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
-- group names the page's tab (ns.PANEL_GROUPS); bottom (the old sidebar) is still allowed but no
-- longer read.
function ns.RegisterPanel(spec)
    assert(type(spec.key) == "string" and type(spec.create) == "function", "RegisterPanel needs key and create")
    upsert(ns.panels, spec, "key")
end

-- The tabs under the main window, left to right (since 2.27.0, D-45; until then the collapsible
-- sections of the page list): the page list shows the pages of the chosen tab.
ns.PANEL_GROUPS = {
    { key = "raid", label = "Raid" },
    { key = "gear", label = L["Ausrüstung"] },
    { key = "guild", label = L["Gilde"] },
    { key = "calendar", label = L["Kalender"] },
    { key = "amisia", label = "Amisia" },
}

-- The tab of a page: its group, else by its order (a page without one or with an unknown one, a
-- test page).
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
    if allowOff and (text == "aus" or text == "off") then return false end -- l10n-ok: typed words, both work
    local h, m = text:match("^(%d%d?)[:.](%d%d)$")
    if not h then h, m = text:match("^(%d%d?)$"), "0" end
    h, m = tonumber(h), tonumber(m)
    if not h or not m or h > 23 or m > 59 then return nil end
    return h * 60 + m
end

function ns.FormatTime(mins)
    if not mins then return L["aus"] end
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
-- Item: { key = "section.name", type = toggle|slider|time|choice|text|button|desc|custom, label, tip,
--         default, min, max, step, allowOff, values = { { value, text } }, officer, expert,
--         available, validate = fn, onChange = fn(value), run = fn (buttons), invalid = "reason" }
--         (custom: build = fn(parent) -> frame, fill = fn(frame); the settings page shows the frame)
-- Section: { key, label, order, group = the tab it belongs to (a key of ns.PANEL_GROUPS; "amisia" is
--            "Allgemein"), pages = { page keys whose head button "Einstellungen" opens it }, officer,
--            expert, available, items } (D-49)
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

-- The visible sections, by their tab (ns.PANEL_GROUPS order), then their order: { { key, label,
-- sections = { section, ... } }, ... }; a tab without a visible section is left out.
function ns.SettingsGroups()
    local out, byKey = {}, {}
    for _, g in ipairs(ns.PANEL_GROUPS) do
        local e = { key = g.key, label = g.key == "amisia" and L["Allgemein"] or g.label, sections = {} }
        out[#out + 1], byKey[g.key] = e, e
    end
    for _, sec in ipairs(ns.schema) do
        local e = byKey[sec.group] or byKey.amisia
        if ns.Visible(sec) then e.sections[#e.sections + 1] = sec end
    end
    local shown = {}
    for _, e in ipairs(out) do
        if #e.sections > 0 then
            table.sort(e.sections, function(a, b)
                if (a.order or 50) ~= (b.order or 50) then return (a.order or 50) < (b.order or 50) end
                return a.key < b.key
            end)
            shown[#shown + 1] = e
        end
    end
    return shown
end

-- The visible sections whose head button a page shows (section.pages), in the list's order.
function ns.SettingsSectionsOf(pageKey)
    local out = {}
    for _, g in ipairs(ns.SettingsGroups()) do
        for _, sec in ipairs(g.sections) do
            for _, p in ipairs(sec.pages or {}) do
                if p == pageKey then out[#out + 1] = sec break end
            end
        end
    end
    return out
end

-- Whether a section holds a setting that is not on its default.
function ns.SectionChanged(sec)
    for _, it in ipairs(sec.items or {}) do
        if it.key and it.type ~= "button" and it.type ~= "desc" and it.type ~= "custom" and not ns.IsDefault(it.key) then
            return true
        end
    end
    return false
end

-- Sets every setting of the sections back to its default (buttons, notes and the loot rules' editor
-- store nothing). Returns how many changed.
function ns.ResetSections(list)
    local n = 0
    for _, sec in ipairs(list) do
        for _, it in ipairs(sec.items or {}) do
            if it.key and it.type ~= "button" and it.type ~= "desc" and it.type ~= "custom" and not ns.IsDefault(it.key) then
                ns.Reset(it.key)
                n = n + 1
            end
        end
    end
    return n
end

-- The visible settings section a word names: its key ("map"), its name ("Karte und Wegpunkt") or the
-- start of its name ("karte"), any case; nil when none does.
function ns.SettingsSection(word)
    local w = ns.Fold((tostring(word or ""):match("^%s*(.-)%s*$")))
    if w == "" then return nil end
    local sections = {}
    for _, sec in ipairs(ns.schema) do
        if ns.Visible(sec) then sections[#sections + 1] = sec end
    end
    table.sort(sections, function(a, b)
        if (a.order or 50) ~= (b.order or 50) then return (a.order or 50) < (b.order or 50) end
        return a.key < b.key
    end)
    for _, sec in ipairs(sections) do
        if sec.key == w or ns.Fold(sec.label) == w then return sec end
    end
    for _, sec in ipairs(sections) do
        if ns.Fold(sec.label):sub(1, #w) == w then return sec end
    end
    return nil
end

-- Whether a settings item matches a search text (plain, lower case, not empty): by its label, its
-- tip, its path or the names of its choices. The settings page and the main window's search use it.
function ns.SettingHits(it, query)
    local function hit(text)
        return type(text) == "string" and ns.Fold(text):find(query, 1, true) ~= nil
    end
    if query == "" or hit(it.label) or hit(it.tip) or hit(it.key) then return true end
    for _, c in ipairs(it.values or {}) do if hit(c[2]) then return true end end
    return false
end

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
    if not it or it.type == "button" or it.type == "desc" then return false, L["Unbekannte Einstellung: %s"]:format(tostring(path)) end
    local s = stored()
    if not s then return false, L["Amisia ist noch nicht geladen."] end
    local ok, v = check(it, value)
    if not ok then return false, it.invalid or L["Ungültiger Wert."] end
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
    ns.msg(L["Befehle (das Fenster öffnet /amisia):"])
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
        ns.msg(L["Unbekannter Befehl \"%s\"."]:format(word))
        ns.ShowHelp()
        return
    end
    def.run(rest or "", word:lower())
end

SLASH_AMISIA1 = "/amisia"
SlashCmdList.AMISIA = ns.Dispatch

ns.RegisterSlash("hilfe", { en = "help", aliases = { "?" }, desc = L["alle Befehle"], run = function() ns.ShowHelp() end })

---------------------------------------------------------------------------
-- Interface settings that belong to no single feature
---------------------------------------------------------------------------
ns.RegisterSettings{ key = "ui", label = L["Oberfläche"], order = 90, group = "amisia", pages = { "about" }, items = {
    { key = "ui.minimap", type = "toggle", label = L["Minimap-Button"], default = true,
      tip = L["Der runde Amisia-Button am Rand der Minimap."],
      onChange = function(v) if ns.ShowMinimapButton then ns.ShowMinimapButton(v) end end },
    { key = "ui.scale", type = "slider", label = L["Fenstergröße (%)"], default = 100, min = 70, max = 130, step = 5,
      onChange = function(v) if ns.ApplyScale then ns.ApplyScale(v) end end, tip = L["Größe des Amisia-Fensters in Prozent."] },
    { key = "ui.talentScale", type = "slider", label = L["Größe des Talentfensters (%)"], default = 100, min = 70, max = 150, step = 5,
      tip = L["Das große Talentfenster (Talentrechner). Strg + Mausrad über dem Fenster ändert die Größe auch."],
      onChange = function(v) if ns.ApplyTalentScale then ns.ApplyTalentScale(v) end end },
    { key = "ui.resetPosition", type = "button", label = L["Fensterposition zurücksetzen"],
      run = function() if ns.ResetPositions then ns.ResetPositions() end end, tip = L["Setzt Hauptfenster, Ausrüstungstabelle, Würfel-Fenster, Talentrechner und Raid-Kalender an ihren Standardplatz zurück."] },
    { key = "ui.view", type = "choice", label = L["Ansicht"], default = "auto",
      values = { { "auto", L["Automatisch"] }, { "officer", L["Offizier"] }, { "raider", "Raider" } },
      tip = L["Automatisch: wer Offiziersnotizen bearbeiten darf, sieht den Offiziersbereich."] },
    { key = "ui.expert", type = "toggle", label = L["Expertenmodus"], default = false,
      tip = L["Zeigt die Werkzeuge und seltene Einstellungen."] },
    { key = "ui.resetAll", type = "button", label = L["Alle Einstellungen zurücksetzen"],
      tip = L["Setzt nach einer Rückfrage alle Einstellungen aller Abschnitte auf ihren Standard. Raids, Listen, Wünsche und Fensterplätze bleiben."],
      run = function()
          ns.W.Confirm(L["Alle Einstellungen zurücksetzen"], L["Alle Einstellungen aller Abschnitte auf den Standard setzen? Raids, Listen, Wünsche und Fensterplätze bleiben."],
              L["Zurücksetzen"], function()
                  local n = ns.ResetSections(ns.schema)
                  ns.msg(L["%d Einstellungen auf den Standard gesetzt."]:format(n))
              end)
      end },
}}
