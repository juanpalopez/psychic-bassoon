## Summary

<!-- What changes and why, in a few lines. The PR title must follow Conventional Commits: type(scope): summary -->

Closes #

## Phase

- [ ] This PR belongs to the current phase in `docs/PLAN.md` (no features from later phases)

## Checklist

- [ ] Tests written first for sim/content changes (TDD), and they pass
- [ ] `pnpm lint && pnpm test` pass locally, and for Godot code `gdformat`, `gdlint`, GUT and the Linux desktop export
- [ ] `godot/sim` passes `pnpm check:sim-purity`
- [ ] Balance numbers live in `godot/content`; no magic numbers in logic
- [ ] No hard-coded colours (CSS tokens or the Godot Theme only) and no `Math.random()` or `randf`/`randi` in the sim
- [ ] New assets (CC0 packs, or the owner's own models as `Owned by the owner (all rights reserved)`) are recorded in `assets/CREDITS.md` with source and licence
- [ ] Docs updated if behaviour or rules changed
- [ ] Adversarial review done at the right tier (see `docs/REVIEW-CHECKLIST.md`) and posted, or skipped by rule; blockers and majors fixed or answered

## Lessons and decisions

<!-- Paths of the entries written in docs/lessons/ with their rule line, or: Lessons: none -->

## Notes for the reviewer

<!-- Screenshots or a short clip for visual changes; device and fps for performance changes. -->
