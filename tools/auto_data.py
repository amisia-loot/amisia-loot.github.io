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

C. the user's SavedVariables (D-122), when A and B have nothing to build and no new client build waits (an
   export of a build newer than main's data, not tried, its report less than a day old; or a wago.tools
   fetch that came back incomplete): ~/addons/_SavedVariables/Amisia.lua (Syncthing brings it after every
   logout; only read) differs from the file taken over last (size and mtime first, the SHA-256 of its
   content decides; ~/addons/_auto/amisia-sv.json), has not changed for SV_SETTLE seconds and the last run
   of this trigger is SV_GAP hours ago or more. Then in the same worktree, detached at main: `build.py data
   --sv <file>`; when no archive and no generated file changed, one line "nichts Neues" and no branch;
   otherwise `build.py check`, a commit, and branch auto/sv-<YYYY-MM-DD> (the date of the run) set to that
   commit; a second run on the same day starts from main again and moves the day's branch (the newest file
   holds everything the earlier one had). Only the newest SV_KEEP auto/sv-* branches stay. What the file
   added against main (new and changed entries per archive, the changed files) and the check's outcome go
   into a block "Spielstand vom ..." of amisia-data.txt, kept under every later build report. Off with
   ~/addons/_auto/amisia-sv.off or AMISIA_AUTO_SV=0; `--force-sv` takes the file over now (no gap, even
   when it was taken over already).

Before the triggers: a report about a client build whose data main has by now (merged, or built by hand)
is replaced by one line that says so.

It never pushes, never merges into main and never releases: the user starts the release (DECISIONS
D-51, D-122). `--dry-run` only says what it would do; `--force` tries the newest export again; `--look-now`
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
# trigger C, the SavedVariables (D-122)
SV_FILE = os.path.expanduser('~/addons/_SavedVariables/Amisia.lua')
SV_STATE = 'amisia-sv.json'
SV_OFF_FILE = 'amisia-sv.off'
SV_OFF_ENV = 'AMISIA_AUTO_SV'
SV_SETTLE = 300                 # seconds the file must be unchanged (Syncthing may still be writing)
SV_GAP = 6 * 3600               # seconds between two runs of trigger C: one evening of logouts, one build
SV_KEEP = 5                     # auto/sv-* branches kept; older ones are deleted
SV_BRANCH = 'auto/sv-'
SV_HEAD = 'Spielstand vom '     # first line of the block in amisia-data.txt
SV_PATHS = ('Amisia_Gear/Data', 'tools', 'Amisia-Website')   # what a data build may change
# what "new" counts: (archive, key, label); key "a/*" sums the dicts under a (one per locale)
SV_COUNTS = (
    ('tools/scan_archive.json', 'items', 'Items'),
    ('tools/scan_archive.json', 'sources', 'Item-Quellen'),
    ('tools/scan_archive.json', 'quests/*', 'Questnamen'),
    ('tools/scan_archive.json', 'npcs/*', 'NPC-Namen'),
    ('tools/quest_obs.json', 'q', 'Quests beobachtet'),
    ('tools/quest_item_archive.json', 'links', 'Quest-Items'),
    ('tools/quest_tag_archive.json', 'tags', 'Quest-Merkmale'),
    ('tools/entrance_archive.json', 'entrances', 'Eingänge'),
    ('tools/trainer_archive.json', 'trainers', 'Lehrer'),
    ('tools/drop_obs.json', 'k', 'Kills'),
)


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


def git(*args, cwd=None, check=True):
    p = subprocess.run(['git', *args], cwd=cwd or ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
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


def split_status(state_dir):
    """amisia-data.txt in its three parts: (the build report's lines, the lines of the block "Spielstand
    vom ..." (D-122; it holds no empty line), the line of the daily look or None)."""
    try:
        with open(os.path.join(state_dir, 'amisia-data.txt'), encoding='utf-8') as fh:
            lines = fh.read().splitlines()
    except OSError:
        lines = []
    rest, block, look, inside = [], [], None, False
    for ln in lines:
        if ln.startswith(WAGO_LINE):
            look, inside = ln, False
        elif ln.startswith(SV_HEAD):
            block, inside = [ln], True
        elif inside and ln.strip():
            block.append(ln)
        else:
            inside = False
            rest.append(ln)
    while rest and not rest[-1].strip():
        rest.pop()
    return rest, block, look


def write_status(state_dir, rest, block, look):
    """The build report, then the block of the SavedVariables, then the line of the look, an empty line
    between them."""
    out = list(rest)
    for part in (block, [look] if look else []):
        if part:
            out += ([''] if out else []) + list(part)
    os.makedirs(state_dir, exist_ok=True)
    with open(os.path.join(state_dir, 'amisia-data.txt'), 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(out) + '\n')


def set_status_line(state_dir, line):
    """Puts the one line of the daily look into amisia-data.txt, keeping the rest of it."""
    rest, block, _ = split_status(state_dir)
    write_status(state_dir, rest, block, line)


def set_sv_block(state_dir, lines):
    """Puts the block of the SavedVariables into amisia-data.txt, keeping the build report and the look."""
    rest, _, look = split_status(state_dir)
    write_status(state_dir, rest, lines, look)


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
                git('add', '-A', *present(args.worktree, SV_PATHS), cwd=args.worktree)
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
    # the block of the last SavedVariables and the line of the last look stay in the status file
    write_status(args.state_dir, split_status(args.state_dir)[0],
                 load_state(os.path.join(args.state_dir, SV_STATE)).get('lines') or [],
                 load_state(os.path.join(args.state_dir, WAGO_STATE)).get('line'))
    print(head)
    return 0 if result == 'ok' else 1


def present(root, paths):
    """The paths of paths that exist under root (git add stops on a path that matches nothing)."""
    return [p for p in paths if os.path.exists(os.path.join(root, p))]


def settle_stale(args, on_main, state, now=None, log=print):
    """When main has the data of the client build the report talks about (merged, or built by hand), the
    report is replaced by one line saying so (once; the block of the SavedVariables and the look stay).
    True when it did (or would, with --dry-run)."""
    b = state.get('build')
    if (not b or not on_main or state.get('settled') or not VERSION.match(str(b)) or not VERSION.match(on_main)
            or build_key(on_main) < build_key(b)):
        return False
    when = datetime.datetime.fromtimestamp(time.time() if now is None else now).strftime('%Y-%m-%d %H:%M')
    line = (f'Amisia-Daten für Client-Build {b}: {args.base} hat diese Daten inzwischen (bemerkt {when}); '
            f'der Bericht vom {state.get("at")} ({"bereit" if state.get("result") == "ok" else "FEHLER"}, '
            f'Branch {state.get("branch")}) ist erledigt.')
    if args.dry_run:
        log('would replace the report of ' + b + ': ' + line)
        return True
    state['settled'] = when
    with open(os.path.join(args.state_dir, 'amisia-data.json'), 'w', encoding='utf-8') as fh:
        json.dump(state, fh, indent=1)
    _, block, look = split_status(args.state_dir)
    write_status(args.state_dir, [line], block, look)
    log(line)
    return True


# ---------------------------------------------------------------- trigger C: the SavedVariables (D-122)
def sv_on(state_dir, env=None):
    """Trigger C is on unless ~/addons/_auto/amisia-sv.off exists or AMISIA_AUTO_SV is 0/off/no."""
    env = os.environ if env is None else env
    if str(env.get(SV_OFF_ENV, '')).strip().lower() in ('0', 'off', 'no', 'false'):
        return False
    return not os.path.exists(os.path.join(state_dir, SV_OFF_FILE))


def file_hash(path):
    import hashlib
    h = hashlib.sha256()
    with open(path, 'rb') as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def stamp(t):
    return datetime.datetime.fromtimestamp(t).strftime('%Y-%m-%d %H:%M')


def build_waiting(args, on_main, state, now=None):
    """Why a new client build comes before the SavedVariables (a short German text), or None: an export of
    a build newer than main's data that was not tried yet (still arriving or incomplete; its report less
    than a day old), or a fetch of wago.tools that came back incomplete for a build newer than main's."""
    now = time.time() if now is None else now
    newer = lambda b: VERSION.match(str(b or '')) and (not on_main or build_key(b) > build_key(on_main))
    try:
        names = os.listdir(args.wago)
    except OSError:
        names = []
    for name in names:
        m = BUILD.match(name)
        if m and newer(m.group(1)) and m.group(1) != state.get('build'):
            try:
                young = now - os.path.getmtime(os.path.join(args.wago, name)) < DAILY
            except OSError:
                young = False
            if young:
                return f'der Export von Client-Build {m.group(1)} ist noch nicht fertig'
    look = load_state(os.path.join(args.state_dir, WAGO_STATE))
    if look.get('result') == 'fetch incomplete' and newer(look.get('answer')) and look.get('answer') != state.get('build'):
        return f'die Tabellen von Client-Build {look.get("answer")} sind unvollständig geladen'
    return None


def json_at(text):
    try:
        out = json.loads(text) if text else {}
    except ValueError:
        return {}
    return out if isinstance(out, dict) else {}


def entries(arch, key):
    """{name: value} of one counted part of an archive; "a/*" joins the dicts under a (locale/name)."""
    if key.endswith('/*'):
        out = {}
        for loc, part in (arch.get(key[:-2]) or {}).items():
            if isinstance(part, dict):
                out.update({f'{loc}/{k}': v for k, v in part.items()})
        return out
    part = arch.get(key)
    if isinstance(part, list):
        return {json.dumps(v, sort_keys=True): True for v in part}
    return part if isinstance(part, dict) else {}


def archive_news(base, worktree):
    """What the data build added to the archives against base: ['312 Items', '4 Kills (1 geändert)', ...],
    new entries and changed ones per counted part (SV_COUNTS); an archive that does not read counts nothing."""
    out, cache = [], {}
    for path, key, label in SV_COUNTS:
        if path not in cache:
            try:
                with open(os.path.join(worktree, path), encoding='utf-8') as fh:
                    new = json_at(fh.read())
            except OSError:
                new = {}
            # the committed archive of base, not the main checkout's file (which may be dirty); a path
            # base lacks gives git's message, which is no JSON: then everything counts as new
            cache[path] = (json_at(git('show', f'{base}:{path}', check=False)), new)
        old, new = cache[path]
        a, b = entries(old, key), entries(new, key)
        added = sum(1 for k in b if k not in a)
        changed = sum(1 for k in b if k in a and a[k] != b[k])
        if added or changed:
            out.append(f'{added} {label}' + (f' ({changed} geändert)' if changed else ''))
    return out


def changed_files(worktree):
    """The files a data build changed or added in the worktree (SV_PATHS), sorted."""
    out = git('status', '--porcelain', '--', *present(worktree, SV_PATHS), cwd=worktree, check=False)
    return sorted(ln[3:].strip().strip('"') for ln in out.splitlines() if len(ln) > 3)


def failing_lines(out, n=10):
    """The first failing lines of `build.py check` (its step lines "FAIL ...", pytest's "FAILED ..."), else its
    end; the summary line "check: ..." last."""
    lines = [ln.rstrip() for ln in out.splitlines() if ln.strip()]
    bad = [ln for ln in lines if 'FAILED' in ln or re.match(r'^(fail|FAIL)\b', ln.strip())]
    summary = [ln for ln in lines if ln.startswith('check:')][-1:]
    picked = (bad[:n] if bad else lines[-n:])
    return [ln for ln in picked if ln not in summary] + summary


def take_over_sv(args, sv, on_main, now=None):
    """Builds main with the SavedVariables sv in the worktree (detached at args.base) and, when something is
    new, checks it, commits and sets the day's branch auto/sv-<date> to the commit. Returns (result, lines
    of the block, branch or None, commit or None); result is 'ok', 'failed', 'nothing new' or 'unreadable'.
    The worktree is removed again in any case."""
    now = time.time() if now is None else now
    head = SV_HEAD + stamp(os.path.getmtime(sv))
    with open(sv, encoding='utf-8', errors='replace') as fh:
        text = fh.read()
    if 'AmisiaDB' not in text:   # a cheap look before a worktree; the build's own parser decides the rest
        return 'unreadable', [f'{head}: nicht lesbar (keine Tabelle AmisiaDB in {sv}); nichts übernommen.'], None, None
    branch = SV_BRANCH + datetime.datetime.fromtimestamp(now).strftime('%Y-%m-%d')
    py = sys.executable
    remove_worktree(args.worktree)
    git('worktree', 'add', '--force', '--detach', args.worktree, args.base)
    commit = None
    try:
        rc, out = run([py, 'tools/build.py', 'data', '--sv', sv], args.worktree)
        if rc != 0:
            return ('failed', [f'{head}: build.py data ist damit fehlgeschlagen, nichts übernommen:']
                    + ['  ' + ln for ln in tail(out, 8)], None, None)
        news, files = archive_news(args.base, args.worktree), changed_files(args.worktree)
        if not news and not files:
            return 'nothing new', [f'{head}: nichts Neues gegenüber {args.base}.'], None, None
        tables = data_build(read(os.path.join(args.worktree, 'Amisia_Gear', 'Data', 'TalentData.lua')))
        rc, out = run([py, 'tools/build.py', 'check'], args.worktree)
        git('add', '-A', *present(args.worktree, SV_PATHS), cwd=args.worktree)
        msg = (f'Spielstand vom {stamp(os.path.getmtime(sv))} übernommen (automatisch gebaut, Prüfung '
               f'{"grün" if rc == 0 else "rot"})\n\n{TRAILER}\n')
        subprocess.run(['git', 'commit', '-q', '--allow-empty', '-F', '-'], cwd=args.worktree, input=msg, text=True,
                       check=True)
        commit = git('rev-parse', '--short', 'HEAD', cwd=args.worktree).strip()
        git('branch', '-f', branch, commit)
        lines = [f'{head}: übernommen auf Branch {branch} ({commit}), Prüfung ' + ('grün.' if rc == 0 else 'ROT:')]
        if rc != 0:
            lines += ['  ' + ln for ln in failing_lines(out)]
        lines.append(f'Neu gegenüber {args.base}: ' + (', '.join(news) if news else 'keine neuen Einträge in den Archiven') + '.')
        lines.append(f'Geänderte Dateien ({len(files)}): ' + ', '.join(files[:8]) + (' ...' if len(files) > 8 else '') + '.')
        if tables and on_main and tables != on_main:
            lines.append(f'Achtung: die Client-Tabellen auf dem N100 sind von Build {tables}, {args.base} hat {on_main}: '
                         'der Branch enthält auch deren Änderungen.')
        lines.append('Zum Veröffentlichen: build.py data auf main, dann build.py release.' if rc == 0 else
                     'Vor dem nächsten Release klären: build.py data auf main bringt denselben Fehler.')
        return ('ok' if rc == 0 else 'failed'), lines, branch, commit
    finally:
        remove_worktree(args.worktree)
        prune_sv_branches()


def read(path):
    try:
        with open(path, encoding='utf-8') as fh:
            return fh.read()
    except OSError:
        return ''


def prune_sv_branches(keep=SV_KEEP):
    """Deletes the local auto/sv-* branches but the newest keep (the names sort by date)."""
    names = sorted(git('for-each-ref', '--format=%(refname:short)', f'refs/heads/{SV_BRANCH}*', check=False).split())
    for name in names[:-keep] if keep else names:
        git('branch', '-D', name, check=False)


def sv_trigger(args, on_main, now=None, take=take_over_sv, log=print):
    """Trigger C (see the module's text). Returns the exit code: 1 when the check was red or the build broke."""
    now = time.time() if now is None else now
    if not sv_on(args.state_dir):
        log(f'SavedVariables trigger off ({SV_OFF_FILE} in {args.state_dir} or {SV_OFF_ENV}=0)')
        return 0
    sv = args.sv
    try:
        st = os.stat(sv)
    except OSError:
        log(f'no SavedVariables at {sv}')
        return 0
    if now - st.st_mtime < SV_SETTLE:
        log(f'{sv} changed {int(now - st.st_mtime)} s ago; waiting until it settles')
        return 0
    path = os.path.join(args.state_dir, SV_STATE)
    last = load_state(path)

    def save(rec):
        os.makedirs(args.state_dir, exist_ok=True)
        with open(path, 'w', encoding='utf-8') as fh:
            json.dump(rec, fh, indent=1)
    force = getattr(args, 'force_sv', False)
    if not force and (last.get('size'), last.get('mtime')) == (st.st_size, st.st_mtime):
        log(f'SavedVariables unchanged since the take-over of {last.get("when")}')
        return 0
    digest = file_hash(sv)
    if not force and digest == last.get('hash'):
        save(dict(last, size=st.st_size, mtime=st.st_mtime))
        log(f'SavedVariables touched, content unchanged since the take-over of {last.get("when")}')
        return 0
    at = last.get('at')
    if not force and isinstance(at, (int, float)) and now - at < SV_GAP:
        log(f'SavedVariables changed; next take-over from {stamp(at + SV_GAP)} (--force-sv: now)')
        return 0
    if args.dry_run:
        log(f'would take over {sv} ({stamp(st.st_mtime)}) on {SV_BRANCH}{stamp(now)[:10]} ({args.base} has {on_main})')
        return 0
    rec = {'size': st.st_size, 'mtime': st.st_mtime, 'hash': digest, 'at': now, 'when': stamp(now),
           'sv_when': stamp(st.st_mtime), 'result': None, 'branch': None, 'commit': None, 'lines': last.get('lines')}
    save(rec)       # counts for the gap even when what follows breaks off
    try:
        result, lines, branch, commit = take(args, sv, on_main, now)
    except Exception as e:      # git or the file: a status line, not a crash of the timer
        result, lines, branch, commit = 'error', [f'{SV_HEAD}{stamp(st.st_mtime)}: abgebrochen ({type(e).__name__}: '
                                                  f'{str(e).splitlines()[0][:160] if str(e) else ""}).'], None, None
    rec.update(result=result, lines=lines, branch=branch, commit=commit)
    save(rec)
    set_sv_block(args.state_dir, lines)
    for ln in lines:
        log(ln)
    return 0 if result in ('ok', 'nothing new') else 1


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
    ap.add_argument('--sv', default=SV_FILE, help=f'the SavedVariables of trigger C (default {SV_FILE}; only read)')
    ap.add_argument('--force-sv', action='store_true', help='take the SavedVariables over now: no gap, even unchanged')
    args = ap.parse_args(argv)

    os.makedirs(args.state_dir, exist_ok=True)
    lock = open(os.path.join(args.state_dir, 'amisia-data.lock'), 'w')
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        print('another run is busy')
        return 0

    on_main = data_build(git('show', f'{args.base}:Amisia_Gear/Data/TalentData.lua', check=False))
    state = load_state(os.path.join(args.state_dir, 'amisia-data.json'))
    settle_stale(args, on_main, state)
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
    built = []

    def build(*a):
        built.append(a[1])
        return build_branch(*a)
    rc = daily_look(args, on_main, state, build=build)
    if built:
        return rc
    # trigger C: no client build built or waiting (D-122)
    why = build_waiting(args, on_main, state)
    if why:
        print(f'SavedVariables wait: {why}')
        return rc
    return sv_trigger(args, on_main) or rc


if __name__ == '__main__':
    sys.exit(main())
