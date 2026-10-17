"""The site puts no ledger value raw into an HTML attribute (DECISIONS D-33, security audit 2026-10-17).

Ledger values (ids, dates, keys) come from the database, which any editor writes; an id such as
'x"><img onerror=...>' would run in every visitor's browser. Every attribute built from a value goes
through esc(); a selector ($('[data-x="' + id + '"]')) is no HTML and stays as it is."""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RAW = re.compile(r'''(?<![\w\[-])([A-Za-z][\w-]*)="'\s*\+\s*(?=\S)(?!esc\()([^'"]+?)\s*\+\s*'"''')
# values that are numbers or fixed words the code itself makes (not from the ledger)
ALLOWED = {
    "colspan": None, "height": None, "width": None, "style": None, "class": None, "data-glboss": None,
}


def test_no_raw_value_in_an_attribute():
    with open(os.path.join(ROOT, 'Amisia-Website', 'index.html'), encoding='utf-8') as fh:
        lines = fh.read().split('\n')
    bad = []
    for n, line in enumerate(lines, 1):
        for m in RAW.finditer(line):
            if m.group(1) in ALLOWED:
                continue
            bad.append(f'{n}: {m.group(0)[:80]}')
    assert not bad, 'unescaped values in attributes:\n' + '\n'.join(bad)


def test_the_check_finds_a_raw_value():
    assert RAW.search('''x = '<a data-card="'+r.id+'">' ''')
    assert not RAW.search('''x = '<a data-card="'+esc(r.id)+'">' ''')
    assert not RAW.search('''$('[data-mlraider="' + id + '"]')''')
