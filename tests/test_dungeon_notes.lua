-- The own notes of dungeons and raids (Gear/DungeonNotes.lua; F-212, D-137): cleaning (item links kept,
-- codes, textures and control characters gone, the byte caps, UTF-8 kept whole), set, get, boss notes by
-- encounter, clear, the saved table shaped on load (twice without change), the chat line once per entry
-- (not after a /reload, not with the setting off) and its link, the dungeon bar's "Notiz" with its list
-- and the boss notes under the bosses, the part Notiz on the pages Dungeons and Raids (field, count,
-- boss lines, saving, a shift-clicked link, "Notiz leeren"), the mark in the table and the tooltip.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return m end end
    return nil
end
local N, DBar, R = NS.DungeonNotes, NS.DungeonBar, NS.Runs
local T = NS.Theme

STUB.class, STUB.level, STUB.faction = "WARRIOR", 18, "Alliance"
local THANES = { name = "Halle der Thane", type = "party", id = 3065 }
local OUT = { name = "Dun Morogh", type = "none", id = 0 }
local E1, E4 = 3493, nil
local function enter(i, reload)
    STUB.instance = i
    STUB.fire("PLAYER_LEAVING_WORLD")
    STUB.fire("PLAYER_ENTERING_WORLD", false, reload or false)
    STUB.tick(N.CHAT_DELAY + 0.1)
end

---------------------------------------------------------------------------
-- cleaning
---------------------------------------------------------------------------
local LINK = "|cff1eff00|Hitem:2589::::::::18:::::::|h[Leinenstoff]|h|r"
local NEW_LINK = "|cnIQ2:|Hitem:2592::::::::18:::::::|h[Wollstoff]|h|r"
assert(N.Clean("  a\r\nb\t\1c  ", 100) == "a\nbc", "line ends, controls, blanks: " .. N.Clean("  a\r\nb\t\1c  ", 100))
assert(N.Clean("a\nb", 100, true) == "a b", "one line")
local cleaned = N.Clean("x |cffff0000rot|r |TInterface\\Icons\\X:12|t |Hunit:1|h[Name]|h y|", 100)
assert(cleaned == "x rot  [Name] y", "codes go whole, a link's text stays: " .. cleaned)
assert(N.Clean("vor " .. LINK .. " nach", 200) == "vor " .. LINK .. " nach", "an item link stays")
assert(N.Clean(NEW_LINK, 200) == NEW_LINK, "the new link colour stays")
assert(N.Clean("ab " .. LINK, 10) == "ab", "a link that does not fit goes whole")
assert(N.Clean("ääää", 5) == "ää", "no half letter: " .. N.Clean("ääää", 5))
assert(N.Clean(nil, 10) == "" and N.Clean(5, 10) == "", "no string")

---------------------------------------------------------------------------
-- set, get, boss notes, clear
---------------------------------------------------------------------------
local fired = 0
NS.Listen("DUNGEON_NOTES", function() fired = fired + 1 end)
assert(not N.Has("thanes") and N.Get("thanes") == "", "nothing yet")
assert(N.Set("thanes", "Erst links die Goblins\nRhahk allein ziehen  ") == "Erst links die Goblins\nRhahk allein ziehen", "set")
assert(N.Has("thanes") and fired == 0, "kept; the others hear of it a moment later")
STUB.tick(0.6)
assert(fired == 1, "fired once")
assert(N.Set("thanes", "Erst links die Goblins\nRhahk allein ziehen") and fired == 1, "the same text: no fire")
STUB.tick(0.6)
assert(fired == 1, "still once")
local bk = N.BossKey("thanes", 1, "Faldrim Anvilmar")
assert(bk == tostring(E1), "the boss key is the encounter: " .. bk)
assert(N.SetBoss("thanes", bk, "Adds\nzuerst") == "Adds zuerst", "a boss note is one line")
assert(N.Boss("thanes", bk) == "Adds zuerst", "boss note kept")
assert(N.SetBoss("thanes", "bad key", "x") == nil and N.Set("bad key!", "x") == nil, "bad keys refused")
assert(N.FirstLine("thanes") == "Erst links die Goblins", N.FirstLine("thanes"))
local bosses = N.Bosses("thanes")
assert(#bosses >= 4 and bosses[1].text == "Adds zuerst" and bosses[2].text == "", "the bosses in order with their notes")
assert(#N.BossNotes("thanes") == 1 and N.BossNotes("thanes")[1].name == bosses[1].name, "the set boss notes")
local long = ("x"):rep(N.MAX_TEXT + 50)
assert(#N.Set("raw", long) == N.MAX_TEXT, "the cap")
N.Set("raw", "")
assert(not N.Has("raw") and AmisiaDB.dungeonNotes.list.raw == nil, "an empty note is deleted")
-- a boss note alone keeps the entry
N.SetBoss("raw", "n:boss", "nur der Boss")
assert(N.Has("raw") and N.Get("raw") == "", "a boss note alone")
N.Clear("raw")
assert(not N.Has("raw"), "cleared")

---------------------------------------------------------------------------
-- the saved table on load: checked, cleaned, twice without change
---------------------------------------------------------------------------
AmisiaDB.dungeonNotes.list["bad key!"] = { text = "weg" }
AmisiaDB.dungeonNotes.list.empty = { text = "", boss = {} }
AmisiaDB.dungeonNotes.list.codes = { text = "a|cffff0000b", at = "x", boss = { ["123"] = "ok", ["bad"] = "weg", ["n:x"] = 5 } }
N.Loaded()
local L1 = AmisiaDB.dungeonNotes.list
assert(L1["bad key!"] == nil and L1.empty == nil, "bad and empty dropped")
assert(L1.codes.text == "ab" and L1.codes.at == 0 and L1.codes.boss["123"] == "ok" and L1.codes.boss.bad == nil
    and L1.codes.boss["n:x"] == nil, "cleaned")
local before = STUB.dump(AmisiaDB.dungeonNotes)
N.Loaded()
assert(STUB.dump(AmisiaDB.dungeonNotes) == before, "a second load changes nothing")
N.Clear("codes")

---------------------------------------------------------------------------
-- the chat line: once per entry, not after a /reload, not with the setting off; the link
---------------------------------------------------------------------------
enter(OUT)
STUB.messages = {}
enter(THANES)
local line = said("Erst links die Goblins")
assert(line and has(line, "|Haddon:Amisia:note:thanes|h[Notiz]|h"), "the chat line with the link: " .. tostring(line))
local n = #STUB.messages
STUB.fire("PLAYER_ENTERING_WORLD", false, true)
STUB.tick(N.CHAT_DELAY + 0.1)
assert(#STUB.messages == n, "a /reload inside says nothing again")
-- a /reload into the dungeon (a fresh session): the entry is only marked
N._reset()
R.entry = R.entry + 1
STUB.fire("PLAYER_ENTERING_WORLD", false, true)
STUB.tick(N.CHAT_DELAY + 0.1)
assert(#STUB.messages == n, "a reload's entry: no line")
enter(OUT)
NS.Set("dungeonbar.noteChat", false)
STUB.messages = {}
enter(THANES)
assert(not said("Erst links"), "setting off: no line")
NS.Set("dungeonbar.noteChat", true)

---------------------------------------------------------------------------
-- the dungeon bar: "Notiz", its list, the boss notes under the bosses, the right click
---------------------------------------------------------------------------
local bar = _G.AmisiaDungeonBar
DBar.Refresh()
local seg = bar.seg
assert(seg.note:IsShown() and plain(seg.note:GetText()) == " Notiz", "the segment: " .. tostring(seg.note:GetText()))
seg.note:Click()
assert(DBar.ListShown() == "note", "the note's list")
local rows = {}
for _, r in ipairs(_G.AmisiaDungeonBarList.rows) do if r:IsShown() then rows[#rows + 1] = r end end
assert(#rows == 3, "two lines and a boss note: " .. #rows)
assert(rows[1].text:GetText() == "Erst links die Goblins" and not rows[1].note:IsShown(), "a wide line")
assert(has(plain(rows[3].text:GetText()), "Adds zuerst"), "the boss note: " .. rows[3].text:GetText())
-- a long note wraps over the list's width
assert(#DBar.Wrap(("Wort "):rep(80), 200) > 5, "wrapped")
local w = DBar.Wrap("a " .. LINK .. " b", 2000)
assert(#w == 1 and has(w[1], LINK), "a link stays whole")
seg.bosses:Click()
rows = {}
for _, r in ipairs(_G.AmisiaDungeonBarList.rows) do if r:IsShown() then rows[#rows + 1] = r end end
assert(has(rows[2].text:GetText(), "Adds zuerst") and has(rows[2].text:GetText(), T.GREY), "grey under its boss")
assert(plain(rows[3].text:GetText()):find("^2%. "), "then the next boss")
-- the setting hides the segment
NS.Set("dungeonbar.note", false)
DBar.Refresh()
assert(not seg.note:IsShown(), "segment off")
NS.Set("dungeonbar.note", true)
DBar.Refresh()
-- a right click opens the part Notiz of the page
seg.note.scripts.OnClick(seg.note, "RightButton")
local D = NS.PageFrame("dungeons")
assert(D and D.chosen == "thanes" and D.noteView:IsShown(), "the page on the part Notiz")

---------------------------------------------------------------------------
-- the part Notiz: field, count, boss lines, saving, a link, clearing; the tab's mark
---------------------------------------------------------------------------
local v = D.noteView
assert(v.area.box:GetText() == "Erst links die Goblins\nRhahk allein ziehen", "the field holds the note")
assert(has(D.parts.note:GetText(), "PublicNote"), "the tab carries the mark")
assert(has(v.count:GetText(), tostring(N.MAX_TEXT)), v.count:GetText())
local box = v.area.box
box:SetFocus()
box:SetText("Neu geschrieben")
box.scripts.OnTextChanged(box, true)
assert(N.Get("thanes") == "Neu geschrieben", "saved while typing")
-- a shift-clicked item lands in the field with the focus
ChatFrameUtil.InsertLink(LINK)
assert(N.Get("thanes") == "Neu geschrieben" .. LINK, "the link saved: " .. N.Get("thanes"))
-- one click, one link (both hooks may run); a link past the cap is not put in
ChatFrameUtil.InsertLink(LINK)
assert(N.Get("thanes") == "Neu geschrieben" .. LINK, "no second copy in the same moment")
box:SetText(("x"):rep(N.MAX_TEXT - 10))
box.scripts.OnTextChanged(box, true)
STUB.tick(1)
ChatFrameUtil.InsertLink(LINK)
assert(#N.Get("thanes") == N.MAX_TEXT - 10, "a link that does not fit stays out")
box:SetText("Neu geschrieben" .. LINK)
box.scripts.OnTextChanged(box, true)
box:ClearFocus()
-- the boss lines
local brow
for _, r in ipairs(v.list.rows) do
    if r.item and r.item.key == bk then brow = r end
end
assert(brow and brow.edit:GetText() == "Adds zuerst", "the boss's line")
brow.edit:SetFocus()
brow.edit:SetText("Adds zuerst, dann Boss")
brow.edit:ClearFocus()
assert(N.Boss("thanes", bk) == "Adds zuerst, dann Boss", "the boss line saved on leaving")
-- the hint
assert(D.hint:GetText() == NS.JournalParts.NOTE_HINT, "the hint")

-- the table's mark and the tooltip
assert(has(NS.DungeonJournalKit.runBadge({ key = "thanes" }, false, true), "PublicNote"), "the mark in the table")
local preview = N.Preview("thanes", 3)
assert(preview[1] == "Neu geschrieben" .. LINK and preview[#preview] == "Boss-Notizen: 1", "the tooltip's lines")

-- the link of the chat line opens the part
NS.ShowDungeon("thanes", "bosses")
assert(not D.noteView:IsShown(), "Übersicht")
N.OnLink(nil, "addon:Amisia:note:thanes")
assert(D.noteView:IsShown(), "the link opens Notiz")

-- clearing asks first; a field with the focus does not bring the old text back
v.area.box:SetFocus()
v.clear:Click()
assert(_G.AmisiaConfirmFrame and _G.AmisiaConfirmFrame:IsShown(), "asks")
_G.AmisiaConfirmFrame.ok:Click()
assert(not N.Has("thanes") and v.area.box:GetText() == "" and not v.area.box:HasFocus(), "cleared")
-- another tab: no field keeps the keyboard
N.Set("thanes", "wieder da")
NS.Refresh()
v.area.box:SetFocus()
NS.ShowDungeon("thanes", "bosses")
assert(not v.area.box:HasFocus() and N.Get("thanes") == "wieder da", "focus gone with the tab")
-- a long note: the bar's list ends with a row to the page
N.Set("thanes", ("Eine Zeile der Taktik\n"):rep(30))
STUB.tick(1)
DBar.Refresh()
if DBar.ListShown() ~= "note" then seg.note:Click() end
local shownRows = {}
for _, r in ipairs(_G.AmisiaDungeonBarList.rows) do if r:IsShown() then shownRows[#shownRows + 1] = r end end
assert(#shownRows == T.DUNGEONBAR.MAX_ROWS and has(shownRows[#shownRows].text:GetText(), "mehr auf der Seite"), "the last row points to the page")
N.Clear("thanes")
NS.Refresh()
assert(not has(D.parts.note:GetText(), "PublicNote"), "the tab's mark gone")

---------------------------------------------------------------------------
-- raids: the same part on the page Raids
---------------------------------------------------------------------------
N.Set("onyxia", "Tiefe Atemzüge")
NS.ShowRaid("onyxia", "note")
local Rj = NS.PageFrame("raidjournal")
assert(Rj.noteView:IsShown() and Rj.noteView.area.box:GetText() == "Tiefe Atemzüge", "the raid's note")
assert(Rj.hint:GetText() == NS.JournalParts.NOTE_HINT, "the raid's hint")

---------------------------------------------------------------------------
-- the note window (F-213): entering a dungeon with an own note opens it with "Deine Notiz zu"
---------------------------------------------------------------------------
local RW = NS.RaidNote.Window
N.Set("thanes", "Links {totenkopf} zuerst")
N.SetBoss("thanes", bk, "Adds zuerst")
RW.Hide()
RW._reset()
enter(OUT)
enter(THANES)
local NW = _G.AmisiaRaidNote
assert(NW and NW:IsShown(), "the window opened on entering")
local wt = NW.note.fs:GetText()
assert(has(wt, "Deine Notiz zu") and has(wt, "Links") and has(wt, "UI-RaidTargetingIcon_8") and has(wt, "Adds zuerst"), wt)
-- a /reload inside does not open it again; the switch keeps it closed
RW.Hide()
STUB.fire("PLAYER_ENTERING_WORLD", false, true)
STUB.tick(3.1)
assert(not NW:IsShown(), "not after a reload")
NS.Set("raidnote.dungeonOpen", false)
enter(OUT)
enter(THANES)
assert(not NW:IsShown(), "the switch off")
NS.Set("raidnote.dungeonOpen", true)

print("dungeon notes: clean, set, boss notes, load, chat once, link, bar, list, part, link insert, clear, raids")
