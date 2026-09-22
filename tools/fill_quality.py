"""Fills the item quality into data/<game>.js, so the page can colour a name and an icon frame
the way the game does.

The loot tables were built without a quality for most items, and the page drew every one of them
as epic - a legendary like the Warglaive of Azzinoth looked like any other drop. The quality comes
from the Wowhead tooltip endpoint, which still answers while the pages themselves are blocked.

    python tools/fill_quality.py [tbc classic sod mop ...] [--all]

Only items without a quality are asked for, and every answer is kept in tools/item-quality.json,
so a second run costs nothing. Epic is the default of the page, so only the others are written
into the data file.
"""
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DATA = os.path.join(ROOT, 'data')
CACHE = os.path.join(HERE, 'item-quality.json')

# The tooltip endpoint serves one game world per number.
ENV = {'classic': 4, 'hardcore': 4, 'sod': 4, 'tbc': 5, 'mop': 15}
DEFAULT_Q = 4
PAUSE = 0.12


def load_cache():
    if os.path.exists(CACHE):
        with open(CACHE, encoding='utf-8') as fh:
            return json.load(fh)
    return {}


def save_cache(c):
    with open(CACHE, 'w', encoding='utf-8', newline='\n') as fh:
        json.dump(c, fh, indent=0, sort_keys=True)
        fh.write('\n')


def fetch(item, env):
    url = 'https://nether.wowhead.com/tooltip/item/%d?dataEnv=%d' % (item, env)
    req = urllib.request.Request(url, headers={'User-Agent': 'amisia-loot-ledger'})
    with urllib.request.urlopen(req, timeout=20) as r:
        d = json.loads(r.read().decode('utf-8'))
    q = d.get('quality')
    return int(q) if q is not None else None


def game_file(game):
    return os.path.join(DATA, game + '.js')


def fill(game, cache):
    path = game_file(game)
    if not os.path.exists(path):
        print(game + ': no data file, skipped')
        return 0
    env = ENV.get(game)
    if env is None:
        print(game + ': no game world for the tooltip endpoint, skipped')
        return 0
    with open(path, encoding='utf-8') as fh:
        src = fh.read()
    # the file is one assignment: keep everything up to the "=" of the table itself
    cut = src.index('={')
    head, body = src[:cut + 1], json.loads(src[cut + 1:].rstrip().rstrip(';'))

    todo = [i for i in body['items'] if i.get('q') is None]
    print('%s: %d of %d items without a quality' % (game, len(todo), len(body['items'])))
    asked, failed = 0, []
    for n, item in enumerate(todo, 1):
        key = '%d:%d' % (env, item['id'])
        if key not in cache:
            try:
                cache[key] = fetch(item['id'], env)
            except (urllib.error.URLError, ValueError, TimeoutError) as e:
                failed.append((item['id'], str(e)[:60]))
                continue
            asked += 1
            time.sleep(PAUSE)
            if asked % 100 == 0:
                save_cache(cache)
                print('  %d of %d asked' % (n, len(todo)))
        q = cache.get(key)
        if q is not None and q != DEFAULT_Q:
            item['q'] = q
    save_cache(cache)

    changed = sum(1 for i in body['items'] if i.get('q') is not None and i['q'] != DEFAULT_Q)
    with open(path, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(head + json.dumps(body, ensure_ascii=False, separators=(',', ':')) + '\n')
    print('  %d items now carry a quality other than epic' % changed)
    for item in body['items']:
        if item.get('q') == 5:
            print('    legendary: %d %s' % (item['id'], item['name']))
    if failed:
        print('  %d items could not be asked for, run again later:' % len(failed))
        for item, why in failed[:5]:
            print('    %d %s' % (item, why))
    return changed


def main(argv):
    games = [a for a in argv if not a.startswith('-')]
    if '--all' in argv or not games:
        games = [re.sub(r'\.js$', '', f) for f in sorted(os.listdir(DATA))
                 if f.endswith('.js') and not f.startswith(('craft-', 'bossnames'))]
    cache = load_cache()
    for game in games:
        fill(game, cache)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
