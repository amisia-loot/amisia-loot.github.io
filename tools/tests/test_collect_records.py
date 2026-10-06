"""The collector's records in Python (build_scan.py) as in the addon (Collector.lua), review 26:
the same strict check (one canonical form, no trailing newline, the addon's text rules), the same
merge (own values beat heard ones, caps), a build view that trusts own values and heard values only
when two distinct accounts hold them alike, the item filter by the client's tables, and a sandboxed
reading of the SavedVariables."""
import itertools
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
sys.path.insert(0, os.path.join(ROOT, 'addon', 'tests'))
import build_scan as b  # noqa: E402
import run  # noqa: E402

_LUA = None


def lua():
    global _LUA
    if _LUA is None:
        _LUA = run.fresh()
    return _LUA


def lua_parse(kind, s):
    return lua().eval('function(k, s) return NS.CollectParse(k, s) ~= nil end')(kind, s)


def lua_merge(kind, x, y):
    return lua().eval('function(k, a, b) return NS.CollectMergeRecords(k, a, b) end')(kind, x, y)


Q = '280;0;3344;1440:5234:4011;4455;1440:1:1;280604;5001,5002;34;30;AH;2000;Sturmrufer;Titel; mit Semikolon'


def test_parse_is_as_strict_as_the_addon():
    cases = [
        ('q', Q), ('q', Q + '\n'), ('q', '280;0;00;;0;;;;0;0;;0;;T'), ('q', '280;0;-0;;0;;;;0;0;;0;;T'),
        ('q', '280;0;١;;0;;;;0;0;;0;;T'), ('q', '280;0;1;;0;;;;0;0;;0;Zwei  Leer;T'), ('q', '280;0;1;;0;;;;0;0;;0; Vorn;T'),
        ('q', '280;0;1;;0;;;;0;0;;0;;' + 'x' * 49), ('q', '280;0;1;;0;;;;0;0;;0;;' + 'x' * 48),
        ('q', '280;1;1;;0;;;;0;0;;0;;T'), ('q', '280;2;1;;0;;;;0;0;;0;;T'), ('q', '280;4095;1;;0;;;;0;0;;0;;T'),
        ('q', '280;2049;1;;0;;;;0;0;;0;;T'), ('q', '280;0;1;1440:1:1\n;0;;;;0;0;;0;;T'), ('q', '280;0;1;1440:10001:1;0;;;;0;0;;0;;T'),
        ('q', '280;0;1;;0;;5,5;;0;0;;0;;T'), ('q', '280;0;1;;0;;7,5;;0;0;;0;;T'), ('q', '280;0;1;;0;;1,2,3,4,5,6,7,8,9;;0;0;;0;;T'),
        ('q', '280;0;1;;0;;;;0;0;X;0;;T'), ('q', '280;0;1;;0;;;;0;0;;0;;Ti|tel'), ('q', '280;0;1;;0;;;;0;0;;0;;Ti\x7ftel'),
        ('q', '280;0;1;;0;;;;0;0;;0;;Titél'), ('q', '100000;0;1;;0;;;;0;0;;0;;T'), ('q', '280;0;1;;0;;;;100;0;;0;;T'),
        ('s', '280;0;;6001:1520:L:6@Orgrimmar;Grimm'), ('s', '280;0;;6001:1520:Q:;Grimm'), ('s', '280;0;;6001:1520::9@X;N'),
        ('s', '280;0;;6001:1520::6@Org;rimmar;N'), ('s', '280;0;;6001:1520::6@Org:x;N'), ('s', '280;3;1:1:1;6001:01::;N'),
        ('s', '280;7;1:1:1;6001:1::;N'), ('s', '280;0;;6002:1::,6001:1::;N'),
        ('w', '280;0;r;1411:1:1;0;7001:2;Wolf'), ('w', '280;0;z;;0;;N'), ('w', '280;0;n;;0;1:100;N'), ('w', '280;0;n;;0;1:0;N'),
        ('w', '280;31;r;1411:1:1;5;7001:2;Wolf'), ('w', '280;31;r;1411:1:1;0;7001:2;Wolf'), ('w', '280;0;;;0;;'),
        ('q', '280;3344;1440:5234:4011;4455;1440:1:1;280604;;34;30;AH;2000;Sturmrufer;Titel'),   # version 1
    ]
    for kind, s in cases:
        assert (b.parse_collect_record(kind, s) is not None) == lua_parse(kind, s), (kind, s)


def records(rnd, kind):
    """Random valid records of a kind, own masks included."""
    while True:
        if kind == 'q':
            r = {'giver': rnd.choice([0, 5, 7, -9]), 'gpos': rnd.choice(['', '1440:1:1', '1440:2:2', '1411']),
                 'ender': rnd.choice([0, 6, 8]), 'epos': rnd.choice(['', '1440:3:3']),
                 'rewards': sorted(rnd.sample(range(1, 14), rnd.randint(0, 6))), 'choices': sorted(rnd.sample(range(20, 24), rnd.randint(0, 2))),
                 'qlevel': rnd.choice([0, 20, 30]), 'minlvl': rnd.choice([0, 18, 12]), 'fac': rnd.choice(['', 'A', 'H', 'AH']),
                 'pre': rnd.choice([0, 3, 4]), 'gname': rnd.choice(['', 'Geber', 'Anders']), 'title': rnd.choice(['', 'Titel', 'Ärger'])}
        elif kind == 's':
            items = {i: {'price': rnd.choice([10, 20]), 'flags': rnd.choice(['', 'L', 'x', 'Lx']), 'rep': rnd.choice(['', '5@Orgrimmar', '6@Bucht'])}
                     for i in rnd.sample(range(1, 60), rnd.randint(0, 30))}
            r = {'pos': rnd.choice(['', '1:1:1', '2']), 'items': items, 'name': rnd.choice(['', 'Grimm', 'Bork'])}
        else:
            r = {'class': rnd.choice(['', 'n', 'r', 'R']), 'pos': rnd.choice(['', '1:1:1']), 'inst': rnd.choice([0, 36]),
                 'items': {i: rnd.randint(1, 99) for i in rnd.sample(range(1, 30), rnd.randint(0, 12))}, 'name': rnd.choice(['', 'Wolf', 'Eber'])}
        r['day'] = rnd.randint(270, 280)
        fields = b.COLLECT_FIELDS[kind]
        r['own'] = sum(1 << i for i, f in enumerate(fields) if b._empty(r[f]) is False and rnd.random() < 0.5)
        yield b.format_collect_record(kind, r)


def test_merge_is_the_addons_merge():
    rnd = random.Random(26)
    for kind in ('q', 's', 'w'):
        gen = records(rnd, kind)
        for _ in range(150):
            x, y = next(gen), next(gen)
            assert lua_parse(kind, x) and lua_parse(kind, y), (x, y)
            assert b.merge_collect(kind, x, y) == lua_merge(kind, x, y), (kind, x, y)


def sv(me, q):
    return {'drops': {'me': me}, 'collect': {'ver': 2, 'q': q}}


def test_the_build_trusts_own_values_and_heard_ones_two_accounts_agree_on():
    own = '280;' + str(1 << 11) + ';0;;0;;;;0;0;;0;;Echt'                 # the title, own
    heard_a = '280;0;5;;6;;40;;0;0;;0;;Gift'                               # giver 5, ender 6, reward 40, title
    heard_b = '279;0;5;;7;;40,41;;0;0;;0;;Anders'                          # giver 5 again, another ender
    files = [sv('a0000001', {7: own}), sv('b0000002', {7: heard_a}), sv('c0000003', {7: heard_b}),
             sv('c0000003', {7: heard_b})]   # the last: a copy of the third account's file, not a source of its own
    results = [b.collect_observed(list(order)) for order in itertools.permutations(files)]
    assert all(r == results[0] for r in results), 'the same in any file order'
    q = results[0]['q'][7]
    assert q['title'] == 'Echt', 'own wins'
    assert q['giver'] == 5, 'two accounts heard the same giver'
    assert q['ender'] == 0, 'the heard enders disagree (6 at one account, 7 at the other)'
    assert q['rewards'] == [40], 'reward 40 heard at two accounts, 41 at one'
    # one file alone: only its own values
    one = b.collect_observed([sv('b0000002', {7: heard_a})])
    assert 7 not in one['q'], 'heard data of one account alone is not used'
    q1 = b.collect_observed([sv('a0000001', {7: own})])['q'][7]
    assert q1['title'] == 'Echt' and q1['giver'] == 0


def test_the_build_drops_items_the_client_lacks(tmp_path):
    (tmp_path / 'ItemSparse.1.60.1.70235.csv').write_text('ID,Display_lang,InventoryType\n40,A,5\n41,B,0\n42,C,0\n', encoding='utf-8')
    (tmp_path / 'Item.1.60.1.70235.csv').write_text('ID,ClassID,SubclassID,InventoryType\n40,4,1,5\n41,7,0,0\n42,9,2,0\n', encoding='utf-8')
    ok = b.observed_item_filter(str(tmp_path))
    assert [i for i in (40, 41, 42, 99) if ok(i)] == [40, 42], 'wearable or a recipe, and in the client'
    own = '280;' + str(16 + 2048) + ';0;;0;;40,41,42,99;;0;0;;0;;Echt'
    q = b.collect_observed([sv('a0000001', {7: own})], item_ok=ok)['q'][7]
    assert q['rewards'] == [40, 42]
    assert b.observed_item_filter(str(tmp_path / 'none')) is None, 'without the tables no filter'


def test_load_sv_runs_in_a_sandbox(tmp_path):
    p = tmp_path / 'Amisia.lua'
    p.write_text('AmisiaDB = { ["collect"] = { ["ver"] = 2 }, x = 1 }\n'
                 'AmisiaDB.home = os and os.getenv and os.getenv("HOME") or "none"\n'
                 'AmisiaDB.io = io and "io" or "none"\n'
                 'AmisiaDB.py = python and "python" or "none"\n'
                 'AmisiaDB.ld = (load or loadstring) and "load" or "none"\n', encoding='utf-8')
    db = b.load_sv(str(p))
    assert db['x'] == 1 and db['home'] == 'none' and db['io'] == 'none' and db['py'] == 'none' and db['ld'] == 'none'
    bad = tmp_path / 'bad.lua'
    bad.write_text('AmisiaDB = {}\nwhile true do end\n', encoding='utf-8')
    try:
        b.load_sv(str(bad))
        raise AssertionError('an endless file must not hang the build')
    except SystemExit as e:
        assert 'bad.lua' in str(e)
    rep = tmp_path / 'rep.lua'
    rep.write_text('AmisiaDB = { s = ("x"):rep(10) }\n', encoding='utf-8')
    try:
        db = b.load_sv(str(rep))
        assert db.get('s') is None
    except SystemExit:
        pass
