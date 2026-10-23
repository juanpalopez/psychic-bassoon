---
type: decision
date: 2026-10-23
status: accepted
decided-by: owner
links: []
---
# Opus designs and mentors; Haiku and Sonnet implement

## Context
Every implementation agent so far ran on Opus (about $50 for the session of 2026-10-22 and 23). Reviews already scale by tier (Haiku, Sonnet, Opus). Most tickets now arrive with a clear plan and "Done when" list.

## Decision
- Opus is the designer and mentor: architecture proposals, RFCs, design memos, ticket plans and briefs, owner decisions, deep reviews. It implements only when the owner asks.
- Haiku implements well-defined tickets (clear "Done when", one area, no open design choice); Sonnet implements the rest.
- Either may propose a simple architectural change in its PR; one that needs a real design choice stops and goes back to Opus and the owner.
- The rule lives in CLAUDE.md, "Who implements".

## Alternatives considered
- Opus for everything: best results, highest cost.
- Sonnet for everything: cheaper, but design-heavy tickets (the road redesign, #460) need Opus's planning.

## Consequences
- Briefs must be complete enough for a smaller model: files, rules, tests, commands and when to stop.
- If Haiku's PRs keep failing review, that ticket kind moves to Sonnet.
