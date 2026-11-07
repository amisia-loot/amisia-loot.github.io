-- Professions from guild notes (F-133): Prof.FromNote reads German and English names and short forms
-- with the skill right after them; the page Mitglieder shows them for members the recipe exchange does
-- not know (rank 0 without a number: no number on the box), adds the ones the exchange lacks, the
-- tooltip says where it comes from, the Beruf dropdown finds them, and "mit Amisia" does not count them.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local Pr, Cr = NS.Prof, NS.Crafters
dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")
for _, p in ipairs({ { 333, "enchanting" }, { 197, "tailoring" }, { 186, "mining" } }) do
    table.insert(NS.PROFESSIONS.P, p)
end
Pr._reset()

---------------------------------------------------------------------------
-- the parser
---------------------------------------------------------------------------
local function read(text)
    local out = {}
    for _, p in ipairs(Pr.FromNote(text)) do out[#out + 1] = p.skill .. ":" .. tostring(p.rank) end
    return table.concat(out, ",")
end
assert(read("Alchi 300 / Kräuter") == "171:300,182:nil", read("Alchi 300 / Kräuter"))
assert(read("KRÄUTERKUNDE 225, Alchemie") == "182:225,171:nil", read("KRÄUTERKUNDE 225, Alchemie"))
assert(read("BS 225, Mining 300") == "164:225,186:300", read("BS 225, Mining 300"))
assert(read("Rüstungsschmied/Bergbau") == "164:nil,186:nil", read("Rüstungsschmied/Bergbau"))
assert(read("VZ300 Schneider275") == "333:300,197:275", read("VZ300 Schneider275"))
assert(read("Ingi 300 Kürschnerei") == "202:300,393:nil", read("Ingi 300 Kürschnerei"))
assert(read("LW/Skinning 300/300") == "165:nil,393:300", read("LW/Skinning 300/300"))
assert(read("Erste Hilfe 300, Kochen 150, Angeln") == "129:300,185:150,356:nil", read("Erste Hilfe 300, Kochen 150, Angeln"))
assert(read("first aid, cooking 1, fishing 9999") == "129:nil,185:1,356:nil", "a rank only 1..450")
assert(read("Alchi 300 Alchemie 150") == "171:300", "each profession once, the first number")
assert(read("Twink von Bob, DKP 120") == "", "nothing named")
assert(read("eher Heiler") == "", "short forms only as the whole word")
assert(read("|cffff0000Alchi|r 300") == "171:300", "colour codes left out")
assert(read(nil) == "" and read("") == "" and read(42) == "", "no text")

---------------------------------------------------------------------------
-- the page
---------------------------------------------------------------------------
STUB.player = "Vuloo"
STUB.officer = true
local D = NS.DropsToday()
STUB.guild = {
    { name = "Vuloo", class = "PRIEST", rank = 2, level = 60, zone = "Sturmwind" },
    { name = "Anna Amboss", class = "WARRIOR", rank = 3, level = 58, zone = "Eisenschmiede", note = "Schmiedin, Bergbau 280" },
    { name = "Bob", class = "MAGE", rank = 4, level = 60, zone = "Tanaris", note = "Schneider 300 / VZ" },
    { name = "Carla", class = "PRIEST", rank = 3, level = 42, zone = "Tanaris", note = "Twink", onote = "Alchi 250" },
    { name = "Dora", class = "ROGUE", rank = 5, level = 12, zone = "Tanaris" },
}
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)
AmisiaDB.prof = { chars = { ["Vuloo"] = { [171] = { rank = 120, max = 150, day = D, known = { [2330] = true } } } } }
local ix = Cr._index(164)
AmisiaDB.crafters = { v = 1, src = {}, c = {
    ["Anna Amboss"] = { via = "Anna Amboss", self = true, seen = D, p = { [164] = { r = 225, m = 300, h = ix.hash,
        b = Cr._toBits(ix, { [2663] = true }) } } },
} }
Cr.Changed()

NS.ShowPage("members")
local f = assert(NS.PageFrame("members"))
local function row(name)
    for _, e in ipairs(f.list.items) do if e.name == name then return e end end
end
local function skills(e)
    local out = {}
    for _, p in ipairs(e.profs or {}) do out[#out + 1] = p.skill .. ":" .. p.rank .. (p.note and "n" or "") end
    table.sort(out)
    return table.concat(out, ",")
end
assert(skills(row("Bob")) == "197:300n,333:0n", skills(row("Bob")))
assert(skills(row("Carla")) == "171:250n", "the officer note too: " .. skills(row("Carla")))
assert(skills(row("Anna Amboss")) == "164:225,186:280n", "the exchange first, the note adds mining: " .. skills(row("Anna Amboss")))
assert(skills(row("Vuloo")) == "171:120", skills(row("Vuloo")))
assert(row("Dora").profs == nil, "no note, no professions")
assert(not row("Bob").amisia and row("Anna Amboss").amisia, "a note is not Amisia")
assert(has(f.data:GetText(), "mit Amisia"), f.data:GetText())

-- the texts: number or none, where it comes from
local bob = row("Bob")
local vz, tail
for _, p in ipairs(bob.profs) do if p.skill == 333 then vz = p else tail = p end end
assert(NS.MembersProfText(tail) == "Schneiderei 300, laut Gildennotiz", NS.MembersProfText(tail))
assert(NS.MembersProfText(vz) == "Verzauberkunst, laut Gildennotiz", NS.MembersProfText(vz))

-- the box: no number for a note without one
local checked = 0
for _, r in ipairs(f.list.rows) do
    if r.item == bob then
        for _, b in ipairs(r.boxes) do
            if b:IsShown() and b.prof and b.prof.skill == 333 then assert(b.num:GetText() == "", b.num:GetText()); checked = checked + 1 end
            if b:IsShown() and b.prof and b.prof.skill == 197 then assert(b.num:GetText() == "300", b.num:GetText()); checked = checked + 1 end
        end
    end
end
assert(checked == 2, "both of Bob's boxes: " .. checked)

-- the dropdown: enchanting finds Bob, mining Anna (the note's part)
f.prof.onPick(333)
assert(#f.list.items == 1 and f.list.items[1].name == "Bob", #f.list.items)
f.prof.onPick(186)
assert(#f.list.items == 1 and f.list.items[1].name == "Anna Amboss", #f.list.items)
f.prof.onPick("all")
print("note professions ok")
