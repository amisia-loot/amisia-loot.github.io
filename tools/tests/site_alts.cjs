// Runs the ledger's alt code out of index.html: mainIdOf / altsOf / groupIds / setMain decide which
// character belongs to which main, attendance and nightMark add up the characters of a player,
// altAddonText writes the text for the addon, removeRaider unlinks the alts of a removed main.
// Prints the results as JSON; tools/tests/test_alts_site.py checks them and feeds the text into
// the addon's own parser.
process.env.TZ = 'UTC';
const {grab} = require('./site_parser.cjs');

const NEEDED = ['raiderById', 'nights', 'nightOn', 'allNights', 'countedNights', 'presentOn', 'lateOn', 'BENCH_MODES', 'benchMode',
  'benchOn', 'missedNight', 'attendance', 'mainIdOf', 'altsOf', 'groupIds', 'mainRaiders', 'awardsOfGroup', 'nightMark', 'setMain',
  'altAddonText', 'removeRaider'];
// What else the code reaches for on the page, kept as small as the code allows.
const STUBS = `
let state = {raiders: [], awards: [], nights: []};
const PLAY = 'forever';
const BOSSZONE = {Gruul: 'gruul', Moroes: 'kara'};
const today = () => '2026-10-06';
const fitShelf = s => { s.shelf = s.shelf || {}; };
const inArchive = () => false;
const allBuckets = s => [s];
const forgetRaider = (b, rid) => { b.awards = (b.awards || []).filter(a => a.raider !== rid); };
`;
const src = STUBS + NEEDED.map(grab).join('\n\n') + `
;module.exports = {mainIdOf, altsOf, groupIds, mainRaiders, awardsOfGroup, setMain, altAddonText, attendance, missedNight, nightMark,
  removeRaider, get: () => state, set: s => { state = s; }};`;
const mod = {exports: {}};
new Function('module', 'exports', src)(mod, mod.exports);
const api = mod.exports;
const out = {};
const ids = list => list.map(r => r.id);

// a roster from before the alts: everyone is their own main, no text
const raiders = [{id: 'a', name: 'Anna', cls: 'Priest'}, {id: 'b', name: 'Bob', cls: 'Mage'}, {id: 'z', name: 'Zed Zorn', cls: 'Rogue'},
  {id: 'c', name: 'Chorf', cls: 'Warrior'}, {id: 'v', name: 'Vulo Sturmwind', cls: 'Mage'}];
api.set({raiders, awards: [], nights: []});
out.before = {main: api.mainIdOf('b'), group: api.groupIds('a'), mains: ids(api.mainRaiders()), text: api.altAddonText()};

// linking: Bob and Zed to Anna; refused: Anna to Chorf (has alts), Chorf to Bob (an alt), self
out.link = [api.setMain('b', 'a'), api.setMain('z', 'a'), api.setMain('a', 'c'), api.setMain('c', 'b'), api.setMain('c', 'c'), api.setMain('c', 'nobody'), api.setMain('nobody', 'a')];
out.after = {main: api.mainIdOf('b'), mainOfMain: api.mainIdOf('a'), alts: ids(api.altsOf('a')), altsOfAlt: ids(api.altsOf('b')),
  group: api.groupIds('z'), mains: ids(api.mainRaiders())};
// a broken link from a hand-edited ledger: a chain and a dangling id are ignored
api.get().raiders.push({id: 'x', name: 'Xaver', cls: 'Druid', main: 'b'}, {id: 'y', name: 'Yvonne', cls: 'Druid', main: 'gone'});
out.broken = {chain: api.mainIdOf('x'), dangling: api.mainIdOf('y'), alts: ids(api.altsOf('a')), mains: ids(api.mainRaiders())};
api.get().raiders.splice(-2, 2);

// the text for the addon: one line per alt by main, then alt, "_" for a space
out.text = api.altAddonText();

// attendance over four nights: Anna there, Bob there (late), Zed on the bench, nobody
const st = api.get();
st.nights = [
  {date: '2026-10-01', present: ['a']},
  {date: '2026-10-02', present: ['b'], late: {b: 1759430000}},
  {date: '2026-10-03', present: [], bench: {z: {sid: 's', at: 1, self: true, note: 'voll'}}},
  {date: '2026-10-04', present: ['c']},
  {date: '2026-10-05', present: ['a', 'b'], late: {b: 1759690000}},
];
st.awards = [{id: 'w1', raider: 'b', date: '2026-10-02', boss: 'Gruul', item: 1}, {id: 'w2', raider: 'a', date: '2026-10-01', boss: 'Moroes', item: 2},
  {id: 'w3', raider: 'c', date: '2026-10-04', boss: 'Gruul', item: 3}];
out.attAnnaAlone = api.attendance('a');
out.attAnna = api.attendance('a', api.groupIds('a'));
out.attBob = api.attendance('b');
out.missed = ['2026-10-01', '2026-10-03', '2026-10-04'].map(d => api.missedNight('a', d, api.groupIds('a')));
out.marks = st.nights.map(n => api.nightMark(api.groupIds('a'), n.date));
out.awardsOfGroup = api.awardsOfGroup('a').map(a => a.id);
out.awardsOfGroupZone = api.awardsOfGroup('a', 'gruul').map(a => a.id);
// unlinking is lossless: Bob counts on his own again
api.setMain('b', '');
out.unlinked = {main: api.mainIdOf('b'), anna: api.attendance('a', api.groupIds('a')), bob: api.attendance('b', api.groupIds('b'))};
api.setMain('b', 'a');

// removing the main: the alts stand on their own, their records stay
api.removeRaider(st, 'a');
out.removed = {raiders: ids(st.raiders), mainB: api.mainIdOf('b'), hasMainField: st.raiders.some(r => 'main' in r),
  awards: st.awards.map(a => a.id), text: api.altAddonText()};
process.stdout.write(JSON.stringify(out));
