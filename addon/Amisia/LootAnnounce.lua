-- Amisia loot lead: exactly one client per raid announces loot and answers !sr, without any sync.
-- That is the master looter under master loot, else the raid leader; Amisia must run in the
-- officer view. loot.lead = "me" makes this client the lead when the leader has no Amisia.
local ADDON, ns = ...

local MASTER = (Enum and Enum.LootMethod and Enum.LootMethod.Masterlooter) or 2

-- The loot method as a flag for master loot, with the master looter's party and raid index.
-- Both clients have C_PartyInfo.GetLootMethod; an older one the global with "master".
local function lootMethod()
    local info = _G.C_PartyInfo
    if type(info) == "table" and type(info.GetLootMethod) == "function" then
        local ok, method, partyID, raidID = pcall(info.GetLootMethod)
        if ok then return method == MASTER, partyID, raidID end
        return nil
    end
    local old = _G.GetLootMethod
    if type(old) == "function" then
        local ok, method, partyID, raidID = pcall(old)
        if ok then return method == "master", partyID, raidID end
    end
    return nil
end

function ns.IsLootLead()
    if not IsInRaid() or not ns.IsOfficerView() then return false end
    if ns.Get("loot.lead") == "me" then return true end
    local master, partyID, raidID = lootMethod()
    if master then
        if raidID then return UnitIsUnit("raid" .. raidID, "player") and true or false end
        if partyID then return partyID == 0 end
    end
    -- no master loot, or no way to tell who loots: the leader leads
    return UnitIsGroupLeader("player") and true or false
end

ns.RegisterSettings{ key = "loot", label = "Loot-Ansage", order = 22, officer = true, items = {
    { key = "loot.lead", type = "choice", label = "Ansage und !sr-Antworten", default = "auto",
      values = { { "auto", "Plündermeister, sonst Leiter" }, { "me", "Immer ich" } },
      tip = "Antwortet nur ein Amisia im Raid, posten zwei Offiziere nicht doppelt. \"Immer ich\", wenn der Leiter Amisia nicht hat." },
}}
