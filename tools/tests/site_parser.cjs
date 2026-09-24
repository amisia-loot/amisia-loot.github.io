// Runs the ledger's own import parser out of index.html against an export on stdin and prints
// what it made of it as JSON. tools/tests/test_export_format.py drives this with an export the
// addon itself wrote, so a change to the export format cannot pass unnoticed on the site.
const fs = require('fs');
const path = require('path');

const PAGE = path.join(__dirname, '..', '..', 'index.html');
const src = fs.readFileSync(PAGE, 'utf8').replace(/\r\n/g, '\n');

// The page is one big script, so the few functions of the import are cut out by name. A function
// written on one line ends on it; every other one ends at the closing brace in the first column.
function grab(name) {
  for (const head of ['\nfunction ' + name + '(', '\nconst ' + name + ' =']) {
    const i = src.indexOf(head);
    if (i < 0) continue;
    const eol = src.indexOf('\n', i + 1);
    const line = src.slice(i + 1, eol).trimEnd();
    if (line.endsWith('}') || line.endsWith(';')) return line;
    const end = src.indexOf('\n}', i + 1);
    if (end < 0) break;
    return src.slice(i + 1, end + 2);
  }
  throw new Error('index.html has no ' + name + ' to test against');
}
// Other drivers borrow grab; only a direct run reads an export from stdin.
module.exports = {grab};
if (require.main !== module) return;

const NEEDED = ['GL_CLASS', 'CLASS_ALIAS', 'glCleanName', 'classFromAny', 'amSplit', 'amParse', 'amParseBank', 'amAwardRows'];
const parts = NEEDED.map(grab);
// amAwardRows looks up the class of the raider in the session, nothing else of the page is needed.
const src2 = parts.join('\n\n') + '\n;module.exports = {amSplit, amParse, amParseBank, amAwardRows, source: ' + JSON.stringify(parts.join('\n')) + '};';
const mod = {exports: {}};
new Function('module', 'exports', src2)(mod, mod.exports);
const api = mod.exports;

let text = '';
process.stdin.on('data', d => text += d);
process.stdin.on('end', () => {
  const {blocks, rest} = api.amSplit(text);
  const sessions = api.amParse(blocks);
  // Which line letters the parser knows, to hold against the ones the addon writes.
  const letters = [...new Set([...api.source.matchAll(/f\[0\] === '([A-Z])'/g)].map(m => m[1]))].sort();
  process.stdout.write(JSON.stringify({
    blocks: blocks.length,
    rest: rest.trim(),
    letters,
    sessions,
    bank: api.amParseBank(blocks),
    awardRows: api.amAwardRows(sessions),
  }));
});
