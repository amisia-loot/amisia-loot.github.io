// Runs loadGame/loadCraft out of index.html with a fake script loader and lets the data files arrive in
// the wrong order: a late script of another game must not put its tables on the page. Prints JSON;
// tools/tests/test_site_load.py checks it.
const {grab} = require('./site_parser.cjs');

// What else the code reaches for on the page; the scripts the page adds are kept so the test can finish them by hand.
const STUBS = `
const BUILD_ID = 'x', CLASSIC_CLASSES = [], MOP_CLASSES = [];
let DATA = null, CRAFT = null, DROPS = null, gameKey = 'forever', CLASSES, dataState, craftState, bossNameState = 'ok', renders = 0;
const window = {__LOOT: {}, __CRAFT: {}, __DROPS: {}};
const document = {createElement: () => ({}), head: {appendChild: s => scripts.push(s)}};
function applyData(d){ DATA = d; } function applyCraft(c){ CRAFT = c; } function loadBossNames(){} function renderAll(){ renders++; }
`;
const src = STUBS + ['PLAY', 'GAMES', 'GAME', 'loadCraft', 'dropsState', 'applyDrops', 'loadDrops', 'loadGame'].map(grab).join('\n')
  + `;module.exports = {loadGame, window, get: () => ({gameKey, DATA, dataState, CRAFT, craftState}), drops: () => ({DROPS, state: dropsState.forever || null, renders})};`;

function fresh() {
  const scripts = [];
  const mod = {exports: {}};
  new Function('module', 'exports', 'scripts', src)(mod, mod.exports, scripts);
  const api = mod.exports;
  const arrive = (file, key, tables) => {
    const s = scripts.find(x => x.src.startsWith(file));
    if (tables) api.window[key][tables.k] = tables.v;
    s.onload();
  };
  const fail = file => scripts.find(x => x.src.startsWith(file)).onerror();
  return {api, scripts, arrive, fail};
}
const out = {};

// open #archive directly: the page loads Forever, then enters the archive; tbc.js arrives first, forever.js second
{
  const {api, arrive} = fresh();
  api.loadGame('forever'); api.loadGame('tbc');
  arrive('data/tbc.js', '__LOOT', {k: 'tbc', v: {tag: 'TBC'}});
  arrive('data/forever.js', '__LOOT', {k: 'forever', v: {tag: 'FOREVER'}});
  out.directArchive = api.get();
}
// leave the archive before tbc.js loads: Forever is back on show, the late tbc.js must not replace it,
// and Forever's own script still applies its tables
{
  const {api, arrive} = fresh();
  api.loadGame('forever'); api.loadGame('tbc'); api.loadGame('forever');
  arrive('data/tbc.js', '__LOOT', {k: 'tbc', v: {tag: 'TBC'}});
  out.afterLate = {gameKey: api.get().gameKey, DATA: api.get().DATA, dataState: api.get().dataState};
  arrive('data/forever.js', '__LOOT', {k: 'forever', v: {tag: 'FOREVER'}});
  out.leaveEarly = api.get();
}
// the crafting tables of the archive arrive after the page is back on Forever
{
  const {api, arrive} = fresh();
  api.loadGame('tbc'); api.loadGame('forever');
  arrive('data/craft-tbc.js', '__CRAFT', {k: 'tbc', v: {tag: 'CRAFT'}});
  out.lateCraft = {CRAFT: api.get().CRAFT, craftState: api.get().craftState};
}
// the crafting tables of the game on show still apply when they arrive
{
  const {api, arrive} = fresh();
  api.loadGame('tbc');
  arrive('data/craft-tbc.js', '__CRAFT', {k: 'tbc', v: {tag: 'CRAFT'}});
  out.ownCraft = {CRAFT: api.get().CRAFT, craftState: api.get().craftState};
}
// the boss kills of the data build (F-187): Forever loads data/drops-forever.js once, with BUILD_ID; the
// archive has none; a missing file leaves DROPS empty; a file that arrives while the archive is on show
// waits in window.__DROPS until Forever is back
{
  const {api, scripts, arrive} = fresh();
  api.loadGame('forever');
  out.dropsScripts = scripts.map(s => s.src);
  arrive('data/drops-forever.js', '__DROPS', {k: 'forever', v: {v: 1, k: [], names: {}, zones: {}}});
  out.dropsOk = api.drops();
  api.loadGame('tbc');
  out.dropsArchive = {DROPS: api.drops().DROPS, scripts: scripts.filter(s => s.src.includes('drops')).length};
  api.loadGame('forever');
  out.dropsBack = {DROPS: api.drops().DROPS, scripts: scripts.filter(s => s.src.includes('drops')).length};
}
{
  const {api, fail} = fresh();
  api.loadGame('forever');
  fail('data/drops-forever.js');
  out.dropsMissing = api.drops();
}
{
  const {api, arrive} = fresh();
  api.loadGame('forever'); api.loadGame('tbc');
  arrive('data/drops-forever.js', '__DROPS', {k: 'forever', v: {v: 1, k: []}});
  out.dropsLate = api.drops().DROPS;
  api.loadGame('forever');
  out.dropsLateBack = api.drops().DROPS;
}
process.stdout.write(JSON.stringify(out));
