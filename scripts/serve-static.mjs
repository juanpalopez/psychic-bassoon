import {createReadStream, statSync} from 'node:fs';
import {createServer} from 'node:http';
import {extname, join, normalize, resolve, sep} from 'node:path';

// A tiny static file server for the Godot web export in `build/web/`, used by
// the Playwright smoke test (and handy for `pnpm serve` on a phone over LAN).
// Usage: node scripts/serve-static.mjs [dir] [port] [host]

const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.webmanifest': 'application/manifest+json; charset=utf-8',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.pck': 'application/octet-stream',
};

const root = resolve(process.argv[2] ?? 'build/web');
const port = Number(process.argv[3] ?? 4174);
const host = process.argv[4] ?? '127.0.0.1';

const server = createServer((request, response) => {
  const url = new URL(request.url ?? '/', 'http://localhost');
  const name = normalize(decodeURIComponent(url.pathname)).replace(/^\/+/, '');
  let file = join(root, name === '' ? 'index.html' : name);
  // never serve anything outside the export directory
  if (file !== root && !file.startsWith(root + sep)) {
    response.writeHead(403).end();
    return;
  }
  try {
    if (statSync(file).isDirectory()) file = join(file, 'index.html');
    const {size} = statSync(file);
    response.writeHead(200, {
      'content-type': TYPES[extname(file)] ?? 'application/octet-stream',
      'content-length': size,
      'cache-control': 'no-store',
    });
    createReadStream(file).pipe(response);
  } catch {
    response.writeHead(404).end('not found');
  }
});

server.listen(port, host, () => {
  console.log(`Serving ${root} at http://${host}:${port}/`);
});
