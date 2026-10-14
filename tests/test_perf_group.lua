-- The group index of the performance pass (2.35.2): the group is read once per frame and its answers
-- stay those of the lookups before it (ns.InMyGroup, ns.InGroup, ns.TrustName, ns.SameNameInGroup):
-- a bare first name counts only while one raider carries it, a realm ending of the own realm goes,
-- a secret name is skipped; the index goes on GROUP_ROSTER_UPDATE, the lockdown changing and an
-- encounter within the same frame. The raiders with Amisia (ns.AmisiaInGroup) are kept for the frame
-- and take a hello at once; the plus-one counts the book once per frame and takes an award at once;
-- the roll window's tally gives what it gave.
STUB.roster = { { name = "Vulo Sturmwind", class = "WARRIOR" }, { name = "Vulo Eisherz", class = "SHAMAN" },
                { name = "Mira Stein", class = "PRIEST" }, { name = "Kim", class = "MAGE" },
                { name = "Bob Hammer", class = "ROGUE" }, { name = "Zaubi Geheim", class = "WARLOCK" },
                { name = "Ida Licht", class = "PALADIN" } }
STUB.guild = {}
for i, m in ipairs(STUB.roster) do STUB.guild[i] = { name = m.name, class = m.class, rank = 4, online = true } end
STUB.guild[#STUB.guild + 1] = { name = "Lia Weide", class = "DRUID", rank = 4, online = true }
STUB.guild[#STUB.guild + 1] = { name = "Ole Dorn", class = "HUNTER", rank = 4, online = true }
STUB.secret["Zaubi Geheim"] = true
NS.Set("ui.view", "officer")
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
STUB.tick(11)
STUB.fire("GROUP_ROSTER_UPDATE")

-- the lookups as they were before the index (Trust.lua, Core.lua 2.35.1)
local function refInMyGroup(name)
    local group = {}
    for i = 1, GetNumGroupMembers() do
        local n = NS.FullName(NS.Plain((GetRaidRosterInfo(i))))
        if n then group[#group + 1] = n end
    end
    for _, n in ipairs(group) do
        if NS.SameNameIn(name, n, group) then return true end
    end
    return false
end
local function refInGroup(name)
    for i = 1, GetNumGroupMembers() do
        local n, _, _, _, _, class = GetRaidRosterInfo(i)
        n, class = NS.Plain(n), NS.Plain(class)
        if type(n) == "string" and NS.SameName(n, name) then return true, class end
    end
    return false
end

local probes = { "Vulo", "vulo sturmwind", "VULO EISHERZ", "Vulo Fern", "Mira", "mira", "Mira Stein", "  Mira   Stein ", "Mira Fern",
                 "Kim", "Kim Fern", "kim", "Bob", "Bob Hammer", "Bob Stein", "Zaubi", "Zaubi Geheim", "Ida", "Lia", "Lia Weide",
                 "Fremd Ling", "", "   ", false, 12 }
local function check(label)
    for _, p in ipairs(probes) do
        local name = p or nil
        assert(NS.InMyGroup(name) == refInMyGroup(name), label .. ": InMyGroup " .. tostring(name))
        local a, b = NS.InGroup(name)
        local x, y = refInGroup(name)
        assert(a == x and b == y, label .. ": InGroup " .. tostring(name) .. " " .. tostring(b) .. " vs " .. tostring(y))
        local group = {}
        for i = 1, GetNumGroupMembers() do
            local n = NS.FullName(NS.Plain((GetRaidRosterInfo(i))))
            if n then group[#group + 1] = n end
        end
        for _, q in ipairs({ "Vulo", "Mira", "Kim Fern", "Bob Hammer", "Ida Licht" }) do
            assert(NS.SameNameInGroup(name, q) == NS.SameNameIn(name, q, group), label .. ": SameNameInGroup " .. tostring(name) .. "/" .. q)
        end
    end
end
check("seven, one secret")
assert(NS.InMyGroup("Mira") and not NS.InMyGroup("Vulo"), "a first name alone: one Mira, two Vulos")
assert(NS.InMyGroup("Kim Fern"), "the raider without surname is the one Kim")
assert(not NS.InMyGroup("Zaubi Geheim") and not NS.InMyGroup("Zaubi"), "a secret name is skipped")
local ok, class = NS.InGroup("Vulo")
assert(ok and class == "WARRIOR", "ns.InGroup: the first that fits, with its class")

-- the guild and the realm ending
assert(NS.TrustName("Mira") == "Mira Stein", "one Mira in group and guild")
assert(NS.TrustName("Vulo") == nil, "two Vulos: no one")
assert(NS.TrustName("Mira Stein-Realm") == "Mira Stein", "the own realm goes")
assert(NS.TrustName("Mira Stein-Anderswo") == nil, "another realm stays a stranger")
assert(NS.TrustName("lia weide") == "Lia Weide" and NS.TrustName("Ole") == "Ole Dorn", "the guild after the group")
assert(NS.TrustName("Fremd Ling") == nil)
local roster = NS.GroupRoster()
assert(#roster == 6 and roster[6] == "Ida Licht", "the roster without the secret name")
roster[1] = "Geändert"
assert(NS.GroupRoster()[1] == "Vulo Sturmwind", "a fresh copy each call")

-- the same frame: GROUP_ROSTER_UPDATE drops the index (one name swapped, the count the same)
assert(not NS.InMyGroup("Neu Ling"))
STUB.roster[3] = { name = "Neu Ling", class = "MAGE" }
STUB.fire("GROUP_ROSTER_UPDATE")
assert(NS.InMyGroup("Neu Ling") and not NS.InMyGroup("Mira"), "the swap counts at once")
check("after the swap")
-- a second Kim: the bare first name is no one any more
STUB.roster[#STUB.roster + 1] = { name = "Kim Eisherz", class = "PRIEST" }
STUB.fire("GROUP_ROSTER_UPDATE")
assert(not NS.InMyGroup("Kim Fern") and NS.InMyGroup("Kim Eisherz"), "two Kims")
check("two Kims")
-- the name turns plain after the fight, a new one secret at an encounter
STUB.secret["Zaubi Geheim"] = nil
STUB.fire("ADDON_RESTRICTION_STATE_CHANGED")
assert(NS.InMyGroup("Zaubi"), "plain again")
STUB.secret["Ida Licht"] = true
STUB.fire("ENCOUNTER_START", 1, "Boss", 4, 25)
assert(not NS.InMyGroup("Ida Licht"), "secret at the encounter")
check("at the encounter")
STUB.secret["Ida Licht"] = nil
STUB.fire("ENCOUNTER_END", 1, "Boss", 4, 25, 1)
-- the next frame reads the group again by itself
STUB.roster[#STUB.roster] = nil
STUB.roster[#STUB.roster + 1] = { name = "Ole Dorn", class = "HUNTER" }
STUB.tick(0.1)
assert(NS.InMyGroup("Ole") and NS.InMyGroup("Kim Fern"), "the next frame")
check("the next frame")

---------------------------------------------------------------------------
-- The raiders with Amisia
---------------------------------------------------------------------------
local function refExpected(since)
    local out = {}
    local me = NS.UnitFullName("player")
    for name, e in pairs(AmisiaDB.sync.seen) do
        if type(name) == "string" and type(e) == "table" and (tonumber(e.p) or 0) >= 1 and not NS.SameName(name, me) and refInMyGroup(name)
            and (not since or (type(e.v) == "string" and e.v:match("^%d+%.%d+%.%d+$") and NS.CompareVersion(e.v, since) >= 0)) then
            out[#out + 1] = name
        end
    end
    table.sort(out, function(a, b) return a:lower() < b:lower() end)
    return table.concat(out, ",")
end
AmisiaDB.sync = AmisiaDB.sync or {}
AmisiaDB.sync.seen = { ["Mira"] = { v = NS.VERSION, p = 1, mp = 1, flags = "", at = time() },
                       ["Vulo"] = { v = NS.VERSION, p = 1, mp = 1, flags = "", at = time() },
                       ["Bob Hammer"] = { v = "1.0.0", p = 1, mp = 1, flags = "", at = time() },
                       ["Lia Weide"] = { v = NS.VERSION, p = 1, mp = 1, flags = "", at = time() } }
STUB.tick(0.1)
STUB.roster[3] = { name = "Mira Stein", class = "PRIEST" }
STUB.fire("GROUP_ROSTER_UPDATE")
local list = NS.AmisiaInGroup()
assert(table.concat(list, ",") == refExpected() and table.concat(list, ",") == "Bob Hammer,Mira", table.concat(list, ","))
assert(table.concat(NS.AmisiaInGroup("2.0.0"), ",") == refExpected("2.0.0"), "with since")
list[1] = "Geändert"
assert(NS.AmisiaInGroup()[1] == "Bob Hammer", "a fresh copy each call")
-- a hello in the same frame counts at once
local function hello(sender, v)
    STUB.fire("CHAT_MSG_ADDON", "Amisia", "1HI\t" .. v .. "\t1\t-\t-", "RAID", sender, "", 0, 0, "", 0)
end
hello("Ole Dorn", NS.VERSION)
assert(AmisiaDB.sync.seen["Ole Dorn"], "the hello was recorded")
assert(table.concat(NS.AmisiaInGroup(), ",") == "Bob Hammer,Mira,Ole Dorn", table.concat(NS.AmisiaInGroup(), ","))
-- and a raider leaving in the same frame goes at once
STUB.roster[#STUB.roster] = nil
STUB.fire("GROUP_ROSTER_UPDATE")
assert(table.concat(NS.AmisiaInGroup(), ",") == refExpected() and refExpected() == "Bob Hammer,Mira")

-- the note on a newer version: a hello of the own version checks again while the last check could
-- not run (the note was off), as before
local function notes()
    local n = 0
    for _, m in ipairs(STUB.messages) do if tostring(m):find("Es gibt eine neuere Version", 1, true) then n = n + 1 end end
    return n
end
NS.Set("sync.outdatedWarn", false)
hello("Lia Weide", "9.9.9")
hello("Ole Dorn", "9.9.9")
assert(notes() == 0, "off")
NS.Set("sync.outdatedWarn", true)
hello("Bob Hammer", NS.VERSION)
assert(notes() == 1 and AmisiaDB.sync.warned == "9.9.9", "on again: the next hello tells " .. notes())
hello("Mira Stein", NS.VERSION)
hello("Lia Weide", "9.9.9")
assert(notes() == 1, "once per version")

---------------------------------------------------------------------------
-- The plus-one
---------------------------------------------------------------------------
local function refPlus(name)
    local s = NS.Active()
    local n = 0
    for _, a in ipairs(s.awards) do
        if a.kind == "MS" and (a.to == nil or a.to == "player") and NS.SameMain(a.name, name) then n = n + 1 end
    end
    return n
end
local s = NS.Active()
assert(s, "a recording runs")
AmisiaDB.alts = { list = { { alt = "Ida Licht", main = "Bob Hammer" }, { alt = "Zed Twink", main = "Mira" } }, n = 2 }
for i, w in ipairs({ "Bob Hammer", "Ida Licht", "Mira Stein", "Mira", "Vulo", "Vulo Sturmwind", "Zed Twink", "Kim", "Bob Hammer" }) do
    s.awards[#s.awards + 1] = { id = 500 + i, name = w, item = 30000 + i, t = time(), kind = (i == 9) and "OS" or "MS", src = "Boss" }
end
s.awards[#s.awards + 1] = { id = 600, name = "Lia Weide", item = 30100, t = time(), kind = "MS", src = "Boss", to = "bank" }
local who = { "Bob Hammer", "bob hammer", "Bob", "Ida Licht", "Ida", "Mira Stein", "Mira", "Zed Twink", "Zed", "Vulo", "Vulo Sturmwind",
              "Vulo Eisherz", "Kim", "Kim Fern", "Lia Weide", "Fremd Ling" }
local function checkPlus(label)
    for _, n in ipairs(who) do
        assert(NS.PlusCount(n) == refPlus(n), label .. ": " .. n .. " " .. NS.PlusCount(n) .. " vs " .. refPlus(n))
    end
end
checkPlus("the book")
assert(NS.PlusCount("Bob Hammer") == 2 and NS.PlusCount("Ida") == 2, "a main and its alt together")
-- an award in the same frame counts at once
NS.AddAward("Bob Hammer", 31000, "MS", "Boss")
assert(NS.PlusCount("Bob Hammer") == 3, "added: " .. NS.PlusCount("Bob Hammer"))
checkPlus("after an award")
-- the sync writes into the book: counted at once
s.awards[#s.awards + 1] = { id = 700, name = "Kim", item = 31001, t = time(), kind = "MS", src = "Boss" }
checkPlus("after a written award")
-- an edit in the same frame
local last = s.awards[#s.awards]
NS.EditAward(s, last.id, { kind = "OS" })
assert(NS.PlusCount("Kim") == refPlus("Kim"), "an edit counts at once")
checkPlus("after an edit")
-- another alt list in the same frame
AmisiaDB.alts = { list = { { alt = "Vulo Sturmwind", main = "Bob Hammer" } }, n = 1 }
checkPlus("another alt list")

---------------------------------------------------------------------------
-- The roll window's tally
---------------------------------------------------------------------------
local function refTally(r)
    local roster = r.roster or NS.GroupRoster()
    local function inSet(set, name)
        for k in pairs(set or {}) do
            if NS.SameNameIn(k, name, roster) then return true end
        end
        return false
    end
    local passed = 0
    for name in pairs(r.passed or {}) do
        if not inSet(r.rolls, name) then passed = passed + 1 end
    end
    local missing = 0
    for _, name in ipairs(NS.AmisiaInGroup(NS.VERSION)) do
        if not inSet(r.rolls, name) and not inSet(r.passed, name) then missing = missing + 1 end
    end
    return NS.L["passt: %d · ohne Antwort: %d"]:format(passed, missing)
end
for name, e in pairs(AmisiaDB.sync.seen) do e.v = NS.VERSION end
AmisiaDB.sync.seen["Kim"] = { v = NS.VERSION, p = 1, mp = 1, flags = "", at = time() }
AmisiaDB.sync.seen["Vulo Eisherz"] = { v = NS.VERSION, p = 1, mp = 1, flags = "", at = time() }
STUB.tick(0.1)
local cases = {
    { rolls = { ["Mira Stein"] = {} }, passed = { ["Bob"] = true, ["Kim Fern"] = true } },
    { rolls = { ["Mira"] = {}, ["Vulo"] = {} }, passed = { ["Bob Hammer"] = true, ["Vulo Eisherz"] = true } },
    { rolls = {}, passed = { ["Kim"] = true, ["Mira Stein"] = true, ["  "] = true } },
    { rolls = { ["Kim"] = {}, ["Bob Hammer"] = {} }, passed = {} },
}
for i, c in ipairs(cases) do
    local r = { wsSent = true, rolls = c.rolls, passed = c.passed, roster = NS.GroupRoster() }
    assert(NS.RollWindowTally(r) == refTally(r), "tally " .. i .. ": " .. NS.RollWindowTally(r) .. " vs " .. refTally(r))
end
print("perf group ok")
