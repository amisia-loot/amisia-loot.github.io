-- The author's channels (D-108): two symbols at the right end of the main window's footer, Twitch
-- then Discord, the view and the version left of them; a click shows the link in a small window,
-- marked to copy; typing puts the link back, Enter and Escape close it.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
NS.Dispatch("")
local F = _G.AmisiaFrame
assert(F and F:IsShown(), "the main window")
local T = NS.Theme
assert(#T.LINKS == 2 and T.LINKS[1].key == "twitch" and T.LINKS[2].key == "discord")
local tw, dc = F.links.twitch, F.links.discord
assert(tw and dc and tw:IsShown() and dc:IsShown(), "both symbols")
assert(tw.points.BOTTOMRIGHT and dc.points.BOTTOMRIGHT and F.viewText.points.BOTTOMRIGHT, "at the footer's right end")
-- Discord outermost, Twitch left of it, the text left of both
local function right(f) return -f.points.BOTTOMRIGHT.x end
assert(right(dc) < right(tw) and right(tw) < right(F.viewText), "the order from the right: Discord, Twitch, the text")
assert(has(tw.icon.texture or tw.icon:GetTexture(), "twitch") and has(dc.icon.texture or dc.icon:GetTexture(), "discord"))

-- a click: the link to copy
tw:Click()
local w = _G.AmisiaLinkFrame
assert(w and w:IsShown() and w.box:GetText() == "https://www.twitch.tv/mrvulo", w and w.box:GetText())
assert(has(w.text:GetText(), "Strg+C") or has(w.text:GetText(), "Ctrl+C"), w.text:GetText())
-- typing puts the link back
w.box:SetText("etwas anderes")
w.box:GetScript("OnTextChanged")(w.box, true)
assert(w.box:GetText() == "https://www.twitch.tv/mrvulo", "the link again")
-- the other symbol replaces it
dc:Click()
assert(w:IsShown() and w.box:GetText() == "https://discord.gg/mxhvFBSXSf", w.box:GetText())
-- Escape and Enter close it
w.box:GetScript("OnEscapePressed")(w.box)
assert(not w:IsShown(), "Escape closes")
dc:Click()
w.box:GetScript("OnEnterPressed")(w.box)
assert(not w:IsShown(), "Enter closes")
print("links ok")
