// Runs the whole page script of index.html against a small fake DOM (as site_prio_page.cjs does) and
// drives the Points tab and the import of the addon's DKP lines as an editor would: switch the
// ledger to DKP in the form, paste an addon export on the Import tab and take its points over
// (with the award the costs belong to already in the ledger), book a correction, apply the decay,
// copy the text for the addon, and look at it as a viewer. Also hands back the site's formula and
// rounding for a grid of inputs, so the test can hold them against the addon's.
// Reads {"export": "<the addon's export>", "award": {uid, item, name, date}} on stdin; prints JSON for
// tools/tests/test_points_site.py.
process.env.TZ = 'UTC';
const fs = require('fs');
const path = require('path');

Date.now = () => 1791500000 * 1000;
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
;return {state: () => state, showView, renderAll, setReadOnly: v => { readOnly = v; }, toast: () => $('#toast').textContent,
  pointsStandings, pointsHistory, pointsAddonText, amParsePoints, pointsPlan, ptCfg, ptFormula, ptRound, ptDecayed, ptPR, ptCompare, mainIdOf};`)(...names.map(n => ctx[n]));

let input = '';
process.stdin.on('data', d => input += d);
process.stdin.on('end', () => run(JSON.parse(input || '{}')).catch(e => { console.error(e && e.stack || e); process.exit(1); }));

const plain = list => list.map(s => ({name: s.name, a: s.a, b: s.b, low: !!s.low}));

async function run({export: exported, award, epgp}) {
  const out = {};
  const S = () => api.state();
  api.setReadOnly(false);
  // the models, for the comparison with the addon
  out.formula = [];
  for (const ilvl of [40, 66, 78, 92, 120]) for (const slot of ['head', 'shoulder', 'neck', 'weapon', 'weapon2', 'offhand', 'token']) for (const q of [3, 4, 5])
    out.formula.push([ilvl, slot, q, api.ptFormula(ilvl, slot, q, 100, 66), api.ptFormula(ilvl, slot, q, 50, 70)]);
  out.round = [2.5, -2.5, 2.49, -0.4, 13.5, -49.5].map(api.ptRound);
  out.decayed = [[100, 10], [-55, 10], [15, 10], [5, 0], [5, 100]].map(([v, p]) => api.ptDecayed(v, p));
  out.compare = api.ptCompare({a: 300, b: 50}, {a: 200, b: 0}, 100);

  // rolling: the tab says so; nothing is created by looking
  api.showView('points');
  out.rolling = {hint: el('#ptHint').textContent, body: el('#ptBody').innerHTML, points: 'points' in S()};
  // switch to DKP in the form (the fields hold the defaults after the render)
  el('#ptSys').value = epgp ? 'epgp' : 'dkp';
  el('#ptCfg_pub').checked = true;
  el('#ptCfg_raid').value = '10';
  el('#ptCfg_step').value = '0';
  await el('#ptCfgForm').fire('submit');
  out.refusedCfg = api.toast();
  el('#ptCfg_step').value = '5';
  await el('#ptCfgForm').fire('submit');
  out.cfg = api.ptCfg();
  out.saved = api.toast();

  // the alts as the roster links them, and the award the costs belong to, as an import of it would have left it
  for (const [alt, main] of award.alts || []) {
    const x = S().raiders.find(y => y.name === alt), m = S().raiders.find(y => y.name === main);
    if (x && m) x.main = m.id;
  }
  const r = S().raiders.find(x => x.name === award.name);
  S().awards.push({id: 'aw1', date: award.date, boss: 'Noth', item: award.item, raider: r.id, note: '', ts: award.at * 1000, am: award.uid});
  // the addon's export on the Import tab
  api.showView('import');
  el('#glText').value = exported;
  await el('#glPreview').fire('click');
  out.panel = {hidden: el('#amPoints').hidden, text: el('#amPointsText').innerHTML, disabled: el('#amPointsAdd').disabled};
  await el('#amPointsAdd').fire('click');
  out.taken = api.toast();
  out.afterImport = plain(api.pointsStandings());
  out.costAt = S().awards.find(x => x.id === 'aw1').pts;
  // the same text again: nothing new
  await el('#glPreview').fire('click');
  out.again = {text: el('#amPointsText').innerHTML, disabled: el('#amPointsAdd').disabled};

  // the tab: rows, history, a correction
  api.showView('points');
  out.rows = el('#ptBody').innerHTML;
  out.count = el('#ptCount').textContent;
  const fr = S().raiders.find(x => x.name === award.name);
  await el('#ptBody').fire('click', {target: {closest: s => s === '[data-ptpick]' ? {dataset: {ptpick: api.mainIdOf(fr.id)}} : null}});
  out.history = el('#ptHist').innerHTML;
  out.historyHead = el('#ptHistHead').textContent;
  el('#ptAdjRaider').value = fr.id;
  el('#ptAdjN').value = '-20';
  el('#ptAdjReason').value = '';
  await el('#ptAdjForm').fire('submit');
  out.noReason = api.toast();
  el('#ptAdjReason').value = 'Ninja | Loot';
  await el('#ptAdjForm').fire('submit');
  out.booked = api.toast();
  out.afterAdjust = plain(api.pointsStandings());
  out.adjEntry = S().points.log.find(e => e.code === 'X' && e.src === 'site');

  // the weekly decay, confirmed in the dialog
  const p = el('#ptDecay').fire('click');
  await el('#dlgYes').fire('click');
  await p;
  out.afterDecay = plain(api.pointsStandings());
  out.decays = S().points.decays;
  // a raid imported later but dated before the decay is decayed with it (the replay goes by time)
  out.historyAfter = api.pointsHistory(api.mainIdOf(fr.id)).map(h => [h.n, h.text, h.after.a]);

  // the text for the addon
  await el('#ptAddon').fire('click');
  out.text = el('#ptAddonText').value;
  out.pointsText = api.pointsAddonText();

  // a viewer: the list while pub is on, else nothing (no linked character)
  api.setReadOnly(true);
  api.showView('points');
  out.viewerPub = {side: el('#ptSide').hidden, rows: (el('#ptBody').innerHTML.match(/data-ptpick/g) || []).length};
  S().points.cfg.pub = 0;
  api.showView('points');
  out.viewerOwn = {rows: (el('#ptBody').innerHTML.match(/data-ptpick/g) || []).length, hint: el('#ptHint').textContent};
  api.setReadOnly(false);
  // removing the award takes its cost along
  S().awards = S().awards.filter(x => x.id !== 'aw1');
  out.withoutAward = plain(api.pointsStandings());
  // hostile lines
  out.bad = api.amParsePoints(['#AMISIA 2 X\nS 20261008200000-533 2026-10-08 533 Naxx\nPS D epgp on\nPS D dkp on\nPE zz Anna 5 R 1\nPE 0123456789ab Anna -5 R 1\n'
    + 'PE 0123456789ab Anna 5 Q 1\nPE 0123456789ab X1 5 R 1\nPE 0123456789ab Anna 5 R 1\nPA 0123456789ab D 1.5 1 X\nPA 0123456789ab X 5 1 X\nPA 0123456789ab D 5 99999999999 X\n'
    + 'PX 0123456789ab Anna D 0 1 X Grund\nPX 0123456789ab Anna D 5 1 X\nPX 0123456789ac Anna Q 5 1 X Grund\nPX 0123456789ad Anna D -7 1 X Gut |cff\nE\n#END']);
  process.stdout.write(JSON.stringify(out));
}
