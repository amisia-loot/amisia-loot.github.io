"""DKP and EPGP on the site (index.html) and their way to and from the Amisia addon.

tools/tests/site_points.cjs runs the whole page against a fake DOM: the ledger switches to DKP (or
EPGP) in the Points tab, an export the addon itself wrote (here, under lupa) is pasted on the Import
tab and its points are taken over, a correction is booked, the weekly decay applied, and the text for
the addon is pasted back into the addon. The two halves must agree: the site's standings after the
import are the addon's live standings, the formula and the rounding are the same on both sides, and
the addon does not count again what the site already has (R and I lines).
"""
import json
import os
import shutil
import subprocess
import sys

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DRIVER = os.path.join(ROOT, 'tools', 'tests', 'site_points.cjs')
sys.path.insert(0, os.path.join(ROOT, 'addon', 'tests'))

ON_SITE = ('Vuloo', 'Fraktur', 'Chorf')   # names of the page's own ledger the addon's raid uses


def node():
    n = shutil.which('node') or os.path.expanduser('~/.local/node/bin/node')
    if not os.path.exists(n):
        pytest.skip('node is not installed')
    return n


def addon():
    run = pytest.importorskip('run', reason='addon/tests/run.py needs lupa')
    return run.fresh('--[[preload\nSTUB.toc = 16001\n]]')


def raid(lua, sys_):
    """A raid recorded by the addon under sys_ ('dkp' or 'epgp'): returns the export, the award's id,
    the raid date, the award's time, the addon's standings {name: (a, b)}, the correction's id."""
    head = ('#AMISIA-PTS 1 forever 2026-10-08 %s 0\\nCFG raid=10 boss=5 time=5 bench=10 base=100 scale=100 ref=66 os=50\\n#END' % sys_)
    res = lua.eval('''function()
        STUB.now = 1791400000
        STUB.instance = { name = "Naxxramas", type = "raid", id = 533 }
        STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" }, { name = "Chorf", class = "WARRIOR" },
                        { name = "Ziepel", class = "MAGE" }, { name = "Gast", class = "ROGUE" } }
        assert(NS.SetAlts("#AMISIA-ALTS 1 forever 2026-10-08\\nA Ziepel Fraktur\\n#END"))
        assert(NS.SetPointsSite("%s"))
        STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
        local s = NS.Active()
        s.members["Chorf"].late = true
        s.bench = { ["Bankdrücker"] = { t = STUB.now } }
        s.kills = { { enc = 1107, name = "Anub'Rekhan", start = STUB.now, t = STUB.now + 60, ok = true, who = { "Vuloo", "Fraktur", "Ziepel" } } }
        STUB.item(30000, "Brustplatte", 4)
        local a = NS.AddAwardTo(s, { name = "Ziepel", item = 30000, kind = "MS", src = "Noth", t = STUB.now + 100 })
        assert(NS.SetAwardPoints(s, a.id, 25))
        local c = assert(NS.PointsAdjust("Chorf", 7, "Pünktlich nachgetragen"))
        local st = {}
        for _, e in ipairs(NS.PointsStandings()) do st[e.name] = { e.a, e.b } end
        return NS.ExportText({ s }), a.id, s.date, math.floor(a.t), st, c.id
    end''' % head)()
    export, uid, date, at, st, cid = res
    standings = {k: (st[k][1], st[k][2]) for k in st.keys()}
    return export, uid, date, at, standings, cid


def drive(export, award, epgp=False):
    p = subprocess.run([node(), DRIVER], input=json.dumps({'export': export, 'award': award, 'epgp': epgp}).encode('utf-8'),
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=dict(os.environ, TZ='UTC'))
    assert p.returncode == 0, p.stderr.decode('utf-8', 'replace')
    return json.loads(p.stdout.decode('utf-8'))


@pytest.fixture(scope='module')
def dkp():
    lua = addon()
    export, uid, date, at, st, cid = raid(lua, 'dkp')
    out = drive(export, {'uid': uid, 'item': 30000, 'name': 'Ziepel', 'date': date, 'at': at, 'alts': [['Ziepel', 'Fraktur']]})
    return {'lua': lua, 'export': export, 'uid': uid, 'st': st, 'cid': cid, 'out': out}


def by_name(rows):
    return {r['name']: r for r in rows}


def test_the_export_lines(dkp):
    lines = dkp['export'].split('\n')
    assert 'PS D dkp on' in lines
    assert any(l.startswith('PA %s D 25 ' % dkp['uid']) for l in lines), lines
    assert any(l.startswith('PX %s Chorf D 7 ' % dkp['cid']) and l.endswith(' Vuloo Pünktlich nachgetragen') for l in lines), lines
    pe = [l for l in lines if l.startswith('PE ')]
    assert len(pe) == 13, pe   # 5 for the raid, 4 on time (Chorf came late), 3 for the boss, 1 for the bench
    assert any(' Ziepel 5 B ' in l and l.endswith("Anub'Rekhan") for l in pe)
    assert any(' Bankdrücker 10 N ' in l for l in pe), 'the bench'


def test_the_import_panel(dkp):
    p = dkp['out']['panel']
    assert not p['hidden'] and not p['disabled']
    assert '(DKP): 70 DKP for 4 raiders' in p['text'] and 'new' in p['text'], p['text']
    assert 'not on the roster: Gast, Bankdrücker' in p['text'] or 'not on the roster: Bankdrücker, Gast' in p['text'], p['text']
    assert '1 award cost: 1 to take over' in p['text'] and '1 correction made in game: 1 new' in p['text'], p['text']
    out = dkp['out']
    assert out['again']['disabled'] and 'already in the ledger' in out['again']['text'], 'the same text again: nothing new'
    assert out['costAt'] == {'p': 'D', 'n': 25, 'at': out['costAt']['at'], 'by': 'Vuloo'}


def test_the_site_counts_what_the_addon_counts(dkp):
    site = by_name(dkp['out']['afterImport'])
    for name in ON_SITE:
        assert site[name]['a'] == dkp['st'][name][0], (name, site[name], dkp['st'][name])
    assert site['Fraktur']['a'] == 20 + 20 - 25, "the alt's earnings and cost for the main"
    assert 'Ziepel' not in site and 'Gast' not in site, 'mains on the roster only'


def test_the_tab(dkp):
    out = dkp['out']
    assert 'The guild rolls' in out['rolling']['hint'] and 'No points system' in out['rolling']['body']
    assert not out['rolling']['points'], 'looking creates nothing in the ledger'
    assert 'Step must be a whole number from 1 to 10000.' == out['refusedCfg'], out['refusedCfg']
    assert out['cfg']['sys'] == 'dkp' and out['cfg']['pub'] == 1 and out['cfg']['step'] == 5
    assert out['count'] == '3 of 3 players'
    assert 'data-ptpick' in out['rows'] and 'Ziepel' in out['rows'], 'the alts beside the main'
    assert out['historyHead'] == 'Fraktur: 15 DKP', out['historyHead']
    assert 'Award: ' in out['history'] and 'Boss: Anub&#39;Rekhan (Ziepel)' in out['history'], out['history']


def test_a_correction_needs_a_reason(dkp):
    out = dkp['out']
    assert out['noReason'] == 'Give a reason.'
    assert out['booked'] == 'Booked.'
    e = out['adjEntry']
    assert e['n'] == -20 and e['pool'] == 'D' and e['reason'] == 'Ninja Loot' and e['code'] == 'X'
    assert by_name(out['afterAdjust'])['Fraktur']['a'] == 15 - 20, 'an alt booked counts for the main'


def test_the_decay(dkp):
    out = dkp['out']
    d = by_name(out['afterDecay'])
    assert d['Vuloo']['a'] == 18 and d['Fraktur']['a'] == -5 and d['Chorf']['a'] == 15, d
    assert len(out['decays']) == 1 and out['decays'][0]['pct'] == 10
    assert out['historyAfter'][0][1] == 'Decay 10 %' and out['historyAfter'][0][2] == -5, out['historyAfter'][0]


def test_the_text_for_the_addon(dkp):
    t = dkp['out']['pointsText'].split('\n')
    assert t[0].startswith('#AMISIA-PTS 1 forever ') and t[0].split()[4] == 'dkp' and t[-1] == '#END', t
    assert t[1].startswith('CFG raid=10 boss=5 time=5 bench=10 mode=bid seal=0 min=10 step=5 decay=10 ') and 'pub=1' in t[1], t[1]
    assert 'P Vuloo 18' in t and 'P Fraktur -5' in t and 'P Chorf 15' in t
    assert any(l.startswith('R ') for l in t) and any(l.startswith('I ') and dkp['uid'] in l and dkp['cid'] in l for l in t), t
    assert dkp['out']['text'].endswith(dkp['out']['pointsText']), 'behind the wishes, alts and prio'


def test_the_addon_takes_the_site_text_without_counting_twice(dkp):
    lua = dkp['lua']
    back = lua.eval('''function(t)
        local text, ok = NS.ImportSiteText(t)
        return text, ok, NS.PointsOf("Vuloo").a, NS.PointsOf("Fraktur").a, NS.PointsOf("Ziepel").a, NS.PointsOf("Chorf").a, #NS.PointsExportLines()
    end''')
    text, ok, vuloo, fraktur, ziepel, chorf, pending = back(dkp['out']['text'])
    assert ok and '3 Punktestände' in text, text
    assert (vuloo, fraktur, ziepel, chorf) == (18, -5, -5, 15), (vuloo, fraktur, ziepel, chorf)
    assert pending == 0, 'the site has the correction: it is not exported again'


def test_viewers(dkp):
    out = dkp['out']
    assert out['viewerPub']['side'] and out['viewerPub']['rows'] == 3, 'the list while the guild shows it'
    assert out['viewerOwn']['rows'] == 0 and 'only your own standing' in out['viewerOwn']['hint']


def test_an_award_removed_takes_its_cost_along(dkp):
    assert by_name(dkp['out']['withoutAward'])['Fraktur']['a'] > by_name(dkp['out']['afterDecay'])['Fraktur']['a']


def test_hostile_lines(dkp):
    b = dkp['out']['bad']
    assert b['bad'] == 11, b
    assert len(b['raids']) == 1 and [e['name'] for e in b['raids'][0]['earn']] == ['Anna']
    assert b['costs'] == [] and [x['n'] for x in b['adjust']] == [-7] and b['adjust'][0]['reason'] == 'Gut  cff'


def test_formula_and_rounding_match_the_addon(dkp):
    lua = dkp['lua']
    loc = {'head': 'INVTYPE_HEAD', 'shoulder': 'INVTYPE_SHOULDER', 'neck': 'INVTYPE_NECK', 'weapon': 'INVTYPE_WEAPON',
           'weapon2': 'INVTYPE_2HWEAPON', 'offhand': 'INVTYPE_SHIELD', 'token': None}
    f = lua.eval('function(i, s, q, sc, r) return NS.PointsFormula(i, s, q, sc, r) end')
    for ilvl, slot, q, a, b in dkp['out']['formula']:
        assert f(ilvl, loc[slot], q, 100, 66) == a, (ilvl, slot, q)
        assert f(ilvl, loc[slot], q, 50, 70) == b, (ilvl, slot, q)
    r = lua.eval('function(x) return NS.PointsRound(x) end')
    assert dkp['out']['round'] == [r(x) for x in (2.5, -2.5, 2.49, -0.4, 13.5, -49.5)]
    d = lua.eval('function(v, p) return NS.PointsDecayed(v, p) end')
    assert dkp['out']['decayed'] == [d(v, p) for v, p in ((100, 10), (-55, 10), (15, 10), (5, 0), (5, 100))]
    assert dkp['out']['compare'] == 0


@pytest.fixture(scope='module')
def epgp():
    lua = addon()
    export, uid, date, at, st, cid = raid(lua, 'epgp')
    out = drive(export, {'uid': uid, 'item': 30000, 'name': 'Ziepel', 'date': date, 'at': at, 'alts': [['Ziepel', 'Fraktur']]}, epgp=True)
    return {'lua': lua, 'export': export, 'uid': uid, 'st': st, 'out': out}


def test_epgp_round_trip(epgp):
    lines = epgp['export'].split('\n')
    assert 'PS E epgp on' in lines and any(l.startswith('PA %s G 25 ' % epgp['uid']) for l in lines)
    site = by_name(epgp['out']['afterImport'])
    for name in ON_SITE:
        assert (site[name]['a'], site[name]['b']) == epgp['st'][name], (name, site[name], epgp['st'][name])
    assert site['Fraktur']['b'] == 25, 'the cost is GP'
    t = epgp['out']['pointsText'].split('\n')
    assert t[0].split()[4] == 'epgp' and any(l.startswith('P Fraktur ') and len(l.split()) == 4 for l in t), t
    back = epgp['lua'].eval('''function(t)
        local _, ok = NS.ImportSiteText(t)
        local f = NS.PointsOf("Fraktur")
        return ok, f.a, f.b
    end''')
    ok, a, b = back(epgp['out']['text'])
    sf = by_name(epgp['out']['afterDecay'])['Fraktur']
    assert ok and (a, b) == (sf['a'], sf['b']), ((a, b), sf)


def test_the_page_wires_it_up():
    page = open(os.path.join(ROOT, 'index.html'), encoding='utf-8').read()
    assert 'data-view="points"' in page and 'id="view-points"' in page
    assert "'lootPrio', 'points'];" in page, 'kept per game'
    assert "if (ui.view === 'points') renderPoints();" in page
    assert 't = pointsAddonText(); return wishAddonText(WISHES)' in page, 'the paste-in block behind the others'
