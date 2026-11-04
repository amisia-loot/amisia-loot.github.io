"""tools/curseforge.py: the upload of the release zip to CurseForge (DECISIONS D-58), against a fake API."""
import io
import json
import os
import sys
import urllib.error
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import curseforge  # noqa: E402

TOC = '## Interface: 16001, 20506, 11509\n## Title: Amisia\n## Version: 2.49.0\n## X-Curse-Project-ID: 123456\n'
VERSIONS = [{'id': 13001, 'name': '1.60.1'}, {'id': 12001, 'name': '2.5.6'}, {'id': 9001, 'name': '2.5.6'},
            {'id': 11001, 'name': '1.15.9'}, {'id': 1, 'name': '11.2.5'}]


def addon(tmp_path, toc=TOC, zipped=None):
    root = str(tmp_path)
    os.makedirs(os.path.join(root, 'Amisia'))
    os.makedirs(os.path.join(root, 'Amisia-Website'))
    with open(os.path.join(root, 'Amisia', 'Amisia.toc'), 'w', encoding='utf-8') as fh:
        fh.write(toc)
    with zipfile.ZipFile(os.path.join(root, 'Amisia-Website', 'Amisia.zip'), 'w') as zf:
        zf.writestr('Amisia/Amisia.toc', zipped or toc)
    with open(os.path.join(root, 'CHANGELOG.md'), 'w', encoding='utf-8') as fh:
        fh.write('# Changelog\n\n## 2.49.0 (2026-11-04)\n\n- Neu: etwas\n\n## 2.48.2 (2026-11-03)\n\n- alt\n')
    return root


class Fake:
    """urlopen: the game versions on GET, a file id on the upload; records every request."""

    def __init__(self, versions=VERSIONS, fail=None):
        self.versions, self.fail, self.seen = versions, fail, []

    def __call__(self, req, timeout=None):
        self.seen.append(req)
        if self.fail:
            raise urllib.error.HTTPError(req.full_url, self.fail, 'no', {}, io.BytesIO(b'{"errorMessage":"bad"}'))
        out = self.versions if req.full_url.endswith('/game/versions') else {'id': 777}
        resp = io.BytesIO(json.dumps(out).encode('utf-8'))
        resp.__enter__ = lambda *a: resp
        return resp


def test_the_interface_numbers_are_curseforge_names():
    assert curseforge.interface_names(TOC) == ['1.60.1', '2.5.6', '1.15.9']
    assert curseforge.interface_name(110205) == '11.2.5'
    assert curseforge.project_id(TOC) == 123456 and curseforge.project_id('## Title: x\n') is None


def test_pick_takes_the_newest_id_and_names_the_unknown():
    assert curseforge.pick_versions(VERSIONS, ['1.60.1', '2.5.6']) == ([13001, 12001], [])
    assert curseforge.pick_versions(VERSIONS, ['1.60.1', '1.61.0']) == ([13001], ['1.61.0'])


def test_the_changelog_is_the_release_section():
    text = '# Changelog\n\n## 2.49.0 (x)\n\n- a\n- b\n\n## 2.48.2 (y)\n\n- c\n'
    assert curseforge.changelog_section(text, '2.49.0') == '- a\n- b'
    assert curseforge.changelog_section(text, '2.48.2') == '- c'
    assert curseforge.changelog_section(text, '1.0.0') == ''


def test_the_token_comes_from_the_environment_or_the_file(tmp_path):
    path = tmp_path / 'token'
    assert curseforge.read_token(str(path), env={}) is None
    path.write_text(' abc \n')
    assert curseforge.read_token(str(path), env={}) == 'abc'
    assert curseforge.read_token(str(path), env={'CURSEFORGE_TOKEN': 'env'}) == 'env'


def test_upload_sends_the_zip_with_the_versions_and_the_changelog(tmp_path):
    root, fake, said = addon(tmp_path), Fake(), []
    assert curseforge.upload(root, token='t0k', opener=fake, say=said.append) == 0
    get, post = fake.seen
    assert get.get_method() == 'GET' and get.get_header('X-api-token') == 't0k'
    assert post.full_url == 'https://wow.curseforge.com/api/projects/123456/upload-file'
    body = post.data
    meta = json.loads(body.split(b'\r\n\r\n', 1)[1].split(b'\r\n--', 1)[0])
    assert meta == {'changelog': '- Neu: etwas', 'changelogType': 'markdown', 'displayName': 'Amisia 2.49.0',
                    'gameVersions': [13001, 12001, 11001], 'releaseType': 'release'}
    assert b'filename="Amisia-2.49.0.zip"' in body and b'PK' in body
    assert 'uploaded Amisia 2.49.0 (file 777)' in said[-1]


def test_dry_run_sends_nothing(tmp_path):
    fake, said = Fake(), []
    assert curseforge.upload(addon(tmp_path), dry_run=True, token='t', opener=fake, say=said.append) == 0
    assert [r.get_method() for r in fake.seen] == ['GET'] and 'would upload' in said[-1]


def test_skipped_without_project_or_token(tmp_path, monkeypatch):
    monkeypatch.setattr(curseforge, 'read_token', lambda *a, **k: None)
    fake, said = Fake(), []
    assert curseforge.upload(addon(tmp_path), opener=fake, say=said.append) == 0
    assert 'skipped' in said[-1] and curseforge.TOKEN_FILE in said[-1] and not fake.seen
    root = addon(tmp_path / 'b', toc=TOC.replace('## X-Curse-Project-ID: 123456\n', ''))
    assert curseforge.upload(root, token='t', opener=fake, say=said.append) == 0
    assert 'X-Curse-Project-ID' in said[-1] and not fake.seen


def test_refuses_an_unknown_game_version_an_old_zip_and_reports_http_errors(tmp_path):
    said = []
    fake = Fake(versions=[v for v in VERSIONS if v['name'] != '1.60.1'])
    assert curseforge.upload(addon(tmp_path / 'a'), token='t', opener=fake, say=said.append) == 1
    assert 'no game version 1.60.1' in said[-1] and len(fake.seen) == 1, 'no upload with a guessed version'
    old = addon(tmp_path / 'b', zipped=TOC.replace('2.49.0', '2.48.2'))
    assert curseforge.upload(old, token='t', opener=Fake(), say=said.append) == 1 and 'release first' in said[-1]
    assert curseforge.upload(addon(tmp_path / 'c'), token='t', opener=Fake(fail=403), say=said.append) == 1
    assert 'HTTP 403' in said[-1]
