#!/usr/bin/env python3
"""Builds and checks Amisia's data by itself when a new client build's tables are there.

Run every 15 minutes by the systemd user timer amisia-auto-data.timer (tools/systemd/). Two triggers,
whichever sees a new build first wins (DECISIONS D-51, D-103):

A. the PC's export (D-51):
   1. the newest client build in ~/addons/_wago whose export is complete: its _export.<build>.txt names
      every table it exported with "ok", each <Table>.<build>.csv is there, and nothing of that build
      changed in the last 5 minutes (Syncthing may still be sending);
   2. stops when the data on main is already of that build (the build line of Data/TalentData.lua) or
      this build was tried already (the state file).
B. the daily look at wago.tools (D-103), when A has nothing to build: at most once a day (the time and
   the answer of the last look in ~/addons/_auto/amisia-wago.json) `tools/fetch_tables.py --latest` asks
   the site's API once for the newest wowf build; when that is newer than main's data, not built on a
   branch and not tried, `tools/fetch_tables.py --version <build>` fetches its tables (the tool's rules:
   one request at a time, nothing twice). A fetch with errors in its manifest, or without a table the
   last fetched build had, is incomplete: a line in the status file and nothing built (the next look
   tries again; the tables already fetched are not asked for again). A failed look (network, an answer
   the tool does not expect) is a line in the status file too. Off with the file
   ~/addons/_auto/amisia-wago.off or AMISIA_AUTO_WAGO=0 in the environment.

Then, for either trigger, in its own worktree (~/addons/.amisia-auto) on branch auto/data-<build> from
main: `build.py data` (the newest copy of each client table, tools/client_tables.py; it fetches nothing),
then `build.py check`, and commits the result on that branch; tools/build_diff.py compares the tables of
main's build with the new one ("new in this build": its first lines into the status file, the whole
report into ~/addons/_auto/amisia-data-diff.txt); the outcome goes to ~/addons/_auto/amisia-data.txt
(read by Claude at the start of a session, CLAUDE.md) and the worktree is removed again (the branch
stays).

It never pushes, never merges into main and never releases: the user starts the release (DECISIONS
D-51). `--dry-run` only says what it would do; `--force` tries the newest export again; `--look-now`
looks at wago.tools even when the last look is less than a day old.
"""
import argparse
import datetime
import fcntl
import json
import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WAGO = os.path.expanduser('~/addons/_wago')
STATE_DIR = os.path.expanduser('~/addons/_auto')
WORKTREE = os.path.expanduser('~/addons/.amisia-auto')
SETTLE = 300            # seconds without a change before a build counts as complete
BUILD = re.compile(r'^_export\.(\d+\.\d+\.\d+\.\d+)\.txt$')
TALENT_BUILD = re.compile(r'^build="(\d+\.\d+\.\d+\.\d+)"', re.M)
TRAILER = 'Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
FETCHED = os.path.expanduser('~/addons/_cache/wago')   # tools/client_tables.FETCHED, fetch_tables.OUT
PRODUCT = 'wowf'                                       # fetch_tables.PRODUCT
DAILY = 24 * 3600                                      # seconds between two looks at wago.tools
WAGO_STATE = 'amisia-wago.json'
WAGO_OFF_FILE = 'amisia-wago.off'
WAGO_OFF_ENV = 'AMISIA_AUTO_WAGO'
WAGO_LINE = 'wago.tools (täglich'
DIFF_FILE = 'amisia-data-diff.txt'
VERSION = re.compile(r'^\d+\.\d+\.\d+\.\d+$')


def build_key(b):
    return tuple(int(x) for x in b.split('.'))


def complete_builds(wago, now=None, settle=SETTLE):
    """The builds of the folder whose export is complete and settled, oldest first."""
    now = time.time() if now is None else now
    out = []
    try:
        names = os.listdir(wago)
    except OSError:
        return out
    for name in names:
        m = BUILD.match(name)
        if not m:
            continue
        b = m.group(1)
        files = [os.path.join(wago, name)]
        ok = True
        with open(files[0], encoding='utf-8', errors='replace') as fh:
            for line in fh:
                parts = line.rstrip('\n').split('\t')
                if len(parts) >= 2 and parts[1] == 'ok':
                    csv = os.path.join(wago, f'{parts[0]}.{b}.csv')
                    if not os.path.isfile(csv):
                        ok = False
                        break
                    files.append(csv)
        if not ok or len(files) < 2:
            continue
        if any(now - os.path.getmtime(f) < settle for f in files):
            continue
        out.append(b)
    return sorted(out, key=build_key)


def data_args(wago):
    """The --wago of `build.py data`: none for the export folder, so the build takes the newest copy of each
    table (tools/client_tables.py, D-101: the export, the wago.tools exports, AllTheThings' copies); a
    folder given to this script is handed on."""
    return [] if os.path.abspath(os.path.expanduser(wago)) == os.path.abspath(WAGO) else ['--wago', wago]


def data_build(text):
    """The client build Data/TalentData.lua was built from, or None."""
    m = TALENT_BUILD.search(text or '')
    return m.group(1) if m else None


def git(*args, cwd=ROOT, check=True):
    p = subprocess.run(['git', *args], cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if check and p.returncode != 0:
        raise RuntimeError(f'git {" ".join(args)}: {p.stdout.strip()}')
    return p.stdout


def run(cmd, cwd):
    p = subprocess.run(cmd, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    return p.returncode, p.stdout


def load_state(path):
    try:
        with open(path, encoding='utf-8') as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {}


def write_report(state_dir, state, lines):
    os.makedirs(state_dir, exist_ok=True)
    with open(os.path.join(state_dir, 'amisia-data.json'), 'w', encoding='utf-8') as fh:
        json.dump(state, fh, indent=1)
    with open(os.path.join(state_dir, 'amisia-data.txt'), 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(lines) + '\n')


def remove_worktree(path):
    if os.path.exists(path):
        git('worktree', 'remove', '--force', path, check=False)
    git('worktree', 'prune', check=False)


def tail(text, n=15):
    return [ln for ln in text.splitlines() if ln.strip()][-n:]


# ---------------------------------------------------------------- the daily look at wago.tools (D-103)
def wago_on(state_dir, env=None):
    """The daily look is on unless ~/addons/_auto/amisia-wago.off exists or AMISIA_AUTO_WAGO is 0/off/no."""
    env = os.environ if env is None else env
    if str(env.get(WAGO_OFF_ENV, '')).strip().lower() in ('0', 'off', 'no', 'false'):
        return False
    return not os.path.exists(os.path.join(state_dir, WAGO_OFF_FILE))


def look_due(state, now):
    """True when the last look (state['at'], seconds) is a day or more ago, or there was none."""
    at = state.get('at')
    return not isinstance(at, (int, float)) or now - at >= DAILY


def ask_latest(py=None):
    """(newest wowf build or None, why not): one run of `tools/fetch_tables.py --latest` (its own
    functions and checks; this script names no address of the site)."""
    rc, out = run([py or sys.executable, os.path.join('tools', 'fetch_tables.py'), '--latest'], ROOT)
    lines = [ln.strip() for ln in out.splitlines() if ln.strip()]
    if rc == 0 and lines and VERSION.match(lines[-1]):
        return lines[-1], None
    return None, (lines[-1] if lines else f'exit {rc}')[:160]


def fetch_build(version, out_dir, py=None):
    """(exit code, output) of `tools/fetch_tables.py --version <build> --out <dir>`."""
    return run([py or sys.executable, os.path.join('tools', 'fetch_tables.py'), '--version', version,
                '--out', out_dir], ROOT)


def manifest_of(out_dir, version):
    return load_state(os.path.join(out_dir, f'_fetch.{PRODUCT}.{version}.json'))


def fetch_problems(out_dir, version):
    """Why the fetch of version is not complete (a list of short English texts; empty when it is): no
    manifest, errors in it, or a table the last fetched build before it had and this one lacks."""
    man = manifest_of(out_dir, version)
    if not man.get('tables'):
        return ['no manifest or no table fetched']
    out = [f'{t}: {w}' for t, w in sorted((man.get('errors') or {}).items())]
    older = []
    try:
        names = os.listdir(out_dir)
    except OSError:
        names = []
    for name in names:
        m = re.match(r'^_fetch\.' + PRODUCT + r'\.(\d+\.\d+\.\d+\.\d+)\.json$', name)
        if m and build_key(m.group(1)) < build_key(version):
            older.append(m.group(1))
    if older:
        prev = manifest_of(out_dir, max(older, key=build_key))
        lost = sorted(set(prev.get('tables') or {}) - set(man['tables']))
        out += [f'{t}: missing (the fetch of {max(older, key=build_key)} had it)' for t in lost]
    return out


def branch_exists(branch):
    return bool(git('rev-parse', '--verify', '--quiet', f'refs/heads/{branch}', check=False).strip())


def set_status_line(state_dir, line):
    """Puts the one line of the daily look into amisia-data.txt, keeping the rest of it."""
    path = os.path.join(state_dir, 'amisia-data.txt')
    try:
        with open(path, encoding='utf-8') as fh:
            lines = [ln for ln in fh.read().splitlines() if not ln.startswith(WAGO_LINE)]
    except OSError:
        lines = []
    while lines and not lines[-1].strip():
        lines.pop()
    os.makedirs(state_dir, exist_ok=True)
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(lines + ([''] if lines else []) + [line]) + '\n')


def daily_look(args, on_main, state, now=None, ask=ask_latest, fetch=fetch_build, built=branch_exists,
               build=None, log=print):
    """Trigger B (see the module's text). Returns the exit code; never builds a half-fetched build."""
    now = time.time() if now is None else now
    if not wago_on(args.state_dir):
        log(f'daily look at wago.tools off ({WAGO_OFF_FILE} in {args.state_dir} or {WAGO_OFF_ENV}=0)')
        return 0
    path = os.path.join(args.state_dir, WAGO_STATE)
    look = load_state(path)
    if not look_due(look, now) and not args.look_now:
        log(f'wago.tools looked at {look.get("when")}: {look.get("answer") or look.get("error")}; next look a day later')
        return 0
    if args.dry_run:
        log(f'would ask wago.tools for the newest {PRODUCT} build (main has {on_main})')
        return 0
    when = datetime.datetime.fromtimestamp(now).strftime('%Y-%m-%d %H:%M')
    version, why = ask()
    look = {'at': now, 'when': when, 'answer': version, 'error': why, 'result': None,
            'build': look.get('build'), 'build_result': look.get('build_result')}

    def save():
        os.makedirs(args.state_dir, exist_ok=True)
        with open(path, 'w', encoding='utf-8') as fh:
            json.dump(look, fh, indent=1)

    def done(result, line):
        look['result'], look['line'] = result, f'{WAGO_LINE}, {when}): {line}'
        save()
        set_status_line(args.state_dir, look['line'])
        log(line)
        return 0
    save()      # the look counts even when what follows breaks off: once a day stays once a day
    if not version:
        return done('no answer', f'keine Antwort ({why}); nächster Blick morgen.')
    branch = f'auto/data-{version}'
    if on_main and build_key(on_main) >= build_key(version):
        return done('nothing new', f'neuester Build {version}, die Daten auf main sind von {on_main}: nichts Neues.')
    if built(branch) or (version in (look.get('build'), state.get('build')) and not args.force):
        return done('built already', f'neuester Build {version}, schon gebaut oder versucht (Branch {branch}).')
    fetch(version, args.fetched)     # its manifest says whether it is complete
    problems = fetch_problems(args.fetched, version)
    if problems:
        return done('fetch incomplete', f'neuer Build {version}, Tabellen unvollständig geladen ('
                    + '; '.join(problems[:4]) + (' ...' if len(problems) > 4 else '')
                    + '): nichts gebaut, nächster Blick morgen.')
    look['build'] = version
    rc = (build or build_branch)(args, version, on_main, 'wago.tools')
    look['build_result'] = 'ok' if rc == 0 else 'failed'
    done('built', f'neuer Build {version} von wago.tools geladen und gebaut ('
         + ('Prüfung grün' if rc == 0 else 'FEHLER') + f', Branch {branch}).')
    return rc


# ---------------------------------------------------------------- the build of a new client build
def diff_lines(old, new, state_dir):
    """The short head of tools/build_diff.py (old against new) for the status file; the whole report
    goes to amisia-data-diff.txt beside it. Never fails the build: a problem is one line."""
    if not old or not new:
        return []
    try:
        import build_diff
        short, full = build_diff.report(old, new)
        with open(os.path.join(state_dir, DIFF_FILE), 'w', encoding='utf-8') as fh:
            fh.write('\n'.join(full) + '\n')
        return ['', f'Neu in diesem Build (tools/build_diff.py; ganz in {os.path.join(state_dir, DIFF_FILE)}):'] + short[1:]
    except Exception as e:      # the report is a help, the build's outcome matters more
        return ['', f'Neu in diesem Build: kein Bericht ({type(e).__name__}: {e})']


def build_branch(args, newest, on_main, trigger):
    """Builds and checks newest on branch auto/data-<newest> in the worktree and writes the report.
    Returns 0 when the check is green."""
    branch = f'auto/data-{newest}'
    started = datetime.datetime.now().strftime('%Y-%m-%d %H:%M')
    remove_worktree(args.worktree)
    git('worktree', 'add', '--force', '-B', branch, args.worktree, args.base)
    py = sys.executable
    result, lines, commit = 'failed', [], None
    # the export folder only when the PC's export started it with a folder of its own; a build of
    # wago.tools always takes the choice of tools/client_tables.py
    wago_args = data_args(args.wago) if trigger == 'export' else []
    try:
        rc, out = run([py, 'tools/build.py', 'data'] + wago_args, args.worktree)
        if rc != 0:
            lines = ['build.py data ist fehlgeschlagen:'] + tail(out)
        else:
            rc, out = run([py, 'tools/build.py', 'check'], args.worktree)
            changed = git('status', '--porcelain', '--untracked-files=no', cwd=args.worktree).strip()
            if changed:
                git('add', '-A', 'Amisia/Data', 'tools', cwd=args.worktree)
                msg = (f'Daten für Client-Build {newest} (automatisch gebaut, Prüfung '
                       f'{"grün" if rc == 0 else "rot"})\n\n{TRAILER}\n')
                subprocess.run(['git', 'commit', '-q', '-F', '-'], cwd=args.worktree, input=msg, text=True, check=True)
                commit = git('rev-parse', '--short', 'HEAD', cwd=args.worktree).strip()
            if rc == 0:
                result = 'ok'
                lines = [f'Prüfung grün. Branch {branch}' + (f' ({commit})' if commit else ' (keine Änderung)') + '.',
                         'Zum Veröffentlichen: Branch nach main mergen (oder build.py data auf main), dann build.py release.']
            else:
                lines = [f'build.py check ist rot. Branch {branch}' + (f' ({commit})' if commit else '') + ':'] + tail(out)
        stat = git('diff', '--stat', args.base, branch, check=False).strip().splitlines()
        lines += [''] + stat[-12:]
    finally:
        remove_worktree(args.worktree)
    lines += diff_lines(on_main, newest, args.state_dir)
    state = {'build': newest, 'branch': branch, 'commit': commit, 'result': result, 'at': started,
             'main': on_main, 'trigger': trigger}
    head = f'Amisia-Daten für Client-Build {newest} ({started}): ' + ('bereit' if result == 'ok' else 'FEHLER')
    source = 'Export des PCs' if trigger == 'export' else 'von wago.tools geladen'
    write_report(args.state_dir, state, [head, f'{args.base} hat Daten von {on_main}. Tabellen: {source}.'] + lines)
    last = load_state(os.path.join(args.state_dir, WAGO_STATE)).get('line')
    if last:    # the line of the last look stays in the status file
        set_status_line(args.state_dir, last)
    print(head)
    return 0 if result == 'ok' else 1


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--wago', default=WAGO)
    ap.add_argument('--fetched', default=FETCHED, help=f'where tools/fetch_tables.py puts the tables (default {FETCHED})')
    ap.add_argument('--state-dir', default=STATE_DIR)
    ap.add_argument('--worktree', default=WORKTREE)
    ap.add_argument('--base', default='main', help='the branch the data is built on (default main)')
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--force', action='store_true', help='try the newest build again')
    ap.add_argument('--look-now', action='store_true', help='look at wago.tools even when the last look is not a day old')
    args = ap.parse_args(argv)

    os.makedirs(args.state_dir, exist_ok=True)
    lock = open(os.path.join(args.state_dir, 'amisia-data.lock'), 'w')
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        print('another run is busy')
        return 0

    on_main = data_build(git('show', f'{args.base}:Amisia/Data/TalentData.lua', check=False))
    state = load_state(os.path.join(args.state_dir, 'amisia-data.json'))
    builds = complete_builds(args.wago)
    newest = builds[-1] if builds else None
    if not newest:
        print('no complete export in', args.wago)
    elif on_main and build_key(on_main) >= build_key(newest):
        print(f'{args.base} has the data of {on_main}; newest export {newest}')
    elif state.get('build') == newest and not args.force:
        print(f'{newest} tried already ({state.get("result")}); --force to try again')
    elif args.dry_run:
        print(f'would build {newest} on auto/data-{newest} ({args.base} has {on_main})')
        return 0
    else:
        return build_branch(args, newest, on_main, 'export')
    # trigger B: the PC's export had nothing to build
    return daily_look(args, on_main, state)


if __name__ == '__main__':
    sys.exit(main())
