"""tools/web_sources.py: the polite fetcher of the fan sites' item pages and its parser (D-157, step 2).
No test touches the network: the client gets a fake GET and a fake clock."""
import json
import os
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import web_sources  # noqa: E402

FIXTURES = os.path.join(HERE, 'fixtures', 'web')
FC = 'foreverchanges'
HOST = web_sources.SITES[FC]['host']


def fixture(name):
    with open(os.path.join(FIXTURES, name), encoding='utf-8') as fh:
        return fh.read()


# ---------------------------------------------------------------- the URL check
@pytest.mark.parametrize('url', [
    f'https://{HOST}/item/18316/obsidian-bauble',
    f'https://{HOST}/item/18316',
    f'https://{HOST}/item/sitemap.xml',
])
def test_item_pages_and_the_item_sitemap_are_allowed(url):
    assert web_sources.check_url(FC, url) == url


@pytest.mark.parametrize('url', [
    f'https://{HOST}/api/items/18316',            # robots.txt: Disallow /api/
    f'https://{HOST}/search?q=bauble',            # robots.txt: Disallow /search (and a query)
    f'https://{HOST}/spell/12345/fireball',       # robots.txt: Disallow /spell/
    f'https://{HOST}/admin',                      # robots.txt: Disallow /admin
    f'https://{HOST}/quest/123/a-quest',          # allowed by robots.txt, but no item page
    f'https://{HOST}/',
    f'https://{HOST}/item/18316/obsidian-bauble?x=1',
    f'https://{HOST}/item/18316/obsidian-bauble#from',
    f'http://{HOST}/item/18316/obsidian-bauble',  # https only
    'https://www.wowhead.com/classic/item=18316',  # another host
    f'https://{HOST}.evil.example/item/18316',
    f'https://user@{HOST}/item/18316',
])
def test_every_other_url_is_refused(url):
    with pytest.raises(web_sources.Refused):
        web_sources.check_url(FC, url)


def test_a_refused_site_is_never_asked():
    """metaforge.app: robots.txt allows item pages, its terms forbid scripts without permission."""
    assert web_sources.SITES['metaforge'].get('refused')
    with pytest.raises(web_sources.Refused):
        web_sources.check_url('metaforge', 'https://metaforge.app/wow-forever/items/obsidian-bauble')
    with pytest.raises(web_sources.Refused):
        web_sources.fetch('metaforge', [18316], base='/nonexistent', client=lambda url: pytest.fail('asked'))
    with pytest.raises(web_sources.Refused):
        web_sources.http_get('https://example.com/item/1')


# ---------------------------------------------------------------- the client
class FakeNet:
    def __init__(self, answers=None):
        self.now, self.asked, self.slept = 0.0, [], []
        self.answers = answers or {}

    def get(self, url):
        self.asked.append(url)
        self.now += 0.5            # the answer takes half a second
        return self.answers.get(url, (200, b'<html>page</html>'))

    def sleep(self, s):
        self.slept.append(round(s, 3))
        self.now += s

    def clock(self):
        return self.now

    def client(self):
        return web_sources.Client(FC, get=self.get, sleep=self.sleep, clock=self.clock)


def test_the_client_pauses_between_requests_and_counts_them():
    net = FakeNet()
    c = net.client()
    for i in (1, 2, 3):
        c(f'https://{HOST}/item/{i}/x')
    assert c.requests == 3
    assert net.slept == [web_sources.PAUSE, web_sources.PAUSE], 'no pause before the first, PAUSE after each answer'
    assert web_sources.PAUSE >= 3


def test_the_client_checks_every_url_before_it_asks():
    net = FakeNet()
    with pytest.raises(web_sources.Refused):
        net.client()(f'https://{HOST}/api/x')
    assert net.asked == []


@pytest.mark.parametrize('status', [403, 429, 500, 0])
def test_403_429_and_any_other_failure_stop_the_run(tmp_path, status):
    sitemap = (f'<urlset><url><loc>https://{HOST}/item/1/a</loc></url><url><loc>https://{HOST}/item/2/b</loc></url>'
               '</urlset>')
    os.makedirs(tmp_path / FC)
    (tmp_path / FC / '_item_sitemap.xml').write_text(sitemap, encoding='utf-8')
    net = FakeNet({f'https://{HOST}/item/1/a': (status, b'')})
    with pytest.raises(web_sources.Blocked):
        web_sources.fetch(FC, [1, 2], base=str(tmp_path), client=net.client())
    assert net.asked == [f'https://{HOST}/item/1/a'], 'nothing after the stop, no retry'
    manifest = json.loads((tmp_path / FC / '_fetch.json').read_text(encoding='utf-8'))
    assert manifest['requests'] == 1


def test_only_listed_items_are_fetched_and_a_cached_page_never_again(tmp_path):
    sitemap = ''.join(f'<url><loc>https://{HOST}/item/{i}/item-{i}</loc></url>' for i in (1, 2, 3))
    net = FakeNet({f'https://{HOST}/item/sitemap.xml': (200, f'<?xml version="1.0"?><urlset>{sitemap}</urlset>'.encode()),
                   f'https://{HOST}/item/3/item-3': (404, b'')})
    base = str(tmp_path)
    got, absent, gone = web_sources.fetch(FC, [1, 2, 3, 99], base=base, client=net.client())
    assert (got, absent, gone) == (2, [99], 1), 'an item the sitemap does not list is never guessed'
    assert net.asked == [f'https://{HOST}/item/sitemap.xml', f'https://{HOST}/item/1/item-1',
                         f'https://{HOST}/item/2/item-2', f'https://{HOST}/item/3/item-3']
    # a second run asks nothing: the pages and the sitemap are cached, the 404 recorded
    net2 = FakeNet()
    assert web_sources.fetch(FC, [1, 2, 3, 99], base=base, client=net2.client()) == (0, [99], 0)
    assert net2.asked == []
    # --limit
    net3 = FakeNet()
    web_sources.fetch(FC, [1, 2], base=base, client=net3.client(), refresh=True, limit=1)
    assert net3.asked == [f'https://{HOST}/item/1/item-1'], 'refresh asks again, limit caps it'
    manifest = json.loads((tmp_path / FC / '_fetch.json').read_text(encoding='utf-8'))
    assert manifest['items']['3']['status'] == 404 and manifest['items']['1']['url'].endswith('/item/1/item-1')
    assert manifest['requests'] == 5


def test_the_user_agent_is_honest():
    assert web_sources.USER_AGENT.startswith('Amisia-build-tool/') and 'web_sources.py' in web_sources.USER_AGENT
    assert 'Mozilla' not in web_sources.USER_AGENT


# ---------------------------------------------------------------- the parser (pages of 2026-11-20, trimmed)
def test_a_page_without_sources_gives_none():
    assert web_sources.parse_page(fixture('fc_no_source.html')) == []


def test_an_unnamed_creature_drop():
    assert web_sources.parse_page(fixture('fc_18316_creature_drop.html')) == [
        {'kind': 'drop', 'npc': None, 'name': None, 'zone': None, 'boss': False, 'rare': False,
         'chance': '1 in 7 kills'}]


def test_a_vendor_with_zone_and_price():
    assert web_sources.parse_page(fixture('fc_271934_vendor.html')) == [
        {'kind': 'vendor', 'npc': None, 'name': 'Bryanna Embreeze', 'zone': 'The Barrens', 'cost': '3g 23s'}]


def test_quest_rewards_with_level_and_faction():
    assert web_sources.parse_page(fixture('fc_18403_quest_rewards.html')) == [
        {'kind': 'quest', 'quest': 7491, 'name': 'For All To See', 'level': 60, 'faction': 'H'},
        {'kind': 'quest', 'quest': 7496, 'name': 'Celebrating Good Times', 'level': 60, 'faction': 'A'}]


def test_a_dungeon_drop_names_its_boss_and_an_unnamed_drop_its_dungeon():
    assert web_sources.parse_page(fixture('fc_274430_dungeon_drop.html')) == [
        {'kind': 'drop', 'npc': None, 'name': 'Obsidian Sentinel', 'zone': 'Uldaman', 'boss': True, 'rare': False,
         'chance': None},
        {'kind': 'drop', 'npc': None, 'name': None, 'zone': 'Uldaman', 'boss': False, 'rare': False, 'chance': '33%'}]


def test_a_quest_the_item_starts_or_a_quest_wants_is_no_source():
    assert web_sources.parse_page(fixture('fc_18706_starts_a_quest.html')) == []


def test_the_guide_prose_is_not_read():
    assert web_sources.parse_page(fixture('fc_284716_guide_only.html')) == []


def test_an_unknown_group_is_kept_with_its_heading():
    page = ('<section class="it-from" aria-labelledby="h-from"><h2 id="h-from">Where it comes from</h2>'
            '<div class="it-from-group"><h3>Fished up</h3><ul><li><b>Pool</b></li></ul></div></section>')
    assert web_sources.parse_page(page) == [{'kind': None, 'heading': 'Fished up', 'text': 'Pool'}]


def test_parse_cache_and_load(tmp_path):
    folder = tmp_path / FC / 'item'
    folder.mkdir(parents=True)
    (folder / '271934.html').write_text(fixture('fc_271934_vendor.html'), encoding='utf-8')
    (folder / '12104.html').write_text(fixture('fc_no_source.html'), encoding='utf-8')
    data = web_sources.parse_cache(FC, str(tmp_path))
    assert data['items']['271934']['sources'][0]['name'] == 'Bryanna Embreeze'
    assert data['items']['271934']['url'] == f'https://{HOST}/item/271934' and data['items']['271934']['fetched']
    loaded = web_sources.load(str(tmp_path))
    assert list(loaded) == [FC] and loaded[FC][12104] == [] and loaded[FC][271934][0]['kind'] == 'vendor'
