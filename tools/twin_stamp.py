"""Tells whether the claude.ai twin of the ledger is behind the repo.

The twin is built from index.html by build_twin.py and carries the data files, favicon and logo
beside it. This keeps the fingerprints of those inputs as they were at the last publish, in
tools/twin-stamp.json.

    python tools/twin_stamp.py              lists what changed since the last publish, exit 1 if anything did
    python tools/twin_stamp.py --published  records the current state, run it right after publishing the twin

The pre-push hook in .githooks runs the first form and only warns: publishing the twin needs the
Artifact tool, a push must not wait for it.
"""
import hashlib, json, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
STAMP = ROOT / 'tools' / 'twin-stamp.json'
TEXT = {'.html', '.js', '.py', '.json'}


def inputs():
    files = [ROOT / 'index.html', ROOT / 'tools' / 'build_twin.py', ROOT / 'favicon.png', ROOT / 'logo.png']
    files += sorted((ROOT / 'data').iterdir())
    return [f for f in files if f.is_file()]


def fingerprint(f):
    b = f.read_bytes()
    if f.suffix in TEXT:
        b = b.replace(b'\r', b'')        # the same file with CRLF or LF checkout is the same file
    return hashlib.sha256(b).hexdigest()[:16]


def current():
    return {f.relative_to(ROOT).as_posix(): fingerprint(f) for f in inputs()}


def main():
    now = current()
    if '--published' in sys.argv[1:]:
        STAMP.write_text(json.dumps(now, indent=1, sort_keys=True) + '\n', encoding='utf-8', newline='\n')
        print('twin stamp recorded,', len(now), 'files')
        return 0
    if not STAMP.exists():
        print('twin: no stamp yet - publish the twin, then run python tools/twin_stamp.py --published')
        return 1
    was = json.loads(STAMP.read_text(encoding='utf-8'))
    changed = sorted(p for p in now if p in was and now[p] != was[p])
    added = sorted(p for p in now if p not in was)
    gone = sorted(p for p in was if p not in now)
    if not (changed or added or gone):
        print('twin: up to date')
        return 0
    print('twin: behind the repo since its last publish')
    for label, paths in (('changed', changed), ('new', added), ('removed', gone)):
        for p in paths:
            print('  ' + label.ljust(8) + p)
    print('  rebuild with tools/build_twin.py, publish it, then run python tools/twin_stamp.py --published')
    return 1


if __name__ == '__main__':
    sys.exit(main())
