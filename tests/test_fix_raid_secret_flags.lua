-- Secret answers are never compared (audit 2026-11-07): the raid check's roster reads the online and
-- dead flags of GetRaidRosterInfo through ns.Plain (a secret flag: online and alive), and the award
-- dialog's master loot candidates skip a secret name and go on (Raid/RaidCheck.lua roster(),
-- Raid/AwardDialog.lua names()). Lua 5.1 cannot observe a comparison with nil, so the candidate part
-- checks the behaviour only; the flags part fails when a secret false is compared.
local RC = NS.RaidCheck
STUB.player, STUB.class, STUB.level = "Vuloo", "PRIEST", 60
STUB.guild = { { name = "Vuloo", rank = 2, class = "PRIEST" }, { name = "Fraktur", rank = 3, class = "SHAMAN" },
               { name = "Chorf", rank = 3, class = "WARRIOR" } }
STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.tick(2)
NS.Set("ui.view", "officer")
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" }, { name = "Chorf", class = "WARRIOR" } }
_G.IsInRaid = function() return true end
_G.GetNumGroupMembers = function() return #STUB.roster end

-- the flags: Fraktur's "offline" and Chorf's "dead" are secret answers
local SECRET_FALSE, SECRET_TRUE = false, true
local GRI = GetRaidRosterInfo
_G.GetRaidRosterInfo = function(i)
    local name, rank, sub, level, cls, file, zone, online = GRI(i)
    local dead = false
    if name == "Fraktur" then online = SECRET_FALSE end
    if name == "Chorf" then dead = SECRET_TRUE end
    return name, rank, sub, level, cls, file, zone, online, dead
end
local IS = _G.issecretvalue
local reading = false
_G.issecretvalue = function(v)
    if reading and (v == SECRET_FALSE or v == SECRET_TRUE) then return true end
    return IS(v)
end
reading = true
local rows = RC.Rows()
reading = false
local by = {}
for _, r in ipairs(rows.list) do by[r.name] = r end
assert(by.Fraktur and by.Fraktur.state ~= "offline", "a secret online flag is not read as offline: " .. tostring(by.Fraktur and by.Fraktur.state))
assert(by.Chorf and by.Chorf.state ~= "dead", "a secret dead flag is not read as dead: " .. tostring(by.Chorf and by.Chorf.state))
_G.GetRaidRosterInfo, _G.issecretvalue = GRI, IS

-- the candidates: a secret one in the middle is skipped, the ones after it still come
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local link = STUB.item(32235, "Verfluchte Vision", 4)
STUB.loot = { { link = link, name = "Verfluchte Vision", src = "Creature-0-1-1-1-22917-1" } }
STUB.fire("LOOT_OPENED")
local CANDS = { "Vuloo", "Geheim Name", "Neuling" }
STUB.secret["Geheim Name"] = true
local GMC = GetMasterLootCandidate
_G.GetMasterLootCandidate = function(_, i) return CANDS[i] end
NS.ShowAwardDialog(link)
local D = AmisiaAwardDialog
assert(D and D:IsShown())
local seen = {}
for _, v in ipairs(D.winner.values or {}) do seen[type(v) == "table" and v.value or v] = true end
assert(not seen["Geheim Name"], "the secret name is not offered")
assert(seen.Neuling, "the candidate after the secret one still comes")
_G.GetMasterLootCandidate = GMC
STUB.secret["Geheim Name"] = nil
STUB.fire("LOOT_CLOSED")
STUB.loot = {}
