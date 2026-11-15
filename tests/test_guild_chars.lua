--[[clients Vulo_Sturmwind Kim_Eisherz Lia_Weide Pug]]
-- The guild characters between clients (F-210, D-135, Core/GuildChars.lua): the message AC goes to the
-- guild right after the guild hello, once per session, not again after a /reload within 30 minutes; its
-- fields (the main, then the own characters of this guild with their item level); a receiver keeps only
-- members' reports, only names of the roster, a character's own report over another's; a bad field
-- drops the whole message; the gap of 300 s per sender.
BUS.setGuild({ { name = "Vulo Sturmwind", rank = 1 }, { name = "Kim Eisherz", rank = 4 }, { name = "Kim Zweit", rank = 4 },
               { name = "Lia Weide", rank = 4 }, { name = "Pug", rank = 4 } })
for _, name in ipairs(CLIENTS) do
    C(name, [[STUB.rankFlags = { [1] = { [22] = true } }
        STUB.officer = STUB.player == "Vulo Sturmwind"
        STUB.leader = false
        STUB.level = 60
        _G.GetAverageItemLevel = function() return 40, 40 end
        -- Pug is no member: the others' rosters lack him (his own client sends to the guild channel)
        if STUB.player ~= "Pug" then
            for i = #STUB.guild, 1, -1 do if STUB.guild[i].name == "Pug" then table.remove(STUB.guild, i) end end
        end
        STUB.fire("GUILD_ROSTER_UPDATE")]])
end
-- Kim's account: a level 60 character in the guild (the main), one in another guild; Kim Eisherz is 25
C("Kim Eisherz", [[STUB.level = 25
    _G.GetAverageItemLevel = function() return 31.6, 31.4 end
    AmisiaDB.account = { v = 1, chars = {
        ["Kim Zweit"] = { class = "MAGE", level = 60, il = 58, guild = "Amisia", at = time() - 3600 },
        ["Kim Fremd"] = { class = "ROGUE", level = 60, il = 70, guild = "Andere", at = time() - 3600 },
    } }]])

---------------------------------------------------------------------------
-- the hello and AC: once, together, 20 to 60 s after the login
---------------------------------------------------------------------------
for _, name in ipairs(CLIENTS) do C(name, "STUB.fire('PLAYER_LOGIN')") end
BUS.tick(19.9)
assert(BUS.count({ kind = "AC" }) == 0, "nothing before the hello")
BUS.tick(40.2)
for _, name in ipairs({ "Vulo Sturmwind", "Kim Eisherz", "Lia Weide", "Pug" }) do
    assert(BUS.count({ kind = "AC", chan = "GUILD", sender = name }) == 1, name)
    assert(BUS.count({ kind = "HI", chan = "GUILD", sender = name }) == 1, name)
end
local kimAC
for _, m in ipairs(BUS.sent) do if m.sender == "Kim Eisherz" and m.kind == "AC" then kimAC = m.text end end
assert(kimAC == "1AC\tKim Zweit\tKim Zweit:58\tKim Eisherz:31", "the main first, then by level, the other guild left out: " .. kimAC)
-- the own account kept the character that logged in
assert(C("Kim Eisherz", "AmisiaDB.account.chars['Kim Eisherz'].level") == 25)
assert(C("Kim Eisherz", "AmisiaDB.account.chars['Kim Eisherz'].guild") == "Amisia")
assert(C("Kim Eisherz", "AmisiaDB.account.chars['Kim Eisherz'].class") == "WARRIOR")

-- what Vulo keeps: both of Kim's characters with their main; Kim Eisherz reported itself
local list = C("Vulo Sturmwind", "AmisiaDB.guildChars.list")
assert(list["Kim Zweit"].main == "Kim Zweit" and list["Kim Zweit"].il == 58 and list["Kim Zweit"].by == "Kim Eisherz"
    and list["Kim Zweit"].self == nil, "Kim Zweit by another character")
assert(list["Kim Eisherz"].main == "Kim Zweit" and list["Kim Eisherz"].il == 31 and list["Kim Eisherz"].self == true, "Kim's own word")
assert(list["Kim Fremd"] == nil, "not reported")
-- Pug is no member: nobody kept his report
assert(list["Pug"] == nil, "a sender outside the guild is ignored")
assert(C("Kim Eisherz", "AmisiaDB.guildChars.list['Pug']") == nil)
-- Lia and Vulo reported themselves
assert(list["Lia Weide"].main == "Lia Weide" and list["Lia Weide"].il == 40 and list["Lia Weide"].self == true)

---------------------------------------------------------------------------
-- a bad field drops the whole message; names outside the roster are dropped; the own word wins
---------------------------------------------------------------------------
local function send(name, fields)
    local parts = {}
    for i, f in ipairs(fields) do parts[i] = ("%q"):format(f) end
    assert(C(name, "NS.CommSend('AC', { " .. table.concat(parts, ", ") .. " }, 'GUILD')") == true)
    BUS.tick(1)
end
-- 300 s after Lia's AC of the login: a bad message would count now, but is dropped (and does not start the gap)
BUS.tick(300)
send("Lia Weide", { "Lia Weide", "Lia Weide:1000" })
assert(C("Vulo Sturmwind", "AmisiaDB.guildChars.list['Lia Weide'].il") == 40, "an item level of 1000 drops it")
send("Lia Weide", { "Lia Weide", "Lia Weide:0" })
send("Lia Weide", { "Lia Weide", "Lia Weide:45", "Lia 2:30" })
send("Lia Weide", { "Lia9", "Lia Weide:45" })
local eleven = { "Lia Weide" }
for i = 1, 11 do eleven[#eleven + 1] = "Lia Weide:" .. (40 + i) end
send("Lia Weide", eleven)
send("Lia Weide", { "Lia Weide" })
assert(C("Vulo Sturmwind", "AmisiaDB.guildChars.list['Lia Weide'].il") == 40, "item level 0, a digit in a name or the main, 11 entries, none: all dropped")
-- a good one: Lia claims Kim Eisherz and a stranger as her alts
send("Lia Weide", { "Lia Weide", "Lia Weide:44", "Kim Eisherz:12", "Fremder Name:50" })
list = C("Vulo Sturmwind", "AmisiaDB.guildChars.list")
assert(list["Lia Weide"].il == 44, "the good one counts")
assert(list["Fremder Name"] == nil, "a name outside the roster is dropped")
assert(list["Kim Eisherz"].main == "Kim Zweit" and list["Kim Eisherz"].il == 31 and list["Kim Eisherz"].by == "Kim Eisherz",
    "Kim's own word wins over Lia's")
-- the next one within 300 s is not handled
send("Lia Weide", { "Lia Weide", "Lia Weide:50" })
assert(C("Vulo Sturmwind", "AmisiaDB.guildChars.list['Lia Weide'].il") == 44, "one AC per sender in 300 s")
BUS.tick(300)
send("Lia Weide", { "Lia Weide", "Lia Weide:50" })
assert(C("Vulo Sturmwind", "AmisiaDB.guildChars.list['Lia Weide'].il") == 50, "after 300 s again")

-- the members page's view on Vulo: Kim Eisherz under Kim Zweit, from Amisia
local view = C("Vulo Sturmwind", "NS.GuildCharsView()")
assert(view["kim eisherz"].main == "Kim Zweit" and view["kim eisherz"].src == "amisia" and view["kim eisherz"].il == 31)
assert(view["kim zweit"].main == nil and view["kim zweit"].il == 58)
-- Kim's own view: its account
view = C("Kim Eisherz", "NS.GuildCharsView()")
assert(view["kim eisherz"].main == "Kim Zweit" and view["kim eisherz"].src == "amisia" and view["kim eisherz"].il == 31, "own account")

---------------------------------------------------------------------------
-- a /reload within 30 minutes: no second AC; after 30 minutes one with the hello
---------------------------------------------------------------------------
BUS.reload("Kim Eisherz")
C("Kim Eisherz", "_G.GetAverageItemLevel = function() return 32, 32 end STUB.fire('PLAYER_LOGIN')")
BUS.tick(61)
assert(BUS.count({ kind = "AC", sender = "Kim Eisherz" }) == 1, "no AC after the reload")
assert(C("Kim Eisherz", "AmisiaDB.account.chars['Kim Zweit'].il") == 58, "the account survives the reload")
BUS.tick(1800)
BUS.reload("Kim Eisherz")
C("Kim Eisherz", "_G.GetAverageItemLevel = function() return 32, 32 end STUB.fire('PLAYER_LOGIN')")
BUS.tick(61)
assert(BUS.count({ kind = "AC", sender = "Kim Eisherz", chan = "GUILD" }) == 2, "after 30 minutes AC goes again with the hello")
assert(C("Vulo Sturmwind", "AmisiaDB.guildChars.list['Kim Eisherz'].il") == 32, "the new item level")
print("guild chars ok")
