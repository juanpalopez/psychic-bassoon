# Goldens written by the GDScript sim

Regression data written by the GDScript sim itself, not by the TypeScript sim (whose fixtures in `/fixtures` are frozen and cover only the ported core). A golden changes only by a reviewed balance change: edit the rule or number, regenerate it with its script in `godot/tools/`, and say so in the PR.

| File | Written by | Holds |
| --- | --- | --- |
| `sockets.json` | `godot --headless --path godot -s tools/write_sockets_golden.gd` | for 8 seeds, the sockets in reading order and their elevation levels |
| `socket_blocks.json` | `godot --headless --path godot -s tools/write_socket_blocks_golden.gd` | for 8 seeds on the 22 by 16 board, the 2x2 socket anchors, their levels and the Heartstone's footprint |
| `replays.json` | `godot --headless --path godot -s tools/write_replays_golden.gd` | 5 whole games played by the scripted bot (won, lost and stopped runs, each strategy): the seed, the commands with their ticks, a checkpoint every 20 seconds of play and the final state |
| `specs.json` | `godot --headless --path godot -s tools/write_specs_golden.gd` | one fixed tier 4 scenario (a Crossbow Ballista and its skewer on a line of Orcs): checkpoints every second with the same hashes |
| `specs_prism.json` | same tool | the two Prism Spire specs (Flash Freeze with Frostbite; Ink Vortex with Corrosive Light) on a line of foes with a Golem among them, checkpoints every second |
| `specs_mortar.json` | same tool | the two Thimble Mortar specs (Confetti Burst with Shrapnel Spread; PVA Deluge with Lingering Residue) on a line of foes, checkpoints every second |

## How a replay golden works

A checkpoint is taken at the start of a tick, before that tick's commands. It holds a few readable numbers (tick, wave, Buttons, Heartstone health, foe and tower counts), the SHA-256 of the whole state and a running SHA-256 of every event so far, with every float turned into its IEEE-754 bits first, so a change in the last bit of any foe's position shows up. `tests/sim/test_replay.gd` checks two things: the bot, played again from the seed, gives the recorded commands and checkpoints, and the recorded commands alone, fed to a fresh game, give the same checkpoints. When a checkpoint differs, the readable numbers say roughly where the games diverged; then replay with a snapshot of the full state (`GameTestKit.snapshot`) around that tick.

Whole numbers and strings are written as they are; floats are never written, only inside the hash.
