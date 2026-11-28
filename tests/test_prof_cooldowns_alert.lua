-- F-241 (D-175): an own cooldown that gets ready while playing says so: the chat line, for the played character
-- a banner and a sound, for another own character the chat line only; nothing for a line that was ready before
-- the addon loaded; in combat it waits and comes once; a line switched off (prof.cdMute) says nothing and the
-- login line leaves it out; "Als Nächstes" names the shortest time left; the sound setting; the load check.
local PC = NS.ProfCooldowns
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
local function said(part)
    local n = 0
    for _, m in ipairs(STUB.messages) do if has(m, part) then n = n + 1 end end
    return n
end
dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")
STUB.player = "Vulo Sturmwind"
_G.GetRealmName = function() return "Kargath" end
STUB.instance = { name = "Durotar", type = "none", id = 0 }
NS.PROF_COOLDOWNS = { [3321] = "310:47", [2330] = "0:95" }
local banners = {}
_G.RaidWarningFrame = {}
_G.RaidNotice_AddMessage = function(_, text) banners[#banners + 1] = text end
local inFight = false
_G.UnitAffectingCombat = function() return inFight end

local t = time()
AmisiaDB.prof = AmisiaDB.prof or { chars = {} }
AmisiaDB.prof.cd = {
    ["Vulo Sturmwind"] = { realm = "Kargath", faction = "A", [3321] = t + 30, [2330] = t - 60 },   -- ready before: silent
    ["Kim Zweit"] = { realm = "Kargath", faction = "A", [2330] = t + 3600 },
}

-- Als Nächstes: the shortest time left that is not ready
local nxt = PC.Next()
assert(nxt and nxt.name == "Vulo Sturmwind" and nxt.group == "c310", nxt and nxt.name)
assert(has(PC.NextText(), "Als Nächstes: Transmutation (Vulo Sturmwind) in 1 Min."), PC.NextText())

-- the played character's transmute gets ready: chat, banner, sound, once
local sounds = #STUB.sounds
STUB.tick(40)
assert(said("Transmutation ist bereit (Vulo Sturmwind).") == 1, "the chat line")
assert(#banners == 1 and banners[1] == "Transmutation ist bereit.", banners[1])
assert(#STUB.sounds == sounds + 1, "the sound")
assert(said("Schwacher Heiltrank ist bereit (Vulo Sturmwind)") == 0, "ready before the load: nothing")
STUB.tick(30)
assert(said("Transmutation ist bereit") == 1 and #banners == 1, "once")

-- the next one is Kim's
assert(PC.Next().name == "Kim Zweit")

-- in combat it waits; another own character: the chat line only
inFight = true
STUB.now = t + 3600 + 1
STUB.tick(10)
assert(said("ist bereit (Kim Zweit)") == 0, "waits in combat")
inFight = false
STUB.tick(10)
assert(said("Schwacher Heiltrank ist bereit (Kim Zweit).") == 1, "after the fight")
assert(#banners == 1 and #STUB.sounds == sounds + 1, "a twink: no banner, no sound")
assert(PC.Next() == nil, "nothing runs")

-- switched off: no alert, not in the login line; the sound setting
local now0 = time()
AmisiaDB.prof.cd["Vulo Sturmwind"][3321] = now0 + 20
AmisiaDB.prof.cd["Kim Zweit"][2330] = now0 + 20
assert(PC.SetMuted("Kim Zweit", "s2330", true) and PC.Muted("Kim Zweit", "s2330"))
assert(PC.SetMuted("Kim Zweit", "x1", true) == false, "a bad line")
NS.Set("prof.cdSound", false)
STUB.tick(30)
assert(said("Transmutation ist bereit (Vulo Sturmwind).") == 2 and #banners == 2, "the banner again")
assert(#STUB.sounds == sounds + 1, "no sound with the sound off")
assert(said("ist bereit (Kim Zweit)") == 1, "a muted line says nothing")
local line = PC.LoginLine()
assert(has(line, "Vulo Sturmwind") and not has(line, "Kim Zweit"), line)

-- the alert off: nothing at all
NS.Set("prof.cdAlert", false)
AmisiaDB.prof.cd["Vulo Sturmwind"][3321] = time() + 10
STUB.tick(20)
assert(said("Transmutation ist bereit (Vulo Sturmwind).") == 2 and #banners == 2, "alert off")
NS.Set("prof.cdAlert", true)
STUB.tick(10)
assert(said("Transmutation ist bereit (Vulo Sturmwind).") == 2, "turned on again: what passed while off stays quiet")

-- the load check: only own characters of prof.cd, only lines, only true
AmisiaDB.prof.cdMute["Fremd Name|c310"] = true
AmisiaDB.prof.cdMute["Vulo Sturmwind|zz"] = true
AmisiaDB.prof.cdMute["Vulo Sturmwind|c310"] = "ja"
NS.ProfCooldownsLoaded(AmisiaDB)
local n = 0
for _ in pairs(AmisiaDB.prof.cdMute) do n = n + 1 end
assert(n == 1 and AmisiaDB.prof.cdMute["Kim Zweit|s2330"] == true, "only the good one stays")
PC.SetMuted("Kim Zweit", "s2330", false)
assert(not PC.Muted("Kim Zweit", "s2330"))
print("prof cooldowns alert ok")
