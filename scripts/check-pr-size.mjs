// Counts the production lines a pull request changes and fails above the limit (owner,
// 2026-10-18: a PR changes at most 200 to 300 lines of production code, else it is split).
// Production is code and config that ships or runs the game and its checks; tests, docs,
// goldens, fixtures, assets, lockfiles and files Godot generates are not counted.
//
//   node scripts/check-pr-size.mjs <base sha> <head sha> [--allow]
//
// `--allow` (the PR has the owner's `size-exception` label) turns a failure into a warning.
import {execFileSync} from 'node:child_process';

export const LIMIT = 300;
export const WARN_ABOVE = 200;

const PRODUCTION =
  /\.(gd|gdshader|gdshaderinc|tscn|tres|cfg|godot|ts|mjs|js|sh|py|yml|yaml)$/;
const NOT_PRODUCTION = [
  /^godot\/tests\//,
  /^godot\/addons\//,
  /^e2e/,
  /\.test\.(ts|mjs|js)$/,
  /^scripts\/mutations\//,
  /^fixtures\//,
  /^docs\//,
  /^assets-src\//,
  /^godot\/assets\//,
  /^prototype\//,
  /\.import$/,
  /\.uid$/,
  /(^|\/)pnpm-lock\.yaml$/,
];

/** Whether a changed file's lines count towards the limit. */
export function isProduction(path) {
  return PRODUCTION.test(path) && !NOT_PRODUCTION.some(rule => rule.test(path));
}

/**
 * Sums added and deleted lines of production files from `git diff --numstat` output.
 * Binary files (`-` counts) never count.
 */
export function countProduction(numstat) {
  let total = 0;
  const files = [];
  for (const line of numstat.split('\n')) {
    if (line.trim() === '') continue;
    const [added, deleted, ...rest] = line.split('\t');
    const path = rest.join('\t');
    // a rename shows as `old => new` (or `dir/{old => new}/file`): judge the new path
    const target = path.includes('=>')
      ? path.replace(/\{[^}]* => ([^}]*)\}/, '$1').replace(/^.* => /, '')
      : path;
    if (added === '-' || !isProduction(target)) continue;
    const lines = Number(added) + Number(deleted);
    total += lines;
    files.push({path: target, lines});
  }
  return {total, files};
}

/** The verdict for a count: `ok`, `warn` or `fail` (a `fail` with `allow` becomes `warn`). */
export function verdict(total, allow = false) {
  if (total > LIMIT) return allow ? 'warn' : 'fail';
  if (total > WARN_ABOVE) return 'warn';
  return 'ok';
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
    ['diff', '--numstat', '-M', `${base}...${head}`],
    {
      encoding: 'utf8',
    }
  );
  const {total, files} = countProduction(numstat);
  files.sort((a, b) => b.lines - a.lines);
  for (const file of files)
    console.log(`${String(file.lines).padStart(5)}  ${file.path}`);
  console.log(
    `Production lines changed: ${total} (warn above ${WARN_ABOVE}, limit ${LIMIT})`
  );
  const result = verdict(total, allow);
  if (result === 'fail') {
    console.log(
      `::error::This PR changes ${total} production lines, over the ${LIMIT}-line limit. ` +
        'Split it into smaller PRs (stacked, one ticket each), or ask the owner for the ' +
        '`size-exception` label.'
    );
    return 1;
  }
  if (result === 'warn') {
    console.log(
      `::warning::This PR changes ${total} production lines` +
        (total > LIMIT
          ? ' (allowed by the size-exception label).'
          : `, near the ${LIMIT}-line limit.`)
    );
  }
  return 0;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  process.exit(main(process.argv.slice(2)));
}
