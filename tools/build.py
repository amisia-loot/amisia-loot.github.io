"""One entry point for Amisia's builds, checks and releases.

    python3 tools/build.py data [--sv FILE] [--wago DIR] [--refresh-att]
    python3 tools/build.py check
    python3 tools/build.py snapshots [--out DIR] [--compare DIR] [--scale N] [--mono]
    python3 tools/build.py release X.Y.Z [-m SUMMARY] [--no-push] [--no-copy]

data     rebuilds every generated file in addon/Amisia/Data in dependency order (dungeons, gear, map,
         dungeon quests, quests, professions, talents, dungeon art, BiS), stops at the first error
         and shows what changed. A step whose client tables are missing in --wago is skipped with a
         note (the tables come only from the user's own tools/export_db2.ps1 run, never downloaded).
check    the syntax check, the addon tests (German, then English), the translation check
         (tools/l10n.py), the layout rules of every page and window in both locales
         (tools/ui_layout.py), the tool tests (they include the "generated file is current" checks),
         a UTF-8 check of the addon files, the TOC against the folder, luacheck. Exit code 1 when
         anything fails.
snapshots  draws every page (raider, officer and expert view) and side window from the test stub
         (--locale deDE or enUS) into PNGs with an index.html contact sheet (default /tmp/amisia-snapshots); --compare names
         the shots whose layout boxes differ from an earlier run's folder.
release  refuses a dirty tree, sets ## Version in the TOC, runs check (and puts the TOC back when it
         fails), builds addon/Amisia.zip, adds the commits since the last release to CHANGELOG.md,
         commits "Amisia X.Y.Z: <summary>", pushes origin main and copies the release to the folder
         Syncthing sends (tools/release_addon.sh). --no-push and --no-copy leave those two out.

The tests need lupa: without it in this Python, the build starts again in ~/.venvs/amisia.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import time
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON_REL = 'addon/Amisia'
VENV_PY = os.path.expanduser('~/.venvs/amisia/bin/python')
WAGO = os.path.expanduser('~/addons/_wago')
SNAPSHOTS = '/tmp/amisia-snapshots'
NODE_DIRS = (os.path.expanduser('~/.local/node/bin'),)
LUAPARSE_DIRS = (os.path.join(ROOT, 'node_modules'), os.path.expanduser('~/addons/VuloForeverUI/tools/node_modules'))
TRAILER = 'Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
RELEASE_SUBJECT = re.compile(r'^Amisia (\d+\.\d+\.\d+): ')
VERSION_LINE = re.compile(r'^(## Version:[ \t]*)(\S+)[ \t]*$', re.M)
TEXT_EXT = ('.lua', '.toc', '.xml', '.txt', '.md')


def say(msg=''):
    print(msg, flush=True)


def run(cmd, cwd=ROOT, env=None, capture=False):
    """Runs cmd; with capture the output comes back as text (stdout and stderr together)."""
    if capture:
        p = subprocess.run(cmd, cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        return p.returncode, p.stdout
    return subprocess.run(cmd, cwd=cwd, env=env).returncode, ''


def git(root, *args, check=True):
    p = subprocess.run(['git', *args], cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if check and p.returncode != 0:
        raise SystemExit(f'git {" ".join(args)}: {p.stderr.strip()}')
    return p.stdout


def has_lupa():
    try:
        import lupa  # noqa: F401
        return True
    except ImportError:
        return False


# ---------------------------------------------------------------- TOC
def toc_path(root):
    return os.path.join(root, ADDON_REL, 'Amisia.toc')


def toc_version(root=ROOT):
    with open(toc_path(root), encoding='utf-8') as fh:
        m = VERSION_LINE.search(fh.read())
    return m.group(2) if m else None


def set_toc_version(root, version):
    path = toc_path(root)
    with open(path, encoding='utf-8', newline='') as fh:
        text = fh.read()
    new, n = VERSION_LINE.subn(lambda m: m.group(1) + version, text, count=1)
    if n != 1:
        raise SystemExit('no "## Version:" line in ' + path)
    with open(path, 'w', encoding='utf-8', newline='') as fh:
        fh.write(new)


def toc_files(root=ROOT):
    """The files the TOC loads, as paths relative to the addon folder with "/"."""
    out = []
    with open(toc_path(root), encoding='utf-8') as fh:
        for line in fh:
            line = line.strip()
            if line and not line.startswith('#'):
                out.append(re.sub(r'\s*\[[^\]]*\]', '', line).replace('\\', '/'))
    return out


def version_key(v):
    return tuple(int(x) for x in v.split('.'))


# ---------------------------------------------------------------- data
def data_steps(sv=None, wago=WAGO, refresh_att=False):
    """The data builds in dependency order: (name, script, args, client tables it needs or None,
    what happens without them: 'skip' or the args to use instead)."""
    sv_args = ['--sv', sv] if sv else []
    return [
        # the dungeon facts first: the gear build places dungeon sources by them
        ('dungeons', 'build_dungeons.py', ['--wago', wago], [('LFGDungeons', 'AreaTable')], []),
        ('gear', 'build_gear.py', ['--wago', wago] + sv_args + (['--refresh-att'] if refresh_att else []), None, None),
        ('map', 'build_map.py', ['--wago', wago], None, None),
        ('dungeon quests', 'build_dungeonquests.py', [], None, None),
        ('quests', 'build_quests.py', [], None, None),
        ('professions', 'build_professions.py', ['--wago', wago], ['ItemSparse', 'SkillLineAbility'], 'skip'),
        ('talents', 'build_talents.py', ['--wago', wago], 'talents', 'skip'),
        ('dungeon art', 'build_dungeonart.py', ['--wago', wago], ['Map', 'LoadingScreens'], []),
        ('bis', 'build_bis.py', ['--wago', wago] + sv_args, None, None),
    ]


def missing_tables(needs, wago):
    """The client tables of needs not found in wago. A tuple in needs is "one of these"."""
    tools = os.path.join(ROOT, 'tools')
    if tools not in sys.path:
        sys.path.insert(0, tools)
    import att_data
    if needs == 'talents':
        import build_talents
        needs = build_talents.REQUIRED
    out = []
    for t in needs:
        alts = t if isinstance(t, tuple) else (t,)
        if not any(att_data.wago_csv(wago, a) for a in alts):
            out.append('/'.join(alts))
    return out


def cmd_data(args):
    if args.sv and not os.path.exists(args.sv):
        raise SystemExit('no SavedVariables file ' + args.sv)
    wago = os.path.abspath(os.path.expanduser(args.wago))
    py = sys.executable
    done, skipped = [], []
    for name, script, sargs, needs, without in data_steps(args.sv, wago, args.refresh_att):
        if needs:
            miss = missing_tables(needs, wago)
            if miss:
                note = (f'client tables missing in {wago}: {", ".join(miss)} '
                        f'(export them on the PC: tools/export_db2.ps1 -Tables {",".join(miss)})')
                if without == 'skip':
                    say(f'skip  {name}: {note}')
                    skipped.append(name)
                    continue
                say(f'note  {name}: {note}; built from the kept snapshot')
                sargs = without
        say(f'---- {name}: tools/{script} {" ".join(sargs)}')
        t0 = time.time()
        rc, _ = run([py, os.path.join(ROOT, 'tools', script)] + sargs)
        if rc != 0:
            say(f'FAIL  {name} (exit {rc}); the later steps did not run')
            return 1
        done.append(f'{name} {time.time() - t0:.0f}s')
    say()
    say('built: ' + ', '.join(done) + (('; skipped: ' + ', '.join(skipped)) if skipped else ''))
    stat = git(ROOT, 'diff', '--stat', '--', ADDON_REL + '/Data', 'tools').rstrip()
    say('changed:\n' + stat if stat else 'changed: nothing (every generated file is current)')
    return 0


# ---------------------------------------------------------------- check
def node_env():
    node = shutil.which('node') or next((os.path.join(d, 'node') for d in NODE_DIRS
                                         if os.path.exists(os.path.join(d, 'node'))), None)
    env = dict(os.environ)
    paths = [p for p in [env.get('NODE_PATH')] + list(LUAPARSE_DIRS) if p and os.path.isdir(p)]
    if paths:
        env['NODE_PATH'] = os.pathsep.join(paths)
    return node, env


def luacheck_cmd():
    found = shutil.which('luacheck') or (os.path.expanduser('~/.local/bin/luacheck')
                                         if os.path.exists(os.path.expanduser('~/.local/bin/luacheck')) else None)
    return found


def addon_files(root=ROOT):
    base = os.path.join(root, ADDON_REL)
    out = []
    for d, dirs, files in os.walk(base):
        dirs[:] = sorted(x for x in dirs if not x.startswith('.'))
        for f in sorted(files):
            if not f.startswith('.'):
                out.append(os.path.relpath(os.path.join(d, f), base).replace(os.sep, '/'))
    return out


def check_utf8(root=ROOT):
    """Every text file of the addon is UTF-8 without a byte order mark. Returns the problems."""
    bad = []
    for rel in addon_files(root):
        if not rel.lower().endswith(TEXT_EXT):
            continue
        with open(os.path.join(root, ADDON_REL, rel), 'rb') as fh:
            data = fh.read()
        if data.startswith(b'\xef\xbb\xbf'):
            bad.append(f'{rel}: byte order mark')
        try:
            data.decode('utf-8')
        except UnicodeDecodeError as e:
            line = data[:e.start].count(b'\n') + 1
            bad.append(f'{rel}:{line}: not UTF-8 ({e.reason})')
    return bad


def check_toc(root=ROOT):
    """The TOC lists only files that exist, and every .lua and .xml of the addon is in it."""
    listed = toc_files(root)
    have = [f for f in addon_files(root) if f.endswith(('.lua', '.xml'))]
    bad = [f'{f}: in the TOC, but no such file' for f in listed if f not in have]
    bad += [f'{f}: not in the TOC' for f in have if f not in listed]
    dup = sorted({f for f in listed if listed.count(f) > 1})
    bad += [f'{f}: twice in the TOC' for f in dup]
    return bad


def fail_lines(out, limit=25):
    """The lines of a tool's output worth showing on a failure."""
    lines = [ln for ln in out.splitlines() if ln.strip()]
    keep = [ln for ln in lines if re.match(r'\s*(FAIL|FAILED|ERROR|E\s|\S+:\d+:\d+:|\s{6}\S)', ln)]
    return (keep or lines)[-limit:]


def cmd_check(args=None):
    py = sys.executable
    node, env = node_env()
    results = []

    def step(name, fn):
        t0 = time.time()
        status, detail = fn()
        took = f'{time.time() - t0:.1f}s'
        results.append(status)
        say(f'{status:<5} {name} ({took})' + (f': {detail[0]}' if status == 'skip' and detail else ''))
        if status == 'FAIL':
            for ln in detail:
                say('      ' + ln)

    def syntax():
        if not node:
            return 'skip', ['node not found']
        rc, out = run([node, os.path.join(ROOT, 'addon', 'tests', 'syntax.cjs')], env=env, capture=True)
        if rc == 2:
            return 'skip', ['luaparse not found (npm install luaparse, or NODE_PATH)']
        n = sum(1 for ln in out.splitlines() if ln.startswith('ok'))
        return ('ok', [f'{n} files']) if rc == 0 else ('FAIL', fail_lines(out))

    def addon_tests():
        rc, out = run([py, os.path.join(ROOT, 'addon', 'tests', 'run.py')], capture=True)
        return ('ok', []) if rc == 0 else ('FAIL', fail_lines(out))

    def addon_tests_en():
        rc, out = run([py, os.path.join(ROOT, 'addon', 'tests', 'run.py'), '--locale', 'enUS'], capture=True)
        summary = [ln for ln in out.splitlines() if ln.startswith('locale ')]
        return ('ok', summary) if rc == 0 else ('FAIL', fail_lines(out))

    def translations():
        rc, out = run([py, os.path.join(ROOT, 'tools', 'l10n.py'), 'check'], capture=True)
        lines = [ln for ln in out.splitlines() if ln.strip()]
        return ('ok', []) if rc == 0 else ('FAIL', lines[-40:])

    def layout_rules():
        rc, out = run([py, os.path.join(ROOT, 'tools', 'ui_layout.py'), 'rules'], capture=True)
        if rc == 0:
            return 'ok', []
        lines = [ln for ln in out.splitlines() if ln.strip()]
        return 'FAIL', lines[-40:]

    def tool_tests():
        rc, out = run([py, '-m', 'pytest', os.path.join(ROOT, 'tools', 'tests'), '-q', '-p', 'no:cacheprovider'],
                      capture=True)
        return ('ok', []) if rc == 0 else ('FAIL', fail_lines(out))

    def utf8():
        bad = check_utf8()
        return ('ok', []) if not bad else ('FAIL', bad)

    def toc():
        bad = check_toc()
        return ('ok', []) if not bad else ('FAIL', bad)

    def luacheck():
        exe = luacheck_cmd()
        if not exe:
            return 'skip', ['luacheck not installed (see tools/README.md)']
        rc, out = run([exe, '--no-color', '--formatter', 'plain', ADDON_REL], capture=True)
        return ('ok', []) if rc == 0 else ('FAIL', fail_lines(out, 40))

    step('syntax (luaparse, Lua 5.1)', syntax)
    step('addon tests (addon/tests/run.py)', addon_tests)
    step('addon tests in English (run.py --locale enUS: no Lua error, no missing text)', addon_tests_en)
    step('translations (tools/l10n.py check: no German outside L, enUS complete)', translations)
    step('layout rules (tools/ui_layout.py rules, every page and window)', layout_rules)
    step('tool tests (pytest tools/tests, incl. generated files current)', tool_tests)
    step('UTF-8 of the addon files', utf8)
    step('TOC against the addon folder', toc)
    step('luacheck', luacheck)
    failed = results.count('FAIL')
    skipped = results.count('skip')
    say(('check: %d failed' % failed if failed else 'check: all ok') + (', %d skipped' % skipped if skipped else ''))
    return 1 if failed else 0


# ---------------------------------------------------------------- release
def build_zip(root, out=None):
    """addon/Amisia.zip from the tracked addon files, under Amisia/, without dotfiles."""
    out = out or os.path.join(root, 'addon', 'Amisia.zip')
    files = [f for f in git(root, 'ls-files', '--', ADDON_REL).splitlines() if f]
    base = os.path.join(root, ADDON_REL)
    n = 0
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as zf:
        for rel in sorted(files):
            inner = os.path.relpath(os.path.join(root, rel), base).replace(os.sep, '/')
            if any(part.startswith('.') for part in inner.split('/')):
                continue
            path = os.path.join(root, rel)
            if not os.path.isfile(path):
                continue
            zf.write(path, 'Amisia/' + inner)
            n += 1
    return out, n


def commits_since_release(root):
    """The subjects of the commits after the last release commit ("Amisia X.Y.Z: ..."), oldest first."""
    out = []
    for line in git(root, 'log', '--no-merges', '--format=%s').splitlines():
        if RELEASE_SUBJECT.match(line):
            break
        out.append(line)
    return list(reversed(out))


def update_changelog(root, version, subjects, day):
    path = os.path.join(root, 'CHANGELOG.md')
    head = '# Changelog\n\nWhat changed in each release of the Amisia addon, from the commit subjects.\n'
    old = ''
    if os.path.exists(path):
        with open(path, encoding='utf-8') as fh:
            old = fh.read()
    body = old[len(head):].lstrip('\n') if old.startswith(head) else old.lstrip('\n')
    if re.search(r'^## ' + re.escape(version) + r' ', body, re.M):
        raise SystemExit(f'CHANGELOG.md already has {version}')
    section = f'## {version} ({day})\n\n' + ''.join(f'- {s}\n' for s in (subjects or ['(no changes recorded)']))
    with open(path, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(head + '\n' + section + ('\n' + body if body else ''))
    return path


def default_summary(subjects, limit=200):
    text = '; '.join(subjects) if subjects else 'maintenance'
    return text if len(text) <= limit else text[:limit - 1].rstrip() + '…'


def release(root, version, summary=None, push=True, copy=True, check=None, day=None):
    """The release steps; check() returns 0 when everything passes. Returns the exit code."""
    if not re.fullmatch(r'\d+\.\d+\.\d+', version or ''):
        raise SystemExit('the version is X.Y.Z: ' + str(version))
    current = toc_version(root)
    if current and version_key(version) <= version_key(current):
        raise SystemExit(f'{version} is not newer than the TOC version {current}')
    dirty = git(root, 'status', '--porcelain', '--untracked-files=no').strip()
    untracked = git(root, 'ls-files', '--others', '--exclude-standard', '--', ADDON_REL).strip()
    if dirty or untracked:
        raise SystemExit('the tree is not clean; commit or stash first:\n' + '\n'.join(filter(None, [dirty, untracked])))
    branch = git(root, 'rev-parse', '--abbrev-ref', 'HEAD').strip()
    if push and branch != 'main':
        raise SystemExit(f'releases are pushed from main, this is {branch} (or use --no-push)')

    touched = [ADDON_REL + '/Amisia.toc', 'addon/Amisia.zip', 'CHANGELOG.md']

    def undo():
        """Back to HEAD: no version bump, zip or changelog entry is left behind by a failed release."""
        git(root, 'reset', '-q', '--', *touched, check=False)
        for rel in touched:
            if git(root, 'ls-files', '--', rel).strip():
                git(root, 'checkout', '--', rel, check=False)
            elif os.path.exists(os.path.join(root, rel)):
                os.remove(os.path.join(root, rel))

    try:
        set_toc_version(root, version)
        say(f'TOC: {current} -> {version}; running check')
        if (check or cmd_check)() != 0:
            undo()
            say(f'check failed: nothing released, the TOC stays at {current}')
            return 1
        zpath, n = build_zip(root)
        say(f'{os.path.relpath(zpath, root)}: {n} files')
        subjects = commits_since_release(root)
        update_changelog(root, version, subjects, day or time.strftime('%Y-%m-%d'))
        message = f'Amisia {version}: {summary or default_summary(subjects)}\n\n{TRAILER}\n'
        git(root, 'add', '--', *touched)
        p = subprocess.run(['git', 'commit', '-q', '-F', '-'], cwd=root, input=message, text=True,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if p.returncode != 0:
            raise SystemExit('git commit: ' + p.stderr.strip())
    except BaseException:
        undo()
        raise
    say('committed ' + git(root, 'log', '-1', '--format=%h %s').strip())
    if push:
        rc, _ = run(['git', 'push', 'origin', 'main'], cwd=root)
        if rc != 0:
            say('push failed: the release commit is local; push it by hand, then run tools/release_addon.sh')
            return 1
    if copy:
        rc, _ = run(['bash', os.path.join(root, 'tools', 'release_addon.sh')], cwd=root)
        if rc != 0:
            return 1
    return 0


def cmd_snapshots(args):
    tools = os.path.join(ROOT, 'tools')
    if tools not in sys.path:
        sys.path.insert(0, tools)
    import ui_layout
    argv = ['snapshots', '--out', args.out, '--scale', str(args.scale), '--locale', args.locale]
    if args.compare:
        argv += ['--compare', args.compare]
    if args.mono:
        argv.append('--mono')
    return ui_layout.main(argv)


def cmd_release(args):
    return release(ROOT, args.version, summary=args.message, push=not args.no_push, copy=not args.no_copy)


# ---------------------------------------------------------------- main
def main(argv=None):
    ap = argparse.ArgumentParser(prog='build.py', description=__doc__.split('\n\n')[0],
                                 formatter_class=argparse.RawDescriptionHelpFormatter, epilog=__doc__)
    sub = ap.add_subparsers(dest='cmd', required=True)
    d = sub.add_parser('data', help='rebuild the generated data files')
    d.add_argument('--sv', default=None, help='Amisia SavedVariables for build_gear and build_bis '
                                              '(default: what each build finds, e.g. ~/addons/_SavedVariables/Amisia.lua)')
    d.add_argument('--wago', default=WAGO, help=f'folder of the client table CSVs (default {WAGO})')
    d.add_argument('--refresh-att', action='store_true', help='download the AllTheThings Forever data first')
    sub.add_parser('check', help='every test and check; exit 1 on a failure')
    sn = sub.add_parser('snapshots', help='PNGs of every page and window with an index.html (tools/ui_layout.py)')
    sn.add_argument('--out', default=SNAPSHOTS, help=f'output folder (default {SNAPSHOTS})')
    sn.add_argument('--compare', default=None, help='an earlier run\'s folder: list the shots whose layout changed')
    sn.add_argument('--scale', type=int, default=1, help='pixels per UI pixel (default 1)')
    sn.add_argument('--mono', action='store_true', help='text in a fixed 0.6 em grid instead of the estimated widths')
    sn.add_argument('--locale', default='deDE', help='the client locale of the shots: deDE (default) or enUS')
    r = sub.add_parser('release', help='check, version, zip, changelog, commit, push, copy to Syncthing')
    r.add_argument('version', help='X.Y.Z')
    r.add_argument('-m', '--message', default=None,
                   help='the summary after "Amisia X.Y.Z: " (default: the commit subjects since the last release)')
    r.add_argument('--no-push', action='store_true', help='commit only, do not push')
    r.add_argument('--no-copy', action='store_true', help='do not run tools/release_addon.sh')
    args = ap.parse_args(argv)
    if not has_lupa() and os.path.exists(VENV_PY) and not os.environ.get('AMISIA_BUILD_VENV'):
        # once only: the venv's python is a link to the same binary, so the guard is the variable
        os.environ['AMISIA_BUILD_VENV'] = '1'
        rest = sys.argv[1:] if argv is None else list(argv)
        os.execv(VENV_PY, [VENV_PY, os.path.abspath(__file__)] + rest)
    return {'data': cmd_data, 'check': cmd_check, 'snapshots': cmd_snapshots, 'release': cmd_release}[args.cmd](args)


if __name__ == '__main__':
    sys.exit(main())
