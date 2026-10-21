---
description: Review a stack or a set of sibling PRs with one adversarial reviewer per PR, in parallel, sharing notes
argument-hint: <PR numbers, bottom to top>
---

Review these PRs as a stack: $ARGUMENTS

Follow "Review a stack in parallel" in `docs/REVIEW-CHECKLIST.md`.

1. For each PR run `gh pr view <N> --json number,title,baseRefName,headRefOid,body,files` and `gh pr checks <N>`; find the ticket in the body (`Closes #N` or `Refs #N`) and pick the tier from the checklist (what the PR touches, not how it feels): `haiku` light, `sonnet` standard, `opus` deep.
2. Create the stack directory `<scratchpad>/review-<first PR number>/` and write `stack.md`: the PRs bottom to top (number, base, head commit, ticket, tier, one line on what it adds), the decision record or plan to read, what must NOT change (name the old pipeline, goldens, fixtures, workflows), the cross-PR questions (a higher layer breaking a lower one; two PRs editing the same file: list the shared files from the `files` lists; a ticket requirement in the wrong PR; config drift), and the `gh pr checks` result of each PR.
3. Start one `adversarial-reviewer` agent per PR in a single message (two same-tier PRs that edit the same files may share one reviewer: say so in `stack.md`), all with `run_in_background: true`, each with `model` set to its tier's model, giving: the PR number, base, head commit, ticket, tier, the stack directory path, and that it must write `report-<N>.md` and `notes-<N>.md` there, and that its integration, sibling reads and report writes have 6 extra tool calls beyond the tier limit.
4. When they report, read the reports (and any `notes-*.md`), write the stack-level points (at most 3), and post each PR's report as a comment headed `Adversarial review (Claude)` (the stack-level section on the top PR). Fix every blocker and major or answer it on the PR with a reason; re-review only the delta.
