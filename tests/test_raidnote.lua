-- The raid note on one client (F-196, Raid/RaidNote.lua): the text as the window shows it (defused,
-- raid marks, names in class colour, the own lines in gold), the limits, the templates, the own note,
-- who may send, the window (place, size, lock, reset) and the page.
local RN = NS.RaidNote
local function has(s, part) return type(s) == "string" and s:find(part, 1, true) ~= nil end

STUB.fire("PLAYER_LOGIN")

-- rendering: marks, names, the own lines, a foreign code defused
local roster = { { name = "Anna Bergmann", class = "PRIEST" }, { name = "Bob Eisherz", class = "WARRIOR" },
    { name = "Bob Fels", class = "ROGUE" } }
local out = RN.Render("{totenkopf} Tank: Bob Eisherz\n{star} Kick: Anna\nHeal |cffff0000rot|r {unbekannt}", { roster = roster, self = "Anna Bergmann" })
local l1, l2, l3 = out:match("^(.-)\n(.-)\n(.-)$")
assert(has(l1, "UI-RaidTargetingIcon_8") and has(l1, "|cffc79c6eBob Eisherz|r"), l1)
assert(not has(l1, "|cffffd100"), "not the player's line")
assert(has(l2, "UI-RaidTargetingIcon_1") and l2:sub(1, 10) == "|cffffd100", "the own line in gold (by the first name): " .. l2)
assert(has(l2, "Anna|r|cffffd100"), "gold again after the name")
assert(has(l3, "||cffff0000rot||r") and has(l3, "{unbekannt}"), "a foreign code stays text: " .. l3)
-- "Bob" alone is two members: no colour for the first name
local bob = RN.Render("Bob soll", { roster = roster, self = "Zed" })
assert(bob == "Bob soll", bob)
-- a name inside a longer word is no name
assert(RN.Render("Annabell", { roster = roster, self = "Zed" }) == "Annabell")
for word, i in pairs({ rt3 = 3, Kreuz = 7, MOON = 5 }) do
    assert(has(RN.Render("{" .. word .. "}", { roster = {}, self = "Zed" }), "Icon_" .. i), word)
end

-- names that start or end with a letter beyond ASCII; a name inside a longer word is none
local uroster = { { name = "Öl Pala", class = "WARRIOR" }, { name = "Zoë Hall", class = "SHAMAN" }, { name = "Ari Stein", class = "PRIEST" } }
local u = RN.Render("Öl Pala dispel\nZoë Hall tank\nArië", { roster = uroster, self = "Zed" })
assert(has(u, "Öl Pala|r") and has(u, "Zoë Hall|r") and not has(u, "Ari|r"), u)
assert(RN.Render("Öl kommt", { roster = uroster, self = "Öl Pala" }):sub(1, 10) == "|cffffd100", "gold by an umlaut first name")
-- two members with the player's first name: no gold by the first name alone
local two = { { name = "Max Eins", class = "MAGE" }, { name = "Max Zwei", class = "MAGE" } }
assert(RN.Render("Max: Kick", { roster = two, self = "Max Eins" }):sub(1, 10) ~= "|cffffd100", "ambiguous first name")
assert(RN.Render("Max Eins: Kick", { roster = two, self = "Max Eins" }):sub(1, 10) == "|cffffd100", "the full name")
-- old and future notes are not fresh
assert(RN.Fresh(NS.ServerTime()) and not RN.Fresh(NS.ServerTime() - 13 * 3600) and not RN.Fresh(NS.ServerTime() + 3600))

-- the limits
local long = ("x"):rep(RN.MAX_CHARS + 50)
assert(#RN.CleanText(long) == RN.MAX_CHARS)
local many = {}
for i = 1, RN.MAX_LINES + 5 do many[i] = "z" .. i end
assert(RN.LineCount(RN.CleanText(table.concat(many, "\n"))) == RN.MAX_LINES)
assert(RN.CleanText("a\r\nb\0c\7") == "a\nbc", "control characters out")
local cut = RN.Clip(("a"):rep(9) .. "ä", 10)
assert(cut == ("a"):rep(9), "no half letter: " .. cut)

-- the templates
assert(RN.SaveSet("Ragnaros", "{skull} Tank: Bob") == true)
assert(RN.SaveSet("  ", "x") == nil)
assert(RN.SaveSet("Leer", "") == nil)
assert(RN.SaveSet("ragnaros", "neu") == true and #RN.Sets() == 1 and RN.SetText("Ragnaros") == "neu", "same name replaced")
for i = 1, RN.MAX_SETS - 1 do assert(RN.SaveSet("Boss " .. i, "t")) end
local full, why = RN.SaveSet("Einer zu viel", "t")
assert(full == nil and has(why, tostring(RN.MAX_SETS)), "at most 30")
assert(RN.DeleteSet("Boss 1") and #RN.Sets() == RN.MAX_SETS - 1)
-- the own note
RN.SetOwn("Meine Zeile")
assert(RN.Own() == "Meine Zeile" and AmisiaDB.raidNote.own == "Meine Zeile")
RN.SetOwn(("o"):rep(RN.MAX_OWN + 10))
assert(#RN.Own() == RN.MAX_OWN)
RN.SetOwn("Meine Zeile")
-- broken saved data is dropped field by field
AmisiaDB.raidNote.cur = { id = "x" }
AmisiaDB.raidNote.sets[#AmisiaDB.raidNote.sets + 1] = { name = 5 }
assert(RN.Current() == nil and #RN.Sets() == RN.MAX_SETS - 1)

-- who may send: only in a raid; a raider without a rank not, an assistant yes
local ok, reason = RN.CanSend()
assert(not ok and has(reason, "Raid"), tostring(reason))
assert(RN.Send("x") == nil)

-- the window: shown, the note and the own note, place and size kept, the lock
RN.Window.Show()
local F = _G.AmisiaRaidNote
assert(F and F:IsShown(), "the window")
assert(has(F.note.fs:GetText(), "Keine Raid-Notiz") and has(F.note.fs:GetText(), "Meine Zeile"), F.note.fs:GetText())
F.lock:Click()
assert(AmisiaDB.settings.raidNoteWindow.locked == true and F.mouseEnabled == false, "locked: clicks go through")
assert(not F.grip:IsShown())
F.lock:Click()
assert(AmisiaDB.settings.raidNoteWindow.locked == nil and F.mouseEnabled == true)
AmisiaDB.settings.raidNoteWindow.w, AmisiaDB.settings.raidNoteWindow.h = 5000, 5
NS.ResetRaidNotePosition()
local st = AmisiaDB.settings.raidNoteWindow or {}
assert(st.w == nil and st.h == nil and st.point == nil and not st.locked, "reset")
-- in a fight it still opens and closes; the lock waits
STUB.combat = true
RN.Window.Hide(); RN.Window.Toggle()
assert(F:IsShown(), "opens in a fight")
F.lock:Click()
assert(not (AmisiaDB.settings.raidNoteWindow or {}).locked, "no lock in a fight")
STUB.combat = false
SlashCmdList.AMISIA("notiz")
assert(not F:IsShown(), "/amisia notiz closes it")

-- a received note with codes shows them as text in the page's field
AmisiaDB.raidNote.cur = { id = NS.ServerTime(), at = NS.ServerTime(), by = "Vulo", text = "|cffff0000rot|r", h = NS.Checksum("|cffff0000rot|r") }
-- the page: everyone sees it; without the right the field is read only and there is no send button
NS.ShowPage("raidnote")
local p = NS.PageFrame("raidnote")
assert(p and p:IsShown() and not p.send:IsShown() and p.readOnly, "read only")
assert(has(p.own.box:GetText(), "Meine Zeile"))
assert(p.note.box:GetText() == "||cffff0000rot||r", p.note.box:GetText())
-- the raid marks (F-198): read only, a mark goes into the own note
assert(#p.marks == 8 and p.marks[1].word == "totenkopf" and p.marks[8].word == "stern")
p.marks[1]:Click()
assert(p.note.box:GetText() == "||cffff0000rot||r", "the read-only field keeps its text")
assert(p.own.box:GetText():sub(-11) == "{totenkopf}" and NS.RaidNote.Own():sub(-11) == "{totenkopf}", p.own.box:GetText())
-- with the right: into the note's draft, unless the own note was written in last
local canSend = NS.RaidNote.CanSend
NS.RaidNote.CanSend = function() return true end
AmisiaDB.raidNote.draft = "Tank: "
p.markBox = nil
NS.Refresh()
assert(not p.readOnly, "the officer may edit")
p.marks[2]:Click()
assert(p.note.box:GetText() == "Tank: {kreuz}" and NS.RaidNote.Draft() == "Tank: {kreuz}", p.note.box:GetText())
assert(NS.RaidNote.Render(NS.RaidNote.Draft()):find("UI-RaidTargetingIcon_7", 1, true), "the inserted word renders as the mark")
p.own.box:SetFocus()
p.marks[8]:Click()
assert(NS.RaidNote.Own():sub(-7) == "{stern}" and NS.RaidNote.Draft() == "Tank: {kreuz}", "the field written in last")
p.own.box:ClearFocus()
NS.RaidNote.CanSend = canSend
NS.Refresh()
-- the settings section and the minimap menu entry
local all = ""
for _, e in ipairs(NS.MinimapMenuEntries()) do all = all .. e[1] .. "|" end
assert(has(all, "Raid-Notiz"), all)
assert(NS.SettingItem("raidnote.autoShow") and NS.Get("raidnote.font") == 12)
print("raid note ok")
