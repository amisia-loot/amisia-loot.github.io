# Changelog

What changed in each release of Amisia, in English (D-60). New notes go under the
heading "Unreleased" with the change itself; `build.py release` turns them into the version's section.

## Unreleased

- feat(dungeons): run times with splits, best time and history (F-166)

  A small "Run times" window opens with the first fight in a dungeon (and raid): the running time, each
  boss's split with the difference to your best run in green or red, the next boss's target, and at the end
  "New best time!" or the difference, with one chat line. Runs that are reset or left unfinished stay in the
  history but never count as a best. The Dungeons and Raids pages have a new "Times" tab with the best run,
  the best time per boss and the latest runs; `/amisia times` opens the window, `/amisia times stop` stops
  the clock.

- feat(lineup): set raid roles from name lists (F-165)

  The Lineup page has a new view, "Roles" (a link in its head row): lists of main tanks (in order, "From the planner" fills it
  with the night's tanks), assistants and master looters (the first one in the raid gets it) with the loot
  threshold. "Set roles now" promotes, marks and sets master loot for the listed raiders, as raid leader
  and out of combat; it never demotes or clears. An optional switch does the same for each player who
  joins. If the game does not let addons set a role, the chat says so once and that list is skipped.

- feat(lineup): invite the guild by rank, own whisper keywords, accept invites (F-163)

  The Lineup page's "Invite" view (officers) has a rank picker and "Invite guild": after a question with
  the number of players it invites every online guild member of that rank or higher who is not in the
  group, one every 0.5 seconds as with "Invite all", also on a night without a lineup; the list shows
  them with their status. The whisper invite takes your own keywords ("inv, invite" by default). A new
  setting for everyone, "Accept invites from guild and friends", joins a group of a guild member or
  friend without a click.

- feat(raid): pull and break timer (F-164)

  `/amisia pull [seconds]` counts down to the pull for the group with the game's own countdown (when the
  client has it) and a raid warning; `/amisia break [minutes]` announces a break with its end, one
  minute before and when it is over. As leader or assistant; alone only for you. The status line shows
  the running timer, and its menu starts or cancels both.

## [v2.73.1](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.73.1) (2026-11-10)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.73.0...v2.73.1) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- fix(lineup): the author's character sees the officer pages without a rank (F-162)

  The pages Lineup and Raid check open for the addon author's character even without an officer rank
  or a guild. Nothing changes for anyone else, and what other players' clients accept still depends
  on the sender's guild rank.

## [v2.73.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.73.0) (2026-11-10)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.72.0...v2.73.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(lineup): build a raid lineup without a sign-up list (F-161)

  The Lineup page (officers) now works from scratch: the planner opens on an empty night and
  "Players" lists the raid or the guild with an online filter, a class filter and a search; click a
  name, then a place. "Templates" keeps a lineup under a name and loads it on another night. Under
  "More" you can take the groups of the current raid, clear the groups, or export the night as text
  that another officer pastes to get the same groups.

## [v2.72.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.72.0) (2026-11-09)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.71.0...v2.72.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(professions): where a reagent comes from (F-160)

  Click a reagent on the Professions page (in a recipe, the crafting list or the route's shopping list)
  and a menu "Where does ... come from?" lists its vendors with place and price (nearest first), the
  recipes that make it, the zones where you gather it (herbs, ore, leather, fish), the mobs that drop
  it, quest rewards and world drops. Click a line to set the waypoint, open the zone's world map or
  open the recipe.

- feat(professions): your alts' reagents and how often you can craft (F-159)

  Reagents now show what your other characters of the same realm and faction hold: "4+6 / 10" in
  orange when it is enough with them, and their names and counts in the tooltip. A known recipe shows
  "(3)" behind its name when your bags hold enough for three, and the reagents' head says how many
  you can craft with and without the bank.

## [v2.71.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.71.0) (2026-11-09)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.70.0...v2.71.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(ui): move and style the item display (F-158)

  The "+Item" display has its own settings section "Item display": move it with the mouse ("Move the
  display", then "Done"), choose the font, its outline and shadow, show or hide the icon, align it left,
  centered or right, set how long a line stays, whether it rises, sinks or stays still, whether new lines
  come below or above, how many show at once and how transparent it is. Your earlier settings are kept.

- fix(ui): the logo in the window's head without the black disc (F-147)

  The Amisia logo at the top left of the main window no longer sits on a black disc: only a thin gold
  ring surrounds it, with the head's background behind it.

## [v2.70.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.70.0) (2026-11-09)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.69.0...v2.70.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(gear): the source symbol in the gear planner opens the boss or the recipe (F-157)

  A click on the dungeon or raid symbol of a suggestion opens that dungeon or raid at the boss that
  drops the item, with the item's row marked. A click on a profession symbol opens the recipe on the
  Professions page. The symbol's tooltip says where a click goes.

## [v2.69.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.69.0) (2026-11-08)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.68.0...v2.69.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(ui): the officer view only for the guild's officers (F-156)

  Only players with an officer rank in the guild (and the author's character) get the officer view.
  Everyone else has the raider view: the switch in the menu, the setting and /amisia view officer are
  gone for them. Officers can still switch to the raider view and back.

## [v2.68.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.68.0) (2026-11-08)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.67.0...v2.68.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(dungeons): bosses with portraits, their loot with icons (F-154)

  The overview of a dungeon or raid now has two columns: on the left the bosses, each with a round
  portrait of its model in a gold ring, its number, name and how many items and upgrades it drops; on
  the right the chosen boss with its loot, each item with its icon in its quality's frame, slot, gain,
  drop chance and a star for the wishlist. A click on a boss shows its loot.

- feat(ui): the main window in the game's own window frame (F-147)

  The main window has the standard frame of the game's windows again: its border, the title bar with
  "Amisia", the red close button and the game's minimize button next to it. Inside, the hub stays as
  it is: the picture head, the tabs, the side bar and the footer.

- feat(professions): camp objects and Merchant's Favor recipes in the same boxed detail as every recipe (F-151)

  The views Lager and Händlergunst now show the chosen entry like a profession's recipes: the boxes
  Details, Reagenzien with have/need from bags and bank, and the guild's crafters, with the star and
  "+ Liste". A camp object lists its places, what it replaces and its description above its recipe.
  The profession data is rebuilt from the newest AllTheThings Forever data (more vendors and prices).

- feat(professions): read profession trainers for the real learn ranks (F-155)

  When you talk to a profession trainer (or a rogue trainer for poisons), Amisia quietly reads what it
  teaches: the skill each recipe needs, its price and the trainer. The recipe's Details then show the
  real learn rank "(vom Lehrer)" and the trainer with a waypoint; estimated learn ranks carry a "?"
  and the head counts them. `/amisia lehrer` tells how many trainers were read. Nothing is learned,
  bought or sent; the readings go into the profession data with the next data build.

## [v2.67.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.67.0) (2026-11-08)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.66.0...v2.67.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(map): flight masters, zeppelins and ships are off on the world map by default (F-105)

  Amisia no longer puts flight master, zeppelin and ship icons on the world map; the dungeon and raid
  entrances stay. Switch them on again under Settings, Map and waypoint.

- fix(ui): the "+Item" display shows only loot and quest rewards (F-152)

  Items and money now show only when you loot them from mobs or chests or get them for a quest.
  Purchases, sales, the mail and trades no longer show.

## [v2.66.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.66.0) (2026-11-08)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.65.0...v2.66.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(prof): recipe view with WoW icons, favorites and a crafting list (F-151, F-153)

  A profession's recipes now look like the game's: tabs All recipes, Favorites, Merchant's Favor, Crafting
  list and Route; a head with the profession's icon, your skill and how many recipes you know; each recipe
  with the crafted item's icon, a bar in its difficulty colour and dots for "I know it" and "the guild knows
  it". The detail shows the colour steps, where to learn it, the reagents with what you have, and the guild
  members who can craft it. Star a recipe to keep it under Favorites, or add a count to the crafting list,
  which sums up all reagents and where to buy them. The filters moved into the funnel next to the search.

- feat(ui): Amisia's own gold icons for the tabs and the side bar (F-147)

  The tabs and the pages in the side bar now carry gold line icons drawn for Amisia (a shield for
  Gear, swords for Dungeons & Raids, a hammer for Professions, dice for Raid and so on) instead of the
  game's grey marks. The item slots of the gear planner have a thin rounded frame in the item's
  quality colour instead of the thick square one, and their icons rounded corners.

## [v2.65.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.65.0) (2026-11-08)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.64.0...v2.65.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(gear): no extra gear window: the gear goals live in the gear planner (F-149)

  The Gear Goals window is gone; everything it had is on the Gear Planner page. The new Goals tab
  shows "N/17 goals" with its bar, the filters and your slots by section; a click shows that slot's
  suggestions, which now start with "Your pick" (remove it, or take over a better item). Under the
  model switch between targets and worn gear and see your score; its tooltip shows the best at your
  level and the biggest stat changes. "Options" holds the weapon plan, sources and play style, and the
  search box also takes an item link or ID. The Gear tab's side bar lists no windows any more; the
  gear table still opens from the Gear page. The goals window's size setting is gone.

- feat(ui): the "+Item" display shows money too, in the items' quality colours, with its own font size (F-152)

  Item names now always take their quality colour (in 2.64.0 they stayed white on Forever). Money you
  get shows as "+1g 2s 3c" with the coins in gold, silver and copper. Settings, Interface: "Show money
  you get" and "Display font size" (10 to 32).

- feat(gear): the gear planner closer to its model: wider panel, richer rows, source menu (F-149)

  The planner's left panel takes about 42 % of the page and grows with the window, the model with it;
  slots are bigger and the weapons' enchant squares sit above them. Rows are taller and read like
  "Level 25 · Razorfen Kraul - Roogug", "Level 32 · Tailoring 150" or "Quest: Free at Last" (with a
  yellow "!" after the name); crafted items show their profession's icon and an empty slot shows
  "new" instead of a percentage. "Sources" next to the search turns the gear page's source switches
  on and off, and "Level" stands before the level boxes again.

- feat(prof): professions overview first, four cards a row and the nearest trainers (F-151)

  The Professions tab now opens on the overview the first time in a session, even when a profession
  was open before. Its cards are narrower, four to a row. At the bottom, "Nearest trainers" lists for
  each profession the closest trainer of your faction with the zone and a map button that sets the
  waypoint.

## [v2.64.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.64.0) (2026-11-08)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.63.0...v2.64.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(ui): show the items you get as "+Item" near the middle of the screen (F-152)

  When you loot something or get an item as a quest reward, Amisia briefly shows "+Name" with the
  item's icon in its quality colour; it rises and fades out. Switch it under Settings, Interface
  ("Show items you get"), choose the lowest quality shown, and try it with "Try the display".

- feat(prof): professions overview with cards, professions in the side bar (F-151)

  The Professions page opens on an overview: your professions with rank and known recipes, every
  profession with its recipe count, and cards for the camp objects and the Merchant's Favor. Click a
  card to open that profession's recipes. The side bar lists Overview, each profession with its icon,
  Camp and Merchant's Favor (with your favor) to switch between them.

- feat(gear): talents with classes, plans and actions in the side bar (F-150)

  The Talents tab lists the nine classes with their crests in the side bar, then the two plans
  (Plan 1: Primary, Plan 2: Secondary) and the actions Load own, Clear plan, Import build and Export
  build. The page shows "Level · Available · Spent · Remaining" across the top and the three trees,
  each in a thin gold-brown frame on its part of the class's own art; the trees grow with the window.
  Export marks the code for Ctrl+C, import empties the code box for a pasted code or build link.

- feat(gear): gear planner with your model, suggestions per slot and sets in the side bar (F-149)

  The Gear tab opens with the new Gear Planner. On the left your character stands on a dark panel
  between eight slots on each side and the weapons below, with your name, level and spec picker on
  top; each slot shows its target in its quality's frame (green once worn) and a small square with
  the enchantment of your worn item, or a "+" that lists the enchantments that fit. On the right pick
  Suggested or Wishlist, search all items, and set the level range; each row shows the item, its
  level and source, the gain, the source's symbol and a star for the wish list. Click a row to make
  it your pick for the slot (click again to lift it); Reset removes all your picks after asking. The
  side bar lists raid, dungeon, PvP, crafted and world sets and reputation; a click shows them.

## [v2.63.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.63.0) (2026-11-08)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.62.1...v2.63.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(world): dungeons and raids as a table grouped by level range (F-148)

  The start of the Dungeons and Raids pages is now a table instead of tiles: each instance with its
  picture, name, level in the quest log's colours, the territory's crest, zone, keys, open quests and
  a map button for the waypoint to the entrance. Click a column head to sort, a level range to fold
  it. The side bar lists the level ranges (raids: their sizes) with their counts; a click jumps there.

- feat(ui): the main window is a hub with tabs along the top (F-147)

  The window has a new dark frame with a thin gold edge. Its head shows the Amisia logo and name over a
  strip of the game's loading screen, with the search box and buttons for feedback, minimize and close.
  Under it sit the tabs Gear, Dungeons & Raids, Professions, Talents, Raid, Guild and the gear for the
  settings; the side bar shows only the open tab's pages, each with its symbol. Quests and the map moved
  to Dungeons & Raids, the mage scrolls to Professions. The footer shows the recording state (click it
  for the menu), your view and the version.

- feat(world): dungeon and raid journal with search, your run, instance maps, wishes and keys (F-146)

  The Dungeons and Raids pages get a search box, the choices All / Fitting / Quests and "Where am I".
  Cards show the bosses you killed in your current run, your open quests and the keys you have or
  lack, and the instance you stand in is marked. Inside an instance the page opens it directly. The
  detail has tabs: overview with your run (right-click a boss to mark it), the game's map of the
  instance with its floors, quests, your wish list for this instance, and the keys with the quests
  that lead to them.

- feat(ui): the main window can be dragged wider and minimized to a small bar (F-145)

  The grip at the bottom right corner now changes the width as well as the height, up to 1440 pixels.
  Lists and rows use the extra room, and the dungeon and raid cards show up to six per row. A new red
  button next to the close button folds the window into a small bar; a click on the bar brings the
  window back at the same place.

- feat(ui): the side bar gets a head with the logo, headings and a symbol on every row (F-145)

  The main window's side bar now starts with the Amisia logo, the version and the current view.
  Each group is a gold heading with all its pages listed under it, so nothing needs to be unfolded
  any more. Every page and side window has a small game symbol in front of its name.

## [v2.62.1](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.62.1) (2026-11-07)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.62.0...v2.62.1) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- fix(raid): loot rules and other loot addons' roll lines read item links with the named colour form (F-074, F-092)

  Item links that carry their quality as a named colour (such as "|cnIQ4:") are now read correctly: a loot
  rule no longer picks up the colour's number as a second item, and roll rounds started by another loot
  addon are recognised again.

- fix(raid): raid sync, loot rules, lineup and soft-reserve fixes from a code audit (F-025, F-019, F-074, F-078, F-083, F-084, F-098, F-015, F-030)

  An officer whose view was set to raider no longer loses award notes, first winners and "by hand" marks:
  they are kept, the officer part is asked for again on switching back, and a new keeper gathers them
  before sending, so they are no longer wiped for the whole raid. A late officer part of an older state no
  longer blocks a newer one. Soft-reserve marks now also show in the loot window of Classic Era and TBC
  Anniversary. Two sign-ups of the same character make one lineup row, a night older than the eight kept
  ones is refused with a message instead of vanishing, and a failed invite no longer uses up a try. A loot
  rule that would make the set too big to send to the officers is refused when it is added. Raid-Check and
  the award dialog no longer compare hidden boss-fight values, and the statistics no longer break on a raid
  saved without a start time.

- fix(gear): gear, quest and journal fixes from a code audit (F-039, F-038, F-048, F-049, F-047, F-122, F-003, F-045)

  A set in the gear goals counts its bonus once instead of twice. A repeatable quest turned in early stays
  open, the talent planner's class list sorts reliably, and an item the server answers too slowly is asked
  again a minute later instead of having no stats all session. The enchant line also matches on clients
  whose template has brackets or hyphens, and the level table opens even with an odd saved column. A quest
  reward that is no upgrade no longer says the slot is empty, the Raids page redraws after a spec change
  and when item data arrives, the overview cards show short dates, the map's "no place" view names the
  guild's crafters again after combat, and two-click moves in the lineup act on the chosen player.

- fix(guild): exchange, trust, chat and calendar fixes from a code audit (F-036, F-037, F-025, F-019, F-087, F-088)

  A drop or source pull cut off by combat and restarted within a minute is still pulled, and the first data
  sent after a /reload is no longer dropped as a repeat. A "!" command from a guildmate with your first
  name is no longer taken for your own line, and former guildmates are no longer trusted after you leave the
  guild. Gear without stats (shirts, tabards) is no longer stored again on every bag update. A busy game
  calendar no longer makes the raid calendar read it more and more often, and the sign-up window keeps the
  date it was opened at.

## [v2.62.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.62.0) (2026-11-07)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.61.0...v2.62.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(ui): boss rows fold into one line with their loot icons (F-144)

  On the detail pages of dungeons (part Bosses) and raids every boss is a row with the quest log's plus or
  minus. A click folds or unfolds it: folded, its item rows are hidden and up to six small item icons in
  their quality's colour stand at the row's right end, with "+N" for the rest; hovering an icon shows the
  item's tooltip and clicking it works like clicking its row. Bosses with an upgrade for you start unfolded,
  the others folded, and an "Expand all"/"Collapse all" link sits in the bosses' header line. The fold is
  kept per dungeon until the next /reload.

- feat(ui): start pages with cards and a detail page for dungeons and raids (F-143)

  The pages Dungeons and Raids now open on a start page with every dungeon or raid as a card, three side by
  side: its image with the name in gold, the level and how well it fits you, and the upgrades, the gain per
  run and the value; the recommended one carries a green "Recommended" tag, ones out of reach are greyed.
  A click on a card opens its detail page with a "< All dungeons" link back, the image right under the head
  row and the boss or quest list reaching down to the bottom. The search, the map's entrances and the
  quest pins open the detail page directly; raid cards also show the size and your raid ID.

- feat(ui): a page head with the page's name, one line and a gold rule (F-142)

  Every page now starts with its name in large gold letters, one grey line on what the page is for, and a
  thin gold line that fades out to both sides. The page's help "i" and its settings gear moved from the
  window's head into this page head. The window is 38 pixels taller for it, so no page lost any room.

- feat(ui): one side bar with groups instead of tabs under and beside the window (F-141)

  The main window has one way to its pages: the side bar on the left, laid out like the auction house's
  category list. The groups Raid, Character, World, Guild and Amisia are bars with a plus or minus, and one
  is unfolded at a time with its pages under it; Calendar and Duels moved into Guild. The side windows (gear
  table, gear goals, talent calculator, and for officers the roll window and the soft-reserve import) are
  rows right under their page, and a click opens or closes them. The tabs under the window and the tabs on
  its right edge are gone. The window's height can be dragged at the grip in the bottom right corner (598
  to 898), long lists grow with it, and the height is kept.

## [v2.61.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.61.0) (2026-11-06)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.60.0...v2.61.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(ui): a tidier interface with one red button per view (F-140)

  The window head has no red buttons any more: the raid status sits in the middle with a small arrow that
  opens a menu to pause or resume the recording and to switch the view, and the right end holds a gear for
  the page's settings and the game's "i" for the page's help. The grey explanations at the bottom of many
  pages moved into that "i", and their lists now reach the bottom. Views and choices are quiet gold words
  (the chosen one white and underlined), on/off filters have a small check box, values to pick in the
  settings are dropdowns, and every action but a view's main one is a quiet link. Overview cards open with a
  click anywhere on them. Row buttons such as "Map", "Waypoint", "Wish" and "Invite" show only while the
  mouse is on their row. The side windows follow the same line: the gear table, the goals window, sign-up,
  raid calendar, soft-reserve import, setup, the officers' roll window ("Award" always shows on the winner)
  and the award dialog.

## [v2.60.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.60.0) (2026-11-06)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.59.0...v2.60.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(dungeons): a run planner in the dungeon journal (F-139)

  The journal now answers the questions before a run. The dungeon's image shows what the run brings: the
  open quests' XP on your XP bar (the tooltip names your level after the run) and the upgrades. "Your run",
  the first card of the list (or "Plan the run" in the planner), lists the stops before the run by zone with
  a route button that walks them, the bosses in the game's order with the quests whose objective or start
  item hangs on them, and where to hand in afterwards. Every quest gets a worth ("Must", "Worth it",
  "Skip", "Later") with a bar, the quest view shows a level window up to the level the quest turns grey,
  reward tiles name the item they replace and the best choice, and the done steps at the start of a quest
  path fold to one line.

## [v2.59.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.59.0) (2026-11-06)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.58.0...v2.59.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(dungeons): a quest journal for each dungeon (F-138)

  A click on a dungeon quest now opens the dungeon's quest journal: all its quests on the left as cards
  with the game's quest mark, level, path progress and the upgrade gain, the chosen quest on the right
  with its next step, the rewards as tiles with icon and gain, the XP and the quest path. Click another
  quest on the left to switch without going back; done steps of the path fold to one line.

## [v2.58.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.58.0) (2026-11-06)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.57.0...v2.58.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(professions): a route to the top rank with a shopping list (F-137)

  The professions page has a switch "Rezepte | Route". The route shows the cheapest way from your rank to
  the top of a crafting profession, cooking, first aid or poisons: which recipe to craft how often, when to
  visit the trainer, what it costs at vendor prices and, with "auch Händler", which recipes to buy. Materials
  no vendor sells are weighed by an estimate from their sell price, so the route prefers orange and yellow
  recipes and never asks for hundreds of crafts that hardly give a point; recipes with a cooldown, of a
  specialisation or from a quest stay out, and a recipe is never planned before you can learn it. The
  shopping list counts what you have in bags and bank and what your alts on the same realm and faction
  hold, and sets the waypoint to a vendor. The current step moves on as you skill up; nothing is sent.
- fix(map): no more "blocked action" errors after Amisia opened a game window (F-045, F-106, F-090)

  The "Karte" buttons now let the game open the world map itself, on the right zone. Amisia no longer
  closes the who list after "Klassen suchen" and no longer opens the game calendar from the sign-up window
  ("Warum?" names the reason and the calendar button at the minimap). Each of these could leave the game's
  window manager tainted until /reload, and opening or closing windows later, even in combat, raised
  "blocked action" errors (SetPassThroughButtons, SetPropagateMouseClicks).

## [v2.57.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.57.0) (2026-11-06)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.56.0...v2.57.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(professions): clearer recipe filters that explain an empty list (F-051, F-035)

  "Bekannt" and "Quelle" are real dropdowns now ("Bekannt: Alle", "Quelle: Händlergunst"), "Gilde (N)"
  shows how many recipes the guild shares and is greyed while nobody does, and the count reads "N von M
  Rezepten". An empty list says which filter would bring recipes back and offers "Filter zurücksetzen".
- feat(map): all zones, dungeon quest steps and items without a place on the map page (F-045, F-135)

  The page opens on "Alle Zonen", grouped by zone, nearest first. The new chip "Quests" lists the next
  step of each dungeon quest path, also as a "!" on the world map. "Items ohne Ort" opens a list with the
  reason and who can craft them; the target is a card with distance, direction and a turning arrow; rows
  have a "Karte" button; names Amisia saw in the game are shown in German.
- fix(chat): chat commands and guild names with the realm ending (F-019, F-023, F-032)

  Chat commands like !sr, !bench, !dkp, !bid, !need, !greed and !pass now find the player when the client
  writes the sender as "Name-Realm": the own realm's ending is dropped, the answer still goes to the sender.
  Your own echoed line is no longer taken for a command, and the classic guild roster stores names without
  the own realm, so those members are recognised in the group.
- fix(chat): announcements and whispers on TBC Anniversary and Classic Era (F-126)

  Where only the old chat function exists, Amisia now sends its raid announcements, roll countdowns and
  whispers instead of dropping them silently.
- fix(rolls): roll window for rounds of other loot addons in a five-man group (F-092)

  In a five-man group the group leader is now recognised as the loot lead, so roll rounds announced in
  party chat open the roll window again.
- fix(settings): raiders reach "Wer braucht das?" and "Loot-Prio" (F-103)

  The head button "Einstellungen" now offers both sections on the Vergaben page, and "Loot-Prio" on the gear
  page, so raiders, who don't see the officers' Rolls page, can reach them.
- fix(gear): item tooltips no longer replaced while the item is still loading (F-039)

  An item the client knows but had not loaded yet showed Amisia's scan tooltip ("der Server beschreibt
  dieses Item nicht") and lost Amisia's own lines. Now only items missing from the client's item table get
  the scan tooltip; a loading item keeps the normal tooltip and is shown again once its data arrives.
- fix(duels): "Klassen suchen" no longer closes a who list the player opened (F-106)

  If the player opened the who list or sent an own /who while Amisia's question waited for its answer,
  Amisia closed the list when the answer came. Now it only closes the list its own answer opened.
- perf: smoother gear swaps, members page and duels

  Swapping a gear set refreshes the gear page, the Gear Goals window and the slot card once instead of once
  per slot (about 15 ms instead of 170 ms in the test client). A new character's first login no longer
  builds the stat weights (about 1 MB). World map pins wait two seconds after a bag change before redrawing.
  The members page reuses its rows for search, filters and sorting (about 2 ms instead of 26 ms with 800
  members), and learning a duellist's class or tree no longer re-reads every duel (0.4 ms instead of 26 ms).
- feat(ui): Raid tab in the order of a raid night, "Raids" becomes "Raid-Archiv" (F-094, F-013, F-017)

  The Raid tab lists its pages as a raid night runs: Übersicht, Aufstellung, Soft-Reserves and Raid-Check
  before, Rolls, Vergaben and Raid-Log during, Punkte, Statistik, Raid-Archiv and Export after. The officers'
  page of recorded raids is now called "Raid-Archiv", so "Raids" is only the raid journal in Ausrüstung, and
  Export moved next to it. "Löschen (n)" and "Angekreuzte (n)" show how many raids are ticked and are grey
  without any, "Alle wählen" turns into "Keine wählen", a footer explains the grey date and the orange +N,
  and an empty export box says what each button fills in.
- feat(ui): search finds pages by keywords and lists commands (F-095)

  Pages and settings sections are found by German and English keywords ("dkp" finds Punkte, "wegpunkt"
  the map, "bis" the gear page). A new group "Befehle" lists the /amisia commands from three characters; a
  click writes the command into the chat line. The search box's tooltip says what it finds from how many
  characters, one typed character shows "Noch 1 Zeichen", and results keep their scroll place while data
  changes during a raid.
- feat(ui): quick menu follows the tabs, portrait opens the overview (F-004, F-003)

  The minimap's right-click menu lists the window's tabs; a click shows that tab's pages (Kalender,
  Aufstellung, Berufe, Quests, Talente, Dungeons and the rest) in the same menu, with "Zurück". A click on
  the Amisia portrait opens Übersicht from any tab, and overview cards all say "Öffnen"; the raiders' last
  raid card opens the Raid-Log.
- feat(ui): clearer buttons and tooltips across the pages (F-022, F-015, F-048, F-039, F-049)

  Every set-a-waypoint button says "Wegpunkt", the guild bank's remove button "Entfernen", and buttons that
  open a window carry its name ("Ausrüstungsziele", "Talentrechner", "Raid-Kalender", "Aus Kalender"). The
  Raid-Log drops its duplicate "Discord-Text" button and explains its views; Vergaben explains MS, OS, SR and
  "ohne" (was "-"); the gear page's view chips, "Pausieren" and the side tabs have tooltips; an empty quest
  list no longer mentions checkboxes and offers "Filter zurücksetzen".

## [v2.56.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.56.0) (2026-11-06)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.55.0...v2.56.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(dungeons): show where a quest's start item lies inside the dungeon (F-136, D-65)

  Steps that start with an item lying somewhere in a dungeon now list the spots where it can be found,
  what it looks like and a map button to the dungeon's entrance. The first is Crest of Lordaeron in Ruins
  of Lordaeron, which now also names who takes it back (Oran Snakewrithe in Undercity for the Horde, Lady Dena
  Kennedy for the Alliance).

## [v2.55.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.55.0) (2026-11-06)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.54.2...v2.55.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- fix(map): draw Amisia's world map pins on its own layer (D-64)

  The pins no longer hook into the world map's own pin system, which let Amisia taint the map's and the
  objective tracker's updates ("tainted by 'Amisia'", a blocked SetPropagateMouseClicks in combat).
  Pins, tooltips, clicks and menus work as before. The TOC changed: restart WoW once.

- feat(dungeons): show the whole quest path of a dungeon quest (F-135, D-63)

  A click on a dungeon quest opens its path: every pre-quest numbered in order, where and how to get it
  (quest giver with map button, an item and where it drops, an object, or inside the dungeon), where to
  hand it in once known, requirements and the objective once you have seen it, and the next step with
  "Nächsten Schritt auf der Karte". Quests that start inside a dungeon show the dungeon mark.

- data(quests): rebuild all data from the current AllTheThings Forever data (F-135)

  Dungeon quests grow from 122 in 12 dungeons to 411 in 24, among them Blackrock Depths and Spire,
  Uldaman, Dire Maul, Scholomance, Stratholme and Zul'Farrak, with longer pre-quest chains, start items
  and where they drop, and turn-in places you saw yourself. The gear data gains about 260 items and 140
  sources, the world map about 140 places (more quest givers and rare mobs).

## [v2.54.2](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.54.2) (2026-11-05)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.54.1...v2.54.2) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- fix(map): keep the game's waypoint and world map alone inside instances and in combat (D-62)

  Setting or clearing the game's waypoint or opening the world map from Amisia in a dungeon made the
  objective tracker fail with "tainted by 'Amisia'". Inside instances, in combat and during boss fights
  Amisia now only changes its own target and clears the game's waypoint once you are out.

## [v2.54.1](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.54.1) (2026-11-05)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.54.0...v2.54.1) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- fix(map): show quest givers as a plain yellow "!" (F-134)

  Quest giver pins and a quest target on the world map are now just the yellow "!" without the diamond,
  the green frame and the ring; a dungeon entrance target shows the dungeon mark without a frame.

## [v2.54.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.54.0) (2026-11-05)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.53.0...v2.54.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(dungeons): mark dungeon quests like the game and open the map where you need to go (F-134)

  The quests of a dungeon show the game's quest marks: a yellow "!" to take, a grey one for later, a
  "?" while in your log (yellow once complete), a tick when done. A click opens the world map with the
  waypoint: at the quest giver, or at the dungeon entrance once the quest is in your log.

## [v2.53.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.53.0) (2026-11-05)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.52.0...v2.53.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(members): read professions from guild notes (F-133)

  The members page shows the professions a public or officer note names, such as "Alchi 300 / Kräuter",
  for guild members without Amisia, and adds those the recipe exchange does not know; the tooltip says
  they come from the note, and the profession filter finds them.

## [v2.52.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.52.0) (2026-11-05)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.51.0...v2.52.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(feedback): send bug reports and wishes to the author in game (F-130)

  The new page "Feedback" in the tab Amisia sends a bug or a wish of up to 500 characters to the author,
  with version, game, class and level; it waits while he is offline and shows "arrived" once he has it.

## [v2.51.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.51.0) (2026-11-05)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.50.1...v2.51.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(gear): plan only with sources you can really get (F-132, D-59)

  Targets, the gear table and the level sets count quests, dungeon and raid bosses, crafting, vendors,
  PvP ranks and named rare mobs. Random world drops need the "World drops" switch (now off) and never
  bring epics; the auction house only counts for items that also have a fixed source.
- feat(gear): show name, icon and tooltip for items only the server describes (F-132)

  Items missing from the client's item table get the name and icon Amisia's scan saw and an own tooltip
  with slot, item level, stats and sources.

## [v2.50.1](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.50.1) (2026-11-05)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.50.0...v2.50.1) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(duels): delete all recorded duels (F-131)

  `/amisia duelle leeren` or the button in the duel settings asks first, then history, leaderboard and
  tournaments start over. Known classes and specs stay.
- data(scan): add 53 newly scanned items to the archive and the gear data

## [v2.50.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.50.0) (2026-11-05)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.49.2...v2.50.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(goals): add level sets to the catalog (F-129)

  The gear goals window's catalog lists six sets, levels 1-19 up to 60, each with the best item per slot
  for your spec at the top of the range. Try a whole set on the model or pick single pieces.

## [v2.49.2](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.49.2) (2026-11-05)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.49.1...v2.49.2) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- fix(goals): stop the character model flickering (F-110)

  Every item answer from the server dressed the model anew; now it only redresses when an item on the
  doll changes. Gains over 999 % show as ">999 %" instead of a cut-off number.
- fix(release): never print the CurseForge token in an error (D-58)

## [v2.49.1](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.49.1) (2026-11-04)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.49.0...v2.49.1) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- data(talents): update talents, professions and enchants for client build 1.60.1.70790

  Rogue, warrior and shaman trees changed the most, e.g. Improved Tactical Mastery now has 3 ranks.

## [v2.49.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.49.0) (2026-11-04)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.48.2...v2.49.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(release): upload the zip to CurseForge too, token only on the N100 (D-58)
- chore(release): add CurseForge project ID 1783476 to the TOC (D-58)
- refactor(data): drop third-party data: profession ranks from client tables, docks and flight masters by hand, own map pins (D-04)

## [v2.48.2](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.48.2) (2026-11-03)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.48.1...v2.48.2) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- data(data): add data for client build 1.60.1.70755 (built automatically, check green)

## [v2.48.1](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.48.1) (2026-11-03)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.48.0...v2.48.1) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- chore(data): read the new _forever_ folder in tools, _classic_beta_ only as fallback
- data(data): add data for client build 1.60.1.70707 (built automatically, check green)

## [v2.48.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.48.0) (2026-10-31)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.47.1...v2.48.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- docs(talents): spec for importing talent builds from talent calculator site links (F-127, draft)
- feat(talents): import build links from talent calculator sites (F-127)
- docs(gear): spec for enchant suggestions per slot (F-128, draft)
- feat(gear): add enchant suggestions per slot in the gear goals window and slot card (F-128)
- docs(release): mark F-127, F-128 as built in 2.48.0

## [v2.47.1](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.47.1) (2026-10-30)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.47.0...v2.47.1) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- fix(release): add separate TOCs for TBC and Era without Forever parts, TBC Anniversary loaded Gear/* despite the camelot tag (D-57)

## [v2.47.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.47.0) (2026-10-25)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.46.1...v2.47.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- docs(raid): spec F-126, raid part on TBC Anniversary and Classic Era (draft)
- docs(raid): approve spec F-126, export, trade helper and raid-check buffs off on TBC/Era, guild stays
- fix(settings): put the red reset X directly right of its field
- feat(raid): add the raid part on TBC Anniversary and Classic Era (F-126, D-57)
- docs(release): mark F-126 as built in 2.47.0

## [v2.46.1](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.46.1) (2026-10-24)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.46.0...v2.46.1) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- fix(ui): name the tabs below the main window, PanelTemplates_SelectTab failed on unnamed tabs

## [v2.46.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.46.0) (2026-10-24)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.45.0...v2.46.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- docs(gear): spec for play-style filter and right-click on the character slot (F-124, F-125, draft)
- feat(gear): add play-style filter (F-124) and right-click on the character slot (F-125)
- data(data): add data from client build 1.60.1.70532 with reputation table, new scans in the archive
- docs(release): mark F-124, F-125 as built in 2.46.0

## [v2.45.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.45.0) (2026-10-17)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.44.0...v2.45.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(talents): add two plans per class (primary/secondary, F-121), TOC with category VuloUI
- docs(gear): spec for a Raids page in the Gear tab (F-122, draft)
- feat(gear): add a Raids page in the Gear tab with all raids on every tier, size, opening day, value, own raid ID, image, bosses with loot, waypoint (F-122)
- docs(gear): spec for gear goals, catalog with set categories and item search (F-123, draft)
- feat(catalog): add gear goals catalog with set categories and search over all items (F-123)
- docs(release): mark F-121..F-123 as built in 2.45.0

## [v2.44.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.44.0) (2026-10-17)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.43.0...v2.44.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(gear): add the "why?" check naming the goals' explanation line and /amisia bis warum, open points for the game (F-115)
- feat(goals): add gear goals window with doll (character model, 17 slots, goals/equipped), list by armor/jewelry/weapons, "big window" button, /amisia bis gross, ui.goalScale, "character model" self-test (F-110)
- feat(goals): add "N/17 goals" progress bar, "armor N of 9" sections and filters All / To get / In bag / Without enchant (F-113)
- feat(goals): add slot bar with "your pick", ranking of the ten best, dungeon drops near the tier, "item link or ID" field, per-spec own pick in bis.chars[].pick (F-112, D-54)
- feat(goals): add rating head under the doll with current, delta and bar to best on tier, six biggest changes, ns.BisSummary (F-111, D-11)
- fix(goals): fix review findings: second ring keeps the displaced best item, rating pairs rings/trinkets by item, "outdated" compares against own pick, weapon try-on with hand, ui.* settings and own pick do not recompute Gear.Best
- docs(goals): rename the own-pick rule to D-55 (D-54 is the exact upgrade, F-115)
- docs(release): mark F-110..F-113 as built in 2.44.0

## [v2.43.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.43.0) (2026-10-17)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.42.0...v2.43.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- docs(release): adjust release notes, F-115 comes with 2.43 (2.42.0 was only duels) (F-115)
- docs(release): mark F-115 as built in 2.43.0

## [v2.42.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.42.0) (2026-10-17)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.41.0...v2.42.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- docs(gear): spec for the exact upgrade per spec: character sheet values, before/after model, total percent, spec in tooltip (F-115, draft)
- feat(duels): add class icon and spec (inspect), card on duel requests, record in player tooltip, streaks/nemesis/favorite opponent, time range, classes by spec (F-114, F-116..F-120)

## [v2.41.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.41.0) (2026-10-17)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.40.0...v2.41.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- fix(ui): drop the blue hover glow on the page list, search finds settings sections (also by tab), recipes and dungeons
- data(data): add data for client build 1.60.1.70450 (built automatically, check green)
- fix(site): security: roles only from account data nobody can edit themselves (migration, not yet applied), escape ledger values in HTML attributes, drop blob parts sent to GUILD
- docs(softres): spec for sharing soft-reserves, preview in the import window, class check (F-107..F-109, draft)
- docs(softres): approve spec for sharing/preview/classes, F-107..F-109 planned
- feat(softres): add class check against the raid, CSV column Raider Class, suggestions by class (F-109)
- feat(softres): add preview in the import window with item icons and findings, "in raid without reserve" box, hard reserves on top, announcement when applying in a raid (F-108)
- feat(softres): share soft-reserves with the raid, SV/SQ/SR, officers with their own list only, newest wins, offer for officers (F-107, D-53)
- docs(goals): spec for gear goals window: doll, rating head, slot bar with own pick, progress/filter (F-110..F-113, draft)
- docs(goals): approve spec for gear goals, F-110..F-113 planned
- fix(softres): fix review findings: empty apply replaces nothing, delete/re-import arrive despite gap, officer keeps own list, old offer expires, invalid lists not announced, reply only for the current list, English announcement without German, button only on offer
- docs(release): mark F-107..F-109 as built in 2.41.0

## [v2.40.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.40.0) (2026-10-16)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.39.6...v2.40.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- docs(duels): spec for duels: history, ranking, classes from the system message, class lookup by click (F-106, draft)
- feat(duels): add PvP tab with history, ranking and classes, class lookup by click, tournament mode (F-106, D-52)
- docs(release): mark F-106 as built in 2.40.0

## [v2.39.6](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.39.6) (2026-10-16)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.39.5...v2.39.6) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- fix(map): polish ship and zeppelin symbols: smooth edge, soft shadow, zeppelin without spikes and box shadow
- docs(release): note F-105 in 2.39.6 (polished symbols) (F-105)

## [v2.39.5](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.39.5) (2026-10-16)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.39.4...v2.39.5) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- fix(map): remove the detached light pieces right of and below the boot, with rim, from the flight master symbol
- feat(data): export client tables automatically: a Windows task exports after each patch, the N100 builds and checks on auto/data-<build>, publish only on request (D-51)
- fix(map): smooth the flight master symbol with soft edges instead of jags
- fix(map): redraw the flight master symbol as one closed shape with even dark rim, soft shadow, no blotches

## [v2.39.4](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.39.4) (2026-10-16)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.39.3...v2.39.4) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- data(data): add data for client build 1.60.1.70425: talent trees (priest, paladin, warrior, hunter and others), professions, raid check, BiS

## [v2.39.3](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.39.3) (2026-10-16)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.39.2...v2.39.3) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- fix(map): remove the white stripe right of the boot from the flight master symbol

## [v2.39.2](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.39.2) (2026-10-16)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.39.1...v2.39.2) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- docs(release): note F-105 in 2.39.1 (correct symbols) (F-105)
- fix(map): leave out own flight masters and entrances only where game pins are on the map (Forever has C_TaxiMap and providers but shows none), release says when WoW must restart

## [v2.39.1](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.39.1) (2026-10-16)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.39.0...v2.39.1) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(map): use proper symbols for map places: winged boot for flight masters, ship in faction colour, zeppelin from above (Media/Icons/place_*.tga), no frame

## [v2.39.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.39.0) (2026-10-16)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.38.0...v2.39.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- docs(map): spec for places on the world map: entrances, flight masters, zeppelins, ships (F-105, draft)
- docs(map): approve spec for places on the map (proposals 1-5), sources: third-party data, client table Map, AllTheThings, F-105 planned
- data(data): rebuild data (build.py data): newer third-party data version, scan archive with SavedVariables of 2026-10-16
- feat(map): add places on the world map: entrances, flight masters, zeppelins and ships, entrances remembered on entering (F-105)
- fix(map): make no remembered entry after a group finder teleport (IsInLFGDungeon)
- docs(map): mark F-105 as built in 2.39.0, third-party data also for map places (F-105, D-04)

## [v2.38.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.38.0) (2026-10-16)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.37.2...v2.38.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- docs(guild): spec for a Members page in the Guild tab (draft)
- docs(guild): approve Members spec (all views, guild members only, alts as own row), F-104 planned
- feat(guild): add Members page in the Guild tab: name, level, rank, location, last online, professions with skill, filters class/profession/online (F-104)
- fix(guild): use two wide fields for main professions (full names) and three for secondary, show only the largest unit in "last seen", both in tooltip
- fix(guild): fix review findings: Cr.Own always returns the same empty list (professions cache), "just offline" under one hour, level as number so rank matches, saved class/profession without hits falls back to all, rank name as text
- docs(release): mark F-104 as built in 2.38.0

## [v2.37.2](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.37.2) (2026-10-15)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.37.1...v2.37.2) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- fix(ui): remove the black background under the Amisia icon in the window portrait and minimap button (icon with transparent background)
- feat(ui): use the new Amisia icon (A with ribbon, from the user) everywhere: window portraits, addon list and compartment, minimap button, make_icons.py builds it from tools/art/Amisia.png, drop Cinzel font
- data(gear): use third-party data 5.6.0 as gear data source: build_gear reads the new format (dungeon registry, recipe lists) isolated, only items with Forever ID or known to the client, download into ~/addons/_cache, GearData 5520 -> 6036 items

## [v2.37.1](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.37.1) (2026-10-15)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.37.0...v2.37.1) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(ui): use the Amisia icon (Amisia.tga) for the minimap button and addon compartment instead of a separate minimap icon, remove Minimap.tga

## [v2.37.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.37.0) (2026-10-14)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.36.0...v2.37.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(settings): collapse and expand settings in the page list: click the open group to fold its sections, click Settings to fold all groups (like the auction house)

## [v2.36.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.36.0) (2026-10-14)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.35.1...v2.36.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- perf(raid): cache the score for raids (122 -> 3 ms, 6 ms after a change), recompute the keeper's points and prio state only after changes (5 s tick 126 -> 2.6 ms), cache old raids' export fingerprint up to 60 s while unchanged (230 -> 0.2 ms)
- perf(raid): read the group list once per frame instead of per name (roll row 70 -> 2.3 ms, raiders with Amisia 33 -> 0.9 ms), count plus-one once per frame (40 names 11 -> 0.5 ms), hello without rebuilding the version list (3.6 -> 0.2 ms), forget silent senders after 10 minutes
- perf(gear): compute BiS only on rating change (bag change 54 -> 5 ms, weapon skill 62 -> 0 ms), no warm-up in combat, Gear.Best with set index (51 -> 31 ms), skill lines fire only on real change, ore hover builds no gear data (18.5 ms/5.4 MB -> 0.1 ms), drop index only on send (20 -> 0.1 ms), LinkSuffix in one pattern and known bag links skipped, DropsMigrate without new tables (39 ms/2.3 MB -> 30 ms/64 KB), bound the crafter tooltip cache
- perf(ui): cache statistics (88 -> 0.7 ms per update, rebuild 86 -> 27 ms), gear window recomputes on open only after changes (166 -> 3 ms), raid check reads once after a group wave (30 x 5 ms -> 1), window draws data changes once in the next frame
- fix(perf): fix review findings: refresh statistics after one minute instead of one hour (raids over the 4-week limit), prepare BiS goals in combat again as before

## [v2.35.1](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.35.1) (2026-10-13)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.35.0...v2.35.1) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- fix(settings): fix 2.35 review findings: complete candidate list with secret names, reset section only for visible settings, single-word soft-reserve name without realm, export reminder at most every 10 minutes, settings checklist

## [v2.35.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.35.0) (2026-10-13)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.34.0...v2.35.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- perf(raid): version list without group list per entry (23 -> 0.5 ms), cache old raids' export state for 5 s (32 -> 0.2 ms), lineup builds the player list once per frame

## [v2.34.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.34.0) (2026-10-13)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.33.0...v2.34.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(raid): remind about unexported raids at the end of recording and when keeping (record.exportWarn)

## [v2.33.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.33.0) (2026-10-13)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.32.0...v2.33.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- docs(dungeons): spec for Dungeons page and settings by tabs (approved, with reset)
- feat(settings): split settings by tabs: sections in the page list, "Settings" button per page with "Back to", reset per section and for all (D-49)
- feat(dungeons): move the dungeon planner from the Gear page to its own page in the Gear tab (F-102, part A)

## [v2.32.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.32.0) (2026-10-13)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.31.0...v2.32.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(settings): version the saved data: AmisiaDB.schema and ordered migrations (D-48), guard for window state
- docs(settings): spec for settings in logical sections (approved)
- refactor(settings): group settings in logical sections: who needs this?, bench, Discord text, guild wishes; plus-one into roll rounds, gear into gear and wishes; migration step 2

## [v2.31.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.31.0) (2026-10-13)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.30.1...v2.31.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- docs(release): add checks for the 2.30.1 fixes to FEATURES
- feat(settings): add /amisia einstellungen <section> to open the named section, otherwise the search for it
- feat(settings): add help text for every setting (62 new, German and English), test keeps it that way

## [v2.30.1](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.30.1) (2026-10-13)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.30.0...v2.30.1) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- docs(settings): spec for Dungeons page and settings by tabs with gear icon (draft)
- fix(loot): start rounds on alt-click in the loot window only in the officer view, award dialog checks secret candidates
- fix(awards): read the award type from the roll also for the short chat name (MS instead of -)
- fix(raid): find the calendar event without ID again by time and title when re-reading the lineup
- fix(raid): do not silently delete unexported raids when cleaning up in the officer view
- fix(collect): save an item once per session in the item collector instead of on every bag update
- fix(softres): keep a hyphenated surname in the soft-reserve code, only drop the realm
- fix(ui): treat Ä, Ö, Ü like ä, ö, ü in search and settings search
- fix(gear): use the same threshold as the tooltip for the upgrade dot in the gear table
- test(raid): add tests for the fixes from the 13.10. review

## [v2.30.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.30.0) (2026-10-13)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.29.0...v2.30.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(comms): add game text templates as patterns for system messages in Core/Chat.lua (ns.TemplatePattern, ns.TemplateName)
- feat(raid): add lineup: invite all, sort groups, "inv" by whisper and assist helper for officers (F-084)
- docs(raid): mark F-084 as built (2.30.0), F-100 checkable alone, decision to build parts C and D (F-084, F-100)
- fix(raid): sort automatically even when the open invite view sees the join first
- fix(raid): assist helper only for the exact guild list name, never by first name alone
- fix(raid): invite on whisper only for a guild member under the exact name, invited in the guild list spelling
- fix(raid): repeat the same group sort step only after 3 seconds
- fix(raid): report "group is full" only within 3 seconds of Amisia's last invite
- fix(raid): invite only for tonight, other nights show "Only for tonight"
- fix(raid): invite on whisper checks limits after the guild check, never converts to a raid, not in five-player instances

## [v2.29.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.29.0) (2026-10-13)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.28.0...v2.29.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- docs(raid): approve the raid-check spec with the proposals
- feat(raid): add raid-check data: tools/build_raidcheck.py (flasks, elixirs, food, class buffs from client tables)
- refactor(raid): share readers for raid check and group check (Raid/RaidCheckRead.lua)
- feat(raid): add raid check and raid IDs: XQ/XA, IV/IQ, own report, AmisiaDB.raidcheck
- docs(raid): add in-game group probe results (invites work from timers, auras readable out of combat)
- feat(raid): add Raid-Check page (buffs & consumables, gear, raid IDs) and ID mark in the lineup
- docs(raid): mark D-46, F-098 and F-099 as built (2.29.0): raid check and raid IDs (D-46, F-098, F-099)
- fix(raid): send IV under the guild list spelling, 12 characters per sender also on apply
- fix(raid): do not count utility elixirs (water breathing, detect, water walking, languages) as supplied
- fix(raid): ready check only from the guild, one redraw per burst, name index
- feat(ui): style the page list like the auction house category list (2.29.0)

## [v2.28.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.28.0) (2026-10-12)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.27.4...v2.28.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- docs(raid): spec for raid lineup: user wants parts C and D now, plus invite on whisper and auto assist
- feat(raid): add group check /amisia selbsttest gruppe (F-097)
- docs(raid): spec for raid check (buffs and consumables, gear) and raid IDs, not approved yet

## [v2.27.4](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.27.4) (2026-10-12)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.27.3...v2.27.4) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- fix(softres): read the slot link of the loot window's SR mark through ns.Plain, a secret link gets no mark
- fix(ui): start another view or raid at the top of its list on the soft-reserve and awards pages
- fix(loot): pass the loot window's slot links through ns.Plain before ns.ItemID in roll frame and award dialog
- feat(ui): add small actions: show in calendar, remove points, clear loot prio with one click
- fix(softres): move the code's note, class and softres plus-one with a name fix of the loaded list
- fix(loot): ask before /amisia prio löschen deletes the whole priority list
- chore(locale): note that 'Löschen##Knopf' was already translated
- fix(comms): remember only a whole revision of a keeper's snapshot (a malformed one broke the next request)

## [v2.27.3](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.27.3) (2026-10-12)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.27.2...v2.27.3) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- fix(scan): ask an ID that is twice in the retry or list queue once, so the scan and its ticker end
- fix(scan): skip secret chat text, unit names and GUIDs in the collector instead of reading them into source notes
- fix(awards): skip secret names and GUIDs of the loot window and roster in core, awards and rolls, never use them as keys or compare them
- fix(ui): fix audit leftovers: overview card slot starts without the previous line limit, material ID must be a whole positive number, loot method read through ns.Plain
- refactor(raid): remove dead code: unused collector readers, crafter/map/talent/profession accessors, handover helper hook, bank log money kinds, gear kind names, group roll choice list
- refactor(raid): remove 35 export lines nothing reads, keep the locals
- refactor(ui): remove unused theme tokens SCROLLBAR_W, PAGE_H and RAIDCAL.INSET_GAP, keep their numbers in comments
- fix(calendar): make today's gold frame on the calendar page 2 px thick as the token says, not 1 px
- refactor(comms): remove dead events QUESTXP_CHANGED, BANK_NEEDS_CHANGED and HANDOVER, they had no listener
- fix(comms): translate the reason "Daten zu groß." like every other reason of CommSendBlob
- fix(raid): open the standings view with /amisia punkte, not the last used view

## [v2.27.2](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.27.2) (2026-10-11)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.27.1...v2.27.2) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- chore(site): add an interim Pages workflow that stages the site from the root so the Pages source can switch to GitHub Actions
- refactor(release): move the addon to Amisia/, tests to tests/, the site to Amisia-Website/ (move only)
- chore(release): follow the move in paths (tools, tests, docs, luacheck, the site's zip link, Pages workflow stages Amisia-Website/)
- chore(release): remove tools/sync_addon.ps1, the PC only receives the release folder through Syncthing
- chore(release): remove Amisia/.stignore, the addon folder is no longer a Syncthing folder
- chore(site): remove .nojekyll, Pages deploys through the pages workflow
- chore(data): remove tools/build_bossnames.py, data/bossnames.js only serves the frozen read-only TBC archive
- chore(release): drop the .gitignore lines of tools/cache and the old Syncthing marker
- data(scan): join the newest scan and collector notes from the SavedVariables

## [v2.27.1](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.27.1) (2026-10-11)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.27.0...v2.27.1) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- fix(calendar): show group heads as flat one-line bars in the small font, keep the day's inset clear of 'Today', put a date's time and title on one line each in the cells

## [v2.27.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.27.0) (2026-10-11)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.26.0...v2.27.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- docs(ui): spec for tabs at the bottom of the main window, search field top left, month calendar as a tab (approved 2026-10-11)
- feat(ui): put tabs at the bottom of the main window instead of section bars, search field top left, calendar page as a month sheet (2.27.0, not released)
- fix(ui): set tabPadding and minTabWidth on the window so the tab template measures the same size when shown
- fix(calendar): show attendees per event instead of per night, no background reading while the window is closed (2.27.0, not released)
- fix(ui): clear the search on a tab click, fall back to the overview without overwriting the remembered page (2.27.0, not released)

## [v2.26.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.26.0) (2026-10-11)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.25.2...v2.26.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- docs(softres): note the soft-reserve site CSV fix in FEATURES
- docs(softres): spec for soft-reserve site and another addon compatibility: in-game checks, build A2 + B1 + B4 with the proposed answers
- feat(softres): read the soft-reserve site code, rounds from another addon open the roll window, English announcement (2.26.0, not released)
- fix(softres): fix review findings for the soft-reserve code and rounds: no freeze from a pasted code, bounded unpacking, no cut English line (2.26.0, not released)

## [v2.25.2](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.25.2) (2026-10-11)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.25.1...v2.25.2) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- fix(softres): read the soft-reserve site's CSV of today (name in 'Raider Name', it gave 0 reservations), spec for soft-reserve site and another addon compatibility (not approved yet)
- fix(softres): read the soft-reserve site's CSV of today (name in 'Raider Name', it gave 0 reservations), spec for soft-reserve site and another addon compatibility (not approved yet)
- chore(softres): revert the soft-reserve site CSV commit

## [v2.25.1](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.25.1) (2026-10-11)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.25.0...v2.25.1) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- docs(calendar): add calendar write probe results from the game (all writes work from timers), F-089 checked (F-089)
- fix(professions): sort the recipe list by learn rank, then yellow, then name
- fix(calendar): put the raid calendar above the main window in the style of the professions window, read state correct again
- test(professions): follow the recipe order by learn rank in tests, English 'signed off' for abgemeldet everywhere

## [v2.25.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.25.0) (2026-10-11)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.24.0...v2.25.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- docs(calendar): spec for H3, part I (raid calendar window visible to the guild), polish, user decisions 2026-10-11
- fix(raid): make the raid sign-up window more compact, card shows "Change" when a sign-up exists
- feat(calendar): add raid calendar window for the whole guild showing who comes to the dates (part I, D-43)
- feat(calendar): add calendar write probe /amisia selbsttest kalender schreiben (checks 23 to 25)
- feat(calendar): make the raid sign-up also write into the game calendar (part H3)
- fix(calendar): never write the calendar entry and write probe for the wrong event or next to a check
- fix(calendar): keep the officer's state in the game calendar, no entry on past days

## [v2.24.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.24.0) (2026-10-10)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.23.1...v2.24.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- docs(calendar): add in-game results of calendar checks 17-20 to the spec
- feat(calendar): read the calendar (F-086) and sign up in Amisia (F-087) in the raid lineup (D-42)
- fix(raid): fix the check after the sign-up build (G/H), add /amisia abmelden
- fix(raid): make the sign-up note hint say what is true: the guild can read it (AN goes to the guild channel)

## [v2.23.1](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.23.1) (2026-10-10)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.23.0...v2.23.1) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- fix(calendar): use any guild event in the calendar probe when none is of the raid type (that type needs a raid instance Forever may not offer yet), spec note

## [v2.23.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.23.0) (2026-10-10)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.22.0...v2.23.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- docs(raid): spec for raid lineup part G (calendar) and H (sign-up in Amisia), not approved yet
- docs(raid): approve raid lineup spec G/H
- feat(calendar): add calendar check /amisia selbsttest kalender doing checks 17 to 20 itself (F-085)

## [v2.22.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.22.0) (2026-10-10)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.21.0...v2.22.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(raid): add raid lineup "Aufstellung" (parts A, B and E): paste the sign-up list, match against the guild, plan the groups, bench through ns.BenchAdd
- data(scan): join the user's gear scan of build 70338 (melee computed stats proven again: Rage of the Storm 35.61 DPS at 3.3 s)

## [v2.21.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.21.0) (2026-10-10)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.20.0...v2.21.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- docs(raid): approve the raid lineup spec (sign-up paste, planner, invite, sort, bench) by the user
- data(data): take the MageScrollData header from client tables 1.60.1.70338 (content unchanged)
- feat(settings): add setup assistant "Amisia einrichten": six steps over the existing settings, one-time offer for officers
- data(data): add data from build 1.60.1.70338 (warrior talents reworked, 29 talents changed, weapons re-timed), the pick test takes computed stats without damage while old scans fail the melee check

## [v2.20.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.20.0) (2026-10-10)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.19.0...v2.20.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(talents): add big talent window "Talentrechner": one builder for page and window, page trees clear of the borders

## [v2.19.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.19.0) (2026-10-10)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.18.0...v2.19.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(talents): use the classic three-tree look: centred head, square framed icons, rank plate, gold lines

## [v2.18.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.18.0) (2026-10-09)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.17.2...v2.18.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- docs(raid): note in-game check 9 (trade time constants) done
- feat(raid): add trade helper with awarded items in own bags, "still to hand over", insert by click (F-076, F-080, D-39)
- fix(raid): fix trade helper review: two items per click in their own slots, a refused pick-up not counted, one of a stack, same-item copies after the trade
- fix(raid): treat an unreadable handover tooltip as not 'run out' (only a read tooltip without the trade line is)

## [v2.17.2](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.17.2) (2026-10-09)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.17.1...v2.17.2) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- fix(ui): put roll window content 18 px from the frame's edges (12 still touched the border), 340 wide

## [v2.17.1](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.17.1) (2026-10-09)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.17.0...v2.17.1) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- fix(ui): put roll window content 12 px from the frame's edges (T.WINDOW_PAD, 8 lay under the border in the game), window 330 wide, test round lasts the roll time setting

## [v2.17.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.17.0) (2026-10-09)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.16.0...v2.17.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(awards): propose exactly one matching candidate also in the award dialog and roll window (ns.LootCandidate, shared with the loot rules)
- feat(loot): add roll window for raiders: round of the loot lead with main spec, off spec, pass, bid or need/greed, winner at the end (WS/WE/WA)
- fix(loot): fix roll window review: answers count with realm suffix, foreign rolls and round ends with the same first name do not count, held round expires after 5 s, bid stands
- fix(awards): write nothing for an unclear candidate name in the award dialog (the game's master loot menu gives it and the hook records it), so no second award

## [v2.16.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.16.0) (2026-10-09)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.15.0...v2.16.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- docs(loot): approve the loot night spec: trade helper for exceptions only (D-27 note), loot rules automatic by default, no second account (D-27)
- feat(loot): add loot rules: master looter hands out small loot by rules, automatic or one click, shared between officers (MR/MQ)
- fix(loot): fix loot rules review: unclear names never get loot, chat line names only what arrived, announcement leaves out what a rule hands out

## [v2.15.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.15.0) (2026-10-08)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.14.0...v2.15.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(awards): add award history in the tooltip (who got an item: newest three, "+N more", bank/disenchant, alt with main, deleted and undone awards left out) and what a roller got in the roll window row tooltip (last 4 weeks, MS/OS/SR, latest item), one lazy index dropped on DATA_CHANGED/ALTS/RECORDING or a new raid list (D-36, F-073)
- docs(loot): spec for a faster loot night (loot rules, roll window for raiders, trade helper), waiting for the user's ok

## [v2.14.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.14.0) (2026-10-08)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.13.3...v2.14.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(settings): add view switch in the head and /amisia ansicht, add a search on the settings page (label, tip, choices, section name, a new search starts at the top)

## [v2.13.3](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.13.3) (2026-10-08)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.13.2...v2.13.3) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- fix(ui): pull side tab icons 4 px into the tab, sharp dice (INV_Misc_Dice_01), put back the clicked settings row when the client takes the new scroll range, make the stub's textures read their points

## [v2.13.2](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.13.2) (2026-10-08)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.13.1...v2.13.2) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- fix(settings): label the data sizes in /amisia speicher as measured when built, garbage included, F-071 checked in game (F-071)
- fix(settings): keep the changed settings row in place on screen when sections come or go above it (view, expert mode), the stub's GetPoint reads the points set

## [v2.13.1](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.13.1) (2026-10-08)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.13.0...v2.13.1) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- refactor(scan): add build_scan.run_sv that runs the text of any SavedVariables file in the sandbox and returns its globals, load_sv uses it for AmisiaDB
- docs(docs): add docs/FEATURES.md with 70 features, build.py testlist, tested F-xxx and errors, release prints the test list and warns about game errors
- docs(docs): add specs before larger features (docs/specs README and TEMPLATE), D-35, contract test that every spec has the template headings (D-35)
- feat(scan): extend /amisia speicher: memory before and after a full collection, built data, saved scan (F-071), F-054 checked in game (Amisia.lua 2.3 MB -> 15 KB), F-043 back to built (F-071, F-054, F-043)

## [v2.13.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.13.0) (2026-10-08)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.12.0...v2.13.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- chore(data): turn off the icon lookup from a data site by default in build_scan (opt-in flag to ask), update D-03 (D-03)
- chore(data): remove fill_quality.py, Forever takes quality from the scan and ItemSparse, one less scripted data-site fetch
- refactor(scan): hand items and collector notes in id order from build_scan.collect so builds no longer depend on SavedVariables order
- feat(scan): add scan archive on the N100 and trim in game: tools/build_scan_archive.py keeps every scanned item line, note and suffix in tools/scan_archive.json and writes the marker Data/ScanDone.lua, Collect/ScanTrim.lua trims 8 s after login, setting tools.scanAutotrim, /amisia scan aufräumen (D-34)
- chore(tools): add load_cost.py showing what every TOC file holds after loading, with --files, --locale and --sv
- perf(gear): keep GearWeights.lua as text until the first score (lazy GEAR_WEIGHTS), Gear.Available asks ns.HasData, addon load in the stub 6.36 -> 5.96 MB
- perf(scan): move what is left of scan.items and scan.sources into new tables in ScanTrim so memory comes back in the same session
- perf(data): strip needless blanks from lazy data texts (lua_data.compact), every lazy file rebuilt with the same tables, texts at login 1.72 -> 1.41 MB
- docs(scan): note in the README what the trimmed SavedVariables weigh (6 KB instead of 2.4 MB)

## [v2.12.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.12.0) (2026-10-08)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.11.0...v2.12.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- refactor(ui): add the page scaffold W.Page (bands, head, column heads, list, detail, empty state, bottom row, footer) with sizes from ns.Theme.LAYOUT, grid layout rule checks it
- refactor(ui): move Rolls to W.Page: head with running round and roll window, column head, list to the footer (18 rows), empty state, alt-click hint in the footer
- docs(release): name MageScrollData.lua (AllTheThings data) in the licence file, licence test also detects "Generated by", build_gear.py without a data site URL
- refactor(ui): move Export to W.Page: buttons and state in the head, purpose as hint line, text to the footer
- docs(docs): add docs/ARCHITECTURE.md and docs/DECISIONS.md, tools/tests/test_contracts.py keeps both against the code, CLAUDE.md points to them
- refactor(ui): move Raids to W.Page: count, select all and delete in the head, column heads, empty state, details to page end
- refactor(ui): move Scrolls to W.Page: view, count and rank in the head, list and detail inset from the scaffold (18 rows), footer, neutral data line, page now in the snapshots
- refactor(ui): move Professions to W.Page: profession, search and rank in the head, filters with count in the second band, list and detail inset, empty state, footer
- refactor(ui): move Quests to W.Page: zone and search in the head, chips and count as bands, column heads and cells from the scaffold, 14 rows, empty state with title
- refactor(ui): move Map to W.Page: zone, switches and world map in the head, count as row, target with delete as band, column heads, 13 rows, hidden ones as bottom row, empty state with title
- refactor(ui): move Statistics to W.Page: view and range in the head, class/role/count as band, sortable column heads, empty state, hint in the footer, details and hall of fame above the footer
- refactor(ui): move Points to W.Page: views in the head, system row, column heads and cells, correction/import as bottom row, booking state in the footer, empty state at content start
- refactor(ui): move Soft-Reserves to W.Page: list with import/delete in the head, check as row, views with remind/post as band, column heads, 16 rows, empty state without list, hint in the footer
- refactor(ui): move Raid Log to W.Page: raid and buttons in the head, count, views as band; history, bench, rolls and Discord as views of the scaffold, bench empty state, Discord text to the footer
- refactor(ui): move Awards to W.Page: officer and raider halves as views with their own head, count and sync as row, column heads and cells, empty states in all three lists, hints in the footer, footer frame named footFrame, head also in views
- refactor(ui): move Guild Bank to W.Page: views in the head, stock/needs/log/text as views of the scaffold, log with column heads (18 rows), pledges head as column head, chat text to the footer, list-row buttons ROW_BUTTON_H high
- refactor(ui): move Tools to W.Page: scan buttons in the head, state and hint as two-line rows, drop data as view with section band ("header" band), share/site as band, list to the footer, site hint in the footer
- refactor(ui): move About and Commands to W.Page: version and self-test in the head, description and newer version as rows, ask raid/guild as band, column heads in head font (was grey), empty state above the list
- refactor(ui): move Overview to W.Page: cards from the page start, empty state with title and sentence instead of a grey line
- refactor(ui): move Settings to W.Page (the sections fill the page, no head)
- refactor(ui): move Talents to W.Page: class, level and talented points in the head, trees below the head band, load/reset/code as bottom row (code fills the rest), text spacing from the edge
- refactor(ui): move Gear to W.Page: spec, views and table in the head, count with reset as row, sources with weapon plan as band; goals, here, dungeons, wishlist, guild and simulation as views, column heads 18 high instead of 14, dungeon planner with 5 dungeons
- test(ui): make the grid layout rule require W.Page on every page, README and rule list describe the scaffold
- fix(ui): fix "1 Raid" instead of "1 Raids" in the count text (the German key was plural)
- fix(ui): use straight quotes for the BiS pick source (curly ones may have no glyph in the game font), font guard covers „“”

## [v2.11.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.11.0) (2026-10-08)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.10.1...v2.11.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- docs(points): design for DKP and EPGP as alternative to rolling
- feat(points): add DKP and EPGP to the addon (models, standings, bids, need by PR, award costs)
- feat(points): share points in the raid: KV/KQ/KS from the keeper, KC for the cost of an award
- feat(points): add Points page: ranking, history, correction with reason, paste the website block
- feat(site): add Points tab, import of points from the addon, block for the addon
- perf(points): let the keeper compute the shared state once, throttle confirmation of hidden bids, manual bids up to six digits
- feat(points): merge DKP/EPGP, the page list lowers its rows when more pages are shown (19 for a mage officer in the expert view)
- fix(points): find the bid of an earlier item's round, won bids reduce the free balance, roll raids get no points afterwards
- fix(site): import points per raid key and time, backup keeps points, viewers get only their own balances

## [v2.10.1](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.10.1) (2026-10-08)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.10.0...v2.10.1) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- data(data): rebuild data from AllTheThings e9311f6 and the latest scan and collector records

## [v2.10.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.10.0) (2026-10-08)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.9.6...v2.10.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(loot): add loot council: per item an officers' note and priority list (#AMISIA-LC from the site, in-game edit dialog, LC export lines) shown in roll window, award dialog, tooltip, roll frames and optionally the loot announcement, shared by the keeper (LV/LQ/LC, verified officers only)
- feat(site): add Loot Council tab (prio and note per item, kept per game in state.lootPrio), #AMISIA-LC block in Copy for the addon, addon LC lines taken over on the Import tab, backups keep it
- feat(loot): add group loot roll log: Need/Greed/Disenchant/Pass, numbers and winner per item, in the raid or a dungeon run
- feat(professions): add guild crafters: share known recipes in the guild (PV/PQ/PW, PK blob), "Made by" on the professions page, a "Guild" filter, ask-by-whisper button and a "Can craft" tooltip line
- feat(raid): add Statistics page: items won (MS/OS/SR), items per raid, attendance since first seen, bosses seen, streak and items per week per player over all characters, ranges 4 weeks/phase/all, class and role filters, sortable columns, hall of fame, raiders see their own row, page list rows 20 high so 18 pages fit
- feat(site): add Stats tab with loot and attendance per player (alts counted for their main, bench rule of the Attendance tab), ranges, class and role filters, sortable columns, items per week, hall of fame
- data(data): update att_data: library books folder, quest givers of a header (aqd/hqd), quest maps, newer map constants
- feat(bank): add guild bank needs with pledges and the guild bank log
- chore(locale): add Item/Items only once (the stats page and the raid area both added them)
- test(site): make the site prio test use today's date for the copy block, not a fixed day
- feat(professions): add Mage scrolls: Comprehension page for mages (/amisia schriftrollen) from client tables and AllTheThings
- fix(professions): let a crafter sender speak only of itself and its known alts, lists keep only indexed spells, caps per sender and for the store
- fix(bank): allow pledges only for needed materials, capped per name, a cleared list reaches who missed it, no revision from the future
- fix(loot): make the order field of the loot prio dialog hold a whole list, the test stub enforces SetMaxLetters
- fix(bank): skip bank log rows older than bank.logDays instead of counting them as new on every open
- fix(loot): refuse loot prio times more than a day ahead (paste, site import), LC list goes at the lowest priority, site prio names count bytes, a damaged prio renders
- fix(loot): keep one row per player in the group roll log whatever spelling a roll line uses
- chore(settings): make the guild bank log functions optional in the self-test, drop the unused ns.LootAnnounceAgain

## [v2.9.6](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.9.6) (2026-10-07)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.9.5...v2.9.6) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- fix(collect): treat a vendor price of 0 as unknown so a real price replaces it (prices recorded while the merchant API was missing stayed 0 forever)

## [v2.9.5](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.9.5) (2026-10-07)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.9.4...v2.9.5) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- fix(talents): use 36 px icons, frame 2 px outside the icon so its dark rim no longer covers it, less icon crop

## [v2.9.4](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.9.4) (2026-10-07)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.9.3...v2.9.4) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- fix(map): keep the main window open under the world map and bring it back on top when the map closes

## [v2.9.3](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.9.3) (2026-10-07)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.9.2...v2.9.3) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- fix(talents): use 34 px icons again, action bar's thin rounded frame tinted by state

## [v2.9.2](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.9.2) (2026-10-07)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.9.1...v2.9.2) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- fix(quests): take quest giver waypoints and pins only from own observations: dungeon guide uses CollectQuestOwnStart, profession places from the guild without waypoint, tests first
- fix(talents): draw nodes as the client does: 30 px icon with the action bar's rounded mask, state frame at 1.25x, room between neighbouring frames
- perf(comms): speed up source exchange: 192 KB per session, half share per asker, 120 parts per 10 minutes, one blob per 30 s, 90 requests per hour, announcements valid one hour, flow test with new expectations and two senders per hour, numbers in the spec
- fix(collect): read merchants in the collector via C_MerchantFrame.GetItemInfo (Forever 1.60.1.70245 dropped GetMerchantItemInfo), old function as fallback, self-test: GetMerchantItemInfo optional, C_MerchantFrame.GetItemInfo required
- fix(professions): request spell data for the storage description (C_Spell.RequestLoadSpellData), fill in on SPELL_DATA_LOAD_RESULT, "Description loading ..." until then, self-test reports "not loaded yet" as VALUE not MISSING, add SPELL_DATA_LOAD_RESULT to the event list

## [v2.9.1](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.9.1) (2026-10-07)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.9.0...v2.9.1) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- data(data): rebuild data from the user's own client export (talents identical, profession reagents from SpellReagents), build_talents accepts the export's Index column

## [v2.9.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.9.0) (2026-10-07)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.8.0...v2.9.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- feat(locale): add locales: ns.L with German keys and English for every other client locale (Locales/Locale.lua, enUS parts), ns.Num/FmtDay/FmtDate, N_ marker, English slash words (def.en, collisions are errors), run.py --locale enUS, tools/l10n.py scan/check, layout rules in deDE and enUS, build.py check runs both
- chore(locale): add WIP l10n: partial English routing gathered from the area worktrees (SelfTest.lua mid-edit, not yet green)
- feat(locale): translate core, window, settings, overview, export, bank, tools, about and the self-test into English
- feat(locale): translate the raid area into English (awards, rolls, soft-reserves, raid log, bench, sync, announcements and chat in the sender's language)
- feat(locale): translate gear, BiS, dungeons, map, quests, professions, talents and the collector into English
- fix(locale): make the GuildWishes delete button use the button key, add README section on languages and CLAUDE.md note

## [v2.8.0](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.8.0) (2026-10-07)

[Full Changelog](https://github.com/amisia-loot/amisia-loot.github.io/compare/v2.7.1...v2.8.0) [Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- test(ui): add UI snapshots and layout rules: the stub keeps the frame tree, GetStringWidth estimates per character and font, uidump.lua hands the tree over as JSON, ui_scene.lua is the world the shots show, tools/ui_layout.py solves anchors, checks bounds, overlap, text fit, minimum widths, atlases and the page list, draws PNGs and compares layout boxes
- refactor(ui): add UI/Theme.lua with the design tokens in one table (sizes, gaps, heights, padding, insets, fonts, colours, atlas allow-list), layout helpers W.Row, W.Column, W.Grid and W.FitChip, every page and window lays out exactly as before
- fix(ui): fix layout problems the rules found: overlapping Warum?/Simulation buttons, "Aus" and weapon plan picker widths, talent rank text sticking out of the page, Merchant's Favor hint cut off, roll window "Vergeben" and MS chip, award dialog chips, gear window source chips sized with W.FitChip, snapshot text on its baseline
- feat(release): add build.py check running the layout rules of every page and window, snapshots draws them into PNGs with index.html (--out, --compare, --scale, --mono), tests for each rule, README and CLAUDE.md on ui_layout.py and the theme
- perf(data): load GearData, MapData, QuestData, ProfessionData and TalentData lazily as one long string through ns.LazyData (tools/lua_data.py lazy()), ns.Data builds on first use, ns.HasData and ns.DataSize answer without building, addon load in the stub 98 ms/8.3 MB -> 59 ms/5.7 MB, nothing built at login
- fix(ui): end a list cell wider than its column in an ellipsis in snapshots where the client cuts it

## [v2.7.1](https://github.com/amisia-loot/amisia-loot.github.io/releases/tag/v2.7.1) (2026-10-07)

[Previous Releases](https://github.com/amisia-loot/amisia-loot.github.io/releases)

- refactor(release): move the addon into folders Core/, Raid/, Gear/, Collect/, Data/, UI/ and UI/Pages/ (git mv, TOC order unchanged), build scripts, tests, syntax.cjs and the LICENSES head on the new paths
- refactor(release): keep the version only in the TOC, Core reads ## Version through C_AddOns.GetAddOnMetadata (fallback GetAddOnMetadata), the test stub answers from the TOC
- chore(release): add .luacheckrc (lua51, client globals) and fix its findings without behaviour change: rename helpers shadowed by locals, remove unused locals, captures and dead Drops report()
- feat(release): add tools/build.py as one entry point: data (builds in order), check (syntax, addon and tool tests, UTF-8, TOC against the folder, luacheck) and release (clean tree, TOC version, check, zip, CHANGELOG.md, commit, push, release_addon.sh, undone on failure), tests with a temporary repository, README and CLAUDE.md
- chore(release): add GitHub Actions check.yml running tools/build.py check on push and pull request, deploys nothing, Pages unchanged
