# Review checklist

What the `adversarial-reviewer` agent reads instead of the full `CLAUDE.md` and `docs/PLAN.md`. Keep it short; when a rule here changes in `CLAUDE.md`, change it here too.

## Pick the review tier

| Tier | When | Model | Depth |
| --- | --- | --- | --- |
| Skip | Dependabot bump with green CI, typo or wording-only docs, generated files | none | Check CI is green and the title conforms, then merge |
| Standard | Most PRs: scaffolding, content data, UI, render, docs with rules or numbers | `sonnet` | Diff, ticket and this checklist; at most 8 tool calls |
| Deep | `.github/workflows/`, `src/sim`, anything touching secrets, permissions, deploy or release, determinism, a rule change in `CLAUDE.md` | `opus` | As Standard, plus try to break it (mutations, edge inputs); at most 15 tool calls |

When unsure, take the higher tier.

## Do not repeat CI

Run `gh pr checks <N>` first. Lint, types, unit tests, build, bundle size, the smoke test and the PR title and commit format are already proven by CI when green: do not re-run them. Spend the effort on what CI cannot see: logic, missing tests, mismatches with the ticket, rules no linter enforces, and whether the checks themselves are strong enough (for example, mutate the code and see if a test fails). If CI is red, missing or not yet run, say so and run only the minimum you need.

## What to check

1. **Ticket.** Compare the diff with the ticket's "Done when". List unmet or unverified items and any work from a later phase.
2. **Sim rules.** No imports from `render`, `ui`, `three` or the DOM, including dynamic `import()` and `globalThis`. No `Math.random()` or clock reads. Player actions only as commands. Game speed is more ticks, never a bigger tick.
3. **Content.** Balance numbers live in `src/content`; no magic numbers in logic. Lore names are used.
4. **Tests.** Sim and content changes have tests written first, with a fixed seed and no timing. A test that cannot fail is a finding.
5. **Render and UI.** No `any`. No hard-coded colours (tokens only). Dispose geometry and materials; no allocation in the frame loop. Tap targets of at least 44 px. Respect `prefers-reduced-motion`.
6. **Assets.** CC0 only, recorded in `assets/CREDITS.md`, compressed GLB only.
7. **Workflows.** Least-privilege `permissions`; no untrusted input (PR title, body, branch) in `run:` steps; deploy and release cannot skip `ci`; tag and branch guards are enforced.
8. **Consistency.** Docs, scripts, ticket numbers and paths agree with each other and with the code.

## Report format

- At most **5 findings**, `blocker` and `major` first. Add at most 5 `minor` findings, each one line. Skip style nits.
- Each `blocker` or `major`: `[severity] path:line title`, then evidence (the command or code you read), the failure scenario, and the smallest fix.
- One line for what you checked and found clean, and a verdict: `BLOCK`, `FIX BEFORE MERGE` or `NO FINDINGS`.
- Start the report with `Reviewed commit: <sha>`.
- Re-review: you get the previous findings and the diff since the reviewed commit. Check only whether each finding is fixed and whether the new diff added problems.
