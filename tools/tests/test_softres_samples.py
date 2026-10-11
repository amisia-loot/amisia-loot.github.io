"""The made-up softres.it codes the addon tests use (addon/tests/fixtures/softres_*.txt) are real codes:
Base64 of zlib-packed JSON, as softres.it writes its "Gargul" export (spec
docs/specs/2026-10-11-softres-gargul.md, A2). The stub cannot inflate zlib, so addon/tests/run.py
unpacks them with Python; these tests prove the samples themselves are valid, and that the sample
of the spec's acceptance criteria is the one the addon tests read.
"""
import base64
import glob
import json
import os
import re
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FIXTURES = os.path.join(ROOT, 'addon', 'tests', 'fixtures')
SPEC = os.path.join(ROOT, 'docs', 'specs', '2026-10-11-softres-gargul.md')


def code_of(name):
    with open(os.path.join(FIXTURES, name), encoding='ascii') as fh:
        return fh.read().strip()


def unpack(code):
    return zlib.decompress(base64.b64decode(code, validate=True)).decode('utf-8')


def test_every_sample_is_base64_of_zlib():
    paths = sorted(glob.glob(os.path.join(FIXTURES, 'softres_*.txt')))
    assert len(paths) >= 4
    for path in paths:
        code = code_of(os.path.basename(path))
        assert re.fullmatch(r'[A-Za-z0-9+/]+={0,2}', code), path
        assert unpack(code), path


def test_the_spec_sample_is_the_fixture_and_holds_what_the_spec_says():
    with open(SPEC, encoding='utf-8') as fh:
        spec = fh.read()
    code = code_of('softres_sample.txt')
    assert '`' + code + '`' in spec, 'the acceptance sample of the spec is addon/tests/fixtures/softres_sample.txt'
    data = json.loads(unpack(code))
    assert data['metadata']['id'] == 'ab12cd'
    by_name = {sr['name']: sr for sr in data['softreserves']}
    assert [i['id'] for i in by_name['Anna']['items']] == [18814, 18814]
    assert by_name['Anna']['class'] == 'Priest'
    assert by_name['Bob']['note'] == 'Tank' and by_name['Bob']['plusOnes'] == 1
    assert [i['id'] for i in by_name['Bob']['items']] == [17076]
    assert data['hardreserves'] == [{'id': 17204, 'for': 'Gilde', 'note': ''}]
    assert data['bonusrolls'] == []


def test_the_other_samples():
    messy = json.loads(unpack(code_of('softres_messy.txt')))
    assert len(messy['bonusrolls']) == 3 and len(messy['hardreserves']) == 2
    empty = json.loads(unpack(code_of('softres_empty.txt')))
    assert empty['softreserves'] == [] and empty['hardreserves'] == []
    broken = unpack(code_of('softres_notjson.txt'))
    try:
        json.loads(broken)
    except ValueError:
        pass
    else:
        raise AssertionError('softres_notjson.txt must not be JSON')
