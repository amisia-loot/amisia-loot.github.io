// Runs the ledger's shelf and archive code out of index.html: fitShelf puts Forever on top, the TBC
// archive is a read-only copy of shelf.tbc, removing a raider never thins the archive. Prints the
// results as JSON; tools/tests/test_site_archive.py checks them.
const fs = require('fs');
const path = require('path');
const {grab} = require('./site_parser.cjs');

const PAGE = fs.readFileSync(path.join(__dirname, '..', '..', 'index.html'), 'utf8').replace(/\r\n/g, '\n');
// the ledger the page starts with (and the twin keeps): TBC on top, from before the shelf
const START = PAGE.match(/<script id="ledger-data" type="application\/json">([\s\S]*?)<\/script>/)[1];

const NEEDED = ['PLAY', 'PER_GAME', 'fitShelf', 'allBuckets', 'archiveBucket', 'archiveHas', 'archiveView', 'inArchive',
  'importSig', 'forgetImport', 'forgetRaider', 'removeRaider', 'noteMove', 'setReadOnly', 'ARCHIVE_TABS',
  'enterArchive', 'leaveArchive', 'takeState', 'markDirty'];
// What else the code reaches for on the page, kept as small as the code allows.
const STUBS = `
let state = {raiders: [], awards: []}, dirty = false, saving = false, readOnly = false, gameKey = 'forever';
let archiveOn = false, liveState = null, liveReadOnly = true, movedOnLoad = null;
let editSeq = 0, draftBase = null, serverVersion = 0, saveTimer = null, renders = 0, games = [];
let ui = {view: 'armory'};
const LS_KEY = 'test', localStorage = {setItem(){}, removeItem(){}};
const location = {hash: '', pathname: '/', search: ''}, history = {replaceState(){}};
const setTimeout = () => 0, clearTimeout = () => {};
const busy = () => dirty || saving;
function publish(){}
function refreshBar(){}
function renderAll(){ renders++; }
function showView(v){ ui.view = v; }
function loadGame(k){ gameKey = k; games.push(k); }
`;
const src = STUBS + NEEDED.map(grab).join('\n\n') + `
;module.exports = {fitShelf, allBuckets, archiveHas, archiveView, inArchive, removeRaider, enterArchive, leaveArchive,
  takeState, markDirty, noteMove, setReadOnly,
  get: () => ({state, liveState, archiveOn, readOnly, dirty, gameKey, movedOnLoad, view: ui.view, games}),
  set: o => { if ('state' in o) state = o.state; if ('dirty' in o) dirty = o.dirty; if ('readOnly' in o) readOnly = o.readOnly;
    if ('view' in o) ui.view = o.view; if ('gameKey' in o) gameKey = o.gameKey; }};`;
const mod = {exports: {}};
new Function('module', 'exports', src)(mod, mod.exports);
const api = mod.exports;
const clone = x => JSON.parse(JSON.stringify(x));
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
const count = s => {
  // awards and raid nights of every game version in a ledger, wherever they lie
  const buckets = [s, ...Object.values(s.shelf || {})];
  return {awards: buckets.reduce((t, b) => t + (b.awards || []).length, 0), nights: buckets.reduce((t, b) => t + (b.nights || []).length, 0)};
};
const out = {};

// ---------------------------------------------------------------- the four starting points
const anna = {id: 'a', name: 'Anna', cls: 'Priest'}, bob = {id: 'b', name: 'Bob', cls: 'Mage'}, cid = {id: 'c', name: 'Cid', cls: 'Rogue'};
const tbcData = () => ({
  awards: [{id: 'w1', date: '2026-09-01', boss: 'Gruul the Dragonkiller', item: 28822, raider: 'a', note: '', ts: 1, gargul: 'g1'},
    {id: 'w2', date: '2026-09-02', boss: 'Moroes', item: 28530, raider: 'b', note: 'OS', ts: 2, src: '2026-09-02|28530|bob'}],
  nights: [{date: '2026-09-01', present: ['a', 'b'], late: {b: 1790000000}, kills: [{end: 5, ok: true, name: 'Gruul', present: ['a', 'b'], sid: 's'}]},
    {date: '2026-09-02', present: ['b'], bench: {a: {at: 1}}}],
  crafters: [{id: 'c1', craft: 1, raider: 'a', ts: 1}],
  bank: {at: 1, date: '2026-09-02', time: '20:00', by: 'Anna', items: {32428: 3}},
});

// 1. live today: Forever on top, shelfGame forever, the TBC loot on the shelf
const live = {version: 1, guild: 'Amisia', game: 'forever', shelfGame: 'forever', raiders: [anna, bob, cid], awards: [], nights: [],
  shelf: {tbc: tbcData()}};
const live1 = clone(live); api.fitShelf(live1);
const live2 = clone(live1); api.fitShelf(live2);
out.live = {unchanged: same(live1, live), twice: same(live2, live1), has: api.archiveHas(live1)};

// 2. twin, start ledger, old backup: TBC on top (game tbc or none), no shelfGame
const old = Object.assign({version: 1, guild: 'Amisia', raiders: [anna, bob, cid]}, tbcData());
const noGame = clone(old), withGame = Object.assign(clone(old), {game: 'tbc'});
const before = count(old);
api.fitShelf(noGame); api.fitShelf(withGame);
const again = clone(noGame); api.fitShelf(again);
out.old = {game: noGame.game, shelfGame: noGame.shelfGame, top: noGame.awards.length, topNights: 'nights' in noGame,
  shelfTbc: same(noGame.shelf.tbc, tbcData()), withGameSame: same(withGame, noGame), twice: same(again, noGame),
  countBefore: before, countAfter: count(noGame), has: api.archiveHas(noGame), shelfKeys: Object.keys(noGame.shelf)};

// 3. a backup with MoP on top and the TBC loot on the shelf
const mopData = {awards: [{id: 'm1', date: '2026-08-01', boss: 'Feng', item: 85000, raider: 'c', note: '', ts: 1}], nights: []};
const mop = Object.assign({game: 'mop', shelfGame: 'mop', raiders: [anna, bob, cid], shelf: {tbc: tbcData()}}, clone(mopData));
api.fitShelf(mop);
out.mop = {game: mop.game, shelfGame: mop.shelfGame, top: mop.awards.length, shelfMop: same(mop.shelf.mop, mopData),
  shelfTbc: same(mop.shelf.tbc, tbcData()), has: api.archiveHas(mop)};

// 4. a ledger without TBC loot
const none = {game: 'forever', shelfGame: 'forever', raiders: [anna], awards: []};
api.fitShelf(none);
const noneOld = {raiders: [anna], awards: []};   // from before the shelf, but empty
api.fitShelf(noneOld);
out.none = {has: api.archiveHas(none), hasOld: api.archiveHas(noneOld), game: noneOld.game, shelfGame: noneOld.shelfGame};

// a shelf entry of the game on top is never overwritten (a broken backup: TBC on top and on the shelf)
const clash = Object.assign({raiders: [anna], shelf: {tbc: {awards: [{id: 'x', raider: 'a', item: 1, date: '2026-01-01'}]}}}, tbcData());
api.fitShelf(clash);
out.clash = {keys: Object.keys(clash.shelf).sort(), kept: clash.shelf['tbc~2'] && clash.shelf['tbc~2'].awards.length, top: same(clash.shelf.tbc, tbcData())};

// ---------------------------------------------------------------- the archive view
const view = api.archiveView(live1);
const viewOld = api.archiveView(clone(old));   // a ledger that has not moved yet: the TBC data is on top
view.awards.push({id: 'new'}); view.raiders.push({id: 'z'}); view.nights[0].present.push('z');
out.view = {game: view.game, shelfGame: view.shelfGame, shelf: view.shelf, awards: view.awards.length - 1, nights: view.nights.length,
  liveUntouched: same(live1, (() => { const l = clone(live); api.fitShelf(l); return l; })()),
  oldAwards: viewOld.awards.length, oldNights: viewOld.nights.length, guild: view.guild, bank: !!viewOld.bank,
  noRetiredKey: !('retired' in view)};

// ---------------------------------------------------------------- removing a raider
const rm = clone(live1);
rm.shelf.mop = {awards: [{id: 'm1', date: '2026-08-01', boss: 'Feng', item: 85000, raider: 'a', ts: 1}], crafters: [{id: 'c9', craft: 2, raider: 'a'}]};
rm.awards = [{id: 'f1', date: '2026-11-05', boss: 'Ragnaros', item: 17076, raider: 'a', ts: 1}];
const tbcBefore = clone(rm.shelf.tbc);
out.allBuckets = (() => { api.set({state: rm}); return api.allBuckets().length; })();
api.removeRaider(rm, 'a');
const tbcAfter = clone(rm.shelf.tbc); const retired = tbcAfter.retired; delete tbcAfter.retired;
api.removeRaider(rm, 'c');   // Cid has nothing in the archive
api.removeRaider(rm, 'a');   // gone already: nothing happens
out.remove = {tbcSame: same(tbcAfter, tbcBefore), retired, retiredAfterCid: rm.shelf.tbc.retired.map(r => r.id),
  raiders: rm.raiders.map(r => r.id), top: rm.awards.length, mop: rm.shelf.mop.awards.length + rm.shelf.mop.crafters.length,
  dropped: rm.dropped || []};
// the archive still names Anna
const viewRm = api.archiveView(rm);
out.remove.viewRaiders = viewRm.raiders.map(r => r.id).sort();
out.remove.annaInArchive = api.inArchive(rm, 'a');
out.remove.cidInArchive = api.inArchive(live1, 'c');
// someone only on the bench or in a kill still counts as a trace in the archive
const benchOnly = {shelfGame: 'forever', shelf: {tbc: {nights: [{date: 'd', bench: {q: {}}, kills: [{present: ['k']}]}]}}};
out.remove.bench = api.inArchive(benchOnly, 'q'); out.remove.kill = api.inArchive(benchOnly, 'k');

// ---------------------------------------------------------------- entering, saving, leaving
const liveRun = clone(live1);
api.set({state: liveRun, dirty: true, readOnly: false, view: 'wish'});
api.enterArchive();
out.enterDirty = api.get().archiveOn;   // unsaved changes: no archive
api.set({dirty: false});
api.enterArchive();
let g = api.get();
out.enter = {archiveOn: g.archiveOn, readOnly: g.readOnly, game: g.state.game, live: g.liveState === liveRun, view: g.view, gameKey: g.gameKey,
  awards: g.state.awards.length};
// markDirty in the archive changes nothing
const savedAt = g.state.savedAt;
api.markDirty();
g = api.get();
out.markDirty = {dirty: g.dirty, savedAt: g.state.savedAt === savedAt};
// the role turns to editor while in the archive: still read-only, editor again after leaving
api.setReadOnly(false);
out.roleInArchive = api.get().readOnly;
// a new ledger from the server goes behind the view
const fromServer = clone(live1); fromServer.shelf.tbc.awards.push({id: 'w3', date: '2026-09-03', boss: 'Moroes', item: 28530, raider: 'c', ts: 3});
api.takeState(fromServer);
g = api.get();
out.takeInArchive = {live: g.liveState === fromServer, archiveOn: g.archiveOn, awards: g.state.awards.length, viewIsNotLive: g.state !== fromServer};
api.leaveArchive();
g = api.get();
out.leave = {archiveOn: g.archiveOn, live: g.state === fromServer, readOnly: g.readOnly, gameKey: g.gameKey,
  shelfTbc: g.state.shelf.tbc.awards.length};
// a ledger without archive data in the archive: back to Forever
api.enterArchive();
api.takeState(clone(none));
out.takeEmpty = api.get().archiveOn;
// outside the archive takeState notes a move of a ledger with TBC on top
api.takeState(JSON.parse(START));
g = api.get();
out.takeOld = {moved: g.movedOnLoad, gameKey: g.gameKey};
api.takeState(clone(live1));
out.takeLive = {moved: api.get().movedOnLoad};

// ---------------------------------------------------------------- the start ledger of the page and the twin
const start = JSON.parse(START), startBefore = count(start);
api.fitShelf(start);
const startView = api.archiveView(start);
out.start = {game: JSON.parse(START).game, before: startBefore, after: count(start), view: {awards: startView.awards.length, nights: (startView.nights || []).length},
  top: start.awards.length};
process.stdout.write(JSON.stringify(out));
