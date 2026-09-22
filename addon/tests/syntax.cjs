// Syntax check of every addon file with the Lua 5.1 grammar.
const fs = require('fs');
const path = require('path');
// Exit code 2 means the checker itself is missing; callers must not read that as a bad file.
let lp;
try {
  lp = require('luaparse');
} catch (e) {
  try {
    lp = require('C:/Users/aobiw/Desktop/VuloForeverUI/tools/node_modules/luaparse');
  } catch (e2) {
    console.log('SKIP  luaparse nicht gefunden');
    process.exit(2);
  }
}

const dir = path.join(__dirname, '..', 'Amisia');
let bad = 0;
for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.lua'))) {
  try {
    lp.parse(fs.readFileSync(path.join(dir, f), 'utf8'), { luaVersion: '5.1' });
    console.log('ok   ', f);
  } catch (e) {
    bad++;
    console.log('FAIL ', f, e.message);
  }
}
process.exit(bad ? 1 : 0);
