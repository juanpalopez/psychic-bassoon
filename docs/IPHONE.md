# Put the game on your iPhone

This guide installs the latest build of the game on your own iPhone from your Mac. One script,
`scripts/ios-run.sh`, does all the steps: it exports the Xcode project with Godot, builds it,
installs the app on the iPhone and opens it. The first time takes about 15 minutes to set
up. After that, each install takes about 3 minutes.

## What you need

- A Mac with **Xcode 15 or newer**, installed from the App Store. Open it once so it can
  finish installing its components.
- **Godot 4.7.2** in `/Applications/Godot.app`, or on your `PATH`. The version must match
  `.godot-version`. You also need its **export templates**: in Godot, open Editor → Manage
  Export Templates → Download and Install.
- An **Apple ID**. A free one works, but an app installed with it expires after 7 days. A paid
  developer account ($99 a year) keeps an install for a year.
- A **USB cable** for the first install. Later installs can also work over Wi-Fi.
- A clone of this repo on the Mac.

## One-time setup

### 1. Sign in to Xcode with your Apple ID

Xcode → Settings → Accounts → **+** → Apple ID. A free Apple ID gets a "Personal Team".

### 2. Save your team id where the script can find it

The team id is the 10-character code of your team, made of capital letters and digits. To find
it, open Xcode → Settings → Accounts, select your Apple ID, and look at the team. You can also
open **Keychain Access**, find the certificate "Apple Development: …", and read its
"Organizational Unit".

Save it once:

```bash
mkdir -p ~/.config/pkd
echo YOURTEAMID > ~/.config/pkd/team_id
```

The id is personal, so **never commit it**. The script writes it into
`godot/export_presets.cfg` only while it exports, then puts the committed file back. If you
prefer, you can set it for a single run: `PKD_TEAM_ID=YOURTEAMID scripts/ios-run.sh`.

### 3. Prepare the iPhone

1. Plug the iPhone into the Mac, unlock it, and tap **Trust** when it asks about this computer.
2. Turn on **Developer Mode**: Settings → Privacy & Security → Developer Mode, then restart the
   phone and confirm. The option only appears after the phone has been connected to Xcode
   once. If you don't see it, open Xcode → Window → Devices and Simulators with the phone
   plugged in, then look again.

## Install the game

```bash
cd ~/Documents/projects/psychic-bassoon   # your clone
git checkout main && git pull             # the latest merged game
scripts/ios-run.sh
```

**Keep the iPhone unlocked** while it runs. A locked phone refuses the build, the install and
the launch. The script waits up to 2 minutes for you to unlock it; you can give it longer
with `PKD_UNLOCK_WAIT=600 scripts/ios-run.sh`.

The script prints one line per step:

| Line | What happens |
|---|---|
| `==> iPhone 0000…` | It found your iPhone (the first physical iPhone it can reach). |
| `==> Exporting the Xcode project with Godot` | Godot writes `build/ios/PapercraftKD.xcodeproj`. |
| `==> Building with xcodebuild` | Xcode compiles and signs the app with your team. |
| `==> Installing …` | The app is copied to the iPhone. |
| `==> Launching com.juanpalopez.papercraftkd` | The game opens on the phone. |

### The first launch only

iOS blocks apps from a developer it doesn't trust yet, so the launch fails the first time. On
the iPhone, open Settings → General → **VPN & Device Management**, tap your Apple ID under
"Developer App", and tap **Trust**. Then run `scripts/ios-run.sh` again, or just tap the
game's icon.

## Every week (free Apple ID)

An install made with a free Apple ID stops opening after 7 days. Plug the phone in, unlock it
and run `scripts/ios-run.sh` again. Your progress stays, because the app is replaced, not
deleted.

## When something goes wrong

| Message | Fix |
|---|---|
| `no Apple team id` | Do step 2 of the one-time setup. |
| `no connected iPhone found` | Plug the phone in, unlock it and tap Trust. If you have several phones, pick one with `PKD_DEVICE=<UDID>`; `xcrun devicectl list devices` lists the UDIDs. |
| `devicectl not found` / `xcodebuild not found` | Install Xcode and open it once. If you have several Xcodes, set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. |
| `the Godot export failed` | Install the 4.7.2 export templates (Editor → Manage Export Templates). On a fresh clone, import the project once first: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --import`. |
| `Godot … not found` | Put Godot in `/Applications/Godot.app`, or set `GODOT=/path/to/Godot`. |
| `the iPhone stayed locked` | Unlock it and run the script again, or give it longer with `PKD_UNLOCK_WAIT`. |
| `xcodebuild failed` with a signing error | Sign in to Xcode → Settings → Accounts, keep the phone plugged in, and run it again. A free account can sign at most 3 apps per phone at a time, so delete an old test app if Xcode complains about the limit. |
| `the install failed` | The phone is locked, not trusted, or not in Developer Mode (one-time setup, step 3). |
| `resource fork, Finder information, or similar detritus not allowed` | The app was built inside a folder iCloud syncs (`~/Documents`, `~/Desktop`), and iCloud tags the files there. The script builds in `~/Library/Developer/Xcode/DerivedData/PapercraftKD-ios` to avoid it; if you set `PKD_DERIVED`, keep it outside those folders. |
| `the launch failed` | Trust the developer on the phone (see "The first launch only"). |

## What the script does, step by step

If you want to run the steps by hand, these are the commands the script runs, from the repo
root:

```bash
# 1. Find the iPhone's UDID
xcrun devicectl list devices

# 2. Export the Xcode project (with your team id in the iOS preset's app_store_team_id)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot \
  --export-debug iOS ../build/ios/PapercraftKD.xcodeproj

# 3. Build and sign it for that iPhone
xcodebuild -project build/ios/PapercraftKD.xcodeproj -scheme PapercraftKD -configuration Debug \
  -destination "id=<UDID>" -derivedDataPath ~/Library/Developer/Xcode/DerivedData/PapercraftKD-ios \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM=<TEAMID> CODE_SIGN_STYLE=Automatic "CODE_SIGN_IDENTITY=Apple Development" \
  PRODUCT_BUNDLE_IDENTIFIER=com.juanpalopez.papercraftkd build

# 4. Install and launch
xcrun devicectl device install app --device <UDID> ~/Library/Developer/Xcode/DerivedData/PapercraftKD-ios/Build/Products/Debug-iphoneos/*.app
xcrun devicectl device process launch --device <UDID> com.juanpalopez.papercraftkd
```

If you run step 2 by hand, put `godot/export_presets.cfg` back afterwards (`git checkout
godot/export_presets.cfg`) so your team id is never committed.

You can also open `build/ios/PapercraftKD.xcodeproj` in Xcode after step 2, choose your
iPhone at the top of the window, and press **Run** (⌘R). Xcode then does steps 3 and 4 itself,
and shows the game's log and its frame-time graphs while it runs.
