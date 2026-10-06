-- BiS picks (ns.BIS.PICK from tools/bis_picks.json): a hand-kept item goes first in its slot for
-- its spec and level range, the computed options below it; the weapon plan decides whether a
-- two-hand pick counts; bis.picks switches them off; the own targets, ns.UpgradeOf, ns.BisGain,
-- the explanation, the item tooltip and the gear page treat the pick as the slot's target. Every
-- check runs, the failures are listed together.
local Gear = NS.Gear
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local REAL_GEAR, REAL_W, REAL_BIS = NS.GEAR, NS.GEAR_WEIGHTS, NS.BIS
local PICK_ID = 280604
local NOTE = "BiS für Verstärkung auf Stufe 30; ihr Effekt fehlt in der Wertung."
local LINKS = {}

local function fixture()
    STUB.class, STUB.level, STUB.faction = "SHAMAN", 31, "Alliance"
    STUB.worn = {}
    NS.GEAR = { built = "test-picks", Z = {}, cap = 60,
        S = { { "V", "Händler", 1429, "" } },
        I = {
            [201] = { "2HWEAPON", 2, 5, 25, 3, 1, 35, 0, 3.4, 0, 1 },
            [202] = { "WEAPON", 2, 4, 25, 3, 1, 35, 0, 2.6, 0, 1 },
            [203] = { "SHIELD", 4, 6, 25, 3, 1, 35, 0, 0, 0, 1 },
            [204] = { "HEAD", 4, 2, 1, 3, 1, 30, 0, 0, 0, 1 },
            [205] = { "HEAD", 4, 2, 1, 3, 1, 30, 0, 0, 0, 1 },
        },
        ST = {
            [201] = "DAMAGE_PER_SECOND=30;STRENGTH=40", [202] = "DAMAGE_PER_SECOND=20;STRENGTH=10",
            [203] = "STRENGTH=8", [204] = "STRENGTH=30", [205] = "STRENGTH=5",
        },
    }
    local function spec(key, name, w) return { key = key, name = name, role = "dps", unit = "AP", why = "Test.", all = w } end
    NS.GEAR_WEIGHTS = { brackets = { 60 }, order = { "SHAMAN" }, ratings = REAL_W.ratings,
        specs = { SHAMAN = {
            spec("ele", "Elementar", { SP = 1, INT = 0.5, STR = 0 }),
            spec("enh", "Verstärkung", { AP = 1, STR = 2, DPS = 14, INT = 0.1, STA = 0.1 }),
        } } }
    NS.BIS = {
        SC = { [PICK_ID] = "INTELLECT=16;STAMINA=15" },
        EF = { V = 1, C = 2, A = 2, Q = 2, D = 3, R = 8, W = 20, P = 25, X = 6, DMAX = 30 },
        PICK = {
            { class = "SHAMAN", spec = "enh", from = 30, to = 34, slot = "MAINHAND", item = PICK_ID, note = NOTE,
              src = "Quelle noch unbekannt" },
            { class = "SHAMAN", spec = "enh", from = 30, to = 34, slot = "HEAD", item = 205, note = "Kopf-Test",
              src = "Quelle unbekannt" },
        },
        PI = { [PICK_ID] = { "2HWEAPON", 2, 5, 30, 3, 1, 40, 0, 3.6, 0, name = "Rage of the Storm" } },
    }
    -- the client knows every item; the pick's damage is low, its stats do not show its effect
    local function item(id, name, loc, classID, sub, stats)
        LINKS[id] = STUB.item(id, name, 3)
        local it = STUB.items[id]
        it.equipLoc, it.classID, it.subclassID, it.stats, it.minLevel = "INVTYPE_" .. loc, classID, sub, stats, 25
    end
    item(201, "Großer Hammer", "2HWEAPON", 2, 5, { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 30, ITEM_MOD_STRENGTH_SHORT = 40 })
    item(202, "Streitkolben", "WEAPON", 2, 4, { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 20, ITEM_MOD_STRENGTH_SHORT = 10 })
    item(203, "Schild", "SHIELD", 4, 6, { ITEM_MOD_STRENGTH_SHORT = 8 })
    item(204, "Helm A", "HEAD", 4, 2, { ITEM_MOD_STRENGTH_SHORT = 30 })
    item(205, "Helm B", "HEAD", 4, 2, { ITEM_MOD_STRENGTH_SHORT = 5 })
    item(PICK_ID, "Wut des Sturms", "2HWEAPON", 2, 5,
        { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 20, ITEM_MOD_INTELLECT_SHORT = 16, ITEM_MOD_STAMINA_SHORT = 15 })
    STUB.items[PICK_ID].minLevel = 1
    Gear._reset()
    NS.BisBump()
    NS.BisSetSpec("enh")
    STUB.fire("PLAYER_EQUIPMENT_CHANGED")
end
local function restore()
    NS.GEAR, NS.GEAR_WEIGHTS, NS.BIS = REAL_GEAR, REAL_W, REAL_BIS
    STUB.worn = {}
    NS.Reset("bis.picks")
    Gear._reset()
    NS.BisBump()
end

local failures = {}
local function check(name, fn)
    local ok, err = pcall(fn)
    if not ok then failures[#failures + 1] = name .. ": " .. tostring(err) end
    restore()
end
local function idsOf(list)
    local out = {}
    for i, e in ipairs(list or {}) do out[i] = tostring(e[1] or e.id) end
    return table.concat(out, ",")
end

check("1 the pick goes first, the computed options stay below", function()
    fixture()
    local row = Gear.Item(PICK_ID)
    assert(row and row[1] == "2HWEAPON" and row[4] == 30 and row[9] == 3.6 and row.name == "Rage of the Storm",
        "the pick's row from ns.BIS.PI")
    assert(#Gear.Sources(PICK_ID) == 0, "no source")
    local r = NS.BisFor("SHAMAN", "enh", 34)
    assert(r.MAINHAND[1][1] == PICK_ID and r.MAINHAND[1].pick and r.MAINHAND[1].pick.note == NOTE,
        "the pick first: " .. idsOf(r.MAINHAND))
    assert(r.MAINHAND[2] and r.MAINHAND[2][1] == 201, "the best computed two-hander below: " .. idsOf(r.MAINHAND))
    assert(r.MAINHAND[2][2] > r.MAINHAND[1][2], "the pick scores less on stats alone")
    assert(r.plan == "2H" and #r.OFFHAND == 0, "a two-hand pick makes the plan two-hand")
    assert(idsOf(r.HEAD) == "205,204" and r.HEAD[1].pick.note == "Kopf-Test", "a head pick too: " .. idsOf(r.HEAD))
    assert(not r.HEAD[2].pick, "only the pick is marked")
end)

check("2 only in its level range and spec", function()
    fixture()
    for _, lvl in ipairs({ 29, 35 }) do
        local r = NS.BisFor("SHAMAN", "enh", lvl)
        for _, e in ipairs(r.MAINHAND) do assert(e[1] ~= PICK_ID, "no pick at " .. lvl) end
        assert(r.HEAD[1][1] == 204, "the computed head at " .. lvl)
    end
    assert(NS.BisFor("SHAMAN", "enh", 30).MAINHAND[1][1] == PICK_ID, "from 30")
    local r = NS.BisFor("SHAMAN", "ele", 32)
    for _, e in ipairs(r.MAINHAND) do assert(not e.pick, "no pick for another spec") end
end)

check("3 the weapon plan decides", function()
    fixture()
    local r = NS.BisFor("SHAMAN", "enh", 32, { plan = "SHIELD" })
    assert(r.plan == "1H" and r.MAINHAND[1][1] == 202 and r.OFFHAND[1][1] == 203, "weapon and shield: " .. idsOf(r.MAINHAND))
    for _, e in ipairs(r.MAINHAND) do assert(e[1] ~= PICK_ID, "no two-hand pick with a shield plan") end
    for _, e in ipairs(r.altMainhand or {}) do assert(not e.pick, "not marked among the alternatives either") end
    r = NS.BisFor("SHAMAN", "enh", 32, { plan = "2H" })
    assert(r.plan == "2H" and r.MAINHAND[1][1] == PICK_ID, "the two-hand plan takes it")
end)

check("4 bis.picks off", function()
    fixture()
    assert(NS.Get("bis.picks") == true, "on by default")
    assert(NS.Set("bis.picks", false))
    local r = NS.BisFor("SHAMAN", "enh", 32)
    assert(r.MAINHAND[1][1] == 201 and r.HEAD[1][1] == 204, "switched off: the computed order " .. idsOf(r.MAINHAND))
    for _, e in ipairs(r.MAINHAND) do assert(e[1] ~= PICK_ID, "the pick has no source: not listed at all") end
    local o = NS.BisOpts()
    assert(o.picks == false, "the option carries the switch")
    assert(NS.BisTargets().MAINHAND[1].id == 201, "the own targets too")
    NS.Reset("bis.picks")
    local b = Gear.Best({ class = "SHAMAN", spec = "enh", kind = "Speedrun", level = 32, sources = { V = true }, picks = false })
    assert(b.MAINHAND[1][1] == 201, "Gear.Best's own switch")
end)

check("5 the own targets, the upgrade and the gain", function()
    fixture()
    local t = NS.BisTargets()
    local first = t.MAINHAND[1]
    assert(first.id == PICK_ID and first.pick and first.upgrade == true, "the pick is the target")
    assert(t.state.MAINHAND == "upgrade", "the slot wants it: " .. tostring(t.state.MAINHAND))
    STUB.worn[16] = LINKS[201]
    STUB.fire("PLAYER_EQUIPMENT_CHANGED")
    t = NS.BisTargets()
    assert(t.MAINHAND[1].gain < 0 and t.MAINHAND[1].upgrade == true, "a target even below the worn hammer by stats")
    local u = NS.UpgradeOf(LINKS[PICK_ID])
    assert(u and u.up == true and u.pick and u.pick.note == NOTE, "ns.UpgradeOf: an upgrade")
    -- the pick worn: nothing else is an upgrade for the slot
    STUB.worn[16] = LINKS[PICK_ID]
    STUB.fire("PLAYER_EQUIPMENT_CHANGED")
    t = NS.BisTargets()
    assert(t.MAINHAND[1].worn and t.state.MAINHAND == "done", "worn: done")
    assert(t.MAINHAND[2] and t.MAINHAND[2].id == 201 and t.MAINHAND[2].upgrade == false, "the hammer is no upgrade")
    u = NS.UpgradeOf(LINKS[201])
    assert(u and u.up == false and u.pickWorn, "ns.UpgradeOf: no upgrade while the pick is worn")
    local gain = NS.BisGain(LINKS[201])
    assert(gain == 0, "ns.BisGain: nothing to gain " .. tostring(gain))
    u = NS.UpgradeOf(LINKS[202])
    assert(not u or u.up == false, "nor a one-hander (a weapon switch)")
    -- another row: its pick is not worn, so a better item there still counts by its stats
    assert(NS.UpgradeOf(LINKS[204]).up == true, "the stronger head is an upgrade while the head pick is not worn")
    assert(NS.UpgradeOf(LINKS[205]).up == true, "the head pick itself")
end)

check("6 explanation, tooltip and page", function()
    fixture()
    local lines = NS.BisExplain(PICK_ID)
    local all = table.concat(lines, "\n")
    assert(has(all, "BiS-Empfehlung") and has(all, NOTE), all)
    assert(not has(all, "Gilde"), all)
    local tip = NS.BisTooltipLines(LINKS[PICK_ID])
    local text = {}
    for _, l in ipairs(tip or {}) do text[#text + 1] = l[1] end
    text = table.concat(text, "\n")
    assert(has(text, "BiS-Empfehlung") and has(text, NOTE), "tooltip: " .. text)
    STUB.worn[16] = LINKS[PICK_ID]
    STUB.fire("PLAYER_EQUIPMENT_CHANGED")
    NS.BisBump()
    tip = NS.BisTooltipLines(LINKS[201])
    for _, l in ipairs(tip or {}) do assert(not has(l[1], "Upgrade für dich"), "no upgrade line: " .. l[1]) end
    STUB.worn[16] = nil
    STUB.fire("PLAYER_EQUIPMENT_CHANGED")
    NS.BisBump()
    -- the page: badge and source on the option
    NS.ShowGear("goals", "MAINHAND")
    local f = NS.GearPageFrame()
    local b = f.goals.opts[1]
    assert(has(plain(b.name:GetText()), "BiS-Empfehlung"), "badge: " .. plain(b.name:GetText()))
    assert(has(plain(b.src:GetText()), "Quelle noch unbekannt"), "source: " .. plain(b.src:GetText()))
    assert(has(plain(f.goals.explain:GetText()), NOTE), "explanation: " .. plain(f.goals.explain:GetText()))
    -- the level-range planner shows it in both views without errors
    AmisiaDB.settings.gear = { class = "SHAMAN", specs = { SHAMAN = "enh" }, col = 6, view = "list" }
    if not (AmisiaGearFrame and AmisiaGearFrame:IsShown()) then NS.ToggleGearFrame() end
    NS.GearRefresh(true)
    AmisiaDB.settings.gear.view = "overview"
    NS.GearRefresh(true)
    AmisiaGearFrame:Hide()
end)

check("7 a setting exists with a neutral label", function()
    local found = NS.SettingItem("bis.picks")
    assert(found and found.default == true and found.label == "BiS-Empfehlungen zeigen", "setting entry")
end)

check("8 the committed data: Rage of the Storm for Enhancement at 30-34", function()
    assert(type(NS.BIS.PICK) == "table" and #NS.BIS.PICK >= 1, "BisData.lua has picks")
    local row = Gear.Item(PICK_ID)
    assert(row and row[1] == "2HWEAPON" and row[4] == 30, "its row")
    local r = NS.BisFor("SHAMAN", "enh", 34)
    assert(r.MAINHAND[1][1] == PICK_ID and r.MAINHAND[1].pick and r.plan == "2H", "first at 34")
    assert(r.MAINHAND[2] and r.MAINHAND[2][1] ~= PICK_ID, "the computed options below")
    assert(NS.BisFor("SHAMAN", "enh", 29).MAINHAND[1][1] ~= PICK_ID, "not at 29")
    assert(NS.BisFor("SHAMAN", "ele", 34).MAINHAND[1][1] ~= PICK_ID, "not for Elemental")
end)

assert(#failures == 0, table.concat(failures, "\n"))
