// Runs the ledger's wishlist code for the Amisia addon out of index.html: amParseWishes reads the
// addon's WL lines, wishImportPlan decides what "Paste from the addon" would add, wishAddonText
// writes the text for /amisia wuensche. Prints the results as JSON; tools/tests/test_wish_import.py
// checks them and feeds the text into the addon's own parser.
process.env.TZ = 'UTC';
const {grab} = require('./site_parser.cjs');

const NEEDED = ['GL_CLASS', 'CLASS_ALIAS', 'glCleanName', 'classFromAny', 'amSplit', 'amParse', 'amParseWishes',
  'wishesHere', 'wishGot', 'amLikely', 'wishImportPlan', 'wishAddonText'];
// What else the code reaches for on the page, kept as small as the code allows.
const STUBS = `
let state = {raiders: [], awards: []}, WISHES = [], ITEM = {}, gameKey = 'tbc';
const today = () => '2026-10-05';
const raiderById = id => state.raiders.find(r => r.id === id);
`;
const src = STUBS + NEEDED.map(grab).join('\n\n') + `
;module.exports = {amSplit, amParse, amParseWishes, wishImportPlan, wishAddonText,
  set: (s, w, items, game) => { state = s; WISHES = w; ITEM = items; gameKey = game || 'tbc'; }};`;
const mod = {exports: {}};
new Function('module', 'exports', src)(mod, mod.exports);
const api = mod.exports;
const out = {};

// a raid export and a wishlist in one paste: each import reads only its own lines
const RAID = ['#AMISIA 2 Vuloo', 'S 20261001195500-532 2026-10-01 532 Karazhan', 'M Vuloo PRIEST 1759340100 0',
  'L Vuloo 22450 2', 'E', '#END'].join('\n');
const WL = ['#AMISIA 2 Vulo_Sturmwind', 'WL 28830 3 1759601000 Vulo_Sturmwind nur MS, bitte', 'WL 29434 1 1759601100 Vulo_Sturmwind',
  'WL 30000 7 1759601200 Vulo_Sturmwind', 'WL abc 2 1759601300 Vulo_Sturmwind', 'WL 31000 2 1759601400', 'WL 32000 2 x Vulo_Sturmwind',
  'WL 33000 2 1759601500 Vulo_Sturmwind ' + 'n'.repeat(100), '#END'].join('\n');
const both = api.amSplit(RAID + '\n\n' + WL + '\n');
out.blocks = both.blocks.length;
out.rest = both.rest.trim();
out.raid = api.amParse(both.blocks);
out.wishes = api.amParseWishes(both.blocks);
out.wishesOfRaid = api.amParseWishes(api.amSplit(RAID).blocks);
out.raidOfWishes = api.amParse(api.amSplit(WL).blocks);

// the plan: new, already on the list, already received, not in the loot tables, unknown raider,
// the same wish twice in one paste, over the limit of 30 open wishes
const raiders = [{id: 'a', name: 'Anna', cls: 'Priest'}, {id: 'b', name: 'Bob', cls: 'Mage'}, {id: 'v', name: 'Vulo Sturmwind', cls: 'Mage'},
  {id: 'f', name: 'Full', cls: 'Rogue'}];
const items = {28830: {name: 'Crown', sources: ['Prince Malchezaar', 'Moroes']}, 29434: {name: 'Cloak', sources: ['Gruul']},
  30000: {name: 'Ring', sources: ['Magtheridon']}, 30001: {name: 'Belt', sources: ['Netherspite']}};
const existing = [{id: 'w1', game: 'tbc', raider: 'a', raider_name: 'Anna', item: 28830, prio: 2, note: ''},
  {id: 'w2', game: 'forever', raider: 'b', raider_name: 'Bob', item: 29434, prio: 2, note: ''}];
for (let i = 0; i < 29; i++) existing.push({id: 'f' + i, game: 'tbc', raider: 'f', raider_name: 'Full', item: 40000 + i, prio: 2, note: ''});
// one more of Full's, received, does not count against the limit
existing.push({id: 'fg', game: 'tbc', raider: 'f', raider_name: 'Full', item: 49999, prio: 2, note: ''});
const awards = [{raider: 'b', item: 30000}, {raider: 'f', item: 49999}];
api.set({raiders, awards}, existing, items, 'tbc');
const pasted = [
  {item: 28830, prio: 3, at: 1, name: 'Anna', note: ''},            // already on the list
  {item: 29434, prio: 2, at: 1, name: 'Bob', note: 'only MS'},      // new (Bob's wish of the other game does not count)
  {item: 30000, prio: 2, at: 1, name: 'Bob', note: ''},             // already received
  {item: 99999, prio: 2, at: 1, name: 'Anna', note: ''},            // not in the loot tables
  {item: 30001, prio: 1, at: 1, name: 'Zed', note: ''},             // unknown raider
  {item: 30001, prio: 1, at: 1, name: 'anna', note: ''},            // new, the name in any case
  {item: 30001, prio: 3, at: 1, name: 'Anna', note: ''},            // the same again in this paste
  {item: 28830, prio: 2, at: 1, name: 'Full', note: ''},            // the 30th open wish: new
  {item: 29434, prio: 2, at: 1, name: 'Full', note: ''},            // the 31st: over the limit
];
out.plan = api.wishImportPlan(pasted).map(p => ({item: p.item, name: p.name, status: p.status, raider: p.raider ? p.raider.id : null,
  boss: p.boss || null, prio: p.prio, note: p.note}));

// Forever names "First_Last" against a roster that has the first name only: the same name first,
// then the one raider of that first name
api.set({raiders: raiders.concat([{id: 'k', name: 'Kim', cls: 'Mage'}, {id: 'k2', name: 'Kim Eisherz', cls: 'Mage'}]), awards: []},
  [], items, 'tbc');
out.planNames = api.wishImportPlan([
  {item: 30001, prio: 2, at: 1, name: 'Bob Baumann', note: ''},     // Bob on the roster
  {item: 30001, prio: 2, at: 1, name: 'Vulo Sturmwind', note: ''},  // the full name is on the roster
  {item: 30001, prio: 2, at: 1, name: 'Kim Eisherz', note: ''},     // the same name wins over "Kim"
  {item: 30001, prio: 2, at: 1, name: 'Kim Feuerherz', note: ''},   // first name Kim: only "Kim" carries it exactly
  {item: 30001, prio: 2, at: 1, name: 'Zed Zorn', note: ''},        // nobody
]).map(p => [p.name, p.raider ? p.raider.id : null, p.status]);

// the text for the addon: open wishes of this game only, by item, then priority; names with "_"
const forText = [
  {id: 'x1', game: 'tbc', raider: 'v', raider_name: 'Vulo Sturmwind', item: 30001, prio: 1, note: 'nach | dem\nBoss'},
  {id: 'x2', game: 'tbc', raider: 'a', raider_name: 'Anna', item: 28830, prio: 2, note: ''},
  {id: 'x3', game: 'tbc', raider: 'b', raider_name: 'Bob', item: 28830, prio: 3, note: 'nur MS'},
  {id: 'x4', game: 'tbc', raider: 'b', raider_name: 'Bob', item: 30000, prio: 3, note: ''},           // received
  {id: 'x5', game: 'forever', raider: 'a', raider_name: 'Anna', item: 18832, prio: 3, note: ''},      // another game
  {id: 'x6', game: 'tbc', raider: 'gone', raider_name: 'Alt Name', item: 29434, prio: 2, note: ''},   // raider no longer on the roster
];
api.set({raiders, awards}, forText, items, 'tbc');
out.text = api.wishAddonText(forText);
api.set({raiders, awards}, forText, items, 'forever');
out.textForever = api.wishAddonText(forText);
api.set({raiders, awards}, [], items, 'tbc');
out.empty = api.wishAddonText([]);
process.stdout.write(JSON.stringify(out));
