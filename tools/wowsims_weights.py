"""The stat weights of the WoWSims simulation for WoW Forever, as templates for the own weights (F-230, D-161).

Source: https://github.com/wowsims/forever (branch master), MIT licence; Amisia names it in
Amisia/LICENSES/THIRD-PARTY.md and ships its licence text as Amisia/LICENSES/WoWSims-MIT.txt.

refresh() (`python3 tools/build.py wowsims`) downloads through the GitHub API, one request after the other, only
the files ui/specs/<class>/<spec>/presets.ts, the weights a class shares (ui/specs/<class>/*_ep.ts) and
the repository's LICENSE into ~/addons/_cache/wowsims (or
$AMISIA_WOWSIMS_CACHE), outside the repo. `build.py data` never downloads: load() reads the cache, and a missing
cache means no templates (a printed note).

The files are TypeScript. Nothing of them runs: parse_presets() reads the calls
`PresetUtils.makePresetEpWeights('<name>', Stats.fromMap({ [Stat.StatX]: 1.0, ... }))` as text, keeps the name and
every `[Stat.<name>]: <number>` / `[PseudoStat.<name>]: <number>` pair, and maps the stat names to Amisia's keys
(STAT_KEY). WoWSims' weights are per point of a stat, the same unit Amisia's own weights (AmisiaDB.weights) use;
in Forever one rating point counts for weapons and spells alike, so the simulation's hit, crit and haste go to
Amisia's one key each. Which spec of the simulation is which of Amisia's stands by hand in SPECS.
"""
import json
import os
import re
import sys
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
WOWSIMS_CACHE = os.path.expanduser(os.environ.get('AMISIA_WOWSIMS_CACHE') or '~/addons/_cache/wowsims')
WOWSIMS_REPO = 'wowsims/forever'
WOWSIMS_LICENSE = 'MIT'
WOWSIMS_SOURCE = f'WoWSims for WoW Forever (github.com/{WOWSIMS_REPO}, {WOWSIMS_LICENSE}; see LICENSES/THIRD-PARTY.md)'
USER_AGENT = 'Amisia-build-tool/1.0 (tools/wowsims_weights.py; +https://amisia-loot.github.io)'
KEEP_FILES = ('LICENSE',)
PAUSE = 1.0   # seconds between two requests
PRESETS = re.compile(r'^ui/specs/[a-z_]+/[a-z_]+/presets\.ts$')
# a class's shared weights that its specs' presets import (druid/feral_ep.ts: the bear's and the cat's)
SHARED_EP = re.compile(r'^ui/specs/[a-z_]+/[a-z_]+_ep\.ts$')


def log(*a):
    print(*a, file=sys.stderr)


def kept(path):
    """Whether refresh() downloads a file of the repository."""
    return path in KEEP_FILES or bool(PRESETS.match(path)) or bool(SHARED_EP.match(path))


def _token():
    import att_data
    return att_data._token()


def refresh(dest=WOWSIMS_CACHE, ref='master'):
    """Downloads the files kept() names through the GitHub API into dest, one request at a time; files of an
    older download that the repository no longer has are removed. Returns the commit."""
    token = _token()

    def get(url, raw=False):
        headers = {'User-Agent': USER_AGENT}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        if raw:
            headers['Accept'] = 'application/vnd.github.raw'
        time.sleep(PAUSE)
        with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=120) as r:
            return r.read()

    api = f'https://api.github.com/repos/{WOWSIMS_REPO}'
    commit = json.loads(get(f'{api}/commits/{ref}'))['sha']
    tree = json.loads(get(f'{api}/' + f'git/commits/{commit}'))['tree']['sha']
    listing = json.loads(get(f'{api}/' + f'git/trees/{tree}?recursive=1'))
    if listing.get('truncated'):
        raise SystemExit('the repository listing is truncated')
    wanted = {t['path']: t['sha'] for t in listing['tree'] if t['type'] == 'blob' and kept(t['path'])}
    if not any(PRESETS.match(p) for p in wanted):
        raise SystemExit(f'{WOWSIMS_REPO}@{commit[:10]} has no ui/specs/*/*/presets.ts')
    for path, blob in sorted(wanted.items()):
        out = os.path.join(dest, path)
        os.makedirs(os.path.dirname(out) or dest, exist_ok=True)
        with open(out, 'wb') as fh:
            fh.write(get(f'{api}/' + f'git/blobs/{blob}', raw=True))
    removed = 0
    for d, _dirs, files in os.walk(dest):
        for f in files:
            rel = os.path.relpath(os.path.join(d, f), dest).replace(os.sep, '/')
            if rel != 'COMMIT' and rel not in wanted:
                os.remove(os.path.join(d, f))
                removed += 1
    with open(os.path.join(dest, 'COMMIT'), 'w', encoding='utf-8') as fh:
        fh.write(commit + '\n')
    log(f'WoWSims {commit[:10]}: {len(wanted)} files -> {dest}' + (f' ({removed} old files removed)' if removed else ''))
    return commit


def commit_of(base):
    p = os.path.join(base, 'COMMIT')
    if os.path.exists(p):
        with open(p, encoding='utf-8') as fh:
            return fh.read().strip() or None
    return None


# ---------------------------------------------------------------- reading
# WoWSims' stat names (proto/common.proto: Stat, PseudoStat) -> Amisia's keys of an own weight set (per point).
STAT_KEY = {
    'StatStrength': 'STR', 'StatAgility': 'AGI', 'StatStamina': 'STA', 'StatIntellect': 'INT', 'StatSpirit': 'SPI',
    'StatSpellDamage': 'SP', 'StatHealingPower': 'HEAL', 'StatArcaneDamage': 'SP_ARCANE', 'StatFireDamage': 'SP_FIRE',
    'StatFrostDamage': 'SP_FROST', 'StatHolyDamage': 'SP_HOLY', 'StatNatureDamage': 'SP_NATURE',
    'StatShadowDamage': 'SP_SHADOW', 'StatMP5': 'MP5', 'StatHitRating': 'HIT', 'StatCritRating': 'CRIT',
    'StatHasteRating': 'HASTE', 'StatExpertiseRating': 'EXP', 'StatDefenseRating': 'DEF', 'StatBlockRating': 'BLOCK',
    'StatBlockValue': 'BLOCKVAL', 'StatDodgeRating': 'DODGE', 'StatParryRating': 'PARRY', 'StatArmor': 'ARMOR',
    'StatAttackPower': 'AP', 'StatRangedAttackPower': 'RAP', 'StatSpellPiercing': 'SPEN',
    'StatResilienceRating': 'RES',
    'PseudoStatMainHandDps': 'DPS', 'PseudoStatRangedDps': 'RDPS',
}
# known names Amisia has no key of its own for (no log line for them): a druid's feral attack power counts with the
# attack power's weight (Gear.lua terms), bonus armour is armour, the rest Amisia does not score
SKIPPED = {'StatFeralAttackPower', 'StatBonusArmor', 'StatArmorNoMods', 'StatArmorPenetration', 'StatPhysicalDamage',
           'StatHealth', 'StatMana', 'PseudoStatOffHandDps', 'PseudoStatFeralCombatSkill'}

# The simulation's specs (folder under ui/specs) -> Amisia's class, spec key (None: no one spec of Amisia's) and
# per preset name the German name the addon shows (its English one in Locales/enUS_gear.lua). A preset not named
# here is left out with a log line.
SPECS = {
    'priest/dps': ('PRIEST', None, {'Shadow': ('Schatten', 'shadow'), 'Smite': ('Schmettern', None)}),
    'priest/healer': ('PRIEST', None, {'Disc Single-Target': ('Disziplin Einzelziel', None),
                                       'Disc Raid Healing': ('Disziplin Raid', None),
                                       'Holy Single-Target': ('Heilig Einzelziel', 'holy'),
                                       'Holy Raid Healing': ('Heilig Raid', 'holy')}),
    'druid/balance': ('DRUID', 'balance', {'P1': ('Gleichgewicht P1', None), 'Pre-BiS': ('Gleichgewicht Pre-BiS', None)}),
    'druid/feralcat': ('DRUID', 'feral', {'Cat': ('Katze', None)}),
    'druid/feralbear': ('DRUID', 'bear', {'Bear': ('Bär', None)}),
    'hunter/dps': ('HUNTER', 'dps', {'Weave': ('Jäger Weben', None), 'Turret': ('Jäger stationär', None),
                                     'Melee': ('Jäger Nahkampf', None)}),
    'rogue/dps': ('ROGUE', 'dps', {'Combat Sinister': ('Kampf Finsterer Stoß', None), 'Combat Daggers': ('Kampf Dolche', None),
                                   'Subtlety': ('Täuschung', None), 'Assassination': ('Meucheln', None)}),
    'warrior/dps': ('WARRIOR', 'dps', {'Pre-BiS - Fury': ('Furor Pre-BiS', None), 'Pre-BiS - Arms': ('Waffen Pre-BiS', None),
                                       'Pre-BiS - Fury 2H': ('Furor Zweihand Pre-BiS', None)}),
    'warrior/protection': ('WARRIOR', 'tank', {'Pre-BiS - Offensive': ('Schutz offensiv', None),
                                               'Pre-BiS - Balanced': ('Schutz ausgewogen', None)}),
    'shaman/elemental': ('SHAMAN', 'ele', {'Default': ('Elementar', None)}),
    'shaman/enhancement': ('SHAMAN', 'enh', {'Pre-BiS': ('Verstärkung Pre-BiS', None)}),
    'paladin/retribution': ('PALADIN', 'ret', {'Holy Shock': ('Vergeltung Heiliger Schock', None),
                                               'Unsealed Wrath': ('Vergeltung ohne Siegel', None)}),
}
CLASS_ORDER = ('WARRIOR', 'PALADIN', 'HUNTER', 'ROGUE', 'PRIEST', 'SHAMAN', 'MAGE', 'WARLOCK', 'DRUID')

CALL = re.compile(r"makePresetEpWeights\(\s*'((?:[^'\\]|\\.)*)'\s*,\s*")
CONST = re.compile(r'(?:export\s+)?const\s+(\w+)\s*(?::\s*[\w.<>]+\s*)?=\s*')
PAIR = re.compile(r'\[\s*(?:Stat|PseudoStat)\.(\w+)\s*\]\s*:\s*([^,}\n]+?)\s*(?:,|\n|})')
NUMBER = re.compile(r'^-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?$')


def _span(text, start):
    """The text from start (an opening bracket) to its matching closing one, or None."""
    pairs = {'(': ')', '{': '}', '[': ']'}
    stack = []
    i = start
    quote = None
    while i < len(text):
        ch = text[i]
        if quote:
            if ch == '\\':
                i += 1
            elif ch == quote:
                quote = None
        elif ch in '\'"`':
            quote = ch
        elif ch == '/' and text.startswith('//', i):
            j = text.find('\n', i)
            i = len(text) if j < 0 else j
            continue
        elif ch in pairs:
            stack.append(pairs[ch])
        elif ch in ')}]':
            if not stack or stack.pop() != ch:
                return None
            if not stack:
                return text[start:i + 1]
        i += 1
    return None


def _definitions(texts):
    """{name: the expression after `const name =`} up to the end of that expression, for every text."""
    out = {}
    for text in texts:
        for m in CONST.finditer(text):
            rest = text[m.end():]
            if rest.startswith('Stats.fromMap('):
                body = _span(text, m.end() + len('Stats.fromMap'))
                if body:
                    out.setdefault(m.group(1), 'Stats.fromMap' + body)
            else:
                ident = re.match(r'(\w+)\s*;', rest)
                out.setdefault(m.group(1), ident.group(1) if ident else rest.split(';', 1)[0].strip())
    return out


def _weights(expr, defs, depth=0):
    """The pairs of a `Stats.fromMap(...)` expression, following plain names through defs; None for anything else
    (a computed value like `CatEp.scale(...)` is never evaluated)."""
    expr = expr.strip()
    if depth < 5 and re.fullmatch(r'\w+', expr) and expr in defs:
        return _weights(defs[expr], defs, depth + 1)
    if not expr.startswith('Stats.fromMap('):
        return None
    out, skipped = {}, []
    for name, value in PAIR.findall(expr):
        value = value.strip()
        if not NUMBER.match(value):
            skipped.append(f'{name} (not a plain number: {value})')
            continue
        key = STAT_KEY.get(name)
        if key is None:
            if name not in SKIPPED:
                skipped.append(f'{name} (no key in Amisia)')
            continue
        v = float(value)
        if v != 0:
            out[key] = round(v, 4)
    return out, skipped


def parse_presets(text, shared=()):
    """[(preset name, {Amisia key: weight per point}, [skipped names with the reason])] of one presets.ts, in the
    file's order; shared: the texts of the class's *_ep.ts the presets may name. A preset whose weights are not a
    plain map comes back with None."""
    defs = _definitions([text] + list(shared))
    out = []
    for m in CALL.finditer(text):
        name = m.group(1).replace("\\'", "'")
        rest = text[m.end():]
        if rest.startswith('Stats.fromMap('):
            body = _span(text, m.end() + len('Stats.fromMap'))
            expr = 'Stats.fromMap' + body if body else ''
        else:
            ident = re.match(r'(\w+)', rest)
            expr = ident.group(1) if ident else ''
        got = _weights(expr, defs)
        if got is None:
            out.append((name, None, [f'{name}: not a plain map ({expr[:40]})']))
        else:
            out.append((name, got[0], got[1]))
    return out


def load(base=WOWSIMS_CACHE, quiet=False):
    """{class: [{'name': German name, 'spec': Amisia's spec key or None, 'w': {key: weight per point}}, ...]} from the
    cache, in SPECS' order per class; None (with a note) when there is no download."""
    root = os.path.join(base, 'ui', 'specs')
    if not os.path.isdir(root):
        if not quiet:
            log(f'no WoWSims download in {base} (python3 tools/build.py wowsims): no weight templates')
        return None
    sims = {}
    for folder, (cls, spec, names) in SPECS.items():
        path = os.path.join(root, *folder.split('/'), 'presets.ts')
        if not os.path.exists(path):
            log(f'WoWSims: {folder}/presets.ts is missing')
            continue
        with open(path, encoding='utf-8') as fh:
            text = fh.read()
        shared = []
        class_dir = os.path.join(root, folder.split('/')[0])
        for f in sorted(os.listdir(class_dir)):
            if f.endswith('_ep.ts'):
                with open(os.path.join(class_dir, f), encoding='utf-8') as fh:
                    shared.append(fh.read())
        for preset, w, skipped in parse_presets(text, shared):
            for why in skipped:
                if not quiet:
                    log(f'WoWSims {folder} {preset}: skipped {why}')
            if preset not in names:
                if not quiet:
                    log(f'WoWSims {folder}: preset "{preset}" has no name in SPECS: left out')
                continue
            if not w:
                continue
            de, own_spec = names[preset]
            entry = {'name': de, 'spec': own_spec or spec, 'w': w}
            lst = sims.setdefault(cls, [])
            if any(e['name'] == de for e in lst):
                if not quiet:
                    log(f'WoWSims {folder} {preset}: "{de}" twice, the first kept')
                continue
            lst.append(entry)
    return {c: sims[c] for c in CLASS_ORDER if c in sims}


def main(argv=None):
    import argparse
    ap = argparse.ArgumentParser(description='Download the WoWSims Forever presets into the cache (F-230, D-161).')
    ap.add_argument('--dest', default=WOWSIMS_CACHE)
    ap.add_argument('--ref', default='master')
    args = ap.parse_args(argv)
    refresh(args.dest, args.ref)
    sims = load(args.dest)
    if sims:
        for cls in sorted(sims):
            log(f'  {cls}: ' + ', '.join(t['name'] for t in sims[cls]))


if __name__ == '__main__':
    main()
