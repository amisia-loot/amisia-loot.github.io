// Runs the ledger's material list out of index.html: the TBC archive keeps its fixed list, Forever
// derives its list from the imported data (looted materials and the last guild bank count), named
// from the loot tables or the names the addon sent. Prints the results as JSON;
// tools/tests/test_site_mats.py checks them.
const {grab} = require('./site_parser.cjs');

const NEEDED = ['MATS', 'matsHere', 'matName', 'anyItemName'];
const STUBS = `
let state = {}, gameKey = 'forever';
const ITEM = {5001: {id: 5001, name: 'Table Ore'}};
`;
const src = STUBS + NEEDED.map(grab).join('\n\n') + `
;module.exports = {matsHere, matName, set: o => { if ('state' in o) state = o.state; if ('gameKey' in o) gameKey = o.gameKey; }};`;
const mod = {exports: {}};
new Function('module', 'exports', src)(mod, mod.exports);
const api = mod.exports;
const out = {};

// Forever with nothing imported yet
api.set({state: {raiders: [], awards: []}, gameKey: 'forever'});
out.empty = api.matsHere();

// Forever with looted materials, a bank count and names from the addon
api.set({state: {raiders: [], awards: [],
  matloot: [{key: 'k1', date: '2026-11-05', instance: 409, raider: 'a', item: 61005, count: 2},
    {key: 'k2', date: '2026-11-05', instance: 409, raider: 'b', item: 61001, count: 1},
    {key: 'k3', date: '2026-11-06', instance: 409, raider: 'a', item: 61001, count: 3},
    {key: 'k4', date: '2026-11-06', instance: 409, raider: 'a', item: 5001, count: 1}],
  bank: {at: 1, date: '2026-11-06', time: '20:00', by: 'Anna', items: {61001: 9, 61011: 0}},
  itemNames: {61001: {n: 'Fiery Core', q: 3}, 61005: {n: 'Lava Core', q: 3}, 61011: {n: 'Late Cloth', q: 2}}}, gameKey: 'forever'});
out.forever = api.matsHere();
out.names = {61005: api.matName(61005), 5001: api.matName(5001), 99: api.matName(99)};

// a bank count alone, without loot
api.set({state: {raiders: [], awards: [], bank: {at: 1, items: {61011: 4}}, itemNames: {}}});
out.bankOnly = api.matsHere();

// the TBC archive keeps the fixed list
api.set({state: {raiders: [], awards: [], matloot: [{item: 61001, count: 1}], itemNames: {61001: {n: 'Fiery Core'}}}, gameKey: 'tbc'});
out.tbc = api.matsHere().map(m => m.id);
out.tbcName = api.matName(32897);

process.stdout.write(JSON.stringify(out));
