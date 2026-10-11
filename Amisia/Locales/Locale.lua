-- Amisia's languages: German and English, the client's locale decides (deDE: German, every other
-- locale: English). German is the source text in the code: every text for the screen or the chat
-- goes through L["German text"], and Locales/enUS.lua gives its English. A key without an entry
-- shows as it stands (German). A key may carry a context after "##" ("Aus##Ansage") when one German
-- text needs two English ones; the German text is the part before "##".
-- Loaded first (before the registry), so every file can use ns.L while it loads.
local ADDON, ns = ...

-- AMISIA_LOCALE is the tests' hook to force a locale (the client never sets it).
local locale = (type(AMISIA_LOCALE) == "string" and AMISIA_LOCALE) or (GetLocale and GetLocale()) or "deDE"
ns.LOCALE = locale
ns.GERMAN = locale == "deDE"
-- the language of the texts: deDE, or enUS for every other locale
ns.LANG = ns.GERMAN and "deDE" or "enUS"

local strings = {}   -- the active language's texts: German key -> text (true: the key itself)
local missing = {}   -- keys asked for in English without an entry (the tests read them)

local function plainKey(k)
    return (k:gsub("##.*$", ""))
end

ns.L = setmetatable({}, { __index = function(t, k)
    if type(k) ~= "string" then return k end
    local v = strings[k]
    if v == true or (v == nil and ns.GERMAN) then
        v = plainKey(k)
    elseif v == nil then
        missing[k] = true
        v = plainKey(k)
    end
    rawset(t, k, v)
    return v
end })

-- The table a locale file fills, or nil when that language is not the client's (the file returns
-- then, so a German client keeps no English texts in memory).
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

-- Day and time: "07.10. 20:15" in German, "Oct 7 20:15" in English.
function ns.FmtDayTime(t)
    t = t or time()
    return ns.FmtDay(t) .. " " .. date("%H:%M", t)
end
