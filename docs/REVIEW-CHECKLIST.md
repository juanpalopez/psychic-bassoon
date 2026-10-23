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

## Review a stack in parallel (owner, 2026-10-21)

A stack (PRs linked with `gh stack`, or sibling PRs of one epic) gets one reviewer per PR, all started at once, each at the tier of its own PR. They share a stack directory, so they work in parallel and still see each other's findings. Waiting for one reviewer to read seven diffs in turn was the slowest step of a stack; the extra tokens are the price of finishing in the time of the slowest PR.

- **The caller prepares the stack directory** (in the scratchpad, for example `<scratchpad>/review-<first PR number>/`) with one file, `stack.md`: the PRs bottom to top with base, head commit, ticket, tier and what each layer adds; the decision record to read; what must NOT change (for example the old pipeline and goldens); and the cross-PR questions to check (a higher layer breaking a lower one, two PRs editing the same file, a ticket requirement landing in the wrong PR, config drift between layers). Also run `gh pr checks` for every PR and put the result in `stack.md`.
- **The caller starts every reviewer in one message** (background agents): PR number, tier and model (`haiku`, `sonnet`, `opus`), the stack directory, and the tool budget of the tier.
- **Each reviewer** reads `stack.md`, reviews its own PR's diff (base to head, never the cumulative diff), and writes `report-<N>.md` in the stack directory. Before it finishes it lists the other `report-*.md` and `notes-*.md` files that exist and reads them. It appends to `notes-<N>.md` any fact a sibling needs (a function it saw changed, a constant two PRs both edit) and records in its own report only the interactions it confirmed. It writes only inside the stack directory.
- **Tool budget.** A reviewer's tier limit covers its own review of the diff. The integration step (merge onto the current base, run the area's tests, sweeps), reading the sibling files and writing the two report files have their own allowance of 6 more calls; say so in the prompt.
- **Same-tier PRs that touch the same files** may share one reviewer; say so in `stack.md`.
- **Integration checks, mandatory for generators, plans and anything with seeds:** merge the PR head onto the CURRENT base in a scratch worktree and run the tests of the touched area (CI ran on the head's old base, so it can be stale: a section PR that passed CI failed on the newer base). For a stack or a set of siblings, also merge them all in one scratch branch and run the suite of the area. Sweep a generator over more seeds than the PR's own tests (a sweep of 300 hid a 0.9% failure that showed at 3,000 seeds).
- **Loosened rules:** a PR that lowers a minimum, widens a tolerance, raises a budget or drops a check against its ticket is a finding unless the PR body gives a measured reason.
- **The caller then reads the reports**, merges the `Stack-level` points (at most 3), and posts each PR's report as a comment on that PR (the stack-level section on the top PR). The reviewers never post.
- **Fixes and re-review.** Fix a finding in the PR it belongs to (an agent author may be resumed with the findings). Re-review only the changed PRs and the ones above them, as a delta, with the earlier findings and the diff since the reviewed commit.
- **Slash command.** `/review-stack <PR numbers>` (`.claude/commands/review-stack.md`) does the preparation and the launch.

## What to check

0. **Size.** The `PR size` check enforces at most 300 changed production lines (CLAUDE.md, #349); do not re-count. Flag any edit to `.gitattributes`, to `scripts/check-pr-size.mjs` or to the `PR size` job, and a `size-exception` label the owner did not add. A PR that passes only with the `size-exception` label is reviewed as two halves if it can be, and a finding that the change should have been split is a minor, not a blocker.
1. **Ticket.** Compare the diff with the ticket's "Done when". List unmet or unverified items and any work from a later phase. The only allowed exceptions are the Phase 5 greybox (tickets under the Phase 5 epic), Track B (the Scrap Goblin, #157), the Phase 7 content the owner asked for early (the tickets under the Phase 7 epic #270 and the Phase 7 tickets of epic #316), and the Hand-Folded Fantasy epic (#316 and its children, owner 2026-10-18); a greybox PR must not edit `godot/sim`, `fixtures/` or content numbers, and `godot/render` and `godot/ui` must not touch `rng`, `route_rng` or `pending`, and must not assign to or call a mutating method on a field of the game state (plain reads are allowed until read-only accessors exist). Edits to `godot/content` numbers by a greybox PR are caught by review only.
2. **Sim rules.** GDScript (`godot/sim`): no `Node`, `get_tree`, `Engine`, `Time` or `OS`, no `randf`/`randi`; integer division, 32-bit masking and rounding follow the parity rules in `CLAUDE.md`. No `Math.random()` or clock reads. Player actions only as commands. Game speed is more ticks, never a bigger tick.
3. **Content.** Balance numbers live in `godot/content`; no magic numbers in logic. Lore names are used.
4. **Tests.** Sim and content changes have tests written first, with a fixed seed and no timing. A test that cannot fail is a finding. A test about a mechanic names its board (`TowerFireKit.landscape`, `Game.create(seed, cols, rows)`); only a test about the game board uses the default. A headless test never reads MultiMesh instance transforms back (the dummy renderer returns the identity); it checks the function or array that computed them.
5. **Render and UI.** Typed GDScript. No hard-coded colours (the Theme only; the 3D board's look colours are `source_color` uniforms in `godot/render/paper/` and the `main.tscn` Environment). Free nodes you remove; no allocation per frame; one `MultiMesh` per foe type. Tap targets of at least 44 pt; at the overview zoom a tap on a socket or tower flies the camera in until the socket is at least 44 pt and selects it on arrival (player input during the flight cancels it), and zooming out past 44 pt closes the build menu or tower panel. Respect reduced motion.
6. **Assets.** CC0 packs (the row says CC0) or the owner's own work (the row says `Owned by the owner (all rights reserved)`; AI mesh generators such as Meshy are not used; a Blender model scripted with Claude and HUD icons drawn with Claude are the owner's own); fonts (`.ttf`, `.otf`, `.woff`, `.woff2` under `fonts/`) may also be SIL OFL 1.1 with the licence text in `assets/licenses/`; flag any third-party IP, brand or likeness in a reference; each recorded in `assets/CREDITS.md`; models as GLB only, within the per-unit triangle budget (foe 800 to 1,200 with a baked 512 px map, tower 1,500 to 3,000, boss 3,000 to 5,000) and the frame caps in the plan.
7. **Workflows.** Least-privilege `permissions`; no untrusted input (PR title, body, branch) in `run:` steps; deploy and release cannot skip `ci`; tag and branch guards are enforced. No secrets in the repo, and no Apple team id: the committed iOS preset keeps `application/app_store_team_id` blank (`scripts/ios-run.sh` injects it only for the export). No doc, script or agent step creates a release by hand or has a cloud session push a release tag. The one allowed tag path is the `tag` job of `release-please.yml`, with the GitHub App token, after the merge of release-please's own PR (owner, 2026-10-19, #358); otherwise the owner pushes the `vX.Y.Z` tag from his clone. The release workflow makes the release (`docs/lessons/2026-10-19-release-tag-from-owner-clone.md`).
8. **Consistency.** Docs, scripts, ticket numbers and paths agree with each other and with the code. The PR names its implementing model (CLAUDE.md, "Who implements"), and an architectural change in a Haiku or Sonnet PR is a simple one, not an open design choice (else FIX: back to Opus and the owner).

## Report format

- At most **5 findings**, `blocker` and `major` first. Add at most 5 `minor` findings, each one line. Skip style nits.
- Each `blocker` or `major`: `[severity] path:line title`, then evidence (the command or code you read), the failure scenario, and the smallest fix.
- One line for what you checked and found clean, and a verdict: `BLOCK`, `FIX BEFORE MERGE` or `NO FINDINGS`.
- Start the report with `Reviewed commit: <sha>`.
- Re-review: you get the previous findings and the diff since the reviewed commit. Check only whether each finding is fixed and whether the new diff added problems.
