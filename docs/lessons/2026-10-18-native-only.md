---
type: decision
date: 2026-10-18
status: accepted
decided-by: owner
links: [#317, #318, #319]
---
# Ship natively on iOS and desktop and drop the web build

## Context
The new look needs more than the Compatibility renderer (WebGL2) gives: no SSAO, no volumetric fog, weak shadows. Godot 4.7 has no WebGPU export. A debug build from a local Xcode project ran on the owner's iPhone 15 Pro on 2026-10-18 with a free Apple ID.

## Decision
- Targets: iOS first, then macOS, Windows and Linux; Android only if wanted. The web export, the GitHub Pages deploy of the game, the HTML shell and the Playwright smoke test go (#318, #319).
- Renderers: Forward+ on desktop (Metal on Mac), Mobile on iOS (`rendering_method.mobile`).
- The phone loop is local: export the Xcode project, build with `xcodebuild`, install with `devicectl` (`scripts/ios-run.sh`, #318). A free Apple ID's installs expire after 7 days; TestFlight needs the paid Apple Developer Program (the owner's call, later).

## Alternatives considered
- Keep the web build on Compatibility: the new look would be a different, flatter game on the web.
- WebGPU: not in Godot 4.7.

## Consequences
- No shareable link for playtesters until TestFlight or a desktop release; the personal site links to releases instead.
- The `?stress` and `?fps` phone checks become command-line flags and a debug menu (#319).
- CI can no longer smoke-test a running build in a browser; it exports a desktop build headless instead.
