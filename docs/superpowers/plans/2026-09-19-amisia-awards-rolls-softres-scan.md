# Amisia 1.2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Amisia addon records master-loot awards, runs roll rounds, shows soft-reserves and scans the item database; the site imports the awards.

**Architecture:** Four new Lua modules on the addon namespace `ns` (`Awards.lua`, `Rolls.lua`, `SoftRes.lua`, `Scan.lua`) beside the existing `Core.lua`/`UI.lua`. Awards live inside the existing session model and travel as `A` lines in the `#AMISIA` export; the site converts them into rows of its existing award preview. A Python build script turns the scan into `data/forever.js`.

**Tech Stack:** WoW Lua 5.1 (Anniversary 2.5.6 and Forever 1.60.1 clients), Python 3.11 with `lupa.lua51` for logic tests, `luaparse` (in `C:/Users/aobiw/Desktop/VuloForeverUI/tools/node_modules`) for syntax checks, vanilla JS in `index.html`.

## Global Constraints

- TOC: `## Interface: 20506, 16001`, `## Version: 1.2.0`.
- Every global API that Forever lacks is looked up at call time and skipped when nil: `GetItemInfo`, `GiveMasterLoot`, `GetMasterLootCandidate`, `LootFrame_Update`, `LootButton1`.
- Addon UI text stays within Latin-1 (the client font has no glyphs for U+25CF, U+2013 and similar).
- Chat announcements go to `RAID_WARNING` when the player is leader or assistant, else `RAID`, else `PARTY`, else nowhere.
- Export header stays `#AMISIA 1`.
- Roll ranges: `1-100` = MS, `1-99` = OS, anything else invalid.
- Commit messages: English, no third-party addon names, end with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Tests run with `python addon/tests/run.py` from the repo root; syntax check with `node addon/tests/syntax.cjs`.

---

## File Structure

```
addon/Amisia/Amisia.toc        TOC (modify)
addon/Amisia/Core.lua          shim, s.awards, ns.AddAward, A lines in export, event fan-out (modify)
addon/Amisia/Awards.lua        master-loot hook + confirmation, /award, /unaward (create)
addon/Amisia/Rolls.lua         roll round state machine, parser, announcements, ns.RollKind (create)
addon/Amisia/RollFrame.lua     the roll window (create)
addon/Amisia/SoftRes.lua       list parser, storage, tooltip, loot-button marks, import window (create)
addon/Amisia/Scan.lua          item scan (create)
addon/Amisia/UI.lua            buttons, status line, tooltip counts (modify)
addon/tests/wow_stub.lua       fake WoW API for lupa (create)
addon/tests/run.py             loads stub + addon files, runs every addon/tests/test_*.lua (create)
addon/tests/syntax.js          luaparse over addon/Amisia/*.lua (create)
addon/tests/test_*.lua         one file per module (create)
tools/build_scan.py            SavedVariables -> data/forever.js (create)
tools/forever_zones.json       zone keys/colours by instance name (create)
tools/forever_bosses.json      trash/rename overrides (create)
index.html                     amParse A lines, award rows into glRows, forever data file (modify)
```

Module interfaces (all on `ns`):

```lua
-- Core.lua
ns.AddAward(name, itemID, kind, src, t)   -- writes into the active session, returns the award or nil, reason
ns.RemoveLastAward()                      -- returns the removed award or nil
ns.Active()                               -- existing
ns.BuildMatcher(fmt)                      -- existing local buildMatcher, exported
ns.ItemID(link)                           -- tonumber(link:match("item:(%d+)"))
ns.Announce(text)                         -- picks the channel, no-op when not grouped
ns.OnEvent(event, fn)                     -- modules register extra event handlers on the core frame
-- Rolls.lua
ns.StartRoll(link, seconds, onlyNames)    -- returns true or nil, reason
ns.StopRoll()
ns.RollKind(itemID, name)                 -- "MS" | "OS" | "SR" | "-"
ns.CurrentRoll()                          -- the round table or nil (for the window)
-- SoftRes.lua
ns.ParseSoftRes(text)                     -- returns byItem, count, bad (list of unrecognised lines)
ns.SetSoftRes(text)                       -- parses and stores into DB.softres
ns.ReservedBy(itemID)                     -- sorted list of names, may be empty
-- Scan.lua
ns.ScanStart(from, to) / ns.ScanStop() / ns.ScanStatus()
```

---

### Task 0: Test harness

**Files:**
- Create: `addon/tests/wow_stub.lua`, `addon/tests/run.py`, `addon/tests/syntax.js`, `addon/tests/test_core.lua`

**Interfaces:**
- Produces: `STUB` global in tests with `STUB.fire(event, ...)`, `STUB.tick(seconds)`, `STUB.chat` (captured `SendChatMessage` calls), `STUB.roster` (list of `{name, class, online, zone}`), `STUB.items[id] = {name, quality, link}`, `STUB.loot` (slots for `GetNumLootItems`/`GetLootSlotLink`/`GetLootSourceInfo`), `STUB.now` (epoch used by `time()`), `STUB.instance = {name, type, id}`.

- [ ] **Step 1: Write the stub**

```lua
-- addon/tests/wow_stub.lua: just enough WoW API for the Amisia modules under plain Lua 5.1.
STUB = { chat = {}, roster = {}, items = {}, loot = {}, now = 1789000000, instance = { name = "Black Temple", type = "raid", id = 564 },
         timers = {}, frames = {}, hooks = {}, player = "Vuloo", leader = true }
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.tinsert = table.insert
_G.time = function() return STUB.now end
_G.date = function(fmt, t) return os.date(fmt, t or STUB.now) end
_G.GetServerTime = function() return STUB.now end
_G.UnitName = function(u) return STUB.player end
_G.UnitGUID = function() return "Creature-0-1-1-1-22917-1" end
_G.IsInRaid = function() return #STUB.roster > 0 end
_G.IsInGroup = function() return #STUB.roster > 0 end
_G.GetNumGroupMembers = function() return #STUB.roster end
_G.GetRaidRosterInfo = function(i) local m = STUB.roster[i]; if not m then return nil end
  return m.name, m.rank or 0, 1, 70, m.class, m.class, m.zone or "Black Temple", m.online ~= false end
_G.UnitIsGroupLeader = function() return STUB.leader end
_G.UnitIsGroupAssistant = function() return false end
_G.GetInstanceInfo = function() local i = STUB.instance; return i.name, i.type, 0, "", 0, 0, false, i.id end
_G.GetItemInfo = function(x) local id = tonumber(x) or tonumber(tostring(x):match("item:(%d+)")); local it = STUB.items[id]
  if not it then return nil end return it.name, it.link, it.quality, 141, 70, "Armor", "Cloth", 1, "INVTYPE_HEAD", 134, 0 end
_G.C_Item = { GetItemInfo = _G.GetItemInfo, GetItemInfoInstant = function(id) return id, "Armor", "Cloth", "INVTYPE_HEAD", 134, 4, 1 end,
  RequestLoadItemDataByID = function(id) STUB.requested = STUB.requested or {}; STUB.requested[#STUB.requested + 1] = id end }
_G.GetNumLootItems = function() return #STUB.loot end
_G.GetLootSlotLink = function(s) return STUB.loot[s] and STUB.loot[s].link end
_G.GetLootSlotInfo = function(s) return "icon", STUB.loot[s].name, STUB.loot[s].qty or 1 end
_G.GetLootSourceInfo = function(s) return STUB.loot[s].src or "Creature-0-1-1-1-22917-1", STUB.loot[s].qty or 1 end
_G.GetMasterLootCandidate = function(slot, i) return STUB.roster[i] and STUB.roster[i].name end
_G.GiveMasterLoot = function(slot, i) STUB.given = { slot = slot, i = i } end
_G.SendChatMessage = function(text, chan) STUB.chat[#STUB.chat + 1] = { text = text, chan = chan } end
_G.InCombatLockdown = function() return false end
_G.IsAltKeyDown = function() return STUB.alt end
_G.hooksecurefunc = function(a, b, c) if type(a) == "string" then local orig = _G[a]; _G[a] = function(...) local r = { orig(...) }; b(...); return unpack(r) end
  else local orig = a[b]; a[b] = function(...) local r = { orig(...) }; c(...); return unpack(r) end end end
_G.C_Timer = { After = function(s, fn) STUB.timers[#STUB.timers + 1] = { at = STUB.clock + s, fn = fn } end,
  NewTicker = function(s, fn) local t = { at = STUB.clock + s, fn = fn, every = s }; t.Cancel = function() t.dead = true end; STUB.timers[#STUB.timers + 1] = t; return t end }
STUB.clock = 0
function STUB.tick(seconds)
  local target = STUB.clock + seconds
  while true do
    local nextT
    for _, t in ipairs(STUB.timers) do if not t.dead and t.at <= target and (not nextT or t.at < nextT.at) then nextT = t end end
    if not nextT then break end
    STUB.clock = nextT.at; STUB.now = STUB.now + 0
    if nextT.every then nextT.at = nextT.at + nextT.every else nextT.dead = true end
    nextT.fn()
  end
  STUB.clock = target
end
local function fs() local f = { text = "" }; for _, m in ipairs({ "SetPoint", "SetWidth", "SetHeight", "SetSize", "SetJustifyH", "SetWordWrap", "SetTextColor", "Show", "Hide", "SetFontObject", "SetAllPoints", "SetColorTexture", "SetTexture", "SetTexCoord", "SetAlpha", "SetDrawLayer" }) do f[m] = function() end end
  f.SetText = function(self, t) self.text = t end; f.GetText = function(self) return self.text end; f.IsShown = function() return true end; return f end
local frameMethods = { "SetPoint", "SetSize", "SetWidth", "SetHeight", "SetFrameStrata", "SetClampedToScreen", "SetMovable", "EnableMouse", "RegisterForDrag", "SetAllPoints",
  "SetScrollChild", "SetVerticalScroll", "SetMultiLine", "SetMaxLetters", "SetAutoFocus", "SetFontObject", "SetCursorPosition", "HighlightText", "SetFocus", "ClearFocus",
  "EnableMouseWheel", "SetFrameLevel", "SetToplevel", "StartMoving", "StopMovingOrSizing", "SetBackdrop", "SetBackdropColor", "SetNormalTexture", "SetHighlightTexture", "SetPushedTexture", "SetScale", "SetID", "SetEnabled", "Disable", "Enable" }
function _G.CreateFrame(kind, name, parent, template)
  local f = { kind = kind, name = name, shown = false, scripts = {}, events = {}, text = "" }
  for _, m in ipairs(frameMethods) do f[m] = function() end end
  f.SetScript = function(self, k, fn) self.scripts[k] = fn end
  f.GetScript = function(self, k) return self.scripts[k] end
  f.HookScript = function(self, k, fn) local o = self.scripts[k]; self.scripts[k] = function(...) if o then o(...) end fn(...) end end
  f.RegisterEvent = function(self, e) self.events[e] = true; STUB.frames[self] = true end
  f.UnregisterEvent = function(self, e) self.events[e] = nil end
  f.Show = function(self) self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
  f.Hide = function(self) self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
  f.IsShown = function(self) return self.shown end
  f.IsVisible = f.IsShown
  f.SetText = function(self, t) self.text = t end
  f.GetText = function(self) return self.text end
  f.CreateFontString = function() return fs() end
  f.CreateTexture = function() return fs() end
  f.GetParent = function() return parent end
  f.GetName = function() return name end
  f.SetOwner = function() end; f.AddLine = function() end; f.AddDoubleLine = function() end; f.NumLines = function() return 0 end
  f.GetFrameLevel = function() return 1 end
  if name then _G[name] = f end
  return f
end
function STUB.fire(event, ...)
  for f in pairs(STUB.frames) do if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end end
end
_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) STUB.messages = STUB.messages or {}; STUB.messages[#STUB.messages + 1] = t end }
_G.GameTooltip = CreateFrame("GameTooltip", "GameTooltip"); _G.ItemRefTooltip = CreateFrame("GameTooltip", "ItemRefTooltip")
_G.UIParent = CreateFrame("Frame", "UIParent"); _G.UISpecialFrames = {}
_G.StaticPopupDialogs = {}; _G.StaticPopup_Show = function() end
_G.SlashCmdList = {}; _G.ChatFontNormal = {}; _G.GameFontNormal = {}; _G.RAID_CLASS_COLORS = { WARRIOR = { r = 1, g = 0.8, b = 0.6, colorStr = "ffc79c6e" } }
_G.LOOT_ITEM = "%s receives loot: %s."; _G.LOOT_ITEM_MULTIPLE = "%s receives loot: %sx%d."
_G.LOOT_ITEM_SELF = "You receive loot: %s."; _G.LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
_G.LOOT_ITEM_PUSHED = "%s receives item: %s."; _G.LOOT_ITEM_PUSHED_MULTIPLE = "%s receives item: %sx%d."
_G.LOOT_ITEM_PUSHED_SELF = "You receive item: %s."; _G.LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d."
_G.RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)"
_G.Enum = { TooltipDataType = { Item = 0 } }
function STUB.link(id, name, q) local c = ({ [3] = "ff0070dd", [4] = "ffa335ee" })[q or 4]
  return ("|c%s|Hitem:%d::::::::70:::::|h[%s]|h|r"):format(c, id, name) end
function STUB.item(id, name, q) STUB.items[id] = { name = name, quality = q or 4, link = STUB.link(id, name, q) }; return STUB.items[id].link end
```

- [ ] **Step 2: Write the runner**

```python
# addon/tests/run.py: runs every addon/tests/test_*.lua under Lua 5.1 with the WoW stub.
import glob, os, sys
from lupa.lua51 import LuaRuntime
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON = os.path.join(ROOT, 'Amisia')
FILES = ['Core.lua', 'Awards.lua', 'Rolls.lua', 'RollFrame.lua', 'SoftRes.lua', 'Scan.lua', 'UI.lua']
def fresh():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(open(os.path.join(ROOT, 'tests', 'wow_stub.lua'), encoding='utf-8').read())
    ns = lua.eval('{}')
    for f in FILES:
        p = os.path.join(ADDON, f)
        if not os.path.exists(p): continue
        chunk = lua.eval('function(src, name) return assert(loadstring(src, "@" .. name)) end')(open(p, encoding='utf-8').read(), f)
        chunk('Amisia', ns)
    lua.eval('function(ns) NS = ns; STUB.fire("ADDON_LOADED", "Amisia") end')(ns)
    return lua
failed = 0
for t in sorted(glob.glob(os.path.join(ROOT, 'tests', 'test_*.lua'))):
    lua = fresh()
    try:
        lua.execute(open(t, encoding='utf-8').read())
        print('ok   ', os.path.basename(t))
    except Exception as e:
        failed += 1
        print('FAIL ', os.path.basename(t)); print('     ', str(e).strip().splitlines()[0][:400])
sys.exit(1 if failed else 0)
```

Each test file gets a fresh runtime, so tests inside one file share state in order; `NS` is the addon namespace, `AmisiaDB` the saved table.

- [ ] **Step 3: Write the syntax checker**

```js
// addon/tests/syntax.js: luaparse over every addon file, Lua 5.1 grammar.
const fs = require('fs'), path = require('path');
const lp = require('C:/Users/aobiw/Desktop/VuloForeverUI/tools/node_modules/luaparse');
const dir = path.join(__dirname, '..', 'Amisia'); let bad = 0;
for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.lua'))) {
  try { lp.parse(fs.readFileSync(path.join(dir, f), 'utf8'), { luaVersion: '5.1' }); console.log('ok   ', f); }
  catch (e) { bad++; console.log('FAIL ', f, e.message); }
}
process.exit(bad ? 1 : 0);
```

- [ ] **Step 4: Write a first test against existing behaviour**

```lua
-- addon/tests/test_core.lua
assert(AmisiaDB and AmisiaDB.sessions, "DB initialised")
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active(); assert(s, "session started in a raid instance")
assert(s.members.Fraktur, "roster recorded")
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
STUB.fire("CHAT_MSG_LOOT", ("%s receives loot: %s."):format("Fraktur", link))
assert(#s.items == 1 and s.items[1].name == "Fraktur", "epic loot recorded")
```

- [ ] **Step 5: Run both**

Run: `python addon/tests/run.py` and `node addon/tests/syntax.cjs`
Expected: `ok test_core.lua`, every file `ok`. Fix the stub (not the addon) until this passes.

- [ ] **Step 6: Commit**

```bash
git add addon/tests
git commit -m "Addon: test harness under Lua 5.1 with a small client stub"
```

---

### Task 1: Core shim, awards in the session, export A lines

**Files:**
- Modify: `addon/Amisia/Core.lua` (top: shim; `newSession`: `awards = {}`; ADDON_LOADED migration `s.awards = s.awards or {}`; export after D lines; new helpers), `addon/Amisia/Amisia.toc`
- Test: `addon/tests/test_awards_core.lua`

**Interfaces:**
- Produces: `ns.AddAward(name, itemID, kind, src, t)`, `ns.RemoveLastAward()`, `ns.BuildMatcher(fmt)`, `ns.ItemID(link)`, `ns.Announce(text)`, `ns.OnEvent(event, fn)`, `ns.AwardCount(s)`, `ns.RememberItem(id, link, q)`, `ns.GetItemInfo` (shim).

- [ ] **Step 1: Failing test**

```lua
-- addon/tests/test_awards_core.lua
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
assert(NS.ItemID(link) == 32235)
local a = NS.AddAward("Fraktur", 32235, "MS", "Illidan Stormrage")
assert(a and s.awards[1] == a and a.kind == "MS" and a.src == "Illidan Stormrage")
assert(s.members.Fraktur, "award recipient counted as present")
local txt = NS.ExportText({ s })
assert(txt:find("\nA Fraktur 32235 " .. a.t .. " MS Illidan Stormrage\n", 1, true), txt)
assert(txt:find("\nN 32235 4 Cursed Vision of Sargeras\n", 1, true), "awarded item named")
assert(NS.RemoveLastAward() == a and #s.awards == 0)
assert(NS.AddAward("Fraktur", 32235, "MS", "?") and s.awards[1].src == "?")
-- no session: refused
NS.SetEnabled(false)
local ok, why = NS.AddAward("Fraktur", 32235, "-", "?")
assert(ok == nil and why, "refused without session")
NS.SetEnabled(true)
-- announce channel
NS.Announce("hi"); assert(STUB.chat[1].chan == "RAID_WARNING")
STUB.leader = false; NS.Announce("hi"); assert(STUB.chat[2].chan == "RAID")
STUB.roster = {}; NS.Announce("hi"); assert(#STUB.chat == 2, "no announce when alone")
```

- [ ] **Step 2: Run, expect FAIL** (`ItemID` nil).

- [ ] **Step 3: Implement in Core.lua**

Top of file, after `ns.VERSION = "1.2.0"`:

```lua
-- Forever has no GetItemInfo global; both clients have C_Item.
local GetItemInfo = _G.GetItemInfo or (C_Item and C_Item.GetItemInfo)
ns.GetItemInfo = GetItemInfo
function ns.ItemID(link) return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil end
```

Replace every bare `GetItemInfo(` in Core.lua with the local (it already is a local upvalue after this line). Export `buildMatcher` as `ns.BuildMatcher = buildMatcher` right after its definition. `newSession` gets `awards = {},  -- { name, item, t, kind, src }`; the ADDON_LOADED loop gets `s.awards = s.awards or {}`. `rememberItem` becomes `ns.RememberItem` (keep the local alias).

```lua
-- Chat announcement for the raid: raid warning for leader or assistant, else raid, else party.
function ns.Announce(text)
    if not IsInGroup() then return end
    local chan = "PARTY"
    if IsInRaid() then
        chan = (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) and "RAID_WARNING" or "RAID"
    end
    SendChatMessage(text, chan)
end

local VALID_KIND = { MS = true, OS = true, SR = true, ["-"] = true }
function ns.AddAward(name, item, kind, src, t)
    if not active then return nil, "Keine Aufnahme: Vergaben werden nur in einer Raidinstanz mit Raidgruppe gespeichert." end
    if type(name) ~= "string" or name == "" or not tonumber(item) then return nil, "Name oder Item fehlt." end
    t = t or time()
    local a = { name = name, item = tonumber(item), t = t, kind = VALID_KIND[kind] and kind or "-", src = (src and src ~= "") and src or "?" }
    active.awards[#active.awards + 1] = a
    noteMember(active, name, nil, t)
    local known = DB.itemNames[a.item]
    if not known then ns.RememberItem(a.item, nil, select(3, GetItemInfo(a.item))) end
    active.last = t
    refresh()
    return a
end
function ns.RemoveLastAward()
    if not active or #active.awards == 0 then return nil end
    local a = table.remove(active.awards)
    refresh()
    return a
end
function ns.AwardCount(s) return #(s.awards or {}) end
-- Modules add handlers for events the core frame registers on their behalf.
local extra = {}
function ns.OnEvent(event, fn)
    extra[event] = extra[event] or {}
    table.insert(extra[event], fn)
    if events then events:RegisterEvent(event) end
end
```

In the OnEvent handler, before the `if event == "ADDON_LOADED"` chain, add dispatch at the end of the function (after the chain) as:

```lua
    local list = extra[event]
    if list then for _, fn in ipairs(list) do fn(arg1, ...) end end
```

Change the handler signature to `function(self, event, arg1, ...)`. Registration of extra events made before ADDON_LOADED must be replayed: in the ADDON_LOADED branch add `for ev in pairs(extra) do self:RegisterEvent(ev) end`.

Export, after the D loop inside the session loop:

```lua
        -- A <name> <itemID> <epoch> <MS|OS|SR|-> <source name>: master loot awards
        for _, a in ipairs(s.awards or {}) do
            lines[#lines + 1] = ("A %s %d %d %s %s"):format(a.name, a.item, a.t or 0, a.kind or "-", a.src or "?")
            used[a.item] = true
        end
```

`rememberItem(id, link, q)` must accept `link == nil` (it already guards with `type(link) == "string"`).

TOC:

```
## Interface: 20506, 16001
## Title: Amisia
## Notes: Zeichnet pro Raid Raidmitglieder, Loot und Vergaben auf, verwaltet Rolls und Soft-Reserves und exportiert alles für die Amisia-Loot-Seite.
## Author: mrvulo
## Version: 1.2.0
## IconTexture: Interface\AddOns\Amisia\Media\Icons\Amisia
## SavedVariables: AmisiaDB

Core.lua
Awards.lua
Rolls.lua
RollFrame.lua
SoftRes.lua
Scan.lua
UI.lua
```

- [ ] **Step 4: Run tests and syntax, expect PASS.**
- [ ] **Step 5: Commit** `Amisia: awards in the session model and A lines in the export`

---

### Task 2: Awards.lua, master-loot hook and slash commands

**Files:**
- Create: `addon/Amisia/Awards.lua`
- Modify: `addon/Amisia/Core.lua` slash command (`award`, `unaward` sub-commands delegate to `ns.AwardCommand(rest)`)
- Test: `addon/tests/test_awards.lua`

**Interfaces:**
- Consumes: `ns.AddAward`, `ns.RemoveLastAward`, `ns.OnEvent`, `ns.BuildMatcher`, `ns.ItemID`, `ns.ParseLoot`, `ns.Active`, `ns.RollKind` (from Task 3; call through `ns.RollKind and ns.RollKind(...) or "-"`).
- Produces: `ns.AwardCommand(rest)`, `ns.PendingAward()` (for tests), `ns.LootSourceName(slot)`.

- [ ] **Step 1: Failing test**

```lua
-- addon/tests/test_awards.lua
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
STUB.loot = { { link = link, name = "Cursed Vision of Sargeras", src = "Creature-0-1-1-1-22917-1" } }
STUB.fire("LOOT_OPENED")                     -- Core records the drop with src "?" (no target name in the stub)
GiveMasterLoot(1, 2)                          -- hook: pending for Fraktur
assert(NS.PendingAward() and NS.PendingAward().name == "Fraktur")
assert(#s.awards == 0, "not written before confirmation")
STUB.fire("CHAT_MSG_LOOT", ("%s receives loot: %s."):format("Fraktur", link))
assert(#s.awards == 1 and s.awards[1].item == 32235 and NS.PendingAward() == nil, "confirmed by chat line")
-- confirmation by slot cleared
GiveMasterLoot(1, 2); STUB.fire("LOOT_SLOT_CLEARED", 1)
assert(#s.awards == 2, "confirmed by slot cleared")
-- expiry
GiveMasterLoot(1, 2); STUB.tick(6)
assert(NS.PendingAward() == nil and #s.awards == 2, "pending expired")
-- loot closed drops pending
GiveMasterLoot(1, 2); STUB.fire("LOOT_CLOSED"); assert(NS.PendingAward() == nil)
-- a chat line for someone else does not confirm
GiveMasterLoot(1, 2); STUB.fire("CHAT_MSG_LOOT", ("%s receives loot: %s."):format("Vuloo", link))
assert(#s.awards == 2 and NS.PendingAward()); STUB.fire("LOOT_CLOSED")
-- manual
NS.AwardCommand("Fraktur " .. link .. " os"); assert(s.awards[3].kind == "OS")
NS.AwardCommand("Fraktur 32235"); assert(s.awards[4].kind == "-" and s.awards[4].item == 32235)
NS.AwardCommand("Fraktur"); assert(#s.awards == 4, "missing item refused")
NS.AwardCommand("unaward"); assert(#s.awards == 3)
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement Awards.lua**

```lua
-- Amisia awards: what the master looter hands out, confirmed by the loot chat line or the emptied slot.
local ADDON, ns = ...
local PENDING_TTL = 5
local pending   -- { slot, name, item, link, src, t, timer }

function ns.PendingAward() return pending end

-- Name of what a loot slot came from: the recorded drop source, else the current target.
function ns.LootSourceName(slot)
    local s = ns.Active()
    local guid = GetLootSourceInfo and GetLootSourceInfo(slot)
    if s and guid and s.drops[guid] and s.drops[guid].src ~= "?" then return s.drops[guid].src end
    local target = UnitName("target")
    if target and (not guid or guid == (UnitGUID and UnitGUID("target"))) then return target end
    return "?"
end

local function clearPending()
    if pending and pending.timer then pending.timer:Cancel() end
    pending = nil
end

local function commit(a)
    local kind = ns.RollKind and ns.RollKind(a.item, a.name) or "-"
    local ok, why = ns.AddAward(a.name, a.item, kind, a.src, time())
    if ok then
        ns.msg(("Vergabe gespeichert: %s an %s (%s)."):format(a.link or ("Item " .. a.item), a.name, kind))
    elseif why then
        ns.msg(why)
    end
end

local function onGive(slot, candidate)
    local link = GetLootSlotLink and GetLootSlotLink(slot)
    local id = ns.ItemID(link)
    local name = GetMasterLootCandidate and GetMasterLootCandidate(slot, candidate)
    if not id or not name then return end
    name = name:match("^([^%-]+)") or name
    clearPending()
    pending = { slot = slot, name = name, item = id, link = link, src = ns.LootSourceName(slot), t = time() }
    pending.timer = C_Timer.NewTimer and C_Timer.NewTimer(PENDING_TTL, clearPending) or nil
    if not pending.timer then C_Timer.After(PENDING_TTL, function() if pending and pending.t + PENDING_TTL <= time() + 0.5 then clearPending() end end) end
end

if type(GiveMasterLoot) == "function" then
    hooksecurefunc("GiveMasterLoot", onGive)
end

ns.OnEvent("CHAT_MSG_LOOT", function(text)
    if not pending then return end
    local who, id = ns.ParseLoot(text)
    if who and who == pending.name and id == pending.item then
        local a = pending; clearPending(); commit(a)
    end
end)
ns.OnEvent("LOOT_SLOT_CLEARED", function(slot)
    if pending and slot == pending.slot then local a = pending; clearPending(); commit(a) end
end)
ns.OnEvent("LOOT_CLOSED", function() clearPending() end)

-- "/amisia award <Name> <link or id> [ms|os|sr]" and "/amisia unaward"
function ns.AwardCommand(rest)
    rest = (rest or ""):match("^%s*(.-)%s*$")
    if rest:lower() == "unaward" then
        local a = ns.RemoveLastAward()
        ns.msg(a and ("Vergabe entfernt: Item %d an %s."):format(a.item, a.name) or "Keine Vergabe in der laufenden Aufnahme.")
        return
    end
    local name, tail = rest:match("^(%S+)%s*(.*)$")
    if not name then ns.msg("Aufruf: /amisia award <Name> <Item-Link oder ID> [ms|os|sr]") return end
    local id = ns.ItemID(tail) or tonumber(tail:match("^(%d+)"))
    if not id then ns.msg("Item fehlt: Link einfügen oder Item-ID angeben.") return end
    local kind = (tail:match("%s(%a%a)%s*$") or ""):upper()
    if kind ~= "MS" and kind ~= "OS" and kind ~= "SR" then kind = "-" end
    local ok, why = ns.AddAward(name, id, kind, ns.LootSourceName(0), time())
    if ok then ns.msg(("Vergabe gespeichert: Item %d an %s (%s)."):format(id, name, kind)) else ns.msg(why) end
end
```

Note: the stub's `C_Timer` has no `NewTimer`; keep the `C_Timer.After` fallback so the test's expiry passes (`STUB.tick(6)` moves `STUB.now`? No: the stub's `tick` does not advance `STUB.now`; make the fallback compare against `STUB`-independent state instead: store `pending.id = {}` token and check `pending and pending.token == token` before clearing). Use that token approach in the real code:

```lua
    local token = {}
    pending.token = token
    C_Timer.After(PENDING_TTL, function() if pending and pending.token == token then clearPending() end end)
```

(and drop the `NewTimer` branch entirely). Slash in Core.lua: `elseif cmd:match("^award") or cmd == "unaward" then ns.AwardCommand(cmd == "unaward" and "unaward" or input:match("^%s*award%s*(.*)$"))`, using the raw `input` (not lowercased) for the arguments.

- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `Amisia: record master loot hand-outs as awards`

---

### Task 3: Site import of A lines

**Files:**
- Modify: `index.html` `amParse` (add `awards: []` to `cur`, `A` branch), `$('#glPreview')` handler (award rows appended before `glResolve`), new `amAwardRows(sessions)`; `#glDups` handler.
- Test: a browser check with a pasted export (manual) plus a Node check of the pure functions is not possible (they live inline). Verify with the sample text below in the running site.

- [ ] **Step 1: amParse**

In `amParse`, `cur` gets `awards: []` and the branch:

```js
      } else if (f[0] === 'A' && cur && f.length >= 5) {
        const name = glCleanName(f[1]), item = Number(f[2]), at = Number(f[3]) || 0, kind = f[4].toUpperCase();
        if (name && item) cur.awards.push({name, item, at, kind: ['MS','OS','SR'].includes(kind) ? kind : '', source: (f.slice(5).join(' ') || '?').slice(0, 60)});
```

- [ ] **Step 2: Rows for the award preview**

```js
// Awards the Amisia addon recorded, as rows of the award preview. The session date is the raid night already.
function amAwardRows(sessions){
  const rows = [], seen = new Set();
  for (const s of sessions) for (const a of (s.awards || [])) {
    const own = s.date + '|' + a.item + '|' + a.name.toLowerCase() + '|' + a.at;
    if (seen.has(own)) continue; seen.add(own);
    const m = s.members.find(x => x.name.toLowerCase() === a.name.toLowerCase());
    rows.push({item: a.item, rawName: a.name, name: a.name, date: s.date, ts: a.at ? a.at * 1000 : null, os: a.kind === 'OS', key: null, cls: m ? m.cls : '', boss: a.source !== '?' ? a.source : null, note: a.kind === 'SR' ? 'SR' : ''});
  }
  return rows;
}
```

In the preview handler replace `glRows = rest.trim() ? glResolve(glParse(rest)) : [];` with:

```js
  const amSessions = blocks.length ? amParse(blocks) : [];
  amRows = amSessions.length ? amResolve(amSessions) : [];
  amBank = blocks.length ? amBankResolve(amParseBank(blocks)) : null;
  const rawRows = (rest.trim() ? glParse(rest) : []).concat(amAwardRows(amSessions));
  glRows = rawRows.length ? glResolve(rawRows) : [];
```

`glResolve` already handles `r.boss` (matched against the item's sources) and dedups by `date|item|name`. Update the help text near line 726 to mention awards: "…and every item the master looter hands out."

- [ ] **Step 3: Manual check**

Paste into the Import tab:

```
#AMISIA 1 Vuloo
S 20260919210000-564 2026-09-19 564 Black Temple
M Fraktur SHAMAN
M Vuloo PRIEST
A Fraktur 32235 1789000000 MS Illidan Stormrage
A Vuloo 32235 1789000100 OS Illidan Stormrage
A Vuloo 99999 1789000200 - ?
E
N 32235 4 Cursed Vision of Sargeras
N 99999 4 Unknown Thing
#END
```

Expected: two award rows to import (boss Illidan Stormrage, second marked OS), one ignored ("not a drop from a supported raid"); previewing again after import shows both as Exists.

- [ ] **Step 4: Commit** `Import: awards recorded by the Amisia addon`

---

### Task 4: Rolls.lua, the round without a window

**Files:**
- Create: `addon/Amisia/Rolls.lua`
- Modify: `addon/Amisia/Core.lua` slash (`roll`, `rollzeit`), settings default `DB.settings.rollSeconds = 20`.
- Test: `addon/tests/test_rolls.lua`

**Interfaces:**
- Consumes: `ns.BuildMatcher`, `ns.Announce`, `ns.OnEvent`, `ns.ItemID`, `ns.ReservedBy` (Task 6; call through `ns.ReservedBy and ns.ReservedBy(id) or {}`), `ns.GetItemInfo`.
- Produces: `ns.StartRoll(link, seconds, onlyNames)`, `ns.StopRoll()`, `ns.CurrentRoll()`, `ns.RollKind(itemID, name)`, `ns.RollRanking(round)` (sorted list of entries), `ns.OnRollChanged` (callback hook the window sets), `ns.LastRoll()`.

Round table: `{ item, link, name, started, ends, seconds, only = {names} or nil, rolls = { [name] = {value, low, high, kind, t, class} }, order = {names in arrival order}, ignored = { {name, value, low, high, why} }, reserved = {names}, done = bool, winner = name|nil, tie = {names}|nil }`.

- [ ] **Step 1: Failing test**

```lua
-- addon/tests/test_rolls.lua
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" }, { name = "Chorf", class = "WARRIOR" } }
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
assert(NS.StartRoll(link, 20))
local r = NS.CurrentRoll(); assert(r and r.item == 32235 and r.seconds == 20)
assert(STUB.chat[1].text:find("/roll 99", 1, true) and STUB.chat[1].text:find("20 Sekunden", 1, true), STUB.chat[1].text)
local function roll(name, v, lo, hi) STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format(name, v, lo, hi)) end
roll("Fraktur", 57, 1, 100); roll("Chorf", 80, 1, 99); roll("Fraktur", 99, 1, 100); roll("Stranger", 100, 1, 100); roll("Vuloo", 12, 1, 50)
assert(r.rolls.Fraktur.value == 57 and r.rolls.Fraktur.kind == "MS")
assert(r.rolls.Chorf.kind == "OS")
assert(not r.rolls.Stranger and not r.rolls.Vuloo)
assert(#r.ignored == 3, "duplicate, stranger and wrong range listed")
local rank = NS.RollRanking(r); assert(rank[1].name == "Fraktur" and rank[2].name == "Chorf", "MS beats a higher OS")
-- countdown and end
STUB.tick(10); assert(STUB.chat[#STUB.chat].text:find("10 Sekunden", 1, true))
STUB.tick(10); assert(r.done and r.winner == "Fraktur", "winner after the timer")
assert(STUB.chat[#STUB.chat].text:find("Gewinner: Fraktur (57, MS)", 1, true), STUB.chat[#STUB.chat].text)
assert(NS.RollKind(32235, "Fraktur") == "MS" and NS.RollKind(32235, "Chorf") == "OS" and NS.RollKind(32235, "Vuloo") == "-")
-- tie and re-roll restricted to the tied names
assert(NS.StartRoll(link, 10)); r = NS.CurrentRoll()
roll("Fraktur", 90, 1, 100); roll("Chorf", 90, 1, 100); STUB.tick(10)
assert(r.done and not r.winner and #r.tie == 2, "tie detected")
assert(STUB.chat[#STUB.chat].text:find("Gleichstand", 1, true))
assert(NS.StartRoll(link, 10, r.tie)); r = NS.CurrentRoll()
roll("Vuloo", 100, 1, 100); roll("Chorf", 5, 1, 100); roll("Fraktur", 4, 1, 100); STUB.tick(10)
assert(r.winner == "Chorf", "only tied names count in the re-roll")
-- stop early and nobody rolled
assert(NS.StartRoll(link, 20)); NS.StopRoll(); assert(NS.CurrentRoll().done and STUB.chat[#STUB.chat].text:find("Niemand", 1, true))
-- reserved first
NS.ReservedBy = function(id) return id == 32235 and { "Chorf" } or {} end
assert(NS.StartRoll(link, 10)); r = NS.CurrentRoll()
assert(STUB.chat[#STUB.chat].text:find("Reserviert von Chorf", 1, true))
roll("Fraktur", 100, 1, 100); roll("Chorf", 3, 1, 99); STUB.tick(10)
assert(r.winner == "Chorf" and NS.RollKind(32235, "Chorf") == "SR")
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement Rolls.lua**

```lua
-- Amisia rolls: one round at a time, results read from the system chat, ranking and announcements.
local ADDON, ns = ...
local KEEP = 10 * 60
local current, last, ticker
local matcher

local function inRaid(name)
    for i = 1, GetNumGroupMembers() or 0 do
        local n, _, _, _, _, class = GetRaidRosterInfo(i)
        if n and (n == name or n:match("^([^%-]+)") == name) then return true, class end
    end
    return false
end

local function kindOf(low, high)
    if low == 1 and high == 100 then return "MS" end
    if low == 1 and high == 99 then return "OS" end
    return nil
end

local RANK = { SR = 3, MS = 2, OS = 1 }
local function rankOf(r, e) return r.reservedSet[e.name] and 3 or RANK[e.kind] or 0 end

function ns.RollRanking(r)
    local list = {}
    for _, name in ipairs(r.order) do list[#list + 1] = r.rolls[name] end
    table.sort(list, function(a, b)
        local ra, rb = rankOf(r, a), rankOf(r, b)
        if ra ~= rb then return ra > rb end
        if a.value ~= b.value then return a.value > b.value end
        return a.t < b.t
    end)
    for _, e in ipairs(list) do e.rank = rankOf(r, e) == 3 and "SR" or e.kind end
    return list
end

local function changed() if ns.OnRollChanged then ns.OnRollChanged(current) end end

local function finish()
    if not current or current.done then return end
    if ticker then ticker:Cancel(); ticker = nil end
    current.done = true
    local list = ns.RollRanking(current)
    if #list == 0 then
        ns.Announce("Stopp! Niemand hat gewürfelt.")
    else
        local top = list[1]
        local tie = { top.name }
        for i = 2, #list do
            if list[i].value == top.value and rankOf(current, list[i]) == rankOf(current, top) then tie[#tie + 1] = list[i].name else break end
        end
        if #tie > 1 then
            current.tie = tie
            ns.Announce(("Stopp! Gleichstand: %s (%d, %s). Bitte nochmal würfeln."):format(table.concat(tie, " und "), top.value, top.rank))
        else
            current.winner = top.name
            ns.Announce(("Stopp! Gewinner: %s (%d, %s)."):format(top.name, top.value, top.rank))
        end
    end
    last = current
    changed()
end

function ns.StartRoll(link, seconds, onlyNames)
    local id = ns.ItemID(link)
    if not id then return nil, "Kein Item-Link." end
    if current and not current.done then finish() end
    seconds = tonumber(seconds) or (AmisiaDB and AmisiaDB.settings and AmisiaDB.settings.rollSeconds) or 20
    local reserved = ns.ReservedBy and ns.ReservedBy(id) or {}
    current = { item = id, link = link, name = link:match("|h%[(.-)%]|h") or ("Item " .. id), started = time(), seconds = seconds,
                rolls = {}, order = {}, ignored = {}, reserved = reserved, reservedSet = {}, leftAt = seconds }
    for _, n in ipairs(reserved) do current.reservedSet[n] = true end
    if onlyNames then current.only = {}; for _, n in ipairs(onlyNames) do current.only[n] = true end end
    if not matcher then matcher = ns.BuildMatcher(RANDOM_ROLL_RESULT) end
    if current.only then
        ns.Announce(("Stechen: %s. /roll. %d Sekunden."):format(table.concat(onlyNames, ", "), seconds))
    else
        ns.Announce(("Roll auf %s: /roll für Mainspec, /roll 99 für Offspec. %d Sekunden."):format(link, seconds))
        if #reserved > 0 then ns.Announce("Reserviert von " .. table.concat(reserved, ", ") .. ".") end
    end
    local left = seconds
    ticker = C_Timer.NewTicker(1, function()
        left = left - 1
        if current then current.leftAt = left end
        if (left == 10 and seconds > 10) or (left == 5 and seconds > 5) or (left == 3 and seconds > 3) then
            ns.Announce(("%d Sekunden."):format(left))
        end
        if left <= 0 then finish() else changed() end
    end)
    changed()
    return true
end

function ns.StopRoll() finish() end
function ns.CurrentRoll() return current end
function ns.LastRoll() return last end

local function onSystem(text)
    if not current or current.done or not matcher then return end
    local a = matcher(text)
    if not a then return end
    local name, value, low, high = a[1], tonumber(a[2]), tonumber(a[3]), tonumber(a[4])
    name = name:match("^([^%-]+)") or name
    local ok, class = inRaid(name)
    local why
    if not ok then why = "nicht im Raid"
    elseif current.only and not current.only[name] then why = "nicht am Stechen beteiligt"
    elseif current.rolls[name] then why = "schon gewürfelt"
    elseif not kindOf(low, high) then why = ("Bereich %d-%d"):format(low, high) end
    if why then
        current.ignored[#current.ignored + 1] = { name = name, value = value, low = low, high = high, why = why }
    else
        current.rolls[name] = { name = name, value = value, low = low, high = high, kind = kindOf(low, high), t = time() + #current.order / 1000, class = class }
        current.order[#current.order + 1] = name
    end
    changed()
end
ns.OnEvent("CHAT_MSG_SYSTEM", onSystem)

-- MS, OS or SR for an award: what the recipient rolled or reserved in the last round for this item.
function ns.RollKind(item, name)
    local r = (current and current.item == item) and current or ((last and last.item == item) and last or nil)
    if not r or (time() - r.started) > KEEP then return "-" end
    if r.reservedSet[name] then return "SR" end
    local e = r.rolls[name]
    return e and e.kind or "-"
end
```

Slash in Core: `roll <link> [sec]` -> `ns.StartRoll(link, sec)`, `rollzeit N` -> `DB.settings.rollSeconds = N`; `rolls` -> `ns.ToggleRollFrame()` (Task 5). Default `DB.settings.rollSeconds = DB.settings.rollSeconds or 20` in ADDON_LOADED.

- [ ] **Step 4: Run, expect PASS.** The stub's `time()` does not move during `tick`; the test only relies on ticks, not on `time()`.
- [ ] **Step 5: Commit** `Amisia: roll rounds read from the system chat`

---

### Task 5: RollFrame.lua and the alt-click start

**Files:**
- Create: `addon/Amisia/RollFrame.lua`
- Test: `addon/tests/test_rollframe.lua` (smoke: frame builds, rows fill, award button calls `GiveMasterLoot` with the matching slot)

**Interfaces:**
- Consumes: `ns.CurrentRoll`, `ns.RollRanking`, `ns.StartRoll`, `ns.StopRoll`, `ns.OnRollChanged`, `ns.AddAward`, `ns.LootSourceName`.
- Produces: `ns.ToggleRollFrame()`, `ns.RollFrame` (the frame), `ns.AwardFromRoll(name)`.

- [ ] **Step 1: Failing test**

```lua
-- addon/tests/test_rollframe.lua
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
STUB.loot = { { link = STUB.item(30000, "Other", 4), name = "Other" }, { link = link, name = "Cursed Vision of Sargeras" } }
STUB.fire("LOOT_OPENED")
-- alt-click in the loot window starts a round
STUB.alt = true; HandleModifiedItemClick(link); STUB.alt = false
local r = NS.CurrentRoll(); assert(r and r.item == 32235, "alt-click started the round")
assert(NS.RollFrame and NS.RollFrame:IsShown(), "window opened")
STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format("Fraktur", 77, 1, 100))
assert(NS.RollFrame.rows[1].name:GetText():find("Fraktur", 1, true))
NS.AwardFromRoll("Fraktur")
assert(STUB.given and STUB.given.slot == 2 and STUB.given.i == 2, "GiveMasterLoot called with the item's slot and candidate")
STUB.fire("LOOT_CLOSED")
NS.AwardFromRoll("Fraktur"); assert(STUB.messages[#STUB.messages]:find("Lootfenster", 1, true), "hint without loot window")
```

- [ ] **Step 2: Implement RollFrame.lua**

Frame `AmisiaRollFrame` (320 x 300, strata DIALOG, movable, `UISpecialFrames`), header FontString (item link), timer FontString, 12 row frames (`row.name`, `row.kind`, `row.value`, `row.award` button "Vergeben" 70 px), buttons "Stopp", "Nochmal" (enabled only when `r.tie`), close button. `ns.OnRollChanged = function(r) refresh() end`. Refresh writes ranking rows first (name in class colour via `RAID_CLASS_COLORS[class]`, kind, value), then ignored rows greyed with `why`; timer text `"%d s"` or "Beendet". `HandleModifiedItemClick` hook:

```lua
local lootOpen = false
ns.OnEvent("LOOT_OPENED", function() lootOpen = true end)
ns.OnEvent("LOOT_CLOSED", function() lootOpen = false end)
if type(HandleModifiedItemClick) == "function" then
    hooksecurefunc("HandleModifiedItemClick", function(link)
        if lootOpen and IsAltKeyDown() and ns.ItemID(link) then
            ns.StartRoll(link)
            ns.ShowRollFrame()
        end
    end)
end
```

`ns.AwardFromRoll(name)`:

```lua
function ns.AwardFromRoll(name)
    local r = ns.CurrentRoll() or ns.LastRoll()
    if not r then return end
    if not lootOpen or type(GiveMasterLoot) ~= "function" then
        ns.msg("Lootfenster öffnen und Master Loot nutzen, oder /amisia award " .. name .. " " .. (r.link or r.item) .. ".")
        return
    end
    local slot
    for i = 1, GetNumLootItems() or 0 do
        if ns.ItemID(GetLootSlotLink(i)) == r.item then slot = i break end
    end
    if not slot then ns.msg("Das Item liegt nicht mehr im Lootfenster.") return end
    for i = 1, 40 do
        local c = GetMasterLootCandidate(slot, i)
        if c and (c == name or c:match("^([^%-]+)") == name) then GiveMasterLoot(slot, i) return end
    end
    ns.msg(name .. " ist kein Kandidat für dieses Item (zu weit weg?).")
end
```

Awards.lua's hook records the hand-out as in Task 2, with `ns.RollKind` giving MS/OS/SR.

- [ ] **Step 3: Run, expect PASS. Commit** `Amisia: roll window with hand-out button`

---

### Task 6: SoftRes.lua

**Files:**
- Create: `addon/Amisia/SoftRes.lua`
- Modify: `addon/Amisia/UI.lua` (button "Soft-Reserves" -> `ns.ToggleSoftResFrame()`)
- Test: `addon/tests/test_softres.lua`

**Interfaces:**
- Produces: `ns.ParseSoftRes(text) -> byItem, count, bad`, `ns.SetSoftRes(text)`, `ns.ReservedBy(itemID)`, `ns.ClearSoftRes()`, `ns.ToggleSoftResFrame()`, `ns.MarkLootButtons()`.

- [ ] **Step 1: Failing test**

```lua
-- addon/tests/test_softres.lua
local csv = 'Item,ItemId,From,Name,Class,Spec,Note,Plus,Date\n"Cursed Vision of Sargeras",32235,Illidan,Fraktur,Shaman,Enhancement,,0,2026-09-19\n"Cursed Vision of Sargeras",32235,Illidan,fraktur-Thunderstrike,Shaman,,,0,2026-09-19\nBlade,32837,Illidan,Chorf,Warrior,,,0,x\n'
local byItem, n, bad = NS.ParseSoftRes(csv)
assert(n == 2 and #bad == 0, n .. " " .. #bad)
assert(#byItem[32235] == 1 and byItem[32235][1] == "Fraktur", "realm stripped, duplicate merged")
assert(byItem[32837][1] == "Chorf")
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
byItem, n, bad = NS.ParseSoftRes("Chorf " .. link .. "\nVuloo: 32837\nFraktur; 32235\nNobody\n")
assert(n == 3 and #bad == 1 and bad[1] == "Nobody", "plain lines")
assert(#byItem[32235] == 2)
NS.SetSoftRes("Chorf " .. link)
assert(NS.ReservedBy(32235)[1] == "Chorf" and #NS.ReservedBy(1) == 0)
assert(AmisiaDB.softres.date == date("%Y-%m-%d"))
-- tooltip line
local lines = {}
GameTooltip.AddLine = function(_, t) lines[#lines + 1] = t end
GameTooltip.GetItem = function() return "Cursed Vision of Sargeras", link end
GameTooltip.scripts.OnTooltipSetItem(GameTooltip)
assert(lines[1] and lines[1]:find("Reserviert: Chorf", 1, true), lines[1] or "no line")
NS.ClearSoftRes(); assert(#NS.ReservedBy(32235) == 0)
```

- [ ] **Step 2: Implement SoftRes.lua**

Parser: split lines; if the first line matches `[Ii]tem[Ii][Dd]` -> CSV mode with a quote-aware splitter (comma or semicolon, whichever the header has more of), header columns lower-cased, take `itemid` and `name`. Else per line: `name` = first token up to space, tab, comma, semicolon or colon; item = `ns.ItemID(rest)` or `rest:match("^%s*(%d+)%s*$")`. Names: strip `-Realm`, capitalise first letter. Per item keep a set and a sorted list. Storage `AmisiaDB.softres = { date = date("%Y-%m-%d"), byItem = ..., raw = text }`. Tooltip hook:

```lua
local function addLine(tip)
    local _, link = tip:GetItem()
    local id = ns.ItemID(link)
    if not id then return end
    local names = ns.ReservedBy(id)
    if #names == 0 then return end
    tip:AddLine("Reserviert: " .. table.concat(names, ", "), 0.89, 0.72, 0.34)
end
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, addLine)
else
    GameTooltip:HookScript("OnTooltipSetItem", addLine)
    if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipSetItem", addLine) end
end
```

(The stub has no `TooltipDataProcessor`, so the HookScript path is what the test exercises. The frame stub's `HookScript` stores into `scripts`.)

Loot marks: `ns.MarkLootButtons()` loops `LootButton1..4` (`_G["LootButton" .. i]`, `.slot`), creates once a FontString `btn.amisiaSR` ("SR", gold, TOPLEFT of the icon) and shows it when `#ns.ReservedBy(ns.ItemID(GetLootSlotLink(btn.slot))) > 0`. Called from `LOOT_OPENED`, `LOOT_SLOT_CLEARED` and a `hooksecurefunc("LootFrame_Update", ...)` when that global exists. Forever: after `LOOT_OPENED`, `C_Timer.After(0, ...)` and if `LootFrame and LootFrame.ScrollBox and LootFrame.ScrollBox.ForEachFrame` then mark each frame with `frame:GetSlotIndex()`.

Import frame `AmisiaSoftResFrame` (420 x 320): multi-line EditBox in a scroll frame, "Übernehmen" (`ns.SetSoftRes(text)` and result line `"%d Reservierungen, %d Zeilen nicht erkannt"`), "Leeren", "Schließen"; on open shows the stored raw text and a line "Liste vom <date>" in orange when the date is not today.

- [ ] **Step 3: Run, expect PASS. Commit** `Amisia: soft-reserves in tooltip and loot window`

---

### Task 7: Scan.lua

**Files:**
- Create: `addon/Amisia/Scan.lua`
- Modify: `addon/Amisia/Core.lua` slash (`scan ...`), `UI.lua` status line
- Test: `addon/tests/test_scan.lua`

**Interfaces:**
- Produces: `ns.ScanStart(from, to)`, `ns.ScanStop()`, `ns.ScanStatus() -> text`, `ns.ScanCommand(rest)`, `ns.ScanRunning()`.
- Storage: `AmisiaDB.scan = { from, to, next, rate, items = { [id] = "name\tq\tilvl\tmin\tclass\tsub\tequip\ticon\tbind" }, retry = {}, at }`.

- [ ] **Step 1: Failing test**

```lua
-- addon/tests/test_scan.lua
STUB.instance = { name = "Shattrath", type = "none", id = 0 }
STUB.item(100, "Hundred", 2); STUB.item(102, "Hundredtwo", 3)
assert(NS.ScanStart(100, 105))
STUB.tick(0.1)
assert(STUB.requested and #STUB.requested == 6, "all six requested within the first tick at rate 100")
STUB.fire("ITEM_DATA_LOAD_RESULT", 100, true); STUB.fire("ITEM_DATA_LOAD_RESULT", 101, false); STUB.fire("ITEM_DATA_LOAD_RESULT", 102, true)
for _, id in ipairs({ 103, 104 }) do STUB.fire("ITEM_DATA_LOAD_RESULT", id, false) end
assert(AmisiaDB.scan.items[100]:match("^Hundred\t2\t") and AmisiaDB.scan.items[102] and not AmisiaDB.scan.items[101])
STUB.tick(3.5)   -- 105 never answers: retried once
assert(#STUB.requested == 7 and STUB.requested[7] == 105, "timeout retried")
STUB.tick(3.5)
assert(AmisiaDB.scan.retry[1] == 105 and not NS.ScanRunning(), "second timeout parks the id and the scan ends")
assert(AmisiaDB.scan.next == 106)
assert(NS.ScanStatus():find("2 Items", 1, true), NS.ScanStatus())
-- refuses inside an instance
STUB.instance = { name = "Black Temple", type = "raid", id = 564 }
assert(NS.ScanStart(1, 10) == nil)
```

- [ ] **Step 2: Implement Scan.lua**

State machine: `pending = { [id] = { sent = clock, tries } }`, `queue` cursor `nextId`, ticker every 0.1 s sends `math.floor(rate / 10)` ids while `count(pending) < 200` and `nextId <= to`; on `ITEM_DATA_LOAD_RESULT(id, ok)` if `pending[id]`: store or skip, remove; each tick also checks timeouts (`clock - sent > 3`): `tries < 2` -> resend, else push to `retry`, remove. Scan ends when `nextId > to` and `pending` is empty: message and `at = time()`. `clock` uses `GetTime` when present, else a counter advanced by the ticker (the stub has no `GetTime`; use `local clock = 0` incremented by 0.1 per tick). `InCombatLockdown()` true or `GetInstanceInfo()` type `raid`/`party` -> refuse to start / pause ticks with one message. Store line via `C_Item.GetItemInfo(id)` (name, link, quality, ilvl, minLevel, _, _, _, equipLoc, icon, _, classID, subclassID, bindType) with `GetItemInfoInstant` fallback for icon. Progress message every 5000 ids. Slash: `scan` (resume), `scan <from> <to>`, `scan stop`, `scan status`, `scan rate N`.

- [ ] **Step 3: Run, expect PASS. Commit** `Amisia: throttled item scan for the loot tables`

---

### Task 8: UI.lua additions

**Files:**
- Modify: `addon/Amisia/UI.lua`

- [ ] Session row tooltip: after the items/drops lines add `Vergaben: n` when `ns.AwardCount(s) > 0`.
- [ ] Buttons left of "Export erstellen": "Soft-Reserves" (`ns.ToggleSoftResFrame`) and "Rolls" (`ns.ToggleRollFrame`); shrink the export label width to 250 so the three buttons fit at the right.
- [ ] Status line: when `ns.ScanRunning()` append ` · ` free text `Scan <next> von <to>, <n> Items` (ASCII middle dot is Latin-1, U+00B7, allowed).
- [ ] Run `python addon/tests/run.py` (UI.lua loads in the harness; nothing new to assert beyond loading) and syntax. Commit `Amisia: window buttons for rolls and soft-reserves`.

---

### Task 9: tools/build_scan.py

**Files:**
- Create: `tools/build_scan.py`, `tools/forever_zones.json`, `tools/forever_bosses.json`, `tools/README.md`
- Test: `tools/tests/test_build_scan.py` (pytest, uses a tiny hand-written SavedVariables file)

**Interfaces:**
- CLI: `python tools/build_scan.py <SavedVariables.lua>... [--out data/forever.js] [--no-icons]`.
- Functions: `load_sv(path) -> dict` (lupa), `collect(dbs) -> (items, sessions)`, `zones_and_bosses(sessions, zones_cfg, bosses_cfg) -> (zones, bosses, warnings)`, `build_items(scan_items, drops, boss_of) -> list`, `write_js(out, zones, bosses, items, sprite)`.

- [ ] **Step 1: Failing test**

```python
# tools/tests/test_build_scan.py
import json, os, textwrap, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
import build_scan as b
SV = textwrap.dedent('''
AmisiaDB = {
  ["scan"] = { ["items"] = { [32235] = "Cursed Vision of Sargeras\\t4\\t141\\t70\\t4\\t1\\tINVTYPE_HEAD\\t134\\t1", [32837] = "Warglaive\\t5\\t156\\t70\\t2\\t7\\tINVTYPE_WEAPONMAINHAND\\t135\\t1" } },
  ["sessions"] = { { ["zone"] = "Black Temple", ["instanceID"] = 564, ["date"] = "2026-09-19",
     ["drops"] = { ["Creature-1"] = { ["src"] = "Illidan Stormrage", ["items"] = { [32235] = 1, [32837] = 1 } }, ["Creature-2"] = { ["src"] = "Ashtongue Guard", ["items"] = { [32235] = 1 } } } } },
}
''')
def test_pipeline(tmp_path):
    p = tmp_path / 'Amisia.lua'; p.write_text(SV, encoding='utf-8')
    db = b.load_sv(str(p))
    items, sessions = b.collect([db])
    assert items[32235]['name'] == 'Cursed Vision of Sargeras' and items[32235]['q'] == 4
    zones, bosses, warn = b.zones_and_bosses(sessions, {'Black Temple': {'key': 'bt', 'short': 'BT', 'color': ['#c26a4a', '#a6482a']}}, {'Ashtongue Guard': 'trash'})
    assert zones[0]['key'] == 'bt' and [x['name'] for x in bosses] == ['Illidan Stormrage', 'Trash (Black Temple)']
    out = b.build_items(items, sessions, bosses, zones)
    head = next(i for i in out if i['id'] == 32235)
    assert head['slot'] == 'head' and head['sources'] == ['Illidan Stormrage', 'Trash (Black Temple)']
    js = tmp_path / 'forever.js'
    b.write_js(str(js), zones, bosses, out, None)
    txt = js.read_text(encoding='utf-8')
    assert txt.startswith('window.__LOOT=window.__LOOT||{};window.__LOOT["forever"]=')
    data = json.loads(txt.split('=', 2)[2].rstrip(';\n'))
    assert data['items'][0]['id'] in (32235, 32837)
```

- [ ] **Step 2: Implement**

`load_sv`: `lupa.lua51.LuaRuntime().execute(src)` then `globals().AmisiaDB` converted to Python recursively (tables with only integer keys -> lists when 1..n contiguous, else dicts). `SLOT` map from `equipLoc` to the site's slot keys (`INVTYPE_HEAD`->`head`, `INVTYPE_NECK`->`neck`, `INVTYPE_SHOULDER`->`shoulder`, `INVTYPE_CLOAK`->`back`, `INVTYPE_CHEST`/`INVTYPE_ROBE`->`chest`, `INVTYPE_WRIST`->`wrist`, `INVTYPE_HAND`->`hands`, `INVTYPE_WAIST`->`waist`, `INVTYPE_LEGS`->`legs`, `INVTYPE_FEET`->`feet`, `INVTYPE_FINGER`->`finger`, `INVTYPE_TRINKET`->`trinket`, weapons (`WEAPON`, `WEAPONMAINHAND`, `2HWEAPON`)->`mainhand`, `WEAPONOFFHAND`/`SHIELD`/`HOLDABLE`->`offhand`, `RANGED`/`RANGEDRIGHT`/`THROWN`/`RELIC`->`ranged`, classID 9 -> `recipe`, else `other`). Check `data/tbc.js` slot keys first (`grep -o '"slot":"[a-z]*"' data/tbc.js | sort -u`) and match them exactly. Icons: `--no-icons` skips the sprite (`sprite: null`, site falls back to no image; check `icoInner` in index.html handles a missing sprite: if not, write the icon name into `icon` and let `icoInner` show a blank). With icons: for each item fetch `https://www.wowhead.com/item=<id>&xml`, read `<icon>`, cache in `tools/icon-cache.json`, download `https://wow.zamimg.com/images/wow/icons/large/<icon>.jpg`, build the sprite with Pillow (cols = 24, 56 px cells, JPEG quality 85) as `data/forever.<8-hex-of-content>.jpg`, `sprite = {file, cols, rows, n}`; each item gets `s` = its index. Zone `s` order = first-seen. Print warnings for unknown zones/sources.

- [ ] **Step 3: Run `python -m pytest tools/tests -q`, expect PASS.** Then a real run with `--no-icons` against the Anniversary SavedVariables (`C:/Program Files (x86)/World of Warcraft/_anniversary_/WTF/Account/<acct>/SavedVariables/Amisia.lua`) to see the warnings output; do not commit the produced `data/forever.js` until a Forever scan exists.
- [ ] **Step 4: Commit** `Tools: build the Forever loot data file from addon scans`

---

### Task 10: Site: Forever data file hook-up and docs

**Files:**
- Modify: `index.html` (`GAMES` forever entry, the Import help text, `BUILD_ID`), `addon/Amisia.zip` (rebuild from `addon/Amisia`, exclude `.vscode`).

- [ ] `GAMES` forever entry: keep `soon: true` and `file: null` until `data/forever.js` exists; add a comment `// set file: 'data/forever.js' and drop soon once tools/build_scan.py has produced it`.
- [ ] Help text in the Import tab: list the new addon abilities (awards, rolls, soft-reserves, scan) in one sentence each, and the slash commands.
- [ ] Rebuild the zip: `cd addon && python -c "import shutil; shutil.make_archive('Amisia', 'zip', '.', 'Amisia')"` after removing `.vscode` from the copy (zip from a temp copy without `.vscode`).
- [ ] Bump `BUILD_ID` to the current epoch seconds.
- [ ] Commit `Amisia 1.2.0: awards, rolls, soft-reserves and item scan`.

---

### Task 11: Review and in-game check

- [ ] Run the `adversarial-review` skill on the changed addon files.
- [ ] Copy `addon/Amisia` into `C:/Program Files (x86)/World of Warcraft/_anniversary_/Interface/AddOns/Amisia` and into `_classic_beta_/Interface/AddOns/Amisia`; `/reload` on both and confirm no Lua error at load, `/amisia scan 1 2000` runs on both, `/amisia roll <link>` announces (in a group) on Anniversary.
- [ ] Update the memory file `amisia-addon.md` with the 1.2.0 export line `A`, the modules, the roll ranges and the Forever notes.

## Self-review

- Spec coverage: awards (Tasks 1-3), rolls (4-5), soft-reserves (6), scan (7, 9), UI (8), site (3, 10), tests (0 and per task), Forever notes (Global Constraints, Task 11).
- Names used across tasks: `ns.AddAward`, `ns.RemoveLastAward`, `ns.OnEvent`, `ns.BuildMatcher`, `ns.ItemID`, `ns.Announce`, `ns.RollKind`, `ns.ReservedBy`, `ns.StartRoll`, `ns.CurrentRoll`, `ns.LastRoll`, `ns.RollRanking`, `ns.OnRollChanged`, `ns.AwardFromRoll`, `ns.LootSourceName`, `ns.ScanRunning`, `ns.ScanStatus` — consistent.
