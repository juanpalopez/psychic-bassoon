#!/usr/bin/env bash
# Builds the game for a connected iPhone and runs it there (macOS with Xcode only).
#
#   scripts/ios-run.sh
#
# 1. Finds the first connected physical iPhone (or PKD_DEVICE).
# 2. Godot exports the Xcode project to build/ios/PapercraftKD.xcodeproj (the "iOS" preset).
# 3. xcodebuild builds it with automatic signing for your Apple team.
# 4. devicectl installs the app on the iPhone and launches it.
#
# The Apple team id is personal, so it never lives in the repo: the script reads it from
# PKD_TEAM_ID or ~/.config/pkd/team_id, writes it into godot/export_presets.cfg only for the
# export, and always puts the committed preset back. Other settings:
#   PKD_DEVICE       the iPhone's UDID (default: the first connected physical iPhone)
#   PKD_UNLOCK_WAIT  seconds to wait for a locked iPhone to be unlocked (default 120)
#   PKD_DERIVED      Xcode's derived data (default ~/Library/Developer/Xcode/DerivedData/PapercraftKD-ios)
#   GODOT            the Godot binary (default: godot on PATH, or /Applications/Godot.app)
#
# With a free Apple ID the install expires after 7 days: run the script again. The first
# launch on a phone needs the developer trusted in Settings → General → VPN & Device
# Management (and Developer Mode on in Settings → Privacy & Security).
set -euo pipefail

BUNDLE_ID="com.juanpalopez.papercraftkd"
PROJECT="build/ios/PapercraftKD.xcodeproj"
SCHEME="PapercraftKD"
# Derived data stays outside the clone: in an iCloud-synced folder (~/Documents, ~/Desktop) the
# file provider tags the built app and codesign stops with "resource fork, Finder information,
# or similar detritus not allowed" (#354).
DERIVED="${PKD_DERIVED:-${HOME}/Library/Developer/Xcode/DerivedData/PapercraftKD-ios}"
PRESET="godot/export_presets.cfg"
TEAM_KEY="application/app_store_team_id"
TEAM_FILE="${HOME}/.config/pkd/team_id"
UNLOCK_WAIT="${PKD_UNLOCK_WAIT:-120}"

cd "$(dirname "$0")/.."
GODOT_VERSION="$(tr -d '[:space:]' < .godot-version)"

fail() {
  echo "ios-run: $*" >&2
  exit 1
}

[ "$(uname -s)" = "Darwin" ] || fail "this script needs macOS with Xcode (it builds with xcodebuild)."

# xcode-select may point at the Command Line Tools, which have no iOS SDK and no devicectl,
# so prefer the full Xcode when it is installed.
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app/Contents/Developer ]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
xcrun --find xcodebuild >/dev/null 2>&1 || fail "xcodebuild not found. Install Xcode from the App Store."
xcrun --find devicectl >/dev/null 2>&1 \
  || fail "devicectl not found. It needs Xcode 15 or newer; set DEVELOPER_DIR to your Xcode's Contents/Developer."

godot_bin="${GODOT:-}"
if [ -z "$godot_bin" ]; then
  if command -v godot >/dev/null; then
    godot_bin="godot"
  elif [ -x /Applications/Godot.app/Contents/MacOS/Godot ]; then
    godot_bin="/Applications/Godot.app/Contents/MacOS/Godot"
  else
    fail "Godot ${GODOT_VERSION} not found. Put godot on PATH or set GODOT to the binary."
  fi
fi

# The team id: the environment first, then the file.
team="${PKD_TEAM_ID:-}"
if [ -z "$team" ] && [ -f "$TEAM_FILE" ]; then
  team="$(tr -d '[:space:]' < "$TEAM_FILE")"
fi
if [ -z "$team" ]; then
  fail "no Apple team id. Set PKD_TEAM_ID, or save it once:
  mkdir -p ~/.config/pkd && echo YOURTEAMID > ~/.config/pkd/team_id
It is the 10-character id of your team in Xcode → Settings → Accounts (a free Apple ID has a Personal Team)."
fi
[[ "$team" =~ ^[A-Z0-9]{10}$ ]] || fail "the team id '${team}' is not 10 capital letters and digits."
grep -q "^${TEAM_KEY}=" "$PRESET" || fail "${PRESET} has no ${TEAM_KEY} line; is the iOS preset there?"

# The first physical iPhone devicectl can reach: one with a live tunnel first, then any
# that is attached (by cable or on the local network). Prints its UDID.
find_iphone() {
  local json want i
  json="$(mktemp "${TMPDIR:-/tmp}/pkd-devices.XXXXXX")"
  # one field of device i in the JSON, or "" when it is missing
  field() { plutil -extract "result.devices.${1}.${2}" raw -o - "$json" 2>/dev/null || true; }
  if ! xcrun devicectl list devices --json-output "$json" >/dev/null 2>&1; then
    rm -f "$json"
    return 1
  fi
  for want in tunnel attached; do
    i=0
    while plutil -extract "result.devices.${i}" json -o /dev/null "$json" >/dev/null 2>&1; do
      if [ "$(field "$i" hardwareProperties.reality)" = "physical" ] \
        && [ "$(field "$i" hardwareProperties.deviceType)" = "iPhone" ] \
        && [ -n "$(field "$i" hardwareProperties.udid)" ] \
        && { { [ "$want" = "tunnel" ] && [ "$(field "$i" connectionProperties.tunnelState)" = "connected" ]; } \
          || { [ "$want" = "attached" ] && [ -n "$(field "$i" connectionProperties.transportType)" ]; }; }; then
        field "$i" hardwareProperties.udid
        rm -f "$json"
        return 0
      fi
      i=$((i + 1))
    done
  done
  rm -f "$json"
  return 1
}

device="${PKD_DEVICE:-}"
if [ -z "$device" ]; then
  if ! device="$(find_iphone)"; then
    echo "Devices devicectl sees:" >&2
    xcrun devicectl list devices >&2 || true
    fail "no connected iPhone found. Connect it by cable, unlock it and tap Trust, then run this again (or set PKD_DEVICE to its UDID)."
  fi
fi
echo "==> iPhone ${device}"

# Write the team id into the preset for the export only, and always restore the committed file.
backup="$(mktemp "${TMPDIR:-/tmp}/pkd-preset.XXXXXX")"
cp "$PRESET" "$backup"
restore_preset() {
  if [ -f "$backup" ]; then
    cat "$backup" > "$PRESET"
    rm -f "$backup"
  fi
}
trap restore_preset EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
sed "s|^${TEAM_KEY}=.*|${TEAM_KEY}=\"${team}\"|" "$backup" > "$PRESET"

echo "==> Exporting the Xcode project with Godot"
# Godot refuses to export into a folder that holds files it did not write, and in an iCloud-synced
# folder (~/Documents) iCloud adds "name 2" copies of earlier exports. build/ is generated and
# ignored by git, so start from an empty folder every time.
rm -rf build/ios
mkdir -p build/ios
"$godot_bin" --headless --path godot --export-debug iOS "../${PROJECT}" \
  || fail "the Godot export failed: read the Godot ERROR lines above this one. If they name a missing template, install the ${GODOT_VERSION} export templates (Editor → Manage Export Templates)."
restore_preset
[ -d "$PROJECT" ] || fail "Godot did not write ${PROJECT}."

# A locked iPhone refuses development services (the build's device step, the install and
# the launch): wait for it to be unlocked.
locked() {
  xcrun devicectl device info lockState --device "$device" 2>/dev/null | grep -q "passcodeRequired: true"
}
wait_until_unlocked() {
  if locked; then
    echo "==> The iPhone is locked: unlock it (waiting up to ${UNLOCK_WAIT} s)"
    local waited=0
    while locked; do
      [ "$waited" -lt "$UNLOCK_WAIT" ] || fail "the iPhone stayed locked for ${UNLOCK_WAIT} s. Unlock it and run this again."
      sleep 3
      waited=$((waited + 3))
    done
  fi
}

echo "==> Building with xcodebuild"
wait_until_unlocked
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug \
  -destination "id=${device}" -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM="$team" CODE_SIGN_STYLE=Automatic "CODE_SIGN_IDENTITY=Apple Development" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" build \
  || fail "xcodebuild failed. For a signing error, sign in to your Apple ID in Xcode → Settings → Accounts and run this again with the iPhone connected."

app=""
for candidate in "$DERIVED"/Build/Products/Debug-iphoneos/*.app; do
  if [ -d "$candidate" ]; then
    app="$candidate"
    break
  fi
done
[ -n "$app" ] || fail "no .app in ${DERIVED}/Build/Products/Debug-iphoneos after the build."

wait_until_unlocked

echo "==> Installing ${app}"
xcrun devicectl device install app --device "$device" "$app" \
  || fail "the install failed. Is the iPhone unlocked, trusted (tap Trust on the phone) and in Developer Mode (Settings → Privacy & Security)?"

wait_until_unlocked

echo "==> Launching ${BUNDLE_ID}"
if ! xcrun devicectl device process launch --device "$device" "$BUNDLE_ID"; then
  fail "the launch failed. On the first install, trust the developer on the iPhone in Settings → General → VPN & Device Management, then run this again."
fi

echo "Done. With a free Apple ID this install expires in 7 days; run scripts/ios-run.sh again then."
