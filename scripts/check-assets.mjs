import {
  existsSync,
  lstatSync,
  readdirSync,
  readFileSync,
  statSync,
} from 'node:fs';
import {join, relative, sep} from 'node:path';

// Raised from 6 MB for the three full-length music tracks (about 5.8 MB, owner decision pending).
const MAX_ASSET_BYTES = 9_000_000;
// Placeholders and OS junk that is never shipped on purpose, and the `.import`
// file Godot writes next to each asset it imports (it belongs to the credited file).
const IGNORED = new Set(['.gitkeep', '.DS_Store', 'Thumbs.db']);
const isGodotImport = name => name.endsWith('.import');
const assetsDir = process.argv[2] ?? 'godot/assets';
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
  .filter(
    entry =>
      !entry.isDirectory() &&
      !IGNORED.has(entry.name) &&
      !isGodotImport(entry.name)
  )
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

// CC0 for packs, or the owner's own models, which the owner keeps the rights to.
// Fonts may also be SIL OFL 1.1 (owner decision, 2026-10-15), and only fonts: the
// licence lets a game embed them, and no CC0 face fits the papercraft HUD.
// Only the licence column counts, and it has to start with the licence (a row that
// says "CC BY 4.0, not CC0" is not CC0).
const OWNED = /^\s*Owned by the owner \(all rights reserved\)/;
const OFL = /^\s*SIL OFL 1\.1\b/;
for (const [, path, rest] of rows) {
  // columns: | file | source | licence | edits |
  const licence = (rest ?? '').split('|')[2] ?? '';
  const font = /^fonts\/[^/]+\.(ttf|otf|woff2?)$/i.test(path);
  if (
    !/^\s*CC0\b/i.test(licence) &&
    !OWNED.test(licence) &&
    !(font && OFL.test(licence))
  ) {
    errors.push(
      `${path}: the credits row does not say CC0 or 'Owned by the owner (all rights reserved)'${font ? " or 'SIL OFL 1.1'" : ''}`
    );
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
