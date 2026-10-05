--[[preload
-- the client's deprecation fallbacks switched on: the alias ChatEdit_InsertLink exists, bound to
-- the unhooked ChatFrameUtil.InsertLink (Blizzard_DeprecatedChatInfo)
ChatEdit_InsertLink = ChatFrameUtil.InsertLink
]]
-- Review fixes of the award dialog and the awards page: the chat link path of the client, master
-- loot only into the running recording, a raid deleted while the dialog is open, notes typed without
-- Enter, free names, and the layout at the main window's size.
local function lastMsg() return STUB.messages[#STUB.messages] or "" end
local function countAwards()
    local n = 0
    for _, x in ipairs(NS.Sessions()) do n = n + #(x.awards or {}) end
    return n
end

STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" }, { name = "Chorf", class = "WARRIOR" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
local link2 = STUB.item(32837, "Warglaive of Azzinoth", 5)
local old = { id = "20260901200000-564", date = "2026-09-01", zone = "Der Schwarze Tempel", instanceID = 564,
              start = 1700000000, last = 1700003600, members = { ["Fraktur"] = { class = "SHAMAN", first = 1, last = 1 } },
              loot = {}, items = {}, drops = {}, awards = {}, gone = {} }
table.insert(AmisiaDB.sessions, 1, old)

---------------------------------------------------------------------------
-- the client puts shift-clicked links in through ChatFrameUtil.InsertLink, not the alias
---------------------------------------------------------------------------
local D = NS.ShowAwardDialog(nil, s)
STUB.shift = true
HandleModifiedItemClick(link2)
STUB.shift = false
assert(D.itemText:IsShown() and D.itemText:GetText() == link2, "a shift-click in the bags fills the item")
D.cancel:Click()
-- an addon calling the alias still fills it
NS.ShowAwardDialog(nil, s)
ChatEdit_InsertLink(link2)
assert(D.itemText:GetText() == link2, "the alias too")
D.cancel:Click()
-- the page's shift-click goes the client's way
NS.AddAwardTo(s, { name = "Fraktur", item = 32235, kind = "MS", src = "X" })
NS.ShowPage("awards")
local O = NS.AwardsPageFrame().officer
local insertVia
local realInsert = ChatFrameUtil.InsertLink
ChatFrameUtil.InsertLink = function(l) insertVia = "util"; return realInsert(l) end
STUB.shift = true
O.list.rows[1]:Click()
STUB.shift = false
ChatFrameUtil.InsertLink = realInsert
assert(insertVia == "util" and STUB.inserted == link, "the page uses ChatFrameUtil.InsertLink")

---------------------------------------------------------------------------
-- master loot only into the running recording
---------------------------------------------------------------------------
STUB.loot = { { link = link, name = "Cursed Vision of Sargeras", src = "Creature-0-1-1-1-22917-1" } }
STUB.fire("LOOT_OPENED")
-- another raid than the recording: a direct entry into it, nothing handed out
NS.ShowAwardDialog(link, old)
assert(D.give:GetText() == "Eintragen", "another raid than the recording: Eintragen, got " .. tostring(D.give:GetText()))
assert(D.hint:GetText():find("eingetragen", 1, true), D.hint:GetText())
D.winner.onPick("Fraktur")
STUB.given = nil
D.give:Click()
assert(STUB.given == nil and #old.awards == 1 and old.awards[1].manual == true, "written into the chosen raid, not handed out")
-- bank too
NS.Set("awards.bankName", "Chorf")
NS.ShowAwardDialog(link, old)
D.bank:Click()
assert(STUB.given == nil and #old.awards == 2 and old.awards[2].to == "bank", "bank into the chosen raid, not handed out")
-- the recording paused: the newest raid gets a direct entry
local awards0 = countAwards()
NS.SetEnabled(false); STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
assert(NS.Active() == nil, "recording stopped")
STUB.fire("LOOT_OPENED")
NS.ShowAwardDialog(link)
assert(D.give:GetText() == "Eintragen", "without a recording: Eintragen, got " .. tostring(D.give:GetText()))
D.winner.onPick("Fraktur")
D.give:Click()
assert(STUB.given == nil and countAwards() == awards0 + 1, "saved, not handed out: " .. lastMsg())
STUB.fire("LOOT_CLOSED")

---------------------------------------------------------------------------
-- a raid deleted while the dialog is open
---------------------------------------------------------------------------
local gone = { id = "20260801200000-564", date = "2026-08-01", zone = "Der Schwarze Tempel", instanceID = 564,
               start = 1690000000, last = 1690003600, members = {}, loot = {}, items = {}, drops = {}, awards = {}, gone = {} }
table.insert(AmisiaDB.sessions, 1, gone)
NS.ShowAwardDialog(link2, gone)
D.winner.onPick("Fraktur")
assert(NS.DeleteSessions({ [gone.id] = true }) == 1, "deleted")
D.give:Click()
assert(lastMsg():find("Der Raid wurde inzwischen gelöscht.", 1, true), lastMsg())
assert(D:IsShown() and #gone.awards == 0, "nothing written, the dialog stays open")
D.bank:Click()
assert(D:IsShown() and #gone.awards == 0, "bank neither")
D.cancel:Click()

---------------------------------------------------------------------------
-- the note counts without Enter, a free name is cleaned like an edit
---------------------------------------------------------------------------
NS.ShowAwardDialog(link2, old)
D.winner.onPick("  Neuling   Berg-Tal ", true)
D.note:SetFocus(); D.note:SetText("  ohne Enter  ")
D.give:Click()
local a = old.awards[#old.awards]
assert(a.name == "Neuling Berg-Tal", "the free name through ns.FullName: [" .. tostring(a.name) .. "]")
assert(a.note == "ohne Enter", "the typed note without Enter: " .. tostring(a.note))
NS.ShowAwardDialog(link2, old)
D.note:SetFocus(); D.note:SetText("Bank ohne Enter")
D.bank:Click()
assert(old.awards[#old.awards].note == "Bank ohne Enter", tostring(old.awards[#old.awards].note))
STUB.focus = nil

---------------------------------------------------------------------------
-- the page: a note typed but not committed stays with its own award
---------------------------------------------------------------------------
NS.ShowPage("awards")
O.raid.onPick(old.id)
local rows = O.list.rows
local first, second = rows[1].item.a, rows[2].item.a
local firstNote = first.note
rows[2]:Click()
O.edit.note:SetFocus(); O.edit.note:SetText("zur zweiten")
rows[1]:Click()
assert(second.note == "zur zweiten", "committed to the award it was typed for: " .. tostring(second.note))
assert(first.note == firstNote and O.edit.note:GetText() == (firstNote or ""), "the new award keeps its own note")
O.edit.note:ClearFocus()
assert(first.note == firstNote, "and nothing reaches it later: " .. tostring(first.note))
-- another raid chosen: the same
rows[2]:Click()
O.edit.note:SetFocus(); O.edit.note:SetText("vor dem Raidwechsel")
O.raid.onPick(s.id)
assert(second.note == "vor dem Raidwechsel", tostring(second.note))
O.edit.note:ClearFocus()
-- delete with an uncommitted note: no edit lands on the undo stack in front of the deletion
O.raid.onPick(old.id)
rows[2]:Click()
O.edit.note:SetFocus(); O.edit.note:SetText("verworfen")
O.edit.del:Click()
assert(second.deleted and NS.UndoLabel():find("Löschen", 1, true), tostring(NS.UndoLabel()))
NS.UndoAward()
assert(second.deleted == nil and second.note == "vor dem Raidwechsel", "one undo brings it back unchanged: " .. tostring(second.note))
STUB.focus = nil

---------------------------------------------------------------------------
-- layout: at the main window's size (content 602 px) nothing overlaps or leaves its frame
---------------------------------------------------------------------------
local H = { LEFT = "L", TOPLEFT = "L", BOTTOMLEFT = "L", RIGHT = "R", TOPRIGHT = "R", BOTTOMRIGHT = "R" }
local root, rootW
local span
local function edge(rel, relPoint, owner)
    rel = rel or owner.parent
    local l, r = span(rel)
    local c = H[relPoint] or "C"
    if c == "L" then return l elseif c == "R" then return r end
    return (l + r) / 2
end
span = function(f)
    if f == root then return 0, rootW end
    assert(f ~= UIParent and f ~= nil, "laid out outside the root")
    local L, R, C
    for p, a in pairs(f.points or {}) do
        local x = edge(a.rel, a.relPoint, f) + a.x
        local c = H[p] or "C"
        if c == "L" then L = x elseif c == "R" then R = x else C = x end
    end
    local w = f._w
    if L and R then return L, R end
    assert(w, "a width for " .. tostring(f.name or f.text))
    if L then return L, L + w end
    if R then return R - w, R end
    assert(C, "an anchor for " .. tostring(f.name or f.text))
    return C - w / 2, C + w / 2
end
local function row(name, ...)
    local prevR
    for i, f in ipairs({ ... }) do
        local l, r = span(f)
        assert(l >= 0 and r <= rootW, ("%s #%d leaves its frame: %d..%d of %d"):format(name, i, l, r, rootW))
        if prevR then assert(l >= prevR, ("%s #%d overlaps #%d: %d < %d"):format(name, i, i - 1, l, prevR)) end
        prevR = r
    end
end

local E = O.edit
root, rootW = O, 602
row("page head", O.raid, O.search, O.add, O.undo)
local hl, hr = span(O.searchHint)
local sl, sr = span(O.search)
assert(hl >= sl and hr <= sr, ("the hint sits in the search box: %d..%d in %d..%d"):format(hl, hr, sl, sr))
row("edit panel", E.winner, E.kinds.MS, E.kinds.OS, E.kinds.SR, E.kinds["-"], E.note)
row("edit buttons", E.bank, E.de, E.del)

root, rootW = D, 380
row("dialog item", D.icon, D.itemText, D.raidText)
row("dialog item box", D.icon, D.itemEdit, D.raidText)
row("dialog winner", D.winner, D.kinds.MS, D.kinds.OS, D.kinds.SR, D.kinds["-"])
row("dialog note", D.note)
row("dialog buttons", D.give, D.bank, D.de, D.cancel)
