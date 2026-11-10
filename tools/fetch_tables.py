"""Downloads the client tables Amisia's builders read from the CSV exports of wago.tools (D-101).

    python3 tools/fetch_tables.py [--version 1.60.1.70888] [--tables T ...] [--out DIR] [--retry-missing]
    python3 tools/fetch_tables.py --latest          only prints the newest wowf build (one request)
    python3 tools/build.py tables [--version V] [--tables T ...]

The only script that talks to wago.tools, and only along the two routes the site's robots.txt and
llms.txt allow programs (read 2026-11-10): its API (/api/builds..., here /api/builds/wowf/latest for the
newest build of the Forever client) and the CSV export of a table (/db2/<Table>/csv?version=<build>,
optionally &locale=). Every URL is checked against those patterns before it is asked for (check_url);
nothing else of the site is ever requested (no table browser, no diff, no HTML page).

Rules it keeps (the site's own guidance): GET only, one request at a time with a pause of PAUSE seconds,
an honest User-Agent naming this tool, an exact build (from the API or --version) recorded with the
product, a timeout, and a download reused instead of asked for again: a file <Table>.<build>.csv that is
there and no error answer is never downloaded again, and a table the site answered "not found" for is
recorded in the manifest and not asked for again (--retry-missing asks once more). An error answer (JSON
with "errors", an HTML page, an empty body, a status other than 200) is never saved as a table; it is
reported.

Files: ~/addons/_cache/wago/<Table>.<build>.csv (the name the builders read, tools/client_tables.py) and
the manifest _fetch.<product>.<build>.json there (product, build, date, per table rows and bytes, the
tables the site does not have). The tables are those of tools/client_tables.TABLES (the lists of
tools/export_db2.ps1). The string columns come in English (enUS, the site's default and what the
builders read; no builder reads German names from the tables).
"""
import argparse
import csv
import datetime
import http.client
import io
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import client_tables  # noqa: E402

HOST = 'wago.tools'
BASE = 'https://' + HOST
PRODUCT = 'wowf'                 # the WoW Forever client on wago.tools
OUT = client_tables.FETCHED
PAUSE = 2.0                      # seconds between two requests
TIMEOUT = 180                    # seconds for one answer (ItemSparse and Spell are several MB)
USER_AGENT = 'Amisia-build-tool/1.0 (tools/fetch_tables.py of the Amisia WoW addon; one request at a time)'
LOCALES = ('enUS', 'deDE')
# Tables the site answered {"errors":"Table not found."} for, product wowf, 2026-11-10 (asked by hand):
# never asked for again unless --retry-missing.
KNOWN_MISSING = ('JournalEncounter', 'JournalEncounterCreature', 'JournalInstance')

VERSION = re.compile(r'^\d+\.\d+\.\d+\.\d+$')
NAME = re.compile(r'^[A-Za-z0-9_]+$')
API_PATH = re.compile(r'^/api/builds(?:/[a-z0-9_]+(?:/latest)?)?$')
CSV_PATH = re.compile(r'^/db2/([A-Za-z0-9_]+)/csv$')


class Refused(ValueError):
    """A URL outside the two routes the site allows programs."""


def check_url(url):
    """url unchanged when it is one of the two allowed kinds: https://wago.tools/api/builds[/<product>[/latest]]
    without a query, or https://wago.tools/db2/<Table>/csv?version=<a.b.c.d>[&locale=<enUS|deDE>]. Raises
    Refused otherwise."""
    u = urllib.parse.urlsplit(url)
    if u.scheme != 'https' or u.netloc != HOST or u.fragment or u.username or u.password:
        raise Refused(f'not an allowed wago.tools URL: {url}')
    if API_PATH.match(u.path):
        if u.query:
            raise Refused(f'the API route takes no query here: {url}')
        return url
    if CSV_PATH.match(u.path):
        q = urllib.parse.parse_qs(u.query, keep_blank_values=True, strict_parsing=False)
        if set(q) - {'version', 'locale'} or 'version' not in q or any(len(v) != 1 for v in q.values()):
            raise Refused(f'the CSV route takes version (and locale) only: {url}')
        if not VERSION.match(q['version'][0]):
            raise Refused(f'not an exact build: {url}')
        if 'locale' in q and q['locale'][0] not in LOCALES:
            raise Refused(f'unknown locale: {url}')
        return url
    raise Refused(f'not an allowed wago.tools route (only /api/builds... and /db2/<Table>/csv): {url}')


def csv_url(table, version, locale=None):
    if not NAME.match(table or ''):
        raise Refused(f'not a table name: {table!r}')
    query = {'version': version}
    if locale and locale != 'enUS':
        query['locale'] = locale
    return check_url(f'{BASE}/db2/{table}/csv?{urllib.parse.urlencode(query)}')


def latest_url(product=PRODUCT):
    if not NAME.match(product or ''):
        raise Refused(f'not a product name: {product!r}')
    return check_url(f'{BASE}/api/builds/{product}/latest')


def http_get(url, timeout=TIMEOUT):
    """(status, content type, body bytes) of one GET of an allowed URL; a network failure is status 0."""
    check_url(url)
    req = urllib.request.Request(url, method='GET', headers={'User-Agent': USER_AGENT, 'Accept': 'text/csv, application/json'})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status, resp.headers.get('Content-Type') or '', resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.headers.get('Content-Type') or '', e.read() or b''
    except (urllib.error.URLError, http.client.HTTPException, OSError) as e:
        return 0, '', str(e).encode('utf-8', 'replace')


def error_of(status, ctype, body):
    """Why an answer is no table (a short text), or None when it is one: a status other than 200, an
    empty body, JSON (the site's {"errors": ...}), an HTML page, or text without a header line."""
    head = (body or b'')[:512].lstrip()
    if status != 200:
        return f'status {status}: ' + _short(body)
    if not head:
        return 'empty answer'
    if head[:1] in (b'{', b'[') or 'json' in (ctype or '').lower():
        try:
            data = json.loads(body.decode('utf-8', 'replace'))
            if isinstance(data, dict) and data.get('errors'):
                return f'site error: {data["errors"]}'
        except ValueError:
            pass
        return 'JSON instead of CSV: ' + _short(body)
    if head[:1] == b'<' or 'html' in (ctype or '').lower():
        return 'HTML page instead of CSV'
    first = head.split(b'\n', 1)[0]
    if not re.match(rb'^\xef?\xbb?\xbf?"?[A-Za-z_][A-Za-z0-9_]*"?(,|\r|$)', first):
        return 'no CSV header line: ' + _short(body)
    return None


def _short(body, n=120):
    text = (body or b'')[:n].decode('utf-8', 'replace').replace('\n', ' ').strip()
    return text or '(empty)'


def rows_of(body):
    """The data rows of a CSV body (a quoted field may span lines)."""
    return max(0, sum(1 for _ in csv.reader(io.StringIO(body.decode('utf-8-sig', 'replace')))) - 1)


def file_name(table, version, locale=None):
    return f'{table}.{version}.csv' if not locale or locale == 'enUS' else f'{table}.{version}.{locale}.csv'


def is_table_file(path):
    """A file that is there, not empty and no saved error answer."""
    try:
        with open(path, 'rb') as fh:
            head = fh.read(512)
    except OSError:
        return False
    return error_of(200, 'text/csv', head) is None


def manifest_path(out, product, version):
    return os.path.join(out, f'_fetch.{product}.{version}.json')


def load_manifest(path):
    try:
        with open(path, encoding='utf-8') as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {}


class Client:
    """Asks the site one request at a time, PAUSE seconds apart, and counts the requests."""

    def __init__(self, get=http_get, sleep=time.sleep, pause=PAUSE, clock=time.monotonic):
        self.get, self.sleep, self.pause, self.clock = get, sleep, pause, clock
        self.requests, self.last = 0, None

    def __call__(self, url):
        check_url(url)
        if self.last is not None:
            wait = self.pause - (self.clock() - self.last)
            if wait > 0:
                self.sleep(wait)
        try:
            return self.get(url)
        finally:
            self.requests += 1
            self.last = self.clock()


def latest_version(client, product=PRODUCT):
    """The newest build of product from /api/builds/<product>/latest ({"product", "version", ...})."""
    status, ctype, body = client(latest_url(product))
    if status != 200:
        raise SystemExit(f'{latest_url(product)}: status {status}: {_short(body)}')
    try:
        data = json.loads(body.decode('utf-8'))
    except ValueError:
        raise SystemExit(f'{latest_url(product)}: no JSON: {_short(body)}')
    if isinstance(data, list):
        data = max((d for d in data if isinstance(d, dict) and VERSION.match(str(d.get('version') or ''))),
                   key=lambda d: client_tables.version_key(d['version']), default={})
    version = str((data or {}).get('version') or '')
    if (data or {}).get('product', product) != product or not VERSION.match(version):
        raise SystemExit(f'{latest_url(product)}: no build of {product} in the answer: {_short(body)}')
    return version


def fetch(tables, version, out=OUT, client=None, product=PRODUCT, locale=None, retry_missing=False,
          today=None, log=print):
    """Downloads every table of tables for build version into out and writes the manifest. Returns the
    manifest: {'product', 'version', 'locale', 'date', 'source', 'tables': {table: {'rows', 'bytes', 'file',
    'got'}}, 'missing': {table: why}, 'errors': {table: why}}."""
    if not VERSION.match(version or ''):
        raise SystemExit(f'not an exact build: {version!r}')
    client = client or Client()
    os.makedirs(out, exist_ok=True)
    mpath = manifest_path(out, product, version) if not locale or locale == 'enUS' else \
        manifest_path(out, product, f'{version}.{locale}')
    old = load_manifest(mpath)
    man = {'product': product, 'version': version, 'locale': locale or 'enUS',
           'date': today or datetime.date.today().isoformat(), 'source': BASE + '/db2/<Table>/csv',
           'tables': dict(old.get('tables') or {}), 'missing': dict(old.get('missing') or {}), 'errors': {}}
    if product == PRODUCT:
        for t in KNOWN_MISSING:
            man['missing'].setdefault(t, 'site error: Table not found. (asked by hand 2026-11-10)')
    got = kept = 0
    for table in tables:
        name = file_name(table, version, locale)
        path = os.path.join(out, name)
        if os.path.exists(path) and is_table_file(path):
            rec = man['tables'].get(table) or {}
            size = os.path.getsize(path)
            if rec.get('bytes') != size:
                rec = {'rows': client_tables.count_rows(path), 'bytes': size, 'file': name,
                       'got': rec.get('got') or 'before'}
            man['tables'][table] = rec
            man['missing'].pop(table, None)
            kept += 1
            log(f'have  {table:<28} {rec["rows"]:>7} rows {rec["bytes"]:>9} bytes')
            continue
        if table in man['missing'] and not retry_missing:
            log(f'none  {table:<28} not on the site ({man["missing"][table]}); not asked again')
            continue
        url = csv_url(table, version, locale)
        status, ctype, body = client(url)
        why = error_of(status, ctype, body)
        if why:
            if 'table not found' in why.lower():   # the site's answer for a table it has not (status 400 or 404)
                man['missing'][table] = why
                log(f'none  {table:<28} {why}')
            else:
                man['errors'][table] = why
                log(f'FAIL  {table:<28} {why}')
            continue
        tmp = path + '.part'
        with open(tmp, 'wb') as fh:
            fh.write(body)
        os.replace(tmp, path)
        rec = {'rows': rows_of(body), 'bytes': len(body), 'file': name, 'got': man['date']}
        man['tables'][table] = rec
        man['missing'].pop(table, None)
        got += 1
        log(f'got   {table:<28} {rec["rows"]:>7} rows {rec["bytes"]:>9} bytes')
    man['tables'] = {t: man['tables'][t] for t in sorted(man['tables'])}
    man['missing'] = {t: man['missing'][t] for t in sorted(man['missing'])}
    tmp = mpath + '.part'
    with open(tmp, 'w', encoding='utf-8', newline='\n') as fh:
        json.dump(man, fh, indent=1, sort_keys=True)
        fh.write('\n')
    os.replace(tmp, mpath)
    man['_counts'] = {'got': got, 'kept': kept, 'requests': client.requests}
    return man


def summary(man):
    c = man.get('_counts') or {}
    rows = sum(r.get('rows', 0) for r in man['tables'].values())
    size = sum(r.get('bytes', 0) for r in man['tables'].values())
    lines = [f'{man["product"]} {man["version"]} ({man["locale"]}): {len(man["tables"])} tables '
             f'({c.get("got", 0)} downloaded, {c.get("kept", 0)} there already), {rows} rows, {size} bytes; '
             f'{c.get("requests", 0)} requests to {HOST}']
    if man['missing']:
        lines.append('not on the site: ' + ', '.join(sorted(man['missing'])))
    if man['errors']:
        lines.append('FAILED (nothing saved, run again later): ' + ', '.join(f'{t} ({w})' for t, w in sorted(man['errors'].items())))
    return lines


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--version', default=None, help='the exact client build (default: the newest of --product)')
    ap.add_argument('--product', default=PRODUCT, help=f'the product on wago.tools (default {PRODUCT}, WoW Forever)')
    ap.add_argument('--tables', nargs='*', default=None, help='only these tables (default: tools/client_tables.TABLES)')
    ap.add_argument('--locale', default=None, choices=LOCALES, help='string columns in this language (default enUS)')
    ap.add_argument('--out', default=OUT, help=f'the folder (default {OUT})')
    ap.add_argument('--retry-missing', action='store_true', help='ask again for tables the site did not have')
    ap.add_argument('--latest', action='store_true',
                    help='only print the newest build of --product (one request) and stop; tools/auto_data.py asks so')
    args = ap.parse_args(argv)
    if args.latest:
        print(latest_version(Client(), args.product))
        return 0
    tables = args.tables or client_tables.TABLES
    if not tables:
        raise SystemExit('no tables: tools/export_db2.ps1 not readable')
    client = Client()
    version = args.version or latest_version(client, args.product)
    print(f'{args.product} {version}: {len(tables)} tables into {args.out} ({PAUSE:.0f} s between requests)')
    man = fetch(tables, version, args.out, client, args.product, args.locale, args.retry_missing)
    for line in summary(man):
        print(line)
    print('then: python3 tools/build.py data (it takes the newest copy of each table)')
    return 1 if man['errors'] else 0


if __name__ == '__main__':
    sys.exit(main())
