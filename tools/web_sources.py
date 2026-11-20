"""Item sources from fan sites, for the items no other source of tools/build_gear.py explains (D-157, step 2).

    python3 tools/web_sources.py [--site foreverchanges] [--limit N] [--items ID ...] [--refresh]
    python3 tools/build.py web [--site foreverchanges] [--limit N]
    python3 tools/web_sources.py --parse            only parses the cached pages again (no request)

The only script that talks to foreverchanges.pro (and the only one that names metaforge.app). Rules it keeps,
read from the sites on 2026-11-20:
  - robots.txt: foreverchanges.pro allows everything but /admin, /api/, /search and /spell/. This script asks for
    nothing but the item sitemap (/item/sitemap.xml) and item pages (/item/<id>/<slug>) the sitemap lists; check_url
    refuses every other URL, another host, a query, and every path robots.txt disallows.
  - Its terms ("Fair use of the site"): "Do not overload it with automated requests, ... or copy its compiled data
    wholesale to republish it as your own." So: GET only, one request at a time, PAUSE seconds apart, a timeout,
    an honest User-Agent naming this tool, only the items no other source explains (tools/build_gear.py's
    GearNoSource set), and the site named in GearData.lua's header and in Amisia/LICENSES/THIRD-PARTY.md.
  - metaforge.app: its robots.txt allows item pages, but its Terms of Service (effective 2025-11-07, section 3)
    say "You agree not to: ... Use bots, scripts, or automated tools without permission". Without that permission
    the script refuses the site (REFUSED); nothing of it is fetched.
  - A page in the cache is never fetched again (--refresh asks once more); a 404 is recorded in the manifest and
    not asked again. Status 403 or 429 (or any status but 200 and 404, or a network failure) stops the run at
    once: no retry, no other route.

Files (outside the repo): ~/addons/_cache/web/<site>/ (or $AMISIA_WEB_CACHE/<site>): the item sitemap
_item_sitemap.xml, the pages item/<id>.html, the manifest _fetch.json (per item: URL, date, status). After every
run the cached pages are parsed into ~/addons/_cache/web/<site>.json (per item: URL, fetch date, the source
entries), which tools/build_gear.py reads (load()); `build.py data` never fetches.

A source entry (parse_page) is a dict with 'kind':
  'drop'    a creature drop: 'npc' (id or None), 'name' (or None when the page does not name it), 'zone' (the
            zone or instance name the page gives, or None), 'boss' (True when the page files it as a boss or
            dungeon drop), 'rare', 'chance' (the page's text)
  'object'  a container or object: 'name', 'zone'
  'vendor'  'npc', 'name', 'zone'
  'quest'   'quest' (id), 'name', 'level' (0 unknown), 'faction' (A, H or None)
  'crafted' (the site's "Crafted"/"Created by" group; the build has its own recipe data and ignores it)
  'world'   a world drop without a named creature: 'zone' or None
"""
import argparse
import datetime
import html
import http.client
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import modules  # noqa: E402  (where each Data/* file stands, F-228)

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CACHE = os.path.expanduser(os.environ.get('AMISIA_WEB_CACHE') or '~/addons/_cache/web')
NOSRC = modules.data_file('GearNoSource.lua')
USER_AGENT = 'Amisia-build-tool/1.0 (tools/web_sources.py; GPL-3.0 WoW addon data build)'
PAUSE = 3.0      # seconds between two requests to one site
TIMEOUT = 30     # seconds for one answer

SITES = {
    'foreverchanges': {
        'host': 'foreverchanges.pro',
        'name': 'foreverchanges.pro',
        # robots.txt of 2026-11-20
        'disallow': ('/admin', '/api/', '/search', '/spell/'),
        # the only paths this script asks for
        'paths': (re.compile(r'^/item/sitemap\.xml$'), re.compile(r'^/item/\d{1,7}(?:/[a-z0-9-]{1,120})?$')),
        'sitemap': '/item/sitemap.xml',
    },
    'metaforge': {
        'host': 'metaforge.app',
        'name': 'MetaForge (metaforge.app)',
        'disallow': ('/api/wardogs/map/',),
        'paths': (re.compile(r'^/wow-forever/sitemap\.xml$'), re.compile(r'^/wow-forever/items?/[a-z0-9-]{1,160}$')),
        'sitemap': '/wow-forever/sitemap.xml',
        # https://metaforge.app/terms, read 2026-11-20
        'refused': ('its Terms of Service (effective 2025-11-07, section 3) say "You agree not to: ... Use bots, '
                    'scripts, or automated tools without permission"; ask the site for permission first'),
    },
}
ORDER = ('foreverchanges', 'metaforge')   # the order build_gear takes the sites in


class Refused(ValueError):
    """A URL this script must not ask for."""


class Blocked(RuntimeError):
    """The site answered 403, 429 or another status that ends the run."""


def log(*a):
    print(*a, file=sys.stderr)


def check_url(site, url):
    """url unchanged when it is an https URL of the site's host without query or fragment whose path is one of the
    site's own patterns and none robots.txt disallows; raises Refused otherwise (also for a refused site)."""
    cfg = SITES.get(site)
    if cfg is None:
        raise Refused(f'unknown site {site!r}')
    if cfg.get('refused'):
        raise Refused(f'{cfg["name"]} is refused: {cfg["refused"]}')
    u = urllib.parse.urlsplit(url)
    if u.scheme != 'https' or u.netloc != cfg['host'] or u.query or u.fragment or u.username or u.password:
        raise Refused(f'not an allowed {cfg["host"]} URL: {url}')
    path = u.path
    if any(path == d.rstrip('/') or path.startswith(d) for d in cfg['disallow']):
        raise Refused(f'robots.txt of {cfg["host"]} disallows {path}')
    if not any(p.match(path) for p in cfg['paths']):
        raise Refused(f'not an item page or the item sitemap of {cfg["host"]}: {url}')
    return url


def site_of(url):
    """The key of SITES whose host the URL names (None for any other host)."""
    host = urllib.parse.urlsplit(url).netloc
    return next((k for k, cfg in SITES.items() if cfg['host'] == host), None)


def http_get(url, timeout=TIMEOUT):
    """(status, body bytes) of one GET of an allowed URL; a network failure is status 0."""
    check_url(site_of(url), url)
    req = urllib.request.Request(url, method='GET', headers={'User-Agent': USER_AGENT,
                                                             'Accept': 'text/html, application/xml'})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, b''
    except (urllib.error.URLError, http.client.HTTPException, OSError) as e:
        return 0, str(e).encode('utf-8', 'replace')


class Client:
    """Asks one site, one request at a time, PAUSE seconds apart; counts the requests; raises Blocked on any
    answer but 200 and 404 (the caller stops)."""

    def __init__(self, site, get=http_get, sleep=time.sleep, pause=PAUSE, clock=time.monotonic):
        self.site, self.get, self.sleep, self.pause, self.clock = site, get, sleep, pause, clock
        self.requests, self.last = 0, None

    def __call__(self, url):
        check_url(self.site, url)
        if self.last is not None:
            wait = self.pause - (self.clock() - self.last)
            if wait > 0:
                self.sleep(wait)
        try:
            status, body = self.get(url)
        finally:
            self.requests += 1
            self.last = self.clock()
        if status not in (200, 404):
            raise Blocked(f'{url}: status {status}' + (f' ({body[:120].decode("utf-8", "replace")})' if status == 0 else ''))
        return status, body


# ---------------------------------------------------------------- the cache
def site_dir(site, base=CACHE):
    return os.path.join(base, site)


def page_path(site, iid, base=CACHE):
    return os.path.join(site_dir(site, base), 'item', f'{int(iid)}.html')


def manifest_path(site, base=CACHE):
    return os.path.join(site_dir(site, base), '_fetch.json')


def load_json(path, empty):
    try:
        with open(path, encoding='utf-8') as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return empty


def save_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + '.tmp'
    with open(tmp, 'w', encoding='utf-8') as fh:
        json.dump(data, fh, ensure_ascii=False, indent=1, sort_keys=True)
        fh.write('\n')
    os.replace(tmp, path)


def today():
    return datetime.date.today().isoformat()


def sitemap_urls(text, host):
    """{item id: the page URL} of an item sitemap (the English <loc> entries)."""
    out = {}
    for m in re.finditer(r'<loc>\s*(https://' + re.escape(host) + r'/item/(\d+)(?:/[^<\s]*)?)\s*</loc>', text):
        out.setdefault(int(m.group(2)), html.unescape(m.group(1)))
    return out


def sitemap(site, client, base=CACHE, refresh=False):
    """The site's item sitemap from the cache, fetched once when it is not there (or with refresh)."""
    cfg = SITES[site]
    path = os.path.join(site_dir(site, base), '_item_sitemap.xml')
    if refresh or not os.path.exists(path):
        status, body = client(f'https://{cfg["host"]}{cfg["sitemap"]}')
        if status != 200 or b'<urlset' not in body[:2000]:
            raise Blocked(f'{cfg["host"]}: no item sitemap (status {status})')
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'wb') as fh:
            fh.write(body)
    with open(path, encoding='utf-8', errors='replace') as fh:
        return sitemap_urls(fh.read(), cfg['host'])


def nosource_ids(path=NOSRC):
    """The item ids of Amisia_Gear/Data/GearNoSource.lua (the scanned gear no source explains)."""
    with open(path, encoding='utf-8') as fh:
        text = fh.read()
    i = text.index('I={')
    j = text.index('\n}', i)
    return sorted({int(x) for x in re.findall(r'^\[(\d+)\]=', text[i:j], re.M)})


def fetch(site, ids, base=CACHE, client=None, limit=None, refresh=False, refresh_sitemap=False):
    """Fetches the pages of ids the site's sitemap lists and the cache lacks (all of them with refresh), at most
    limit, into the cache; records every answer in the manifest. Returns (fetched, not in the sitemap, 404s).
    Raises Refused for a refused site and Blocked when the site stops the run (the manifest is saved first)."""
    cfg = SITES[site]
    if cfg.get('refused'):
        raise Refused(f'{cfg["name"]} is refused: {cfg["refused"]}')
    client = client or Client(site)
    urls = sitemap(site, client, base, refresh_sitemap)
    mpath = manifest_path(site, base)
    manifest = load_json(mpath, {})
    items = manifest.setdefault('items', {})
    todo, absent = [], []
    for iid in ids:
        if iid not in urls:
            absent.append(iid)
            continue
        have = os.path.exists(page_path(site, iid, base)) or (items.get(str(iid)) or {}).get('status') == 404
        if refresh or not have:
            todo.append(iid)
    if limit is not None:
        todo = todo[:max(0, limit)]
    got, gone = 0, 0
    try:
        for iid in todo:
            status, body = client(urls[iid])
            items[str(iid)] = {'url': urls[iid], 'fetched': today(), 'status': status}
            if status == 404:
                gone += 1
                continue
            path = page_path(site, iid, base)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, 'wb') as fh:
                fh.write(body)
            got += 1
            if got % 50 == 0:
                save_json(mpath, manifest)
                log(f'{cfg["host"]}: {got} of {len(todo)} pages')
    finally:
        manifest['host'] = cfg['host']
        manifest['requests'] = manifest.get('requests', 0) + client.requests
        save_json(mpath, manifest)
    return got, absent, gone



# ---------------------------------------------------------------- reading a page
# foreverchanges.pro renders an item's sources server-side, in two sections: "Where it comes from"
# (<section class="it-from" aria-labelledby="h-from">) and "Quests" (aria-labelledby="h-quests"), each with one
# <div class="it-from-group"> per kind: an <h3> heading and a <ul> of <li>: the name in <b> or a link, the place or
# "Level 60, Horde" in <span>, the chance or price in <em>. Headings seen 2026-11-20 on 1033 pages (fixtures in
# tools/tests/fixtures/web/): "Creature drop" (a li without a name when the site knows a drop but not the
# creature), "Dungeon drop" (the boss as a link to the dungeon page), "Sold by a vendor", "Reward of", "A reward to
# choose from", and "Starts a quest" and "Asked for by" (no source: the item starts a quest or a quest wants it).
# The guide section "How to get it" (h-guide: "What is known", "Not known yet") is prose and not read.
FROM = re.compile(r'<section class="it-from" aria-labelledby="h-(?:from|quests)">(.*?)</section>', re.S)
GROUP = re.compile(r'<div class="it-from-group"><h3>(.*?)</h3>(.*?)</div>', re.S)
LI = re.compile(r'<li[^>]*>(.*?)</li>', re.S)
COORDS = re.compile(r'\s*\(\s*-?[\d.]+\s*,\s*-?[\d.]+\s*\)\s*$')
QUEST_INFO = re.compile(r'^Level (\d+)(?:, (Alliance|Horde))?$')
# headings that name no source of the item
NO_SOURCE = ('starts a quest', 'asked for by', 'objective', 'not known', 'what is known')
# a group heading as the kind of its entries (lower case, the first match wins)
GROUP_KINDS = (
    ('vendor', ('sold by', 'vendor', 'merchant')),
    ('quest', ('quest', 'reward')),
    ('object', ('contained in', 'object', 'chest', 'gathered', 'fishing', 'container')),
    ('crafted', ('crafted', 'created by', 'recipe', 'profession')),
    ('drop', ('drop', 'dropped', 'creature', 'boss', 'rare', 'loot')),
)


def text_of(fragment):
    """The plain text of an HTML fragment: tags and React's <!-- --> markers gone, entities resolved, spaces
    squeezed."""
    s = re.sub(r'<!--.*?-->', '', fragment or '', flags=re.S)
    s = re.sub(r'<[^>]+>', '', s)
    return re.sub(r'\s+', ' ', html.unescape(s)).strip()


def group_kind(heading):
    """The kind of a group's entries; 'skip' for a heading that names no source, None for an unknown one."""
    h = (heading or '').lower()
    if any(w in h for w in NO_SOURCE):
        return 'skip'
    for kind, words in GROUP_KINDS:
        if any(w in h for w in words):
            return kind
    return None


def _first(rx, text):
    m = re.search(rx, text, re.S)
    return m.group(1) if m else None


def parse_entry(kind, heading, li):
    """One <li> of a group as a source entry (see the module's docstring), or None for a kind the build has no
    use for."""
    link = re.search(r'<a [^>]*href="/([a-z]+)/([^"#/]+)[^"]*"[^>]*>(.*?)</a>', li, re.S)
    name = text_of(_first(r'<b[^>]*>(.*?)</b>', li) or (link.group(3) if link else '')) or None
    if name and name.lower() == (heading or '').lower():
        name = None   # "Creature drop" as the entry's own text: the site does not know the creature
    place = text_of(_first(r'<span[^>]*>(.*?)</span>', li) or '')
    place = COORDS.sub('', place).strip() or None
    note = text_of(_first(r'<em[^>]*>(.*?)</em>', li) or '') or None
    ref = (link.group(1), int(link.group(2))) if link and link.group(2).isdigit() else (None, None)
    h = (heading or '').lower()
    if kind == 'vendor':
        return {'kind': 'vendor', 'npc': ref[1] if ref[0] == 'npc' else None, 'name': name, 'zone': place, 'cost': note}
    if kind == 'quest':
        info = QUEST_INFO.match(place or '')
        return {'kind': 'quest', 'quest': ref[1] if ref[0] == 'quest' else None, 'name': name,
                'level': int(info.group(1)) if info else 0,
                'faction': {'Alliance': 'A', 'Horde': 'H'}.get(info.group(2)) if info else None}
    if kind == 'object':
        return {'kind': 'object', 'name': name, 'zone': place}
    if kind == 'crafted':
        return {'kind': 'crafted', 'name': name}
    if kind == 'drop':
        return {'kind': 'drop', 'npc': ref[1] if ref[0] == 'npc' else None, 'name': name, 'zone': place,
                'boss': 'boss' in h or 'dungeon' in h, 'rare': 'rare' in h, 'chance': note}
    return None


def parse_page(text):
    """The source entries of one cached item page ([] when the page names none). A group whose heading no kind
    matches is kept as {'kind': None, 'heading': ...} so that a new kind of the site shows in the parsed file."""
    m = FROM.search(text or '')
    if not m:
        return []
    out = []
    for heading, body in GROUP.findall(m.group(1)):
        heading = text_of(heading)
        kind = group_kind(heading)
        for li in LI.findall(body):
            if kind == 'skip':
                continue
            e = parse_entry(kind, heading, li) if kind else {'kind': None, 'heading': heading, 'text': text_of(li)}
            if e is not None:
                out.append(e)
    return out


def parsed_path(site, base=CACHE):
    return os.path.join(base, f'{site}.json')


def parse_cache(site, base=CACHE):
    """Parses every cached item page of a site into <base>/<site>.json and returns it: {'site', 'host',
    'parsed' (date), 'items': {"<id>": {'url', 'fetched', 'sources': [...]}}}."""
    cfg = SITES[site]
    manifest = load_json(manifest_path(site, base), {}).get('items') or {}
    folder = os.path.join(site_dir(site, base), 'item')
    items = {}
    for f in sorted(os.listdir(folder)) if os.path.isdir(folder) else ():
        m = re.match(r'^(\d+)\.html$', f)
        if not m:
            continue
        path = os.path.join(folder, f)
        with open(path, encoding='utf-8', errors='replace') as fh:
            sources = parse_page(fh.read())
        rec = manifest.get(m.group(1)) or {}
        fetched = rec.get('fetched') or datetime.date.fromtimestamp(os.path.getmtime(path)).isoformat()
        items[m.group(1)] = {'url': rec.get('url') or f'https://{cfg["host"]}/item/{m.group(1)}', 'fetched': fetched,
                             'sources': sources}
    data = {'site': site, 'host': cfg['host'], 'name': cfg['name'], 'parsed': today(), 'items': items}
    save_json(parsed_path(site, base), data)
    return data


def load(base=CACHE, sites=ORDER):
    """{site: {item id (int): [source entries]}} of the parsed files that exist (build_gear reads only these;
    nothing is fetched), with the sites in ORDER; a site without a parsed file is left out."""
    out = {}
    for site in sites:
        data = load_json(parsed_path(site, base), None)
        if not data:
            continue
        out[site] = {int(k): v.get('sources') or [] for k, v in (data.get('items') or {}).items()}
    return out


def site_name(site):
    return SITES[site]['name']


def credit(site):
    """The site as GearData.lua's header names it (see Amisia/LICENSES/THIRD-PARTY.md)."""
    return f'item pages of {SITES[site]["name"]} (only items no other source names; see LICENSES/THIRD-PARTY.md)'

# ---------------------------------------------------------------- command line
def main(argv=None):
    ap = argparse.ArgumentParser(description='Item pages of fan sites into the cache, for the items no other source '
                                             'explains (D-157 step 2); then parses the cache.')
    ap.add_argument('--site', choices=sorted(SITES), action='append',
                    help='the site (default: every site that is not refused)')
    ap.add_argument('--limit', type=int, default=None, help='at most N new pages per site')
    ap.add_argument('--items', type=int, nargs='*', help='these item ids instead of GearNoSource.lua')
    ap.add_argument('--refresh', action='store_true', help='fetch cached pages again')
    ap.add_argument('--refresh-sitemap', action='store_true', help='fetch the item sitemap again')
    ap.add_argument('--parse', action='store_true', help='only parse the cached pages (no request)')
    ap.add_argument('--cache', default=CACHE)
    args = ap.parse_args(argv)
    sites = args.site or [s for s in ORDER if not SITES[s].get('refused')]
    ids = args.items if args.items else nosource_ids()
    rc = 0
    for site in sites:
        cfg = SITES[site]
        if not args.parse:
            if cfg.get('refused'):
                log(f'{cfg["name"]}: refused, nothing fetched: {cfg["refused"]}')
                rc = 1
                continue
            client = Client(site)
            try:
                got, absent, gone = fetch(site, ids, args.cache, client, args.limit, args.refresh, args.refresh_sitemap)
                log(f'{cfg["host"]}: {client.requests} requests, {got} pages fetched, {gone} not found (404), '
                    f'{len(absent)} of {len(ids)} items not in its sitemap')
            except Blocked as e:
                log(f'{cfg["host"]}: STOPPED after {client.requests} requests: {e}')
                rc = 2
        if not cfg.get('refused'):
            data = parse_cache(site, args.cache)
            log(f'{cfg["host"]}: {len(data["items"])} cached pages parsed, '
                f'{sum(1 for v in data["items"].values() if v["sources"])} with a source -> {parsed_path(site, args.cache)}')
    return rc


if __name__ == '__main__':
    sys.exit(main())
