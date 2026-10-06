// Runs the ledger's drop code out of index.html: amParseDrops reads the DZ/DN/DK lines of the addon's
// text "Drops für die Website", dropPlan says what "Add the kills" would do, dropImport merges the
// kills into the ledger (by kill id, items at their largest count, the smaller origin, no names but
// the bosses' and instances'), and dropTables builds the loot tables per boss from the observations
// of data/forever.js and the kills imported after its day. Prints the results as JSON;
// tools/tests/test_drop_import.py checks them.
process.env.TZ = 'UTC';
const {grab} = require('./site_parser.cjs');

const NEEDED = ['amSplit', 'DROP_DAY0', 'dropDay', 'dropDate', 'dropName', 'amParseDrops', 'dropRecOk', 'dropMergeInto', 'dropPlan',
  'dropImport', 'dropRateText', 'dropTables', 'dropDownload'];
const src = NEEDED.map(grab).join('\n\n') + `
;module.exports = {amSplit, dropDay, dropDate, amParseDrops, dropPlan, dropImport, dropRateText, dropTables, dropDownload};`;
const mod = {exports: {}};
new Function('module', 'exports', src)(mod, mod.exports);
const api = mod.exports;
const out = {};
const clone = x => JSON.parse(JSON.stringify(x));

out.days = {first: api.dropDay('2026-01-01'), oct5: api.dropDay('2026-10-05'), next: api.dropDay('2027-01-01'),
  bad: [api.dropDay('2026-02-30'), api.dropDay('nonsense'), api.dropDay('')], back: api.dropDate(277)};

// a text as the addon writes it, with a raid block and broken lines around
const TEXT = [
  '#AMISIA 2 Vulo_Sturmwind',
  'DZ 2834 party Halle der Thane',
  'DZ 409 raid Geschmolzener Kern',
  'DZ 77 pvp Kaputt',
  'DN 213450 0 Faldrim Ambossmahl',
  'DN 213470 3012 Kurgor der Wächter',
  'DN 0 3020 Geheimer Boss',
  'DK a0000001 213450 2834 1 2026-10-05 3fa9c2e1 G 219004:1,219006:2',
  'DK a0000002 213450 2834 1 2026-10-04 11111111 G -',
  'DK a0000003 213470 409 9 2026-10-06 3fa9c2e1 G 219005:1',
  'DK a0000004 0 2834 1 2026-10-05 3fa9c2e1 E 219006:1',
  'DK a0000001 213450 2834 1 2026-10-05 00000001 G 219004:3',
  'DK zzzzzzzz 213450 2834 1 2026-10-05 3fa9c2e1 G -',
  'DK a0000005 213450 2834 1 2026-13-05 3fa9c2e1 G -',
  'DK a0000006 213450 2834 1 2026-10-05 3fa9c2e1 X -',
  'DK a0000007 0 2834 1 2026-10-05 3fa9c2e1 G -',
  'DK a0000008 213450 2834 1 2026-10-05 3fa9c2e1 G 219004:0',
  'DK a0000009 213450 2834 1 2026-10-05 3fa9c2e1 G 219004',
  '#END'].join('\n');
const blocks = api.amSplit('S 1 2 3\n' + TEXT + '\n').blocks;
out.parsed = api.amParseDrops(blocks);
out.parsedNone = api.amParseDrops(api.amSplit('#AMISIA 2 Vuloo\nWL 28830 3 1759601000 Vuloo\n#END\n').blocks);

// the plan and the import, twice
const st = {raiders: [], awards: []};
out.plan1 = clone(api.dropPlan(out.parsed, st));
delete out.plan1.parsed;
out.import1 = api.dropImport(st, out.parsed);
out.state1 = clone(st);
out.plan2 = clone(api.dropPlan(out.parsed, st));
delete out.plan2.parsed;
out.import2 = api.dropImport(st, out.parsed);
out.state2 = clone(st);
// a second text with the same kill seen by someone else: more items, a smaller origin, a name nobody knew
const OTHER = ['#AMISIA 2 Fraktur',
  'DZ 2834 party Hall of Thanes',
  'DN 213450 0 Faldrim Anvilmeal',
  'DN 213480 0 Neuer Boss',
  'DK a0000001 213450 2834 1 2026-10-05 00000002 G 219004:1,219007:1',
  'DK b0000001 213480 2834 1 2026-10-06 00000002 G 219008:1',
  '#END'].join('\n');
const other = api.amParseDrops(api.amSplit(OTHER).blocks);
out.plan3 = clone(api.dropPlan(other, st));
delete out.plan3.parsed;
out.import3 = api.dropImport(st, other);
out.state3 = clone(st);
// the order of two imports does not matter
const st2 = {raiders: [], awards: []};
api.dropImport(st2, other); api.dropImport(st2, out.parsed);
const sortRecs = s => (s.dropObs || []).slice().sort((a, b) => a[0] < b[0] ? -1 : 1);
out.orderFree = JSON.stringify(sortRecs(st2)) === JSON.stringify(sortRecs(st));
// broken records from a backup are left alone and skipped
const st3 = {raiders: [], awards: [], dropObs: [['a0000001', 1], 'kaputt', null], dropNames: [], dropZones: 'x'};
out.import4 = api.dropImport(st3, out.parsed);
out.state4 = clone(st3);

// the loot tables: forever.js has the base observations up to its day (obsThrough), the ledger the
// kills after it; a raid nobody listed appears from its first imported kill
const DATA = {
  zones: [{key: 'thanes', name: 'Halle der Thane', short: 'Thane', color: ['#111111', '#222222']}],
  bosses: [{name: 'Faldrim Ambossmahl', zone: 'thanes'}],
  items: [{id: 219004, name: 'Ring der Thane', slot: 'finger', sources: ['Faldrim Ambossmahl'], q: 3},
          {id: 219009, name: 'Stab der Thane', slot: 'weapon', sources: ['Faldrim Ambossmahl'], q: 3},
          {id: 219006, name: 'Gürtel', slot: 'waist', sources: ['Unknown source'], q: 2}],
  obsThrough: 277,
  obsZones: [{key: 'thanes', name: 'Halle der Thane', short: 'Thane', inst: 2834, kind: 'party'}],
  obsBosses: [{npc: 213450, name: 'Faldrim Ambossmahl', zone: 'thanes', kills: 40, obs: {219004: 8, 219006: 3}}],
  obsItems: [{id: 219005, name: 'Umhang der Thane', slot: 'back', q: 3}],
};
const led = {raiders: [], awards: []};
api.dropImport(led, out.parsed);   // a0000001 (day 277, in the base already), a0000002 (276), a0000003 (raid 409, day 278)
api.dropImport(led, other);        // a0000001 again, b0000001 (day 278, after the base)
out.tables = api.dropTables(DATA, led);
// without forever.js observations every imported kill counts
out.tablesNoBase = api.dropTables({zones: [], bosses: [], items: []}, led);
out.tablesEmpty = api.dropTables({zones: [], bosses: [], items: []}, {raiders: [], awards: []});
out.rates = [api.dropRateText(9, 41), api.dropRateText(2, 3), api.dropRateText(0, 40), api.dropRateText(5, 5)];
out.download = JSON.parse(api.dropDownload(st));

// hostile names: boss and zone names equal to Object.prototype members are just names
{
  const hostile = Object.create(null);
  for (const name of ['constructor', 'toString', '__proto__', 'hasOwnProperty', 'valueOf']) {
    const text = ['#AMISIA 2 X', 'DZ 99999 party ' + name, 'DN 999001 0 ' + name,
      'DK a0000001 999001 99999 1 2026-10-05 3fa9c2e1 G 219004:1', 'DK a0000002 999001 2834 1 2026-10-05 3fa9c2e1 G -', '#END'].join('\n');
    const led = {raiders: [], awards: []};
    try {
      api.dropImport(led, api.amParseDrops(api.amSplit(text).blocks));
      const t = api.dropTables({zones: [{key: 'x', name: 'X', inst: 1}], items: [{id: 5, name: 'Five', sources: [name]}]}, led);
      hostile[name] = t.map(z => [z.name, z.bosses.map(b => [b.name, b.kills])]);
    } catch (e) { hostile[name] = 'THROWS ' + e.message; }
  }
  out.hostile = hostile;
}

// midnight: a kill data/forever.js holds on its last day (obsIds) counts once when a client dated it
// a day later; two texts with the same kill on two days keep the earlier day
{
  const base = {zones: [{key: 'thanes', name: 'Halle der Thane', inst: 2834}], obsThrough: 276, obsIds: ['a0000001'],
    obsBosses: [{npc: 213450, name: 'Faldrim', zone: 'thanes', kills: 1, obs: {219004: 1}}]};
  const led = {raiders: [], awards: []};
  api.dropImport(led, api.amParseDrops(api.amSplit('#AMISIA 2 B\nDK a0000001 213450 2834 1 2026-10-05 bbbbbbbb G 219004:1\n#END').blocks));
  out.midnight = api.dropTables(base, led)[0].bosses.map(b => [b.name, b.kills, b.items[0].rate]);
  const led2 = {raiders: [], awards: []};
  api.dropImport(led2, api.amParseDrops(api.amSplit('#AMISIA 2 A\nDK a0000009 213450 2834 1 2026-10-05 bbbbbbbb G -\n#END').blocks));
  api.dropImport(led2, api.amParseDrops(api.amSplit('#AMISIA 2 B\nDK a0000009 213450 2834 1 2026-10-04 cccccccc G -\n#END').blocks));
  out.midnightDay = led2.dropObs.map(r => r[4]);
  const one = api.amParseDrops(api.amSplit('#AMISIA 2 A\nDK a0000008 213450 2834 1 2026-10-05 bbbbbbbb G -\nDK a0000008 213450 2834 1 2026-10-04 bbbbbbbb G -\n#END').blocks);
  out.midnightParse = one.kills.map(k => k.day);
  // a kill dated far after today (a wrong clock) is not read
  out.future = api.amParseDrops(api.amSplit('#AMISIA 2 A\nDK a0000007 213450 2834 1 2099-01-01 bbbbbbbb G -\n#END').blocks);
}

// the tab itself, on a small fake page: names from the addon are escaped, items carry no link
{
  const els = {};
  const el = id => els[id] || (els[id] = {id, value: '', innerHTML: '', textContent: '', hidden: false,
    get options() { return [...this.innerHTML.matchAll(/<option value="([^"]*)"/g)].map(m => ({value: m[1]})); }});
  const STUBS = `
let DATA, state, archiveOn = false, readOnly = false;
const ITEM = {}, OBSITEM = {}, SLOTNAME = {finger: 'Ring'};
const zTag = z => '<span class="zone ' + z + '">Z</span>';
const icoHTML = (it, extra, count, link) => '<ico item="' + (it ? it.id : '') + '" link="' + link + '">';
`;
  const page = STUBS + ['esc', 'DROP_DAY0', 'dropRecOk', 'dropRateText', 'dropTables', 'DROP_KIND', 'renderDrops'].map(grab).join('\n\n')
    + `;module.exports = {renderDrops, set: (d, s, ro) => { DATA = d; state = s; readOnly = ro; }};`;
  const m2 = {exports: {}};
  new Function('module', 'exports', '$', page)(m2, m2.exports, sel => el(sel));
  const evil = {raiders: [], awards: [], dropObs: [['c0000001', 777, 55, 1, 300, '00000001', 'G', [5, 1]]],
    dropNames: {777: '<img src=x onerror=alert(1)>'}, dropZones: {55: ['raid', 'Zone "<b>"']}, itemNames: {5: {n: '<i>Item</i>'}}};
  m2.exports.set({zones: [], bosses: [], items: []}, evil, false);
  m2.exports.renderDrops();
  out.page = {body: el('#dropBody').innerHTML, count: el('#dropCount').textContent, download: el('#dropDownload').hidden, zones: el('#dropZone').innerHTML};
  m2.exports.set({zones: [], bosses: [], items: []}, evil, true);
  m2.exports.renderDrops();
  out.page.downloadViewer = el('#dropDownload').hidden;
  m2.exports.set({zones: [], bosses: [], items: []}, {raiders: [], awards: []}, false);
  m2.exports.renderDrops();
  out.page.empty = el('#dropBody').innerHTML;
}

process.stdout.write(JSON.stringify(out));
