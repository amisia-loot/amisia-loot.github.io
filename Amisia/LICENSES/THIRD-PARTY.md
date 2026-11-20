# Third-party data in Amisia

Amisia is free software under the GNU General Public License, version 3 (GPL-3.0); the full text is in
`LICENSE` in each of the three addon folders (Amisia, Amisia_Raid, Amisia_Gear). The generated data files of
Amisia: Gear & Dungeons are built in part from the data below.

## AllTheThings (MIT)

- Source: https://github.com/ATTWoWAddon/AllTheThings, folder `.contrib/.db/forever` (the hand-kept WoW Forever data).
- Licence: MIT, Copyright (c) 2026 AllTheThings WoW Addon. The licence text and the list of the files built from
  it are in `AllTheThings-MIT.txt` next to this file.

## QuestieDB (GPL-3.0)

- Source: https://github.com/Questie/questiedb, folder `data/Forever` (the WoW Forever item, NPC, object and quest
  tables).
- Used for: the item sources (NPC drops, objects, vendors, quest rewards) in `Amisia_Gear/Data/GearData.lua`, only
  for items none of Amisia's other sources knows.
- Licence: QuestieDB's `LICENSE.md` puts contributions made after 21.10.2026 under the GPL-3.0. Its data was first
  imported from Questie (https://github.com/Questie/Questie); for that older content its authors write that the
  licensing is unclear, that the Questie team considers it shared in the spirit of open source and is alright with
  others copying it under the GPLv3 terms, but cannot promise that every historic contributor agrees ("when in
  doubt ... all rights reserved"). Amisia uses the data under the GPL-3.0 on that basis.
- The Questie name and logo are not used by Amisia.

## foreverchanges.pro (item pages)

- Source: the item pages of the fan site foreverchanges.pro (Waypoint Digital SL), fetched on 2026-11-20 by
  Amisia's build tool, one page every three seconds, within the site's robots.txt, only for items none of Amisia's
  other sources (including QuestieDB) knows.
- Used for: where those items come from (the creature, vendor, quest or object the page names, with its zone) in
  `Amisia_Gear/Data/GearData.lua`. Nothing else of the site is used: no text, no images, no stats.
- Terms: the site's terms of use (3 November 2026) welcome links and short quotes and ask not to overload it with
  automated requests or to copy its compiled data wholesale to republish it as one's own. Amisia takes only the
  sources of the items no other source knows (229 items of the 13568 the site lists, on 2026-11-20) and names the
  site here and in the header of the data file. The game data itself
  (names of items, creatures, quests, zones) belongs to Blizzard Entertainment.
- MetaForge (metaforge.app) is not used: its terms of service do not allow scripts without permission.
