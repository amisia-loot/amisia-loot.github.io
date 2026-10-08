"""tools/lua_data.py: the lazy form of the big generated data files (Core/LazyData.lua builds their
tables on first use): the long string's level, the count, the way back, and the five shipped files."""
import os
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import lua_data  # noqa: E402

ADDON = os.path.join(os.path.dirname(os.path.dirname(HERE)), 'addon', 'Amisia')
SHIPPED = {'GearData': ('GEAR', 'I'), 'MapData': ('MAP', 'P'), 'QuestData': ('QUEST_DATA', 'Q'),
           'ProfessionData': ('PROFESSIONS', 'P'), 'TalentData': ('TALENTS', 'classes'),
           'MageScrollData': ('MAGESCROLLS', 'scrolls'), 'GearWeights': ('GEAR_WEIGHTS', 'specs')}

PLAIN = 'local _, ns = ...\n\n-- a comment\nns.X = {\n    a = "x]=]y [[z]]",\n    b = { 1, 2 },\n}\n'


def test_lazy_and_back():
    text = lua_data.lazy(PLAIN, 'X', 2)
    assert text.startswith('local _, ns = ...\n\n-- a comment\nns.LazyData("X", [==[\nreturn {\n')
    assert text.endswith('}\n]==], 2)\n'), 'a level the text does not hold, the count at the end'
    assert lua_data.eager(text) == PLAIN
    assert lua_data.eager(PLAIN) == PLAIN, 'a plain file stays as it is'
    # level 1 at least: Lua 5.1 refuses "[[" inside a level-0 long string
    assert lua_data.lazy(PLAIN.replace(']=]', ''), 'X').endswith('}\n]=])\n'), 'level 1 and no count'
    with pytest.raises(ValueError):
        lua_data.lazy(PLAIN, 'Y')


def test_load_builds_at_once():
    pytest.importorskip('lupa')
    ns = lua_data.load(lua_data.lazy(PLAIN, 'X', 2))
    assert ns.X.a == 'x]=]y [[z]]' and ns.X.b[2] == 2 and ns.LazyData is None


@pytest.mark.parametrize('name', sorted(SHIPPED))
def test_shipped_files_wait_for_their_first_use(name):
    key, field = SHIPPED[name]
    with open(os.path.join(ADDON, 'Data', name + '.lua'), encoding='utf-8') as fh:
        text = fh.read()
    assert f'\nns.LazyData("{key}", [' in text and f'\nns.{key} = {{' not in text
    plain = lua_data.eager(text)
    assert f'\nns.{key} = {{' in plain
    pytest.importorskip('lupa')
    ns = lua_data.load(text, name + '.lua')
    n = int(text.rsplit(', ', 1)[1].rstrip(')\n'))
    assert n == len(list(ns[key][field].keys())), 'the count is the number of entries'
