"""The project's knowledge, held against the code.

docs/ARCHITECTURE.md lists the addon's files, its message kinds and blob arts, the export lines, the
paste-in blocks, the saved keys and the settings sections; docs/DECISIONS.md the user's decisions.
These tests read the tables marked "(checked)" and the code and fail when the two drift apart either
way: a new message kind, export line or saved key needs its row in the same commit, a row whose code
went needs to go. The decision guards check what of DECISIONS.md a machine can check, and that every
test DECISIONS.md names exists.
"""
import json
import os
import re

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ADDON = os.path.join(ROOT, 'addon', 'Amisia')
TOOLS = os.path.join(ROOT, 'tools')
ARCH = os.path.join(ROOT, 'docs', 'ARCHITECTURE.md')
DECISIONS = os.path.join(ROOT, 'docs', 'DECISIONS.md')
SITE = os.path.join(ROOT, 'index.html')


def read(path):
    with open(path, encoding='utf-8') as fh:
        return fh.read()


def addon_files(exts=('.lua',), skip=()):
    """(path relative to the addon folder with "/", text) of every addon file with one of exts."""
    out = []
    for d, dirs, files in os.walk(ADDON):
        dirs[:] = sorted(x for x in dirs if not x.startswith('.'))
        for f in sorted(files):
            if f.endswith(exts):
                rel = os.path.relpath(os.path.join(d, f), ADDON).replace(os.sep, '/')
                if not any(rel.startswith(s) for s in skip):
                    out.append((rel, read(os.path.join(d, f))))
    return out


def code_files():
    """The hand-written addon Lua (no generated data, no translations)."""
    return addon_files(skip=('Data/', 'Locales/'))


def tool_files():
    out = []
    for f in sorted(os.listdir(TOOLS)):
        if f.endswith(('.py', '.ps1', '.sh')):
            out.append((f, read(os.path.join(TOOLS, f))))
    return out


def section(text, heading):
    """The lines under the first heading that contains heading, up to the next heading."""
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if line.startswith('#') and heading in line:
            out = []
            for rest in lines[i + 1:]:
                if rest.startswith('#'):
                    break
                out.append(rest)
            return out
    raise AssertionError(f'{os.path.basename(ARCH)} has no heading "{heading}"')


def rows(text, heading):
    """{first backticked word of the first cell: [cells]} of the table under heading."""
    out = {}
    for line in section(text, heading):
        m = re.match(r'^\|\s*`([^`]+)`', line)
        if m:
            cells = [c.strip() for c in line.strip().strip('|').split('|')]
            assert m.group(1) not in out, f'"{m.group(1)}" stands twice under "{heading}"'
            out[m.group(1)] = cells
    assert out, f'no table rows under "{heading}"'
    return out


@pytest.fixture(scope='module')
def arch():
    return read(ARCH)


@pytest.fixture(scope='module')
def comm():
    return read(os.path.join(ADDON, 'Core', 'Comm.lua'))


def lua_table(src, name):
    """{key: value text} of a one-line Lua table "local NAME = { A = 1, B = true }"."""
    m = re.search(r'^local ' + name + r'\s*=\s*\{([^}\n]*)\}', src, re.M)
    assert m, f'Comm.lua has no one-line table {name}'
    return dict(re.findall(r'([A-Z]{2,3})\s*=\s*([^,\s]+)', m.group(1)))


def lua_number(src, name):
    """The number a "local A, B = 1, 2" line gives name."""
    m = re.search(r'^local ([^=\n]*\b' + name + r'\b[^=\n]*)=([^\n]+)', src, re.M)
    assert m, name
    names = [x.strip() for x in m.group(1).split(',')]
    values = [x.strip() for x in m.group(2).split('--')[0].split(',')]
    return int(values[names.index(name)])


# ---------------------------------------------------------------- comm
def valid_kinds(comm):
    block = re.search(r'^local VALID = \{\n(.*?)^\}', comm, re.M | re.S)
    assert block, 'Comm.lua has no VALID table'
    return set(re.findall(r'^    ([A-Z]{2}) = ', block.group(1), re.M))


def test_every_message_kind_has_its_row_and_no_row_is_left_over(arch, comm):
    code = valid_kinds(comm)
    doc = set(rows(arch, 'Message kinds'))
    assert code, 'no kinds found in VALID'
    assert not code - doc, 'kinds without a row in ARCHITECTURE.md "Message kinds": ' + ', '.join(sorted(code - doc))
    assert not doc - code, 'rows of kinds Comm.lua does not know: ' + ', '.join(sorted(doc - code))


def test_every_blob_art_has_its_row_with_its_part_cap(arch, comm):
    arts = set(lua_table(comm, 'BLOB_ARTS'))
    doc = rows(arch, 'Blob arts')
    assert arts == set(doc), f'blob arts in Comm.lua {sorted(arts)} against ARCHITECTURE.md {sorted(doc)}'
    caps = lua_table(comm, 'ART_PARTS')
    named = {'MAX_PARTS': lua_number(comm, 'MAX_PARTS'), 'MAX_PARTS_OP': lua_number(comm, 'MAX_PARTS_OP'),
             'MAX_PARTS_DK': lua_number(comm, 'MAX_PARTS_DK')}
    for art, cells in doc.items():
        cap = caps.get(art, 'MAX_PARTS')
        cap = named[cap] if cap in named else int(cap)
        assert cells[3] == str(cap), f'blob {art}: ARCHITECTURE.md says {cells[3]} parts, Comm.lua {cap}'


def test_the_gap_of_every_kind_is_the_documented_one(arch, comm):
    gaps = lua_table(comm, 'KIND_GAP')
    keyed = lua_table(comm, 'KEYED_GAP')
    for kind, cells in rows(arch, 'Message kinds').items():
        gap = cells[3]
        if kind in gaps:
            assert gap.startswith(gaps[kind] + ' s'), f'{kind}: gap {gaps[kind]} s in Comm.lua, "{gap}" in ARCHITECTURE.md'
        elif kind in keyed:
            assert gap.startswith('keyed ' + keyed[kind] + ' s'), f'{kind}: keyed gap {keyed[kind]} s, "{gap}" documented'
        elif kind == 'BL':
            assert gap == 'sender limits'
        else:
            assert gap.startswith('none'), f'{kind} has no gap in Comm.lua, ARCHITECTURE.md says "{gap}"'


def test_every_kind_is_sent_and_handled_somewhere(comm):
    others = [text for rel, text in code_files() if rel != 'Core/Comm.lua']
    joined = '\n'.join(others)
    for kind in valid_kinds(comm) - {'BL'}:
        assert re.search(r'CommOn\("' + kind + '"', joined), f'{kind}: no handler (ns.CommOn)'
        assert re.search(r'"' + kind + r'"', joined.replace('CommOn("' + kind + '"', '')), f'{kind}: never sent'
    for art in lua_table(comm, 'BLOB_ARTS'):
        assert 'CommOnBlob("' + art + '"' in joined, f'blob {art}: no handler'
        assert 'CommSendBlob("' + art + '"' in joined, f'blob {art}: never sent'


def test_two_prefixes_and_one_sender(comm):
    assert re.search(r'local PREFIX_CTRL, PREFIX_DATA = "Amisia", "AmisiaD"', comm), 'exactly the two prefixes'
    assert re.search(r'^local CHANNELS = \{ RAID = true, GUILD = true, WHISPER = true \}', comm, re.M), \
        'only RAID, GUILD and WHISPER (never INSTANCE_CHAT)'
    for rel, text in code_files():
        if rel in ('Core/Comm.lua', 'Core/SelfTest.lua'):
            continue
        assert 'SendAddonMessage' not in text, f'{rel} sends addon messages past Comm.lua'
        assert 'RegisterAddonMessagePrefix' not in text, f'{rel} registers a prefix of its own'


# ---------------------------------------------------------------- export
WRITE = re.compile(r'\[#lines \+ 1\] = \(?"([A-Z]{1,3})[ "]')


def written_lines():
    """{line kind: set of writer files (basename without .lua)}."""
    out = {}
    for rel, text in code_files():
        for kind in WRITE.findall(text):
            out.setdefault(kind, set()).add(os.path.basename(rel)[:-4])
    return out


def site_reads():
    return set(re.findall(r"f\[0\] [!=]== '([A-Z]{1,3})'", read(SITE)))


def test_every_export_line_has_its_row(arch):
    written = written_lines()
    doc = rows(arch, 'Export lines')
    assert {'S', 'E', 'A', 'N', 'DK', 'WL'} <= set(written), 'the writer pattern still finds the export'
    assert not set(written) - set(doc), 'export lines without a row: ' + ', '.join(sorted(set(written) - set(doc)))
    assert not set(doc) - set(written), 'rows of export lines no code writes: ' + ', '.join(sorted(set(doc) - set(written)))
    for kind, files in written.items():
        for f in files:
            assert f + '.lua' in doc[kind][2], f'{kind} is written by {f}.lua, ARCHITECTURE.md names "{doc[kind][2]}"'


def test_the_site_reads_what_the_table_says(arch):
    reads = site_reads()
    site = read(SITE)
    doc = rows(arch, 'Export lines')
    assert not reads - set(doc), 'the site reads lines ARCHITECTURE.md does not list: ' + ', '.join(sorted(reads - set(doc)))
    for kind, cells in doc.items():
        reader = cells[3]
        if reader.startswith('ignored'):
            assert kind not in reads, f'{kind} is read by the site now: name its reader in ARCHITECTURE.md'
        else:
            assert kind in reads, f'{kind}: the site has no branch for it, yet ARCHITECTURE.md names {reader}'
            assert 'function ' + reader + '(' in site, f'{kind}: index.html has no function {reader}'


def test_paste_in_blocks(arch):
    site = read(SITE)
    on_site = set(re.findall(r"'#AMISIA-([A-Z]+) 1 '", site))
    in_addon = set()
    for _, text in code_files():
        in_addon |= set(re.findall(r'#AMISIA%-([A-Z]+)', text))
    doc = {k.replace('#AMISIA-', '') for k in rows(arch, 'Paste-in blocks')}
    assert on_site == doc, f'blocks the site writes {sorted(on_site)} against ARCHITECTURE.md {sorted(doc)}'
    assert in_addon == doc, f'blocks the addon reads {sorted(in_addon)} against ARCHITECTURE.md {sorted(doc)}'
    pts = read(os.path.join(ADDON, 'Raid', 'Points.lua'))
    parser = re.search(r'^function ns\.ParsePointsSite\(.*?^end', pts, re.M | re.S)
    assert parser, 'Points.lua has ns.ParsePointsSite'
    kinds = set(re.findall(r'kind == "([A-Z]+)"', parser.group(0)))
    assert {'CFG', 'P'} <= kinds
    cell = rows(arch, 'Paste-in blocks')['#AMISIA-PTS'][1]
    for k in kinds:
        assert '`' + k + ' ' in cell, f'the #AMISIA-PTS line {k} is not in ARCHITECTURE.md'


# ---------------------------------------------------------------- saved variables, settings, files
def saved_keys():
    keys = set()
    for _, text in code_files():
        keys |= set(re.findall(r'\b(?:AmisiaDB|DB|db|root)\.([A-Za-z_]\w*)', text))
    return keys


def test_every_saved_key_has_its_row(arch):
    code = saved_keys()
    doc = set(rows(arch, 'SavedVariables'))
    assert {'sessions', 'settings', 'points'} <= code
    assert not code - doc, 'AmisiaDB keys without a row: ' + ', '.join(sorted(code - doc))
    assert not doc - code, 'rows of AmisiaDB keys no code uses: ' + ', '.join(sorted(doc - code))


def test_every_settings_section_is_listed(arch):
    code = set()
    for _, text in code_files():
        code |= set(re.findall(r'(?:RegisterSettings\s*\{|SETTINGS\s*=\s*\{|Settings\s*=\s*\{)\s*key\s*=\s*"(\w+)"', text))
    doc = set()
    for line in section(arch, 'Settings registry'):
        if line.startswith('|'):
            # two sections per row: the first and the third cell
            cells = [c.strip() for c in line.strip().strip('|').split('|')]
            for c in cells[0::2]:
                m = re.fullmatch(r'`([a-z]+)`', c)
                if m:
                    doc.add(m.group(1))
    assert code, 'no settings sections found'
    assert not code - doc, 'settings sections not in ARCHITECTURE.md: ' + ', '.join(sorted(code - doc))
    assert not doc - code, 'sections in ARCHITECTURE.md the code does not register: ' + ', '.join(sorted(doc - code))


def toc_files():
    out = []
    for line in read(os.path.join(ADDON, 'Amisia.toc')).splitlines():
        line = line.strip()
        if line and not line.startswith('#'):
            out.append(re.sub(r'\s*\[[^\]]*\]', '', line).replace('\\', '/'))
    return out


def test_the_module_map_has_every_toc_file(arch):
    doc = set(rows(arch, 'Module map'))
    listed = toc_files()
    missing = [f for f in listed if f not in doc and not (f.startswith('UI/Pages/') and 'UI/Pages/*.lua' in doc)]
    assert not missing, 'TOC files without a row in the module map: ' + ', '.join(missing)
    gone = [f for f in doc if '*' not in f and f not in listed]
    assert not gone, 'module map rows of files the TOC does not load: ' + ', '.join(gone)


# ---------------------------------------------------------------- decision guards
def test_toc_is_forever_only():
    toc = read(os.path.join(ADDON, 'Amisia.toc'))
    assert re.search(r'^## Interface: 16001\s*$', toc, re.M), 'the TOC targets WoW Forever (16001) and nothing else'
    for line in toc.splitlines():
        if line.startswith('Data\\'):
            assert line.endswith('[AllowLoadGameType camelot]'), f'generated data loads on Forever only: {line}'


def test_no_tbc_client_left_in_the_addon():
    for rel, text in addon_files(exts=('.lua', '.toc', '.xml')):
        for word in ('_anniversary_', '_classic_era_', 'BisDataTBC', 'MapDataTBC', 'BisWeightsTBC', 'IsForever'):
            assert word not in text, f'{rel} still names {word} (Amisia is WoW Forever only)'


ALLOWED_HOSTS = ('wowhead.com', 'zamimg.com', 'supabase.co', 'jsdelivr.net', 'fonts.googleapis.com',
                 'github.com', 'blizzard.com', 'w3.org')


def test_no_links_to_fan_sites():
    texts = [('index.html', read(SITE))] + addon_files(exts=('.lua', '.toc', '.xml', '.txt'))
    for rel, text in texts:
        assert 'foreverchanges' not in text.lower(), f'{rel} names foreverchanges (no links to fan sites)'
        for host in re.findall(r'https?://([A-Za-z0-9.-]+)', text):
            assert host.endswith(ALLOWED_HOSTS), f'{rel} links to {host}: only Wowhead and the site\'s own services'


# fetchers kept from the TBC ledger and the first Forever builds; see DECISIONS.md D-03
WOWHEAD_FETCH_KNOWN = {'fill_quality.py', 'build_scan.py'}


def test_no_tool_fetches_from_the_forbidden_sites():
    for name, text in tool_files():
        assert not re.search(r'https?://[^\s\'"]*wago\.tools', text), f'tools/{name} has a wago.tools URL (client tables come only from export_db2.ps1)'
        assert 'foreverchanges' not in text.lower(), f'tools/{name} names foreverchanges'
        if name not in WOWHEAD_FETCH_KNOWN:
            assert not re.search(r'https?://[^\s\'"]*wowhead\.com', text), f'tools/{name} fetches from Wowhead'


def test_no_questie_data_left():
    for name, text in tool_files():
        assert 'questie' not in text.lower(), f'tools/{name} still reads QuestieDB (no licence, removed 2026-10-06)'
    for rel, text in addon_files(skip=('Locales/',)):
        assert 'questie' not in text.lower(), f'{rel} still names QuestieDB'


def header(text):
    out = []
    for line in text.splitlines():
        if not line.startswith('--'):
            break
        out.append(line)
    return '\n'.join(out)


def test_every_generated_file_names_its_generator_and_sources():
    licence = read(os.path.join(ADDON, 'LICENSES', 'AllTheThings-MIT.txt'))
    data = addon_files(skip=('Core/', 'Raid/', 'Gear/', 'Collect/', 'UI/', 'Locales/'))
    data = [(rel, text) for rel, text in data if rel.startswith('Data/')]
    assert len(data) >= 10
    for rel, text in data:
        head = header(text)
        m = re.search(r'generated by tools/(build_\w+\.py)', head, re.I)
        assert m, f'{rel}: the header names no generator (GENERATED by tools/build_*.py)'
        script = read(os.path.join(TOOLS, m.group(1)))
        assert os.path.basename(rel) in script, f'{rel}: tools/{m.group(1)} does not write it'
        assert re.search(r'\bfrom\b|\bSources?:|\btables?\b', head), f'{rel}: the header names no source'
        if 'AllTheThings' in head:
            assert 'MIT' in head and 'LICENSES' in head, f'{rel}: AllTheThings data without its MIT credit'
            assert rel in licence, f'{rel} uses AllTheThings data but LICENSES/AllTheThings-MIT.txt does not list it'
    for rel in re.findall(r'Data/\w+\.lua', licence):
        assert os.path.exists(os.path.join(ADDON, rel)), f'LICENSES names {rel}, which does not exist'


def test_bis_picks_are_a_bis_recommendation_not_a_guild_one():
    texts = [('index.html', read(SITE)), ('tools/bis_picks.json', read(os.path.join(TOOLS, 'bis_picks.json')))]
    texts += addon_files(exts=('.lua',))
    for rel, text in texts:
        low = text.lower()
        for word in ('gilden-empfehlung', 'gildenempfehlung', 'guild recommendation', 'guild pick'):
            assert word not in low, f'{rel} calls the BiS picks "{word}" (they are "BiS-Empfehlung", not the guild\'s)'
    gear = '\n'.join(t for r, t in code_files() if r.startswith(('Gear/', 'UI/')))
    assert 'L["BiS-Empfehlung"]' in gear or 'BiS-Empfehlung)' in gear, 'the badge "BiS-Empfehlung" is shown'


def test_rage_of_the_storm_stays_at_30_to_34():
    picks = json.loads(read(os.path.join(TOOLS, 'bis_picks.json')))
    found = [p for p in picks['picks'] if p.get('item') == 280604]
    assert len(found) == 1, 'the pick of Rage of the Storm (280604) is there once'
    p = found[0]
    assert (p['class'], p['spec'], p['from'], p['to'], p['slot']) == ('SHAMAN', 'enh', 30, 34, 'MAINHAND'), p


# characters the game font has no glyph for (they draw as boxes; the curly quotes unverified, so kept out): use "·", straight quotes and textures
NO_GLYPH = re.compile('[–—…←-↓→•●▶▸„“”]')


def test_no_characters_the_game_font_lacks():
    for rel, text in addon_files(exts=('.lua', '.toc', '.xml')):
        for i, line in enumerate(text.splitlines(), 1):
            m = NO_GLYPH.search(line)
            assert not m, f'{rel}:{i}: U+{ord(m.group(0)):04X} has no glyph in the game font'


def test_the_forever_look():
    widgets = read(os.path.join(ADDON, 'UI', 'Widgets.lua'))
    theme = read(os.path.join(ADDON, 'UI', 'Theme.lua'))
    assert '"SharedButtonSmallTemplate"' in widgets, 'buttons and chips are the red profession-window button'
    assert '"PortraitFrameTemplate"' in widgets, 'windows are the client\'s portrait frame'
    atlases = re.search(r'T\.ATLASES = \{(.*?)\n\}', theme, re.S)
    assert atlases, 'Theme.lua keeps its atlas list'
    listed = set(re.findall(r'"([^"]+)"', atlases.group(1)))
    assert 'common-dropdown-a-button' in listed, 'dropdown and arrow buttons use the client\'s dropdown atlas'
    assert 'UI-HUD-ActionBar-IconFrame' in listed, 'talent nodes keep the thin rounded action button rim'
    assert 'common-dropdown-b-button' not in listed, 'no filter-button chips with the baked-in arrow'
    for rel, text in code_files():
        if rel == 'Core/SelfTest.lua':
            continue
        code = '\n'.join(line.split('--')[0] for line in text.splitlines())
        assert 'common-dropdown-b-button' not in code, f'{rel} uses the arrow chip atlas'


def test_no_foreign_libraries_menus_or_combat_log():
    words = ('LibStub', 'UIDropDownMenu', 'EasyMenu', 'MenuUtil', 'InterfaceOptions_AddCategory',
             'RegisterCanvasLayoutCategory', 'RegisterAddOnCategory', 'COMBAT_LOG_EVENT', 'CombatLogGetCurrentEventInfo')
    for rel, text in addon_files(exts=('.lua', '.xml', '.toc')):
        for w in words:
            assert w not in text, f'{rel} uses {w}'


# other addons are never named in what ships (AllTheThings only where its licence asks; see D-04)
OTHER_ADDONS = ('gargul', 'rclootcouncil', 'questie', 'atlasloot', 'oneforall', 'restedxp', 'tomtom', 'weakauras',
                'bigwigs', 'deadly boss mods', 'cepgp', 'monolithdkp', 'essentialdkp', 'zygor', 'guidelime')


def test_other_addons_are_not_named_in_the_addon():
    for rel, text in addon_files(exts=('.lua', '.toc', '.xml'), skip=('Data/',)):
        low = text.lower()
        for name in OTHER_ADDONS:
            assert name not in low, f'{rel} names {name}'


def test_the_version_stands_only_in_the_toc():
    for rel, text in code_files():
        assert not re.search(r'ns\.VERSION\s*=\s*"', text), f'{rel} sets a version literal (the TOC holds it)'
    core = read(os.path.join(ADDON, 'Core', 'Core.lua'))
    assert re.search(r'ns\.VERSION = GetAddOnMetadata and GetAddOnMetadata\(ADDON, "Version"\)', core)


# ---------------------------------------------------------------- the documents themselves
def test_every_decision_says_how_it_is_kept():
    text = read(DECISIONS)
    blocks = re.split(r'^## ', text, flags=re.M)[1:]
    ids = []
    for b in blocks:
        title = b.splitlines()[0]
        m = re.match(r'(D-\d\d) ', title)
        if not m:
            continue
        ids.append(m.group(1))
        assert re.search(r'^\*\*Datum:\*\* \d{4}-\d{2}-\d{2}', b, re.M), f'{title}: no date'
        for field in ('Entscheidung', 'Grund', 'Folge'):
            assert f'**{field}:**' in b, f'{title}: no {field}'
        assert '**Durchgesetzt durch:**' in b or '**Nicht maschinell geprüft**' in b, f'{title}: says neither how it is enforced nor that it is not'
    assert len(ids) >= 20 and len(ids) == len(set(ids)), 'decisions D-01 ... are numbered once each'


def test_every_test_the_decisions_name_exists():
    text = read(DECISIONS)
    named = re.findall(r'`((?:tools|addon)/[\w./-]+?)(?:::(\w+))?`', text)
    assert named
    for path, func in named:
        full = os.path.join(ROOT, path)
        assert os.path.exists(full), f'DECISIONS.md names {path}, which does not exist'
        if func:
            src = read(full)
            assert re.search(r'^def ' + func + r'\(', src, re.M), f'DECISIONS.md names {path}::{func}, which does not exist'


def test_claude_md_points_to_the_documents():
    text = read(os.path.join(ROOT, 'CLAUDE.md'))
    assert 'docs/ARCHITECTURE.md' in text and 'docs/DECISIONS.md' in text
