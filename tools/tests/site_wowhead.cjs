// Runs the Wowhead links and the icon lookup out of index.html for each game and prints JSON:
// the links an item gets and the tooltip URL the visitor's browser would ask for.
// tools/tests/test_site_wowhead.py checks it.
const {grab} = require('./site_parser.cjs');

const STUBS = `
let gameKey = 'forever', extIcons = {}, iconTimer = null;
const ITEM = {}, state = {itemNames: {}};
const asked = [];
function fetch(url){ asked.push(url); return {then: () => ({then: () => ({catch: () => {}})})}; }
const localStorage = {getItem: () => null, setItem: () => {}};
function esc(s){ return String(s); } function qCls(){ return ''; } function anyItemName(id){ return 'Item ' + id; }
function icoHTML(){ return ''; } function renderAll(){}
`;
const src = STUBS + ['WOWHEAD_DB', 'ICON_KEY', 'iconAsked', 'extIcon', 'anyItemLink', 'anyItemHTML'].map(grab).join('\n')
  + `;module.exports = {extIcon, anyItemLink, anyItemHTML, asked, WOWHEAD_DB, WOWHEAD_ENV, set: k => { gameKey = k; }};`;

const out = {};
for (const key of ['forever', 'tbc']) {
  const mod = {exports: {}};
  new Function('module', 'exports', src)(mod, mod.exports);
  const api = mod.exports;
  api.set(key);
  api.extIcon(12345);
  out[key] = {link: api.anyItemLink(12345), html: api.anyItemHTML(12345), asked: api.asked.slice(),
    db: api.WOWHEAD_DB[key], env: api.WOWHEAD_ENV[key]};
}
process.stdout.write(JSON.stringify(out));
