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
T.SCROLLBAR_W = 8     -- the client's minimal scroll bar
T.SCROLLBAR_GAP = 4   -- between a list and its bar
T.SCROLL_ROOM = 12    -- what a list leaves free at its right for the bar (gap + width)
T.HOVER_ALPHA = 0.5   -- the recipe list's hover glow on rows
T.ROW_SHADE = { 0.025, 0.045 }   -- the faint shade of odd and even list rows
T.EDIT_W = 60         -- W.TimeBox without a width
T.LINE_W = 150        -- W.LineEdit, W.SearchBox, W.Picker without a width

-- the page area of the main window (the content inset less its 7 px margin)
T.PAGE_W, T.PAGE_H = 602, 478

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

-- the main window (MainFrame.lua)
T.MAIN = {
    W = 806, H = 560,
    -- the page list: up to 23 rows (4 bars, 3 gaps and 23 rows of 16 fill the 480 px); rows are 20 high and shrink (to 16 at least) when more pages than
    -- fit the 480 px list are shown (a mage officer in the expert view has 19)
    NAV_W = 164, NAV_ROWS = 23, NAV_HEADS = 4, NAV_LIST_H = 480, NAV_ROW_MIN = 16,
    NAV_ROW_H = 20, NAV_GAP = 4, NAV_INDENT = 8, NAV_ICON = 16, NAV_LABEL_X = 26, NAV_LABEL_W = 130,
    MARGIN = 6,           -- the insets from the window's edge
    TOP = 62,             -- the insets start this far below the top (title bar and status line)
    LIST_W = 176,         -- the page list's inset
    CONTENT_X = 184,      -- the content inset's left edge
    INNER = 6,            -- the page list inside its inset
    PAGE_PAD = 7,         -- the page inside the content inset
    HEAD_X = 66, HEAD_Y = 26, HEAD_H = 22,  -- the status line between the portrait and the button
    PAUSE_W = 110,
    VIEW_W = 120, VIEW_GAP = 6,  -- the view switch left of the pause button
    TAB_Y = 60, TAB_GAP = 2,                 -- the side tabs on the right edge
    TAB_ICON_INSET = 4,                      -- the side tab icon, pulled in from the tab's interior
}

-- an overview card
T.CARD = { PAD = 10, TITLE_Y = 8, LINE1_Y = 28, LINE2_Y = 48, BUTTON_W = 110, BUTTON_Y = 8 }
-- the empty state of a page: a short title (no full stop) and a sentence of help
T.EMPTY = { W = 420, H = 120, ICON = 56, ALPHA = 0.35, TITLE_GAP = 10, TEXT_GAP = 6 }
-- the shared popup menu and the picker's panel
T.MENU = { W = 182, ROW_W = 170, ROW_H = 20, PAD = 6, LABEL_W = 160, GROUND_X = 10, GROUND_Y = 3, ALPHA = 0.925 }
T.PICKER = { ROWS = 8, ROW_H = 20, MIN_W = 180, FILTER_Y = 6, LIST_Y = 30, ARROW_ROOM = 26 }
-- the talent calculator (Pages/Talents.lua) in the look of the game's classic three-tree talent
-- window: three dark panels side by side, a centred head (name over points), square icons with a
-- thin square frame, a rank plate at the lower right, straight prerequisite lines behind them
T.TALENT = {
    TREE_W = 198, TREE_GAP = 4, TREE_H = 398,   -- 3 x 198 + 2 x 4 = the page width (602)
    HEAD_H = 42,          -- the head of a tree: the name, the points under it (mouse area for the reset)
    NAME_Y = 7,           -- the name's top below the tree's top
    PTS_GAP = 2,          -- between the name and the points
    NAME_FONT = "GameFontNormalLarge",          -- the tree name: large, gold
    PTS_FONT = "GameFontHighlightSmall",        -- "N Punkte": small, white
    RANK_FONT = "NumberFontNormalSmall",        -- the rank on its plate
    RESET = 14,           -- the red reset X at the head's top right, shown while the mouse is on the head
    RESET_X = 5,          -- its distance from the tree's top right corner
    ICON = 36,            -- a talent's icon (cropped 0.07..0.93)
    CROP = 0.07,
    FRAME = 1,            -- the square frame around the icon (the button is ICON + 2 x FRAME)
    PITCH = 50,           -- button to button, across and down: 14 px between two icons
    GRID_TOP = 46,        -- the first row's top below the tree's top (under the head)
    GLOW = { 0.6, 0.35, 0.15 },  -- a maxed talent's soft glow: alpha of the rings 1, 2, 3 px outside its frame
    PLATE_W = 24, PLATE_H = 12,  -- the dark plate under the rank text
    PLATE_X = 3, PLATE_Y = -3,   -- its lower right corner from the button's: over the icon's lower right edge
    PLATE_ALPHA = 0.75,
    DIM = 0.5,            -- an unreachable talent's icon: desaturated and this bright
    LINE = 3,             -- a prerequisite line's thickness
    ARROW = 10,           -- the arrow head at the line's end, in the gap before the talent
    -- the frame per state: unreachable grey-brown, reachable the classic gold-brown, partly learned
    -- green, maxed bright gold (with the glow)
    FRAME_COLOR = { locked = { 0.36, 0.33, 0.28 }, free = { 0.66, 0.53, 0.3 }, partial = { 0.3, 0.85, 0.3 },
                    maxed = { 1, 0.82, 0 } },
    -- the rank text per state: grey, white, green, gold
    RANK_COLOR = { locked = { 0.5, 0.5, 0.5 }, free = { 1, 1, 1 }, partial = { 0.25, 1, 0.25 }, maxed = { 1, 0.82, 0 } },
    LINE_COLOR = { met = { 1, 0.82, 0, 0.9 }, unmet = { 0.3, 0.28, 0.25, 0.9 } },
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
    -- fields, menus, buttons
    "common-search-border-left", "common-search-border-middle", "common-search-border-right",
    "common-dropdown-bg", "auctionhouse-ui-filter-redx",
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
    -- the map legend's quest giver mark
    "QuestNormal",
}
