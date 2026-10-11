-- The registry: settings with defaults, checks, reset, migration; slash commands; messages; panels.
assert(NS.RegisterSettings and NS.Get and NS.Set, "registry loaded")

NS.RegisterSettings{ key = "t", label = "Test", order = 1, items = {
    { key = "t.on", type = "toggle", label = "An", default = true },
    { key = "t.n", type = "slider", label = "Zahl", default = 20, min = 5, max = 120, step = 5 },
    { key = "t.at", type = "time", allowOff = true, label = "Zeit", default = 20 * 60 },
    { key = "t.mode", type = "choice", label = "Modus", default = "a", values = { { "a", "A" }, { "b", "B" } } },
    { key = "t.go", type = "button", label = "Los", run = function() end },
}}

-- defaults
assert(NS.Get("t.on") == true and NS.Get("t.n") == 20 and NS.Get("t.at") == 1200 and NS.Get("t.mode") == "a")
assert(NS.IsDefault("t.n"))

-- set, check, step rounding
local changed = {}
NS.Listen("SETTING", function(path, v) changed[#changed + 1] = path .. "=" .. tostring(v) end)
assert(NS.Set("t.n", 33) and NS.Get("t.n") == 35, "rounded to the step")
assert(changed[#changed] == "t.n=35")
assert(not NS.Set("t.n", 500), "out of range refused")
assert(not NS.Set("t.on", "ja"), "a toggle takes booleans")
assert(NS.Set("t.on", false) and NS.Get("t.on") == false, "false is a value, not the default")
assert(NS.Set("t.at", "19:30") and NS.Get("t.at") == 1170)
assert(NS.Set("t.at", "aus") and NS.Get("t.at") == false, "off when allowed")
assert(not NS.Set("t.at", "25:00"))
assert(not NS.Set("t.mode", "c") and NS.Set("t.mode", "b"))
assert(not NS.Set("t.go", true), "buttons hold no value")
assert(not NS.Set("nope.x", 1))
assert(not NS.IsDefault("t.n"))
NS.Reset("t.n")
assert(NS.Get("t.n") == 20 and NS.IsDefault("t.n"))

-- time helpers
assert(NS.ParseTime("8") == 480 and NS.ParseTime("20.15") == 1215 and NS.ParseTime("aus", true) == false and NS.ParseTime("aus") == nil)
assert(NS.FormatTime(1215) == "20:15" and NS.FormatTime(false) == "aus")

-- migration from the flat settings of 1.3 and a stored value that no longer passes
local root = { settings = { enabled = false, lateAt = false, rollSeconds = 30, collect = true,
                            minimap = { hide = true, angle = 90 }, t = { n = 999 } },
               scan = { rate = 50 } }
NS.ApplySettings(root)
local s = root.settings
assert(s.version == 2)
assert(s.record.enabled == false and s.record.lateAt == false and s.rolls.seconds == 30 and s.tools.collect == true)
assert(s.ui.minimap == false and s.minimap.angle == 90 and s.minimap.hide == nil)
assert(s.tools.scanRate == 50)
assert(s.enabled == nil and s.lateAt == nil and s.rollSeconds == nil and s.collect == nil)
assert(s.t.n == nil, "an invalid stored value falls back to the default")
NS.ApplySettings(root)
assert(s.rolls.seconds == 30, "a second run changes nothing")

-- slash commands, help, unknown word
local got
NS.RegisterSlash("testcmd", { aliases = { "tc" }, args = "<x>", desc = "Testbefehl", run = function(rest) got = rest end })
SlashCmdList.AMISIA("testcmd hallo welt"); assert(got == "hallo welt")
SlashCmdList.AMISIA("TC eins"); assert(got == "eins", "aliases, any case")
STUB.messages = {}
SlashCmdList.AMISIA("gibtsnicht")
assert(STUB.messages[1]:find("Unbekannter Befehl", 1, true))
local help = table.concat(NS.SlashHelpLines(true), "\n")
assert(help:find("/amisia testcmd <x> - Testbefehl", 1, true) and help:find("/amisia hilfe", 1, true))

-- a broken message handler reaches the error handler
NS.Listen("BOOM", function() error("kaputt") end)
assert(not pcall(NS.Fire, "BOOM"), "the error is reported")

-- panels and visibility
NS.RegisterPanel{ key = "zz", label = "Z", order = 99, create = function(p) return CreateFrame("Frame", nil, p) end }
NS.RegisterPanel{ key = "aa", label = "A", order = 1, officer = true, create = function(p) return CreateFrame("Frame", nil, p) end }
assert(NS.Panel("aa") and NS.panels[1].order <= NS.panels[#NS.panels].order, "sorted by order")
STUB.officer = true
assert(NS.IsOfficerView() and NS.Visible(NS.Panel("aa")))
STUB.officer = false
assert(not NS.IsOfficerView() and not NS.Visible(NS.Panel("aa")))
NS.Set("ui.view", "officer"); assert(NS.IsOfficerView(), "forced officer view")
NS.Set("ui.view", "raider"); STUB.officer = true; assert(not NS.IsOfficerView(), "forced raider view")
NS.Reset("ui.view")
assert(not NS.Visible({ expert = true }) and NS.Set("ui.expert", true) and NS.Visible({ expert = true }))
assert(not NS.Visible({ available = function() return false end }))
NS.Reset("ui.expert")
