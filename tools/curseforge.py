"""Uploads the release zip to CurseForge (DECISIONS D-58).

    python3 tools/curseforge.py versions             the CurseForge game versions of the TOC's clients
    python3 tools/curseforge.py upload [--dry-run]   Amisia-Website/Amisia.zip as the TOC's version

`build.py release` calls upload() after a successful push; this script is for a first try and for a
retry after a failed upload. The project is `## X-Curse-Project-ID` in Amisia/Amisia.toc, the token
comes from ~/.config/amisia/curseforge.token (or $CURSEFORGE_TOKEN) and never from the repository.
Without either the upload is skipped with a note. The game versions are the TOC's interface numbers
read as CurseForge names (16001 -> 1.60.1, 20506 -> 2.5.6, 11509 -> 1.15.9); a name CurseForge does
not know yet stops the upload, nothing is sent with a guessed version. The changelog is the release's
section of CHANGELOG.md. Only Python's standard library, no download of anything.
"""
import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request
import uuid
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API = 'https://wow.curseforge.com/api'
TOKEN_FILE = os.path.expanduser('~/.config/amisia/curseforge.token')
ZIP_REL = 'Amisia-Website/Amisia.zip'
TOC_REL = 'Amisia/Amisia.toc'


def toc_field(text, name):
    m = re.search(r'^## ' + re.escape(name) + r':[ \t]*(.*?)[ \t]*$', text, re.M)
    return m.group(1) if m else None


def interface_name(n):
    """A TOC interface number as the game version CurseForge names it: 16001 -> 1.60.1."""
    n = int(n)
    return f'{n // 10000}.{n // 100 % 100}.{n % 100}'


def interface_names(toc_text):
    return [interface_name(x) for x in re.findall(r'\d+', toc_field(toc_text, 'Interface') or '')]


def project_id(toc_text):
    v = toc_field(toc_text, 'X-Curse-Project-ID')
    return int(v) if v and v.isdigit() else None


def read_token(path=TOKEN_FILE, env=None):
    env = os.environ if env is None else env
    if env.get('CURSEFORGE_TOKEN'):
        return env['CURSEFORGE_TOKEN'].strip()
    if os.path.isfile(path):
        with open(path, encoding='utf-8') as fh:
            return fh.read().strip() or None
    return None


def pick_versions(versions, names):
    """The ids of the game versions named, and the names CurseForge does not know. A name listed
    twice (CurseForge keeps old version types) takes the newest id."""
    ids, missing = [], []
    for name in names:
        found = [v['id'] for v in versions if v.get('name') == name]
        if found:
            ids.append(max(found))
        else:
            missing.append(name)
    return ids, missing


def changelog_section(text, version):
    m = re.search(r'^## ' + re.escape(version) + r' [^\n]*\n(.*?)(?=^## |\Z)', text, re.M | re.S)
    return m.group(1).strip() if m else ''


def multipart(metadata, filename, data, boundary=None):
    """The body of the upload request: the metadata as JSON, then the zip."""
    boundary = boundary or uuid.uuid4().hex
    head = (f'--{boundary}\r\nContent-Disposition: form-data; name="metadata"\r\n'
            f'Content-Type: application/json\r\n\r\n{json.dumps(metadata)}\r\n'
            f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{filename}"\r\n'
            f'Content-Type: application/zip\r\n\r\n').encode('utf-8')
    return head + data + f'\r\n--{boundary}--\r\n'.encode('utf-8'), f'multipart/form-data; boundary={boundary}'


def call(path, token, body=None, ctype=None, opener=None):
    req = urllib.request.Request(API + path, data=body, method='POST' if body is not None else 'GET')
    req.add_header('X-Api-Token', token)
    if ctype:
        req.add_header('Content-Type', ctype)
    with (opener or urllib.request.urlopen)(req, timeout=120) as resp:
        return json.loads(resp.read().decode('utf-8') or 'null')


def zip_version(path):
    with zipfile.ZipFile(path) as zf:
        return toc_field(zf.read(TOC_REL).decode('utf-8'), 'Version')


def upload(root=ROOT, dry_run=False, token=None, opener=None, say=print):
    """Sends the zip; 0 when it is up (or skipped for want of a project or token), 1 on an error."""
    with open(os.path.join(root, TOC_REL), encoding='utf-8') as fh:
        toc = fh.read()
    version = toc_field(toc, 'Version')
    project = project_id(toc)
    token = token or read_token()
    if not project or not token:
        what = ' and '.join(w for w, ok in (('## X-Curse-Project-ID in the TOC', project), (TOKEN_FILE, token)) if not ok)
        say(f'CurseForge: skipped, no {what}')
        return 0
    zpath = os.path.join(root, ZIP_REL)
    if not os.path.isfile(zpath) or zip_version(zpath) != version:
        say(f'CurseForge: {ZIP_REL} is not version {version}; release first')
        return 1
    names = interface_names(toc)
    try:
        ids, missing = pick_versions(call('/game/versions', token, opener=opener), names)
        if missing:
            say(f'CurseForge: no game version {", ".join(missing)} yet; nothing uploaded')
            return 1
        with open(os.path.join(root, 'CHANGELOG.md'), encoding='utf-8') as fh:
            notes = changelog_section(fh.read(), version) or f'Amisia {version}'
        meta = {'changelog': notes, 'changelogType': 'markdown', 'displayName': f'Amisia {version}',
                'gameVersions': ids, 'releaseType': 'release'}
        if dry_run:
            say(f'CurseForge: would upload Amisia {version} to project {project} for {", ".join(names)} {ids}')
            return 0
        with open(zpath, 'rb') as fh:
            body, ctype = multipart(meta, f'Amisia-{version}.zip', fh.read())
        res = call(f'/projects/{project}/upload-file', token, body, ctype, opener=opener)
    except urllib.error.HTTPError as e:
        detail = e.read().decode('utf-8', 'replace')[:300]
        say(f'CurseForge: HTTP {e.code} {detail}'.rstrip())
        return 1
    except (urllib.error.URLError, OSError, ValueError) as e:
        say(f'CurseForge: {e}')
        return 1
    say(f'CurseForge: uploaded Amisia {version} (file {(res or {}).get("id")}) for {", ".join(names)}')
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(prog='curseforge.py', description=__doc__.split('\n\n')[0])
    sub = ap.add_subparsers(dest='cmd', required=True)
    sub.add_parser('versions', help='the CurseForge game versions of the TOC\'s interface numbers')
    u = sub.add_parser('upload', help=f'upload {ZIP_REL} as the TOC\'s version')
    u.add_argument('--dry-run', action='store_true', help='check everything, send nothing')
    args = ap.parse_args(argv)
    if args.cmd == 'upload':
        return upload(dry_run=args.dry_run)
    token = read_token()
    if not token:
        print(f'no token: put it into {TOKEN_FILE}')
        return 1
    with open(os.path.join(ROOT, TOC_REL), encoding='utf-8') as fh:
        names = interface_names(fh.read())
    versions = call('/game/versions', token)
    for name in names:
        hits = [v for v in versions if v.get('name') == name]
        print(name, ' '.join(f'id {v["id"]} (type {v.get("gameVersionTypeID")})' for v in hits) or 'unknown')
    return 0


if __name__ == '__main__':
    sys.exit(main())
