---
type: decision
date: 2026-10-16
status: accepted   # owner, 2026-10-16: "merge 281 and skip graphify"
decided-by: owner on Claude's evaluation (Haiku pilot, then a pre-registered 88-run study)
links: [#40]
---
# Skip graphify for now

## Context
Ticket #40 asked for a first-hand evaluation of graphify (a codebase knowledge graph for agents) before adopting it. A Haiku agent read its source and tried it on a copy of `godot/sim`.

## Decision
Do not adopt it and do not commit `graphify-out/`. Reasons verified first-hand: the package is `graphifyy` 0.9.91 (Apache-2.0); GDScript is not among its code extensions (`.gd` absent in `graphify/detect.py`), so the graph of `godot/sim` came out empty ("No code files found", 63 files skipped); `graphify claude install` appends a `## graphify` section to the root `CLAUDE.md` (telling reviewers not to flag `graph.json` churn, which conflicts with `docs/REVIEW-CHECKLIST.md`) and adds PreToolUse hooks for Bash, Grep, Read and Glob to `.claude/settings.json`.

## Second attempt and usefulness trial (2026-10-16)
- A GDScript extractor (graphifyy 0.9.91, tree-sitter-gdscript 6.1.0, about 250 lines of ours, patched in at run time) builds a correct graph: 223 nodes and 551 edges for `godot/sim` and `godot/content`, 17 of 17 hand-checked answers. Ready-made options were worse: `graphify-godot` misses every `step()` call, `codebase-memory-mcp` links calls wrongly and needs a 335 MB daemon, ctags has no edges.
- Limits: graphify has no plugin point (we patch private internals), its hooks and `graphify update` cannot see `.gd` files, `GRAPHIFY_MAX_WORKERS=1` is required, the venv is about 150 MB, and the graph leaves out signals, field reads, tests, `main.gd` and `main.tscn`.
- Usefulness: 10 real questions (callers, callees, impact, where-is, tests, signals, scene wiring), one Haiku agent per question and arm (plain grep and Read, or the same plus the graph), graded blind by Opus. Both arms scored 20 of 20. The graph arm used 79 tool calls against 60 and the same tokens (about 595k each). The graph did not help on any question, even the cross-file caller ones, because grep already answers them quickly on a 37-file sim.
- Full study (pre-registered, 88 runs, 32 questions on two codebases: this game and Pixelorama with 249 `.gd` files): every question scored 2 of 2 in both arms. With the graph the agents used 10 percent more tokens (ratio 1.10, CI 1.03 to 1.18), 29 percent more tool calls (1.29, CI 1.18 to 1.42) and 26 percent more wall time (1.26, CI 1.16 to 1.38); Holm-adjusted p 0.025, 0.0001 and below 0.0001. Posted on #40; the report and scripts are in the session scratchpad only, not in the repo.
- Rule set beforehand: adopt only if the graph arm is clearly better (more correct answers, or about 30 percent fewer calls or tokens at equal accuracy). It was not, so the outcome is skip.

## Alternatives considered
- Adopt it for the TypeScript scripts only: too little code to be worth the hooks.
- Add a GDScript extractor (`tree-sitter-gdscript` exists on PyPI, MIT): engineering work, not a config flag; not tried.

## Consequences
- The architecture section in CLAUDE.md and the render-boundary and sim-purity scripts stay our way of keeping the contexts apart.
- Revisit only if the sim grows several times larger or graphify gains GDScript support and plugin hooks. The trial files (extractor, questions, answer key) are in the session scratchpad, not in the repo.
