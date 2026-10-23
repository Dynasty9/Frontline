#!/usr/bin/env bash
# A release's own commit, on a branch of its own (release/vVERSION): every
# waiting changelog entry filed under changelog/vVERSION/, and the release
# (version, download links, checksums) baked into the website and the
# matchmaker. The release workflow drafts the release at this commit and opens
# a pull request from the branch. Merging that is what releases it: Publish
# release tags this commit and publishes it, so the tag holds exactly the game
# that was built plus its changelog, and the merge puts it on the website and
# tells the matchmaker, and through it every copy of the game. (main only takes
# pull requests, so the workflow can't commit there itself.)
#
#   bake-release.sh VERSION ZIP_DIR [NAME]
#
# Run it on the commit that was built. NAME names the release (by default it's
# named after its headline entry). Prints the new commit's SHA. BAKE_REMOTE
# pushes somewhere other than origin.
set -euo pipefail

version="$1"
zips="$(cd "$2" && pwd)"
name="${3:-}"
branch="release/v$version"
remote="${BAKE_REMOTE:-origin}"

# Still the next release? The build took minutes, and a release merged in the
# meantime would have shipped some of these entries already.
git fetch -q "$remote" main
if git ls-remote --exit-code --tags "$remote" "refs/tags/v$version" > /dev/null; then
  echo "v$version was released while this was building: run Release again." >&2
  exit 1
fi
gone=$(git diff --name-only --diff-filter=D HEAD FETCH_HEAD -- changelog/unreleased)
if [ -n "$gone" ]; then
  echo "A release merged while this was building, and took some of these entries with it: run Release again." >&2
  echo "$gone" >&2
  exit 1
fi

python3 .github/scripts/changelog.py release "$version" --name "$name" >&2
python3 .github/scripts/release_json.py "$version" "$zips" > web/src/release.json
cp web/src/release.json matchmaker/release.json

git switch -q -C "$branch"
git add -A changelog CHANGELOG.md web/src/changelog.json web/src/release.json matchmaker/release.json
git commit -q -m "Release v$version: $(python3 .github/scripts/changelog.py name "$version")" \
  -m "The changelog filed under v$version, and the release baked into the website and the matchmaker. Written by the release workflow."

# forced: running Release again rebuilds the release on the same branch
git push -q --force "$remote" "HEAD:refs/heads/$branch"
git rev-parse HEAD
