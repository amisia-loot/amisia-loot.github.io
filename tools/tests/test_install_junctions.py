"""tools/install_junctions.ps1 (runs once on the PC, no PowerShell here; F-202, D-130): read as text. It
names the three addon folders of tools/modules.py and the release folders tools/release_addon.sh writes,
gives each WoW client the folders that load there (the gear module only WoW Forever), removes junctions
only (never a real folder, never with rmdir /s or Remove-Item) and stays plain ASCII for Windows
PowerShell 5.1."""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
SCRIPT = os.path.join(TOOLS, 'install_junctions.ps1')
sys.path.insert(0, TOOLS)
import modules  # noqa: E402


def source():
    with open(SCRIPT, encoding='utf-8') as fh:
        return fh.read()


def names(block):
    return re.findall(r"'([A-Za-z_]+)'", block)


def test_every_client_gets_its_folders():
    text = source()
    folders = re.search(r"^\$Folders = @\(([^)]*)\)", text, re.M)
    assert folders and names(folders.group(1)) == [modules.FOLDERS[m] for m in modules.MODULES]
    block = re.search(r"^\$Clients = \[ordered\]@\{(.*?)^\}", text, re.M | re.S)
    assert block, '$Clients'
    clients = {}
    for line in block.group(1).strip().split('\n'):
        m = re.match(r"\s*'(\w+)'\s*=\s*@\(([^)]*)\)", line)
        assert m, line
        clients[m.group(1)] = names(m.group(2))
    assert clients == {
        '_forever_': ['Amisia', 'Amisia_Raid', 'Amisia_Gear'],
        '_anniversary_': ['Amisia', 'Amisia_Raid'],
        '_classic_era_': ['Amisia', 'Amisia_Raid'],
    }


def test_the_release_folder_is_the_one_syncthing_fills():
    text = source()
    assert "Join-Path $env:USERPROFILE 'VuloSync\\Amisia'" in text
    with open(os.path.join(TOOLS, 'release_addon.sh'), encoding='utf-8') as fh:
        release = fh.read()
    assert 'FOLDERS=(Amisia Amisia_Raid Amisia_Gear)' in release
    # each folder checked with its TOC before anything changes
    assert re.search(r'Join-Path \(Join-Path \$Release \$f\) "\$f\.toc"', text)


def test_only_junctions_go():
    text = source()
    assert 'Remove-Item' not in text and not re.search(r'rmdir\s+/s', text, re.I)
    assert re.search(r'cmd /c rmdir "\$Path"', text)
    # a real folder is reported and left alone
    assert 'echter Ordner, bleibt unberuehrt' in text
    assert 'ReparsePoint' in text and 'New-Item -ItemType Junction' in text


def test_plain_ascii():
    with open(SCRIPT, 'rb') as fh:
        raw = fh.read()
    assert all(b < 128 for b in raw), 'Windows PowerShell 5.1 reads a script without BOM as ANSI'
