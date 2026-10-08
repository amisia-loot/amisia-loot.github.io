"""docs/FEATURES.md: the user-visible features with their status and the checks the user does in game.

    python3 tools/build.py testlist [--all] [--out FILE]
    python3 tools/build.py tested F-001 [F-002 ...] [--raid]

The file holds one entry per feature (the format is described at its top):

    ### F-012 Scan-Daten aufräumen
    - Version: 2.13.0
    - Status: gebaut
    - Braucht: Gruppe
    - Prüfung: Wenn du ..., dann ...
    - Notiz: ...

Version and Status once, Braucht at most once (Gruppe, Gilde, Raid, comma separated), one to five
Prüfung lines, Notiz as often as wanted. Status is `geplant`, `gebaut`, `im Spiel geprüft (YYYY-MM-DD)`
or `im Raid bewährt (YYYY-MM-DD)`. Anything else between two entries is an error with its line number,
so a typo never hides an entry from the test list.
"""
import re
from dataclasses import dataclass, field

PLANNED, BUILT, CHECKED, PROVEN = 'geplant', 'gebaut', 'im Spiel geprüft', 'im Raid bewährt'
STATUSES = (PLANNED, BUILT, CHECKED, PROVEN)
NEEDS = ('Gruppe', 'Gilde', 'Raid')
MAX_CHECKS = 5
LATER = 'Erst nach dem Start (Gruppe/Gilde/Raid)'

HEAD = re.compile(r'^### (F-\d{3}) (\S.*?)\s*$')
FIELD = re.compile(r'^- (Version|Status|Braucht|Prüfung|Notiz): (.*?)\s*$')
STATUS = re.compile(r'^(geplant|gebaut|im Spiel geprüft|im Raid bewährt)(?: \((\d{4}-\d{2}-\d{2})\))?$')
VERSION = re.compile(r'^\d+\.\d+\.\d+$')


class FeatureError(ValueError):
    pass


@dataclass
class Feature:
    id: str
    title: str
    section: str
    line: int                       # 1-based line of the heading
    version: str = None
    status: str = None
    date: str = None
    needs: list = field(default_factory=list)
    checks: list = field(default_factory=list)
    notes: list = field(default_factory=list)
    status_line: int = None         # 0-based index of the "- Status:" line

    @property
    def alone(self):
        """The user can check it on his own (no group, guild or raid needed)."""
        return not self.needs


def version_key(v):
    return tuple(int(x) for x in v.split('.'))


def parse(text):
    """The entries of a FEATURES.md text, in file order. Raises FeatureError on anything malformed."""
    out, cur, section, fence = [], None, '', False
    errors = []
    lines = text.split('\n')
    for i, raw in enumerate(lines):
        line = raw.rstrip()
        if line.startswith('```'):
            fence = not fence
            continue
        if fence:
            continue
        if line.startswith('## '):
            section, cur = line[3:].strip(), None
            continue
        m = HEAD.match(line)
        if m:
            cur = Feature(m.group(1), m.group(2), section, i + 1)
            out.append(cur)
            continue
        if line.startswith('#'):
            cur = None
            continue
        if cur is None or not line.strip():
            continue
        f = FIELD.match(line)
        if not f:
            errors.append(f'line {i + 1} ({cur.id}): not "- Version|Status|Braucht|Prüfung|Notiz: ...": {line[:60]}')
            continue
        key, value = f.groups()
        if key == 'Version':
            if cur.version is not None:
                errors.append(f'line {i + 1} ({cur.id}): Version twice')
            cur.version = value
        elif key == 'Status':
            if cur.status is not None:
                errors.append(f'line {i + 1} ({cur.id}): Status twice')
            s = STATUS.match(value)
            if not s:
                errors.append(f'line {i + 1} ({cur.id}): status "{value}" is none of {", ".join(STATUSES)}')
                cur.status = value
            else:
                cur.status, cur.date = s.groups()
                if cur.status in (CHECKED, PROVEN) and not cur.date:
                    errors.append(f'line {i + 1} ({cur.id}): "{cur.status}" needs its date: "{cur.status} (YYYY-MM-DD)"')
                if cur.status in (PLANNED, BUILT) and cur.date:
                    errors.append(f'line {i + 1} ({cur.id}): "{cur.status}" takes no date')
            cur.status_line = i
        elif key == 'Braucht':
            if cur.needs:
                errors.append(f'line {i + 1} ({cur.id}): Braucht twice')
            cur.needs = [n.strip() for n in value.split(',') if n.strip()]
            bad = [n for n in cur.needs if n not in NEEDS]
            if bad or not cur.needs:
                errors.append(f'line {i + 1} ({cur.id}): Braucht takes {", ".join(NEEDS)}, not "{value}"')
        elif key == 'Prüfung':
            cur.checks.append(value)
        else:
            cur.notes.append(value)
    if fence:
        errors.append('a ``` block is not closed')
    for f in out:
        if f.version is None:
            errors.append(f'line {f.line} ({f.id}): no Version')
        elif not (VERSION.match(f.version) or (f.version == '-' and f.status == PLANNED)):
            errors.append(f'line {f.line} ({f.id}): version "{f.version}" is not X.Y.Z ("-" only while geplant)')
        if f.status is None:
            errors.append(f'line {f.line} ({f.id}): no Status')
        if not 1 <= len(f.checks) <= MAX_CHECKS:
            errors.append(f'line {f.line} ({f.id}): {len(f.checks)} checks, 1 to {MAX_CHECKS} wanted')
    seen = {}
    for f in out:
        if f.id in seen:
            errors.append(f'line {f.line}: {f.id} again (first at line {seen[f.id]})')
        seen.setdefault(f.id, f.line)
    if errors:
        raise FeatureError('\n'.join(errors))
    return out


def load(path):
    with open(path, encoding='utf-8') as fh:
        return parse(fh.read())


def released(f):
    return f.version not in (None, '-') and VERSION.match(f.version)


def by_version(features):
    """{version: [features]} newest version first, file order inside a version."""
    groups = {}
    for f in features:
        groups.setdefault(f.version, []).append(f)
    return dict(sorted(groups.items(), key=lambda kv: version_key(kv[0]), reverse=True))


def entry_lines(f, with_needs=False):
    head = f'### {f.id} {f.title}'
    if with_needs and f.needs:
        head += f' (braucht: {", ".join(f.needs)})'
    return [head] + [f'- [ ] {c}' for c in f.checks]


def testlist(features, all_=False, version=None):
    """The German check list for the user: the built features he can check alone, newest version first;
    with all_ also the ones that need a group, guild or raid, in their own section."""
    todo = [f for f in features if f.status == BUILT and released(f)]
    alone = [f for f in todo if f.alone]
    out = ['# Testliste Amisia' + (f' (Stand {version})' if version else ''), '',
           'Gebaute Features, die noch niemand im Spiel geprüft hat. Was klappt: '
           '`python3 tools/build.py tested F-xxx`.']
    if not alone:
        out += ['', 'Nichts offen, was du allein prüfen kannst.']
    for v, group in by_version(alone).items():
        out += ['', f'## {v}']
        for f in group:
            out += [''] + entry_lines(f)
    if all_:
        later = [f for f in todo if not f.alone]
        out += ['', f'## {LATER}']
        if not later:
            out += ['', 'Nichts offen.']
        for f in later:
            out += [''] + entry_lines(f, with_needs=True)
    return '\n'.join(out) + '\n'


def release_list(features, version):
    """The short test list of one release (the features whose version is this one), or None."""
    mine = [f for f in features if f.version == version]
    if not mine:
        return None
    out = [f'Zum Testen im Spiel ({version}), danach `python3 tools/build.py tested F-xxx`:']
    for f in mine:
        out += [''] + entry_lines(f, with_needs=True)
    return '\n'.join(out) + '\n'


def mark_tested(text, ids, raid=False, day=None):
    """text with the status of each named entry set to "im Spiel geprüft (day)" (or "im Raid bewährt"
    with raid). Returns (new text, [messages]). Unknown ids raise FeatureError and change nothing; an
    entry already proven in a raid stays so when raid is not set."""
    if not day or not re.match(r'^\d{4}-\d{2}-\d{2}$', day):
        raise FeatureError(f'the day is YYYY-MM-DD, not {day!r}')
    features = {f.id: f for f in parse(text)}
    wanted = [i.upper() for i in ids]
    unknown = [i for i in wanted if i not in features]
    if unknown:
        raise FeatureError('no such feature: ' + ', '.join(unknown))
    lines = text.split('\n')
    msgs = []
    status = PROVEN if raid else CHECKED
    for fid in dict.fromkeys(wanted):
        f = features[fid]
        if f.status == PROVEN and not raid:
            msgs.append(f'{fid} {f.title}: stays "{PROVEN} ({f.date})"')
            continue
        old = lines[f.status_line]
        lines[f.status_line] = f'- Status: {status} ({day})'
        msgs.append(f'{fid} {f.title}: {old[len("- Status: "):]} -> {status} ({day})')
    return '\n'.join(lines), msgs


def counts(features):
    out = {s: 0 for s in STATUSES}
    for f in features:
        out[f.status] = out.get(f.status, 0) + 1
    return out
