---
type: lesson
date: 2026-10-16
area: ci
links: [#279]
promote: script
promoted-to: scripts/run-gut.sh
---
# Run the whole GUT suite before every push

## What happened
PR #279 went red in CI on `test_tower_panel`, which hard-coded the old Prism Spire damage, after I had run only the test scripts I expected to change and written "GUT 797 pass" in the PR body.

## Evidence
CI log: `Expected 'Damage 76/s  Range 2.6' to contain '84/s'` (1 failing test, 453568/453569 asserts).

## What we learnt
A content number reaches tests in unrelated areas (UI, render, replay goldens). A partial run proves nothing about them, and the claim in the PR body was wrong.

## Rule next time
Run `scripts/run-gut.sh` (all tests, output in a file) before pushing and only write a test count in a PR body from that run.
