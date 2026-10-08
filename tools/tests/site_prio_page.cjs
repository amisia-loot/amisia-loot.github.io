// Runs the whole page script of index.html against a small fake DOM (every element keeps its value,
// innerHTML, hidden flag and listeners) and drives the Loot Council tab and the import of the LC
// lines as an editor would: set a prio in the form, edit it again from its row, copy the text for
// the addon, paste an addon export on the Import tab and take its changes over, restore a backup.
// Prints JSON; tools/tests/test_prio_site.py checks it.
process.env.TZ = 'UTC';
const fs = require('fs');
const path = require('path');

// the clock stands just before the export below was written (a time more than a day ahead is refused)
Date.now = () => 1890999000 * 1000;
const html = fs.readFileSync(path.join(__dirname, '..', '..', 'index.html'), 'utf8');
const script = [...html.matchAll(/<script(?![^>]*src=)[^>]*>([\s\S]*?)<\/script>/g)].map(m => m[1]).find(s => s.length > 100000)
  .replace(/^\s*\(function\(\)\{/, '').replace(/\}\)\(\);\s*$/, '');
const ledger = html.match(/<script[^>]*id="ledger-data"[^>]*>([\s\S]*?)<\/script>/)[1];

const els = {};
function el(key) {
  if (els[key]) return els[key];
  const listeners = {};
  const e = {
    key, value: '', innerHTML: '', textContent: '', hidden: false, disabled: false, dataset: {}, style: {}, checked: false,
    classList: {toggle() {}, add() {}, remove() {}, contains() { return false; }},
    addEventListener(t, f) { (listeners[t] = listeners[t] || []).push(f); },
    fire(t, ev) { return Promise.all((listeners[t] || []).map(f => f(Object.assign({preventDefault() {}, target: e}, ev || {})))); },
    querySelector(s) { return el(key + ' ' + s); }, querySelectorAll() { return []; },
    setAttribute() {}, getAttribute() { return null; }, focus() {}, select() {}, scrollIntoView() {}, closest() { return null; },
    insertAdjacentHTML(_, h) { e.innerHTML += h; }, appendChild() {}, remove() {},
  };
  if (key === '#ledger-data') e.textContent = ledger;
  els[key] = e;
  return e;
}
const document = {
  querySelector: s => el(s), querySelectorAll: () => [], getElementById: id => el('#' + id),
  addEventListener() {}, createElement: () => el('new' + Math.random()), head: {appendChild() {}}, documentElement: el('html'), body: el('body'),
};
const store = {};
const storage = {getItem: k => store[k] || null, setItem: (k, v) => { store[k] = v; }, removeItem: k => { delete store[k]; }};
const window = {supabase: null, addEventListener() {}, matchMedia: () => ({matches: false, addEventListener() {}})};
const ctx = {document, window, localStorage: storage, sessionStorage: storage, location: {hash: '', pathname: '/', search: ''},
  history: {replaceState() {}}, navigator: {clipboard: {writeText: async () => {}}}, innerWidth: 1000, innerHeight: 800,
  setTimeout: () => 0, clearTimeout() {}, setInterval: () => 0, structuredClone, TextEncoder, matchMedia: window.matchMedia,
  fetch: async () => ({ok: false})};
const names = Object.keys(ctx);
const api = new Function(...names, script + `
;return {state: () => state, showView, setReadOnly: v => { readOnly = v; }, prioOf, lootPrio, toast: () => $('#toast').textContent};`)(...names.map(n => ctx[n]));

(async () => {
  const out = {};
  api.setReadOnly(false);
  api.showView('prio');
  out.empty = el('#lcBody').innerHTML.includes('No priority lists yet');
  // a prio through the form
  el('#lcItem').value = '32235';
  el('#lcOrder').value = 'Anna (Tank), Krieger Furor, offen';
  el('#lcNote').value = 'erst Tanks';
  await el('#lcForm').fire('submit');
  out.saved = api.prioOf(32235);
  out.toast = api.toast();
  out.count = el('#lcCount').textContent;
  out.row = el('#lcBody').innerHTML;
  // a broken order is refused
  el('#lcOrder').value = 'Anna, X1';
  await el('#lcForm').fire('submit');
  out.refused = api.toast();
  // the row's Edit button fills the form again
  await el('#lcBody').fire('click', {target: {closest: s => s === '[data-lcedit]' ? {dataset: {lcedit: '32235'}} : null}});
  out.form = [el('#lcItem').value, el('#lcOrder').value, el('#lcNote').value];
  // the text for the addon
  await el('#lcAddon').fire('click');
  out.text = el('#lcAddonText').value;
  // read only: no form, no edit buttons
  api.setReadOnly(true);
  api.showView('prio');
  out.readOnly = {side: el('#lcSide').hidden, edit: el('#lcBody').innerHTML.includes('data-lcedit')};
  api.setReadOnly(false);
  // the addon's export with LC lines on the Import tab
  api.showView('import');
  el('#glText').value = '#AMISIA 2 Vulo_Sturmwind\nLC 32235 1891000000 Vulo_Sturmwind p:Chorf:Tank,o neu\nLC 32837 1891000000 Vulo_Sturmwind p:Bob\nLC 1 1 X p:X1\n#END';
  await el('#glPreview').fire('click');
  out.importPanel = {hidden: el('#amPrio').hidden, text: el('#amPrioText').innerHTML, disabled: el('#amPrioAdd').disabled};
  await el('#amPrioAdd').fire('click');
  out.imported = {a: api.prioOf(32235), b: api.prioOf(32837), toast: api.toast(), panel: el('#amPrio').hidden};
  // the same text again: nothing new
  await el('#glPreview').fire('click');
  out.again = {text: el('#amPrioText').innerHTML, disabled: el('#amPrioAdd').disabled};
  // a damaged entry (prio not a list) does not break the tab
  api.lootPrio()[30005] = {prio: {k: 'o'}, note: 'kaputt', at: 1, by: ''};
  api.showView('prio');
  out.damaged = el('#lcBody').innerHTML.includes('kaputt') && el('#lcBody').innerHTML.includes('no order');
  delete api.lootPrio()[30005];
  // a backup keeps the prio
  await el('#exportBtn').fire('click');
  const backup = JSON.parse(el('#backup').value);
  out.backupHas = !!(backup.lootPrio && backup.lootPrio['32235']);
  process.stdout.write(JSON.stringify(out));
})().catch(e => { console.error(e && e.stack || e); process.exit(1); });
