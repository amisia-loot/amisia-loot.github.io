// Runs the ledger's guild bank needs and log code out of index.html: merging the addon's log
// entries without duplicates, what an import would change, the need line of a material and the
// needed materials in the Mats list. Prints the results as JSON; tools/tests/test_site_bank.py
// checks them.
const {grab} = require('./site_parser.cjs');

const NEEDED = ['glCleanName', 'amParseGuildBank', 'bankLogMerge', 'amGuildResolve', 'needInfo', 'MATS', 'matsHere'];
const STUBS = `
let state = {}, gameKey = 'forever';
const ITEM = {};
const anyItemName = id => 'Item ' + id;
`;
const src = STUBS + NEEDED.map(grab).join('\n\n') + `
;module.exports = {amParseGuildBank, bankLogMerge, amGuildResolve, needInfo, matsHere, set: o => { state = o; }};`;
const mod = {exports: {}};
new Function('module', 'exports', src)(mod, mod.exports);
const api = mod.exports;
const out = {};

const e = (lo, hi, extra) => Object.assign({lo, hi, tab: 1, kind: 'deposit', item: 61001, count: 20, t1: 0, t2: 0, name: 'Anna'}, extra || {});
// the same entry read by two officers an hour apart: one entry, the window narrowed
let m = api.bankLogMerge([e(1000, 4600)], [e(3000, 6600)]);
out.narrow = {n: m.list.length, added: m.added, lo: m.list[0].lo, hi: m.list[0].hi};
// two equal deposits in one export stay two; a third matches neither of the saved twice
m = api.bankLogMerge([], [e(1000, 4600), e(1000, 4600)]);
out.twins = m.added;
m = api.bankLogMerge(m.list, [e(1200, 4800), e(1200, 4800), e(1200, 4800)]);
out.third = m.added;
// another hour, another name, another count: new
m = api.bankLogMerge([e(1000, 4600)], [e(9000, 12600), e(1000, 4600, {name: 'Bob'}), e(1000, 4600, {count: 19})]);
out.others = m.added;
// newest first, at most 1000
const many = [];
for (let i = 0; i < 1100; i++) many.push(e(i * 4000, i * 4000 + 3600));
m = api.bankLogMerge([], many);
out.cap = {n: m.list.length, first: m.list[0].hi};

// every need taken out in the addon: "BQ 0 ..." is an empty, newer list that replaces the old one
const emptyNeeds = api.amParseGuildBank(['#AMISIA 2 Vuloo\nBQ 0 0 0 200 Vulo_Sturmwind\n#END']).needs;
out.empty = {parsed: emptyNeeds, resolved: api.amGuildResolve({needs: emptyNeeds, log: []},
  {bankNeeds: {at: 100, by: 'Vuloo', items: {61001: {min: 40, target: 80}}, pledges: []}, bankLog: []})};

// what an import changes
const needs = {at: 100, by: 'Vuloo', items: {61001: {min: 40, target: 80}}, pledges: [{item: 61001, count: 5, at: 90, name: 'Anna'}]};
out.fresh = api.amGuildResolve({needs, log: [e(1000, 4600)]}, {bankNeeds: null, bankLog: []});
out.older = api.amGuildResolve({needs: Object.assign({}, needs, {at: 50}), log: []}, {bankNeeds: needs, bankLog: []});
out.samePledges = api.amGuildResolve({needs, log: [e(1000, 4600)]}, {bankNeeds: needs, bankLog: [e(1000, 4600)]});
out.newPledges = api.amGuildResolve({needs: Object.assign({}, needs, {pledges: []}), log: []}, {bankNeeds: needs, bankLog: []});

// the need line of a material, against the last count
const st = {raiders: [], awards: [], bank: {at: 1, items: {61001: 12, 61002: 60, 61003: 500}},
  bankNeeds: {at: 100, by: 'Vuloo', items: {61001: {min: 40, target: 80}, 61002: {min: 50, target: 100}, 61003: {min: 10, target: 0}, 61004: {min: 5, target: 0}},
    pledges: [{item: 61001, count: 5, at: 90, name: 'Anna'}, {item: 61001, count: 7, at: 91, name: 'Bob'}]}};
api.set(st);
out.need = [61001, 61002, 61003, 61004, 61005].map(id => api.needInfo(id));
out.mats = api.matsHere().map(x => x.id);

process.stdout.write(JSON.stringify(out));
