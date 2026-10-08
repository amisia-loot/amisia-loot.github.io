-- The page "Punkte" (UI/Pages/Points.lua): hidden from raiders while the guild rolls, a hint for
-- officers; the website's text pasted under "Einfügen"; the DKP list (place, name, standing, alts),
-- the history of the chosen main, a correction with a reason; EPGP with EP, GP, PR and the minimum
-- EP; a raider's own row (the list when the site shows it); the layout at the main window's size.
local function has(s, part) return type(s) == "string" and s:find(part, 1, true) ~= nil end
STUB.now = 1791400000
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" }, { name = "Chorf", class = "WARRIOR" } }

-- rolling: raiders do not see the page, officers see the hint
NS.Set("ui.view", "raider")
assert(not NS.Visible(NS.Panel("points")), "no page for raiders of a rolling guild")
NS.Set("ui.view", "officer")
assert(NS.Visible(NS.Panel("points")))
NS.ShowPoints("list")
assert(NS.CurrentPage() == "points", "the page opens")
local f = NS.PointsPageFrame()
assert(f.empty:IsShown() and has(f.empty.title:GetText(), "würfelt"), "the hint while the guild rolls")
assert(not f.list:IsShown() and not f.book:IsShown())

-- the website's text under "Einfügen"
f.view.paste:Click()
assert(f.paste:IsShown() and f.import:IsShown() and not f.empty:IsShown())
f.paste.box:SetText("#AMISIA-ALTS 1 forever 2026-10-08\nA Kimtwink Fraktur\n#END\n"
    .. "#AMISIA-PTS 1 forever 2026-10-08 dkp 1791300000\nCFG raid=10 boss=5 time=0 bench=0 mode=bid min=10 step=5 decay=10 pub=0\n"
    .. "P Vuloo 120\nP Fraktur 80\nP Chorf -15\n#END")
f.import:Click()
assert(has(f.result:GetText(), "3 Punktestände") and has(f.result:GetText(), "1 Twink"), f.result:GetText())
assert(f.list:IsShown() and not f.paste:IsShown(), "back to the list")
assert(has(f.info:GetText(), "DKP") and has(f.info:GetText(), "2026-10-08"), f.info:GetText())

-- the list
local function shown()
    local out = {}
    for _, r in ipairs(f.list.rows) do
        if r:IsShown() then out[#out + 1] = r end
    end
    return out
end
local rows = shown()
assert(#rows == 3 and rows[1].name:GetText() == "Vuloo" and rows[1].a:GetText() == "120" and rows[1].rank:GetText() == "1")
assert(rows[3].name:GetText() == "Chorf" and rows[3].a:GetText() == "-15")
assert(has(rows[2].alts:GetText(), "Kimtwink"), "the alts beside the main")
assert(f.heads.a:GetText() == "DKP" and f.heads.b:GetText() == "")
assert(has(f.detail.fs:GetText(), "Vuloo: 120 DKP"), f.detail.fs:GetText())

-- the history of a main: a click on the row
rows[2]:Click()
assert(has(f.detail.fs:GetText(), "Fraktur: 80 DKP") and has(f.detail.fs:GetText(), "Twinks: Kimtwink"), f.detail.fs:GetText())
assert(has(f.detail.fs:GetText(), "Stand der Website"))

-- a correction: without a reason refused, with one booked
f.who:SetValue("Fraktur")
f.amount:SetText("-20")
f.reason:SetText("")
f.book:Click()
assert(has(f.status:GetText(), "Grund"), f.status:GetText())
f.reason:SetText("Ninja-Loot")
f.book:Click()
assert(has(f.status:GetText(), "Gebucht"), f.status:GetText())
assert(NS.PointsOf("Fraktur").a == 60)
assert(has(f.detail.fs:GetText(), "Korrektur: Ninja-Loot (Vuloo)") and has(f.detail.fs:GetText(), "-20"), f.detail.fs:GetText())
assert(f.reason:GetText() == "" and f.amount:GetText() == "")

-- layout
do
    local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
    Lay.row("points chips", f.view.list, f.view.paste)
    local h = f.heads
    Lay.row("points heads", h.rank, h.name, h.a, h.b, h.pr, h.alts)
    Lay.row("points correction", f.adjLabel, f.who, f.amount, f.reason, f.book)
    Lay.column("points parts", f.headFrame, f.list, f.detail, f.who, f.status)
end

-- EPGP
NS.ShowPoints("paste")
f.paste.box:SetText("#AMISIA-PTS 1 forever 2026-10-08 epgp 1791300000\nCFG raid=0 boss=0 time=0 bench=0 base=100 minep=50 pub=1\n"
    .. "P Vuloo 500 100\nP Fraktur 300 50\nP Chorf 40 0\n#END")
f.import:Click()
rows = shown()
assert(f.heads.a:GetText() == "EP" and f.heads.b:GetText() == "GP" and f.heads.pr:GetText() == "PR")
assert(rows[1].name:GetText() == "Vuloo" and rows[1].pr:GetText() == NS.PointsPRText(2.5), rows[1].pr:GetText())
assert(rows[3].name:GetText() == "Chorf" and has(rows[3].pr:GetText(), NS.PointsPRText(0.4)), "below the minimum: last, red")
assert(f.pool:IsShown() and has(f.info:GetText(), "Mindest-EP 50"), f.info:GetText())
f.who:SetValue("Chorf")
f.pool:Click()
assert(f.pool.current == "G")
f.amount:SetText("25")
f.reason:SetText("Nachtrag GP")
f.book:Click()
assert(NS.PointsOf("Chorf").b == 25, tostring(NS.PointsOf("Chorf").b))
do
    local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
    Lay.row("points correction epgp", f.adjLabel, f.who, f.amount, f.pool, f.reason, f.book)
end

-- a raider: the list (pub=1), no correction, no history
NS.Set("ui.view", "raider")
NS.ShowPoints("list")
rows = shown()
assert(#rows == 3, "the site shows the list")
assert(not f.book:IsShown() and not f.who:IsShown(), "no correction for raiders")
rows[1]:Click()
assert(has(f.detail.fs:GetText(), "Vuloo: EP 500") and not has(f.detail.fs:GetText(), "Stand der Website"), "the standing, no history: " .. f.detail.fs:GetText())
-- without pub: only the own row
NS.SetPointsSite("#AMISIA-PTS 1 forever 2026-10-08 epgp 1791300000\nCFG pub=0\nP Vuloo 500 100\nP Fraktur 300 50\n#END")
NS.Refresh()
rows = shown()
assert(#rows == 1 and rows[1].name:GetText() == "Vuloo")

-- the slash command opens the page
NS.Set("ui.view", "officer")
NS.ShowPage("overview")
NS.Dispatch("punkte")
assert(NS.CurrentPage() == "points")

---------------------------------------------------------------------------
-- the page "Vergaben": the cost in the column of the plus-one, edited in the panel
---------------------------------------------------------------------------
NS.SetPointsSite("#AMISIA-PTS 1 forever 2026-10-08 dkp 1791300000\nCFG raid=0 boss=0 time=0 bench=0 pub=1\nP Vuloo 120\nP Fraktur 80\n#END")
STUB.instance = { name = "Naxxramas", type = "raid", id = 533 }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(s and s.points and s.points.sys == "dkp")
STUB.item(30000, "Brustplatte", 4)
local a = NS.AddAwardTo(s, { name = "Fraktur", item = 30000, kind = "MS", src = "Noth", t = time() })
NS.SetAwardPoints(s, a.id, 30)
NS.ShowPage("awards")
local O = NS.AwardsPageFrame().officer
assert(O.plusHead:GetText() == "DKP", O.plusHead:GetText())
local row = O.list.rows[1]
assert(row.plus:GetText() == "30", tostring(row.plus:GetText()))
row:Click()
local E = O.edit
assert(E.pts:IsShown() and E.pts:GetText() == "30" and E.ptsLabel:GetText() == "DKP")
E.pts:SetFocus(); E.pts:SetText("45"); E.pts.scripts.OnEnterPressed(E.pts)
assert(NS.AwardPoints(s, a.id).n == 45 and NS.PointsOf("Fraktur").a == 80 - 20 - 45, "the correction of before and the new cost")
do
    local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(NS.AwardsPageFrame(), 602, 478)
    Lay.row("award edit with cost", E.bank, E.de, E.del, E.ptsLabel, E.pts, E.status)
end
-- undo takes the award and its cost back
NS.UndoAward()
assert(NS.PointsOf("Fraktur").a == 60, "an award taken back costs nothing")
