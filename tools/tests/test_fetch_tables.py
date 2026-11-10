"""tools/fetch_tables.py without the network (D-101): only the two allowed routes of wago.tools, error
answers never saved, a table that is there never asked for again, the manifest, the newest build from a
canned /api/builds answer, one request at a time with the pause."""
import json
import os
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import fetch_tables as ft  # noqa: E402

V = '1.60.1.70888'
LATEST = (b'{"product":"wowf","version":"1.60.1.70888","created_at":"2026-11-10 15:10:07",'
          b'"build_config":"0597e74b01a3f779d849ffe9b3270196"}')


class Fake:
    """Stands in for the network: answers by URL, records every URL asked for."""

    def __init__(self, answers):
        self.answers, self.asked = answers, []

    def __call__(self, url):
        ft.check_url(url)
        self.asked.append(url)
        return self.answers.get(url, (404, 'application/json', b'{"errors":"Table not found."}'))


def client(answers, slept=None):
    fake = Fake(answers)
    clock = iter(range(0, 10000, 1)).__next__
    c = ft.Client(get=fake, sleep=(slept.append if slept is not None else (lambda s: None)), clock=clock)
    return c, fake


def test_only_the_api_and_the_csv_routes_pass_the_guard():
    ok = ['https://wago.tools/api/builds', 'https://wago.tools/api/builds/wowf/latest', 'https://wago.tools/api/builds/wowf',
          'https://wago.tools/db2/Map/csv?version=1.60.1.70888', 'https://wago.tools/db2/Map/csv?version=1.60.1.70888&locale=deDE']
    for url in ok:
        assert ft.check_url(url) == url
    bad = ['https://wago.tools/db2/Map', 'https://wago.tools/db2/Map?build=1.60.1.70888',          # the table browser
           'https://wago.tools/db2/Map/csv', 'https://wago.tools/db2/Map/csv?version=latest',     # no exact build
           'https://wago.tools/db2/Map/csv?version=1.60.1.70888&page=2', 'https://wago.tools/db2/Map/csv?version=1&version=2',
           'https://wago.tools/db2/Map/csv?version=1.60.1.70888&locale=frFR',
           'https://wago.tools/diff?build=1', 'https://wago.tools/', 'https://wago.tools/files',
           'https://wago.tools/api/builds?x=1', 'http://wago.tools/api/builds', 'https://www.wago.tools/api/builds',
           'https://wago.tools.evil.example/api/builds', 'https://user@wago.tools/api/builds',
           'https://www.wowhead.com/item=19019', 'https://foreverchanges.pro/']
    for url in bad:
        with pytest.raises(ft.Refused):
            ft.check_url(url)
    with pytest.raises(ft.Refused):
        ft.csv_url('../Map', V)
    assert ft.csv_url('Map', V) == 'https://wago.tools/db2/Map/csv?version=1.60.1.70888'
    assert ft.csv_url('Map', V, 'deDE').endswith('&locale=deDE')


def test_the_client_refuses_before_it_asks():
    c, fake = client({})
    with pytest.raises(ft.Refused):
        c('https://wago.tools/db2/Map?build=1')
    assert fake.asked == [] and c.requests == 0


def test_error_answers_are_no_tables():
    assert ft.error_of(200, 'text/csv', b'ID,Name_lang\n1,"a"\n') is None
    assert ft.error_of(200, 'text/csv', b'\xef\xbb\xbfID,Name\n') is None
    assert 'not found' in ft.error_of(404, 'application/json', b'{"errors":"Table not found."}').lower()
    assert 'not found' in ft.error_of(200, 'application/json', b'{"errors":"Table not found."}').lower()
    assert ft.error_of(200, 'text/html', b'<!doctype html><html>') == 'HTML page instead of CSV'
    assert ft.error_of(200, 'text/csv', b'  <html>') == 'HTML page instead of CSV'
    assert ft.error_of(200, 'text/csv', b'') == 'empty answer'
    assert ft.error_of(429, 'text/plain', b'slow down').startswith('status 429')
    assert ft.error_of(0, '', b'timed out').startswith('status 0')


def test_tables_are_saved_errors_not_and_nothing_is_asked_twice(tmp_path):
    out = str(tmp_path)
    url = ft.csv_url
    answers = {url('Map', V): (200, 'text/csv', b'ID,Directory\n2970,2970\n3001,"a\nb"\n'),
               url('Item', V): (200, 'text/html', b'<html>busy</html>'),
               url('Spell', V): (200, 'text/csv', b''),
               url('Gone', V): (400, 'application/json', b'{"errors":"Table not found."}')}
    c, fake = client(answers)
    man = ft.fetch(['Map', 'Item', 'Spell', 'Gone', 'JournalInstance'], V, out, c, today='2026-11-10', log=lambda *_: None)
    assert sorted(os.listdir(out)) == ['Map.1.60.1.70888.csv', '_fetch.wowf.1.60.1.70888.json']
    assert man['tables'] == {'Map': {'rows': 2, 'bytes': 34, 'file': 'Map.1.60.1.70888.csv', 'got': '2026-11-10'}}
    assert set(man['errors']) == {'Item', 'Spell'} and 'Gone' in man['missing']
    assert 'JournalInstance' in man['missing'], 'known missing: not asked'
    assert len(fake.asked) == 4 and not any('JournalInstance' in u for u in fake.asked)
    with open(os.path.join(out, '_fetch.wowf.1.60.1.70888.json'), encoding='utf-8') as fh:
        saved = json.load(fh)
    assert saved['product'] == 'wowf' and saved['version'] == V and saved['date'] == '2026-11-10'
    assert saved['locale'] == 'enUS' and saved['tables']['Map']['rows'] == 2 and '_counts' not in saved
    # again: Map is there, Gone is known missing; only the two that failed are asked for
    c2, fake2 = client(answers)
    man = ft.fetch(['Map', 'Item', 'Spell', 'Gone'], V, out, c2, today='2026-11-11', log=lambda *_: None)
    assert sorted(fake2.asked) == sorted([url('Item', V), url('Spell', V)])
    assert man['tables']['Map']['got'] == '2026-11-10', 'kept, not downloaded again'
    # --retry-missing asks for a missing table once more
    c3, fake3 = client(answers)
    ft.fetch(['Gone'], V, out, c3, retry_missing=True, log=lambda *_: None)
    assert fake3.asked == [url('Gone', V)]


def test_a_saved_error_body_is_asked_for_again(tmp_path):
    out = str(tmp_path)
    with open(os.path.join(out, f'Map.{V}.csv'), 'w', encoding='utf-8') as fh:
        fh.write('{"errors":"Table not found."}')
    c, fake = client({ft.csv_url('Map', V): (200, 'text/csv', b'ID\n1\n')})
    man = ft.fetch(['Map'], V, out, c, log=lambda *_: None)
    assert len(fake.asked) == 1 and man['tables']['Map']['rows'] == 1
    with open(os.path.join(out, f'Map.{V}.csv'), encoding='utf-8') as fh:
        assert fh.read() == 'ID\n1\n'


def test_a_hand_fetched_file_counts_as_there(tmp_path):
    out = str(tmp_path)
    with open(os.path.join(out, f'DungeonEncounter.{V}.csv'), 'w', encoding='utf-8') as fh:
        fh.write('Name_lang,ID,MapID\n"Zul\'Alai",3474,2970\n')
    c, fake = client({})
    man = ft.fetch(['DungeonEncounter'], V, out, c, log=lambda *_: None)
    assert fake.asked == [] and man['tables']['DungeonEncounter']['rows'] == 1
    assert man['tables']['DungeonEncounter']['got'] == 'before'


def test_the_newest_build_comes_from_the_api():
    c, fake = client({ft.latest_url(): (200, 'application/json', LATEST)})
    assert ft.latest_version(c) == V
    assert fake.asked == ['https://wago.tools/api/builds/wowf/latest']
    # a list of builds: the highest version
    many = json.dumps([{'product': 'wowf', 'version': '1.60.1.9999'}, {'product': 'wowf', 'version': V}]).encode()
    c, _ = client({ft.latest_url(): (200, 'application/json', many)})
    assert ft.latest_version(c) == V
    for body in (b'<html>', b'{"version":"latest"}', b'{"product":"wow","version":"11.0.0.1"}'):
        c, _ = client({ft.latest_url(): (200, 'application/json', body)})
        with pytest.raises(SystemExit):
            ft.latest_version(c)
    with pytest.raises(SystemExit):
        ft.fetch(['Map'], 'latest', '/nonexistent', client({})[0])


def test_one_request_at_a_time_with_the_pause(tmp_path):
    slept = []
    answers = {ft.csv_url(t, V): (200, 'text/csv', b'ID\n1\n') for t in ('A', 'B', 'C')}
    c, fake = client(answers, slept)
    man = ft.fetch(['A', 'B', 'C'], V, str(tmp_path), c, log=lambda *_: None)
    assert c.requests == 3 and man['_counts'] == {'got': 3, 'kept': 0, 'requests': 3}
    assert len(slept) == 2 and all(0 < s <= ft.PAUSE for s in slept), 'a pause before every request but the first'
    assert ft.PAUSE >= 2 and ft.TIMEOUT > 0
    assert 'Amisia' in ft.USER_AGENT and 'fetch_tables' in ft.USER_AGENT
    assert any('requests to wago.tools' in line for line in ft.summary(man))


def test_it_asks_for_every_table_the_builders_read():
    import client_tables
    assert ft.OUT == client_tables.FETCHED
    assert 'DungeonEncounter' in client_tables.TABLES and 'ItemSparse' in client_tables.TABLES


def test_latest_only_prints_the_newest_build(monkeypatch, capsys):
    """--latest (tools/auto_data.py's daily look, D-103): one request to the API route, the build on stdout;
    an answer that is no build ends with an error and prints no build."""
    real, asked = ft.Client, []

    def answering(status, ctype, body):
        def get(url):
            asked.append(url)
            return status, ctype, body
        return lambda: real(get=get, sleep=lambda s: None)
    monkeypatch.setattr(ft, 'Client', answering(200, 'application/json', LATEST))
    assert ft.main(['--latest']) == 0
    assert capsys.readouterr().out.strip() == V and asked == ['https://wago.tools/api/builds/wowf/latest']
    monkeypatch.setattr(ft, 'Client', answering(200, 'text/html', b'<html>'))
    with pytest.raises(SystemExit):
        ft.main(['--latest'])
    assert capsys.readouterr().out == ''
