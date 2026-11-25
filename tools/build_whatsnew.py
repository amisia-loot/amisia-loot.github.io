"""The news of the newest versions for the window "Neu in Amisia" (F-236, D-168): Amisia/Data/WhatsNew.lua.

    python3 tools/build_whatsnew.py [--version X.Y.Z] [--root DIR]
    python3 tools/build.py whatsnew          the same with the TOC's version

Sources: docs/FEATURES.md (the German title of each feature) and CHANGELOG.md (the English summary of its
notes). The items of a version are, in this order: the features its "feat" notes name (the first F number of a
note; notes of the scope "site" left out, the site is not in the game), then the features whose FEATURES entry
carries the version and no feat note named. German: the feature's title (no entry: the English summary);
English: the summary of the version's first feat note naming it, else of any note naming it, else the title.
The notes under "## Unreleased" belong to the given version while CHANGELOG.md has no section of it yet: so
`build.py release` writes the file after the TOC got the new version and before its check, and the file stays the
same once the release turned the notes into the version's section. Versions newer than the given one are left
out (FEATURES entries of the coming release). The newest KEEP versions with at least one item go in, newest
first. Characters the game font lacks are replaced (tools/tests/test_contracts.py).

tools/tests/test_build_whatsnew.py holds the shipped file against the documents (build.py check).
"""
import argparse
import os
import re
import sys

TOOLS = os.path.dirname(os.path.abspath(__file__))
if TOOLS not in sys.path:
    sys.path.insert(0, TOOLS)
import features  # noqa: E402
import lua_data  # noqa: E402
import modules  # noqa: E402  (where each Data/* file stands, F-228)

ROOT = os.path.dirname(TOOLS)
NAME = 'WhatsNew.lua'
KEY = 'WHATSNEW'
KEEP = 5            # versions in the file
LEFT_OUT = ('site',)   # note scopes the game does not show
NOTE = re.compile(r'^- (\w+)\(([^)]*)\): (.+?)\s*\(((?:F-\d+)(?:,\s*F-\d+)*)\)\s*$')
SECTION = re.compile(r'^## \[v(\d+\.\d+\.\d+)\][^\n]*$', re.M)
# the game font has no glyph for these (test_no_characters_the_game_font_lacks)
GLYPHS = {'–': '-', '—': '-', '…': '...', '←': '<-', '↑': '^', '→': '->', '↓': 'v', '•': '·', '●': '·', '▶': '>',
          '▸': '>', '„': '"', '“': '"', '”': '"'}


def out_path(root=ROOT):
    """Where the file stands in a checkout (the core's Data folder, tools/modules.py DATA_HOME)."""
    return os.path.join(root, modules.FOLDERS[modules.DATA_HOME[NAME]], 'Data', NAME)


def version_key(v):
    return tuple(int(x) for x in v.split('.'))


def clean(text):
    """One line in the game font's characters, its first letter capital (the notes start small)."""
    for bad, good in GLYPHS.items():
        text = text.replace(bad, good)
    text = re.sub(r'\s+', ' ', text).strip()
    return text[:1].upper() + text[1:]


def sections(changelog, version):
    """[(version, notes text)] of CHANGELOG.md, newest first; the notes under "## Unreleased" as version's
    while no section carries version."""
    out = []
    heads = list(SECTION.finditer(changelog))
    for i, m in enumerate(heads):
        end = heads[i + 1].start() if i + 1 < len(heads) else len(changelog)
        out.append((m.group(1), changelog[m.end():end]))
    if version and version not in {v for v, _ in out}:
        m = re.search(r'^## Unreleased[ \t]*\n(.*?)(?=^## |\Z)', changelog, re.M | re.S)
        if m and m.group(1).strip():
            out.insert(0, (version, m.group(1)))
    return out


def notes(text):
    """[(type, scope, summary, [F numbers])] of the note lines of a section."""
    out = []
    for line in text.splitlines():
        m = NOTE.match(line)
        if m:
            out.append((m.group(1), m.group(2), m.group(3), re.findall(r'F-\d+', m.group(4))))
    return out


def collect(features_text, changelog, version, keep=KEEP):
    """[(version, [(F number, German, English)])], newest first, at most keep versions with items."""
    feats = {f.id: f for f in features.parse(features_text)}
    out = []
    for v, text in sections(changelog, version):
        if version and version_key(v) > version_key(version):
            continue
        ns = [n for n in notes(text) if n[1] not in LEFT_OUT]
        items, seen = [], set()

        def summary(fid):
            for kind, _, text_, ids in ns:
                if kind == 'feat' and ids[0] == fid:
                    return text_
            for _, _, text_, ids in ns:
                if fid in ids:
                    return text_
            return None

        for kind, _, text_, ids in ns:
            fid = ids[0]
            if kind != 'feat' or fid in seen:
                continue
            seen.add(fid)
            f = feats.get(fid)
            items.append((fid, clean(f.title if f else text_), clean(text_)))
        for f in feats.values():
            if f.version == v and f.id not in seen:
                seen.add(f.id)
                en = summary(f.id)
                items.append((f.id, clean(f.title), clean(en or f.title)))
        if items:
            out.append((v, items))
        if len(out) >= keep:
            break
    return out


def lua_string(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'


def render(data, version):
    lines = [
        '-- Generated by tools/build_whatsnew.py from docs/FEATURES.md (the German titles) and CHANGELOG.md (the',
        '-- English summaries). Do not edit; rebuild instead (python3 tools/build.py whatsnew; build.py release does',
        '-- it). The news of the newest versions for the window "Neu in Amisia" (F-236, D-168), newest first:',
        '-- { version, { { feature, German title, English summary }, ... } }',
        'local _, ns = ...',
        '',
        'ns.%s = {' % KEY,
        '    version = %s,' % lua_string(version or ''),
        '    versions = {',
    ]
    for v, items in data:
        lines.append('        { %s, {' % lua_string(v))
        for fid, de, en in items:
            lines.append('            { %s, %s, %s },' % (lua_string(fid), lua_string(de), lua_string(en)))
        lines.append('        } },')
    lines += ['    },', '}', '']
    return lua_data.lazy('\n'.join(lines), KEY, len(data))


def build(root=ROOT, version=None):
    """The file's text for version (default: the core's TOC version) from the documents under root."""
    if version is None:
        with open(os.path.join(root, 'Amisia', 'Amisia.toc'), encoding='utf-8') as fh:
            version = re.search(r'^## Version:\s*(\S+)', fh.read(), re.M).group(1)
    with open(os.path.join(root, 'docs', 'FEATURES.md'), encoding='utf-8') as fh:
        feats = fh.read()
    with open(os.path.join(root, 'CHANGELOG.md'), encoding='utf-8') as fh:
        log = fh.read()
    return render(collect(feats, log, version), version)


def write(root=ROOT, version=None):
    """Writes the file; returns its path and whether it changed."""
    text = build(root, version)
    path = out_path(root)
    old = None
    if os.path.exists(path):
        with open(path, encoding='utf-8') as fh:
            old = fh.read()
    if old != text:
        with open(path, 'w', encoding='utf-8', newline='\n') as fh:
            fh.write(text)
    return path, old != text


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--version', default=None, help='the version the file is for (default: the TOC\'s)')
    ap.add_argument('--root', default=ROOT, help=argparse.SUPPRESS)
    args = ap.parse_args(argv)
    path, changed = write(args.root, args.version)
    print(f'{os.path.relpath(path, args.root)}: {"written" if changed else "unchanged"}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
