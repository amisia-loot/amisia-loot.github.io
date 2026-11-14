-- Amisia's languages: German and English. The player picks one in the settings (ui.language: "auto",
-- "deDE", "enUS"; F-199, D-128); "auto" (the default) follows the client's locale (deDE: German, every
-- other locale: English, D-08). German is the source text in the code: every text for the screen or the
-- chat goes through L["German text"], and Locales/enUS_*.lua gives its English. A key without an entry
-- shows as it stands (German). A key may carry a context after "##" ("Aus##Ansage") when one German
-- text needs two English ones; the German text is the part before "##".
--
-- Loading (D-128): the client runs an addon's files first and loads its SavedVariables after them, but
-- most files translate texts while they load. So this file, the first of the TOC, runs at once; every
-- other file puts its body in ns.Load(function() ... end), and this file runs those bodies in TOC order
-- on Amisia's ADDON_LOADED, once AmisiaDB (and with it the chosen language) is there; then the core's
-- own ADDON_LOADED (ns.CoreLoaded). A body that fails stops only itself, as a failing file did.
local ADDON, ns = ...
-- the start of loading Amisia's files, for /amisia leistung (Core/Perf.lua, F-184): this is the first file
ns.PERF_T0 = (type(debugprofilestop) == "function" and debugprofilestop())
    or (type(GetTimePreciseSec) == "function" and GetTimePreciseSec() * 1000) or nil

-- AMISIA_LOCALE is the tests' hook to force the client's locale (the client never sets it).
local locale = (type(AMISIA_LOCALE) == "string" and AMISIA_LOCALE) or (GetLocale and GetLocale()) or "deDE"
-- the client's locale (the language of the game's own texts: items, zones, tooltips, chat lines)
ns.LOCALE = locale
-- the language Amisia speaks: set by ns.RunLoad from the setting, until then the client's
ns.CLIENT_LANG = locale == "deDE" and "deDE" or "enUS"
ns.LANG = ns.CLIENT_LANG
ns.GERMAN = ns.LANG == "deDE"
ns.LANGUAGES = { auto = true, deDE = true, enUS = true }

local strings = {}   -- the active language's texts: German key -> text (true: the key itself)
local missing = {}   -- keys asked for in English without an entry (the tests read them)
local settled = false   -- the language is chosen (ns.RunLoad); before it nothing is kept

local function plainKey(k)
    return (k:gsub("##.*$", ""))
end

ns.L = setmetatable({}, { __index = function(t, k)
    if type(k) ~= "string" then return k end
    local v = strings[k]
    if v == true or (v == nil and ns.GERMAN) then
        v = plainKey(k)
    elseif v == nil then
        if settled then missing[k] = true end
        v = plainKey(k)
    end
    if settled then rawset(t, k, v) end
    return v
end })

-- The saved choice ("auto", "deDE", "enUS"); anything else counts as "auto".
function ns.LanguageChoice(db)
    db = db or AmisiaDB
    local ui = type(db) == "table" and type(db.settings) == "table" and db.settings.ui
    local v = type(ui) == "table" and ui.language
    return (type(v) == "string" and ns.LANGUAGES[v]) and v or "auto"
end

-- The files' bodies, in TOC order, until ns.RunLoad runs them; after it a body runs at once (a test
-- that loads one file again).
local bodies, ran = {}, false
function ns.Load(fn)
    if ran then
        fn()
    else
        bodies[#bodies + 1] = fn
    end
end

-- Chooses the language from AmisiaDB and runs the files' bodies (once). Each runs protected: its error
-- goes to the client's error handler and the next body runs.
function ns.RunLoad()
    if ran then return end
    ran = true
    local choice = ns.LanguageChoice()
    ns.LANG = choice == "auto" and ns.CLIENT_LANG or choice
    ns.GERMAN = ns.LANG == "deDE"
    settled = true
    local list = bodies
    bodies = nil
    -- xpcall: the error handler sees the failing body's stack (and its locals), as for a failing file
    local handler = type(geterrorhandler) == "function" and geterrorhandler() or nil
    local function report(err)
        if handler then pcall(handler, err) end
        return err
    end
    for _, fn in ipairs(list) do xpcall(fn, report) end
end

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self, _, name)
        if name ~= ADDON then return end
        self:UnregisterEvent("ADDON_LOADED")
        ns.RunLoad()
        if ns.CoreLoaded then ns.CoreLoaded() end
    end)
end

-- The table a locale file fills, or nil when that language is not the chosen one (the file returns
-- then, so a German Amisia keeps no English texts in memory).
function ns.NewLocale(lang)
    if lang ~= ns.LANG or lang == "deDE" then return nil end
    return strings
end

-- Marks a text the code keeps as it is (a name it compares, stores or sends) and shows later
-- through L[variable]: returns it unchanged; tools/l10n.py counts it as a key.
function ns.N_(s) return s end

-- For the tests: the keys asked for in English that have no entry.
function ns.MissingTranslations() return missing end

---------------------------------------------------------------------------
-- Numbers and dates in the language's form
---------------------------------------------------------------------------
-- A number with up to `decimals` decimals (default 1; whole numbers plain unless decimals is given):
-- "2,5" in German, "2.5" in English.
function ns.Num(x, decimals)
    x = tonumber(x) or 0
    local s
    if not decimals and math.abs(x - math.floor(x + 0.5)) < 0.05 then
        s = tostring(math.floor(x + 0.5))
    else
        s = ("%." .. (decimals or 1) .. "f"):format(x)
    end
    if ns.GERMAN then s = s:gsub("%.", ",") end
    return s
end

local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

-- Day and month: "07.10." in German, "Oct 7" in English.
function ns.FmtDay(t)
    t = t or time()
    if ns.GERMAN then return date("%d.%m.", t) end
    local d = date("*t", t)
    return ("%s %d"):format(MONTHS[d.month], d.day)
end

-- A full date: "07.10.2026" in German, "Oct 7, 2026" in English.
function ns.FmtDate(t)
    t = t or time()
    if ns.GERMAN then return date("%d.%m.%Y", t) end
    local d = date("*t", t)
    return ("%s %d, %d"):format(MONTHS[d.month], d.day, d.year)
end

-- ns.FmtDate of a "2026-10-07"; "?" for anything else.
function ns.LongDate(iso)
    local y, m, d = tostring(iso or ""):match("^(%d+)%-(%d+)%-(%d+)$")
    return y and ns.FmtDate(time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })) or "?"
end

-- Day and time: "07.10. 20:15" in German, "Oct 7 20:15" in English.
function ns.FmtDayTime(t)
    t = t or time()
    return ns.FmtDay(t) .. " " .. date("%H:%M", t)
end
