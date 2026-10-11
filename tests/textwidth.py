"""How wide the client draws a text: an estimate on the safe side, shared by the test stub
(FontString:GetStringWidth, through run.py) and the layout rules of tools/ui_layout.py.

The width is the sum of per-character advances in em (close to Friz Quadrata, the client's UI face,
rounded up) times the font object's size, times the locale's factor. Colour and link codes take no
room, a texture code its size.
"""
import re

# Font objects of the Forever client: size in px and whether the face is narrow (Arial Narrow).
FONTS = {
    'GameFontNormal': (12, False), 'GameFontHighlight': (12, False), 'GameFontDisable': (12, False),
    'GameFontNormalSmall': (10, False), 'GameFontHighlightSmall': (10, False), 'GameFontDisableSmall': (10, False),
    'GameFontNormalLarge': (16, False), 'GameFontHighlightLarge': (16, False), 'GameFontNormalMed3': (14, False),
    'NumberFontNormalSmall': (12, True), 'NumberFontNormal': (14, True), 'ChatFontNormal': (14, True), 'Game15Font_Shadow': (15, False),
}
DEFAULT_FONT = (12, False)

_W = {}
for _ch in " .,;:'!|ilj`":
    _W[_ch] = 0.28
for _ch in '()[]{}"/\\-':
    _W[_ch] = 0.36
for _ch in 'ftrIJ':
    _W[_ch] = 0.38
for _ch in '0123456789':
    _W[_ch] = 0.57
for _ch in 'mM':
    _W[_ch] = 0.88
for _ch in 'wW':
    _W[_ch] = 0.82
_W.update({'W': 0.96, '%': 0.8, '@': 0.9, '·': 0.3, '…': 0.8, '+': 0.6})
LOWER, UPPER, OTHER = 0.55, 0.70, 0.62
NARROW = 0.82   # Arial Narrow against Friz Quadrata
BASE = {'ä': 'a', 'ö': 'o', 'ü': 'u', 'Ä': 'A', 'Ö': 'O', 'Ü': 'U', 'ß': 'B', 'é': 'e', 'è': 'e', 'á': 'a'}

CODE = re.compile(r'\|c[0-9a-fA-F]{8}|\|r|\|H[^|]*\|h|\|h|\|T([^|]*)\|t|\|A([^|]*)\|a|\|n')


def plain(text):
    """The text as the client draws it, colour and link codes out, each texture or atlas code as one
    NUL character; and the sizes of those (px or None). "||" is one bar."""
    extra = []

    def sub(m):
        spec = m.group(1) if m.group(1) is not None else m.group(2)
        if spec is None:
            return ''
        size = None
        for p in spec.split(':')[1:3]:
            try:
                size = float(p)
                break
            except ValueError:
                pass
        extra.append(size)
        return '\x00'
    return CODE.sub(sub, str(text if text is not None else '')).replace('||', '|'), extra


def font_size(font):
    return FONTS.get(font or '', DEFAULT_FONT)[0]


def text_width(text, font, factor=1.0):
    """The estimated width in px of the widest line of text in font (a font object's name)."""
    size, narrow = FONTS.get(font or '', DEFAULT_FONT)
    s, extra = plain(text)
    icons = iter(extra)
    best = 0.0
    for line in s.split('\n'):
        w = 0.0
        for ch in line:
            if ch == '\x00':
                px = next(icons, None)
                w += (px or size) + 2
                continue
            base = BASE.get(ch, ch)
            em = _W.get(base)
            if em is None:
                em = LOWER if base.islower() else UPPER if base.isupper() else OTHER
            w += em * size * (NARROW if narrow else 1.0)
        best = max(best, w)
    return best * factor


def wrap_lines(text, font, width, factor=1.0):
    """How many lines text takes at width when the client wraps it at spaces."""
    s, _ = plain(text)
    n = 0
    for para in s.split('\n'):
        line = ''
        n += 1
        for word in para.split(' '):
            cand = (line + ' ' + word) if line else word
            if line and text_width(cand, font, factor) > width:
                n += 1
                line = word
            else:
                line = cand
    return n
