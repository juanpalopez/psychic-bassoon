import {readdirSync, readFileSync, statSync} from 'node:fs';
import {join} from 'node:path';

// The Godot sim must be pure and deterministic, like src/sim: no scene tree,
// no engine singletons, no Godot random numbers, only maths that matches the
// TypeScript sim, and nothing from render or ui. It uses an allowlist for
// what a sim class may extend and which capitalised names it may use.

const BANNED_CALLS = [
  'get_tree',
  'get_node',
  'get_node_or_null',
  'get_parent',
  'get_viewport',
  'get_window',
  'get_children',
  'add_child',
  'queue_free',
  'call_deferred',
  // random numbers: use the seeded PRNG
  'randf',
  'randi',
  'randf_range',
  'randi_range',
  'randfn',
  'randomize',
  'rand_from_seed',
  'pick_random',
  'shuffle',
  // maths that can differ from the TypeScript sim: use + - * /, sqrt, floor
  'round',
  'roundf',
  'roundi',
  'snapped',
  'snappedf',
  'snappedi',
  'sin',
  'cos',
  'tan',
  'asin',
  'acos',
  'atan',
  'atan2',
  'sinh',
  'cosh',
  'tanh',
  'pow',
  'exp',
  'log',
  'lerp_angle',
  'angle',
  'rotated',
];
const BANNED_NAMES = [
  'Engine',
  'Time',
  'OS',
  'DisplayServer',
  'Input',
  'FileAccess',
  'DirAccess',
  'ProjectSettings',
  'JavaScriptBridge',
  'ResourceLoader',
  'Performance',
  'RenderingServer',
  'PhysicsServer3D',
  'AudioServer',
  'RandomNumberGenerator',
  'Node',
  'Node2D',
  'Node3D',
  'Control',
  'Resource',
];
const ALLOWED_BUILTINS = new Set([
  'RefCounted',
  'Dictionary',
  'Array',
  'String',
  'StringName',
  'PackedByteArray',
  'PackedInt32Array',
  'PackedInt64Array',
  'PackedFloat32Array',
  'PackedFloat64Array',
  'PackedStringArray',
  'Vector2',
  'Vector2i',
  'Callable',
  'Variant',
  'Error',
  'INF',
  'PI',
  'TAU',
]);
const ALLOWED_EXTENDS = new Set(['RefCounted']);
const ALLOWED_PATHS = /^res:\/\/(sim|content)\//;

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

/** Returns the problems in one file's source. `known` is the set of sim names. */
export function check(source, known, file = 'file.gd') {
  const errors = [];
  const raw = source.split('\n');
  raw.forEach((line, n) => {
    const code = codeOf(line);
    const where = `${file}:${n + 1}`;
    const bad = why => errors.push(`${where}: ${why}: ${line.trim()}`);
    for (const m of code.matchAll(/\bextends\s+([A-Za-z_]\w*)/g)) {
      if (!ALLOWED_EXTENDS.has(m[1]) && !known.has(m[1])) {
        bad(
          `a sim class may only extend RefCounted or another sim class, not ${m[1]}`
        );
      }
    }
    for (const name of BANNED_CALLS) {
      if (new RegExp(`(^|[^\\w])${name}\\s*\\(`).test(code))
        bad(`${name}() is not allowed in the sim`);
    }
    if (/(^|[(=,:\s])%[A-Za-z_"]|\$[A-Za-z_"]/.test(code))
      bad('node lookups touch the scene tree');
    for (const name of BANNED_NAMES) {
      if (new RegExp(`\\b${name}\\b`).test(code) && !/\bextends\b/.test(code)) {
        bad(`${name} is not allowed in the sim`);
      }
    }
    for (const m of raw[n].matchAll(/\b(?:preload|load)\s*\(\s*"([^"]*)"/g)) {
      if (!ALLOWED_PATHS.test(m[1]))
        bad(
          `the sim may only load from res://sim or res://content, not ${m[1]}`
        );
    }
    for (const m of code.matchAll(/\b([A-Z][A-Za-z0-9_]*)\b/g)) {
      const word = m[1];
      if (/^[A-Z0-9_]+$/.test(word)) continue; // constants
      if (ALLOWED_BUILTINS.has(word) || known.has(word)) continue;
      if (BANNED_NAMES.includes(word)) continue; // reported above
      bad(
        `unknown capitalised name ${word}: sim code may only use sim classes and plain data types`
      );
    }
  });
  return errors;
}

/** Class, enum and enum member names declared in the sim files. */
export function declaredNames(sources) {
  const known = new Set();
  for (const source of sources) {
    for (const line of source.split('\n')) {
      const code = codeOf(line);
      for (const m of code.matchAll(
        /\b(?:class_name|class|enum)\s+([A-Za-z_]\w*)/g
      ))
        known.add(m[1]);
      for (const m of code.matchAll(/\benum\s*(?:\w+\s*)?\{([^}]*)\}/g)) {
        for (const member of m[1].split(',')) {
          const name = member.split('=')[0]?.trim();
          if (name) known.add(name);
        }
      }
    }
  }
  return known;
}

if (process.argv[1]?.endsWith('check-sim-purity.mjs')) {
  const dir = process.argv[2] ?? 'godot/sim';
  const files = readdirSync(dir, {recursive: true, withFileTypes: true})
    .filter(e => e.isFile() && e.name.endsWith('.gd'))
    .map(e => join(e.parentPath, e.name))
    .filter(f => statSync(f).isFile());
  const sources = files.map(f => readFileSync(f, 'utf8'));
  const known = declaredNames(sources);
  const errors = files.flatMap((f, i) => check(sources[i] ?? '', known, f));
  console.log(`Sim purity: ${files.length} GDScript files checked in ${dir}`);
  if (errors.length > 0) {
    for (const e of errors) console.error(e);
    process.exit(1);
  }
}
