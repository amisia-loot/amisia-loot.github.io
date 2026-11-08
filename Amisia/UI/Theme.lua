-- Amisia's design tokens: the sizes, gaps, fonts, colours and atlases the windows, the widgets and
-- the pages share, in one place (the look of Forever's own windows, the profession window). A value
-- here changes every place that uses it; a page's own column positions stay in the page.
-- The layout rules of tools/ui_layout.py check the pages against these (padding, atlases).
local ADDON, ns = ...

local T = {}
ns.Theme = T

---------------------------------------------------------------------------
-- Colours
---------------------------------------------------------------------------
T.GOLD = { 0.89, 0.72, 0.34 }               -- frames of the flat fallbacks, a chip's text when on
T.BG = { 0.055, 0.04, 0.08, 0.96 }          -- the flat window ground without the client's template
T.TEXT_OFF = { 0.6, 0.6, 0.6 }              -- a chip's text when off
T.TEXT_DISABLED = { 0.45, 0.45, 0.45 }      -- a chip's text when disabled
T.TEXT_FREE = { 0.56, 0.53, 0.64 }          -- the free-text entry of a picker, the muted slot name
T.CHIP_OFF = 0.45                           -- vertex shade of a chip that is off
-- colour codes inside texts
T.GREY = "|cff8f86a3"
T.ORANGE = "|cffe0a344"
T.GREEN = "|cff4fbf7a"
T.RED = "|cffe0574a"                        -- a shortfall below the minimum
T.LABEL = "|cffe2b857"
T.GOLD_TEXT = "|cffe3b857"
-- the client's item quality colours (0 poor to 6 artifact): colour codes ("|c" .. T.QUALITY_HEX[q]) and
-- r, g, b (T.QUALITY_RGB, the slot frames of T.GOALS.QUALITY too)
T.QUALITY_HEX = { [0] = "ff9d9d9d", "ffffffff", "ff1eff00", "ff0070dd", "ffa335ee", "ffff8000", "ffe6cc80" }
T.QUALITY_RGB = { [0] = { 0.62, 0.62, 0.62 }, { 1, 1, 1 }, { 0.12, 1, 0 }, { 0, 0.44, 0.87 }, { 0.64, 0.21, 0.93 },
    { 1, 0.5, 0 }, { 0.9, 0.8, 0.5 } }

---------------------------------------------------------------------------
-- Fonts (the client's font objects)
---------------------------------------------------------------------------
T.FONT = {
    text = "GameFontHighlightSmall",   -- list cells, labels, chips
    hint = "GameFontDisableSmall",     -- grey help and status lines
    head = "GameFontNormalSmall",      -- gold column heads
    title = "GameFontNormal",          -- gold titles, the window title
    body = "GameFontHighlight",        -- white lines of a card, the status
    big = "GameFontNormalLarge",       -- the empty state's title
    dim = "GameFontDisable",           -- the empty state's text
}

---------------------------------------------------------------------------
-- Sizes and gaps (px)
---------------------------------------------------------------------------
T.TITLE_H = 24        -- the client's title bar: content starts at least this far below the top
T.BUTTON_W = 120      -- W.Button without a width
T.BUTTON_H = 22       -- the red button (SharedButtonSmallTemplate)
T.ROW_BUTTON_H = 20   -- a red button inside a list row or a field row
T.CHIP_W = 60         -- W.Chip without a width
T.CHIP_H = 20
T.CHIP_PAD = 8        -- a chip's or button's text keeps this much room on each side (W.FitChip)
T.CHIP_GAP = 4        -- between chips of a row
-- the quiet text tab (W.Tab, D-67): views and filters as gold words, the chosen one white over a thin gold
-- line; a filter (opts.check) with the client's small check box before its word
T.TAB_PAD = 4         -- room left and right of a tab's word
T.TAB_GAP = 12        -- between two tabs of a row
T.TAB_LINE = 2        -- the chosen tab's line under its word
T.TAB_CHECK = 14      -- a filter tab's check box
T.TAB_CHECK_GAP = 3   -- between the check box and the word
T.TAB_OFF = { 0.89, 0.72, 0.34 }   -- a tab's word when not chosen (gold, as the client's GameFontNormal)
T.TAB_ON = { 1, 1, 1 }             -- the chosen tab's word
T.CHOICE_W = 120      -- W.Choice without a width
T.FIELD_H = 20        -- edit boxes, search boxes, pickers, steppers
T.FIELD_CAP = 8       -- the input border's end caps
T.TEXT_INSET = 6      -- text inside an edit box or a picker, from its left edge
T.ARROW = 22          -- the dropdown arrow button
T.ARROW_SMALL = 20    -- the stepper's arrows
T.STEPPER_W = 120
T.TOGGLE = 18         -- the check box
T.RESET = 18          -- the red reset circle
T.HEADER_H = 25       -- the section header (ListHeaderVisualTemplate)
T.HEADER_TEXT_X = 8   -- its text from the left edge (and the collapse mark's room on the right: 24)
T.SECTION_GAP = 12    -- after a section of rows (settings)
T.WINDOW_PAD = 18     -- content of a side window from its left and right edge (12 still touched the border in the game)
T.SCROLLBAR_GAP = 4   -- between a list and its bar
T.SCROLL_ROOM = 12    -- what a list leaves free at its right for the bar (gap + the client's minimal scroll bar, 8)
T.HOVER_ALPHA = 0.5   -- the recipe list's hover glow on rows
T.ROW_SHADE = { 0.025, 0.045 }   -- the faint shade of odd and even list rows
T.ROW_ACTION_TICK = 0.05   -- how often the row actions (W.RowAction) follow the mouse, seconds
T.EDIT_W = 60         -- W.TimeBox without a width
T.LINE_W = 150        -- W.LineEdit, W.SearchBox, W.Picker without a width

-- the width of the page area of the main window (the content inset less its 7 px margin; 478 high):
-- what a page is laid out for; PAGE_W_NOW the width it has now, the main window dragged wider (D-71:
-- the page scaffold's bands fill it, W.FitWidths)
T.PAGE_W = 602
T.PAGE_W_NOW = 602
T.PAGE_H = 478   -- the page area under the window's head (MainFrame: content), for lists that fill it;
                 -- the main window sets it to its dragged height less 120 (D-68, D-69), W.FitLists follows

-- The page scaffold (W.Page): every page is built of the same parts, top to bottom: bands (the head
-- row first, then rows of controls or lines of text), the content (column heads, a list, a detail
-- beside or under it, an empty state over it), a bottom row of controls and the footer (hint and
-- data lines). The layout rules (tools/ui_layout.py, rule "grid") check the pages against these.
T.LAYOUT = {
    ROW_H = 22,       -- a band of controls: as high as the red button; chips, pickers and fields sit centred
    LINE_H = 16,      -- a band of text: the hint or counts line under the head row, a footer line
    GAP = 4,          -- between two bands, after the last band, and before the bottom row or the footer
    ITEM_GAP = 6,     -- between two controls of a band (between two chips: T.CHIP_GAP)
    TEXT_X = 6,       -- a line's text from the page's edges (as the cells of a list and a picker's text)
    COLHEAD_H = 18,   -- the column heads over a list (gold, T.FONT.head)
    SPLIT_X = 306,    -- a list with a detail inset beside it: the list 290 wide, its bar, then the inset
    SPLIT_LIST_W = 290,
    EMPTY_Y = 36,     -- the empty state's top below the top of the list it stands for
    DETAIL = { PAD = 8, ICON = 32, TITLE_X = 44, TITLE_H = 18, SUB_Y = 28, BODY_Y = 46, BUTTONS = 32 },
}

-- the main window (MainFrame.lua, D-68, D-70): the side bar on the left (the head with the logo, the
-- search box, the groups as headings with their pages and side windows as the auction house's
-- sub-category bars); the page in the content inset on the right. Nothing hangs under or beside it.
T.MAIN = {
    -- 560 until 2.62.0; the page head (PAGE_HEAD, D-69) made it taller, the page keeps its 478
    W = 806, H = 598,
    -- the size the player can drag (the grip at the bottom right, the chat window's size grabber,
    -- GRIP square in the frame's corner (GRIP_OUT past it), over its border and clear of the page's controls
    -- in its bottom right corner): H_MIN to H_MAX, never taller than the screen; T.PAGE_H and the side
    -- bar follow (D-68)
    H_MIN = 598, H_MAX = 898, GRIP = 12, GRIP_OUT = 0,
    -- and its width (D-71): W_MIN to W_MAX, never wider than the screen; T.PAGE_W_NOW follows
    W_MIN = 806, W_MAX = 1440,
    -- the minimize button (the client's UIPanelHideButtonNoScripts, 24 square) left of the close
    -- button; the bar it leaves (MINI: in the tooltip's frame, the logo LOGO square from LOGO_X, the
    -- name and under it the open page from TEXT_X, the close button X square X_R from the right)
    MIN_SIZE = 24, MIN_SIZE_OLD = 20,
    MINI = { W = 214, H = 36, LOGO = 22, LOGO_X = 9, TEXT_X = 38, NAME_Y = 7, PAGE_Y = -7, X = 20, X_R = 6, TEXT_W = 140 },
    -- the side bar (D-70, after the reference's hub): at its top the head (NAV_HEAD high: the logo
    -- LOGO square, the name in gold and under it the version and the view in grey, the gold line at
    -- its bottom), the search box under it, then a W.List of NAV_ROW_H rows, the client's list spacing
    -- 0, a scroll bar when not all fit. Every group with a page is a heading (gold, capitals, from
    -- NAV_LABEL_X; the gold line over it from the second on); each page and side window a
    -- sub-category bar with its symbol (NAV_ICON square at NAV_ICON_X, T.NAV_ICONS) and its name from
    -- NAV_SUB_X (gold); under the open page "Einstellungen" its tabs from NAV_SUB2_X (gold) and the
    -- chosen tab's sections from NAV_SUB3_X (white, D-49); a side window with the chat window's
    -- maximize sign (FOLD square) FOLD_R from the right. NAV_LIST_H: the list's height at H
    NAV_HEAD = 40, LOGO = 30, LOGO_X = 2, HEAD_TEXT_X = 38, HEAD_NAME_Y = 4, HEAD_SUB_Y = 21, HEAD_RULE_Y = 38,
    NAV_W = 164, NAV_LIST_H = 452, NAV_SUB_X = 29, NAV_SUB2_X = 34, NAV_SUB3_X = 46,
    NAV_ROW_H = 21, NAV_LABEL_X = 8, NAV_LABEL_W = 150, NAV_ICON = 14, NAV_ICON_X = 11, FOLD = 14, FOLD_R = 6,
    -- the search box under the head (T.FIELD_H high), the list SEARCH_GAP under it; typing turns the
    -- list into the results (RES_ROW_H rows: a group as a category bar, its hits as the indented
    -- sub-category bars, RES_HIT_X the hit's text as the client's 18), at least SEARCH_MIN
    -- characters, at most RES_MAX hits per group; 21 x 21 = 441 of the 452
    SEARCH_GAP = 6, SEARCH_MIN = 2, RES_ROWS = 21, RES_ROW_H = 21, RES_MAX = 8, RES_HIT_X = 18,
    MARGIN = 6,           -- the insets from the window's edge
    TOP = 62,             -- the insets start this far below the top (title bar and status line)
    LIST_W = 176,         -- the side bar's inset
    CONTENT_X = 184,      -- the content inset's left edge
    INNER = 6,            -- the side bar inside its inset
    PAGE_PAD = 7,         -- the page inside the content inset
    -- the page head (D-69) at the top of the content inset, PAGE_HEAD high over the page: the page's
    -- name (T.FONT.big, gold) at TITLE_Y, its one line (T.FONT.hint) at SUB_Y, the gold line fading to
    -- both ends at RULE_Y (RULE_ALPHA at its middle); at its right end the page's help ("?", the
    -- client's help-i) and its settings (the quest log's gear, D-49) as small icons, ICON_SIZE square,
    -- ICON_GAP apart, ICON_Y from the head's top
    PAGE_HEAD = 38, TITLE_Y = 2, SUB_Y = 21, RULE_Y = 35, RULE_ALPHA = 0.7, ICON_Y = 4,
    HEAD_X = 66, HEAD_Y = 26, HEAD_H = 22,  -- the status line right of the portrait (D-67)
    -- the recording and the view sit in a menu behind the status line (its arrow MENU_SIZE); the right
    -- end of the window's head keeps ICON_RIGHT free (the close button's row)
    ICON_SIZE = 22, ICON_GAP = 6, ICON_RIGHT = 12, MENU_SIZE = 20,
}

-- The symbol of each page and side window in the side bar (D-70): the client's own marks (the
-- minimap's tracking icons, the gossip icons, the map's marks, the money and group loot art), never a
-- spell or item icon in their place. { file = path } or { atlas = name }; a key not here: no symbol.
local TRACK, GOSSIP = "Interface\\Minimap\\Tracking\\", "Interface\\GossipFrame\\"
T.NAV_ICONS = {
    -- Raid
    overview = { file = TRACK .. "Innkeeper" },
    lineup = { file = GOSSIP .. "GossipGossipIcon" },
    raidcheck = { file = "Interface\\RaidFrame\\ReadyCheck-Ready" },
    softres = { file = GOSSIP .. "PetitionGossipIcon" },
    rolls = { file = "Interface\\Buttons\\UI-GroupLoot-Dice-Up" },
    awards = { file = GOSSIP .. "VendorGossipIcon" },
    raidlog = { file = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull" },
    points = { atlas = "coin-gold" },
    stats = { file = GOSSIP .. "TrainerGossipIcon" },
    raids = { file = TRACK .. "None" },
    export = { file = "Interface\\Buttons\\UI-GuildButton-PublicNote-Up" },
    -- Charakter
    gear = { file = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest" },
    talents = { file = TRACK .. "Class" },
    professions = { file = TRACK .. "Profession" },
    scrolls = { file = TRACK .. "Reagents" },
    -- Welt
    dungeons = { atlas = "Dungeon" },
    raidjournal = { atlas = "Raid" },
    quests = { file = GOSSIP .. "AvailableQuestIcon" },
    map = { file = TRACK .. "FlightMaster" },
    -- Gilde
    members = { file = GOSSIP .. "TabardGossipIcon" },
    calendar = { file = "Interface\\Calendar\\MeetingIcon" },
    bank = { file = GOSSIP .. "BankerGossipIcon" },
    duels = { file = GOSSIP .. "BattleMasterGossipIcon" },
    tools = { file = TRACK .. "Repair" },
    -- Amisia
    settings = { atlas = "questlog-icon-setting" },
    about = { file = "Interface\\common\\help-i" },
    feedback = { file = TRACK .. "Mailbox" },
    -- the side windows (key "win:" .. their key)
    ["win:gear"] = { file = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Head" },
    ["win:goals"] = { atlas = "auctionhouse-icon-favorite" },
    ["win:talents"] = { file = TRACK .. "Class" },
    ["win:rolls"] = { file = "Interface\\Buttons\\UI-GroupLoot-Dice-Up" },
    ["win:softres"] = { file = GOSSIP .. "PetitionGossipIcon" },
}

-- A bar of the auction house's category list (AuctionCategoryButtonTemplate as the client's
-- AuctionHouseFilterButton_SetUp dresses it, Blizzard_AuctionHouseUI/Mainline; W.NavBar): the art is
-- TEX_H / BAR_H of the bar's height (136 x 32 on a 132 x 21 button) and hangs from its top, so a bar
-- reaches a little under the next one as in the client. TOP: a category (the page list, a search
-- group): the art X left of the button and R past its right edge, the chosen rim and the hover glow
-- over the whole button. SUB: a sub-category (a search hit): the art from X, R past the right edge,
-- the rim and the glow from HL_X (indented as in the client).
T.NAVBAR = {
    TEX_H = 32, BAR_H = 21,
    TOP = { X = -2, R = 2, HL_X = 0 },
    SUB = { X = 1, R = 1, HL_X = 10 },
}

-- the calendar page (UI/Pages/Calendar.lua, the tab "Kalender"): the head row with the month (gold,
-- arrows left and right, "Heute" on the right), the month grid on the left (a weekday bar, 6 rows of
-- 7 day cells on the client calendar's parchment), the chosen day's dates and participants in an inset
-- on the right, the bottom row (the calendar read's state, Zur Aufstellung, Anmelden ...) and the hint.
-- 26 (head row and gap) + 20 + 6 x 64 + 4 + 22 + 4 + 16 = 478; 7 x 56 + 8 + 202 = 602.
T.CALPAGE = {
    TITLE_W = 160,        -- the month's title between the arrows (T.FONT.big, gold, centred)
    GRID_Y = 26,          -- the grid below the page's top (under the head row)
    CELL_W = 56, CELL_H = 64,
    HEAD_H = 20,          -- the weekday bar (the client calendar's weekday art)
    PAD = 4,              -- a cell's texts from its edges
    DAY_Y = 3,            -- the day's number below the cell's top (T.FONT.body)
    EVENT_Y = 20,         -- the first date's time below the cell's top, its title LINE_H under it
    LINE_H = 12,          -- one line of a date in a cell (T.FONT.text)
    DOT = 8,              -- the own state's dot at the cell's top right
    DARK = 0.45,          -- a day of another month: its ground this bright
    TODAY = 2,            -- the gold frame round today
    -- the day's inset on the right
    RIGHT_X = 400, RIGHT_W = 202,
    RIGHT_TOP = 6,        -- the day's inset starts this far below the grid's top: its frame art reached "Heute" in the game
    INNER = 6,            -- its texts from its edges
    TERM_Y = 26,          -- the day's dates (TERM_H each, TERMS at most) under the day's title
    TERM_H = 18, TERMS = 2,
    TOTALS_Y = 64,        -- the totals of the chosen date
    LIST_Y = 84,          -- the participants (rows ROW_H high)
    ROW_H = 18, ROWS = 17,
    LIST_W = 178,         -- RIGHT_W - 2 x INNER - T.SCROLL_ROOM
    CELL_ICON = 14,
    -- the participant columns, as the raid calendar window's (T.RAIDCAL.COLS): role (icon and letter),
    -- class icon, name (class colour), sources K/A
    COLS = { { "r", 2, 34 }, { "class", 38, 14 }, { "name", 54, 90 }, { "src", 146, 30 } },
    ROLE_LETTER_X = 17,
    COMPACT_HEAD = true,  -- the groups' heads as flat one-line bars in the small gold font (RaidCalendar.lua)
    BUTTON_W = 110,       -- "Anmelden ..." / "Ändern ..." and "Zur Aufstellung" (at least; FitChip)
}

-- the round class icons (W.SetClassIcon: the members page, the duels page): the client's class circles
T.CLASS_ICON = {
    TEXTURE = "Interface\\TargetingFrame\\UI-Classes-Circles",
    -- the class's part of TEXTURE when the client's CLASS_ICON_TCOORDS lacks it
    COORDS = {
        WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.49609375, 0, 0.25 }, ROGUE = { 0.49609375, 0.7421875, 0, 0.25 },
        DRUID = { 0.7421875, 0.98828125, 0, 0.25 }, HUNTER = { 0, 0.25, 0.25, 0.5 }, SHAMAN = { 0.25, 0.49609375, 0.25, 0.5 },
        PRIEST = { 0.49609375, 0.7421875, 0.25, 0.5 }, WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 },
        PALADIN = { 0, 0.25, 0.5, 0.75 },
    },
}

-- the members page (UI/Pages/Members.lua, tab Gilde, F-104): the head row (class and profession
-- dropdowns, "nur online", the name search), the column heads, ROWS rows of ROW_H and the footer line:
-- 26 + 18 + 9 x 46 + 20 = 478. A row, left to right on the list's 590: the round class icon, the name
-- in class colour over level, class and rank; the zone (map icon) over online or the last time online
-- (clock icon); the professions as icon (skill on it) and bar (name on it, filled rank / max), the
-- main professions in the upper line, the secondary ones in the lower, BOXES per line.
T.MEMBERS = {
    ROWS = 9, ROW_H = 46,
    CLASS_W = 130, PROF_W = 130, SEARCH_W = 140,   -- the head row's dropdowns and the search box
    ICON = 36, ICON_X = 6,                         -- the round class icon (T.CLASS_ICON), centred on the row
    LINE1_Y = -8, LINE2_Y = -26,                   -- the two lines of text below the row's top
    NAME_X = 48, NAME_W = 124,                     -- the name (T.FONT.body), under it level, class, rank
    ZONE_X = 176, ZONE_W = 140,                    -- the zone and the time column
    SMALL_ICON = 12, SMALL_GAP = 3,                -- the map and clock icons before their texts
    MAP_ICON = "Interface\\Icons\\INV_Misc_Map_01",
    CLOCK_ICON = "Interface\\Icons\\INV_Misc_PocketWatch_01",
    -- the professions from PROF_X to 588: two main ones of 2 x 132 + 4 = 268, under them three
    -- secondary ones of 3 x 86 + 2 x 4 = 266
    PROF_X = 320, MAIN_BOXES = 2, MAIN_BOX_W = 132, BOXES = 3,
    BOX_W = 86, BOX_H = 18, BOX_GAP = 4, BOX_Y = -4, BOX_ROW_GAP = 3,
    BOX_ICON = 18, BAR_H = 14, BAR_GAP = 2, BAR_PAD = 3,
    BAR_COLOR = { 0.25, 0.42, 0.85 },              -- the bar's fill (the classic profession window's blue)
    NUM_FONT = "NumberFontNormalSmall",            -- the skill on the icon
    -- the column heads (sort on click; Berufe sorts by the skill), x and width on the list
    COLS = { { "name", 48, 60 }, { "level", 110, 56 }, { "zone", 176, 60 }, { "last", 238, 78 }, { "prof", 320, 120 } },
}

-- the page Karte (tab Ausrüstung, F-045): the head row (zone picker, the chips Ziele, Wünsche,
-- Quests), the counts line with the link "N Items ohne Ort", the target card of two lines (the arrow
-- towards the target from ARROW_X, the name over zone, coordinates, distance and direction from
-- TEXT_X), then the list: 13 rows of 24 from the column heads (100) to the bottom row (420)
T.MAPPAGE = {
    ROWS = 13, ROW_H = 24,
    PICKER_W = 240, OPEN_W = 130,
    CARD_LINES = 2, ARROW = 16, ARROW_X = 6, TEXT_X = 28, TEXT_Y = 2,
    CARD_SHADE = 0.045,
    ARROW_TEX = "Interface\\AddOns\\Amisia\\Media\\Icons\\arrow",
    -- the place list: kind, source, place, items, the button "Karte"; the zone head over the whole row
    COLS = { { "kind", 4, 66 }, { "src", 74, 186 }, { "where", 264, 100 }, { "items", 368, 164 }, { "go", 540, 46, cell = false } },
    GO_X = 536, GO_W = 54, HEAD_X = 4, HEAD_W = 528,
    -- the view "Ohne Ort": the item, the reason
    NP_COLS = { { "name", 4, 220 }, { "why", 230, 350 } },
}

-- the page Berufe (F-051) and its route (F-137): the head row's profession picker, the chips
-- "Rezepte | Route", the search and the rank; the route's steps (two lines per card: what, then the
-- expected crafts and reagents; the cost at the right, a tick on done steps) and its shopping list
-- the quest journal of a dungeon (UI/Pages/Dungeons.lua, F-138): a view under the page's head row:
-- its own row ("< Zurück", "Nächsten Schritt auf der Karte"), the dungeon's image (ART_Y), then from
-- CONTENT_Y the quests as cards of two lines on the left (LIST_W, ROWS of ROW_H) and the chosen
-- quest in an inset on the right (DETAIL_X to the page's edge, as high as the list): its mark and
-- title, the info line, then scrolling the next step's box, the reward tiles (two per row), the XP
-- and the quest path's step cards (their fields over their text; done steps folded to the head)
T.DJOURNAL = {
    ART_Y = 26, CONTENT_Y = 78,
    ROWS = 9, ROW_H = 37, LIST_W = 232, DETAIL_X = 248,
    -- a card of the list: the state mark, title (gold) and the state word right of it; level, path,
    -- start mark under it, the upgrade's gain at the right
    MARK = 16, MARK_X = 6, MARK_Y = -4, TEXT_X = 26, LINE1_Y = -5, LINE2_Y = -21, RIGHT_PAD = 6,
    -- the inset: its mark, title and info line; the scrolling body below BODY_Y
    PAD = 8, ICON = 20, TITLE_X = 34, TITLE_Y = -8, INFO_Y = -28, BODY_Y = 46,
    SECTION_GAP = 8,           -- between the parts of the body
    LABEL_H = 16,              -- a gold label line ("Belohnung:", "Questweg:")
    BOX_PAD = 6,               -- the next step's text inside its box
    TILE_H = 34, TILE_ICON = 28, TILE_GAP = 4, TILE_TEXT_X = 34,
    -- the run planner (F-139): the run's sum in the image (text and XP bar left of the boss model),
    -- the worth bar under a list card, the level window, the stops and the boss track
    RUN_W = 200, RUN_X = 6, RUN_Y = -8, BAR_H = 6, BAR_Y = 10,
    XP_COLOR = { 0.58, 0.0, 0.55 }, GAIN_COLOR = { 0.0, 0.39, 0.88 }, BAR_BG = { 0, 0, 0, 0.6 },
    WORTH_H = 2, WORTH_Y = 3,
    LVL_W = 110, LVL_H = 6, LVL_ROW = 16, LVL_GAP = 8,
    LVL_LOW = { 0.75, 0.3, 0.2, 0.9 }, LVL_OK = { 0.31, 0.82, 0.42, 0.9 }, LVL_GREY = { 0.5, 0.5, 0.5, 0.9 },
    STOP_X = 10, NODE = 14, NODE_TEXT_X = 20, LINK_W = 2, DONE_H = 20,
    PLAN_W = 96,               -- "Lauf planen" in the planner's image, left of "Alle auf Karte"
}

-- the start views of the pages Dungeons and Raids (F-143, D-69): a grid of cards, COLS per list row
-- (W x H, GAP between them: 3 x 192 + 2 x 7 = 590, the list's width). A card: the image at its top
-- (ART_H, darkened towards its bottom from SHADE_TOP to SHADE_BOTTOM; SHADE_ALPHA without gradients)
-- with the name on its lower left (NAME_X, NAME_Y above the image's bottom), under it two lines
-- (LINE1_Y, LINE2_Y below the card's top); the tag "Empfohlen" at the top right (TAG_*); a thin gold
-- frame (EDGE, CHOSEN for the chosen one), the hover glow GLOW; a dim card's name in DIM.
T.DCARD = {
    W = 192, H = 84, GAP = 7, COLS = 3, MIN_ROWS = 2,
    MAX_COLS = 6,              -- the window dragged wide (D-71): up to six per row
    ART_H = 44, NAME_X = 6, NAME_Y = 4, TEXT_X = 6, TEXT_W = 180, LINE1_Y = -49, LINE2_Y = -66,
    SHADE_TOP = 0.05, SHADE_BOTTOM = 0.85, SHADE_ALPHA = 0.45, GROUND = { 0, 0, 0, 0.35 },
    TAG_X = -4, TAG_Y = -4, TAG_H = 14, TAG_PAD = 4, TAG_BG = { 0, 0, 0, 0.7 }, TAG_COLOR = { 0.31, 0.82, 0.42 },
    EDGE = 0.35, CHOSEN = 0.95, GLOW = 0.06, DIM = { 0.56, 0.53, 0.64 },
}

-- the boss list of the detail views of Dungeons and Raids (F-144, D-69): a boss's head row with the
-- quest log's plus or minus (SIGN square at SIGN_X), its name from NAME_X (NAME_W), its gain per run
-- from RATE_X (RATE_W); folded, a strip of at most MAX_ICONS item icons (ICON square, ICON_GAP apart,
-- an EDGE px frame in the item's quality colour) STRIP_R from the row's right end, "+N" (MORE_W) after them.
T.DBOSS = {
    SIGN = 14, SIGN_X = 4, NAME_X = 22, NAME_W = 202, RATE_X = 228, RATE_W = 200,
    ICON = 18, ICON_GAP = 2, MAX_ICONS = 6, EDGE = 1, STRIP_R = 4, MORE_W = 26,
}

T.PROFPAGE = {
    PICKER_W = 170, SEARCH_W = 150, RANK_W = 120,
    STEP_ROWS = 9, STEP_H = 36, TICK = 14, MARK_X = 4, TEXT_X = 22, LINE1_Y = -4, LINE2_Y = -19, COST_W = 80,
    TICK_TEX = "Interface\\RaidFrame\\ReadyCheck-Ready",
    SHOP_ROWS = 14, SHOP_H = 22,
    -- material, need, have, the other own characters, missing, price of one, source
    SHOP_COLS = { { "name", 4, 170 }, { "need", 178, 40, justify = "RIGHT" }, { "have", 222, 40, justify = "RIGHT" },
                  { "twinks", 266, 44, justify = "RIGHT" }, { "miss", 314, 40, justify = "RIGHT" },
                  { "price", 358, 64, justify = "RIGHT" }, { "src", 430, 148 } },
}

-- the page Duelle (tab PvP, F-106): three lists on the page's 590 px. The history: two lines per row
-- (the name in class colour, under it the class); the leaderboard and the classes: one line each.
T.DUELS = {
    CLASS_W = 130, SEARCH_W = 140, RANGE_W = 110,  -- the second head row's class and time pickers, search box
    -- the card under the client's duel request (UI/DuelInfo.lua): below the request window, without
    -- one that far from the screen's top; hidden after CARD_TIME seconds without a request window
    CARD_GAP = 6, CARD_Y = -140, CARD_TIME = 60,
    HIST_ROWS = 12, HIST_ROW_H = 32, LINE1_Y = -3, LINE2_Y = -17,
    -- { key, x, width } of the history: time, winner, loser, result, place; a name column holds the
    -- round class icon (HIST_ICON) and beside it the name over class and specialisation
    HIST_COLS = { { "t", 6, 66 }, { "w", 76, 166 }, { "l", 246, 166 }, { "k", 416, 50 }, { "z", 470, 114 } },
    HIST_ICON = 24, ICON_GAP = 4,
    ROWS = 19, ROW_H = 20,
    -- the leaderboard: rank, class icon (BOARD_ICON at the name column's x) and name, class with
    -- specialisation, games, wins-losses, win rate (a click on the last four heads sorts)
    BOARD_COLS = { { "rank", 6, 26, justify = "RIGHT" }, { "name", 38, 164, cx = 58, cw = 144 }, { "class", 206, 150 },
                   { "games", 360, 52, justify = "RIGHT" }, { "wins", 418, 76, justify = "CENTER" },
                   { "rate", 500, 70, justify = "RIGHT" } },
    BOARD_ICON = 16,
    -- the classes: class icon (BOARD_ICON) with rank and class, games, players, wins-losses, win rate
    CLASS_COLS = { { "class", 6, 200, cx = 26, cw = 180 }, { "games", 214, 60, justify = "RIGHT" }, { "players", 288, 60, justify = "RIGHT" },
                   { "wins", 366, 90, justify = "CENTER" }, { "rate", 470, 70, justify = "RIGHT" } },
}

-- the soft-reserve import window (F-108): from the top the list's date, the pasted text, the
-- preview line, the box "Im Raid ohne Reserve", the head and the rows of the preview (two lines: the
-- name in class colour, under it the finding; the items as icons on the right), then the result
-- line and the buttons. Content T.WINDOW_PAD from both edges: 524 wide, the list 512 (its bar).
T.SRIMPORT = {
    W = 560, H = 614,
    DATE_Y = -32, BOX_Y = -50, BOX_H = 84, PREVIEW_Y = -140, TEXT_H = 26,
    MISS_Y = -172, MISS_H = 64, MISS_PAD = 8, MISS_TITLE_Y = -8, MISS_NAMES_Y = -32, MISS_BUTTON_Y = -5,
    HEAD_Y = -244, LIST_Y = -262, ROWS = 7, ROW_H = 40,
    NAME_X = 8, NAME_Y = -5, STATUS_Y = -21, STATUS_W = 232, SUGGEST_MAX_W = 120, SUGGEST_Y = -19,
    ANNOUNCE_X = 140, ANNOUNCE_Y = -10,            -- "Ansagen" on the hard-reserve row
    ICON = 28, ICON_GAP = 4, ICON_X = 248, ICONS = 8, ICON_Y = -6,
    RESULT_Y = 38, BUTTON_Y = 10,
    HARD = { 0.8, 0.22, 0.18, 0.9 },             -- the frame of the hard-reserve row
}

-- an overview card
T.CARD = { PAD = 10, TITLE_Y = 8, LINE1_Y = 28, LINE2_Y = 48, BUTTON_Y = 8,
    HOVER_ALPHA = 0.05 }   -- the card under the mouse lights up faintly (a click runs its first action, D-67)
-- the card "Upgrades: <Slot>" beside the character window (UI/SlotCard.lua, F-125): the best ROWS
-- items of a slot, each an icon with name and source over each other and the gain at the right
T.SLOTCARD = { W = 300, PAD = 10, TITLE_H = 24, ROWS = 5, ROW_H = 34, ICON = 26, TEXT_X = 34, GAIN_W = 56,
    GAP = 6, CLOSE = 20, OFFSET_X = 4, ENCH_H = 18 }
-- the empty state of a page: a short title (no full stop) and a sentence of help; BUTTON_GAP: an
-- action button under the help (the professions page's "Filter zurücksetzen")
T.EMPTY = { W = 420, H = 120, ICON = 56, ALPHA = 0.35, TITLE_GAP = 10, TEXT_GAP = 6, BUTTON_GAP = 10 }
-- the shared popup menu and the picker's panel
T.MENU = { W = 182, ROW_W = 170, ROW_H = 20, PAD = 6, LABEL_W = 160, GROUND_X = 10, GROUND_Y = 3, ALPHA = 0.925 }
T.PICKER = { ROWS = 8, ROW_H = 20, MIN_W = 180, FILTER_Y = 6, LIST_Y = 30, ARROW_ROOM = 26 }
-- the talent calculator (Pages/Talents.lua) in the look of the game's classic three-tree talent
-- window: three dark panels side by side, a centred head (name over points), square icons with a
-- thin square frame, a rank plate at the lower right, straight prerequisite lines behind them.
-- One builder draws it in two sizes: PAGE (the page in the main window) and BIG (the window
-- "Talentrechner", AmisiaTalentFrame). What both share stands here, the sizes in the two profiles.
-- A button is ICON + 2 x FRAME; the 4 columns sit centred in the tree, so the outer buttons keep
-- (TREE_W - 3 x PITCH - button) / 2 to the tree's edges, less the glow (3 px) or the plate's
-- overhang (PLATE_X) on the outside: at least MARGIN (the tests and the layout rules check it).
T.TALENT = {
    RESET = 14,           -- the red reset X at the head's top right, shown while the mouse is on the head
    RESET_X = 5,          -- its distance from the tree's top right corner
    CROP = 0.07,          -- a talent's icon is cropped CROP..1-CROP
    FRAME = 1,            -- the square frame around the icon
    GLOW = { 0.6, 0.35, 0.15 },  -- a maxed talent's soft glow: alpha of the rings 1, 2, 3 px outside its frame
    PLATE_ALPHA = 0.75,   -- the dark plate under the rank text
    DIM = 0.5,            -- an unreachable talent's icon: desaturated and this bright
    -- the frame per state: unreachable grey-brown, reachable the classic gold-brown, partly learned
    -- green, maxed bright gold (with the glow)
    FRAME_COLOR = { locked = { 0.36, 0.33, 0.28 }, free = { 0.66, 0.53, 0.3 }, partial = { 0.3, 0.85, 0.3 },
                    maxed = { 1, 0.82, 0 } },
    -- the rank text per state: grey, white, green, gold
    RANK_COLOR = { locked = { 0.5, 0.5, 0.5 }, free = { 1, 1, 1 }, partial = { 0.25, 1, 0.25 }, maxed = { 1, 0.82, 0 } },
    LINE_COLOR = { met = { 1, 0.82, 0, 0.9 }, unmet = { 0.3, 0.28, 0.25, 0.9 } },
    -- the page in the main window: 3 x 198 + 2 x 4 = the page width (602). 34 px icons 12 px apart
    -- leave 12 px to the tree's edges, 9 past the glow and the plate (2.19.0: 36 px, 14 apart, 2 px:
    -- the outer buttons touched the borders in the game)
    PAGE = {
        TREE_W = 198, TREE_GAP = 4, TREE_H = 398,
        HEAD_H = 42,          -- the head of a tree: the name, the points under it (mouse area for the reset)
        NAME_Y = 7,           -- the name's top below the tree's top
        PTS_GAP = 2,          -- between the name and the points
        NAME_FONT = "GameFontNormalLarge",      -- the tree name: large, gold
        PTS_FONT = "GameFontHighlightSmall",    -- "N Punkte": small, white
        RANK_FONT = "NumberFontNormalSmall",    -- the rank on its plate
        ICON = 34,            -- a talent's icon
        PITCH = 46,           -- button to button, across and down: 10 px between two buttons
        GRID_TOP = 46,        -- the first row's top below the tree's top (under the head)
        PLATE_W = 24, PLATE_H = 12,  -- the dark plate under the rank text
        PLATE_X = 3, PLATE_Y = -3,   -- its lower right corner from the button's: over the icon's lower right edge
        LINE = 3,             -- a prerequisite line's thickness
        ARROW = 10,           -- the arrow head at the line's end, in the gap before the talent
        MARGIN = 8,           -- at least this from a tree's edge to the outside of its outer buttons
        LIVE_W = 262,         -- the line "Im Spiel: ..." under the trees (the message takes the rest)
    },
    -- the window "Talentrechner": 3 x 270 + 2 x 6 = 822 wide, T.WINDOW_PAD on both sides; 44 px
    -- icons 16 px apart, 19 px to the tree's edges (16 past the glow and the plate)
    BIG = {
        TREE_W = 270, TREE_GAP = 6, TREE_H = 488,
        HEAD_H = 48, NAME_Y = 8, PTS_GAP = 3,
        NAME_FONT = "GameFontNormalLarge",
        PTS_FONT = "GameFontHighlight",
        RANK_FONT = "NumberFontNormal",
        ICON = 44, PITCH = 62, GRID_TOP = 52,
        PLATE_W = 30, PLATE_H = 15, PLATE_X = 3, PLATE_Y = -3,
        LINE = 4, ARROW = 12,
        MARGIN = 14,
        LIVE_W = 360,
    },
    -- the window around the BIG view: the view starts TOP below the window's top (under the title
    -- bar), leaves BOTTOM free at the bottom; scale from the setting ui.talentScale (Ctrl + mouse
    -- wheel over the window: SCALE_STEP)
    WINDOW = { TOP = 32, BOTTOM = 12, SCALE_STEP = 5 },
}

-- the window "Ausrüstungsziele" (UI/GoalsWindow.lua, AmisiaGoalsFrame, F-110 to F-113) in the
-- talent window's frame: the head row under the title bar; left the doll (the character model
-- between the slot columns as on the character frame, the weapons under it, the switch Ziele /
-- Angelegt, the score head), in the middle the progress, the filter chips and the list of slots by
-- section, right the chosen slot's panel (own pick, ranking, dungeon drops, the item field).
-- 18 + 300 + 10 + 380 + 10 + 210 + 18 = 946 wide; the doll's column with the score head sets the
-- height: 60 + 410 (model, weapons, switch, hint) + 4 + 20 + 4 + 10 + 14 + 4 + 84 (stats) + 12 = 622.
T.GOALS = {
    W = 946, H = 700,
    TOP = 32,             -- the head row below the window's top, under the title bar
    BOTTOM = 12,          -- what the columns leave free at the bottom
    SCALE_STEP = 5,       -- Ctrl + mouse wheel: percent per notch (setting ui.goalScale)
    COL_Y = 60,           -- the three columns below the window's top
    -- the doll: 6 slots left (centred on the 8 right), the model between, the weapons under it
    DOLL_X = 18, DOLL_W = 300,
    SLOT = 36, SLOT_GAP = 4, SLOT_EDGE = 2, SLOT_INSET = 2,
    DOT = 10,             -- the state dot at a slot's lower right corner
    MODEL_GAP = 8,        -- between a slot column and the model
    MODEL_H = 316,        -- 8 slots and their gaps
    WEAPON_GAP = 8,       -- between the model and the weapon row
    SWITCH_GAP = 6,       -- between the weapon row and the switch Ziele / Angelegt
    HINT_H = 24,          -- the model's hint under the switch (two lines at most)
    ROTATE = 0.012,       -- radians per pixel the mouse is dragged
    ZOOM_STEP = 0.1, ZOOM_MAX = 0.8,
    -- the list in the middle
    LIST_X = 328, LIST_W = 380,
    PROG_Y = 60,          -- "N/17 Ziele hast du" (T.FONT.title) and the bar of 17 parts beside it
    PROG_TEXT_W = 148, BAR_W = 224, BAR_H = 10, BAR_PART_GAP = 2,
    FILTER_Y = 84,        -- the filter chips
    LIST_Y = 112,         -- the list (its rows ROW_H high, ROWS of them)
    ROW_H = 20, ROWS = 21,
    ICON = 16,
    -- { key, x, width } on the list's 368 (LIST_W less T.SCROLL_ROOM): slot, icon, item, gain, map, source
    COLS = { { "slot", 4, 56 }, { "icon", 62, 16 }, { "name", 82, 150 }, { "gain", 236, 38 }, { "map", 280, 16 }, { "src", 298, 68 } },
    -- the catalog (F-123) in the place of the list and the slot panel: the search row on top (the
    -- box, the level range "von - bis", "Meine Stufe", "Alle"), the categories left as the page
    -- list's bars with "Set anprobieren" and "Anprobe leeren" under them, the list of sets or hits
    -- right of them, its hint under it. 30 + 24 x 20 + 4 + 28 = 542 of the 552 under PROG_Y.
    CAT_W = 600,          -- the whole catalog: LIST_X to the right end of the slot panel
    CAT_SEARCH_W = 220, CAT_LEVEL_W = 64, CAT_RANGE_W = 10,
    CAT_LIST_Y = 30,      -- the list and the categories under the search row
    CAT_NAV_W = 150, CAT_NAV_H = 24, CAT_NAV_GAP = 4,
    CAT_BTN_GAP = 10,     -- between the last category and "Set anprobieren"
    CAT_LIST_X = 160, CAT_ROWS = 24, CAT_HINT_H = 28,
    -- { key, x, width } on the list's 428 (440 less T.SCROLL_ROOM): icon, item or set, slot or N/M,
    -- level, gain, map, source
    CAT_COLS = { { "icon", 4, 16 }, { "name", 24, 176 }, { "slot", 204, 58 }, { "level", 264, 28 }, { "gain", 296, 40 },
        { "map", 340, 16 }, { "src", 360, 64 } },
    CAT_ICON = 16,
    -- the slot panel on the right
    SIDE_X = 718, SIDE_W = 210,
    SIDE_ROW_H = 18, RANK_ROWS = 10,   -- the ranking's rows
    ENCH_ROWS = 5,        -- the enchantments of the worn item (F-128), SIDE_ROW_H high
    DROP_ROWS = 3, DROP_ROW_H = 30,     -- the dungeon drops: item over boss and dungeon
    HEAD_H = 16,          -- a head in the panel (the slot, Deine Wahl, Rangliste, ...)
    SECTION_GAP = 6,      -- before a section's head in the panel
    PICK_H = 30,          -- the own pick: name over source (or the line without a pick)
    TAKE_W = 76,          -- "Übernehmen" beside the hint "Überholt: ..."
    RANK_GAIN_W = 44,     -- the gain at a ranking row's right end
    FIELD_W = 132,        -- "Item-Link oder ID"; "Hinzufügen" takes the rest
    MSG_H = 26,           -- what the field says (two lines)
    -- the score head under the doll (part B): "Wertung 18,6" (T.FONT.big), "jetzt 17,2" and "+1,4"
    -- beside it, the bar up to "Bestes auf Stufe N" with its line under it, the six biggest stat
    -- changes one under the other (the German stat names do not fit two columns of 150 px), the label
    -- left and the change right
    SCORE_GAP = 4,        -- between the doll's hint and the score line, and between the parts
    SCORE_H = 20, SCORE_W = 140, NOW_W = 86, GAIN_W = 62,
    SCORE_BAR_H = 10, BEST_H = 14,
    STAT_ROWS = 6, STAT_H = 14, STAT_W = 300, STAT_VALUE_W = 60,
    MARK_W = 2,           -- the line in the bar for "jetzt"
    DOWN_COLOR = { 0.88, 0.34, 0.29 },   -- a stat that falls (T.RED as a colour)
    -- an item's quality colour on its slot's frame (the client's item quality colours)
    QUALITY = T.QUALITY_RGB,
    -- the state colours: worn green, in bag or bank yellow, still to get grey, no target dark
    STATE_COLOR = { done = { 0.31, 0.82, 0.42 }, bag = { 1, 0.82, 0.2 }, todo = { 0.5, 0.48, 0.55 }, none = { 0.16, 0.14, 0.18 } },
    -- the empty slot art of the character frame, when the client's GetInventorySlotInfo does not say
    SLOT_ART = {
        HEAD = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Head", NECK = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Neck",
        SHOULDER = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Shoulder", BACK = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest",
        CHEST = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest", WRIST = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Wrists",
        HANDS = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Hands", WAIST = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Waist",
        LEGS = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Legs", FEET = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Feet",
        FINGER1 = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Finger", FINGER2 = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Finger",
        TRINKET1 = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket", TRINKET2 = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket",
        MAINHAND = "Interface\\PaperDoll\\UI-PaperDoll-Slot-MainHand", OFFHAND = "Interface\\PaperDoll\\UI-PaperDoll-Slot-SecondaryHand",
        RANGED = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Ranged",
    },
    -- the client's slot names for GetInventorySlotInfo
    SLOT_NAME = { HEAD = "HEADSLOT", NECK = "NECKSLOT", SHOULDER = "SHOULDERSLOT", BACK = "BACKSLOT", CHEST = "CHESTSLOT",
        WRIST = "WRISTSLOT", HANDS = "HANDSSLOT", WAIST = "WAISTSLOT", LEGS = "LEGSSLOT", FEET = "FEETSLOT",
        FINGER1 = "FINGER0SLOT", FINGER2 = "FINGER1SLOT", TRINKET1 = "TRINKET0SLOT", TRINKET2 = "TRINKET1SLOT",
        MAINHAND = "MAINHANDSLOT", OFFHAND = "SECONDARYHANDSLOT", RANGED = "RANGEDSLOT" },
    -- the doll's slots as on the character frame
    LEFT = { "HEAD", "NECK", "SHOULDER", "BACK", "CHEST", "WRIST" },
    RIGHT = { "HANDS", "WAIST", "LEGS", "FEET", "FINGER1", "FINGER2", "TRINKET1", "TRINKET2" },
    BOTTOM_ROW = { "MAINHAND", "OFFHAND", "RANGED" },
}

-- the setup assistant (UI/Setup.lua, "Amisia einrichten"): one window, one step at a time. Its
-- content keeps T.WINDOW_PAD from the left and right edge; the step line and the step's title at
-- the top, the step's rows in the middle, a status line and the red buttons at the bottom.
T.SETUP = {
    W = 560, H = 430,     -- the window (AmisiaSetupFrame)
    STEP_Y = 32,          -- the step line ("Schritt 2 von 6") below the window's top, under the title bar
    TITLE_Y = 50,         -- the step's title (gold) below the window's top
    BODY_Y = 76,          -- a step's content starts this far below the window's top
    LINE_H = 14,          -- one line of a wrapped explanation (T.FONT.text)
    ROW_H = 26,           -- a row of one setting: its label, then the controls
    ROW_GAP = 4,          -- between two parts of a step
    LABEL_W = 180,        -- the label column; the controls start LABEL_GAP after it
    LABEL_GAP = 8,
    PICK_W = 170,         -- the name pickers of step 1
    BOTTOM = 14,          -- the button row from the window's bottom edge
    STATUS_GAP = 6,       -- the status line above the button row
    NAV_W = 90,           -- the red buttons Zurück, Überspringen, Weiter, Fertig (at least; FitChip)
    CHANGE_W = 70,        -- "Ändern" on a line of the summary
    RULE_ROWS = 5,        -- loot rules listed in step 5 (then "+N weitere")
    -- the one-time offer at the first open of the main window (AmisiaSetupOffer)
    OFFER_W = 420, OFFER_H = 116, OFFER_TEXT_Y = 34,
}

-- the raid sign-up window (UI/Signup.lua, "Raid-Anmeldung", AmisiaSignupFrame): the date picker,
-- the state of the own sign-up, the role chips and the note, the hints, the three red buttons at the
-- bottom. Its content keeps T.WINDOW_PAD from the left and right edge. Compact (2.25.0): under the
-- note hint only what is shown (the other characters, the calendar hint) follows, GAP apart, and
-- the window ends BOTTOM under the button row (its height follows the content).
T.SIGNUP = {
    W = 400, H = 202,     -- the window; H without the other characters and the calendar hint
    PICK_Y = 34,          -- the date picker below the window's top, under the title bar
    STATE_Y = 62,         -- "Deine Anmeldung: ..." (T.FONT.body)
    ROLE_Y = 88,          -- the row "Rolle" with the chips T, H, N, F
    NOTE_Y = 116,         -- the row "Notiz" with the field (40 characters)
    HINT_Y = 142,         -- "Für die Gilde lesbar." under the note
    GAP = 10,             -- between the note hint, the other characters, the calendar hint and the buttons
    LINE_GAP = 4,         -- between the note hint and the other characters
    LABEL_W = 70,         -- the labels "Rolle" and "Notiz"; the controls start LABEL_GAP after them
    LABEL_GAP = 8,
    CAL_W = 130,          -- "Warum?" beside the calendar hint (the room the hint leaves it)
    BUTTON_W = 100,       -- Anmelden, Vorläufig, Abmelden (at least; FitChip)
    BOTTOM = 14,          -- the button row from the window's bottom edge
    LINE_H = 14,          -- one line of a hint (T.FONT.hint)
}

-- the raid calendar window (UI/RaidCalendar.lua, "Raid-Kalender", AmisiaRaidCalendarFrame, part I),
-- in the profession window's look (2.25.1): left the dates of the next 14 days in an inset with the
-- recipe list's ground (each row the day large, the time, the title and the own state as a badge),
-- right an inset with the chosen date's head (the event's icon, the title large and gold, the date
-- line, a badge per role with the client's role icon, the totals per status), the column heads and
-- the participants grouped by status under section bars; the status of the calendar read and the red
-- buttons at the bottom. 18 (pad) + 232 (dates) + 8 + 484 (participants) + 18 (pad) = 760.
T.RAIDCAL = {
    W = 760, H = 500,     -- the window
    TOP = 32,             -- the insets below the window's top, under the title bar
    INSET_BOTTOM = 44,    -- the insets end this far above the window's bottom: BOTTOM + BUTTON_H + 8
    INNER = 6,            -- the date list inside its inset
    -- the dates (left inset): the list is DATES_W - 2 x INNER - SCROLL_ROOM wide
    DATES_W = 232,
    DATE_ROW_H = 40,      -- a date: day and time on the first line, the title under it
    DATE_ROWS = 10,
    DATE_X = 8,           -- the date's texts from the row's left and right edge
    DAY_Y = 5,            -- the first line below the row's top (T.FONT.title: "Do 10.09.")
    TIME_GAP = 6,         -- between the day and the time (T.FONT.body)
    TITLE_Y = 23,         -- the title below the row's top (T.FONT.text)
    BADGE_H = 14,         -- the own state's badge at the first line's right end
    BADGE_PAD = 5,        -- its text from its edges
    BADGE_ALPHA = 0.22,   -- its ground: the state's colour this strong
    -- the participants (right inset, RIGHT_X from the window's left, RIGHT_W wide)
    RIGHT_X = 258,        -- 18 + 232 + 8 (the gap between the two insets)
    RIGHT_W = 484,
    PAD = 8,              -- the head, the column heads and the list from the inset's edges
    ICON = 36,            -- the event's icon at the head's top left
    TITLE_X = 52,         -- the title and the date line from the inset's left edge (PAD + ICON + 8)
    HEAD_Y = 8,           -- the title (T.FONT.big, gold) below the inset's top
    WHEN_Y = 30,          -- the date line (T.FONT.text)
    ROLES_Y = 52,         -- the role badges below the inset's top
    ROLE_ICON = 16,       -- a role badge's icon; its count and word follow ROLE_TEXT_GAP after it
    ROLE_TEXT_GAP = 4,
    ROLE_GAP = 16,        -- between two role badges
    TOTALS_Y = 74,        -- the totals per status (T.FONT.text)
    COLHEAD_Y = 94,       -- the column heads (T.LAYOUT.COLHEAD_H high)
    LIST_Y = 112,         -- the participant list
    ROW_H = 20,           -- a participant or a group's section bar
    ROWS = 15,            -- 112 + 15 x 20 = 412 of the inset's 424
    LIST_W = 456,         -- RIGHT_W - 2 x PAD - SCROLL_ROOM
    CELL_ICON = 14,       -- the role icon and the class icon in a row
    -- the participant columns { key, x, width, justify }: role (icon and letter), class icon, name
    -- (class colour), level (right), sources K/A, note (cut with the client's ellipsis, whole in the
    -- tooltip); the heads stand over the same x. The name's head covers the class icon too.
    COLS = { { "r", 4, 36 }, { "class", 44, 14 }, { "name", 62, 142 }, { "level", 206, 34, "RIGHT" },
             { "src", 250, 42 }, { "note", 298, 154 } },
    ROLE_LETTER_X = 21,   -- the role's letter after its icon (within the role column)
    EMPTY_Y = 40,         -- the empty state below the list's top
    BOTTOM = 14,          -- the button row from the window's bottom edge
    BUTTON_W = 110,       -- "Anmelden ..." / "Ändern ..." and "Zur Aufstellung" (at least; FitChip)
}

-- the page Feedback (F-130, UI/Pages/Feedback.lua): "Neue Meldung" (Bug/Wunsch, "Abschicken", the
-- hint line, the text field EDIT_H high, under it what goes along (META_H, two lines) with the counter
-- on the right, the row "Fehler anhängen", "Deine Meldungen" with OUT_ROWS rows) and, on the author's
-- characters, "Eingang" (the filter chips, a split list of IN_ROWS rows beside the detail inset)
T.FEEDBACK = {
    SEND_W = 100, RETRY_W = 70, ACTION_W = 90,
    EDIT_H = 112, COUNT_W = 60, META_H = 32, ERR_W = 120, GAP = 4, TITLE_H = 16,
    OUT_ROWS = 7, ROW_H = 20, IN_ROWS = 19,
    -- { key, x, width } of "Deine Meldungen": date, kind, the text's start, state, the button "Nochmal"
    OUT_COLS = { { "at", 6, 76 }, { "kind", 86, 54 }, { "text", 144, 266 }, { "state", 414, 100 } },
    RETRY_X = 516,
    -- the inbox (T.LAYOUT.SPLIT_LIST_W wide): kind, sender, date, the text's start
    IN_COLS = { { "kind", 6, 44 }, { "from", 52, 100 }, { "at", 154, 42 }, { "text", 198, 88 } },
}

-- the question window (W.Confirm, AmisiaConfirmFrame): the text under the title bar, wrapped, the
-- two red buttons at the bottom right; its height follows the text.
T.CONFIRM = {
    W = 440, H = 140,     -- the window (H before the text is set)
    TEXT_Y = 34,          -- the text below the window's top, under the title bar
    LINE_H = 16,          -- one line of the text (T.FONT.body)
    GAP = 12,             -- between the text and the buttons
    BUTTON_W = 100,       -- the two buttons (at least; FitChip)
    BOTTOM = 14,          -- the button row from the window's bottom edge
}

---------------------------------------------------------------------------
-- Atlases: the client's art Amisia may use (the style allow-list; the layout rules fail on any
-- other). Not on it on purpose: common-dropdown-b-button (the filter button carries a baked-in
-- arrow and looked wrong on chips), and no grey flat boxes.
---------------------------------------------------------------------------
T.ATLASES = {
    -- windows, insets, lists
    "Profession-Background-Overview", "Professions-background-summarylist", "common-insideframe",
    "Professions_Recipe_Active", "Professions_Recipe_Hover", "Professions-skillbar-bg", "Professions-skillbar-frame",
    -- the page list and the search results: the auction house's category bars (W.NavBar)
    "auctionhouse-nav-button", "auctionhouse-nav-button-select", "auctionhouse-nav-button-highlight",
    "auctionhouse-nav-button-secondary", "auctionhouse-nav-button-secondary-select",
    "auctionhouse-nav-button-secondary-highlight",
    -- fields, menus, buttons
    "common-search-border-left", "common-search-border-middle", "common-search-border-right",
    "common-dropdown-bg", "auctionhouse-ui-filter-redx",
    -- the head's settings icon (UIPanelIconDropdownButtonTemplate, Blizzard_SharedXML/Mainline, loaded on Forever)
    "questlog-icon-setting",
    "common-dropdown-a-button", "common-dropdown-a-button-hover", "common-dropdown-a-button-pressed",
    "common-dropdown-a-button-pressedhover", "common-dropdown-a-button-open", "common-dropdown-a-button-disabled",
    "common-dropdown-a-button-shadowless", "common-dropdown-a-button-hover-shadowless",
    "common-dropdown-a-button-pressed-shadowless", "common-dropdown-a-button-pressedhover-shadowless",
    "common-dropdown-a-button-open-shadowless", "common-dropdown-a-button-disabled-shadowless",
    -- the talent calculator (the client's talent window): the arrow heads of its edges and the class
    -- backgrounds; the square frames are drawn (T.TALENT), not the thick talents-node-square atlases
    -- nor the action bar's rounded rim
    "talents-arrow-head-yellow", "talents-arrow-head-gray",
    "talent-background-warrior", "talent-background-paladin", "talent-background-hunter", "talent-background-rogue",
    "talent-background-priest", "talent-background-shaman", "talent-background-mage", "talent-background-warlock",
    "talent-background-druid",
    -- the mark of an own pick in the window "Ausrüstungsziele" (the auction house's favourite star)
    "auctionhouse-icon-favorite",
    -- the map legend's quest giver mark, the dungeon and raid entrances (Gear/MapPlaces.lua)
    "QuestNormal", "Dungeon", "Raid",
    -- the side bar's symbols (T.NAV_ICONS, D-70): the money frame's gold coin
    "coin-gold",
    -- the raid calendar window: the group finder's role icons (Blizzard_UIPanelTemplates/Camelot,
    -- LFGVanilla) and its class icons (Blizzard_GroupFinder_VanillaStyle)
    "groupfinder-icon-role-large-tank", "groupfinder-icon-role-large-heal", "groupfinder-icon-role-large-dps",
    "groupfinder-icon-class-warrior", "groupfinder-icon-class-paladin", "groupfinder-icon-class-hunter",
    "groupfinder-icon-class-rogue", "groupfinder-icon-class-priest", "groupfinder-icon-class-shaman",
    "groupfinder-icon-class-mage", "groupfinder-icon-class-warlock", "groupfinder-icon-class-druid",
}
