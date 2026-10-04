// Runs the ledger's award import out of index.html (glResolve, amAwardRows, amGoneRows,
// amApplyAwardChanges, amResolve, importAmisia, nightExtraLoot) against small ledgers and prints
// what each scenario did as JSON. tools/tests/test_award_import.py checks that an award the Amisia
// addon exports with its id is recognised again, that changes made in game move the award, that
// an older export never overwrites a change made on the site, that deletions in game remove the
// award, and that hand-outs to the bank or the disenchanter create no raider.
const {grab} = require('./site_parser.cjs');

const NEEDED = ['GL_CLASS', 'CLASS_ALIAS', 'glCleanName', 'classFromAny', 'amSplit', 'amParse', 'amAwardRows', 'amGoneRows',
  'importSig', 'forgetImport', 'glResolve', 'amApplyAwardChanges', 'amLate', 'amResolve', 'importAmisia', 'nightExtraLoot',
  'bossGuessed', 'bossHere', 'raiderById', 'anyItemName', 'nightOn', 'lootDrops', 'lootAway', 'otherLoot', 'itemNames', 'matloot',
  'nights', 'lootOk'];
const src = NEEDED.map(grab).join('\n\n');

// What the page has around these functions: the item tables, the DOM checkbox and the ledger.
const STUBS = `
let state;
const BOSSNAME = {'Illidan Sturmgrimm': 'Illidan Stormrage'};
const ITEM = {
  32235: {id: 32235, name: 'Cursed Vision of Sargeras', slot: 'head', sources: ['Illidan Stormrage']},
  32837: {id: 32837, name: 'Warglaive of Azzinoth', slot: 'weapon', sources: ['Illidan Stormrage']},
  32524: {id: 32524, name: 'Shroud of the Highborne', slot: 'back', sources: ['Mother Shahraz', 'Illidan Stormrage']},
};
const BOSSES = [{name: 'Illidan Stormrage'}, {name: 'Mother Shahraz'}];
let dupsChecked = false;
let glRows = [], amRows = [], amBank = null;
const $ = sel => { if (sel === '#glDups') return {checked: dupsChecked}; throw new Error('unexpected ' + sel); };
let seq = 0;
const uid = () => 'u' + (++seq);
function lateOn(date){ const n = nightOn(date); return n && n.late ? n.late : {}; }
`;

const mod = {exports: {}};
new Function('module', STUBS + '\n' + src + `
module.exports = {
  run(fn){ return fn({amSplit, amParse, amAwardRows, amGoneRows, glResolve, amApplyAwardChanges, amResolve, importAmisia, nightExtraLoot,
    importSig, forgetImport, setState: s => { state = s; }, getState: () => state, setDups: v => { dupsChecked = v; }, setAmRows: r => { amRows = r; }}); },
};`)(mod);
const api = mod.exports;

const DATE = '2026-09-09';
const ledger = (awards, extra) => Object.assign({
  raiders: [{id: 'r1', name: 'Fraktur', cls: 'Shaman'}, {id: 'r2', name: 'Vuloo', cls: 'Priest'}],
  awards, nights: [], matloot: [], otherLoot: [], lootDrops: [], lootOk: [], itemNames: {}, addonSessions: [], dropped: [],
}, extra || {});
const award = o => Object.assign({id: 'a1', date: DATE, boss: 'Illidan Stormrage', item: 32235, raider: 'r1', note: '', ts: 1757444400000, src: DATE + '|32235|fraktur'}, o);
const session = o => Object.assign({sid: '20260909200000-564', date: DATE, instance: 564, zone: 'Black Temple',
  members: [{name: 'Fraktur', cls: 'Shaman', first: 1, late: false}, {name: 'Vuloo', cls: 'Priest', first: 1, late: false}],
  loot: [], items: [], drops: [], awards: [], away: [], gone: [], names: {}}, o);
const row = o => Object.assign({item: 32235, rawName: 'Fraktur', name: 'Fraktur', date: DATE, ts: 1757444400000, os: false, key: null, cls: 'Shaman',
  boss: 'Illidan Sturmgrimm', note: '', amKey: 'id1', amEdited: 0}, o);
const pick = (r, keys) => { const o = {}; for (const k of keys) if (r[k] !== undefined) o[k] = r[k]; return o; };
const RESOLVED = ['status', 'why', 'awardId', 'change', 'fill', 'removed', 'name', 'amKey'];

const out = {};
// An export of the addon, parsed as the page does it: one plain award, one renamed with a note,
// one bank award, one disenchanted and one deleted.
const EXPORT = [
  '#AMISIA 2 Vuloo',
  'S 20260909200000-564 2026-09-09 564 Black Temple',
  'M Fraktur SHAMAN 1 0', 'M Vuloo PRIEST 1 0',
  'A Fraktur 32235 1757444400 MS Illidan Sturmgrimm',
  'AX id1 0 -',
  'A Vuloo 32837 1757444460 OS Illidan Sturmgrimm',
  'AX id2 1757448000 Fraktur Tausch mit Fraktur',
  'AS id3 32524 1757444520 BANK Vulo_Bank Mutter Shahraz',
  'AX id3 0 -',
  'AS id4 32837 1757444580 DE - Illidan Sturmgrimm',
  'AX id4 0 - zweites Schwert',
  'AD id5 32235 1757444640 1757448100',
  'E',
  'N 32235 4 Cursed Vision of Sargeras', 'N 32837 5 Warglaive of Azzinoth', 'N 32524 4 Shroud of the Highborne',
  '#END', ''].join('\n');

api.run(a => {
  const sessions = a.amParse(a.amSplit(EXPORT).blocks);
  const s = sessions[0];
  out.parsed = {awards: s.awards, away: s.away, gone: s.gone};
  out.rows = a.amAwardRows(sessions);
});

// 1. The same export again: every award with its id is already there.
api.run(a => {
  a.setState(ledger([award({am: 'id1', amEdited: 0})]));
  const r = a.glResolve([row()]);
  out.dup = pick(r[0], RESOLVED);
});

// 2. Renamed in game after the import: the award moves to the new winner, the note comes along,
// and the old winner's signature is remembered as dropped.
api.run(a => {
  a.setState(ledger([award({am: 'id1', amEdited: 0})]));
  const r = a.glResolve([row({name: 'Vuloo', rawName: 'Vuloo', cls: 'Priest', orig: 'Fraktur', amEdited: 1757448000, note: 'Tausch'})]);
  const res = a.amApplyAwardChanges(r);
  const st = a.getState();
  out.change = {row: pick(r[0], RESOLVED), result: res, award: st.awards[0], dropped: st.dropped, raiders: st.raiders.length};
  // the second officer's export still names the old winner under its own id, or without any id
  const again = a.glResolve([row({amKey: 'id9', amEdited: 0}), row({amKey: undefined, amEdited: undefined}), row({name: 'Vuloo', rawName: 'Vuloo', amKey: 'id9'})]);
  out.change.secondRecorder = again.map(x => pick(x, RESOLVED));
});

// 3. Changed on the site after the import, then the older export again: the site's change stays.
api.run(a => {
  a.setState(ledger([award({am: 'id1', amEdited: 1757450000, raider: 'r2', src: DATE + '|32235|vuloo', note: 'OS'})]));
  const r = a.glResolve([row({amEdited: 1757448000})]);
  const res = a.amApplyAwardChanges(r);
  out.older = {row: pick(r[0], RESOLVED), result: res, award: a.getState().awards[0]};
});

// 3b. A note or OS edited in game is a change as well; a new winner the roster lacks is created.
api.run(a => {
  a.setState(ledger([award({am: 'id1', amEdited: 0})]));
  const r = a.glResolve([row({os: true, note: 'SR', amEdited: 5}), row({item: 32837, name: 'Neuling', rawName: 'Neuling', cls: 'Mage', amKey: 'id2', amEdited: 7})]);
  a.getState().awards.push(award({id: 'a2', item: 32837, am: 'id2', amEdited: 0, src: DATE + '|32837|fraktur'}));
  const r2 = a.glResolve(r);
  const res = a.amApplyAwardChanges(r2);
  const st = a.getState();
  out.noteChange = {rows: r2.map(x => pick(x, RESOLVED)), result: res, awards: st.awards, raiders: st.raiders.map(x => x.name)};
});

// 4. Deleted in game: the award goes, and neither its id nor its signature comes back.
api.run(a => {
  a.setState(ledger([award({am: 'id1', amEdited: 0}), award({id: 'a2', item: 32837, am: 'id2', src: DATE + '|32837|fraktur'})]));
  const rows = a.amGoneRows([session({gone: [{uid: 'id1', item: 32235, at: 1757444400, deleted: 1757448100}, {uid: 'nobody', item: 32524, at: 1, deleted: 2}]})]);
  const res = a.amApplyAwardChanges(rows);
  const st = a.getState();
  const back = a.glResolve([row(), row({amKey: undefined, amEdited: undefined})]);
  out.gone = {rows: rows.map(x => pick(x, [...RESOLVED, 'gone', 'item'])), result: res, awards: st.awards.map(x => x.id), dropped: st.dropped,
    back: back.map(x => pick(x, RESOLVED)), passThrough: a.glResolve(rows).map(x => x.status)};
});

// 5. An award imported from 1.4 has no id yet: the first export with ids fills it in, and a winner
// renamed in game since then (orig names the one the ledger knows) moves it.
api.run(a => {
  a.setState(ledger([award({}), award({id: 'a2', item: 32837, raider: 'r2', src: DATE + '|32837|vuloo'}), award({id: 'a3', item: 32524, raider: 'r1', src: DATE + '|32524|fraktur', boss: 'Mother Shahraz', bq: 1})]));
  const r = a.glResolve([row(), row({item: 32837, name: 'Fraktur', orig: 'Vuloo', amKey: 'id2', amEdited: 9}), row({item: 32524, amKey: 'id3', boss: 'Illidan Sturmgrimm'})]);
  const res = a.amApplyAwardChanges(r);
  out.fill = {rows: r.map(x => pick(x, RESOLVED)), result: res, awards: a.getState().awards};
  // what the import button does with a fill row
  for (const x of r.filter(y => y.status === 'fill')) { const aw = a.getState().awards.find(y => y.id === x.awardId); if (x.fill.am) { aw.am = x.fill.am; aw.amEdited = x.amEdited || 0; } }
  out.fill.afterFill = a.getState().awards.map(x => pick(x, ['id', 'am', 'amEdited']));
  out.fill.again = a.glResolve([row()]).map(x => x.status);
});

// 6. Bank and disenchant: ignored in the award preview, no raider, kept in lootAway once, and the
// night no longer lists the item as dropped but not handed out.
api.run(a => {
  a.setState(ledger([], {lootDrops: [{key: DATE + '|564|32524|Mutter Shahraz', date: DATE, instance: 564, item: 32524, count: 1, source: 'Mutter Shahraz'}]}));
  const sessions = a.amParse(a.amSplit(EXPORT).blocks);
  const resolved = a.glResolve(a.amAwardRows(sessions));
  out.away = {rows: resolved.filter(x => x.away).map(x => pick(x, [...RESOLVED, 'away', 'item'])), before: a.nightExtraLoot(DATE).left};
  const first = a.amResolve(sessions);
  out.away.firstStatus = first[0].status;
  a.setAmRows(first);
  a.importAmisia();
  const st = a.getState();
  out.away.lootAway = st.lootAway;
  out.away.raiders = st.raiders.map(x => x.name);
  out.away.after = a.nightExtraLoot(DATE).left;
  // the same export again adds nothing
  const second = a.amResolve(sessions);
  out.away.secondStatus = second[0].status;
  a.setAmRows(second.map(x => Object.assign({}, x, {status: 'ok'})));
  a.importAmisia();
  out.away.lootAwayAfterTwice = a.getState().lootAway.length;
});

process.stdout.write(JSON.stringify(out));
