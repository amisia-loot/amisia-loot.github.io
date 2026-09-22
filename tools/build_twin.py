"""Builds the claude.ai artifact twin of the ledger from the repo's index.html.

The twin has no database: it keeps the ledger in the artifact itself (data.json next to the
page) and lets whoever may edit the artifact edit the ledger. Everything that needs Supabase
is dropped here - sign-in, editors, accounts, version history, who-is-online, material
requests, wishlists, member ranks and the Warcraft Logs import.
"""
import pathlib, sys

SRC = pathlib.Path(r"C:\Users\aobiw\Desktop\Amisia\index.html")
OUT = pathlib.Path(sys.argv[1])
DATA_JSON = pathlib.Path(sys.argv[2])          # the twin's own ledger, kept as the inline copy

# the repo file uses CRLF, the artifact keeps LF
s = SRC.read_bytes().decode('utf-8').replace(chr(13), '')


def sub(old, new, count=1):
    global s
    assert s.count(old) >= 1, 'MISSING: ' + old[:90]
    s = s.replace(old, new, count)


def cut(start, end):
    """Removes everything from `start` up to `end`, which stays."""
    global s
    i = s.index(start)
    j = s.index(end, i)
    s = s[:i] + s[j:]


# ---------------------------------------------------------------- head
sub('<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.49.4/dist/umd/supabase.min.js"></script>\n', '')

# ---------------------------------------------------------------- tabs, status bar, sign-in box
sub('    <button class="tab" role="tab" data-view="wish">Wishlist</button>\n', '')
i = s.index('  <div class="bar" id="bar">')
j = s.index('  <div class="notice" id="exampleNotice"')
s = s[:i] + ('  <div class="bar" id="bar"><span class="dot"></span><span id="barmsg">Loading\u2026</span><span class="grow"></span>'
             '<button class="btn sm ghost" id="discardBtn" hidden title="Go back to the last published version">Discard</button>'
             '<button class="btn sm primary" id="publishBtn" hidden>Publish changes</button></div>\n\n') + s[j:]

# ---------------------------------------------------------------- Warcraft Logs panel
cut('        <div class="panel" id="wclPanel">', '        <div class="panel">\n          <div class="panel-h">Raid nights</div>')

# ---------------------------------------------------------------- wishlist tab
cut('  <!-- ============ WISHLIST ============ -->', '  <!-- ============ MATRIX ============ -->')

# ---------------------------------------------------------------- mats tab: only the material cards
cut('    <div class="matgrid" id="matGrid">', '  </section>\n\n  <!-- ============ ROSTER ============ -->')

# ---------------------------------------------------------------- roster: the linked member's own panel
cut('    <div class="panel" id="myCharPanel"', '    <div class="two">')

# ---------------------------------------------------------------- settings: editors, accounts, history
cut('      <div class="stack">\n          <div class="panel" id="editorsPanel"', '    </div>\n  </section>\n</div>\n<div id="tip" hidden></div>')

# the addon download lives on the live site, not next to the artifact
sub('<a href="addon/Amisia.zip" download>download</a>',
    '<a href="https://amisia-loot.github.io/addon/Amisia.zip" target="_blank" rel="noopener">download from the live site</a>')

# ---------------------------------------------------------------- the ledger the page starts with
ledger = DATA_JSON.read_bytes().decode('utf-8').strip()
i = s.index('<script id="ledger-data" type="application/json">') + len('<script id="ledger-data" type="application/json">')
j = s.index('</script>', i)
s = s[:i] + ledger.replace('</', '<\\/') + s[j:]

# ---------------------------------------------------------------- members: the ledger alone decides
sub("""// Accounts the owner linked to a character: {user_id, raider, rank: 'raider'|'trial', profs}. A linked
// member sets the professions of that character, and those win over the ones in the ledger.
let MEMBERS = [], memberChannel = null;
const memberOf = rid => MEMBERS.find(m => m.raider === rid);
const myMember = () => user ? MEMBERS.find(m => m.user_id === user.id) : null;
const RANKNAME = {spgod: 'SP God', officer: 'Officer', raider: 'Raider', trial: 'Trial'};   // spgod is the owner's own rank
const rankTag = rid => { const m = memberOf(rid); return m && RANKNAME[m.rank] ? '<span class="rank ' + m.rank + '">' + RANKNAME[m.rank] + '</span>' : ''; };
const profsOf = r => { const m = r && memberOf(r.id); return m && Array.isArray(m.profs) ? m.profs : Array.isArray(r && r.profs) ? r.profs : []; };""",
    """// Accounts, ranks and member professions need a database, which this copy of the page does not
// have, so a raider carries only what the ledger itself holds.
const rankTag = () => '';
const profsOf = r => Array.isArray(r && r.profs) ? r.profs : [];
// Wishlists need one too, so nobody wants an item on this page and the award form says nothing.
const wishesFor = () => [];
function renderWantLine(){ const el = $('#wantLine'); if (el) el.hidden = true; }""")

sub("  for (const m of MEMBERS) if (Array.isArray(m.crafts) && m.crafts.includes(c.id)) { const r = raiderById(m.raider); if (r && !seen.has(r.id)) { seen.add(r.id); out.push({r, member: m}); } }\n", '')

# ---------------------------------------------------------------- state: no server version to base a draft on
sub("""let dirty = false, readOnly = false, art = null, artResolved = false, saveTimer = null;
// draftBase: the server version an unsaved draft from an earlier visit was based on. editSeq counts edits.
let draftBase = null, editSeq = 0;""",
    """let dirty = false, readOnly = false, art = null, artResolved = false, saveTimer = null;""")
sub("""  if (loc && loc.dirty && (loc.savedAt||0) > (state.savedAt||0)) {   // unsaved edits from a previous visit
    draftBase = Number.isFinite(loc.baseVersion) ? loc.baseVersion : -1;
    delete loc.dirty; delete loc.baseVersion; state = loc; dirty = true;
  }""",
    """  if (loc && loc.dirty && (loc.savedAt||0) > (state.savedAt||0)) {   // unsaved edits from a previous visit
    delete loc.dirty; state = loc; dirty = true;
  }""")
sub("const LS_KEY = 'guild-loot-ledger.site.v1';", "const LS_KEY = 'raid-loot-armory.v1';")

# ---------------------------------------------------------------- persistence: the artifact instead of Supabase
PERSIST = r"""/* ---------------- persistence (the artifact itself) ---------------- */
// No database here: the ledger is published as data.json next to this page, so whoever may edit
// the artifact may edit the ledger and everyone else sees it read-only.
function setBar(kind, msg){
  const bar = $('#bar'); bar.className = 'bar '+kind; $('#barmsg').textContent = msg;
  $('#publishBtn').hidden = !(dirty && !readOnly && art);
  $('#discardBtn').hidden = !dirty;
}
function refreshBar(){
  if (readOnly) setBar('ro', 'Read-only view. Only people who may edit this artifact can change the ledger.');
  else if (!artResolved) setBar('local', dirty ? 'Unsaved changes.' : 'Ledger loaded.');
  else if (!art) setBar('local', 'Changes are kept in this browser only. Open the page on claude.ai to publish them.');
  else if (dirty) setBar('dirty', 'Unsaved changes. They publish automatically in a moment, or press Publish.');
  else setBar('ok', 'Everything is published. Anyone with the link sees this version.');
}
function markDirty(){
  dirty = true; state.savedAt = Date.now();
  try { localStorage.setItem(LS_KEY, JSON.stringify(Object.assign({}, state, {dirty:true}))); } catch(e){}
  clearTimeout(saveTimer); saveTimer = setTimeout(publish, 25000);
  refreshBar(); renderAll();
}
async function publish(){
  clearTimeout(saveTimer);
  if (!dirty || !art || readOnly) return;
  setBar('dirty', 'Publishing\u2026'); $('#publishBtn').disabled = true;
  const clean = Object.assign({}, state); delete clean.dirty;
  const json = JSON.stringify(clean);
  try {
    // Files form first: no reload, the page keeps its state.
    await art.publish({'data.json': {content: json, contentType: 'application/json'}});
    dirty = false; try { localStorage.setItem(LS_KEY, json); } catch(e){}
    $('#publishBtn').disabled = false; refreshBar(); return;
  } catch (e) {
    if (!(e && e.code === 'capability_disabled')) { $('#publishBtn').disabled = false; return publishFailed(e); }
  }
  // Older artifacts cannot publish single files: write the ledger back into the page source.
  try {
    const res = await fetch('index.html', {cache:'no-store'});
    if (!res.ok) throw {code:'fetch', message:'Could not read the page source ('+res.status+')'};
    let src = new TextDecoder('utf-8').decode(await res.arrayBuffer());
    const re = /(<script id="ledger-data" type="application\/json">)[\s\S]*?(<\/script>)/;
    if (!re.test(src)) throw {code:'fetch', message:'Page source has no ledger block'};
    src = src.replace(re, (m, a, b) => a + json.replace(/<\//g, '<\\/') + b);
    if (!/^\s*<!doctype html>/i.test(src)) src = '<!doctype html>\n' + src;
    try { sessionStorage.setItem(LS_KEY+'.ui', JSON.stringify(ui)); } catch(e){}
    try { localStorage.setItem(LS_KEY, json); } catch(e){}
    await art.publish(src);
    dirty = false; refreshBar();
  } catch (e) { publishFailed(e); }
  finally { $('#publishBtn').disabled = false; }
}
function publishFailed(e){
  $('#publishBtn').disabled = false;
  const code = e && e.code;
  if (code === 'not_writer' || code === 'not_granted') { readOnly = true; renderAll(); refreshBar(); return; }
  if (code === 'conflict') { setBar('dirty', 'Someone else published first. Reloading to the newest version\u2026'); return; }
  if (code === 'rate_limited') { setBar('err', 'Publishing too often. Your changes are kept here; try again in a minute.'); saveTimer = setTimeout(publish, 60000); return; }
  setBar('err', 'Publish failed ('+(e && (e.message||code) || 'unknown')+'). Your changes are kept in this browser. Press Publish to retry.');
}
async function initCapability(){
  if (!window.claude || typeof window.claude.use !== 'function') { artResolved = true; renderAll(); refreshBar(); return; }
  try {
    // A newer data.json (from a files-form publish) beats the copy inside the page.
    try {
      const r = await fetch('data.json', {cache:'no-store'});
      if (r.ok) { const d = await r.json(); if (d && d.awards && (d.savedAt||0) > (state.savedAt||0) && !dirty) { state = d; if ((state.game||'tbc') !== gameKey) loadGame(state.game||'tbc'); } }
    } catch(e){}
    art = await window.claude.use('artifact');
    if (art) {
      try {
        const perms = await window.claude.use('permissions');
        if (perms) { const st = await perms.state('artifact'); if (st === 'unavailable' || st === 'denied') readOnly = true; }
      } catch(e) {}
    }
  } catch(e) { art = null; }
  artResolved = true; renderAll(); refreshBar();
  if (dirty && art && !readOnly) saveTimer = setTimeout(publish, 3000);
}

"""
i = s.index('/* ---------------- persistence (Supabase) ---------------- */')
j = s.index('/* ---------------- header ---------------- */')
s = s[:i] + PERSIST + s[j:]

# ---------------------------------------------------------------- header: tab counts without wishlist and requests
sub("""    const n = t.dataset.view==='night' ? allNights().length : t.dataset.view==='wish' ? wishesHere().filter(w => !wishGot(w)).length : t.dataset.view==='att' ? countedNights().length : t.dataset.view==='mats' ? MATROWS.filter(r => r.kind === 'request' && r.status === 'open').length : t.dataset.view==='craft' ? CRAFT.items.length""",
    """    const n = t.dataset.view==='night' ? allNights().length : t.dataset.view==='att' ? countedNights().length : t.dataset.view==='mats' ? matsHere().length : t.dataset.view==='craft' ? CRAFT.items.length""")

# ---------------------------------------------------------------- Warcraft Logs and wishlists
cut('/* ---------------- warcraft logs ---------------- */', '/* ---------------- matrix ---------------- */')

# ---------------------------------------------------------------- crafting: no "I can craft this" without accounts
sub("  const me = myMember(), meR = me && raiderById(me.raider), myProfs = meR ? profsOf(meR) : [];",
    "  const meR = null, myProfs = [];   // without accounts nobody is \"me\" on this page")

# ---------------------------------------------------------------- mats: the bank count and what was looted
cut("let MATROWS = [], matState = 'loading', matChannel = null;\n", "const matsHere = () => MATS[gameKey] || [];")
sub("const ORDER = {open: 0, received: 1, declined: 2};\n", "const MATROWS = [];   // material requests need a database, so this copy has none\n")
sub("""// Shown to other people: never the e-mail address. The database sets the same name on its side.
const userName = () => user ? (user.user_metadata?.name || user.user_metadata?.full_name || user.user_metadata?.preferred_username || 'Member') : '';
""", "")
cut("async function loadMats(){", "function matStock(id){")
cut("function matOptions(sel){", "function renderMats(){")
MATSVIEW = """function renderMats(){
  const mats = matsHere();
  $('#matStock').innerHTML = mats.length ? mats.map(m => { const st = matStock(m.id); return '<div class="mat">'+icoHTML(ITEM[m.id])+'<div><div class="nm">'+esc(m.name)+'</div><div class="nums"><span><b>'+st.looted+'</b>looted in raids</span></div>'+bankLine(m.id)+'</div></div>'; }).join('')
    : '<div class="empty" style="grid-column:1/-1"><b>No tracked materials for '+esc((GAME[gameKey]||GAME.tbc).name)+'</b>Materials are tracked for TBC Anniversary so far.</div>';
}

"""
i = s.index('function renderMats(){')
j = s.index('/* ---------------- roster ---------------- */')
s = s[:i] + MATSVIEW + s[j:]

# ---------------------------------------------------------------- roster: the linked member's own panel
cut('function renderMyChar(){', 'function renderRoster(){')
sub("  renderMyChar();\n", "")
sub(""" if (memberOf(r.id) && SUPA) SUPA.rpc('set_member_profs', {p_raider: r.id, p_profs: r.profs}).then(({error}) => { if (error) say('Could not save the professions of the linked member: ' + (error.message || error.code)); else loadMembers(); });""", "")

# ---------------------------------------------------------------- crafting handlers that wrote to the database
sub("""  const mc = ev.target.closest('[data-mcon],[data-mcoff]');
  if (mc) {
    const on = mc.dataset.mcon != null, [craft, raider] = (on ? mc.dataset.mcon : mc.dataset.mcoff).split('|');
    mc.disabled = true;
    const {error} = await SUPA.rpc('set_member_craft', {p_raider: raider, p_craft: Number(craft), p_on: on});
    if (error) { mc.disabled = false; return say('Could not save: ' + (error.message || error.code)); }
    const c = CITEM[craft];
    say(on ? 'Listed as crafter of ' + (c ? c.name : 'the recipe') + '.' : 'Removed from ' + (c ? c.name : 'the recipe') + '.');
    return loadMembers();
  }
""", "")
cut("$('#myProfSave').addEventListener('click', async () => {", "$('#rosterForm').addEventListener('submit', ev => {")

# ---------------------------------------------------------------- orchestration and events
sub("  if (v === 'settings') renderHistory();\n", "")
sub("""  // a viewer never stays on the Import tab, once the server has said what the role is
  if (readOnly && roleKnown && (ui.view === 'import' || ui.view === 'settings')) { showView('armory'); return; }""",
    """  // a viewer never stays on the Import tab
  if (readOnly && artResolved && (ui.view === 'import' || ui.view === 'settings')) { showView('armory'); return; }""")
sub("  if (ui.view === 'wish') renderWishes();\n", "")
sub("""$('#discardBtn').addEventListener('click', async () => {
  if (!dirty) return;
  if (saving) return say('Saving right now, try again in a moment.');
  clearTimeout(saveTimer);   // no autosave while the question is open
  if (!await ask('Throw away the changes that are not saved yet? The page goes back to the last saved version.', 'Discard')) {
    if (dirty && isEditor) saveTimer = setTimeout(publish, 4000);
    return;
  }
  try { localStorage.removeItem(LS_KEY); } catch (e) {}
  if (!SUPA) { dirty = false; location.reload(); return; }
  if (!await loadFromServer(true)) return say('Could not reach the saved version. Reload the page to finish discarding.');
  renderHistory(true);
  if (wclRaw.length) { wclRows = wclResolve(wclRaw); wclRender(); }
  say('Unsaved changes discarded.');
});""",
    """$('#discardBtn').addEventListener('click', async () => {
  if (!dirty) return;
  clearTimeout(saveTimer);   // no autosave while the question is open
  if (!await ask('Throw away the changes that are not published yet? The page goes back to the last published version.', 'Discard')) {
    if (dirty && art && !readOnly) saveTimer = setTimeout(publish, 25000);
    return;
  }
  try { localStorage.removeItem(LS_KEY); } catch (e) {}
  dirty = false; location.reload();
});""")
sub("window.addEventListener('beforeunload', ev => { if (dirty && isEditor) { ev.preventDefault(); ev.returnValue = ''; } });",
    "window.addEventListener('beforeunload', ev => { if (dirty && art && !readOnly) { ev.preventDefault(); ev.returnValue = ''; } });")

# Nothing may be left that reaches for the database or for an element this page no longer has.
for dead in ['SUPA', 'MEMBERS', 'WISHES', 'myMember', 'memberOf', 'loadMembers', 'renderHistory', 'renderEditors',
             'renderAccounts', 'loadMats', 'loadWishes', 'renderWishes', 'wclRows', 'isEditor', 'isOwner',
             "$('#matSearch'", "$('#loginBtn'", "$('#edAdd'", "$('#histReload'", "$('#wclFetch'", "$('#wfAdd'",
             "$('#mqAdd'", "$('#matBody'", "$('#wishBody'", 'userName(', 'roleKnown', 'netError']:
    assert dead not in s, 'still references ' + dead

# Nor may a function that was cut out still be called somewhere.
import re
js = s[s.index('<script>\n(function(){'):s.rindex('})();')]
defined = set(re.findall(r'(?:^|\s)(?:async )?function ([A-Za-z0-9_]+)', js)) | set(re.findall(r'(?:const|let|var) ([A-Za-z0-9_]+)\s*=', js))
gone = [n for n in ('renderWantLine', 'wishesFor', 'wishesHere', 'wishGot', 'prioTag', 'renderMyChar', 'matWrite',
                    'matOptions', 'renderHistory', 'loadFromServer', 'refreshRole', 'withTimeout', 'startPresence',
                    'heartbeat', 'renderOnline', 'wclNight', 'wclLoad', 'wclRender', 'wclResolve')
        if re.search(r'\b' + n + r'\s*\(', js) and n not in defined]
assert not gone, 'calls a function this copy no longer has: ' + ', '.join(gone)

OUT.write_bytes(s.encode('utf-8'))
print('built', OUT, len(s), 'chars')
