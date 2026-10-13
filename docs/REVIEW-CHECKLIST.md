# Review checklist

What the `adversarial-reviewer` agent reads instead of the full `CLAUDE.md` and `docs/PLAN.md`. Keep it short; when a rule here changes in `CLAUDE.md`, change it here too.

## Pick the review tier

| Tier | When | Model | Depth |
| --- | --- | --- | --- |
| Skip | Dependabot bump with green CI, typo or wording-only docs, generated files | none | Check CI is green and the title conforms, then merge |
| Standard | Most PRs: scaffolding, content data, UI, render, docs with rules or numbers, and pure-logic sim modules (`godot/sim`) (map generation, combat, economy, waves) | `sonnet` | Diff, ticket and this checklist; at most 8 tool calls |
| Deep | `.github/workflows/`, determinism-critical sim code (the PRNG, the tick and command loop, the replay test and seed or snapshot handling), anything touching secrets, permissions, deploy or release, a rule change in `CLAUDE.md` | `opus` | As Standard, plus try to break it (mutations, edge inputs); at most 15 tool calls |

When unsure, take the higher tier.

## Do not repeat CI

Run `gh pr checks <N>` first. Lint, types, unit tests, build, bundle size, the smoke test and the PR title and commit format are already proven by CI when green: do not re-run them. Spend the effort on what CI cannot see: logic, missing tests, mismatches with the ticket, rules no linter enforces, and whether the checks themselves are strong enough (for example, mutate the code and see if a test fails). If CI is red, missing or not yet run, say so and run only the minimum you need.

## Review a stack as a whole

A stack (PRs linked with `gh stack`) gets one review pass, not one reviewer per PR. This avoids paying for the same context seven times and catches problems that only show across layers.

- **Launch once.** One reviewer gets all the PR numbers, bottom to top, with each PR's base, head commit and ticket. Read the checklist and shared context once.
- **Per-PR diffs.** Review each PR's own diff (its base to its head), in stack order, never the cumulative diff.
- **Group by tier.** All deep-tier PRs in the stack go in one deep review; the rest go in one standard review. A single-tier stack is one review.
- **Cross-PR checks.** Look for what only a whole-stack view shows: a higher layer breaking an assumption of a lower one, duplicated or contradictory work, a ticket's requirement landing in the wrong PR, and config drift between layers (versions, scripts, paths, workflow names).
- **Limits.** The tool-call limit of the tier applies to the whole review, plus 4 more calls per extra PR. Output limits apply per PR, plus at most 3 stack-level findings.
- **Report.** One section per PR (`Reviewed commit`, findings, verdict), then a short `Stack-level` section.
- **Posting.** Post each PR's section as a comment on that PR, and the stack-level section on the top PR.
- **Fixes and re-review.** Fix a finding in the PR it belongs to, then `gh stack sync`. Re-review only the changed PRs and the ones above them, as a delta.

## What to check

1. **Ticket.** Compare the diff with the ticket's "Done when". List unmet or unverified items and any work from a later phase. The only allowed exceptions are the Phase 5 greybox (tickets under the Phase 5 epic) and Track B (the Scrap Goblin, #157); a greybox PR must not edit `godot/sim`, `fixtures/` or content numbers, and `godot/render` and `godot/ui` must not touch `rng`, `route_rng` or `pending`, and must not assign to or call a mutating method on a field of the game state (plain reads are allowed until read-only accessors exist). Edits to `godot/content` numbers by a greybox PR are caught by review only.
2. **Sim rules.** GDScript (`godot/sim`): no `Node`, `get_tree`, `Engine`, `Time` or `OS`, no `randf`/`randi`; integer division, 32-bit masking and rounding follow the parity rules in `CLAUDE.md`. No `Math.random()` or clock reads. Player actions only as commands. Game speed is more ticks, never a bigger tick.
3. **Content.** Balance numbers live in `godot/content`; no magic numbers in logic. Lore names are used.
4. **Tests.** Sim and content changes have tests written first, with a fixed seed and no timing. A test that cannot fail is a finding.
5. **Render and UI.** Typed GDScript. No hard-coded colours (the Theme only). Free nodes you remove; no allocation per frame; one `MultiMesh` per foe type. Tap targets of at least 44 px. Respect reduced motion.
6. **Assets.** CC0 packs (the row says CC0) or the owner's own models (the row says `Owned by the owner (all rights reserved)`; AI mesh generators such as Meshy are not used; a Blender model scripted with Claude is the owner's own); flag any third-party IP, brand or likeness in a reference; each recorded in `assets/CREDITS.md`; GLB only, within the per-unit triangle budget (foe 800 to 1,200 with a baked 512 px map, tower 1,500 to 3,000, boss 3,000 to 5,000) and the frame caps in the plan.
7. **Workflows.** Least-privilege `permissions`; no untrusted input (PR title, body, branch) in `run:` steps; deploy and release cannot skip `ci`; tag and branch guards are enforced.
8. **Consistency.** Docs, scripts, ticket numbers and paths agree with each other and with the code.

## Report format

- At most **5 findings**, `blocker` and `major` first. Add at most 5 `minor` findings, each one line. Skip style nits.
- Each `blocker` or `major`: `[severity] path:line title`, then evidence (the command or code you read), the failure scenario, and the smallest fix.
- One line for what you checked and found clean, and a verdict: `BLOCK`, `FIX BEFORE MERGE` or `NO FINDINGS`.
- Start the report with `Reviewed commit: <sha>`.
- Re-review: you get the previous findings and the diff since the reviewed commit. Check only whether each finding is fixed and whether the new diff added problems.
