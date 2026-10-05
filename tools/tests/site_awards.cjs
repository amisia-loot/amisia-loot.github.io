// Runs the ledger's award import out of index.html (glResolve, amAwardRows, amGoneRows,
// amApplyAwardChanges, amResolve, importAmisia, nightExtraLoot) against small ledgers and prints
// what each scenario did as JSON. tools/tests/test_award_import.py checks that an award the Amisia
// addon exports with its id is recognised again, that changes made in game move the award, that
// an older export never overwrites a change made on the site, that deletions in game remove the
// award, and that hand-outs to the bank or the disenchanter create no raider.
const {grab} = require('./site_parser.cjs');

const NEEDED = ['GL_CLASS', 'CLASS_ALIAS', 'glCleanName', 'classFromAny', 'amSplit', 'amParse', 'amAwardRows', 'amGoneRows',
  'importSig', 'forgetImport', 'glResolve', 'amApplyAwardChanges', 'amLate', 'amNightLog', 'amResolve', 'importAmisia', 'nightExtraLoot',
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

// 7. Review fixes. A note may carry "#END" or "#AMISIA": only a line that is exactly the marker
// ends or starts a block, with LF or CRLF.
const NOTED = ['#AMISIA 2 Vuloo', 'S 20260909200001-564 2026-09-09 564 Black Temple', 'M Fraktur SHAMAN 1 0', 'M Vuloo PRIEST 1 0',
  'A Fraktur 32235 1757444401 MS Illidan_Sturmgrimm', 'AX aaaaaaaaaaaa 0 - bis #END fertig #AMISIA 2 x',
  'A Vuloo 32837 1757444402 MS Illidan_Sturmgrimm', 'AX bbbbbbbbbbbb 0 - #END', 'E',
  'S 20260910200001-564 2026-09-10 564 Black Temple', 'M Vuloo PRIEST 1 0', 'E', 'N 32235 4 Cursed', '#END'].join('\n');
api.run(a => {
  out.marker = {};
  for (const [k, t] of [['lf', NOTED], ['crlf', NOTED.replace(/\n/g, '\r\n') + '\r\n'], ['twice', NOTED + '\n' + NOTED.replace(/aaaa/g, 'cccc')]]) {
    const sp = a.amSplit(t), ss = a.amParse(sp.blocks);
    out.marker[k] = {blocks: sp.blocks.length, rest: sp.rest.trim(), sessions: ss.map(z => [z.date, z.awards.map(x => [x.name, x.uid, x.note || null])])};
  }
});

// 8. Two officers' 1.5 exports of the same raid pasted together: one award, not two. Two copies
// of the same item to the same raider within one recording stay two.
const officer = (who, id, t, extra) => ['#AMISIA 2 ' + who, 'S 2026090920000' + t + '-564 2026-09-09 564 Black Temple', 'M Fraktur SHAMAN 1 0',
  'A Fraktur 32235 175744440' + t + ' MS Illidan_Sturmgrimm', 'AX ' + id + ' 0 -', ...(extra || []), 'E', '#END'].join('\n');
api.run(a => {
  a.setState(ledger([]));
  const rowsOf = t => a.glResolve(a.amAwardRows(a.amParse(a.amSplit(t).blocks)));
  out.officers = {
    both: rowsOf(officer('Vuloo', 'aaaaaaaaaaaa', '1') + '\n' + officer('Other', 'bbbbbbbbbbbb', '2')).map(r => r.status),
    twoCopies: rowsOf(officer('Vuloo', 'aaaaaaaaaaaa', '1', ['A Fraktur 32235 1757444409 MS Illidan_Sturmgrimm', 'AX dddddddddddd 0 -'])).map(r => r.status),
    twoCopiesBoth: rowsOf(officer('Vuloo', 'aaaaaaaaaaaa', '1', ['A Fraktur 32235 1757444409 MS Illidan_Sturmgrimm', 'AX dddddddddddd 0 -'])
      + '\n' + officer('Other', 'bbbbbbbbbbbb', '2', ['A Fraktur 32235 1757444408 MS Illidan_Sturmgrimm', 'AX eeeeeeeeeeee 0 -'])).map(r => r.status),
  };
});
// 8b. Officer A's copy is in the ledger; officer B renamed the winner in game under B's own id.
api.run(a => {
  a.setState(ledger([award({am: 'aaaaaaaaaaaa', amEdited: 0})]));
  const r = a.glResolve([row({name: 'Vuloo', rawName: 'Vuloo', cls: 'Priest', orig: 'Fraktur', amKey: 'bbbbbbbbbbbb', amEdited: 1757448000})]);
  const res = a.amApplyAwardChanges(r);
  const st = a.getState();
  out.renamedByOther = {row: pick(r[0], RESOLVED), result: res, awards: st.awards.map(x => pick(x, ['id', 'raider', 'am', 'amEdited'])),
    again: a.glResolve([row({name: 'Vuloo', rawName: 'Vuloo', cls: 'Priest', orig: 'Fraktur', amKey: 'bbbbbbbbbbbb', amEdited: 1757448000}), row({amKey: 'aaaaaaaaaaaa'})]).map(x => x.status)};
  // the rename by B is older than what the ledger knows of the award: nothing changes
  a.setState(ledger([award({am: 'aaaaaaaaaaaa', amEdited: 1757450000})]));
  const o = a.glResolve([row({name: 'Vuloo', rawName: 'Vuloo', cls: 'Priest', orig: 'Fraktur', amKey: 'bbbbbbbbbbbb', amEdited: 1757448000})]);
  out.renamedByOther.older = {row: pick(o[0], RESOLVED), result: a.amApplyAwardChanges(o), awards: a.getState().awards.map(x => pick(x, ['id', 'raider', 'am']))};
});

// 9. Player, bank and disenchant: a change of target and a deletion reach the ledger, both ways,
// and a second import of the same export changes nothing.
const awayExport = lines => ['#AMISIA 2 V', 'S 20260909200001-564 2026-09-09 564 Black Temple', 'M Fraktur SHAMAN 1 0', ...lines, 'E', '#END'].join('\n');
// what the import button does: changes and deletions first, then the sessions
const importAll = (a, t) => {
  const ss = a.amParse(a.amSplit(t).blocks);
  const rows = a.glResolve(a.amAwardRows(ss)).concat(a.amGoneRows(ss));
  const res = a.amApplyAwardChanges(rows.filter(x => x.status === 'change' || x.status === 'gone'));
  const sess = a.amResolve(ss); a.setAmRows(sess); a.importAmisia();
  return {rows: rows.map(x => pick(x, [...RESOLVED, 'away'])), result: res, session: sess.map(x => x.status)};
};
const looks = a => { const st = a.getState(); return JSON.parse(JSON.stringify({awards: st.awards.map(x => pick(x, ['id', 'raider', 'am', 'amEdited', 'item'])), lootAway: st.lootAway || [], dropped: st.dropped})); };
api.run(a => {
  out.toAway = {};
  // a player award moved to the bank in game
  a.setState(ledger([award({am: 'cccccccccccc', amEdited: 0})]));
  const toBank = awayExport(['AS cccccccccccc 32235 1757444401 BANK - Illidan_Sturmgrimm', 'AX cccccccccccc 1757450000 Fraktur']);
  out.toAway.first = importAll(a, toBank); out.toAway.firstState = looks(a);
  out.toAway.again = importAll(a, toBank); out.toAway.againState = looks(a);
  // then to the disenchanter
  const toDe = awayExport(['AS cccccccccccc 32235 1757444401 DE - Illidan_Sturmgrimm', 'AX cccccccccccc 1757451000 Fraktur']);
  out.toAway.de = importAll(a, toDe); out.toAway.deState = looks(a);
  // an export from before the move still names Fraktur: it does not bring the award back
  const before = awayExport(['A Fraktur 32235 1757444401 MS Illidan_Sturmgrimm', 'AX cccccccccccc 0 -']);
  out.toAway.old = importAll(a, before); out.toAway.oldState = looks(a);
  // back to Fraktur in game: the award returns, the bank entry goes
  const back = awayExport(['A Fraktur 32235 1757444401 MS Illidan_Sturmgrimm', 'AX cccccccccccc 1757452000 Fraktur']);
  out.toAway.back = importAll(a, back); out.toAway.backState = looks(a);
  out.toAway.backAgain = importAll(a, back); out.toAway.backAgainState = looks(a);
  // a site change kept over an older bank export
  a.setState(ledger([award({am: 'cccccccccccc', amEdited: 1757460000})]));
  out.toAway.olderBank = importAll(a, toBank); out.toAway.olderBankState = looks(a);
  // a bank entry deleted in game
  a.setState(ledger([], {lootAway: [{key: 'dddddddddddd', date: DATE, instance: 564, item: 32235, to: 'de'}]}));
  const del = awayExport(['AD dddddddddddd 32235 1757444401 1757450000']);
  out.toAway.gone = importAll(a, del); out.toAway.goneState = looks(a);
  out.toAway.goneAgain = importAll(a, del);
  // the export from before the deletion does not bring it back
  out.toAway.goneOld = importAll(a, awayExport(['AS dddddddddddd 32235 1757444401 DE - Illidan_Sturmgrimm', 'AX dddddddddddd 0 -']));
  out.toAway.goneOldState = looks(a);
});

// 10. A hand-out to the bank by master loot: the bank character looted it as well. Each copy counts once.
api.run(a => {
  const base = {raiders: [{id: 'r1', name: 'Fraktur', cls: 'Shaman'}, {id: 'rb', name: 'Bankchar', cls: 'Mage'}],
    otherLoot: [{key: 'k', date: DATE, instance: 564, raider: 'rb', item: 32235, count: 1}],
    lootDrops: [{key: 'd', date: DATE, instance: 564, item: 32235, count: 2, source: 'Illidan Stormrage'}]};
  const away = [{key: 'u1', date: DATE, instance: 564, item: 32235, to: 'bank'}];
  a.setState(ledger([], Object.assign({}, base)));
  out.bankLoot = {without: a.nightExtraLoot(DATE)};
  a.setState(ledger([], Object.assign({}, base, {lootAway: away})));
  out.bankLoot.oneLeft = a.nightExtraLoot(DATE);
  // the other copy went to Fraktur: nothing left, and the bank character's copy is no clash
  a.setState(ledger([award({})], Object.assign({}, base, {lootAway: away,
    otherLoot: base.otherLoot.concat([{key: 'k2', date: DATE, instance: 564, raider: 'r1', item: 32235, count: 1}])})));
  out.bankLoot.allOut = a.nightExtraLoot(DATE);
});

process.stdout.write(JSON.stringify(out));
