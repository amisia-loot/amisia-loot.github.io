"""Amisia's measurements of its own CPU time (/amisia leistung, F-184, D-116), from the SavedVariables
the PC sends to the N100.

    python3 tools/build.py perf [--sv FILE] [--rows N]

The file (`~/addons/_SavedVariables/Amisia.lua`, receive-only, read only) holds
`AmisiaDB.perf = { v = 1, arm, runs = { newest first } }` (Core/PerfReport.lua names every field). It
runs in the same sandbox as the scan builds (`build_scan.run_sv`); every field is read defensively.
Prints the runs newest first: a head per run and its rows (own time, the costliest first).
"""
import datetime
import os
import sys

DEFAULT_SV = os.path.expanduser('~/addons/_SavedVariables/Amisia.lua')
BUDGET_MS = 1000 / 60   # one frame at 60 fps
KINDS = {'hand': 'von Hand', 'login': 'Login'}
STOPS = {'hand': 'von Hand', 'time': 'nach der gewählten Zeit', 'cap': 'nach 60 min (Obergrenze)', 'logout': 'beim Ausloggen'}


class Unreadable(ValueError):
    pass


def _num(v, default=0.0):
    try:
        return float(v)
    except (TypeError, ValueError):
        return default


def _text(v, limit=200):
    if v is None:
        return ''
    if isinstance(v, bytes):
        v = v.decode('utf-8', 'replace')
    return str(v)[:limit]


def _list(v):
    """A Lua list as a Python list (a list with holes comes over as a dict keyed by number)."""
    if isinstance(v, list):
        return v
    if isinstance(v, dict):
        return [v[k] for k in sorted((k for k in v if isinstance(k, int)))]
    return []


def _dict(v):
    return v if isinstance(v, dict) else {}


def load(path=DEFAULT_SV):
    """The saved runs, newest first, as dicts. Raises Unreadable when the file does not run in the
    sandbox or holds no AmisiaDB table."""
    tools = os.path.dirname(os.path.abspath(__file__))
    if tools not in sys.path:
        sys.path.insert(0, tools)
    import build_scan
    with open(path, 'rb') as fh:
        text = fh.read().decode('utf-8', 'replace')
    try:
        env, err = build_scan.run_sv(text, os.path.basename(path))
    except Exception as e:  # lupa errors of any kind
        raise Unreadable(f'{path}: {e}') from None
    if env is None:
        raise Unreadable(f'{path}: {err}')
    db = env['AmisiaDB']
    if db is None or not hasattr(db, 'items'):
        raise Unreadable(f'{path}: no AmisiaDB table')
    perf = db['perf']
    if perf is None or not hasattr(perf, 'items'):
        return []
    perf = build_scan.lua_to_py(perf)
    return [r for r in _list(_dict(perf).get('runs')) if isinstance(r, dict)]


def _de(x, decimals=1):
    return f'{x:.{decimals}f}'.replace('.', ',')


def _ms(v):
    if v is None or v == '':
        return '?'
    x = _num(v)
    return _de(x, 2 if x < 10 else 0)


def _mb(v):
    return '?' if v is None else _de(_num(v) / 1024, 1) + ' MB'


def _duration(s):
    s = int(round(_num(s)))
    return f'{s} s' if s < 60 else f'{s // 60} min {s % 60:02d} s'


def _when(at):
    if _num(at) <= 0:
        return '?'
    try:
        return datetime.datetime.fromtimestamp(int(_num(at))).strftime('%Y-%m-%d %H:%M')
    except (OverflowError, OSError, ValueError):
        return '?'


def run_lines(run, index, rows=20):
    """The lines of one run: its head and up to rows rows."""
    dur = max(_num(run.get('dur')), 0.001)
    fr = int(_num(run.get('fr')))
    ms = _num(run.get('ms'))
    per_frame = ms / fr if fr > 0 else 0.0
    out = [
        f'Lauf {index}: {_when(run.get("at"))} · {KINDS.get(run.get("kind"), _text(run.get("kind"), 20))} · '
        f'{_duration(run.get("dur"))} · beendet {STOPS.get(run.get("stop"), _text(run.get("stop"), 20))} · '
        f'Amisia {_text(run.get("v"), 20)} · Client {_text(run.get("b"), 30)} · {_text(run.get("g"), 10)} · '
        f'wo {_text(run.get("where"), 40) or "?"}',
        f'  Frames {fr} ({_de(fr / dur, 1)} fps), im Kampf {_duration(run.get("cb"))}; Amisia {_de(ms / dur, 2)} ms/s, '
        f'{_de(per_frame, 3)} ms/Frame ({_de(per_frame / BUDGET_MS * 100, 1)} % von 16,7 ms); '
        f'{int(_num(run.get("n")))} Aufrufe, {int(_num(run.get("sp")))} über 5 ms; Müll {_de(_num(run.get("kb")) / dur, 1)} KB/s',
    ]
    mem = _dict(run.get('mem'))
    out.append(f'  Speicher: Amisia {_mb(mem.get("a0"))} -> {_mb(mem.get("a1"))}, alle Addons {_mb(mem.get("l0"))} -> {_mb(mem.get("l1"))}')
    ld = _dict(run.get('load'))
    out.append(f'  Laden: Dateien {_ms(ld.get("files"))} ms, ADDON_LOADED {_ms(ld.get("al"))}, PLAYER_LOGIN {_ms(ld.get("pl"))}, '
               f'PLAYER_ENTERING_WORLD {_ms(ld.get("pew"))}, andere Ereignisse {_ms(ld.get("ev"))}')
    data = [d for d in _list(run.get('data')) if isinstance(d, dict)]
    if data:
        parts = [f'{_text(d.get("k"), 40)} {_ms(d.get("ms"))} ms{" (in der Messung)" if d.get("run") else ""}' for d in data]
        out.append('  Daten: ' + ', '.join(parts))
    rs = [r for r in _list(run.get('rows')) if isinstance(r, dict)]
    rs.sort(key=lambda r: (-_num(r.get('ms')), -_num(r.get('n')), _text(r.get('l'))))
    if not rs:
        out.append('  keine Aufrufe gemessen')
        return out
    out.append(f'  {"ms":>9} {"Aufrufe":>8} {"ms/Aufruf":>10} {"max ms":>8} {">5ms":>5} {"KB":>8} {"inkl. ms":>9}  Stelle')
    for r in rs[:rows]:
        n = int(_num(r.get('n')))
        out.append(f'  {_num(r.get("ms")):9.2f} {n:8d} {_num(r.get("ms")) / max(n, 1):10.3f} {_num(r.get("max")):8.2f} '
                   f'{int(_num(r.get("sp"))):5d} {_num(r.get("kb")):8.1f} {_num(r.get("inc")):9.2f}  {_text(r.get("l"), 80)}')
    if len(rs) > rows:
        out.append(f'  ... und {len(rs) - rows} weitere Zeilen (--rows {len(rs)})')
    return out


def report(path=DEFAULT_SV, rows=20):
    """The text of `build.py perf` and its exit code."""
    if not os.path.exists(path):
        return f'Keine Datei: {path}', 0
    try:
        runs = load(path)
    except Unreadable as e:
        return f'Datei nicht lesbar: {e}', 1
    if not runs:
        return 'Noch keine Messung gespeichert (/amisia leistung im Spiel, dann ausloggen).', 0
    out = [f'Messungen von Amisia: {len(runs)} (neueste zuerst; Zeiten sind eigene Zeit ohne die gemessenen Aufrufe darin)']
    for i, run in enumerate(runs, 1):
        out.append('')
        out += run_lines(run, i, rows)
    return '\n'.join(out), 0
