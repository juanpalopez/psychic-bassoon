---
type: decision
date: 2026-10-19
status: accepted
decided-by: owner
links: [#370]
---
# Rename the game Kingdom of the Fold and dress it in the new design system

## Context
The owner brought a design-system brief and a homepage reference that call the game "Kingdom of the Fold". The repo, the GDD and the builds still said Papercraft Kingdom Defense. Asked which name to use, he chose the rename (2026-10-19).

## Decision
The game is Kingdom of the Fold. The homepage (#370) uses the name first. The in-game title, the build file names, the GDD and CLAUDE.md follow in later PRs. Game words stay the GDD's: Buttons, the Heartstone, Golden Staples, and the tower, foe and spell names.
The look follows the Kingdom of the Fold design system (claude.ai artifact, owner's account): Alegreya and Alegreya Sans, parchment and wood surfaces, kingdom blue for the one primary action.

## Alternatives considered
- Keep Papercraft Kingdom Defense: the owner preferred the new name.
- Use the new name for marketing only: rejected; the game takes it too.

## Consequences
- Until the rename PRs land, downloads still carry the working name; the homepage says so.
- The repo stays `psychic-bassoon`.
