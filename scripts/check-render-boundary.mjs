import {readdirSync, readFileSync, statSync} from 'node:fs';
import {join} from 'node:path';

// The Phase 5 greybox runs in parallel with the Phase 4 sim port. It may call
// the sim's public entry points and read what they hand back, but it must not
// reach into the game state: the random streams, the command queue, or any
// field of the state. A render change that did would break replay parity
// without touching a file in godot/sim.

// Every field of GameState and of the map and towers it holds.
const FIELDS =
  'seed|map|route|routes|tick_count|gold|lives|wave|running|over|towers|spawners|rng|route_rng|next_id|pending|events|path|tiles|tower_id|invested|cooldown|level';
const MUTATORS =
  'append|append_array|push_back|push_front|erase|clear|insert|remove_at|remove|pop_back|pop_front|pop_at|resize|assign|sort|sort_custom|shuffle|reverse|fill|set|merge|erase_at';

// Checked on the code with strings and comments removed.
const FORBIDDEN = [
  [/\.(rng|route_rng)\b/, 'the sim random streams belong to the sim'],
  [/\.pending\b/, 'the command queue belongs to the sim: use Game.submit'],
  [
    // an assignment whose left side passes through a state field, however
    // deep: game.gold = 1, game.towers[0].level += 1, game.map.tiles[0][1] = 2
    new RegExp(
      `\\.(${FIELDS})\\b[\\w.\\[\\]]*\\s*(?<![=!<>])(=|\\+=|-=|\\*=|/=)(?!=)`
    ),
    'render and ui must not assign through the game state',
  ],
  [
    // a mutating call anywhere down a state field: game.towers.append(...),
    // game.map.routes[0].append(...)
    new RegExp(`\\.(${FIELDS})\\b[\\w.\\[\\]]*\\.(${MUTATORS})\\(`),
    'render and ui must not change the game state',
  ],
];

// Checked on the raw line, because the field name is inside a string.
const RAW_FORBIDDEN = [
  [
    new RegExp(
      `\\b(set|get|set_deferred|call|callv)\\(\\s*["'](${FIELDS})["']`
    ),
    'render and ui must not reach into the game state by name',
  ],
  [
    new RegExp(
      `\\.(call|callv)\\(\\s*["']set["']\\s*,\\s*\\[?\\s*["'](${FIELDS})["']`
    ),
    'render and ui must not reach into the game state by name',
  ],
  [
    new RegExp(`\\[\\s*["'](${FIELDS})["']\\s*\\]`),
    'render and ui must not reach into the game state by name',
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
  // a backslash at the end of a line continues it; keep the line numbers
  const lines = source.split('\n');
  for (let n = 0; n < lines.length; n++) {
    let line = lines[n] ?? '';
    const start = n;
    while (line.endsWith('\\') && n + 1 < lines.length) {
      line = line.slice(0, -1) + ' ' + (lines[++n] ?? '');
    }
    const code = codeOf(line);
    for (const [pattern, why] of FORBIDDEN) {
      if (pattern.test(code)) {
        errors.push(`${file}:${start + 1}: ${why}: ${line.trim()}`);
      }
    }
    // a comment is not code, but a string is only hidden from the first list
    const raw = line.split('#')[0] ?? '';
    // JavaScript passed to the browser is not GDScript state access
    if (raw.includes('JavaScriptBridge.')) continue;
    for (const [pattern, why] of RAW_FORBIDDEN) {
      if (pattern.test(raw)) {
        errors.push(`${file}:${start + 1}: ${why}: ${line.trim()}`);
      }
    }
  }
  return errors;
}

if (process.argv[1]?.endsWith('check-render-boundary.mjs')) {
  const dirs = process.argv.slice(2);
  if (dirs.length === 0) dirs.push('godot/render', 'godot/ui', 'godot/main.gd');
  const files = dirs.flatMap(dir => {
    const info = statSync(dir, {throwIfNoEntry: false});
    if (!info) {
      console.error(`${dir} does not exist: was it renamed? Update the check.`);
      process.exit(1);
    }
    if (info.isFile()) return [dir];
    return readdirSync(dir, {recursive: true, withFileTypes: true})
      .filter(e => e.isFile() && e.name.endsWith('.gd'))
      .map(e => join(e.parentPath, e.name));
  });
  if (files.length === 0) {
    console.error('No GDScript files were checked.');
    process.exit(1);
  }
  const errors = files.flatMap(f => check(readFileSync(f, 'utf8'), f));
  console.log(`Render boundary: ${files.length} GDScript files checked`);
  if (errors.length > 0) {
    for (const e of errors) console.error(e);
    process.exit(1);
  }
}
