"""The lazy form of the addon's big generated data files.

A generated file ends in `ns.KEY = { ... }`. lazy() turns that into

    ns.LazyData("KEY", [==[
    return { ... }
    ]==], N)

(the long string's level chosen so no "]==]" inside ends it; N the number of entries the generator
counted, which the addon's availability checks read without building the table), so the addon keeps
only the text at login and builds the table on first use (Core/LazyData.lua). eager() turns it
back, for the tools and tests that read a data file with plain Lua (`ns.KEY = { ... }` again, the
same lines); load() runs a data file the way the addon would and builds its tables at once.
"""
import re

LAZY = re.compile(r'^ns\.LazyData\("([A-Z_]+)", \[(=*)\[\nreturn (\{.*?\})\n\]\2\](?:, \d+)?\)\n', re.S | re.M)


PUNCT = set(',;{}()[]=')


def compact(body):
    """A table's Lua source without the blanks the parser does not need: no indentation, no blank
    next to , ; { } ( ) [ ] =; strings, comments and line breaks stay as they are (a diff of a data
    file still shows one entry per line). The text is what the client holds at login, so every byte
    counts there."""
    out = []
    i, n = 0, len(body)
    pending = False   # a run of blanks waits: kept as one only between two other characters
    while i < n:
        c = body[i]
        if c in ' \t':
            pending = True
            i += 1
            continue
        if pending:
            prev = out[-1][-1] if out and out[-1] else '\n'
            join = prev + c
            if prev not in PUNCT and prev != '\n' and c not in PUNCT and c != '\n' or join in ('[[', ']]', '--'):
                out.append(' ')
            pending = False
        if c in '"\'':
            j = i + 1
            while j < n and body[j] != c:
                if body[j] == '\\':
                    j += 1
                elif body[j] == '\n':
                    raise ValueError('a string runs over a line end')
                j += 1
            out.append(body[i:j + 1])
            i = j + 1
        elif body.startswith('--', i):
            j = body.find('\n', i)
            j = n if j < 0 else j
            out.append(body[i:j])
            i = j
        elif c == '[' and body[i + 1:i + 2] in ('[', '='):
            m = re.match(r'\[(=*)\[', body[i:])
            if not m:
                out.append(c)
                i += 1
                continue
            end = body.find(']' + m.group(1) + ']', i)
            if end < 0:
                raise ValueError('a long string without its end')
            end += len(m.group(1)) + 2
            out.append(body[i:end])
            i = end
        else:
            out.append(c)
            i += 1
    return ''.join(out)


def lazy(text, key, n=None):
    """text (a generated file with `ns.<key> = {` at the start of a line, the table to the end) in
    the lazy form; n, the number of entries, rides along when given."""
    head = f'ns.{key} = {{'
    m = re.search(r'^' + re.escape(head) + r'$', text, re.M)
    if not m:
        raise ValueError(f'no "{head}" line in the generated text')
    body = text[m.start() + len(f'ns.{key} = '):].rstrip('\n')
    if not body.endswith('}'):
        raise ValueError(f'the table of ns.{key} does not end the text')
    body = compact(body)
    # level 1 at least: Lua 5.1 refuses a "[[" inside a level-0 long string ("nesting of [[...]] is
    # deprecated"), and a quest or recipe name may hold one some day
    level = 1
    while (']' + '=' * level + ']') in body:
        level += 1
    eq = '=' * level
    size = f', {int(n)}' if n is not None else ''
    return text[:m.start()] + f'ns.LazyData("{key}", [{eq}[\nreturn {body}\n]{eq}]{size})\n'


def eager(text):
    """A data file's text with every lazy table written out again as `ns.KEY = { ... }`."""
    return LAZY.sub(lambda m: f'ns.{m.group(1)} = {m.group(3)}\n', text)


LOADER = r'''
return function(src, name, ns)
    -- as Core/LazyData.lua, but at once: the table is built from its text right away
    ns.LazyData = function(key, text) ns[key] = assert(loadstring(text, "=" .. key))() end
    assert(loadstring(src, "@" .. name))("Amisia", ns)
    ns.LazyData = nil
    return ns
end
'''


def load(text, name='data.lua', lua=None):
    """Runs a data file (lazy or not) as the addon would and returns its ns (a Lua table)."""
    if lua is None:
        from lupa.lua51 import LuaRuntime
        lua = LuaRuntime(unpack_returned_tuples=True)
    return lua.execute(LOADER)(text, name, lua.eval('{}'))
