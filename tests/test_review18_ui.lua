-- Review of 1.8 (UI): the W and SR marks follow Forever's scrolling loot window and sit on the
-- item icon, the guild view forgets the last import after clearing, the toast puts its link into
-- a chat box and stays clear of the award dialog, the roll window and the error line, item names
-- that arrive late show without a stamp bump, and a saved place the data lacks falls back.
local failed = {}
local function check(label, fn)
    local ok, err = pcall(fn)
    if not ok then failed[#failed + 1] = label .. ": " .. tostring(err) end
end
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
STUB.class, STUB.level = "WARRIOR", 70
STUB.roster = { { name = "Vuloo", class = "WARRIOR" }, { name = "Anna", class = "PRIEST" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
assert(NS.Set("bis.tooltip", false))

local wishedLink = STUB.item(28830, "Drachenwirbeltrophäe", 4)
local otherLink = STUB.item(31001, "Ohne Wunsch", 4)

---------------------------------------------------------------------------
-- 8. marks follow the scroll box; 9. both sit on the item icon
---------------------------------------------------------------------------
check("8 scroll", function()
    assert(NS.SetGuildWishes("#AMISIA-WL 1 forever 2026-10-05\nW 28830 3 Anna\n#END"))
    assert(NS.SetSoftRes("Anna " .. wishedLink) == 1)
    STUB.loot = { { link = otherLink }, { link = otherLink }, { link = wishedLink } }
    local box = LootFrame.ScrollBox
    local f1, f2 = box.frames[1], box.frames[2]
    box:ShowFrom(1)
    STUB.fire("LOOT_OPENED"); STUB.tick(0)
    assert(not NS.GuildWishMarkShown(f1) and not NS.GuildWishMarkShown(f2) and not NS.SoftResMarkShown(f2), "slots 1 and 2: nothing")
    box:ShowFrom(2)   -- scrolled: the second element shows slot 3 now
    assert(NS.GuildWishMarkShown(f2) and NS.SoftResMarkShown(f2), "the element that took slot 3 is marked")
    assert(not NS.GuildWishMarkShown(f1) and not NS.SoftResMarkShown(f1))
    box:ShowFrom(1)   -- back: the element shows slot 2 again
    assert(not NS.GuildWishMarkShown(f2) and not NS.SoftResMarkShown(f2), "the marks leave with the slot")
end)

check("9 icon", function()
    local box = LootFrame.ScrollBox
    local f2 = box.frames[2]
    box:ShowFrom(2)
    NS.MarkGuildWishLoot()
    local w = NS.GuildWishMark(f2)
    assert(w and w:IsShown(), "W shown")
    assert(w.parent == f2.Item and w.points.TOPRIGHT and w.points.TOPRIGHT.rel == f2.Item,
        "W at the top right of the icon, not of the element (its quality text sits there)")
    local sr = NS.SoftResMark(f2)
    assert(sr and sr.parent == f2.Item and sr.points.TOPLEFT and sr.points.TOPLEFT.rel == f2.Item, "SR at the top left of the icon")
    NS.ClearSoftRes()
end)

---------------------------------------------------------------------------
-- 10. the guild view forgets the import result once the list is cleared
---------------------------------------------------------------------------
check("10 cleared", function()
    NS.ShowGear("guild")
    local U = NS.GearPageFrame().guild
    U.area.box:SetText("#AMISIA-WL 1 forever 2026-10-05\nW 28830 3 Anna nur MS\nW 31000 2 Bob\n#END")
    U.importBtn:Click()
    assert(U.hint:GetText() == "2 Wünsche übernommen, 0 Zeilen nicht erkannt.", tostring(U.hint:GetText()))
    U.clearBtn:Click(); STUB.acceptPopup()
    assert(NS.GuildWishesInfo() == nil)
    assert(U.hint:GetText() == "Auf der Website im Reiter Wishlist: Copy for the addon.", "the old result is gone: " .. tostring(U.hint:GetText()))
    assert(NS.SetGuildWishes("#AMISIA-WL 1 forever 2026-10-05\nW 28830 3 Anna\n#END"))
end)

---------------------------------------------------------------------------
-- 11. the toast: shift-click into a chat box; its place
---------------------------------------------------------------------------
check("11 toast", function()
    NS.BisToast(28830, "wish", wishedLink, "Test")
    local f = NS.BisToastState().frame
    assert(f and f:IsShown())
    local savedUtil = _G.ChatFrameUtil
    local inserted, opened
    _G.ChatFrameUtil = { InsertLink = function(l) inserted = l; return false end, OpenChat = function(t) opened = t end }
    STUB.shift, STUB.modifiedClick = true, nil
    f:GetScript("OnClick")(f, "LeftButton")
    assert(inserted == wishedLink and opened == wishedLink, "no chat box open: one is opened with the link")
    inserted, opened = nil, nil
    _G.ChatFrameUtil.InsertLink = function(l) inserted = l; return true end
    f:GetScript("OnClick")(f, "LeftButton")
    assert(inserted == wishedLink and opened == nil, "an open chat box gets the link")
    _G.ChatFrameUtil = savedUtil
    assert(STUB.modifiedClick == nil, "no modified click, which needs an open chat box")
    STUB.shift = false
    assert(f:IsShown(), "shift-click keeps the toast")

    -- the toast against the award dialog, the roll window and the error line on the smallest screen
    UIParent:SetSize(1024, 768)
    local W, H = 1024, 768
    local function pos(point, w, h)
        local x = point:find("LEFT") and 0 or point:find("RIGHT") and w or w / 2
        local y = point:find("TOP") and h or point:find("BOTTOM") and 0 or h / 2
        return x, y
    end
    local function rect(frame, fw, fh)
        local point, p = next(frame.points)
        assert(point and (p.rel == nil or p.rel == UIParent), "anchored to the screen")
        local ax, ay = pos(p.relPoint, W, H)
        ax, ay = ax + p.x, ay + p.y
        local ox, oy = pos(point, fw, fh)
        return { l = ax - ox, b = ay - oy, r = ax - ox + fw, t = ay - oy + fh }
    end
    local function apart(a, b) return a.r <= b.l or b.r <= a.l or a.t <= b.b or b.t <= a.b end
    local toast = rect(f, f._w, f._h)
    local D = NS.ShowAwardDialog(wishedLink)
    local award = rect(D, D._w, D._h)
    NS.ShowRollFrame()
    local R = AmisiaRollFrame
    local roll = rect(R, R._w, R._h)
    local err = rect({ points = { TOP = { relPoint = "TOP", x = 0, y = -122 } } }, 512, 60)
    assert(apart(toast, award), ("not on the award dialog: toast %d-%d, dialog top %d"):format(toast.b, toast.t, award.t))
    assert(apart(toast, roll), ("not on the roll window: toast %d-%d, roll top %d"):format(toast.b, toast.t, roll.t))
    assert(apart(toast, err), "not on the error line")
    D:Hide(); R:Hide()
    f:GetScript("OnClick")(f, "RightButton")
end)

---------------------------------------------------------------------------
-- 12. item names that arrive late
---------------------------------------------------------------------------
check("12 names", function()
    local c = NS.BisChar()
    for id in pairs(c.wish) do c.wish[id] = nil end
    STUB.item(502, "Beta", 4)
    assert(NS.WishAdd(501, 2) and NS.WishAdd(502, 2))
    NS.ShowGear("wish")
    local V = NS.GearPageFrame().wish
    local function names() local out = {} for i = 1, 2 do out[i] = plain(V.list.rows[i].name:GetText()) end return table.concat(out, ",") end
    assert(names() == "Beta,Item 501", names())
    STUB.item(501, "Alpha", 4)
    for _ = 1, 5 do STUB.fire("GET_ITEM_INFO_RECEIVED", 501, true) end
    STUB.tick(1)
    assert(names() == "Alpha,Beta", "the name shows and the list is sorted again: " .. names())

    -- the guild rows too
    STUB.items[28830] = nil
    NS.ShowGear("guild")
    local U = NS.GearPageFrame().guild
    assert(plain(U.list.rows[1].name:GetText()) == "Item 28830", plain(U.list.rows[1].name:GetText()))
    STUB.item(28830, "Drachenwirbeltrophäe", 4)
    STUB.fire("GET_ITEM_INFO_RECEIVED", 28830, true)
    STUB.tick(1)
    assert(plain(U.list.rows[1].name:GetText()) == "Drachenwirbeltrophäe", plain(U.list.rows[1].name:GetText()))
    NS.WishRemove(501); NS.WishRemove(502)
end)

---------------------------------------------------------------------------
-- 13. a saved place the data no longer has
---------------------------------------------------------------------------
check("13 place", function()
    STUB.instance = { name = "Die Todesminen", type = "party", id = 36 }
    STUB.areas[1581] = "Die Todesminen"
    NS.ShowGear("here")
    AmisiaDB.settings.bis.place = "I:999999"
    NS.Refresh()
    local Hh = NS.GearPageFrame().here
    assert(not has(Hh.pick.label:GetText(), "I:999999"), "no raw key: " .. tostring(Hh.pick.label:GetText()))
    assert(has(Hh.pick.label:GetText(), "Hier: Die Todesminen"), tostring(Hh.pick.label:GetText()))
    assert(AmisiaDB.settings.bis.place == nil, "the stale place is forgotten")
    assert(has(Hh.hint:GetText(), "Der gewählte Ort fehlt in den Daten"), tostring(Hh.hint:GetText()))
    NS.Refresh()
    assert(has(Hh.hint:GetText(), "fehlt"), "the hint stays while nothing else is picked")
    local other
    for _, v in ipairs(Hh.pick.values) do
        if v.value ~= "here" then other = v.value break end
    end
    Hh.pick.onPick(other)   -- a place picked
    assert(AmisiaDB.settings.bis.place == other)
    NS.Refresh()
    assert(not has(Hh.hint:GetText(), "fehlt"), "gone after a pick: " .. tostring(Hh.hint:GetText()))
    STUB.instance = { name = "", type = "none", id = 0 }
end)

if #failed > 0 then error(#failed .. " failed:\n" .. table.concat(failed, "\n"), 0) end
