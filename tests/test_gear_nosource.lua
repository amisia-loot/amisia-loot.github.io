-- The planner's gear without a known source (Gear/NoSource.lua, UI/Pages/Planner.lua, F-175, D-107): a
-- level 42 priest's main hand suggestions end with "+ N weitere ohne bekannte Quelle" when scanned
-- gear of unknown source passes the list's filters (level range, slot and weapon plan, the class's
-- weapon types, the class mask, exclusions, the play style); a click shows them by gain among the
-- others with "Quelle unbekannt", a grey "?" (no click target) and the tooltip; the line then hides them
-- again; the setting bis.noSource (default off), "Optionen"; the wish star and the wish list of an item
-- without a source; an id of both files is a normal entry; the data of another build is ignored.
local Gear, NSR = NS.Gear, NS.GearNoSource
assert(NSR, "the module loads")
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function tipOf(fn)
    local out, keep = {}, GameTooltip.AddLine
    GameTooltip.AddLine = function(_, t) out[#out + 1] = tostring(t) end
    fn()
    GameTooltip.AddLine = keep
    return table.concat(out, "\n")
end

STUB.class, STUB.level = "PRIEST", 42
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
assert(NS.Get("bis.noSource") == false, "the setting is off by default")
NS.GEAR = { game = "forever", cap = 60, built = "test-nosrc", I = {}, Z = {}, ST = {}, S = {
    { "V", "Waffenschmied", 1429, "A", "Waffen", nil, 900 },   -- 1
} }
-- a dagger of the gear data (sourced) and of the source-less file: row, stats
local function dagger(t, id, level, sp, opts)
    opts = opts or {}
    t.I[id] = { opts.loc or "WEAPONMAINHAND", 2, opts.sub or 15, level, 3, 1, level + 5, opts.mask or 0, 1.8, 0 }
    if opts.source then t.I[id][11] = opts.source end
    t.ST[id] = ("SPELL_POWER=%d;INTELLECT=%d;DAMAGE_PER_SECOND=20"):format(sp, math.floor(sp / 4))
end
dagger(NS.GEAR, 501, 38, 30, { source = 1 })
dagger(NS.GEAR, 502, 30, 8, { source = 1 })
local SRC = { built = "test-nosrc", I = {}, ST = {}, N = {}, IC = {} }
dagger(SRC, 274998, 40, 52)                                  -- Schattenlichtathame: the best
dagger(SRC, 274995, 30, 20)                                  -- between the two sourced ones
dagger(SRC, 274990, 50, 90)                                  -- above the range 1 to 42
dagger(SRC, 274991, 40, 60, { mask = 1 })                    -- warriors only
dagger(SRC, 274992, 40, 70, { loc = "2HWEAPON", sub = 10 })  -- a staff: the plan is one hand
dagger(SRC, 274993, 40, 60, { sub = 7 })                     -- a sword: no priest weapon
dagger(SRC, 501, 38, 99)                                     -- an id of both files: the sourced entry wins
SRC.ST[274994] = "PARRY_RATING=5"                             -- scores nothing for a priest
SRC.I[274994] = { "WEAPONMAINHAND", 2, 15, 35, 3, 1, 40, 0, 1.8, 0 }
SRC.N = { [274998] = "Schattenlichtathame", [274995] = "Akolythenklinge" }
NS.GEAR_NOSRC = SRC
Gear._reset()
NSR.Reset()
-- a weak dagger worn, so the gains are percent
STUB.item(503, "Rostiger Dolch", 2)
local it = STUB.items[503]
it.equipLoc, it.classID, it.subclassID, it.stats, it.minLevel = "INVTYPE_WEAPONMAINHAND", 2, 15, { ITEM_MOD_SPELL_POWER_SHORT = 2 }, 5
STUB.worn[16] = "|cff1eff00|Hitem:503::::::::42:::::|h[Rostiger Dolch]|h|r"
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
NS.BisSetSpec(Gear.Specs("PRIEST")[1].key)
assert(Gear.Available())

NS.ShowPlanner("suggest", nil, "MAINHAND")
local f = NS.PageFrame("planner")
local function ids()
    local out = {}
    for _, e in ipairs(f.list.items) do
        out[#out + 1] = tostring(e.id or (e.pickRow and "pick") or (e.more and ("more" .. e.more)) or "note")
    end
    return table.concat(out, ",")
end
local function rowOf(id)
    for _, r in ipairs(f.list.rows) do if r:IsShown() and r.item and r.item.id == id then return r end end
end
local function moreRow()
    for _, r in ipairs(f.list.rows) do if r:IsShown() and r.item and r.item.more then return r end end
end

-- hidden: the sourced ones and one quiet line with the count of what passes the filters
assert(ids() == "pick,501,502,more2", "two pass: " .. ids())
local more = moreRow()
assert(plain(more.name:GetText()) == "+ 2 weitere ohne bekannte Quelle", plain(more.name:GetText()))
assert(not more.src:IsShown() and not more.srcQ:IsShown() and not more.star:IsShown(), "a line, no item parts")
local tip = tipOf(function() more:GetScript("OnEnter")(more) end)
assert(has(tip, "Amisia kennt die Werte aus dem Item-Scan") and has(tip, "Klick: sie in der Liste zeigen"), tip)

-- a click shows them by gain among the others; the line hides them again
more:Click()
assert(NSR.On() and AmisiaDB.settings.bis.noSource == true, "the choice is remembered")
assert(ids() == "pick,274998,501,274995,502,more2", "by gain: " .. ids())
local row = rowOf(274998)
assert(has(plain(row.name:GetText()), "Schattenlichtathame"), plain(row.name:GetText()))
assert(plain(row.sub:GetText()) == "Stufe 40 · Quelle unbekannt", plain(row.sub:GetText()))
assert(has(plain(row.gain:GetText()), "%"), "its gain: " .. plain(row.gain:GetText()))
assert(not row.src:IsShown() and row.srcQ:IsShown() and plain(row.srcQ:GetText()) == "?", "a grey ? for the symbol")
assert(has(row.srcQ:GetText(), "ff9d9d9d") or has(row.srcQ:GetText(), "|c"), "grey")
row.srcBtn:Click()   -- nothing to open, no error
tip = tipOf(function() row.srcBtn:GetScript("OnEnter")(row.srcBtn) end)
assert(has(tip, "Tötet jemand mit Amisia den Boss oder gibt eine Quest es als Belohnung, lernt Amisia die Quelle."), tip)
tip = tipOf(function() row:GetScript("OnEnter")(row) end)
assert(has(tip, "Amisia kennt die Werte aus dem Item-Scan, aber nicht, woher es kommt.") and not has(tip, "Quelle: "), tip)
assert(rowOf(501).src:IsShown() and not rowOf(501).srcQ:IsShown(), "a sourced row keeps its symbol")
assert(not has(plain(rowOf(501).sub:GetText()), "Quelle unbekannt"))
more = moreRow()
assert(plain(more.name:GetText()) == "ohne bekannte Quelle ausblenden", plain(more.name:GetText()))
-- a click on the row makes it the own pick, as any other
row:Click()
assert(NS.BisPick("MAINHAND") == 274998, "the own pick")
row = rowOf(274998)
row:Click()
assert(NS.BisPick("MAINHAND") == nil)

-- the wish star: on the wish list with "Quelle unbekannt"
row = rowOf(274998)
row.star:Click()
assert(NS.BisChar().wish[274998], "the star works on it")
local w = NS.Wishes()[1]
assert(w.id == 274998 and w.src == "Quelle unbekannt" and w.slotKey == "MAINHAND", tostring(w.src))
f.tabWish:Click()
assert(ids() == "274998", ids())
local wr = f.list.rows[1]
assert(has(plain(wr.sub:GetText()), "Quelle unbekannt") and wr.srcQ:IsShown(), plain(wr.sub:GetText()))
f.tabSuggest:Click()
NS.WishRemove(274998)

-- the line hides them again
moreRow():Click()
assert(not NSR.On() and ids() == "pick,501,502,more2", ids())

-- Optionen: the switch there too
f.optLink:Click()
local found
for _, b in ipairs(AmisiaMenu.buttons) do
    if b:IsShown() and has(b.label:GetText(), "Items ohne bekannte Quelle") then found = b end
end
assert(found and not has(found.label:GetText(), "ReadyCheck"), "in the menu, not checked")
found:Click()
assert(NSR.On(), "the menu turns it on")
f.optLink:Click()
for _, b in ipairs(AmisiaMenu.buttons) do
    if b:IsShown() and has(b.label:GetText(), "Items ohne bekannte Quelle") then found = b end
end
assert(has(found.label:GetText(), "ReadyCheck"), "checked")
AmisiaMenu:Hide()
NSR.SetOn(false)

-- the filters: the level range, an exclusion, the play style
local st = AmisiaDB.settings.bis
st.planLo, st.planHi = 1, 35
NS.Refresh()
assert(ids() == "pick,502,more1", "only the level 30 one in 1 to 35: " .. ids())
st.planLo, st.planHi = nil, nil
NS.BisExclude("item", 274998, true)
NS.Refresh()
assert(ids() == "pick,501,502,more1", "an excluded item does not count: " .. ids())
NS.BisExclude("item", 274998, false)
NS.PlayStyle.Set("solo", true)
NS.Refresh()
assert(not has(ids(), "more"), "an unknown source passes no play style switch: " .. ids())
NS.PlayStyle.Set("solo", false)
NS.PlayStyle.Set("now", true)
NS.Refresh()
assert(has(ids(), "more2"), "but \"Jetzt holbar\" asks only for the reputation: " .. ids())
NS.PlayStyle.Set("now", false)
NS.Refresh()
assert(ids() == "pick,501,502,more2", ids())

-- a plan of two hands: the staff comes in, the daggers go
NS.BisSetPlan("2H")
NS.Refresh()
assert(has(ids(), "more1"), "the staff with the plan Zweihand: " .. ids())
NS.BisSetPlan("auto")
NS.Refresh()

-- another slot has none: no line
NS.ShowPlanner("suggest", nil, "HEAD")
assert(not has(ids(), "more"), ids())
NS.ShowPlanner("suggest", nil, "MAINHAND")

-- the data of another build than the gear data's is not used
SRC.built = "other"
NSR.Reset()
NS.Refresh()
assert(not has(ids(), "more"), "another build: " .. ids())
assert(Gear.Item(274998) == nil, "and Gear.Item does not find its rows")
SRC.built = "test-nosrc"
NSR.Reset()
NS.Refresh()
assert(has(ids(), "more2") and Gear.Item(274998)[4] == 40, "built: Gear.Item finds the row")
assert(Gear.ScannedStats(274998)[Gear.StatKey("SPELL_POWER")] == 52, "and its stats")
assert(Gear.ScanName(274998) == "Schattenlichtathame", "and its name")

-- the settings section "Ausrüstung und Wünsche" lists the switch, off by default
local item = NS.SettingItem("bis.noSource")
assert(item and item.type == "toggle" and item.default == false and item.label == "Items ohne bekannte Quelle vorschlagen")
assert(NS.Get("bis.noSource") == false)
print("gear without a known source: the line, the click, by gain, the mark, the filters, the setting, the wish")
