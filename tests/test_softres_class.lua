-- Soft-reserves, the class check (F-109, spec 2026-10-17 part C): the list's class against the
-- raider it is matched to, the CSV class column, suggestions that weigh the class.
_G.LOCALIZED_CLASS_NAMES_MALE = { PRIEST = "Priester", MAGE = "Magier", WARRIOR = "Krieger", ROGUE = "Schurke" }

assert(NS.SoftResClassToken("Death Knight") == "DEATHKNIGHT" and NS.SoftResClassToken("priest") == "PRIEST")
assert(NS.SoftResClassToken("Tank") == nil and NS.SoftResClassToken(nil) == nil)

-- a CSV of softres.it carries "Raider Class"
STUB.item(32235, "Cursed Vision of Sargeras", 4)
STUB.item(32837, "Warglaive of Azzinoth", 4)
local csv = "Item Name,Item ID,From,Raider Name,Raider Class,Raider Spec,Raider Note,Extra Reserves,Date\n"
    .. "Cursed Vision,32235,Illidan,Anna,Mage,Frost,,0,2026-10-17\n"
    .. "Warglaive,32837,Illidan,Bob Stein,Warrior,Arms,,0,2026-10-17\n"
    .. "Warglaive,32837,Illidan,Karla,Rogue,Combat,,0,2026-10-17\n"
    .. "Warglaive,32837,Illidan,Zeta,Tank,Prot,,0,2026-10-17\n"
local _, _, _, _, _, _, extra = NS.ParseSoftRes(csv)
assert(extra.src == "csv" and extra.classes.Anna == "Mage" and extra.classes["Bob Stein"] == "Warrior", tostring(extra.classes.Anna))
assert(extra.classes.Zeta == nil, "no class word, no class")
NS.SetSoftRes(csv)
assert(AmisiaDB.softres.classes.Karla == "Rogue")

-- in the raid: Anna is a priest, Bob (surname on the list) a warrior, Karla misspelt as Karlo
STUB.roster = { { name = "Anna", class = "PRIEST" }, { name = "Bob Stein", class = "WARRIOR" },
                { name = "Karlo", class = "ROGUE" }, { name = "Karl", class = "MAGE" } }
local roster, label, classes = NS.SoftResRoster()
assert(label == "Raid (4)" and classes.anna == "PRIEST" and classes["bob stein"] == "WARRIOR")
local c = NS.SoftResCheck()
assert(c.match.Anna == "Anna" and c.match["Bob Stein"] == "Bob Stein")
assert(#c.class == 1 and c.class[1].name == "Anna" and c.class[1].want == "MAGE" and c.class[1].have == "PRIEST", #c.class)
assert(NS.SoftResClassText(c.class[1]) == "Klasse passt nicht: softres Magier, im Raid Priester", NS.SoftResClassText(c.class[1]))
-- the suggestion for Karla: Karlo (same class) before Karl (one letter nearer, other class)
local u
for _, x in ipairs(c.unclear) do if x.name == "Karla" then u = x end end
assert(u and u.suggest[1] == "Karlo" and u.suggest[2] == "Karl", u and table.concat(u.suggest, ","))
-- the check lines and the preview name it
local lines = table.concat(NS.SoftResCheckLines(), "\n")
assert(lines:find(", 1 Klasse falsch.", 1, true) and lines:find("Anna: Klasse passt nicht", 1, true), lines)
assert(NS.SoftResPreviewText(csv):find("1 Klasse falsch", 1, true), NS.SoftResPreviewText(csv))

-- the same class one letter further: "Annabel" against "Anabelle" (distance 3) only with the class
_, _, _, _, _, _, extra = NS.ParseSoftRes("Item ID,Raider Name,Raider Class\n32235,Annabel,Priest\n")
STUB.roster = { { name = "Anabelle", class = "PRIEST" } }
local b = NS.ParseSoftRes("Item ID,Raider Name,Raider Class\n32235,Annabel,Priest\n")
c = NS.SoftResCheck({ byItem = b, times = {}, classes = extra.classes })
assert(#c.unclear == 1 and c.unclear[1].suggest[1] == "Anabelle", #c.unclear)
STUB.roster = { { name = "Anabelle", class = "MAGE" } }
c = NS.SoftResCheck({ byItem = b, times = {}, classes = extra.classes })
assert(#c.unclear == 0, "another class: three letters are too many")

-- without classes nothing is flagged; a matching class neither
c = NS.SoftResCheck({ byItem = b, times = {} }, { "Annabel" }, { annabel = "MAGE" })
assert(#c.class == 0)
c = NS.SoftResCheck({ byItem = b, times = {}, classes = { Annabel = "Mage" } }, { "Annabel" }, { annabel = "MAGE" })
assert(#c.class == 0)

-- the page's Abgleich view has a row for it
STUB.roster = { { name = "Anna", class = "PRIEST" } }
NS.SetSoftRes(csv)
NS.ShowSoftRes("check")
local f = NS.SoftResPageFrame()
local found = false
for _, e in ipairs(f.list.items or {}) do
    if e.kind == "class" and e.name == "Anna" then found = true end
end
assert(found, "class row on the page")
