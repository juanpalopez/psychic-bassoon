# Lessons and decisions

Short records so later runs do not relearn the same thing. Decisions record what the owner chose; lessons record what a task taught.

## Naming
`docs/lessons/YYYY-MM-DD-<kebab-slug>.md`, for example `2026-10-14-canvaslayer-overlay-sizing.md`. One topic per file. Copy `TEMPLATE-decision.md` or `TEMPLATE-lesson.md`.

## Index (newest first; add a row in the same PR as the entry)
| Date | Type | Title | Area | Promote | Promoted to |
| --- | --- | --- | --- | --- | --- |
| 2026-10-18 | lesson | Place a map feature through a chosen anchor with a search, not by rejection sampling | sim | none | |
| 2026-10-18 | lesson | Check native exports on Linux: every desktop preset and the iOS Xcode project export there | ci | ci-check | .github/workflows/ci.yml, scripts/check-desktop-export.sh |
| 2026-10-18 | lesson | Never read MultiMesh instance transforms back in a headless test | render | checklist | docs/REVIEW-CHECKLIST.md |
| 2026-10-18 | lesson | Give a mechanic test the board it was written on | sim | checklist | docs/REVIEW-CHECKLIST.md |
| 2026-10-18 | decision | Cap the scripted bot at 15 towers and move the CI game and the win test to valley seeds | balance | none | |
| 2026-10-18 | lesson | Measure screen sizes in tests with a SubViewport, never from the headless window | harness | none | |
| 2026-10-18 | decision | Adopt the Hand-Folded Fantasy look and drop the desk-top framing | render | none | |
| 2026-10-18 | decision | Ship natively on iOS and desktop and drop the web build | infra | none | |
| 2026-10-18 | decision | Play on a 32x20 valley with curved routes, guarded bridges and a movable hero | sim | none | |
| 2026-10-18 | decision | Build the towers, the guard and the Camp Cook as stop-motion papercraft models | render | none | |
| 2026-10-17 | decision | Draw the road as masking tape and dress the board in the papercraft look (superseded by 2026-10-18-hand-folded-fantasy) | render | none | |
| 2026-10-16 | decision | Skip graphify for now | tooling | none | |
| 2026-10-16 | lesson | Keep reusable tools in the repo, not in the shared scratchpad | harness | script | scripts/balance_wins.py, scripts/run-gut.sh |
| 2026-10-16 | lesson | Run the whole GUT suite before every push | ci | script | scripts/run-gut.sh |
| 2026-10-15 | decision | Allow SIL OFL 1.1 fonts in godot/assets, for fonts only | assets | none | CLAUDE.md |
| 2026-10-15 | decision | Offer Auto start: the next wave starts by itself after a cleared wave | ui | none | GDD |
| 2026-10-16 | decision | Add a second spawn source that merges into the main road after wave 10 | sim | none |  |
| 2026-10-16 | decision | Build tier 4 as content data plus two commands, one tower pair per PR | sim | none |  |
| 2026-10-16 | decision | Record lessons and decisions at the end of relevant tasks | harness | none | CLAUDE.md |
| 2026-10-16 | lesson | Derive the pan limit from the ground footprint, not from a share of the board | render | none |  |
| 2026-10-16 | lesson | Keep tests on content constants, not copies of balance numbers | balance | checklist |  |
| 2026-10-15 | lesson | Run long Godot jobs in the background and read their log file | harness | skill |  |
| 2026-10-15 | lesson | Merge one PR at a time when each should deploy | ci | command |  |
| 2026-10-14 | lesson | Size a Control under a CanvasLayer from the viewport, not anchors | ui | checklist |  |
| 2026-10-14 | lesson | Keep commit subjects at most 72 characters and use an allowed scope | ci | ci-check |  |

## Write one when
- A CI check, a tool or the harness surprised you (red CI on a passing local run, a hang, a platform quirk).
- A review finding repeats something an earlier review already flagged.
- The owner took a decision that is not yet in CLAUDE.md, the GDD or PLAN.md.
- A number was chosen from a balance sweep. Keep the table in BALANCE.md and record the choice and its reason here.
- A workaround cost more than 15 minutes, or a wrong assumption about Godot or GDScript cost a rework.

## Do not write one when
- The fact is already in CLAUDE.md, REVIEW-CHECKLIST.md, BALANCE.md or a code comment. Link to it instead.
- It is a plain bug fix whose regression test already explains it.
- It is a preference with no evidence, or a one-off that cannot happen again.

## Rules
- The final message of every task lists the entries it wrote (path and one line each), or says "Lessons: none".
- Refer to an entry from the PR body and never edit an accepted decision. Supersede it with a new one; the only edit allowed to the old entry is setting its `status` to `superseded-by: <file>`.
- An entry with `promote` set to anything other than `none` stays open until `promoted-to` is filled in.

## Promoting a lesson
Promote a lesson when it has happened twice, or when one failure was costly. Pick the cheapest form that a machine enforces:
1. **ci-check / script**: if a tool can detect it, write `scripts/check-<name>.mjs` with a Vitest test next to it (as `check-sim-purity` and `check-render-boundary` already do) and wire it into `ci`. Then remove the matching line from REVIEW-CHECKLIST.md so reviewers stop paying for it.
2. **checklist**: if it needs judgement, add one line to `docs/REVIEW-CHECKLIST.md`. If it is a working rule, add it to CLAUDE.md too, and keep the two files in step.
3. **command / skill / agent / hook**: if it is a repeated multi-step procedure, write `.claude/commands/<name>.md` (one prompt) or `.claude/skills/<name>/SKILL.md` (steps plus scripts); a role that keeps coming back becomes an agent in `.claude/agents/`; something that must happen on every tool call or session start becomes a hook.
4. **mode**: a named way of working for a kind of task (for example a balance mode: which agents run the sweeps, which files may change, which checks must pass, what to write at the end), kept as a skill or a command that sets those rules for the session.
5. **mcp / plugin**: an MCP server when the task needs a tool that talks to an outside system (the board, a build farm, a device), and a plugin only when several skills, hooks, agents and servers ship together.
6. Fill in `promoted-to`, update the index row, and use the commit type `ci`, `docs` or `chore`, referencing the lesson file.
