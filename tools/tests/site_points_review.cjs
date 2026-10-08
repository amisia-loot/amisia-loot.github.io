// Runs the whole page script of index.html against a small fake DOM (as site_points.cjs does) and checks
// what the review of DKP/EPGP found on the site: two officers' exports of one raid, an older export of a
// raid after a newer one, the backup restore, and the text for the addon as a viewer sees it.
// Prints JSON for tools/tests/test_points_review.py.
process.env.TZ = 'UTC';
const fs = require('fs');
const path = require('path');

Date.now = () => 1791500000 * 1000;
const html = fs.readFileSync(path.join(__dirname, '..', '..', 'index.html'), 'utf8');
const script = [...html.matchAll(/<script(?![^>]*src=)[^>]*>([\s\S]*?)<\/script>/g)].map(m => m[1]).find(s => s.length > 100000)
  .replace(/^\s*\(function\(\)\{/, '').replace(/\}\)\(\);\s*$/, '');
const ledger = html.match(/<script[^>]*id="ledger-data"[^>]*>([\s\S]*?)<\/script>/)[1];
// the line of the backup restore that builds the new state from the backup d
const restoreLine = script.split('\n').find(l => l.trim().startsWith('state = {version:1, guild:d.guild'));

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
;return {state: () => state, setState: s => { state = s; }, setReadOnly: v => { readOnly = v; }, setUser: (u, m) => { user = u; MEMBERS = m; },
  pointsStandings, pointsAddonText, pointsAdjust, amParsePoints, pointsPlan, pointsApply, pointsState,
  restore: d => { ${restoreLine}; return state; }};`)(...names.map(n => ctx[n]));

const out = {};
const S = api.state();
api.setReadOnly(false);   // an editor
S.raiders.push({id: 'zz1', name: 'Fraktur', cls: 'SHAMAN', role: 'DPS'}, {id: 'zz2', name: 'Chorf', cls: 'WARRIOR', role: 'Tank'});
api.pointsState().sys = 'dkp';
const fraktur = () => (api.pointsStandings().find(s => s.name === 'Fraktur') || {a: 0}).a;
const take = text => {
  const plan = api.pointsPlan(api.amParsePoints([text]));
  return {status: plan.raids.map(r => r.status), other: plan.raids.map(r => !!r.other), applied: api.pointsApply(plan), fraktur: fraktur()};
};
const reset = () => { const p = api.pointsState(); p.log = []; p.raids = {}; };

// two officers recorded the same raid (another session id, the same date and instance)
const raid = (sid, ps, earn) => `#AMISIA 2\nS ${sid} 2026-10-07 533 Naxxramas\n${ps}\n${earn.map(([id, n, code, at]) =>
  `PE ${sid.slice(0, 6)}${id} Fraktur ${n} ${code} ${at}${code === 'B' ? ' Boss' : ''}`).join('\n')}\nE\n#END`;
const two = [['aaaaaa', 10, 'R', 1791400000], ['bbbbbb', 5, 'B', 1791401000]];
out.officers = ['20261007200000-533', '20261007200500-533'].map(sid => take(raid(sid, 'PS D dkp on 2026-10-07:533 1791401000', two)));
reset();
// the same with exports of an older addon (no key on the PS line): the S line names the raid
out.officersOld = ['30261007200000-533', '30261007200500-533'].map(sid => take(raid(sid, 'PS D dkp on', two)));
reset();
// a copy of the raid made mid-raid, pasted after the full one: left out
const sid = '20261007200000-533';
const full = [['aaaaaa', 10, 'R', 1791400000], ['bbbbbb', 5, 'B', 1791401000], ['cccccc', 5, 'B', 1791402000]];
out.full = take(raid(sid, 'PS D dkp on 2026-10-07:533 1791402000', full));
out.mid = take(raid(sid, 'PS D dkp on 2026-10-07:533 1791400000', [['aaaaaa', 10, 'R', 1791400000]]));
// and the same from another officer's mid-raid copy
out.midOther = take(raid('20261007200500-533', 'PS D dkp on 2026-10-07:533 1791401000', two));
out.stored = api.pointsState().raids[sid];
// exports of an older addon carry no time on the PS line: the newest of their earnings stands for it
const keep = JSON.parse(JSON.stringify(api.pointsState()));
reset();
out.oldFull = take(raid(sid, 'PS D dkp on', full));
out.oldMid = take(raid(sid, 'PS D dkp on', [['aaaaaa', 10, 'R', 1791400000]]));
Object.assign(api.pointsState(), keep);
api.pointsAdjust('zz2', 'D', 7, 'Nachtrag', 'Vulo');
// the text for the addon names the raid by its key too
out.text = api.pointsAddonText();

// the backup restore keeps the points, checked
const backup = JSON.parse(JSON.stringify(api.state()));
backup.points.log.push(null, 'x');
backup.points.raids['../evil'] = {date: '2026-10-07'};
backup.points.junk = {a: 1};
const restored = api.restore(backup);
out.restore = {has: !!restored.points, log: restored.points ? restored.points.log.length : -1, raids: restored.points ? Object.keys(restored.points.raids) : [], junk: restored.points ? 'junk' in restored.points : null, sys: restored.points && restored.points.sys};
api.setState(restored);
const noPoints = api.restore(Object.assign({}, backup, {points: undefined}));
out.restoreNone = 'points' in noPoints;
api.setState(restored);

// a viewer: the standings only as the Points tab shows them
api.pointsState().cfg.pub = 0;
api.setReadOnly(true);
api.setUser(null, []);
out.viewerHidden = api.pointsAddonText().split('\n').filter(l => l.startsWith('P '));
api.setUser({id: 'u1'}, [{user_id: 'u1', raider: 'zz2', rank: 'Raider'}]);
out.viewerOwn = api.pointsAddonText().split('\n').filter(l => l.startsWith('P '));
api.pointsState().cfg.pub = 1;
out.viewerPub = api.pointsAddonText().split('\n').filter(l => l.startsWith('P '));
api.setReadOnly(false);
api.pointsState().cfg.pub = 0;
out.editor = api.pointsAddonText().split('\n').filter(l => l.startsWith('P '));
console.log(JSON.stringify(out));
