---
type: lesson
date: 2026-10-21
area: ci
links: [#381, #395, #396, #397]
promote: none
promoted-to:
---
# Push a new commit after retargeting a PR to main, never just rerun its checks

## What happened
Five sibling PRs were built on top of a stack's top branch. After the stack was squash-merged I rebased them onto main, force-pushed and ran `gh pr edit --base main`. Three of them failed `PR size` and `Conventional Commits` as if they still carried the whole merged stack.

## Evidence
`Production lines changed: 1044 (warn above 200, limit 300)` on #396, and `Not a valid Conventional Commit: feat(sim): add the section base class, a straight stand-in and a socket helper (#391)`. `gh run rerun --failed` did not help; an amended commit pushed with `--force-with-lease` did.

## What we learnt
The checks ran with the old base from the event that started them; a rerun reuses that event, only a new push (a `synchronize` event) reads the new base.

## Rule next time
After `gh pr edit --base main` on a rebased PR, push a fresh commit (an amend with a new date is enough) before reading its checks.
