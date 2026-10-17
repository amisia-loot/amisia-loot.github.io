-- The soft-reserve import window (F-108, spec 2026-10-17 part B): the preview model, the window's
-- box of raiders without a reservation and the preview rows, a suggestion clicked before taking
-- the list, and the raid chat announcement with the hard reserves.
STUB.instance = { name = "Dalaran", type = "none", id = 0 }
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" }, { name = "Chorf", class = "WARRIOR" },
                { name = "Bobbington", class = "WARRIOR" }, { name = "Anna Bergmann", class = "PRIEST" } }
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
STUB.item(32837, "Warglaive of Azzinoth", 5)
STUB.item(17204, "Eye of Sulfuras", 5)
local function has(s, part) return type(s) == "string" and s:find(part, 1, true) ~= nil end

local CSV = "Item Name,Item ID,From,Raider Name,Raider Class,Raider Spec,Raider Note,Extra Reserves,Date\n"
    .. "Cursed,32235,Boss,Vuloo,Priest,Holy,,0,2026-10-17\n"
    .. "Cursed,32235,Boss,Vuloo,Priest,Holy,,0,2026-10-17\n"
    .. "Glaive,32837,Boss,Fraktur,Mage,Frost,,0,2026-10-17\n"
    .. "Glaive,32837,Boss,Bobingtn,Warrior,Arms,,0,2026-10-17\n"
    .. "Glaive,32837,Boss,Gustav,Warrior,Arms,,0,2026-10-17\n"

---------------------------------------------------------------------------
-- the model
---------------------------------------------------------------------------
assert(NS.SoftResPreview("   ") == nil and NS.SoftResPreview(nil) == nil, "nothing to show")
local m = NS.SoftResPreview(CSV)
assert(m.raid and m.label == "Raid (5)" and m.reservers == 4 and not m.same, m.reservers)
local miss = {}
for _, p in ipairs(m.missing) do miss[#miss + 1] = p.name .. ":" .. tostring(p.class) end
assert(table.concat(miss, ",") == "Anna Bergmann:PRIEST,Bobbington:WARRIOR,Chorf:WARRIOR", table.concat(miss, ","))
local order = {}
for _, r in ipairs(m.rows) do order[#order + 1] = r.name end
-- findings first (Bobingtn unclear, Fraktur wrong class), then in the raid, then not in it
assert(table.concat(order, ",") == "Bobingtn,Fraktur,Vuloo,Gustav", table.concat(order, ","))
assert(m.rows[1].tone == "unclear" and m.rows[1].suggest[1] == "Bobbington", tostring(m.rows[1].tone))
assert(m.rows[2].tone == "class" and has(m.rows[2].status, "Klasse: softres") and m.rows[2].class == "SHAMAN", m.rows[2].status)
assert(m.rows[3].status == nil and m.rows[3].n == 2 and m.rows[3].items[1].n == 2 and m.rows[3].class == "PRIEST")
assert(m.rows[4].tone == "absent" and m.rows[4].status == "nicht im Raid" and m.rows[4].class == "WARRIOR", "class from the list")
assert(#m.hard == 0)
-- a broken code: the reason, no rows
m = NS.SoftResPreview("eNpljzFPxDAMhf+L5wxNVdoj27EwggSIAXVwa1dEpMnJSVmq")
assert(m.err and #m.rows == 0, "broken code")

---------------------------------------------------------------------------
-- the window
---------------------------------------------------------------------------
NS.ToggleSoftResFrame()
local F = AmisiaSoftResFrame
assert(F and F:IsShown())
F.editBox:SetText(CSV)
NS.SoftResImportPreview()   -- the stub fires no OnTextChanged on SetText
assert(has(F.previewText:GetText(), "Vorschau gegen Raid (5)") and has(F.previewText:GetText(), "1 Klasse falsch"), F.previewText:GetText())
assert(F.miss:IsShown() and has(F.miss.title:GetText(), "Im Raid ohne Reserve · 3"), F.miss.title:GetText())
assert(has(F.miss.names:GetText(), "Bobbington") and has(F.miss.names:GetText(), "Anna Bergmann"))
assert(not F.miss.remind:IsEnabled() and not F.miss.post:IsEnabled(), "not taken yet: no reminders, no post")
local rows = F.list.rows
assert(has(rows[1].name:GetText(), "Bobingtn") and rows[1].chips[1]:IsShown() and rows[1].chips[1].label:GetText() == "Bobbington")
assert(rows[3].icons[1]:IsShown() and rows[3].icons[1].count:GetText() == "2x" and not rows[3].icons[2]:IsShown(), "doubles on one icon")
-- the suggestion: remembered for the pasted text, the preview follows
rows[1].chips[1]:Click()
STUB.tick(1)
assert(AmisiaDB.srAliases.bobingtn == "Bobbington")
assert(has(F.miss.title:GetText(), "· 2"), F.miss.title:GetText())
local fixed
for _, r in ipairs(F.list.items) do if r.name == "Bobbington" then fixed = r end end
assert(fixed and fixed.tone == "renamed" and fixed.status == "korrigiert aus Bobingtn", fixed and fixed.status)

-- taking the list: in a raid it is announced (softres.announce on)
STUB.chat = {}
F.applyBtn:Click()
assert(has(F.resultText:GetText(), "5 Reservierungen übernommen"), F.resultText:GetText())
STUB.tick(1)
local said = {}
for _, c in ipairs(STUB.chat) do if c.chan == "RAID" then said[#said + 1] = c.text end end
assert(#said == 1 and has(said[1], "Soft-Reserves geladen: 5 Reservierungen von 4 Raidern."), table.concat(said, " | "))
assert(F.miss.remind:IsEnabled() and F.miss.post:IsEnabled(), "taken: reminders and post")
AmisiaDB.srAliases.bobingtn = nil

---------------------------------------------------------------------------
-- hard reserves: the row on top, the announcement with links and the English lines
---------------------------------------------------------------------------
NS.SetSoftRes("Vuloo 32235")
AmisiaDB.softres.hard = { [17204] = { to = "Gilde", note = "Bank" }, [32837] = { to = "Anna Bergmann", note = "" } }
AmisiaDB.softres.raw = ""   -- as a shared list: the empty box shows the loaded list
F.editBox:SetText("")
NS.SoftResImportRefresh()
assert(F.list.items[1].kind == "hard" and #F.list.items[1].items == 2)
assert(has(F.list.rows[1].name:GetText(), "Hard-Reserves") and F.list.rows[1].edges[1]:IsShown())
assert(F.list.rows[1].announce:IsShown(), "officer, raid, the loaded list: Ansagen")
assert(not F.list.rows[2].edges[1]:IsShown(), "only the hard row has the frame")
local lines = NS.SoftResAnnounceLines()
assert(#lines == 2 and has(lines[2], "Hard-Reserves: ") and has(lines[2], " für Gilde (Bank)") and has(lines[2], " für Anna Bergmann"), lines[2])
local en = NS.SoftResAnnounceLines(nil, true)
assert(has(en[1], "Soft reserves loaded: 1 reserves from 1 raiders.") and has(en[2], "Hard reserves: ") and has(en[2], " for Gilde"), en[2])
NS.Set("softres.chat", false)
assert(not has(NS.SoftResAnnounceLines()[1], "!sr"), "no !sr answers, no hint")
NS.Reset("softres.chat")
STUB.chat = {}
NS.Set("rolls.announceEnglish", true)
assert(NS.AnnounceSoftRes())
STUB.tick(6)
local raid = 0
for _, c in ipairs(STUB.chat) do if c.chan == "RAID" then raid = raid + 1 end end
assert(raid == 4, "German and English: " .. raid)
NS.Reset("rolls.announceEnglish")
-- a raider may not announce
NS.Set("ui.view", "raider")
local ok, why = NS.AnnounceSoftRes()
assert(not ok and why == "Ansagen nur in der Offiziersansicht.")
NS.Reset("ui.view")
