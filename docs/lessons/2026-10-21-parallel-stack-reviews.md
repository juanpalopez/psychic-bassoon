---
type: decision
date: 2026-10-21
status: accepted
decided-by: owner
links: [#381, #404]
---
# Review a stack with one reviewer per PR, in parallel, sharing notes

## Context
Reviewing the valley stacks (4 foundation PRs, then 5 section PRs, then 2 layout PRs) with one reviewer reading every PR in turn made the review the slowest step; the same reviewers also showed that CI can pass on an old base (two section PRs failed once merged onto the current base) and that a 300-seed sweep hid a 0.9% failure found at 3,000 seeds.

## Decision
A stack or a set of sibling PRs gets one reviewer per PR, all started at once, each at the tier and model of its own PR. They share a stack directory: `stack.md` from the caller (PRs, tiers, what must not change, cross-PR questions) and `report-<N>.md` / `notes-<N>.md` from each reviewer, read before finishing. Every review merges the head onto the current base and runs the touched area's tests, sweeps generators over more seeds than the PR does, and flags loosened rules. `/review-stack <PR numbers>` prepares and launches it. Carried by `docs/REVIEW-CHECKLIST.md`, `.claude/agents/adversarial-reviewer.md`, `.claude/commands/review-stack.md` and CLAUDE.md.

## Alternatives considered
- One reviewer for the whole stack (the rule before): cheapest in tokens, slowest in time, and it reads many diffs in one context.
- Parallel reviewers with no shared notes: faster, but misses interactions between PRs.

## Consequences
- More tokens per stack (one start-up per PR), less waiting; the caller reads the reports and posts the comments.
- Reviewers write files in the stack directory only; they stay read-only for the repo.
