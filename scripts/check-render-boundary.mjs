import {readdirSync, readFileSync, statSync} from 'node:fs';
import {join} from 'node:path';

// The Phase 5 greybox runs in parallel with the Phase 4 sim port. It may call
// the sim's public entry points and read what they hand back, but it must not
// reach into the game state: the random streams, the command queue, or any
// field of the state. A render change that did would break replay parity
// without touching a file in godot/sim.

const FORBIDDEN = [
  [/\.(rng|route_rng)\b/, 'the sim random streams belong to the sim'],
  [/\.pending\b/, 'the command queue belongs to the sim: use Game.submit'],
  [
    /\.(gold|lives|wave|running|over|towers|spawners|next_id|tick_count|events|map|routes|route)\s*(=(?!=)|\+=|-=|\*=|\/=)/,
    'render and ui must not assign fields of the game state',
  ],
  [
    /\.(towers|spawners|events|pending|routes)\.(append|push_back|push_front|erase|clear|insert|remove_at|pop_back|pop_front|resize)\(/,
    'render and ui must not change the game state collections',
  ],
];

/** Removes strings and comments, so only code is checked. */
export function codeOf(line) {
  let out = '';
  let i = 0;
  while (i < line.length) {
    const c = line[i];
    if (c === '#') break;
    if (c === '"' || c === "'") {
      const quote = c;
      i++;
      while (i < line.length && line[i] !== quote)
        i += line[i] === '\\' ? 2 : 1;
      i++;
      out += '""';
      continue;
    }
    out += c;
    i++;
  }
  return out;
}

/** The problems in one file's source. */
export function check(source, file = 'file.gd') {
  const errors = [];
  source.split('\n').forEach((line, n) => {
    const code = codeOf(line);
    for (const [pattern, why] of FORBIDDEN) {
      if (pattern.test(code)) {
        errors.push(`${file}:${n + 1}: ${why}: ${line.trim()}`);
      }
    }
  });
  return errors;
}

if (process.argv[1]?.endsWith('check-render-boundary.mjs')) {
  const dirs = process.argv.slice(2);
  if (dirs.length === 0) dirs.push('godot/render', 'godot/ui', 'godot/main.gd');
  const files = dirs.flatMap(dir => {
    const info = statSync(dir, {throwIfNoEntry: false});
    if (!info) return [];
    if (info.isFile()) return [dir];
    return readdirSync(dir, {recursive: true, withFileTypes: true})
      .filter(e => e.isFile() && e.name.endsWith('.gd'))
      .map(e => join(e.parentPath, e.name));
  });
  const errors = files.flatMap(f => check(readFileSync(f, 'utf8'), f));
  console.log(`Render boundary: ${files.length} GDScript files checked`);
  if (errors.length > 0) {
    for (const e of errors) console.error(e);
    process.exit(1);
  }
}
