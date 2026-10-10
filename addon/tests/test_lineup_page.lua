-- The page "Aufstellung" (UI/Pages/Lineup.lua): officers only; the paste field and "Übernehmen";
-- the match view with its statuses and one-click fixes; the planner with groups, the red frame of a
-- group without a healer, click to swap, a free place to move, drag, the right-click menu, the
-- bench button; the night picker; a raider sees nothing.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return m end end
    return nil
end

STUB.officer = true
STUB.guild = {
    { name = "Vuloo", rank = 2, class = "PRIEST" },
    { name = "Vulo Hunt", rank = 3, class = "HUNTER" },
    { name = "Vulo Pala", rank = 3, class = "PALADIN", level = 52 },
    { name = "Anna Bergmann", rank = 3, class = "PRIEST" },
    { name = "Bob Eisherz", rank = 3, class = "WARRIOR" },
    { name = "Kim Sturmwind", rank = 3, class = "ROGUE", online = false },
    { name = "Kleinfrak", rank = 4, class = "MAGE" },
}
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)

-- a raider: no page, no row in the page list
NS.Set("ui.view", "raider")
assert(not NS.Visible(NS.Panel("lineup")))
NS.ShowLineup()
assert(NS.CurrentPage() ~= "lineup", "a raider is sent elsewhere")

NS.Set("ui.view", "officer")
NS.Dispatch("aufstellung")
assert(NS.CurrentPage() == "lineup")
local f = NS.LineupPageFrame()
assert(f and f.empty:IsShown() and has(f.empty.title:GetText() or "", "Noch keine Anmeldungen"), "the empty state")
assert(not f.auto:IsEnabled(), "nothing to assign yet")

-- paste: the button opens the field, "Übernehmen" takes it
f.pasteBtn:Click()
assert(f.paste:IsShown() and f.take:IsShown() and f.cancel:IsShown() and not f.empty:IsShown())
f.paste.box:SetText("")
f.take:Click()
assert(said("Kein Name erkannt."), "an empty paste changes nothing")
assert(f.paste:IsShown())
STUB.messages = {}
f.paste.box:SetText("Tanks\nVulo Hunt\n:Warrior: Bob Eisherx\nHeiler\nvulo pala\nAnna\nNahkampf\nKim Sturmwind\nVulo\nNiemand Nirgends\nAbgemeldet\nKleinfrak")
f.take:Click()
assert(said("Aufstellung: 7 Anmeldungen, 3 gefunden, 2 vermutlich, 1 nicht eindeutig, 1 unbekannt, 1 abgemeldet."), STUB.messages[1])
assert(not f.paste:IsShown() and f.match:IsShown(), "back to the match view")
assert(has(f.counts:GetText(), "Tanks 2 · Heiler 2 · Nahkampf 3 · Fernkampf 0 · Ersatz 0 · abgemeldet 1"), f.counts:GetText())

-- the match rows: status, level, online, the fixes
local function rowOf(name)
    for _, r in ipairs(f.mlist.rows) do
        if r:IsShown() and r.item and r.item.e.n == name then return r end
    end
end
local r = rowOf("Vulo Hunt")
assert(has(r.state:GetText(), "gefunden") and has(r.online:GetText(), "online") and r.level:GetText() == "70")
r = rowOf("Vulo Pala")
assert(r.level:GetText() == "52", "the level from the roster")
r = rowOf("Anna Bergmann")
assert(has(r.state:GetText(), "vermutlich") and has(r.name:GetText(), "(Liste: Anna)") and r.chips[1]:IsShown()
    and r.chips[1].label:GetText() == "Bestätigen")
r.chips[1]:Click()
r = rowOf("Anna Bergmann")
assert(has(r.state:GetText(), "gefunden") and not r.chips[1]:IsShown(), "confirmed")
r = rowOf("Vulo")
assert(has(r.state:GetText(), "nicht eindeutig") and r.chips[1].label:GetText() == "Vulo Hunt" and r.chips[2].label:GetText() == "Vulo Pala")
r = rowOf("Niemand Nirgends")
assert(has(r.state:GetText(), "unbekannt") and r.edit:IsShown())
r = rowOf("Kim Sturmwind")
assert(has(r.online:GetText(), "offline") and r.r:GetText():find("N", 1, true), "role letter")
r = rowOf("Kleinfrak")
assert(has(r.state:GetText(), "abgemeldet"), "the absent at the bottom")
assert(f.rematch:IsShown() and not f.bench:IsShown())
-- the unknown name typed in
r = rowOf("Niemand Nirgends")
r.edit:SetText("Vuloo")
r.edit.scripts.OnEnterPressed(r.edit)
assert(rowOf("Vuloo") and has(rowOf("Vuloo").state:GetText(), "gefunden"), "typed and found")
-- an alt online for an offline character
NS.SetAlts("#AMISIA-ALTS 1 forever 2026-10-01\nA Kleinfrak Kim_Sturmwind\n#END")
NS.LineupRemove(NS.LineupTonight(), #NS.LineupNight().list)   -- Kleinfrak (absent) leaves the list
NS.Refresh()
r = rowOf("Kim Sturmwind")
assert(has(r.act:GetText(), "Twink online: Kleinfrak") and r.chips[1].label:GetText() == "tauschen")
r.chips[1]:Click()
assert(rowOf("Kleinfrak") and has(rowOf("Kleinfrak").name:GetText(), "(Liste: Kim Sturmwind)"), "swapped to the alt")

-- the planner: automatic, the counts, swap by two clicks, move to a free place, drag, menu
f.auto:Click()
assert(NS.CurrentPage() == "lineup" and f.plan:IsShown() and f.views.planner.on, "the planner after the assignment")
assert(said("Eingeteilt: "), "chat line")
local g1, g2 = f.plan.groups[1], f.plan.groups[2]
assert(g1:IsShown() and f.plan.groups[8]:IsShown() and g1.title:GetText() == "Gruppe 1")
local function slotOf(name)
    for _, box in ipairs(f.plan.groups) do
        for _, b in ipairs(box.slots) do
            local e = b.entry and NS.LineupNight().list[b.entry]
            if e and e.n == name then return b end
        end
    end
end
local hunt = slotOf("Vulo Hunt")
assert(hunt and hunt.group == 1, "the first tank in group 1")
-- a group with members and no healer has the red frame
local n = NS.LineupNight()
local c = NS.LineupCounts()
for _, g in ipairs(c.noHealer) do assert(f.plan.groups[g].alarm[1]:IsShown(), "red frame " .. g) end
assert(not g1.alarm[1]:IsShown() or #c.noHealer > 0)
-- two clicks swap
local bob = slotOf("Bob Eisherz")
local bobGroup, huntGroup = bob.group, hunt.group
hunt:Click()
assert(hunt.sel:IsShown(), "chosen")
bob:Click()
assert(slotOf("Vulo Hunt").group == bobGroup and slotOf("Bob Eisherz").group == huntGroup, "swapped")
-- choose, then a free place in group 8: moved
local free8
for _, b in ipairs(f.plan.groups[8].slots) do if not b.entry then free8 = b break end end
slotOf("Vulo Hunt"):Click()
free8:Click()
assert(slotOf("Vulo Hunt").group == 8, "moved to a free place")
-- drag Vulo Hunt onto Bob: swapped (the drop runs as a click)
local from = slotOf("Vulo Hunt").entry
NS._lineupDrop(from, slotOf("Bob Eisherz"))
assert(slotOf("Bob Eisherz").group == 8, "dragged")
-- right click: hold, bench
local b = slotOf("Bob Eisherz")
b.scripts.OnClick(b, "RightButton")
assert(AmisiaMenu and AmisiaMenu:IsShown(), "the menu")
local labels = {}
for _, btn in ipairs(AmisiaMenu.buttons) do if btn:IsShown() then labels[#labels + 1] = btn.label:GetText() end end
local joined = table.concat(labels, "|")
assert(has(joined, "Rolle: ") and has(joined, "Festhalten") and has(joined, "Ersatz") and has(joined, "Entfernen"), joined)
for _, btn in ipairs(AmisiaMenu.buttons) do
    if btn:IsShown() and btn.label:GetText() == "Festhalten" then btn:Click() break end
end
assert(slotOf("Bob Eisherz").lock:IsShown(), "the hold mark")
f.auto:Click()
assert(slotOf("Bob Eisherz").group == 8, "held in group 8")
-- onto the bench through the list head, then the bench button puts the online ones on the bench
local kf = slotOf("Kleinfrak")
kf:Click()
f.plan.benchBtn:Click()
assert(not slotOf("Kleinfrak") and f.benchList.rows[1]:IsShown() and f.benchList.rows[1].item.e.n == "Kleinfrak", "on the bench")
assert(has(f.benchHead:GetText(), "Ersatz (1)"))
assert(f.bench:IsShown() and f.bench:IsEnabled())
STUB.messages = {}
f.bench:Click()
assert(said("Ersatzbank: Kleinfrak (Notiz \"Aufstellung\")."), STUB.messages[1])
assert(NS.IsBenched(NS.BenchTarget(), "Kleinfrak").note == "Aufstellung")

-- the night picker: tonight and an earlier night; an empty night offers the copy
NS.SetLineupText("Anna Bergmann Heiler", "2026-10-01")
NS.ShowLineup("match", "2026-10-02")
assert(f.empty:IsShown() and f.copy:IsShown() and has(f.copy:GetText(), "übernehmen"), "copy from an earlier night")
f.copy:Click()
assert(#NS.LineupNight("2026-10-02").list == 1 and f.match:IsShown())
f.night.onPick(NS.LineupTonight())
assert(#f.list > 3, "back to tonight")
