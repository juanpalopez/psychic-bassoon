# Goldens written by the GDScript sim

Regression data written by the GDScript sim itself, not by the TypeScript sim (whose fixtures in `/fixtures` are frozen and cover only the ported core). A golden changes only by a reviewed balance change: edit the rule or number, regenerate it with its script in `godot/tools/`, and say so in the PR.

| File | Written by | Holds |
| --- | --- | --- |
| `sockets.json` | `godot --headless --path godot -s tools/write_sockets_golden.gd` | for 8 seeds, the sockets in reading order and their elevation levels |

Everything here is whole numbers. Float goldens (from the combat port on) carry their IEEE-754 bits as hex strings.
