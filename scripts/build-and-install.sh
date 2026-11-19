#!/bin/zsh
# Build this fork, signed with Peter's Apple Development cert, and install it
# to /Applications/macshot.app. Same bundle ID as upstream so settings carry over.
#   Usage: scripts/build-and-install.sh
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY=028224482326EF23584FECEF8B5816686A4E51C0   # Apple Development: Peter Kondrashov
TEAM=LK32C4B428
VERSION=4.4.0
BUILD=119   # keep >= the highest sparkle:version in appcast.xml so Sparkle never offers upstream

xcodebuild -scheme macshot -configuration Release -derivedDataPath build \
  DEVELOPMENT_TEAM=$TEAM CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=$IDENTITY \
  PROVISIONING_PROFILE_SPECIFIER= MARKETING_VERSION=$VERSION CURRENT_PROJECT_VERSION=$BUILD \
  build | grep -E "error:|BUILD (SUCCEEDED|FAILED)"

APP=build/Build/Products/Release/macshot.app
codesign --verify --deep --strict "$APP"

osascript -e 'quit app id "com.sw33tlie.macshot.macshot"' 2>/dev/null || true
sleep 1
rm -rf /Applications/macshot.app
ditto "$APP" /Applications/macshot.app
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$APP" 2>/dev/null || true
open /Applications/macshot.app
echo "Installed and launched /Applications/macshot.app"
