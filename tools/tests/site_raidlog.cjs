// Runs the ledger's raid log code out of index.html (amParse, amResolve, importAmisia, amNightLog,
// nightKills, benchOn, attendance, nightText) through the imports of one raid night and prints what
// the night holds after each step as JSON. tools/tests/test_raidlog_import.py checks it.
process.env.TZ = 'UTC';
const {grab} = require('./site_parser.cjs');

const NEEDED = ['GL_CLASS', 'CLASS_ALIAS', 'glCleanName', 'classFromAny', 'amSplit', 'amParse', 'amLate', 'amResolve',
  'amNightLog', 'importAmisia', 'nights', 'nightOn', 'allNights', 'countedNights', 'presentOn', 'lateOn', 'lateTime',
  'BENCH_MODES', 'benchMode', 'benchOn', 'attendance', 'nightKills', 'matloot', 'otherLoot', 'lootDrops', 'lootAway', 'itemNames',
  'nightData', 'wipeWord', 'killTime', 'nightText'];
// What else the code reaches for on the page, kept as small as the code allows.
const STUBS = `
let state = {raiders: [], awards: [], nights: []}, amRows = [], ui = {night: null};
let BOSSES = [], BOSSZONE = {}, ITEM = {}, ZONE = {bt: 'Black Temple'};
const BOSSNAME = {'Mutter Shahraz': 'Mother Shahraz', "Hochkriegsfürst Naj'entus": "High Warlord Naj'entus", 'Illidan Sturmgrimm': 'Illidan Stormrage'};
const bossHere = name => { const n = String(name == null ? '' : name).trim(); return BOSSNAME[n] || n; };
let uidN = 0; const uid = () => 'r' + (++uidN);
const $ = sel => ({checked: false, value: ''});
const raiderById = id => state.raiders.find(r => r.id === id);
const fmtDate = d => d;
const nightExtraLoot = () => ({clash: [], other: [], left: []});
const matName = id => 'Mat ' + id, anyItemName = id => 'Item ' + id;
`;
const src = STUBS + NEEDED.map(grab).join('\n\n') + `
;module.exports = {amSplit, amParse, amResolve, importAmisia, amNightLog, nightKills, benchOn, attendance, nightText, nightOn,
  getState: () => state, setState: s => { state = s; }, setRows: r => { amRows = r; }, setNight: d => { ui.night = d; }};`;
const mod = {exports: {}};
new Function('module', 'exports', src)(mod, mod.exports);
const api = mod.exports;

const DATE = '2026-10-01', T = Date.UTC(2026, 9, 1, 20, 0, 0) / 1000;
const block = (sid, lines) => ['#AMISIA 2 Vuloo', 'S ' + sid + ' ' + DATE + ' 564 Der Schwarze Tempel', ...lines, 'E', '#END'].join('\n');
const SID_A = '20261001195500-564', SID_B = '20261001195800-564';
const members = ['M Vuloo PRIEST ' + T + ' 0', 'M Fraktur SHAMAN ' + T + ' 0', 'M Chorf WARRIOR ' + T + ' 0'];
const najA = ['EK 601 ' + (T + 600) + ' ' + (T + 792) + " K 25 4 E Hochkriegsfürst Naj'entus", 'EP 601 ' + (T + 792) + ' Chorf Fraktur Vuloo Fremder'];
const supWipeA = ['EK 602 ' + (T + 1200) + ' ' + (T + 1321) + ' W 25 4 E Supremus'];
const supKillA = ['EK 602 ' + (T + 1500) + ' ' + (T + 1740) + ' K 25 4 E Supremus', 'EP 602 ' + (T + 1740) + ' Fraktur Vuloo'];
const shahA = ['EK 0 ' + (T + 5400) + ' ' + (T + 5400) + ' K 0 0 L Mutter Shahraz', 'EP 0 ' + (T + 5400) + ' Vuloo'];
const benchA = ['BN Bob MAGE ' + (T - 600) + ' S - ab 21 Uhr', 'BN Chorf WARRIOR ' + (T - 500) + ' O Vuloo', 'BN Kim_Eisherz UNKNOWN ' + (T - 400) + ' O Vuloo'];
const A = block(SID_A, [...members, ...najA, ...supWipeA, ...supKillA, ...shahA, ...benchA]);
// the same raid exported again after a kill was deleted and Kim left the bench
const A2 = block(SID_A, [...members, ...najA, ...supWipeA, ...shahA, benchA[0], benchA[1]]);
// a second officer's recording of the same night, with an English client and one more raider
const B = block(SID_B, ['M Vuloo PRIEST ' + T + ' 0', 'M Fraktur SHAMAN ' + T + ' 0', 'M Chorf WARRIOR ' + T + ' 0', 'M Anna DRUID ' + T + ' 1',
  'EK 601 ' + (T + 610) + ' ' + (T + 812) + " K 25 4 E High Warlord Naj'entus", 'EP 601 ' + (T + 812) + ' Anna Chorf Fraktur Vuloo',
  'EK 602 ' + (T + 1230) + ' ' + (T + 1351) + ' W 25 4 E Supremus',
  'EK 602 ' + (T + 1510) + ' ' + (T + 1750) + ' K 25 4 E Supremus', 'EP 602 ' + (T + 1750) + ' Fraktur',
  'EK 0 ' + (T + 5500) + ' ' + (T + 5500) + ' K 0 0 H Mother Shahraz', 'EP 0 ' + (T + 5500) + ' Fraktur Vuloo',
  'EK 609 ' + (T + 7000) + ' ' + (T + 7300) + ' W 25 4 E Illidan Sturmgrimm',
  'BN Bob MAGE ' + (T - 300) + ' S - spaeter']);
// an export of 1.6: no log lines
const OLD = block('20261002195500-564', ['M Vuloo PRIEST ' + T + ' 0']).replace(/2026-10-01/, '2026-10-02');

const parse = text => api.amParse(api.amSplit(text).blocks);
const resolve = text => api.amResolve(parse(text));
function importText(text) {
  const rows = resolve(text);
  api.setRows(rows);
  const res = api.importAmisia();
  return {status: rows.map(r => r.status), res};
}
const byId = () => Object.fromEntries(api.getState().raiders.map(r => [r.id, r.name]));
const names = ids => (ids || []).map(id => byId()[id] || id).sort();
// The night with raider ids put back to names, so the test reads names.
function night(date) {
  const n = JSON.parse(JSON.stringify(api.nightOn(date || DATE) || {}));
  if (n.present) n.present = names(n.present);
  if (n.kills) n.kills.forEach(k => { k.present = names(k.present); });
  if (n.bench) n.bench = Object.fromEntries(Object.entries(n.bench).map(([id, e]) => [byId()[id] || id, e]));
  return n;
}
const kills = () => api.nightKills(DATE).map(k => Object.assign({}, k, {present: names(k.present)}));
const bench = () => Object.keys(api.benchOn(DATE)).map(id => byId()[id]).sort();
const text = () => { api.setNight(DATE); return api.nightText(); };

const out = {T};
api.setState({raiders: [{id: 'z1', name: 'Zed', cls: 'Rogue'}], awards: [], nights: []});
out.parsed = parse(A)[0];
out.previewA = resolve(A).map(r => ({status: r.status, newNames: r.newNames, people: r.people}));
out.importA = importText(A);
out.afterA = {night: night(), kills: kills(), bench: bench(), text: text(),
  raiders: api.getState().raiders.map(r => r.name + ':' + r.cls).sort()};
out.againA = resolve(A).map(r => r.status);
out.importB = importText(B);
out.afterB = {night: night(), kills: kills(), bench: bench(), text: text()};
out.againAafterB = resolve(A).map(r => r.status);
out.previewA2 = resolve(A2).map(r => r.status);
out.importA2 = importText(A2);
out.afterA2 = {night: night(), kills: kills(), bench: bench(), text: text()};
out.againA2 = resolve(A2).map(r => r.status);
// an export of 1.6 imports as before: no kills, no bench on its night
out.importOld = importText(OLD);
out.oldNight = night('2026-10-02');

// Attendance against a ledger of four nights: on the bench, there, a night that does not count,
// and a night where a raider was both on the bench and there.
const D = ['2026-09-01', '2026-09-02', '2026-09-03', '2026-09-04'];
const ATT = () => ({raiders: [{id: 'a', name: 'Al', cls: 'Mage'}, {id: 'b', name: 'Bo', cls: 'Mage'}, {id: 'c', name: 'Cy', cls: 'Mage'}], awards: [], nights: [
  {id: 'n1', date: D[0], present: ['a'], bench: {b: {sid: 'x', at: 1, self: true, note: ''}}},
  {id: 'n2', date: D[1], present: ['a', 'b']},
  {id: 'n3', date: D[2], present: ['a'], bench: {b: {sid: 'x', at: 1, self: false, note: ''}}, off: true},
  {id: 'n4', date: D[3], present: ['a'], bench: {a: {sid: 'x', at: 1, self: true, note: ''}}},
]});
out.att = {};
for (const mode of [undefined, 'present', 'excused', 'missed', 'bogus']) {
  const st = ATT(); if (mode !== undefined) st.benchMode = mode;
  api.setState(st);
  out.att[String(mode)] = {a: api.attendance('a'), b: api.attendance('b'), c: api.attendance('c'), benchD4: Object.keys(api.benchOn(D[3]))};
}

process.stdout.write(JSON.stringify(out));
