// Runs the ledger's own late-mark rule (amLate in index.html) through the nights of a raid evening
// and prints each night's marks as JSON. tools/tests/test_late_rule.py checks that only the first
// raid of a night decides who came in late, whatever order the sessions are imported in.
const {grab} = require('./site_parser.cjs');

const NIGHTS = {}, mod = {exports: {}};
// lateOn reads the night the rule is handed, which is all amLate needs of the page.
new Function('module', 'NIGHTS', grab('amLate') + '\nconst lateOn = d => NIGHTS[d].late || {};\nmodule.exports = {amLate};')(mod, NIGHTS);
const {amLate} = mod.exports;

// The same steps importAmisia takes for one session.
function importInto(n, s) {
  NIGHTS[n.date] = n;
  const lt = amLate(n, s, s.members.map(m => m.name));
  if (lt) { n.lateRaid = lt.lateRaid; if (Object.keys(lt.late).length) n.late = lt.late; else delete n.late; }
  return n;
}

const hyjal = {sid: '20260923194932-534', date: '2026-09-23', instance: 534, members: [
  {name: 'Vuloo', first: 1, late: false}, {name: 'Buxxbaum', first: 2, late: true}, {name: 'Ziepel', first: 3, late: true}]};
const hyjalLater = {sid: '20260923195510-534', date: '2026-09-23', instance: 534, members: [
  {name: 'Buxxbaum', first: 2, late: false}, {name: 'Corpina', first: 4, late: true}]};
const bt = {sid: '20260923213457-564', date: '2026-09-23', instance: 564, members: [
  {name: 'Vuloo', first: 5, late: false}, {name: 'Buxxbaum', first: 5, late: false}, {name: 'Chorf', first: 6, late: true}]};

const night = () => ({date: '2026-09-23', present: []});
const run = list => { const n = night(); for (const s of list) importInto(n, s); return {late: n.late || {}, lateRaid: n.lateRaid}; };
// A night imported before the rule: marks from the second raid, no deciding raid recorded.
const legacy = () => { const n = night(); n.late = {Chorf: 6}; for (const s of [bt, hyjal]) importInto(n, s); return {late: n.late || {}, lateRaid: n.lateRaid}; };

process.stdout.write(JSON.stringify({
  hyjalThenBt: run([hyjal, bt]),
  btThenHyjal: run([bt, hyjal]),
  secondOfficer: run([hyjal, hyjalLater, bt]),
  btAlone: run([bt]),
  legacy: legacy(),
}));
