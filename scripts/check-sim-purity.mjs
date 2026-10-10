import {readdirSync, readFileSync, statSync} from 'node:fs';
import {join} from 'node:path';

// The Godot sim must not touch the scene tree, engine singletons or Godot's
// random numbers: it has to be pure and deterministic, like src/sim.
const FORBIDDEN = [
  [
    /\bextends\s+(Node|Node2D|Node3D|Control|Resource|CanvasItem)\b/,
    'the sim must not extend an engine node or resource (use RefCounted)',
  ],
  [/\bget_tree\s*\(/, 'get_tree() touches the scene tree'],
  [/\bget_node\s*\(|\$[A-Za-z_"]/, 'node lookups touch the scene tree'],
  [/\bEngine\./, 'Engine singleton'],
  [/\bTime\./, 'Time singleton (wall clock)'],
  [/\bOS\./, 'OS singleton'],
  [/\bDisplayServer\./, 'DisplayServer singleton'],
  [
    /\b(randf|randi|randf_range|randi_range|randomize|rand_from_seed|RandomNumberGenerator)\b/,
    'Godot random numbers (use the seeded PRNG)',
  ],
  [
    /\b(sin|cos|tan|atan2|atan|pow|round)\s*\(/,
    'maths that may differ from the TypeScript sim (use + - * /, sqrt, floor)',
  ],
  [
    /\bpreload\s*\(\s*"res:\/\/(render|ui)\//,
    'the sim must not depend on render or ui',
  ],
  [
    /\bload\s*\(\s*"res:\/\/(render|ui)\//,
    'the sim must not depend on render or ui',
  ],
];

const dir = process.argv[2] ?? 'godot/sim';
const files = readdirSync(dir, {recursive: true, withFileTypes: true})
  .filter(e => e.isFile() && e.name.endsWith('.gd'))
  .map(e => join(e.parentPath, e.name));

const errors = [];
for (const file of files) {
  if (!statSync(file).isFile()) continue;
  readFileSync(file, 'utf8')
    .split('\n')
    .forEach((line, i) => {
      const code = line.split('#')[0] ?? '';
      for (const [pattern, why] of FORBIDDEN) {
        if (pattern.test(code))
          errors.push(`${file}:${i + 1}: ${why}: ${line.trim()}`);
      }
    });
}
console.log(`Sim purity: ${files.length} GDScript files checked in ${dir}`);
if (errors.length > 0) {
  for (const e of errors) console.error(e);
  process.exit(1);
}
