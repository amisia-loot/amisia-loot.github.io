-- Amisia's upgrade model: what an item changes for the own character in its spec, in percent of the
-- spec's whole output (damage, healing or survival). The weights of GearWeights.lua are the slopes of
-- four models (physical, caster, healer, tank) at a reference character; here the same models run on
-- a state: the character sheet as read out of combat (or, before the first read, the class's base
-- values plus the worn gear). The item's change is the model's output with the compared items out and
-- the new one in, against the output now, so hit over the cap, crit times attack power or mana against
-- spell power come out of the formulas themselves. tools/build_bis.py has the same functions (m_*);
-- tools/tests/test_upgrade_model.py holds the two equal. DECISIONS D-54, spec
-- docs/specs/2026-10-17-upgrade-genau.md.
local ADDON, ns = ...
local L = ns.L
local Gear = ns.Gear

local Model = {}
ns.Model = Model

local SCHOOLS = { "SP_ARCANE", "SP_FIRE", "SP_NATURE", "SP_FROST", "SP_SHADOW", "SP_HOLY" }
-- spell school index of GetSpellBonusDamage / GetSpellCritChance
local SCHOOL_INDEX = { SP_HOLY = 2, SP_FIRE = 3, SP_NATURE = 4, SP_FROST = 5, SP_SHADOW = 6, SP_ARCANE = 7 }
-- the school a healer's spells crit with
local HEAL_SCHOOL = { PALADIN = "SP_HOLY", PRIEST = "SP_HOLY", SHAMAN = "SP_NATURE", DRUID = "SP_NATURE" }
local RATING_HASTE_MELEE, RATING_HASTE_SPELL, RATING_EXPERTISE = 18, 20, 24

local function C() return ns.GEAR_WEIGHTS and ns.GEAR_WEIGHTS.model end
function Model.Available()
    local c = Gear.Available() and C()
    return c ~= nil and c ~= false
end

local function interp(t, level)
    local lo = t[1]
    for _, pt in ipairs(t) do
        if pt[1] > level then
            local span = pt[1] - lo[1]
            return span ~= 0 and lo[2] + (pt[2] - lo[2]) * (level - lo[1]) / span or pt[2]
        end
        lo = pt
    end
    return t[#t][2]
end

local function rp(kind, level) return Gear.RatingPerPoint(kind, level) end
local function apc(class, level) return C().agi60[class] * math.max(level, 10) / 60 end
local function ipc(class, level) return C().int60[class] * math.max(level, 10) / 60 end
local function lowLevelPenalty(level)
    local learnt = math.max(1, level - 2)
    return 1 - math.max(0, 20 - learnt) * 0.0375
end
local function specialsRate(r60, level) return r60 * math.min(1, math.max(level - 4, 0) / 36) end
local function baseHp(class, level) return C().hp[class] * (0.45 * level * level + 1.5 * level) end
local function baseAttr(class, level, key)
    local b60 = C().base60[class][key]
    return 20 + (b60 - 20) * (math.max(level, 1) - 1) / 59
end

-- The parameters of a spec's model ({ model = "phys" | "caster" | "heal" | "tank", ... }), or nil.
function Model.Params(class, specKey)
    if not Model.Available() then return nil end
    local sp = Gear.SpecInfo(class, specKey)
    return sp and sp.p or nil, sp
end

local function physOf(p) return p.model == "phys" and p or p.threat or {} end

---------------------------------------------------------------------------
-- States
---------------------------------------------------------------------------

local function copy(st)
    local out = {}
    for k, v in pairs(st) do out[k] = v end
    out.mult, out.school = {}, {}
    for k, v in pairs(st.mult or {}) do out.mult[k] = v end
    for k, v in pairs(st.school or {}) do out.school[k] = v end
    return out
end

-- A state from a reference character (the planner's form: attributes, ratings in percent, item
-- totals, weapon damage and speed), as build_bis.py's m_state_from_ref.
function Model.FromRef(class, p, ref)
    local level, agi = ref.level, ref.AGI
    local a, i = apc(class, level), ipc(class, level)
    local phys = physOf(p)
    local tank = p.model == "tank" and p or nil
    local mult = tank and tank.armor_mult or 1
    local canParry, canBlock
    if tank then canParry, canBlock = tank.parry and true or false, tank.block and true or false
    else canParry, canBlock = C().parry[class] and true or false, C().block[class] and true or false end
    local d = ref.def or 0
    local st = {
        level = level, STR = ref.STR, AGI = agi, STA = ref.STA, INT = ref.INT, SPI = ref.SPI, mult = {},
        ap = ref.AP + ref.FAP + (phys.ap_str or 0) * ref.STR + (phys.ap_agi or 0) * agi
            + (phys.form and 2 * level or 3 * level - 20),
        rap = ref.RAP + ref.AP + 2 * agi - 10,
        mhDPS = ref.wDPS, mhSpeed = ref.speed or 2.6, ohDPS = 0, rDPS = ref.rDPS, rSpeed = ref.rSpeed,
        crit = C().baseCrit[class] + agi / a + ref.critRating,
        hit = ref.hit, exp = 0, haste = 0, shaste = 0,
        dw = phys.plan == "DW" and C().dual[class] ~= nil and level >= C().dual[class] or false,
        spg = ref.SPD + ref.SPP, school = {}, heal = ref.HEAL + ref.SPP,
        scrit = C().baseSpellCrit[class] + ref.INT / i + ref.spellCritRating, shit = ref.spellhit,
        mana = 18 * level + 15 * ref.INT, mp5 = ref.MP5,
        hp = baseHp(class, level) + 10 * ref.STA, armor = ref.ARMOR * mult + 2 * agi,
        miss = 5 + d * 0.04, dodge = agi / a + ref.dodgeRating + d * 0.04,
        parry = canParry and (5 + ref.parryRating + d * 0.04) or 0,
        block = canBlock and (5 + ref.block + d * 0.04) or 0,
        canParry = canParry, canBlock = canBlock, blockval = ref.BLOCKVAL or 0,
    }
    for _, s in ipairs(SCHOOLS) do st.school[s] = ref[s] or 0 end
    st.rcrit = st.crit
    return st
end

-- The reference of a character at level wearing the stat tables in items ({ { stats, place }, ... }):
-- the class's base attributes plus the items, as build_bis.py's reference().
function Model.Ref(class, level, items, plan)
    local tot = {}
    local mh, rg = {}, {}
    for _, it in ipairs(items) do
        local s, place = it[1], it[2]
        for k, v in pairs(s) do
            if k ~= "DPS" and k ~= "SPEED" and type(v) == "number" then tot[k] = (tot[k] or 0) + v end
        end
        if place == "2H" or place == "MH" then mh = s elseif place == "RANGED" then rg = s end
    end
    local function T(k) return tot[k] or 0 end
    local ref = { level = level, plan = plan }
    for _, k in ipairs({ "STR", "AGI", "STA", "INT", "SPI" }) do ref[k] = baseAttr(class, level, k) + T(k) end
    ref.hit = (T("HIT") + T("MHIT")) * rp("HIT", level)
    ref.spellhit = (T("HIT") + T("SHIT")) * rp("SHIT", level)
    ref.critRating = (T("CRIT") + T("MCRIT")) * rp("CRIT", level)
    ref.spellCritRating = (T("CRIT") + T("SCRIT")) * rp("CRIT", level)
    ref.dodgeRating = T("DODGE") * rp("DODGE", level)
    ref.parryRating = T("PARRY") * rp("PARRY", level)
    ref.block = T("BLOCK") * rp("BLOCK", level)
    ref.def = T("DEF") * rp("DEF", level)
    for _, k in ipairs({ "AP", "RAP", "FAP", "SPP", "SPD", "HEAL", "MP5", "ARMOR", "BLOCKVAL" }) do ref[k] = T(k) end
    for _, s in ipairs(SCHOOLS) do ref[s] = T(s) end
    ref.wDPS = mh.DPS or (1 + 0.75 * level)
    ref.speed = mh.SPEED or 2.6
    ref.rDPS = rg.DPS or (1 + 0.6 * level)
    ref.rSpeed = rg.SPEED or 2.8
    return ref
end

-- The state with an item's stats s added (sign 1) or taken away (sign -1); place ("2H", "MH", "OH",
-- "RANGED" or nil) is where its weapon damage and speed go. A new table.
function Model.Apply(class, p, st, s, place, sign)
    st = copy(st)
    local level = st.level
    local phys = physOf(p)
    local mult = p.model == "tank" and (p.armor_mult or 1) or 1
    local a, i = apc(class, level), ipc(class, level)
    local function v(k)
        local x = s[k]
        return type(x) == "number" and sign * x or 0
    end
    local function m(k) return st.mult[k] or 1 end
    local x = v("STR") * m("STR")
    if x ~= 0 then
        st.STR = st.STR + x
        st.ap = st.ap + (phys.ap_str or 0) * x
    end
    x = v("AGI") * m("AGI")
    if x ~= 0 then
        st.AGI = st.AGI + x
        st.ap = st.ap + (phys.ap_agi or 0) * x
        st.rap = st.rap + 2 * x
        if not phys.noagi then
            st.crit = st.crit + x / a
            st.rcrit = st.rcrit + x / a
        end
        st.armor = st.armor + 2 * x
        st.dodge = st.dodge + x / a
    end
    x = v("STA") * m("STA")
    if x ~= 0 then
        st.STA = st.STA + x
        st.hp = st.hp + 10 * x
    end
    x = v("INT") * m("INT")
    if x ~= 0 then
        st.INT = st.INT + x
        st.mana = st.mana + 15 * x
        st.scrit = st.scrit + x / i
    end
    st.SPI = st.SPI + v("SPI") * m("SPI")
    st.ap = st.ap + v("AP") + (class == "DRUID" and v("FAP") or 0)
    st.rap = st.rap + v("AP") + v("RAP")
    st.spg = st.spg + v("SPD") + v("SPP")
    st.heal = st.heal + v("HEAL") + v("SPP")
    for _, school in ipairs(SCHOOLS) do
        if v(school) ~= 0 then st.school[school] = (st.school[school] or 0) + v(school) end
    end
    st.hit = st.hit + (v("HIT") + v("MHIT")) * rp("HIT", level)
    st.shit = st.shit + (v("HIT") + v("SHIT")) * rp("SHIT", level)
    local crit = (v("CRIT") + v("MCRIT")) * rp("CRIT", level)
    st.crit = st.crit + crit
    st.rcrit = st.rcrit + crit
    st.scrit = st.scrit + (v("CRIT") + v("SCRIT")) * rp("CRIT", level)
    st.haste = st.haste + v("HASTE") * rp("HASTE", level)
    st.shaste = st.shaste + (v("HASTE") + v("SHASTE")) * rp("HASTE", level)
    st.exp = st.exp + v("EXP") * rp("EXP", level)
    st.dodge = st.dodge + v("DODGE") * rp("DODGE", level)
    if st.canParry then st.parry = st.parry + v("PARRY") * rp("PARRY", level) end
    if st.canBlock then st.block = st.block + v("BLOCK") * rp("BLOCK", level) end
    x = v("DEF") * rp("DEF", level) * 0.04
    if x ~= 0 then
        st.miss = st.miss + x
        st.dodge = st.dodge + x
        if st.canParry then st.parry = st.parry + x end
        if st.canBlock then st.block = st.block + x end
    end
    st.armor = st.armor + v("ARMOR") * mult
    st.blockval = st.blockval + v("BLOCKVAL")
    st.mp5 = st.mp5 + v("MP5")
    x = v("DPS")
    if x ~= 0 then
        if place == "RANGED" then st.rDPS = st.rDPS + x
        elseif place == "OH" then st.ohDPS = st.ohDPS + x
        elseif place == "2H" or place == "MH" then st.mhDPS = st.mhDPS + x end
    end
    if sign > 0 and type(s.SPEED) == "number" then
        if place == "RANGED" then st.rSpeed = s.SPEED
        elseif place == "2H" or place == "MH" then st.mhSpeed = s.SPEED end
    end
    -- two weapons miss more: an off-hand weapon in starts it, out or a two-hander in ends it
    if place == "OH" then st.dw = sign > 0
    elseif place == "2H" and sign > 0 then st.dw = false end
    return st
end

---------------------------------------------------------------------------
-- The four models
---------------------------------------------------------------------------

local function ohFactor()
    local c = C()
    local t1 = 1 - c.meleeMiss / 100 - c.targetDodge / 100
    local tdw = 1 - c.dwMiss / 100 - c.targetDodge / 100
    return math.floor(0.5 * tdw / t1 * 1000 + 0.5) / 1000
end

-- Damage per second of the physical model and its size in attack power.
local function phys(p, st)
    local c = C()
    local level = st.level
    local r = specialsRate(p.r_spec or 0, level)
    local B, crit, spd
    if p.ranged then
        B = st.rDPS + math.max(st.rap, 0) / 14
        crit, spd = st.rcrit, st.rSpeed
    else
        local wd = p.form and 0.9 * level or st.mhDPS + ohFactor() * st.ohDPS
        B = wd + math.max(st.ap, 0) / 14
        crit, spd = st.crit, p.form and 0 or st.mhSpeed
    end
    local miss = (st.dw and not p.ranged) and (0.6 * c.dwMiss + 0.4 * c.meleeMiss) or c.meleeMiss
    local t = math.max(0.5, 1 - math.max(0, miss - st.hit) / 100 - math.max(0, c.targetDodge - st.exp) / 100)
    return B * (1 + r * spd) * (1 + crit / 100) * t * (1 + st.haste / 100), 14 * B
end

local function cast(p, level)
    local c = C()
    local B = interp(p.model == "heal" and c.heal or c.nuke, level) * p.f
    local T = p.cast <= 3.0 and math.min(p.cast, interp(c.cast, level)) or p.cast
    local k = math.min(1, T / 3.5) * lowLevelPenalty(level)
    return B, T, k
end

local function power(p, st)
    if p.model == "heal" then return st.heal end
    local v = st.spg
    for school, share in pairs(p.school or {}) do v = v + share * (st.school[school] or 0) end
    return v
end

local function barTime(p, st)
    local B, T = cast(p, st.level)
    local c = C()
    return st.mana * p.eff * T / B / (p.model == "heal" and c.dutyHeal or c.dutyCaster)
end

-- Damage (or healing) per cast with crit, hit, haste and mana, and its size in spell power.
local function caster(class, p, st, bar)
    local c = C()
    local B, _, k = cast(p, st.level)
    local dmg = B + k * power(p, st)
    local t = p.model == "heal" and 1 or math.max(0.5, 1 - math.max(0, c.spellMiss - st.shit) / 100)
    local s = p.scarce
    local pool = st.mana + st.mp5 * bar / 5 + st.SPI * c.spirit[class] * c.castsSpi * bar / 5
    return dmg * (1 + 0.5 * st.scrit / 100) * t * (1 + (1 - s) * st.shaste / 100) * math.max(pool, 1) ^ s, dmg / k
end

-- Effective health against a target two levels higher, and its size in stamina.
local function eh(st)
    local K = 400 + 85 * (st.level + 2)
    local av = math.min(0.6, (st.miss + st.dodge + st.parry + 0.3 * st.block) / 100)
    return st.hp * (st.armor + K) / K / (1 - av), st.hp / 10
end

-- What the model counts straight, in the spec's unit per point as an item shows it.
local function linear(class, p, st)
    local c = C()
    local w = {}
    local model = p.model
    if model == "phys" then
        if p.ranged then
            w.STR = 0.1
            w.DPS_MELEE = p.melee_dps or 1.4
        else
            w.DPS_RANGED = 1.0
        end
    end
    if model == "caster" or model == "heal" then
        w.DPS_MELEE = 0.1
        if model == "caster" and p.wand then
            local level = st.level
            local _, T, k = cast(p, level)
            local cr = st.scrit / 100
            local t = math.max(0.5, 1 - math.max(0, c.spellMiss - st.shit) / 100)
            local f = level < 20 and 0.4 or level < 40 and 0.25 or 0.15
            w.DPS_RANGED = f * T / (k * (1 + 0.5 * cr) * t)
        end
    end
    if p.mana100 and p.mana100 ~= 0 and (model == "phys" or model == "tank") then
        local mv = p.mana100 / 100
        w.INT = 15 * mv
        w.MP5 = 12 * mv
        if model == "phys" then w.SPI = mv * c.spirit[class] * 12 * 0.3 end
    end
    if p.sp then
        w.SPD = p.sp
        w.SPP = p.sp
    end
    if model == "tank" then
        w.HP5 = 0.5
        if p.block then
            local level = st.level
            local hit = 3 * (level + 2) + 0.25 * (level + 2) ^ 2
            local av = math.min(0.6, (st.miss + st.dodge + st.parry + 0.3 * st.block) / 100)
            w.BLOCKVAL = st.block / hit * 0.001 * st.hp / (1 - av)
        end
    end
    if model == "phys" and (c.spirit[class] or 0) == 0 then
        w.SPI = (w.SPI or 0) + c.speedrun * c.unitBudget.AP * c.spiritHealth
    end
    return w
end

local function linearGain(w, s, place)
    local total = 0
    for k, x in pairs(s) do
        if type(x) == "number" then
            if k == "DPS" then
                total = total + (w[place == "RANGED" and "DPS_RANGED" or "DPS_MELEE"] or 0) * x
            elseif w[k] then
                total = total + w[k] * x
            end
        end
    end
    return total
end

-- The change of the spec's output when outItems leave and inItems come ({ { stats, place }, ... }):
-- { total, main, surv, threat (percent; surv nil for a tank, threat nil for the others), gain (in
-- the spec's unit), size (the output's size in that unit) }. kind: "Speedrun" or "Hardcore" (the
-- survival share of non-tanks); wb: the bracket's weights for gems, resilience, spell penetration.
function Model.Change(class, p, kind, st, outItems, inItems, wb)
    local c = C()
    local after = st
    for _, it in ipairs(outItems) do after = Model.Apply(class, p, after, it[1], it[2], -1) end
    for _, it in ipairs(inItems) do after = Model.Apply(class, p, after, it[1], it[2], 1) end
    local lin = linear(class, p, st)
    local extra = 0
    for _, side in ipairs({ { -1, outItems }, { 1, inItems } }) do
        local sign = side[1]
        for _, it in ipairs(side[2]) do
            local s = it[1]
            extra = extra + sign * linearGain(lin, s, it[2])
            if wb then
                for k, wk in pairs(c.fallback) do
                    if type(s[k]) == "number" then extra = extra + sign * s[k] * (wb[wk] or 0) end
                end
            end
            if type(s.SETB) == "number" then extra = extra + sign * s.SETB end
        end
    end
    local eh0, vs = eh(st)
    local eh1 = eh(after)
    local surv = eh1 / eh0 - 1
    if p.model == "tank" then
        local d0, vp = phys(p.threat, st)
        local d1 = phys(p.threat, after)
        local threat = d1 / d0 - 1
        local ts = c.threatShare * 0.5
        local size = vs + ts * vp
        local gain = vs * surv + ts * vp * threat + extra
        return { total = 100 * gain / size, main = 100 * (surv + extra / vs), threat = 100 * threat, gain = gain,
            size = size, after = after }
    end
    local d0, d1, vo
    if p.model == "phys" then
        d0, vo = phys(p, st)
        d1 = phys(p, after)
    else
        local bar = barTime(p, st)
        d0, vo = caster(class, p, st, bar)
        d1 = caster(class, p, after, bar)
    end
    local main = d1 / d0 - 1 + extra / vo
    local share = (kind == "Hardcore" and c.hardcore or c.speedrun) * c.unitBudget[c.units[p.model]]
    local size = vo + share * vs
    local gain = vo * main + share * vs * surv
    return { total = 100 * gain / size, main = 100 * main, surv = 100 * surv, gain = gain, size = size, after = after }
end

---------------------------------------------------------------------------
-- The character sheet
---------------------------------------------------------------------------

local function num(f, ...)
    if type(f) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(f, ...)
    if not ok then return nil end
    return tonumber(ns.Plain(a)), tonumber(ns.Plain(b)), tonumber(ns.Plain(c)), tonumber(ns.Plain(d))
end

-- The worn items as { stats, place } with their slot: { [inv] = { s, place, link } }, and whether a
-- worn item has no stats yet (then the result must not be kept).
local function wornItems()
    local out, partial = {}, false
    for _, sl in ipairs(Gear.SLOTS) do
        local link = GetInventoryItemLink and ns.Plain(GetInventoryItemLink("player", sl.inv))
        if type(link) ~= "string" then link = nil end
        local s = link and Gear.ReadStats(link)
        if link and not s then partial = true end
        if s then
            local place
            local loc = select(4, C_Item.GetItemInfoInstant(link))
            local group = loc and Gear.GROUP[(loc:gsub("^INVTYPE_", ""))]
            if sl.key == "MAINHAND" then place = group == "2H" and "2H" or "MH"
            elseif sl.key == "OFFHAND" then place = (group == "1H" or group == "OHW") and "OH" or nil
            elseif sl.key == "RANGED" then place = "RANGED" end
            out[sl.inv] = { s, place, link }
        end
    end
    return out, partial
end
Model.WornItems = wornItems

-- Which form a druid's sheet was read in: "bear", "cat" or "caster" (everyone else: "caster").
local function formGroup()
    local _, class = UnitClass("player")
    if class ~= "DRUID" or type(GetShapeshiftFormID) ~= "function" then return "caster" end
    local ok, id = pcall(GetShapeshiftFormID)
    id = ok and tonumber(ns.Plain(id)) or nil
    if id == 5 or id == 8 then return "bear" end
    if id == 1 then return "cat" end
    return "caster"
end
local SPEC_FORM = { feral = "cat", bear = "bear" }

-- The raw sheet: what the client says about the own character, or nil when it says nothing.
local function readSheet()
    local level = num(UnitLevel, "player")
    if not level then return nil end
    local raw = { level = level, base = {}, eff = {}, school = {}, scrit = {} }
    for i, k in ipairs({ "STR", "AGI", "STA", "INT", "SPI" }) do
        -- stat, effectiveStat, posBuff, negBuff (PaperDollFrame): the naked value is the effective one
        -- without everything added (gear, buffs, talents) and taken away (negBuff is negative)
        local _, eff, pos, neg = num(UnitStat, "player", i)
        if not eff then return nil end
        raw.base[k], raw.eff[k] = eff - (pos or 0) - (neg or 0), eff
    end
    local base, pos, neg = num(UnitAttackPower, "player")
    raw.ap = base and (base + (pos or 0) + (neg or 0)) or nil
    base, pos, neg = num(UnitRangedAttackPower, "player")
    raw.rap = base and (base + (pos or 0) + (neg or 0)) or nil
    raw.crit = num(GetCritChance)
    raw.rcrit = num(GetRangedCritChance)
    if ns.BisOwnHit then raw.hit, raw.shit = ns.BisOwnHit() end
    raw.haste = num(GetCombatRatingBonus, RATING_HASTE_MELEE)
    raw.shaste = num(GetCombatRatingBonus, RATING_HASTE_SPELL)
    raw.exp = num(GetCombatRatingBonus, RATING_EXPERTISE)
    for school, i in pairs(SCHOOL_INDEX) do
        raw.school[school] = num(GetSpellBonusDamage, i)
        raw.scrit[school] = num(GetSpellCritChance, i)
    end
    raw.heal = num(GetSpellBonusHealing)
    raw.mana = num(UnitPowerMax, "player", 0)
    raw.hp = num(UnitHealthMax, "player")
    local _, armor = num(UnitArmor, "player")
    raw.armor = armor
    raw.dodge, raw.parry, raw.block = num(GetDodgeChance), num(GetParryChance), num(GetBlockChance)
    raw.blockval = num(GetShieldBlock)
    local _, defMod = num(UnitDefense, "player")
    raw.def = defMod
    raw.form = formGroup()
    return raw
end

-- Snapshots per form ("caster", "cat", "bear"), read out of combat; dirty after a change of gear,
-- level or talents (not of buffs: the number should not flicker).
local sheets, dirtyAt, sheetN = {}, 0, 0
local function now() return GetTime and GetTime() or 0 end
local readSoon   -- below: fresh and readSoon call each other
local function fresh()
    if dirtyAt == false then return end
    if InCombatLockdown and InCombatLockdown() then return end
    -- the sheet follows a gear change a moment later: read then
    local since = dirtyAt > 0 and now() - dirtyAt or 1
    if since < 0.5 then
        readSoon(0.55 - since)
        return
    end
    local raw = readSheet()
    if not raw then return end
    raw.at = time and time() or 0
    sheets[raw.form] = raw
    dirtyAt = false
    sheetN = sheetN + 1
    -- the results change, Gear.Best's lists do not (they never read the sheet)
    if ns.BisBumpResults then ns.BisBumpResults() end
end
-- a read that is due runs a moment later by itself, so a kept tooltip line is made again (the read
-- bumps Bis.lua's stamp)
readSoon = function(wait)
    if C_Timer and C_Timer.After then C_Timer.After(wait, fresh) end
end
function Model.MarkDirty()
    dirtyAt = now()
    -- every form was read with the old gear or talents: they go
    sheets = {}
    readSoon(0.6)
end
function Model.Sheet(form)
    fresh()
    return sheets[form or "caster"]
end
function Model.SheetCount() return sheetN end
function Model._reset() sheets, dirtyAt, sheetN = {}, 0, 0 end

-- A state for spec p from the raw sheet and the worn items. Talents and buffs that raise an
-- attribute by a percentage show as the ratio of the sheet's value to base plus gear (between 1 and
-- 1.2; under 1.02 counts as 1).
local function fromSheet(class, p, raw, worn)
    local gear = {}
    local mh, oh, rg, mp5 = nil, nil, nil, 0
    for _, it in pairs(worn) do
        local s, place = it[1], it[2]
        for _, k in ipairs({ "STR", "AGI", "STA", "INT", "SPI" }) do gear[k] = (gear[k] or 0) + (s[k] or 0) end
        mp5 = mp5 + (s.MP5 or 0)
        if place == "2H" or place == "MH" then mh = s elseif place == "OH" then oh = s elseif place == "RANGED" then rg = s end
    end
    local level = raw.level
    local st = { level = level, mult = {}, school = {} }
    for _, k in ipairs({ "STR", "AGI", "STA", "INT", "SPI" }) do
        st[k] = raw.eff[k]
        local denom = (raw.base[k] or 0) + (gear[k] or 0)
        local m = denom > 0 and raw.eff[k] / denom or 1
        m = math.floor(m * 100 + 0.5) / 100
        if m < 1.02 then m = 1 elseif m > 1.2 then m = 1.2 end
        st.mult[k] = m
    end
    local ref = Model.FromRef(class, p, Model.Ref(class, level, {}, nil))
    st.ap = raw.ap or ref.ap
    st.rap = raw.rap or ref.rap
    st.mhDPS = mh and mh.DPS or (1 + 0.75 * level)
    st.mhSpeed = mh and mh.SPEED or 2.6
    st.ohDPS = oh and oh.DPS or 0
    st.rDPS = rg and rg.DPS or (1 + 0.6 * level)
    st.rSpeed = rg and rg.SPEED or 2.8
    st.dw = oh ~= nil and not p.ranged
    st.crit = raw.crit or ref.crit
    st.rcrit = raw.rcrit or st.crit
    st.hit, st.shit = raw.hit or 0, raw.shit or 0
    st.exp, st.haste, st.shaste = raw.exp or 0, raw.haste or 0, raw.shaste or 0
    -- the generic spell damage is what every school has; the rest is the school's own
    local spg
    for _, school in ipairs(SCHOOLS) do
        local v = raw.school[school]
        if v and (not spg or v < spg) then spg = v end
    end
    st.spg = spg or 0
    for _, school in ipairs(SCHOOLS) do st.school[school] = (raw.school[school] or st.spg) - st.spg end
    st.heal = raw.heal or 0
    local critSchool = p.model == "heal" and HEAL_SCHOOL[class] or nil
    if not critSchool then
        local best = -1
        for school, share in pairs(p.school or {}) do
            if share > best then critSchool, best = school, share end
        end
    end
    st.scrit = (critSchool and raw.scrit[critSchool]) or ref.scrit
    st.mana = (raw.mana and raw.mana > 0) and raw.mana or ref.mana
    st.mp5 = mp5
    st.hp = (raw.hp and raw.hp > 0) and raw.hp or ref.hp
    st.armor = raw.armor or ref.armor
    st.miss = 5 + (raw.def or 0) * 0.04
    st.dodge = raw.dodge or ref.dodge
    st.parry = raw.parry or 0
    st.block = raw.block or 0
    st.canParry, st.canBlock = st.parry > 0, st.block > 0
    st.blockval = raw.blockval or 0
    return st
end

-- The state of the own character for spec p: from the sheet when one was read in the spec's form,
-- else from the base values and the worn gear (approx = true). nil without data.
function Model.OwnState(class, specKey, p, plan)
    if not p then return nil end
    local worn = wornItems()
    local raw = Model.Sheet(SPEC_FORM[specKey] or "caster")
    if raw then return fromSheet(class, p, raw, worn), false, raw end
    local level = math.max(1, math.min(tonumber(ns.Plain(UnitLevel("player"))) or 1, Gear.Cap()))
    local list = {}
    for _, it in pairs(worn) do list[#list + 1] = it end
    return Model.FromRef(class, p, Model.Ref(class, level, list, plan)), true, nil
end

-- The main values the model of p uses, for "Warum?" and the tooltip: { { label, text }, ... } with
-- "512 -> 522" where the exchange moves them; changedOnly leaves the others out.
function Model.Values(class, p, st, after, changedOnly)
    local out = {}
    local function add(label, key, pct)
        local a, b = st[key], after and after[key]
        if type(a) ~= "number" then return end
        if changedOnly and not (b and math.abs(b - a) > 1e-6) then return end
        local fmt = pct and "%s %%" or "%s"
        local text = fmt:format(Gear.Num(a, pct and 1 or nil))
        if b and math.abs(b - a) > 1e-6 then text = text .. " -> " .. fmt:format(Gear.Num(b, pct and 1 or nil)) end
        out[#out + 1] = { label, text }
    end
    if p.model == "phys" then
        if p.ranged then add(L["Distanzangriffskraft"], "rap") else add(L["Angriffskraft"], "ap") end
        add(L["Krit"], p.ranged and "rcrit" or "crit", true)
        add(L["Treffer"], "hit", true)
        add(L["Waffenschaden pro Sekunde"], p.ranged and "rDPS" or "mhDPS")
    elseif p.model == "caster" or p.model == "heal" then
        add(p.model == "heal" and L["Heilung"] or L["Zauberschaden"], p.model == "heal" and "heal" or "spg")
        add(L["Zauberkrit"], "scrit", true)
        if p.model == "caster" then add(L["Zaubertreffer"], "shit", true) end
        add(L["Mana"], "mana")
    else
        add(L["Gesundheit"], "hp")
        add(L["Rüstung"], "armor")
        add(L["Ausweichen"], "dodge", true)
        if st.canParry then add(L["Parieren"], "parry", true) end
        if st.canBlock then add(L["Blocken"], "block", true) end
    end
    return out
end

local f = CreateFrame and CreateFrame("Frame")
if f then
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "CHARACTER_POINTS_CHANGED",
        "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED", "TRAIT_CONFIG_UPDATED", "PLAYER_REGEN_ENABLED",
        "UPDATE_SHAPESHIFT_FORM" }) do
        pcall(f.RegisterEvent, f, e)
    end
    f:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" or event == "UPDATE_SHAPESHIFT_FORM" then
            -- a form not read yet (or a read the fight held back) is read now
            if not sheets[formGroup()] and dirtyAt == false then dirtyAt = 0 end
            if dirtyAt ~= false then readSoon(0.1) end
            return
        end
        Model.MarkDirty()
    end)
end
