import {readdirSync, readFileSync, statSync} from 'node:fs';
import {join} from 'node:path';
import {gzipSync} from 'node:zlib';

const MAX_GZIPPED_JS_BYTES = 1_000_000;
const distDir = process.argv[2] ?? 'dist';

if (!statSync(distDir, {throwIfNoEntry: false})?.isDirectory()) {
  console.error(`${distDir} is not a directory. Run pnpm build first.`);
  process.exit(1);
}

const jsFiles = readdirSync(distDir, {recursive: true, withFileTypes: true})
  .filter(
    entry =>
      entry.isFile() &&
      (entry.name.endsWith('.js') || entry.name.endsWith('.mjs'))
  )
  .map(entry => join(entry.parentPath, entry.name));
if (jsFiles.length === 0) {
  console.error(`No JS files found in ${distDir}. Run pnpm build first.`);
  process.exit(1);
}

const total = jsFiles.reduce(
  (sum, path) => sum + gzipSync(readFileSync(path)).length,
  0
);
const kb = bytes => `${(bytes / 1000).toFixed(1)} kB`;

console.log(
  `Gzipped JS: ${kb(total)} in ${jsFiles.length} files (budget ${kb(MAX_GZIPPED_JS_BYTES)})`
);
if (total > MAX_GZIPPED_JS_BYTES) {
  console.error('Bundle size budget exceeded.');
  process.exit(1);
}
