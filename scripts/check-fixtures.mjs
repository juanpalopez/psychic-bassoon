import {createHash} from 'node:crypto';
import {existsSync, readdirSync, readFileSync} from 'node:fs';
import {join} from 'node:path';

// The frozen fixtures (prng, maps, routes) are the reference for the ported
// core and are never regenerated. fixtures/SHA256SUMS lists their hashes; this
// check fails when one changes, goes missing, or a new JSON file appears
// beside them. Pass a directory to check another one (the tests do).

const dir = process.argv[2] ?? 'fixtures';
const sumsPath = join(dir, 'SHA256SUMS');
const problems = [];

const expected = new Map();
if (!existsSync(sumsPath)) {
  problems.push(`${sumsPath} is missing`);
} else {
  const lines = readFileSync(sumsPath, 'utf8').split('\n');
  for (const [i, line] of lines.entries()) {
    if (line.trim() === '') continue;
    const match = /^([0-9a-f]{64}) {2}(\S+\.json)$/.exec(line);
    if (!match) {
      problems.push(`${sumsPath}:${i + 1}: malformed line "${line}"`);
      continue;
    }
    expected.set(match[2], match[1]);
  }
}

for (const [name, hash] of expected) {
  const path = join(dir, name);
  if (!existsSync(path)) {
    problems.push(`${path} is listed in SHA256SUMS but missing`);
    continue;
  }
  const actual = createHash('sha256').update(readFileSync(path)).digest('hex');
  if (actual !== hash) {
    problems.push(`${path} changed: the frozen fixtures are never regenerated`);
  }
}

if (existsSync(dir)) {
  for (const entry of readdirSync(dir, {
    recursive: true,
    withFileTypes: true,
  })) {
    if (!entry.isFile() || !entry.name.toLowerCase().endsWith('.json'))
      continue;
    const path = join(entry.parentPath, entry.name);
    const name = path.slice(dir.length + 1);
    if (!expected.has(name)) {
      problems.push(`${path} is not listed in SHA256SUMS`);
    }
  }
}

if (problems.length > 0) {
  for (const problem of problems) console.error(problem);
  process.exit(1);
}
console.log(`Frozen fixtures: ${expected.size} files match SHA256SUMS`);
