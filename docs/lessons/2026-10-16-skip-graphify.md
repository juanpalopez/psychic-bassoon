---
type: decision
date: 2026-10-16
status: proposed   # the owner confirms by closing #40
decided-by: Claude on a Haiku agent's evaluation
links: [#40]
---
# Skip graphify for now

## Context
Ticket #40 asked for a first-hand evaluation of graphify (a codebase knowledge graph for agents) before adopting it. A Haiku agent read its source and tried it on a copy of `godot/sim`.

## Decision
Do not adopt it and do not commit `graphify-out/`. Reasons verified first-hand: the package is `graphifyy` 0.9.91 (Apache-2.0); GDScript is not among its code extensions (`.gd` absent in `graphify/detect.py`), so the graph of `godot/sim` came out empty ("No code files found", 63 files skipped); `graphify claude install` appends a `## graphify` section to the root `CLAUDE.md` (telling reviewers not to flag `graph.json` churn, which conflicts with `docs/REVIEW-CHECKLIST.md`) and adds PreToolUse hooks for Bash, Grep, Read and Glob to `.claude/settings.json`.

## Alternatives considered
- Adopt it for the TypeScript scripts only: too little code to be worth the hooks.
- Add a GDScript extractor (`tree-sitter-gdscript` exists on PyPI, MIT): engineering work, not a config flag; not tried.

## Consequences
- The hand-written `docs/ARCHITECTURE.md` and the render-boundary and sim-purity scripts stay our way of keeping the contexts apart.
- Revisit if graphify gains GDScript support. Cost of that try: about an hour in a scratch directory.
