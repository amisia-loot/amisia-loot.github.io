"""The stat weights of the WoWSims simulation for WoW Forever, as templates for the own weights (F-230, D-161).

Source: https://github.com/wowsims/forever (branch master), MIT licence; Amisia names it in
Amisia/LICENSES/THIRD-PARTY.md and ships its licence text as Amisia/LICENSES/WoWSims-MIT.txt.

refresh() (`python3 tools/build.py wowsims`) downloads through the GitHub API, one request after the other, only
the files ui/specs/<class>/<spec>/presets.ts, the weights a class shares (ui/specs/<class>/*_ep.ts), the gear sets
(ui/specs/<class>/<spec>/gear_sets/*.gear.json and *.gear.siml), proto/common.proto (the slot order) and
the repository's LICENSE into ~/addons/_cache/wowsims (or
$AMISIA_WOWSIMS_CACHE), outside the repo. `build.py data` never downloads: load() reads the cache, and a missing
cache means no templates (a printed note).

The files are TypeScript. Nothing of them runs: parse_presets() reads the calls
`PresetUtils.makePresetEpWeights('<name>', Stats.fromMap({ [Stat.StatX]: 1.0, ... }))` as text, keeps the name and
every `[Stat.<name>]: <number>` / `[PseudoStat.<name>]: <number>` pair, and maps the stat names to Amisia's keys
(STAT_KEY). WoWSims' weights are per point of a stat, the same unit Amisia's own weights (AmisiaDB.weights) use;
in Forever one rating point counts for weapons and spells alike, so the simulation's hit, crit and haste go to
Amisia's one key each. Which spec of the simulation is which of Amisia's stands by hand in SPECS.

The gear sets (F-239): parse_gear_presets() reads the calls `PresetUtils.makePresetGear('<label>', X[, options])` and
the `import X from './gear_sets/<file>.gear.json|.gear.siml'` lines; load_sets() maps label and option group by hand
(SET_NAMES) to a German name and Amisia's spec. A .gear.json lists item ids in WoWSims' ItemSlot order (SLOT_ORDER);
a .gear.siml names its items in words, which go to ids through English item names the caller hands in (build_bis
gear_set_names: English item names on disk). An item no name explains is left out with a log line.
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
# proto/common.proto: the ItemSlot order of a gear set's items (SLOT_ORDER below)
KEEP_FILES = ('LICENSE', 'proto/common.proto')
PAUSE = 1.0   # seconds between two requests
PRESETS = re.compile(r'^ui/specs/[a-z_]+/[a-z_]+/presets\.ts$')
# a class's shared weights that its specs' presets import (druid/feral_ep.ts: the bear's and the cat's)
SHARED_EP = re.compile(r'^ui/specs/[a-z_]+/[a-z_]+_ep\.ts$')
# the gear sets the presets import (F-239): a spec's own and a class's shared folder (ui/specs/warrior/shared/...)
GEAR_SET_FILE = re.compile(r'^ui/specs/[a-z_]+/[a-z_]+/gear_sets/[\w.-]+\.gear\.(?:json|siml)$')


def log(*a):
    print(*a, file=sys.stderr)


def kept(path):
    """Whether refresh() downloads a file of the repository."""
    return (path in KEEP_FILES or bool(PRESETS.match(path)) or bool(SHARED_EP.match(path))
            or bool(GEAR_SET_FILE.match(path)))


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


# ---------------------------------------------------------------- gear sets (F-239)
# WoWSims' ItemSlot (proto/common.proto, checked against the download): the order of a .gear.json's items, as
# Amisia's slot names (Gear.lua)
SLOT_ORDER = ('HEAD', 'NECK', 'SHOULDER', 'BACK', 'CHEST', 'WRIST', 'HANDS', 'WAIST', 'LEGS', 'FEET', 'FINGER1',
              'FINGER2', 'TRINKET1', 'TRINKET2', 'MAINHAND', 'OFFHAND', 'RANGED')
# a .gear.siml names its slots in words
SIML_SLOT = {'head': 'HEAD', 'neck': 'NECK', 'shoulder': 'SHOULDER', 'back': 'BACK', 'chest': 'CHEST',
             'wrist': 'WRIST', 'hands': 'HANDS', 'waist': 'WAIST', 'legs': 'LEGS', 'feet': 'FEET',
             'finger1': 'FINGER1', 'finger2': 'FINGER2', 'trinket1': 'TRINKET1', 'trinket2': 'TRINKET2',
             'main_hand': 'MAINHAND', 'off_hand': 'OFFHAND', 'ranged': 'RANGED'}

# The simulation's gear presets (makePresetGear '<label>' with its option group, or None) -> per spec folder
# Amisia's class, spec key and per preset the German name the addon shows ("Bekannte Sets", its English one in
# Amisia_Gear/Locales/enUS_gear.lua) with an own spec key or None. A preset not named here is left out with a log line.
SET_NAMES = {
    'warrior/dps': ('WARRIOR', 'dps', {('Pre-BiS', 'Fury'): ('Furor Pre-BiS', None),
                                       ('Pre-BiS', 'Arms'): ('Waffen Pre-BiS', None),
                                       ('Pre-BiS', 'Fury 2H'): ('Furor Zweihand Pre-BiS', None)}),
    'warrior/protection': ('WARRIOR', 'tank', {('Pre-BiS', 'Offensive'): ('Schutz offensiv', None),
                                               ('Pre-BiS', 'Balanced'): ('Schutz ausgewogen', None)}),
    'paladin/retribution': ('PALADIN', 'ret', {('Holy Shock', None): ('Vergeltung Heiliger Schock', None),
                                               ('Default', None): ('Vergeltung Pre-BiS', None)}),
    'paladin/holy': ('PALADIN', 'holy', {('Default', None): ('Heilig Pre-BiS', None)}),
    'paladin/protection': ('PALADIN', 'tank', {('Default', None): ('Schutz Pre-BiS', None)}),
    'hunter/dps': ('HUNTER', 'dps', {('Pre-BiS', 'Weave'): ('Jäger Weben Pre-BiS', None),
                                     ('Pre-BiS (Cheap)', 'Weave'): ('Jäger Weben günstig', None),
                                     ('Pre-BiS', 'Turret'): ('Jäger stationär Pre-BiS', None),
                                     ('Pre-BiS (Cheap)', 'Turret'): ('Jäger stationär günstig', None),
                                     ('Pre-BiS', 'Melee'): ('Jäger Nahkampf Pre-BiS', None),
                                     ('Pre-BiS (Cheap)', 'Melee'): ('Jäger Nahkampf günstig', None)}),
    'rogue/dps': ('ROGUE', 'dps', {('Slow Main Hand', None): ('Kampf Finsterer Stoß', None),
                                   ('Backstab Combat', None): ('Kampf Dolche', None),
                                   ('Backstab Subtlety', None): ('Täuschung', None),
                                   ('Mutilate', None): ('Meucheln', None)}),
    'priest/healer': ('PRIEST', None, {('Pre-raid', None): ('Heiler Pre-BiS', None)}),
    'shaman/elemental': ('SHAMAN', 'ele', {('Budget', None): ('Elementar günstig', None)}),
    'mage/dps': ('MAGE', None, {('Preraid', 'Arcane'): ('Arkan Pre-BiS', 'arcane'),
                                ('Preraid', 'Fire'): ('Feuer Pre-BiS', 'fire'),
                                ('Preraid', 'Frost'): ('Frost Pre-BiS', 'frost')}),
    'warlock/dps': ('WARLOCK', None, {('Aff (Wrack)', None): ('Gebrechen (Wrack)', 'affli'),
                                      ('Destro', None): ('Zerstörung', 'destro'),
                                      ('SM/Ruin', None): ('SM/Ruin', None),
                                      ('Demo (Fire Brand)', None): ('Dämonologie Feuerbrand', None),
                                      ('Demo (Shadow Brand)', None): ('Dämonologie Schattenbrand', None)}),
    'druid/feralcat': ('DRUID', 'feral', {('Pre-raid', None): ('Katze Pre-BiS', None)}),
}

GEAR_IMPORT = re.compile(r"^import\s+(\w+)\s+from\s+'([^']*gear_sets/[\w.-]+\.gear\.(?:json|siml))'\s*;?", re.M)
GEAR_CALL = re.compile(r"makePresetGear\(\s*'((?:[^'\\]|\\.)*)'\s*,\s*([\w.]+)\s*")
GROUP = re.compile(r"\bgroup\s*:\s*'((?:[^'\\]|\\.)*)'")


def slug(name):
    """An item name as WoWSims writes it in a .gear.siml: lower case, apostrophes dropped, every other run of
    signs one underscore ("Don Julio's Band" -> don_julios_band)."""
    s = re.sub(r"['’]", '', (name or '').lower())
    return re.sub(r'[^a-z0-9]+', '_', s).strip('_')


def item_slugs(names):
    """{slug: [item ids]} of {item id: English name} (ItemSparse Display_lang)."""
    out = {}
    for iid, name in names.items():
        if name:
            out.setdefault(slug(name), []).append(iid)
    return out


def _options(text, rest, start):
    """The option group of a makePresetGear call: rest is the text after its second argument (start: its offset in
    text); an inline object or a `const NAME = { ... }` of the same file."""
    m = re.match(r',\s*', rest)
    if not m:
        return None
    after = rest[m.end():]
    if after.startswith('{'):
        body = _span(text, start + m.end()) or ''
    else:
        ident = re.match(r'(\w+)', after)
        if not ident:
            return None
        d = re.search(r'\bconst\s+' + re.escape(ident.group(1)) + r'\s*(?::\s*[\w.<>]+\s*)?=\s*\{', text)
        body = (_span(text, d.end() - 1) or '') if d else ''
    g = GROUP.search(body)
    return g.group(1).replace("\\'", "'") if g else None


def parse_gear_presets(text):
    """[(label, group or None, relative gear set path or None, variable)] of the makePresetGear calls of one
    presets.ts, in the file's order; the path is None when the call's gear is no imported gear_sets file (a build's
    `X.player.equipment`)."""
    imports = {m.group(1): m.group(2) for m in GEAR_IMPORT.finditer(text)}
    out = []
    for m in GEAR_CALL.finditer(text):
        label = m.group(1).replace("\\'", "'")
        var = m.group(2)
        group = _options(text, text[m.end():], m.end())
        out.append((label, group, imports.get(var), var))
    return out


def parse_gear_json(text):
    """{slot: item id} of a .gear.json ({"items": [{"id": N, ...} or {}, ...]} in SLOT_ORDER); empty slots and id 0
    left out."""
    data = json.loads(text)
    out = {}
    for slot, it in zip(SLOT_ORDER, data.get('items') or []):
        iid = it.get('id') if isinstance(it, dict) else None
        if isinstance(iid, int) and iid > 0:
            out[slot] = iid
    return out


def parse_gear_siml(text, slugs, known=(), levels=None):
    """({slot: item id}, [unresolved]) of a .gear.siml: `<slot>  <item slug>[ <suffix>][ + <enchant> ...]` lines. The
    slug goes to an item id through slugs ({slug: [ids]}); a trailing `_<id>` picks that id among the name's items,
    a trailing `_ilvl<N>` the name's items of item level N (levels: {id: item level}); a slug several items share
    takes the one in known (the planner's items), then the one of the highest item level, else it stays unresolved.
    A random suffix (`of_magic`) is dropped:
    the planner picks the item."""
    out, missing = {}, []
    known = set(known or ())
    levels = levels or {}
    for line in text.splitlines():
        parts = line.split()
        if len(parts) < 2 or parts[0] not in SIML_SLOT:
            continue
        item = line.split('+', 1)[0].split()[1]
        ids = list(slugs.get(item) or [])
        tail = re.match(r'^(.*)_(ilvl)?(\d+)$', item)
        if not ids and tail:
            base_ids = slugs.get(tail.group(1)) or []
            n = int(tail.group(3))
            ids = [i for i in base_ids if (levels.get(i) == n if tail.group(2) else i == n)]
        if len(ids) > 1:
            ids = [i for i in ids if i in known] or ids
        if len(ids) > 1 and levels:
            # one name in several item levels (Forest Stalker's Bracers 45/55/65): a pre-raid set means the highest
            top = max(levels.get(i, 0) for i in ids)
            ids = [i for i in ids if levels.get(i, 0) == top]
        if len(ids) == 1:
            out[SIML_SLOT[parts[0]]] = ids[0]
        else:
            missing.append(f'{parts[0]} {item}' + (f' ({len(ids)} items of that name)' if ids else ''))
    return out, missing


def load_sets(base=WOWSIMS_CACHE, names=None, known=(), levels=None, quiet=False):
    """{class: [{'name': German name, 'spec': Amisia's spec key or None, 'items': {slot: item id}}, ...]} of the gear
    presets in the cache, in SET_NAMES' order per class and the file's order per folder; None (with a note) when
    there is no download. names: {item id: English name} (the client's ItemSparse) for the .gear.siml files, which
    name their items; without it those sets are left out. known: the planner's item ids (a name several items
    share); levels: {item id: item level} (a name with `_ilvl<N>`). A set with the same items as an earlier one of its class is left out (the first name kept)."""
    root = os.path.join(base, 'ui', 'specs')
    if not os.path.isdir(root):
        if not quiet:
            log(f'no WoWSims download in {base} (python3 tools/build.py wowsims): no gear sets')
        return None
    slugs = item_slugs(names) if names else None
    sets = {}
    for folder, (cls, spec, labels) in SET_NAMES.items():
        here = os.path.join(root, *folder.split('/'))
        path = os.path.join(here, 'presets.ts')
        if not os.path.exists(path):
            log(f'WoWSims: {folder}/presets.ts is missing')
            continue
        with open(path, encoding='utf-8') as fh:
            text = fh.read()
        for label, group, rel, var in parse_gear_presets(text):
            key = (label, group)
            shown = label + (f' [{group}]' if group else '')
            if key not in labels:
                if not quiet:
                    log(f'WoWSims {folder}: gear preset "{shown}" has no name in SET_NAMES: left out')
                continue
            if not rel:
                if not quiet:
                    log(f'WoWSims {folder} {shown}: its gear ({var}) is no gear_sets file: left out')
                continue
            file = os.path.normpath(os.path.join(here, rel))
            if not file.startswith(root + os.sep) or not os.path.exists(file):
                log(f'WoWSims {folder} {shown}: {rel} is missing: left out')
                continue
            with open(file, encoding='utf-8') as fh:
                body = fh.read()
            if file.endswith('.json'):
                items = parse_gear_json(body)
            elif slugs is None:
                if not quiet:
                    log(f'WoWSims {folder} {shown}: {rel} names its items, no item names to read it: left out')
                continue
            else:
                items, missing = parse_gear_siml(body, slugs, known, levels)
                for why in missing:
                    if not quiet:
                        log(f'WoWSims {folder} {shown}: no item for {why}')
            if not items:
                continue
            de, own_spec = labels[key]
            lst = sets.setdefault(cls, [])
            twin = next((e for e in lst if e['items'] == items or e['name'] == de), None)
            if twin:
                if not quiet:
                    log(f'WoWSims {folder} {shown}: the same ' + ('items' if twin['items'] == items else 'name')
                        + f' as "{twin["name"]}", the first kept')
                continue
            lst.append({'name': de, 'spec': own_spec or spec, 'items': items})
    return {c: sets[c] for c in CLASS_ORDER if c in sets}


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
    # the gear sets (F-239) as build.py data will read them (item names from the disk, never the network)
    import build_bis
    import client_tables
    names, levels = build_bis.gear_set_names(client_tables.default_dir())
    sets = load_sets(args.dest, names, (), levels, quiet=True)
    for cls in sorted(sets or {}):
        log(f'  sets {cls}: ' + ', '.join(f'{t["name"]} ({len(t["items"])})' for t in sets[cls]))


if __name__ == '__main__':
    main()
