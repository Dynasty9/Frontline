#!/usr/bin/env bash
# After a release is built, and before it's published: file its changelog and
# bake it into the website and the matchmaker, then commit that to main, where
# Railway picks it up and redeploys both.
#
#   bake-release.sh VERSION BUILT_SHA ZIP_DIR
#
# The commit goes on top of main as it is now (more may have merged while the
# release built), retrying if main moves under it. Only the changelog entries
# that were in BUILT_SHA are filed under this version. A push with the
# workflow's token doesn't start workflows, so this can't set off another
# release. Optional: PR_NUMBER, PR_TITLE, PR_BODY (for a release with no
# changelog entry), and BAKE_REMOTE / BAKE_BRANCH (default origin / main).
set -euo pipefail

version="$1"
built="$2"
zips="$(cd "$3" && pwd)"
remote="${BAKE_REMOTE:-origin}"
branch="${BAKE_BRANCH:-main}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

python3 .github/scripts/release_json.py "$version" "$zips" > "$tmp/release.json"

for attempt in 1 2 3 4 5; do
  git fetch -q "$remote" "$branch"
  git checkout -q -f -B release-bake FETCH_HEAD
  # anything a failed attempt left behind
  git clean -q -fd changelog web/src matchmaker
  python3 .github/scripts/changelog.py release "$version" --built "$built" \
    --pr "${PR_NUMBER:-}" --pr-title "${PR_TITLE:-}" --pr-body "${PR_BODY:-}"
  cp "$tmp/release.json" web/src/release.json
  cp "$tmp/release.json" matchmaker/release.json
  git add -A changelog CHANGELOG.md web/src/changelog.json web/src/release.json matchmaker/release.json
  if git diff --cached --quiet; then
    echo "v$version is already baked into $branch"
    exit 0
  fi
  git commit -q -m "Release v$version: $(python3 .github/scripts/changelog.py name "$version")" \
    -m "The changelog filed under v$version, and the release baked into the website and the matchmaker. Written by the release workflow."
  if git push -q "$remote" "HEAD:$branch"; then
    echo "baked v$version into $branch"
    exit 0
  fi
  echo "$branch moved; trying again"
  sleep $((attempt * 5))
done
echo "::error::couldn't push the release to $branch"
exit 1
