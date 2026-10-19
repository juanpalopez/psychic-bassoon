---
type: lesson
date: 2026-10-19
area: tooling
links: [#354]
promote: script
promoted-to: scripts/ios-run.sh
---
# Build the iPhone app outside any iCloud-synced folder

## What happened
The owner's clone lives in `~/Documents`, which iCloud syncs. `scripts/ios-run.sh` kept Xcode's derived data in `build/ios/dd` inside the clone, so the Godot export and the build succeeded but signing the app failed.

## Evidence
`PapercraftKD.app: resource fork, Finder information, or similar detritus not allowed` / `Command CodeSign failed with a nonzero exit code`. `xattr -l` on the app showed `com.apple.FinderInfo` and `com.apple.fileprovider.fpfs#P` (the iCloud file provider's tags).

## What we learnt
iCloud's file provider tags every file it manages, including the built `.app`, and `codesign` rejects a bundle that carries those attributes.

## Rule next time
Keep Xcode's derived data in `~/Library/Developer/Xcode/DerivedData` (the script's default; `PKD_DERIVED` overrides it), never inside the clone.
