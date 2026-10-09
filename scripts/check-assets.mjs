import {
  existsSync,
  lstatSync,
  readdirSync,
  readFileSync,
  statSync,
} from 'node:fs';
import {join, relative, sep} from 'node:path';

const MAX_ASSET_BYTES = 6_000_000;
// Placeholders and OS junk that is never shipped on purpose.
const IGNORED = new Set(['.gitkeep', '.DS_Store', 'Thumbs.db']);
const assetsDir = process.argv[2] ?? 'public/assets';
const creditsFile = process.argv[3] ?? 'assets/CREDITS.md';

if (!statSync(assetsDir, {throwIfNoEntry: false})?.isDirectory()) {
  console.error(`${assetsDir} is not a directory.`);
  process.exit(1);
}
if (!existsSync(creditsFile)) {
  console.error(`${creditsFile} is missing.`);
  process.exit(1);
}

const files = readdirSync(assetsDir, {recursive: true, withFileTypes: true})
  .filter(entry => !entry.isDirectory() && !IGNORED.has(entry.name))
  .map(entry => join(entry.parentPath, entry.name));
// A symlink or a device could hide size or skip the credits check.
const odd = files.filter(file => !lstatSync(file).isFile());
if (odd.length > 0) {
  for (const file of odd) console.error(`${file} is not a regular file`);
  process.exit(1);
}
const relativePaths = files.map(file =>
  relative(assetsDir, file).split(sep).join('/')
);

const credits = readFileSync(creditsFile, 'utf8');
// A credit is a table row that starts with the file path in backticks.
const rows = [...credits.matchAll(/^\|\s*`([^`]+)`(.*)$/gm)];
const listed = rows.map(m => m[1]);

const errors = [];
for (const path of relativePaths) {
  if (!listed.includes(path)) {
    errors.push(`${path} is not recorded in ${creditsFile}`);
  }
}
for (const path of listed) {
  if (!relativePaths.includes(path)) {
    errors.push(`${creditsFile} lists ${path}, which is not in ${assetsDir}`);
  }
}

for (const [, path, rest] of rows) {
  if (!/CC0/i.test(rest ?? '')) {
    errors.push(`${path}: the credits row does not say CC0`);
  }
}

const total = files.reduce((sum, file) => sum + statSync(file).size, 0);
const mb = bytes => `${(bytes / 1_000_000).toFixed(2)} MB`;
console.log(
  `Assets: ${mb(total)} in ${files.length} files (budget ${mb(MAX_ASSET_BYTES)})`
);
if (total > MAX_ASSET_BYTES) {
  errors.push('Asset size budget exceeded.');
}

if (errors.length > 0) {
  for (const error of errors) console.error(error);
  process.exit(1);
}
