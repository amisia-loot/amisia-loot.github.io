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
