--[[locale enUS]]
-- English for the core: the main window, overview, settings, export, guild bank, about, tools, the
-- self-test, the chat messages and slash commands of Core/ speak English; the German slash words
-- still work; no German umlaut word shows where the texts are translated.
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
local function german(text) return type(text) == "string" and text:find("[\195][\164\182\188\132\150\156\159]") ~= nil end
local function lastMsg() return STUB.messages[#STUB.messages] or "" end

-- every text a frame tree shows, joined
local function texts(frame, out, seen)
    out, seen = out or {}, seen or {}
    if type(frame) ~= "table" or seen[frame] then return out end
    seen[frame] = true
    if frame.GetText and frame.IsShown and frame:IsShown() then
        local ok, t = pcall(frame.GetText, frame)
        if ok and type(t) == "string" and t ~= "" then out[#out + 1] = t end
    end
    for _, v in pairs(frame) do
        if type(v) == "table" and v ~= frame and (v.GetText or v.GetObjectType or #v > 0) then texts(v, out, seen) end
    end
    return out
end
local function shown(frame) return table.concat(texts(frame), "\n") end

-- tooltip lines: the stub's AddLine does nothing, this test keeps them
local tip = {}
GameTooltip.AddLine = function(_, t) tip[#tip + 1] = t end
local function tipText() return table.concat(tip, "\n") end

-- the main window and its head
STUB.officer = true
NS.ShowPage("overview")
local F = AmisiaFrame
assert(F and F:IsShown(), "the window opens")
assert(F.pauseBtn:GetText() == "Pause", F.pauseBtn:GetText())
assert(F.statusText:GetText():find("Not recording, starts in a raid", 1, true), F.statusText:GetText())
local nav = {}
for _, e in ipairs(F.navOrder) do
    if e.button then nav[#nav + 1] = e.button.label:GetText() end
end
nav = table.concat(nav, ", ")
assert(has(nav, "Overview") and has(nav, "Guild bank") and has(nav, "Settings") and has(nav, "About and commands"), nav)
NS.SetEnabled(false)
assert(F.pauseBtn:GetText() == "Resume" and has(F.statusText:GetText(), "Recording paused"), F.statusText:GetText())
NS.SetEnabled(true)
NS.ResetPositions()
assert(lastMsg():find("Window position reset.", 1, true), lastMsg())

-- overview: the empty text and the cards
local ov = NS.OverviewPageFrame()
assert(ov, "overview built")

-- settings: labels, a reset tooltip, the default line, the value words
NS.ShowPage("settings")
local rows = NS.SettingsRows()
local mm = assert(rows["ui.minimap"], "minimap row")
assert(mm.label:GetText() == "Minimap button", mm.label:GetText())
tip = {}
mm:GetScript("OnEnter")(mm)
assert(has(tipText(), "The round Amisia button at the edge of the minimap.") and has(tipText(), "Default: on"), tipText())
local late = assert(rows["record.lateAt"], "late row")
assert(late.label:GetText() == "Raid start (late after)", late.label:GetText())
NS.Set("ui.minimap", false)
NS.Refresh()
tip = {}
mm.reset:GetScript("OnEnter")(mm.reset)
assert(has(tipText(), "Reset") and has(tipText(), "Back to the default."), tipText())
NS.Reset("ui.minimap")
local setText = shown(NS.SettingsPageFrame())
assert(has(setText, "Interface") and has(setText, "Recording"), setText)
assert(not german(setText), "no German on the settings page:\n" .. setText)

-- export: the messages and the page
NS.ShowExport(false)
assert(lastMsg() == "|cffe2b857Amisia:|r No raids and no guild bank count to export yet." , lastMsg())
local ex = NS.ExportPageFrame()
assert(ex.newBtn:GetText() == "New and changed" and ex.selBtn:GetText() == "Ticked", ex.newBtn:GetText())
assert(ex.hint:GetText() == "Ctrl+A, Ctrl+C, paste in the Import tab.", ex.hint:GetText())
assert(not german(shown(ex)), shown(ex))

-- guild bank: the page and its card, the date the English way
NS.MATS[12345], NS.MAT_ORDER[1] = "Testerz", 12345
NS.ShowPage("bank")
local bank = NS.BankPageFrame()
assert(bank.add.button:GetText() == "Add", bank.add.button:GetText())
assert(has(bank.state:GetText(), "Not counted yet.") and has(bank.state:GetText(), "1 of"), bank.state:GetText())
AmisiaDB.bank = { at = time({ year = 2026, month = 10, day = 7, hour = 20, min = 15 }), counts = { [12345] = 7 },
    tabs = 2, filled = 1, total = 3, by = "Vuloo" }
NS.Refresh()
local st = bank.state:GetText()
assert(has(st, "Counted Oct 7, 2026 20:15 by Vuloo · 1 of 2 visible tabs with items") and has(st, "1 tabs not visible"), st)
assert(not german(shown(bank)), shown(bank))
local card
for _, spec in ipairs(NS.cards) do if spec.key == "bank" then card = spec end end
local c = { text = {} }
c.title = { SetText = function(_, t) c.text.title = t end }
c.line1 = { SetText = function(_, t) c.text.line1 = t end }
c.line2 = { SetText = function(_, t) c.text.line2 = t end }
c.SetAction = function(_, label) c.text.action = label end
card.fill(c)
assert(c.text.title == "Guild bank" and c.text.line1 == "Counted Oct 7 20:15" and c.text.action == "View", tostring(c.text.line1))
AmisiaDB.bank = nil
NS.MATS[12345], NS.MAT_ORDER[1] = nil, nil

-- about: the head, the buttons and the commands with their English words
NS.ShowPage("about")
local ab = NS.AboutPageFrame()
assert(has(ab.head:GetText(), "sync protocol"), ab.head:GetText())
assert(ab.askGuild:GetText() == "Ask guild" and ab.askRaid:GetText() == "Ask raid" and ab.selfTest:GetText() == "Self-test")
assert(ab.cmdTitle:GetText() == "Commands")
local help = table.concat(NS.SlashHelpLines(true), "\n")
for _, w in ipairs({ "/amisia settings - open the settings", "/amisia selftest [short] [waypoint] [calendar] - checks the client",
                     "/amisia late <HH:MM>|off - raid start", "/amisia names - shows how Amisia reads names",
                     "/amisia help - all commands", "/amisia sync [now|on|off|ranks|debug|selftest] - state of the sync" }) do
    assert(has(help, w), w .. "\n" .. help)
end
assert(not german(help), help)

-- tools (expert mode)
NS.Set("ui.expert", true)
NS.ShowPage("tools")
local tl = NS.ToolsPageFrame()
assert(tl and has(tl.hint:GetText(), "The scan runs only outside instances."), tl and tl.hint:GetText())
assert(tl.drops.web:GetText() == "Drops for the website", tl.drops.web:GetText())
assert(has(tl.drops.state:GetText(), "No kills yet."), tl.drops.state:GetText())
assert(not german(shown(tl)), shown(tl))
NS.Reset("ui.expert")

-- the self-test: English marks and sections, the short variant
local R = NS.SelfTest.Run()
assert(has(R.text, "Amisia self-test ") and R.text:find("\nResult: %d+ OK, %d+ MISSING, %d+ ERROR, %d+ VALUE"), R.text:sub(1, 300))
assert(has(R.text, "== Lockdowns now ==") and has(R.text, "== Saved data ==") and has(R.text, "\nVALUE  Time: "), "sections")
assert(not R.text:find("\nFEHLT ") and not R.text:find("\nWERT "), "no German mark")
assert(R.counts.WERT > 0, "the counts keep their codes")
STUB.messages = {}
SlashCmdList.AMISIA("selbsttest kurz")
assert(has(STUB.messages[1], "Self-test: "), STUB.messages[1])
STUB.messages = {}
SlashCmdList.AMISIA("selftest short")
assert(has(STUB.messages[1], "Full report: /amisia selftest"), STUB.messages[1])

-- slash commands of the core: English words, German ones still work
STUB.messages = {}
SlashCmdList.AMISIA("late off")
assert(lastMsg():find("Late arrivals are no longer marked.", 1, true), lastMsg())
SlashCmdList.AMISIA("spaet 20:00")
assert(lastMsg():find("Raid start 20:00: whoever first shows up", 1, true), lastMsg())
SlashCmdList.AMISIA("late")
assert(lastMsg():find("/amisia late off turns it off.", 1, true), lastMsg())
SlashCmdList.AMISIA("late off")
SlashCmdList.AMISIA("status")
assert(has(table.concat(STUB.messages, "\n"), "Not recording. It starts in a raid instance with a raid group."), lastMsg())
SlashCmdList.AMISIA("sync debug")
assert(lastMsg() == "|cffe2b857Amisia:|r Expert mode only.", lastMsg())
SlashCmdList.AMISIA("sync nonsense")
assert(lastMsg() == "|cffe2b857Amisia:|r Usage: /amisia sync [now|on|off|ranks|debug|selftest]", lastMsg())
SlashCmdList.AMISIA("wortgibtsnicht")
assert(has(table.concat(STUB.messages, "\n"), "Unknown command \"wortgibtsnicht\"."), "unknown command")
AmisiaFrame:Hide()
SlashCmdList.AMISIA("settings")
assert(AmisiaFrame:IsShown() and NS.CurrentPage() == "settings", "the English word opens the settings")
AmisiaFrame:Hide()
SlashCmdList.AMISIA("einstellungen")
assert(AmisiaFrame:IsShown() and NS.CurrentPage() == "settings", "the German word too")

-- numbers and the time words of the settings
assert(NS.FormatTime(nil) == "off" and NS.FormatTime(20 * 60) == "20:00")
assert(NS.ParseTime("off", true) == false and NS.ParseTime("aus", true) == false)
