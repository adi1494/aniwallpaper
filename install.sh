#!/bin/zsh
# Rebuild AniWallpaper and install it into /Applications, then relaunch it.
set -euo pipefail
cd "$(dirname "$0")"

./build.sh

pkill -x AniWallpaper 2>/dev/null || true
sleep 1

rm -rf /Applications/AniWallpaper.app
cp -R AniWallpaper.app /Applications/
open /Applications/AniWallpaper.app
echo "Installed and launched /Applications/AniWallpaper.app"
