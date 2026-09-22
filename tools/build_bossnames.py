"""Builds data/bossnames.js: the boss name as a localized client shows it -> the name the loot
tables use.

The Amisia addon writes into its export the source name its own client gave it, so a German
client records "Illidan Sturmgrimm" while the loot tables know "Illidan Stormrage". Without a
translation the site cannot tell which boss an item came from and falls back to the first source
of the item.

The pairs come from the locale files of the loot addon whose data the tables were built from:
they hold AL["<english>"] = "<localized>" for every boss name, in ten languages. Those files
carry their translations only once the addon is packaged, so they are read from the installed
copy, not from the source repository.

    python tools/build_bossnames.py [<locale folder>...]

Without an argument the installed copy under the WoW folder is used; AMISIA_WOW_ROOT overrides
where that is. Every game version of data/*.js is served, and what stays untranslated is listed
at the end.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DATA = os.path.join(ROOT, 'data')
OUT = os.path.join(DATA, 'bossnames.js')

WOW_ROOT = os.environ.get('AMISIA_WOW_ROOT', r'C:\Program Files (x86)\World of Warcraft')
FLAVORS = ('_anniversary_', '_classic_beta_', '_classic_era_', '_retail_')
# Every folder of the loot addon that carries boss names for a game the ledger knows.
MODULES = ('AtlasLootClassic_DungeonsAndRaids', 'AtlasLootClassic_MoP_DungeonsAndRaids')
GAMES = ('classic', 'tbc', 'sod', 'mop')

AL_LINE = re.compile(r'^AL\["(.*?)"\]\s*=\s*"(.*?)"', re.M)


def locale_dirs(argv):
    if argv:
        return list(argv)
    out = []
    for flavor in FLAVORS:
        for mod in MODULES:
            d = os.path.join(WOW_ROOT, flavor, 'Interface', 'AddOns', mod, 'Locales')
            if os.path.isdir(d):
                out.append(d)
    return out


def pairs(dirs):
    """english -> {localized name, ...} out of every constants.<lang>.lua below the folders."""
    out = {}
    for d in dirs:
        for name in sorted(os.listdir(d)):
            if not (name.startswith('constants.') and name.endswith('.lua')):
                continue
            with open(os.path.join(d, name), encoding='utf-8') as fh:
                for en, loc in AL_LINE.findall(fh.read()):
                    if loc and loc != en:
                        out.setdefault(en, set()).add(loc)
    return out


def bosses(game):
    path = os.path.join(DATA, game + '.js')
    if not os.path.exists(path):
        return None
    with open(path, encoding='utf-8') as fh:
        s = fh.read()
    body = s[s.index('={') + 1:].rstrip().rstrip(';')
    return [b['name'] for b in json.loads(body)['bosses']]


def main(argv):
    dirs = locale_dirs(argv)
    if not dirs:
        print('No locale folder found. Install the loot addon, or pass the folders as arguments.')
        return 1
    print('Reading ' + str(len(dirs)) + ' locale folder(s):')
    for d in dirs:
        print('  ' + d)
    table = pairs(dirs)

    games, clashes, misses = {}, [], {}
    for game in GAMES:
        names = bosses(game)
        if names is None:
            continue
        m = {}
        for en in names:
            for loc in sorted(table.get(en, ())):
                if loc in m and m[loc] != en:
                    clashes.append((game, loc, m[loc], en))
                    continue
                m[loc] = en
        games[game] = dict(sorted(m.items()))
        # Trash and the made-up entries of the tables never come out of a loot window by that name.
        misses[game] = [n for n in names if n not in table and not n.startswith(('Trash (', 'Opera: '))]

    lines = ['// Built by tools/build_bossnames.py: the boss name a localized client shows -> the name the loot tables use.',
             'window.__BOSSNAMES=window.__BOSSNAMES||{};']
    for game, m in games.items():
        lines.append('window.__BOSSNAMES["' + game + '"]=' + json.dumps(m, ensure_ascii=False, separators=(',', ':')) + ';')
    with open(OUT, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write('\n'.join(lines) + '\n')

    print('\nWrote ' + os.path.relpath(OUT, ROOT) + ' (' + str(os.path.getsize(OUT)) + ' bytes)')
    for game, m in games.items():
        total = len(bosses(game))
        print('  %-8s %4d names for %d of %d bosses' % (game, len(m), total - len(misses[game]), total))
    for game, left in misses.items():
        if left:
            print('\n' + game + ': no translation for ' + str(len(left)) + ' boss(es); an export naming one of them keeps its own name:')
            for n in left:
                print('  ' + n)
    for game, loc, a, b in clashes:
        print('\n' + game + ': "' + loc + '" would mean both ' + a + ' and ' + b + ', kept ' + a)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
