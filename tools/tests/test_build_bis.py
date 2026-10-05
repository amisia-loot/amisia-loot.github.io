"""tools/build_bis.py: the TBC loot tables read from small excerpts, tier tokens turned into
class-limited set pieces, phases from the site, German raid boss names, the optional client
tables, the Lua output with its guard, and a build that repeats exactly."""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import build_bis  # noqa: E402

HEAD = '''local addonname, private = ...
local AtlasLoot = _G.AtlasLoot
if AtlasLoot:GameVersion_LT(AtlasLoot.BC_VERSION_NUM) then return end
local data = AtlasLoot.ItemDB:Add(addonname, 1, AtlasLoot.BC_VERSION_NUM)
local AL = AtlasLoot.Locales
local ALIL = AtlasLoot.IngameLocales
'''

DUNGEONS = HEAD + '''
local NORMAL_DIFF = data:AddDifficulty("NORMAL", nil, nil, nil, true)
local HEROIC_DIFF = data:AddDifficulty("HEROIC", nil, nil, nil, true)
local RAID25_DIFF = data:AddDifficulty("25RAID")
local NORMAL_ITTYPE = data:AddItemTableType("Item", "Item")
local DUNGEON_CONTENT = data:AddContentType(AL["Dungeons"], ATLASLOOT_DUNGEON_COLOR)
local RAID10_CONTENT = data:AddContentType(AL["10 Raids"], ATLASLOOT_RAID20_COLOR)
local RAID25_CONTENT = data:AddContentType(AL["25 Raids"], ATLASLOOT_RAID40_COLOR)
local KEYS = { name = AL["Keys"], ExtraList = true, IgnoreAsSource = true, [NORMAL_DIFF] = { { 2, 27991 } } }
data["TheShatteredHalls"] = {
    MapID = 3714,
    InstanceID = 540,
    ContentType = DUNGEON_CONTENT,
    items = {
        { -- boss
            name = AL["Warchief Kargath Bladefist"],
            [NORMAL_DIFF] = {
                { 1, 27527 }, -- Greaves of the Shatterer
                { 2, 23001, [ATLASLOOT_IT_ALLIANCE] = 23002 }, -- Faction Ring
            },
            [HEROIC_DIFF] = {
                { 1, 29434 }, -- Badge of Justice
                { 2, 29255 }, -- Bands of Rarefied Magic
            },
        },
        AtlasLoot:GameVersion_GE(AtlasLoot.WRATH_VERSION_NUM, { name = "Wrath only", [NORMAL_DIFF] = { { 1, 99999 } } }),
        KEYS,
    },
}
data["Karazhan"] = {
    MapID = 3457,
    InstanceID = 532,
    ContentType = RAID10_CONTENT,
    items = {
        {
            name = AL["Prince Malchezaar"],
            [NORMAL_DIFF] = {
                { 1, 28770 }, -- Nathrezim Mindblade
                { 2, "INV_Box_01", nil, AL["Misc"], nil },
                { 3, 29760 }, -- Helm of the Fallen Champion
                { 4, 22560 }, -- Formula: Enchant Weapon - Mongoose
            },
        },
    },
}
data["MagtheridonsLair"] = {
    MapID = 3836,
    InstanceID = 544,
    ContentType = RAID25_CONTENT,
    items = {
        {
            name = AL["Magtheridon"],
            [NORMAL_DIFF] = {
                { 1, 28777 }, -- Cloak of the Pit Stalker
                { 17, 29753 }, -- Chestguard of the Fallen Defender
                { 20, 32385 }, -- Magtheridon's Head
            },
        },
    },
}
data["SerpentshrineCavern"] = {
    MapID = 3607,
    InstanceID = 548,
    ContentType = RAID25_CONTENT,
    ContentPhaseBC = 2,
    items = {
        { name = AL["Lady Vashj"], [RAID25_DIFF] = { { 1, 30107 } } }, -- Vestments of the Sea-Witch
    },
}
data["MagistersTerrace"] = {
    MapID = 4131,
    InstanceID = 585,
    ContentType = DUNGEON_CONTENT,
    ContentPhaseBC = 5,
    items = {
        { name = AL["Kael'thas Sunstrider"], [HEROIC_DIFF] = { { 1, 34610 } } }, -- Scarlet Sin'dorei Robes
    },
}
'''

FACTIONS = HEAD + '''
local NORMAL_DIFF = data:AddDifficulty(AL["Normal"], "n", 1, nil, true)
local ALLIANCE_DIFF, HORDE_DIFF
if UnitFactionGroup("player") == "Horde" then
    HORDE_DIFF = data:AddDifficulty(FACTION_HORDE, "horde", nil, 1)
    ALLIANCE_DIFF = data:AddDifficulty(FACTION_ALLIANCE, "alliance", nil, 1)
else
    ALLIANCE_DIFF = data:AddDifficulty(FACTION_ALLIANCE, "alliance", nil, 1)
    HORDE_DIFF = data:AddDifficulty(FACTION_HORDE, "horde", nil, 1)
end
local FACTIONS_CONTENT = data:AddContentType(AL["Factions"], ATLASLOOT_FACTION_COLOR)
data["TheShatar"] = {
    FactionID = 935,
    ContentType = FACTIONS_CONTENT,
    items = {
        { name = ALIL["Exalted"], [NORMAL_DIFF] = {
            { 1, "f935rep8" },
            { 2, 29177 }, -- A'dal's Command
            { 17, 33155 }, -- Design: Kailee's Rose
        } },
        { name = ALIL["Revered"], [NORMAL_DIFF] = {
            { 1, "f935rep7" },
            { 2, 29175 }, -- Gavel of Pure Light
        } },
    },
}
data["Thrallmar"] = {
    FactionID = 947,
    ContentType = FACTIONS_CONTENT,
    items = {
        { name = ALIL["Honored"], [HORDE_DIFF] = {
            { 1, "f947rep6" },
            { 2, 25738 }, -- Brute Cloak of the Ogre-Magi
        } },
    },
}
'''

COLLECTIONS = '''local function C_Map_GetAreaInfo(id)
    local d = C_Map.GetAreaInfo(id)
    return d or "GetAreaInfo"..id
end
''' + HEAD + '''
local GetForVersion = AtlasLoot.ReturnForGameVersion
local NORMAL_DIFF = data:AddDifficulty("NORMAL", nil, nil, nil, true)
local NORMAL_ITTYPE = data:AddItemTableType("Item", "Item")
local VENDOR_CONTENT = data:AddContentType(AL["Vendor"], ATLASLOOT_DUNGEON_COLOR)
data["BadgeofJustice4"] = {
    name = format(AL["'%s %s' Vendor"], AL["Badge of Justice"], "P4"),
    ContentType = VENDOR_CONTENT,
    TableType = NORMAL_ITTYPE,
    items = { { name = ALIL["Neck"], [NORMAL_DIFF] = { { 1, 33296 } } } }, -- Brooch of Deftness
}
data["WorldEpicsBC"] = {
    name = AL["World Epics"],
    TableType = NORMAL_ITTYPE,
    CorrespondingFields = private.WORLD_EPICS,
    items = { { name = AL["Equip"], [NORMAL_ITTYPE] = { { 1, 31329 } } } }, -- Lifegiving Cloak
}
'''

CRAFTING = HEAD + '''
local GetColorSkill = AtlasLoot.Data.Profession.GetColorSkillRankNoSpell
local NORMAL_DIFF = data:AddDifficulty(AL["Normal"], "n", 1, nil, true)
local PROF_ITTYPE = data:AddItemTableType("Profession", "Item")
local PROF_CONTENT = data:AddContentType(ALIL["Professions"], ATLASLOOT_PRIMPROFESSION_COLOR)
data["TailoringBC"] = {
    name = ALIL["Tailoring"],
    ContentType = PROF_CONTENT,
    TableType = PROF_ITTYPE,
    items = {
        { name = AL["Armor"].." - "..ALIL["Chest"], [NORMAL_DIFF] = { { 1, 26759 } } }, -- Frozen Shadoweave Robe (375)
        { name = ALIL["Bag"], [NORMAL_DIFF] = { { 1, 26755 } } }, -- Spellfire Bag (375)
    },
}
data["CookingBC"] = {
    name = ALIL["Cooking"],
    items = { { name = AL["Misc"], [NORMAL_DIFF] = { { 1, 33296 } } } },
}
'''

TOKENS = '''local ALName, ALPrivate = ...
local AtlasLoot = _G.AtlasLoot
local Token = {}
AtlasLoot.Data.Token = Token
local AL = AtlasLoot.Locales
local format = format
local ICONS = ALPrivate.CLASS_ICON_PATH_ITEM_DB
local TOKEN, TOKEN_DATA = AtlasLoot:GetGameVersionDataTable()
TOKEN_DATA.CLASSIC = { [18401] = { 18348 } }
if AtlasLoot:GameVersion_GE(AtlasLoot.BC_VERSION_NUM) then
    TOKEN_DATA.BCC = {
        [29753] = { ICONS.WARRIOR, 29012, 29019, 0, ICONS.PRIEST, 29050, 29056, 0, ICONS.DRUID, 29087, type = 6 }, -- Chestguard of the Fallen Defender
        [29760] = { ICONS.PALADIN, 29061, 0, ICONS.ROGUE, 29044, type = 6 }, -- Helm of the Fallen Champion
        [32385] = { 28791, 28790, type = 3 }, -- Magtheridon's Head
        [34846] = { {32230,"1-3"}, 0, {23441,"1-2"}, type = 2 }, -- Black Sack of Gems
        [31901] = 31907,
    }
end
local function Init() end
AtlasLoot:AddInitFunc(Init)
'''

PROFESSIONS = '''PROFESSION_DATA.CLASSIC = {
    [2658] = {2842,7,75,115,130,{2775},{1}},
}
    PROFESSION_DATA.BCC = {
        [26759] = {21871,8,375,390,405,{21877},{8}},
        [26755] = {21841,8,375,390,405,{21877},{8}},
    }
    PROFESSION_DATA.WRATH = {
    }
'''

TEXTS = {'dungeons': DUNGEONS, 'factions': FACTIONS, 'collections': COLLECTIONS, 'crafting': CRAFTING,
         'tokens': TOKENS, 'professions': PROFESSIONS}

BOSSNAMES = ('window.__BOSSNAMES=window.__BOSSNAMES||{};\n'
             'window.__BOSSNAMES["tbc"]={"Prinz Malchezaar":"Prince Malchezaar","Príncipe Malchezaar":"Prince Malchezaar",'
             '"Принц Малчезар":"Prince Malchezaar","Dame Vashj":"Lady Vashj","Леди Вайш":"Lady Vashj"};\n')


def parsed():
    return build_bis.parse_atlas(TEXTS)


def rec_of(src, nums, kind):
    return [src.rows[n - 1] for n in nums if src.rows[n - 1][0] == kind]


def build(tmp_path, items_info=None):
    bn = tmp_path / 'bossnames.js'
    bn.write_text(BOSSNAMES, encoding='utf-8')
    german = build_bis.german_from_bossnames(str(bn))
    return build_bis.build(parsed(), build_bis.raid_phases(), german, items_info)


def test_tables_are_read():
    a = parsed()
    insts = {i['key']: i for i in a['instances']}
    sh = insts['TheShatteredHalls']
    assert sh['kind'] == 'dungeon' and sh['inst'] == 540 and sh['area'] == 3714 and sh['name'] == 'The Shattered Halls'
    assert sh['bosses'] == [{'name': 'Warchief Kargath Bladefist', 'normal': [27527, 23001], 'heroic': [29434, 29255],
                             'phase': 0}], 'keys and Wrath-only entries stay out'
    assert insts['Karazhan']['kind'] == 'raid' and insts['MagistersTerrace']['phase'] == 5
    fac = {f['key']: f for f in a['factions']}
    assert fac['TheShatar']['ranks'] == {'7': [29175], '8': [29177, 33155]} and fac['TheShatar']['id'] == 935
    assert fac['Thrallmar']['ranks'] == {'6H': [25738]} and fac['Thrallmar']['side'] == 'H'
    assert a['vendors'] == [{'key': 'BadgeofJustice4', 'phase': 4, 'items': [33296]}]
    assert a['world'] == [31329]
    assert a['crafts'] == [{'item': 21871, 'prof': 'tailoring', 'skill': 375}], 'gear sections only'
    assert a['tokens']['29753'] == {'WARRIOR': [29012, 29019], 'PRIEST': [29050, 29056], 'DRUID': [29087]}
    assert a['tokens']['32385'] == {'': [28791, 28790]} and '34846' not in a['tokens'] and '31901' not in a['tokens']
    assert a['names']['27527'] == 'Greaves of the Shatterer' and a['names']['21871'] == 'Frozen Shadoweave Robe'
    assert a['names']['29753'] == 'Chestguard of the Fallen Defender'


def test_phases_come_from_the_site():
    ph = build_bis.raid_phases()
    assert ph[532] == 1 and ph[565] == 1 and ph[544] == 1
    assert ph[548] == 2 and ph[550] == 2 and ph[534] == 3 and ph[564] == 3 and ph[568] == 4 and ph[580] == 5


def test_german_raid_boss_names(tmp_path):
    bn = tmp_path / 'bossnames.js'
    bn.write_text(BOSSNAMES, encoding='utf-8')
    german = build_bis.german_from_bossnames(str(bn))
    assert german == {'Prince Malchezaar': 'Prinz Malchezaar'}, 'a French-looking single name stays English'


def test_german_names_from_the_real_table():
    german = build_bis.german_from_bossnames()
    assert german['Attumen the Huntsman'] == 'Attumen der Jäger'
    assert german['The Lurker Below'] == 'Das Grauen aus der Tiefe'
    assert german['Prince Malchezaar'] == 'Prinz Malchezaar'
    assert 'Lady Vashj' not in german and "Kael'thas Sunstrider" not in german, 'unsure ones stay English'


def test_tokens_become_class_limited_set_pieces(tmp_path):
    src, rows, report = build(tmp_path)
    assert 29753 not in rows and 29760 not in rows and 32385 not in rows, 'tokens are no gear'
    row, nums = rows[29012]
    assert row[7] == 1, 'warrior bit'
    assert rec_of(src, nums, 'X') == [('X', "Magtheridon's Lair", 'Magtheridon', 544, 3836, 1, 29753)]
    assert rows[29050][0][7] == 16 and rows[29087][0][7] == 1024
    assert rows[29061][0][7] == 2 and rec_of(src, rows[29061][1], 'X')[0][2:] == ('Prinz Malchezaar', 532, 3457, 1, 29760)
    assert rows[28791][0][7] == 0, 'a quest reward head is for everyone'
    assert rec_of(src, rows[28777][1], 'X') == [('X', "Magtheridon's Lair", 'Magtheridon', 544, 3836, 1, 0)]
    assert report['tokens without pieces'] == []


def test_sources_phases_heroic_reputation_vendors(tmp_path):
    src, rows, report = build(tmp_path)
    assert rec_of(src, rows[28770][1], 'X') == [('X', 'Karazhan', 'Prinz Malchezaar', 532, 3457, 1, 0)]
    assert rec_of(src, rows[30107][1], 'X')[0][5] == 2, 'SSC is phase 2'
    assert rec_of(src, rows[27527][1], 'D') == [('D', 'The Shattered Halls', 'Warchief Kargath Bladefist', None, 540, 3714, 0)]
    assert rec_of(src, rows[29255][1], 'D') == [('D', 'The Shattered Halls', 'Warchief Kargath Bladefist', None, 540, 3714, 1)]
    assert rec_of(src, rows[34610][1], 'D') == [('D', "Magisters' Terrace", "Kael'thas Sunstrider", None, 585, 4131, 1, 5)]
    assert rec_of(src, rows[29177][1], 'F') == [('F', "The Sha'tar", 8, 935, '')]
    assert rec_of(src, rows[25738][1], 'F') == [('F', 'Thrallmar', 6, 947, 'H')]
    assert rec_of(src, rows[33296][1], 'V') == [('V', "G'eras", 111, '', 'Abzeichen der Gerechtigkeit', 4)]
    assert rec_of(src, rows[31329][1], 'W') == [('W', None, 70, 73, 0)]
    assert rec_of(src, rows[21871][1], 'C') == [('C', 'tailoring', 375)]
    assert 29434 not in rows and 22560 not in rows and 33155 not in rows and 21841 not in rows, 'badges, recipes, bags'
    assert rows[27527][0] == ['', 0, 0, 0, 0, 0, 0, 0, 0, 0], 'the client fills the row'
    assert report['kinds']['X'] >= 5 and report['phases'][2] == 1 and report['phases'][4] == 1
    assert "Serpentshrine Cavern: Lady Vashj" in report['bosses without German name']


def test_client_tables_fill_rows_and_drop_what_is_no_gear(tmp_path):
    item = tmp_path / 'Item.csv'
    item.write_text('ID,ClassID,SubclassID,InventoryType\n27527,4,4,7\n23001,3,0,0\n29012,4,4,5\n', encoding='utf-8')
    sparse = tmp_path / 'ItemSparse.csv'
    sparse.write_text('ID,AllowableClass,ItemDelay,RequiredSkill,ItemLevel,RequiredLevel,OverallQualityID,Bonding,InventoryType\n'
                      '27527,-1,0,0,115,70,3,1,7\n23001,-1,0,0,100,0,2,0,0\n29012,1,0,0,120,70,4,1,5\n', encoding='utf-8')
    out = tmp_path / 'items.json'
    build_bis.refresh_items(str(item), str(sparse), {27527, 23001, 29012}, path=str(out))
    info = json.loads(out.read_text(encoding='utf-8'))
    assert info['items']['27527'] == ['LEGS', 4, 4, 70, 3, 1, 115, 0, 0, 0]
    assert info['not_gear'] == [23001]
    src, rows, report = build(tmp_path, info)
    assert rows[27527][0] == ['LEGS', 4, 4, 70, 3, 1, 115, 0, 0, 0]
    assert 23001 not in rows and rows[29012][0][7] == 1
    assert set(rows) == {27527, 29012}, 'only what the client tables call gear'


def test_output_has_header_licence_and_guard_and_repeats(tmp_path):
    src, rows, _ = build(tmp_path)
    out = tmp_path / 'BisDataTBC.lua'
    build_bis.write_lua(str(out), src, rows, '2026-10-05', {27527: 'STRENGTH=5'})
    text = out.read_text(encoding='utf-8')
    lines = text.split('\n')
    assert lines[0] == '-- GENERATED by tools/build_bis.py. Do not edit; rebuild instead.'
    assert lines[1] == '-- Sources: AtlasLootClassic (GPL-2.0), the Amisia loot tables, the Amisia item scan.'
    assert lines[2] == 'local _, ns = ...' and lines[3] == 'if ns.IsForever and ns.IsForever() then return end'
    assert 'game = "tbc", cap = 70, built = "2026-10-05"' in text and '[27527] = "STRENGTH=5"' in text
    first = out.read_bytes()
    src, rows, _ = build(tmp_path)
    build_bis.write_lua(str(out), src, rows, '2026-10-05', {27527: 'STRENGTH=5'})
    assert out.read_bytes() == first, 'the same input gives the same file'

    from lupa.lua51 import LuaRuntime
    for forever in (False, True):
        lua = LuaRuntime(unpack_returned_tuples=True)
        ns = lua.eval('function(f) return { IsForever = function() return f end } end')(forever)
        lua.eval('function(s, ns) return assert(loadstring(s, "@BisDataTBC.lua"))("Amisia", ns) end')(text, ns)
        if forever:
            assert ns.GEAR is None, 'the guard skips the data on Forever'
        else:
            assert ns.GEAR.game == 'tbc' and ns.GEAR.cap == 70 and ns.GEAR.I[29012][8] == 1
            assert ns.GEAR.S[ns.GEAR.I[29012][11]][7] == 29753


def test_weights_cover_every_class_with_a_unit(tmp_path):
    out = tmp_path / 'BisWeightsTBC.lua'
    build_bis.write_weights(str(out))
    text = out.read_text(encoding='utf-8')
    assert "Amisia's own weights" in text and 'if ns.IsForever and ns.IsForever() then return end' in text
    from lupa.lua51 import LuaRuntime
    lua = LuaRuntime(unpack_returned_tuples=True)
    ns = lua.eval('{ IsForever = function() return false end }')
    lua.eval('function(s, ns) return assert(loadstring(s))("Amisia", ns) end')(text, ns)
    w = ns.GEAR_WEIGHTS
    for cls in build_bis.CLASS_ORDER:
        specs = w.specs[cls]
        assert specs and len(specs) >= 1, cls
        for i in range(1, len(specs) + 1):
            sp = specs[i]
            assert sp.all.unit in ('AP', 'SP', 'HEAL', 'STA') and sp.all[sp.all.unit] == 1, f'{cls} {sp.key}'
    assert w.specs.WARRIOR[1].all.OHDPS == 0.5 and w.specs.MAGE[1].all.SP_ARCANE == 1
    assert [w.specs.DRUID[i].key for i in range(1, 5)] == ['balance', 'feral', 'bear', 'resto']
