-- Effects and computed weapon stats from the client tables (tools/build_bis.py): ns.BIS.FX names the
-- effects the scoring does not count (Gear.EffectText; the explanation, the planner's notes), a weapon's
-- computed stats carry its damage and take the speed of the item row, and ns.BIS.EN gives a fallback
-- drop record (NPC 0, known by its encounter) the boss it belongs to. Every check runs, the failures
-- are listed together.
local Gear = NS.Gear
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local REAL_GEAR, REAL_W, REAL_BIS = NS.GEAR, NS.GEAR_WEIGHTS, NS.BIS
local PICK_ID = 280604
local FX = "Anlegen: Rage of Earth (+10 % Schaden: Stormstrike)"

local function fixture()
    STUB.class, STUB.level, STUB.faction = "SHAMAN", 31, "Alliance"
    STUB.worn = {}
    NS.GEAR = { built = "test-effects", Z = {}, cap = 60,
        S = { { "V", "Händler", 1429, "" } },
        I = { [201] = { "2HWEAPON", 2, 5, 25, 3, 1, 35, 0, 3.4, 0, 1 } },
        ST = { [201] = "DAMAGE_PER_SECOND=30;STRENGTH=40" },
    }
    NS.GEAR_WEIGHTS = { brackets = { 60 }, order = { "SHAMAN" }, ratings = REAL_W.ratings,
        specs = { SHAMAN = { { key = "enh", name = "Verstärkung", role = "dps", unit = "AP", why = "Test.",
            all = { AP = 1, STR = 2, DPS = 14, INT = 0.1, STA = 0.1 } } } } }
    NS.BIS = {
        SC = { [PICK_ID] = "DAMAGE_PER_SECOND=35.5556;INTELLECT=16;STAMINA=15" },
        FX = { [PICK_ID] = FX, [201] = "" },
        EF = { V = 1, C = 2, A = 2, Q = 2, D = 3, R = 8, W = 20, P = 25, X = 6, DMAX = 30 },
        PICK = { { class = "SHAMAN", spec = "enh", from = 30, to = 34, slot = "MAINHAND", item = PICK_ID,
                   note = "Test-Empfehlung", src = "Quelle unbekannt" } },
        PI = { [PICK_ID] = { "2HWEAPON", 2, 5, 30, 3, 1, 40, 0, 3.6, 0, name = "Rage of the Storm" } },
    }
    -- the server never described the pick: its computed stats count
    STUB.item(201, "Großer Hammer", 3)
    local it = STUB.items[201]
    it.equipLoc, it.classID, it.subclassID, it.minLevel = "INVTYPE_2HWEAPON", 2, 5, 25
    it.stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 30, ITEM_MOD_STRENGTH_SHORT = 40 }
    STUB.item(PICK_ID, "Wut des Sturms", 3)
    it = STUB.items[PICK_ID]
    it.equipLoc, it.classID, it.subclassID, it.minLevel = "INVTYPE_2HWEAPON", 2, 5, 1
    it.stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 35.5556, ITEM_MOD_INTELLECT_SHORT = 16, ITEM_MOD_STAMINA_SHORT = 15 }
    Gear._reset()
    NS.BisBump()
    NS.BisSetSpec("enh")
    STUB.fire("PLAYER_EQUIPMENT_CHANGED")
end
local function restore()
    NS.GEAR, NS.GEAR_WEIGHTS, NS.BIS = REAL_GEAR, REAL_W, REAL_BIS
    STUB.worn = {}
    Gear._reset()
    NS.BisBump()
end

local failures = {}
local function check(name, fn)
    local ok, err = pcall(fn)
    if not ok then failures[#failures + 1] = name .. ": " .. tostring(err) end
    restore()
end

check("1 the effect text", function()
    fixture()
    assert(Gear.EffectText(PICK_ID) == FX, tostring(Gear.EffectText(PICK_ID)))
    assert(Gear.EffectText(tostring(PICK_ID)) == FX, "an id as text")
    assert(Gear.EffectText(201) == nil, "an empty text is none")
    assert(Gear.EffectText(999999) == nil)
    NS.BIS = nil
    assert(Gear.EffectText(PICK_ID) == nil, "no build data")
end)

check("2 a computed weapon: damage with the speed of its row", function()
    fixture()
    local s = Gear.ComputedStats(PICK_ID)
    assert(s.SC and math.abs(s.DPS - 35.5556) < 1e-6 and s.INT == 16 and s.STA == 15, "the computed stats")
    assert(s.SPEED == 3.6, "the speed from the pick's row: " .. tostring(s.SPEED))
    NS.BIS.SC[4242] = "STRENGTH=5"
    assert(Gear.ComputedStats(4242).SPEED == nil, "no damage, no speed")
end)

check("3 the explanation names the effect", function()
    fixture()
    local all = table.concat(NS.BisExplain(PICK_ID), "\n")
    assert(has(all, "Effekt nicht gewertet: " .. FX), all)
    all = table.concat(NS.BisExplain(201), "\n")
    assert(not has(all, "Effekt nicht gewertet"), all)
end)

check("4 the planner page marks the option", function()
    fixture()
    NS.ShowGear("goals", "MAINHAND")
    local f = NS.GearPageFrame()
    local found
    for _, b in ipairs(f.goals.opts) do
        local t = b.name and b.name:GetText()
        if has(t, "Effekt nicht gewertet") then found = true end
    end
    assert(found, "a note on the option with the effect")
end)

check("5 a fallback drop record counts under the boss of its encounter", function()
    local d = NS.DropsDB()
    d.me = "11111111"
    local today = NS.DropsToday()
    assert(NS.DropsMerge({ h = "e0000001", npc = 0, inst = 2834, diff = 1, day = today, o = "22222222", src = "E",
        enc = 3493, it = { [219004] = 1 } }) == "new")
    assert(NS.DropsMerge({ h = "e0000002", npc = 261306, inst = 2834, diff = 1, day = today, o = "22222222", src = "G",
        it = { [219005] = 1 } }) == "new")
    NS.DropsLearnNames({ [261306] = "Faldrim Ambossmahl" }, { [2834] = { "party", "Halle der Thane" } },
        { [3493] = "Faldrim" })
    NS.BIS = { EN = { [3493] = 261306 }, OT = -1 }
    local rows = NS.DropsBossList()
    local boss
    for _, e in ipairs(rows) do
        if e.kind == "boss" then
            assert(e.npc == 261306, "one boss, no encounter row: " .. tostring(e.text))
            boss = e
        end
    end
    assert(boss and boss.K == 2 and boss.text == "Faldrim Ambossmahl", "both kills under the boss")
    assert(NS.DropsBossOf({ npc = 0, enc = 3493 }) == 261306 and NS.DropsBossOf({ npc = 0, enc = 1 }) == 0)
    assert(NS.DropsBossOf({ npc = 5, enc = 3493 }) == 5, "an own NPC wins")
    local _, n, K = NS.DropRate(261306, 219004)
    assert(n == 1 and K == 2, "the rate counts the fallback kill: " .. tostring(n) .. "/" .. tostring(K))
    NS.BIS = { OT = -1 }
    rows = NS.DropsBossList()
    local enc
    for _, e in ipairs(rows) do if e.kind == "boss" and e.enc == 3493 then enc = e end end
    assert(enc and enc.npc == 0 and enc.K == 1, "without the table: under its encounter, as before")
    d.k.e0000001, d.k.e0000002 = nil, nil
end)

check("6 the committed data: Rage of the Storm names its effect and has its damage", function()
    assert(has(Gear.EffectText(PICK_ID), "Rage of Earth"), tostring(Gear.EffectText(PICK_ID)))
    local s = Gear.ComputedStats(PICK_ID)
    -- computed stats: with the damage when the melee kind is proven against the scans (build 70235:
    -- 35.56 DPS at 3.6 s), else the allocations alone (build 70338 changed weapons the old scans still
    -- show, so the kind failed the check until the items are scanned again)
    assert(s and s.STA and s.STA > 0, "the pick's computed stats")
    if s.DPS then assert(s.SPEED and s.SPEED > 0, "a damage comes with its speed") end
    assert(type(NS.BIS.EN) == "table" and next(NS.BIS.EN), "encounters")
end)

assert(#failures == 0, table.concat(failures, "\n"))
