## Summary

<!-- What changes and why, in a few lines. The PR title must follow Conventional Commits: type(scope): summary -->

Closes #

## Phase

- [ ] This PR belongs to the current phase in `docs/PLAN.md` (no features from later phases)

## Checklist

- [ ] Tests written first for sim/content changes (TDD), and they pass
- [ ] `pnpm lint && pnpm test` pass locally, and for Godot code `gdformat`, `gdlint`, GUT and the web export
- [ ] `src/sim` has no DOM, `Math.random` or clock, and `godot/sim` passes `pnpm check:sim-purity`
- [ ] Balance numbers live in `godot/content` (or `src/content`); no magic numbers in logic
- [ ] No hard-coded colours (CSS tokens or the Godot Theme only) and no `Math.random()` or `randf`/`randi` in the sim
- [ ] New third-party or generated assets (CC0, Meshy) are recorded in `assets/CREDITS.md` with source and licence
- [ ] Docs updated if behaviour or rules changed
- [ ] Adversarial review done at the right tier (see `docs/REVIEW-CHECKLIST.md`) and posted, or skipped by rule; blockers and majors fixed or answered

## Notes for the reviewer

<!-- Screenshots or a short clip for visual changes; device and fps for performance changes. -->
