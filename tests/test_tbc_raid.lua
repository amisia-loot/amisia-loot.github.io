--[[game tbc]]
-- The raid part alone on TBC Anniversary (F-126, D-57): only the files without the camelot load
-- condition, WOW_PROJECT_ID 5, the classic tab template, the client's missing atlases and templates
-- (run.py). Amisia loads, the side bar shows the raid groups only and their names fit (D-68), the settings, the
-- raid pages and the self-test run without an error, the Forever-only parts are hidden.
local T = NS.Theme
assert(NS.GAME == "tbc" and NS.FOREVER == false, "the client: " .. tostring(NS.GAME))

-- the Forever files did not load: no gear, collectors, duels, trade helper, export page
assert(NS.Gear == nil and NS.Talents == nil and NS.ShowGear == nil and NS.Duels == nil, "no Forever module")
assert(NS.HandoverList == nil and NS.ShowExport == nil, "no trade helper, no export page")
for _, key in ipairs({ "gear", "dungeons", "raidjournal", "map", "quests", "professions", "talents", "scrolls", "duels",
                       "tools", "export" }) do
    assert(NS.Panel(key) == nil, "no page " .. key)
end
for _, key in ipairs({ "bis", "crafters", "wishes", "map", "quests", "collect", "drops", "duels", "tools", "trade" }) do
    for _, sec in ipairs(NS.schema) do assert(sec.key ~= key, "no settings section " .. key) end
end
-- hidden off Forever by the switch
assert(not NS.Visible(NS.SettingItem("ui.talentScale")) and not NS.Visible(NS.SettingItem("ui.goalScale")))
assert(not NS.Visible(NS.SettingItem("record.exportWarn")), "no export reminder")
assert(not NS.Visible({ forever = true }) and NS.Visible({}), "the switch")
-- the export command is gone, its help line too
STUB.officer = true
NS.Set("ui.view", "officer")
STUB.messages = {}
NS.Dispatch("export")
assert(table.concat(STUB.messages, "\n"):find("Unbekannter Befehl", 1, true), table.concat(STUB.messages, "\n"))
for _, line in ipairs(NS.SlashHelpLines(true)) do assert(not line:find("/amisia export ", 1, true), line) end

-- a raid night: recording, a boss kill, a loot window, a loot message, a trade window and the timers of
-- an hour run without a Forever part (nothing calls into a file that did not load)
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.fire("PLAYER_LOGIN")
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(s, "recording on TBC")
STUB.fire("ENCOUNTER_START", 601, "Hochkriegsfürst Naj'entus", 4, 25)
STUB.tick(60)
STUB.fire("ENCOUNTER_END", 601, "Hochkriegsfürst Naj'entus", 4, 25, 1)
STUB.tick(5)
assert(#s.kills == 1, "the kill: " .. #s.kills)
local ring = "|cffa335ee|Hitem:32238::::::::70:::::|h[Ring]|h|r"
STUB.loot = { { link = ring, name = "Ring", src = "Creature-0-0-0-0-22887-0" } }
STUB.fire("LOOT_OPENED"); STUB.fire("LOOT_CLOSED")
STUB.fire("CHAT_MSG_LOOT", "Fraktur erhält Beute: " .. ring .. ".", "", "", "", "Fraktur")
STUB.fire("BAG_UPDATE_DELAYED")
STUB.fire("TRADE_SHOW"); STUB.fire("TRADE_CLOSED")
STUB.fire("GROUP_ROSTER_UPDATE")
STUB.fire("READY_CHECK", "Vuloo", 30)
STUB.fire("QUEST_LOG_UPDATE"); STUB.fire("ZONE_CHANGED_NEW_AREA"); STUB.fire("UPDATE_INSTANCE_INFO")
STUB.tick(3600)

-- the window: the groups Raid, Gilde (with the calendar) and Amisia in the side bar, Charakter and Welt
-- (Forever pages only) left out
NS.ToggleMain()
local F = AmisiaFrame
assert(F and F:IsShown(), "the window opens")
-- the side bar (D-68): a bar per group with a visible page; nothing under or beside the window
local function groupBars()
    local out = {}
    for _, e in ipairs(F.nav.items) do
        if e.kind == "cat" then out[#out + 1] = e.key end
    end
    return table.concat(out, " ")
end
-- the group bars (in place of the tabs under the window) inside the side bar, their names fit
local function barsFit()
    assert(F.nav:GetWidth() <= T.MAIN.NAV_W, "the side bar inside its inset: " .. F.nav:GetWidth())
    for _, e in ipairs(F.navOrder) do
        local b = e.button
        assert(b:IsShown(), e.entry.key)
        assert(e.entry.kind ~= "cat" or b.label:GetStringWidth() <= b.label:GetWidth() + 0.5,
            "the group's name fits its bar: " .. e.entry.key .. " " .. b.label:GetStringWidth() .. " > " .. b.label:GetWidth())
    end
end
assert(F.tabs == nil and F.sideTabs == nil and F.tabOrder == nil, "no tabs under or beside the window")
assert(groupBars() == "raid guild amisia", groupBars())
-- the officer view: the roll window and the soft-reserve import under Raid
NS.ShowTab("raid")
local wins = {}
for _, e in ipairs(F.navOrder) do if e.entry.kind == "win" then wins[#wins + 1] = e.entry.key end end
assert(table.concat(wins, " ") == "softres rolls", table.concat(wins, " "))
STUB.fire("DISPLAY_SIZE_CHANGED")
for _, key in ipairs({ "raid", "guild", "amisia" }) do
    NS.ShowTab(key)
    barsFit()
end
assert(groupBars() == "raid guild amisia", "after a display change: " .. groupBars())

-- every raid page opens
for _, key in ipairs({ "overview", "raids", "lineup", "raidcheck", "raidlog", "rolls", "awards", "stats", "points",
                       "softres", "members", "bank", "calendar", "about" }) do
    if NS.Visible(NS.Panel(key)) then
        NS.ShowPage(key)
        assert(NS.CurrentPage() == key, "the page " .. key .. ": " .. tostring(NS.CurrentPage()))
    end
end

-- the raid check without the buff list: the view Buffs & Verbrauch is gone, Ausrüstung shows
NS.ShowRaidCheck("buffs")
local rc = NS.PageFrame("raidcheck")
if rc then
    assert(not rc.views.buffs:IsShown() and rc.gearView:IsShown() and not rc.buffView:IsShown(), "the gear view instead")
end

-- the settings: the stepper's arrows draw the classic textures, the reset button stands right of its control
NS.Dispatch("einstellungen")
assert(NS.CurrentPage() == "settings")
NS.Set("record.enabled", false)
NS.Refresh()
local rows = NS.SettingsRows()
local keep = rows["record.keepSessions"]
assert(keep and keep.control.minus.arrowSet.texture and keep.control.minus.arrow.texture == "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up",
    "the classic arrow: " .. tostring(keep and keep.control.minus.arrow.texture))
assert(keep.control.plus.arrow.texture == "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
local rec = rows["record.enabled"]
local p = rec.reset.points.LEFT
assert(p and p.rel == rec.control and p.relPoint == "RIGHT" and p.x == 8, "the reset button right of the checkbox")
assert(rec.reset:IsShown(), "changed: the reset button shows")
-- the settings groups: no Ausrüstung, no PvP
for _, g in ipairs(NS.SettingsGroups()) do assert(g.key ~= "gear" and g.key ~= "pvp", "no group " .. g.key) end

-- item tooltips: the old way (OnTooltipSetItem), one line per part even when the data processor fires too
AmisiaDB.softres = { at = time(), list = { { name = "Vuloo", item = 30107 } } }
local count = 0
NS.OnItemTooltip("probe", function(tip, link, id) count = count + 1; tip:AddLine("probe " .. id); return true end)
GameTooltip.GetItem = function() return "x", "|cffa335ee|Hitem:30107::::::::70:::::|h[x]|h|r" end
assert(GameTooltip.scripts.OnTooltipSetItem, "the old tooltip hook")
GameTooltip.scripts.OnTooltipSetItem(GameTooltip)
GameTooltip.scripts.OnTooltipSetItem(GameTooltip)
STUB.showTooltip(GameTooltip, "|cffa335ee|Hitem:30107::::::::70:::::|h[x]|h|r")
assert(count == 1, "one line per item: " .. count)

-- the self-test runs and names the client; no required template is missing
local R = NS.SelfTest.Run()
assert(R.text:find("TBC Anniversary (nur der Raid-Teil)", 1, true), "the client in the self-test")
for line in R.text:gmatch("[^\n]+") do
    if line:find("Template", 1, true) then assert(not line:find("FEHLT", 1, true), line) end
end
assert(not R.text:find("Pin-Ebene der Weltkarte", 1, true), "no map pin check off Forever")
print("tbc raid ok")
