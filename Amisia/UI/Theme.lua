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
-- r, g, b (T.QUALITY_RGB, the slot frames of T.PLANNER.QUALITY too)
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
    -- the hub (D-73) in the client's own window frame (D-84: its border, title bar and red X; the hub's
    -- parts start FRAME_TOP under the top, FRAME_X in from the sides and end FRAME_BOTTOM over the
    -- bottom): 806 x 667 at its own size; the page keeps its 602 x 478 (D-69)
    W = 806, H = 667, FRAME_TOP = 22, FRAME_X = 3, FRAME_BOTTOM = 3,
    -- the client's minimize button (UIPanelHideButtonNoScripts) left of its close button (D-71)
    MIN_SIZE = 24, MIN_SIZE_OLD = 20,
    -- the size the player can drag (the grip at the bottom right, the chat window's size grabber,
    -- GRIP square in the frame's corner, GRIP_OUT past it): H_MIN to H_MAX and W_MIN to W_MAX, never
    -- more than the screen; T.PAGE_H, T.PAGE_W_NOW and the side bar follow (D-68, D-71)
    H_MIN = 667, H_MAX = 967, GRIP = 12, GRIP_OUT = -2,
    W_MIN = 806, W_MAX = 1440,
    -- the bar the minimize button leaves (D-71; MINI: in the tooltip's frame, the logo LOGO square from
    -- LOGO_X, the name and under it the open page from TEXT_X, the close button X square X_R from the right)
    MINI = { W = 214, H = 36, LOGO = 22, LOGO_X = 9, TEXT_X = 38, NAME_Y = 7, PAGE_Y = -7, X = 20, X_R = 6, TEXT_W = 140 },
    -- the head (D-73), HEAD_H high over the whole width: the logo LOGO round from LOGO_X, "Amisia"
    -- (NAME_FONT) from HEAD_TEXT_X at NAME_Y and its line at HEAD_SUB_Y; behind it the client's picture
    -- (T.HUB.BANNER) from BANNER_X to the right edge; at the right the search box (SEARCH_W) and the
    -- square feedback button (HBTN, HBTN_R from the right, HBTN_Y from the head's top; the close and
    -- minimize buttons are the client's, in its title bar, D-84)
    HEAD_H = 60, LOGO = 44, LOGO_X = 12, HEAD_TEXT_X = 66, NAME_Y = 12, HEAD_SUB_Y = 38, NAME_FONT = "GameFontNormalHuge",
    BANNER_X = 200, SEARCH_W = 180, HBTN = 24, HBTN_GAP = 6, HBTN_R = 10, HBTN_Y = 18,
    -- the tabs (D-73) under the head: TAB_H high from TAB_X, TAB_GAP apart; each its symbol (TAB_ICON
    -- square, TAB_PAD from its left edge) and its name TAB_ICON_GAP right of it, TAB_PAD room at the end;
    -- the chosen one lighter with a gold line (TAB_LINE) at its bottom; the gear tab GEAR_W wide at the
    -- right end
    TAB_H = 26, TAB_X = 6, TAB_GAP = 3, TAB_PAD = 10, TAB_ICON = 16, TAB_ICON_GAP = 5, TAB_LINE = 2, GEAR_W = 34,
    -- the side bar of the open tab (D-73): its head (NAV_HEAD high: the tab's symbol NAV_HEAD_ICON
    -- square, its name in gold from NAV_HEAD_X, the gold line at HEAD_RULE_Y), then a W.List of
    -- NAV_ROW_H rows: a page or side window its symbol (NAV_ICON square at NAV_ICON_X) and its name from
    -- NAV_SUB_X, the chosen one lighter with a gold bar (SEL_W) at its left edge; under the open page
    -- "Einstellungen" its tabs from NAV_SUB2_X and the chosen tab's sections from NAV_SUB3_X (D-49); a
    -- side window the chat window's maximize sign (FOLD square) FOLD_R from the right. NAV_LIST_H: the
    -- list's height at H (NAV_GAP under the head)
    NAV_HEAD = 40, NAV_HEAD_ICON = 28, NAV_HEAD_X = 38, HEAD_RULE_Y = 38, NAV_GAP = 4,
    NAV_W = 164, NAV_LIST_H = 474, NAV_SUB_X = 28, NAV_SUB2_X = 34, NAV_SUB3_X = 46, SEL_W = 2,
    NAV_ROW_H = 24, NAV_LABEL_X = 8, NAV_ICON = 16, NAV_ICON_X = 7, FOLD = 14, FOLD_R = 6,
    -- the search (in the head): typing turns the side bar into the results (RES_ROW_H rows: a group as
    -- a category bar, its hits as the indented sub-category bars, RES_HIT_X the hit's text as the
    -- client's 18), at least SEARCH_MIN characters, at most RES_MAX hits per group; the hint SEARCH_GAP
    -- under the list's top
    SEARCH_GAP = 6, SEARCH_MIN = 2, RES_ROWS = 22, RES_ROW_H = 21, RES_MAX = 8, RES_HIT_X = 18,
    MARGIN = 6,           -- the side bar and the page from the window's edge
    TOP = 112,            -- they start this far below the top (the title bar, the head and the tabs)
    BOTTOM = 25,          -- and end this far above the bottom (the footer and the frame)
    FOOT_H = 22,          -- the footer's height
    LIST_W = 176,         -- the side bar
    CONTENT_X = 184,      -- the page's field's left edge
    INNER = 6,            -- the side bar's parts inside it
    PAGE_PAD = 7,         -- the page inside its field
    -- the footer (D-73), BOTTOM high: the recording state from FOOT_X (a click opens the menu with the
    -- recording and the view, its arrow MENU_SIZE), the view and the version at the right end
    FOOT_X = 10, MENU_SIZE = 16,
    -- the page head (D-69, D-73) at the top of the page's field, PAGE_HEAD high: the page's symbol
    -- (PAGE_ICON square), its name (T.FONT.big, gold) PAGE_ICON_GAP right of it at TITLE_Y, its one line
    -- (T.FONT.hint) at SUB_Y, the gold line fading to both ends at RULE_Y (RULE_ALPHA at its middle); at
    -- its right end the page's help ("?") and its settings (the quest log's gear, D-49), ICON_SIZE
    -- square, ICON_GAP apart, ICON_Y from the head's top
    PAGE_HEAD = 38, TITLE_Y = 2, SUB_Y = 21, RULE_Y = 35, RULE_ALPHA = 0.7, ICON_Y = 4, PAGE_ICON = 30, PAGE_ICON_GAP = 8,
    ICON_SIZE = 22, ICON_GAP = 6,
}

-- The hub's colours (D-73): the window dark brown-black with a thin gold edge, the head a shade
-- lighter over the client's picture, the tabs and the side bar's rows; { r, g, b, a }.
T.HUB = {
    BG = { 0.065, 0.05, 0.035, 0.97 },
    EDGE = { 0.78, 0.6, 0.27, 0.9 },
    LINE = { 0.78, 0.6, 0.27, 0.35 },    -- the lines between head, tabs, side bar, page and footer
    HEAD_BG = { 0.11, 0.075, 0.045, 1 },
    SIDE_BG = { 0.09, 0.07, 0.045, 0.9 },
    TAB_BG = { 0.12, 0.09, 0.06, 0.95 },
    TAB_ON = { 0.25, 0.18, 0.09, 1 },
    TAB_EDGE = { 0.78, 0.6, 0.27, 0.45 },
    BTN_BG = { 0.07, 0.05, 0.03, 0.95 },
    ROW_HOVER = { 1, 0.85, 0.5, 0.07 },
    ROW_ON = { 0.85, 0.62, 0.2, 0.2 },
    -- the client's picture behind the head: a band of a loading screen (coords), BANNER alpha, fading
    -- in from the left over FADE px; without the file the head stays plain
    BANNER = { file = "Interface\\Glues\\LoadingScreens\\LoadScreenKalimdor", coords = { 0, 1, 0.36, 0.47 }, alpha = 0.6, FADE = 160 },
}

-- The symbol of each page and side window in the side bar and of each tab (D-81, before it the
-- client's marks of D-70): Amisia's own gold line art, Media/Icons/ui/<key>.tga, drawn by
-- tools/make_ui_icons.py from Lucide (ISC); never a spell or item icon in their place. { file = path,
-- own = true } (own: shipped with the addon, so not looked up in the client's files) or { atlas = name };
-- a key not here: no symbol.
local function own(key) return { file = "Interface\\AddOns\\Amisia\\Media\\Icons\\ui\\" .. key, own = true } end
T.NAV_ICONS = {
    overview = own("overview"),
    lineup = own("lineup"),
    raidcheck = own("raidcheck"),
    softres = own("softres"),
    rolls = own("rolls"),
    awards = own("awards"),
    raidlog = own("raidlog"),
    points = own("points"),
    stats = own("stats"),
    raids = own("raids"),
    export = own("export"),
    planner = own("planner"),
    gear = own("gear"),
    talents = own("talents"),
    professions = own("professions"),
    scrolls = own("scrolls"),
    dungeons = own("dungeons"),
    raidjournal = own("raidjournal"),
    quests = own("quests"),
    map = own("map"),
    members = own("members"),
    calendar = own("calendar"),
    bank = own("bank"),
    duels = own("duels"),
    tools = own("tools"),
    settings = own("settings"),
    about = own("about"),
    feedback = own("feedback"),
    ["win:talents"] = own("win_talents"),
    ["win:rolls"] = own("win_rolls"),
    ["win:softres"] = own("win_softres"),
}

-- The symbol of each tab (D-73, D-81), the same gold line art as the side bar's.
T.TAB_ICONS = {
    gear = own("tab_gear"), dungeons = own("tab_dungeons"), prof = own("tab_prof"), talents = own("tab_talents"),
    raid = own("tab_raid"), guild = own("tab_guild"), amisia = own("tab_amisia"),
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

-- The loot toast (F-152, D-79): its lines W wide in a holder H high, CENTER of the screen moved by X, Y
-- (left of and above the character); the text in FONT at the set size (toast.size, SIZE by
-- default, SIZE_MIN to SIZE_MAX), the icon that size + ICON_PAD square, GAP right of it the text, a
-- line that size + LINE_PAD high, SPACE apart; shown SHOW seconds, in over FADE_IN, out over the last
-- FADE_OUT, risen RISE px by then; at most MAX at once.
T.LOOTTOAST = {
    W = 360, H = 240, X = -120, Y = 110, SPACE = 2, GAP = 4, FONT = "GameFontNormalLarge",
    SIZE = 16, SIZE_MIN = 10, SIZE_MAX = 32, LINE_PAD = 6, ICON_PAD = 4,
    SHOW = 3, FADE_IN = 0.2, FADE_OUT = 0.8, RISE = 30, MAX = 6,
    -- the settings of F-158: the time shown (s), the lines at once, the opacity (%)
    SHOW_MIN = 1, SHOW_MAX = 10, MAX_MIN = 1, MAX_MAX = 12, ALPHA_MIN = 20,
    -- the client's own fonts to choose ("default": the font object's)
    FONTS = { friz = "Fonts\\FRIZQT__.TTF", arial = "Fonts\\ARIALN.TTF", skurri = "Fonts\\SKURRI.TTF",
              morpheus = "Fonts\\MORPHEUS.TTF" },
    -- while it is moved: a dark ground with a gold edge, the hint, "Fertig" (F-158)
    MOVE_BG = { 0, 0, 0, 0.55 }, MOVE_EDGE = { 0.78, 0.6, 0.27, 0.9 }, DONE_W = 70,
}

-- The start of Dungeons and Raids as a table (F-148, D-74): rows ROW_H high (the list's 1 px between),
-- the instance's picture ART_W x ART_H at ART_X with a thin gold frame, its name (gold) and a grey line
-- under it from NAME_X; the columns right of the name WIDTH wide each, GAP apart, the last at the
-- list's right end; the name takes the rest. A level range's group row: the quest log's plus or minus
-- (SIGN square at SIGN_X), its name from GROUP_X, the count at the right. The territory's crest SIDE
-- square, a key's icon KEY square, the action's button ACT square. MIN_ROWS rows at least.
T.DTABLE = {
    ROW_H = 38, ART_X = 2, ART_W = 84, ART_H = 32, NAME_X = 92, NAME_Y = 8, SUB_Y = -9, GAP = 6, MIN_ROWS = 4,
    SIGN = 14, SIGN_X = 6, GROUP_X = 26, SIDE = 22, KEY = 16, ACT = 22,
    WIDTH = { level = 50, side = 42, zone = 100, keys = 50, quests = 46, act = 44, size = 50 },
    GROUP_BG = { 0.18, 0.13, 0.07, 0.9 }, EDGE = 0.45, HERE = { 0.31, 0.82, 0.42 },
}

-- The journal's detail parts (D-72, Pages/Dungeons.lua and RaidJournal.lua): the run in the header's
-- line (RUN: "1/4" TEXT_W wide, then the bar BAR_W x BAR_H), the instance map (MAP: the floor row
-- BAR_H high with its arrows ARROW square, the map under it GAP lower, zoom 1 to ZOOM_MAX by WHEEL a
-- notch, the player's arrow PIN square), the keys (ACCESS: rows ROW_H with the item's icon ICON
-- square, steps indented STEP_X, the state right STATE_W wide)
T.DPART = {
    RUN = { W = 124, H = 14, TEXT_W = 40, BAR_W = 80, BAR_H = 6 },
    MAP = { BAR_H = 22, ARROW = 18, LABEL_W = 260, GAP = 4, ZOOM_MAX = 6, WHEEL = 1.25, PIN = 16, HINT_W = 220 },
    ACCESS = { ROW_H = 22, ICON = 16, TEXT_X = 24, STEP_X = 24, STATE_W = 110 },
    -- the part Zeiten (F-166): rows ROW_H high, four cells at X with widths W (the first from TEXT_X)
    TIMES = { ROW_H = 22, X = { 4, 220, 330, 440 }, W = { 210, 104, 104, 130 } },
}

-- The run timer window (F-166, Gear/RunTimer.lua, AmisiaRunTimer): W wide, the content PAD from the
-- edges and TOP under the window's top; the total in the big font (TOTAL_H), a hint line (LINE_H),
-- one row per boss (ROW_H: name NAME_W, the split SPLIT_W and the difference DIFF_W at the right end),
-- the result line and the link at the bottom (BOTTOM_H); at most MAX_ROWS bosses; the live total is
-- drawn every TICK seconds.
T.RUNTIMER = { W = 260, PAD = 12, TOP = 30, TOTAL_H = 22, LINE_H = 16, ROW_H = 16, NAME_W = 132, SPLIT_W = 44, DIFF_W = 44,
    GAP = 4, BOTTOM_H = 40, MAX_ROWS = 16, TICK = 0.2 }

-- the part Übersicht of the detail views of Dungeons and Raids (F-154, D-85): left the bosses (LIST_W
-- wide with the list's bar, rows ROW_H high: the boss's model PORTRAIT square at PORT_X on a black
-- disc in the gold RING, "n. Name" from TEXT_X over its grey line), GAP, right the chosen boss: its head
-- HEAD_H high (the portrait HEAD_PORT square at HEAD_PORT_X, its name and line from HEAD_TEXT_X), its
-- loot under it, GAP apart (rows LOOT_H high: the item's icon ICON square at ICON_X in its quality's
-- rounded ring, the name over "slot · gain" from LOOT_TEXT_X, the drop rate RATE_W and the wish star
-- STAR square at the right end, END apart). A boss the client shows no model of: the client's skull
-- (NO_MODEL). MIN_ROWS: rows of each list at least.
T.DBOSS = {
    LIST_W = 212, GAP = 8, MIN_ROWS = 3,
    ROW_H = 44, PORTRAIT = 36, PORT_X = 4, TEXT_X = 46, NAME_Y = -7, SUB_Y = -24,
    HEAD_H = 52, HEAD_PORT = 44, HEAD_PORT_X = 4, HEAD_TEXT_X = 56, HEAD_NAME_Y = -8, HEAD_SUB_Y = -30,
    LOOT_H = 36, ICON = 28, ICON_X = 4, LOOT_TEXT_X = 40, LOOT_NAME_Y = -4, LOOT_SUB_Y = -20,
    RATE_W = 72, STAR = 16, END = 6,
    ZOOM = 0.9,                -- the model's portrait zoom (head and shoulders)
    RING = "Interface\\AddOns\\Amisia\\Media\\Icons\\ui\\boss_ring",
    NO_MODEL = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull",
    HEAD_BG = { 0, 0, 0, 0.35 },
}

T.PROFPAGE = {
    SEARCH_W = 190, RANK_W = 120,
    STEP_ROWS = 9, STEP_H = 36, TICK = 14, MARK_X = 4, TEXT_X = 22, LINE1_Y = -4, LINE2_Y = -19, COST_W = 80,
    TICK_TEX = "Interface\\RaidFrame\\ReadyCheck-Ready",
    SHOP_ROWS = 14, SHOP_H = 22,
    -- material, need, have, the other own characters, missing, price of one, source
    SHOP_COLS = { { "name", 4, 170 }, { "need", 178, 40, justify = "RIGHT" }, { "have", 222, 40, justify = "RIGHT" },
                  { "twinks", 266, 44, justify = "RIGHT" }, { "miss", 314, 40, justify = "RIGHT" },
                  { "price", 358, 64, justify = "RIGHT" }, { "src", 430, 148 } },
    -- the overview (F-151, D-78): section heads SEC_H high (gold text, a gold line SEC_LINE_GAP after
    -- it fading to the right at SEC_LINE_A), SEC_GAP over each after the first; cards CARD_H high in
    -- columns of at least CARD_MIN_W (CARD_COLS_MIN to CARD_COLS_MAX of them, CARD_GAP apart; the wide
    -- cards of "Weiteres" WIDE_COLS per row): the dark ground (CARD_BG), a thin border (CARD_EDGE), the
    -- profession's icon CARD_ICON square at CARD_PAD, the name (CARD_NAME_FONT, gold) and its line
    -- (CARD_SUB_FONT) from CARD_TEXT_X, CARD_PAD from the right; four fit the page's 590 px (D-78)
    CARD_H = 44, CARD_MIN_W = 140, CARD_COLS_MIN = 4, CARD_COLS_MAX = 6, CARD_GAP = 6, WIDE_COLS = 2,
    CARD_ICON = 26, CARD_PAD = 6, CARD_TEXT_X = 38, CARD_NAME_Y = -9, CARD_SUB_Y = -24,
    CARD_NAME_FONT = "GameFontNormalSmall", CARD_SUB_FONT = "GameFontHighlightSmall",
    -- "Nächste Lehrer" (D-78): a framed table of TRAINER_COLS cells a row, TRAINER_H high: the icon
    -- TRAINER_ICON square at TRAINER_PAD, the name (gold) and "Name, Zone" from TRAINER_TEXT_X, the map
    -- button TRAINER_BTN square TRAINER_PAD from the cell's right; the frame TRAINER_EDGE
    TRAINER_COLS = 3, TRAINER_H = 36, TRAINER_ICON = 24, TRAINER_PAD = 6, TRAINER_TEXT_X = 36, TRAINER_BTN = 18,
    TRAINER_NAME_Y = -5, TRAINER_LINE_Y = -20, TRAINER_EDGE = { 0.85, 0.7, 0.35, 0.5 },
    MAP_ART = "Interface\\WorldMap\\UI-World-Icon",
    -- the recipe view (D-82). The head band (HEAD_LINES lines): the profession's icon HEAD_ICON square
    -- in the rounded ring, the title and the lines from HEAD_TEXT_X, at the right the legend LEGEND_W
    -- wide (DOT square marks: the client's yellow and green indicator)
    HEAD_LINES = 3, HEAD_ICON = 40, HEAD_TEXT_X = 48, LEGEND_W = 150, DOT = 8, DOT_GAP = 4, LEGEND_GAP = 10,
    DOT_ME = "Interface\\COMMON\\Indicator-Yellow", DOT_GUILD = "Interface\\COMMON\\Indicator-Green",
    -- the filter menu's button (Amisia's own funnel, D-81) and its flyout (FLY_PAD inside, FLY_GAP under it)
    FILTER_BTN = 20, FILTER_ICON = "Interface\\AddOns\\Amisia\\Media\\Icons\\ui\\prof_filter", FLY_PAD = 6, FLY_GAP = 2,
    -- the list LIST_W wide, rows ROW_H high (at least ROWS): the thin frame ROW_EDGE (gold when chosen),
    -- the difficulty bar ROW_BAR_W at the left edge, the item's icon ROW_ICON square at ROW_ICON_X in
    -- the rounded ring, the name from ROW_TEXT_X; at the right the skill (ROW_RANK_W), the dots "kann
    -- ich" and "Gilde" (DOT_ME_R, DOT_GUILD_R from the right), the tag or upgrade mark (ROW_MARK_W,
    -- ROW_MARK_R from the right)
    LIST_W = 318, DETAIL_X = 334, ROW_H = 34, ROWS = 8, ROW_EDGE = { 0.4, 0.36, 0.28, 0.55 }, ROW_BAR_W = 3,
    ROW_ICON = 24, ROW_ICON_X = 8, ROW_TEXT_X = 38, ROW_RANK_W = 30, DOT_ME_R = 52, DOT_GUILD_R = 40,
    ROW_MARK_W = 50, ROW_MARK_R = 64,
    -- the recipe's detail: the icon RD_ICON at RD_PAD, title and quiet line from RD_TITLE_X, the star
    -- (Amisia's own, STAR square, STAR_OFF alpha while off) at the top right; the boxes from RD_BODY_Y in
    -- a scroll frame, RD_BOX_GAP apart (RD_BOX_PAD inside, head RD_HEAD_H, controls RD_CTRL_H, reagent
    -- rows RD_REAG_H with their icon RD_REAG_ICON; the guild's box tinted RD_GUILD_BG)
    RD_PAD = 8, RD_ICON = 32, RD_TITLE_X = 46, RD_TITLE_Y = -9, RD_SUB_Y = -28, RD_BODY_Y = 46,
    STAR = 18, STAR_ICON = "Interface\\AddOns\\Amisia\\Media\\Icons\\ui\\prof_star", STAR_OFF = 0.3,
    RD_BOX_GAP = 6, RD_BOX_PAD = 6, RD_HEAD_H = 16, RD_LINE_H = 12, RD_CTRL_H = 22, RD_REAG_H = 18, RD_REAG_ICON = 16,
    RD_COUNT_W = 70, RD_HAVE_W = 64, RD_BOX_BG = { 0, 0, 0, 0.3 }, RD_GUILD_BG = { 0.25, 0.75, 0.25, 0.1 },
    -- the crafting list: its list LIST_W wide (QUEUE_DEL_W for "Entfernen"), the reagents beside it
    -- (two lines each, NEED_H high: name and have/need, the source under it)
    NEED_H = 34, NEED_HAVE_W = 70, QUEUE_N_W = 40,
    -- the menu "Woher?" of a reagent (F-160): wide enough for "Händler: name, zone 42, 65 · 1g 20s"
    WHERE_W = 360,
    ICON_COORDS = { 0.07, 0.93, 0.07, 0.93 },   -- a profession's icon without the client's icon frame
    CARD_BG = { 0, 0, 0, 0.45 }, CARD_EDGE = { 0.45, 0.4, 0.3, 0.6 }, CARD_HOVER = 0.08,
    SEC_H = 22, SEC_GAP = 10, SEC_LINE_GAP = 8, SEC_LINE_A = 0.6,
    -- the marks of the side bar besides the professions (their own client icons, D-75): the overview,
    -- the camp objects and the Merchant's Favor; the same art on the cards of "Weiteres"
    MARK_ICONS = { overview = { file = "Interface\\GossipFrame\\TrainerGossipIcon" },
        camp = { file = "Interface\\GossipFrame\\BinderGossipIcon" }, favor = { atlas = "coin-gold" } },
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
T.LINEUP_MORE_W = 210   -- the menu "Mehr" of the page Aufstellung (F-161)
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
    -- a tree (D-76): a thin gold-brown frame, a dark ground and over it its part of the client's class
    -- art (talent-background-<class>, cut to the tree's shape) at BG_ALPHA
    TREE_EDGE = { 0.55, 0.42, 0.2, 1 },
    TREE_GROUND = { 0.03, 0.03, 0.04, 0.9 },
    BG_ALPHA = 0.6,
    -- the line over the trees: "Stufe: 60 · Verfügbar: 51 · Verteilt: 0 · Übrig: 51", the four parts
    -- spread over the width, the names gold, the numbers white (red when the plan wants more)
    STAT_FONT = "GameFontNormal",
    -- the side bar's action marks of the page (D-75, D-76): client marks only, no spell or item icons
    MARKS = {
        live = { file = "Interface\\GossipFrame\\TrainerGossipIcon" },
        reset = { file = "Interface\\GossipFrame\\UnlearnGossipIcon" },
        import = { file = "Interface\\Buttons\\UI-GuildButton-OfficerNote-Up" },
        export = { file = "Interface\\Buttons\\UI-GuildButton-PublicNote-Up" },
    },
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
        HINT_W = 160,         -- "Linksklick + · Rechtsklick -" at the bottom row's right end
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


-- the page "Ausrüstungsplaner" (UI/Pages/Planner.lua, F-149, D-77): left a panel over the page's height
-- (the dressing room's background of the own race, else of another race, darkened by SHADE), its
-- width LEFT_RATIO of the page between LEFT_MIN and LEFT_MAX (it grows with the window, D-71): at its
-- top in the head row "Name Stufe N ·" and the spec picker (SPEC_W), centred; the doll (DOLL, the
-- goals window's builder) DOLL_Y under the page's top, PAD from the panel's edges, as wide as the
-- panel, each enchantable slot with its square (ENCH, ENCH_GAP beside it towards the model; above a
-- weapon); "Zurücksetzen" PAD from the panel's lower right corner. Right of it, GAP apart, the head
-- row's tabs Vorschläge | Wunschliste, the warning, "Quellen" (the source switches as a menu) and the
-- search box (filling); under them the slot's name, "Stufe [lo] - [hi]" (LEVEL_W boxes) and Meine
-- Stufe | Alle; the list down to the page's bottom (ROW_H rows: the icon ROW_ICON in its quality's
-- frame, the name over "Stufe N · source" from TEXT_X, at the right end the gain GAIN_W, the source's
-- symbol and the wish star, SRC and STAR square, END apart). At 602: 240 + 8 + 354; the doll 30 + 332
-- + 22 + 38 = 422 of 478, the switch Ziele | Angelegt 426 to 446, score and "Zurücksetzen" from 448.
T.PLANNER = {
    LEFT_RATIO = 0.4, LEFT_MIN = 240, LEFT_MAX = 520,
    GAP = 8, PAD = 8, DOLL_Y = 30,
    SHADE = { 0, 0, 0, 0.45 },            -- over the race's background
    GROUND = { 0.03, 0.045, 0.03, 0.95 },  -- the panel's ground without the background (and under it)
    -- the client's dressing room background (FrameXML DressUpFrame: 4 parts, 256 + 62 wide, 255 + 128
    -- high): PATH .. race token .. 1 to 4, the own race first, then RACES in turn
    BG = { PATH = "Interface\\DressUpFrame\\DressUpBackground-", RACES = { "NightElf", "Human", "Dwarf", "Gnome", "Orc", "Tauren",
        "Troll", "Scourge" }, W = { 256, 62 }, H = { 255, 128 },
        COORDS = { { 0, 1, 0, 255 / 256 }, { 0, 62 / 64, 0, 255 / 256 }, { 0, 1, 0, 1 }, { 0, 62 / 64, 0, 1 } } },
    SPEC_W = 124, WHO_GAP = 6,
    -- the doll (UI/GearDoll.lua buildDoll): 8 slots left and right as on the character frame (the
    -- shirt and the tabard only show what is worn), the model between, the weapons under it with their
    -- enchant squares above them; DOLL_W at the narrowest panel (SetDollWidth follows the panel)
    DOLL = {
        DOLL_W = 224, SLOT = 38, SLOT_GAP = 4, SLOT_INSET = 2, DOT = 10,
        -- the slot's thin rounded ring and the rounded mask of its icon (Amisia's own, D-81 Nachtrag)
        SLOT_RING = "Interface\\AddOns\\Amisia\\Media\\Icons\\ui\\slot_ring",
        SLOT_MASK = "Interface\\AddOns\\Amisia\\Media\\Icons\\ui\\slot_mask",
        MODEL_GAP = 20,       -- the enchant square and 4 px between a slot column and the model
        MODEL_H = 332,        -- 8 slots and their gaps
        MODEL_SHADE = 0.2,    -- the inset's ground under the model
        WEAPON_GAP = 22,      -- the weapons' enchant squares (ENCH + ENCH_GAP) and 6 px
        BOTTOM_GAP = 8,       -- between two weapons
        ROTATE = 0.012, ZOOM_STEP = 0.1, ZOOM_MAX = 0.8,
        LEFT = { "HEAD", "NECK", "SHOULDER", "BACK", "CHEST", "SHIRT", "TABARD", "WRIST" },
        RIGHT = { "HANDS", "WAIST", "LEGS", "FEET", "FINGER1", "FINGER2", "TRINKET1", "TRINKET2" },
        BOTTOM_ROW = { "MAINHAND", "OFFHAND", "RANGED" },
    },
    -- under the doll (D-80): the switch Ziele | Angelegt centred SWITCH_GAP under the weapons, at the
    -- bottom left the score ("Wertung 350 · +130", SCORE_W at most) over its bar (SCORE_BAR_H, the
    -- line at "jetzt" MARK_W), "Zurücksetzen" at the right
    SWITCH_GAP = 4, SCORE_BAR_H = 3, MARK_W = 2,
    SCORE_BAR = { 0.31, 0.82, 0.42, 0.9 }, SCORE_BAR_BG = { 0, 0, 0, 0.5 },
    DOWN_COLOR = { 0.88, 0.34, 0.29 },   -- a stat that falls (T.RED as a colour)
    -- the tab Ziele (D-80): "4/17 Ziele" over the bar of 17 parts (PROG_W wide, BAR_H high) in the
    -- second row, the filters right of it
    PROG_W = 78, BAR_H = 3, BAR_PART_GAP = 1,
    -- the line "Deine Wahl" over the suggestions: the red X (T.RESET) and "Übernehmen" at its right end
    TAKE_W = 76,
    ENCH = 14, ENCH_GAP = 2,
    ENCH_ROWS = 8,        -- the enchantments in a square's menu
    RESET_W = 110,
    LEVEL_W = 30,         -- "Stufe [1] - [33]": the two boxes
    ROW_H = 52, ROW_ICON = 34, ROW_EDGE = 1, ICON_X = 6, TEXT_X = 48, NAME_Y = -9, SUB_Y = -29,
    GAIN_W = 52, SRC = 18, STAR = 16, END = 6,
    MIN_ROWS = 4,
    RANK_N = 40,          -- the suggestions of a slot at most (the slot's ranking)
    QUEST_MARK = "|cffffd100!|r",          -- after the name of a quest reward
    STAR_OFF = { 0.42, 0.42, 0.42 },       -- the star of an item not on the wish list
    STAR_ATLAS = "auctionhouse-icon-favorite", STAR_FILE = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1",
    WARN = { file = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew" }, WARN_SIZE = 18,
    -- the source switches of the gear page in the menu "Quellen", in this order
    SOURCES = { "X", "D", "Q", "C", "V", "P", "W", "A" },
    -- the symbol of a source's kind (the gear data's letters): the client's marks; a crafted item the
    -- profession's own icon (ns.Prof.ICONS, D-75)
    SRC_ICONS = {
        X = { atlas = "Raid" }, D = { atlas = "Dungeon" }, Q = { file = "Interface\\GossipFrame\\AvailableQuestIcon" },
        C = { file = "Interface\\Minimap\\Tracking\\Profession" }, V = { file = "Interface\\GossipFrame\\VendorGossipIcon" },
        A = { file = "Interface\\Minimap\\Tracking\\Auctioneer" }, P = { file = "Interface\\GossipFrame\\BattleMasterGossipIcon" },
        R = { file = "Interface\\GossipFrame\\TabardGossipIcon" }, W = { file = "Interface\\Minimap\\Tracking\\None" },
    },
    ICON_COORDS = { 0.07, 0.93, 0.07, 0.93 },   -- a profession's icon without its frame
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
        -- the shirt and the tabard: only on the planner's doll
        SHIRT = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Shirt", TABARD = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Tabard",
    },
    -- the client's slot names for GetInventorySlotInfo
    SLOT_NAME = { HEAD = "HEADSLOT", NECK = "NECKSLOT", SHOULDER = "SHOULDERSLOT", BACK = "BACKSLOT", CHEST = "CHESTSLOT",
        WRIST = "WRISTSLOT", HANDS = "HANDSSLOT", WAIST = "WAISTSLOT", LEGS = "LEGSSLOT", FEET = "FEETSLOT",
        FINGER1 = "FINGER0SLOT", FINGER2 = "FINGER1SLOT", TRINKET1 = "TRINKET0SLOT", TRINKET2 = "TRINKET1SLOT",
        MAINHAND = "MAINHANDSLOT", OFFHAND = "SECONDARYHANDSLOT", RANGED = "RANGEDSLOT", SHIRT = "SHIRTSLOT", TABARD = "TABARDSLOT" },

    -- the side bar's marks: the catalog's categories (Gear/Catalog.lua) with the client's marks
    MARKS = { "raid", "dungeon", "pvp", "craft", "world", "rep" },
    MARK_ICONS = {
        raid = { atlas = "Raid" }, dungeon = { atlas = "Dungeon" }, pvp = { file = "Interface\\GossipFrame\\BattleMasterGossipIcon" },
        craft = { file = "Interface\\Minimap\\Tracking\\Profession" }, world = { file = "Interface\\Minimap\\Tracking\\FlightMaster" },
        rep = { file = "Interface\\GossipFrame\\TabardGossipIcon" },
    },
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
