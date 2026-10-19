// Decides what a pull request has to run (owner, #359): the Godot job at all, and which GUT
// test scripts. A test is selected when the changed file is in its dependency closure: the
// `res://` paths a script or scene names, and the `class_name` identifiers it uses. Anything
// this cannot place (a deleted file, project settings, content, the PRNG and tick loop, goldens,
// fixtures, workflows, a changed file no test reaches) selects the whole suite. Pushes to
// `main` and tags never use it; CI runs everything there.
//
//   node scripts/select-tests.mjs <base sha> <head sha>
//
// Prints `godot=true|false` and `gut=all|none|<res:// test paths, comma-separated>`.
import {execFileSync} from 'node:child_process';
import {readdirSync, readFileSync, realpathSync} from 'node:fs';
import {join} from 'node:path';
import {pathToFileURL} from 'node:url';

const SCRIPT_LIKE = /\.(gd|tscn|tres|gdshader|gdshaderinc)$/;
const DOCS_ONLY = [
  /^docs\//,
  /\.md$/,
  /^site\//,
  /^assets\/CREDITS\.md$/,
  /^assets-src\//,
  /^prototype\//,
  /^\.claude\//,
  /^LICENSE$/,
];
// Files whose change can alter the Godot job without touching godot/.
const GODOT_ADJACENT = [
  /^fixtures\//,
  /^\.godot-version$/,
  /^\.github\//,
  /^scripts\/(run-godot-checked|check-desktop-export|check-godot-size|select-tests)\./,
];
// A change here runs the whole suite: shared by every replay, or not traceable by references.
const FULL = [
  /^fixtures\//,
  /^\.godot-version$/,
  /^\.github\//,
  /^scripts\/select-tests\./,
  /^godot\/content\//,
  /^godot\/sim\/(rng|streams|rounding)\.gd$/,
  /^godot\/sim\/game\//,
  /^godot\/tests\/goldens\//,
  /^godot\/(project\.godot|export_presets\.cfg|\.gutconfig\.json)$/,
  /^godot\/addons\//,
  /^godot\/assets\//,
];

/** `{godot, gut}` for a changed file list (git's `--name-status`-free `--name-only` output). */
export function select(changed, graph) {
  const files = changed.filter(path => path && !path.endsWith('.uid'));
  if (files.every(path => DOCS_ONLY.some(rule => rule.test(path)))) {
    return {godot: false, gut: 'none'};
  }
  const touchesGodot = files.some(
    path => path.startsWith('godot/') || GODOT_ADJACENT.some(r => r.test(path))
  );
  if (!touchesGodot) return {godot: false, gut: 'none'};
  const relevant = files.filter(
    path => !DOCS_ONLY.some(rule => rule.test(path))
  );
  if (relevant.some(path => FULL.some(rule => rule.test(path)))) {
    return {godot: true, gut: 'all'};
  }
  const chosen = new Set();
  for (const path of relevant) {
    if (!path.startsWith('godot/')) continue;
    const local = path.slice('godot/'.length);
    if (local.startsWith('tests/')) {
      // a test script runs itself; anything else under tests/ (helpers) is traced like code
      if (/^tests\/(.*\/)?test_[^/]*\.gd$/.test(local) && graph.has(local)) {
        chosen.add(local);
        continue;
      }
    }
    if (!graph.has(local)) return {godot: true, gut: 'all'}; // deleted or untraceable
    const reached = graph.testsReaching(local);
    if (reached.length === 0) return {godot: true, gut: 'all'}; // nothing covers it
    for (const test of reached) chosen.add(test);
  }
  const paths = [...chosen].sort().map(path => `res://${path}`);
  return {godot: true, gut: paths.length === 0 ? 'none' : paths.join(',')};
}

/**
 * The reference graph of `files` (a Map from path relative to `godot/` to text). Directory
 * references (`res://content/`) depend on every file below them.
 */
export function buildGraph(files) {
  const paths = [...files.keys()].filter(path => SCRIPT_LIKE.test(path));
  const classes = new Map();
  for (const path of paths) {
    const match = /^class_name\s+(\w+)/m.exec(files.get(path));
    if (match) classes.set(match[1], path);
  }
  const deps = new Map();
  for (const path of paths) {
    const text = files.get(path);
    const found = new Set();
    for (const [, ref] of text.matchAll(/res:\/\/([^"'\s)]*)/g)) {
      if (files.has(ref)) found.add(ref);
      else {
        const prefix = ref.endsWith('/') ? ref : `${ref}/`;
        for (const other of paths)
          if (other.startsWith(prefix)) found.add(other);
      }
    }
    for (const [, name] of text.matchAll(/\b([A-Z]\w*)\b/g)) {
      const target = classes.get(name);
      if (target && target !== path) found.add(target);
    }
    deps.set(path, found);
  }
  const closures = new Map();
  const closure = path => {
    const seen = new Set([path]);
    const stack = [path];
    while (stack.length > 0) {
      for (const next of deps.get(stack.pop()) ?? []) {
        if (!seen.has(next)) {
          seen.add(next);
          stack.push(next);
        }
      }
    }
    return seen;
  };
  const tests = paths.filter(path =>
    /^tests\/(.*\/)?test_[^/]*\.gd$/.test(path)
  );
  for (const test of tests) closures.set(test, closure(test));
  return {
    has: path => deps.has(path),
    testsReaching: path => tests.filter(test => closures.get(test).has(path)),
  };
}

function readTree(root) {
  const files = new Map();
  const walk = dir => {
    for (const entry of readdirSync(join(root, dir), {withFileTypes: true})) {
      const path = dir === '' ? entry.name : `${dir}/${entry.name}`;
      if (entry.isDirectory()) {
        if (entry.name !== '.godot' && entry.name !== 'addons') walk(path);
      } else if (SCRIPT_LIKE.test(path)) {
        files.set(path, readFileSync(join(root, path), 'utf8'));
      }
    }
  };
  walk('');
  return files;
}

function main(argv) {
  const [base, head] = argv;
  if (!base || !head) {
    console.error('usage: node scripts/select-tests.mjs <base sha> <head sha>');
    return 2;
  }
  const changed = execFileSync(
    'git',
    ['diff', '--name-only', '--no-renames', '-z', `${base}...${head}`],
    {encoding: 'utf8', maxBuffer: 64 * 1024 * 1024}
  ).split('\0');
  // the head checkout is the tree on disk; a deleted file is not in it, so it selects all
  const result = select(changed, buildGraph(readTree('godot')));
  console.log(`godot=${result.godot}`);
  console.log(`gut=${result.gut}`);
  return 0;
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(realpathSync(process.argv[1])).href
) {
  process.exit(main(process.argv.slice(2)));
}
