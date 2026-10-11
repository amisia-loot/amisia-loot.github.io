-- The setup assistant (UI/Setup.lua, D-40): the offer once per login for an officer and never for a
-- raider, "Später" asks again at the next login, "Nicht mehr fragen" and "Fertig" never again; every
-- step shows the current values and writes the existing setting at once through ns.Set; Weiter,
-- Überspringen and Zurück write nothing; the presets create their rule once; the summary's
-- "Ändern" jumps back; the slash words in both languages; a raider gets the short note.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return true end end
    return false
end
local SU = NS._setup
local function win() return SU.frame() end
local function page() return win().pages[SU.step()] end
local function offerShown() return SU.offer() ~= nil and SU.offer():IsShown() end
local function login()
    if AmisiaFrame then AmisiaFrame:Hide() end
    if SU.offer() then SU.offer():Hide() end
    STUB.fire("PLAYER_LOGIN")
end
local function openMain()
    if AmisiaFrame and AmisiaFrame:IsShown() then AmisiaFrame:Hide() end
    NS.ToggleMain()
end

-- a copy of every stored setting, to see that nothing was written
local function snapshot()
    local out = {}
    for sec, t in pairs(AmisiaDB.settings) do
        if type(t) == "table" then for k, v in pairs(t) do out[sec .. "." .. k] = v end end
    end
    return out
end
local function same(a, b)
    for k, v in pairs(a) do if b[k] ~= v then return false, k end end
    for k, v in pairs(b) do if a[k] ~= v then return false, k end end
    return true
end

---------------------------------------------------------------------------
-- the saved key is shaped on load
---------------------------------------------------------------------------
assert(type(AmisiaDB.setup) == "table" and AmisiaDB.setup.done == nil and AmisiaDB.setup.never == nil)
local root = { setup = { done = "x", never = 1789000000, extra = 1 } }
NS.SetupLoaded(root)
assert(root.setup.done == nil and root.setup.never == 1789000000 and root.setup.extra == nil, "fields checked")
NS.SetupLoaded(root)
assert(root.setup.never == 1789000000, "twice without change")
NS.SetupLoaded(AmisiaDB)

---------------------------------------------------------------------------
-- a raider: no offer, the command says it is for officers
---------------------------------------------------------------------------
STUB.officer = false
NS.Set("ui.view", "auto")
assert(not NS.IsOfficerView())
openMain()
assert(AmisiaFrame:IsShown() and not offerShown(), "no offer for a raider")
NS.Dispatch("einrichten")
assert(said("Die Einrichtung ist für Offiziere. Für dich: Einstellungen, Würfel-Fenster."), "the raider's note")
assert(win() == nil or not win():IsShown(), "no window for a raider")

---------------------------------------------------------------------------
-- an officer: the offer once per login; "Später" asks again at the next login
---------------------------------------------------------------------------
STUB.officer = true
login()
openMain()
assert(offerShown(), "the offer at the first open after the login")
local o = SU.offer()
assert(has(o.text:GetText(), "Amisia einrichten? Ein paar Schritte vor dem ersten Raid."))
assert(o.go.label == nil and o.go:GetText() == "Los" and o.later:GetText() == "Später" and o.never:GetText() == "Nicht mehr fragen")
o.later:Click()
assert(not offerShown(), "Später closes it")
assert(AmisiaDB.setup.done == nil and AmisiaDB.setup.never == nil, "Später writes nothing")
openMain()
assert(not offerShown(), "only at the first open of this login")
login()
openMain()
assert(offerShown(), "Später: asked again at the next login")
-- the officer view alone counts too (no officer rank)
SU.offer():Hide()
STUB.officer = false
NS.Set("ui.view", "officer")
login()
openMain()
assert(offerShown(), "the officer view counts")
-- "Los" opens the setup at step 1
SU.offer().go:Click()
assert(not offerShown() and win():IsShown() and SU.step() == 1, "Los opens step 1")
win():Hide()
STUB.officer = true
NS.Set("ui.view", "auto")
-- "Nicht mehr fragen": never again
login()
openMain()
assert(offerShown())
SU.offer().never:Click()
assert(not offerShown() and type(AmisiaDB.setup.never) == "number", "the never mark")
assert(said("Amisia fragt nicht mehr."))
login()
openMain()
assert(not offerShown(), "never asked again")
AmisiaDB.setup.never = nil

---------------------------------------------------------------------------
-- the slash words, the window, the step line
---------------------------------------------------------------------------
NS.Dispatch("setup")
assert(win():IsShown() and SU.step() == 1, "the English word")
win():Hide()
NS.Dispatch("einrichten")
local F = win()
assert(F:IsShown() and F.stepText:GetText() == "Schritt 1 von 6" and F.title:GetText() == "Bank und Entzauberer")
assert(not F.back:IsEnabled() and F.next:IsShown() and F.skip:IsShown() and not F.done:IsShown())

---------------------------------------------------------------------------
-- skipping through every step writes nothing
---------------------------------------------------------------------------
local before = snapshot()
local rulesBefore = #NS.LootRules().list
for k = 1, 5 do
    assert(SU.step() == k)
    if k % 2 == 1 then F.skip:Click() else F.next:Click() end
end
assert(SU.step() == 6 and F.stepText:GetText() == "Schritt 6 von 6" and F.done:IsShown() and not F.next:IsShown())
for _ = 1, 5 do F.back:Click() end
assert(SU.step() == 1)
assert(same(before, snapshot()), "Weiter, Überspringen and Zurück write nothing")
assert(#NS.LootRules().list == rulesBefore, "no rule")

---------------------------------------------------------------------------
-- step 1: bank and disenchanter
---------------------------------------------------------------------------
STUB.guild = { { name = "Vuloo", rank = 1 }, { name = "Bobbington", rank = 3 }, { name = "Kimtaro", rank = 3, online = false } }
STUB.fire("GUILD_ROSTER_UPDATE")
NS.ShowSetup(1)
local p = page()
assert(p.bank.pick.label:GetText():find("leer", 1, true), "empty shows leer")
local names = {}
for _, e in ipairs(p.bank.pick.values) do names[e.value] = true end
assert(names["Vuloo"], "oneself in the list")
assert(p.bank.pick.freeText == "Anderer Name", "free text")
p.bank.pick.onPick("Bobbington")
assert(NS.Get("awards.bankName") == "Bobbington", "the picker writes awards.bankName")
assert(p.bank.pick.label:GetText() == "Bobbington" and p.bank.clear:IsShown())
p.de.me:Click()
assert(NS.Get("awards.deName") == "Vuloo", "Mich eintragen writes awards.deName")
p.de.pick.onPick("Zahl3n", true)
assert(NS.Get("awards.deName") == "Vuloo", "an invalid name is refused like the settings do")
assert(has(F.status:GetText(), "Name ohne Ziffern"), "the reason in the status line")
p.de.clear:Click()
assert(NS.Get("awards.deName") == "", "the X clears it")
p.de.me:Click()
-- reopening shows the current values
F:Hide()
NS.Dispatch("einrichten")
assert(page().bank.pick.label:GetText() == "Bobbington" and page().de.pick.label:GetText() == "Vuloo")

---------------------------------------------------------------------------
-- step 2: the loot lead
---------------------------------------------------------------------------
NS.ShowSetup(2)
p = page()
assert(F.title:GetText() == "Lootleitung" and has(p.intro:GetText(), "!sr"))
assert(p.lead.chips[1].on and not p.lead.chips[2].on, "auto is on")
local fired
NS.Listen("SETTING", function(path, v) if path == "loot.lead" then fired = v end end)
p.lead.chips[2]:Click()
assert(NS.Get("loot.lead") == "me" and fired == "me", "writes loot.lead through ns.Set (SETTING fired)")
assert(p.lead.chips[2].on and not p.lead.chips[1].on)

---------------------------------------------------------------------------
-- step 3: the loot system and its points settings
---------------------------------------------------------------------------
NS.ShowSetup(3)
p = page()
assert(NS.Get("points.system") == "roll" and p.system.chips[1].on)
assert(not p.dkp[1]:IsShown() and not p.epgp[1]:IsShown(), "no points rows for rolling")
p.system.chips[2]:Click()
assert(NS.Get("points.system") == "dkp" and p.dkp[1]:IsShown() and p.dkp[2]:IsShown() and not p.epgp[1]:IsShown())
assert(p.dkp[2].control.current == NS.Get("points.minBid"), "shows the minimum bid")
p.dkp[2].control.plus:Click()
assert(NS.Get("points.minBid") == 11, "the stepper writes points.minBid")
p.dkp[1].chips[2]:Click()
assert(NS.Get("points.dkpMode") == "fixed")
p.system.chips[3]:Click()
assert(NS.Get("points.system") == "epgp" and p.epgp[1]:IsShown() and not p.dkp[1]:IsShown())
p.epgp[1].control.minus:Click()
assert(NS.Get("points.gpBase") == 99, "writes points.gpBase")

---------------------------------------------------------------------------
-- step 4: roll duration and countdown
---------------------------------------------------------------------------
NS.ShowSetup(4)
p = page()
assert(p.seconds.control.current == 20 and p.countdown.control:GetChecked() == true)
p.seconds.control.plus:Click()
assert(NS.Get("rolls.seconds") == 21)
p.countdown.control:Click()
assert(NS.Get("rolls.countdown") == false)
F:Hide()
NS.ShowSetup(4)
assert(page().seconds.control.current == 21 and page().countdown.control:GetChecked() == false, "current values on reopening")

---------------------------------------------------------------------------
-- step 5: the presets create their rule once; the mode
---------------------------------------------------------------------------
NS.ShowSetup(5)
p = page()
assert(#NS.LootRules().list == 0 and has(p.rules:GetText(), "Noch keine Regeln"))
assert(p.presets[1]:GetText() == "Grünes zum Entzaubern" and p.presets[2]:GetText() == "Grünes und Blaues zum Entzaubern"
    and p.presets[3]:GetText() == "Raidmaterialien an die Bank")
p.presets[2]:Click()
local list = NS.LootRules().list
assert(#list == 1 and list[1].k == "q" and list[1].q == 3 and list[1].to == "de")
assert(has(p.rules:GetText(), "1. Qualität bis Selten -> Entzaubern") and has(p.rules:GetText(), "Vuloo"), "the list shows the rule")
p.presets[2]:Click()
assert(#NS.LootRules().list == 1 and has(F.status:GetText(), "Diese Regel gibt es schon."), "no duplicate")
p.presets[3]:Click()
list = NS.LootRules().list
assert(#list == 2 and list[1].k == "m" and list[1].to == "bank" and list[2].k == "q", "materials above the quality rule")
p.presets[3]:Click()
assert(#NS.LootRules().list == 2, "no second materials rule")
p.presets[1]:Click()
list = NS.LootRules().list
assert(#list == 3 and list[3].k == "q" and list[3].q == 2)
assert(has(p.rules:GetText(), "1. Raidmaterialien -> Bank"))
assert(p.mode.chips[1].on)
p.mode.chips[2]:Click()
assert(NS.Get("lootrules.mode") == "click")

---------------------------------------------------------------------------
-- step 6: the summary, "Ändern" jumps, "Fertig" saves the done mark
---------------------------------------------------------------------------
F.next:Click()
assert(SU.step() == 6)
p = page()
local texts = {}
for _, r in ipairs(p.lines) do if r:IsShown() then texts[#texts + 1] = r.text:GetText() end end
local all = table.concat(texts, "\n")
assert(has(all, "Bank-Charakter: Bobbington") and has(all, "Entzauberer: Vuloo"), all)
assert(has(all, "Ansage und !sr-Antworten: Immer ich") and has(all, "Lootsystem: EPGP"), all)
assert(has(all, "Roll-Dauer (Sekunden): 21") and has(all, "Countdown ansagen: aus") and has(all, "Lootregeln: 3"), all)
local jump
for _, r in ipairs(p.lines) do if r:IsShown() and has(r.text:GetText(), "Roll-Dauer") then jump = r end end
assert(jump.change:GetText() == "Ändern")
jump.change:Click()
assert(SU.step() == 4 and F.title:GetText() == "Roll-Dauer", "Ändern jumps to its step")
NS.ShowSetup(6)
assert(AmisiaDB.setup.done == nil)
F.done:Click()
assert(type(AmisiaDB.setup.done) == "number" and not F:IsShown(), "the done mark")
assert(said("Einrichtung fertig."))
login()
openMain()
assert(not offerShown(), "no offer after Fertig")
-- the command opens it again, at step 1, with the values
NS.Dispatch("einrichten")
assert(win():IsShown() and SU.step() == 1)

print("test_setup ok")
