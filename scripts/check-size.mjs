import {readdirSync, readFileSync} from 'node:fs';
import {join} from 'node:path';
import {gzipSync} from 'node:zlib';

const MAX_GZIPPED_JS_BYTES = 1_000_000;
const assetsDir = join('dist', 'assets');

const jsFiles = readdirSync(assetsDir).filter(name => name.endsWith('.js'));
if (jsFiles.length === 0) {
  console.error(`No JS files found in ${assetsDir}. Run pnpm build first.`);
  process.exit(1);
}

const total = jsFiles.reduce(
  (sum, name) => sum + gzipSync(readFileSync(join(assetsDir, name))).length,
  0
);
const kb = bytes => `${(bytes / 1000).toFixed(1)} kB`;

console.log(`Gzipped JS: ${kb(total)} (budget ${kb(MAX_GZIPPED_JS_BYTES)})`);
if (total > MAX_GZIPPED_JS_BYTES) {
  console.error('Bundle size budget exceeded.');
  process.exit(1);
}
