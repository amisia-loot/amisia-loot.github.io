"""One scoring formula, two implementations: tools/build_bis.py's score() and Gear.lua's Gear.Score
give the same number (to 0.01) for 200 items of the real item data per spec, at several levels,
with every weapon place, the hit cap and a set bonus."""
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
sys.path.insert(0, os.path.join(ROOT, 'addon', 'tests'))
import build_bis as bb  # noqa: E402
import run  # noqa: E402

KIND_OF = {'2H': '2H', '1H': 'MH', 'MH': 'MH', 'OHW': 'OH', 'RANGED': 'RANGED'}


def weights_py(G, cls, key, kind, level):
    specs = G.specs[cls]
    for i in range(1, len(specs) + 1):
        if specs[i].key == key:
            sets = specs[i][kind]
            brackets = [G.brackets[j] for j in range(1, len(G.brackets) + 1)]
            idx = next((j for j, b in enumerate(brackets) if level <= b), len(brackets) - 1)
            w = sets[idx + 1]
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
            kindw = ('Speedrun', 'Hardcore')[n % 2]
            w = weights_py(G, cls, key, kindw, level)
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
            room = {'MHIT': cap.get('HIT'), 'SHIT': cap.get('SHIT'),
                    'HIT': cap.get('HIT') if cap.get('HIT') is not None else cap.get('SHIT')}.get(key)
            if room is not None:
                conv_v = max(0.0, min(conv_v, room))
            total += conv_v * weight
        else:
            total += value * weight
    return total
