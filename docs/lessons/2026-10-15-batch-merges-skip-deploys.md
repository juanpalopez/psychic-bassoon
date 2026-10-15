---
type: lesson
date: 2026-10-15
area: ci
links: [#254, #257, #259]
promote: command
promoted-to:
---
# Merge one PR at a time when each should deploy

## What happened
We merged four PRs within five minutes and the deployments page showed nothing new for two days of commits.

## Evidence
Deploy run notice: `Skipping deploy: 0d2365b... is not the tip of main (bdc8b05...)`; only the last merge deployed.

## What we learnt
`deploy.yml` deploys only the commit that is the tip of main when its CI finishes, so a batch deploys once, for the last one.

## Rule next time
After a batch, check that the Pages deployment is for the tip sha; if each merge must deploy, wait for the previous deploy before the next merge (a `/merge` command can wait for green checks and the deploy).
