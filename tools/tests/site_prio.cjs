// Runs the ledger's loot council code out of index.html: the prio token the addon reads
// (prioParseToken / prioToken), the order as an officer types it (prioParseFree), the text for the
// addon (prioAddonText, behind the wishes and alts in wishAndAltText) and the LC lines of the addon's
// export (amParsePrio, prioPlan, prioApply). Reads {"export": "<the addon's export>"} on stdin and
// prints the results as JSON; tools/tests/test_prio_site.py checks them and feeds the texts through
// the addon's own parser.
process.env.TZ = 'UTC';
const {grab} = require('./site_parser.cjs');

const NEEDED = ['CLASS_ALIAS', 'lootPrio', 'PRIO_CLASS', 'PRIO_MAX', 'prioName', 'prioLabel', 'prioParseToken', 'prioToken', 'prioText',
  'prioParseFree', 'prioNote', 'prioOf', 'setPrio', 'prioAddonText', 'amSplit', 'amParsePrio', 'prioPlan', 'prioApply', 'wishAndAltText'];
// What else the code reaches for on the page, kept as small as the code allows.
const STUBS = `
let state = {raiders: [], awards: []};
const PLAY = 'forever';
const today = () => '2026-10-07';
const WISHES = [];
const wishAddonText = () => '#AMISIA-WL 1 forever 2026-10-07\\nW 32235 3 Anna\\n#END';
let altText = '';
const altAddonText = () => altText;
const pointsAddonText = () => '';
`;
const src = STUBS + NEEDED.map(grab).join('\n\n') + `
;module.exports = {prioParseToken, prioToken, prioText, prioParseFree, prioOf, setPrio, prioAddonText, amSplit, amParsePrio, prioPlan, prioApply,
  wishAndAltText, lootPrio, get: () => state, set: s => { state = s; }, setAlts: t => { altText = t; }};`;
const mod = {exports: {}};
new Function('module', 'exports', src)(mod, mod.exports);
const api = mod.exports;

let input = '';
process.stdin.on('data', d => input += d);
process.stdin.on('end', () => {
  const {export: exported} = JSON.parse(input || '{}');
  const out = {};
  // the token
  const tok = 'p:Anna:Tank,c:WARRIOR:Furor,o,p:Vulo_Sturmwind';
  out.token = {entries: api.prioParseToken(tok), back: api.prioToken(api.prioParseToken(tok)), text: api.prioText(api.prioParseToken(tok)),
    empty: api.prioParseToken('-'), bad: ['p:X1', 'c:NOCLASS', 'q:Anna', '', 'p:Anna:' + 'x'.repeat(20), Array(12).fill('o').join(','), 'pAnna'].map(t => api.prioParseToken(t))};
  // the order as typed
  out.free = ['Anna (Tank), Krieger Furor, offen', 'Vulo Sturmwind (Heal); warrior, Death Knight Frost, open', 'Anna, X1', '', 'Anna (Tank', 'Anna (' + 'x'.repeat(20) + ')']
    .map(t => { const r = api.prioParseFree(t); return r.error ? {error: r.error} : {token: api.prioToken(r.list)}; });
  // a ledger without any prio: no text, and the copy is as before
  out.none = {text: api.prioAddonText(), copy: api.wishAndAltText()};
  // three items, one cleared
  api.setPrio(32235, api.prioParseFree('Anna (Tank), Krieger Furor, offen').list, 'Erst Tanks | dann DPS', 'Vulo', 1788000000);
  api.setPrio(32837, api.prioParseFree('Vulo Sturmwind').list, '', 'Vulo', 1788000100);
  api.setPrio(30001, [], '', 'Vulo', 1788000200);
  out.shown = [32235, 32837, 30001, 99].map(id => !!api.prioOf(id));
  out.text = api.prioAddonText();
  api.setAlts('#AMISIA-ALTS 1 forever 2026-10-07\nA Bob Anna\n#END');
  out.copy = api.wishAndAltText();
  // the addon's export with LC lines
  if (exported) {
    const {blocks} = api.amSplit(exported);
    const parsed = api.amParsePrio(blocks);
    out.parsed = parsed;
    const plan = api.prioPlan(parsed.rows);
    out.plan = plan.map(r => [r.item, r.status]);
    out.applied = api.prioApply(plan);
    out.again = api.prioPlan(parsed.rows).map(r => [r.item, r.status]);
    out.afterText = api.prioAddonText();
    // an older line than the ledger's is left
    out.older = api.prioPlan([{item: 32235, at: 1, by: 'X', prio: [], note: ''}]).map(r => r.status);
  }
  const now = Math.floor(Date.now() / 1000);
  out.future = api.amParsePrio(['#AMISIA 2 X\nLC 7 ' + (now + 3 * 86400) + ' X o\nLC 8 ' + (now + 3600) + ' X o\n#END']);
  out.nameBytes = [api.prioParseToken('p:' + 'Ä'.repeat(24)), api.prioParseToken('p:' + 'Ä'.repeat(25))].map(x => x && x[0].name);
  out.textOfObject = api.prioText({0: {k: 'o'}});
  out.bad = api.amParsePrio(['#AMISIA 2 X\nLC 1 2 X p:X1\nLC abc 2 X o\nLC 5 2 X\nLC 6 7 Y o fine\n#END']);
  process.stdout.write(JSON.stringify(out));
});
