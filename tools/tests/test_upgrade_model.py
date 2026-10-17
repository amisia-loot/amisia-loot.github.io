"""The upgrade model (DECISIONS D-54) exists twice: tools/build_bis.py's m_* functions and Gear/Model.lua.
They give the same numbers; the model's slopes at a reference character are the weights build_bis.py
derives there (the weights are the model's linear form); GearWeights.lua carries the parameters the
build used."""
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
sys.path.insert(0, os.path.join(ROOT, 'tests'))
import build_bis as bb  # noqa: E402
import run  # noqa: E402

KEYS = ['STR', 'AGI', 'STA', 'INT', 'SPI', 'AP', 'RAP', 'SPD', 'SPP', 'HEAL', 'SP_NATURE', 'SP_FIRE', 'SP_SHADOW',
        'SP_FROST', 'SP_ARCANE', 'SP_HOLY', 'HIT', 'MHIT', 'SHIT', 'CRIT', 'MCRIT', 'SCRIT', 'HASTE', 'EXP', 'DODGE',
        'PARRY', 'BLOCK', 'DEF', 'ARMOR', 'MP5', 'HP5', 'BLOCKVAL', 'DPS']


def conv_of(G=None):
    if G is None:
        return bb.Conv(bb.load_measured())
    return bb.Conv(dict(bb.load_measured(), rating60={k: G.ratings[k] for k in bb.RATING_60}))


def ref_for(cls, level, plan, extra=10, rnd=None):
    r = {'level': level, 'plan': plan}
    x = (lambda a, b: rnd.uniform(a, b)) if rnd else (lambda a, b: (a + b) / 2)
    for k in ('STR', 'AGI', 'STA', 'INT', 'SPI'):
        r[k] = bb.base_attr(cls, level, k) + extra + (x(0, 40) if rnd else 0)
    r.update(hit=x(0, 4), spellhit=x(0, 4), critRating=x(0, 3), spellCritRating=x(0, 3), dodgeRating=x(0, 2),
             parryRating=x(0, 2), block=x(0, 3), AP=x(0, 80), RAP=0, FAP=0, SPP=x(0, 60), SPD=x(0, 30),
             HEAL=x(0, 80), MP5=x(0, 8), ARMOR=x(100, 2000), BLOCKVAL=x(0, 40), wDPS=1 + 0.75 * level, speed=3.3,
             ohDPS=0, rDPS=1 + 0.6 * level, rSpeed=2.8)
    r['def'] = x(0, 10)
    for s in bb.SCHOOLS:
        r[s] = x(0, 10)
    return r


def test_the_slopes_are_the_weights():
    """One point of each stat changes the model by what derive() weighs it at the same reference
    (Speedrun). Left out on purpose: a tank's haste (the weights take four fifths of crit, the model
    the swing time) and, for casters, spirit and mana per 5 with regeneration in the state (the model
    counts regeneration into the mana pool, the weights only the bar): those run with neither here."""
    conv = conv_of()
    bad = []
    for cls, key, _name, _role, model, p in bb.SPECS:
        pp = bb.m_params(cls, model, p)
        for level in (12, 27, 45, 60):
            ref = ref_for(cls, level, p.get('plan', '2H'))
            speed, _hard, _shown = bb.derive(cls, model, p, ref, conv)
            st = bb.m_state_from_ref(cls, pp, ref, conv)
            if model in ('caster', 'heal'):
                st['SPI'] = 0
                st['mp5'] = 0
            for k in KEYS:
                if model == 'tank' and k == 'HASTE':
                    continue
                # a two-hander would end a rogue's dual wield: its weapon damage goes to the main hand
                melee = 'MH' if p.get('plan') == 'DW' else '2H'
                place = ('RANGED' if p.get('ranged') else melee) if k == 'DPS' else None
                d = 0.01
                got = bb.m_change(cls, pp, 'Speedrun', st, [], [({k: d}, place)], conv)['gain'] / d
                want = bb.score({k: 1}, speed, level, place, cls, conv)
                if abs(got - want) > 0.02 + 0.03 * abs(want):
                    bad.append((cls, key, level, k, round(got, 4), round(want, 4)))
    assert not bad, bad[:20]


def to_lua(lua, v):
    if isinstance(v, dict):
        t = lua.table()
        for k, x in v.items():
            t[k] = to_lua(lua, x)
        return t
    if isinstance(v, (list, tuple)):
        t = lua.table()
        for i, x in enumerate(v, 1):
            t[i] = to_lua(lua, x)
        return t
    return v


def from_lua(t):
    return {k: (from_lua(v) if hasattr(v, 'items') else v) for k, v in t.items()}


def test_python_and_lua_alike():
    """Same state, same items: Model.FromRef equals m_state_from_ref and Model.Change equals m_change
    (total, main, survival, threat, gain), with real items swapped in and out, every weapon place and
    both weightings (to the rounding of the conversions GearWeights.lua carries)."""
    lua = run.fresh()
    G = lua.globals().NS.GEAR_WEIGHTS
    conv = conv_of(G)
    gear = bb.load_gear()
    items = bb.Items(gear, {}, bb.gear_stat_map())
    ids = sorted(items.stats)
    rnd = random.Random(11)
    from_ref = lua.eval('function(c, p, ref) return NS.Model.FromRef(c, p, ref) end')
    change = lua.eval('function(c, p, kind, st, o, i, wb) return NS.Model.Change(c, p, kind, st, o, i, wb) end')
    params = lua.eval('function(c, k) return (NS.Model.Params(c, k)) end')
    checked = 0
    for cls, key, _name, _role, model, p in bb.SPECS:
        pp = bb.m_params(cls, model, p)
        lp = params(cls, key)
        assert from_lua(lp) == pp, (cls, key, from_lua(lp), pp)
        for n in range(25):
            level = rnd.choice((8, 15, 24, 33, 47, 60))
            ref = ref_for(cls, level, p.get('plan', '2H'), rnd=rnd)
            st = bb.m_state_from_ref(cls, pp, ref, conv)
            lst = from_lua(from_ref(cls, lp, to_lua(lua, ref)))
            for k, v in st.items():
                if isinstance(v, dict):
                    for kk, vv in v.items():
                        assert abs(vv - lst[k].get(kk, 0)) < 1e-5 * max(1, abs(vv)), (cls, key, k, kk)
                elif isinstance(v, bool):
                    assert bool(lst.get(k)) == v, (cls, key, k)
                else:
                    assert abs(v - lst[k]) < 1e-5 * max(1, abs(v)), (cls, key, k, v, lst[k])
            out_items, in_items = [], []
            for side in (out_items, in_items):
                iid = rnd.choice(ids)
                s = dict(items.stats[iid])
                place = {'2H': '2H', '1H': 'MH', 'MH': 'MH', 'OHW': 'OH', 'RANGED': 'RANGED'}.get(
                    bb.GROUP.get(gear['I'][iid][0]))
                if n % 6 == 0:
                    s['SETB'] = 7.5
                side.append((s, place))
            kind = ('Speedrun', 'Hardcore')[n % 2]
            wb = {'GEM': 4.0, 'META': 9.0, 'RES': 0.5, 'SPEN': 0.3}
            py = bb.m_change(cls, pp, kind, st, out_items, in_items, conv, wb)
            lu = from_lua(change(cls, lp, kind, to_lua(lua, st), to_lua(lua, [list(x) for x in out_items]),
                                 to_lua(lua, [list(x) for x in in_items]), to_lua(lua, wb)))
            for k in ('total', 'main', 'surv', 'threat', 'gain', 'size'):
                a, b = py[k], lu.get(k)
                if a is None:
                    assert b is None, (cls, key, k, b)
                else:
                    assert abs(a - b) < 1e-4 * max(1, abs(a)), (cls, key, k, a, b)
            checked += 1
    assert checked == 25 * len(bb.SPECS)


def test_gear_weights_carry_the_model():
    """GearWeights.lua has every spec's model and parameters and the constants (as the build wrote them)."""
    lua = run.fresh()
    G = lua.globals().NS.GEAR_WEIGHTS
    conv = conv_of(G)
    want = bb.model_constants(conv)
    got = from_lua(G.model)
    for k in ('meleeMiss', 'dwMiss', 'spellMiss', 'targetDodge', 'threatShare', 'speedrun', 'hardcore'):
        assert got[k] == want[k], k
    for cls in bb.CLASS_ORDER:
        assert abs(got['agi60'][cls] - want['agi60'][cls]) < 1e-3, cls
        assert abs(got['int60'][cls] - want['int60'][cls]) < 1e-3, cls
    by = {(c, k): (m, p) for c, k, _n, _r, m, p in bb.SPECS}
    for cls in bb.CLASS_ORDER:
        specs = G.specs[cls]
        for i in range(1, len(specs) + 1):
            sp = specs[i]
            model, p = by[(cls, sp.key)]
            assert sp.model == model, (cls, sp.key)


def test_dual_wield_follows_the_weapons():
    """Two weapons miss more: a two-hander in ends it (the swap is worth the miss it saves), an off-hand
    weapon in starts it, a hunter's shots never miss as two weapons."""
    conv = conv_of()
    cls, key, _n, _r, model, p = next(x for x in bb.SPECS if x[0] == 'WARRIOR' and x[1] == 'dps')
    pp = bb.m_params(cls, model, dict(p, plan='DW'))
    st = bb.m_state_from_ref(cls, pp, ref_for(cls, 60, 'DW'), conv)
    st['ohDPS'], st['dw'] = 50.0, True
    oh, two = ({'DPS': 50.0}, 'OH'), ({'DPS': 70.0, 'SPEED': 3.6}, '2H')
    after = bb.m_apply(cls, pp, bb.m_apply(cls, pp, st, *oh, -1, conv), *two, 1, conv)
    assert after['dw'] is False
    kept = dict(after, dw=True)
    assert bb.m_phys(cls, pp, after)[0] > bb.m_phys(cls, pp, kept)[0] * 1.1
    assert bb.m_apply(cls, pp, dict(st, dw=False), *oh, 1, conv)['dw'] is True
    hunter = next(x for x in bb.SPECS if x[0] == 'HUNTER')
    hp = bb.m_params('HUNTER', hunter[4], hunter[5])
    hs = bb.m_state_from_ref('HUNTER', hp, ref_for('HUNTER', 60, '2H'), conv)
    assert bb.m_phys('HUNTER', hp, dict(hs, dw=True))[0] == bb.m_phys('HUNTER', hp, hs)[0]
