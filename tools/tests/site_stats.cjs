// Runs the ledger's statistics code out of index.html: buildStats adds up the characters of a
// player (groupIds) for items won (MS/OS/SR from the note), attendance since first seen with the
// bench rule of the Attendance tab, bosses seen, streaks and items per week; sortStats and
// statsFame. Prints the results as JSON; tools/tests/test_stats_site.py checks them.
process.env.TZ = 'UTC';
const {grab} = require('./site_parser.cjs');

const NEEDED = ['raiderById', 'nights', 'nightOn', 'allNights', 'countedNights', 'presentOn', 'lateOn', 'BENCH_MODES', 'benchMode',
  'benchOn', 'nightKills', 'mainIdOf', 'altsOf', 'groupIds', 'mainRaiders', 'awardsOfGroup', 'wishesHere',
  'STAT_DPS', 'statRole', 'statRoleWord', 'statKind', 'dayNum', 'statPhase', 'buildStats', 'STAT_SORT', 'sortStats', 'statsFame',
  'esc', 'fmtDate', 'fmtShort', 'MOP_CLASSES', 'clsVar', 'statCols', 'statCharText', 'renderStats'];
const STUBS = `
let state = {raiders: [], awards: [], nights: []};
let WISHES = [];
const PLAY = 'forever';
const BOSSZONE = {Gruul: 'gruul', Kaz: 'hyjal'};
const ZONE = {gruul: "Gruul's Lair", hyjal: 'Mount Hyjal'};
const ITEM = {1003: {name: 'Dragonspine Trophy'}};
const today = () => '2026-10-06';
const bossHere = n => n;
const ui = {};
const els = {};
const $ = sel => els[sel] || (els[sel] = {value: '', innerHTML: '', textContent: ''});
`;
const src = STUBS + NEEDED.map(grab).join('\n\n') + `
;module.exports = {buildStats, sortStats, statsFame, statRole, statKind, statPhase, set: s => { state = s; }, get: () => state,
  wishes: w => { WISHES = w; }, renderStats, ui, $};`;
const mod = {exports: {}};
new Function('module', 'exports', src)(mod, mod.exports);
const api = mod.exports;

api.set({
  raiders: [{id: 'a', name: 'Anna', cls: 'Priest'}, {id: 'b', name: 'Bob', cls: 'Mage'}, {id: 'b2', name: 'Bobalt', cls: 'Mage', main: 'b'},
    {id: 'c', name: 'Chorf', cls: 'Warrior'}, {id: 'd', name: 'Dora', cls: 'Rogue'}],
  nights: [
    {date: '2026-08-27', present: ['a', 'b']},
    {date: '2026-09-16', present: ['a', 'b', 'c'], late: {b: 1}, bench: {d: {sid: 's', at: 1}},
      kills: [{sid: 's', name: 'Naj', end: 100, ok: true, present: ['a', 'b', 'c']}, {sid: 's', name: 'Sup', end: 200, ok: false, present: []}]},
    {date: '2026-09-26', present: ['a', 'b2', 'd'], kills: [{sid: 't', name: 'Winterchill', end: 300, ok: true, present: ['a', 'b2']}]},
    {date: '2026-10-03', present: ['a', 'c'], late: {a: 1}, kills: [{sid: 'u', name: 'Teron', end: 400, ok: true, present: ['a', 'c']}]},
    {date: '2026-10-04', present: ['a', 'b', 'c', 'd'], off: true},
  ],
  awards: [
    {id: 'w1', raider: 'a', date: '2026-08-27', boss: 'Gruul', item: 1001},
    {id: 'w2', raider: 'b', date: '2026-09-16', boss: 'Gruul', item: 1002, note: 'OS'},
    {id: 'w3', raider: 'c', date: '2026-09-16', boss: 'Gruul', item: 1003},
    {id: 'w4', raider: 'b2', date: '2026-09-26', boss: 'Kaz', item: 1004, note: 'SR · swap'},
    {id: 'w5', raider: 'b2', date: '2026-09-26', boss: 'Kaz', item: 1005, note: 'needs it'},
    {id: 'w6', raider: 'c', date: '2026-10-03', boss: 'Gruul', item: 1007},
  ],
});
const brief = p => ({name: p.name, items: p.items, ms: p.ms, os: p.os, sr: p.sr, raids: p.raids, total: p.total, late: p.late,
  bench: p.bench, bosses: p.bosses, streak: p.streak, last: p.last, rate: p.rate, perRaid: p.perRaid, role: p.role, weeks: p.weeks,
  chars: p.chars.map(c => ({name: c.name, items: c.items, raids: c.raids}))});
const run = opts => { const r = api.buildStats(opts); return {nights: r.nights, phase: r.phase, players: r.players.map(brief)}; };
const names = list => list.map(p => p.name).join(',');
const out = {};
out.all = run({range: 'all'});
out.w4 = run({range: '4w'});
out.phase = run({range: 'phase'});
out.mage = run({range: 'all', cls: 'Mage'});
out.dps = run({range: 'all', role: 'dps'});
out.unknown = run({range: 'all', role: 'unknown'});
out.kinds = [api.statKind({note: 'OS'}), api.statKind({note: 'SR · x'}), api.statKind({note: 'swap'}), api.statKind({})];
const r = api.buildStats({range: 'all'});
out.sorted = {
  items: names(api.sortStats(r.players, 'items', true)), rate: names(api.sortStats(r.players, 'rate', true)),
  name: names(api.sortStats(r.players, 'name', false)), nameDesc: names(api.sortStats(r.players, 'name', true)),
  last: names(api.sortStats(r.players, 'last', true)),
};
api.wishes([{game: 'forever', raider: 'c', item: 1003}, {game: 'forever', raider: 'a', item: 1003}, {game: 'forever', raider: 'd', item: 1003},
  {game: 'forever', raider: 'b2', item: 1005}, {game: 'tbc', raider: 'a', item: 1005}, {game: 'forever', raider: 'a', item: 1007}]);
out.fame = api.statsFame(api.buildStats({range: 'all'}));
// the tab itself: Bob's row open, sorted by name
api.$('#stRange').value = 'phase'; api.ui.stOpen = 'b'; api.ui.stSort = 'name'; api.ui.stDesc = false;
api.renderStats();
out.page = {head: api.$('#stHead').innerHTML, body: api.$('#stBody').innerHTML, fame: api.$('#stFame').innerHTML, count: api.$('#stCount').textContent,
  hint: api.$('#stHint').textContent, classes: api.$('#stClass').innerHTML};
api.$('#stRange').value = 'all'; api.$('#stClass').value = 'Warrior';
api.renderStats();
out.pageWarrior = api.$('#stBody').innerHTML;
// the bench left out of the rate, and counted as missed
api.get().benchMode = 'excused';
out.excused = run({range: 'all'});
api.get().benchMode = 'missed';
out.missed = run({range: 'all'});
delete api.get().benchMode;
// an empty ledger
api.set({raiders: [], awards: [], nights: []});
out.empty = run({range: 'phase'});
out.emptyFame = api.statsFame(api.buildStats({range: 'all'}));
process.stdout.write(JSON.stringify(out));
