---
type: lesson
date: 2026-10-14
area: ci
links: [#250, #252, #257, #263]
promote: ci-check
promoted-to:
---
# Keep commit subjects at most 72 characters and use an allowed scope

## What happened
PR checks rejected several of our commits: the subject was 74 to 76 characters, or the scope was `e2e` (and later `lessons`), which is not an allowed scope.

## Evidence
`PR checks` job `Conventional Commits`: `Not a valid Conventional Commit: fix(render): unlock audio again on release, stop effects on mute, test without the clock`; PRs #250, #252, #257, #263.

## What we learnt
The checker only accepts the scopes in CLAUDE.md (sim, render, ui, content, assets, docs, ci, build, deps) and a summary of at most 72 characters. We kept finding out after pushing.

## Rule next time
Check the subject (a script, or a `/pr-open` command) before `git commit` and `gh pr create`, amend it if it is over 72 characters, and use `ci` for end-to-end test changes.
