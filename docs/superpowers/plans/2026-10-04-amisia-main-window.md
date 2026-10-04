# Amisia 1.4 Hauptfenster Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Amisia bekommt ein Fundament (Registry für Seiten, Übersichtskarten, Einstellungen, Befehle, interne Nachrichten), ein neues Hauptfenster mit Seitenleiste und Einstellungsseite, Forever-Nachnamen im Export und auf der Website, und zwei Korrekturen der Ausrüstungstabelle.

**Architecture:** `Registry.lua` lädt als erste Datei und bietet `RegisterPanel/RegisterCard/RegisterSettings/RegisterSlash/Get/Set/Listen/Fire`. Jede Feature-Datei meldet dort ihre Einstellungen und Befehle an; `MainFrame.lua` baut Fenster und Seitenleiste aus `ns.panels`, `Pages/*.lua` melden je eine Seite an. `Widgets.lua` liefert die gemeinsamen UI-Bausteine. `Names.lua` vereinheitlicht Namen und kodiert Leerzeichen im Export als `_`.

**Tech Stack:** Lua 5.1 (WoW 2.5.6 und Forever 1.60.1), Tests mit Python `lupa` (`addon/tests/run.py`, Stub `addon/tests/wow_stub.lua`), Syntaxcheck `node addon/tests/syntax.cjs`, Python-Tests `python -m pytest tools/tests -q`, Website `index.html`.

## Global Constraints

- Ein TOC `## Interface: 20506, 16001`; alles, was einem Client fehlt, zur Laufzeit prüfen.
- Keine fremden Bibliotheken, kein `UIDropDownMenu`/`EasyMenu`, keine Blizzard-Einstellungskategorie.
- UI-Texte deutsch, nur Latin-1-Zeichen (ä ö ü ß und "·" erlaubt; keine U+2013, U+2026, U+25CF, Pfeile). Symbole als Textur.
- Code-Kommentare englisch, im Stil der vorhandenen Dateien.
- Fensterebenen: Hauptfenster und Ausrüstung `FULLSCREEN` + `SetToplevel`, Roll/Soft-Reserve-Fenster `FULLSCREEN_DIALOG`.
- Offiziersansicht: `C_GuildInfo.CanEditOfficerNote` oder globales `CanEditOfficerNote`; Einstellung `ui.view` (auto/officer/raider).
- Export-Kopf `#AMISIA 2 <Exporteur>`, Namen mit `_` statt Leerzeichen; die Seite liest Version 1 und 2.
- Nach Änderung an `index.html`: Twin neu bauen, veröffentlichen, `python tools/twin_stamp.py --published`.
- Nie eine Referenz-Addon (Gargul, RCLootCouncil, ...) in ausgelieferten Texten, Kommentaren oder Commits nennen.
- Bash-Heredocs verschlucken `\\n` und Backslashes: Lua-Teststrings mit `[[...]]` oder über das Edit-Tool schreiben; `.ps1` nur mit dem Edit-Tool ändern.
- Nach Änderungen an `addon/Amisia` per Python/Shell: `pwsh -File tools/sync_addon.ps1` von Hand (der Hook greift nur bei Edit/Write).
- Commits lokal pro Task; Push erst nach Freigabe des Nutzers.

Abweichung vom Entwurf: `Registry.lua` lädt **vor** `Core.lua` (nicht danach), damit `Core.lua` beim Laden schon Einstellungen und Befehle anmelden kann. Der Entwurf wird in Task 1 angepasst.

---

## Dateistruktur

| Datei | Verantwortung |
|---|---|
| `addon/Amisia/Registry.lua` (neu) | Panels, Karten, Einstellungsschema mit Prüfung und Umzug, Slash-Dispatcher mit Hilfe, interne Nachrichten, Offiziersansicht, UI-Einstellungen |
| `addon/Amisia/Names.lua` (neu) | `ns.FullName`, `ns.SameName`, `ns.UnitFullName`, `ns.ExportName`, `/amisia namen` |
| `addon/Amisia/Widgets.lua` (neu) | `ns.W`: Text, Flat, Border, Button, Chip, Toggle, Stepper, TimeBox, Choice, EditArea, ScrollText, List, Card, Menu, Tooltip |
| `addon/Amisia/MainFrame.lua` (neu) | Fenster, Kopfzeile, Seitenleiste, `ns.ShowPage`, `ns.ToggleMain`, `ns.Refresh`, Position/Skalierung |
| `addon/Amisia/Pages/Overview.lua` | Übersicht mit Karten aus `ns.cards` |
| `addon/Amisia/Pages/Raids.lua` | Raid-Liste, Auswahl, Details, Löschen; Karten "raid" und "awards" |
| `addon/Amisia/Pages/Export.lua` | Exportbox, `ns.ShowExport`; Karte "export" |
| `addon/Amisia/Pages/Rolls.lua` | laufende und letzte Runden |
| `addon/Amisia/Pages/SoftRes.lua` | Tabelle der Soft-Reserves; Karte "softres" |
| `addon/Amisia/Pages/Gear.lua` | eigene Upgrades (Forever); Karte "gear" |
| `addon/Amisia/Pages/Bank.lua` | letzte Gildenbank-Zählung; Karte "bank" |
| `addon/Amisia/Pages/Tools.lua` | Scan und Sammler (Expertenmodus) |
| `addon/Amisia/Pages/Settings.lua` | Einstellungsseite aus `ns.schema` |
| `addon/Amisia/Pages/About.lua` | Version und Befehle |
| `addon/Amisia/UI.lua` | entfällt |
| `Core.lua`, `Awards.lua`, `Rolls.lua`, `RollFrame.lua`, `SoftRes.lua`, `Collect.lua`, `Scan.lua`, `GearFrame.lua`, `Minimap.lua` | melden Einstellungen/Befehle an, lesen über `ns.Get`, Namen über `Names.lua` |
| `index.html` | `glCleanName`, `amParse`, Hinweis für Vornamen-Treffer |
| `tools/build_gear.py` | Testitems ausschließen |

TOC-Reihenfolge am Ende (Task 9):

```
Registry.lua
Core.lua
Names.lua
Widgets.lua
Awards.lua
Rolls.lua
RollFrame.lua
SoftRes.lua
Scan.lua
Collect.lua
GearData.lua [AllowLoadGameType camelot]
GearWeights.lua [AllowLoadGameType camelot]
Gear.lua
GearFrame.lua
MainFrame.lua
Pages\Overview.lua
Pages\Raids.lua
Pages\Rolls.lua
Pages\SoftRes.lua
Pages\Gear.lua
Pages\Export.lua
Pages\Bank.lua
Pages\Tools.lua
Pages\Settings.lua
Pages\About.lua
Minimap.lua
```

`addon/tests/run.py` muss Unterordner-Pfade mit `\` laden (Task 5 ersetzt `\` durch `os.sep`).

---

### Task 1: Registry (Einstellungen, Befehle, Nachrichten, Panels)

**Files:**
- Create: `addon/Amisia/Registry.lua`
- Modify: `addon/Amisia/Amisia.toc` (Registry.lua als erste Datei)
- Modify: `addon/tests/wow_stub.lua` (geterrorhandler, GetBuildInfo, C_GuildInfo, MouseIsOver, fehlende Frame-/Region-Methoden)
- Modify: `docs/superpowers/specs/2026-10-04-amisia-main-window-design.md` (Ladereihenfolge)
- Test: `addon/tests/test_registry.lua`

**Interfaces:**
- Produces: `ns.RegisterPanel(spec)`, `ns.Panel(key)`, `ns.RegisterCard(spec)`, `ns.RegisterSettings(section)`, `ns.SettingItem(path)`, `ns.Get(path)`, `ns.Set(path, v) -> ok, valueOrReason`, `ns.Reset(path)`, `ns.IsDefault(path)`, `ns.ApplySettings(root)`, `ns.ParseTime(text, allowOff) -> minutes|false|nil`, `ns.FormatTime(minutes|false) -> "HH:MM"|"aus"`, `ns.RegisterSlash(word, def)`, `ns.SlashHelpLines(officer)`, `ns.ShowHelp()`, `ns.Dispatch(input)`, `ns.Listen(name, fn)`, `ns.Fire(name, ...)`, `ns.IsOfficerView()`, `ns.Visible(spec)`. Einstellungen `ui.minimap`, `ui.scale`, `ui.resetPosition`, `ui.view`, `ui.expert`. Befehl `hilfe`.

- [ ] **Step 1: Stub ergänzen**

In `addon/tests/wow_stub.lua` nach `_G.GetGuildInfo = ...` einfügen:

```lua
-- errors inside protected handlers still fail the test
_G.geterrorhandler = function() return function(e) error(e, 0) end end
STUB.toc = 20506
_G.GetBuildInfo = function() return "2.5.6", "99999", "Oct 1 2026", STUB.toc end
STUB.officer = true
_G.C_GuildInfo = { CanEditOfficerNote = function() return STUB.officer end }
_G.MouseIsOver = function() return false end
_G.IsShiftKeyDown = function() return STUB.shift and true or false end
_G.IsControlKeyDown = function() return false end
```

In der Liste der Region-Methoden `"SetDesaturated", "SetVertexColor", "ClearAllPoints"` ergänzen um `"SetJustifyV", "SetNonSpaceWrap", "SetSpacing", "SetMaxLines"` und nach `f.GetStringWidth = ...` einfügen:

```lua
    f.GetStringHeight = function(self) return 14 end
```

In `frameMethods` ergänzen: `"Raise", "Lower", "SetUserPlaced", "SetJustifyH", "SetJustifyV", "SetTextInsets", "SetNumeric", "SetHighlightFontObject", "SetNormalFontObject"`. In `_G.CreateFrame` nach `f.GetFrameLevel = ...` einfügen:

```lua
    f.GetPoint = function(self) return self._point or "CENTER", nil, self._point or "CENTER", self._x or 0, self._y or 0 end
    f.GetWidth = function(self) return self._w or 400 end
    f.GetHeight = function(self) return self._h or 300 end
    f.GetScale = function(self) return self._scale or 1 end
    f.SetScale = function(self, s) self._scale = s end
    f.SetSize = function(self, w, h) self._w, self._h = w, h end
    f.SetWidth = function(self, w) self._w = w end
    f.SetHeight = function(self, h) self._h = h end
    f.GetChecked = function(self) return self.checked end
```

(`SetSize`, `SetWidth`, `SetHeight`, `SetScale` stehen schon als NOOP in `frameMethods`; die Zuweisung danach überschreibt sie.)

- [ ] **Step 2: Failing test schreiben**

`addon/tests/test_registry.lua`:

```lua
-- The registry: settings with defaults, checks, reset, migration; slash commands; messages; panels.
assert(NS.RegisterSettings and NS.Get and NS.Set, "registry loaded")

NS.RegisterSettings{ key = "t", label = "Test", order = 1, items = {
    { key = "t.on", type = "toggle", label = "An", default = true },
    { key = "t.n", type = "slider", label = "Zahl", default = 20, min = 5, max = 120, step = 5 },
    { key = "t.at", type = "time", allowOff = true, label = "Zeit", default = 20 * 60 },
    { key = "t.mode", type = "choice", label = "Modus", default = "a", values = { { "a", "A" }, { "b", "B" } } },
    { key = "t.go", type = "button", label = "Los", run = function() end },
}}

-- defaults
assert(NS.Get("t.on") == true and NS.Get("t.n") == 20 and NS.Get("t.at") == 1200 and NS.Get("t.mode") == "a")
assert(NS.IsDefault("t.n"))

-- set, check, step rounding
local changed = {}
NS.Listen("SETTING", function(path, v) changed[#changed + 1] = path .. "=" .. tostring(v) end)
assert(NS.Set("t.n", 33) and NS.Get("t.n") == 35, "rounded to the step")
assert(changed[#changed] == "t.n=35")
assert(not NS.Set("t.n", 500), "out of range refused")
assert(not NS.Set("t.on", "ja"), "a toggle takes booleans")
assert(NS.Set("t.on", false) and NS.Get("t.on") == false, "false is a value, not the default")
assert(NS.Set("t.at", "19:30") and NS.Get("t.at") == 1170)
assert(NS.Set("t.at", "aus") and NS.Get("t.at") == false, "off when allowed")
assert(not NS.Set("t.at", "25:00"))
assert(not NS.Set("t.mode", "c") and NS.Set("t.mode", "b"))
assert(not NS.Set("t.go", true), "buttons hold no value")
assert(not NS.Set("nope.x", 1))
assert(not NS.IsDefault("t.n"))
NS.Reset("t.n")
assert(NS.Get("t.n") == 20 and NS.IsDefault("t.n"))

-- time helpers
assert(NS.ParseTime("8") == 480 and NS.ParseTime("20.15") == 1215 and NS.ParseTime("aus", true) == false and NS.ParseTime("aus") == nil)
assert(NS.FormatTime(1215) == "20:15" and NS.FormatTime(false) == "aus")

-- migration from the flat settings of 1.3 and a stored value that no longer passes
local root = { settings = { enabled = false, lateAt = false, rollSeconds = 30, collect = true,
                            minimap = { hide = true, angle = 90 }, t = { n = 999 } },
               scan = { rate = 50 } }
NS.ApplySettings(root)
local s = root.settings
assert(s.version == 2)
assert(s.record.enabled == false and s.record.lateAt == false and s.rolls.seconds == 30 and s.tools.collect == true)
assert(s.ui.minimap == false and s.minimap.angle == 90 and s.minimap.hide == nil)
assert(s.tools.scanRate == 50)
assert(s.enabled == nil and s.lateAt == nil and s.rollSeconds == nil and s.collect == nil)
assert(s.t.n == nil, "an invalid stored value falls back to the default")
NS.ApplySettings(root)
assert(s.rolls.seconds == 30, "a second run changes nothing")

-- slash commands, help, unknown word
local got
NS.RegisterSlash("testcmd", { aliases = { "tc" }, args = "<x>", desc = "Testbefehl", run = function(rest) got = rest end })
SlashCmdList.AMISIA("testcmd hallo welt"); assert(got == "hallo welt")
SlashCmdList.AMISIA("TC eins"); assert(got == "eins", "aliases, any case")
STUB.messages = {}
SlashCmdList.AMISIA("gibtsnicht")
assert(STUB.messages[1]:find("Unbekannter Befehl", 1, true))
local help = table.concat(NS.SlashHelpLines(true), "\n")
assert(help:find("/amisia testcmd <x> - Testbefehl", 1, true) and help:find("/amisia hilfe", 1, true))

-- a broken message handler reaches the error handler
NS.Listen("BOOM", function() error("kaputt") end)
assert(not pcall(NS.Fire, "BOOM"), "the error is reported")

-- panels and visibility
NS.RegisterPanel{ key = "zz", label = "Z", order = 99, create = function(p) return CreateFrame("Frame", nil, p) end }
NS.RegisterPanel{ key = "aa", label = "A", order = 1, officer = true, create = function(p) return CreateFrame("Frame", nil, p) end }
assert(NS.Panel("aa") and NS.panels[1].order <= NS.panels[#NS.panels].order, "sorted by order")
STUB.officer = true
assert(NS.IsOfficerView() and NS.Visible(NS.Panel("aa")))
STUB.officer = false
assert(not NS.IsOfficerView() and not NS.Visible(NS.Panel("aa")))
NS.Set("ui.view", "officer"); assert(NS.IsOfficerView(), "forced officer view")
NS.Set("ui.view", "raider"); STUB.officer = true; assert(not NS.IsOfficerView(), "forced raider view")
NS.Reset("ui.view")
assert(not NS.Visible({ expert = true }) and NS.Set("ui.expert", true) and NS.Visible({ expert = true }))
assert(not NS.Visible({ available = function() return false end }))
NS.Reset("ui.expert")
```

- [ ] **Step 3: Test laufen lassen, er muss fehlschlagen**

Run: `python addon/tests/run.py registry`
Expected: FAIL mit `registry loaded` (Registry.lua fehlt).

- [ ] **Step 4: Registry.lua schreiben**

`addon/Amisia/Registry.lua`:

```lua
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
-- Page: { key, label, icon, order, bottom, officer, expert, available = fn, create = fn(parent) -> frame,
--         refresh = fn(frame) }. Built the first time it is opened, refreshed only while shown.
function ns.RegisterPanel(spec)
    assert(type(spec.key) == "string" and type(spec.create) == "function", "RegisterPanel needs key and create")
    upsert(ns.panels, spec, "key")
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
    local can = (C_GuildInfo and C_GuildInfo.CanEditOfficerNote) or _G.CanEditOfficerNote
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
        if not n or n < it.min or n > it.max then return false end
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
-- def: { aliases = { ... }, args = "<x>", desc, officer, run = fn(rest, word) }
function ns.RegisterSlash(word, def)
    def.word = word
    upsert(ns.slash, def, "word")
    slashWords[word] = def
    for _, a in ipairs(def.aliases or {}) do slashWords[a] = def end
end

function ns.SlashHelpLines(officer)
    local out = {}
    for _, def in ipairs(ns.slash) do
        if officer or not def.officer then
            out[#out + 1] = ("/amisia %s%s - %s"):format(def.word, def.args and (" " .. def.args) or "", def.desc or "")
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

ns.RegisterSlash("hilfe", { aliases = { "help", "?" }, desc = "alle Befehle", run = function() ns.ShowHelp() end })

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
```

- [ ] **Step 5: TOC: Registry.lua vor Core.lua**

In `addon/Amisia/Amisia.toc` die Zeile `Registry.lua` direkt vor `Core.lua` einfügen.

- [ ] **Step 6: Core.lua: alter Slash-Block bleibt vorerst, aber darf Registry nicht überschreiben**

In `addon/Amisia/Core.lua` die Zuweisungen `SLASH_AMISIA1 = "/amisia"` und `SlashCmdList.AMISIA = function(input)` stehen lassen (Task 3 entfernt sie), aber die Zeile `SlashCmdList.AMISIA = function(input)` in `local function oldSlash(input)` umbenennen und `SLASH_AMISIA1 = "/amisia"` löschen. Am Ende von Registry.lua ist der Dispatcher aktiv; damit die bisherigen Wörter bis Task 3 weiter gehen, am Ende von Core.lua anfügen:

```lua
-- Until every feature registers its own commands, unknown words fall back to the old handler.
for _, w in ipairs({ "award", "unaward", "roll", "rollzeit", "spaet", "late", "rolls", "sr", "scan", "sammeln",
                     "collect", "pause", "status", "export", "gear", "ausruestung", "minimap" }) do
    ns.RegisterSlash(w, { desc = "", run = function(rest, word) oldSlash(word .. (rest ~= "" and (" " .. rest) or "")) end })
end
```

- [ ] **Step 7: Tests laufen lassen**

Run: `python addon/tests/run.py`
Expected: alle `ok`, auch `test_registry.lua`.

- [ ] **Step 8: Entwurf anpassen**

In `docs/superpowers/specs/2026-10-04-amisia-main-window-design.md` den Satz "Die TOC lädt Registry und Widgets direkt nach Core" ersetzen durch "Die TOC lädt Registry vor Core (Core meldet beim Laden schon an), Widgets direkt nach Core".

- [ ] **Step 9: Commit**

```bash
git add addon/Amisia/Registry.lua addon/Amisia/Amisia.toc addon/Amisia/Core.lua addon/tests/wow_stub.lua addon/tests/test_registry.lua docs/superpowers/specs/2026-10-04-amisia-main-window-design.md
git commit -m "Amisia: a registry for pages, settings, commands and messages"
```

---

### Task 2: Namen (Forever-Nachnamen) im Addon und auf der Website

**Files:**
- Create: `addon/Amisia/Names.lua`
- Modify: `addon/Amisia/Amisia.toc` (Names.lua nach Core.lua)
- Modify: `addon/Amisia/Core.lua:259-282` (snapshotRoster), `:416-435` (onLoot-Namen), `:672-740` (sessionLines), `:794-796` (ExportText-Kopf)
- Modify: `addon/Amisia/Awards.lua:16-20` (shortName)
- Modify: `addon/Amisia/Rolls.lua:15-25` (shortName, inGroup)
- Modify: `addon/Amisia/RollFrame.lua:57` (Kandidatenvergleich)
- Modify: `addon/Amisia/SoftRes.lua:8-13, 79-84` (shortName, Zeilen-Parser)
- Modify: `index.html` (`glCleanName`, `amParse`, `amRender` + neue `amLikely`)
- Test: `addon/tests/test_names.lua`, `tools/tests/test_export_format.py`

**Interfaces:**
- Consumes: `ns.RegisterSlash` (Task 1)
- Produces: `ns.IsForever() -> bool`, `ns.FullName(name, surname) -> string|nil`, `ns.UnitFullName(unit)`, `ns.SameName(a, b) -> bool`, `ns.ExportName(name) -> string`; Befehl `namen`. Export-Kopf `#AMISIA 2 <Exporteur>`.

- [ ] **Step 1: Failing test schreiben**

`addon/tests/test_names.lua`:

```lua
-- Names: Forever "First Surname", Anniversary "Name-Realm", the same name compared everywhere,
-- and the export writing "_" for the space.
assert(NS.FullName, "Names.lua loaded")

STUB.toc = 20506
assert(NS.FullName("Fraktur-Thunderstrike") == "Fraktur", "Anniversary drops the realm")
assert(NS.FullName("  Vuloo ") == "Vuloo")
assert(NS.FullName("") == nil and NS.FullName(nil) == nil)
assert(NS.FullName("Vulo", "Thunderstrike") == "Vulo", "the second UnitName value is a realm there")

STUB.toc = 16001
assert(NS.IsForever())
assert(NS.FullName("Vulo", "Sturmwind") == "Vulo Sturmwind", "Forever adds the surname")
assert(NS.FullName("Vulo  Stein-Herz") == "Vulo Stein-Herz", "dashes belong to the surname there")
assert(NS.FullName("Vulo Sturmwind", "Sturmwind") == "Vulo Sturmwind", "no surname twice")
STUB.toc = 20506

assert(NS.SameName("Vulo Sturmwind", "vulo sturmwind"))
assert(NS.SameName("Vulo", "Vulo Sturmwind"), "a side without surname matches on the first name")
assert(not NS.SameName("Vulo Sturmwind", "Vulo Eisenfaust"))
assert(not NS.SameName("Vulo", "Vuloo"))

assert(NS.ExportName("Vulo Sturmwind") == "Vulo_Sturmwind" and NS.ExportName("Fraktur") == "Fraktur")

-- a raid with a surname goes through recording and export
STUB.roster = { { name = "Vulo Sturmwind", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.player = "Vulo Sturmwind"
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(s.members["Vulo Sturmwind"], "recorded under the full name")
local txt = NS.ExportText({ s })
assert(txt:match("^#AMISIA 2 Vulo_Sturmwind\n"), txt:sub(1, 40))
assert(txt:find("\nM Vulo_Sturmwind PRIEST ", 1, true), txt)

-- soft-reserve lines with a surname
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
local byItem, count, bad = NS.ParseSoftRes("vulo sturmwind " .. link .. "\nFraktur 32235")
assert(count == 2 and #bad == 0, table.concat(bad, "|"))
assert(byItem[32235][1] == "Fraktur" and byItem[32235][2] == "Vulo sturmwind", table.concat(byItem[32235], ","))

-- /amisia namen prints what the client gives
STUB.messages = {}
SlashCmdList.AMISIA("namen")
assert(table.concat(STUB.messages, "\n"):find("Vulo Sturmwind", 1, true))
```

- [ ] **Step 2: Test laufen lassen, er muss fehlschlagen**

Run: `python addon/tests/run.py names`
Expected: FAIL `Names.lua loaded`.

- [ ] **Step 3: Names.lua schreiben**

`addon/Amisia/Names.lua`:

```lua
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
```

- [ ] **Step 4: TOC**

In `addon/Amisia/Amisia.toc` nach `Core.lua` die Zeile `Names.lua` einfügen.

- [ ] **Step 5: Core.lua auf Namen umstellen**

In `snapshotRoster` (Core.lua) den Block

```lua
    local me, here = UnitName("player"), nil
    for i = 1, n do
        local name, _, _, _, _, _, zone = GetRaidRosterInfo(i)
        if name == me then
```

ersetzen durch

```lua
    local me, here = ns.UnitFullName("player"), nil
    for i = 1, n do
        local name, _, _, _, _, _, zone = GetRaidRosterInfo(i)
        if ns.SameName(name, me) then
```

und `noteMember(active, name, class, t)` durch `noteMember(active, ns.FullName(name), class, t)`.

In `parseLoot` (Core.lua) `who = UnitName("player")` durch `who = ns.UnitFullName("player")` ersetzen und vor `return who, id, tonumber(count) or 1, link` die Zeile `who = ns.FullName(who)` einfügen; damit bekommen `onLoot` (Material- und Itemzeilen, `noteMember`) und `ns.ParseLoot` den einheitlichen Namen.

In `sessionLines` (Core.lua) die vier Formatzeilen ändern:

```lua
        lines[#lines + 1] = ("M %s %s %d %d"):format(ns.ExportName(name), (m.class and m.class ~= "") and m.class or "UNKNOWN",
            m.first or 0, m.late and 1 or 0)
```
```lua
        lines[#lines + 1] = ("L %s %d %d"):format(ns.ExportName(e.name), e.item, e.count)
```
```lua
        lines[#lines + 1] = ("I %s %d %d"):format(ns.ExportName(e.name), e.item, e.count)
```
```lua
        lines[#lines + 1] = ("A %s %d %d %s %s"):format(ns.ExportName(a.name), a.item, a.t or 0, a.kind or "-", a.src or "?")
```

In `ns.ExportText` die erste Zeile:

```lua
    local lines = { "#AMISIA 2 " .. ns.ExportName(ns.UnitFullName("player") or "?") }
```

- [ ] **Step 6: Awards, Rolls, RollFrame, SoftRes auf Namen umstellen**

`Awards.lua`: `local function shortName(name)` ersetzen durch

```lua
local function shortName(name)
    return ns.FullName(name)
end
```

`Rolls.lua`: `shortName` genauso ersetzen; in `inGroup` `if n and shortName(n) == name then` durch `if n and ns.SameName(n, name) then`.

`RollFrame.lua` in `ns.AwardFromRoll`: `if c and (c == name or c:match("^([^%-]+)") == name) then` durch `if c and ns.SameName(c, name) then`.

`SoftRes.lua`: `shortName` ersetzen durch

```lua
local function shortName(name)
    name = ns.FullName(name)
    if not name then return nil end
    return name:sub(1, 1):upper() .. name:sub(2)
end
```

und im Zeilen-Parser (Zweig ohne CSV-Kopf) die Schleife ersetzen durch

```lua
        for _, line in ipairs(all) do
            -- "Name [Item-Link]" or "Name 32235"; the name may hold a space (Forever surnames)
            local item = ns.ItemID(line)
            local name
            if item then
                name = line:match("^(.-)%s*|c") or line:match("^(.-)%s*|H")
            else
                local n, num = line:match("^(.-)[%s,;:\t]+(%d+)%s*$")
                name, item = n, tonumber(num)
            end
            name = name and name:gsub("[%s,;:\t]+$", "")
            if not add(item, shortName(name)) then bad[#bad + 1] = line end
        end
```

- [ ] **Step 7: Website: Namen mit Leerzeichen und Kopf Version 2**

In `index.html` `glCleanName` ersetzen durch:

```js
function glCleanName(n){ n = String(n||'').trim().replace(/\s+/g, ' '); if (!n.includes(' ')) n = n.split('-')[0].trim(); return n ? n.charAt(0).toUpperCase() + n.slice(1) : ''; }
```

In `amParse` direkt nach `const f = line.split(/\s+/);` einfügen:

```js
      // export version 2 writes a Forever surname with "_" for the space; no WoW name holds an underscore
      const nm = s => glCleanName(String(s || '').replace(/_/g, ' '));
```

und in den Zweigen `M`, `L`, `I`, `A` `glCleanName(f[1])` durch `nm(f[1])` ersetzen. (`amSplit` erkennt Blöcke am `#AMISIA`-Kopf; Version 2 braucht dort keine Änderung, Step 9 prüft das.)

Vor `function amRender(){` einfügen:

```js
// A full Forever name nobody on the roster carries, whose first name exactly one raider has: that
// raider was probably entered without the surname.
function amLikely(name){
  if (!name.includes(' ')) return null;
  const first = name.split(' ')[0].toLowerCase(), hits = state.raiders.filter(r => r.name.toLowerCase() === first);
  return hits.length === 1 ? hits[0].name : null;
}
```

und in `amRender` `esc(s.newNames.slice(0, 6).join(', '))` ersetzen durch
`s.newNames.slice(0, 6).map(n => esc(n) + (amLikely(n) ? ' <span class="faint">(= ' + esc(amLikely(n)) + '?)</span>' : '')).join(', ')`.

- [ ] **Step 8: Export-Test um Nachnamen erweitern**

In `tools/tests/test_export_format.py` in `export_from_addon` nach `{ name = "Fraktur", class = "SHAMAN" },` eine Zeile `{ name = "Vulo Sturmwind", class = "MAGE" },` einfügen; in `test_the_roster_keeps_class_and_delay` die Erwartung auf `assert set(m) == {'Vuloo', 'Fraktur', 'Spaetling', 'Vulo Sturmwind'}` ändern und am Ende der Datei anfügen:

```python
def test_a_surname_survives_the_round_trip(parsed):
    text, out = parsed
    assert '\nM Vulo_Sturmwind MAGE ' in text, 'the export writes the space as an underscore'
    assert text.startswith('#AMISIA 2 ')
    names = {m['name'] for m in out['sessions'][0]['members']}
    assert 'Vulo Sturmwind' in names, names


def test_version_one_exports_still_read():
    text = '\n'.join(['#AMISIA 1 Vuloo', 'S 20260901200000-564 2026-09-01 564 Der Schwarze Tempel',
                      'M Vuloo PRIEST 1 0', 'E', '#END', ''])
    out = read_back(text)
    assert [m['name'] for m in out['sessions'][0]['members']] == ['Vuloo']
```

- [ ] **Step 9: Tests laufen lassen**

Run: `python addon/tests/run.py` und `python -m pytest tools/tests -q`
Expected: alles grün.

- [ ] **Step 10: Commit**

```bash
git add addon/Amisia/Names.lua addon/Amisia/Amisia.toc addon/Amisia/Core.lua addon/Amisia/Awards.lua addon/Amisia/Rolls.lua addon/Amisia/RollFrame.lua addon/Amisia/SoftRes.lua addon/tests/test_names.lua index.html tools/tests/test_export_format.py
git commit -m "Amisia: Forever surnames in recording, rolls, reserves and the export, read by the site"
```

---

### Task 3: Einstellungen und Befehle der Features anmelden

**Files:**
- Modify: `addon/Amisia/Core.lua` (Konstanten -> Einstellungen, ApplySettings, record/bank-Abschnitt, Befehle pause/status/spaet/export, alten Slash-Block und Fallback entfernen, Announce-Kanal)
- Modify: `addon/Amisia/Rolls.lua` (Abschnitt rolls, Befehle roll/rollzeit, Countdown-Schalter)
- Modify: `addon/Amisia/RollFrame.lua` (altClick, Befehl rolls)
- Modify: `addon/Amisia/Awards.lua` (Befehle award/unaward)
- Modify: `addon/Amisia/SoftRes.lua` (Abschnitt softres, Tooltip/Markierung schaltbar, Befehl sr)
- Modify: `addon/Amisia/Collect.lua` (tools.collect, Befehl sammeln)
- Modify: `addon/Amisia/Scan.lua` (tools.scanRate, Befehl scan)
- Modify: `addon/Amisia/GearFrame.lua` (Abschnitt gear, Befehl gear)
- Modify: `addon/Amisia/Minimap.lua` (ui.minimap, Befehl minimap)
- Modify: Tests `addon/tests/test_rolls.lua:65`, `test_collect.lua:81`, `test_minimap.lua:36-39`
- Test: `addon/tests/test_settings_features.lua`

**Interfaces:**
- Consumes: Registry (Task 1), Names (Task 2)
- Produces: Einstellungen `record.enabled|lateAt|keepSessions|resumeHours|nightStart`, `bank.count`, `rolls.seconds|countdown|channel|altClick`, `softres.tooltip|lootMark|warnDays`, `gear.kind|upgradeDot`, `tools.collect|scanRate`; `ns.ShowMinimapButton(on)`; alle Befehle aus der Registry.

- [ ] **Step 1: Failing test schreiben**

`addon/tests/test_settings_features.lua`:

```lua
-- Every feature reads its settings through the registry, and the old commands still work.
local function has(path) return NS.SettingItem(path) ~= nil end
for _, p in ipairs({ "record.enabled", "record.lateAt", "record.keepSessions", "record.resumeHours", "record.nightStart",
                     "bank.count", "rolls.seconds", "rolls.countdown", "rolls.channel", "rolls.altClick",
                     "softres.tooltip", "softres.lootMark", "softres.warnDays", "tools.collect", "tools.scanRate" }) do
    assert(has(p), "registered: " .. p)
end

-- the commands are registered words now, with help text
local help = table.concat(NS.SlashHelpLines(true), "\n")
for _, w in ipairs({ "pause", "status", "spaet", "export", "award", "unaward", "roll", "rollzeit", "rolls", "sr",
                     "scan", "sammeln", "minimap", "namen", "hilfe" }) do
    assert(help:find("/amisia " .. w, 1, true), "help lists " .. w)
end

-- pause through the setting
assert(NS.IsEnabled())
SlashCmdList.AMISIA("pause"); assert(not NS.IsEnabled() and NS.Get("record.enabled") == false)
SlashCmdList.AMISIA("pause"); assert(NS.IsEnabled())

-- late time through the setting
SlashCmdList.AMISIA("spaet 19:45"); assert(NS.Get("record.lateAt") == 19 * 60 + 45 and NS.LateTime() == "19:45")
SlashCmdList.AMISIA("spaet aus"); assert(NS.Get("record.lateAt") == false and NS.LateTime() == nil)
NS.Reset("record.lateAt")

-- roll time through the setting
SlashCmdList.AMISIA("rollzeit 45"); assert(NS.Get("rolls.seconds") == 45)
NS.Reset("rolls.seconds")

-- countdown off: no "10 Sekunden." announcement
STUB.roster = { { name = "Vuloo", class = "PRIEST" } }
NS.Set("rolls.countdown", false)
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
assert(NS.StartRoll(link, 12))
STUB.chat = {}
STUB.tick(3)
for _, c in ipairs(STUB.chat) do assert(not c.text:find("Sekunden.", 1, true), c.text) end
NS.StopRoll()
NS.Reset("rolls.countdown")

-- announce channel: raid instead of raid warning
STUB.leader = true
NS.Set("rolls.channel", "RAID")
STUB.chat = {}
NS.Announce("x")
assert(STUB.chat[1].chan == "RAID")
NS.Reset("rolls.channel")
STUB.chat = {}
NS.Announce("y")
assert(STUB.chat[1].chan == "RAID_WARNING")

-- keep sessions
assert(NS.Get("record.keepSessions") == 60)
```

- [ ] **Step 2: Test laufen lassen, er muss fehlschlagen**

Run: `python addon/tests/run.py settings_features`
Expected: FAIL `registered: record.enabled`.

- [ ] **Step 3: Core.lua umstellen**

Konstanten oben ersetzen:

```lua
local ROSTER_EVERY  = 60           -- seconds between roster snapshots while recording
```

(`REUSE_WINDOW`, `NIGHT_START`, `LATE_DEFAULT`, `KEEP_SESSIONS` entfallen) und direkt danach einfügen:

```lua
-- Seconds after midnight before which a raid counts for the night before (record.nightStart).
local function nightStart()
    return (ns.Get("record.nightStart") or 360) * 60
end
```

Alle Vorkommen von `NIGHT_START` durch `nightStart()` ersetzen (in `lateCutoff` zweimal, in `newSession` einmal). In `newSession` `while #DB.sessions > KEEP_SESSIONS do` durch `while #DB.sessions > (ns.Get("record.keepSessions") or 60) do`. In `findReusable` `<= REUSE_WINDOW` durch `<= (ns.Get("record.resumeHours") or 2) * 3600`.

In `lateCutoff` und `ns.LateTime` `DB and DB.settings and DB.settings.lateAt` durch `ns.Get("record.lateAt")` ersetzen. `ns.SetLateTime` ersetzen durch:

```lua
function ns.SetLateTime(text)
    return (ns.Set("record.lateAt", text)) or nil
end
```

`evaluate`: `if not DB.settings.enabled then` durch `if not ns.Get("record.enabled") then`. `ns.IsEnabled` und `ns.SetEnabled` ersetzen durch:

```lua
function ns.IsEnabled() return DB ~= nil and ns.Get("record.enabled") end

function ns.SetEnabled(on)
    if not DB then return end
    ns.Set("record.enabled", on and true or false)
    msg(on and "Aufnahme aktiv." or "Aufnahme pausiert.")
end
```

`ns.Announce` ersetzen durch:

```lua
-- Chat announcement for the group: raid warning for leader or assistant (unless rolls.channel says
-- raid), else raid, else party.
function ns.Announce(text)
    if not IsInGroup() then return end
    local chan = "PARTY"
    if IsInRaid() then
        local warn = ns.Get("rolls.channel") ~= "RAID" and (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player"))
        chan = warn and "RAID_WARNING" or "RAID"
    end
    -- Forever keeps the global only as a deprecated alias; Anniversary has no C_ChatInfo version.
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    send(text, chan)
end
```

In `bankOpened(frame)` als erste Zeile: `if not ns.Get("bank.count") then return end`.

Im ADDON_LOADED-Zweig die Zeilen

```lua
        if DB.settings.enabled == nil then DB.settings.enabled = true end
        DB.settings.rollSeconds = tonumber(DB.settings.rollSeconds) or 20
        if DB.settings.lateAt == nil then DB.settings.lateAt = LATE_DEFAULT end
        if DB.settings.collect == nil then DB.settings.collect = true end
```

ersetzen durch `ns.ApplySettings(DB)`.

Nach der Definition von `ns.SetLateTime` (dort sind `evaluate` und `refresh` bekannt) einfügen:

```lua
ns.RegisterSettings{ key = "record", label = "Aufnahme", order = 10, items = {
    { key = "record.enabled", type = "toggle", label = "Aufnahme im Raid", default = true,
      tip = "Zeichnet in Raidinstanzen mit Raidgruppe Anwesenheit und Loot auf.",
      onChange = function() evaluate() end },
    { key = "record.lateAt", type = "time", allowOff = true, label = "Raidbeginn (zu spät ab)", default = 20 * 60,
      tip = "Wer danach zum ersten Mal im Raid steht, wird als zu spät vermerkt. \"aus\" schaltet es ab." },
    { key = "record.keepSessions", type = "slider", label = "Raids aufbewahren", default = 60, min = 10, max = 200, step = 10 },
    { key = "record.resumeHours", type = "slider", label = "Fortsetzen innerhalb von (Std.)", default = 2, min = 1, max = 6,
      expert = true, tip = "Wer denselben Raid innerhalb dieser Zeit wieder betritt, setzt die Aufnahme fort." },
    { key = "record.nightStart", type = "time", label = "Raidnacht beginnt um", default = 6 * 60, expert = true,
      tip = "Ein Raid vor dieser Uhrzeit zählt zur Nacht davor." },
}}
ns.RegisterSettings{ key = "bank", label = "Gildenbank", order = 40, officer = true, items = {
    { key = "bank.count", type = "toggle", label = "Beim Öffnen der Gildenbank zählen", default = true,
      tip = "Zählt die Gildenmaterialien in allen sichtbaren Tabs." },
}}
```

Den alten Slash-Block (`local function oldSlash(input)` bis zu seinem `end`) und die Fallback-Schleife aus Task 1 entfernen und am Dateiende einfügen:

```lua
ns.RegisterSlash("pause", { desc = "Aufnahme pausieren oder fortsetzen", run = function() ns.SetEnabled(not ns.IsEnabled()) end })
ns.RegisterSlash("spaet", { aliases = { "late" }, args = "<HH:MM>|aus", desc = "Raidbeginn für die Zu-spät-Markierung",
    run = function(rest)
        if rest == "" then
            local at = ns.LateTime()
            msg(at and ("Raidbeginn %s. Wer danach zum ersten Mal im Raid steht, wird als zu spät vermerkt. /amisia spaet aus schaltet es ab."):format(at)
                or "Verspätungen werden nicht vermerkt. /amisia spaet 20:00 schaltet sie ein.")
        elseif ns.SetLateTime(rest) then
            local at = ns.LateTime()
            msg(at and ("Raidbeginn %s: wer danach zum ersten Mal im Raid steht, ist zu spät."):format(at)
                or "Verspätungen werden nicht mehr vermerkt.")
        else
            msg("Aufruf: /amisia spaet <HH:MM> | aus")
        end
    end })
ns.RegisterSlash("status", { desc = "Stand der Aufnahme und der Gildenbank", run = function()
    if active then
        local c = ns.MatCounts(active)
        local late = ns.LateCount(active)
        msg(("Aufnahme: %s, %d Raider%s, Mal %d, Herz %d, Edelsteine %d."):format(active.zone, ns.MemberCount(active),
            late > 0 and (", " .. late .. " zu spät") or "", c[32897] or 0, c[32428] or 0, ns.GemCount(c)))
    else
        msg(ns.IsEnabled() and "Keine Aufnahme. Sie startet in einer Raidinstanz mit Raidgruppe." or "Aufnahme pausiert. /amisia pause setzt sie fort.")
    end
    local bank = ns.Bank()
    if bank and bank.counts then
        local c = bank.counts
        msg(("Gildenbank vom %s: Mal %d, Herz %d, Edelsteine %d."):format(date("%d.%m. %H:%M", bank.at),
            c[32897] or 0, c[32428] or 0, ns.GemCount(c)))
    else
        msg("Gildenbank noch nicht gezählt. Öffne sie einmal.")
    end
end })
ns.RegisterSlash("export", { officer = true, desc = "den neuesten Raid exportieren", run = function()
    if ns.ShowExport then ns.ShowExport(true) end
end })
```

- [ ] **Step 4: Rolls.lua und RollFrame.lua**

`Rolls.lua`, in `ns.StartRoll`: `seconds = tonumber(seconds) or (AmisiaDB and AmisiaDB.settings and tonumber(AmisiaDB.settings.rollSeconds)) or 20` ersetzen durch `seconds = tonumber(seconds) or ns.Get("rolls.seconds") or 20`; im Ticker `if (left == 10 and seconds > 10) or (left == 5 and seconds > 5) or (left == 3 and seconds > 3) then` ersetzen durch `if ns.Get("rolls.countdown") and ((left == 10 and seconds > 10) or (left == 5 and seconds > 5) or (left == 3 and seconds > 3)) then`. Am Dateiende anfügen:

```lua
ns.RegisterSettings{ key = "rolls", label = "Rolls und Vergabe", order = 20, officer = true, items = {
    { key = "rolls.seconds", type = "slider", label = "Roll-Dauer (Sekunden)", default = 20, min = 5, max = 120, step = 1 },
    { key = "rolls.countdown", type = "toggle", label = "Countdown ansagen", default = true,
      tip = "Sagt bei 10, 5 und 3 Sekunden die Restzeit an." },
    { key = "rolls.channel", type = "choice", label = "Ansagekanal", default = "RAID_WARNING",
      values = { { "RAID_WARNING", "Schlachtzugswarnung" }, { "RAID", "Schlachtzug" } },
      tip = "Schlachtzugswarnung nur als Leiter oder Assistent, sonst Schlachtzug." },
    { key = "rolls.altClick", type = "toggle", label = "Alt-Klick im Lootfenster startet einen Roll", default = true,
      tip = "Ausschalten, wenn ein anderes Loot-Addon Alt-Klick selbst benutzt." },
}}
ns.RegisterSlash("roll", { officer = true, args = "<Item-Link> [Sekunden]", desc = "Roll-Runde starten", run = function(rest)
    local link, secs = rest:match("^(.-)%s*(%d*)$")
    local ok, why = ns.StartRoll(link, tonumber(secs))
    if not ok then ns.msg(why or "Aufruf: /amisia roll <Item-Link> [Sekunden]") elseif ns.ShowRollFrame then ns.ShowRollFrame() end
end })
ns.RegisterSlash("rollzeit", { officer = true, args = "<5-120>", desc = "Standard-Dauer einer Roll-Runde", run = function(rest)
    local ok = ns.Set("rolls.seconds", tonumber(rest))
    ns.msg(ok and ("Roll-Dauer: %d Sekunden."):format(ns.Get("rolls.seconds")) or "Aufruf: /amisia rollzeit <5-120>")
end })
```

`RollFrame.lua`, im `HandleModifiedItemClick`-Hook die Bedingung `if lootOpen and IsAltKeyDown() and id and ns.InLootWindow(id) then` ersetzen durch `if ns.Get("rolls.altClick") and lootOpen and IsAltKeyDown() and id and ns.InLootWindow(id) then`; am Dateiende:

```lua
ns.RegisterSlash("rolls", { officer = true, desc = "Roll-Fenster öffnen oder schließen", run = function() ns.ToggleRollFrame() end })
```

- [ ] **Step 5: Awards.lua**

Am Dateiende anfügen (ersetzt die Weiterleitung aus Core):

```lua
ns.RegisterSlash("award", { officer = true, args = "<Name> <Item-Link|ID> [ms|os|sr]", desc = "Vergabe von Hand eintragen",
    run = function(rest) ns.AwardCommand(rest) end })
ns.RegisterSlash("unaward", { officer = true, desc = "letzte Vergabe zurücknehmen", run = function() ns.AwardCommand("unaward") end })
```

- [ ] **Step 6: SoftRes.lua**

In `addLine` als zweite Zeile `if not ns.Get("softres.tooltip") then return end`; in `markButton(btn, slot)` am Anfang: wenn `not ns.Get("softres.lootMark")`, die vorhandene Markierung verstecken und zurückkehren:

```lua
    if not ns.Get("softres.lootMark") then
        if marks[btn] then marks[btn]:Hide() end
        return
    end
```

Am Dateiende:

```lua
ns.RegisterSettings{ key = "softres", label = "Soft-Reserves", order = 30, items = {
    { key = "softres.tooltip", type = "toggle", label = "Tooltip-Zeile \"Reserviert: ...\"", default = true },
    { key = "softres.lootMark", type = "toggle", label = "SR-Markierung im Lootfenster", default = true,
      onChange = function() ns.MarkLootButtons() end },
    { key = "softres.warnDays", type = "slider", label = "Warnen, wenn die Liste älter ist als (Tage)", default = 7, min = 1, max = 30, step = 1 },
}}
ns.RegisterSlash("sr", { desc = "Soft-Reserves anzeigen", run = function()
    if ns.ShowPage then ns.ShowPage("softres") else ns.ToggleSoftResFrame() end
end })
```

- [ ] **Step 7: Collect.lua und Scan.lua**

`Collect.lua`: `enabled()` ersetzen durch

```lua
local function enabled()
    return AmisiaDB ~= nil and ns.Get("tools.collect") and ns.StoreItem
end
```

und am Dateiende:

```lua
ns.RegisterSlash("sammeln", { aliases = { "collect" }, desc = "Item-Sammler an oder aus", run = function()
    ns.Set("tools.collect", not ns.Get("tools.collect"))
    ns.msg(ns.Get("tools.collect") and "Item-Sammler an: Taschen, Händler, Quests, Auktionshaus, Tooltips und Loot werden aufgenommen."
        or "Item-Sammler aus.")
end })
```

`Scan.lua`: in `scanDB()` die Zeile `s.rate = tonumber(s.rate) or DEFAULT_RATE` ersetzen durch `s.rate = ns.Get("tools.scanRate") or DEFAULT_RATE`; in `ns.ScanCommand` den `rate`-Zweig ersetzen durch

```lua
    elseif word == "rate" then
        if ns.Set("tools.scanRate", tonumber(arg)) then
            scanDB()
            ns.msg(("Scan-Rate: %d Anfragen pro Sekunde."):format(ns.Get("tools.scanRate")))
        else
            ns.msg("Aufruf: /amisia scan rate <10-1000>")
        end
```

und in `ns.ScanRetry` `savedRate = s.rate` / `s.rate = slow` so lassen (die Rate des Retry-Laufs ist vorübergehend), am Dateiende:

```lua
ns.RegisterSettings{ key = "tools", label = "Werkzeuge", order = 95, expert = true, items = {
    { key = "tools.collect", type = "toggle", label = "Item-Sammler", default = true,
      tip = "Merkt sich Items aus Taschen, Händlern, Quests, Auktionshaus, Tooltips und Loot mit ihrer Quelle." },
    { key = "tools.scanRate", type = "slider", label = "Scan-Rate (Anfragen pro Sekunde)", default = 100, min = 10, max = 1000, step = 10 },
}}
ns.RegisterSlash("scan", { args = "[von bis] | gear | retry | stop | status | rate <n>", desc = "Item-Scan", run = function(rest)
    ns.ScanCommand(rest)
end })
```

- [ ] **Step 8: GearFrame.lua und Minimap.lua**

`GearFrame.lua`: in `settings()` die Zeile `g.kind = g.kind or "Speedrun"` löschen; in `opts(col)` `kind = g.kind` durch `kind = ns.Get("gear.kind")`; in `updateControls` `g.kind` durch `ns.Get("gear.kind")`; der Klick auf `kindButton` wird

```lua
    kindButton = chip(F, "", 140, function()
        ns.Set("gear.kind", ns.Get("gear.kind") == "Speedrun" and "Hardcore" or "Speedrun")
        ns.GearRefresh(true)
    end)
```

In `fillOverview` die Bedingung für `b.up:Show()` mit `ns.Get("gear.upgradeDot") and` beginnen lassen. Am Dateiende:

```lua
ns.RegisterSettings{ key = "gear", label = "Ausrüstung", order = 50, available = function() return Gear.Available() end, items = {
    { key = "gear.kind", type = "choice", label = "Gewichtung", default = "Speedrun",
      values = { { "Speedrun", "Speedrun" }, { "Hardcore", "Hardcore" } },
      tip = "Speedrun bewertet Schaden höher, Hardcore Ausdauer und Rüstung." },
    { key = "gear.upgradeDot", type = "toggle", label = "Upgrade-Punkt in der Tabelle", default = true,
      tip = "Grüner Punkt an Items, die besser sind als das, was du trägst." },
}}
ns.RegisterSlash("gear", { aliases = { "ausruestung" }, args = "[item <Link>]", desc = "Ausrüstungstabelle (WoW Forever)",
    run = function(rest)
        local sub, arg = rest:match("^(%S+)%s*(.*)$")
        if sub and sub:lower() == "item" then ns.GearDebug(arg) else ns.ToggleGearFrame() end
    end })
```

`Minimap.lua`: in `build()` `if settings().hide then button:Hide() else button:Show() end` ersetzen durch `ns.ShowMinimapButton(ns.Get("ui.minimap"))`; `ns.ToggleMinimapButton` ersetzen durch

```lua
function ns.ShowMinimapButton(on)
    if not button then build() end
    if not button then return end
    if on then button:Show() else button:Hide() end
end

ns.RegisterSlash("minimap", { desc = "Minimap-Button ein- oder ausblenden", run = function()
    ns.Set("ui.minimap", not ns.Get("ui.minimap"))
    ns.msg(ns.Get("ui.minimap") and "Minimap-Button eingeblendet." or "Minimap-Button ausgeblendet. /amisia minimap holt ihn zurück.")
end })
```

Achtung: `build()` ruft `ns.ShowMinimapButton`, `ns.ShowMinimapButton` ruft `build()` nur, wenn `button` fehlt; `build()` setzt `button` vor dem Aufruf, also keine Schleife. In `build()` die Zeile `if button or not Minimap then return end` bleibt erste Zeile.

- [ ] **Step 9: Bestehende Tests anpassen**

`addon/tests/test_rolls.lua:65`: `AmisiaDB.settings.rollSeconds = 30` -> `NS.Set("rolls.seconds", 30)`.
`addon/tests/test_collect.lua:81`: `AmisiaDB.settings.collect = false` -> `NS.Set("tools.collect", false)`.
`addon/tests/test_minimap.lua:36-39` ersetzen durch:

```lua
SlashCmdList.AMISIA("minimap")
assert(not b:IsShown() and NS.Get("ui.minimap") == false)
SlashCmdList.AMISIA("minimap")
assert(b:IsShown() and NS.Get("ui.minimap") == true)
```

- [ ] **Step 10: Tests laufen lassen**

Run: `python addon/tests/run.py` und `node addon/tests/syntax.cjs`
Expected: alles `ok`.

- [ ] **Step 11: Commit**

```bash
git add addon/Amisia addon/tests
git commit -m "Amisia: every feature registers its settings and commands"
```

---

### Task 4: Widgets

**Files:**
- Create: `addon/Amisia/Widgets.lua`
- Modify: `addon/Amisia/Amisia.toc` (Widgets.lua nach Names.lua)
- Test: `addon/tests/test_widgets.lua`

**Interfaces:**
- Produces: `ns.W` mit `GOLD`, `BG`, `Text(parent, template, width, wrap)`, `Flat(parent, r, g, b, a, layer)`, `Border(frame, r, g, b, a) -> edges`, `SetBorderColor(edges, r, g, b, a)`, `Button(parent, label, width, onClick)`, `Chip(parent, label, width, onClick)` (mit `:SetOn(on)`), `Tooltip(frame, title, text)`, `Toggle(parent, onChange)` (`:SetChecked`, `:GetChecked`), `Stepper(parent, width, onChange)` (`:Configure(min, max, step, fmt)`, `:SetValue(v)`), `TimeBox(parent, width, onCommit)`, `Choice(parent, width, onChange)` (`:SetValues(values)`, `:SetValue(v)`), `EditArea(parent)` (`.box`), `ScrollText(parent)` (`:SetText(t)`), `List(parent, rowCount, rowHeight, build, fill)` (`:SetItems(list)`, `:Redraw()`), `Card(parent, width, height)` (`.title`, `.line1`, `.line2`, `:SetAction(label, fn)`), `Menu(owner, entries)` (entries `{ { label, fn } }`).

- [ ] **Step 1: Failing test schreiben**

`addon/tests/test_widgets.lua`:

```lua
-- Widgets build without errors and keep their state.
local W = NS.W
assert(W, "Widgets.lua loaded")
local root = CreateFrame("Frame", nil, UIParent)

local seen
local t = W.Toggle(root, function(v) seen = v end)
t:SetChecked(true); assert(t:GetChecked())
t:Click(); assert(seen == false and not t:GetChecked())

local st = W.Stepper(root, 120, function(v) seen = v end)
st:Configure(5, 120, 5)
st:SetValue(20)
st.plus:Click(); assert(seen == 25)
STUB.shift = true; st.minus:Click(); assert(seen == 5, "shift steps by ten steps, clamped"); STUB.shift = false
st.minus:Click(); assert(seen == 5, "no change below the minimum")
st.scripts.OnMouseWheel(st, 1); assert(seen == 10)

local c = W.Choice(root, 120, function(v) seen = v end)
c:SetValues({ { "a", "Eins" }, { "b", "Zwei" } })
c:SetValue("a"); assert(c.label:GetText() == "Eins")
c:Click(); assert(seen == "b" and c.label:GetText() == "Zwei")
c:Click(); assert(seen == "a", "cycles")

local committed
local tb = W.TimeBox(root, 60, function(text) committed = text end)
tb:SetText("19:30"); tb.scripts.OnEnterPressed(tb); assert(committed == "19:30")

local filled = {}
local list = W.List(root, 3, 20, function(r) r.text = W.Text(r) end, function(r, item) r.text:SetText(item); filled[#filled + 1] = item end)
list:SetItems({ "a", "b", "c", "d", "e" })
assert(list.rows[1].text:GetText() == "a" and list.rows[3].text:GetText() == "c")
list.scripts.OnMouseWheel(list, -1); assert(list.rows[1].text:GetText() == "b")
list.scripts.OnMouseWheel(list, -5); assert(list.rows[1].text:GetText() == "c", "stops at the end")
list:SetItems({ "x" }); assert(list.rows[1].text:GetText() == "x" and not list.rows[2]:IsShown())

local card = W.Card(root, 296, 112)
local clicked
card:SetAction("Los", function() clicked = true end)
card.button:Click(); assert(clicked)
card:SetAction(nil); assert(not card.button:IsShown())

local area = W.EditArea(root); area.box:SetText("abc"); assert(area.box:GetText() == "abc")
local st2 = W.ScrollText(root); st2:SetText("hallo"); assert(st2.fs:GetText() == "hallo")

local hit
W.Menu(root, { { "Eins", function() hit = 1 end }, { "Zwei", function() hit = 2 end } })
assert(AmisiaMenu:IsShown())
AmisiaMenu.buttons[2]:Click(); assert(hit == 2 and not AmisiaMenu:IsShown(), "a click runs the entry and closes")
```

- [ ] **Step 2: Test laufen lassen, er muss fehlschlagen**

Run: `python addon/tests/run.py widgets`
Expected: FAIL `Widgets.lua loaded`.

- [ ] **Step 3: Widgets.lua schreiben**

`addon/Amisia/Widgets.lua`:

```lua
-- Amisia widgets: the building blocks the pages share, in the Amisia look (dark purple, gold).
-- Every control is built from plain frames and textures, so both clients draw it the same way.
local ADDON, ns = ...

local W = {}
ns.W = W
W.GOLD = { 0.89, 0.72, 0.34 }
W.BG = { 0.055, 0.04, 0.08, 0.96 }
local GOLD = W.GOLD

function W.Text(parent, template, width, wrap)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    if width then fs:SetWidth(width) end
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(wrap and true or false)
    return fs
end

function W.Flat(parent, r, g, b, a, layer)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(r, g, b, a)
    return t
end

function W.Border(frame, r, g, b, a)
    local function edge(p1, p2, w, h)
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(r, g, b, a)
        t:SetPoint(p1)
        t:SetPoint(p2)
        if w then t:SetWidth(w) end
        if h then t:SetHeight(h) end
        return t
    end
    return { edge("TOPLEFT", "TOPRIGHT", nil, 1), edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1),
             edge("TOPLEFT", "BOTTOMLEFT", 1, nil), edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil) }
end

function W.SetBorderColor(edges, r, g, b, a)
    for _, e in ipairs(edges) do e:SetColorTexture(r, g, b, a) end
end

function W.Button(parent, label, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 120, 22)
    b:SetText(label or "")
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

-- A flat toggle chip: gold when on.
function W.Chip(parent, label, width, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 60, 20)
    b.bg = W.Flat(b, 1, 1, 1, 0.06)
    b.edges = W.Border(b, GOLD[1], GOLD[2], GOLD[3], 0.35)
    b.label = W.Text(b, "GameFontHighlightSmall")
    b.label:SetPoint("CENTER")
    b.label:SetJustifyH("CENTER")
    b.label:SetText(label or "")
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)
    function b:SetOn(on)
        self.on = on
        self.bg:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], on and 0.28 or 0.04)
        self.label:SetTextColor(on and 1 or 0.6, on and 0.92 or 0.6, on and 0.7 or 0.6)
        W.SetBorderColor(self.edges, GOLD[1], GOLD[2], GOLD[3], on and 0.8 or 0.25)
    end
    b:SetOn(true)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

function W.Tooltip(frame, title, text)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(title, 1, 0.82, 0)
        if text and text ~= "" then GameTooltip:AddLine(text, 0.85, 0.85, 0.85, true) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- A check box: a gold square when on.
function W.Toggle(parent, onChange)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(18, 18)
    W.Flat(b, 0, 0, 0, 0.5)
    W.Border(b, GOLD[1], GOLD[2], GOLD[3], 0.6)
    b.mark = b:CreateTexture(nil, "ARTWORK")
    b.mark:SetPoint("TOPLEFT", 4, -4)
    b.mark:SetPoint("BOTTOMRIGHT", -4, 4)
    b.mark:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    function b:SetChecked(on)
        self.checked = on and true or false
        if self.checked then self.mark:Show() else self.mark:Hide() end
    end
    function b:GetChecked() return self.checked end
    b:SetScript("OnClick", function(self)
        self:SetChecked(not self.checked)
        if onChange then onChange(self.checked) end
    end)
    b:SetChecked(false)
    return b
end

-- A number with minus and plus; shift steps ten times as far, the mouse wheel steps too.
function W.Stepper(parent, width, onChange)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width or 120, 20)
    f.min, f.max, f.step = 0, 100, 1
    f.minus = W.Chip(f, "-", 22)
    f.minus:SetPoint("LEFT")
    f.plus = W.Chip(f, "+", 22)
    f.plus:SetPoint("RIGHT")
    f.value = W.Text(f, "GameFontHighlightSmall")
    f.value:SetPoint("CENTER")
    f.value:SetJustifyH("CENTER")
    function f:Configure(min, max, step, fmt)
        self.min, self.max, self.step, self.fmt = min, max, step or 1, fmt
    end
    function f:SetValue(v)
        self.current = v
        self.value:SetText(self.fmt and self.fmt(v) or tostring(v))
    end
    local function bump(dir)
        local mult = (IsShiftKeyDown and IsShiftKeyDown()) and 10 or 1
        local v = math.max(f.min, math.min(f.max, (f.current or f.min) + dir * f.step * mult))
        if v ~= f.current then
            f:SetValue(v)
            if onChange then onChange(v) end
        end
    end
    f.minus:SetScript("OnClick", function() bump(-1) end)
    f.plus:SetScript("OnClick", function() bump(1) end)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta) bump(delta > 0 and 1 or -1) end)
    return f
end

-- A one-line edit box; Enter or leaving the box hands the text to onCommit.
function W.TimeBox(parent, width, onCommit)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetSize(width or 60, 20)
    e:SetAutoFocus(false)
    e:SetFontObject(ChatFontNormal)
    e:SetJustifyH("CENTER")
    e:SetTextInsets(4, 4, 0, 0)
    W.Flat(e, 0, 0, 0, 0.5)
    W.Border(e, 1, 1, 1, 0.2)
    local function commit(self)
        if self.committing then return end
        self.committing = true
        if onCommit then onCommit(self:GetText()) end
        self.committing = false
    end
    e:SetScript("OnEnterPressed", function(self) commit(self); self:ClearFocus() end)
    e:SetScript("OnEditFocusLost", commit)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return e
end

-- A chip that cycles through its values on click.
function W.Choice(parent, width, onChange)
    local c = W.Chip(parent, "", width or 120)
    function c:SetValues(values) self.values = values end
    function c:SetValue(v)
        self.current = v
        for _, x in ipairs(self.values or {}) do
            if x[1] == v then self.label:SetText(x[2]) end
        end
    end
    c:SetScript("OnClick", function(self)
        local vals, idx = self.values or {}, 0
        for i, x in ipairs(vals) do
            if x[1] == self.current then idx = i end
        end
        local nextValue = vals[idx % math.max(1, #vals) + 1]
        if nextValue then
            self:SetValue(nextValue[1])
            if onChange then onChange(nextValue[1]) end
        end
    end)
    return c
end

-- A multi-line edit box in a scroll frame, on a dark field.
function W.EditArea(parent)
    local bg = CreateFrame("Frame", nil, parent)
    W.Flat(bg, 0, 0, 0, 0.45)
    W.Border(bg, 1, 1, 1, 0.12)
    local sf = CreateFrame("ScrollFrame", nil, bg, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 6, -6)
    sf:SetPoint("BOTTOMRIGHT", -28, 6)
    local box = CreateFrame("EditBox", nil, sf)
    box:SetMultiLine(true)
    box:SetMaxLetters(0)
    box:SetAutoFocus(false)
    box:SetFontObject(ChatFontNormal)
    box:SetWidth(500)
    box:SetHeight(200)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    sf:SetScrollChild(box)
    bg:EnableMouse(true)
    bg:SetScript("OnMouseDown", function() box:SetFocus() end)
    bg:SetScript("OnSizeChanged", function(_, w) box:SetWidth(math.max(100, (w or 500) - 40)) end)
    bg.box, bg.scroll = box, sf
    return bg
end

-- Wrapped read-only text that scrolls.
function W.ScrollText(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(10, 10)
    sf:SetScrollChild(child)
    local fs = W.Text(child, "GameFontHighlightSmall", nil, true)
    fs:SetPoint("TOPLEFT")
    fs:SetJustifyV("TOP")
    function sf:SetText(t)
        local w = math.max(100, (self:GetWidth() or 400) - 24)
        fs:SetWidth(w)
        child:SetWidth(w)
        fs:SetText(t or "")
        child:SetHeight((fs:GetStringHeight() or 14) + 8)
    end
    sf.fs = fs
    return sf
end

-- A list with a fixed number of visible rows; the mouse wheel scrolls. build(row, i) makes a row's
-- parts once, fill(row, item, index) shows an item in it.
function W.List(parent, rowCount, rowHeight, build, fill)
    local f = CreateFrame("Frame", nil, parent)
    f.rows, f.items, f.offset = {}, {}, 0
    f:SetHeight(rowCount * rowHeight)
    for i = 1, rowCount do
        local r = CreateFrame("Button", nil, f)
        r:SetHeight(rowHeight - 1)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
        r:SetPoint("TOPRIGHT", 0, -(i - 1) * rowHeight)
        W.Flat(r, 1, 1, 1, (i % 2 == 0) and 0.03 or 0.06)
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        build(r, i)
        f.rows[i] = r
    end
    function f:Redraw()
        for i, r in ipairs(self.rows) do
            local item = self.items[i + self.offset]
            r.item = item
            if item ~= nil then
                fill(r, item, i + self.offset)
                r:Show()
            else
                r:Hide()
            end
        end
    end
    function f:SetItems(list)
        self.items = list or {}
        self.offset = math.max(0, math.min(self.offset, #self.items - rowCount))
        self:Redraw()
    end
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(self, delta)
        self.offset = math.max(0, math.min(math.max(0, #self.items - rowCount), self.offset - delta))
        self:Redraw()
    end)
    return f
end

-- An overview card: title, two lines and at most one button.
function W.Card(parent, width, height)
    local c = CreateFrame("Frame", nil, parent)
    c:SetSize(width, height)
    W.Flat(c, 1, 1, 1, 0.04)
    W.Border(c, GOLD[1], GOLD[2], GOLD[3], 0.3)
    c.title = W.Text(c, "GameFontNormal", width - 20)
    c.title:SetPoint("TOPLEFT", 10, -8)
    c.line1 = W.Text(c, "GameFontHighlight", width - 20)
    c.line1:SetPoint("TOPLEFT", 10, -28)
    c.line2 = W.Text(c, "GameFontDisableSmall", width - 20, true)
    c.line2:SetPoint("TOPLEFT", 10, -48)
    c.button = W.Button(c, "", 110)
    c.button:SetPoint("BOTTOMLEFT", 10, 8)
    function c:SetAction(label, fn)
        if label then
            self.button:SetText(label)
            self.button:SetScript("OnClick", fn)
            self.button:Show()
        else
            self.button:Hide()
        end
    end
    return c
end

-- A small popup menu under owner; a click runs the entry and closes it. Leaving it for two seconds
-- or Escape closes it too.
local menu
function W.Menu(owner, entries)
    if not menu then
        menu = CreateFrame("Frame", "AmisiaMenu", UIParent)
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetClampedToScreen(true)
        menu:EnableMouse(true)
        W.Flat(menu, W.BG[1], W.BG[2], W.BG[3], W.BG[4])
        W.Border(menu, GOLD[1], GOLD[2], GOLD[3], 0.6)
        menu.buttons = {}
        if UISpecialFrames then tinsert(UISpecialFrames, "AmisiaMenu") end
        menu:SetScript("OnUpdate", function(self, elapsed)
            if MouseIsOver and (MouseIsOver(self) or (self.owner and MouseIsOver(self.owner))) then
                self.away = 0
            else
                self.away = (self.away or 0) + (elapsed or 0)
                if self.away > 2 then self:Hide() end
            end
        end)
    end
    menu.owner = owner
    menu.away = 0
    for i, e in ipairs(entries) do
        local b = menu.buttons[i]
        if not b then
            b = CreateFrame("Button", nil, menu)
            b:SetSize(170, 20)
            b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 20)
            b.label = W.Text(b, "GameFontHighlightSmall", 160)
            b.label:SetPoint("LEFT", 6, 0)
            local hl = b:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.25)
            menu.buttons[i] = b
        end
        b.label:SetText(e[1])
        b:SetScript("OnClick", function()
            menu:Hide()
            e[2]()
        end)
        b:Show()
    end
    for i = #entries + 1, #menu.buttons do menu.buttons[i]:Hide() end
    menu:SetSize(182, 12 + #entries * 20)
    menu:ClearAllPoints()
    menu:SetPoint("TOPRIGHT", owner, "BOTTOMLEFT", 0, 0)
    menu:Show()
    return menu
end
```

- [ ] **Step 4: TOC**

`Widgets.lua` nach `Names.lua` in `addon/Amisia/Amisia.toc`.

- [ ] **Step 5: Tests laufen lassen**

Run: `python addon/tests/run.py` und `node addon/tests/syntax.cjs`
Expected: alles `ok`.

- [ ] **Step 6: Commit**

```bash
git add addon/Amisia/Widgets.lua addon/Amisia/Amisia.toc addon/tests/test_widgets.lua
git commit -m "Amisia: shared widgets for the new window"
```

---

### Task 5: Hauptfenster mit Seitenleiste

**Files:**
- Create: `addon/Amisia/MainFrame.lua`
- Modify: `addon/Amisia/Amisia.toc` (MainFrame.lua nach GearFrame.lua; UI.lua bleibt bis Task 6)
- Modify: `addon/tests/run.py` (Backslash in TOC-Pfaden)
- Test: `addon/tests/test_mainframe.lua`

**Interfaces:**
- Consumes: `ns.panels`, `ns.Panel`, `ns.Visible`, `ns.Listen`, `ns.Get`, `ns.W`
- Produces: `ns.ShowPage(key)`, `ns.ToggleMain()`, `ns.Refresh()`, `ns.CurrentPage() -> key`, `ns.ApplyScale(v)`, `ns.ResetPositions()`, `ns.Toggle(exportLatest)`. Frame `AmisiaFrame`.

- [ ] **Step 1: run.py für Unterordner**

In `addon/tests/run.py` in `toc_files()` die Zeile
`out.append(re.sub(r'\s*\[[^\]]*\]', '', line))` ersetzen durch
`out.append(re.sub(r'\s*\[[^\]]*\]', '', line).replace('\\', os.sep))`.

- [ ] **Step 2: Failing test schreiben**

`addon/tests/test_mainframe.lua`:

```lua
-- The main window: pages from the registry, built once, refreshed while shown, officer pages gated,
-- a broken page does not break the window.
local built, refreshed = 0, 0
NS.RegisterPanel{ key = "tp1", label = "Testseite", order = 5,
    create = function(p) built = built + 1; return CreateFrame("Frame", nil, p) end,
    refresh = function() refreshed = refreshed + 1 end }
NS.RegisterPanel{ key = "tpoff", label = "Offizier", order = 6, officer = true, create = function(p) return CreateFrame("Frame", nil, p) end }
NS.RegisterPanel{ key = "tpbad", label = "Kaputt", order = 7, create = function() error("kaputt") end }

NS.ShowPage("tp1")
assert(AmisiaFrame and AmisiaFrame:IsShown() and NS.CurrentPage() == "tp1")
assert(built == 1 and refreshed >= 1)
NS.ShowPage("tp1"); assert(built == 1, "built once")
local r = refreshed
NS.Refresh(); assert(refreshed == r + 1, "refreshed while shown")
AmisiaFrame:Hide(); NS.Refresh(); assert(refreshed == r + 1, "not while hidden")

-- officer page falls back for a raider
STUB.officer = false
NS.ShowPage("tpoff")
assert(NS.CurrentPage() ~= "tpoff", "raider view does not open officer pages")
STUB.officer = true
NS.ShowPage("tpoff"); assert(NS.CurrentPage() == "tpoff")

-- a page that fails to build shows an error page and the window lives on
NS.ShowPage("tpbad"); assert(NS.CurrentPage() == "tpbad" and AmisiaFrame:IsShown())
NS.ShowPage("tp1"); assert(NS.CurrentPage() == "tp1")

-- toggle, scale, position reset
NS.ToggleMain(); assert(not AmisiaFrame:IsShown())
NS.ToggleMain(); assert(AmisiaFrame:IsShown())
NS.Set("ui.scale", 80); assert(math.abs(AmisiaFrame:GetScale() - 0.8) < 1e-6)
NS.Reset("ui.scale")
AmisiaDB.settings.window = { point = "TOPLEFT", x = 10, y = -10 }
NS.ResetPositions(); assert(AmisiaDB.settings.window.point == nil)
SlashCmdList.AMISIA(""); assert(not AmisiaFrame:IsShown(), "/amisia alone toggles the window")
```

- [ ] **Step 3: Test laufen lassen, er muss fehlschlagen**

Run: `python addon/tests/run.py mainframe`
Expected: FAIL (`attempt to call field 'ShowPage'`).

- [ ] **Step 4: MainFrame.lua schreiben**

`addon/Amisia/MainFrame.lua`:

```lua
-- Amisia main window: a header with the recording state, a sidebar of the registered pages and
-- the page itself. Pages are built the first time they are opened and refreshed only while shown.
local ADDON, ns = ...

local W = ns.W
local GOLD = W.GOLD
local WIDTH, HEIGHT, SIDE, NAV_MAX = 800, 540, 160, 14
local DOT = "|TInterface\\AddOns\\Amisia\\Media\\Icons\\dot:10:10:0:0|t "

local F, nav, content, statusText, pauseBtn
local built, current = {}, nil
local navButtons = {}

local function windowState()
    AmisiaDB.settings.window = AmisiaDB.settings.window or {}
    return AmisiaDB.settings.window
end

local function savePosition()
    local point, _, rel, x, y = F:GetPoint()
    local w = windowState()
    w.point, w.rel, w.x, w.y = point, rel, x, y
end

local function restorePosition()
    local w = windowState()
    F:ClearAllPoints()
    if w.point then
        F:SetPoint(w.point, UIParent, w.rel or w.point, w.x or 0, w.y or 0)
    else
        F:SetPoint("CENTER")
    end
end

function ns.ApplyScale(v)
    if F then F:SetScale((v or ns.Get("ui.scale") or 100) / 100) end
end

function ns.ResetPositions()
    windowState().point = nil
    if F then restorePosition() end
    if ns.ResetGearPosition then ns.ResetGearPosition() end
    ns.msg("Fensterposition zurückgesetzt.")
end

local function reportError(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

local function errorPage(parent, err)
    local f = CreateFrame("Frame", nil, parent)
    local t = W.Text(f, "GameFontNormal", 560, true)
    t:SetPoint("TOPLEFT", 10, -10)
    t:SetText("Diese Seite konnte nicht geladen werden.\n|cff8f86a3" .. (tostring(err):match("^[^\n]*") or "?") .. "|r")
    return f
end

local function updateHeader()
    local act = ns.Active and ns.Active()
    if act then
        local late = ns.LateCount(act)
        statusText:SetText(("%s|cff4fbf7a%s|r · %d Raider%s"):format(DOT, act.zone or "?", ns.MemberCount(act),
            late > 0 and (" · |cffe0a344" .. late .. " zu spät|r") or ""))
    elseif ns.IsEnabled() then
        statusText:SetText("|cff8f86a3Keine Aufnahme, startet im Raid|r")
    else
        statusText:SetText("|cffe0a344Aufnahme pausiert|r")
    end
    pauseBtn:SetText(ns.IsEnabled() and "Pausieren" or "Fortsetzen")
end

local function updateNav()
    local top, bottom = {}, {}
    for _, p in ipairs(ns.panels) do
        if ns.Visible(p) then
            if p.bottom then bottom[#bottom + 1] = p else top[#top + 1] = p end
        end
    end
    local used = 0
    local function place(p, anchor, y)
        used = used + 1
        local b = navButtons[used]
        if not b then return end
        b.key = p.key
        b.icon:SetTexture(p.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        b.label:SetText(p.label)
        b:ClearAllPoints()
        b:SetPoint(anchor, nav, anchor, 0, y)
        if p.key == current then b.sel:Show() else b.sel:Hide() end
        b:Show()
    end
    for i, p in ipairs(top) do place(p, "TOPLEFT", -(i - 1) * 30) end
    for i, p in ipairs(bottom) do place(p, "BOTTOMLEFT", (#bottom - i) * 30) end
    for i = used + 1, NAV_MAX do navButtons[i]:Hide() end
end

local function build()
    F = CreateFrame("Frame", "AmisiaFrame", UIParent)
    F:SetSize(WIDTH, HEIGHT)
    F:SetFrameStrata("FULLSCREEN")
    F:SetToplevel(true)
    F:SetClampedToScreen(true)
    F:SetMovable(true)
    F:EnableMouse(true)
    F:RegisterForDrag("LeftButton")
    F:SetScript("OnDragStart", function(self) self:StartMoving() end)
    F:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); savePosition() end)
    F:SetScript("OnShow", function(self)
        if self.Raise then self:Raise() end
        ns.Refresh()
    end)
    F:Hide()
    if UISpecialFrames then tinsert(UISpecialFrames, "AmisiaFrame") end
    W.Flat(F, W.BG[1], W.BG[2], W.BG[3], W.BG[4])
    W.Border(F, GOLD[1], GOLD[2], GOLD[3], 0.6)
    restorePosition()
    ns.ApplyScale()

    local logo = F:CreateTexture(nil, "ARTWORK")
    logo:SetSize(30, 30)
    logo:SetPoint("TOPLEFT", 12, -7)
    logo:SetTexture("Interface\\AddOns\\Amisia\\Media\\Icons\\Amisia")
    local title = W.Text(F, "GameFontNormalLarge", 220)
    title:SetPoint("LEFT", logo, "RIGHT", 6, 0)
    title:SetText("Amisia |cff8f86a3" .. (ns.VERSION or "") .. "|r")
    title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    local close = CreateFrame("Button", nil, F, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)
    pauseBtn = W.Button(F, "Pausieren", 100, function() ns.SetEnabled(not ns.IsEnabled()) end)
    pauseBtn:SetPoint("TOPRIGHT", -34, -12)
    statusText = W.Text(F, "GameFontHighlightSmall", 320)
    statusText:SetPoint("RIGHT", pauseBtn, "LEFT", -10, 0)
    statusText:SetJustifyH("RIGHT")
    local line = F:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.3)
    line:SetPoint("TOPLEFT", 10, -44)
    line:SetPoint("TOPRIGHT", -10, -44)
    line:SetHeight(1)

    nav = CreateFrame("Frame", nil, F)
    nav:SetPoint("TOPLEFT", 10, -52)
    nav:SetPoint("BOTTOMLEFT", 10, 10)
    nav:SetWidth(SIDE)
    for i = 1, NAV_MAX do
        local b = CreateFrame("Button", nil, nav)
        b:SetSize(SIDE, 28)
        b.sel = W.Flat(b, GOLD[1], GOLD[2], GOLD[3], 0.25, "BORDER")
        b.sel:Hide()
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(20, 20)
        b.icon:SetPoint("LEFT", 6, 0)
        b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b.label = W.Text(b, "GameFontNormal", SIDE - 36)
        b.label:SetPoint("LEFT", 32, 0)
        b:SetScript("OnClick", function(self) ns.ShowPage(self.key) end)
        b:Hide()
        navButtons[i] = b
    end
    local sep = F:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.2)
    sep:SetPoint("TOPLEFT", SIDE + 16, -52)
    sep:SetPoint("BOTTOMLEFT", SIDE + 16, 10)
    sep:SetWidth(1)

    content = CreateFrame("Frame", nil, F)
    content:SetPoint("TOPLEFT", SIDE + 26, -52)
    content:SetPoint("BOTTOMRIGHT", -12, 10)
end

function ns.CurrentPage() return current end

function ns.ShowPage(key)
    if not F then build() end
    local p = ns.Panel(key)
    if not ns.Visible(p) then p = ns.Panel("overview") end
    if not ns.Visible(p) then
        for _, other in ipairs(ns.panels) do
            if ns.Visible(other) then p = other break end
        end
    end
    if not p then return end
    current = p.key
    for k, frame in pairs(built) do
        if k ~= current then frame:Hide() end
    end
    if not built[current] then
        local ok, frame = pcall(p.create, content)
        if not ok or type(frame) ~= "table" then
            -- not passed to the error handler: the error page shows it and the window stays usable
            frame = errorPage(content, ok and "create gab keinen Frame zurück" or frame)
        end
        frame:SetAllPoints(content)
        built[current] = frame
    end
    built[current]:Show()
    if F:IsShown() then ns.Refresh() else F:Show() end
end

function ns.Refresh()
    if not F or not F:IsShown() then return end
    local p = ns.Panel(current)
    if not ns.Visible(p) then
        ns.ShowPage("overview")
        return
    end
    updateHeader()
    updateNav()
    local frame = built[current]
    if p.refresh and frame then
        local ok, err = pcall(p.refresh, frame)
        if not ok then reportError(err) end
    end
end

function ns.ToggleMain()
    if F and F:IsShown() then F:Hide() else ns.ShowPage(current or "overview") end
end

-- The old entry point: /amisia export and the minimap called it with the newest session.
function ns.Toggle(exportLatest)
    if exportLatest and ns.ShowExport then ns.ShowExport(true) else ns.ToggleMain() end
end

ns.Listen("SETTING", function() ns.Refresh() end)
ns.Listen("DATA_CHANGED", function() ns.Refresh() end)

ns.RegisterSlash("einstellungen", { aliases = { "optionen", "config" }, desc = "Einstellungen öffnen",
    run = function() ns.ShowPage("settings") end })
```

- [ ] **Step 5: TOC**

`MainFrame.lua` nach `GearFrame.lua` in die TOC; `UI.lua` steht noch dahinter (Task 6 entfernt es). Weil `UI.lua` `ns.Refresh`/`ns.Toggle` überschreibt, in Task 5 die TOC-Reihenfolge `UI.lua` **vor** `MainFrame.lua` setzen.

- [ ] **Step 6: Tests laufen lassen**

Run: `python addon/tests/run.py` und `node addon/tests/syntax.cjs`
Expected: alles `ok`.

- [ ] **Step 7: Commit**

```bash
git add addon/Amisia/MainFrame.lua addon/Amisia/Amisia.toc addon/tests/run.py addon/tests/test_mainframe.lua
git commit -m "Amisia: the main window with a sidebar of registered pages"
```

---

### Task 6: Seiten (Übersicht, Raids, Export, Rolls, Soft-Reserves, Ausrüstung, Gildenbank, Werkzeuge, Einstellungen, Über)

**Files:**
- Create: `addon/Amisia/Pages/Overview.lua`, `Raids.lua`, `Export.lua`, `Rolls.lua`, `SoftRes.lua`, `Gear.lua`, `Bank.lua`, `Tools.lua`, `Settings.lua`, `About.lua`
- Delete: `addon/Amisia/UI.lua`
- Modify: `addon/Amisia/Amisia.toc` (Pages, UI.lua raus)
- Modify: `addon/Amisia/Rolls.lua` (Verlauf `ns.RollHistory()`)
- Modify: `addon/Amisia/GearFrame.lua` (`ns.GearMyUpgrades()`, `ns.ResetGearPosition()`)
- Test: `addon/tests/test_pages.lua`; `addon/tests/test_export.lua` bleibt unverändert grün

**Interfaces:**
- Consumes: alles aus Task 1-5
- Produces: Panels `overview`, `raids`, `export`, `rolls`, `softres`, `gear`, `bank`, `tools`, `settings`, `about`; Karten `raid`, `softres`, `gear`, `awards`, `bank`, `export`; `ns.ShowExport(latestOnly)` (gleiches Verhalten wie bisher), `ns.RaidSelection` (Tabelle id -> true), `ns.RollHistory() -> rounds`, `ns.GearMyUpgrades() -> list, result, opts`.

- [ ] **Step 1: Failing test schreiben**

`addon/tests/test_pages.lua`:

```lua
-- Every page builds and refreshes; officer pages hide for raiders; the settings page writes settings.
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
_G.UnitClass = function() return "Priester", "PRIEST" end
_G.UnitLevel = function() return 24 end
_G.UnitFactionGroup = function() return "Alliance" end
_G.GetInventoryItemLink = function() return nil end

for _, key in ipairs({ "overview", "raids", "export", "rolls", "softres", "bank", "settings", "about" }) do
    NS.ShowPage(key)
    assert(NS.CurrentPage() == key, "opens " .. key)
end
-- gear only where the gear data is (the tests load it)
NS.ShowPage("gear"); assert(NS.CurrentPage() == "gear")
-- tools only in expert mode
NS.ShowPage("tools"); assert(NS.CurrentPage() ~= "tools")
NS.Set("ui.expert", true); NS.ShowPage("tools"); assert(NS.CurrentPage() == "tools")
NS.Reset("ui.expert")

-- raider view: officer pages and cards stay hidden
NS.Set("ui.view", "raider")
NS.ShowPage("raids"); assert(NS.CurrentPage() == "overview")
NS.ShowPage("export"); assert(NS.CurrentPage() == "overview")
NS.Reset("ui.view")

-- the overview shows cards
NS.ShowPage("overview")
local panelFrame = AmisiaFrame and true
assert(panelFrame)

-- export page keeps the old behaviour
local function lastMsg() return STUB.messages[#STUB.messages] or "" end
NS.ShowExport(false)
assert(lastMsg():find("Export: 1 neue oder geänderte Raid", 1, true), lastMsg())
assert(NS.CurrentPage() == "export")

-- raids page: selection drives "Ausgewählte" export
local s = NS.Active()
NS.RaidSelection[s.id] = true
NS.ShowExport(false)
assert(lastMsg():find("Nichts Neues", 1, true) == nil, "a selected session exports again")
NS.RaidSelection[s.id] = nil

-- settings page: toggling a row writes the setting
NS.ShowPage("settings")
local rows = NS.SettingsRows()
assert(rows["record.enabled"] and rows["record.enabled"].control:GetChecked() == true)
rows["record.enabled"].control:Click()
assert(NS.Get("record.enabled") == false)
NS.Reset("record.enabled")
NS.Refresh()
assert(rows["record.enabled"].control:GetChecked() == true)

-- roll history feeds the rolls page
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
assert(NS.StartRoll(link, 5)); NS.StopRoll()
assert(#NS.RollHistory() >= 1)
NS.ShowPage("rolls")
```

- [ ] **Step 2: Test laufen lassen, er muss fehlschlagen**

Run: `python addon/tests/run.py pages`
Expected: FAIL (`opens overview`).

- [ ] **Step 3: Rolls-Verlauf und Gear-Helfer**

`addon/Amisia/Rolls.lua`: unter `local current, last, ticker` einfügen `local history = {}   -- finished rounds, newest first (this session only)` und in `finish()` direkt nach `last = current`:

```lua
    table.insert(history, 1, current)
    while #history > 10 do table.remove(history) end
```

sowie nach `function ns.LastRoll() return last end`:

```lua
function ns.RollHistory() return history end
```

`addon/Amisia/GearFrame.lua`: vor `function ns.ToggleGearFrame()` einfügen:

```lua
-- The upgrades the player can get at their own level, against what they wear, best first.
function ns.GearMyUpgrades()
    if not Gear.Available() then return {}, nil, nil end
    local g = settings()
    local _, myClass = UnitClass("player")
    local o = {
        class = myClass, spec = g.specs[myClass] or (Gear.Specs(myClass)[1] or {}).key, kind = ns.Get("gear.kind"),
        faction = g.faction ~= "both" and g.faction or nil, sources = g.sources, level = UnitLevel("player") or 1,
    }
    local res = Gear.Best(o)
    local out = {}
    for _, slot in ipairs(Gear.SLOTS) do
        local e = res[slot.key] and res[slot.key][1]
        if e then
            local link = GetInventoryItemLink and GetInventoryItemLink("player", slot.inv)
            local mine = link and Gear.ScoreLink(link, slot.key, o) or 0
            if (not link or ns.ItemID(link) ~= e[1]) and e[2] - mine > math.max(1, math.abs(mine) * 0.02) then
                out[#out + 1] = { slot = slot, id = e[1], score = e[2], gain = e[2] - mine, mine = mine }
            end
        end
    end
    table.sort(out, function(a, b) return a.gain > b.gain end)
    return out, res, o
end

function ns.ResetGearPosition()
    if F then F:ClearAllPoints(); F:SetPoint("CENTER") end
end
```

- [ ] **Step 4: Pages/Overview.lua**

```lua
-- Overview: one card per registered feature, each with its state and at most one button.
local ADDON, ns = ...
local W = ns.W
local CARD_W, CARD_H, GAP, SLOTS = 296, 112, 12, 6

ns.RegisterPanel{ key = "overview", label = "Übersicht", icon = "Interface\\Icons\\INV_Misc_Book_09", order = 10,
    create = function(parent)
        local f = CreateFrame("Frame", nil, parent)
        f.cards = {}
        for i = 1, SLOTS do
            local c = W.Card(f, CARD_W, CARD_H)
            c:SetPoint("TOPLEFT", ((i - 1) % 2) * (CARD_W + GAP), -math.floor((i - 1) / 2) * (CARD_H + GAP))
            c:Hide()
            f.cards[i] = c
        end
        f.empty = W.Text(f, "GameFontDisable", 500)
        f.empty:SetPoint("TOPLEFT", 4, -4)
        return f
    end,
    refresh = function(f)
        local n = 0
        for _, spec in ipairs(ns.cards) do
            if n < SLOTS and ns.Visible(spec) then
                n = n + 1
                local c = f.cards[n]
                c.title:SetText("")
                c.line1:SetText("")
                c.line2:SetText("")
                c:SetAction(nil)
                local ok, err = pcall(spec.fill, c)
                if not ok then
                    c.title:SetText(spec.key)
                    c.line1:SetText("Fehler")
                    c.line2:SetText(tostring(err):match("^[^\n]*"))
                end
                c:Show()
            end
        end
        for i = n + 1, SLOTS do f.cards[i]:Hide() end
        f.empty:SetText(n == 0 and "Noch nichts zu zeigen." or "")
    end }
```

- [ ] **Step 5: Pages/Raids.lua**

```lua
-- Raids: the recorded sessions, a selection for the export, and the details of one session.
local ADDON, ns = ...
local W = ns.W
local ROWS, ROW_H = 8, 22

ns.RaidSelection = ns.RaidSelection or {}
local detailId
local page

local function ordered()
    local src, out = ns.Sessions(), {}
    for i = #src, 1, -1 do out[#out + 1] = src[i] end
    return out
end

local function detailText(s)
    local names = {}
    for name, m in pairs(s.members or {}) do names[#names + 1] = { name = name, m = m } end
    table.sort(names, function(a, b) return a.name < b.name end)
    local people = {}
    for _, e in ipairs(names) do
        people[#people + 1] = e.m.late and ("|cffe0a344%s (%s)|r"):format(e.name, date("%H:%M", e.m.first or 0)) or e.name
    end
    local loot = {}
    for _, l in ipairs(s.items or {}) do
        loot[#loot + 1] = ("%s: %s%s"):format(l.name, ns.ItemName(l.item), (l.count or 1) > 1 and (" x" .. l.count) or "")
    end
    local drops = {}
    for _, d in pairs(s.drops or {}) do
        for id, c in pairs(d.items or {}) do
            drops[#drops + 1] = ("%s (%s)%s"):format(ns.ItemName(id), d.src or "?", c > 1 and (" x" .. c) or "")
        end
    end
    table.sort(drops)
    local awards = {}
    for _, a in ipairs(s.awards or {}) do
        awards[#awards + 1] = ("%s an %s%s"):format(ns.ItemName(a.item), a.name, (a.kind and a.kind ~= "-") and (" (" .. a.kind .. ")") or "")
    end
    return table.concat({
        ("|cffe2b857%s, %s|r"):format(s.zone or "?", s.date or "?"),
        ("|cffe2b857Raider (%d):|r %s"):format(#names, #people > 0 and table.concat(people, ", ") or "keine"),
        "|cffe2b857Loot:|r " .. (#loot > 0 and table.concat(loot, ", ") or "keiner"),
        "|cffe2b857In Lootfenstern:|r " .. (#drops > 0 and table.concat(drops, ", ") or "nichts"),
        "|cffe2b857Vergaben:|r " .. (#awards > 0 and table.concat(awards, ", ") or "keine"),
    }, "\n\n")
end

local function col(parent, x, w, label, template)
    local fs = W.Text(parent, template or "GameFontNormalSmall", w)
    fs:SetPoint("LEFT", x, 0)
    if label then fs:SetText(label) end
    return fs
end

ns.RegisterPanel{ key = "raids", label = "Raids", icon = "Interface\\Icons\\Ability_Warrior_BattleShout", order = 20, officer = true,
    create = function(parent)
        local f = CreateFrame("Frame", nil, parent)
        page = f
        local head = CreateFrame("Frame", nil, f)
        head:SetHeight(18)
        head:SetPoint("TOPLEFT")
        head:SetPoint("TOPRIGHT")
        col(head, 30, 80, "Datum")
        col(head, 112, 200, "Raid")
        col(head, 316, 60, "Raider")
        col(head, 380, 50, "Mal")
        col(head, 432, 50, "Herz")
        col(head, 486, 90, "Edelsteine")
        f.list = W.List(f, ROWS, ROW_H, function(r)
            r.box = W.Toggle(r, function(on)
                if r.item then ns.RaidSelection[r.item.id] = on or nil end
            end)
            r.box:SetPoint("LEFT", 6, 0)
            r.sel = W.Flat(r, W.GOLD[1], W.GOLD[2], W.GOLD[3], 0.18, "BORDER")
            r.date = col(r, 30, 80, nil, "GameFontHighlightSmall")
            r.zone = col(r, 112, 200, nil, "GameFontHighlightSmall")
            r.raiders = col(r, 316, 60, nil, "GameFontHighlightSmall")
            r.mark = col(r, 380, 50, nil, "GameFontHighlightSmall")
            r.heart = col(r, 432, 50, nil, "GameFontHighlightSmall")
            r.gems = col(r, 486, 90, nil, "GameFontHighlightSmall")
            r:SetScript("OnClick", function(self)
                if self.item then
                    detailId = self.item.id
                    ns.Refresh()
                end
            end)
        end, function(r, s)
            local c = ns.MatCounts(s)
            r.box:SetChecked(ns.RaidSelection[s.id])
            r.date:SetText(ns.ExportState(s) == "done" and ("|cff8f86a3" .. s.date .. "|r") or s.date)
            r.zone:SetText((s == ns.Active() and "|TInterface\\AddOns\\Amisia\\Media\\Icons\\dot:12:12:0:0|t " or "") .. (s.zone or "?"))
            local late = ns.LateCount(s)
            r.raiders:SetText(ns.MemberCount(s) .. (late > 0 and ("  |cffe0a344+" .. late .. "|r") or ""))
            r.mark:SetText(c[32897] or 0)
            r.heart:SetText(c[32428] or 0)
            r.gems:SetText(ns.GemCount(c))
            if s.id == detailId then r.sel:Show() else r.sel:Hide() end
        end)
        f.list:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -2)
        f.list:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", 0, -2)
        f.pageText = W.Text(f, "GameFontDisableSmall", 200)
        f.pageText:SetPoint("TOPLEFT", f.list, "BOTTOMLEFT", 6, -8)
        f.del = W.Button(f, "Löschen", 100, function()
            if not next(ns.RaidSelection) then
                ns.msg("Zuerst Raids in der Liste ankreuzen.")
                return
            end
            StaticPopup_Show("AMISIA_DELETE")
        end)
        f.del:SetPoint("TOPRIGHT", f.list, "BOTTOMRIGHT", 0, -4)
        f.all = W.Button(f, "Alle wählen", 100, function()
            local all, allOn = ordered(), true
            for _, s in ipairs(all) do if not ns.RaidSelection[s.id] then allOn = false end end
            wipe(ns.RaidSelection)
            if not allOn then for _, s in ipairs(all) do ns.RaidSelection[s.id] = true end end
            ns.Refresh()
        end)
        f.all:SetPoint("RIGHT", f.del, "LEFT", -6, 0)
        f.detail = W.ScrollText(f)
        f.detail:SetPoint("TOPLEFT", f.list, "BOTTOMLEFT", 0, -34)
        f.detail:SetPoint("BOTTOMRIGHT", -24, 0)
        return f
    end,
    refresh = function(f)
        local all = ordered()
        local exists = {}
        for _, s in ipairs(all) do exists[s.id] = s end
        for id in pairs(ns.RaidSelection) do if not exists[id] then ns.RaidSelection[id] = nil end end
        f.list:SetItems(all)
        f.pageText:SetText(#all == 0 and "Noch keine Raids aufgezeichnet." or ("%d Raids"):format(#all))
        local s = exists[detailId] or all[1]
        detailId = s and s.id or nil
        f.detail:SetText(s and detailText(s) or "")
    end }

StaticPopupDialogs["AMISIA_DELETE"] = {
    text = "Die angekreuzten Raids aus Amisia löschen?",
    button1 = "Löschen",
    button2 = "Abbrechen",
    OnAccept = function()
        local n = ns.DeleteSessions(ns.RaidSelection)
        wipe(ns.RaidSelection)
        ns.msg(("%d Raid(s) gelöscht."):format(n))
        ns.Refresh()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

ns.RegisterCard{ key = "raid", order = 10, fill = function(c)
    local all = ns.Sessions()
    local s = ns.Active() or all[#all]
    c.title:SetText(ns.Active() and "Aufnahme läuft" or "Letzter Raid")
    if not s then
        c.line1:SetText("Noch kein Raid aufgezeichnet")
        c.line2:SetText("Die Aufnahme startet in einer Raidinstanz mit Raidgruppe.")
        return
    end
    c.line1:SetText(("%s, %s"):format(s.zone or "?", s.date or "?"))
    local m = ns.MatCounts(s)
    local late = ns.LateCount(s)
    local parts = { ("%d Raider"):format(ns.MemberCount(s)) }
    if late > 0 then parts[#parts + 1] = late .. " zu spät" end
    local mats = (m[32897] or 0) + (m[32428] or 0) + ns.GemCount(m)
    if mats > 0 then parts[#parts + 1] = ("Mal %d · Herz %d · Edelsteine %d"):format(m[32897] or 0, m[32428] or 0, ns.GemCount(m)) end
    c.line2:SetText(table.concat(parts, " · "))
    if ns.IsOfficerView() then c:SetAction("Raids", function() ns.ShowPage("raids") end) end
end }

ns.RegisterCard{ key = "awards", order = 40, fill = function(c)
    local all = ns.Sessions()
    local last = all[#all]
    c.title:SetText("Vergaben letzte Nacht")
    if not last then
        c.line1:SetText("Keine")
        return
    end
    local n = 0
    for _, s in ipairs(all) do
        if s.date == last.date then n = n + ns.AwardCount(s) end
    end
    c.line1:SetText(("%d Items am %s"):format(n, last.date))
    c.line2:SetText(n > 0 and "Details auf der Seite Raids." or "Master Loot hat nichts vergeben.")
end }
```

- [ ] **Step 6: Pages/Export.lua**

```lua
-- Export: the text block for the ledger's Import tab, of the new and changed raids or the selected ones.
local ADDON, ns = ...
local W = ns.W

local area
local exportText = ""

local function setExport(txt)
    exportText = txt or ""
    if not area then return end
    area.box:SetText(exportText)
    area.box:SetCursorPosition(0)
end

-- Fills the export box. latestOnly: the newest session. Otherwise the selected sessions, or without
-- a selection every session that is new or changed since its last export. What the box shows counts
-- as exported from then on.
function ns.ShowExport(latestOnly)
    ns.ShowPage("export")
    local src, list = ns.Sessions(), {}
    local onlyNew = false
    if latestOnly then
        if src[#src] then list[1] = src[#src] end
    elseif next(ns.RaidSelection or {}) then
        for _, s in ipairs(src) do if ns.RaidSelection[s.id] then list[#list + 1] = s end end
    else
        list = ns.PendingExport()
        onlyNew = true
    end
    if #list == 0 then
        local bankOnly = onlyNew and ns.BankPending() or (not onlyNew and ns.Bank())
        if not bankOnly then
            setExport("")
            if #src == 0 and not ns.Bank() then
                ns.msg("Noch keine Raids und keine Gildenbank-Zählung zum Exportieren.")
            else
                ns.msg("Nichts Neues seit dem letzten Export. Raids auf der Seite Raids ankreuzen, um sie noch einmal zu exportieren.")
            end
            return
        end
    end
    setExport(ns.ExportText(list))
    ns.MarkExported(list)
    if onlyNew then
        ns.msg(("Export: %d neue oder geänderte Raid(s)%s."):format(#list, ns.Bank() and " und die Gildenbank" or ""))
    end
    area.box:SetFocus()
    area.box:HighlightText()
    ns.Refresh()
end

ns.RegisterPanel{ key = "export", label = "Export", icon = "Interface\\Icons\\INV_Scroll_05", order = 60, officer = true,
    create = function(parent)
        local f = CreateFrame("Frame", nil, parent)
        local intro = W.Text(f, "GameFontHighlight", 590, true)
        intro:SetPoint("TOPLEFT", 0, -2)
        intro:SetText("Text für den Import-Tab der Amisia-Loot-Seite.")
        local newBtn = W.Button(f, "Neue und geänderte", 150, function()
            wipe(ns.RaidSelection)
            ns.ShowExport(false)
        end)
        newBtn:SetPoint("TOPLEFT", 0, -26)
        local selBtn = W.Button(f, "Angekreuzte", 120, function()
            if not next(ns.RaidSelection) then
                ns.msg("Zuerst Raids auf der Seite Raids ankreuzen.")
                return
            end
            ns.ShowExport(false)
        end)
        selBtn:SetPoint("LEFT", newBtn, "RIGHT", 6, 0)
        f.state = W.Text(f, "GameFontDisableSmall", 300)
        f.state:SetPoint("LEFT", selBtn, "RIGHT", 10, 0)
        area = W.EditArea(f)
        area:SetPoint("TOPLEFT", 0, -56)
        area:SetPoint("BOTTOMRIGHT", 0, 24)
        area.box:SetScript("OnTextChanged", function(self, userInput)
            if userInput then
                self:SetText(exportText)
                self:HighlightText()
            end
        end)
        local hint = W.Text(f, "GameFontDisableSmall", 590)
        hint:SetPoint("BOTTOMLEFT", 0, 4)
        hint:SetText("Strg+A, Strg+C, im Import-Tab einfügen.")
        return f
    end,
    refresh = function(f)
        local pending = #ns.PendingExport()
        f.state:SetText(pending > 0 and ("%d Raid(s) neu oder geändert"):format(pending) or "alles exportiert")
    end }

ns.RegisterCard{ key = "export", order = 60, officer = true, fill = function(c)
    local pending = #ns.PendingExport()
    c.title:SetText("Export")
    c.line1:SetText(pending > 0 and ("%d Raid(s) neu oder geändert"):format(pending) or "Alles exportiert")
    c.line2:SetText(ns.BankPending() and "Die Gildenbank-Zählung ist auch neu." or "")
    if pending > 0 or ns.BankPending() then c:SetAction("Exportieren", function() wipe(ns.RaidSelection); ns.ShowExport(false) end) end
end }
```

- [ ] **Step 7: Pages/Rolls.lua**

```lua
-- Rolls: the running round and the last rounds of this session; the floating roll window stays.
local ADDON, ns = ...
local W = ns.W

local function roundLine(r)
    local list = ns.RollRanking(r)
    local who
    if r.winner then
        who = ("|cff4fbf7a%s|r (%s)"):format(r.winner, list[1] and list[1].rank or "?")
    elseif r.tie then
        who = "|cffe0a344Gleichstand: " .. table.concat(r.tie, ", ") .. "|r"
    elseif r.done then
        who = "|cff8f86a3niemand gewürfelt|r"
    else
        who = ("läuft, noch %d s, %d Würfe"):format(r.leftAt or 0, #list)
    end
    return ("%s  %s  %s"):format(date("%H:%M", r.started or 0), r.name or "?", who)
end

ns.RegisterPanel{ key = "rolls", label = "Rolls", icon = "Interface\\Buttons\\UI-GroupLoot-Dice-Up", order = 30, officer = true,
    create = function(parent)
        local f = CreateFrame("Frame", nil, parent)
        f.current = W.Text(f, "GameFontHighlight", 590, true)
        f.current:SetPoint("TOPLEFT", 0, -2)
        local open = W.Button(f, "Roll-Fenster", 120, function() ns.ShowRollFrame() end)
        open:SetPoint("TOPLEFT", 0, -26)
        f.hint = W.Text(f, "GameFontDisableSmall", 440, true)
        f.hint:SetPoint("LEFT", open, "RIGHT", 10, 0)
        local head = W.Text(f, "GameFontNormal", 300)
        head:SetPoint("TOPLEFT", 0, -60)
        head:SetText("Letzte Runden")
        f.list = W.List(f, 12, 22, function(r)
            r.text = W.Text(r, "GameFontHighlightSmall", 580)
            r.text:SetPoint("LEFT", 6, 0)
        end, function(r, round) r.text:SetText(roundLine(round)) end)
        f.list:SetPoint("TOPLEFT", 0, -80)
        f.list:SetPoint("TOPRIGHT", 0, -80)
        return f
    end,
    refresh = function(f)
        local cur = ns.CurrentRoll()
        f.current:SetText(cur and not cur.done and ("Laufende Runde: " .. roundLine(cur)) or "Keine laufende Runde.")
        f.hint:SetText(ns.Get("rolls.altClick") and "Alt-Klick auf ein Item im Lootfenster startet eine Runde."
            or "Alt-Klick ist ausgeschaltet. /amisia roll <Item-Link> startet eine Runde.")
        f.list:SetItems(ns.RollHistory())
    end }
```

- [ ] **Step 8: Pages/SoftRes.lua**

```lua
-- Soft-reserves: who reserved what in the loaded list; importing and clearing for officers.
local ADDON, ns = ...
local W = ns.W

local function daysOld(isoDate)
    local y, m, d = tostring(isoDate or ""):match("^(%d+)-(%d+)-(%d+)$")
    if not y then return nil end
    local t = time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
    return t and math.floor((time() - t) / 86400) or nil
end

local function rows()
    local sr = AmisiaDB and AmisiaDB.softres
    local out = {}
    for item, names in pairs(sr and sr.byItem or {}) do
        out[#out + 1] = { item = item, name = ns.ItemName(item), names = names }
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

-- Raid members without a reservation, when in a raid and a list is loaded.
local function missing()
    local sr = AmisiaDB and AmisiaDB.softres
    if not sr or not IsInRaid() then return nil end
    local reserved = {}
    for _, names in pairs(sr.byItem or {}) do
        for _, n in ipairs(names) do reserved[n:lower()] = true end
    end
    local out = {}
    for i = 1, GetNumGroupMembers() or 0 do
        local n = ns.FullName((GetRaidRosterInfo(i)))
        if n and not reserved[n:lower()] then out[#out + 1] = n end
    end
    return out
end

ns.RegisterPanel{ key = "softres", label = "Soft-Reserves", icon = "Interface\\Icons\\INV_Scroll_03", order = 40,
    create = function(parent)
        local f = CreateFrame("Frame", nil, parent)
        f.state = W.Text(f, "GameFontHighlight", 590, true)
        f.state:SetPoint("TOPLEFT", 0, -2)
        f.import = W.Button(f, "Importieren", 110, function() ns.ToggleSoftResFrame() end)
        f.import:SetPoint("TOPLEFT", 0, -26)
        f.clear = W.Button(f, "Löschen", 90, function() ns.ClearSoftRes(); ns.Refresh() end)
        f.clear:SetPoint("LEFT", f.import, "RIGHT", 6, 0)
        f.missing = W.Text(f, "GameFontDisableSmall", 380, true)
        f.missing:SetPoint("LEFT", f.clear, "RIGHT", 10, 0)
        f.list = W.List(f, 16, 22, function(r)
            r.item = W.Text(r, "GameFontHighlightSmall", 230)
            r.item:SetPoint("LEFT", 6, 0)
            r.names = W.Text(r, "GameFontHighlightSmall", 350)
            r.names:SetPoint("LEFT", 240, 0)
        end, function(r, e)
            r.item:SetText(e.name)
            r.names:SetText(table.concat(e.names, ", "))
        end)
        f.list:SetPoint("TOPLEFT", 0, -58)
        f.list:SetPoint("TOPRIGHT", 0, -58)
        return f
    end,
    refresh = function(f)
        local sr = AmisiaDB and AmisiaDB.softres
        if sr then
            local old = daysOld(sr.date) or 0
            local warn = old > (ns.Get("softres.warnDays") or 7)
            f.state:SetText(("%sListe vom %s:|r %d Reservierungen%s"):format(warn and "|cffe0a344" or "|cff4fbf7a", sr.date, sr.count or 0,
                warn and (", " .. old .. " Tage alt") or ""))
        else
            f.state:SetText("|cff8f86a3Keine Soft-Reserves geladen.|r")
        end
        local officer = ns.IsOfficerView()
        if officer then f.import:Show(); f.clear:Show() else f.import:Hide(); f.clear:Hide() end
        local miss = missing()
        f.missing:SetText(miss and (#miss == 0 and "Alle im Raid haben reserviert." or (#miss .. " im Raid ohne Reserve: " .. table.concat(miss, ", "))) or "")
        f.list:SetItems(rows())
    end }

ns.RegisterCard{ key = "softres", order = 20, fill = function(c)
    local sr = AmisiaDB and AmisiaDB.softres
    c.title:SetText("Soft-Reserves")
    if not sr then
        c.line1:SetText("Keine Liste geladen")
        if ns.IsOfficerView() then c:SetAction("Importieren", function() ns.ToggleSoftResFrame() end) end
        return
    end
    c.line1:SetText(("%d Reservierungen, vom %s"):format(sr.count or 0, sr.date))
    local miss = missing()
    c.line2:SetText(miss and (#miss .. " im Raid ohne Reserve") or "")
    c:SetAction("Ansehen", function() ns.ShowPage("softres") end)
end }
```

- [ ] **Step 9: Pages/Gear.lua**

```lua
-- Gear (WoW Forever): what the player can get at their level that beats what they wear.
local ADDON, ns = ...
local W = ns.W
local QUALITY = { [0] = "ff9d9d9d", "ffffffff", "ff1eff00", "ff0070dd", "ffa335ee", "ffff8000", "ffe6cc80" }

local function available() return ns.Gear and ns.Gear.Available() end

local function itemName(id)
    local getInfo = C_Item and C_Item.GetItemInfo or _G.GetItemInfo
    local name, _, q = getInfo(id)
    local row = ns.Gear.Item(id)
    q = q or (row and row[5]) or 1
    return ("|c%s%s|r"):format(QUALITY[q] or QUALITY[1], name or ("Item " .. id))
end

local function sourceText(id, o)
    local rec = ns.Gear.Sources(id, o)[1]
    return rec and ns.Gear.SourceText(rec, true) or ""
end

ns.RegisterPanel{ key = "gear", label = "Ausrüstung", icon = "Interface\\Icons\\INV_Chest_Chain_05", order = 50, available = available,
    create = function(parent)
        local f = CreateFrame("Frame", nil, parent)
        f.state = W.Text(f, "GameFontHighlight", 440, true)
        f.state:SetPoint("TOPLEFT", 0, -2)
        local open = W.Button(f, "Tabelle öffnen", 130, function() ns.ToggleGearFrame() end)
        open:SetPoint("TOPRIGHT", 0, 0)
        f.list = W.List(f, 17, 24, function(r)
            r.slot = W.Text(r, "GameFontNormalSmall", 80)
            r.slot:SetPoint("LEFT", 6, 0)
            r.name = W.Text(r, "GameFontHighlightSmall", 210)
            r.name:SetPoint("LEFT", 90, 0)
            r.src = W.Text(r, "GameFontHighlightSmall", 230)
            r.src:SetPoint("LEFT", 304, 0)
            r.gain = W.Text(r, "GameFontHighlightSmall", 50)
            r.gain:SetPoint("RIGHT", -6, 0)
            r.gain:SetJustifyH("RIGHT")
        end, function(r, e)
            r.slot:SetText(e.slot.name)
            r.name:SetText(itemName(e.id))
            r.src:SetText(sourceText(e.id, r:GetParent().opts))
            r.gain:SetText(("|cff4fd06a+%d|r"):format(math.floor(e.gain + 0.5)))
        end)
        f.list:SetPoint("TOPLEFT", 0, -30)
        f.list:SetPoint("TOPRIGHT", 0, -30)
        return f
    end,
    refresh = function(f)
        local list, _, o = ns.GearMyUpgrades()
        f.list.opts = o
        local loading = ns.Gear.Loading()
        f.state:SetText(("Level %d · %d Upgrades%s"):format(UnitLevel("player") or 1, #list,
            loading > 0 and (" · |cffe0a344lädt noch " .. loading .. " Items|r") or ""))
        f.list:SetItems(list)
    end }

ns.RegisterCard{ key = "gear", order = 30, available = available, fill = function(c)
    local list = ns.GearMyUpgrades()
    c.title:SetText("Deine Ausrüstung")
    c.line1:SetText(("Level %d · %d Upgrades"):format(UnitLevel("player") or 1, #list))
    if list[1] then c.line2:SetText(("Bestes: %s (+%d)"):format(itemName(list[1].id), math.floor(list[1].gain + 0.5))) end
    c:SetAction("Ansehen", function() ns.ShowPage("gear") end)
end }
```

(`r:GetParent()` ist die Liste; `f.list.opts` wird in `refresh` vor `SetItems` gesetzt.)

- [ ] **Step 10: Pages/Bank.lua**

```lua
-- Guild bank: the last count of the tracked materials.
local ADDON, ns = ...
local W = ns.W

ns.RegisterPanel{ key = "bank", label = "Gildenbank", icon = "Interface\\Icons\\INV_Misc_Coin_02", order = 70, officer = true,
    create = function(parent)
        local f = CreateFrame("Frame", nil, parent)
        f.state = W.Text(f, "GameFontHighlight", 590, true)
        f.state:SetPoint("TOPLEFT", 0, -2)
        f.list = W.List(f, #ns.MAT_ORDER, 22, function(r)
            r.name = W.Text(r, "GameFontHighlightSmall", 300)
            r.name:SetPoint("LEFT", 6, 0)
            r.count = W.Text(r, "GameFontHighlightSmall", 80)
            r.count:SetPoint("RIGHT", -6, 0)
            r.count:SetJustifyH("RIGHT")
        end, function(r, e)
            r.name:SetText(ns.ItemName(e.id))
            r.count:SetText(e.count)
        end)
        f.list:SetPoint("TOPLEFT", 0, -40)
        f.list:SetPoint("TOPRIGHT", 0, -40)
        return f
    end,
    refresh = function(f)
        local bank = ns.Bank()
        if not (bank and bank.counts) then
            f.state:SetText("|cff8f86a3Noch nicht gezählt.|r Öffne die Gildenbank einmal, dann zählt Amisia die Materialien.")
            f.list:SetItems({})
            return
        end
        local hidden = (bank.total or 0) - (bank.tabs or 0)
        f.state:SetText(("Gezählt am %s von %s · %d von %d sichtbaren Tabs mit Gegenständen%s"):format(
            date("%d.%m.%Y %H:%M", bank.at), bank.by or "?", bank.filled or 0, bank.tabs or 0,
            hidden > 0 and (" · |cffe0a344" .. hidden .. " Tabs nicht sichtbar|r") or ""))
        local items = {}
        for _, id in ipairs(ns.MAT_ORDER) do items[#items + 1] = { id = id, count = bank.counts[id] or 0 } end
        f.list:SetItems(items)
    end }

ns.RegisterCard{ key = "bank", order = 50, officer = true, fill = function(c)
    local bank = ns.Bank()
    c.title:SetText("Gildenbank")
    if not (bank and bank.counts) then
        c.line1:SetText("Noch nicht gezählt")
        return
    end
    local b = bank.counts
    c.line1:SetText(("Gezählt am %s"):format(date("%d.%m. %H:%M", bank.at)))
    c.line2:SetText(("Mal %d · Herz %d · Edelsteine %d"):format(b[32897] or 0, b[32428] or 0, ns.GemCount(b)))
    c:SetAction("Ansehen", function() ns.ShowPage("bank") end)
end }
```

- [ ] **Step 11: Pages/Tools.lua**

```lua
-- Tools (expert mode): the item scan and the collector that build the data files.
local ADDON, ns = ...
local W = ns.W

ns.RegisterPanel{ key = "tools", label = "Werkzeuge", icon = "Interface\\Icons\\INV_Misc_Gear_01", order = 80, expert = true,
    create = function(parent)
        local f = CreateFrame("Frame", nil, parent)
        f.state = W.Text(f, "GameFontHighlight", 590, true)
        f.state:SetPoint("TOPLEFT", 0, -2)
        local gear = W.Button(f, "Ausrüstungs-Scan", 140, function() ns.ScanCommand("gear"); ns.Refresh() end)
        gear:SetPoint("TOPLEFT", 0, -40)
        local resume = W.Button(f, "Scan fortsetzen", 130, function() ns.ScanCommand(""); ns.Refresh() end)
        resume:SetPoint("LEFT", gear, "RIGHT", 6, 0)
        local retry = W.Button(f, "Offene wiederholen", 140, function() ns.ScanCommand("retry"); ns.Refresh() end)
        retry:SetPoint("LEFT", resume, "RIGHT", 6, 0)
        local stop = W.Button(f, "Anhalten", 90, function() ns.ScanStop(); ns.Refresh() end)
        stop:SetPoint("LEFT", retry, "RIGHT", 6, 0)
        local hint = W.Text(f, "GameFontDisableSmall", 590, true)
        hint:SetPoint("TOPLEFT", 0, -76)
        hint:SetText("Der Scan läuft nur außerhalb von Instanzen. Danach ausloggen, damit die Datei geschrieben wird; "
            .. "tools/build_gear.py und tools/build_scan.py lesen sie. Sammler und Scan-Rate stehen in den Einstellungen.")
        return f
    end,
    refresh = function(f)
        f.state:SetText(ns.ScanStatus() .. ("\nItem-Sammler: %s, %d Items mit Quelle."):format(ns.Get("tools.collect") and "an" or "aus", ns.CollectCount()))
    end }
```

- [ ] **Step 12: Pages/Settings.lua**

```lua
-- Settings: built from the registered sections; changed rows carry a dot and a reset button.
local ADDON, ns = ...
local W = ns.W
local GOLD = W.GOLD
local ROW_H, LABEL_W = 26, 300

local rows = {}   -- path -> row
local scroll, child

function ns.SettingsRows() return rows end

local function valueText(it, v)
    if it.type == "time" then return ns.FormatTime(v) end
    if it.type == "toggle" then return v and "an" or "aus" end
    if it.type == "choice" then
        for _, c in ipairs(it.values) do if c[1] == v then return c[2] end end
    end
    return tostring(v)
end

local function makeRow(it)
    local r = CreateFrame("Frame", nil, child)
    r:SetSize(560, ROW_H)
    r:EnableMouse(true)
    r.dot = r:CreateTexture(nil, "ARTWORK")
    r.dot:SetSize(6, 6)
    r.dot:SetPoint("LEFT", 0, 0)
    r.dot:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    r.label = W.Text(r, "GameFontHighlightSmall", LABEL_W)
    r.label:SetPoint("LEFT", 12, 0)
    r.label:SetText(it.label or it.key)
    local path = it.key
    if it.type == "toggle" then
        r.control = W.Toggle(r, function(v) ns.Set(path, v) end)
    elseif it.type == "slider" then
        r.control = W.Stepper(r, 130, function(v) ns.Set(path, v) end)
        r.control:Configure(it.min, it.max, it.step)
    elseif it.type == "time" then
        r.control = W.TimeBox(r, 70, function(text)
            local ok, why = ns.Set(path, text)
            if not ok then ns.msg(why .. " Beispiel: 20:00" .. (it.allowOff and " oder aus" or "")) end
            ns.Refresh()
        end)
    elseif it.type == "choice" then
        r.control = W.Choice(r, 150, function(v) ns.Set(path, v) end)
        r.control:SetValues(it.values)
    elseif it.type == "button" then
        r.control = W.Button(r, it.label, 230, function() it.run() end)
        r.label:SetText("")
    end
    if r.control then r.control:SetPoint("LEFT", LABEL_W + 20, 0) end
    if it.type ~= "button" and it.type ~= "desc" then
        r.reset = W.Chip(r, "x", 20, function() ns.Reset(path) end)
        r.reset:SetPoint("LEFT", LABEL_W + 20 + 160, 0)
        W.Tooltip(r.reset, "Zurücksetzen", "Auf den Standard zurück.")
    end
    r:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(it.label or it.key, 1, 0.82, 0)
        if it.tip then GameTooltip:AddLine(it.tip, 0.85, 0.85, 0.85, true) end
        if it.default ~= nil then GameTooltip:AddLine("Standard: " .. valueText(it, it.default), 0.6, 0.6, 0.6) end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r.it = it
    rows[path] = r
    return r
end

local function fillRow(r)
    local it, v = r.it, ns.Get(r.it.key)
    if it.type == "toggle" then r.control:SetChecked(v)
    elseif it.type == "slider" then r.control:SetValue(v)
    elseif it.type == "time" then if not r.control:HasFocus() then r.control:SetText(ns.FormatTime(v)) end
    elseif it.type == "choice" then r.control:SetValue(v) end
    local changed = it.type ~= "button" and not ns.IsDefault(it.key)
    if changed then r.dot:Show() else r.dot:Hide() end
    if r.reset then if changed then r.reset:Show() else r.reset:Hide() end end
end

local headers = {}

ns.RegisterPanel{ key = "settings", label = "Einstellungen", icon = "Interface\\Icons\\Trade_Engineering", order = 900, bottom = true,
    create = function(parent)
        local f = CreateFrame("Frame", nil, parent)
        scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT")
        scroll:SetPoint("BOTTOMRIGHT", -24, 0)
        child = CreateFrame("Frame", nil, scroll)
        child:SetSize(560, 10)
        scroll:SetScrollChild(child)
        return f
    end,
    refresh = function()
        local y = 0
        for _, h in pairs(headers) do h:Hide() end
        for _, r in pairs(rows) do r:Hide() end
        for _, section in ipairs(ns.schema) do
            if ns.Visible(section) then
                local shown = {}
                for _, it in ipairs(section.items) do
                    if it.key and ns.Visible(it) then shown[#shown + 1] = it end
                end
                if #shown > 0 then
                    local h = headers[section.key]
                    if not h then
                        h = W.Text(child, "GameFontNormal", 500)
                        h:SetText(section.label)
                        headers[section.key] = h
                    end
                    h:ClearAllPoints()
                    h:SetPoint("TOPLEFT", 0, -y)
                    h:Show()
                    y = y + 24
                    for _, it in ipairs(shown) do
                        local r = rows[it.key] or makeRow(it)
                        r:ClearAllPoints()
                        r:SetPoint("TOPLEFT", 0, -y)
                        fillRow(r)
                        r:Show()
                        y = y + ROW_H
                    end
                    y = y + 12
                end
            end
        end
        child:SetHeight(math.max(10, y))
    end }
```

Stub: `HasFocus` für EditBox in `frameMethods` ergänzen als Funktion, die `false` liefert: in `CreateFrame` nach `f.GetChecked = ...`: `f.HasFocus = function() return false end`.

- [ ] **Step 13: Pages/About.lua**

```lua
-- About: the version and every command, generated from the registry.
local ADDON, ns = ...
local W = ns.W

ns.RegisterPanel{ key = "about", label = "Über und Befehle", icon = "Interface\\Icons\\INV_Misc_QuestionMark", order = 910, bottom = true,
    create = function(parent)
        local f = CreateFrame("Frame", nil, parent)
        f.head = W.Text(f, "GameFontNormal", 590, true)
        f.head:SetPoint("TOPLEFT", 0, -2)
        f.text = W.ScrollText(f)
        f.text:SetPoint("TOPLEFT", 0, -50)
        f.text:SetPoint("BOTTOMRIGHT", -24, 0)
        return f
    end,
    refresh = function(f)
        f.head:SetText(("Amisia %s\n|cff8f86a3Raid-Aufnahme, Loot, Rolls, Soft-Reserves und Export für die Amisia-Loot-Seite.|r"):format(ns.VERSION or ""))
        f.text:SetText(table.concat(ns.SlashHelpLines(ns.IsOfficerView()), "\n"))
    end }
```

- [ ] **Step 14: TOC und UI.lua entfernen**

In `addon/Amisia/Amisia.toc` `UI.lua` löschen und nach `MainFrame.lua` die zehn `Pages\*.lua` in der Reihenfolge der Dateistruktur eintragen. `git rm addon/Amisia/UI.lua`.

- [ ] **Step 15: Tests laufen lassen**

Run: `python addon/tests/run.py` und `node addon/tests/syntax.cjs` (syntax.cjs liest nur `addon/Amisia/*.lua`; in `addon/tests/syntax.cjs` die Dateiliste um `Pages/` erweitern: `const files = fs.readdirSync(dir).filter(f => f.endsWith('.lua')).concat(fs.readdirSync(path.join(dir, 'Pages')).filter(f => f.endsWith('.lua')).map(f => path.join('Pages', f)));` und die Schleife über `files` laufen lassen).
Expected: alles `ok`, inklusive `test_export.lua` und `test_pages.lua`.

- [ ] **Step 16: Commit**

```bash
git add -A addon/Amisia addon/tests
git commit -m "Amisia: the pages of the new window, the old window goes"
```

---

### Task 7: Minimap-Schnellmenü

**Files:**
- Modify: `addon/Amisia/Minimap.lua`
- Modify: `addon/tests/test_minimap.lua`

**Interfaces:**
- Consumes: `ns.W.Menu`, `ns.ShowPage`, `ns.ToggleMain`, `ns.IsOfficerView`
- Produces: `ns.MinimapMenuEntries() -> entries`

- [ ] **Step 1: Test anpassen (failing)**

In `addon/tests/test_minimap.lua` den Block mit `local opened` bis `NS.Toggle, NS.ToggleGearFrame = origToggle, origGear` ersetzen durch:

```lua
-- left click opens the main window, right click the quick menu
local origMain = NS.ToggleMain
local opened
NS.ToggleMain = function() opened = "main" end
b.scripts.OnClick(b, "LeftButton"); assert(opened == "main")
Amisia_OnAddonCompartmentClick("Amisia", "LeftButton"); assert(opened == "main", "the compartment entry clicks the same")
NS.ToggleMain = origMain
b.scripts.OnClick(b, "RightButton"); assert(AmisiaMenu and AmisiaMenu:IsShown(), "right click opens the menu")
local labels = {}
for _, e in ipairs(NS.MinimapMenuEntries()) do labels[#labels + 1] = e[1] end
local all = table.concat(labels, "|")
assert(all:find("Einstellungen", 1, true) and all:find("Soft-Reserves", 1, true) and all:find("Export", 1, true), all)
NS.Set("ui.view", "raider")
all = ""
for _, e in ipairs(NS.MinimapMenuEntries()) do all = all .. e[1] .. "|" end
assert(not all:find("Export", 1, true), "raiders see no officer entries")
NS.Reset("ui.view")
Amisia_OnAddonCompartmentEnter("Amisia", b)
Amisia_OnAddonCompartmentLeave("Amisia", b)
b.scripts.OnEnter(b); b.scripts.OnLeave(b)
```

Run: `python addon/tests/run.py minimap` -> FAIL (`MinimapMenuEntries`).

- [ ] **Step 2: Minimap.lua**

`click(mouse)` ersetzen durch:

```lua
function ns.MinimapMenuEntries()
    local officer = ns.IsOfficerView()
    local e = {}
    if gearAvailable() then e[#e + 1] = { "Ausrüstung", function() ns.ToggleGearFrame() end } end
    if officer then e[#e + 1] = { "Rolls", function() ns.ShowPage("rolls") end } end
    e[#e + 1] = { "Soft-Reserves", function() ns.ShowPage("softres") end }
    if officer then e[#e + 1] = { "Export", function() ns.ShowPage("export") end } end
    e[#e + 1] = { "Einstellungen", function() ns.ShowPage("settings") end }
    e[#e + 1] = { ns.IsEnabled() and "Aufnahme pausieren" or "Aufnahme fortsetzen", function() ns.SetEnabled(not ns.IsEnabled()) end }
    return e
end

-- What both the button and the compartment entry do on a click.
local function click(mouse)
    if mouse == "RightButton" then
        ns.W.Menu((button and button:IsShown()) and button or UIParent, ns.MinimapMenuEntries())
    else
        ns.ToggleMain()
    end
end
```

Im Tooltip `GameTooltip:AddDoubleLine("Linksklick", "Amisia-Fenster", ...)` bleibt, `"Rechtsklick"` bekommt den Text `"Schnellmenü"`.

- [ ] **Step 3: Tests laufen lassen**

Run: `python addon/tests/run.py`
Expected: alles `ok`.

- [ ] **Step 4: Commit**

```bash
git add addon/Amisia/Minimap.lua addon/tests/test_minimap.lua
git commit -m "Amisia: a quick menu on the minimap button"
```

---

### Task 8: Ausrüstung: absoluter Zuwachs, Testitems raus

**Files:**
- Modify: `addon/Amisia/GearFrame.lua` (fillList, Wert-Spalte)
- Modify: `tools/build_gear.py` (TEST_ITEMS)
- Modify: `tools/tests/test_build_gear.py`
- Modify: `addon/Amisia/GearData.lua` (neu gebaut)

**Interfaces:**
- Produces: `build_gear.TEST_ITEMS` (set of item ids)

- [ ] **Step 1: Failing Python-Test**

In `tools/tests/test_build_gear.py` anfügen:

```python
def test_test_items_stay_out():
    assert 8350 in build_gear.TEST_ITEMS
    questie = {'Item': {8350: {1: 'The 1 Ring', 6: [500]}}, 'Quest': {500: {1: 'Q', 4: 1, 5: 2}}, 'Npc': {}}
    scan = {8350: scan_item('Der Eine Ring', loc='INVTYPE_FINGER')}
    _, keep, _, _, dropped, *_ = build_gear.build(scan, {}, questie, ({}, {}, {}), ({}, {}), [], {}, {})
    assert 8350 not in keep and dropped['junk'] == 1
```

Run: `python -m pytest tools/tests/test_build_gear.py -q` -> FAIL (`TEST_ITEMS`).

- [ ] **Step 2: build_gear.py**

Nach `FOREVER_IDS = 200000` einfügen:

```python
# GM and test items the client knows but no player gets (names come in the client's language, so by id).
TEST_ITEMS = {8350}   # The 1 Ring
```

In `build` die Junk-Prüfung ersetzen:

```python
        if iid in TEST_ITEMS or build_scan.JUNK_NAME.search(it['name'] or ''):
            dropped['junk'] += 1
            continue
```

Danach mit Questies englischen Namen weitere Testitems unter den Planer-Items suchen und die IDs in `TEST_ITEMS` ergänzen:

```bash
python -c "import sys,re; sys.path.insert(0,'tools'); import build_gear as b; q=b.load_questie(); t=open('addon/Amisia/GearData.lua',encoding='utf-8').read(); ids=[int(x) for x in re.findall(r'^\s+\[(\d+)\] = \{\"',t,re.M)]; print([(i,q['Item'][i].get(1)) for i in ids if i in q['Item'] and re.search(r'test|monster|deprecated|\bqa\b|gm |martin|\[ph\]|1 ring',str(q['Item'][i].get(1)),re.I)])"
```

- [ ] **Step 3: GearFrame.lua Wert-Spalte**

In `fillList` den Block

```lua
            local mine, link = equippedScore(slot, g.col)
            if mine and mine > 0 and link and ns.ItemID(link) ~= e[1] then
                local gain = (e[2] - mine) / mine * 100
                b.score:SetText(gain >= 2 and ("|cff4fd06a+%d%%|r"):format(gain) or ("%.0f"):format(e[2]))
                b.note = ("Angelegt: %.0f, dieses Item: %.0f"):format(mine, e[2])
            else
```

ersetzen durch

```lua
            local mine, link = equippedScore(slot, g.col)
            if mine and link and ns.ItemID(link) ~= e[1] then
                local gain = e[2] - mine
                b.score:SetText(gain >= 1 and ("|cff4fd06a+%d|r"):format(math.floor(gain + 0.5)) or ("%.0f"):format(e[2]))
                -- a percentage only means something when the worn item scores at all
                b.note = ("Angelegt: %.0f, dieses Item: %.0f%s"):format(mine, e[2],
                    mine >= 20 and ("  (%+d %%)"):format(math.floor(gain / mine * 100 + 0.5)) or "")
            else
```

- [ ] **Step 4: Daten neu bauen, Tests**

Run: `python tools/build_gear.py`, dann `python -m pytest tools/tests -q` und `python addon/tests/run.py`
Expected: grün; Build-Ausgabe zeigt `junk` >= 1.

- [ ] **Step 5: Commit**

```bash
git add tools/build_gear.py tools/tests/test_build_gear.py addon/Amisia/GearFrame.lua addon/Amisia/GearData.lua
git commit -m "Gear planner: absolute gains instead of runaway percentages, test items left out"
```

---

### Task 9: Version, Auslieferung, Twin, Prüfung

**Files:**
- Modify: `addon/Amisia/Amisia.toc` (Version 1.4.0, Dateiliste final), `addon/Amisia/Core.lua` (`ns.VERSION = "1.4.0"`)
- Modify: `addon/Amisia.zip`
- Twin-Artifact (claude.ai) und `tools/twin-stamp.json`

- [ ] **Step 1: Version und TOC**

`## Version: 1.4.0` in der TOC, `ns.VERSION = "1.4.0"` in Core.lua. Dateiliste mit der Liste oben vergleichen.

- [ ] **Step 2: Alle Tests**

Run: `python addon/tests/run.py`, `node addon/tests/syntax.cjs`, `python -m pytest tools/tests -q`
Expected: alles grün.

- [ ] **Step 3: Unabhängige Prüfung**

Skill `adversarial-review` über alle in Task 1-8 geänderten Dateien; bestätigte Funde beheben, Tests erneut.

- [ ] **Step 4: Synchronisieren und ZIP**

Run: `pwsh -File tools/sync_addon.ps1` (prüfen, dass `Pages\` in beiden AddOns-Ordnern ankommt), dann die ZIP aus allen Dateien unter `addon/Amisia` (ohne Punkt-Ordner, Präfix `Amisia/`) neu bauen und gegen die TOC prüfen (jede TOC-Datei, auch `Pages/*.lua`, muss in der ZIP liegen).

- [ ] **Step 5: Twin**

`data.json` des Twins lesen (Artifact `https://claude.ai/artifact/KRddbFih2kAjrRmEuV1arj`, Pfad `data.json`), dann `python tools/build_twin.py <scratchpad>/twin/index.html <scratchpad>/twin/data.json`, mit dem Artifact-Tool auf dieselbe URL veröffentlichen, danach `python tools/twin_stamp.py --published`.

- [ ] **Step 6: Commit (lokal), Push nach Freigabe**

```bash
git add -A addon tools/twin-stamp.json
git commit -m "Amisia 1.4.0: a new main window with pages, settings and quick menu, Forever surnames in the export"
```
