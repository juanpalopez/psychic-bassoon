## Summary

<!-- What changes and why, in a few lines. The PR title must follow Conventional Commits: type(scope): summary -->

Closes #

## Phase

- [ ] This PR belongs to the current phase in `docs/PLAN.md` (no features from later phases)

## Checklist

- [ ] Tests written first for sim/content changes (TDD), and they pass
- [ ] `pnpm lint && pnpm test && pnpm build` pass locally
- [ ] `src/sim` has no imports from `render`, `ui`, `three` or the DOM
- [ ] Balance numbers live in `src/content`; no magic numbers in logic
- [ ] No hard-coded colours (CSS tokens only) and no `Math.random()` in the sim
- [ ] New third-party assets are CC0 and recorded in `assets/CREDITS.md`
- [ ] Docs updated if behaviour or rules changed

## Notes for the reviewer

<!-- Screenshots or a short clip for visual changes; device and fps for performance changes. -->
