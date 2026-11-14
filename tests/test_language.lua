--[[preload
AmisiaDB = { settings = { ui = { language = "enUS" } } }
]]
-- The language choice (F-199, D-128): a German client with "English" chosen runs Amisia in English
-- (texts, numbers, dates), the game's own locale stays German; the command and the setting change the
-- choice for the next /reload, the setting asks to reload, a broken choice counts as "auto".
local L = NS.L
assert(NS.LOCALE == "deDE" and NS.CLIENT_LANG == "deDE", "the client stays German")
assert(NS.LANG == "enUS" and NS.GERMAN == false, "Amisia speaks English")
assert(L["Gilde"] == "Guild" and L["Einstellungen"] == "Settings", L["Gilde"])
assert(NS.Num(2.5) == "2.5", NS.Num(2.5))
assert(NS.FmtDate(time({ year = 2026, month = 10, day = 7, hour = 12 })) == "Oct 7, 2026")
assert(NS.SlashWord({ word = "sprache", en = "language" }) == "language")
-- the files' bodies ran once, in TOC order; a body handed in afterwards runs at once
local ranNow
NS.Load(function() ranNow = true end)
assert(ranNow, "a late body runs at once")
-- a page built in English
NS.ShowPage("about")
assert(NS.Get("ui.language") == "enUS")

-- a broken or unknown choice counts as "auto"
assert(NS.LanguageChoice({ settings = { ui = { language = "frFR" } } }) == "auto")
assert(NS.LanguageChoice({ settings = { ui = 5 } }) == "auto")
assert(NS.LanguageChoice({}) == "auto")

-- the command: no question, a chat line, the choice saved for the next /reload
local function lastMsg() return STUB.messages[#STUB.messages] or "" end
SlashCmdList.AMISIA("language auto")
assert(AmisiaDB.settings.ui.language == "auto", tostring(AmisiaDB.settings.ui.language))
assert(lastMsg():find("Language: Deutsch, after /reload.", 1, true), lastMsg())
assert(not (_G.AmisiaConfirmFrame and _G.AmisiaConfirmFrame:IsShown()), "the command asks nothing")
SlashCmdList.AMISIA("language en")
assert(AmisiaDB.settings.ui.language == "enUS" and lastMsg():find("Language: English.", 1, true), lastMsg())
SlashCmdList.AMISIA("language")
assert(lastMsg():find("setting: English", 1, true), lastMsg())
SlashCmdList.AMISIA("language xx")
assert(AmisiaDB.settings.ui.language == "enUS", "an unknown word changes nothing")

-- the setting: another language asks to reload; the same one does not
local reloaded = 0
_G.ReloadUI = function() reloaded = reloaded + 1 end
assert(NS.Set("ui.language", "deDE"))
local C = _G.AmisiaConfirmFrame
assert(C and C:IsShown(), "asks to reload")
C.ok:Click()
assert(reloaded == 1, "reloads")
NS.Set("ui.language", "enUS")
assert(not C:IsShown(), "the language it runs in: no question")
-- the entry names the client's language, "Deutsch" and "English" in their own words
local it = NS.SettingItem("ui.language")
assert(it.values[1][2] == "Like the client (Deutsch)" and it.values[2][2] == "Deutsch" and it.values[3][2] == "English",
    it.values[1][2])
print("language ok")
