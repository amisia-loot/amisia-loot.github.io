"""Amisia's localisation checks: German stays the source text in the code, every user-visible string
goes through ns.L (L["German text"]), Locales/enUS.lua holds the English text of every key.

    python3 tools/l10n.py scan [FILE...]   German-looking string literals not routed through L
    python3 tools/l10n.py check            the scan, plus: every L key has its enUS entry, no enUS
                                           entry is unused, the format specifiers match
    python3 tools/l10n.py stats            number of keys and of L uses per file
    python3 tools/l10n.py missing          the keys used in code without an enUS entry, as enUS lines

A literal that is German on purpose (a German chat word the addon understands, a German client text
it matches) carries the marker "l10n-ok" in a comment on its line, or stands in ALLOW below.
A text the code keeps as a key (a table of names it compares, stores or sends) and shows later
through L[variable] is marked N_("German text") where it stands: N_ returns it unchanged, and the
check counts it as a key. Generated files (Data/) are not scanned; their German texts (spec names, reasons, effect texts) reach
the screen through L[...] with a variable key, so their keys are listed in DATA_KEYS() and count as
used.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON = os.path.join(ROOT, 'addon', 'Amisia')
LOCALES = os.path.join(ADDON, 'Locales')
ENUS = os.path.join(LOCALES, 'enUS.lua')
SKIP_DIRS = ('Data', 'Locales')

# German words that mark a literal as German text (with umlauts and ß, which mark it anyway).
WORDS = set('''
aber alle allem allen aller alles als also alt alte alten am andere anderen anders anzeigen auch auf aus
ausblenden ausgewählt bei beim bereits bevor bis bitte bleibt da dann darf das dass dein deine deinen deiner
dem den denen der des dich die dies diese diesem diesen dieser dir doch dort du durch ein eine einem einen einer
eines einmal einstellen er erst erste ersten es etwa euch fehlt fertig ganz gar geht gerade gibt hast hat hier
ich ihr ihre ihren im immer ins ist jede jedem jeden jeder jedes jetzt kann kein keine keinem keinen keiner
klick klicken kommt können lädt lange läuft leer liegt los mal man mehr mein meine mit nach neu neue neuen
neuer nicht nichts noch nun nur ob oben oder ohne schon sehr sein seine seit selbst sich sie sind so sobald
soll sonst steht stehen über um und uns unten unter vom von vor wann war waren was weg weil welche wenn wer
werden wie wieder wird wo wurde zu zum zur zurück zwei
Ausrüstung Beute Einstellungen Fehler Gegenstand Gegenstände Gilde Gildenbank Klasse Mitglied Mitglieder
Seite Spieler Stufe Vergabe Vergaben Wurf Würfe Zeit Ziel Ziele Werte Talente Berufe Karte Übersicht
Anzeigen Abbrechen Vergeben Speichern Löschen Starten Beenden Schließen Öffnen Suchen Teilen
'''.split())
GERMAN_CHARS = re.compile('[äöüÄÖÜß]')
MARK = 'l10n-ok'

# Literals that look German but are not text for the screen (none yet beyond the markers in the code).
ALLOW = set()

STRING_START = re.compile(r'''--|"|'|\[(=*)\[''')


def lua_strings(src):
    """Every string literal of a Lua source: (start offset, end offset, value, line). Comments are skipped."""
    out = []
    i, n = 0, len(src)
    while i < n:
        m = STRING_START.search(src, i)
        if not m:
            break
        s = m.start()
        tok = m.group(0)
        if tok == '--':
            lm = re.match(r'--\[(=*)\[', src[s:])
            if lm:
                close = ']' + lm.group(1) + ']'
                e = src.find(close, s + len(lm.group(0)))
                i = n if e < 0 else e + len(close)
            else:
                e = src.find('\n', s)
                i = n if e < 0 else e
            continue
        if tok in ('"', "'"):
            j = s + 1
            buf = []
            while j < n and src[j] != tok:
                if src[j] == '\\' and j + 1 < n:
                    c = src[j + 1]
                    esc = {'n': '\n', 't': '\t', '\\': '\\', '"': '"', "'": "'", 'r': '\r', 'a': '\a', 'b': '\b',
                           'f': '\f', 'v': '\v', '\n': '\n'}
                    if c in esc:
                        buf.append(esc[c])
                        j += 2
                        continue
                    dm = re.match(r'\d{1,3}', src[j + 1:])
                    if dm:
                        buf.append(chr(int(dm.group(0))))
                        j += 1 + len(dm.group(0))
                        continue
                    buf.append(c)
                    j += 2
                    continue
                if src[j] == '\n':
                    break
                buf.append(src[j])
                j += 1
            e = j + 1
            out.append((s, e, ''.join(buf), src.count('\n', 0, s) + 1))
            i = e
            continue
        # long string
        close = ']' + m.group(1) + ']'
        e = src.find(close, m.end())
        e = n if e < 0 else e
        body = src[m.end():e]
        if body.startswith('\n'):
            body = body[1:]
        out.append((s, e + len(close), body, src.count('\n', 0, s) + 1))
        i = e + len(close)
    return out


L_BEFORE = re.compile(r'(?<![\w.:])L\s*\[\s*$')
L_AFTER = re.compile(r'^\s*\]')


N_BEFORE = re.compile(r'(?<![\w.:])(?:ns\.)?N_\s*\(\s*$')
N_AFTER = re.compile(r'^\s*\)')


def routed(src, s, e):
    """Whether the literal at s..e is the key of L[...] (ns.L too) or marked with N_(...) (a key the
    code keeps as it is and shows later through L[variable])."""
    before = src[max(0, s - 40):s]
    if (L_BEFORE.search(before) or re.search(r'ns\.L\s*\[\s*$', before)) and L_AFTER.match(src[e:e + 5]):
        return True
    return bool(N_BEFORE.search(before) and N_AFTER.match(src[e:e + 5]))


def is_german(text):
    if GERMAN_CHARS.search(text):
        return True
    plain = re.sub(r'\|c[0-9a-fA-F]{8}|\|r|\|T[^|]*\|t|\|A[^|]*\|a|\|H[^|]*\|h|\|h|%[-\d.]*[sdfiqx]', ' ', text)
    for w in re.findall(r"[A-Za-zÄÖÜäöüß]+", plain):
        if w in WORDS or (w.lower() in WORDS and len(w) > 3):
            return True
    return False


def addon_files():
    out = []
    for dirpath, dirs, files in os.walk(ADDON):
        rel = os.path.relpath(dirpath, ADDON)
        if rel.split(os.sep)[0] in SKIP_DIRS:
            continue
        for f in files:
            if f.endswith('.lua'):
                out.append(os.path.join(dirpath, f))
    return sorted(out)


def read(path):
    with open(path, encoding='utf-8') as fh:
        return fh.read()


def scan(files=None):
    """German-looking literals outside L[...]: list of (file, line, text)."""
    found = []
    for path in files or addon_files():
        src = read(path)
        lines = src.split('\n')
        for s, e, text, line in lua_strings(src):
            if routed(src, s, e) or not is_german(text) or text in ALLOW:
                continue
            last = src.count('\n', 0, e) + 1
            if any(MARK in lines[k - 1] for k in range(line, last + 1) if k - 1 < len(lines)):
                continue
            found.append((os.path.relpath(path, ROOT), line, text))
    return found


def used_keys(files=None):
    """The literal keys of L[...] in the code: {key: [(file, line)]}."""
    keys = {}
    for path in files or addon_files():
        src = read(path)
        for s, e, text, line in lua_strings(src):
            if routed(src, s, e):
                keys.setdefault(text, []).append((os.path.relpath(path, ROOT), line))
    return keys


def enus_files():
    if not os.path.isdir(LOCALES):
        return []
    return sorted(os.path.join(LOCALES, f) for f in os.listdir(LOCALES) if re.match(r'enUS.*\.lua$', f))


def enus_entries(paths=None, dups=None):
    """The English entries (Locales/enUS*.lua) as {German key: English text} (True: the same as the key),
    from the lines L["key"] = "value". dups, a list, gets (key, file) of every key given twice."""
    out = {}
    for path in (paths or enus_files()):
        for k, v in file_entries(path):
            if k in out and dups is not None:
                dups.append((k, os.path.relpath(path, ROOT)))
            out[k] = v
    return out


def file_entries(path):
    """[(key, value)] of one locale file, in order."""
    src = read(path)
    out = []
    strings = lua_strings(src)
    for i, (s, e, text, line) in enumerate(strings):
        if not routed(src, s, e):
            continue
        if re.match(r'^\s*\]\s*=\s*true\b', src[e:e + 16]):
            out.append((text, True))
        elif i + 1 < len(strings) and re.match(r'^\s*\]\s*=\s*$', src[e:strings[i + 1][0]]):
            out.append((text, strings[i + 1][2]))
    return out


def data_keys():
    """German texts of the generated files the code shows through L[variable] (they count as used)."""
    keys = set()
    gw = os.path.join(ADDON, 'Data', 'GearWeights.lua')
    if os.path.exists(gw):
        src = read(gw)
        for m in re.finditer(r'\b(name|why)\s*=\s*"((?:[^"\\]|\\.)*)"', src):
            keys.add(m.group(2).replace('\\"', '"').replace('\\\\', '\\'))
    for k in DATA_TABLE_KEYS:
        keys.add(k)
    return keys


# Keys reached only through a variable (tables of German texts built in code and translated where
# shown). Filled by the code owners as they need them; each must also stand in enUS.lua.
DATA_TABLE_KEYS = set()

SPEC = re.compile(r'%[-+ #0]*\d*(?:\.\d+)?[sdifgqxXceEouaA%]')


def specs(text):
    return [s[-1] for s in SPEC.findall(text) if s != '%%']


def check():
    problems = []
    for f, line, text in scan():
        problems.append(f'unrouted {f}:{line}: {text!r}')
    used = used_keys()
    dups = []
    entries = enus_entries(dups=dups)
    data = data_keys()
    for k, f in dups:
        problems.append(f'given twice: {f}: {k!r}')
    for k, where in sorted(used.items()):
        if k not in entries:
            problems.append(f'missing enUS {where[0][0]}:{where[0][1]}: {k!r}')
    for k, v in sorted(entries.items(), key=lambda kv: kv[0]):
        if k not in used and k not in data:
            problems.append(f'unused enUS: {k!r}')
        if v is not True and specs(k) != specs(v):
            problems.append(f'format specifiers differ: {k!r} {specs(k)} -> {v!r} {specs(v)}')
    for k in sorted(data):
        if k not in entries:
            problems.append(f'missing enUS (data): {k!r}')
    return problems


def lua_quote(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n') + '"'


def main(argv):
    cmd = argv[1] if len(argv) > 1 else 'check'
    if cmd == 'scan':
        files = [os.path.abspath(f) for f in argv[2:]] or None
        found = scan(files)
        for f, line, text in found:
            print(f'{f}:{line}: {text!r}')
        print(f'{len(found)} unrouted German-looking literals')
        return 1 if found else 0
    if cmd == 'check':
        problems = check()
        for p in problems:
            print(p)
        print(f'{len(problems)} problems')
        return 1 if problems else 0
    if cmd == 'stats':
        used = used_keys()
        per = {}
        for k, where in used.items():
            for f, _ in where:
                per[f] = per.get(f, 0) + 1
        for f in sorted(per):
            print(f'{per[f]:5d} {f}')
        print(f'{len(used)} keys, {sum(per.values())} uses, {len(enus_entries())} enUS entries')
        return 0
    if cmd == 'missing':
        files = [os.path.abspath(f) for f in argv[2:]] or None
        entries = enus_entries()
        for k in sorted(used_keys(files)):
            if k not in entries:
                print(f'L[{lua_quote(k)}] = {lua_quote(k)}')
        return 0
    print(__doc__)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv))
