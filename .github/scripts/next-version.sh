#!/usr/bin/env bash
# The next release version after the newest vX.Y.Z tag, without the "v".
#   next-version.sh [patch|minor|major]      (default patch)
# With no release yet, the first is 0.1.0 whatever the bump.
set -euo pipefail
bump="${1:-patch}"
last=$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -n 1)
if [ -z "$last" ]; then
  echo "0.1.0"
  exit 0
fi
IFS=. read -r major minor patch <<< "${last#v}"
patch="${patch%%[!0-9]*}"
case "$bump" in
  major) echo "$((major + 1)).0.0" ;;
  minor) echo "$major.$((minor + 1)).0" ;;
  patch) echo "$major.$minor.$((patch + 1))" ;;
  *) echo "unknown bump '$bump' (patch, minor or major)" >&2; exit 1 ;;
esac
