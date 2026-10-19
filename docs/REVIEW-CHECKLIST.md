# Review checklist

What the `adversarial-reviewer` agent reads instead of the full `CLAUDE.md` and `docs/PLAN.md`. Keep it short; when a rule here changes in `CLAUDE.md`, change it here too.

## Pick the review tier

PRs are small (at most 300 changed production lines, #349), so a cheaper model is enough for most (owner, 2026-10-19). Choose by what the PR touches.

| Tier | When | Model | Depth |
| --- | --- | --- | --- |
| Skip | Dependabot bump with green CI, typo or wording-only docs, generated files | none | Check CI is green and the title conforms, then merge |
| Light | Small, low-risk changes with no logic that can break the sim: docs with rules or numbers, `godot/content` data and numbers, tests only, copy and Theme tweaks, repo scripts, renames; at most about 100 changed production lines | `haiku` | Diff, ticket and checks 0, 1, 3, 4, 8 only; at most 5 tool calls |
| Standard | Most PRs: `godot/sim` logic (map generation, combat, economy, waves), render, UI, scaffolding, workflows that do not touch secrets, permissions or release, and rule changes in `CLAUDE.md` | `sonnet` | Diff, ticket and this checklist; at most 8 tool calls |
| Deep | Determinism-critical sim code (the PRNG, the tick and command loop, the replay test, seed and snapshot handling) and anything that touches secrets, permissions, tokens, deploy or release trust (tag guards, release and deploy workflows) | `opus` | As Standard, plus try to break it (mutations, edge inputs); at most 15 tool calls |

**Escalation.** If you cannot judge the change at your tier (a Light review meets sim logic, a Standard review meets the tick loop, the PRNG or a token), stop and reply `ESCALATE: <reason>`; the caller reruns one tier up. Do not give a verdict you cannot support. When unsure which tier, take the lower one; escalate when the review says so, or when the first review found a blocker in sim, security or release code. A Light review never clears a PR that changes `godot/sim` logic.

Rough cost of one review: Light about 10k tokens, Standard 30k to 40k, Deep 50k to 75k. A sim PR that does not touch the tick loop, the PRNG, seeds or snapshots is Standard even without `scripts/mutate.py` results, but the reviewer then checks that its tests can fail.

## What the caller sends the reviewer

The author does the cheap work first and hands over the evidence, so the reviewer verifies instead of rediscovering:

- The PR number, base, head commit, ticket, tier, and for a re-review the earlier findings and the diff since.
- **The author's mutation results**: the list from `scripts/mutate.py` (a file in `scripts/mutations/`), with the survivors. The reviewer checks that the list covers the rules of the ticket and adds a mutation only for a rule it is missing; it does not rebuild a worktree to edit code by hand.
- **The author's numbers**: for a balance or doc PR, the raw files and the commands that made them. The reviewer recounts a sample and the claims that matter, not every number.
- A tool call budget (the tier's limit) and the instruction to report only what it proved, and to say what it did not check.
- Never reuse or reset the author's worktrees: create a new scratch worktree and remove it afterwards.

A re-review is worth its cost when logic changed (code under `godot/sim`, the tick loop, input handling). A fix that only adds tests, changes wording or moves a number is checked by the author with `scripts/mutate.py`, and the PR says so.

## Do not repeat CI

Run `gh pr checks <N>` first. Lint, types, unit tests, the Linux desktop export and its checked headless run (a clean log: no `ERROR:`, `SCRIPT ERROR:` or `SHADER ERROR:` line, exit 0, no timeout; nothing is rendered, so judge visuals from screenshots), and the PR title and commit format are already proven by CI when green: do not re-run them. Spend the effort on what CI cannot see: logic, missing tests, mismatches with the ticket, rules no linter enforces, and whether the checks themselves are strong enough (for example, mutate the code and see if a test fails). If CI is red, missing or not yet run, say so and run only the minimum you need.

## Review a stack as a whole

A stack (PRs linked with `gh stack`) gets one review pass, not one reviewer per PR. This avoids paying for the same context seven times and catches problems that only show across layers.

- **Launch once.** One reviewer gets all the PR numbers, bottom to top, with each PR's base, head commit and ticket. Read the checklist and shared context once.
- **Per-PR diffs.** Review each PR's own diff (its base to its head), in stack order, never the cumulative diff.
- **Group by tier.** All PRs of one tier in the stack go in one review of that tier. A single-tier stack is one review.
- **Cross-PR checks.** Look for what only a whole-stack view shows: a higher layer breaking an assumption of a lower one, duplicated or contradictory work, a ticket's requirement landing in the wrong PR, and config drift between layers (versions, scripts, paths, workflow names).
- **Limits.** The tool-call limit of the tier applies to the whole review, plus 4 more calls per extra PR. Output limits apply per PR, plus at most 3 stack-level findings.
- **Report.** One section per PR (`Reviewed commit`, findings, verdict), then a short `Stack-level` section.
- **Posting.** Post each PR's section as a comment on that PR, and the stack-level section on the top PR.
- **Fixes and re-review.** Fix a finding in the PR it belongs to, then `gh stack sync`. Re-review only the changed PRs and the ones above them, as a delta.

## What to check

0. **Size.** The `PR size` check enforces at most 300 changed production lines (CLAUDE.md, #349); do not re-count. Flag any edit to `.gitattributes`, to `scripts/check-pr-size.mjs` or to the `PR size` job, and a `size-exception` label the owner did not add. A PR that passes only with the `size-exception` label is reviewed as two halves if it can be, and a finding that the change should have been split is a minor, not a blocker.
1. **Ticket.** Compare the diff with the ticket's "Done when". List unmet or unverified items and any work from a later phase. The only allowed exceptions are the Phase 5 greybox (tickets under the Phase 5 epic), Track B (the Scrap Goblin, #157), the Phase 7 content the owner asked for early (the tickets under the Phase 7 epic #270 and the Phase 7 tickets of epic #316), and the Hand-Folded Fantasy epic (#316 and its children, owner 2026-10-18); a greybox PR must not edit `godot/sim`, `fixtures/` or content numbers, and `godot/render` and `godot/ui` must not touch `rng`, `route_rng` or `pending`, and must not assign to or call a mutating method on a field of the game state (plain reads are allowed until read-only accessors exist). Edits to `godot/content` numbers by a greybox PR are caught by review only.
2. **Sim rules.** GDScript (`godot/sim`): no `Node`, `get_tree`, `Engine`, `Time` or `OS`, no `randf`/`randi`; integer division, 32-bit masking and rounding follow the parity rules in `CLAUDE.md`. No `Math.random()` or clock reads. Player actions only as commands. Game speed is more ticks, never a bigger tick.
3. **Content.** Balance numbers live in `godot/content`; no magic numbers in logic. Lore names are used.
4. **Tests.** Sim and content changes have tests written first, with a fixed seed and no timing. A test that cannot fail is a finding. A test about a mechanic names its board (`TowerFireKit.landscape`, `Game.create(seed, cols, rows)`); only a test about the game board uses the default. A headless test never reads MultiMesh instance transforms back (the dummy renderer returns the identity); it checks the function or array that computed them.
5. **Render and UI.** Typed GDScript. No hard-coded colours (the Theme only; the 3D board's look colours are `source_color` uniforms in `godot/render/paper/` and the `main.tscn` Environment). Free nodes you remove; no allocation per frame; one `MultiMesh` per foe type. Tap targets of at least 44 pt; at the overview zoom a tap on a socket or tower flies the camera in until the socket is at least 44 pt and selects it on arrival (player input during the flight cancels it), and zooming out past 44 pt closes the build menu or tower panel. Respect reduced motion.
6. **Assets.** CC0 packs (the row says CC0) or the owner's own work (the row says `Owned by the owner (all rights reserved)`; AI mesh generators such as Meshy are not used; a Blender model scripted with Claude and HUD icons drawn with Claude are the owner's own); fonts (`.ttf`, `.otf`, `.woff`, `.woff2` under `fonts/`) may also be SIL OFL 1.1 with the licence text in `assets/licenses/`; flag any third-party IP, brand or likeness in a reference; each recorded in `assets/CREDITS.md`; models as GLB only, within the per-unit triangle budget (foe 800 to 1,200 with a baked 512 px map, tower 1,500 to 3,000, boss 3,000 to 5,000) and the frame caps in the plan.
7. **Workflows.** Least-privilege `permissions`; no untrusted input (PR title, body, branch) in `run:` steps; deploy and release cannot skip `ci`; tag and branch guards are enforced. No secrets in the repo, and no Apple team id: the committed iOS preset keeps `application/app_store_team_id` blank (`scripts/ios-run.sh` injects it only for the export). No doc, script or agent step creates a release by hand or has a cloud session push a release tag. The one allowed tag path is the `tag` job of `release-please.yml`, with the GitHub App token, after the merge of release-please's own PR (owner, 2026-10-19, #358); otherwise the owner pushes the `vX.Y.Z` tag from his clone. The release workflow makes the release (`docs/lessons/2026-10-19-release-tag-from-owner-clone.md`).
8. **Consistency.** Docs, scripts, ticket numbers and paths agree with each other and with the code.

## Report format

- At most **5 findings**, `blocker` and `major` first. Add at most 5 `minor` findings, each one line. Skip style nits.
- Each `blocker` or `major`: `[severity] path:line title`, then evidence (the command or code you read), the failure scenario, and the smallest fix.
- One line for what you checked and found clean, and a verdict: `BLOCK`, `FIX BEFORE MERGE` or `NO FINDINGS`.
- Start the report with `Reviewed commit: <sha>`.
- Re-review: you get the previous findings and the diff since the reviewed commit. Check only whether each finding is fixed and whether the new diff added problems.
