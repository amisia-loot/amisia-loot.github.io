# Amisia architecture

What the parts are, how data moves, and the contracts between the addon, the tools and the site.
Read this and [DECISIONS.md](DECISIONS.md) before changing anything. Change this file in the same
commit as a protocol, an export line, a saved key, a settings section or a TOC file.
`tools/tests/test_contracts.py` (run by `python3 tools/build.py check`) holds the tables marked
"(checked)" against the code, both ways.

The other documents: [DECISIONS.md](DECISIONS.md) (the user's decisions), `docs/FEATURES.md`
(every user-visible feature with version, status and the checks the user does in game; read by
`tools/features.py`) and `docs/specs` (a short spec before each larger feature, `README.md` says
when and how, `TEMPLATE.md` the headings; older drafts in `docs/superpowers`). See D-35.

Three parts:

| Part | Where | What |
|---|---|---|
| Addon | `addon/Amisia` | WoW Forever addon (TOC Interface 16001 only): raid recording, awards, rolls, DKP/EPGP, sync between Amisia clients, gear/BiS/map/quests/professions/talents, collectors. |
| Site | `index.html` (+ `data/*.js`) | The guild ledger on GitHub Pages; state in Supabase (`ledgers.main`). Reads the addon's export lines, writes the paste-in blocks for the addon. TBC is a read-only archive. |
| Tools | `tools/` | Python builders of `addon/Amisia/Data/*.lua` and `data/forever.js`, the build/check/release entry point `tools/build.py`, tests in `tools/tests` and `addon/tests`. |

## Module map (checked)

Every file the TOC loads, in load order. `ns` is the addon table. Every file also uses
`Locales/Locale.lua` (`ns.L`), `Core/Registry.lua`, `Core/Core.lua` and `Core/Names.lua`; the
"Uses" column names the rest (by `ns.` calls; late calls are guarded, see load order).

| File | Purpose | Owns (AmisiaDB keys) | Uses |
|---|---|---|---|
| `Locales/Locale.lua` | `ns.L`, `ns.N_`, `ns.GERMAN`; deDE shows the German key, every other locale the enUS entry | - | - |
| `Locales/enUS_core.lua` | English of Core/UI | - | Locale |
| `Locales/enUS_raid.lua` | English of Raid (1) | - | Locale |
| `Locales/enUS_raid2.lua` | English of Raid (2), bank | - | Locale |
| `Locales/enUS_gear.lua` | English of Gear | - | Locale |
| `Locales/enUS_world.lua` | English of Collect, map, quests, crafters | - | Locale |
| `Locales/enUS_selftest.lua` | English of the self-test | - | Locale |
| `Core/Registry.lua` | Pages, cards, settings schema (`ns.Get/Set`), slash words, `ns.Listen/Fire` | `settings` (via `ns.ApplySettings`) | MainFrame, Minimap (late) |
| `Core/LazyData.lua` | `ns.LazyData`, `ns.Data`, `ns.HasData`, `ns.DataSize`: generated tables built on first use; `/amisia speicher` (memory before/after a full collection, data built) | - | - |
| `Core/Core.lua` | Recording (sessions, members, loot, drops), guild bank count, export text, event frame, `ns.OnEvent`, item shim | `sessions`, `itemNames`, `exported`, `exportedBank`, `bank` | Awards, Mats, Bench, RaidLog, Points, BankNeeds, BankLog, LootPrio, GroupRolls (export hooks) |
| `Core/Names.lua` | `ns.FullName`, `ns.SameName(In)`, `ns.ExportName` ("_" for the space) | - | - |
| `Raid/Alts.lua` | Alt -> main (site paste), `ns.MainOf`, `ns.ImportSiteText` (all paste-in blocks) | `alts` | GuildWishes, LootPrio, Points |
| `Raid/Mats.lua` | Learned raid materials, `ns.MATS`/`ns.MAT_ORDER` | `mats`, `matsScan` | MainFrame |
| `Core/Chat.lua` | `ns.Say` chat queue (waits in the lockdown), `!word` dispatch, `ns.ChatLocked` | - | - |
| `Core/Comm.lua` | Addon message layer (see Comm) | - | Trust, Chat |
| `Core/Trust.lua` | Who a sender is (group, guild roster, officer rank flag 22), `ns.TrustWait`, `ns.IsVerifiedOfficer/Member` | - | Comm, Chat, Bench |
| `Core/Version.lua` | HI/VQ version check | `sync` | Comm, Trust, Sync, LootAnnounce |
| `UI/Theme.lua` | Design tokens `ns.Theme` (sizes, fonts, colours, `ATLASES`) | - | - |
| `UI/Widgets.lua` | `ns.W`: window, buttons, chips, rows, lists in the Forever look | - | Theme |
| `Raid/Awards.lua` | Award book (ids, tombstones `s.gone`, undo), master loot hand-out confirmation | `awardsVersion` (migration mark) | Alts, Sync, Points, Rolls, AwardDialog |
| `Raid/Rolls.lua` | One roll round at a time (MS 1-100, OS 1-99, SR first, +1) | - | PointsRounds, RollFrame, SoftRes, Awards, Chat |
| `Raid/RollFrame.lua` | Roll window | - | Rolls, LootPrio, Need, Bis, GuildWishes, AwardHistory, Widgets |
| `Raid/AwardDialog.lua` | The one award dialog (winner list, kind, note, points cost) | - | Awards, Need, Points, LootPrio, Widgets |
| `Raid/SoftRes.lua` | Soft-reserves paste, tooltip, loot window "SR" | `softres`, `srAliases` | Chat, LootAnnounce, Widgets |
| `Raid/LootAnnounce.lua` | Loot lead (`ns.IsLootLead`), loot announcement (without the items an item or player loot rule hands out by itself, `ns.LootRuleTakes`), `!sr` | - | SoftRes, Awards, Need, LootPrio, Chat |
| `Raid/RaidLog.lua` | Boss attempts from encounter events, presence at kills | - | Sync, Awards |
| `Raid/Bench.lua` | Bench per raid, `!bench` | `benchNext` | Sync, Trust, LootAnnounce, RaidLog |
| `Raid/GroupRolls.lua` | Group loot roll log (R lines) | `groupRolls` | RaidLog |
| `Raid/Sync.lua` | Raid sync: keeper, snapshots SP/SO, wishes OP, OK/NO/NW/ST/RQ | - (per raid `s.sync`) | Comm, Trust, Awards, Bench, RaidLog, LootAnnounce |
| `Raid/LootPrio.lua` | Loot council prio (site paste, local edits, LV/LQ/LC share) | `prio` | Comm, Trust, Sync, Awards, Alts |
| `Raid/Points.lua` | DKP/EPGP standings, earnings, costs, PS/PE/PA/PX lines | `points` | Alts, PointsSync, Awards, Sync, Chat |
| `Raid/PointsRounds.lua` | Bid and need/greed rounds inside Rolls | - | Points, Rolls, RollFrame, Alts, Chat |
| `Raid/PointsSync.lua` | KV/KQ/KS/KC share of standings and costs | - (`points.shared`) | Comm, Points, Trust, Sync, Alts |
| `Raid/RaidText.lua` | Discord text of a raid | - | RaidLog, Bench, Awards |
| `Raid/Stats.lua` | Loot statistics, hall of fame | - | Alts, GuildWishes |
| `Raid/AwardHistory.lua` | Award history: who got an item (item tooltip, `awards.tooltip`) and what a player got (roll window row tooltip); one index built on first use, dropped on `DATA_CHANGED`/`ALTS`/`RECORDING` | - | Alts, Stats |
| `Raid/BankNeeds.lua` | Guild bank needs and pledges (GN/GQ/GP, BQ/BP lines) | `bankNeeds`, `bankPledges`, `exportedNeeds` | Comm, Trust, MainFrame |
| `Raid/BankLog.lua` | Guild bank log (BT lines) | `bankLog` | MainFrame |
| `Collect/Scan.lua` | `/amisia scan`: every item id, throttled | `scan` | LazyData, Collect |
| `Collect/Collect.lua` | Item collector: items met, source notes (`scan.sources`) | (`scan`) | Scan, Gear, Drops, Collector, Bis |
| `Collect/ScanTrim.lua` | Takes out of `scan` what the N100's scan archive already holds (marker `SCAN_DONE`), at login in steps, `/amisia scan aufräumen` | (`scan`, `scan.trim`) | LazyData, Scan, Data/ScanDone |
| `Collect/Drops.lua` | Boss kill drop records (no player names), drops text | `drops` | Data/BisData, Tools page |
| `Collect/DropSync.lua` | Drop exchange DV/DQ/DI/DR/DW/DK | - | Drops, Comm, Trust |
| `Collect/Collector.lua` | Source collector (quests, vendors, world drops; own vs heard) | `collect` | Drops, CollectSync |
| `Collect/CollectSync.lua` | Source exchange CV/CQ/CI/CR/CW/CK | - | Comm, Collector, Drops, Trust |
| `Collect/QuestXP.lua` | Quest XP seen by this client (own data only, never sent) | `questxp` | - |
| `Data/GearData.lua` | generated (`build_gear.py`), lazy `GEAR` | - | LazyData |
| `Data/GearWeights.lua` | generated (`build_bis.py`), lazy `GEAR_WEIGHTS` | - | LazyData |
| `Data/BisData.lua` | generated (`build_bis.py`), `ns.BIS` | - | - |
| `Data/MapData.lua` | generated (`build_map.py`), lazy `MAP` | - | LazyData |
| `Data/DungeonData.lua` | generated (`build_dungeons.py`) | - | - |
| `Data/DungeonQuestData.lua` | generated (`build_dungeonquests.py`) | - | - |
| `Data/ProfessionData.lua` | generated (`build_professions.py`), lazy | - | LazyData |
| `Data/QuestData.lua` | generated (`build_quests.py`), lazy | - | LazyData |
| `Data/TalentData.lua` | generated (`build_talents.py`), lazy | - | LazyData |
| `Data/MageScrollData.lua` | generated (`build_magescrolls.py`), lazy | - | LazyData |
| `Data/DungeonArt.lua` | generated (`build_dungeonart.py`) | - | - |
| `Data/ScanDone.lua` | generated (`build_scan_archive.py`), lazy `SCAN_DONE`: what `tools/scan_archive.json` holds | - | LazyData |
| `Gear/Gear.lua` | Gear planner core: scoring with own weights, best items per level range | `gear` (stats cache) | LazyData, Data/BisData, Data/GearWeights, Bis |
| `Gear/GearFrame.lua` | Gear table window (`/amisia gear`) | - | Bis, Gear, Widgets |
| `Gear/Bis.lua` | Best items for the own character, wishes, `ns.UpgradeOf` | `bis` | Gear, Awards, Map, Chat |
| `Gear/Dungeons.lua` | Dungeon planner, ranking, quests per dungeon | - (`map.quests`) | Bis, Drops, Map, Collector, QuestXP, Data/Dungeon* |
| `Gear/Professions.lua` | Professions page logic | `prof` | Collector, Crafters, Drops |
| `Gear/Crafters.lua` | Guild crafter directory PV/PQ/PW/PK | `crafters` (+ `prof.guild`) | Comm, Trust, Professions, Alts |
| `Gear/Quests.lua` | World quest tracker | - | Bis, Map, Gear, Collector |
| `Gear/GuildWishes.lua` | Site wishlist paste-in (W lines), tooltip, "W" marks | (`bis.guild`) | Bis, SoftRes, Awards |
| `Gear/Compare.lua` | Upgrade marks on roll frames and quest rewards | - | Bis, Gear |
| `Raid/Need.lua` | "Wer braucht das?" UQ/UA | - | Trust, Bis, Comm, Gear, LootAnnounce, Sync |
| `Raid/LootRules.lua` | Loot rules of the master looter (D-37): ordered rules (quality, raid materials, item list -> bank/disenchant; one item -> a player), applied by GiveMasterLoot automatically or by one click on the bar beside the loot window, awards with the note "Regel: ...", one raid chat line of the hand-outs whose slot cleared; the editor in the settings (custom item); MR/MQ share between officers (an offer until "Übernehmen") | `lootRules` | Awards, LootAnnounce, SoftRes, LootPrio, GuildWishes, Need, Rolls, Points, Mats, Chat, Comm, Trust, Widgets, Settings page |
| `Gear/Talents.lua` | Talent calculator rules | `talents` | LazyData |
| `Gear/MageScrolls.lua` | Mage scrolls (Comprehension) | - | LazyData, Professions |
| `Gear/Map.lua` | One target, client waypoint or own arrow | `map` | Bis, LazyData, Widgets, Gear |
| `Gear/MapPins.lua` | World map pins via data provider | - | Bis, Map, Dungeons, Widgets, Gear |
| `Gear/MapPin.xml` | Pin template `AmisiaMapPinMixin` | - | - |
| `UI/MainFrame.lua` | Main window, page list, side tabs | (`settings.window`) | GearFrame, Widgets, Gear, Theme, SoftRes, RollFrame |
| `UI/Pages/*.lua` | One page each (`ns.RegisterPanel`), drawn from the logic files; no logic of their own beyond the view | - | MainFrame, Widgets, Theme, their logic file |
| `Core/Minimap.lua` | Minimap button, addon compartment | (`settings.minimap`) | MainFrame, Widgets, Gear, GearFrame, Map |
| `Core/SelfTest.lua` | `/amisia selbsttest`: in-game checks, `AMISIA-WERTE` line | - | read-only on everything |

Other folders: `Media/Icons` (TGA, made by `tools/make_icons.py`; a new texture needs a full client
restart), `LICENSES/` (licence texts shipped with the addon).

### Load order rules

- The TOC lists every `.lua`/`.xml` exactly once (`build.py check`: TOC against the folder).
- `Locales/Locale.lua` and the `enUS_*` parts first, then `Core/Registry.lua` (everyone registers
  while loading), `Core/LazyData.lua`, `Core/Core.lua`, then the rest in dependency order.
- A file may call into a later file only at run time (events, timers, clicks), and then guarded:
  `if ns.X then ns.X() end`. At load time it only defines and registers.
- `Data/*` carry `[AllowLoadGameType camelot]` (Forever only); they are generated, never edited.
- Saved data is shaped on `ADDON_LOADED` (Core calls the migrations, others listen); nothing is
  built at login (lazy data, see `addon/tests/test_lazy_data.lua`, `tools/load_cost.py`).
- A new client global goes into `read_globals` of `.luacheckrc`.

## Data flow

```
in game                                  N100 / tools                         site (index.html)
-------                                  ------------                         -----------------
Scan/Collect/Collector/Drops/QuestXP ->  AmisiaDB (SavedVariables)
   (and /amisia selbsttest AMISIA-WERTE)    -> Syncthing (PC -> ~/addons/_SavedVariables/Amisia.lua)
                                            -> tools/build_scan_archive.py -> tools/scan_archive.json (all scan data
                                               for good) + addon/Amisia/Data/ScanDone.lua (marker)
                                            -> tools/build_*.py (archive + file) -> addon/Amisia/Data/*.lua (next release)
ScanTrim.lua (login) <- Data/ScanDone.lua: takes what the archive holds out of AmisiaDB.scan
                                            -> tools/build_scan.py -> data/forever.js, tools/drop_obs.json
client tables (export_db2.ps1 on the PC) -> ~/addons/_wago -> build_bis/talents/professions/...
AllTheThings (MIT, --refresh-att)        -> ~/addons/_cache/att -> build_gear/map/quests/...
raid recording, awards, bank, points  -> "#AMISIA 2" export text --- paste --> Import tab (amParse...)
                                      <-- paste "#AMISIA-WL/ALTS/LC/PTS" --- "Copy for the addon"
drops text ("Drops für die Website")  -> "#AMISIA 2" DZ/DN/DK ----- paste --> Loot Tables (amParseDrops)
wishlist text                         -> "#AMISIA 2" WL ------------ paste --> Wishlist (amParseWishes)
Amisia clients  <--- addon messages (Comm: sync, exchanges) --->  Amisia clients
```

- Build inputs: own data first (scan, collector, drop records of the guild, SavedVariables), the
  user's client table export, AllTheThings (MIT), and the user-accepted inputs wowsrc.com,
  OneForAll, AtlasLoot (PC only). Nothing is fetched from wago.tools, Wowhead or foreverchanges by
  script (see DECISIONS).
- The scan data (`AmisiaDB.scan`: item lines, collector notes, suffixes) lives for good in
  `tools/scan_archive.json` (committed, about 2.5 MB; git keeps it compressed). `build.py data` joins
  the SavedVariables into it first and writes the marker `Data/ScanDone.lua`; `build_gear.py`,
  `build_scan.py` (full) and `build_bis.py` read the archive under the files (the file's line wins,
  notes join; `--scan-archive ""` for none), and `build_scan.collect` hands items in id order, so a
  file the addon trimmed builds the same data (`tools/tests/test_scan_archive.py`, round trip with
  the real files). The marker holds per item a hash of its line, per item the hashes of its notes and
  the ids the client table ItemSparse knows; the addon removes only what it covers.
- Every generated file names its generator and sources in its header; files with AllTheThings data
  are listed in `addon/Amisia/LICENSES/AllTheThings-MIT.txt`. "Generated file is current" tests
  live in `tools/tests/test_build_*.py`.
- After a change to a `data/*.js` file, bump `BUILD_ID` in `index.html`.

## Comm (addon messages)

`Core/Comm.lua`. Envelope: `<proto digit><KIND 2 letters>\t<field>\t<field>...`, at most 250 bytes,
no control characters or `|` in a field. `ns.SYNC_PROTO = 1`, `ns.SYNC_MIN_PROTO = 1`; a newer
protocol is noted (`ns.CommNewerProto`) and dropped; a kind a client does not know is dropped (so new
kinds need no protocol bump). More fields than the check needs are allowed (a later client).

| Prefix | Carries | Throttle (send) |
|---|---|---|
| `Amisia` | every control kind | 10 messages burst, refill 1/s |
| `AmisiaD` | only `BL` (blob parts) | 10 messages burst, refill 1/s; leaves 260 bytes for a waiting control message |
| both | - | 1000 bytes burst, refill 500 bytes/s; queue max 200 (low priority, then data parts fall out first) |

Send queue: priority = control before data; `opts.low` entries (exchanges) go only while nothing
else waits (ttl 120 s); default ttl 60 s; `opts.key` replaces a waiting entry; `opts.when` gates it.
Result 3/8 (throttled): back off 2^tries s, 5 tries; 11 (lockdown): hold until
`ADDON_RESTRICTION_STATE_CHANGED`; nothing is sent in the chat lockdown, in battlegrounds or arenas,
on `RAID` without a home raid, on `WHISPER` to a name neither in the group nor in the guild.

Receive limits per sender: 40 messages in 10 s and 20480 bytes in 60 s, else ignored for 60 s;
own echo dropped; per-kind gap below (a second message of the kind within the gap is dropped);
keyed gaps per first field (`KEYED_GAP`, 64 keys per sender). Blob parts: from a verified guild
member only (an outsider's parts are dropped unread for 60 s), 3 open sets per sender, 90 open parts
and 18000 Base64 bytes per sender, a set waits 30 s for its next part (`COMM_BLOB_LOST`), a finished
set id is remembered 60 s; unpacked size max 65536 bytes; packing is the client's `C_EncodingUtil`
(CBOR, Deflate, Base64), 200 characters per part.

Trust words below: **member** = `ns.TrustWait(name, "member")` (in the own guild by the roster);
**officer** = officer rank (rank flag 22) in the own guild; **in group** = `ns.InMyGroup`. The
sender is always the server's sender name, never a field.

### Message kinds (checked)

| Kind | Sender -> channel | Receiver trust | Gap (per sender) | Fields (after the kind) | Module, version |
|---|---|---|---|---|---|
| `HI` | everyone: GUILD once per session (20-60 s after login), RAID on entering a raid/recording, WHISPER as answer to VQ | member (Version); member + officer flag (Sync) | none | version, min proto, flags (`O` officer view, `L` loot lead, `-`), raid key or `-` | Version.lua, Sync.lua; proto 1 |
| `VQ` | on request: GUILD (5 min apart) or RAID | member; answered by WHISPER HI after 0-15 s | 300 s | 4 hex nonce | Version.lua |
| `ST` | keeper: RAID after a change and every 240 s; WHISPER to a new member | officer, in group | none | raid key, rev, 16 hex hash, flags (`K` keeper claim, `KM` claim as master looter, `-`), [term] | Sync.lua |
| `RQ` | follower -> keeper WHISPER; a new keeper's gathering (5th field `G`) RAID + WHISPER | `P`: member, in group; `O`/`PO`: officer, in group | 20 s (gathering: 20 s apart as `RQG`) | raid key, own rev, part `P`/`O`/`PO`, [term], [`G`] | Sync.lua |
| `OK` | keeper -> wisher WHISPER | only the keeper the wish went to | none | raid key, 12 hex op id, rev | Sync.lua |
| `NO` | keeper -> wisher WHISPER | only the keeper the wish went to | none | raid key, op id, reason `CONFLICT`/`GONE`/`DENIED`/`NORAID`/`BAD`, rev | Sync.lua |
| `NW` | follower or asked officer -> keeper WHISPER (newer state / nothing newer) | member, in group | 10 s | raid key, rev, hash, term | Sync.lua |
| `UQ` | loot lead -> RAID | officer, in group, the elected loot lead | 5 s | 4 hex question id, item ids (max 8, comma) | Need.lua |
| `UA` | raider -> asker WHISPER | member, in group; only for an open question | none | question id, `id:U/W/-:gain:pct:slot` (max 8) | Need.lua |
| `DV` | everyone -> GUILD (60-180 s after login, then max every 30 min) | member | 60 s | drop proto (2), records, newest day, weeks `w:hhhh:n` (max 4) | DropSync.lua; `DROP_PROTO` 2 |
| `DQ` | asker -> sender WHISPER | member | keyed 60 s per week | week 0-3 | DropSync.lua |
| `DI` | sender -> asker WHISPER | only the sender being pulled | none | week, part, parts (max 20), buckets `day:inst:hhhh:n` or `-` | DropSync.lua |
| `DR` | asker -> sender WHISPER | member | keyed 60 s per first bucket | pairs of bucket key and known kills (12 hex, max 16) or `*`, max 12 pairs | DropSync.lua |
| `DW` | sender -> asker WHISPER (busy) | only the sender being pulled | none | seconds 1-3600 | DropSync.lua |
| `CV` | everyone -> GUILD (90-210 s after login, then max every 30 min) | member | 60 s | collect proto (2), records, kinds `q/s/w:hhhh:n` | CollectSync.lua; `COLLECT_PROTO` 2 |
| `CQ` | asker -> sender WHISPER | member | keyed 60 s per kind | kind `q`/`s`/`w` | CollectSync.lua |
| `CI` | sender -> asker WHISPER | only the sender being pulled | none | kind, part, parts (max 8), buckets `bb:hhhh:n` or `-` | CollectSync.lua |
| `CR` | asker -> sender WHISPER | member | keyed 60 s per first bucket | pairs of kind+bucket and known records (4 hex, max 45) or `*`, max 12 pairs | CollectSync.lua |
| `CW` | sender -> asker WHISPER (busy) | only the sender being pulled | none | seconds 1-3600 | CollectSync.lua |
| `LV` | keeper -> RAID (10 s after a change, else every 240 s) | officer, in group | 8 s | raid key, 16 hex hash, item count | LootPrio.lua |
| `LQ` | raider -> keeper WHISPER | member, in group | 15 s | raid key, own hash | LootPrio.lua |
| `KV` | keeper -> RAID (10 s after a change, else every 240 s) | officer, in group | 8 s | raid key, 16 hex hash, players | PointsSync.lua |
| `KQ` | raider -> keeper WHISPER | member, in group | 15 s | raid key, own hash | PointsSync.lua |
| `KC` | officer -> RAID (an award's cost) | officer, in group; receiver in officer view | none | raid key, 12 hex award id, `D`/`G`, amount, epoch | PointsSync.lua |
| `PV` | everyone -> GUILD (120-240 s after login, then hourly) | member | 60 s | crafter proto (1), crafters, 8 hex digest | Crafters.lua; `CRAFT_PROTO` 1 |
| `PQ` | asker -> sender WHISPER | member | 60 s | crafter proto, format `B`/`L`, request number | Crafters.lua |
| `PW` | sender -> asker WHISPER (busy/spent) | only the sender being pulled | none | seconds 1-3600 | Crafters.lua |
| `GN` | officer -> GUILD after a change; WHISPER as answer to GQ | officer; only a newer rev (max 1 day ahead), all parts within 30 s | none | rev, part, parts (max 5), set by, `id:min:target` (max 8) or `-` | BankNeeds.lua |
| `GQ` | everyone -> GUILD after login (low) | member | 30 s | own rev | BankNeeds.lua |
| `GP` | member -> GUILD (or WHISPER to an asking officer) | member; only for a needed item, max 40 per name, 200 in all | none | item id, count (0 takes back), epoch | BankNeeds.lua |
| `MR` | officer -> GUILD on "An Offiziere senden"; WHISPER as answer to MQ (only a set the officer sent and has not changed since) | officer; only a newer rev than the own set, the offer and a declined set (max 1 day ahead), all parts within 30 s; becomes an offer, never active before "Übernehmen" | none (a new set per officer at most every 30 s, in LootRules.lua) | rev, part, parts (max 4), set by, rules `id:kind:value:target` (max 6; `q:2`/`q:3` and `m:-` to `bank`/`de`, `i:<id+id...>` (max 50) to `bank`/`de`, `p:<item id>` to a name with `_`, no digits; a long list takes several entries of one id) or `-` | LootRules.lua |
| `MQ` | officer -> GUILD once 35-55 s after the login (low) | officer | 30 s | newest rev the asker knows | LootRules.lua |
| `BL` | any blob part, prefix `AmisiaD` | verified guild member (before unpacking); then the art's rule | sender limits | art, key `YYYY-MM-DD:n`, set number, part, parts, 1-200 Base64 chars | Comm.lua |

### Blob arts (checked)

| Art | Sender -> channel | Receiver trust | Max parts | Payload | Module, version |
|---|---|---|---|---|---|
| `SP` | keeper -> RAID after a change; WHISPER as answer to RQ or a gathering | officer, in group; `k` = blob key | 60 | public snapshot `{k, r, e, by, d, i, z, a = awards, g = tombstones, p = plus-one, lin, h}` | Sync.lua |
| `SO` | keeper -> WHISPER to each verified officer | officer, in group, WHISPER only | 60 | officer part `{k, r, n = notes, b = bench, x = kills, l = lineage}` | Sync.lua |
| `OP` | officer (not keeper) -> keeper WHISPER, a change wish | member, in group, WHISPER only (keeper answers NO DENIED without rank) | 8 | `{k, o = op id, b = base rev, op = add/edit/restore/delete/bench+/..., id, a/f/w/n/e}` | Sync.lua |
| `DK` | sender -> asker WHISPER | only asked, member | 20 | `{v = 1, r = records, n, z, e, m}` | DropSync.lua |
| `CK` | sender -> asker WHISPER | only asked, member | 20 | `{v = 2, k = kind, r = {id, record, ...}}`; key `0000-00-00:<kind*100+bucket+1>` | CollectSync.lua; `COLLECT_BLOB_V` 2 |
| `LC` | keeper -> RAID (many askers, low) or WHISPER | officer, in group | 40 | `{v = 1, l = {{id, at, by, token, note}}}` | LootPrio.lua |
| `PK` | sender -> asker WHISPER | only asked, member | 20 | `{v = 1, d, f = B/L, m, c = crafters}`; key `0000-00-01:<request>` | Crafters.lua |
| `KS` | keeper -> RAID (many askers, low) or WHISPER | officer, in group | 20 | `{v = 1, sys, cfg, s = {{name, a, b}}, c = costs}` | PointsSync.lua |

Exchange budgets (bytes per session, parts per 10 min, one blob per N s per asker): drops 61440 B,
40 parts, 30 s (`ns.DROPSYNC_LIMITS`); sources 196608 B, 120 parts, 30 s (`COLLECT` `L` table);
crafters 32768 B, 60 parts, 20 s (`ns.CRAFTERS_LIMITS`). All exchanges: only between guild members,
never in an instance, in combat, in the lockdown or while a raid is synced; both sides pull, a blob
nobody asked for is dropped.

## Export format `#AMISIA 2`

Text block `#AMISIA 2 <exporter>` ... `#END`, fields split by spaces, names with `_` for the space,
free text (source name, note) always last. Rules (DECISIONS): existing lines stay byte for byte; a new
line is a new two-letter kind; the header stays `#AMISIA 2`; the site skips kinds it does not know.
Three texts use the header: the raid export (`ns.ExportText`, Core.lua), the drops text
(`ns.DropsExportText`, Drops.lua) and the wishlist text (`ns.WishExportText`, Bis.lua).
`tools/tests/test_export_format.py` reads a real export back with the site's parser.

### Export lines (checked)

| Line | Fields | Writer | Site reader |
|---|---|---|---|
| `S` | session id, date, instance id, zone... | Core.lua | amParse |
| `M` | name, class, first seen epoch, late 1/0 | Core.lua | amParse |
| `L` | name, item id, count (materials) | Core.lua | amParse |
| `I` | name, item id, count (blue+ loot) | Core.lua | amParse |
| `D` | item id, count, source name... (loot windows) | Core.lua | amParse |
| `A` | name, item id, epoch, MS/OS/SR/-, source... | Core.lua | amParse |
| `AS` | award id, item id, epoch, BANK/DE, receiver or -, source... | Core.lua | amParse |
| `AX` | award id, edited epoch, first winner or -, [note...] (after its A/AS) | Core.lua | amParse |
| `AD` | award id, item id, epoch, deleted epoch | Core.lua | amParse |
| `EK` | encounter id, start, end, K/W, size, difficulty, E/B/L/H, boss name... | Core.lua | amParse |
| `EP` | encounter id, end epoch, names... | Core.lua | amParse |
| `BN` | name, class, epoch, S/O, officer or -, [note...] | Core.lua | amParse |
| `R` | item id, epoch, W/A/O, winner or -, `name:choice[:roll]`... | GroupRolls.lua | ignored (not read by the site yet) |
| `PS` | pool, system, on/off | Points.lua | amParsePoints |
| `PE` | id, character, amount, code, epoch, [boss...] | Points.lua | amParsePoints |
| `PA` | award id, D/G, amount, epoch, officer | Points.lua | amParsePoints |
| `E` | end of a session block | Core.lua | amParse |
| `K` | epoch, date, HH:MM, tabs with items, visible, total, counted by | Core.lua | amParseBank |
| `B` | item id, count (bank count) | Core.lua | amParseBank |
| `LC` | item id, edited epoch, officer, prio token or -, [note...] | LootPrio.lua | amParsePrio |
| `PX` | id, name, D/E/G, amount, epoch, officer, reason... | Points.lua | amParsePoints |
| `BQ` | item id, min, target, set epoch, set by (item 0: list empty) | Core.lua | amParseGuildBank |
| `BP` | item id, count, epoch, name | Core.lua | amParseGuildBank |
| `BT` | from, to, tab, kind, item id, count/copper, tab1, tab2, name | Core.lua | amParseGuildBank |
| `N` | item id, quality, item name... | Core.lua | amParse |
| `DZ` | instance id, party/raid, name... | Drops.lua | amParseDrops |
| `DN` | npc id, encounter id, name... | Drops.lua | amParseDrops |
| `DK` | kill id, npc, instance, difficulty, date, origin, G/E, `item:n,...` or - | Drops.lua | amParseDrops |
| `WL` | item id, prio 1-3, epoch, name, [note...] | Bis.lua | amParseWishes |

Order in the raid export: header, `K`/`B`, `LC`, `PX`, `BQ`/`BP`, `BT`, then per session
`S M L I D (A|AS AX)* AD EK EP BN R PS PE PA E`, then `N`, `#END`. Sessions are fingerprinted by
`ns.SessionHash`; a new line kind that is empty for old raids keeps their hash.

Other machine lines: `AMISIA-WERTE 1 <class> <level> key=value...` (self-test report, read by
`tools/build_bis.py --werte` into `tools/bis_measured.json`).

### Paste-in blocks (site -> addon) (checked)

All are `#AMISIA-<X> 1 <game> <yyyy-mm-dd> ...` up to `#END`, written by the site's "Copy for the
addon" and read in one paste by `ns.ImportSiteText` (Alts.lua). The game must be `forever`. Pasted
text is untrusted: codes and bars stripped, every field checked and capped, at most 2000 lines.

| Block | Lines | Site writer | Addon reader -> saved |
|---|---|---|---|
| `#AMISIA-WL` | `W <item> <prio 1-3> <name> [note]` | wishAddonText | ns.ParseGuildWishes -> `bis.guild` |
| `#AMISIA-ALTS` | `A <alt> <main>` | altAddonText | ns.ParseAlts -> `alts` |
| `#AMISIA-LC` | `C <item> <edited epoch> <token or -> [note]` | prioAddonText | ns.ParseLootPrio -> `prio.site` |
| `#AMISIA-PTS` | head adds `<roll/dkp/epgp> <as-of epoch>`; `CFG k=v...`, `P <main> <a> [<b>]`, `R <sid>...`, `K <date:inst>...`, `I <12 hex>...` | pointsAddonText | ns.ParsePointsSite -> `points.site` |

Soft-reserves are not a site block: a softres CSV or `Name [item]` lines pasted in game
(`ns.SetSoftRes`, saved as `softres`).

## SavedVariables `AmisiaDB` (checked)

One account-wide table. Every key is shaped on `ADDON_LOADED`; a migration runs twice without
change (tests assert that). Settings live in `settings.<section>.<name>`.

| Key | Shape | Owner | Migration / cleanup |
|---|---|---|---|
| `sessions` | list of raids `{id, date, instanceID, zone, start, last, members, loot, items, drops, awards, gone, kills, bench, outside, rolls, sync, points, announced...}` | Core.lua | Core fills missing lists, cleans `s.sync` (pending < 1 day, 20 conflicts of tonight), award `v` |
| `settings` | `{version = 2, <section> = {<name> = value}, window, minimap}` | Registry.lua | `ns.ApplySettings`: flat 1.3 keys moved once; invalid values dropped |
| `itemNames` | `[id] = {n, q}` | Core.lua | - |
| `exported` | `[session id] = {h = hash, at}` | Core.lua | marks of deleted sessions dropped |
| `exportedBank` | epoch of the last exported bank count | Core.lua | - |
| `exportedNeeds` | epoch of the last exported needs | BankNeeds.lua | - |
| `bank` | `{at, counts, filled, tabs, total, by}` last guild bank count | Core.lua | older count never replaces newer |
| `awardsVersion` | 1 after the move of 1.4 awards | Awards.lua | `ns.MigrateAwards` (ids, tombstones, export marks) |
| `mats` | `[id] = {name, q, first, manual, hide}` learned materials | Mats.lua | `ns.MatsLoaded` |
| `matsScan` | 1 once the old raids taught the material list | Mats.lua | `ns.MatsLoaded` |
| `alts` | `{game, date, at, by, n, list = {{alt, main}}}` | Alts.lua | replaced by each paste |
| `softres` | soft-reserve list, data model 2 (`byItem`, `version`) | SoftRes.lua | `ns.MigrateSoftRes` |
| `srAliases` | `[lower list name] = fixed name` | SoftRes.lua | `ns.MigrateSoftRes` |
| `benchNext` | bench gathered before tonight's first recording | Bench.lua | earlier night falls away |
| `groupRolls` | `{runs = ...}` group loot outside raids | GroupRolls.lua | caps MAX_RUNS/ITEMS/PLAYERS |
| `sync` | `{v = 1, seen = {[name] = {v, p, mp, flags, k, o, at}}}` versions seen | Version.lua | 30 days, 300 entries |
| `prio` | `{site, edits, shared}` loot council | LootPrio.lua | entries checked on load |
| `points` | `{site, adj, shared, ...}` DKP/EPGP | Points.lua, PointsSync.lua | dropped by "forget points" |
| `bankNeeds` | `{rev, by, list = {[id] = {min, target}}}` | BankNeeds.lua | `ns.BankNeedsLoaded` |
| `bankPledges` | `{{name, item, count, t}}` | BankNeeds.lua | expire after `bank.pledgeDays` |
| `bankLog` | guild bank log entries with time windows | BankLog.lua | `ns.BankLogLoaded`; `bank.logDays`, 1000 entries |
| `scan` | `{items, sources, suffix, retry, next, from, to, count, sourceCount, trim, ...}` item scan and collector notes; `trim = {built, at, items, notes, retry, total}` the last trim | Scan.lua, Collect.lua, ScanTrim.lua | rate moved to settings (2.0); `ScanTrim.lua` removes from `items`, `sources` and `retry` what `Data/ScanDone.lua` covers |
| `drops` | `{v = 1, me = client id, k = records, inst, npc, enc}` | Drops.lua | `ns.DropsMigrate`; 28 days, 4000 records |
| `collect` | `{ver = 2, q, s, w}` records as strings (own mask) | Collector.lua | `ns.CollectMigrate`; v1 kept as heard |
| `questxp` | `[questID] = {xp, level}` | QuestXP.lua | `QX.Migrate` |
| `gear` | stats cache, key `v2/<built>/<client build>` | Gear.lua | rebuilt when the key changes |
| `bis` | `{v, chars = {[name] = {class, wish, ex, bag, bank}}, guild}` | Bis.lua, GuildWishes.lua | `ns.BisMigrate` (TBC settings and other-game guild lists dropped, 50 wishes) |
| `map` | `{v, target, hidden, quests}` | Map.lua, Dungeons.lua | `ns.MapMigrate` |
| `prof` | `{chars = {[name] = {[skill] = {rank, max, day, known}}}, guild}` | Professions.lua, Crafters.lua | checked on load |
| `crafters` | `{v = 1, src, c}` heard crafters | Crafters.lua | `Cr.Prune`: malformed dropped, 45 days, 500 crafters, byte caps |
| `talents` | `{class, level, talented, plans}` | Talents.lua | - |
| `lootRules` | `{v = 1, rev, by, at, sent, seen, list = {{id (4 hex), k = q/m/i/p, q (2/3), items, to = bank/de/name, by}}, offer = {from, rev, at, list}}` | LootRules.lua | `ns.LootRulesLoaded`: every field checked, a bad rule or offer dropped; 30 rules, 50 items per list, a player rule exactly one item |

## Settings registry

`ns.RegisterSettings{ key = "<section>", label, order, officer, expert, items = {...} }`; an item is
`{ key = "<section>.<name>", type = toggle/slider/time/choice/text/button/desc/custom, default, min, max,
step, ... }`; a `custom` item brings `build(parent)` and `fill(frame)` (the frame sets its own height;
the loot rules' editor), it stores nothing through `ns.Set`. `ns.Get(path)` returns the stored value or the default, `ns.Set` validates and fires
`SETTING`. The settings page is built from the schema. Sections (checked):

| Section | File | Section | File |
|---|---|---|---|
| `ui` | Core/Registry.lua | `prio` | Raid/LootPrio.lua |
| `record` | Core/Core.lua | `points` | Raid/Points.lua |
| `bank` | Core/Core.lua | `tools` | Collect/Scan.lua |
| `sync` | Core/Comm.lua (items added by Trust, Version, Sync) | `drops` | Collect/Drops.lua |
| `awards` | Raid/Awards.lua | `collect` | Collect/Collector.lua |
| `rolls` | Raid/Rolls.lua | `crafters` | Gear/Crafters.lua |
| `softres` | Raid/SoftRes.lua | `gear` | Gear/GearFrame.lua |
| `loot` | Raid/LootAnnounce.lua | `bis` | Gear/Bis.lua |
| `raidlog` | Raid/RaidLog.lua | `map` | Gear/Map.lua |
| `mats` | Raid/Mats.lua | `quests` | Gear/Quests.lua |
| `lootrules` | Raid/LootRules.lua (officers) | | |

A section with `officer` is hidden in the raider view; an item can carry `officer` itself. `awards`
is everyone's since 2.15.0 for its one raider item, `awards.tooltip` (the award history in the item
tooltip, D-36); its other items are the officers'.

## Locales

- German is the source text and the key: `L["Vergaben"]`. deDE shows the key, every other client
  the entry of `Locales/enUS_<area>.lua` (one key in exactly one part file). Context after `##`
  (`L["Aus##Ansage"]`). `ns.N_("...")` marks German kept as data and shown later through `L[var]`.
- Numbers and dates through `ns.Num`, `ns.FmtDay`, `ns.FmtDate`, `ns.FmtDayTime`.
- Machine formats never translate: export lines, addon messages, `AMISIA-WERTE`, talent codes, saved
  keys. Chat lines go out in the sender's language. Slash commands keep the German word plus `en =`.
- A German literal that must stay (a typed sub-word, a data key) ends its line with `-- l10n-ok`.
- `python3 tools/l10n.py check`: no German outside `L`, every key translated, none unused or twice,
  format specifiers in the same order. The game font has no `–`, `—`, `…`, arrows or bullets: use
  `·` and textures.

## Build, check, release

`python3 tools/build.py` (re-executes itself in `~/.venvs/amisia` when `lupa` is missing):

| Command | Does |
|---|---|
| `data [--sv FILE] [--wago DIR] [--refresh-att]` | every generator in order: scan archive (and its marker), dungeons, gear, map, dungeon quests, quests, professions, talents, mage scrolls, dungeon art, BiS; a step without its client tables is skipped or uses its kept snapshot; ends with `git diff --stat` |
| `check` | luaparse syntax, addon tests (deDE, then enUS), `tools/l10n.py check`, layout rules (`tools/ui_layout.py rules`, both locales), `pytest tools/tests` (incl. generated-file-current and `test_contracts.py`), UTF-8 without BOM, TOC against the folder, luacheck |
| `snapshots [--out DIR] [--compare DIR] [--locale enUS]` | PNG of every page and window from the test stub, index.html, changed layouts |
| `release X.Y.Z [-m ...] [--no-push] [--no-copy]` | warning with Amisia's game errors, clean tree, TOC version, check (TOC restored on failure), `addon/Amisia.zip`, CHANGELOG.md, commit `Amisia X.Y.Z: ...`, push main, `tools/release_addon.sh`, then the test list of the version's features in `docs/FEATURES.md` (a warning when none carries it) |
| `testlist [--all] [--out FILE]` | the German check list of the features with status `gebaut` from `docs/FEATURES.md`, newest version first; `--all` adds those that need a group, guild or raid |
| `tested F-001 [...] [--raid]` | sets their status in `docs/FEATURES.md` to `im Spiel geprüft (today)` (`im Raid bewährt`) |
| `errors [--sv FILE] [--all]` | the Lua errors in `~/addons/_SavedVariables/!BugGrabber.lua` that name Amisia (`--all`: every addon's), via `tools/game_errors.py`; `check` adds a non-failing note "Fehler aus dem Spiel: N" |

The version stands only in `## Version:` of `Amisia.toc` (`ns.VERSION` reads it at load). GitHub
Actions (`.github/workflows/check.yml`) runs the checks on push.

## Machines: PC, N100, Syncthing

| Path | Role |
|---|---|
| `~/addons/Amisia` (N100) | the only working copy; commits and pushes happen here |
| `~/addons/_release/Amisia` | committed HEAD of `addon/Amisia`, written only by `tools/release_addon.sh`; Syncthing folder `amisia` (send-only) -> `C:\Users\aobiw\VuloSync\Amisia` on the PC, junctioned into `_classic_beta_\Interface\AddOns\Amisia` |
| `~/addons/_SavedVariables/Amisia.lua` | receive-only copy of the PC's SavedVariables (folder `vfui-savedvariables`); read only; its scan part goes into `tools/scan_archive.json` with every `build.py data`, after which the addon trims it |
| `~/addons/_SavedVariables/!BugGrabber.lua` | receive-only copy of the PC's error catcher SavedVariables (same Syncthing folder); read only by `build.py errors`, `check` and `release` |
| `~/addons/_wago` | receive-only client tables (folder `amisia-wago`), exported on the PC by `tools/export_db2.ps1` |
| `~/addons/_cache/att` | AllTheThings cache (MIT), read only through the sandboxed `tools/att_data.py` |
| `~/.venvs/amisia` | Python with lupa and pytest for the tests |

In-game tests are the user's (PC); `/reload` after a release (a new file or texture needs a full
client restart). PC-only builders: `tools/build_scan.py` (full), `tools/build_bossnames.py` (archive);
optional PC-only build inputs: AtlasLoot, OneForAll and the live SavedVariables.
`tools/sync_addon.ps1` (PC) skips junctioned targets, so the PC never writes into the received copy.
