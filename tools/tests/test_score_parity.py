"""One scoring formula, two implementations: tools/build_bis.py's score() and Gear.lua's Gear.Score
give the same number (to 0.01) for 200 items of the real item data per spec, at several levels,
with every weapon place, the hit cap and a set bonus."""
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
sys.path.insert(0, os.path.join(ROOT, 'tests'))
import build_bis as bb  # noqa: E402
import run  # noqa: E402

KIND_OF = {'2H': '2H', '1H': 'MH', 'MH': 'MH', 'OHW': 'OH', 'RANGED': 'RANGED'}


def weights_py(G, cls, key, kind, level):
    specs = G.specs[cls]
    for i in range(1, len(specs) + 1):
        if specs[i].key == key:
            sets = specs[i][kind] or specs[i].Speedrun
            brackets = [G.brackets[j] for j in range(1, len(G.brackets) + 1)]
            idx = next((j for j, b in enumerate(brackets) if level <= b), len(brackets) - 1)
            # a weighting without a set of its own for the bracket ("Raid" below the cap) reads Speedrun
            w = sets[idx + 1] or specs[i].Speedrun[idx + 1]
            return {k: w[k] for k in w.keys()}
    raise KeyError(key)


def test_python_and_lua_score_alike():
    lua = run.fresh()
    G = lua.globals().NS.GEAR_WEIGHTS
    gear = bb.load_gear()
    items = bb.Items(gear, {}, bb.gear_stat_map())
    ratings = {k: G.ratings[k] for k in bb.RATING_60}
    conv = bb.Conv({'rating60': ratings})
    score_lua = lua.eval('function(s, w, level, kind, class, cap) return NS.Gear.Score(s, w, level, kind, class, cap) end')
    rnd = random.Random(7)
    ids = sorted(items.stats)
    checked = 0
    for cls, key, *_ in bb.SPECS:
        sample = rnd.sample(ids, 200)
        for n, iid in enumerate(sample):
            s = dict(items.stats[iid])
            level = (9, 14, 27, 41, 60)[n % 5]
            kindw = ('Speedrun', 'Hardcore', 'Raid')[n % 3]
            w = weights_py(G, cls, key, kindw, level)
            got = lua.eval('function(c, k, kind, level) return NS.Gear.Weights(c, k, kind, level) end')(cls, key, kindw, level)
            assert {k: got[k] for k in got.keys()} == w, (cls, key, kindw, level)
            row = gear['I'][iid]
            place = KIND_OF.get(bb.GROUP.get(row[0]))
            if n % 7 == 0:
                s['SETB'] = 11.5
            cap = {'HIT': 1.5, 'SHIT': 0.5} if n % 3 == 0 else None
            py = bb.score(s, w, level, place, cls, conv) if not cap else py_capped(s, w, level, place, cls, conv, cap)
            lu = score_lua(lua.table_from(s), lua.table_from(w), level, place, cls,
                           lua.table_from(cap) if cap else None)
            assert abs(py - lu) < 0.01, (cls, key, iid, level, place, py, lu)
            checked += 1
    assert checked == 200 * len(bb.SPECS)


def py_capped(s, w, level, kind, cls, conv, cap):
    """score() with the hit cap of Gear.lua: hit rating counts up to the room left."""
    total = 0.0
    for key, value, weight, rating in bb.terms(s, w, level, kind, cls, conv):
        if not value or not weight:
            continue
        if rating:
            conv_v = value * conv.rating_pp(rating, level)
            room = {'HIT': cap.get('HIT'), 'MHIT': cap.get('HIT'), 'SHIT': cap.get('SHIT'),
                    'HITSP': cap.get('SHIT')}.get(key)
            if room is not None:
                conv_v = max(0.0, min(conv_v, room))
            total += conv_v * weight
        else:
            total += value * weight
    return total


def test_an_own_set_scores_alike(tmp_path):
    """F-230, D-161: an own set per point becomes the same weights in Python (point_weights) and Lua
    (Gear.Weights with "Eigene"), and scores the same; a generic hit or crit point counts its weight once, on the
    spec's side (a caster's spells, a warrior's weapons), at every level; empty haste counts nothing."""
    lua = run.fresh()
    NS = lua.globals().NS
    G = NS.GEAR_WEIGHTS
    gear = bb.load_gear()
    items = bb.Items(gear, {}, bb.gear_stat_map())
    conv = bb.Conv({'rating60': {k: G.ratings[k] for k in bb.RATING_60}})
    sets = {('PRIEST', 'shadow'): {'INT': 0.24, 'SP': 1, 'SP_SHADOW': 1, 'SPI': 0.01, 'HIT': 1.14, 'CRIT': 0.84},
            ('WARRIOR', 'dps'): {'STR': 2.2, 'AGI': 1.7, 'AP': 1, 'HIT': 1.69, 'CRIT': 2.26, 'HASTE': 1.76, 'EXP': 2.35,
                                 'DPS': 12.59, 'STA': -0.1}}
    save = lua.eval('function(c, s, n, t) return NS.OwnWeights.Save(c, s, n, t, { pick = true, replace = true }) end')
    weights = lua.eval('function(c, k, level) return NS.Gear.Weights(c, k, "Eigene", level) end')
    score_lua = lua.eval('function(s, w, level, kind, class) return NS.Gear.Score(s, w, level, kind, class) end')
    rnd = random.Random(11)
    ids = sorted(items.stats)
    for (cls, key), pp in sets.items():
        assert save(cls, key, 'Test', lua.table_from(pp)) == 'Test'
        model = next(m for c, k, _n, _r, m, _p in bb.SPECS if (c, k) == (cls, key))
        for level in (9, 27, 60):
            w = bb.point_weights(pp, model, level, conv)
            got = weights(cls, key, level)
            got = {k: got[k] for k in got.keys() if k != 'own'}
            assert got.keys() == w.keys() and all(abs(got[k] - w[k]) < 1e-9 for k in w), (cls, level, got, w)
            # one generic hit point and one crit point count their weight per point, once
            one = {'HIT': 1}
            assert abs(bb.score(one, w, level, None, cls, conv) - pp['HIT']) < 1e-9
            assert abs(bb.score({'CRIT': 1}, w, level, None, cls, conv) - pp['CRIT']) < 1e-9
            assert abs(bb.score({'HASTE': 10}, w, level, None, cls, conv) - 10 * pp.get('HASTE', 0)) < 1e-9
            for iid in rnd.sample(ids, 60):
                s = dict(items.stats[iid])
                place = KIND_OF.get(bb.GROUP.get(gear['I'][iid][0]))
                py = bb.score(s, w, level, place, cls, conv)
                lu = score_lua(lua.table_from(s), lua.table_from(w), level, place, cls)
                assert abs(py - lu) < 0.01, (cls, iid, level, py, lu)
