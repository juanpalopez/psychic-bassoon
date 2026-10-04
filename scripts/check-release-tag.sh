#!/usr/bin/env bash
# Succeeds only for a SemVer 2.0 release tag: vMAJOR.MINOR.PATCH with an
# optional -prerelease suffix. No leading zeros in numeric identifiers, no
# empty identifiers, no build metadata.
set -euo pipefail

tag="${1:-}"
num='(0|[1-9][0-9]*)'
pre_id='(0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)'
pattern="^v${num}\.${num}\.${num}(-${pre_id}(\.${pre_id})*)?$"

if [[ ! "$tag" =~ $pattern ]]; then
  echo "Tag '${tag}' is not a SemVer release tag (vMAJOR.MINOR.PATCH or vMAJOR.MINOR.PATCH-prerelease)." >&2
  exit 1
fi
