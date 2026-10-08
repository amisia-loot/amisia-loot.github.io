"""The Lua errors the game caught, from the error catcher's SavedVariables the PC sends to the N100.

    python3 tools/build.py errors [--sv FILE] [--all]

The file (`~/addons/_SavedVariables/!BugGrabber.lua`, receive-only, read only) holds
`BugGrabberDB = { session = N, errors = { {message, stack, locals, session, time, counter}, ... } }`.
It runs in the same sandbox as Amisia's own SavedVariables (`build_scan.run_sv`); every field is read
defensively, since the file comes from another machine and another addon. Amisia's errors are the
ones whose message or stack names Amisia.
"""
import os
import re
import sys

DEFAULT_SV = os.path.expanduser('~/addons/_SavedVariables/!BugGrabber.lua')
BUDGET = 50000000   # Lua instructions; a full error list needs a small fraction
# "Interface/AddOns/Amisia/Core/Core.lua:12:", "[string "@Interface\AddOns\Amisia\UI\Widgets.lua"]:7:",
# "Amisia/Core/Core.lua:12:" (the catcher strips the folder in front)
FRAME = re.compile(r'((?:[A-Za-z]:)?[\w!.\- ]+(?:[/\\][\w!.\- ]+)*[/\\][\w!.\- ]+\.(?:lua|xml))"?\]?:(\d+)')
PREFIX = re.compile(r'^.*?(?:Interface[/\\])?AddOns[/\\]', re.I)


class Unreadable(ValueError):
    pass


def _text(v, limit=20000):
    if v is None:
        return ''
    if isinstance(v, bytes):
        v = v.decode('utf-8', 'replace')
    return str(v)[:limit]


def _int(v, default=0):
    try:
        return int(v)
    except (TypeError, ValueError):
        return default


def load(path=DEFAULT_SV):
    """(session, [errors]) of the file; each error a dict with message, stack, session, time, counter.
    Raises Unreadable when the file is no Lua the sandbox can run or holds no BugGrabberDB table."""
    tools = os.path.dirname(os.path.abspath(__file__))
    if tools not in sys.path:
        sys.path.insert(0, tools)
    import build_scan
    with open(path, 'rb') as fh:
        text = fh.read().decode('utf-8', 'replace')
    try:
        env, err = build_scan.run_sv(text, os.path.basename(path), BUDGET)
    except Exception as e:  # lupa errors of any kind
        raise Unreadable(f'{path}: {e}') from None
    if env is None:
        raise Unreadable(f'{path}: {err}')
    db = env['BugGrabberDB']
    if db is None or not hasattr(db, 'items'):
        raise Unreadable(f'{path}: no BugGrabberDB table')
    db = build_scan.lua_to_py(db)
    raw = db.get('errors')
    if isinstance(raw, dict):    # a list with holes comes over as a table keyed by number
        raw = [raw[k] for k in sorted(raw, key=lambda k: (not isinstance(k, int), str(k)))]
    if not isinstance(raw, list):
        raw = []
    out = []
    for e in raw:
        if not isinstance(e, dict):
            continue
        out.append({
            'message': _text(e.get('message')),
            'stack': _text(e.get('stack')),
            'session': _int(e.get('session')),
            'time': _text(e.get('time'), 40),
            'counter': max(1, _int(e.get('counter'), 1)),
        })
    return _int(db.get('session')), out


def is_amisia(err):
    return 'Amisia' in err['message'] or 'Amisia' in err['stack']


def where(err, prefer='Amisia'):
    """"Amisia/Core/Core.lua:12" of the first frame in message or stack, Amisia's own first."""
    frames = FRAME.findall(err['message'] + '\n' + err['stack'])
    if not frames:
        return '?'
    pick = next((fr for fr in frames if prefer and prefer in fr[0]), frames[0])
    path = PREFIX.sub('', pick[0].replace('\\', '/')).lstrip('@ ')
    return f'{path}:{pick[1]}'


def addon_of(err):
    w = where(err, prefer=None)
    return w.split('/')[0] if '/' in w else '?'


def first_line(text, limit=160):
    line = (text.strip().splitlines() or [''])[0]
    line = re.sub(r'\|c[0-9a-fA-F]{8}|\|r', '', line)
    return line if len(line) <= limit else line[:limit - 3] + '...'


def lines(errors, session=None, all_=False):
    """One line per error: count, where, the message's first line, session and time."""
    out = []
    for e in errors:
        tag = '' if session is None or e['session'] != session else ', diese Sitzung'
        head = f'{e["counter"]}x' if e['counter'] > 1 else '1x'
        where_ = where(e, prefer=None if all_ else 'Amisia')
        out.append(f'{head:>4}  {where_}  {first_line(e["message"])}  (Sitzung {e["session"]}{tag}, {e["time"] or "?"})')
    return out


def amisia_errors(path=DEFAULT_SV):
    """(session, Amisia's errors) or None when the file is missing; Unreadable passes through."""
    if not path or not os.path.exists(path):
        return None
    session, errors = load(path)
    return session, [e for e in errors if is_amisia(e)]


def report(path=DEFAULT_SV, all_=False):
    """The text of `build.py errors` and its exit code."""
    if not os.path.exists(path):
        return f'Keine Fehlerdatei: {path}', 0
    try:
        session, errors = load(path)
    except Unreadable as e:
        return f'Fehlerdatei nicht lesbar: {e}', 1
    shown = errors if all_ else [e for e in errors if is_amisia(e)]
    what = 'aller Addons' if all_ else 'von Amisia'
    head = f'Fehler aus dem Spiel {what}: {len(shown)} (von {len(errors)} in der Datei, aktuelle Sitzung {session})'
    return '\n'.join([head] + lines(shown, session, all_)), 0
