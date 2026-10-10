import {readFileSync, readdirSync, statSync} from 'node:fs';
import {join} from 'node:path';
import {gzipSync} from 'node:zlib';

// Download size of the Godot web export, gzipped as GitHub Pages serves it.
// Provisional budget: re-set after the iPhone measurement (ticket #124).
const MAX_GZIPPED_BYTES = 14_000_000;
const dir = process.argv[2] ?? 'build/web';

if (!statSync(dir, {throwIfNoEntry: false})?.isDirectory()) {
  console.error(`${dir} is not a directory. Export the Web build first.`);
  process.exit(1);
}
const files = readdirSync(dir).filter(f => /\.(wasm|js|pck|html|png)$/.test(f));
const sizes = files.map(f => [
  f,
  gzipSync(readFileSync(join(dir, f)), {level: 9}).length,
]);
const total = sizes.reduce((sum, [, n]) => sum + n, 0);
for (const [f, n] of sizes.sort((a, b) => b[1] - a[1])) {
  console.log(`  ${f}: ${(n / 1e6).toFixed(2)} MB gzipped`);
}
console.log(
  `Godot export: ${(total / 1e6).toFixed(2)} MB gzipped (budget ${(MAX_GZIPPED_BYTES / 1e6).toFixed(1)} MB)`
);
if (!files.some(f => f.endsWith('.wasm'))) {
  console.error('No .wasm file: is this a Web export?');
  process.exit(1);
}
if (total > MAX_GZIPPED_BYTES) {
  console.error('Godot download budget exceeded.');
  process.exit(1);
}
