-- Exactly one matching master loot candidate (ns.LootCandidate, the rule of the loot rules): the award
-- dialog and the roll window's hand-out give nothing when a first name fits two candidates (the
-- client lists them without surnames), and give to the one candidate that fits otherwise.
local function lastMsg() return STUB.messages[#STUB.messages] or "" end

STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Mira Sturmwind", class = "MAGE" },
                { name = "Mira Eisherz", class = "ROGUE" }, { name = "Chorf", class = "WARRIOR" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(s, "recording runs")
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
STUB.loot = { { link = link, name = "Cursed Vision of Sargeras", src = "Creature-0-1-1-1-22917-1" } }
STUB.fire("LOOT_OPENED")

-- the helper itself
assert(NS.LootCandidate(1, "Mira Sturmwind") == 2, "the exact name is candidate 2")
assert(NS.LootCandidate(1, "Chorf") == 4)
local idx, unclear = NS.LootCandidate(1, "Mira")
assert(idx == nil and unclear == true, "\"Mira\" fits two candidates")
idx, unclear = NS.LootCandidate(1, "Niemand")
assert(idx == nil and not unclear, "no candidate at all")

-- candidates without surnames: "Mira Sturmwind" fits both
local GMC = GetMasterLootCandidate
GetMasterLootCandidate = function(slot, i)
    local c = GMC(slot, i)
    return c and c:match("^(%S+)") or c
end
idx, unclear = NS.LootCandidate(1, "Mira Sturmwind")
assert(idx == nil and unclear == true, "two candidates called Mira")
assert(NS.LootCandidate(1, "Chorf") == 4, "a unique first name still fits")

-- the award dialog: nothing through master loot and nothing written (the client's menu gives it,
-- its hook records), the dialog stays open
NS.ShowAwardDialog(link)
local D = AmisiaAwardDialog
assert(D and D:IsShown() and D.give:GetText() == "Vergeben")
D.winner.onPick("Mira Sturmwind")
STUB.given = nil
local n = #s.awards
D.give:Click()
assert(STUB.given == nil, "the first loose match is not given the item")
assert(#s.awards == n, "no direct entry: a later give through the menu would make it twice")
assert(D:IsShown(), "the dialog stays open")
assert(lastMsg():find("nicht eindeutig", 1, true) and lastMsg():find("Plündermeister-Menü", 1, true), lastMsg())

-- bank: the bank character's first name fits two candidates
NS.Set("awards.bankName", "Mira")
NS.ShowAwardDialog(link)
STUB.given = nil
n = #s.awards
D.bank:Click()
assert(STUB.given == nil and #s.awards == n, "the bank name is not unique: nothing given, nothing written")
assert(lastMsg():find("nicht eindeutig", 1, true), lastMsg())

-- the roll window's hand-out
STUB.given = nil
NS.AwardFromRoll("Mira Sturmwind", 32235, link)
assert(STUB.given == nil, "the roll window gives nothing to an unclear name")
assert(lastMsg():find("nicht eindeutig", 1, true), lastMsg())
NS.AwardFromRoll("Chorf", 32235, link)
assert(STUB.given and STUB.given.i == 4, "a unique name is given the item")

-- with surnames again the exact name gets it
GetMasterLootCandidate = GMC
NS.ShowAwardDialog(link)
D.winner.onPick("Mira Eisherz")
STUB.given = nil
D.give:Click()
assert(STUB.given and STUB.given.i == 3, "exactly one candidate: master loot to it")
STUB.fire("LOOT_CLOSED")
