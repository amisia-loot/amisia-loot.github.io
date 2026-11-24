-- Every player feature has a click path, slash commands are shortcuts (D-167): the link "%d zu übergeben"
-- on the page Vergaben (officer and raider) and on the overview's awards card opens "Noch zu übergeben";
-- the guild queue as a side window of the tab Gilde and in the minimap menu (with the count); the raider's
-- card "Mein Raid-Check" (in a raid, or signed up for tonight); the pull and break timer in the minimap
-- menu while leading; the settings buttons "Probe-Runde zeigen" (Würfel-Fenster) and "Gemerkte Namen
-- vergessen" (Soft-Reserves); an item hit of the search opens a menu (map target, wish list, link); the
-- wish list row's "Notiz ..."; the mage scrolls card under Berufe > Weiteres.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return m end end
    return nil
end
local function labels(entries)
    local out = {}
    for _, e in ipairs(entries) do out[#out + 1] = e[1] end
    return table.concat(out, "|")
end
local function entry(entries, label)
    for _, e in ipairs(entries) do if e[1] == label then return e end end
end
local function setting(key)
    for _, sec in ipairs(NS.schema) do
        for _, it in ipairs(sec.items) do if it.key == key then return it, sec end end
    end
end

STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
assert(NS.Active(), "a recording")
STUB.item(32235, "Cursed Vision of Sargeras", 4)

---------------------------------------------------------------------------
-- 1. "Noch zu übergeben": the link on the page head and on the card
---------------------------------------------------------------------------
local opened = 0
local origShow = NS.ShowHandover
NS.ShowHandover = function() opened = opened + 1; return origShow() end
local origEntries = NS.HandoverEntries
local fake = { { key = "k1", item = 32235, by = "Vuloo" } }
NS.HandoverEntries = function() return fake end
NS.HandoverToText = function() return "Fraktur" end
NS.HandoverLeft = function() return 3000 end
NS.HandoverLeftText = function() return "50 min" end
NS.HandoverItemText = function() return "Cursed Vision" end
NS.ShowPage("awards")
local f = NS.PageFrame("awards")
assert(f.handover:IsShown(), "with an entry the page opens on Noch zu übergeben")
f.handover.back:Click()
assert(f.officer:IsShown() and not f.handover:IsShown(), "Zu den Vergaben puts it away")
local link = f.officer.handover
assert(link:IsShown() and link:GetText() == "1 zu übergeben", "the head's link: " .. tostring(link:GetText()))
assert(not has(f.officer.head:GetText(), "zu übergeben"), "the counts no longer name it: " .. f.officer.head:GetText())
link:Click()
assert(opened == 1 and f.handover:IsShown(), "the link opens Noch zu übergeben")
f.handover.back:Click()
-- the raider view: the link at the right of the head, the footer without a command
NS.Set("ui.view", "raider")
NS.ShowPage("awards")
assert(f.raider:IsShown() and f.raider.handover:IsShown() and f.raider.handover:GetText() == "1 zu übergeben", "the raider's link")
assert(not has(f.raider.text:GetText(), "/amisia"), "no command: " .. f.raider.text:GetText())
f.raider.handover:Click()
assert(opened == 2 and f.handover:IsShown(), "the raider's link opens it")
f.handover.back:Click()
-- the overview's awards card: the second link
NS.ShowPage("overview")
local ov = NS.PageFrame("overview")
local function card(title)
    for _, c in ipairs(ov.cards) do
        if c:IsShown() and c.title:GetText() == title then return c end
    end
end
local ac = card("Deine Items letzte Nacht")
assert(ac and ac.button2:IsShown() and ac.button2:GetText() == "1 zu übergeben", "the card's second link")
ac.button2:Click()
assert(opened == 3 and NS.CurrentPage() == "awards", "the card's link opens it")
f.handover.back:Click()
-- nothing to hand over: no link
fake = {}
NS.ShowPage("awards")
assert(not f.raider.handover:IsShown(), "no entry, no link")
NS.HandoverEntries = origEntries
NS.ShowHandover = origShow
NS.Reset("ui.view")

---------------------------------------------------------------------------
-- 2. the guild queue: a side window of the tab Gilde and a minimap entry with the count
---------------------------------------------------------------------------
NS.ShowPage("members")
local F = AmisiaFrame
local function navRow(kind, key)
    for _, e in ipairs(F.navOrder) do
        if e.entry.kind == kind and e.entry.key == key then return e end
    end
end
local win = navRow("win", "bgqueue")
assert(win, "the tab Gilde lists the window Gilden-Warteschlange")
win.button:Click()
assert(AmisiaGuildQueue and AmisiaGuildQueue:IsShown(), "a click opens it without an own queue")
win = navRow("win", "bgqueue")
win.button:Click()
assert(not AmisiaGuildQueue:IsShown(), "a second click closes it")
local mm = NS.MinimapMenuEntries()
local gq = entry(mm, "Gilden-Warteschlange")
assert(gq and has(gq.tip, "niemand"), "the minimap entry and its tooltip: " .. tostring(gq and gq.tip))
gq[2]()
assert(AmisiaGuildQueue:IsShown(), "the minimap entry opens it")
NS.GuildQueue.Toggle()
STUB.inGuild = false
assert(not entry(NS.MinimapMenuEntries(), "Gilden-Warteschlange"), "no guild, no entry")
STUB.inGuild = nil

---------------------------------------------------------------------------
-- 3. the raider's card "Mein Raid-Check": in a raid group, for whoever has no page Raid-Check
---------------------------------------------------------------------------
NS.ShowPage("overview")
assert((card("Mein Raid-Check") == nil) == NS.RaidCheckAllowed(), "whoever has the page Raid-Check has no card")
NS.Set("ui.view", "raider")
NS.Refresh()
local rc = card("Mein Raid-Check")
assert(rc, "the raider's card in a raid group")
assert(has(rc.line1:GetText(), "Haltbarkeit"), rc.line1:GetText())
local tip = rc.tip()
assert(tip[1] == "Mein Raid-Check" and has(tip[2], "Raid-Check:") and has(tip[#tip], "Raid-IDs"), table.concat(tip, " / "))
STUB.messages = {}
rc.button:Click()
assert(said("Raid-Check:"), "Im Chat zeigen writes the own line")
-- out of the group and without a sign-up: no card
local roster = STUB.roster
STUB.roster = {}
NS.Refresh()
assert(not card("Mein Raid-Check"), "no group, no sign-up: no card")
STUB.roster = roster
NS.Reset("ui.view")

---------------------------------------------------------------------------
-- 7. the pull and break timer in the minimap menu while leading
---------------------------------------------------------------------------
STUB.leader = false
assert(not entry(NS.MinimapMenuEntries(), "Pull-Timer (10 s)"), "not leading: no timer entries")
STUB.leader = true
local pull = entry(NS.MinimapMenuEntries(), ("Pull-Timer (%d s)"):format(NS.Get("pull.seconds")))
assert(pull and pull[2], "leading: the pull timer: " .. labels(NS.MinimapMenuEntries()))
assert(entry(NS.MinimapMenuEntries(), ("Pause (%d min)"):format(NS.Get("pull.minutes"))), "and the break")
STUB.leader = nil

---------------------------------------------------------------------------
-- 5. the settings button "Probe-Runde zeigen" (section Würfel-Fenster)
---------------------------------------------------------------------------
local it, sec = setting("rollwin.test")
assert(it and sec.key == "rollwin" and it.type == "button" and it.label == "Probe-Runde zeigen", "the button")
it.run()
assert(AmisiaRollWindow and AmisiaRollWindow:IsShown(), "it shows a test round")
assert(said("Probe-Runde nur bei dir"), "and says it is only here")

---------------------------------------------------------------------------
-- 10. the settings button "Gemerkte Namen vergessen" (section Soft-Reserves), with a question
---------------------------------------------------------------------------
AmisiaDB.srAliases = { ["vulo"] = "Vuloo", ["frak"] = "Fraktur" }
it, sec = setting("softres.forget")
assert(it and sec.key == "softres" and it.type == "button" and it.officer, "the button (officers)")
it.run()
assert(AmisiaConfirmFrame and AmisiaConfirmFrame:IsShown() and next(AmisiaDB.srAliases), "a question first, nothing gone yet")
AmisiaConfirmFrame.ok:Click()
assert(next(AmisiaDB.srAliases) == nil and said("2 gemerkte Namenskorrekturen vergessen"), "forgotten")

---------------------------------------------------------------------------
-- 6. an item hit of the search: a menu with map target, wish list and link
---------------------------------------------------------------------------
local menu = NS.SearchIndex.ItemMenu(32235)
assert(entry(menu, "Link in den Chat"), labels(menu))
assert(entry(menu, "Auf die Wunschliste"), "the gear module: the wish list: " .. labels(menu))
assert((entry(menu, "Als Ziel auf der Karte") ~= nil) == (NS.MapSetTarget ~= nil and NS.HasData("MAP")), "the map target only with the map data")
STUB.messages = {}
entry(menu, "Auf die Wunschliste")[2]()
local c = NS.BisChar()
assert(c.wish[32235] or said("tragen"), "the wish is added (or the reason said)")
-- the hit itself carries the menu; the main window's click opens it, Shift-click puts the link in
AmisiaDB.itemNames[32235] = { n = "Cursed Vision of Sargeras", q = 4 }
NS.SearchIndex._reset()
local hits
for _, g in ipairs(NS.Search("cursed vision")) do if g.key == "items" then hits = g.hits end end
assert(hits and hits[1].menu and hits[1].item == 32235, "the item hit has a menu")
assert(labels(hits[1].menu()) == labels(menu), labels(hits[1].menu()))

---------------------------------------------------------------------------
-- 6b. the wish list row's "Notiz ...": the note of the wish
---------------------------------------------------------------------------
c.wish[32235] = c.wish[32235] or { t = time(), prio = 2, note = "" }
local dlg = StaticPopupDialogs.AMISIA_WISH_NOTE
assert(dlg and dlg.hasEditBox and dlg.text == "Notiz zum Wunsch:", "the note dialog")
local box = CreateFrame("EditBox")
local d = { editBox = box }
dlg.OnShow(d, 32235)
box:SetText("nur mit Bonus")
dlg.OnAccept(d, 32235)
assert(c.wish[32235].note == "nur mit Bonus", tostring(c.wish[32235].note))
-- the page's row menu offers it for a wish
NS.ShowGear("wish")
local gf = NS.PageFrame("gear")
local wishView = gf.wish
local row
for _, r in ipairs((wishView and wishView.list and wishView.list.rows) or {}) do
    if r.item and r.item.id == 32235 then row = r end
end
assert(row, "the wish's row")
do
    row.scripts.OnClick(row, "RightButton")
    assert(AmisiaMenu and AmisiaMenu:IsShown(), "the row's menu")
    local found = false
    for _, b in ipairs(AmisiaMenu.buttons) do
        if b:IsShown() and b.label:GetText() == "Notiz ..." then
            found = true
            b:Click()
        end
    end
    assert(found and STUB.popup and STUB.popup.which == "AMISIA_WISH_NOTE" and STUB.popup.data == 32235, "Notiz ... opens the dialog")
end

---------------------------------------------------------------------------
-- 8. the mage scrolls under Berufe > Weiteres (Forever, with the data)
---------------------------------------------------------------------------
assert(NS.MageScrolls and NS.MageScrolls.Available(), "the Forever client has the scroll data")
do
    NS.ShowPage("professions")
    local pf = NS.PageFrame("professions")
    local more
    for _, s in ipairs(pf.ovView.secs) do if s.title == "Weiteres" then more = s.cards end end
    local scrolls
    for _, x in ipairs(more or {}) do if x.name == "Schriftrollen" then scrolls = x end end
    assert(scrolls, "the card Schriftrollen")
    scrolls.open()
    assert(NS.CurrentPage() == "scrolls", "it opens the page for any class: " .. tostring(NS.CurrentPage()))
end
print("click paths ok")
