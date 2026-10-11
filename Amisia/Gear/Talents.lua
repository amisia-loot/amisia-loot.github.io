-- The talent calculator's rules, without any frame: WoW Forever's talent trees from TalentData.lua
-- (ns.TALENTS, tools/build_talents.py from the client's Trait* tables), plans per class, the row
-- locks and prerequisites as the client applies them, points per level (and with the Talented
-- perk), a short share code, the player's live talents (C_ClassTalents/C_Traits) and the client's
-- own texts with the data as fallback. Pages/Talents.lua draws it.
--
-- A node row of the data: { node, entry, spell, icon, tree, row, col, max ranks, gates, pre, name,
-- text, values }. gates: 0 or { counting group, points, ... }: that many points spent in the nodes
-- of the counting group (the rows above). pre: 0 or node ids; a positive id is "sufficient" (one
-- full source of these is enough), a negative one "required" (that node must be full).
local ADDON, ns = ...
local L, N_ = ns.L, ns.N_

local T = {}
ns.Talents = T

local CODE_VERSION = 1
local NODE, ENTRY, SPELL, ICON, TREE, ROW, COL, MAX, GATES, PRE, NAME, TEXT, VALUES = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
T.F = { NODE = NODE, ENTRY = ENTRY, SPELL = SPELL, ICON = ICON, TREE = TREE, ROW = ROW, COL = COL, MAX = MAX,
        GATES = GATES, PRE = PRE, NAME = NAME, TEXT = TEXT, VALUES = VALUES }

-- the class names when the client gives none (German keys, shown through L)
local CLASS_NAME = { WARRIOR = N_("Krieger"), PALADIN = N_("Paladin"), HUNTER = N_("Jäger"), ROGUE = N_("Schurke"),
    PRIEST = N_("Priester"), SHAMAN = N_("Schamane"), MAGE = N_("Magier"), WARLOCK = N_("Hexenmeister"), DRUID = N_("Druide") }

local prepared = {}     -- class -> { byId, order[tree], data }
local treeNames = {}    -- class -> { [tree index] = client name } (false: asked, none)

function T._reset()
    prepared, treeNames = {}, {}
end

local function data() return ns.Data("TALENTS") end

function T.Available()
    -- the generator's count of classes, while the table waits (opening the window builds nothing)
    local n = ns.DataSize("TALENTS")
    if n then return n > 0 end
    local d = data()
    return type(d) == "table" and type(d.classes) == "table" and next(d.classes) ~= nil
end

-- The prepared class: its data plus the nodes by id and per tree in row/column order.
function T.Class(cls)
    local d = data()
    local c = d and d.classes and d.classes[cls]
    if not c then return nil end
    local p = prepared[cls]
    if p and p.data == c then return p end
    p = { data = c, cls = cls, byId = {}, order = { {}, {}, {} }, tree = c.tree, trees = c.trees, gates = c.gates or {} }
    for _, n in ipairs(c.nodes or {}) do
        p.byId[n[NODE]] = n
        local list = p.order[n[TREE]]
        if list then list[#list + 1] = n end
    end
    for _, list in ipairs(p.order) do
        table.sort(list, function(a, b)
            if a[ROW] ~= b[ROW] then return a[ROW] < b[ROW] end
            return a[COL] < b[COL]
        end)
    end
    prepared[cls] = p
    return p
end

function T.Node(cls, id)
    local c = T.Class(cls)
    return c and c.byId[id]
end

local function playerClass()
    local _, cls = UnitClass("player")
    return cls
end

-- The classes with data: the player's own first, then by class id.
function T.Classes()
    local d = data()
    local out = {}
    for cls in pairs(d and d.classes or {}) do out[#out + 1] = cls end
    local mine = playerClass()
    table.sort(out, function(a, b)
        if a == mine then return true end
        if b == mine then return false end
        return (d.classes[a].id or 99) < (d.classes[b].id or 99)
    end)
    return out
end

function T.Max()
    local d = data()
    return d and tonumber(d.max) or 51
end

-- The talent points a character has at level with talented ranks of the Talented perk.
function T.PointsAt(level, talented)
    local d = data()
    if not d then return 0 end
    level, talented = tonumber(level) or 0, math.max(0, math.min(5, tonumber(talented) or 0))
    local n = 0
    for _, l in ipairs(d.levels or {}) do
        if l <= level then n = n + 1 end
    end
    for k = 1, talented do
        local l = d.talented and d.talented[k]
        if l and l <= level then n = n + 1 end
    end
    return math.min(T.Max(), n)
end

-- The lowest level with at least points talent points; nil when no level gives that many.
function T.LevelFor(points, talented)
    if (points or 0) <= 0 then return 1 end
    for level = 1, 60 do
        if T.PointsAt(level, talented) >= points then return level end
    end
    return nil
end

---------------------------------------------------------------------------
-- Names and texts: the client's own (German) where it gives one, else the data (enUS)
---------------------------------------------------------------------------
local function plainString(v)
    v = ns.Plain and ns.Plain(v) or v
    return type(v) == "string" and v ~= "" and v or nil
end

local function call(path1, path2, ...)
    local lib = _G[path1]
    local fn = type(lib) == "table" and lib[path2]
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok then return nil end
    return a, b
end

function T.ClassName(cls)
    local names = _G.LOCALIZED_CLASS_NAMES_MALE
    return (type(names) == "table" and plainString(names[cls])) or (CLASS_NAME[cls] and L[CLASS_NAME[cls]]) or cls
end

function T.TreeName(cls, i)
    local c = T.Class(cls)
    if not c or not c.trees[i] then return "?" end
    local names = treeNames[cls]
    if names == nil then
        names = {}
        local infos = call("C_Traits", "GetGroupDisplayInfoByTreeID", c.tree)
        if type(infos) == "table" then
            for _, info in ipairs(infos) do
                for k, t in ipairs(c.trees) do
                    if type(info) == "table" and info.groupID == t[1] then names[k] = plainString(info.displayName) end
                end
            end
        end
        treeNames[cls] = names
    end
    return names[i] or c.trees[i][2] or "?"
end

function T.TreeIcon(cls, i)
    local c = T.Class(cls)
    return c and c.trees[i] and c.trees[i][3] or nil
end

function T.NodeName(n)
    if not n then return "?" end
    return plainString((call("C_Spell", "GetSpellName", n[SPELL]))) or n[NAME] or "?"
end

function T.NodeIcon(n)
    if not n then return nil end
    if n[ICON] and n[ICON] ~= 0 then return n[ICON] end
    return (call("C_Spell", "GetSpellTexture", n[SPELL]))
end

-- The text of rank (1 at rank 0): the client's text of that rank, else the data's with the
-- rank's values put in.
function T.NodeText(n, rank)
    if not n then return "" end
    rank = math.max(1, math.min(n[MAX], tonumber(rank) or 1))
    local own = plainString((call("C_Traits", "GetTraitDescription", n[ENTRY], rank)))
    if own then return own end
    local values = n[VALUES]
    return ((n[TEXT] or ""):gsub("{(%d+)}", function(k)
        local v = type(values) == "table" and values[tonumber(k)]
        return v and (v[rank] or v[#v]) or "?"
    end))
end

---------------------------------------------------------------------------
-- Plans and the rules
---------------------------------------------------------------------------
function T.NewPlan(cls) return { class = cls, ranks = {} } end

function T.Rank(plan, id) return plan.ranks[id] or 0 end

-- Points spent in the plan, or in tree (1-3) only.
function T.Spent(plan, tree)
    local c = T.Class(plan.class)
    local n = 0
    for id, r in pairs(plan.ranks) do
        local node = c and c.byId[id]
        if node and (not tree or node[TREE] == tree) then n = n + r end
    end
    return n
end

local function groupSpent(c, plan, gid)
    local n = 0
    for _, id in ipairs(c.gates[gid] or {}) do n = n + (plan.ranks[id] or 0) end
    return n
end

-- The highest row lock of a node (points), 0 without one.
function T.GateReq(n)
    local g, req = n and n[GATES], 0
    if type(g) == "table" then
        for i = 2, #g, 2 do req = math.max(req, g[i]) end
    end
    return req
end

local function full(c, plan, id)
    local n = c.byId[id]
    return n ~= nil and (plan.ranks[id] or 0) >= n[MAX]
end

-- What keeps node n from taking a point (rank aside): a line per missing requirement.
local function missing(c, plan, n)
    local out = {}
    local g = n[GATES]
    if type(g) == "table" then
        for i = 1, #g - 1, 2 do
            if groupSpent(c, plan, g[i]) < g[i + 1] then
                out[#out + 1] = (L["Benötigt %d Punkte in %s."]):format(g[i + 1], T.TreeName(c.cls, n[TREE]))
                break
            end
        end
    end
    local pre = n[PRE]
    if type(pre) == "table" then
        local any, anyMet = {}, false
        for _, sid in ipairs(pre) do
            local src = c.byId[math.abs(sid)]
            if src then
                if sid < 0 then
                    if not full(c, plan, -sid) then
                        out[#out + 1] = (L["Benötigt %s (%d/%d)."]):format(T.NodeName(src), src[MAX], src[MAX])
                    end
                else
                    any[#any + 1] = src
                    if full(c, plan, sid) then anyMet = true end
                end
            end
        end
        if #any > 0 and not anyMet then
            local names = {}
            for _, src in ipairs(any) do names[#names + 1] = ("%s (%d/%d)"):format(T.NodeName(src), src[MAX], src[MAX]) end
            out[#out + 1] = L["Benötigt %s."]:format(table.concat(names, L[" oder "]))
        end
    end
    return out
end

-- The requirements of a node the plan does not meet (for the tooltip).
function T.Missing(plan, id)
    local c = T.Class(plan.class)
    local n = c and c.byId[id]
    if not n then return {} end
    return missing(c, plan, n)
end

-- Whether node id can take one more point with points to spend at most; else false and why.
function T.CanAdd(plan, id, points)
    local c = T.Class(plan.class)
    local n = c and c.byId[id]
    if not n then return false, L["Unbekanntes Talent."] end
    if (plan.ranks[id] or 0) >= n[MAX] then return false, L["Höchster Rang erreicht."] end
    if T.Spent(plan) >= (points or T.Max()) then return false, L["Keine Punkte mehr frei."] end
    local miss = missing(c, plan, n)
    if #miss > 0 then return false, miss[1] end
    return true
end

function T.Add(plan, id, points)
    if not T.CanAdd(plan, id, points) then return false end
    plan.ranks[id] = (plan.ranks[id] or 0) + 1
    return true
end

-- Whether node id can give a point back: every spent point stays valid without it.
function T.CanRemove(plan, id)
    local c = T.Class(plan.class)
    local r = plan.ranks[id] or 0
    if not c or r <= 0 then return false, L["Kein Punkt gesetzt."] end
    plan.ranks[id] = r - 1
    local broken
    for oid, rank in pairs(plan.ranks) do
        local n = c.byId[oid]
        if rank > 0 and n and #missing(c, plan, n) > 0 then broken = n break end
    end
    plan.ranks[id] = r
    if broken then return false, (L["%s hängt davon ab."]):format(T.NodeName(broken)) end
    return true
end

function T.Remove(plan, id)
    if not T.CanRemove(plan, id) then return false end
    local r = plan.ranks[id] - 1
    plan.ranks[id] = r > 0 and r or nil
    return true
end

-- As many points as possible in or out of one node; the number moved.
function T.AddAll(plan, id, points)
    local n = 0
    while T.Add(plan, id, points) do n = n + 1 end
    return n
end

function T.RemoveAll(plan, id)
    local n = 0
    while T.Remove(plan, id) do n = n + 1 end
    return n
end

-- All points of one tree back (the other trees' locks count only their own tree).
function T.ResetTree(plan, tree)
    local c = T.Class(plan.class)
    for id in pairs(plan.ranks) do
        local n = c and c.byId[id]
        if not n or n[TREE] == tree then plan.ranks[id] = nil end
    end
end

function T.Reset(plan) plan.ranks = {} end

---------------------------------------------------------------------------
-- The share code: AT1.<CLASS>.<tree 1>.<tree 2>.<tree 3>, one digit per node in row/column order,
-- zeros at the end left out.
---------------------------------------------------------------------------
function T.Encode(plan)
    local c = T.Class(plan.class)
    local parts = { "AT" .. CODE_VERSION, plan.class }
    for t = 1, 3 do
        local digits = {}
        for i, n in ipairs(c and c.order[t] or {}) do digits[i] = tostring(math.min(9, plan.ranks[n[NODE]] or 0)) end
        parts[#parts + 1] = (table.concat(digits):gsub("0+$", ""))
    end
    return table.concat(parts, ".")
end

-- The plan of a code (also inside a line of chat text), rebuilt with the rules; nil and why.
function T.Decode(text)
    text = tostring(text or "")
    if not text:find("%S") then return nil, L["Kein Code eingegeben."] end
    -- trees at the end without points may be left out ("AT1.MAGE.2"); a sentence's full stop after
    -- the code is no fourth tree
    local version, cls, rest, after = text:match("AT(%d+)%.(%u+)([%.%d]*)(.?)")
    if not version or after:find("%w") or (rest ~= "" and rest:sub(1, 1) ~= ".") then
        return nil, L["Kein Amisia-Talentcode (AT1.KLASSE.x.y.z)."]
    end
    if tonumber(version) ~= CODE_VERSION then return nil, (L["Kein Code dieser Version (AT%s)."]):format(version) end
    local c = T.Class(cls)
    if not c then return nil, (L["Unbekannte Klasse %s."]):format(cls) end
    local parts = {}
    for digits in rest:gmatch("%.(%d*)") do parts[#parts + 1] = digits end
    for i = 4, #parts do
        if parts[i] ~= "" then return nil, L["Kein Amisia-Talentcode (mehr als drei Bäume)."] end
    end
    local want = {}
    for t = 1, 3 do
        local digits = parts[t] or ""
        local list = c.order[t]
        if #digits > #list then return nil, (L["Der Code ist für %s zu lang (Baum %d)."]):format(T.ClassName(cls), t) end
        for i = 1, #digits do
            local r = tonumber(digits:sub(i, i))
            local n = list[i]
            if r > n[MAX] then return nil, (L["Rang %d für %s, höchstens %d."]):format(r, T.NodeName(n), n[MAX]) end
            if r > 0 then want[n[NODE]] = r end
        end
    end
    -- rebuilt row by row; a prerequisite later in the order (same row, or one the data draws
    -- upwards) takes another pass
    local plan = T.NewPlan(cls)
    local all = {}
    for t = 1, 3 do for _, n in ipairs(c.order[t]) do all[#all + 1] = n end end
    table.sort(all, function(x, y)
        if x[ROW] ~= y[ROW] then return x[ROW] < y[ROW] end
        if x[TREE] ~= y[TREE] then return x[TREE] < y[TREE] end
        return x[COL] < y[COL]
    end)
    local progress = true
    while progress do
        progress = false
        for _, n in ipairs(all) do
            local id = n[NODE]
            while (plan.ranks[id] or 0) < (want[id] or 0) and T.Add(plan, id, T.Max()) do progress = true end
        end
    end
    for _, n in ipairs(all) do
        if (plan.ranks[n[NODE]] or 0) ~= (want[n[NODE]] or 0) then
            return nil, (L["Der Code verletzt eine Voraussetzung (%s)."]):format(T.NodeName(n))
        end
    end
    return plan
end

---------------------------------------------------------------------------
-- The player's talents in the game
---------------------------------------------------------------------------
-- The live plan of the player's class and { config, spent, free, total, missing }; nil and why
-- when the client gives none (no API, no talent configuration, another class).
function T.Live()
    local cls = playerClass()
    local c = T.Class(cls)
    if not c then return nil, L["Keine Talentdaten für diese Klasse."] end
    local CT, TR = _G.C_ClassTalents, _G.C_Traits
    if type(CT) ~= "table" or type(CT.GetActiveConfigID) ~= "function" or type(TR) ~= "table" or type(TR.GetNodeInfo) ~= "function" then
        return nil, L["Der Client kennt die Talent-Schnittstelle nicht."]
    end
    local ok, config = pcall(CT.GetActiveConfigID)
    config = ok and ns.Plain(config) or nil
    if not config then return nil, L["Keine aktive Talentkonfiguration."] end
    local plan, lacking = T.NewPlan(cls), 0
    for id in pairs(c.byId) do
        local got, info = pcall(TR.GetNodeInfo, config, id)
        local r = got and type(info) == "table" and ns.Plain(info.ranksPurchased) or nil
        if type(r) == "number" then
            if r > 0 then plan.ranks[id] = r end
        else
            lacking = lacking + 1
        end
    end
    local spent = T.Spent(plan)
    local result = { config = config, spent = spent, missing = lacking }
    if type(TR.GetTreeCurrencyInfo) == "function" then
        local got, list = pcall(TR.GetTreeCurrencyInfo, config, c.tree, false)
        local cur = got and type(list) == "table" and list[1]
        if type(cur) == "table" then
            local q, s = ns.Plain(cur.quantity), ns.Plain(cur.spent)
            if type(q) == "number" and type(s) == "number" then
                result.free, result.spent, result.total = q, s, q + s
            end
        end
    end
    return plan, result
end

---------------------------------------------------------------------------
-- What the page keeps: AmisiaDB.talents = { class, level, talented, plans = { [class] = code } }
---------------------------------------------------------------------------
function T.State()
    if type(AmisiaDB) ~= "table" then return { plans = {} } end
    local s = type(AmisiaDB.talents) == "table" and AmisiaDB.talents or {}
    AmisiaDB.talents = s
    s.plans = type(s.plans) == "table" and s.plans or {}
    return s
end

function T.SavePlan(plan)
    local s = T.State()
    if T.Spent(plan) > 0 then s.plans[plan.class] = T.Encode(plan) else s.plans[plan.class] = nil end
end

-- The saved plan of a class (an empty one without, or when the code no longer fits the data).
function T.LoadPlan(cls)
    local code = T.State().plans[cls]
    local plan = type(code) == "string" and T.Decode(code)
    if plan and plan.class == cls then return plan, true end
    return T.NewPlan(cls), false
end
