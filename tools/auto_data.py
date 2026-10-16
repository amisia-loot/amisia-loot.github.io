#!/usr/bin/env python3
"""Builds and checks Amisia's data by itself when the PC has exported the tables of a new client build.

Run every 15 minutes by the systemd user timer amisia-auto-data.timer (tools/systemd/). Steps:

1. the newest client build in ~/addons/_wago whose export is complete: its _export.<build>.txt names
   every table it exported with "ok", each <Table>.<build>.csv is there, and nothing of that build
   changed in the last 5 minutes (Syncthing may still be sending);
2. stops when the data on main is already of that build (the build line of Data/TalentData.lua) or
   this build was tried already (the state file);
3. otherwise, in its own worktree (~/addons/.amisia-auto) on branch auto/data-<build> from main:
   `build.py data`, then `build.py check`, and commits the result on that branch;
4. writes the outcome to ~/addons/_auto/amisia-data.txt (read by Claude at the start of a session,
   CLAUDE.md) and removes the worktree again (the branch stays).

It never pushes, never merges into main and never releases: the user starts the release (DECISIONS
D-51). `--dry-run` only says what it would do; `--force` tries the build again.
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


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--wago', default=WAGO)
    ap.add_argument('--state-dir', default=STATE_DIR)
    ap.add_argument('--worktree', default=WORKTREE)
    ap.add_argument('--base', default='main', help='the branch the data is built on (default main)')
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--force', action='store_true', help='try the newest build again')
    args = ap.parse_args(argv)

    os.makedirs(args.state_dir, exist_ok=True)
    lock = open(os.path.join(args.state_dir, 'amisia-data.lock'), 'w')
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        print('another run is busy')
        return 0

    builds = complete_builds(args.wago)
    if not builds:
        print('no complete export in', args.wago)
        return 0
    newest = builds[-1]
    on_main = data_build(git('show', f'{args.base}:Amisia/Data/TalentData.lua', check=False))
    state = load_state(os.path.join(args.state_dir, 'amisia-data.json'))
    if on_main and build_key(on_main) >= build_key(newest):
        print(f'{args.base} has the data of {on_main}; newest export {newest}')
        return 0
    if state.get('build') == newest and not args.force:
        print(f'{newest} tried already ({state.get("result")}); --force to try again')
        return 0
    branch = f'auto/data-{newest}'
    if args.dry_run:
        print(f'would build {newest} on {branch} ({args.base} has {on_main})')
        return 0

    started = datetime.datetime.now().strftime('%Y-%m-%d %H:%M')
    remove_worktree(args.worktree)
    git('worktree', 'add', '--force', '-B', branch, args.worktree, args.base)
    py = sys.executable
    result, lines, commit = 'failed', [], None
    try:
        rc, out = run([py, 'tools/build.py', 'data', '--wago', args.wago], args.worktree)
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
    state = {'build': newest, 'branch': branch, 'commit': commit, 'result': result, 'at': started,
             'main': on_main}
    head = f'Amisia-Daten für Client-Build {newest} ({started}): ' + ('bereit' if result == 'ok' else 'FEHLER')
    write_report(args.state_dir, state, [head, f'{args.base} hat Daten von {on_main}.'] + lines)
    print(head)
    return 0 if result == 'ok' else 1


if __name__ == '__main__':
    sys.exit(main())
