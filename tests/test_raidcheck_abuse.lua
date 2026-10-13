-- The raid check against abuse and load (Raid/RaidCheck.lua, F-098, D-46, review 2026-10-13): a
-- ready check started by somebody outside the own guild gets no answer by itself (a raid of
-- strangers learns nothing); a burst of answers redraws the page once, not once per answer; a
-- raider out of sight (only the own report) has no class buffs "missing" (the report names none).
local RC = NS.RaidCheck

STUB.player, STUB.class, STUB.level = "Vuloo", "PRIEST", 60
STUB.guild = { { name = "Vuloo", rank = 2, class = "PRIEST" }, { name = "Fraktur", rank = 3, class = "SHAMAN" } }
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" }, { name = "Kim Fremd", class = "MAGE" } }
for i = 1, 12 do
    local name = "Raider " .. string.char(64 + i) .. "bc"
    STUB.guild[#STUB.guild + 1] = { name = name, rank = 4, class = "WARRIOR" }
    STUB.roster[#STUB.roster + 1] = { name = name, class = "WARRIOR" }
end
STUB.playerRaidIndex = 1
STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.fire("PLAYER_ENTERING_WORLD")
STUB.tick(12)
_G.C_UnitAuras = { GetAuraDataByIndex = function() return nil end }

local function xas() local n = 0 for _, m in ipairs(STUB.addon) do if m.text:find("^1XA\t") then n = n + 1 end end return n end

-- 1. the ready check of a stranger: no answer; of a guild member: one
STUB.addon = {}
STUB.fire("READY_CHECK", "Kim Fremd", 30)
STUB.tick(4)
assert(xas() == 0, "a stranger's ready check gets no answer")
STUB.fire("READY_CHECK", "Fraktur", 30)
STUB.tick(4)
assert(xas() == 1, "a guild member's one")

-- 2. twelve answers in the same moment: the page is told once
NS.Set("ui.view", "officer")
assert(NS.RaidCheckAllowed())
local fired = 0
NS.Listen("RAIDCHECK", function() fired = fired + 1 end)
for i = 1, 12 do
    STUB.fire("CHAT_MSG_ADDON", "Amisia", "1XA\t-\t90\t0\t600\t-\t-\t0\tF", "RAID", "Raider " .. string.char(64 + i) .. "bc", "", 0, 0, "", 0)
end
STUB.tick(1)
local n = 0
for _ in pairs(NS._raidcheck.answers()) do n = n + 1 end
assert(n == 12, "every answer kept: " .. n)
assert(fired == 1, "one redraw for the burst: " .. fired)

-- 3. out of sight: the own report names no class buffs, so none is "missing"
_G.UnitIsVisible = function(u) return u == "player" or u == "raid1" end
local rows = RC.Rows()
for _, r in ipairs(rows.list) do
    if r.src == "self" then assert(#r.missing == 0, r.name .. ": no class buff missing by the own report") end
end
local selfRows = 0
for _, r in ipairs(rows.list) do if r.src == "self" then selfRows = selfRows + 1 end end
assert(selfRows == 12, "the raiders out of sight count by their report: " .. selfRows)
