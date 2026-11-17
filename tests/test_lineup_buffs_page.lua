-- The buffs of the lineup on the page Aufstellung (F-224, UI/Pages/Lineup.lua): the link "Buffs" beside
-- "Spieler" (the two exclude each other), the three blocks in place of the lists with icon, the client's
-- spell name and the state (white count, yellow "Talent", red "fehlt", "Gr. 1, 3"), the tooltip, the line
-- "Es fehlt" (cut to its width, "(alle Anmeldungen)", green "Alle Buffs da"), a click on it, the grey notes
-- ("ohne Klasse", "Noch niemand eingeteilt"), and without the data neither link nor line.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local NAMES = {}
C_Spell = {
    GetSpellName = function(id) return NAMES[id] or ("Zauber " .. tostring(id)) end,
    GetSpellTexture = function(id) return 2000 + id end,
}
local DATA = NS.Data("RAIDBUFFS")
local SPELL = {}
for _, d in ipairs(DATA.entries) do SPELL[d[1]] = d[4] end
NAMES[SPELL.int] = "Arkane Intelligenz"
NAMES[SPELL.wild] = "Mal der Wildnis"
NAMES[SPELL.trueshot] = "Aura des Volltreffers"
NAMES[SPELL.windfury] = "Totem des Windzorns"
NAMES[SPELL.sta] = "Machtwort: Seelenstärke"

local TIP = {}
local addLine = GameTooltip.AddLine
GameTooltip.AddLine = function(self, text, ...) TIP[#TIP + 1] = text return addLine(self, text, ...) end
local function tip(part)
    for _, t in ipairs(TIP) do if has(t, part) then return t end end
end

STUB.officer = true
STUB.guild = { { name = "Vuloo", rank = 2, class = "PRIEST" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.Set("ui.view", "officer")
local night = NS.LineupTonight()
local n = NS.LineupNight(night, true)
n.size = 20
n.list = {
    { n = "Kleinfrak", c = "MAGE", r = "R" },
    { n = "Vulo Hunt", c = "HUNTER", r = "R" },
    { n = "Schami", c = "SHAMAN", r = "H" },
    { n = "Niemand Nirgends", r = "M" },
}
NS.ShowLineup("planner", night)
local f = NS.PageFrame("lineup")
local BV = f.buffs
assert(BV and f.buffsBtn:IsShown() and f.gridBtn:IsShown(), "the link beside Spieler")
assert(f.openList:IsShown() and not BV.blocks.buff.list:IsShown(), "the lists first")
-- nobody placed: every sign-up counts, the line says so
assert(BV.line:IsShown() and has(BV.line.text:GetText(), "Es fehlt: ") and has(BV.line.text:GetText(), "(alle Anmeldungen)"),
    BV.line.text:GetText())
assert(not has(BV.line.text:GetText(), "Arkane Intelligenz"), "the mage brings it")
assert(has(BV.line.text:GetText(), "Machtwort: Seelenstärke"), "no priest: the first missing one")
assert(has(BV.line.text:GetText(), "(+"), "cut to the width")
assert(BV.Width(BV.line.text) <= BV.line.text:GetWidth() + 0.5, "fits its line")

-- "Buffs": the three blocks in place of the lists
f.buffsBtn:Click()
assert(f.buffsBtn.on and not f.openList:IsShown() and not f.benchList:IsShown() and not f.gridList:IsShown())
for _, key in ipairs({ "buff", "boss", "util" }) do
    assert(BV.blocks[key].list:IsShown() and BV.blocks[key].head:IsShown(), key)
end
assert(BV.blocks.buff.title:GetText() == "Buffs" and BV.blocks.boss.title:GetText() == "Auf dem Boss"
    and BV.blocks.util.title:GetText() == "Nützliches")
assert(BV.note:IsShown() and has(BV.note:GetText(), "1 ohne Klasse"), BV.note:GetText())
local function row(name)
    for _, b in pairs(BV.blocks) do
        b.list:SetItems(b.list.items)
        for o = 0, #b.list.items do
            b.list.offset = o
            b.list:Redraw()
            for _, r in ipairs(b.list.rows) do
                if r:IsShown() and r.item and r.item.name == name then return r end
            end
        end
    end
end
local r = row("Arkane Intelligenz")
assert(r and has(r.state:GetText(), "1") and r.icon.texture == 2000 + SPELL.int, r and r.state:GetText())
r = row("Mal der Wildnis")
assert(r and has(r.state:GetText(), "fehlt"))
r = row("Aura des Volltreffers")
assert(r and has(r.state:GetText(), "Talent") and not has(r.state:GetText(), "Gr."), "no groups without placed players")
-- the tooltip: the class, the talent, the players
TIP = {}
r:GetScript("OnEnter")(r)
assert(tip("Aura des Volltreffers") and tip("Talent") and tip("Angemeldet:") and tip("Vulo Hunt"))

-- placed players: the groups, the count, no "(alle Anmeldungen)"
n.list[1].g, n.list[2].g, n.list[3].g = 1, 3, 2
NS.Refresh()
assert(not has(BV.line.text:GetText(), "alle Anmeldungen") and has(BV.line.text:GetText(), "Es fehlt"))
r = row("Aura des Volltreffers")
assert(r and has(r.state:GetText(), "Talent, Gr. 3"), r.state:GetText())
r = row("Totem des Windzorns")
assert(r and has(r.state:GetText(), "Gr. 2"), r.state:GetText())
TIP = {}
r:GetScript("OnEnter")(r)
assert(tip("Eingeteilt:") and tip("Schami") and tip("eigenen Gruppe"))
-- in a block: what is missing first, then what needs a talent, what is there last
do
    local items, rank, last = BV.blocks.buff.list.items, { missing = 1, talent = 2, have = 3 }, 0
    assert(items[1].state == "missing" and items[#items].state == "have", items[1].state .. " " .. items[#items].state)
    for _, it in ipairs(items) do
        assert(rank[it.state] >= last, "sorted by state: " .. it.name)
        last = rank[it.state]
    end
end
assert(not BV.note:IsShown() or not has(BV.note:GetText(), "ohne Klasse"), "the unknown one is not placed")
-- a druid joins: the mark is there
table.insert(n.list, { n = "Druida", c = "DRUID", r = "H", g = 2 })
NS.Refresh()
assert(has(row("Mal der Wildnis").state:GetText(), "1") and not has(BV.line.text:GetText(), "Mal der Wildnis"))

-- "Spieler" takes the place, "Buffs" goes off; "Buffs" again
f.gridBtn:Click()
assert(f.gridBtn.on and not f.buffsBtn.on and f.gridList:IsShown() and not BV.blocks.buff.list:IsShown())
f.buffsBtn:Click()
assert(f.buffsBtn.on and not f.gridBtn.on and not f.gridList:IsShown() and BV.blocks.buff.list:IsShown())
f.buffsBtn:Click()
assert(not f.buffsBtn.on and f.openList:IsShown() and BV.line:IsShown(), "a second click: the lists again, the line stays")
-- a click on the line opens the blocks
BV.line:Click()
assert(f.buffsBtn.on and BV.blocks.boss.list:IsShown())

-- everything there: green
local all = {}
for _, d in ipairs(DATA.entries) do
    for i = 1, #d[7], 2 do all[d[7][i]] = true end
end
n.list = {}
local g = 1
for cls in pairs(all) do
    for _, role in ipairs({ "T", "H", "M", "R" }) do
        table.insert(n.list, { n = cls .. role, c = cls, r = role, g = math.min(4, g) })
        g = g + 0.2
    end
end
table.insert(n.list, { n = "Imp", c = "WARLOCK", r = "R", g = 1 })
NS.Refresh()
assert(has(BV.line.text:GetText(), "Alle Buffs da"), BV.line.text:GetText())

-- an empty night: no line, the grey note in the blocks
n.list = {}
NS.Refresh()
assert(not BV.line:IsShown() and BV.blocks.buff.list:IsShown() and has(BV.note:GetText(), "Noch niemand eingeteilt"))
row("Arkane Intelligenz")
assert(row("Arkane Intelligenz").state:GetText() == "", "no state without anybody")

-- without the data (TBC, Era, the gear module off): neither link nor line
n.list = { { n = "Kleinfrak", c = "MAGE", r = "R", g = 1 } }
local saved = NS.Data("RAIDBUFFS")
NS.RAIDBUFFS = nil
NS.Refresh()
assert(not f.buffsBtn:IsShown() and not BV.line:IsShown() and not BV.blocks.buff.list:IsShown())
assert(f.openList:IsShown(), "the lists, even with buffs chosen before")
NS.RAIDBUFFS = saved
NS.Refresh()
assert(f.buffsBtn:IsShown() and BV.line:IsShown())
print("ok")
