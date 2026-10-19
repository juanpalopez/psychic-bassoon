---
type: lesson
date: 2026-10-19
area: harness
links: [#356]
promote: checklist
promoted-to: docs/REVIEW-CHECKLIST.md, CLAUDE.md
---
# Push release tags from the owner's clone, not from a cloud session

## What happened
The site linked to `/releases/latest`, but no `v*` tag had ever been pushed, so the link was a 404. Tagging `v0.1.0` from the cloud session failed both ways the session can write to GitHub.

## Evidence
`git push origin v0.1.0`: `send-pack: unexpected disconnect while reading sideband packet` / `fatal: the remote end hung up unexpectedly`. `gh api repos/.../git/tags`: `Write access to this GitHub API path is not permitted through this proxy. (HTTP 403)`.

## What we learnt
The cloud session could push branches and open PRs but not create a tag, so it could not start a release. The `git push` failure was a disconnect, not a clear refusal; the API's 403 is the proven one.

## Rule next time
To release, an agent checks that `main` is green and hands the owner the exact `git tag -a vX.Y.Z <sha>` and `git push origin vX.Y.Z` commands (or runs them on his Mac when it is linked). Never create the release by hand on GitHub: the workflow's `gh release create` then fails and no builds are attached.

## Follow-up
The first tag was `v0.1.0-alpha.1`. `release.yml` marks it a pre-release, and `GET /releases/latest` returned 404, so the page now links to `/releases` (pre-releases included) and `deploy.yml` checks for that `href`.

Update (2026-10-19, #358): the owner approved a GitHub App that tags the merge of release-please's own PR (`release-please.yml`). Manual tags from the owner's clone still work; a cloud session still never tags by hand.
