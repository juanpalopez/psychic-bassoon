import {readdirSync, readFileSync, statSync} from 'node:fs';
import {join} from 'node:path';

// The Phase 5 greybox runs in parallel with the Phase 4 sim port. It may call
// the sim's public entry points and read what they hand back, but it must not
// reach into the game state: the random streams, the command queue, or any
// field of the state. A render change that did would break replay parity
// without touching a file in godot/sim.
//
// This is a line-based tripwire, not a guarantee. It cannot see through an
// alias (`var t = game.towers` then `t.append(x)`); the real fix is for the
// sim's snapshot to hand render read-only or duplicated data, which belongs to
// a Phase 4 sim ticket. State fields are matched on a receiver named `game` or
// `state` (or ending in `_game` or `_state`), so `board.map = x` is allowed;
// the random streams and the queue are matched on any receiver.

// Every field of GameState and of the map and towers it holds.
const FIELDS =
  'seed|map|route|routes|tick_count|gold|lives|wave|running|over|towers|spawners|rng|route_rng|next_id|pending|events|path|tiles|tower_id|invested|cooldown|level';
const MUTATORS =
  'append|append_array|push_back|push_front|erase|clear|insert|remove_at|remove|pop_back|pop_front|pop_at|resize|assign|sort|sort_custom|shuffle|reverse|fill|set|merge|erase_at';
// An assignment operator, plain or compound (`=`, `+=`, `**=`, `<<=`, `|=`...),
// but not a comparison (`==`, `!=`, `<=`, `>=`).
const ASSIGN = '(?<![=!<>])(?:\\*\\*|<<|>>|[-+*/%&|^])?=(?!=)';
// A receiver that holds the game state: `game`, `state`, `my_game`, `old_state`.
const STATE = '\\b(?:\\w+_)?(?:game|state)\\b';
// A field name written as a literal: "gold", &"gold", StringName("gold"),
// NodePath("gold").
const NAME = `(?:&|StringName\\(|NodePath\\()?\\s*["'](?:${FIELDS})["']`;

// Checked on the code with strings and comments removed.
const FORBIDDEN = [
  [/\.(rng|route_rng)\b/, 'the sim random streams belong to the sim'],
  [/\.pending\b/, 'the command queue belongs to the sim: use Game.submit'],
  [
    // an assignment whose left side passes through a state field, however
    // deep: game.gold = 1, game.towers[0].level += 1, game.map.tiles[0][1] = 2
    new RegExp(
      `${STATE}[\\w.\\[\\]]*\\.(?:${FIELDS})\\b[\\w.\\[\\]]*\\s*${ASSIGN}`
    ),
    'render and ui must not assign through the game state',
  ],
  [
    // a mutating call anywhere down a state field: game.towers.append(...),
    // game.map.routes[0].append(...)
    new RegExp(
      `${STATE}[\\w.\\[\\]]*\\.(?:${FIELDS})\\b[\\w.\\[\\]]*\\.(?:${MUTATORS})\\(`
    ),
    'render and ui must not change the game state',
  ],
  [
    /\b(get_property_list|set_indexed)\(/,
    'render and ui must not enumerate or index-write properties of the game state',
  ],
];

// Checked on the raw line, because the field name is inside a string.
const RAW_FORBIDDEN = [
  [
    new RegExp(
      `${STATE}\\.(?:set|get|set_deferred|call|callv|call_deferred)\\(\\s*${NAME}`
    ),
    'render and ui must not reach into the game state by name',
  ],
  [
    new RegExp(
      `${STATE}\\.(?:call|callv|call_deferred)\\(\\s*(?:&|StringName\\()?\\s*["']set["']\\s*,\\s*\\[?\\s*${NAME}`
    ),
    'render and ui must not reach into the game state by name',
  ],
  [
    new RegExp(`${STATE}\\[\\s*${NAME}\\s*\\]`),
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

/** How many brackets are still open at the end of this code. */
function openBrackets(code) {
  let depth = 0;
  for (const c of code) {
    if (c === '(' || c === '[' || c === '{') depth++;
    if (c === ')' || c === ']' || c === '}') depth--;
  }
  return depth;
}

/** The problems in one file's source. */
export function check(source, file = 'file.gd') {
  const errors = [];
  // a backslash at the end of a line continues it; keep the line numbers
  const lines = source.split('\n');
  for (let n = 0; n < lines.length; n++) {
    let line = lines[n] ?? '';
    const start = n;
    // join a statement that continues: a trailing backslash, or an open
    // bracket (the lines inside a call or an index belong to one statement)
    while (n + 1 < lines.length) {
      if (line.endsWith('\\')) {
        line = line.slice(0, -1) + ' ' + (lines[++n] ?? '');
      } else if (openBrackets(codeOf(line)) > 0) {
        // no space after an opener or a comma, so `a[\n 0]` reads as `a[0]`
        const next = (lines[++n] ?? '').trim();
        line = line + (/[([{,]$/.test(line) ? '' : ' ') + next;
      } else {
        break;
      }
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
