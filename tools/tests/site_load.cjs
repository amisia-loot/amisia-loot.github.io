// Runs loadGame/loadCraft out of index.html with a fake script loader and lets the data files arrive in
// the wrong order: a late script of another game must not put its tables on the page. Prints JSON;
// tools/tests/test_site_load.py checks it.
const {grab} = require('./site_parser.cjs');

// What else the code reaches for on the page; the scripts the page adds are kept so the test can finish them by hand.
const STUBS = `
const BUILD_ID = 'x', CLASSIC_CLASSES = [], MOP_CLASSES = [];
let DATA = null, CRAFT = null, gameKey = 'forever', CLASSES, dataState, craftState, bossNameState = 'ok';
const window = {__LOOT: {}, __CRAFT: {}};
const document = {createElement: () => ({}), head: {appendChild: s => scripts.push(s)}};
function applyData(d){ DATA = d; } function applyCraft(c){ CRAFT = c; } function loadBossNames(){} function renderAll(){}
`;
const src = STUBS + ['PLAY', 'GAMES', 'GAME', 'loadCraft', 'loadGame'].map(grab).join('\n')
  + `;module.exports = {loadGame, window, get: () => ({gameKey, DATA, dataState, CRAFT, craftState})};`;

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
  return {api, scripts, arrive};
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
process.stdout.write(JSON.stringify(out));
