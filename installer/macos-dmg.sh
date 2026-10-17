#!/usr/bin/env bash
# The Mac installer, Frontline-macos.dmg: a disk image holding the app and a
# link to Applications to drag it onto, the way Mac apps usually come. Once
# it's in Applications the game can update itself (scripts/autoload/updater.gd
# swaps the whole app there); run straight from the disk image, it can't, and
# its menu sends the player to the website instead.
#
#   macos-dmg.sh ZIP DMG
#
# ZIP is the macOS export (Frontline-macos.zip: Frontline.app, ad-hoc signed,
# and the licence). Runs on a Mac, since hdiutil is macOS's own: the release
# workflow (.github/workflows/release.yml) runs it on a macOS runner. It then
# opens the image the way a player would and checks what's inside.
set -euo pipefail

zip="$1"
dmg="$2"
work="$(mktemp -d)"
stage="$work/Frontline"
mnt="$work/mnt"
mkdir -p "$stage" "$mnt"

# ditto, unlike unzip, keeps everything the app's signature covers just as it
# was, and the programs' executable bits
ditto -x -k "$zip" "$stage"
ln -s /Applications "$stage/Applications"
codesign --verify --deep --strict "$stage/Frontline.app"

# hdiutil now and then finds the image busy on a CI runner: try again
rm -f "$dmg"
for try in 1 2 3; do
  if hdiutil create -volname Frontline -srcfolder "$stage" -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$dmg"; then
    break
  fi
  [ "$try" = 3 ] && exit 1
  sleep 5
done

hdiutil attach -readonly -nobrowse -mountpoint "$mnt" "$dmg" > /dev/null
trap 'hdiutil detach -quiet "$mnt" || hdiutil detach -force -quiet "$mnt" || true' EXIT
test -x "$mnt/Frontline.app/Contents/MacOS/Frontline"
test -s "$mnt/Frontline.app/Contents/Resources/Frontline.pck"
test "$(readlink "$mnt/Applications")" = /Applications
codesign --verify --deep --strict "$mnt/Frontline.app"
ls -la "$mnt"
ls -la "$dmg"
