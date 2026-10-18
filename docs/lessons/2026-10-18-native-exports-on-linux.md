---
type: lesson
date: 2026-10-18
area: ci
links: [#318]
promote: ci-check
promoted-to: .github/workflows/ci.yml (Linux export, headless run), scripts/check-desktop-export.sh
---
# Check native exports on Linux: every desktop preset and the iOS Xcode project export there

## What happened
Dropping the web build (#318) removed the only check that the exported game starts. The exports and the iPhone script were assumed to need a Mac.

## Evidence
On Linux with Godot 4.7.2, `--export-release` for `Linux`, `Windows` and `macOS` (ad-hoc signed `.app` in a zip) and `--export-debug iOS ../build/ios/PapercraftKD.xcodeproj` all exit 0; iOS only warns `Xcode Build: .ipa can only be built on macOS. Leaving Xcode project without building the package.` The exported Linux binary runs `--headless --quit-after 300` in about 5 s. Each export needs only its release template (`linux_release.x86_64`, `windows_release_x86_64.exe`, `macos.zip`), not the 1.28 GB set. `actions/upload-artifact` does not keep file modes, so the Linux binary loses its executable bit on download.

## What we learnt
Only signing and installing need a Mac; the export itself, and a headless start of the exported game, can be checked in Linux CI. `scripts/ios-run.sh` can be exercised on Linux with stub `xcrun`, `xcodebuild`, `plutil` and `uname`, which is how its team-id restore was checked.

## Rule next time
Prove an export change with a Linux export plus a headless run of the exported build, extract only the release templates you export, and `chmod +x` a Linux binary after downloading an artifact.
