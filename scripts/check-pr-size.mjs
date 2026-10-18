// Counts the production lines a pull request changes and fails above the limit (owner,
// 2026-10-18, #349: a PR changes at most 200 to 300 lines of production code, else it is split).
// Production is code and config that ships or runs the game and its checks; tests, docs,
// goldens, fixtures, assets, lockfiles and files Godot or our tools generate are not counted.
//
//   node scripts/check-pr-size.mjs <base sha> <head sha> [--allow]
//
// `--allow` (the PR has the owner's `size-exception` label) turns a failure into a warning.
// CI runs the base branch's copy of this file, so a PR cannot raise its own limit.
import {execFileSync} from 'node:child_process';

export const LIMIT = 300;
export const WARN_ABOVE = 200;

const PRODUCTION =
  /\.(gd|gdshader|gdshaderinc|gdextension|tscn|tres|cfg|godot|ts|mts|cts|tsx|js|mjs|cjs|jsx|sh|py|yml|yaml|swift|m|mm|c|cc|cpp|h|hpp|html|css)$/;
const NOT_PRODUCTION = [
  /^godot\/tests\//,
  /^godot\/addons\//,
  /^e2e(-[a-z]+)?\//,
  /\.test\.(ts|mts|mjs|js)$/,
  /\.d\.(ts|mts|cts)$/,
  /^scripts\/mutations\//,
  /^fixtures\//,
  /^docs\//,
  /^assets-src\//,
  /^godot\/assets\//,
  /^prototype\//,
  // written by godot/tools/build_hud_theme.gd from the tokens at its top
  /^godot\/ui\/hud_theme\.tres$/,
  /\.import$/,
  /\.uid$/,
  /(^|\/)pnpm-lock\.yaml$/,
];

/** Whether a changed file's lines count towards the limit. */
export function isProduction(path) {
  return PRODUCTION.test(path) && !NOT_PRODUCTION.some(rule => rule.test(path));
}

/**
 * Sums added and deleted lines of production files from `git diff --numstat -z --text
 * --no-renames` output (NUL-separated records `added<TAB>deleted<TAB>path`). With
 * `--no-renames` a move is a delete plus an add, so moving code out of a test folder into
 * production counts in full; `--text` makes git count every file, so a `-diff` attribute
 * cannot hide one. A `-` count (only possible without `--text`) is counted as a whole
 * unknown file and fails safe: it is reported as over the limit.
 */
export function countProduction(numstat) {
  let total = 0;
  const files = [];
  for (const record of numstat.split('\0')) {
    if (record.trim() === '') continue;
    const [added, deleted, ...rest] = record.replace(/^\n/, '').split('\t');
    const path = rest.join('\t');
    if (!isProduction(path)) continue;
    const lines =
      added === '-' || deleted === '-'
        ? LIMIT + 1
        : Number(added) + Number(deleted);
    total += lines;
    files.push({path, lines});
  }
  return {total, files};
}

/** The verdict for a count: `ok`, `warn` or `fail` (a `fail` with `allow` becomes `warn`). */
export function verdict(total, allow = false) {
  if (total > LIMIT) return allow ? 'warn' : 'fail';
  if (total > WARN_ABOVE) return 'warn';
  return 'ok';
}

/**
 * The whole check on a numstat: the report lines to print and the exit code (0 or 1).
 */
export function report(numstat, allow = false) {
  const {total, files} = countProduction(numstat);
  files.sort((a, b) => b.lines - a.lines);
  const lines = files.map(
    file => `${String(file.lines).padStart(5)}  ${file.path}`
  );
  lines.push(
    `Production lines changed: ${total} (warn above ${WARN_ABOVE}, limit ${LIMIT})`
  );
  const result = verdict(total, allow);
  if (result === 'fail') {
    lines.push(
      `::error::This PR changes ${total} production lines, over the ${LIMIT}-line limit. ` +
        'Split it into smaller PRs (stacked, one ticket each), or ask the owner for the ' +
        '`size-exception` label.'
    );
    return {lines, code: 1};
  }
  if (result === 'warn') {
    lines.push(
      `::warning::This PR changes ${total} production lines` +
        (total > LIMIT
          ? ' (allowed by the size-exception label).'
          : `, near the ${LIMIT}-line limit.`)
    );
  }
  return {lines, code: 0};
}

function main(argv) {
  const [base, head] = argv.filter(arg => !arg.startsWith('--'));
  const allow = argv.includes('--allow');
  if (!base || !head) {
    console.error(
      'usage: node scripts/check-pr-size.mjs <base sha> <head sha> [--allow]'
    );
    return 2;
  }
  const numstat = execFileSync(
    'git',
    ['diff', '--numstat', '-z', '--text', '--no-renames', `${base}...${head}`],
    {encoding: 'utf8', maxBuffer: 64 * 1024 * 1024}
  );
  const {lines, code} = report(numstat, allow);
  for (const line of lines) console.log(line);
  return code;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  process.exit(main(process.argv.slice(2)));
}
