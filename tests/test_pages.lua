-- Every page builds and refreshes; officer pages hide for raiders; the settings page writes settings.
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
_G.UnitClass = function() return "Priester", "PRIEST" end
_G.UnitLevel = function() return 24 end
_G.UnitFactionGroup = function() return "Alliance" end
_G.GetInventoryItemLink = function() return nil end

for _, key in ipairs({ "overview", "raids", "raidlog", "export", "rolls", "softres", "bank", "settings", "about" }) do
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
NS.ShowPage("raidlog"); assert(NS.CurrentPage() == "raidlog", "the raid log is for everyone")
assert(NS.RaidLogPageFrame() and NS.RaidLogPageFrame().log, "the raid log page builds")
NS.Reset("ui.view")

-- the overview shows cards
NS.ShowPage("overview")
local panelFrame = AmisiaFrame and true
assert(panelFrame)

-- 2.2 layout of the raid pages at 602 x 478: overview cards are insets that fill the width exactly
local ov = NS.OverviewPageFrame()
assert(ov.cards[1]:IsShown(), "a card is shown")
do
    local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(ov, 602, 478)
    for i = 1, 5, 2 do L.row("overview cards " .. i, ov.cards[i], ov.cards[i + 1]) end
    L.column("overview left", ov.cards[1], ov.cards[3], ov.cards[5])
    L.column("overview right", ov.cards[2], ov.cards[4], ov.cards[6])
    for i, c in ipairs(ov.cards) do
        L.inside("overview card " .. i, c)
        assert(c.border and c.border.atlas == "common-insideframe", "card " .. i .. " is Forever's inset")
    end
    local _, r = L.span(ov.cards[2])
    assert(r == 602, "the right card ends at the edge: " .. r)
end
-- the raids page: the list leaves 12 px for its bar, the detail text's bar sits under it
NS.ShowPage("raids")
local rp = NS.RaidsPageFrame()
do
    local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(rp, 602, 478)
    L.row("raids list", rp.list, rp.list.bar)
    L.inside("raids list bar", rp.list.bar)
    local _, r = L.span(rp.list)
    assert(r == 590, "the raids list is 590 wide: " .. r)
    local r1 = rp.list.rows[1]
    L.row("raids row", r1.box, r1.date, r1.zone, r1.raiders, r1.mats[1], r1.mats[2])
    local _, gr = L.span(r1.gems)
    assert(gr <= 590, "the last column ends in the row: " .. gr)
    L.row("raids buttons", rp.pageText, rp.all, rp.del)
    L.row("raids detail", rp.detail, rp.detail.bar)
    L.inside("raids detail bar", rp.detail.bar)
    -- the head row (count and buttons), the list, the chosen raid
    L.column("raids page", rp.del, rp.list, rp.detail)
    assert(r1.sel.atlas == "Professions_Recipe_Active" and r1.sel:IsShown(), "the shown raid glows like the recipe list's")
end
NS.ShowPage("overview")

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

-- a text row writes its setting on Enter, refuses what validate refuses, and keeps the typed text
-- while it has the focus
local bank = rows["awards.bankName"]
assert(bank and bank.control and bank.control:GetText() == "", "the text row is built for officers")
bank.control:SetFocus(); bank.control:SetText("Vulobank"); bank.control.scripts.OnEnterPressed(bank.control)
assert(NS.Get("awards.bankName") == "Vulobank", tostring(NS.Get("awards.bankName")))
assert(bank.control:GetText() == "Vulobank" and bank.dot:IsShown(), "the row shows the stored value and the changed dot")
local msgs = #STUB.messages
bank.control:SetFocus(); bank.control:SetText("Vulo1"); bank.control.scripts.OnEnterPressed(bank.control)
assert(NS.Get("awards.bankName") == "Vulobank", "a name with digits is refused")
assert(#STUB.messages == msgs + 1 and STUB.messages[#STUB.messages]:find("Ziffern", 1, true), "the reason goes to the chat")
assert(bank.control:GetText() == "Vulobank", "the refresh puts the stored value back")
bank.control:SetFocus(); bank.control:SetText("Vul")
NS.Refresh()
assert(bank.control:GetText() == "Vul", "a refresh leaves a focused box alone")
bank.control:ClearFocus()
assert(NS.Get("awards.bankName") == "Vul", "leaving the box commits")
bank.reset:Click()
assert(NS.Get("awards.bankName") == "" and bank.control:GetText() == "", "reset empties the box")

-- roll history feeds the rolls page
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
assert(NS.StartRoll(link, 5)); NS.StopRoll()
assert(#NS.RollHistory() >= 1)
NS.ShowPage("rolls")
do
    local rf = NS.RollsPageFrame()
    local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(rf, 602, 478)
    L.row("rolls list", rf.list, rf.list.bar)
    L.inside("rolls list bar", rf.list.bar)
    local _, r = L.span(rf.list)
    assert(r == 590, "the rolls list is 590 wide: " .. r)
    local _, tr = L.span(rf.list.rows[1].text)
    assert(tr <= 590, "the round text ends in the row: " .. tr)
    L.column("rolls page", rf.current, rf.list)
    L.inside("rolls list", rf.list)
end

-- 2.2 layout of the guild and Amisia pages at 602 x 478
-- export: the edit area with its thin bar inside the page
NS.ShowPage("export")
do
    local ef = NS.ExportPageFrame()
    local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(ef, 602, 478)
    L.row("export buttons", ef.newBtn, ef.selBtn, ef.state)
    -- the head row (buttons), the line under it, the text, the footer
    L.column("export page", ef.newBtn, ef.intro, ef.area, ef.hint)
    L.inside("export area", ef.area)
    assert(ef.area.bar and ef.area.bar.inherits.MinimalScrollBar, "the export text scrolls with the thin bar")
    L.inside("export bar", ef.area.bar)
    assert(ef.area.border.atlas == "common-insideframe", "the export text lies in an inset")
    assert(ef.newBtn.inherits.SharedButtonSmallTemplate and ef.selBtn.inherits.SharedButtonSmallTemplate)
end
-- guild bank: the list ends 12 px before the edge, the count and the button move with it
NS.ShowPage("bank")
do
    local bf = NS.BankPageFrame()
    local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(bf, 602, 478)
    L.row("bank editor", bf.add.box, bf.add.button, bf.add.hint)
    L.row("bank list", bf.list, bf.list.bar)
    L.inside("bank list bar", bf.list.bar)
    local _, lr = L.span(bf.list)
    assert(lr == 590, "the bank list is 590 wide: " .. lr)
    local r1 = bf.list.rows[1]
    L.row("bank row", r1.name, r1.count, r1.remove)
    local _, rr = L.span(r1.remove)
    assert(rr == 586, "the button keeps its 4 px to the row's end: " .. rr)
    L.column("bank page", bf.state, bf.add.box, bf.list)
    L.inside("bank list", bf.list)
    assert(bf.add.box.inherits.InputBoxTemplate, "the link box is the client's input box")
end
-- tools: the red buttons in a row
NS.Set("ui.expert", true)
NS.ShowPage("tools")
do
    local tf = NS.ToolsPageFrame()
    local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(tf, 602, 478)
    L.row("tools buttons", unpack(tf.buttons))
    L.column("tools page", tf.buttons[1], tf.state, tf.hint)
    for _, b in ipairs(tf.buttons) do assert(b.inherits.SharedButtonSmallTemplate and b._h == 22) end
end
NS.Reset("ui.expert")
-- settings: a plain scroll frame with the thin bar, the sections under the client's list header
NS.ShowPage("settings")
do
    local sp = NS.SettingsPageFrame()
    local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(sp, 602, 478)
    assert(sp.scroll.inherits == nil, "no old scroll frame template")
    assert(sp.bar and sp.bar.inherits.MinimalScrollBar and sp.scroll.bar == sp.bar)
    L.row("settings scroll", sp.scroll, sp.bar)
    L.inside("settings bar", sp.bar)
    local _, sr = L.span(sp.scroll)
    assert(sr == 586, "the rows' frame ends 16 px before the edge: " .. sr)
    local CL = dofile(ADDON_DIR .. "/../tests/layout.lua")(sp.child, 560, sp.child._h)
    local parts, heads = {}, 0
    for _, h in pairs(sp.headers) do
        if h:IsShown() then
            heads = heads + 1
            parts[#parts + 1] = h
            assert(h.inherits.ListHeaderVisualTemplate and h.inherits.ListHeaderCodeTemplate and h._h == 25, "a list header, 25 high")
            assert(not h.CollapseButton:IsShown(), "a settings section does not collapse")
            assert(h.titleColors[false] == NORMAL_FONT_COLOR, "gold like the recipe list's")
            local hl, hr = CL.span(h)
            assert(hl == 0 and hr == 560, "the bar over the row width: " .. hl .. ".." .. hr)
        end
    end
    for _, r in pairs(NS.SettingsRows()) do
        if r:IsShown() then
            parts[#parts + 1] = r
            assert(r._w == 560, "rows stay 560 wide")
            if r.reset then local _, rr = CL.span(r.reset); assert(rr <= 560) end
        end
    end
    assert(heads >= 3, "the sections show: " .. heads)
    table.sort(parts, function(a, b) return a.points.TOPLEFT.y > b.points.TOPLEFT.y end)
    CL.column("settings sections", unpack(parts))
    -- the first section starts with its bar, its first row right under it
    assert(parts[1].inherits and parts[1].points.TOPLEFT.y == 0 and parts[2].points.TOPLEFT.y == -25, "a bar of 25, then the rows")
end
-- about: the list and the commands end 12 px before the edge, their bars inside the page
NS.ShowPage("about")
do
    local af = NS.AboutPageFrame()
    local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(af, 602, 478)
    L.row("about head", af.title, af.askRaid, af.askGuild)
    L.row("about list", af.list, af.list.bar)
    L.inside("about list bar", af.list.bar)
    local _, lr = L.span(af.list)
    assert(lr == 590, "the about list is 590 wide: " .. lr)
    local _, cr = L.span(af.list.rows[1].last)
    assert(cr <= 590, "the last column ends in the row: " .. cr)
    L.row("about commands", af.text, af.text.bar)
    L.inside("about commands bar", af.text.bar)
    L.column("about page", af.head, af.sub, af.title, af.summary, af.cols[1], af.list, af.cmdTitle, af.text)
end
NS.ShowPage("overview")

-- the soft-reserves page fills its list without losing the row text
local errs = {}
local oldHandler = geterrorhandler
_G.geterrorhandler = function() return function(e) errs[#errs + 1] = e end end
NS.SetSoftRes("Vuloo " .. link .. "\nFraktur 32235\n")
NS.ShowPage("softres"); NS.Refresh(); NS.Refresh()
assert(#errs == 0, "softres page: " .. tostring(errs[1]))
_G.geterrorhandler = oldHandler
NS.ClearSoftRes()

-- a raider's /amisia export shows nothing, so nothing is marked as exported
NS.Set("ui.view", "raider")
AmisiaDB.exported = {}
local before = NS.ExportState(NS.Active())
assert(before == "new")
NS.ShowExport(true)
assert(NS.ExportState(NS.Active()) == before, "raider export marks nothing")
NS.Reset("ui.view")

-- the quick menu closes on a second click from the same owner
local m = NS.W.Menu(UIParent, { { "Eins", function() end } })
assert(m:IsShown())
NS.W.Menu(UIParent, { { "Eins", function() end } })
assert(not m:IsShown(), "second click closes the menu")

-- the gear page with the real Forever data: every view builds and refreshes, for officers and raiders
for _, view in ipairs({ "officer", "raider" }) do
    NS.Set("ui.view", view)
    for _, v in ipairs({ "goals", "here", "dungeons", "wish", "guild" }) do
        NS.ShowGear(v)
        NS.Refresh()
        assert(NS.CurrentPage() == "gear", "the gear page in " .. v)
    end
end
NS.Reset("ui.view")
-- the map page with the real Forever map data: builds and refreshes for officers and raiders, in
-- the quick menu for both (with the level-range table), and its parts fit the content at 602 x 478
assert(NS.MAP and NS.Visible(NS.Panel("map")), "the map page with MapData.lua")
for _, view in ipairs({ "officer", "raider" }) do
    NS.Set("ui.view", view)
    NS.ShowMap()
    NS.Refresh()
    assert(NS.CurrentPage() == "map", "the map page for " .. view)
    local quick = {}
    for _, e in ipairs(NS.MinimapMenuEntries()) do quick[#quick + 1] = e[1] end
    assert(table.concat(quick, "|"):find("Ausrüstung|Ausrüstungstabelle|Karte|", 1, true), "the quick menu for " .. view)
    local mf = NS.MapPageFrame()
    local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(mf, 602, 478)
    L.row(view .. " map head", mf.zone, mf.targets, mf.wishes, mf.open)
    L.row(view .. " map target", mf.target, mf.clear)
    L.row(view .. " map columns", mf.head.kind, mf.head.src, mf.head.where, mf.head.items, mf.head.go)
    L.row(view .. " map list", mf.list, mf.list.bar)
    L.inside(view .. " map list bar", mf.list.bar)
    L.column(view .. " map page", mf.zone, mf.counts, mf.target, mf.head.kind, mf.list, mf.showHidden, mf.hint, mf.data)
    L.fits(mf.hint); L.fits(mf.data); L.fits(mf.counts); L.fits(mf.target)
end
NS.Reset("ui.view")
local gp = NS.GearPageFrame()
assert(gp and gp.goals and #gp.goals.list.items == 17, "all slots on the real data")
NS.ShowPage("overview")
NS.Refresh()
