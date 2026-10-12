-- The page "Raid-Check" (UI/Pages/RaidCheck.lua, F-098/F-099): officers only (a raider has no page
-- and no row, /amisia raidcheck gives a raider the own line); the views Buffs & Verbrauch (cells red
-- when missing, "laut Amisia" out of sight), Ausrüstung (durability red/orange, "-" without Amisia,
-- free points grey below the highest level), Raid-IDs (instance, filters, grouped by main); "Prüfen"
-- in combat says "Nicht im Kampf." and sends nothing, the page shows the last values with their time;
-- "Im Raid-Chat sagen" only with its setting, grey in the lockdown; the "ID" marks of the lineup.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return m end end
    return nil
end

STUB.player, STUB.class, STUB.level = "Vuloo", "PRIEST", 60
STUB.guild = { { name = "Vuloo", rank = 2, class = "PRIEST" }, { name = "Fraktur", rank = 3, class = "SHAMAN" },
               { name = "Chorf", rank = 3, class = "WARRIOR" }, { name = "Vulo Hunt", rank = 3, class = "HUNTER", level = 60 },
               { name = "Vulo Pala", rank = 3, class = "PALADIN", level = 52 } }
STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" }, { name = "Chorf", class = "WARRIOR" } }
STUB.playerRaidIndex = 1
STUB.fire("PLAYER_ENTERING_WORLD")
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.tick(2)
local AURAS = {}
_G.C_UnitAuras = { GetAuraDataByIndex = function(unit, i) local l = AURAS[unit] return l and l[i] end }
local function aura(id, dur) return { name = "Buff " .. id, spellId = id, duration = dur, expirationTime = GetTime() + dur } end
AURAS.raid1 = { aura(17626, 7200), aura(19705, 900), aura(10938, 1800) }
AURAS.player = AURAS.raid1
AURAS.raid2 = { aura(10938, 1800) }
AURAS.raid3 = { aura(17538, 3600), aura(19705, 900), aura(10938, 1800) }

-- a raider: no page, no row; the command gives the own line
NS.Set("ui.view", "raider")
assert(not NS.Visible(NS.Panel("raidcheck")))
STUB.messages = {}
NS.Dispatch("raidcheck")
assert(NS.CurrentPage() ~= "raidcheck" and said("Raid-Check: Fläschchen ja"), "the own line, no page")

-- the officer
NS.Set("ui.view", "officer")
NS.Dispatch("raidcheck")
assert(NS.CurrentPage() == "raidcheck")
local f = NS.RaidCheckPageFrame()
local function rowOf(list, name)
    for _, r in ipairs(list.rows) do
        if r:IsShown() and r.item and (r.item.name or r.item.n) == name then return r end
    end
end
assert(f.buffView:IsShown() and not f.gearView:IsShown() and not f.idView:IsShown())
assert(has(f.line:GetText(), "Es fehlt: 1 Fläschchen, 1 Essen"), f.line:GetText())
local r = rowOf(f.buffList, "Fraktur")
assert(has(r.flask:GetText(), "fehlt") and has(r.food:GetText(), "fehlt") and has(r.flask:GetText(), "|cffe0574a"), "red when missing")
r = rowOf(f.buffList, "Chorf")
assert(has(r.flask:GetText(), "-") and has(r.elixir:GetText(), "1") and has(r.food:GetText(), "ja"), "an elixir supplies")
r = rowOf(f.buffList, "Vuloo")
assert(has(r.ver:GetText(), NS.VERSION))
assert(f.check:IsShown() and not f.say:IsShown() and not f.ask:IsShown(), "the chat button only with its setting")
NS.Set("raidcheck.chat", true)
NS.Refresh()
assert(f.say:IsShown() and f.say:IsEnabled())
STUB.chatLock = true
NS.Refresh()
assert(f.say:IsShown() and not f.say:IsEnabled(), "grey in the lockdown")
STUB.chatLock = false

-- gear: the own report, the others' (XA), "-" without Amisia
NS._raidcheck.answers()["fraktur"] = { name = "Fraktur", at = time() - 120, dur = 24, below = 2, ilvl = 61.3, empty = { 2 }, unench = {}, free = 3,
                                        heard = true, cons = { elixirs = {}, have = {} } }
f.views.gear:Click()
assert(f.gearView:IsShown() and has(f.line:GetText(), "2 von 3 mit Amisia"), f.line:GetText())
r = rowOf(f.gearList, "Fraktur")
assert(has(r.dur:GetText(), "24 % (2)") and has(r.dur:GetText(), "|cffe0574a"), r.dur:GetText())
assert(has(r.ilvl:GetText(), "61.3") and has(r.empty:GetText(), "1") and has(r.at:GetText(), "vor 2 Min."))
r = rowOf(f.gearList, "Chorf")
assert(has(r.ilvl:GetText(), "-") and r.dur:GetText() == "", "no Amisia: -")
NS._raidcheck.answers()["chorf"] = { name = "Chorf", at = time(), dur = 45, below = 0, empty = {}, unench = {}, free = 4, level = 52,
                                      heard = true, cons = { elixirs = {}, have = {} } }
NS.Refresh()
r = rowOf(f.gearList, "Chorf")
assert(has(r.dur:GetText(), "|cffe0a344"), "orange under 50")

-- combat: "Prüfen" sends nothing, the last values with their time
STUB.addon = {}
STUB.combat = true
STUB.messages = {}
f.check:Click()
assert(said("Nicht im Kampf."), "the reason in the chat")
assert(has(f.line:GetText(), "Im Kampf: Werte von"), f.line:GetText())
assert(not f.check:IsEnabled())
STUB.tick(2)
for _, m in ipairs(STUB.addon) do assert(not m.text:find("^1X[QA]"), "nothing of the raid check in combat: " .. m.text) end
STUB.combat = false
NS.Refresh()
f.check:Click()
STUB.tick(1)
local xq = 0
for _, m in ipairs(STUB.addon) do if m.text:find("^1XQ") then xq = xq + 1 end end
assert(xq == 1, "out of combat it asks")

-- raid IDs
local now = math.floor(STUB.now)
AmisiaDB.raidcheck.own["Vulo Pala"] = { at = now, c = "PALADIN", l = 52, ids = { { m = 409, d = 9, r = now + 86400, k = 4, t = 10 } } }
AmisiaDB.raidcheck.own["Vulo Hunt"] = { at = now, c = "HUNTER", l = 60, ids = {} }
AmisiaDB.raidcheck.names[409] = "Geschmolzener Kern"
NS.ImportSiteText("#AMISIA-ALTS 1 forever 2026-10-12\nA Vulo_Pala Vulo_Hunt\n#END")
f.views.ids:Click()
assert(f.idView:IsShown() and f.ask:IsShown() and not f.check:IsShown())
assert(has(f.line:GetText(), "Geschmolzener Kern: 1 frei · 1 gesperrt · 3 unbekannt"), f.line:GetText())
r = rowOf(f.idList, "Vulo Pala")
assert(r and has(r.state:GetText(), "gesperrt (4/10, Reset "), "locked with bosses and reset")
assert(select(4, r.name:GetPoint(1)) == 18, "an alt indented")
assert(has(rowOf(f.idList, "Vulo Hunt").state:GetText(), "frei"))
f.onlyFree:Click()
assert(not rowOf(f.idList, "Vulo Pala") and rowOf(f.idList, "Vulo Hunt"), "only free")
f.onlyFree:Click()
f.onlyTop:Click()
assert(not rowOf(f.idList, "Vulo Pala"), "level 52 is not 60")
f.onlyTop:Click()
STUB.messages = {}
f.ask:Click()
assert(said("die Gilde ist gefragt"))
assert(not f.ask:IsEnabled(), "not again within 5 minutes")

-- the lineup: "ID" per name for the chosen instance
NS.SetLineupText("Tanks\nVulo Pala\nVulo Hunt\nChorf")
NS.ShowLineup("match", NS.LineupTonight())
local lf = NS.LineupPageFrame()
assert(lf.raidIdPick:IsShown(), "the instance picker")
local function lrow(name)
    for _, x in ipairs(lf.mlist.rows) do
        if x:IsShown() and x.item and x.item.e.n == name then return x end
    end
end
assert(has(lrow("Vulo Pala").id:GetText(), "|cffe0574aID"), "red: locked")
assert(has(lrow("Vulo Hunt").id:GetText(), "|cff4fbf7aID"), "green: free")
assert(has(lrow("Chorf").id:GetText(), "|cff8f86a3ID"), "grey: unknown")
-- the tooltip (bosses, reset, the free alts of the main) draws without an error
lrow("Vulo Pala").scripts.OnEnter(lrow("Vulo Pala"))
local free = NS.RaidIDFreeAlts("Vulo Pala", 409)
assert(#free == 1 and free[1] == "Vulo Hunt")
-- "aus" takes the marks away
lf.raidIdPick.onPick(0)
assert(lrow("Vulo Pala").id:GetText() == "", "no marks")
